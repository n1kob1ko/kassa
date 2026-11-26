import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:kassa/data/database.dart';
import 'package:kassa/data/outbox_repository.dart';
import 'package:kassa/sync/push_wire.dart';

import 'generated_migrations/schema.dart';
import 'migration_test.dart' show copyFixture, count;

/// Version 6 (Teil C2) nach Version 5 (1.5.0, Spalte `unit`). Die Datei
/// `kassa_v5.sqlite` entsteht mit `tool/make_kassa_v5_fixture.dart` aus dem
/// Abzug von Version 5.
void main() {
  Future<int> userVersion(KassaDatabase db) async =>
      (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
        'user_version',
      );

  /// (Art, Kennung) ohne Artikel-Änderungen, in der Reihenfolge der Liste.
  Future<List<(String, String)>> outboxList(KassaDatabase db) async => [
    for (final r
        in await db
            .customSelect(
              "SELECT kind, ref FROM outbox WHERE kind <> 'item_change' "
              'ORDER BY id',
            )
            .get())
      (r.read<String>('kind'), r.read<String>('ref')),
  ];

  Future<List<String>> outboxTriggers(KassaDatabase db) async => [
    for (final r
        in await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'trigger' "
              "AND name LIKE 'outbox_%' ORDER BY name",
            )
            .get())
      r.read<String>('name'),
  ];

  const triggers = [
    'outbox_business_days_insert',
    'outbox_business_days_update',
    'outbox_cash_movements_insert',
    'outbox_receipts_insert',
    'outbox_reports_insert',
    'outbox_reports_update',
    'outbox_rksv_certificates_insert',
    'outbox_rksv_chains_insert',
    'outbox_rksv_chains_update',
    'outbox_rksv_entries_insert',
  ];

  String receiptId(int n) => 'v5-${n.toString().padLeft(4, '0')}';

  test('Schema: Version 5 wird zu Version 6', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final connection = await verifier.startAt(5);
    final db = KassaDatabase(connection);
    await verifier.migrateAndValidate(db, 6);
    await db.close();
  });

  test('Schema: Version 4 wird zu Version 6 (Schritt 5, dann 6)', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final connection = await verifier.startAt(4);
    final db = KassaDatabase(connection);
    await verifier.migrateAndValidate(db, 6);
    await db.close();
  });

  test('Update von 1.5.0: Schritt 6 läuft, alle Bons, Tage, Bewegungen, '
      'Ketten und Einträge stehen in der richtigen Reihenfolge in der Liste, '
      'unit bleibt erhalten', () async {
    final before = DateTime.now().subtract(const Duration(seconds: 2));
    final db = KassaDatabase(
      NativeDatabase(await copyFixture('kassa_v5.sqlite')),
    );
    addTearDown(db.close);
    expect(await userVersion(db), 7);

    // Nichts ging verloren.
    expect(await count(db, 'receipts'), 305);
    expect(await count(db, 'receipt_lines'), 600);
    expect(await count(db, 'receipt_line_options'), 326);
    expect(await count(db, 'payments'), 300);
    expect(await count(db, 'business_days'), 5);
    expect(await count(db, 'cash_movements'), 5);
    expect(await count(db, 'rksv_certificates'), 3);
    expect(await count(db, 'rksv_entries'), 294);
    expect(await count(db, 'reports'), 0);

    final chains = await (db.select(
      db.rksvChainRows,
    )..orderBy([(t) => OrderingTerm.asc(t.chain)])).get();
    expect(
      chains.map((c) => (c.chain, c.mode, c.unit, c.zdaId, c.endedAt != null)),
      [
        (1, 'probe', 'probe', 'AT100', true),
        (2, 'probe', 'atrustTest', 'AT1', true),
        (3, 'probe', 'probe', 'AT100', false),
      ],
    );
    final state = await db.select(db.rksvStateRows).getSingle();
    expect((state.mode, state.chain, state.counterCents), ('probe', 3, 216090));

    // Die Liste: Zertifikate, Ketten, Tage, Bewegungen, Bons nach Nummer.
    expect(await outboxList(db), [
      ('rksv_certificate', 'c0ffee01'),
      ('rksv_certificate', '7e570002'),
      ('rksv_certificate', 'c0ffee03'),
      ('rksv_chain', '1'),
      ('rksv_chain', '2'),
      ('rksv_chain', '3'),
      for (var d = 1; d <= 5; d++) ('day', 'day-$d'),
      for (var m = 1; m <= 5; m++) ('cash_movement', 'move-$m'),
      for (var n = 1; n <= 305; n++) ('receipt', receiptId(n)),
    ]);
    final states = await db
        .customSelect('SELECT DISTINCT state, rev FROM outbox')
        .get();
    expect(states.map((r) => (r.read<String>('state'), r.read<int>('rev'))), [
      ('pending', 0),
    ]);
    // Jeder Eintrag im Protokoll geht mit seinem Bon.
    final orphans = await db
        .customSelect(
          'SELECT COUNT(*) c FROM rksv_entries e WHERE NOT EXISTS (SELECT 1 '
          "FROM outbox o WHERE o.kind = 'receipt' AND o.ref = e.receipt_id)",
        )
        .getSingle();
    expect(orphans.read<int>('c'), 0);

    // Gekoppelt: die Werte vom Tablet kommen als Artikel-Änderungen nach den
    // Bons, und die Artikel selbst bleiben, wie sie sind.
    final changes = await db
        .customSelect(
          'SELECT ref, field, value, changed_at FROM outbox '
          "WHERE kind = 'item_change' ORDER BY id",
        )
        .get();
    expect(changes, hasLength(30));
    final byKey = {
      for (final r in changes)
        '${r.read<String>('ref')}/${r.read<String>('field')}': r.read<String>(
          'value',
        ),
    };
    expect(byKey['huhn-bowl/priceCents'], '1090');
    expect(byKey['cola/priceCents'], '320');
    expect(byKey['cola/depositCents'], '25');
    expect(byKey['cola/favorite'], 'true');
    expect(byKey['teigtaschen/inSale'], 'false');
    expect(byKey['tofu-bowl/tags'], '["vegan"]');
    // Der stillgelegte Artikel bekommt keine Änderung (der Server kennt ihn
    // nicht, sie käme als unknown_item zurück).
    expect(
      changes.map((r) => r.read<String>('ref')),
      isNot(contains('kuerbissuppe')),
    );
    final at = DateTime.fromMillisecondsSinceEpoch(
      changes.first.read<int>('changed_at') * 1000,
    );
    expect(at.isAfter(before), isTrue);
    final last = await db
        .customSelect('SELECT kind FROM outbox ORDER BY id DESC LIMIT 1')
        .getSingle();
    expect(last.read<String>('kind'), 'item_change');
    final prices = await (db.select(
      db.itemRows,
    )..orderBy([(t) => OrderingTerm.asc(t.position)])).get();
    expect(prices.map((i) => (i.id, i.priceCents, i.inSale)), [
      ('huhn-bowl', 1090, true),
      ('tofu-bowl', 950, true),
      ('teigtaschen', 650, false),
      ('pommes', 390, true),
      ('cola', 320, true),
      ('limonade', 290, true),
      ('kuerbissuppe', 590, true),
    ]);

    // Trigger der Liste und der Unveränderlichkeit stehen.
    expect(await outboxTriggers(db), triggers);
    for (final sql in const [
      'UPDATE receipts SET total_cents = 1',
      "UPDATE rksv_entries SET jws = 'x'",
      'DELETE FROM rksv_certificates',
      "UPDATE rksv_chains SET unit = 'probe' WHERE chain = 2",
      'DELETE FROM rksv_chains',
      'DELETE FROM cash_movements',
      "UPDATE business_days SET opening_float_cents = 1 WHERE id = 'day-1'",
    ]) {
      await expectLater(
        db.customStatement(sql),
        throwsA(isA<SqliteException>()),
        reason: sql,
      );
    }
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);

    // Die Kette atrustTest geht wie eine Probe-Kette, ohne `unit`.
    final entries = await OutboxRepository(db).nextBatch(limit: 6);
    final payloads = PushPayloads(db);
    final chain2 = await payloads.build(entries[4]);
    expect(chain2!['kind'], 'rksv_chain');
    expect(chain2['chain'], {
      'chain': 2,
      'mode': 'probe',
      'cashBoxId': 'ONLINETST2',
      'zdaId': 'AT1',
      'certSerial': '7e570002',
      'startedAt': '2026-11-12T06:58:00.000Z',
      'endedAt': '2026-11-12T19:00:00.000Z',
    });
  });

  test('Update von 1.5.0 ist ganz oder gar nicht: scheitert Schritt 6, '
      'bleibt die Datei auf Version 5 und läuft danach durch', () async {
    final file = await copyFixture('kassa_v5.sqlite');
    final broken = NativeDatabase(
      file,
      setup: (raw) => raw.execute(
        'CREATE TRIGGER outbox_reports_update AFTER UPDATE ON items '
        'BEGIN SELECT 1; END',
      ),
    );
    final first = KassaDatabase(broken);
    await expectLater(
      first.select(first.syncStateRows).get(),
      throwsA(anything),
    );
    await first.close();

    final raw = sqlite.sqlite3.open(file.path);
    expect(raw.select('PRAGMA user_version').single.values.single, 5);
    expect([
      for (final r in raw.select('PRAGMA table_info(items)')) r['name'],
    ], isNot(contains('photo_file_id')));
    expect(
      raw.select("SELECT name FROM sqlite_master WHERE name = 'outbox'"),
      isEmpty,
    );
    raw.execute('DROP TRIGGER outbox_reports_update');
    raw.close();

    final db = KassaDatabase(NativeDatabase(file));
    addTearDown(db.close);
    expect(await count(db, 'receipts'), 305);
    expect(await count(db, 'outbox'), 3 + 3 + 5 + 5 + 305 + 30);
    expect(await userVersion(db), 7);
    expect((await db.select(db.rksvChainRows).get()).map((c) => c.unit), [
      'probe',
      'atrustTest',
      'probe',
    ]);
  });

  // Drift schreibt user_version nach onUpgrade ohne Transaktion darum. Wurde
  // die App beim Update auf 1.5.0 zwischen ADD COLUMN und diesem Schreiben
  // beendet, hat die Datei die Spalte schon und steht noch auf Version 4.
  test('halb fertiger Schritt 5 (unit da, Version 4): erreicht Version 6, '
      'die Liste ist voll', () async {
    final file = await copyFixture('kassa_v4.sqlite');
    final db = KassaDatabase(
      NativeDatabase(
        file,
        setup: (raw) {
          if (raw.userVersion == 4) {
            raw.execute(
              'ALTER TABLE rksv_chains ADD COLUMN '
              "unit TEXT NOT NULL DEFAULT 'probe'",
            );
          }
        },
      ),
    );
    addTearDown(db.close);

    expect(await userVersion(db), 7);
    final chains = await (db.select(
      db.rksvChainRows,
    )..orderBy([(t) => OrderingTerm.asc(t.chain)])).get();
    expect(chains.map((c) => (c.chain, c.unit)), [(1, 'probe'), (2, 'probe')]);
    final receipts = await (db.select(
      db.receiptRows,
    )..orderBy([(t) => OrderingTerm.asc(t.number)])).get();
    final certificates = await db
        .customSelect('SELECT serial_hex FROM rksv_certificates ORDER BY rowid')
        .get();
    final day = await db.select(db.businessDayRows).getSingle();
    expect(await outboxList(db), [
      for (final c in certificates)
        ('rksv_certificate', c.read<String>('serial_hex')),
      ('rksv_chain', '1'),
      ('rksv_chain', '2'),
      ('day', day.id),
      for (final r in receipts) ('receipt', r.id),
    ]);
    expect(await outboxTriggers(db), triggers);
    expect(await count(db, 'rksv_entries'), 5);
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
  });

  // Schritt 6 ist eine Transaktion, aber drift schreibt user_version erst
  // danach und ohne Transaktion darum. Wurde die App genau dazwischen
  // beendet, ist Schritt 6 fertig und die Datei steht noch auf der alten
  // Version. Der nächste Start darf ihn nicht noch einmal versuchen.
  Future<void> rewindVersion(File file, int version) async {
    final raw = sqlite.sqlite3.open(file.path);
    raw.execute('PRAGMA user_version = $version');
    raw.close();
  }

  for (final (fixture, version) in const [
    ('kassa_v5.sqlite', 5),
    ('kassa_v4.sqlite', 4),
  ]) {
    test('Schritt 6 fertig, Version noch $version ($fixture): die Kassa '
        'öffnet auf Version 6, die Liste ist nicht doppelt', () async {
      final file = await copyFixture(fixture);
      final first = KassaDatabase(NativeDatabase(file));
      expect(await userVersion(first), 7);
      final listed = await count(first, 'outbox');
      final receipts = await count(first, 'receipts');
      await first.close();
      await rewindVersion(file, version);

      final db = KassaDatabase(NativeDatabase(file));
      addTearDown(db.close);
      expect(await db.select(db.syncStateRows).get(), isNotNull);
      expect(await userVersion(db), 7);
      expect(await count(db, 'outbox'), listed);
      expect(await count(db, 'receipts'), receipts);
      expect(await outboxTriggers(db), triggers);
      expect(listed, greaterThan(0));
    });
  }

  /// Der Plan des UPDATE jedes Triggers der Liste, wie er in der Datei steht
  /// (`NEW.<Spalte>` durch einen festen Wert ersetzt).
  Future<Map<String, String>> updatePlans(KassaDatabase db) async {
    final plans = <String, String>{};
    for (final r
        in await db
            .customSelect(
              "SELECT name, sql FROM sqlite_master WHERE type = 'trigger' "
              "AND name LIKE 'outbox_%'",
            )
            .get()) {
      final sql = r.read<String>('sql');
      final update = RegExp(r'UPDATE outbox [^;]*').firstMatch(sql)!.group(0)!;
      final plan = await db
          .customSelect(
            'EXPLAIN QUERY PLAN '
            "${update.replaceAll(RegExp(r'NEW\.\w+'), "'x'")}",
          )
          .get();
      plans[r.read<String>('name')] = plan
          .map((p) => p.read<String>('detail'))
          .join('; ');
    }
    return plans;
  }

  test('das UPDATE der Trigger nimmt den Index outbox_entity, neu und nach '
      'dem Update von 1.5.0', () async {
    final fresh = KassaDatabase(NativeDatabase.memory());
    addTearDown(fresh.close);
    final migrated = KassaDatabase(
      NativeDatabase(await copyFixture('kassa_v5.sqlite')),
    );
    addTearDown(migrated.close);
    for (final db in [fresh, migrated]) {
      final plans = await updatePlans(db);
      expect(plans.keys.toSet(), triggers.toSet());
      for (final MapEntry(:key, :value) in plans.entries) {
        expect(
          value,
          contains('SEARCH outbox USING INDEX outbox_entity'),
          reason: key,
        );
      }
    }
  });

  test('neue Datenbank: Version 6 mit Liste, Index und Triggern', () async {
    final db = KassaDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(await userVersion(db), 7);
    expect(await outboxTriggers(db), triggers);
    expect(await count(db, 'outbox'), 0);
    final columns = [
      for (final r
          in await db.customSelect('PRAGMA table_info(rksv_chains)').get())
        r.read<String>('name'),
    ];
    expect(columns, contains('unit'));
  });
}
