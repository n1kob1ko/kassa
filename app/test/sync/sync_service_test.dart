import 'dart:async';
import 'dart:convert';
import 'dart:io' show Directory;

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart' show WidgetsFlutterBinding, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/app_sync_providers.dart';
import 'package:kassa/core/app_info.dart';
import 'package:kassa/core/clock.dart';
import 'package:kassa/data/customer_repository.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/outbox_repository.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/data/report_repository.dart';
import 'package:kassa/data/sync_state_repository.dart';
import 'package:kassa/devices/internet.dart';
import 'package:kassa/sync/file_sync.dart';
import 'package:kassa/sync/pairing_service.dart';
import 'package:kassa/sync/server_api.dart';
import 'package:kassa/sync/push_wire.dart';
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
  Harness(
    this.async, {
    bool paired = true,
    bool enabled = true,
    FileSync Function(KassaDatabase db, ServerApi api)? files,
    void Function()? onChanged,
  }) {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = KassaDatabase(NativeDatabase.memory());
    sync = SyncStateRepository(db);
    outbox = OutboxRepository(db);
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
    final api = ServerApi(
      baseUrl: 'https://kassa.example',
      client: server,
      appVersion: '1.2.0',
    );
    service = SyncService(
      api: api,
      files: files?.call(db, api),
      onChanged: onChanged ?? () {},
      tokens: tokens,
      syncState: sync,
      changes: ServerChanges(db),
      outbox: outbox,
      payloads: PushPayloads(db),
      clock: _FakeClock(async),
      internet: internet.stream,
      resumed: resumed.stream,
      enabled: enabled,
      reportError: ReportRepository(
        db,
        _FakeClock(async),
        appVersion: '1.6.0',
      ).addError,
    );
  }

  final FakeAsync async;
  late final KassaDatabase db;
  late final SyncStateRepository sync;
  late final OutboxRepository outbox;
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

  /// Ein Tag in der Datenbank; die Trigger stellen ihn in die Liste.
  void addDay(String id, {bool open = false, int? openingFloat}) => run(
    db
        .into(db.businessDayRows)
        .insert(
          BusinessDayRowsCompanion.insert(
            id: id,
            openedAt: start,
            closedAt: Value(open ? null : start),
            openingFloatCents: Value(openingFloat),
          ),
        ),
  );

  /// Ändert den Tag und hebt damit `rev` seines Eintrags.
  Future<void> setFloat(String id, int cents) =>
      (db.update(db.businessDayRows)..where((t) => t.id.equals(id))).write(
        BusinessDayRowsCompanion(openingFloatCents: Value(cents)),
      );

  OutboxCounts counts() => run(outbox.watchCounts().first);

  /// Die Kennungen der Tage je Anfrage an `push`.
  List<List<String>> pushedDays() => [
    for (final request in server.pushRequests)
      [for (final e in request) (e['day']! as Map)['id']! as String],
  ];

  String? rejectedReason() => run(
    db
        .customSelect("SELECT reason FROM outbox WHERE state = 'rejected'")
        .getSingleOrNull()
        .then((r) => r?.read<String>('reason')),
  );

  void close() {
    service.dispose();
    run(db.close());
  }
}

/// Ein `FileSync`, das nichts lädt: es merkt sich nur, womit es gerufen wurde.
class _StubFiles extends FileSync {
  _StubFiles(KassaDatabase db, ServerApi api)
    : super(db, api, () async => Directory.systemTemp);

  final tokens = <String>[];
  bool result = false;
  Object? failure;

  @override
  Future<bool> run(String token) async {
    tokens.add(token);
    if (failure != null) throw failure!;
    return result;
  }
}

