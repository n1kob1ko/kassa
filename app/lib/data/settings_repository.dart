// Einstellungen der Kassa und der Entwurf des offenen Bons.

import 'dart:convert';

import 'package:drift/drift.dart';

import '../core/app_language.dart';
import '../core/enums.dart';
import '../domain/feature_access.dart';
import 'database.dart';

enum AppThemeMode { system, light, dark }

enum PrinterKind { none, network, usb, bluetooth }

class RegisterSettings {
  const RegisterSettings({
    this.cashDrawerEnabled = true,
    this.showImages = false,
    this.themeMode = AppThemeMode.system,
    this.voidRequiresChef = false,
    this.printerKind = PrinterKind.none,
    this.printerAddress,
    this.printerName,
    this.printerColumns = 48,
    this.printerQrAsImage = false,
    this.language = AppLanguage.de,
    this.kitchenMode = KitchenMode.off,
    this.kitchenLanguage = AppLanguage.de,
    this.kitchenPrinterKind = PrinterKind.none,
    this.kitchenPrinterAddress,
    this.kitchenPrinterName,
    this.kitchenPrinterColumns = 48,
    this.kitchenSkipCategories = const {},
    this.splitPaymentEnabled = false,
    this.cardTipEnabled = false,
    this.discountAccess = FeatureAccess.off,
    this.openAmountAccess = FeatureAccess.off,
    this.depositReturnAccess = FeatureAccess.off,
    this.voucherEnabled = false,
    this.invoiceEnabled = false,
    this.receiptMode = ReceiptMode.alwaysPrint,
  });

  final bool cashDrawerEnabled;
  final bool showImages;
  final AppThemeMode themeMode;
  final bool voidRequiresChef;
  final PrinterKind printerKind;
  final String? printerAddress;
  final String? printerName;
  final int printerColumns;

  /// Den QR-Code als Bild drucken statt mit dem QR-Befehl des Druckers.
  final bool printerQrAsImage;

  /// Sprache der Oberfläche.
  final AppLanguage language;

  /// Wohin der Küchenbon geht und in welcher Sprache er gedruckt wird.
  final KitchenMode kitchenMode;
  final AppLanguage kitchenLanguage;
  final PrinterKind kitchenPrinterKind;
  final String? kitchenPrinterAddress;
  final String? kitchenPrinterName;
  final int kitchenPrinterColumns;

  /// Kennungen der Kategorien, die nicht auf den Küchenbon kommen.
  final Set<String> kitchenSkipCategories;

  /// Die Schalter von "Zahlen": Teil bar, Rest Karte; Trinkgeld bei
  /// Kartenzahlung; wer Rabatt geben und wer einen freien Betrag bonieren
  /// darf.
  final bool splitPaymentEnabled;
  final bool cardTipEnabled;
  final FeatureAccess discountAccess;
  final FeatureAccess openAmountAccess;

  /// Die Schalter von Stufe 1b: wer Pfand zurückgeben darf, Gutschein,
  /// Rechnung an Firma und wie der Kunde seinen Beleg bekommt.
  final FeatureAccess depositReturnAccess;
  final bool voucherEnabled;
  final bool invoiceEnabled;
  final ReceiptMode receiptMode;

