import 'dart:io';

import 'package:drift/backends.dart';
import 'package:drift/drift.dart' show OpeningDetails, OrderingTerm;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/settings_repository.dart';
import 'package:kassa/data/sync_state_repository.dart';

import 'generated_migrations/schema.dart';

/// Kopie der Datei in ein Temp-Verzeichnis, damit die eingecheckte Datei
/// nie verändert wird.
Future<File> copyFixture(String name) async {
  final dir = await Directory.systemTemp.createTemp('kassa_fixture');
  addTearDown(() => dir.delete(recursive: true));
  return File('test/data/fixtures/$name').copy('${dir.path}/$name');
}

Future<int> count(KassaDatabase db, String table) async =>
    (await db.customSelect('SELECT COUNT(*) c FROM $table').getSingle())
        .read<int>('c');

void main() {
  test('Schema: Version 1 wird zu Version 2', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final connection = await verifier.startAt(1);
    final db = KassaDatabase(connection);
    await verifier.migrateAndValidate(db, 2);
    await db.close();
  });

  test(
    'echte Datei von Version 1: Daten, Trigger und Einstellungen bleiben',
    () async {
      final file = await copyFixture('kassa_v1.sqlite');
      final db = KassaDatabase(NativeDatabase(file));
      final settings = await SettingsRepository(db).current();
      expect(settings.cashDrawerEnabled, isFalse);
      expect(settings.themeMode, AppThemeMode.dark);
      expect(settings.printerKind, PrinterKind.none);
      expect(settings.printerColumns, 48);
      final receipts = await db.select(db.receiptRows).get();
      expect(receipts, hasLength(1));
      final payment = await db.select(db.paymentRows).getSingle();
      expect(payment.provider, isNull);
      await expectLater(
        db.customStatement('UPDATE receipts SET total_cents = 1'),
        throwsA(isA<SqliteException>()),
      );
      await expectLater(
        db.customStatement('DELETE FROM payments'),
        throwsA(isA<SqliteException>()),
      );
      expect(await db.select(db.pendingCardPaymentRows).get(), isEmpty);
      await db.close();
    },
  );

  test('Schema: Version 2 wird zu Version 3', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final connection = await verifier.startAt(2);
    final db = KassaDatabase(connection);
    await verifier.migrateAndValidate(db, 3);
    await db.close();
  });

  test('echte Datei von Version 2: Bon, Chefin und Drucker bleiben, SyncState ist leer und nicht gekoppelt', () async {
    final file = await copyFixture('kassa_v2.sqlite');
    final db = KassaDatabase(NativeDatabase(file));
    final settings = await SettingsRepository(db).current();
    expect(settings.cashDrawerEnabled, isFalse);
    expect(settings.themeMode, AppThemeMode.dark);
    expect(settings.printerKind, PrinterKind.network);
    expect(settings.printerAddress, '192.168.1.50:9100');
    expect(settings.printerName, 'Bondrucker');
    expect(settings.printerColumns, 42);
    final receipts = await db.select(db.receiptRows).get();
    expect(receipts, hasLength(1));
    expect(receipts.single.totalCents, 2 * 290 + 2 * 25);
    final staff = await db.select(db.staffRows).get();
    expect(staff.map((s) => s.name), ['Chefin']);
    expect(staff.single.role, 'chef');
    final business = await db.select(db.businessRows).getSingle();
    expect(business.name, 'Beispiel-Imbiss');

    final sync = await SyncStateRepository(db).current();
    expect(sync.hasRegister, isFalse);
    expect(sync.paired, isFalse);
    expect(sync.pullCursor, 0);
    expect(sync.initialPullDone, isFalse);
    expect(sync.blocked, isFalse);
    await db.close();
  });

  test('Trigger gegen das Ändern von Bons gelten nach der Migration', () async {
    final file = await copyFixture('kassa_v2.sqlite');
    final db = KassaDatabase(NativeDatabase(file));
    await db.select(db.syncStateRows).get(); // löst die Migration aus
    for (final sql in const [
      'UPDATE receipts SET total_cents = 1',
      'DELETE FROM receipts',
      'UPDATE payments SET amount_cents = 1',
      'DELETE FROM payments',
      'UPDATE receipt_lines SET quantity = 9',
      'DELETE FROM receipt_lines',
    ]) {
      await expectLater(
        db.customStatement(sql),
        throwsA(isA<SqliteException>()),
        reason: sql,
      );
    }
    await db.close();
  });

  test('Schema: Version 3 wird zu Version 4', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final connection = await verifier.startAt(3);
    final db = KassaDatabase(connection);
    await verifier.migrateAndValidate(db, 4);
    await db.close();
  });

  test('echte Datei von Version 3: Bons, Zeilen, Zahlungen und Storno bleiben; '
      'UPDATE und DELETE auf receipts scheitern weiter; ein Bon ohne Tag lässt '
      'sich einfügen; rksv_state hat genau eine Zeile mit mode off', () async {
    final file = await copyFixture('kassa_v3.sqlite');
    final db = KassaDatabase(NativeDatabase(file));

    final receipts = await (db.select(
      db.receiptRows,
    )..orderBy([(t) => OrderingTerm.asc(t.number)])).get();
    expect(
      receipts.map(
        (r) => (r.number, r.kind, r.totalCents, r.businessDayId != null),
      ),
      [
        (1, 'sale', 1820, true),
        (2, 'sale', 965, true),
        (3, 'voided', -965, true),
      ],
    );
    expect(receipts[2].voidsReceiptId, 'v3-karte');
    expect(await count(db, 'receipt_lines'), 6);
    expect(await count(db, 'receipt_line_options'), 2);
    final payments = await db.select(db.paymentRows).get();
    expect(payments.map((p) => (p.kind, p.amountCents)).toSet(), {
      ('cash', 1820),
      ('card', 965),
      ('card', -965),
    });
    expect(await count(db, 'business_days'), 1);

    final settings = await SettingsRepository(db).current();
    expect(settings.printerAddress, '192.168.1.50:9100');
    expect(settings.printerColumns, 42);
    expect(settings.printerQrAsImage, isFalse);

    for (final sql in const [
      'UPDATE receipts SET total_cents = 1',
      'DELETE FROM receipts',
      'UPDATE payments SET amount_cents = 1',
      'DELETE FROM receipt_lines',
    ]) {
      await expectLater(
        db.customStatement(sql),
        throwsA(isA<SqliteException>()),
        reason: sql,
      );
    }
    // Der eindeutige Index auf voids_receipt_id ist wieder da.
    await expectLater(
      db.customStatement(
        'INSERT INTO receipts (id, number, created_at, staff_id, staff_name, '
        "business_day_id, kind, voids_receipt_id, goods_cents, deposit_cents, "
        "total_cents) SELECT 'zweit-storno', 4, created_at, staff_id, "
        "staff_name, business_day_id, 'voided', 'v3-karte', -965, 0, -965 "
        "FROM receipts WHERE id = 'v3-karte'",
      ),
      throwsA(isA<SqliteException>()),
    );

    await db.customStatement(
      'INSERT INTO receipts (id, number, created_at, staff_id, staff_name, '
      'business_day_id, kind, goods_cents, deposit_cents, total_cents) '
      "VALUES ('start-1', 4, 1794913300, 'chefin', 'Chefin', NULL, "
      "'start', 0, 0, 0)",
    );
    final start = await (db.select(
      db.receiptRows,
    )..where((t) => t.id.equals('start-1'))).getSingle();
    expect((start.kind, start.businessDayId), ('start', null));

    final state = await db.select(db.rksvStateRows).get();
    expect(state.map((s) => (s.id, s.mode, s.chain, s.counterCents)), [
      (1, 'off', null, 0),
    ]);
    expect((state.single.tasks, state.single.notice), ('[]', null));
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    expect(
      (await db.customSelect('PRAGMA foreign_keys').getSingle()).read<bool>(
        'foreign_keys',
      ),
      isTrue,
    );
    await db.close();
  });

  test('echte Datei von Version 3 mit einem alten kaputten Verweis: die App '
      'öffnet in Version 4, Bons bleiben, die alte Zeile auch', () async {
    final file = await copyFixture('kassa_v3.sqlite');
    // Ein Artikel zeigt auf eine Kategorie, die es nicht gibt. Ohne
    // PRAGMA foreign_keys prüft SQLite das beim Einfügen nicht.
    final broken = NativeDatabase(
      file,
      setup: (raw) => raw.execute(
        'INSERT INTO items (id, name, price_cents, category_id, tax_percent, '
        "position) VALUES ('verwaist', 'Verwaist', 100, 'gibt-es-nicht', 10, "
        '99)',
      ),
    );
    await broken.ensureOpen(_NoUser());
    await broken.close();

    final db = KassaDatabase(NativeDatabase(file));
    expect(
      (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
        'user_version',
      ),
      5,
    );
    final receipts = await (db.select(
      db.receiptRows,
    )..orderBy([(t) => OrderingTerm.asc(t.number)])).get();
    expect(
      receipts.map(
        (r) => (r.number, r.kind, r.totalCents, r.businessDayId != null),
      ),
      [
        (1, 'sale', 1820, true),
        (2, 'sale', 965, true),
        (3, 'voided', -965, true),
      ],
    );
    expect(receipts[2].voidsReceiptId, 'v3-karte');
    expect(await count(db, 'receipt_lines'), 6);
    expect(await count(db, 'payments'), 3);
    final orphan = await db
        .customSelect("SELECT category_id FROM items WHERE id = 'verwaist'")
        .getSingle();
    expect(orphan.read<String>('category_id'), 'gibt-es-nicht');
    final violations = await db.customSelect('PRAGMA foreign_key_check').get();
    expect(violations.map((r) => r.data['table']), ['items']);
    await db.close();
  });

  for (final (name, open) in [
    ('neue Datenbank', () async => KassaDatabase(NativeDatabase.memory())),
    (
      'nach der Migration',
      () async =>
          KassaDatabase(NativeDatabase(await copyFixture('kassa_v3.sqlite'))),
    ),
  ]) {
    group('Protokoll-Tabellen ($name)', () {
      late KassaDatabase db;
      setUp(() async {
        db = await open();
        await db.customStatement(
          'INSERT INTO rksv_certificates (serial_hex, certificate) '
          "VALUES ('0a1b', x'3082')",
        );
        await db.customStatement(
          'INSERT INTO rksv_chains (chain, mode, cash_box_id, zda_id, '
          'cert_serial, started_at) '
          "VALUES (1, 'probe', 'ABCDEFGHJK', 'AT100', '0a1b', 1794913200)",
        );
        await db.customStatement(
          'INSERT INTO receipts (id, number, created_at, staff_id, '
          'staff_name, kind, goods_cents, deposit_cents, total_cents) '
          "VALUES ('start-x', 100, 1794913200, 'c', 'Chef', 'start', 0, 0, 0)",
        );
        await db.customStatement(
          'INSERT INTO rksv_entries (chain, position, receipt_id, jws, '
          "damaged, cert_serial) VALUES (1, 1, 'start-x', 'a.b.c', 0, '0a1b')",
        );
      });
      tearDown(() => db.close());

      test('rksv_entries: UPDATE und DELETE scheitern', () async {
        for (final sql in const [
          "UPDATE rksv_entries SET jws = 'x'",
          'DELETE FROM rksv_entries',
        ]) {
          await expectLater(
            db.customStatement(sql),
            throwsA(
              isA<SqliteException>().having(
                (e) => e.message,
                'message',
                contains('Das Protokoll ist unveränderlich'),
              ),
            ),
            reason: sql,
          );
        }
        expect(await count(db, 'rksv_entries'), 1);
      });

      test(
        'rksv_entries: receipt_id ist eindeutig und verweist auf receipts',
        () async {
          for (final sql in const [
            'INSERT INTO rksv_entries (chain, position, receipt_id, jws, '
                "damaged, cert_serial) VALUES (1, 2, 'start-x', 'a', 0, 's')",
            'INSERT INTO rksv_entries (chain, position, receipt_id, jws, '
                "damaged, cert_serial) VALUES (1, 2, 'gibt-es-nicht', 'a', 0, 's')",
            'INSERT INTO rksv_entries (chain, position, receipt_id, jws, '
                "damaged, cert_serial) VALUES (1, 1, 'start-x', 'a', 0, 's')",
          ]) {
            await expectLater(
              db.customStatement(sql),
              throwsA(isA<SqliteException>()),
              reason: sql,
            );
          }
        },
      );

      test(
        'rksv_chains: UPDATE nach ended_at scheitert, DELETE scheitert',
        () async {
          await db.customStatement(
            'UPDATE rksv_chains SET ended_at = 1794913300 WHERE chain = 1',
          );
          await expectLater(
            db.customStatement(
              'UPDATE rksv_chains SET ended_at = NULL WHERE chain = 1',
            ),
            throwsA(isA<SqliteException>()),
          );
          await expectLater(
            db.customStatement('DELETE FROM rksv_chains'),
            throwsA(isA<SqliteException>()),
          );
          final chain = await db.select(db.rksvChainRows).getSingle();
          expect(chain.endedAt, isNotNull);
        },
      );

      test('rksv_chains: cert_serial verweist auf rksv_certificates', () async {
        await expectLater(
          db.customStatement(
            'INSERT INTO rksv_chains (chain, mode, cash_box_id, zda_id, '
            'cert_serial, started_at) '
            "VALUES (2, 'probe', 'MNPQRSTUVW', 'AT100', 'ffff', 1794913200)",
          ),
          throwsA(isA<SqliteException>()),
        );
        expect(await count(db, 'rksv_chains'), 1);
      });

      test('rksv_chains: DELETE scheitert auch bei laufender Kette', () async {
        await expectLater(
          db.customStatement('DELETE FROM rksv_chains'),
          throwsA(isA<SqliteException>()),
        );
        expect(await count(db, 'rksv_chains'), 1);
      });

      test('rksv_certificates: UPDATE und DELETE scheitern', () async {
        for (final sql in const [
          "UPDATE rksv_certificates SET issuers = '[\"x\"]'",
          'DELETE FROM rksv_certificates',
        ]) {
          await expectLater(
            db.customStatement(sql),
            throwsA(isA<SqliteException>()),
            reason: sql,
          );
        }
        final cert = await db.select(db.rksvCertificateRows).getSingle();
        expect(cert.issuers, '[]');
      });

      test('rksv_state hat genau eine Zeile', () async {
        expect(await count(db, 'rksv_state'), 1);
      });
    });
  }

  test('Schema: Version 4 wird zu Version 5', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final connection = await verifier.startAt(4);
    final db = KassaDatabase(connection);
    await verifier.migrateAndValidate(db, 5);
    await db.close();
  });

  test('4 → 5: Schema stimmt, alle Daten da', () async {
    final db = KassaDatabase(NativeDatabase(await copyFixture('kassa_v4.sqlite')));
    expect(
      (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
        'user_version',
      ),
      5,
    );
    expect(await count(db, 'business_days'), 2);
    expect(await count(db, 'cash_movements'), 1);
    expect(await count(db, 'receipts'), 4);
    expect(await count(db, 'receipt_lines'), 3);
    expect(await count(db, 'payments'), 3);
    expect(await count(db, 'rksv_entries'), 3);
    expect(await count(db, 'rksv_chains'), 1);
    expect(await count(db, 'rksv_certificates'), 1);
    expect(await count(db, 'items'), 3);
    expect(await count(db, 'reports'), 0);
    final sync = await SyncStateRepository(db).current();
    expect(sync.registerId, 'test-register');
    expect(sync.pullCursor, 12);
    expect(sync.lastPushAt, isNull);
    final row = await db.select(db.syncStateRows).getSingle();
    expect((row.deviceId, row.photosAutoEnabled), (null, false));
    final item = await (db.select(
      db.itemRows,
    )..where((t) => t.id.equals('cola'))).getSingle();
    expect((item.photoFileId, item.photoColor), (null, null));
    final business = await db.select(db.businessRows).getSingle();
    expect(
      (business.logoFileId, business.logoPath, business.logoColor),
      (null, null, null),
    );
    final state = await db.select(db.rksvStateRows).getSingle();
    expect((state.mode, state.chain, state.counterCents), ('probe', 1, 1480));
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    final index = await db
        .customSelect(
          "SELECT sql FROM sqlite_master WHERE name = 'outbox_entity'",
        )
        .getSingle();
    expect(index.read<String>('sql'), contains("kind <> 'item_change'"));
    await db.close();
  });

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

  test('4 → 5: Vorhandenes steht in der Liste, in der Reihenfolge Zertifikat, '
      'Kette, Tage, Bewegung, Bons nach Nummer', () async {
    final db = KassaDatabase(NativeDatabase(await copyFixture('kassa_v4.sqlite')));
    expect(await outboxList(db), [
      ('rksv_certificate', '0a1b2c'),
      ('rksv_chain', '1'),
      ('day', 'day-1'),
      ('day', 'day-2'),
      ('cash_movement', 'move-1'),
      ('receipt', 'v4-bar'),
      ('receipt', 'v4-start'),
      ('receipt', 'v4-karte'),
      ('receipt', 'v4-storno'),
    ]);
    final states = await db
        .customSelect('SELECT DISTINCT state, rev FROM outbox')
        .get();
    expect(states.map((r) => (r.read<String>('state'), r.read<int>('rev'))), [
      ('pending', 0),
    ]);
    await db.close();
  });

  test('4 → 5 gekoppelt: 3 Artikel ergeben 15 Artikel-Änderungen', () async {
    final before = DateTime.now().subtract(const Duration(seconds: 2));
    final db = KassaDatabase(NativeDatabase(await copyFixture('kassa_v4.sqlite')));
    final rows = await db
        .customSelect(
          "SELECT ref, field, value, changed_at FROM outbox "
          "WHERE kind = 'item_change' ORDER BY id",
        )
        .get();
    expect(rows, hasLength(15));
    final byKey = {
      for (final r in rows)
        '${r.read<String>('ref')}/${r.read<String>('field')}': r.read<String>(
          'value',
        ),
    };
    expect(byKey, {
      'huhn-bowl/priceCents': '990',
      'huhn-bowl/inSale': 'true',
      'huhn-bowl/favorite': 'false',
      'huhn-bowl/depositCents': '0',
      'huhn-bowl/tags': '["spicy"]',
      'teigtaschen/priceCents': '650',
      'teigtaschen/inSale': 'false',
      'teigtaschen/favorite': 'false',
      'teigtaschen/depositCents': '0',
      'teigtaschen/tags': '[]',
      'cola/priceCents': '290',
      'cola/inSale': 'true',
      'cola/favorite': 'true',
      'cola/depositCents': '25',
      'cola/tags': '["vegan","spicy"]',
    });
    final at = await db
        .customSelect(
          "SELECT MIN(changed_at) lo FROM outbox WHERE kind = 'item_change'",
        )
        .getSingle();
    final changedAt = DateTime.fromMillisecondsSinceEpoch(
      at.read<int>('lo') * 1000,
    );
    expect(changedAt.isAfter(before), isTrue);
    // Die Liste der Artikel kommt nach den Bons.
    final last = await db
        .customSelect('SELECT kind FROM outbox ORDER BY id DESC LIMIT 1')
        .getSingle();
    expect(last.read<String>('kind'), 'item_change');
    await db.close();
  });

  test('4 → 5 nicht gekoppelt: keine Artikel-Änderung', () async {
    final file = await copyFixture('kassa_v4.sqlite');
    final db = KassaDatabase(
      NativeDatabase(
        file,
        setup: (raw) => raw.execute('UPDATE sync_state SET register_id = NULL'),
      ),
    );
    expect(await count(db, 'outbox'), 9);
    expect(
      await db
          .customSelect(
            "SELECT COUNT(*) c FROM outbox WHERE kind = 'item_change'",
          )
          .getSingle()
          .then((r) => r.read<int>('c')),
      0,
    );
    await db.close();
  });

  test('4 → 5: Trigger der Unveränderlichkeit greifen weiter', () async {
    final db = KassaDatabase(NativeDatabase(await copyFixture('kassa_v4.sqlite')));
    await db.select(db.syncStateRows).get(); // löst die Migration aus
    for (final sql in const [
      'UPDATE receipts SET total_cents = 1',
      'DELETE FROM receipts',
      'UPDATE receipt_lines SET quantity = 9',
      'DELETE FROM payments',
      'UPDATE cash_movements SET amount_cents = 1',
      'DELETE FROM cash_movements',
      "UPDATE business_days SET opening_float_cents = 1 WHERE id = 'day-1'",
      'DELETE FROM business_days',
      "UPDATE rksv_entries SET jws = 'x'",
      'DELETE FROM rksv_entries',
      "UPDATE rksv_certificates SET issuers = '[\"x\"]'",
      'DELETE FROM rksv_certificates',
      'DELETE FROM rksv_chains',
    ]) {
      await expectLater(
        db.customStatement(sql),
        throwsA(isA<SqliteException>()),
        reason: sql,
      );
    }
    // Der offene Tag lässt sich noch ändern, und das stellt ihn neu ein.
    await db.customStatement(
      "UPDATE business_days SET opening_float_cents = 5 WHERE id = 'day-2'",
    );
    final rev = await db
        .customSelect(
          "SELECT rev FROM outbox WHERE kind = 'day' AND ref = 'day-2'",
        )
        .getSingle();
    expect(rev.read<int>('rev'), 1);
    await db.close();
  });

  test('unbekannter gespeicherter Wert fällt auf die Vorgabe zurück', () async {
    final db = KassaDatabase(NativeDatabase.memory());
    await db.customStatement(
      "INSERT INTO settings (id, theme_mode, printer_kind) VALUES (1, 'neon', 'laser')",
    );
    final s = await SettingsRepository(db).current();
    expect(s.themeMode, AppThemeMode.system);
    expect(s.printerKind, PrinterKind.none);
    await db.close();
  });
}

/// Öffnet eine Datei von Version 3 ohne Migration, nur zum Vorbereiten.
class _NoUser extends QueryExecutorUser {
  @override
  int get schemaVersion => 3;

  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {}
}
