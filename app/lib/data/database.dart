// SQLite-Datenbank der Kassa (drift). Enthält Katalog, Mitarbeiter und
// Einstellungen, Bons und Geschäftstage und das Protokoll der Signatur (RKSV).

import 'dart:convert';

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

  /// Das Logo vom Server: Kennung der Datei, Pfad auf dem Tablet und die
  /// Farbe als Platzhalter.
  TextColumn get logoFileId => text().nullable()();
  TextColumn get logoPath => text().nullable()();
  TextColumn get logoColor => text().nullable()();

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

  /// Das Foto vom Server: Kennung der Datei und Farbe als Platzhalter.
  TextColumn get photoFileId => text().nullable()();
  TextColumn get photoColor => text().nullable()();
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

  /// Zufällige Kennung dieser Installation, entsteht beim ersten Gebrauch.
  TextColumn get deviceId => text().nullable()();

  /// Wann zuletzt etwas an den Server gesendet wurde.
  DateTimeColumn get lastPushAt => dateTime().nullable()();

  /// Ob "Bilder anzeigen" schon einmal von selbst eingeschaltet wurde (beim
  /// ersten Foto vom Server, siehe `FileSync`). Das geschieht nur ein Mal;
  /// danach gilt, was am Tablet eingestellt wird.
  BoolColumn get photosAutoEnabled =>
      boolean().withDefault(const Constant(false))();

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

  /// Wer die Kette signiert: `probe` (Probe-Signatur auf dem Tablet),
  /// `atrustTest` (Testsystem von A-Trust) oder `atrust`. Siehe `RksvUnit`.
  TextColumn get unit => text().withDefault(const Constant('probe'))();
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

/// Was noch an den Server gesendet werden muss. Bons, Tage, Bewegungen und die
/// Signatur trägt die Datenbank selbst ein (Trigger in
/// `_createOutboxTriggers`), Artikel-Änderungen der `OutboxRepository`. Der
/// Inhalt steht nicht hier, er wird beim Senden aus den Tabellen gelesen.
class OutboxRows extends Table {
  @override
  String get tableName => 'outbox';

  IntColumn get id => integer().autoIncrement()();

  /// `receipt`, `day`, `cash_movement`, `item_change`, `report`,
  /// `rksv_certificate` oder `rksv_chain`.
  TextColumn get kind => text()();

  /// Kennung der Sache (bei Artikel-Änderungen die Artikel-Kennung).
  TextColumn get ref => text()();

  /// Nur bei Artikel-Änderungen: Feld, Wert als JSON und Zeitpunkt.
  TextColumn get field => text().nullable()();
  TextColumn get value => text().nullable()();
  DateTimeColumn get changedAt => dateTime().nullable()();

  /// Zählt hoch, wenn sich die Sache ändert, solange der Eintrag wartet.
  IntColumn get rev => integer().withDefault(const Constant(0))();

  /// `pending` oder `rejected`.
  TextColumn get state => text().withDefault(const Constant('pending'))();
  TextColumn get reason => text().nullable()();
}

/// Berichte (Fehler, Ergebnis von "Geräte testen"), die an den Server gehen.
class ReportRows extends Table {
  @override
  String get tableName => 'reports';

  TextColumn get id => text()();

  /// `error` oder `device_test`.
  TextColumn get kind => text()();
  DateTimeColumn get at => dateTime()();
  TextColumn get appVersion => text()();
  TextColumn get androidVersion => text().nullable()();
  TextColumn get deviceModel => text().nullable()();

  /// Wie oft derselbe Fehler (gleiche `signature`) aufgetreten ist.
  IntColumn get count => integer().withDefault(const Constant(1))();
  TextColumn get signature => text()();

  /// Inhalt als JSON.
  TextColumn get content => text()();

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
    OutboxRows,
    ReportRows,
  ],
)
class KassaDatabase extends _$KassaDatabase {
  KassaDatabase(super.e);

