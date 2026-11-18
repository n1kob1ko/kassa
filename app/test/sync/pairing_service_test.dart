import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/app_sync_providers.dart';
import 'package:kassa/core/clock.dart';
import 'package:kassa/data/catalog_repository.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/data/settings_repository.dart';
import 'package:kassa/data/staff_repository.dart';
import 'package:kassa/data/sync_state_repository.dart';
import 'package:kassa/domain/staff.dart';
import 'package:kassa/features/kassa/cart_controller.dart';
import 'package:kassa/features/login/session.dart';
import 'package:kassa/sync/pairing_service.dart';
import 'package:kassa/sync/server_api.dart';
import 'package:kassa/sync/server_changes.dart';
import 'package:kassa/sync/sync_service.dart';
import 'package:kassa/sync/token_store.dart';

import '../support/demo_fixtures.dart';
import '../support/fake_server.dart';

final now = DateTime(2026, 11, 18, 10);

/// Ein Schlüssel-Speicher, der nach dem Schreiben noch etwas tun lässt.
class SpyTokenStore extends MemoryTokenStore {
  Future<void> Function()? afterWrite;

  @override
  Future<void> write(String token) async {
    await super.write(token);
    final hook = afterWrite;
    afterWrite = null;
    if (hook != null) await hook();
  }
}

/// Das Tablet mit Datenbank im Speicher, das über die Provider der App mit
/// dem [FakeServer] spricht.
class Tablet {
  Tablet._(this.db, this.server, this.tokens, this.container);

  static Future<Tablet> open({bool withMenu = true, int pageSize = 3}) async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final db = KassaDatabase(NativeDatabase.memory());
    if (withMenu) {
      await CatalogRepository(db).importCatalog(catalog);
      await StaffRepository(db)
          .create(name: 'Anna', pin: '1111', role: StaffRole.chef);
    }
    final server = FakeServer.beispiel(pageSize: pageSize);
    final tokens = SpyTokenStore();
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(FixedClock(now)),
        tokenStoreProvider.overrideWithValue(tokens),
        serverApiProvider.overrideWithValue(
          ServerApi(
            baseUrl: 'https://kassa.example',
            client: server,
            appVersion: '1.2.0',
          ),
        ),
      ],
    );
    addTearDown(() async {
      // Was der offene Bon noch liest, fertig werden lassen.
      await pumpEventQueue();
      container.dispose();
      await db.close();
    });
    return Tablet._(db, server, tokens, container);
  }

  final KassaDatabase db;
  final FakeServer server;
  final SpyTokenStore tokens;
  final ProviderContainer container;

  PairingService get pairing => container.read(pairingServiceProvider);

  Future<SyncState> state() => SyncStateRepository(db).current();

  /// Ein Abgleich wie im Hintergrund, auf denselben Daten.
  SyncService syncService() => SyncService(
    api: container.read(serverApiProvider),
    tokens: tokens,
    syncState: SyncStateRepository(db),
    changes: ServerChanges(db),
    clock: FixedClock(now),
  );

  /// Alles, was das Koppeln und Laden nicht halb ändern darf.
  Future<List<Object>> menu() async => [
    await db.select(db.businessRows).get(),
    await db.select(db.categoryRows).get(),
    await db.select(db.itemRows).get(),
    await db.select(db.modifierTemplateRows).get(),
    await db.select(db.modifierGroupRows).get(),
    await db.select(db.modifierOptionRows).get(),
    await db.select(db.staffRows).get(),
    await db.select(db.settingsRows).get(),
  ];
}

Future<ServerFailure> failureOf(Future<Object?> call) async {
  try {
    await call;
  } on ServerException catch (e) {
    return e.failure;
  }
  fail('Es wurde keine ServerException geworfen.');
}

