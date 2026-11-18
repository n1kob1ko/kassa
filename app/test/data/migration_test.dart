import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm;
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
