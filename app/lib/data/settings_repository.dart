// Einstellungen der Kassa und der Entwurf des offenen Bons.

import 'package:drift/drift.dart';

import '../core/enums.dart';
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
  });

  final bool cashDrawerEnabled;
  final bool showImages;
  final AppThemeMode themeMode;
  final bool voidRequiresChef;
  final PrinterKind printerKind;
  final String? printerAddress;
  final String? printerName;
  final int printerColumns;

  RegisterSettings copyWith({
    bool? cashDrawerEnabled,
    bool? showImages,
    AppThemeMode? themeMode,
    bool? voidRequiresChef,
    PrinterKind? printerKind,
    String? printerAddress,
    String? printerName,
    int? printerColumns,
  }) => RegisterSettings(
    cashDrawerEnabled: cashDrawerEnabled ?? this.cashDrawerEnabled,
    showImages: showImages ?? this.showImages,
    themeMode: themeMode ?? this.themeMode,
    voidRequiresChef: voidRequiresChef ?? this.voidRequiresChef,
    printerKind: printerKind ?? this.printerKind,
    printerAddress: printerAddress ?? this.printerAddress,
    printerName: printerName ?? this.printerName,
    printerColumns: printerColumns ?? this.printerColumns,
  );

  /// Kein Drucker mehr: Art `none`, Adresse und Name leer (`copyWith` kann
  /// Werte nicht auf `null` setzen).
  RegisterSettings withoutPrinter() => RegisterSettings(
    cashDrawerEnabled: cashDrawerEnabled,
    showImages: showImages,
    themeMode: themeMode,
    voidRequiresChef: voidRequiresChef,
    printerColumns: printerColumns,
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
        );
}
