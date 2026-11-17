// Einstellungen der Kassa und der Entwurf des offenen Bons.

import 'package:drift/drift.dart';

import 'database.dart';

enum AppThemeMode { system, light, dark }

class RegisterSettings {
  const RegisterSettings({
    this.cashDrawerEnabled = true,
    this.showImages = false,
    this.themeMode = AppThemeMode.system,
    this.voidRequiresChef = false,
  });

  final bool cashDrawerEnabled;
  final bool showImages;
  final AppThemeMode themeMode;
  final bool voidRequiresChef;

  RegisterSettings copyWith({
    bool? cashDrawerEnabled,
    bool? showImages,
    AppThemeMode? themeMode,
    bool? voidRequiresChef,
  }) =>
      RegisterSettings(
        cashDrawerEnabled: cashDrawerEnabled ?? this.cashDrawerEnabled,
        showImages: showImages ?? this.showImages,
        themeMode: themeMode ?? this.themeMode,
        voidRequiresChef: voidRequiresChef ?? this.voidRequiresChef,
      );
}

class SettingsRepository {
  SettingsRepository(this._db);

  final KassaDatabase _db;

  /// Gibt zuerst den aktuellen Stand und danach nach jedem Speichern den neuen.
  Stream<RegisterSettings> watch() => (_db.select(_db.settingsRows)
        ..where((t) => t.id.equals(1)))
      .watchSingleOrNull()
      .map(_toSettings);

  Future<RegisterSettings> current() async => _toSettings(await _row());

  Future<void> save(RegisterSettings s) =>
      _db.into(_db.settingsRows).insertOnConflictUpdate(SettingsRowsCompanion(
        id: const Value(1),
        cashDrawerEnabled: Value(s.cashDrawerEnabled),
        showImages: Value(s.showImages),
        themeMode: Value(s.themeMode.name),
        voidRequiresChef: Value(s.voidRequiresChef),
      ));

  Future<String?> readDraft() async => (await _row())?.receiptDraft;

  /// `null` löscht den Entwurf.
  Future<void> writeDraft(String? json) async {
    await _db.into(_db.settingsRows).insertOnConflictUpdate(
        SettingsRowsCompanion(id: const Value(1), receiptDraft: Value(json)));
  }

  Future<SettingsRow?> _row() => (_db.select(_db.settingsRows)
        ..where((t) => t.id.equals(1)))
      .getSingleOrNull();

  RegisterSettings _toSettings(SettingsRow? r) => r == null
      ? const RegisterSettings()
      : RegisterSettings(
          cashDrawerEnabled: r.cashDrawerEnabled,
          showImages: r.showImages,
          themeMode: AppThemeMode.values.byName(r.themeMode),
          voidRequiresChef: r.voidRequiresChef,
        );
}
