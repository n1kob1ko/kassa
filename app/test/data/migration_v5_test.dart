import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/rksv_repository.dart';
import 'package:kassa/rksv/rksv_state.dart';

import 'generated_migrations/schema.dart';
import 'migration_test.dart' show copyFixture, count;

void main() {
  test('Schema: Version 4 wird zu Version 5', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final connection = await verifier.startAt(4);
    final db = KassaDatabase(connection);
    await verifier.migrateAndValidate(db, 5);
    await db.close();
  });

  // kassa_v4.sqlite: Probe-Kette 1 (Startbeleg, Verkauf, Schlussbeleg,
  // beendet um 14:00) und laufende Probe-Kette 2 (Startbeleg, Verkauf).
  test('echte Datei von Version 4: beide Probe-Ketten haben die Einheit '
      'probe; Einträge, Stand und Trigger bleiben', () async {
    final file = await copyFixture('kassa_v4.sqlite');
    final db = KassaDatabase(NativeDatabase(file));

    final chains = await (db.select(
      db.rksvChainRows,
    )..orderBy([(t) => OrderingTerm.asc(t.chain)])).get();
    expect(chains.map((c) => (c.chain, c.mode, c.unit, c.zdaId, c.endedAt)), [
      (1, 'probe', 'probe', 'AT100', DateTime(2026, 11, 18, 14)),
      (2, 'probe', 'probe', 'AT100', null),
    ]);
    expect(
      (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
        'user_version',
      ),
      db.schemaVersion,
    );

    final entries =
        await (db.select(db.rksvEntryRows)..orderBy([
              (t) => OrderingTerm.asc(t.chain),
              (t) => OrderingTerm.asc(t.position),
            ]))
            .get();
    expect(entries.map((e) => (e.chain, e.position, e.damaged)), [
      (1, 1, false),
      (1, 2, false),
      (1, 3, false),
      (2, 1, false),
      (2, 2, false),
    ]);
    expect(
      (entries[1].receiptId, entries[4].receiptId),
      ('v4-bar', 'v4-zweit'),
    );
    for (final e in entries) {
      expect(e.certSerial, chains[e.chain - 1].certSerial);
      expect(e.jws.split('.'), hasLength(3));
    }
    expect(await count(db, 'rksv_certificates'), 2);
    expect(await count(db, 'receipts'), 5);

    final state = await db.select(db.rksvStateRows).getSingle();
    expect(
      (state.mode, state.chain, state.counterCents, state.outageSince),
      ('probe', 2, 1820, null),
    );
    expect(
      [for (final t in decodeRksvTasks(state.tasks)) t.id],
      ['check-start-2'],
    );
    final rksv = await RksvRepository(db).current();
    expect((rksv.chain, rksv.unit), (2, RksvUnit.probe));

    for (final sql in const [
      "UPDATE rksv_entries SET jws = 'x'",
      'DELETE FROM rksv_entries',
      "UPDATE rksv_certificates SET issuers = '[\"x\"]'",
      'DELETE FROM rksv_certificates',
      "UPDATE rksv_chains SET unit = 'atrustTest' WHERE chain = 1",
      'DELETE FROM rksv_chains',
      'UPDATE receipts SET total_cents = 1',
    ]) {
      await expectLater(
        db.customStatement(sql),
        throwsA(isA<SqliteException>()),
        reason: sql,
      );
    }
    expect(await count(db, 'rksv_entries'), 5);
    expect(await count(db, 'rksv_chains'), 2);
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    await db.close();
  });

  // Drift schreibt user_version nach onUpgrade ohne Transaktion darum. Wird
  // die App zwischen ADD COLUMN und diesem Schreiben beendet, hat die Datei
  // die Spalte schon und steht noch auf Version 4.
  test('Datei von Version 4, die die Spalte unit schon hat: öffnet, endet '
      'auf der aktuellen Version, Ketten und Einträge bleiben', () async {
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

    final chains = await (db.select(
      db.rksvChainRows,
    )..orderBy([(t) => OrderingTerm.asc(t.chain)])).get();
    expect(chains.map((c) => (c.chain, c.mode, c.unit, c.endedAt)), [
      (1, 'probe', 'probe', DateTime(2026, 11, 18, 14)),
      (2, 'probe', 'probe', null),
    ]);
    expect(
      (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
        'user_version',
      ),
      db.schemaVersion,
    );
    expect(await count(db, 'rksv_entries'), 5);
    expect(await count(db, 'rksv_certificates'), 2);
    expect(await count(db, 'receipts'), 5);
    final state = await db.select(db.rksvStateRows).getSingle();
    expect((state.mode, state.chain, state.counterCents), ('probe', 2, 1820));
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
  });

  test(
    'neue Datenbank: eine Kette ohne Angabe hat die Einheit probe',
    () async {
      final db = KassaDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.customStatement(
        'INSERT INTO rksv_certificates (serial_hex, certificate) '
        "VALUES ('0a1b', x'3082')",
      );
      await db.customStatement(
        'INSERT INTO rksv_chains (chain, mode, cash_box_id, zda_id, '
        'cert_serial, started_at) '
        "VALUES (1, 'probe', 'ABCDEFGHJK', 'AT100', '0a1b', 1794913200)",
      );
      expect((await db.select(db.rksvChainRows).getSingle()).unit, 'probe');
    },
  );
}
