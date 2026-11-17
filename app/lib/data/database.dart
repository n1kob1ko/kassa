// SQLite-Datenbank der Kassa (drift). Enthält Katalog, Mitarbeiter und
// Einstellungen, Bons und Geschäftstage. Tabellen für den Tagesabschluss
// folgen mit den Aufgaben, die sie brauchen.

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

/// Ein Geschäftstag: offen, solange `closedAt` leer ist. Die Felder zum
/// Abschluss füllt der Tagesabschluss.
class BusinessDayRows extends Table {
  @override
  String get tableName => 'business_days';

  TextColumn get id => text()();
  DateTimeColumn get openedAt => dateTime()();
  DateTimeColumn get closedAt => dateTime().nullable()();
  IntColumn get openingFloatCents => integer().withDefault(const Constant(0))();
  IntColumn get countedCents => integer().nullable()();
  IntColumn get leftInDrawerCents => integer().nullable()();
  IntColumn get expectedCents => integer().nullable()();
  IntColumn get differenceCents => integer().nullable()();
  TextColumn get closedByName => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Bons sind unveränderlich: Trigger weisen UPDATE und DELETE auf diese und
/// die drei folgenden Tabellen ab. Die Id eines Verkaufs ist seine `saleId`.
class ReceiptRows extends Table {
  @override
  String get tableName => 'receipts';

  TextColumn get id => text()();
  IntColumn get number => integer().unique()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get staffId => text()();
  TextColumn get staffName => text()();
  TextColumn get businessDayId => text().references(BusinessDayRows, #id)();

  /// `sale` oder `voided`.
  TextColumn get kind => text()();

  /// Beim Storno-Bon der Bon, den er storniert. Ein eindeutiger Index sorgt
  /// dafür, dass es höchstens einen Storno je Bon gibt.
  TextColumn get voidsReceiptId => text().nullable().references(ReceiptRows, #id)();
  IntColumn get goodsCents => integer()();
  IntColumn get depositCents => integer()();
  IntColumn get totalCents => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class ReceiptLineRows extends Table {
  @override
  String get tableName => 'receipt_lines';

  TextColumn get receiptId => text().references(ReceiptRows, #id)();
  IntColumn get position => integer()();
  TextColumn get itemId => text()();
  TextColumn get name => text()();
  TextColumn get info => text().nullable()();

  /// Einzelpreis inklusive Aufpreisen der Optionen.
  IntColumn get unitPriceCents => integer()();
  IntColumn get quantity => integer()();
  IntColumn get unitDepositCents => integer()();

  /// Brutto-Warenwert der Zeile je Steuersatz (ohne Pfand).
  IntColumn get gross20Cents => integer().withDefault(const Constant(0))();
  IntColumn get gross10Cents => integer().withDefault(const Constant(0))();
  IntColumn get gross13Cents => integer().withDefault(const Constant(0))();
  IntColumn get gross0Cents => integer().withDefault(const Constant(0))();
  IntColumn get gross19Cents => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {receiptId, position};
}

class ReceiptLineOptionRows extends Table {
  @override
  String get tableName => 'receipt_line_options';

  TextColumn get receiptId => text()();
  IntColumn get linePosition => integer()();
  IntColumn get position => integer()();
  TextColumn get groupName => text()();
  TextColumn get optionName => text()();
  IntColumn get surchargeCents => integer()();

  @override
  Set<Column> get primaryKey => {receiptId, linePosition, position};

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (receipt_id, line_position) REFERENCES receipt_lines (receipt_id, position)',
  ];
}

class PaymentRows extends Table {
  @override
  String get tableName => 'payments';

  TextColumn get receiptId => text().references(ReceiptRows, #id)();

  /// `cash` oder `card`.
  TextColumn get kind => text()();
  IntColumn get amountCents => integer()();
  IntColumn get givenCents => integer()();
  IntColumn get changeCents => integer()();

  @override
  Set<Column> get primaryKey => {receiptId};
}

@DriftDatabase(
  tables: [
    BusinessRows,
    CategoryRows,
    ItemRows,
    ModifierTemplateRows,
    ModifierGroupRows,
    ModifierOptionRows,
    StaffRows,
    SettingsRows,
    BusinessDayRows,
    ReceiptRows,
    ReceiptLineRows,
    ReceiptLineOptionRows,
    PaymentRows,
  ],
)
class KassaDatabase extends _$KassaDatabase {
  KassaDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await customStatement(
        'CREATE UNIQUE INDEX receipts_voids_receipt_id '
        'ON receipts (voids_receipt_id)',
      );
      for (final table in const ['receipts', 'receipt_lines', 'receipt_line_options', 'payments']) {
        for (final action in const ['UPDATE', 'DELETE']) {
          await customStatement(
            'CREATE TRIGGER ${table}_no_${action.toLowerCase()} '
            'BEFORE $action ON $table BEGIN '
            "SELECT RAISE(ABORT, 'Bons sind unveränderlich'); END",
          );
        }
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
