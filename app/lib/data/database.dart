// SQLite-Datenbank der Kassa (drift). Enthält Katalog, Mitarbeiter und
// Einstellungen. Tabellen für Bons, Zahlungen und Tagesabschluss folgen mit
// den Aufgaben, die sie brauchen.

import 'package:drift/drift.dart';

part 'database.g.dart';

/// Genau eine Zeile (id = 1): der Name des Betriebs.
class BusinessRows extends Table {
  @override
  String get tableName => 'business';

  IntColumn get id => integer()();
  TextColumn get name => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class CategoryRows extends Table {
  @override
  String get tableName => 'categories';

  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get position => integer()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class ItemRows extends Table {
  @override
  String get tableName => 'items';

  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get priceCents => integer()();
  TextColumn get categoryId => text().references(CategoryRows, #id)();
  IntColumn get taxPercent => integer()();
  IntColumn get depositCents => integer().withDefault(const Constant(0))();

  /// Namen der Kennzeichen, durch Komma getrennt.
  TextColumn get tags => text().withDefault(const Constant(''))();
  TextColumn get info => text().nullable()();

  /// Bewusst ohne Fremdschlüssel: stillgelegte Artikel dürfen auf eine
  /// Vorlage zeigen, die es in der neuen Datei nicht mehr gibt.
  TextColumn get templateId => text().nullable()();
  BoolColumn get favorite => boolean().withDefault(const Constant(false))();
  BoolColumn get inSale => boolean().withDefault(const Constant(true))();
  TextColumn get photoPath => text().nullable()();
  IntColumn get position => integer()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class ModifierTemplateRows extends Table {
  @override
  String get tableName => 'modifier_templates';

  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get position => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class ModifierGroupRows extends Table {
  @override
  String get tableName => 'modifier_groups';

  TextColumn get id => text()();
  TextColumn get templateId => text().references(ModifierTemplateRows, #id)();
  TextColumn get name => text()();
  IntColumn get minCount => integer()();

  /// `null` heißt ohne Grenze.
  IntColumn get maxCount => integer().nullable()();
  IntColumn get position => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class ModifierOptionRows extends Table {
  @override
  String get tableName => 'modifier_options';

  TextColumn get id => text()();
  TextColumn get groupId => text().references(ModifierGroupRows, #id)();
  TextColumn get name => text()();
  IntColumn get surchargeCents => integer().withDefault(const Constant(0))();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  IntColumn get taxPercent => integer().nullable()();
  IntColumn get depositCents => integer().nullable()();
  IntColumn get position => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class StaffRows extends Table {
  @override
  String get tableName => 'staff';

  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get role => text()();
  TextColumn get pinSalt => text()();
  TextColumn get pinHash => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Genau eine Zeile (id = 1): Einstellungen und Entwurf des offenen Bons.
class SettingsRows extends Table {
  @override
  String get tableName => 'settings';

  IntColumn get id => integer()();
  BoolColumn get cashDrawerEnabled => boolean().withDefault(const Constant(true))();
  BoolColumn get showImages => boolean().withDefault(const Constant(false))();
  TextColumn get themeMode => text().withDefault(const Constant('system'))();
  BoolColumn get voidRequiresChef => boolean().withDefault(const Constant(false))();
  TextColumn get receiptDraft => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [
  BusinessRows,
  CategoryRows,
  ItemRows,
  ModifierTemplateRows,
  ModifierGroupRows,
  ModifierOptionRows,
  StaffRows,
  SettingsRows,
])
class KassaDatabase extends _$KassaDatabase {
  KassaDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