  RegisterSettings copyWith({
    bool? cashDrawerEnabled,
    bool? showImages,
    AppThemeMode? themeMode,
    bool? voidRequiresChef,
    PrinterKind? printerKind,
    String? printerAddress,
    String? printerName,
    int? printerColumns,
    bool? printerQrAsImage,
    AppLanguage? language,
    KitchenMode? kitchenMode,
    AppLanguage? kitchenLanguage,
    PrinterKind? kitchenPrinterKind,
    String? kitchenPrinterAddress,
    String? kitchenPrinterName,
    int? kitchenPrinterColumns,
    Set<String>? kitchenSkipCategories,
    bool? splitPaymentEnabled,
    bool? cardTipEnabled,
    FeatureAccess? discountAccess,
    FeatureAccess? openAmountAccess,
    FeatureAccess? depositReturnAccess,
    bool? voucherEnabled,
    bool? invoiceEnabled,
    ReceiptMode? receiptMode,
  }) => RegisterSettings(
    cashDrawerEnabled: cashDrawerEnabled ?? this.cashDrawerEnabled,
    showImages: showImages ?? this.showImages,
    themeMode: themeMode ?? this.themeMode,
    voidRequiresChef: voidRequiresChef ?? this.voidRequiresChef,
    printerKind: printerKind ?? this.printerKind,
    printerAddress: printerAddress ?? this.printerAddress,
    printerName: printerName ?? this.printerName,
    printerColumns: printerColumns ?? this.printerColumns,
    printerQrAsImage: printerQrAsImage ?? this.printerQrAsImage,
    language: language ?? this.language,
    kitchenMode: kitchenMode ?? this.kitchenMode,
    kitchenLanguage: kitchenLanguage ?? this.kitchenLanguage,
    kitchenPrinterKind: kitchenPrinterKind ?? this.kitchenPrinterKind,
    kitchenPrinterAddress: kitchenPrinterAddress ?? this.kitchenPrinterAddress,
    kitchenPrinterName: kitchenPrinterName ?? this.kitchenPrinterName,
    kitchenPrinterColumns: kitchenPrinterColumns ?? this.kitchenPrinterColumns,
    kitchenSkipCategories: kitchenSkipCategories ?? this.kitchenSkipCategories,
    splitPaymentEnabled: splitPaymentEnabled ?? this.splitPaymentEnabled,
    cardTipEnabled: cardTipEnabled ?? this.cardTipEnabled,
    discountAccess: discountAccess ?? this.discountAccess,
    openAmountAccess: openAmountAccess ?? this.openAmountAccess,
    depositReturnAccess: depositReturnAccess ?? this.depositReturnAccess,
    voucherEnabled: voucherEnabled ?? this.voucherEnabled,
    invoiceEnabled: invoiceEnabled ?? this.invoiceEnabled,
    receiptMode: receiptMode ?? this.receiptMode,
  );

  /// Kein Drucker mehr: Art `none`, Adresse und Name leer (`copyWith` kann
  /// Werte nicht auf `null` setzen).
  RegisterSettings withoutPrinter() => RegisterSettings(
    cashDrawerEnabled: cashDrawerEnabled,
    showImages: showImages,
    themeMode: themeMode,
    voidRequiresChef: voidRequiresChef,
    printerColumns: printerColumns,
    printerQrAsImage: printerQrAsImage,
    language: language,
    kitchenMode: kitchenMode,
    kitchenLanguage: kitchenLanguage,
    kitchenPrinterKind: kitchenPrinterKind,
    kitchenPrinterAddress: kitchenPrinterAddress,
    kitchenPrinterName: kitchenPrinterName,
    kitchenPrinterColumns: kitchenPrinterColumns,
    kitchenSkipCategories: kitchenSkipCategories,
    splitPaymentEnabled: splitPaymentEnabled,
    cardTipEnabled: cardTipEnabled,
    discountAccess: discountAccess,
    openAmountAccess: openAmountAccess,
    depositReturnAccess: depositReturnAccess,
    voucherEnabled: voucherEnabled,
    invoiceEnabled: invoiceEnabled,
    receiptMode: receiptMode,
  );

  /// Kein Küchendrucker mehr: Art `none`, Adresse und Name leer.
  RegisterSettings withoutKitchenPrinter() => RegisterSettings(
    cashDrawerEnabled: cashDrawerEnabled,
    showImages: showImages,
    themeMode: themeMode,
    voidRequiresChef: voidRequiresChef,
    printerKind: printerKind,
    printerAddress: printerAddress,
    printerName: printerName,
    printerColumns: printerColumns,
    printerQrAsImage: printerQrAsImage,
    language: language,
    kitchenMode: kitchenMode,
    kitchenLanguage: kitchenLanguage,
    kitchenPrinterColumns: kitchenPrinterColumns,
    kitchenSkipCategories: kitchenSkipCategories,
    splitPaymentEnabled: splitPaymentEnabled,
    cardTipEnabled: cardTipEnabled,
    discountAccess: discountAccess,
    openAmountAccess: openAmountAccess,
    depositReturnAccess: depositReturnAccess,
    voucherEnabled: voucherEnabled,
    invoiceEnabled: invoiceEnabled,
    receiptMode: receiptMode,
  );
}

class SettingsRepository {
  SettingsRepository(this._db);

  final KassaDatabase _db;

  /// Gibt zuerst den aktuellen Stand und danach nach jedem Speichern den neuen.
  Stream<RegisterSettings> watch() => (_db.select(
    _db.settingsRows,
  )..where((t) => t.id.equals(1))).watchSingleOrNull().map(_toSettings);

  Future<RegisterSettings> current() async => _toSettings(await _row());