void main() {
  test(
    'pair legt Schlüssel und Kassa ab, die Speisekarte ist noch die alte',
    () async {
      final t = await Tablet.open();
      final before = await t.menu();

      final r = await t.pairing.pair(FakeServer.code);

      expect(r.registerName, 'Kassa 1');
      expect(await t.tokens.read(), FakeServer.token);
      final s = await t.state();
      expect(s.registerId, FakeServer.registerId);
      expect(s.registerName, 'Kassa 1');
      expect(s.businessId, FakeServer.businessId);
      expect(s.initialPullDone, isFalse);
      expect(s.paired, isFalse);
      expect(await t.menu(), before);
      expect(t.server.pullRequests, isEmpty);
      // Der Schlüssel steht nirgends in der Datenbank.
      final rows = await t.db.customSelect('SELECT * FROM sync_state').get();
      expect(
        rows.single.data.values.join(' '),
        isNot(contains(FakeServer.token)),
      );
    },
  );

  test(
    'falscher Code: ServerException invalidCode, nichts gespeichert',
    () async {
      final t = await Tablet.open();
      expect(
        await failureOf(t.pairing.pair('11111111')),
        ServerFailure.invalidCode,
      );
      expect(await t.tokens.read(), isNull);
      expect((await t.state()).hasRegister, isFalse);
    },
  );

  test('loadInitial holt alle Seiten und meldet ab', () async {
    final t = await Tablet.open(withMenu: false);
    expect(await t.container.read(setupCompleteProvider.future), isFalse);
    await t.pairing.pair(FakeServer.code);
    // Anmelden geht hier nur mit einer Person am Tablet.
    await StaffRepository(t.db)
        .create(name: 'Anna', pin: '1111', role: StaffRole.chef);
    expect(
      await t.container.read(sessionProvider.notifier).login('1111'),
      isTrue,
    );

    await t.pairing.loadInitial();

    expect(t.server.pullRequests, [0, 3, 6]);
    expect(t.container.read(sessionProvider), isNull);
    final s = await t.state();
    expect(s.paired, isTrue);
    expect(s.pullCursor, t.server.seq);
    expect(s.lastPullAt, now);
    final c = (await CatalogRepository(t.db).current())!;
    expect(c.items.map((i) => i.id), ['huhn-bowl', 'teigtaschen', 'cola']);
    // Die Einrichtung gilt danach als fertig, ohne dass jemand neu lädt.
    expect(await t.container.read(setupCompleteProvider.future), isTrue);
    expect(
      await t.container.read(sessionProvider.notifier).login('1234'),
      isTrue,
    );
  });

  test('Internet bricht nach Seite 1 ab: alte Speisekarte vollständig, loadInitial nochmal ohne neuen Code gelingt', () async {
    final t = await Tablet.open();
    await t.pairing.pair(FakeServer.code);
    final before = await t.menu();
    t.server.breakAfterPages = 1;

    expect(await failureOf(t.pairing.loadInitial()), ServerFailure.offline);
    expect(await t.menu(), before);
    expect((await t.state()).paired, isFalse);
    expect((await t.state()).pullCursor, 0);

    t.server.breakAfterPages = null;
    await t.pairing.loadInitial();

    expect(t.server.pairRequests, hasLength(1));
    expect(t.server.pullRequests, [0, 3, 0, 3, 6]);
    expect((await t.state()).paired, isTrue);
    final c = (await CatalogRepository(t.db).current())!;
    expect(c.items.map((i) => i.id), ['huhn-bowl', 'teigtaschen', 'cola']);
  });

  test(
    'loadInitial ohne Schlüssel: unauthorized, der Server wird nicht gefragt',
    () async {
      final t = await Tablet.open();
      await t.pairing.pair(FakeServer.code);
      await t.tokens.clear();
      expect(
        await failureOf(t.pairing.loadInitial()),
        ServerFailure.unauthorized,
      );
      expect(t.server.pullRequests, isEmpty);
    },
  );

  test(
    'zweites Koppeln sendet die Kennung des bisherigen Betriebs mit',
    () async {
      final t = await Tablet.open();
      await t.pairing.pair(FakeServer.code);
      await t.pairing.loadInitial();
      await t.pairing.pair(FakeServer.code);

      expect(t.server.pairRequests[0]['previousBusinessId'], isNull);
      expect(
        t.server.pairRequests[1]['previousBusinessId'],
        FakeServer.businessId,
      );
      expect(t.server.pairRequests[1]['appVersion'], '1.2.0');
    },
  );

  test('pair legt zuerst die Kassa ab, dann den Schlüssel: ein Lauf dazwischen holt nichts', () async {
    final t = await Tablet.open();
    await t.pairing.pair(FakeServer.code);
    await t.pairing.loadInitial();
    final pulls = t.server.pullRequests.length;
    SyncState? seenAtWrite;
    t.tokens.afterWrite = () async {
      seenAtWrite = await t.state();
      await t.syncService().syncNow();
    };

    await t.pairing.pair(FakeServer.code);

    expect(seenAtWrite!.paired, isFalse, reason: 'Kassa vor dem Schlüssel');
    expect(seenAtWrite!.pullCursor, 0);
    expect(t.server.pullRequests, hasLength(pulls));
    expect(await t.tokens.read(), FakeServer.token);
  });

  test(
    'nach loadInitial ist auch ein offener Bon in der laufenden App leer',
    () async {
      final t = await Tablet.open();
      await t.pairing.pair(FakeServer.code);
      // Der Bon lebt, wie an der Kassa, und folgt dem Katalog.
      final sub = t.container.listen(cartProvider, (_, _) {});
      addTearDown(sub.close);
      t.container.listen(catalogStreamProvider, (_, _) {});
      await t.container.read(catalogStreamProvider.future);
      t.container.read(cartProvider.notifier).add(cola);
      await pumpEventQueue();
      expect(await SettingsRepository(t.db).readDraft(), isNotNull);

      await t.pairing.loadInitial();
      await pumpEventQueue();

      expect(t.container.read(cartProvider).isEmpty, isTrue);
      expect(await SettingsRepository(t.db).readDraft(), isNull);
    },
  );
}
