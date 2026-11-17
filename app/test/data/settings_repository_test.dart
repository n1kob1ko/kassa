import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/settings_repository.dart';

void main() {
  late KassaDatabase db;
  late SettingsRepository settings;

  setUp(() {
    db = KassaDatabase(NativeDatabase.memory());
    settings = SettingsRepository(db);
  });
  tearDown(() => db.close());

  test('Voreinstellungen und Speichern', () async {
    final s = await settings.current();
    expect(
      (s.cashDrawerEnabled, s.showImages, s.themeMode, s.voidRequiresChef),
      (true, false, AppThemeMode.system, false),
    );
    await settings.save(s.copyWith(cashDrawerEnabled: false));
    expect((await settings.current()).cashDrawerEnabled, isFalse);
  });

  test('alle Felder werden gespeichert', () async {
    await settings.save(
      const RegisterSettings(
        cashDrawerEnabled: false,
        showImages: true,
        themeMode: AppThemeMode.dark,
        voidRequiresChef: true,
      ),
    );
    final s = await settings.current();
    expect(
      (s.cashDrawerEnabled, s.showImages, s.themeMode, s.voidRequiresChef),
      (false, true, AppThemeMode.dark, true),
    );
  });

  test('watch gibt zuerst den Stand und danach jede Änderung', () async {
    final emitted = expectLater(
      settings.watch().map((s) => s.showImages),
      emitsInOrder([false, true, false]),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await settings.save(const RegisterSettings(showImages: true));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await settings.save(const RegisterSettings());
    await emitted;
  });

  test(
    'Entwurf schreiben, lesen und löschen; Speichern lässt ihn stehen',
    () async {
      expect(await settings.readDraft(), isNull);
      await settings.writeDraft('{"lines":[]}');
      expect(await settings.readDraft(), '{"lines":[]}');
      await settings.save(const RegisterSettings(showImages: true));
      expect(await settings.readDraft(), '{"lines":[]}');
      await settings.writeDraft(null);
      expect(await settings.readDraft(), isNull);
    },
  );

  test(
    'Drucker-Einstellungen werden gespeichert, withoutPrinter leert sie',
    () async {
      await settings.save(
        const RegisterSettings(
          printerKind: PrinterKind.network,
          printerAddress: '192.168.1.50:9100',
          printerName: 'Bondrucker',
          printerColumns: 42,
        ),
      );
      final s = await settings.current();
      expect(
        (s.printerKind, s.printerAddress, s.printerName, s.printerColumns),
        (PrinterKind.network, '192.168.1.50:9100', 'Bondrucker', 42),
      );
      final leer = s.withoutPrinter();
      expect(
        (
          leer.printerKind,
          leer.printerAddress,
          leer.printerName,
          leer.printerColumns,
        ),
        (PrinterKind.none, null, null, 42),
      );
      await settings.save(leer);
      final back = await settings.current();
      expect(
        (back.printerKind, back.printerAddress, back.printerName),
        (PrinterKind.none, null, null),
      );
    },
  );
}