  @override
  int get schemaVersion => 6;

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
      await _createOutboxIndex();
      await _createOutboxTriggers();
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
        // Mit dem Stand von Version 3 anlegen, nicht mit dem heutigen: die
        // Spalten von Version 6 kommen unten dazu.
        await customStatement(
          'CREATE TABLE IF NOT EXISTS "sync_state" ("id" INTEGER NOT NULL, '
          '"register_id" TEXT NULL, "register_name" TEXT NULL, '
          '"business_id" TEXT NULL, '
          '"pull_cursor" INTEGER NOT NULL DEFAULT 0, '
          '"initial_pull_done" INTEGER NOT NULL DEFAULT 0 '
          'CHECK ("initial_pull_done" IN (0, 1)), '
          '"last_pull_at" INTEGER NULL, "last_error" TEXT NULL, '
          '"blocked" INTEGER NOT NULL DEFAULT 0 '
          'CHECK ("blocked" IN (0, 1)), PRIMARY KEY ("id"))',
        );
      }
      if (from < 4 && to >= 4) {
        // Neu aufbauen, damit business_day_id leer sein darf. Ohne
        // Fremdschlüssel, sonst würde das Löschen der alten Tabelle an den
        // Verweisen von Zeilen und Zahlungen scheitern. Trigger und Index
        // entstehen danach wie in onCreate neu.
        await customStatement('PRAGMA foreign_keys = OFF');
        // Alte kaputte Verweise, die die Migration nicht verursacht hat,
        // dürfen sie nicht aufhalten; nur neue zählen (siehe unten).
        final brokenBefore = await _brokenReferences();
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
          // In der Form von Version 4: createTable legte die heutige Form an,
          // und Schritt 5 fände seine Spalte schon vor.
          await customStatement(_rksvChainsV4);
          await m.createTable(rksvCertificateRows);
          await m.createTable(rksvEntryRows);
          await m.createTable(rksvStateRows);
          await _createRksvGuards();
          await _insertRksvState();

          final brokenAfter = await _brokenReferences();
          final added = [
            for (final MapEntry(:key, :value) in brokenAfter.entries)
              if (value > (brokenBefore[key] ?? 0)) key,
          ];
          if (added.isNotEmpty) {
            throw StateError(
              'Verweise nach der Migration auf Version 4 kaputt: $added',
            );
          }
        });
        await customStatement('PRAGMA foreign_keys = ON');
      }
      if (from < 5 && to >= 5) {
        // Vorhandene Ketten signiert die Probe-Signatur. ADD COLUMN lässt die
        // Trigger der Tabelle stehen. Drift schreibt user_version erst danach
        // und ohne Transaktion darum: Wurde die App dazwischen beendet, ist
        // die Spalte schon da, und der Schritt fügt sie nicht noch einmal ein.
        final columns = await customSelect('PRAGMA table_info(rksv_chains)')
            .get();
        if (!columns.any((c) => c.read<String>('name') == 'unit')) {
          await m.addColumn(rksvChainRows, rksvChainRows.unit);
        }
      }
      if (from < 6 && to >= 6) {
        // Ganz oder gar nicht: drift setzt die Version erst nach allen
        // Schritten, ein halber Schritt würde beim nächsten Start an den
        // schon vorhandenen Spalten scheitern. Was hier angelegt wird, hat
        // die Form von Version 6. Drift schreibt user_version danach und ohne
        // Transaktion darum: Wurde die App dazwischen beendet, ist der Schritt
        // schon ganz da (die Liste gibt es nur dann), und er läuft nicht noch
        // einmal.
        final done = await customSelect(
          "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'outbox'",
        ).get();
        if (done.isEmpty) await _stepTo6(m);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Schritt 6 in einer Transaktion.
  Future<void> _stepTo6(Migrator m) async {
    await transaction(() async {
      await m.addColumn(itemRows, itemRows.photoFileId);
      await m.addColumn(itemRows, itemRows.photoColor);
      await m.addColumn(businessRows, businessRows.logoFileId);
      await m.addColumn(businessRows, businessRows.logoPath);
      await m.addColumn(businessRows, businessRows.logoColor);
      await m.addColumn(syncStateRows, syncStateRows.deviceId);
      await m.addColumn(syncStateRows, syncStateRows.lastPushAt);
      await m.addColumn(syncStateRows, syncStateRows.photosAutoEnabled);
      await m.createTable(outboxRows);
      await m.createTable(reportRows);
      await _createOutboxIndex();
      await _createOutboxTriggers();
      await _fillOutboxWithExisting();
    });
  }

  /// `rksv_chains`, wie Version 4 sie angelegt hat (ohne `unit`).
  static const _rksvChainsV4 =
      'CREATE TABLE "rksv_chains" ("chain" INTEGER NOT NULL, '
      '"mode" TEXT NOT NULL, "cash_box_id" TEXT NOT NULL, '
      '"zda_id" TEXT NOT NULL, "cert_serial" TEXT NOT NULL '
      'REFERENCES rksv_certificates(serial_hex), '
      '"started_at" INTEGER NOT NULL, "ended_at" INTEGER NULL, '
      'PRIMARY KEY(chain))';

  /// Zahl der kaputten Verweise je Tabelle, Zieltabelle und Fremdschlüssel.
  /// Gezählt statt nach rowid verglichen, weil der Neuaufbau einer Tabelle
  /// die rowids neu vergeben darf.
  Future<Map<String, int>> _brokenReferences() async {
    final rows = await customSelect('PRAGMA foreign_key_check').get();
    final counts = <String, int>{};
    for (final row in rows) {
      final key =
          '${row.data['table']} -> ${row.data['parent']} '
          '(${row.data['fkid']})';
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

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

  /// Eine Zeile je Sache; nur Artikel-Änderungen dürfen mehrfach vorkommen.
  Future<void> _createOutboxIndex() => customStatement(
    'CREATE UNIQUE INDEX outbox_entity ON outbox (kind, ref) '
    "WHERE kind <> 'item_change'",
  );

  /// Jede Zeile, die gesendet werden muss, stellt sich selbst in die Liste,
  /// in derselben Transaktion: zuerst `rev` einer wartenden (oder abgelehnten)
  /// Zeile anheben, sonst eine neue anlegen. So geht eine Änderung nicht
  /// verloren, die während des Sendens geschieht, und kein Schreiber im Code
  /// kann es vergessen. Ein Bon nimmt seinen Eintrag im Protokoll mit.
  Future<void> _createOutboxTriggers() async {
    Future<void> trigger(
      String table,
      String event,
      String kind,
      String ref,
    ) => customStatement(
      'CREATE TRIGGER outbox_${table}_${event.toLowerCase()} '
      'AFTER $event ON $table BEGIN '
      // `kind <> 'item_change'` lässt das UPDATE den Teilindex outbox_entity
      // nehmen, sonst liest es die ganze Liste.
      'UPDATE outbox SET rev = rev + 1 '
      "WHERE kind = '$kind' AND kind <> 'item_change' AND ref = $ref; "
      "INSERT OR IGNORE INTO outbox (kind, ref) VALUES ('$kind', $ref); END",
    );
    await trigger('receipts', 'INSERT', 'receipt', 'NEW.id');
    await trigger('rksv_entries', 'INSERT', 'receipt', 'NEW.receipt_id');
    await trigger('business_days', 'INSERT', 'day', 'NEW.id');
    await trigger('business_days', 'UPDATE', 'day', 'NEW.id');
    await trigger('cash_movements', 'INSERT', 'cash_movement', 'NEW.id');
    await trigger(
      'rksv_certificates',
      'INSERT',
      'rksv_certificate',
      'NEW.serial_hex',
    );
    await trigger('rksv_chains', 'INSERT', 'rksv_chain', 'NEW.chain');
    await trigger('rksv_chains', 'UPDATE', 'rksv_chain', 'NEW.chain');
    await trigger('reports', 'INSERT', 'report', 'NEW.id');
    await trigger('reports', 'UPDATE', 'report', 'NEW.id');
  }

  /// Migration auf Version 6: alles Vorhandene einmal in die Liste, in der
  /// Reihenfolge, in der der Server es braucht (Zertifikat und Kette vor den
  /// Bons, der Tag vor seinen Bons). Ist die Kassa schon gekoppelt, kommen die
  /// fünf Felder jedes Artikels als Änderung dazu: seit Stufe 1 lassen sie sich
  /// am Tablet ändern, ohne dass der Server davon erfuhr, und der Stand der
  /// Theke soll gewinnen.
  Future<void> _fillOutboxWithExisting() async {
    for (final sql in const [
      "SELECT 'rksv_certificate', serial_hex FROM rksv_certificates "
          'ORDER BY rowid',
      "SELECT 'rksv_chain', CAST(chain AS TEXT) FROM rksv_chains "
          'ORDER BY chain',
      "SELECT 'day', id FROM business_days ORDER BY opened_at, rowid",
      "SELECT 'cash_movement', id FROM cash_movements "
          'ORDER BY created_at, rowid',
      "SELECT 'receipt', id FROM receipts ORDER BY number",
    ]) {
      await customStatement('INSERT OR IGNORE INTO outbox (kind, ref) $sql');
    }
    final paired = await customSelect(
      'SELECT 1 FROM sync_state WHERE id = 1 AND register_id IS NOT NULL',
    ).get();
    if (paired.isEmpty) return;
    final now = DateTime.now();
    // Liest und schreibt mit den heutigen Tabellenklassen (itemRows,
    // outboxRows). Ändert ein späterer Schritt `items` oder `outbox`, passen
    // sie nicht mehr zur Datei von Version 5: dann muss das hier auf rohes SQL
    // umziehen (oder einen Test 4 -> 7 bekommen).
    // Stillgelegte Artikel nicht: die kennt der Server oft nicht, sie kämen
    // als unknown_item zurück.
    final items = select(itemRows)..where((t) => t.archived.equals(false));
    for (final item in await items.get()) {
      final values = <String, Object>{
        'priceCents': item.priceCents,
        'inSale': item.inSale,
        'favorite': item.favorite,
        'depositCents': item.depositCents,
        'tags': [
          for (final tag in item.tags.split(','))
            if (tag.isNotEmpty) tag,
        ],
      };
      for (final MapEntry(:key, :value) in values.entries) {
        await into(outboxRows).insert(
          OutboxRowsCompanion.insert(
            kind: 'item_change',
            ref: item.id,
            field: Value(key),
            value: Value(jsonEncode(value)),
            changedAt: Value(now),
          ),
        );
      }
    }
  }

  Future<void> _insertRksvState() =>
      into(rksvStateRows).insert(const RksvStateRowsCompanion(id: Value(1)));
}
