import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/core/app_info.dart';
import 'package:kassa/core/clock.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/data/sync_state_repository.dart';
import 'package:kassa/sync/server_api.dart';
import 'package:kassa/sync/server_changes.dart';
import 'package:kassa/sync/sync_service.dart';
import 'package:kassa/sync/token_store.dart';

import '../support/fake_server.dart';

final start = DateTime(2026, 11, 18, 10);

class _FakeClock implements Clock {
  _FakeClock(this._async);

  final FakeAsync _async;

  @override
  DateTime now() => start.add(_async.elapsed);
}

/// Ein gekoppeltes Tablet mit dem Beispiel-Imbiss, in der Zeit von
/// [FakeAsync].
class Harness {
  Harness(this.async, {bool paired = true, bool enabled = true}) {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = KassaDatabase(NativeDatabase.memory());
    sync = SyncStateRepository(db);
    server = FakeServer.beispiel(pageSize: 2);
    run(tokens.write(FakeServer.token));
    run(
      sync.saveRegister(
        registerId: FakeServer.registerId,
        registerName: 'Kassa 1',
        businessId: FakeServer.businessId,
      ),
    );
    if (paired) {
      run(ServerChanges(db).replaceAll(server.pages(), at: start));
    }
    service = SyncService(
      api: ServerApi(
        baseUrl: 'https://kassa.example',
        client: server,
        appVersion: '1.2.0',
      ),
      tokens: tokens,
      syncState: sync,
      changes: ServerChanges(db),
      clock: _FakeClock(async),
      internet: internet.stream,
      resumed: resumed.stream,
      enabled: enabled,
    );
  }

  final FakeAsync async;
  late final KassaDatabase db;
  late final SyncStateRepository sync;
  late final FakeServer server;
  late final SyncService service;
  final tokens = MemoryTokenStore();
  final internet = StreamController<bool>();
  final resumed = StreamController<void>();

  /// Lässt [f] in der falschen Zeit fertig laufen, ohne die Uhr zu bewegen.
  T run<T>(Future<T> f) {
    var done = false;
    late T value;
    Object? error;
    f.then(
      (v) {
        value = v;
        done = true;
      },
      onError: (Object e) {
        error = e;
        done = true;
      },
    );
    for (var i = 0; i < 1000 && !done; i++) {
      async.elapse(Duration.zero);
    }
    if (error != null) throw error!;
    expect(done, isTrue, reason: 'Future ist nicht fertig geworden');
    return value;
  }

  SyncState state() => run(sync.current());

  int get pulls => server.pullRequests.length;

  void close() {
    service.dispose();
    run(db.close());
  }
}

