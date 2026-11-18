// SQLite-Datenbank der Kassa (drift). Enthält Katalog, Mitarbeiter und
// Einstellungen, Bons und Geschäftstage und das Protokoll der Signatur (RKSV).

import 'package:drift/drift.dart';

part 'database.g.dart';

/// Genau eine Zeile (id = 1): der Name des Betriebs.
class BusinessRows extends Table {
  @override
  String get tableName => 'business';

  IntColumn get id => integer()();
  TextColumn get name => text()();

  /// Anschrift für den Bon, Zeilen durch `\n` getrennt.
  TextColumn get addressLines => text().withDefault(const Constant(''))();
  TextColumn get vatId => text().nullable()();
  TextColumn get receiptFooter => text().nullable()();

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
  BoolColumn get cashDrawerEnabled =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get showImages => boolean().withDefault(const Constant(false))();
  TextColumn get themeMode => text().withDefault(const Constant('system'))();
  BoolColumn get voidRequiresChef =>
      boolean().withDefault(const Constant(false))();
  TextColumn get receiptDraft => text().nullable()();

  /// `none`, `network`, `usb` oder `bluetooth`.
  TextColumn get printerKind => text().withDefault(const Constant('none'))();
  TextColumn get printerAddress => text().nullable()();
  TextColumn get printerName => text().nullable()();
  IntColumn get printerColumns => integer().withDefault(const Constant(48))();

  /// Den QR-Code als Bild drucken statt mit dem QR-Befehl des Druckers.
  BoolColumn get printerQrAsImage =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Ein Geschäftstag: offen, solange `closedAt` leer ist. Die Felder zum
/// Abschluss füllt der Tagesabschluss. Abgeschlossene Tage sind unveränderlich.
class BusinessDayRows extends Table {
  @override
  String get tableName => 'business_days';

  TextColumn get id => text()();
  DateTimeColumn get openedAt => dateTime()();
  DateTimeColumn get closedAt => dateTime().nullable()();

  /// `null`, solange das Wechselgeld des Tages nicht bekannt ist.
  IntColumn get openingFloatCents => integer().nullable()();
  IntColumn get countedCents => integer().nullable()();
  IntColumn get leftInDrawerCents => integer().nullable()();
  IntColumn get expectedCents => integer().nullable()();
  IntColumn get differenceCents => integer().nullable()();
  TextColumn get closedByName => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Eine Ein- oder Auszahlung an der Geldlade. Unveränderlich.
class CashMovementRows extends Table {
  @override
  String get tableName => 'cash_movements';