  Future<void> save(RegisterSettings s) => _db
      .into(_db.settingsRows)
      .insertOnConflictUpdate(
        SettingsRowsCompanion(
          id: const Value(1),
          cashDrawerEnabled: Value(s.cashDrawerEnabled),
          showImages: Value(s.showImages),
          themeMode: Value(s.themeMode.name),
          voidRequiresChef: Value(s.voidRequiresChef),
          printerKind: Value(s.printerKind.name),
          printerAddress: Value(s.printerAddress),
          printerName: Value(s.printerName),
          printerColumns: Value(s.printerColumns),
          printerQrAsImage: Value(s.printerQrAsImage),
          language: Value(s.language.name),
          kitchenMode: Value(s.kitchenMode.name),
          kitchenLanguage: Value(s.kitchenLanguage.name),
          kitchenPrinterKind: Value(s.kitchenPrinterKind.name),
          kitchenPrinterAddress: Value(s.kitchenPrinterAddress),
          kitchenPrinterName: Value(s.kitchenPrinterName),
          kitchenPrinterColumns: Value(s.kitchenPrinterColumns),
          kitchenSkipCategories: Value(
            jsonEncode((s.kitchenSkipCategories.toList()..sort())),
          ),
          splitPayment: Value(s.splitPaymentEnabled),
          cardTip: Value(s.cardTipEnabled),
          discountAccess: Value(s.discountAccess.name),
          openAmountAccess: Value(s.openAmountAccess.name),
          depositReturnAccess: Value(s.depositReturnAccess.name),
          voucher: Value(s.voucherEnabled),
          invoice: Value(s.invoiceEnabled),
          receiptMode: Value(s.receiptMode.name),
        ),
      );

  Future<String?> readDraft() async => (await _row())?.receiptDraft;

  /// `null` löscht den Entwurf.
  Future<void> writeDraft(String? json) async {
    await _db
        .into(_db.settingsRows)
        .insertOnConflictUpdate(
          SettingsRowsCompanion(id: const Value(1), receiptDraft: Value(json)),
        );
  }

  Future<SettingsRow?> _row() => (_db.select(
    _db.settingsRows,
  )..where((t) => t.id.equals(1))).getSingleOrNull();

  RegisterSettings _toSettings(SettingsRow? r) => r == null
      ? const RegisterSettings()
      : RegisterSettings(
          cashDrawerEnabled: r.cashDrawerEnabled,
          showImages: r.showImages,
          themeMode: enumByNameOr(
            AppThemeMode.values,
            r.themeMode,
            AppThemeMode.system,
          ),
          voidRequiresChef: r.voidRequiresChef,
          printerKind: enumByNameOr(
            PrinterKind.values,
            r.printerKind,
            PrinterKind.none,
          ),
          printerAddress: r.printerAddress,
          printerName: r.printerName,
          printerColumns: r.printerColumns,
          printerQrAsImage: r.printerQrAsImage,
          language: AppLanguage.byCode(r.language),
          kitchenMode: enumByNameOr(
            KitchenMode.values,
            r.kitchenMode,
            KitchenMode.off,
          ),
          kitchenLanguage: AppLanguage.byCode(r.kitchenLanguage),
          kitchenPrinterKind: enumByNameOr(
            PrinterKind.values,
            r.kitchenPrinterKind,
            PrinterKind.none,
          ),
          kitchenPrinterAddress: r.kitchenPrinterAddress,
          kitchenPrinterName: r.kitchenPrinterName,
          kitchenPrinterColumns: r.kitchenPrinterColumns,
          kitchenSkipCategories: _skipCategories(r.kitchenSkipCategories),
          splitPaymentEnabled: r.splitPayment,
          cardTipEnabled: r.cardTip,
          discountAccess: enumByNameOr(
            FeatureAccess.values,
            r.discountAccess,
            FeatureAccess.off,
          ),
          openAmountAccess: enumByNameOr(
            FeatureAccess.values,
            r.openAmountAccess,
            FeatureAccess.off,
          ),
          depositReturnAccess: enumByNameOr(
            FeatureAccess.values,
            r.depositReturnAccess,
            FeatureAccess.off,
          ),
          voucherEnabled: r.voucher,
          invoiceEnabled: r.invoice,
          receiptMode: enumByNameOr(
            ReceiptMode.values,
            r.receiptMode,
            ReceiptMode.alwaysPrint,
          ),
        );

  /// Kaputtes JSON oder etwas anderes als eine Liste: leere Menge.
  static Set<String> _skipCategories(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is List) return {...decoded.whereType<String>()};
    } on FormatException {
      // fällt auf die leere Menge zurück
    }
    return const {};
  }
}
