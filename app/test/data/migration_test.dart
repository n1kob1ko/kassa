import 'dart:io';

import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/settings_repository.dart';

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