  TextColumn get id => text()();
  TextColumn get businessDayId => text().references(BusinessDayRows, #id)();

  /// `deposit` oder `withdrawal`.
  TextColumn get kind => text()();
  IntColumn get amountCents => integer()();

  /// `bank`, `purchase`, `change` oder `other`.
  TextColumn get reason => text()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get staffId => text()();
  TextColumn get staffName => text()();

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

  /// Leer bei Sonderbelegen: sie gehören zu keinem Tag.
  TextColumn get businessDayId =>
      text().nullable().references(BusinessDayRows, #id)();

  /// `sale` oder `voided`, bei Sonderbelegen `start`, `month`, `year`,
  /// `zero`, `collective` oder `closing`.
  TextColumn get kind => text()();

  /// Beim Storno-Bon der Bon, den er storniert. Ein eindeutiger Index sorgt
  /// dafür, dass es höchstens einen Storno je Bon gibt.
  TextColumn get voidsReceiptId =>
      text().nullable().references(ReceiptRows, #id)();
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

  /// Nur bei Kartenzahlung gefüllt.
  TextColumn get provider => text().nullable()();
  TextColumn get providerTxCode => text().nullable()();
  TextColumn get cardScheme => text().nullable()();
  TextColumn get cardLast4 => text().nullable()();

  @override
  Set<Column> get primaryKey => {receiptId};
}

/// Eine Kartenzahlung, die gestartet, aber noch nicht als Bon abgeschlossen
/// ist. Bleibt über einen Neustart erhalten, damit kein bezahlter Betrag
/// verloren geht.
class PendingCardPaymentRows extends Table {
  @override
  String get tableName => 'pending_card_payments';

  TextColumn get id => text()();
  TextColumn get cartJson => text()();
  IntColumn get amountCents => integer()();
  TextColumn get staffId => text()();
  TextColumn get staffName => text()();
  DateTimeColumn get startedAt => dateTime()();

  /// `started` oder `unknown`.
  TextColumn get state => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Genau eine Zeile (id = 1): wie weit der Abgleich mit dem Server ist. Der
/// Geräte-Schlüssel steht hier nicht, er liegt im geschützten Speicher.
class SyncStateRows extends Table {
  @override
  String get tableName => 'sync_state';

  IntColumn get id => integer()();

  /// `null`, solange die Kassa nicht gekoppelt ist.
  TextColumn get registerId => text().nullable()();
  TextColumn get registerName => text().nullable()();
  TextColumn get businessId => text().nullable()();

  /// Die höchste Änderungs-Nummer, die schon eingespielt ist.
  IntColumn get pullCursor => integer().withDefault(const Constant(0))();

  /// Erst wahr, wenn der erste vollständige Abgleich eingespielt ist.
  BoolColumn get initialPullDone =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastPullAt => dateTime().nullable()();
  TextColumn get lastError => text().nullable()();
  BoolColumn get blocked => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Eine Kette der Signatur. Eine beendete Kette (`endedAt` gesetzt) ist
/// unveränderlich, gelöscht wird keine.
class RksvChainRows extends Table {
  @override
  String get tableName => 'rksv_chains';

  IntColumn get chain => integer()();

  /// `probe` oder `live`.
  TextColumn get mode => text()();
  TextColumn get cashBoxId => text()();
  TextColumn get zdaId => text()();

  /// Das Zertifikat, mit dem die Kette gerade signiert.
  TextColumn get certSerial =>
      text().references(RksvCertificateRows, #serialHex)();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {chain};
}

/// Zertifikate, mit denen signiert wurde. Unveränderlich.
class RksvCertificateRows extends Table {
  @override
  String get tableName => 'rksv_certificates';

  TextColumn get serialHex => text()();
  BlobColumn get certificate => blob()();

  /// Zertifikate der Aussteller: JSON-Liste aus base64.
  TextColumn get issuers => text().withDefault(const Constant('[]'))();

  @override
  Set<Column> get primaryKey => {serialHex};
}

/// Das Protokoll: ein Eintrag je signiertem Bon. Unveränderlich.
class RksvEntryRows extends Table {
  @override
  String get tableName => 'rksv_entries';

  IntColumn get chain => integer().references(RksvChainRows, #chain)();

  /// Stelle in der Kette, lückenlos ab 1.
  IntColumn get position => integer()();
  TextColumn get receiptId => text().unique().references(ReceiptRows, #id)();

  /// Kompakte JWS-Form.
  TextColumn get jws => text()();

  /// Wahr, wenn die Signatur ausgefallen war.
  BoolColumn get damaged => boolean()();
  TextColumn get certSerial => text()();

  @override
  Set<Column> get primaryKey => {chain, position};
}

/// Genau eine Zeile (id = 1): Stand der Signatur. Die Kassen-Kennung steht in
/// der laufenden Kette, der letzte Monatsbeleg ergibt sich aus ihrem letzten
/// Eintrag. Die Schlüssel liegen im geschützten Speicher, nie hier.
class RksvStateRows extends Table {
  @override
  String get tableName => 'rksv_state';

  IntColumn get id => integer()();

  /// `off`, `probe` oder `live`.
  TextColumn get mode => text().withDefault(const Constant('off'))();

  /// Die laufende Kette, `null` ohne.
  IntColumn get chain => integer().nullable()();
  IntColumn get counterCents => integer().withDefault(const Constant(0))();
  DateTimeColumn get outageSince => dateTime().nullable()();
  TextColumn get outageReason => text().nullable()();

  /// Offene Aufgaben als JSON-Liste.
  TextColumn get tasks => text().withDefault(const Constant('[]'))();
  TextColumn get notice => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
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
    CashMovementRows,
    ReceiptRows,
    ReceiptLineRows,
    ReceiptLineOptionRows,
    PaymentRows,
    PendingCardPaymentRows,
    SyncStateRows,
    RksvChainRows,
    RksvCertificateRows,
    RksvEntryRows,
    RksvStateRows,
  ],
)
class KassaDatabase extends _$KassaDatabase {
  KassaDatabase(super.e);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createReceiptsVoidsIndex();
      // Höchstens ein offener Tag. NULL gilt in einem eindeutigen Index immer
      // als verschieden, darum der Ausdruck, der für offene Tage gleich ist.
      await customStatement(
        'CREATE UNIQUE INDEX business_days_one_open '
        'ON business_days ((closed_at IS NULL)) WHERE closed_at IS NULL',
      );
      for (final action in const ['UPDATE', 'DELETE']) {
        await customStatement(
          'CREATE TRIGGER cash_movements_no_${action.toLowerCase()} '
          'BEFORE $action ON cash_movements BEGIN '
          "SELECT RAISE(ABORT, 'Bargeld-Bewegungen sind unveränderlich'); END",
        );
      }
      await customStatement(
        'CREATE TRIGGER business_days_no_update_closed '
        'BEFORE UPDATE ON business_days WHEN OLD.closed_at IS NOT NULL BEGIN '
        "SELECT RAISE(ABORT, 'Abgeschlossene Tage sind unveränderlich'); END",
      );
      await customStatement(
        'CREATE TRIGGER business_days_no_delete '
        'BEFORE DELETE ON business_days BEGIN '
        "SELECT RAISE(ABORT, 'Tage können nicht gelöscht werden'); END",
      );
      for (final table in const [
        'receipts',
        'receipt_lines',
        'receipt_line_options',
        'payments',
      ]) {
        await _createReceiptGuards(table);
      }
      await _createRksvGuards();
      await _insertRksvState();
    },
    // Jeder Schritt prüft auch [to], damit die Tests der älteren Schritte
    // genau bis zu ihrer Version migrieren.
    onUpgrade: (m, from, to) async {
      if (from < 2 && to >= 2) {
        await m.addColumn(settingsRows, settingsRows.printerKind);
        await m.addColumn(settingsRows, settingsRows.printerAddress);
        await m.addColumn(settingsRows, settingsRows.printerName);
        await m.addColumn(settingsRows, settingsRows.printerColumns);
        await m.addColumn(businessRows, businessRows.addressLines);
        await m.addColumn(businessRows, businessRows.vatId);
        await m.addColumn(businessRows, businessRows.receiptFooter);
        await m.addColumn(paymentRows, paymentRows.provider);
        await m.addColumn(paymentRows, paymentRows.providerTxCode);
        await m.addColumn(paymentRows, paymentRows.cardScheme);
        await m.addColumn(paymentRows, paymentRows.cardLast4);
        await m.createTable(pendingCardPaymentRows);
      }
      if (from < 3 && to >= 3) {
        await m.createTable(syncStateRows);
      }
      if (from < 4 && to >= 4) {
        // Neu aufbauen, damit business_day_id leer sein darf. Ohne
        // Fremdschlüssel, sonst würde das Löschen der alten Tabelle an den
        // Verweisen von Zeilen und Zahlungen scheitern. Trigger und Index
        // entstehen danach wie in onCreate neu.
        await customStatement('PRAGMA foreign_keys = OFF');
        await transaction(() async {
          for (final action in const ['update', 'delete']) {
            await customStatement('DROP TRIGGER IF EXISTS receipts_no_$action');
          }
          await customStatement(
            'DROP INDEX IF EXISTS receipts_voids_receipt_id',
          );
          await m.alterTable(TableMigration(receiptRows));
          await _createReceiptsVoidsIndex();
          await _createReceiptGuards('receipts');

          await m.addColumn(settingsRows, settingsRows.printerQrAsImage);
          await m.createTable(rksvChainRows);
          await m.createTable(rksvCertificateRows);
          await m.createTable(rksvEntryRows);
          await m.createTable(rksvStateRows);
          await _createRksvGuards();
          await _insertRksvState();

          final broken = await customSelect('PRAGMA foreign_key_check').get();
          if (broken.isNotEmpty) {
            throw StateError(
              'Verweise nach der Migration auf Version 4 kaputt: '
              '${broken.map((r) => r.data).toList()}',
            );
          }
        });
        await customStatement('PRAGMA foreign_keys = ON');
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Höchstens ein Storno je Bon.
  Future<void> _createReceiptsVoidsIndex() => customStatement(
    'CREATE UNIQUE INDEX receipts_voids_receipt_id '
    'ON receipts (voids_receipt_id)',
  );

  Future<void> _createReceiptGuards(String table) async {
    for (final action in const ['UPDATE', 'DELETE']) {
      await customStatement(
        'CREATE TRIGGER ${table}_no_${action.toLowerCase()} '
        'BEFORE $action ON $table BEGIN '
        "SELECT RAISE(ABORT, 'Bons sind unveränderlich'); END",
      );
    }
  }

  /// Protokoll und Zertifikate sind unveränderlich, Ketten nur, solange sie
  /// laufen, und gelöscht wird keine.
  Future<void> _createRksvGuards() async {
    for (final action in const ['UPDATE', 'DELETE']) {
      await customStatement(
        'CREATE TRIGGER rksv_entries_no_${action.toLowerCase()} '
        'BEFORE $action ON rksv_entries BEGIN '
        "SELECT RAISE(ABORT, 'Das Protokoll ist unveränderlich'); END",
      );
      await customStatement(
        'CREATE TRIGGER rksv_certificates_no_${action.toLowerCase()} '
        'BEFORE $action ON rksv_certificates BEGIN '
        "SELECT RAISE(ABORT, 'Zertifikate sind unveränderlich'); END",
      );
    }
    await customStatement(
      'CREATE TRIGGER rksv_chains_no_update_ended '
      'BEFORE UPDATE ON rksv_chains WHEN OLD.ended_at IS NOT NULL BEGIN '
      "SELECT RAISE(ABORT, 'Beendete Ketten sind unveränderlich'); END",
    );
    await customStatement(
      'CREATE TRIGGER rksv_chains_no_delete '
      'BEFORE DELETE ON rksv_chains BEGIN '
      "SELECT RAISE(ABORT, 'Ketten können nicht gelöscht werden'); END",
    );
  }

  Future<void> _insertRksvState() =>
      into(rksvStateRows).insert(const RksvStateRowsCompanion(id: Value(1)));
}
