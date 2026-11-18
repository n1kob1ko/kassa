import 'dart:io';

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