void main() {
  group('Bilder', () {
    test('nach dem Holen: die Bilder laden, mit dem Schlüssel, und der Katalog '
        'wird neu gelesen, wenn etwas neu ist', () {
      fakeAsync((async) {
        late _StubFiles files;
        var changed = 0;
        final h = Harness(
          async,
          files: (db, api) => files = _StubFiles(db, api)..result = true,
          onChanged: () => changed++,
        );
        h.run(h.service.syncNow());
        expect(files.tokens, [FakeServer.token]);
        // Nichts Neues geholt, aber ein Bild ist neu da.
        expect(changed, 1);
        files.result = false;
        async.elapse(const Duration(minutes: 5));
        h.run(h.service.syncNow());
        expect(files.tokens, hasLength(2));
        expect(changed, 1);
        h.close();
      });
    });

    test('ein Fehler beim Laden macht den Lauf nicht zum Fehler, '
        '"Zuletzt abgeglichen" rückt trotzdem', () {
      fakeAsync((async) {
        late _StubFiles files;
        final h = Harness(
          async,
          files: (db, api) =>
              files = _StubFiles(db, api)..failure = StateError('Platte voll'),
        );
        async.elapse(const Duration(minutes: 3));
        h.run(h.service.syncNow());
        expect(files.tokens, hasLength(1));
        final s = h.state();
        expect(s.lastError, isNull);
        expect(s.lastPullAt, start.add(const Duration(minutes: 3)));
        h.close();
      });
    });

    test('scheitert das Holen, wird nichts geladen', () {
      fakeAsync((async) {
        late _StubFiles files;
        final h = Harness(
          async,
          files: (db, api) => files = _StubFiles(db, api),
        );
        h.server.mode = FakeMode.offline;
        h.run(h.service.syncNow());
        expect(files.tokens, isEmpty);
        h.close();
      });
    });

    test('Laden ohne neues Bild ändert "Zuletzt abgeglichen" nicht', () {
      fakeAsync((async) {
        late _StubFiles files;
        final h = Harness(
          async,
          files: (db, api) => files = _StubFiles(db, api),
        );
        async.elapse(const Duration(minutes: 1));
        h.run(h.service.syncNow());
        final at = h.state().lastPullAt;
        expect(at, start.add(const Duration(minutes: 1)));
        expect(files.tokens, hasLength(1));
        h.close();
      });
    });
  });

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
      h.run(h.service.syncNow());
      expect(h.pulls, 1);
      expect(h.state().lastError, 'unauthorized');
      h.close();
    });
  });

  test('syncNow wirft auch bei unlesbarer Antwort nicht', () {
    // Fehler am Tablet gehen beim Entwickeln ins Protokoll, nur ihre Art.
    final printed = <String>[];
    final original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) => printed.add('$message');
    addTearDown(() => debugPrint = original);
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
      expect(h.state().lastError, 'local', reason: 'ein Fehler am Tablet');
      expect(h.state().pullCursor, cursor);

      // Und die Datenbank ist weg.
      h.run(h.db.close());
      h.run(h.service.syncNow());
      h.service.dispose();
    });
    expect(printed, [
      'Abgleich: Fehler am Tablet (SqliteException)',
      'Abgleich: Fehler am Tablet (StateError)',
    ]);
    expect(printed.join(), isNot(contains(FakeServer.token)));
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

  test('neues Koppeln zwischen pull und Einspielen: die alte Seite wird still verworfen', () {
    fakeAsync((async) {
      final h = Harness(async);
      // Die Seite, die gerade unterwegs ist.
      h.server.change('items', 'cola', {'priceCents': 310});
      final pairing = PairingService(
        api: ServerApi(
          baseUrl: 'https://kassa.example',
          client: h.server,
          appVersion: '1.2.0',
        ),
        tokens: h.tokens,
        syncState: h.sync,
        changes: ServerChanges(h.db),
        clock: _FakeClock(async),
        onCatalogReplaced: () {},
      );
      h.server.beforeNextPage = () async {
        h.server.archive('items', 'cola');
        await pairing.pair(FakeServer.code);
        await pairing.loadInitial();
      };

      h.service.start();
      h.run(h.service.syncNow());

      final s = h.state();
      expect(s.pullCursor, h.server.seq, reason: 'Cursor aus loadInitial');
      expect(s.lastError, isNull);
      final cola = h.run(
        (h.db.select(
          h.db.itemRows,
        )..where((t) => t.id.equals('cola'))).getSingle(),
      );
      expect(cola.archived, isTrue);
      final pulls = h.pulls;
      async.elapse(const Duration(minutes: 4, seconds: 59));
      expect(h.pulls, pulls, reason: 'kein schnelles Wiederholen');
      h.close();
    });
  });

  group('senden', () {
    test('250 Einträge gehen in drei Paketen in Reihenfolge hinauf', () {
      fakeAsync((async) {
        final h = Harness(async);
        final ids = [
          for (var i = 0; i < 250; i++) 'd${i.toString().padLeft(3, '0')}',
        ];
        for (final id in ids) {
          h.addDay(id);
        }

        h.run(h.service.syncNow());

        expect(h.server.pushRequests.map((r) => r.length), [100, 100, 50]);
        expect(h.pushedDays().expand((d) => d).toList(), ids);
        final seqs = [
          for (final r in h.server.pushRequests) ...[
            for (final e in r) e['seq']! as int,
          ],
        ];
        expect(seqs, [...seqs]..sort());
        expect(h.server.received, hasLength(250));
        expect(h.counts().pending, 0);
        expect(h.state().lastError, isNull);
        expect(h.pulls, greaterThan(0));
        h.close();
      });
    });

    test('Antwort geht verloren: beim nächsten Lauf kommt alles noch einmal, danach ist die Liste leer', () {
      fakeAsync((async) {
        final h = Harness(async);
        for (final id in ['a', 'b', 'c']) {
          h.addDay(id);
        }
        h.server.loseNextPushAnswer = true;

        h.run(h.service.syncNow());

        expect(h.state().lastError, 'offline');
        expect(h.counts().pending, 3, reason: 'nichts gelöscht');
        expect(h.server.received, hasLength(3));

        h.run(h.service.syncNow());

        expect(h.pushedDays(), [
          ['a', 'b', 'c'],
          ['a', 'b', 'c'],
        ]);
        expect(h.server.received, hasLength(3), reason: 'nichts doppelt');
        expect(h.counts().pending, 0);
        expect(h.state().lastError, isNull);
        h.close();
      });
    });

    test('Tag ändert sich zwischen Bauen und Antwort: Eintrag bleibt und geht im nächsten Lauf mit dem neuen Stand hinauf', () {
      fakeAsync((async) {
        final h = Harness(async);
        h.addDay('a', open: true);
        h.server.beforePushAnswer = () => h.setFloat('a', 5000);

        h.run(h.service.syncNow());

        expect(h.counts().pending, 1, reason: 'der Eintrag bleibt');
        expect(h.server.pushRequests, hasLength(1));

        h.run(h.service.syncNow());

        expect(h.server.pushRequests, hasLength(2));
        final day = h.server.pushRequests.last.single['day']! as Map;
        expect(day['openingFloatCents'], 5000);
        expect(h.counts().pending, 0);
        h.close();
      });
    });

    test('abgelehnter Eintrag hält die anderen nicht auf', () {
      fakeAsync((async) {
        final h = Harness(async);
        for (final id in ['a', 'b', 'c']) {
          h.addDay(id);
        }
        h.server.pushStatuses[2] = 'rejected';

        h.run(h.service.syncNow());

        expect(h.server.received, hasLength(2));
        final counts = h.counts();
        expect((counts.pending, counts.rejected), (0, 1));
        expect(h.rejectedReason(), isNotNull);
        expect(h.pulls, greaterThan(0), reason: 'Holen läuft trotzdem');
        expect(h.state().lastError, isNull);

        // Der abgelehnte wird nicht noch einmal gesendet.
        h.run(h.service.syncNow());
        expect(h.server.pushRequests, hasLength(1));
        h.close();
      });
    });

    test('Paket scheitert mit 422: einzeln senden, der kaputte wird abgelehnt, der Rest kommt an', () {
      fakeAsync((async) {
        final h = Harness(async);
        for (final id in ['a', 'bad', 'c']) {
          h.addDay(id);
        }
        h.server.rejectWholeIf = (e) => (e['day']! as Map)['id'] == 'bad';

        h.run(h.service.syncNow());

        expect(h.pushedDays(), [
          ['a', 'bad', 'c'],
          ['a'],
          ['bad'],
          ['c'],
        ]);
        expect(h.server.received, hasLength(2));
        final counts = h.counts();
        expect((counts.pending, counts.rejected), (0, 1));
        expect(h.rejectedReason(), 'invalid');
        expect(h.state().lastError, isNull);
        expect(h.pulls, greaterThan(0));
        h.close();
      });
    });

    test(
      'ein Eintrag lässt sich nicht bauen: abgelehnt mit Grund local, ein '
      'Bericht mit Art des Eintrags und des Fehlers, die anderen gehen hinauf',
      () {
        fakeAsync((async) {
          final h = Harness(async);
          h.addDay('a');
          // Ein Wert, der kein JSON ist: das Bauen wirft.
          h.run(
            h.db.customStatement(
              'INSERT INTO outbox (kind, ref, field, value, changed_at) '
              "VALUES ('item_change', 'cola', 'priceCents', 'kaputt{', 0)",
            ),
          );
          h.addDay('b');

          h.run(h.service.syncNow());

          // Der Bericht entsteht während des Laufs und geht gleich mit hinauf.
          expect(
            [
              for (final r in h.server.pushRequests)
                [for (final e in r) e['kind']],
            ],
            [
              ['day', 'day'],
              ['report'],
            ],
          );
          expect(
            [
              for (final e in h.server.pushRequests.first)
                (e['day']! as Map)['id'],
            ],
            ['a', 'b'],
          );
          final counts = h.counts();
          expect((counts.pending, counts.rejected), (0, 1));
          expect(h.rejectedReason(), 'local');
          final reports = h.run(h.db.select(h.db.reportRows).get());
          expect(reports, hasLength(1));
          expect(jsonDecode(reports.single.content), {
            'type': 'OutboxBuildError',
            'message': 'Eintrag item_change: FormatException',
            'stack': '',
          });
          expect(reports.single.content, isNot(contains('kaputt')));

          // Der abgelehnte geht nicht noch einmal.
          h.run(h.service.syncNow());
          expect(h.server.pushRequests, hasLength(2));
          h.close();
        });
      },
    );

    test('Zeitüberschreitung beim Senden: das nächste Paket ist kleiner '
        '(100, 25, 5), nach einem, das durchging, wieder 100', () {
      fakeAsync((async) {
        final h = Harness(async);
        for (var i = 0; i < 40; i++) {
          h.addDay('d${i.toString().padLeft(2, '0')}');
        }
        // 1,5 Sekunden je Eintrag: erst 5 Einträge gehen in 30 Sekunden.
        h.server.pushDelay = (n) => Duration(milliseconds: 1500 * n);
        h.service.start();
        async.elapse(const Duration(seconds: 31));
        expect(h.state().lastError, 'timeout');

        async.elapse(const Duration(minutes: 10));
        expect(h.server.pushRequests.map((r) => r.length).take(4), [
          40,
          25,
          5,
          35,
        ]);
        h.close();
      });
    });

    test('ein Paket darf 30 Sekunden auf die Antwort warten', () {
      fakeAsync((async) {
        final h = Harness(async);
        h.addDay('a');
        h.server.pushDelay = (_) => const Duration(seconds: 25);
        h.service.syncNow();
        async.elapse(const Duration(seconds: 40));
        expect(h.server.pushRequests, hasLength(1));
        expect(h.counts().pending, 0);
        expect(h.state().lastError, isNull);
        h.close();
      });
    });

    test('error: Eintrag bleibt, Holen läuft trotzdem, nächster Lauf nach 30 Sekunden', () {
      fakeAsync((async) {
        final h = Harness(async);
        h.addDay('a');
        h.addDay('b');
        async.elapse(const Duration(minutes: 1));
        final lastPullAt = h.state().lastPullAt;
        h.server.pushStatuses[2] = 'error';
        h.service.start();
        h.run(Future<void>.value());

        expect(
          h.server.pushRequests,
          hasLength(1),
          reason: 'nicht noch einmal',
        );
        expect(h.pulls, greaterThan(0), reason: 'Holen läuft trotzdem');
        expect(h.counts().pending, 1);
        expect(h.state().lastPullAt, lastPullAt, reason: 'nicht abgeglichen');
        final pulls = h.pulls;

        async.elapse(const Duration(seconds: 29));
        expect(h.server.pushRequests, hasLength(1));
        h.server.pushStatuses.clear();
        async.elapse(const Duration(seconds: 1));

        expect(h.pushedDays(), [
          ['a', 'b'],
          ['b'],
        ]);
        expect(h.pulls, greaterThan(pulls));
        expect(h.counts().pending, 0);
        expect(h.state().lastError, isNull);
        h.close();
      });
    });

    test('ohne Internet: nichts gelöscht, Zuletzt abgeglichen rückt nicht', () {
      fakeAsync((async) {
        final h = Harness(async);
        h.addDay('a');
        async.elapse(const Duration(minutes: 1));
        final lastPullAt = h.state().lastPullAt;
        h.server.mode = FakeMode.offline;

        h.run(h.service.syncNow());

        expect(h.server.pushRequests, hasLength(1));
        expect(h.counts().pending, 1);
        expect(h.state().lastError, 'offline');
        expect(h.state().lastPullAt, lastPullAt);
        h.close();
      });
    });

    test('gesperrt: kein Holen, Liste bleibt', () {
      fakeAsync((async) {
        final h = Harness(async);
        h.addDay('a');
        h.server.mode = FakeMode.blocked;

        h.run(h.service.syncNow());

        expect(h.server.pushRequests, hasLength(1));
        expect(h.pulls, 0);
        expect(h.counts().pending, 1);
        expect(h.state().blocked, isTrue);
        h.close();
      });
    });

    test(
      'poke: fünf Aufrufe in einer Sekunde ergeben einen Lauf nach 2 Sekunden',
      () {
        fakeAsync((async) {
          final h = Harness(async);
          h.addDay('a');
          for (var i = 0; i < 5; i++) {
            h.service.poke();
            async.elapse(const Duration(milliseconds: 250));
          }
          // Der letzte Aufruf liegt jetzt 1999 Millisekunden zurück.
          async.elapse(const Duration(milliseconds: 1749));
          h.run(Future<void>.value());
          expect(h.server.pushRequests, isEmpty);

          async.elapse(const Duration(milliseconds: 1));
          h.run(Future<void>.value());

          expect(h.server.pushRequests, hasLength(1));
          expect(h.pulls, greaterThan(0));
          async.elapse(const Duration(seconds: 10));
          expect(h.server.pushRequests, hasLength(1), reason: 'nur ein Lauf');
          h.close();
        });
      },
    );

    test(
      'poke während eines Laufs: kein zweiter Lauf zugleich, einer danach',
      () {
        fakeAsync((async) {
          final h = Harness(async);
          h.addDay('a');
          final gate = Completer<void>();
          h.server.beforePushAnswer = () => gate.future;
          final first = h.service.syncNow();
          async.elapse(Duration.zero);
          expect(h.server.pushRequests, hasLength(1));

          h.addDay('b');
          h.service.poke();
          async.elapse(const Duration(seconds: 5));
          expect(h.server.pushRequests, hasLength(1), reason: 'nicht parallel');
          expect(h.pulls, 0);

          gate.complete();
          h.run(first);
          expect(h.pulls, 1, reason: 'ein Lauf');
          async.elapse(const Duration(seconds: 1));
          expect(h.pulls, 1, reason: 'erst nach 2 Sekunden Ruhe');
          async.elapse(const Duration(seconds: 1));
          h.run(Future<void>.value());

          expect(h.pulls, 2, reason: 'danach ein weiterer Lauf');
          expect(h.pushedDays(), [
            ['a'],
            ['b'],
          ]);
          h.close();
        });
      },
    );

    test('nicht gekoppelt: senden tut nichts', () {
      fakeAsync((async) {
        final h = Harness(async, paired: false);
        h.addDay('a');

        h.service.poke();
        async.elapse(const Duration(seconds: 10));
        h.run(h.service.syncNow());

        expect(h.server.pushRequests, isEmpty);
        expect(h.counts().pending, 1);

        final off = Harness(async, enabled: false);
        off.addDay('a');
        off.service.poke();
        async.elapse(const Duration(seconds: 10));
        expect(off.server.pushRequests, isEmpty);
        off.close();
        h.close();
      });
    });
  });

  test(
    'ein Lauf, der die erste Chefin bringt, macht die Einrichtung fertig',
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      final db = KassaDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final server = FakeServer.beispiel()..archive('staff', '<uuid>');
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
          serverApiProvider.overrideWithValue(
            ServerApi(
              baseUrl: 'https://kassa.example',
              client: server,
              appVersion: '1.2.0',
            ),
          ),
          hasServerProvider.overrideWithValue(true),
          internetProvider.overrideWith((ref) => Stream.value(true)),
        ],
      );
      addTearDown(container.dispose);
      container.listen(setupCompleteProvider, (_, _) {});
      expect(await container.read(setupCompleteProvider.future), isFalse);

      server.upsert(
        'staff',
        FakeServer.staffRow(
          id: 's-ben',
          name: 'Ben',
          pin: '4321',
          role: 'chef',
        ),
      );
      await container.read(syncServiceProvider).syncNow();
      await pumpEventQueue();

      expect(await container.read(setupCompleteProvider.future), isTrue);
    },
  );

  group('Firmenkunden (Stufe 1b)', () {
    const customerId = 'c0000000-0000-4000-8000-00000000000a';
    final muster = <String, Object?>{
      'id': customerId,
      'name': 'Muster GmbH',
      'addressLine1': 'Musterweg 1',
      'addressLine2': '1010 Wien',
      'vatId': 'ATU00000000',
      'archived': false,
    };

    bool catchUpPending(Harness h) =>
        h.run(h.db.select(h.db.syncStateRows).getSingle()).catchUpPending;
    CustomerRow? customer(Harness h) => h.run(
      (h.db.select(
        h.db.customerRows,
      )..where((t) => t.id.equals(customerId))).getSingleOrNull(),
    );
    String colaName(Harness h) => h.run(
      (h.db.select(
        h.db.itemRows,
      )..where((t) => t.id.equals('cola'))).getSingle(),
    ).name;

    test('Nachholen: mit catchUpPending kommt ein Kunde mit Änderungs-Nummer '
        'unter dem eigenen pullCursor an; pullCursor und Artikel bleiben; '
        'danach ist catchUpPending falsch; ein Abbruch mittendrin lässt es '
        'wahr', () {
      fakeAsync((async) {
        final h = Harness(async);
        // Wie 1.11.0: der Kunde kam beim Abholen an, die Liste wurde
        // überlesen, der Cursor steht schon dahinter. Die Migration auf 9
        // hat catchUpPending gesetzt.
        h.server.upsert('customers', muster);
        final cursor = h.server.seq;
        h.run(
          h.db
              .update(h.db.syncStateRows)
              .write(
                SyncStateRowsCompanion(
                  pullCursor: Value(cursor),
                  catchUpPending: const Value(true),
                ),
              ),
        );
        // Ein Artikel am Tablet, anders als am Server: das Nachholen fasst
        // ihn nicht an.
        h.run(
          h.db.customStatement(
            "UPDATE items SET name = 'Tablet-Cola' WHERE id = 'cola'",
          ),
        );

        // Abbruch nach der ersten Seite des Nachholens.
        h.server.breakAfterPages = 1;
        h.run(h.service.syncNow());
        expect(h.server.pullRequests, [0, 2]);
        expect(catchUpPending(h), isTrue);
        expect(h.state().pullCursor, cursor);
        expect(h.state().lastError, ServerFailure.offline.name);

        // Der nächste Lauf beginnt wieder bei 0, holt bis zum eigenen Cursor
        // und dann wie immer ab dem Cursor.
        h.server.breakAfterPages = null;
        h.server.pullRequests.clear();
        h.run(h.service.syncNow());
        expect(h.server.pullRequests, [0, 2, 4, 6, 8, cursor]);
        expect(customer(h)?.name, 'Muster GmbH');
        expect(catchUpPending(h), isFalse);
        expect(h.state().pullCursor, cursor);
        expect(h.state().lastError, isNull);
        expect(colaName(h), 'Tablet-Cola');
        expect(h.counts().pending, 0);

        // Danach kein Nachholen mehr.
        h.server.pullRequests.clear();
        h.run(h.service.syncNow());
        expect(h.server.pullRequests, [cursor]);
        h.close();
      });
    });

    test('ohne catchUpPending kein Nachholen; neue Kunden kommen beim '
        'normalen Holen', () {
      fakeAsync((async) {
        final h = Harness(async);
        final cursor = h.state().pullCursor;
        h.server.upsert('customers', muster);
        h.run(h.service.syncNow());
        expect(h.server.pullRequests, [cursor]);
        expect(customer(h)?.name, 'Muster GmbH');
        h.close();
      });
    });

    test('customer und recipient gehen hinauf; abgelehnt ohne Bericht mit '
        'Name, Adresse oder UID; eine unbekannte Art wird einmal gemeldet und '
        'hält die anderen nicht auf', () {
      fakeAsync((async) {
        final h = Harness(async);
        final repo = CustomerRepository(h.db, FixedClock(start));
        final saved = h.run(
          repo.save(
            name: 'Geheim GmbH',
            addressLine1: 'Geheimweg 7',
            addressLine2: '1010 Wien',
            vatId: 'ATU99999999',
          ),
        );
        h.run(
          h.db
              .into(h.db.receiptRecipientRows)
              .insert(
                ReceiptRecipientRowsCompanion.insert(
                  receiptId: 'r1',
                  version: 0,
                  name: 'Geheim GmbH',
                  addressLine1: 'Geheimweg 7',
                  addressLine2: '1010 Wien',
                  vatId: const Value('ATU99999999'),
                  createdAt: start,
                  staffId: 'chefin',
                  staffName: 'Chefin',
                ),
              ),
        );
        h.run(
          h.db.customStatement(
            "INSERT INTO outbox (kind, ref) VALUES ('recipient', 'r1/0')",
          ),
        );
        h.run(
          h.db.customStatement(
            "INSERT INTO outbox (kind, ref) VALUES ('unbekannt', 'x')",
          ),
        );
        h.addDay('a');
        final ids = {
          for (final r in h.run(
            h.db.customSelect('SELECT id, kind FROM outbox').get(),
          ))
            r.read<String>('kind'): r.read<int>('id'),
        };
        h.server.pushStatuses[ids['customer']!] = 'rejected';
        h.server.pushStatuses[ids['recipient']!] = 'rejected';

        h.run(h.service.syncNow());
        final first = h.server.pushRequests.first;
        expect([for (final e in first) e['kind']], [
          'customer',
          'recipient',
          'day',
        ]);
        expect(first[0], {
          'seq': ids['customer'],
          'kind': 'customer',
          'id': saved.id,
          'name': 'Geheim GmbH',
          'addressLine1': 'Geheimweg 7',
          'addressLine2': '1010 Wien',
          'vatId': 'ATU99999999',
          'archived': false,
          'updatedAt': start.toUtc().toIso8601String(),
        });
        expect(first[1]['receiptId'], 'r1');
        expect(first[1]['version'], 0);
        final counts = h.counts();
        // customer und recipient abgelehnt vom Server, die unbekannte Art am
        // Tablet; der Tag ist angekommen.
        expect((counts.pending, counts.rejected), (0, 3));

        final reports = h.run(h.db.select(h.db.reportRows).get());
        expect(reports, hasLength(1));
        expect(jsonDecode(reports.single.content), {
          'type': 'OutboxBuildError',
          'message': 'Eintrag unbekannt: ArgumentError',
          'stack': '',
        });
        for (final word in ['Geheim', 'ATU99999999', '1010 Wien']) {
          expect(reports.single.content, isNot(contains(word)));
        }

        // Ein zweiter Lauf meldet nichts Neues und sendet nichts davon
        // noch einmal.
        final pushes = h.server.pushRequests.length;
        h.run(h.service.syncNow());
        expect(h.run(h.db.select(h.db.reportRows).get()), hasLength(1));
        expect(
          [
            for (final r in h.server.pushRequests.skip(pushes))
              for (final e in r) e['kind'],
          ],
          everyElement('report'),
        );
        h.close();
      });
    });
  });
}
