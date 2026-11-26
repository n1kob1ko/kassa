import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:kassa/core/app_language.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/settings_repository.dart';

import 'generated_migrations/schema.dart';
import 'migration_test.dart' show copyFixture, count;

/// Version 7 (Sprachen und Küchenbon) nach Version 6 (1.9.0). Die Datei
/// `kassa_v6.sqlite` entsteht mit `tool/make_kassa_v6_fixture.dart` aus dem
/// Abzug von Version 6.
void main() {
  Future<int> userVersion(KassaDatabase db) async =>
      (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
        'user_version',
      );

  Future<List<String>> triggerNames(KassaDatabase db) async => [
    for (final r
        in await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'trigger' "
              'ORDER BY name',
            )
            .get())
      r.read<String>('name'),
  ];

  test('Schema: Version 6 wird zu Version 7', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final connection = await verifier.startAt(6);
    final db = KassaDatabase(connection);
    await verifier.migrateAndValidate(db, 7);
    await db.close();
  });

  test('Schema: Version 5 wird zu Version 7 (Schritt 6, dann 7)', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final connection = await verifier.startAt(5);
    final db = KassaDatabase(connection);
    await verifier.migrateAndValidate(db, 7);
    await db.close();
  });

  test('Update von 1.9.0: Einstellungen behalten ihre Werte und bekommen die '
      'Vorgaben, der Abgleich holt neu, nichts sonst ändert sich', () async {
    final file = await copyFixture('kassa_v6.sqlite');
    // Zählung vor dem Update, an der Datei selbst.
    final raw = sqlite.sqlite3.open(file.path);
    expect(raw.select('PRAGMA user_version').single.values.single, 6);
    int rawCount(String table) =>
        raw.select('SELECT COUNT(*) c FROM $table').single['c'] as int;
    final before = {
      for (final t in const [
        'receipts',
        'receipt_lines',
        'receipt_line_options',
        'payments',
        'business_days',
        'cash_movements',
        'outbox',
        'items',
        'categories',
      ])
        t: rawCount(t),
    };
    final triggersBefore = [
      for (final r in raw.select(
        "SELECT name FROM sqlite_master WHERE type = 'trigger' ORDER BY name",
      ))
        r['name'] as String,
    ];
    raw.close();
    expect(before['receipts'], 6);
    expect(before['outbox'], greaterThan(0));
    expect(triggersBefore, isNotEmpty);

    final db = KassaDatabase(NativeDatabase(file));
    addTearDown(db.close);
    expect(await userVersion(db), 7);

    // Alte Werte bleiben, die neuen haben ihre Vorgaben.
    final s = await SettingsRepository(db).current();
    expect(s.cashDrawerEnabled, isFalse);
    expect(s.showImages, isTrue);
    expect(s.themeMode, AppThemeMode.dark);
    expect(s.voidRequiresChef, isTrue);
    expect(s.printerKind, PrinterKind.network);
    expect(s.printerAddress, '192.168.1.50:9100');
    expect(s.printerName, 'Bondrucker');
    expect(s.printerColumns, 42);
    expect(s.printerQrAsImage, isTrue);
    expect(s.language, AppLanguage.de);
    expect(s.kitchenMode, KitchenMode.off);
    expect(s.kitchenLanguage, AppLanguage.de);
    expect(s.kitchenPrinterKind, PrinterKind.none);
    expect(s.kitchenPrinterAddress, isNull);
    expect(s.kitchenPrinterName, isNull);
    expect(s.kitchenPrinterColumns, 48);
    expect(s.kitchenSkipCategories, isEmpty);
    final row = await db.select(db.settingsRows).getSingle();
    expect(row.kitchenSkipCategories, '[]');

    // Die Übersetzungen kommen vom Server, bis dahin ist die Tabelle leer.
    expect(await count(db, 'translations'), 0);

    // Der Abgleich holt alles einmal neu, der erste Abgleich bleibt getan.
    final sync = await db.select(db.syncStateRows).getSingle();
    expect(sync.pullCursor, 0);
    expect(sync.initialPullDone, isTrue);
    expect(sync.registerId, 'test-register');
    expect(sync.deviceId, 'test-device');

    // Bons, Liste und Trigger sind unverändert.
    for (final MapEntry(:key, :value) in before.entries) {
      expect(await count(db, key), value, reason: key);
    }
    expect(await triggerNames(db), triggersBefore);
    await expectLater(
      db.customStatement('UPDATE receipts SET total_cents = 1'),
      throwsA(isA<SqliteException>()),
    );
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
  });

  test('Schritt 7 ist wiederholbar: Version zurückgesetzt, die Kassa öffnet '
      'auf Version 7 und der Abgleich-Stand bleibt', () async {
    final file = await copyFixture('kassa_v6.sqlite');
    final first = KassaDatabase(NativeDatabase(file));
    expect(await userVersion(first), 7);
    await SettingsRepository(first).save(
      const RegisterSettings(
        language: AppLanguage.tr,
        kitchenMode: KitchenMode.receiptPrinter,
        kitchenSkipCategories: {'getraenke'},
      ),
    );
    await first.customStatement('UPDATE sync_state SET pull_cursor = 12');
    await first.close();

    final raw = sqlite.sqlite3.open(file.path);
    raw.execute('PRAGMA user_version = 6');
    raw.close();

    final db = KassaDatabase(NativeDatabase(file));
    addTearDown(db.close);
    expect(await userVersion(db), 7);
    final s = await SettingsRepository(db).current();
    expect(s.language, AppLanguage.tr);
    expect(s.kitchenMode, KitchenMode.receiptPrinter);
    expect(s.kitchenSkipCategories, {'getraenke'});
    // Der zweite Lauf hat den Stand nicht noch einmal auf 0 gesetzt.
    expect((await db.select(db.syncStateRows).getSingle()).pullCursor, 12);
  });

  test(
    'neue Datenbank: Version 7 mit leerer Tabelle der Übersetzungen',
    () async {
      final db = KassaDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      expect(await userVersion(db), 7);
      expect(await count(db, 'translations'), 0);
      expect(
        await SettingsRepository(db).current(),
        isA<RegisterSettings>().having(
          (s) => s.language,
          'language',
          AppLanguage.de,
        ),
      );
    },
  );
}
