import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/core/app_language.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/settings_repository.dart';
import 'package:kassa/domain/feature_access.dart';
import 'package:kassa/domain/staff.dart';

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

  test('Sprache und Küchenbon: Vorgaben', () async {
    final s = await settings.current();
    expect(s.language, AppLanguage.de);
    expect(s.kitchenMode, KitchenMode.off);
    expect(s.kitchenLanguage, AppLanguage.de);
    expect(s.kitchenPrinterKind, PrinterKind.none);
    expect(s.kitchenPrinterAddress, isNull);
    expect(s.kitchenPrinterName, isNull);
    expect(s.kitchenPrinterColumns, 48);
    expect(s.kitchenSkipCategories, isEmpty);
  });

  test('Sprache und Küchenbon: alle Felder werden gespeichert', () async {
    await settings.save(
      const RegisterSettings(
        language: AppLanguage.ar,
        kitchenMode: KitchenMode.kitchenPrinter,
        kitchenLanguage: AppLanguage.tr,
        kitchenPrinterKind: PrinterKind.network,
        kitchenPrinterAddress: '192.168.1.60:9100',
        kitchenPrinterName: 'Küche',
        kitchenPrinterColumns: 32,
        kitchenSkipCategories: {'getraenke', 'dessert'},
      ),
    );
    final s = await settings.current();
    expect(s.language, AppLanguage.ar);
    expect(s.kitchenMode, KitchenMode.kitchenPrinter);
    expect(s.kitchenLanguage, AppLanguage.tr);
    expect(s.kitchenPrinterKind, PrinterKind.network);
    expect(s.kitchenPrinterAddress, '192.168.1.60:9100');
    expect(s.kitchenPrinterName, 'Küche');
    expect(s.kitchenPrinterColumns, 32);
    expect(s.kitchenSkipCategories, {'getraenke', 'dessert'});
  });

  test('withoutKitchenPrinter lässt den Rest stehen', () {
    final s = const RegisterSettings(
      language: AppLanguage.en,
      kitchenMode: KitchenMode.kitchenPrinter,
      kitchenPrinterKind: PrinterKind.usb,
      kitchenPrinterAddress: 'x',
      kitchenPrinterName: 'y',
      kitchenPrinterColumns: 42,
      kitchenSkipCategories: {'a'},
      printerKind: PrinterKind.network,
      printerAddress: 'z',
    ).withoutKitchenPrinter();
    expect(s.kitchenPrinterKind, PrinterKind.none);
    expect(s.kitchenPrinterAddress, isNull);
    expect(s.kitchenPrinterName, isNull);
    expect(s.kitchenPrinterColumns, 42);
    expect(s.kitchenMode, KitchenMode.kitchenPrinter);
    expect(s.kitchenSkipCategories, {'a'});
    expect(s.language, AppLanguage.en);
    expect(s.printerKind, PrinterKind.network);
    expect(s.printerAddress, 'z');
  });

  test('unbekannter Text und kaputtes JSON geben die Vorgaben', () async {
    await settings.save(const RegisterSettings());
    Future<void> set(String sql) => db.customStatement(sql);
    await set(
      "UPDATE settings SET language = 'xx', kitchen_mode = 'bogus', "
      "kitchen_language = '', kitchen_printer_kind = 'laser', "
      "kitchen_skip_categories = '{kaputt'",
    );
    var s = await settings.current();
    expect(s.language, AppLanguage.de);
    expect(s.kitchenMode, KitchenMode.off);
    expect(s.kitchenLanguage, AppLanguage.de);
    expect(s.kitchenPrinterKind, PrinterKind.none);
    expect(s.kitchenSkipCategories, isEmpty);
    // Gültiges JSON, aber keine Liste von Texten.
    await set("UPDATE settings SET kitchen_skip_categories = '{\"a\":1}'");
    s = await settings.current();
    expect(s.kitchenSkipCategories, isEmpty);
    await set("UPDATE settings SET kitchen_skip_categories = '[\"a\", 3]'");
    s = await settings.current();
    expect(s.kitchenSkipCategories, {'a'});
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

  test('QR-Code als Bild: Vorgabe falsch, wird gespeichert und bleibt ohne Drucker', () async {
    expect((await settings.current()).printerQrAsImage, isFalse);
    await settings.save(
      const RegisterSettings(
        printerKind: PrinterKind.usb,
        printerQrAsImage: true,
      ),
    );
    final s = await settings.current();
    expect(s.printerQrAsImage, isTrue);
    expect(s.copyWith(printerColumns: 32).printerQrAsImage, isTrue);
    expect(s.copyWith(printerQrAsImage: false).printerQrAsImage, isFalse);
    expect(s.withoutPrinter().printerQrAsImage, isTrue);
  });

  test('die vier Schalter: speichern und lesen', () async {
    var s = await settings.current();
    expect(
      (
        s.splitPaymentEnabled,
        s.cardTipEnabled,
        s.discountAccess,
        s.openAmountAccess,
      ),
      (false, false, FeatureAccess.off, FeatureAccess.off),
    );
    await settings.save(
      s.copyWith(
        splitPaymentEnabled: true,
        cardTipEnabled: true,
        discountAccess: FeatureAccess.chefOnly,
        openAmountAccess: FeatureAccess.all,
      ),
    );
    s = await settings.current();
    expect(
      (
        s.splitPaymentEnabled,
        s.cardTipEnabled,
        s.discountAccess,
        s.openAmountAccess,
      ),
      (true, true, FeatureAccess.chefOnly, FeatureAccess.all),
    );
    final row = await db.select(db.settingsRows).getSingle();
    expect((row.discountAccess, row.openAmountAccess), ('chefOnly', 'all'));
    // withoutPrinter und withoutKitchenPrinter reichen sie durch.
    for (final t in [s.withoutPrinter(), s.withoutKitchenPrinter()]) {
      expect(
        (
          t.splitPaymentEnabled,
          t.cardTipEnabled,
          t.discountAccess,
          t.openAmountAccess,
        ),
        (true, true, FeatureAccess.chefOnly, FeatureAccess.all),
      );
    }
    expect(
      s.copyWith(printerColumns: 32).discountAccess,
      FeatureAccess.chefOnly,
    );
  });

  test('unbekannter Text in discount_access gibt off', () async {
    await settings.save(
      const RegisterSettings(
        discountAccess: FeatureAccess.all,
        openAmountAccess: FeatureAccess.all,
      ),
    );
    await db.customStatement(
      "UPDATE settings SET discount_access = 'bogus', open_amount_access = ''",
    );
    final s = await settings.current();
    expect(s.discountAccess, FeatureAccess.off);
    expect(s.openAmountAccess, FeatureAccess.off);
  });

  group('FeatureAccess.allows', () {
    const anna = Staff(id: 'staff-anna', name: 'Anna', role: StaffRole.staff);
    const chef = Staff(id: 'staff-chef', name: 'Chef', role: StaffRole.chef);

    test('off: nie', () {
      expect(
        [
          for (final p in [anna, chef, null]) FeatureAccess.off.allows(p),
        ],
        [false, false, false],
      );
    });

    test('all: Anna und Chef, ohne Anmeldung nie', () {
      expect(
        [
          for (final p in [anna, chef, null]) FeatureAccess.all.allows(p),
        ],
        [true, true, false],
      );
    });

    test('chefOnly: nur der Chef', () {
      expect(
        [
          for (final p in [anna, chef, null]) FeatureAccess.chefOnly.allows(p),
        ],
        [false, true, false],
      );
    });
  });
}