void main() {
  test('nicht gekoppelt: syncNow fragt den Server nicht', () {
    fakeAsync((async) {
      final h = Harness(async, paired: false);
      h.run(h.service.syncNow());
      expect(h.pulls, 0);
      expect(h.state().lastError, isNull);
      h.close();

      // Ohne Adresse des Servers auch dann nicht, wenn gekoppelt.
      final off = Harness(async, enabled: false);
      off.service.start();
      off.run(off.service.syncNow());
      async.elapse(const Duration(hours: 1));
      expect(off.pulls, 0);
      off.close();
    });
  });

  test('ohne Adresse des Servers fragt auch der Provider nie', () async {
    expect(hasServer, isFalse, reason: 'Tests bauen ohne KASSA_SERVER_URL');
    final db = KassaDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final server = FakeServer.beispiel();
    final tokens = MemoryTokenStore();
    await tokens.write(FakeServer.token);
    await SyncStateRepository(db).saveRegister(
      registerId: FakeServer.registerId,
      registerName: 'Kassa 1',
      businessId: FakeServer.businessId,
    );
    await ServerChanges(db).replaceAll(server.pages(), at: start);
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        tokenStoreProvider.overrideWithValue(tokens),
        httpClientProvider.overrideWithValue(server),
      ],
    );
    addTearDown(container.dispose);

    await container.read(syncServiceProvider).syncNow();

    expect(server.pullRequests, isEmpty);
  });

  test('Lauf holt alle Seiten und merkt sich den Zeitpunkt', () {
    fakeAsync((async) {
      final h = Harness(async);
      final cursor = h.state().pullCursor;
      h.server
        ..change('items', 'cola', {'priceCents': 310})
        ..change('items', 'teigtaschen', {'priceCents': 700})
        ..archive('items', 'huhn-bowl')
        ..change('categories', 'bowls', {'name': 'Schüsseln'})
        ..upsert(
          'staff',
          FakeServer.staffRow(id: 's-ben', name: 'Ben', pin: '4321'),
        );
      h.run(h.sync.setResult(at: start, error: 'offline'));
      async.elapse(const Duration(minutes: 7));

      h.run(h.service.syncNow());

      expect(h.server.pullRequests, [cursor, cursor + 2, cursor + 4]);
      final s = h.state();
      expect(s.pullCursor, h.server.seq);
      expect(s.lastPullAt, start.add(const Duration(minutes: 7)));
      expect(s.lastError, isNull);
      expect(s.blocked, isFalse);
      final cola = h.run(
        (h.db.select(
          h.db.itemRows,
        )..where((t) => t.id.equals('cola'))).getSingle(),
      );
      expect(cola.priceCents, 310);
      h.close();
    });
  });

  test('zwei syncNow gleichzeitig: nur ein Lauf', () {
    fakeAsync((async) {
      final h = Harness(async);
      final running = <bool>[];
      h.service.running.listen(running.add);

      final first = h.service.syncNow();
      final second = h.service.syncNow();
      h.run(Future.wait([first, second]));

      expect(h.pulls, 1);
      expect(running, [true, false]);
      h.close();
    });
  });

  test('offline: lastError gesetzt, nächste Versuche nach 30 s, 1 min, 2 min, höchstens 15 min, Erfolg setzt zurück', () {
    fakeAsync((async) {
      final h = Harness(async);
      h.server.mode = FakeMode.offline;
      final lastPullAt = h.state().lastPullAt;
      h.service.start();
      h.run(Future<void>.value());
      expect(h.pulls, 1);
      expect(h.state().lastError, 'offline');
      expect(h.state().lastPullAt, lastPullAt);

      void nextAfter(Duration d) {
        final before = h.pulls;
        async.elapse(d - const Duration(seconds: 1));
        expect(h.pulls, before, reason: 'zu früh vor $d');
        async.elapse(const Duration(seconds: 1));
        expect(h.pulls, before + 1, reason: 'nach $d');
      }

      for (final seconds in [30, 60, 120, 240, 480, 900, 900, 900]) {
        nextAfter(Duration(seconds: seconds));
      }
      expect(h.state().lastError, 'offline');

      h.server.mode = FakeMode.online;
      nextAfter(const Duration(minutes: 15));
      expect(h.state().lastError, isNull);

      // Nach dem Erfolg wieder alle 5 Minuten, und der nächste Fehler
      // beginnt wieder bei 30 Sekunden.
      h.server.mode = FakeMode.offline;
      nextAfter(const Duration(minutes: 5));
      expect(h.state().lastError, 'offline');
      nextAfter(const Duration(seconds: 30));
      nextAfter(const Duration(seconds: 60));
      h.close();
    });
  });

  test('gesperrt: blocked = true, kein schnelles Wiederholen, nach dem Aufheben wieder false', () {
    fakeAsync((async) {
      final h = Harness(async);
      h.server.mode = FakeMode.blocked;
      h.service.start();
      h.run(Future<void>.value());
      expect(h.pulls, 1);
      expect(h.state().blocked, isTrue);
      expect(h.state().lastPullAt, start, reason: 'Zeitpunkt rückt nicht');

      async.elapse(const Duration(minutes: 4, seconds: 59));
      expect(h.pulls, 1);
      async.elapse(const Duration(seconds: 1));
      expect(h.pulls, 2);
      expect(h.state().blocked, isTrue);

      h.server.mode = FakeMode.online;
      async.elapse(const Duration(minutes: 5));
      expect(h.pulls, 3);
      expect(h.state().blocked, isFalse);
      expect(h.state().lastError, isNull);
      h.close();
    });
  });

  test('unauthorized: lastError = unauthorized', () {
    fakeAsync((async) {
      final h = Harness(async);
      h.server.mode = FakeMode.unauthorized;
      h.service.start();
      h.run(Future<void>.value());
      expect(h.state().lastError, 'unauthorized');
      async.elapse(const Duration(minutes: 4, seconds: 59));
      expect(h.pulls, 1, reason: 'kein schnelles Wiederholen');

      // Der Schlüssel fehlt, obwohl die Kassa gekoppelt ist: wie
      // unauthorized, ohne den Server zu fragen.
      h.server.mode = FakeMode.online;
      h.run(h.sync.setResult(at: start, error: 'offline'));
      h.run(h.tokens.clear());
      async.elapse(const Duration(seconds: 1));
      expect(h.pulls, 1);
      expect(h.state().lastError, 'unauthorized');
      h.close();
    });
  });

  test('syncNow wirft auch bei unlesbarer Antwort nicht', () {
    fakeAsync((async) {
      final h = Harness(async);
      h.server.mode = FakeMode.garbage;
      h.run(h.service.syncNow());
      expect(h.state().lastError, 'server');

      // Auch eine Seite, die sich nicht einspielen lässt, wirft nicht.
      h.server.mode = FakeMode.online;
      final groups = h.server.rowOf('templates', 'bowl')['groups']! as List;
      h.server.change('templates', 'bowl', {
        'groups': [groups[0], groups[0]],
      });
      final cursor = h.state().pullCursor;
      h.run(h.service.syncNow());
      expect(h.state().lastError, 'server');
      expect(h.state().pullCursor, cursor);

      // Und die Datenbank ist weg.
      h.run(h.db.close());
      h.run(h.service.syncNow());
      h.service.dispose();
    });
  });

  test('alle 5 Minuten ein Lauf, und einer, wenn das Internet zurückkommt', () {
    fakeAsync((async) {
      final h = Harness(async);
      h.service.start();
      h.internet.add(true);
      h.run(Future<void>.value());
      expect(h.pulls, 1);

      async.elapse(const Duration(minutes: 5));
      expect(h.pulls, 2);
      async.elapse(const Duration(minutes: 5));
      expect(h.pulls, 3);

      async.elapse(const Duration(minutes: 1));
      h.internet.add(false);
      async.elapse(Duration.zero);
      expect(h.pulls, 3);
      h.internet.add(true);
      async.elapse(Duration.zero);
      expect(h.pulls, 4);

      // Die App kommt wieder nach vorn.
      async.elapse(const Duration(minutes: 1));
      h.resumed.add(null);
      async.elapse(Duration.zero);
      expect(h.pulls, 5);

      // Der nächste regelmäßige Lauf zählt ab dem letzten.
      async.elapse(const Duration(minutes: 4, seconds: 59));
      expect(h.pulls, 5);
      async.elapse(const Duration(seconds: 1));
      expect(h.pulls, 6);

      h.close();
      async.elapse(const Duration(hours: 1));
      expect(h.pulls, 6, reason: 'nach dispose läuft nichts mehr');
    });
  });
}
