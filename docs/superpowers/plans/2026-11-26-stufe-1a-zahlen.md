# Stufe 1a: Zahlen (gemischt zahlen, Trinkgeld, Rabatt, freier Betrag) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ein Bon kann mehrere Zahlungen tragen (Teil bar, Rest Karte), die Kassa nimmt Trinkgeld bei Kartenzahlung, gibt Rabatt auf Zeile oder Bon und verkauft einen freien Betrag. Jede der vier Funktionen ist pro Kassa schaltbar und nach dem Update aus. Abschluss, Monatsabrechnung, Übersicht, Bons und die Verwaltung im Browser rechnen aus den Zahlungen.

**Architecture:** Zahlungen sind eine Liste am Bon (`payments` mit Schlüssel Bon und Stelle), das Trinkgeld hängt an der Kartenzahlung, der Rabatt steht an jeder Zeile (der Bon-Rabatt wird nach einer festen Regel auf die Zeilen verteilt). Die Rechenregeln sind reines Dart (`domain/discount.dart`, `domain/receipt_rules.dart`, `domain/tip.dart`) und werden beim Schreiben jedes Bons geprüft. Der Bon geht als `v: 2` zum Server, der `v: 1` weiter versteht und vier Summen-Spalten je Bon führt (Migration `0004`). Die ersten fünf Aufgaben ändern nur Daten und Auswertungen, danach kommen Schalter und Funktionen.

**Tech Stack:** Flutter (flutter_riverpod, drift, `package:material_ui`, gen-l10n), Fastify + PostgreSQL (TypeScript, Node 22, zod, vitest), React 19 + TanStack Query (vitest).

**Spec:** `docs/superpowers/specs/2026-11-26-stufe-1a-zahlen-design.md`. Wer eine Aufgabe umsetzt, liest den genannten Abschnitt der Spec mit.

## Global Constraints

- Zweig `claude/project-thread-jyl5f5`. Kein PR. Nichts wird ausgerollt: weder Server noch Installationsdatei. Das geschieht erst nach Nikos Ja, und dann zuerst der Server, dann die App.
- Plan und alle Doku auf Deutsch mit einfachen Worten. Namen im Code englisch. Texte an der Kassa deutsch mit österreichischen Begriffen (bonieren, Bon, Storno).
- Jeder neue Text an der Kassa steht in allen fünf ARB-Dateien (`de`, `en`, `zh`, `tr`, `ar`), Schlüssel englisch in lowerCamelCase mit Bereich vorn. Nach jeder Änderung an den ARB-Dateien: `~/flutter/bin/flutter gen-l10n` (die Datei `build/l10n_untranslated.json` bleibt leer) und `~/flutter/bin/dart run tool/l10n_review.dart` (sonst scheitert `test/l10n_review_test.dart`). Wörter: Trinkgeld = Tip, 小费, Bahşiş, إكرامية. Rabatt = Discount, 折扣, İndirim, خصم. Freier Betrag = Open amount, 自定义金额, Serbest tutar, مبلغ حر.
- Kundenbon (`receipt_layout.dart`), Berichte (`report_layout.dart`) und die Bildschirme der Einrichtung bleiben Deutsch.
- Tests zuerst (TDD). Kein vorhandener Test verliert eine Erwartung; wo sich nur die Form ändert (`payment` wird `payments`), wird nur die Form angepasst.
- Datenbank am Tablet: Version 7 wird 8, mit Migration und Test auf einer Datenbank aus 1.10.0 (`test/data/fixtures/kassa_v7.sqlite`). Der Schlüssel der Installationsdatei wird nicht angefasst. `app/lib/rksv/` wird nicht angefasst.
- Version: App `1.11.0+13`, Server-Migration `0004`. `0001` bis `0003` nie ändern. Bon im Abgleich `v: 2`; der Server nimmt `v: 1` von Tablets mit 1.10.0 weiter an.
- Alle vier Schalter sind aus, nach dem Update und bei neuer Installation. Sind alle aus, ist kein Tipp und kein Bildschirm anders als in 1.10.0: `test/features/stufe_1a_off_test.dart` (Task 6) bleibt in jeder späteren Aufgabe grün, und vorhandene Goldens ändern sich nicht (Ausnahme: Einstellungen in Task 6).
- Nur Tippen: kein Textfeld im Verkauf (`test/no_text_field_test.dart` bleibt grün). Eingaben über Tasten und die vorhandenen Zahlenfelder (`Keypad`, `KeypadInput`, `TypedAmount`, `AmountEntry`). Tippflächen mindestens 48 dp. Farben und Maße nur aus `KassaTokens`/`KassaColors`, im Web aus `styles/tokens.css`.
- Feste Geld-Regeln (Spec 5.6), im Code geprüft und getestet: Summe der Zahlungen ohne Trinkgeld = Summe des Bons. Summe des Bons = Warenwert nach Rabatt plus Pfand. Beträge je Steuersatz zusammen = Summe des Bons plus Trinkgeld. Höchstens eine Kartenzahlung pro Bon, an letzter Stelle.
- Die Absicherung der Kartenzahlung bekommt keine Lücke: Die offene Zahlung steht in `pending_card_payments`, bevor das Terminal etwas erfährt, und sie trägt Bar-Teil und Trinkgeld. Ab dem Aufruf des Terminals endet jeder Fehler als "unklar", nie als "gescheitert".
- Tests laufen so: am Tablet einzelne Dateien mit `cd app && ~/flutter/bin/flutter test <pfad>`; am Server `server/tool/test-db.sh start`, dann `cd server && npx vitest run test/<datei>` und `npm run typecheck`; im Web `cd web && npm test && npm run typecheck`. Die ganzen Suiten laufen auf GitHub (Workflows `app` und `server`) nach einem Push. Nie Flutter-Tests starten, während im selben Ordner ein APK-Bau läuft.
- Kleine Helfer in den Test-Beispielen, die es noch nicht gibt (`buttonOf`, `switchOf`, `selectedSegment`, `openWithTip`, `openSplit`, `openWithDiscount`, `rows`, `lines`, `daySample`, `randomCart`, `catalogOf`, `discounted`, `mixedDiscounted`, `migrateTo`, `reportKinds`), entstehen im selben Schritt: in der Test-Datei selbst, oder in `test/support/`, wenn eine zweite Datei sie braucht. Sie enthalten keine Erwartungen.
- Nach Änderungen an `database.dart`: `~/flutter/bin/dart run build_runner build`. `flutter analyze` ohne Befund vor jedem Commit.
- Commit-Nachrichten deutsch, Form `Stufe 1a Task N: <was>`, jede endet mit genau diesen zwei Zeilen:
  ```
  Co-Authored-By: Claude Fable 5.2 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01DHykqgFLoUjNABiyhcqtuv
  ```
- Das Repo ist öffentlich: keine Schlüssel, keine Server-Adresse, keine echten Umsätze. Beispiele sind erfunden ("Beispiel-Imbiss").

## Review Focus

1. **Bon, den 1.10.0 schon gesendet hat, kommt nach dem Update noch einmal:** Die Antwort ging verloren oder der Eintrag der Signatur kam später. Das Tablet schickt ihn jetzt als `v: 2`. Der Server antwortet `duplicate`, nicht `conflict`, und schreibt keinen Bericht (Test in Task 4).
2. **Offene Kartenzahlung und Bon-Entwurf aus 1.10.0 über das Update hinweg:** Die Zeile in `pending_card_payments` und der Entwurf haben die alte Form. Nach dem Update lässt sich die Zahlung als "bezahlt" abschließen (ein Bon, eine Kartenzahlung, kein Trinkgeld), und der Entwurf liegt wieder am Bon (Tests in Task 1 und 7).
3. **Karte scheitert nach dem Bar-Teil, dann zahlt der Gast alles bar:** Es entsteht genau ein Bon mit einer Bar-Zahlung über die ganze Summe. Keine offene Zahlung bleibt, der Hinweis "bar zurückgeben" ist weg (Test in Task 8).
4. **Der Bon ändert sich, nachdem ein Rabatt gesetzt wurde:** Menge auf 0, letzte Zeile weg, "Bon leeren" und "Rückgängig", neuer Preis aus dem Abgleich. Ein Prozent-Rabatt rechnet mit, ein Betrag-Rabatt wird gekappt, ein leerer Bon hat keinen Bon-Rabatt mehr, "Rückgängig" bringt die Rabatte zurück (Tests in Task 9 und 11).
5. **Schalter aus oder Mitarbeiter angemeldet, während ein Rabatt oder freier Betrag am offenen Bon liegt:** Der Rabatt bleibt und zählt, seine Reihe ist zu sehen, ein Tipp darauf tut nichts. Die Zeile "Diverses" bleibt und lässt sich mit Minus entfernen (Tests in Task 11 und 12).

---

## File Structure

Neu am Tablet (`app/lib/`):

| Datei | Aufgabe der Datei |
| --- | --- |
| `domain/feature_access.dart` | `FeatureAccess` (aus, alle, nur Chef) und wer eine Funktion sehen darf |
| `domain/receipt_rules.dart` | Die festen Geld-Regeln und die fünf Beträge der Signatur; die einzige Stelle, die sagt, zu welchem Satz das Trinkgeld zählt |
| `domain/discount.dart` | `Discount`, Gründe, das Verteilen auf Cent (`allocate`) |
| `domain/tip.dart` | Vorschläge für "Gast zahlt" und die Grenze für die Nachfrage |
| `features/kassa/tip_sheet.dart` | Blatt "Gast zahlt" vor dem Terminal |
| `features/kassa/card_availability.dart` | Ob und warum "Karte" geht (aus `cart_panel.dart` herausgezogen, auch für "Teil bar") |
| `features/kassa/discount_sheet.dart` | Ein Blatt für Zeilen-Rabatt und Bon-Rabatt |
| `features/kassa/open_amount_sheet.dart` | Blatt "Freier Betrag" |
| `features/settings/payment_section.dart` | Abschnitt "Zahlen" mit den vier Schaltern |

Geändert am Tablet: `data/database.dart` (Version 8), `data/{receipt,card_payment,day,period_report,stats,settings}_repository.dart`, `domain/{receipt,cart,pricing,day,period_report,receipt_layout,report_layout,kitchen_ticket}.dart`, `features/kassa/{sale_service,cart_controller,cart_panel,cart_line_row,cash_sheet,unclear_card_payment,sale_done,kassa_screen}.dart`, `features/bons/{receipt_list,receipt_detail,void_question}.dart`, `features/close/{income_card,cash_movement_sheet,close_format}.dart`, `features/settings/settings_screen.dart`, `sync/push_wire.dart`, `l10n/app_*.arb`.

Server: neu `server/migrations/0004_payments.sql`, `server/src/admin/tips.ts`; geändert `server/src/device/{push,push_schema}.ts`, `server/src/admin/{months,days,overview,receipts}.ts`. Gemeinsam: neu `shared/fixtures/sync/push_request_v2.json`; `shared/fixtures/stats/*.json` bekommen je einen Bon in `v: 2`.

Web: geändert `web/src/api/{receipts,days,months}.ts`, `web/src/pages/{ReceiptsPage,ReceiptDetail,DayDetail,PeriodDetail}.tsx`. `OverviewPage.tsx` und `ReportContent.tsx` bleiben, wie sie sind (die Übersicht bekommt dieselben Felder mit neuen Zahlen; Berichte des Servers zeigt `ReportContent` schon als Text).

Doku: neu `docs/testen/stufe-1a-pruefliste.md`; geändert die Spec (Abschnitt 10), `PRODUCT.md`.

Beispiel-Bons in den Tests (aus `app/test/support/sales.dart`): `cart` = 2 × Cola (5,80 zu 20 %, Pfand 0,50) + Huhn Bowl XXL Nudeln (11,90 zu 10 %), Summe 18,20. `cartCard` = Teigtaschen (6,50 zu 10 %) + Cola (2,90 zu 20 %, Pfand 0,25), Summe 9,65.

---

## Teil 1: Daten und Auswertungen (noch nichts Neues zu sehen)

### Task 1: Datenbank 8 am Tablet mit Migration

Spec 5.6 (Datenbank am Tablet), 5.1 (Vorgaben), 7 (Migration).

**Files:**
- Create: `app/lib/domain/feature_access.dart`, `app/tool/make_kassa_v7_fixture.dart`, `app/test/data/fixtures/kassa_v7.sqlite`, `app/test/data/migration_v8_test.dart`, `app/drift_schemas/drift_schema_v8.json`, `app/test/data/generated_migrations/schema_v8.dart`
- Modify: `app/lib/data/database.dart` (+ `.g.dart`), `app/lib/data/settings_repository.dart`, `app/test/data/generated_migrations/schema.dart`
- Test: `app/test/data/migration_v8_test.dart`, `app/test/data/settings_repository_test.dart`, `app/test/data/migration_test.dart` (bleibt grün)

**Interfaces:**
- Consumes: nichts.
- Produces: die Spalten unten (Namen in drift, in der Datei in snake_case) und

```dart
// domain/feature_access.dart
enum FeatureAccess { off, all, chefOnly;
  /// off: nie. all: jede angemeldete Person. chefOnly: nur Chef. Ohne Anmeldung nie.
  bool allows(Staff? staff);
}
// RegisterSettings, neue Felder mit copyWith; withoutPrinter() und withoutKitchenPrinter() reichen sie durch:
final bool splitPaymentEnabled;        // false
final bool cardTipEnabled;             // false
final FeatureAccess discountAccess;    // off
final FeatureAccess openAmountAccess;  // off
```

| Tabelle | Neue Spalten (Vorgabe) |
| --- | --- |
| `PaymentRows` | `position` int (0), `tipCents` int (0), `tipStaffId` text (leer erlaubt), `tipStaffName` text (leer erlaubt). Schlüssel wird `{receiptId, position}` |
| `ReceiptRows` | `tipCents` int (0), `discountCents` int (0), `discountPercent` int (leer erlaubt), `discountAmountCents` int (0), `discountReason` text (leer erlaubt) |
| `ReceiptLineRows` | `discountCents` int (0), `ownDiscountPercent` int (leer erlaubt), `ownDiscountCents` int (0), `ownDiscountReason` text (leer erlaubt) |
| `PendingCardPaymentRows` | `cashPartCents` int (0), `tipCents` int (0) |
| `SettingsRows` | `splitPayment` bool (false), `cardTip` bool (false), `discountAccess` text (`'off'`), `openAmountAccess` text (`'off'`) |

Regeln für Schritt 8 (`_stepTo8`):
- Eine Transaktion, wie `_stepTo7`. Wiederholbar: Er läuft nur, wenn `PRAGMA table_info(payments)` keine Spalte `position` hat.
- `payments` wird neu aufgebaut (der Schlüssel ändert sich), nach dem Muster von Schritt 4: `PRAGMA foreign_keys = OFF` davor, Trigger `payments_no_update` und `payments_no_delete` weg, `m.alterTable(TableMigration(paymentRows, newColumns: [...]))`, `_createReceiptGuards('payments')`, Prüfung auf neue kaputte Verweise, `PRAGMA foreign_keys = ON` danach. Alle anderen Spalten kommen mit `m.addColumn`.
- Schritt 8 stellt nichts in die Liste "noch zu senden" und ändert `sync_state` nicht.
- Zwei alte Schritte bauen heute mit den Tabellenklassen von heute und fänden die neuen Spalten schon vor: Schritt 2 (`m.createTable(pendingCardPaymentRows)`) und Schritt 4 (`m.alterTable(TableMigration(receiptRows))`). Beide ziehen auf rohes SQL in der Form ihrer Version um (Muster `_rksvChainsV4`; der Wortlaut steht in `test/data/generated_migrations/schema_v2.dart` und `schema_v4.dart`).
- `onCreate` legt `payments` gleich mit dem neuen Schlüssel an (das macht `createAll`).

`make_kassa_v7_fixture.dart` baut die Datei wie `make_kassa_v6_fixture.dart`, aber aus `schema_v7.dart`: derselbe erfundene Inhalt (sechs Bons, einer mit Karte, einer storniert, Einstellungen ungleich den Vorgaben), dazu Sprache `tr` und Küchenbon `receiptPrinter`, eine offene Kartenzahlung (`state = 'started'`, `cart_json` in der Form von 1.10.0, Betrag passend zum Katalog der Datei) und ein `receipt_draft` in der Form von 1.10.0.

- [ ] **Step 1: Datei aus 1.10.0 erzeugen und die Tests schreiben, die scheitern**

`dart run tool/make_kassa_v7_fixture.dart`. Dann `migration_v8_test.dart` (Helfer `userVersion`, `triggerNames`, `copyFixture`, `count` wie in `migration_v7_test.dart`):

```dart
for (final from in [1, 3, 6, 7]) {
  test('Schema: Version $from wird zu Version 8', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final db = KassaDatabase(await verifier.startAt(from));
    await verifier.migrateAndValidate(db, 8);
    await db.close();
  });
}

test('Update von 1.10.0: Zahlungen bekommen Stelle 0, alles andere bleibt', () async {
  final file = await copyFixture('kassa_v7.sqlite');
  // before, triggersBefore, paymentsBefore: an der Datei gezählt und gelesen, wie im Test für Version 7
  final db = KassaDatabase(NativeDatabase(file));
  addTearDown(db.close);
  expect(await userVersion(db), 8);
  final payments = await db.select(db.paymentRows).get();
  expect(payments.length, before['payments']);
  expect(payments.every((p) => p.position == 0 && p.tipCents == 0 && p.tipStaffId == null && p.tipStaffName == null), isTrue);
  expect([for (final p in payments) (p.receiptId, p.kind, p.amountCents, p.givenCents, p.changeCents, p.providerTxCode)], paymentsBefore);
  final pk = await db.customSelect("SELECT name FROM pragma_table_info('payments') WHERE pk > 0 ORDER BY pk").get();
  expect([for (final r in pk) r.read<String>('name')], ['receipt_id', 'position']);
  final receipts = await db.select(db.receiptRows).get();
  expect(receipts.every((r) => r.tipCents == 0 && r.discountCents == 0 && r.discountPercent == null && r.discountAmountCents == 0 && r.discountReason == null), isTrue);
  final lines = await db.select(db.receiptLineRows).get();
  expect(lines.every((l) => l.discountCents == 0 && l.ownDiscountPercent == null && l.ownDiscountCents == 0 && l.ownDiscountReason == null), isTrue);
  for (final MapEntry(:key, :value) in before.entries) {
    expect(await count(db, key), value, reason: key);   // auch 'outbox' und 'pending_card_payments'
  }
  expect(await triggerNames(db), triggersBefore);
  await expectLater(db.customStatement('UPDATE payments SET amount_cents = 1'), throwsA(isA<SqliteException>()));
  await expectLater(db.customStatement('DELETE FROM payments'), throwsA(isA<SqliteException>()));
  expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
});

test('Update von 1.10.0: alle vier Schalter sind aus, alte Einstellungen bleiben', () async {
  final db = KassaDatabase(NativeDatabase(await copyFixture('kassa_v7.sqlite')));
  addTearDown(db.close);
  final s = await SettingsRepository(db).current();
  expect((s.splitPaymentEnabled, s.cardTipEnabled, s.discountAccess, s.openAmountAccess), (false, false, FeatureAccess.off, FeatureAccess.off));
  expect((s.language, s.kitchenMode, s.voidRequiresChef, s.printerColumns), (AppLanguage.tr, KitchenMode.receiptPrinter, true, 42));
});

test('Update von 1.10.0: offene Kartenzahlung und Entwurf bleiben lesbar', () async {
  final db = KassaDatabase(NativeDatabase(await copyFixture('kassa_v7.sqlite')));
  addTearDown(db.close);
  final p = (await db.select(db.pendingCardPaymentRows).get()).single;
  expect((p.cashPartCents, p.tipCents, p.state), (0, 0, 'started'));
  expect(p.amountCents, pendingAmountBefore);
  expect((await db.select(db.settingsRows).getSingle()).receiptDraft, draftBefore);
});
```

Dazu: `'Schritt 8 ist wiederholbar'` (Version in der Datei auf 7 zurücksetzen, neu öffnen: Version 8, Zahl der Zahlungen gleich, ein inzwischen gespeicherter Schalter bleibt an), `'neue Datenbank: Version 8, alle Schalter aus'`, `'zwei Zahlungen an einem Bon gehen, dieselbe Stelle zweimal nicht'` (zweites `INSERT` mit `position = 1` geht, noch einmal `position = 1` wirft `SqliteException`). In `settings_repository_test.dart`: `'die vier Schalter: speichern und lesen'` und `'unbekannter Text in discount_access gibt off'`. Für `FeatureAccess.allows`: `off` nie, `all` für Anna und Chef, `chefOnly` nur für den Chef, `null` nie.

- [ ] **Step 2: Laufen lassen, sie scheitern**

Run: `cd app && ~/flutter/bin/flutter test test/data/migration_v8_test.dart`
Expected: FAIL (kein `schema_v8.dart`, keine Spalte `position`).

- [ ] **Step 3: Umsetzen**

Tabellen und `schemaVersion => 8`, `_stepTo8`, Schritt 2 und 4 auf rohes SQL, `FeatureAccess`, die vier Felder in `RegisterSettings` und `SettingsRepository` (`enumByNameOr` mit `FeatureAccess.off`). Dann `dart run build_runner build`, Abzug mit `dart run drift_dev schema dump lib/data/database.dart drift_schemas/` und Test-Schemas mit `dart run drift_dev schema generate drift_schemas/ test/data/generated_migrations/` (wie bei Version 7).

- [ ] **Step 4: Laufen lassen, alles grün**

Run: `cd app && ~/flutter/bin/flutter test test/data/ && ~/flutter/bin/flutter analyze`
Expected: PASS, auch `migration_test.dart`, `migration_v5_test.dart`, `migration_v6_test.dart`, `migration_v7_test.dart` ohne Änderung.

- [ ] **Step 5: Commit** mit dem Titel `Stufe 1a Task 1: Datenbank 8 am Tablet mit Migration` (`git add app/`).

### Task 2: Bon mit Zahlungen als Liste und die festen Regeln

Spec 5.6 (feste Regeln), 5.3 (Signatur), 5.4a (Storno und Trinkgeld), 5.2 (höchstens eine Karte, zuletzt).

**Files:**
- Create: `app/lib/domain/receipt_rules.dart`, `app/test/domain/receipt_rules_test.dart`
- Modify: `app/lib/domain/receipt.dart`, `app/lib/data/receipt_repository.dart`, `app/lib/domain/receipt_layout.dart`, `app/lib/features/kassa/{sale_service,sale_done,unclear_card_payment}.dart`, `app/lib/features/bons/{receipt_list,receipt_detail,void_question}.dart`, `app/test/support/{sales,rksv_rig}.dart` und jede Testdatei, die `Receipt(payment: ...)` oder `.payment` nutzt
- Test: `app/test/domain/receipt_rules_test.dart`, `app/test/data/receipt_repository_test.dart`, `app/test/rksv/rksv_journal_test.dart`

**Interfaces:**
- Consumes: Spalten aus Task 1.
- Produces:

```dart
// domain/receipt.dart
class Payment {
  const Payment({this.position = 0, required this.kind, required this.amountCents, required this.givenCents,
      required this.changeCents, this.tipCents = 0, this.tipStaffId, this.tipStaffName,
      this.provider, this.providerTxCode, this.cardScheme, this.cardLast4});
  final int position;
  final int amountCents;      // Anteil an der Summe des Bons, ohne Trinkgeld
  final int tipCents;         // nur bei Karte ungleich 0
  final String? tipStaffId;   // wem das Trinkgeld gehört, leer ohne Trinkgeld
  final String? tipStaffName;
  int get chargedCents;       // amountCents + tipCents: was die Karte gebucht hat
}
enum ReceiptPaymentKind { cash, card, mixed }
class Receipt {
  Receipt({..., required List<Payment> payments, ...});   // ersetzt `payment`
  final List<Payment> payments;            // nach Stelle, leer bei Sonderbelegen
  Payment? get cashPayment;                // die erste Bar-Zahlung
  Payment? get cardPayment;                // die Kartenzahlung
  ReceiptPaymentKind? get paymentKind;     // null bei Sonderbelegen
  int get cashCents;  int get cardCents;   // Summen von amountCents je Art
  int get tipCents;                        // Summe von tipCents
}

// domain/receipt_rules.dart (reines Dart)
/// Die einzige Stelle, die sagt, zu welchem Satz das Trinkgeld bei der Signatur zählt (Spec 5.3 und 9).
const tipSignatureRate = TaxRate.zero;
/// Die fünf Beträge in der Reihenfolge 20, 10, 13, 0, 19: Zeilen je Satz, Pfand zu 0, Trinkgeld zu [tipSignatureRate].
List<int> codeSums({required Iterable<Map<TaxRate, int>> lineGross, required int depositCents, required int tipCents});
enum ReceiptRule { paymentsEqualTotal, totalIsGoodsPlusDeposit, ratesEqualGoods, oneCardLast, tipOnlyOnCard, positions }
class ReceiptRuleViolation implements Exception { const ReceiptRuleViolation(this.rule); final ReceiptRule rule; }
/// Wirft bei der ersten verletzten Regel. Ein Bon ohne Zeilen und Zahlungen mit Summe 0 (Sonderbeleg) besteht.
void checkReceiptRules({required int goodsCents, required int depositCents, required int totalCents,
    required List<ReceiptLine> lines, required List<Payment> payments});

// data/receipt_repository.dart
Future<Receipt> finalizeCashSale({required String saleId, required Cart cart, required int givenCents, required Staff staff}); // unverändert
Future<Receipt> finalizeCardSale({required String saleId, required Cart cart, required Staff staff, required String provider,
    String? txCode, String? cardScheme, String? cardLast4, int cashPartCents = 0, int tipCents = 0});
```

Regeln:
- `checkReceiptRules`: Summe `amountCents` = `totalCents`; `totalCents` = `goodsCents + depositCents`; Summe aller Zeilen-Beträge je Satz = `goodsCents` (daraus folgt mit `codeSums`: die fünf Beträge = Summe plus Trinkgeld); höchstens eine Zahlung `card`, an letzter Stelle; `tipCents != 0` nur bei `card`; Stellen sind 0, 1, 2 … ohne Lücke.
- `_write` nimmt `payments` statt `payment`, ruft `checkReceiptRules` bei jedem Verkauf und Storno (heute wird nur mit laufender Signatur geprüft) und rechnet die Beträge für die Signatur mit `codeSums`. Es schreibt `receipts.tip_cents` als Summe der Zahlungen.
- `finalizeCardSale`: `0 <= cashPartCents < cart.totalCents` und `tipCents >= 0`, sonst `ArgumentError`. Mit Bar-Teil: Zahlung 0 `cash` (Betrag = gegeben = Bar-Teil, Rückgeld 0), Zahlung 1 `card` über den Rest. Die Karte trägt `tipCents`; bei Trinkgeld über 0 sind `tipStaffId`/`tipStaffName` die Bedienung des Bons.
- `voidReceipt` spiegelt jede Zahlung: Betrag und Trinkgeld mit Minus, gegeben und Rückgeld 0, Kartendaten und "Trinkgeld für" vom stornierten Bon (nicht von der Person, die storniert).
- `_hydrate` liest die Zahlungen nach `position`.
- Alle Stellen, die heute `receipt.payment` lesen, nutzen die neuen Getter und verhalten sich bei einer Zahlung genau wie bisher. `layoutReceipt` druckt die Zahlungen in ihrer Reihenfolge im heutigen Format ("Gegeben" und "Rückgeld" nur, wenn die Bar-Zahlung die einzige ist).
- `RksvRig.sellCard` und `TestShop.sellCard` bekommen `cashPartCents` und `tipCents` (Vorgabe 0).

- [ ] **Step 1: Die Tests schreiben, die scheitern**

```dart
// receipt_rules_test.dart
test('codeSums: Pfand und Trinkgeld zählen zum Satz 0', () {
  expect(codeSums(lineGross: [{TaxRate.normal: 580}, {TaxRate.reduced1: 1190}], depositCents: 50, tipCents: 80),
      [580, 1190, 0, 130, 0]);
  expect(tipSignatureRate, TaxRate.zero);
});
test('jede feste Regel hat einen Bon, der an ihr scheitert', () {
  ReceiptRule? broken({int goods = 1770, int deposit = 50, int total = 1820, List<Payment>? payments}) { /* ruft checkReceiptRules mit den Zeilen von `cart`, gibt die Regel der Ausnahme zurück */ }
  const cash = PaymentKind.cash, card = PaymentKind.card;
  Payment p(int pos, PaymentKind k, int a, {int tip = 0}) => Payment(position: pos, kind: k, amountCents: a, givenCents: 0, changeCents: 0, tipCents: tip);
  expect(broken(payments: [p(0, cash, 1000), p(1, card, 820, tip: 80)]), isNull);
  expect(broken(payments: [p(0, cash, 1000), p(1, card, 800)]), ReceiptRule.paymentsEqualTotal);
  expect(broken(total: 1830, payments: [p(0, cash, 1830)]), ReceiptRule.totalIsGoodsPlusDeposit);
  expect(broken(goods: 1760, total: 1810, payments: [p(0, cash, 1810)]), ReceiptRule.ratesEqualGoods);
  expect(broken(payments: [p(0, card, 820), p(1, cash, 1000)]), ReceiptRule.oneCardLast);
  expect(broken(payments: [p(0, card, 1000), p(1, card, 820)]), ReceiptRule.oneCardLast);
  expect(broken(payments: [p(0, cash, 1820, tip: 10)]), ReceiptRule.tipOnlyOnCard);
  expect(broken(payments: [p(0, cash, 1000), p(2, card, 820)]), ReceiptRule.positions);
});

// receipt_repository_test.dart
test('Teil bar, Rest Karte mit Trinkgeld: zwei Zahlungen, Karte zuletzt', () async {
  final r = await shop.receipts.finalizeCardSale(saleId: 'm1', cart: cart, staff: shop.anna,
      provider: 'sumup', txCode: 'TX1', cashPartCents: 1000, tipCents: 80);
  expect(r.totalCents, 1820);
  expect([for (final p in r.payments) (p.position, p.kind, p.amountCents, p.tipCents)],
      [(0, PaymentKind.cash, 1000, 0), (1, PaymentKind.card, 820, 80)]);
  expect((r.payments[1].tipStaffId, r.payments[1].chargedCents), (shop.anna.id, 900));
  expect((r.cashCents, r.cardCents, r.tipCents, r.paymentKind), (1000, 820, 80, ReceiptPaymentKind.mixed));
  expect((await shop.db.select(shop.db.receiptRows).getSingle()).tipCents, 80);
});
test('Storno spiegelt jede Zahlung und das Trinkgeld; es bleibt bei der Person, die kassiert hat', () async {
  await shop.receipts.finalizeCardSale(saleId: 'm1', cart: cart, staff: shop.anna, provider: 'sumup', cashPartCents: 1000, tipCents: 80);
  final v = await shop.receipts.voidReceipt('m1', staff: shop.chef);
  expect([for (final p in v.payments) (p.kind, p.amountCents, p.tipCents, p.givenCents, p.changeCents)],
      [(PaymentKind.cash, -1000, 0, 0, 0), (PaymentKind.card, -820, -80, 0, 0)]);
  expect((v.payments[1].tipStaffId, v.staffId), (shop.anna.id, shop.chef.id));
});
test('Bar-Teil gleich der Summe, negativ, oder Trinkgeld negativ: ArgumentError, nichts gespeichert', ...);
test('ein Bon aus 1.10.0 (eine Zahlung, Stelle 0) lässt sich lesen und stornieren', ...);   // Zeilen direkt eingefügt wie TestShop.insertCardReceipt

// rksv_journal_test.dart
test('Trinkgeld: der Umsatzzähler steigt um Summe plus Trinkgeld, die Kette prüft sich', () async {
  final before = (await rig.stateRow()).counterCents;
  await rig.sellCard('t1', cart, tipCents: 80);
  expect((await rig.stateRow()).counterCents, before + 1900);
  await rig.receipts.voidReceipt('t1', staff: rig.chef);
  expect((await rig.stateRow()).counterCents, before);
  await rig.verifyChain(1);
});
```

- [ ] **Step 2: Laufen lassen, sie scheitern**

Run: `cd app && ~/flutter/bin/flutter test test/domain/receipt_rules_test.dart test/data/receipt_repository_test.dart`
Expected: FAIL (`receipt_rules.dart` und `payments` gibt es nicht).

- [ ] **Step 3: Umsetzen** nach den Signaturen und Regeln oben.

- [ ] **Step 4: Laufen lassen, alles grün**

Run: `cd app && ~/flutter/bin/flutter test test/domain/ test/data/ test/rksv/rksv_journal_test.dart test/features/sale_service_test.dart test/features/bons_test.dart test/features/card_test.dart test/features/cash_test.dart test/features/unclear_card_test.dart && ~/flutter/bin/flutter analyze`
Expected: PASS. Kein Golden ändert sich.

- [ ] **Step 5: Commit** `Stufe 1a Task 2: Bon mit Zahlungen als Liste und feste Regeln`.

### Task 3: Auswertungen am Tablet lesen aus den Zahlungen

Spec 5.7 (Bar und Karte aus den Zahlungen; Bons: "Bar + Karte", Filter), 6 Punkt 2.

**Files:**
- Modify: `app/lib/data/{day_repository,period_report_repository,stats_repository}.dart`, `app/lib/domain/{day,period_report}.dart` (nur die Kommentare zur Zählung), `app/lib/features/bons/{receipt_list,receipt_detail}.dart`, `app/lib/l10n/app_*.arb`
- Test: `app/test/data/{day_repository,period_report_repository,stats_repository}_test.dart`, `app/test/features/bons_test.dart`

**Interfaces:**
- Consumes: `finalizeCardSale(cashPartCents:, tipCents:)`, `Receipt.paymentKind`, `Receipt.payments` aus Task 2.
- Produces: `String receiptPaymentLabel(L10n l, Receipt r)` in `receipt_list.dart` ("Bar", "Karte", "Bar + Karte"); ARB-Schlüssel `bonsCashAndCard` ("Bar + Karte"). Die Felder von `DaySummary`, `PeriodReport` und `Overview` behalten ihre Namen.

Regeln (gleich in allen drei Repositories):
- `cashRevenueCents`/`cashCents` = Summe `amount_cents` der Zahlungen `cash`, `cardRevenueCents`/`cardCents` = Summe der Zahlungen `card` (ohne Trinkgeld), je über die gezählten Bons. Storno-Bons haben negative Zahlungen und ziehen ab.
- `cashReceiptCount` zählt Bons mit mindestens einer Bar-Zahlung, `cardReceiptCount` Bons mit einer Kartenzahlung (Verkauf +1, Storno −1). Ein gemischter Bon zählt in beiden, in `receiptCount` einmal.
- `revenueCents` bleibt die Summe von `total_cents` (ohne Trinkgeld). `expectedCashCents` = Wechselgeld + Bar-Zahlungen + Einlagen − Entnahmen.
- Bons: Die Filter "Bar" und "Karte" zeigen einen gemischten Bon beide. Die Pille zeigt `receiptPaymentLabel`. Das Detail listet jede Zahlung in ihrer Reihenfolge (Schlüssel `detail-payment-<Stelle>`), "Gegeben" und "Rückgeld" wie bisher nur bei einer einzigen Bar-Zahlung.

- [ ] **Step 1: Die Tests schreiben, die scheitern**

```dart
// day_repository_test.dart
test('gemischter Bon: Bar und Karte kommen aus den Zahlungen, Trinkgeld zählt nicht zum Umsatz', () async {
  await shop.days.setOpeningFloat(10000);
  await shop.sell('a');                                              // bar 18,20
  await shop.sellCard('b');                                          // Karte 9,65
  await shop.sellCard('m1', cart: cart, cashPartCents: 1000, tipCents: 80);
  final s = (await shop.days.summary())!;
  expect((s.revenueCents, s.cashRevenueCents, s.cardRevenueCents), (4605, 2820, 1785));
  expect((s.receiptCount, s.cashReceiptCount, s.cardReceiptCount), (3, 2, 2));
  expect(s.expectedCashCents, 10000 + 2820);
});
test('Storno des gemischten Bons nimmt beide Teile zurück', () async {
  // wie oben, dann:
  await shop.receipts.voidReceipt('m1', staff: shop.chef);
  final s = (await shop.days.summary())!;
  expect((s.revenueCents, s.cashRevenueCents, s.cardRevenueCents), (2785, 1820, 965));
  expect((s.receiptCount, s.cashReceiptCount, s.cardReceiptCount, s.voidCount, s.voidedCents), (2, 1, 1, 1, 1820));
  expect(s.expectedCashCents, 10000 + 1820);
});
```

Dieselben drei Bons in `stats_repository_test.dart` (`'Übersicht: Zahlungsarten aus den Zahlungen'`: `revenueCents 4605`, `cashCents 2820`, `cardCents 1785`) und in `period_report_repository_test.dart` (`'Monat mit gemischtem Bon'`, Bons im Vormonat wie in den vorhandenen Tests: `cashRevenueCents 2820`, `cardRevenueCents 1785`, `cashReceiptCount 2`, `cardReceiptCount 2`). In `bons_test.dart`:

```dart
testWidgets('gemischter Bon: Pille "Bar + Karte", zu sehen unter "Bar" und unter "Karte"', (t) async {
  // Bons öffnen mit einem gemischten Bon Nr. 1 (Muster der Datei, Bon über das Repository angelegt)
  expect(find.descendant(of: find.byKey(const Key('receipt-1')), matching: find.text('Bar + Karte')), findsOneWidget);
  for (final f in ['bar', 'karte']) {
    await t.tap(find.byKey(Key('filter-$f')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('receipt-1')), findsOneWidget);
  }
  await t.tap(find.byKey(const Key('receipt-1')));
  await t.pumpAndSettle();
  expect(find.byKey(const Key('detail-payment-0')), findsOneWidget);
  expect(find.byKey(const Key('detail-payment-1')), findsOneWidget);
});
```

- [ ] **Step 2: Laufen lassen, sie scheitern**

Run: `cd app && ~/flutter/bin/flutter test test/data/day_repository_test.dart test/data/stats_repository_test.dart test/data/period_report_repository_test.dart test/features/bons_test.dart`
Expected: FAIL (der gemischte Bon zählt ganz zur Karte: `cashRevenueCents` ist 1820 statt 2820).

- [ ] **Step 3: Umsetzen** nach den Regeln oben; `bonsCashAndCard` in fünf Sprachen, `gen-l10n`, `l10n_review`.

- [ ] **Step 4: Laufen lassen, alles grün**

Run: dieselben Dateien, dazu `test/features/close_test.dart test/features/close_month_test.dart test/features/overview_test.dart test/l10n_review_test.dart`, `flutter analyze`.
Expected: PASS.

- [ ] **Step 5: Commit** `Stufe 1a Task 3: Auswertungen am Tablet lesen aus den Zahlungen`.

### Task 4: Abgleich `v: 2` und der Server nimmt beide Formen

Spec 5.6 (Abgleich, Server-Migration 0004), 7 (Server: `v: 1` und `v: 2`, Migration mit alten Bons).

**Files:**
- Create: `server/migrations/0004_payments.sql`, `shared/fixtures/sync/push_request_v2.json`
- Modify: `app/lib/sync/push_wire.dart`, `server/src/device/push_schema.ts`, `server/src/device/push.ts`, `server/test/support/push.ts`
- Test: `app/test/sync/push_wire_test.dart`, `server/test/push.test.ts`, `server/test/sync_fixtures.test.ts`, `server/test/migrate.test.ts`

**Interfaces:**
- Consumes: Spalten aus Task 1 (Rabatt-Spalten stehen bis Task 10 auf ihren Vorgaben und gehen so hinaus).
- Produces: die Form `v: 2` und die Spalten am Server.

```jsonc
// Eintrag `receipt`, v: 2. Alle Felder von v: 1 bleiben, außer `payment`.
{ "v": 2, /* id … totalCents, test wie v: 1; goodsCents ist der Warenwert nach Rabatt */
  "tipCents": 64, "discountCents": 284,
  "discount": { "percent": 10, "amountCents": 165, "reason": "promotion" },      // Bon-Rabatt oder null
  "lines": [ { /* wie v: 1 */ "discountCents": 226,
               "discount": { "percent": 10, "amountCents": 119, "reason": "regular" } } ],   // eigener Rabatt oder null
  "payments": [ { "position": 0, "kind": "cash", "amountCents": 1000, "givenCents": 1000, "changeCents": 0, "tipCents": 0,
                  "tipStaffId": null, "tipStaffName": null, "provider": null, "providerTxCode": null, "cardScheme": null, "cardLast4": null } ],
  "rksv": null }
```

```ts
// push_schema.ts
export type ParsedReceiptV1; export type ParsedReceiptV2; export type ParsedReceipt = ParsedReceiptV1 | ParsedReceiptV2;
export const receiptEntry;   // z.object({ receipt: z.discriminatedUnion('v', [receiptV1, receiptV2]) })
/** Zahlungsart und Summen für die Spalten von `receipts`. */
export function paymentColumns(r: ParsedReceipt): { paymentKind: 'cash' | 'card' | 'mixed' | null; cashCents: number; cardCents: number; tipCents: number; discountCents: number };
/** Ein v2-Bon in der Form von v1, wenn er sich so schreiben lässt (höchstens eine Zahlung, kein Trinkgeld, kein Rabatt), sonst null. */
export function asV1(r: ParsedReceiptV2): ParsedReceiptV1 | null;
```

```sql
-- 0004_payments.sql
alter table receipts add column cash_cents int not null default 0, add column card_cents int not null default 0,
                     add column tip_cents int not null default 0, add column discount_cents int not null default 0;
alter table receipt_lines add column discount_cents int not null default 0, add column discount jsonb;
-- Alte Bons füllen: receipts ist unveränderlich (Trigger receipts_immutable), darum für diese eine Änderung aus.
alter table receipts disable trigger receipts_immutable;
update receipts set cash_cents = total_cents where kind in ('sale', 'voided') and payment_kind = 'cash';
update receipts set card_cents = total_cents where kind in ('sale', 'voided') and payment_kind is distinct from 'cash';
alter table receipts enable trigger receipts_immutable;
```

Regeln:
- Schema `v: 2`: `payments` höchstens 20, `kind` nur `cash` oder `card`, `position` 0 bis 100, `percent` 1 bis 100 oder `null`, `reason` Text. Eine andere Zahl in `v` ist `rejected/invalid`.
- `paymentColumns`: `v: 1` wie die Migration (`cash`: alles bar, sonst alles Karte, ohne Zahlung beide 0). `v: 2`: Summen von `amountCents` je Art; `paymentKind` ist `null` ohne Zahlung, `mixed` bei beiden Arten.
- `handleReceipt` schreibt die neuen Spalten und je Zeile `discount_cents` und `discount`. Passt der Prüfwert eines vorhandenen Bons nicht und der neue ist `v: 2`, wird noch der Prüfwert von `asV1` verglichen: Passt der, ist es `duplicate` (Review Focus 1).
- Bericht `receipt_sums` bekommt für `v: 2` die Befunde `payments` (Summe der Zahlungen ungleich Summe, bei Verkauf und Storno), `tip` (Summe der Zahlungen ungleich `tipCents`), `discount` (Summe der Zeilen ungleich `discountCents`), `card_last` (mehr als eine Karte oder nicht zuletzt). Der Bon wird trotzdem angenommen.
- Tablet: `_receipt` in `push_wire.dart` baut immer `v: 2`, Zahlungen nach `position`.
- `push_request.json` bleibt, wie es ist (das ist das Paket eines Tablets mit 1.10.0). `push_request_v2.json` ist dasselbe Paket mit dem Bon aus dem Beispiel oben: `cart` mit 10 % Stammgast auf der Bowl und 10 % Aktion auf dem Bon, `goodsCents 1486`, `depositCents 50`, `totalCents 1536`, Zeilen-Beträge Cola `{"20": 522}` mit `discountCents 58`, Bowl `{"10": 964}` mit `discountCents 226`, Zahlungen bar 1000 und Karte 536 mit `tipCents 64`, `tipStaffName "Anna"`.

- [ ] **Step 1: Die Tests schreiben, die scheitern**

```ts
// push.test.ts
test('v: 2 mit zwei Zahlungen, Trinkgeld und Rabatt: angenommen, die Spalten stimmen', async () => {
  const res = await push(a, [entry(1, 'receipt', sampleReceiptV2())]);
  expect(res.results).toEqual([{ seq: 1, status: 'accepted' }]);
  const row = (await a.db.query('select payment_kind, cash_cents, card_cents, tip_cents, discount_cents from receipts')).rows[0];
  expect(row).toEqual({ payment_kind: 'mixed', cash_cents: 1000, card_cents: 536, tip_cents: 64, discount_cents: 284 });
  const lines = (await a.db.query('select discount_cents, discount from receipt_lines order by position')).rows;
  expect(lines).toEqual([{ discount_cents: 58, discount: null }, { discount_cents: 226, discount: { percent: 10, amountCents: 119, reason: 'regular' } }]);
  expect(await reportKinds(a)).toEqual([]);
});
test('v: 1 von einem Tablet mit 1.10.0: angenommen, bar steht in cash_cents', async () => {
  await push(a, [entry(1, 'receipt', sampleReceipt())]);            // Barverkauf 9,90
  const row = (await a.db.query('select payment_kind, cash_cents, card_cents, tip_cents, discount_cents from receipts')).rows[0];
  expect(row).toEqual({ payment_kind: 'cash', cash_cents: 990, card_cents: 0, tip_cents: 0, discount_cents: 0 });
});
test('derselbe Bon erst als v: 1, dann als v: 2: duplicate, kein Bericht', async () => {
  await push(a, [entry(1, 'receipt', sampleReceipt())]);
  const res = await push(a, [entry(2, 'receipt', asV2(sampleReceipt()))]);
  expect(res.results).toEqual([{ seq: 2, status: 'duplicate' }]);
  expect(await reportKinds(a)).toEqual([]);
});
test('v: 2 mit anderem Betrag als der gespeicherte v: 1: rejected/conflict', ...);
test('v: 2, Summen passen nicht: angenommen, Bericht receipt_sums nennt payments, tip, discount und card_last', ...);
test('v: 3: rejected/invalid', ...);

// migrate.test.ts
test('0004 füllt alte Bons aus payment_kind und total_cents, danach ist receipts wieder unveränderlich', async () => {
  // Stand 0003 herstellen, drei Bons direkt einfügen: bar 990, Karte 1250, Sonderbeleg 0 ohne Zahlung
  expect(await migrateTo(owner, '0004_payments.sql')).toEqual(['0004_payments.sql']);
  expect((await owner.query('select number, cash_cents, card_cents, tip_cents, discount_cents from receipts order by number')).rows).toEqual([
    { number: 1, cash_cents: 990, card_cents: 0, tip_cents: 0, discount_cents: 0 },
    { number: 2, cash_cents: 0, card_cents: 1250, tip_cents: 0, discount_cents: 0 },
    { number: 3, cash_cents: 0, card_cents: 0, tip_cents: 0, discount_cents: 0 },
  ]);
  await expect(owner.query('update receipts set cash_cents = 1')).rejects.toThrow(/unveränderlich/);
});
```

Helfer in `test/support/push.ts`: `sampleReceiptV2()` (der Bon aus `push_request_v2.json`), `asV2(v1)` (dieselbe Bedeutung in der neuen Form), `reportKinds(a)`. `sync_fixtures.test.ts`: `push_request_v2.json` wird wie `push_request.json` ganz angenommen. Tablet, `push_wire_test.dart`: Ein Bon aus `cart` mit Bar-Teil 1000 und Trinkgeld 80 gibt `v: 2`, `payments` mit zwei Einträgen in der Reihenfolge der Stellen, `tipCents 80`, kein Feld `payment`; der Vergleich mit der gemeinsamen Datei läuft gegen `push_request_v2.json`.

- [ ] **Step 2: Laufen lassen, sie scheitern**

Run: `server/tool/test-db.sh start && cd server && npx vitest run test/push.test.ts test/migrate.test.ts test/sync_fixtures.test.ts`; `cd app && ~/flutter/bin/flutter test test/sync/push_wire_test.dart`
Expected: FAIL (`v: 2` wird als `invalid` abgelehnt, die Spalten fehlen).

- [ ] **Step 3: Umsetzen** nach Form, SQL und Regeln oben.

- [ ] **Step 4: Laufen lassen, alles grün**

Run: `cd server && npx vitest run test/push.test.ts test/push_rejected.test.ts test/migrate.test.ts test/schema.test.ts test/sync_fixtures.test.ts && npm run typecheck`; `cd app && ~/flutter/bin/flutter test test/sync/`
Expected: PASS.

- [ ] **Step 5: Commit** `Stufe 1a Task 4: Abgleich v2, Server nimmt v1 und v2, Migration 0004`.

### Task 5: Verwaltung: Adressen am Server und Seiten im Browser

Spec 5.7 (Monatsabrechnung, Übersicht, Bons im Browser), 2 Ziel 6.

**Files:**
- Create: `server/src/admin/tips.ts`
- Modify: `server/src/admin/{months,days,overview,receipts}.ts`, `shared/fixtures/stats/{months,overview}.json`, `web/src/api/{receipts,days,months}.ts`, `web/src/pages/{ReceiptsPage,ReceiptDetail,DayDetail,PeriodDetail}.tsx` (+ ihre `.module.css`, wo eine Zeile dazukommt)
- Test: `server/test/{months,days,overview,receipts}.test.ts`, `web/src/api/receipts.test.ts`

**Interfaces:**
- Consumes: Spalten `cash_cents`, `card_cents`, `tip_cents`, `discount_cents`, `payment_kind = 'mixed'` und `payload.payments` aus Task 4.
- Produces:

```ts
// admin/tips.ts
/** Karten-Trinkgeld je Person aus `payload.payments` der Bons, die `where` trifft (Alias `r`). Nach Name sortiert, Zeilen mit 0 fehlen. */
export async function tipsByStaff(c: pg.PoolClient, where: string, params: unknown[]): Promise<{ staffName: string; cents: number }[]>;

// Antwort von GET …/days/:id und GET …/months/summary, neue Felder:
discountCount: number; discountCents: number; cardTipCents: number; cardAccountCents: number;   // Karte plus Trinkgeld
tipsByStaff: { staffName: string; cents: number }[];

// GET …/receipts: paymentKind: 'cash' | 'card' | 'mixed' | null
// GET …/receipts/:id: `payments` (Liste, ersetzt `payment`), tipCents, discountCents,
//   discount: { percent: number | null; amountCents: number; reason: string } | null, und je Zeile discountCents und discount

// web/src/api/receipts.ts
export function paymentKindText(kind: ReceiptHead['paymentKind']): string;                  // 'Bar', 'Karte', 'Bar + Karte', ''
export function discountText(d: { percent: number | null; reason: string }): string;        // 'Rabatt 10 % Aktion', 'Rabatt Mitarbeiter'
```

Regeln:
- `RECEIPT_SUMS`: `cash` = Summe `cash_cents`, `card` = Summe `card_cents`. `cash_count` zählt Bons mit `payment_kind in ('cash', 'mixed')`, `card_count` Bons mit `payment_kind is distinct from 'cash'` (Verkauf +1, Storno −1). Neu `tip` (Summe `tip_cents`), `discount` (Summe `discount_cents`), `discount_count` (Bons mit `discount_cents <> 0`, Verkauf +1, Storno −1). Zahlen alter Bons ändern sich nicht.
- `tipsByStaff` gruppiert nach `tipStaffId`; der Name ist der des spätesten Bons. Ein Bon in `v: 1` hat kein Trinkgeld.
- Übersicht: Umsatz bleibt `total_cents` (nach Rabatt, ohne Trinkgeld). `cashCents`/`cardCents` aus den Spalten. "Meistverkauft" und Kategorien rechnen je Zeile mit der Summe ihrer fünf Beträge je Satz (das ist der Wert nach Rabatt) statt mit Preis mal Menge.
- Bons: Filter `payment=cash` trifft `cash` und `mixed`, `payment=card` trifft `card` und `mixed`. Das Detail gibt für einen Bon in `v: 1` die eine Zahlung als Liste mit einem Eintrag, Trinkgeld 0, keinen Rabatt.
- Browser: Liste zeigt `paymentKindText`. Detail zeigt jede Zahlung (`data-testid="payment-<Stelle>"`), "davon Trinkgeld" unter der Karte (`tip`), je Zeile ihren Rabatt und den Bon-Rabatt mit `discountText` (`discount`). Tag und Abrechnung zeigen, nur wenn ungleich 0: "Rabatte" (`discounts`), "Trinkgeld Karte" mit einer Zeile je Person (`card-tip`), "Am Kartenkonto" (`card-account`). Gründe der Bargeld-Bewegungen bekommen `tip: 'Trinkgeld'`. Gründe eines Rabatts: `regular` Stammgast, `staff` Mitarbeiter, `complaint` Reklamation, `promotion` Aktion, `invitation` Einladung; ein unbekannter Grund steht, wie er kam.

- [ ] **Step 1: Die Tests schreiben, die scheitern**

```ts
// days.test.ts
test('Tag mit gemischtem Bon, Trinkgeld und Rabatt', async () => {
  // gesendet: Tag, sampleReceipt() (bar 9,90, v: 1) und sampleReceiptV2() (15,36: bar 10,00, Karte 5,36, Trinkgeld 0,64, Rabatt 2,84)
  const d = await getDay(a, dayId);
  expect(d).toMatchObject({
    receiptCount: 2, revenueCents: 2526, cashCents: 1990, cardCents: 536, cashReceiptCount: 2, cardReceiptCount: 1,
    discountCount: 1, discountCents: 284, cardTipCents: 64, cardAccountCents: 600,
    tipsByStaff: [{ staffName: 'Anna', cents: 64 }],
  });
});
// receipts.test.ts
test('gemischter Bon: Art mixed, zu sehen unter payment=cash und payment=card', async () => {
  expect((await list(a, '')).receipts.map((r) => r.paymentKind)).toEqual(['mixed', 'cash']);
  expect((await list(a, '?payment=cash')).receipts).toHaveLength(2);
  expect((await list(a, '?payment=card')).receipts.map((r) => r.paymentKind)).toEqual(['mixed']);
});
test('Detail: alle Zahlungen, Trinkgeld und Rabatte; ein Bon in v: 1 hat eine Zahlung in der Liste', async () => {
  const d = await detail(a, v2Id);
  expect(d.payments.map((p) => [p.kind, p.amountCents, p.tipCents])).toEqual([['cash', 1000, 0], ['card', 536, 64]]);
  expect(d).toMatchObject({ tipCents: 64, discountCents: 284, discount: { percent: 10, amountCents: 165, reason: 'promotion' } });
  expect(d.lines.map((l) => l.discountCents)).toEqual([58, 226]);
  expect((await detail(a, v1Id)).payments).toHaveLength(1);
});
// receipts.test.ts (web)
test('paymentKindText und discountText', () => {
  expect([paymentKindText('cash'), paymentKindText('card'), paymentKindText('mixed'), paymentKindText(null)]).toEqual(['Bar', 'Karte', 'Bar + Karte', '']);
  expect(discountText({ percent: 10, reason: 'promotion' })).toBe('Rabatt 10 % Aktion');
  expect(discountText({ percent: null, reason: 'staff' })).toBe('Rabatt Mitarbeiter');
  expect(discountText({ percent: null, reason: 'xyz' })).toBe('Rabatt xyz');
});
```

Dazu: `months.test.ts` `'Zusammenfassung mit Trinkgeld je Person und Rabatt'` (dieselben Felder wie beim Tag; ein Storno im Folgemonat steht dort als Minus bei der Person). `shared/fixtures/stats/months.json` und `overview.json` bekommen den Bon aus Task 4 als `v: 2` mit von Hand nachgerechneten `expected`; die Zahlen der vorhandenen Bons darin ändern sich nicht. `overview.test.ts`: Der Bon in `v: 2` zählt mit 15,36 zum Umsatz, Cola mit 5,22 und die Bowl mit 9,64.

- [ ] **Step 2: Laufen lassen, sie scheitern**

Run: `cd server && npx vitest run test/days.test.ts test/months.test.ts test/overview.test.ts test/receipts.test.ts`; `cd web && npm test`
Expected: FAIL (`cashCents` ist 990 statt 1990, `discountCount` fehlt, `paymentKindText` gibt es nicht).

- [ ] **Step 3: Umsetzen** nach den Regeln oben.

- [ ] **Step 4: Laufen lassen, alles grün**

Run: `cd server && npx vitest run && npm run typecheck`; `cd web && npm test && npm run typecheck`
Expected: PASS. Dann pushen und die Workflows `app` und `server` für den Commit lesen.

- [ ] **Step 5: Commit** `Stufe 1a Task 5: Verwaltung rechnet mit Zahlungen, Trinkgeld und Rabatt`.

## Teil 2: Schalter

### Task 6: Abschnitt "Zahlen" in den Einstellungen, und der Test "alles aus ist wie 1.10.0"

Spec 5.1, 2 (Anti-Ziel: der Imbiss wird langsamer).

**Files:**
- Create: `app/lib/features/settings/payment_section.dart`, `app/test/features/payment_settings_test.dart`, `app/test/features/stufe_1a_off_test.dart`
- Modify: `app/lib/features/settings/settings_screen.dart`, `app/lib/l10n/app_*.arb`, `app/test/support/kassa_pump.dart`
- Test: die zwei neuen Dateien, `app/test/features/settings_test.dart`, `app/test/golden/settings_golden_test.dart`

**Interfaces:**
- Consumes: `RegisterSettings.{splitPaymentEnabled, cardTipEnabled, discountAccess, openAmountAccess}`, `FeatureAccess` aus Task 1.
- Produces:

```dart
// features/settings/payment_section.dart
class PaymentSection extends StatelessWidget {
  const PaymentSection({super.key, required this.settings, required this.onChange});
  final RegisterSettings settings;
  final Future<void> Function(RegisterSettings Function(RegisterSettings)) onChange;
}
// test/support/kassa_pump.dart
Future<void> pumpKassa(WidgetTester t, {..., String pin = '1234'});            // '4711' meldet den Chef an
Future<void> setSettings(WidgetTester t, RegisterSettings Function(RegisterSettings) change);   // speichert und wartet
```

Aufbau: Karte "Zahlen" in der linken Spalte unter der Karte "Kassa". Vier Zeilen (`SettingsRow`): "Teil bar, Rest Karte" und "Trinkgeld bei Kartenzahlung" mit `RowToggle` (`toggle-split-payment`, `toggle-card-tip`); "Rabatt" und "Freier Betrag" mit `Segmented<FeatureAccess>` und den Segmenten "Aus", "Alle", "Nur Chef" (`discount-access-<name>`, `open-amount-access-<name>`). Jede Änderung speichert sofort. ARB: `settingsPayments` "Zahlen", `settingsSplitPayment`, `settingsCardTip`, `settingsDiscount`, `settingsOpenAmount`, `settingsAccessOff`, `settingsAccessAll`, `settingsAccessChef`.

- [ ] **Step 1: Die Tests schreiben**

```dart
// payment_settings_test.dart (Einstellungen als Chef geöffnet, Muster settings_test.dart)
testWidgets('Abschnitt "Zahlen": vier Zeilen, alles aus', (t) async {
  expect(find.text('Zahlen'), findsOneWidget);
  expect(switchOf(t, 'toggle-split-payment').value, isFalse);
  expect(switchOf(t, 'toggle-card-tip').value, isFalse);
  expect(selectedSegment(t, 'discount-access'), FeatureAccess.off);
  expect(selectedSegment(t, 'open-amount-access'), FeatureAccess.off);
});
testWidgets('jede Änderung steht sofort in der Datenbank', (t) async {
  await t.tap(find.byKey(const Key('toggle-card-tip')));
  await t.tap(find.byKey(const Key('discount-access-chefOnly')));
  await t.tap(find.byKey(const Key('open-amount-access-all')));
  await t.pumpAndSettle();
  final s = await containerOf(t).read(settingsRepositoryProvider).current();
  expect((s.splitPaymentEnabled, s.cardTipEnabled, s.discountAccess, s.openAmountAccess), (false, true, FeatureAccess.chefOnly, FeatureAccess.all));
});

// stufe_1a_off_test.dart: von Anfang an grün, und bleibt es in jeder späteren Aufgabe
testWidgets('alle Schalter aus: keine neue Taste, kein neuer Schritt', (t) async {
  await pumpKassa(t, overrides: await memoryOverrides(terminal: FakeCardTerminal()));
  await tapItem(t, 'cola'); await tapItem(t, 'teigtaschen');
  for (final k in ['discount-button', 'open-amount-button', 'receipt-discount', 'finish-free', 'split-card-failed']) {
    expect(find.byKey(Key(k)), findsNothing, reason: k);
  }
  await t.tap(find.text('Teigtaschen').last);                       // Tipp auf die Bon-Zeile tut nichts
  await t.pumpAndSettle();
  expect(find.byKey(const Key('discount-sheet')), findsNothing);
  expect(cartOf(t).lines.map((l) => l.quantity), [1, 1]);
  await t.tap(find.byKey(const Key('pay-cash')));
  await t.pumpAndSettle();
  expect(find.byKey(const Key('cash-mode-split')), findsNothing);
  await t.tap(find.byKey(const Key('cash-back')));
  await t.pumpAndSettle();
  await t.tap(find.byKey(const Key('pay-card')));                   // direkt zum Terminal
  await t.pump();
  expect(find.byKey(const Key('tip-sheet')), findsNothing);
  await t.pumpAndSettle();
  expect(terminalOf(t).payments.single.amountCents, 965);
  expect(await queryRows(t, 'SELECT position, kind, amount_cents, tip_cents FROM payments'),
      [{'position': 0, 'kind': 'card', 'amount_cents': 965, 'tip_cents': 0}]);
});
testWidgets('alle Schalter aus, Chef angemeldet: auch für ihn keine neue Taste', ...);   // pin: '4711'
```

- [ ] **Step 2: Laufen lassen**

Run: `cd app && ~/flutter/bin/flutter test test/features/payment_settings_test.dart test/features/stufe_1a_off_test.dart`
Expected: `payment_settings_test.dart` FAIL (keine Karte "Zahlen"); `stufe_1a_off_test.dart` PASS.

- [ ] **Step 3: Umsetzen** nach dem Aufbau oben; Texte in fünf Sprachen, `gen-l10n`, `l10n_review`.

- [ ] **Step 4: Laufen lassen, alles grün**

Run: `cd app && ~/flutter/bin/flutter test test/features/payment_settings_test.dart test/features/stufe_1a_off_test.dart test/features/settings_test.dart test/features/l10n_layout_test.dart test/l10n_review_test.dart && ~/flutter/bin/flutter analyze`. Die Goldens der Einstellungen neu erzeugen (`--update-goldens test/golden/settings_golden_test.dart`) und ansehen: Nur die Karte "Zahlen" ist dazugekommen, die Signatur steht weiter ohne Scrollen im Bild.
Expected: PASS.

- [ ] **Step 5: Commit** `Stufe 1a Task 6: Schalter für Zahlen in den Einstellungen`.

## Teil 3: Die vier Funktionen

### Task 7: Trinkgeld bei Kartenzahlung

Spec 5.3, 5.2 (die offene Zahlung trägt Bar-Teil und Trinkgeld), 5.4a.

**Files:**
- Create: `app/lib/domain/tip.dart`, `app/lib/features/kassa/tip_sheet.dart`, `app/test/domain/tip_test.dart`, `app/test/features/tip_test.dart`
- Modify: `app/lib/data/card_payment_repository.dart`, `app/lib/features/kassa/{sale_service,kassa_screen,unclear_card_payment,sale_done}.dart`, `app/lib/domain/day.dart` (`CashReason.tip`), `app/lib/features/close/{cash_movement_sheet,close_format}.dart`, `app/lib/l10n/app_*.arb`
- Test: die zwei neuen Dateien, `app/test/data/card_payment_repository_test.dart`, `app/test/features/{sale_service,unclear_card,close}_test.dart`

**Interfaces:**
- Consumes: `finalizeCardSale(cashPartCents:, tipCents:)` (Task 2), `cardTipEnabled` (Task 1), `setSettings` (Task 6).
- Produces:

```dart
// domain/tip.dart
/// Was der Gast zahlen könnte, über [dueCents]: nächster voller Euro, nächste Fünfer-Stufe, nächste Zehner-Stufe,
/// jeweils echt größer, aufsteigend, ohne Doppelte, höchstens drei.
List<int> tipSuggestions(int dueCents);
/// Wahr, wenn das Trinkgeld höher ist als 30 % der Summe des Bons und höher als 5,00 €.
bool tipNeedsConfirm({required int totalCents, required int tipCents});

// data/card_payment_repository.dart
class PendingCardPayment { ..., required this.cashPartCents, required this.tipCents });   // amountCents: was das Terminal bucht
Future<void> begin({required String paymentId, required Cart cart, required Staff staff, int cashPartCents = 0, int tipCents = 0});

// features/kassa/sale_service.dart
Future<CardSaleOutcome> payByCard({required String paymentId, required Cart cart, required Staff staff,
    int cashPartCents = 0, int tipCents = 0});

// features/kassa/tip_sheet.dart
class TipSheet extends ConsumerStatefulWidget {
  const TipSheet({super.key, required this.dueCents, required this.receiptTotalCents, required this.onBack, required this.onPay});
  final int dueCents;            // was die Karte ohne Trinkgeld bucht
  final int receiptTotalCents;   // Grundlage der 30-%-Grenze
  final VoidCallback onBack;
  final ValueChanged<int> onPay; // Trinkgeld in Cent; 0 bei "Ohne Trinkgeld"
}
// domain/day.dart
enum CashReason { bank, purchase, change, other, tip }   // reasonLabel(tip) = 'Trinkgeld'
```

Regeln:
- `begin`: `amountCents = cart.totalCents - cashPartCents + tipCents`. `payByCard` prüft den Kleinstbetrag am Rest ohne Trinkgeld (`cart.totalCents - cashPartCents`), schreibt die offene Zahlung, ruft das Terminal mit `amountCents` wie in `begin` und schließt mit `finalizeCardSale(cashPartCents:, tipCents:)`. Die Reihenfolge und jede `catch`-Stelle bleiben, wie sie sind.
- `cartOfPending` gilt nur, wenn `cart.totalCents - p.cashPartCents + p.tipCents == p.amountCents`. `confirmUnclear` schließt mit Bar-Teil und Trinkgeld der offenen Zahlung ab; das Trinkgeld gehört der Person der offenen Zahlung.
- Kassa: Ist `cardTipEnabled` an, zeigt "Karte" zuerst das `TipSheet` (neuer Zustand `_Side.tip`), sonst geht es wie heute direkt zum Terminal. `CardWait` zeigt den Betrag mit Trinkgeld.
- `TipSheet` (Schlüssel `tip-sheet`): Summe (`tip-due`), "Gast zahlt" mit einer Taste je Vorschlag (`tip-pays-<cent>`) und "Anderer Betrag" (`tip-other`, öffnet `TypedAmount`, `KeypadInput(maxIntDigits: 6)`), Zeile "Trinkgeld" (`tip-amount`), "Ohne Trinkgeld" (`tip-none`, ein Tipp, ruft `onPay(0)`), "Zum Terminal 50,00 €" (`tip-go`, aus, solange nichts gewählt ist oder der Betrag unter der Summe liegt; dann steht `tipTooLow` darunter), zurück (`tip-back`). Verlangt `tipNeedsConfirm` eine Nachfrage, zeigt `tip-go` statt des Terminals die Frage "Trinkgeld 453,20 €?" (`tip-confirm`) mit "Ja, stimmt" (`tip-confirm-yes`) und "Ändern" (`tip-confirm-no`).
- Blatt "Unklare Kartenzahlung": unter dem Betrag "Davon Trinkgeld 0,35 €" (`unclear-tip`), nur bei Trinkgeld. "Verkauf fertig": unter "Mit Karte bezahlt" die Zeile "davon Trinkgeld 0,35 €" (`tip-done`), nur bei Trinkgeld.
- Entnahme: "Trinkgeld" als fünfter Grund, nur bei "Bargeld entnehmen" (`reason-tip`), `cashReasonText` in fünf Sprachen (`closeReasonTip`).
- ARB: `tipGuestPays` "Gast zahlt", `tipTip` "Trinkgeld", `tipNone` "Ohne Trinkgeld", `tipToTerminal` "Zum Terminal {amount}", `tipConfirm` "Trinkgeld {amount}?", `tipConfirmYes` "Ja, stimmt", `tipConfirmNo` "Ändern", `tipTooLow` "Der Betrag ist kleiner als die Summe.", `kassaTipDone` und `unclearTip` "davon Trinkgeld {amount}" / "Davon Trinkgeld {amount}", `closeReasonTip` "Trinkgeld". "Anderer Betrag" ist das vorhandene `kassaOtherAmount`.

- [ ] **Step 1: Die Tests schreiben, die scheitern**

```dart
// domain/tip_test.dart
test('Vorschläge: voller Euro, Fünfer, Zehner, ohne Doppelte', () {
  expect(tipSuggestions(4680), [4700, 5000]);
  expect(tipSuggestions(4210), [4300, 4500, 5000]);
  expect(tipSuggestions(4700), [4800, 5000]);
  expect(tipSuggestions(965), [1000]);
});
test('Nachfrage nur über 30 % der Summe und über 5,00 €', () {
  expect(tipNeedsConfirm(totalCents: 4680, tipCents: 45320), isTrue);
  expect(tipNeedsConfirm(totalCents: 4680, tipCents: 320), isFalse);
  expect(tipNeedsConfirm(totalCents: 1000, tipCents: 500), isFalse);   // 50 %, aber nicht über 5,00 €
  expect(tipNeedsConfirm(totalCents: 1000, tipCents: 501), isTrue);
  expect(tipNeedsConfirm(totalCents: 4000, tipCents: 1200), isFalse);  // genau 30 %
});

// features/tip_test.dart (Cola + Teigtaschen = 9,65; Schalter an über setSettings)
testWidgets('Gast zahlt 10,00: Terminal bucht 10,00, der Bon trägt 0,35 Trinkgeld für Anna', (t) async {
  await openWithTip(t);
  await t.tap(find.byKey(const Key('pay-card')));
  await t.pumpAndSettle();
  expect(textOf(t, const Key('tip-due')), '9,65 €');
  await t.tap(find.byKey(const Key('tip-pays-1000')));
  await t.pump();
  expect(textOf(t, const Key('tip-amount')), '0,35 €');
  await t.tap(find.byKey(const Key('tip-go')));
  await t.pumpAndSettle();
  expect(terminalOf(t).payments.single.amountCents, 1000);
  expect(await queryRows(t, 'SELECT amount_cents, tip_cents, tip_staff_name FROM payments'),
      [{'amount_cents': 965, 'tip_cents': 35, 'tip_staff_name': 'Anna'}]);
  expect(await queryRows(t, 'SELECT total_cents, tip_cents FROM receipts'), [{'total_cents': 965, 'tip_cents': 35}]);
  expect(find.byKey(const Key('tip-done')), findsOneWidget);
});
testWidgets('"Ohne Trinkgeld" ist ein Tipp und bucht die Summe', (t) async {
  await openWithTip(t);
  await t.tap(find.byKey(const Key('pay-card'))); await t.pumpAndSettle();
  await t.tap(find.byKey(const Key('tip-none'))); await t.pumpAndSettle();
  expect(terminalOf(t).payments.single.amountCents, 965);
  expect(find.byKey(const Key('tip-done')), findsNothing);
});
testWidgets('Anderer Betrag unter der Summe: "Zum Terminal" ist aus', (t) async {
  // tip-other, tapKeys(t, '9'): 9,00 < 9,65
  expect(buttonOf(t, 'tip-go').onPressed, isNull);
  expect(terminalOf(t).payments, isEmpty);
});
testWidgets('Vertippt (100,00 statt 10,00): die Kassa fragt einmal nach', (t) async {
  // tip-other, tapKeys(t, '1 0 0'), tip-go
  expect(textOf(t, const Key('tip-confirm')), 'Trinkgeld 90,35 €?');
  expect(terminalOf(t).payments, isEmpty);
  await t.tap(find.byKey(const Key('tip-confirm-no'))); await t.pump();
  expect(find.byKey(const Key('tip-confirm')), findsNothing);
});
testWidgets('die offene Zahlung trägt das Trinkgeld, bevor das Terminal antwortet', (t) async {
  // terminalOf(t).hang gesetzt, Gast zahlt 10,00
  expect(await queryRows(t, 'SELECT amount_cents, tip_cents, cash_part_cents FROM pending_card_payments'),
      [{'amount_cents': 1000, 'tip_cents': 35, 'cash_part_cents': 0}]);
});
```

Dazu: `unclear_card_test.dart` `'unklar mit Trinkgeld: "bezahlt" schreibt den Bon mit Trinkgeld für die Person der Zahlung'` (auch wenn inzwischen der Chef angemeldet ist) und `'offene Zahlung in der Form von 1.10.0 (ohne Bar-Teil und Trinkgeld): "bezahlt" gibt einen Bon mit einer Kartenzahlung'` (Review Focus 2). `sale_service_test.dart` `'payByCard mit Bar-Teil 10,00 und Trinkgeld 0,80: Terminal bucht 9,00'` und `'Rest unter dem Kleinstbetrag: belowMinimum, nichts geschrieben'` (Bar-Teil 1750 bei `cart`). `card_payment_repository_test.dart`: `begin` schreibt `amountCents 900`, `cashPartCents 1000`, `tipCents 80`. `close_test.dart`: `reason-tip` gibt es bei "Bargeld entnehmen", nicht bei "Bargeld einlegen"; die Entnahme steht mit dem Grund "Trinkgeld" in der Karte.

- [ ] **Step 2: Laufen lassen, sie scheitern**

Run: `cd app && ~/flutter/bin/flutter test test/domain/tip_test.dart test/features/tip_test.dart`
Expected: FAIL (`tip.dart` und `tip-sheet` gibt es nicht).

- [ ] **Step 3: Umsetzen** nach Signaturen und Regeln oben; Texte in fünf Sprachen.

- [ ] **Step 4: Laufen lassen, alles grün**

Run: `cd app && ~/flutter/bin/flutter test test/domain/tip_test.dart test/features/tip_test.dart test/features/card_test.dart test/features/unclear_card_test.dart test/features/sale_service_test.dart test/features/kassa_card_outage_test.dart test/features/close_test.dart test/features/stufe_1a_off_test.dart test/data/card_payment_repository_test.dart test/l10n_review_test.dart && ~/flutter/bin/flutter analyze`
Expected: PASS, kein Golden ändert sich.

- [ ] **Step 5: Commit** `Stufe 1a Task 7: Trinkgeld bei Kartenzahlung`.

### Task 8: Teil bar, Rest Karte

Spec 5.2, 5.4a (Storno-Dialog).

**Files:**
- Create: `app/lib/features/kassa/card_availability.dart`, `app/test/features/split_payment_test.dart`
- Modify: `app/lib/features/kassa/{cash_sheet,cart_panel,kassa_screen,sale_service,sale_done,unclear_card_payment}.dart`, `app/lib/features/bons/void_question.dart`, `app/lib/l10n/app_*.arb`
- Test: die neue Datei, `app/test/features/{bons,unclear_card,sale_service}_test.dart`

**Interfaces:**
- Consumes: `payByCard(cashPartCents:, tipCents:)`, `TipSheet` (Task 7), `splitPaymentEnabled` (Task 1), `Receipt.cashCents`/`cardPayment` (Task 2).
- Produces:

```dart
// features/kassa/card_availability.dart
/// Ob die Karte für [amountCents] geht, sonst der erste Grund in der Bediensprache (wie heute in `_cardAvailability`).
({bool enabled, String? reason}) cardAvailability(WidgetRef ref, BuildContext context, int amountCents);

// features/kassa/cash_sheet.dart
class CashSheet extends ConsumerStatefulWidget {
  const CashSheet({super.key, required this.cart, required this.onBack, required this.onPaid, this.onSplit});
  final ValueChanged<int>? onSplit;   // Bar-Teil in Cent: "Weiter zur Karte"
}
// features/kassa/cart_panel.dart
const CartPanel({..., this.payNotice});   // Widget? über dem Summenblock
```

Regeln:
- Ist `splitPaymentEnabled` an (und `onSplit` gesetzt), stehen im Bar-Blatt oben zwei Segmente "Ganzer Betrag" und "Teil bar" (`cash-mode-full`, `cash-mode-split`); gewählt ist "Ganzer Betrag", und das Blatt ist dann genau das heutige. "Teil bar" zeigt: "Bar-Teil" mit Zahlenfeld (`TypedAmount`), "Rest mit Karte" (`split-rest`), die Taste "Weiter zur Karte 4,65 €" (`split-go`) und darunter den Grund, wenn sie aus ist (`split-reason`).
- `split-go` ist an, wenn der Bar-Teil über 0 ist, der Rest mindestens `cardTerminalProvider.minimumCents` beträgt und `cardAvailability` für den Rest `enabled` meldet. Gründe: `splitNeedCash` "Bar-Teil eingeben.", `splitRestTooSmall` "Rest mit Karte mindestens {amount}.", sonst der Grund aus `cardAvailability`. Rückgeld rechnet das Blatt hier nicht.
- "Weiter zur Karte" speichert nichts. Die Kassa geht mit dem Bar-Teil in den Karten-Ablauf (mit `TipSheet`, wenn an; `dueCents` ist der Rest, `receiptTotalCents` die Summe).
- Bezahlt: Der Bon hat zwei Zahlungen. Die Lade geht auf, wenn `receipt.cashCents > 0` und die Lade eingeschaltet ist (im selben Druckauftrag wie beim Barverkauf); `printAgain` holt die Lade auch hier nach. "Verkauf fertig" zeigt zusätzlich "Bar-Teil 5,00 €" (`cash-part-done`).
- Sicher gescheitert: nichts ist gespeichert, die Kassa steht beim offenen Bon. Über dem Summenblock steht, bis der Bon sich ändert oder eine Zahlung beginnt: "Karte nicht bezahlt. 5,00 € bar zurückgeben oder noch einmal versuchen." (`split-card-failed`, über `payNotice`), darunter der Grund aus `cardSaleFailedText`. Kein Hinweis, der nach Sekunden verschwindet.
- Unklar: Das Blatt zeigt zusätzlich "Bar-Teil 5,00 € ist schon kassiert." (`unclear-cash-part`). Bei "nicht bezahlt" steht in der Wirkung zusätzlich "5,00 € bar zurückgeben." (`unclear-return-cash`).
- Storno-Dialog: Ein Bon mit nur einer Bar-Zahlung oder nur einer Kartenzahlung ohne Trinkgeld zeigt genau die heutigen Texte. Sonst: bei Bar-Teil "5,00 € bar zurückgeben." (`void-cash-back`), bei Karte in `void-card-hint` "4,65 € bei SumUp zurückbuchen." oder mit Trinkgeld "5,00 € bei SumUp zurückbuchen, davon 0,35 € Trinkgeld." (der Betrag ist `chargedCents`).
- ARB: `splitWhole` "Ganzer Betrag", `splitPart` "Teil bar", `splitCashPart` "Bar-Teil", `splitRest` "Rest mit Karte", `splitGo` "Weiter zur Karte {amount}", `splitNeedCash`, `splitRestTooSmall`, `splitCardFailed` "Karte nicht bezahlt. {amount} bar zurückgeben oder noch einmal versuchen.", `kassaCashPartDone` "Bar-Teil {amount}", `unclearCashPart` "Bar-Teil {amount} ist schon kassiert.", `unclearReturnCash` "{amount} bar zurückgeben.", `bonsVoidMixedCash` "{amount} bar zurückgeben.", `bonsVoidCardBack` "{amount} bei SumUp zurückbuchen.", `bonsVoidCardBackTip` "{amount} bei SumUp zurückbuchen, davon {tip} Trinkgeld.".

- [ ] **Step 1: Die Tests schreiben, die scheitern**

```dart
// split_payment_test.dart (Cola + Teigtaschen = 9,65; Schalter an; Drucker eingerichtet)
testWidgets('5,00 bar, Rest 4,65 mit Karte: ein Bon mit zwei Zahlungen, die Lade geht auf', (t) async {
  await openSplit(t);                                                // "Bar", dann cash-mode-split
  await tapKeys(t, '5');
  await t.pump();
  expect(textOf(t, const Key('split-rest')), '4,65 €');
  await t.tap(find.byKey(const Key('split-go')));
  await t.pumpAndSettle();
  expect(terminalOf(t).payments.single.amountCents, 465);
  expect(await queryRows(t, 'SELECT position, kind, amount_cents FROM payments ORDER BY position'), [
    {'position': 0, 'kind': 'cash', 'amount_cents': 500},
    {'position': 1, 'kind': 'card', 'amount_cents': 465},
  ]);
  expect(await receiptCount(t), 1);
  expect(printerOf(t).log.single, startsWith('print+drawer:'));
  expect(find.byKey(const Key('cash-part-done')), findsOneWidget);
});
testWidgets('die Taste sagt, warum sie aus ist', (t) async {
  await openSplit(t);
  expect(textOf(t, const Key('split-reason')), 'Bar-Teil eingeben.');
  await tapKeys(t, '9');                                             // Rest 0,65
  await t.pump();
  expect(textOf(t, const Key('split-reason')), 'Rest mit Karte mindestens 1,00 €.');
  expect(buttonOf(t, 'split-go').onPressed, isNull);
});
testWidgets('Karte abgelehnt: nichts gespeichert, der Hinweis nennt den Bar-Teil und bleibt stehen', (t) async {
  terminalOf(t).next = const CardFailed(CardFailure.declined);
  // 5,00 bar, split-go
  expect(await receiptCount(t), 0);
  expect(await queryRows(t, 'SELECT id FROM pending_card_payments'), isEmpty);
  expect(textOf(t, const Key('split-card-failed')), contains('5,00 € bar zurückgeben'));
  await t.pump(const Duration(seconds: 30));
  expect(find.byKey(const Key('split-card-failed')), findsOneWidget);
  expect(cartOf(t).totalCents, 965);
});
testWidgets('danach alles bar: ein Bon, eine Bar-Zahlung über 9,65, der Hinweis ist weg', (t) async {
  // wie oben, dann pay-cash (Ganzer Betrag), finish-sale
  expect(find.byKey(const Key('split-card-failed')), findsNothing);
  expect(await queryRows(t, 'SELECT kind, amount_cents FROM payments'), [{'kind': 'cash', 'amount_cents': 965}]);
  expect(await receiptCount(t), 1);
});
testWidgets('mit Trinkgeld: das Blatt "Gast zahlt" rechnet vom Rest, das Terminal bucht Rest plus Trinkgeld', (t) async {
  // beide Schalter an; 5,00 bar, split-go: tip-due zeigt 4,65 €; tip-pays-500
  expect(terminalOf(t).payments.single.amountCents, 500);
  expect(await queryRows(t, 'SELECT amount_cents, tip_cents FROM payments WHERE kind = \'card\''), [{'amount_cents': 465, 'tip_cents': 35}]);
});
```

Dazu: `'unklar mit Bar-Teil: die offene Zahlung trägt ihn, "bezahlt" gibt den Bon mit zwei Zahlungen, "nicht bezahlt" nennt den Betrag zum Zurückgeben'` in `unclear_card_test.dart`; in `bons_test.dart` `'Storno-Frage beim gemischten Bon mit Trinkgeld'` (Bon aus `cart`, bar 10,00, Karte 8,20, Trinkgeld 0,80: `void-cash-back` zeigt "10,00 € bar zurückgeben.", `void-card-hint` zeigt "9,00 € bei SumUp zurückbuchen, davon 0,80 € Trinkgeld.") und `'Storno-Frage bei einem Bar-Bon: der Text von 1.10.0'`.

- [ ] **Step 2: Laufen lassen, sie scheitern**

Run: `cd app && ~/flutter/bin/flutter test test/features/split_payment_test.dart`
Expected: FAIL (`cash-mode-split` gibt es nicht).

- [ ] **Step 3: Umsetzen** nach den Regeln oben; `_cardAvailability` zieht nach `card_availability.dart` um, `CartPanel` nutzt sie mit der Summe des Bons.

- [ ] **Step 4: Laufen lassen, alles grün**

Run: `cd app && ~/flutter/bin/flutter test test/features/split_payment_test.dart test/features/tip_test.dart test/features/cash_test.dart test/features/card_test.dart test/features/unclear_card_test.dart test/features/bons_test.dart test/features/sale_service_test.dart test/features/stufe_1a_off_test.dart test/golden/cash_golden_test.dart test/golden/card_golden_test.dart test/l10n_review_test.dart && ~/flutter/bin/flutter analyze`
Expected: PASS, kein Golden ändert sich. Dann pushen und die Workflows lesen.

- [ ] **Step 5: Commit** `Stufe 1a Task 8: Teil bar, Rest Karte`.

### Task 9: Rabatt: die Rechenregel im offenen Bon

Spec 5.4 (Rechenregel 1 bis 4, Kappen, Pfand nie), 5.6 (Entwurf), 7 (viele zufällige Bons).

**Files:**
- Create: `app/lib/domain/discount.dart`, `app/test/domain/discount_test.dart`, `app/test/domain/discount_random_test.dart`
- Modify: `app/lib/domain/cart.dart`, `app/lib/domain/pricing.dart`, `app/lib/features/kassa/cart_controller.dart`
- Test: die zwei neuen Dateien, `app/test/domain/{cart,pricing}_test.dart`

**Interfaces:**
- Consumes: nichts aus früheren Aufgaben.
- Produces:

```dart
// domain/discount.dart (reines Dart, kennt den Bon nicht)
enum DiscountReason { regular, staff, complaint, promotion, invitation }
/// 'regular' Stammgast, 'staff' Mitarbeiter, 'complaint' Reklamation, 'promotion' Aktion, 'invitation' Einladung;
/// ein unbekannter Name kommt zurück, wie er ist. Deutsch, für Bon und Berichte.
String discountReasonLabel(String name);
const discountPercents = [5, 10, 15, 20, 50, 100];
class Discount {
  const Discount.percent(int this.percent, this.reason) : amountCents = 0;   // 1 bis 100
  const Discount.amount(this.amountCents, this.reason) : percent = null;     // über 0
  final int? percent;  final int amountCents;  final DiscountReason reason;
  int of(int baseCents);                       // der Rabatt in Cent von diesem Wert
  Map<String, dynamic> toJson();               // {"percent": 10, "reason": "regular"} oder {"amountCents": 200, "reason": "staff"}
  static Discount? fromJson(Object? json);     // alles Unlesbare: null
}
/// Verteilt [amountCents] im Verhältnis von [weights] auf Cent genau.
List<int> allocate(int amountCents, List<int> weights);

// domain/cart.dart
class CartLine { ..., this.discount });  final Discount? discount;
  int get goodsCents;                          // wie bisher: Preis mal Menge, vor Rabatt
  Map<TaxRate, int> get listGrossByRate;       // vor Rabatt (der Inhalt des heutigen grossByRateOfLine)
class LinePricing { final int listCents; final int ownDiscountCents; final int shareCents; final int depositCents;
  final Map<TaxRate, int> grossByRate;         // nach allen Rabatten
  int get discountCents;                       // ownDiscountCents + shareCents
  int get goodsCents; }                        // listCents - discountCents
class CartPricing { final List<LinePricing> lines;
  final int subtotalCents;                     // Warenwert nach Zeilen-Rabatten, vor dem Bon-Rabatt
  final int receiptDiscountCents;
  int get discountCents; int get goodsCents; int get depositCents; int get totalCents; Map<TaxRate, int> get grossByRate; }
class Cart { final Discount? discount;         // Bon-Rabatt
  CartPricing get pricing;
  int get goodsCents;  int get totalCents;     // jetzt nach Rabatt, aus [pricing]
  Cart setLineDiscount(String lineId, Discount? discount);
  Cart setReceiptDiscount(Discount? discount); }
// features/kassa/cart_controller.dart
void setLineDiscount(String lineId, Discount? discount);
void setReceiptDiscount(Discount? discount);
```

Die Rechnung (Spec 5.4, damit jedes Gerät auf den Cent gleich rechnet):

```
Discount.of(base):   base <= 0: 0.  Prozent: (base * percent + 50) ~/ 100.  Betrag: min(amountCents, base).
allocate(a, w):      W = Summe w.  a == 0: lauter Nullen.  ArgumentError bei a < 0, einem w < 0 oder a > W.
                     grund[i] = a * w[i] ~/ W;  rest[i] = (a * w[i]) % W.
                     Die a - Summe(grund) übrigen Cent gehen je einer an die Stellen mit dem größten rest,
                     bei gleichem rest an die frühere Stelle.
Cart.pricing:        1. je Zeile: list = Preis * Menge; own = line.discount?.of(list) ?? 0; nach = list - own.
                     2. subtotal = Summe nach; bon = cart.discount?.of(subtotal) ?? 0.
                     3. share = allocate(bon, [max(0, nach) je Zeile]).
                     4. je Zeile: d = own + share; die Beträge je Satz in der Reihenfolge von TaxRate.values;
                        abzug = allocate(d, [max(0, betrag) je Satz]); grossByRate = betrag - abzug.
                     Pfand wird nie rabattiert.
```

Regeln für den Bon:
- `Cart.toJson`: eine Zeile mit Rabatt trägt `"discount"`, der Bon mit Rabatt `"discount"` neben `"lines"`. `fromJson` liest einen Entwurf aus 1.10.0 (ohne diese Felder) wie bisher; ein unlesbarer Rabatt fällt weg, die Zeile bleibt. `rebind` behält die Rabatte.
- `setQuantity`, `add` und `remove` behalten den Rabatt der Zeile. Wird der Bon leer, ist auch der Bon-Rabatt weg.
- `grossByRate(Cart)` in `pricing.dart` gibt die Beträge nach Rabatt (`cart.pricing.grossByRate`), `grossByRateOfLine` bleibt der Wert vor Rabatt.

- [ ] **Step 1: Die Tests schreiben, die scheitern**

```dart
// discount_test.dart
test('allocate: das Beispiel der Spec und der Gleichstand', () {
  expect(allocate(213, [1782, 350]), [178, 35]);   // 10 % Aktion von 21,32
  expect(allocate(2, [3, 3, 3]), [1, 1, 0]);       // gleicher Rest: die frühere Zeile
  expect(allocate(1, [0, 5, 5]), [0, 1, 0]);
  expect(allocate(0, [5, 5]), [0, 0]);
  expect(() => allocate(11, [5, 5]), throwsArgumentError);
});
test('Discount.of: kaufmännisch gerundet, Betrag gekappt', () {
  expect(const Discount.percent(10, DiscountReason.regular).of(1980), 198);
  expect(const Discount.percent(10, DiscountReason.promotion).of(2132), 213);
  expect(const Discount.percent(15, DiscountReason.staff).of(290), 44);        // 43,5 wird 44
  expect(const Discount.amount(500, DiscountReason.staff).of(290), 290);
  expect(const Discount.percent(100, DiscountReason.invitation).of(0), 0);
});
test('Zeilen-Rabatt und Bon-Rabatt zusammen', () {
  final bowl = cart.lines[1].lineId;
  final p = cart.setLineDiscount(bowl, const Discount.percent(10, DiscountReason.regular))
      .setReceiptDiscount(const Discount.percent(10, DiscountReason.promotion)).pricing;
  expect((p.subtotalCents, p.receiptDiscountCents, p.discountCents), (1651, 165, 284));
  expect([for (final l in p.lines) (l.listCents, l.ownDiscountCents, l.shareCents)], [(580, 0, 58), (1190, 119, 107)]);
  expect(p.grossByRate, {TaxRate.normal: 522, TaxRate.reduced1: 964});
  expect((p.goodsCents, p.depositCents, p.totalCents), (1486, 50, 1536));
});
test('Zeile mit zwei Steuersätzen: der Rabatt verteilt sich nach derselben Regel', () {
  // Artikel 10,00 zu 10 %, Option +3,00 mit eigenem Satz 20 %, Rabatt 1,00 als Betrag
  expect(line.pricing.grossByRate, {TaxRate.normal: 277, TaxRate.reduced1: 923});
});
test('Option mit Minus-Aufpreis und 100 %: kein Satz wird durch den Rabatt negativ, die Zeile ergibt 0', () {
  // Artikel 5,00 zu 10 %, Option -1,00 mit eigenem Satz 20 %, Einladung
  expect(line.pricing.grossByRate, {TaxRate.normal: -100, TaxRate.reduced1: 100});
  expect(line.pricing.goodsCents, 0);
});
test('Einladung auf den Bon: Summe ist das Pfand', () {
  expect(cart.setReceiptDiscount(const Discount.percent(100, DiscountReason.invitation)).totalCents, 50);
});

// cart_test.dart
test('der Bon ändert sich: Prozent rechnet mit, Betrag wird gekappt, leerer Bon hat keinen Bon-Rabatt', () {
  final cola = cart.lines[0].lineId, bowl = cart.lines[1].lineId;
  var c = cart.setLineDiscount(cola, const Discount.percent(10, DiscountReason.regular));
  expect(c.setQuantity(cola, 4).pricing.lines[0].ownDiscountCents, 116);
  c = cart.setLineDiscount(cola, const Discount.amount(500, DiscountReason.staff));
  expect(c.setQuantity(cola, 1).pricing.lines[0].ownDiscountCents, 290);
  c = cart.setReceiptDiscount(const Discount.amount(5000, DiscountReason.staff));
  expect(c.pricing.receiptDiscountCents, 1770);
  expect(c.remove(cola).remove(bowl).discount, isNull);
});
test('Entwurf: Rabatte überstehen toJson, fromJson und rebind; ein Entwurf aus 1.10.0 bleibt lesbar', ...);

// discount_random_test.dart
test('2000 zufällige Bons: Zeilen ergeben den Bon, nichts wird negativ, zweimal gerechnet ist gleich', () {
  final random = Random(20261126);
  for (var i = 0; i < 2000; i++) {
    final c = randomCart(random);   // 1 bis 8 Zeilen; Preis 0 bis 50,00; Menge 1 bis 9; Pfand 0 oder 0,25; 0 bis 2 Optionen mit
                                    // Aufpreis -1,00 bis 3,00 (Einzelpreis nie unter 0), teils mit eigenem Satz; jede dritte Zeile
                                    // mit Rabatt (Prozent aus discountPercents oder Betrag bis zum Doppelten des Werts); jeder zweite Bon mit Bon-Rabatt
    final p = c.pricing;
    expect(p.lines.fold<int>(0, (s, l) => s + l.discountCents), p.discountCents, reason: '$i');
    expect(p.lines.fold<int>(0, (s, l) => s + l.goodsCents), p.goodsCents, reason: '$i');
    expect(p.totalCents, p.goodsCents + p.depositCents, reason: '$i');
    expect(p.grossByRate.values.fold<int>(0, (a, b) => a + b), p.goodsCents, reason: '$i');
    for (final (n, l) in p.lines.indexed) {
      expect(l.discountCents, inInclusiveRange(0, l.listCents), reason: '$i/$n');
      expect(l.grossByRate.values.fold<int>(0, (a, b) => a + b), l.goodsCents, reason: '$i/$n');
      final before = c.lines[n].listGrossByRate;
      for (final rate in before.keys) {
        expect(l.grossByRate[rate] ?? 0, greaterThanOrEqualTo(min(0, before[rate]!)), reason: '$i/$n/$rate');
      }
    }
    expect(p.totalCents, greaterThanOrEqualTo(p.depositCents), reason: '$i');
    expect(Cart.fromJson(c.toJson(), catalogOf(c)).pricing.totalCents, p.totalCents, reason: '$i');
  }
});
```

- [ ] **Step 2: Laufen lassen, sie scheitern**

Run: `cd app && ~/flutter/bin/flutter test test/domain/discount_test.dart test/domain/discount_random_test.dart test/domain/cart_test.dart`
Expected: FAIL (`discount.dart` gibt es nicht).

- [ ] **Step 3: Umsetzen** nach Signaturen, Rechnung und Regeln oben.

- [ ] **Step 4: Laufen lassen, alles grün**

Run: `cd app && ~/flutter/bin/flutter test test/domain/ test/features/kassa_test.dart test/features/stufe_1a_off_test.dart && ~/flutter/bin/flutter analyze`
Expected: PASS.

- [ ] **Step 5: Commit** `Stufe 1a Task 9: Rechenregel für Rabatt im offenen Bon`.

### Task 10: Rabatt am gespeicherten Bon, Storno, Abschließen bei 0,00 €

Spec 5.4 (Summe 0, Storno), 5.6 (Spalten und Regeln), 7 (Storno ist das genaue Spiegelbild).

**Files:**
- Modify: `app/lib/domain/{receipt,receipt_rules}.dart`, `app/lib/data/receipt_repository.dart`, `app/lib/features/kassa/sale_service.dart`, `app/lib/sync/push_wire.dart`
- Test: `app/test/data/receipt_repository_test.dart`, `app/test/data/receipt_random_test.dart` (neu), `app/test/domain/receipt_rules_test.dart`, `app/test/features/sale_service_test.dart`, `app/test/sync/push_wire_test.dart`

**Interfaces:**
- Consumes: `Cart.pricing`, `Discount`, `discountReasonLabel` (Task 9); Spalten (Task 1); `checkReceiptRules` (Task 2); Form `v: 2` (Task 4).
- Produces:

```dart
// domain/receipt.dart
class ReceiptDiscount {
  const ReceiptDiscount({this.percent, required this.amountCents, required this.reason});
  final int? percent;  final int amountCents;  final String reason;   // reason ist der Name aus DiscountReason
  String get label;   // "Rabatt 10 % Stammgast" oder "Rabatt Stammgast"
}
class ReceiptLine { ..., this.discountCents = 0, this.discount });
  final int discountCents;           // eigener Rabatt plus Anteil am Bon-Rabatt; beim Storno negativ
  final ReceiptDiscount? discount;   // der eigene Rabatt der Zeile
class Receipt { ..., this.discountCents = 0, this.discount });
  final int discountCents;           // Summe aller Rabatte, positiv; beim Storno negativ
  final ReceiptDiscount? discount;   // der Bon-Rabatt
  int get subtotalCents;             // goodsCents + (discount?.amountCents ?? 0): die Zwischensumme
// goodsCents des Bons ist der Warenwert nach Rabatt (so gilt weiter goodsCents + depositCents = totalCents).

// domain/receipt_rules.dart: ReceiptRule bekommt `discountSums`, checkReceiptRules bekommt `int discountCents = 0`
// features/kassa/sale_service.dart
/// Schließt einen Bon mit Summe 0,00 € ab: eine Bar-Zahlung über 0, die Lade bleibt zu. ArgumentError bei anderer Summe.
Future<SaleResult> completeFree({required String saleId, required Cart cart, required Staff staff});
```

Regeln:
- `_linesOf(cart)` nimmt je Zeile aus `cart.pricing`: `grossByRate` (nach Rabatt), `discountCents`, den eigenen Rabatt. Der Bon bekommt `goodsCents`, `discountCents` und den Bon-Rabatt (`amountCents = receiptDiscountCents`) aus `pricing`. `unitPriceCents` bleibt der Preis vor Rabatt.
- Neue Regel `discountSums`: Summe `discountCents` der Zeilen = `discountCents` des Bons, und Summe (`unitPriceCents * quantity - discountCents`) der Zeilen = `goodsCents`.
- Storno: jede Zeile mit `-discountCents` und dem eigenen Rabatt mit `-amountCents` (Prozent und Grund bleiben), der Bon mit `-discountCents` und dem Bon-Rabatt mit `-amountCents`.
- `push_wire.dart` füllt `discountCents`, `discount` und je Zeile `discountCents`, `discount` aus den Spalten.

- [ ] **Step 1: Die Tests schreiben, die scheitern**

```dart
// receipt_repository_test.dart
test('Bon mit Zeilen-Rabatt und Bon-Rabatt', () async {
  final r = await shop.receipts.finalizeCashSale(saleId: 'r1', cart: discounted, givenCents: 2000, staff: shop.anna);
  // discounted: `cart` mit 10 % Stammgast auf der Bowl und 10 % Aktion auf dem Bon (wie in Task 9)
  expect((r.goodsCents, r.depositCents, r.totalCents, r.discountCents, r.subtotalCents), (1486, 50, 1536, 284, 1651));
  expect((r.discount!.percent, r.discount!.amountCents, r.discount!.reason, r.discount!.label), (10, 165, 'promotion', 'Rabatt 10 % Aktion'));
  expect([for (final l in r.lines) (l.goodsCents, l.discountCents, l.discount?.amountCents)], [(580, 58, null), (1190, 226, 119)]);
  expect(r.grossByRate, {TaxRate.normal: 522, TaxRate.reduced1: 964});
  expect((r.payments.single.amountCents, r.payments.single.changeCents), (1536, 464));
});
test('Storno ist das genaue Spiegelbild, auch der Rabatte', () async {
  final r = await shop.receipts.finalizeCashSale(saleId: 'r1', cart: discounted, givenCents: 2000, staff: shop.anna);
  final v = await shop.receipts.voidReceipt('r1', staff: shop.chef);
  expect((v.goodsCents, v.totalCents, v.discountCents, v.discount!.amountCents), (-1486, -1536, -284, -165));
  expect([for (final l in v.lines) (l.quantity, l.discountCents, l.discount?.amountCents)], [(-2, -58, null), (-1, -226, -119)]);
  expect(v.grossByRate, {for (final e in r.grossByRate.entries) e.key: -e.value});
});
test('Einladung ohne Pfand: Bon über 0,00 € mit einer Bar-Zahlung über 0', () async {
  final free = const Cart.empty().add(teigtaschen).setReceiptDiscount(const Discount.percent(100, DiscountReason.invitation));
  final r = await shop.receipts.finalizeCashSale(saleId: 'f1', cart: free, givenCents: 0, staff: shop.anna);
  expect((r.totalCents, r.discountCents, r.payments.single.kind, r.payments.single.amountCents), (0, 650, PaymentKind.cash, 0));
});

// receipt_random_test.dart
test('200 zufällige Bons mit Rabatt: gespeichert wie gerechnet, Storno ist das Spiegelbild, die Regeln halten', () async {
  // randomCart aus Task 9 (in test/support/random_carts.dart), Artikel vorher in den Katalog der Datenbank eingespielt.
  // Je Bon: verkaufen (bar; jeder dritte mit Bar-Teil, Karte und Trinkgeld, wenn die Summe reicht), dann stornieren.
  // Erwartet je Bon: r.totalCents == c.pricing.totalCents; r.discountCents == c.pricing.discountCents;
  //   v.totalCents == -r.totalCents; v.discountCents == -r.discountCents; v.tipCents == -r.tipCents;
  //   je Zeile v.discountCents == -r.discountCents und v.grossByRate == -r.grossByRate;
  //   je Zahlung v.amountCents == -r.amountCents und v.tipCents == -r.tipCents.
  // Am Ende: die Zusammenfassung des Tages hat revenueCents 0, cashRevenueCents 0, cardRevenueCents 0.
});

// sale_service_test.dart
test('completeFree: Bon gespeichert, der Druckauftrag öffnet die Lade nicht', ...);   // printer.log.single beginnt mit 'print:'
test('completeFree mit Summe über 0: ArgumentError, nichts gespeichert', ...);
```

Dazu `receipt_rules_test.dart`: Ein Bon, dessen Zeilen-Rabatte nicht den Rabatt des Bons ergeben, scheitert an `ReceiptRule.discountSums`. `push_wire_test.dart`: Der Bon `r1` geht mit `discountCents 284`, `discount {percent: 10, amountCents: 165, reason: promotion}` und den Zeilen-Feldern hinaus.

- [ ] **Step 2: Laufen lassen, sie scheitern**

Run: `cd app && ~/flutter/bin/flutter test test/data/receipt_repository_test.dart test/data/receipt_random_test.dart`
Expected: FAIL (`Receipt.discountCents` gibt es nicht).

- [ ] **Step 3: Umsetzen** nach Signaturen und Regeln oben.

- [ ] **Step 4: Laufen lassen, alles grün**

Run: `cd app && ~/flutter/bin/flutter test test/data/ test/domain/ test/sync/ test/features/sale_service_test.dart test/rksv/rksv_journal_test.dart && ~/flutter/bin/flutter analyze`
Expected: PASS.

- [ ] **Step 5: Commit** `Stufe 1a Task 10: Rabatt am gespeicherten Bon, Storno, Abschließen bei 0`.

### Task 11: Rabatt an der Kassa

Spec 5.4 (zwei Stellen, ein Blatt), 5.1 ("nur Chef").

**Files:**
- Create: `app/lib/features/kassa/discount_sheet.dart`, `app/test/features/discount_test.dart`
- Modify: `app/lib/features/kassa/{cart_panel,cart_line_row,kassa_screen}.dart`, `app/lib/l10n/app_*.arb`
- Test: die neue Datei, `app/test/features/stufe_1a_off_test.dart` (bleibt grün)

**Interfaces:**
- Consumes: `cartProvider.notifier.setLineDiscount/setReceiptDiscount`, `Cart.pricing`, `Discount`, `discountPercents` (Task 9); `completeFree` (Task 10); `discountAccess`, `FeatureAccess.allows` (Task 1).
- Produces:

```dart
// features/kassa/discount_sheet.dart
class DiscountSheet extends ConsumerStatefulWidget {
  const DiscountSheet({super.key, required this.lineId, required this.onClose});
  final String? lineId;        // null: der ganze Bon
  final VoidCallback onClose;
}
// features/kassa/cart_line_row.dart
const CartLineRow({..., this.onDiscount});   // VoidCallback?; null: der Tipp auf Name und Preis tut nichts
// features/kassa/cart_panel.dart
const CartPanel({..., this.onLineDiscount, this.onReceiptDiscount, this.onFinishFree});
```

Regeln:
- Darf die angemeldete Person Rabatt geben (`discountAccess.allows(staff)`): Ein Tipp auf Name und Preis einer Bon-Zeile öffnet das Blatt für die Zeile (Minus, Menge, Plus bleiben, wie sie sind), und im Summenblock steht die Taste "Rabatt" (`discount-button`, nur bei einem Bon mit Zeilen). Sonst gibt es keine Tippfläche und keine Taste: Die Zeile ist genau die von 1.10.0.
- Ein gesetzter Rabatt ist immer zu sehen, auch wenn die Person keinen geben darf: unter der Zeile eine kleine Reihe (`line-discount-<lineId>`: "−10 % Stammgast" und rechts "−1,19 €", beim Betrag-Rabatt "Rabatt Stammgast"), im Summenblock eine Reihe (`receipt-discount`). Ein Tipp auf eine Reihe öffnet das Blatt nur, wenn die Person Rabatt geben darf. Die Summe und "inkl. MwSt" rechnen nach Rabatt.
- Das Blatt steht in der Bon-Spalte (`PayColumnFrame`, neuer Zustand `_Side.discount`, Schlüssel `discount-sheet`): Kopf "Rabatt auf: 2x Huhn Bowl" mit dem Wert vor diesem Rabatt (`discount-target`; beim Bon "ganzer Bon" mit der Zwischensumme), "Grund" mit fünf Tasten (`discount-reason-<name>`), "Höhe" mit einer Taste je Wert aus `discountPercents` (`discount-percent-<n>`) und "Betrag" (`discount-amount`, öffnet das Zahlenfeld), "Neu" mit dem Wert nach dem Rabatt (`discount-new`), "Entfernen" (`discount-remove`, nur wenn ein Rabatt da ist) und "Übernehmen" (`discount-apply`, aus, solange Grund oder Höhe fehlen). Beim Bon steht der Hinweis `discountLineHint` (`discount-hint`). "Einladung" wählt 100 % vor. Ein Betrag über dem Wert wird gekappt angezeigt.
- Ist die Summe 0,00 € und der Bon hat einen Rabatt (`pricing.discountCents > 0`), steht statt "Bar" und "Karte" eine Taste "Abschließen" (`finish-free`, Text `kassaFinish`); sie ruft `completeFree` und führt zu "Verkauf fertig". Ein Bon mit Summe 0 ohne Rabatt (Leitungswasser) zeigt "Bar" und "Karte" wie in 1.10.0.
- ARB: `discountTitle` "Rabatt", `discountOn` "Rabatt auf: {what}", `discountWholeReceipt` "ganzer Bon", `discountReason` "Grund", `discountReasonRegular` "Stammgast", `discountReasonStaff` "Mitarbeiter", `discountReasonComplaint` "Reklamation", `discountReasonPromotion` "Aktion", `discountReasonInvitation` "Einladung", `discountHeight` "Höhe", `discountAmount` "Betrag", `discountNew` "Neu", `discountRemove` "Entfernen", `discountApply` "Übernehmen", `discountLineHint` "Für eine einzelne Zeile die Zeile im Bon antippen.", `discountRowPercent` "−{percent} % {reason}", `discountRowAmount` "Rabatt {reason}".

- [ ] **Step 1: Die Tests schreiben, die scheitern**

```dart
// features/discount_test.dart (Schalter über setSettings; Bon: 2 × Cola, Teigtaschen = 12,30 + 0,50 Pfand)
testWidgets('Zeile: Tipp auf den Namen öffnet das Blatt, 10 % Stammgast steht unter der Zeile', (t) async {
  await openWithDiscount(t, FeatureAccess.all);
  await t.tap(find.text('Teigtaschen').last);
  await t.pumpAndSettle();
  expect(buttonOf(t, 'discount-apply').onPressed, isNull);          // Grund ist Pflicht
  await t.tap(find.byKey(const Key('discount-reason-regular')));
  await t.tap(find.byKey(const Key('discount-percent-10')));
  await t.pump();
  expect(textOf(t, const Key('discount-new')), '5,85 €');
  await t.tap(find.byKey(const Key('discount-apply')));
  await t.pumpAndSettle();
  final line = cartOf(t).lines[1];
  expect(find.descendant(of: find.byKey(Key('line-discount-${line.lineId}')), matching: find.text('−10 % Stammgast')), findsOneWidget);
  expect(textOf(t, const Key('cart-total')), '12,15 €');
});
testWidgets('ganzer Bon: Taste "Rabatt", Hinweis auf die Zeile, Reihe im Summenblock', (t) async {
  await openWithDiscount(t, FeatureAccess.all);
  await t.tap(find.byKey(const Key('discount-button')));
  await t.pumpAndSettle();
  expect(find.byKey(const Key('discount-hint')), findsOneWidget);
  await t.tap(find.byKey(const Key('discount-reason-promotion')));
  await t.tap(find.byKey(const Key('discount-percent-20')));
  await t.tap(find.byKey(const Key('discount-apply')));
  await t.pumpAndSettle();
  expect(find.byKey(const Key('receipt-discount')), findsOneWidget);
  expect(textOf(t, const Key('cart-total')), '10,34 €');             // 12,30 - 2,46 + 0,50
});
testWidgets('"Einladung" wählt 100 % vor; Summe 0,00 €: "Abschließen" statt Bar und Karte, die Lade bleibt zu', (t) async {
  // nur Teigtaschen am Bon, Drucker eingerichtet; discount-button, discount-reason-invitation, discount-apply
  expect(find.byKey(const Key('pay-cash')), findsNothing);
  expect(find.byKey(const Key('pay-card')), findsNothing);
  await t.tap(find.byKey(const Key('finish-free')));
  await t.pumpAndSettle();
  expect(await queryRows(t, 'SELECT total_cents, discount_cents FROM receipts'), [{'total_cents': 0, 'discount_cents': 650}]);
  expect(await queryRows(t, 'SELECT kind, amount_cents FROM payments'), [{'kind': 'cash', 'amount_cents': 0}]);
  expect(printerOf(t).log.single, startsWith('print:'));
});
testWidgets('nur Chef: Anna hat keine Taste; der Rabatt des Chefs bleibt, Anna kann ihn nicht ändern', (t) async {
  // Chef (pin 4711) setzt 10 % auf den Bon, meldet sich ab, Anna meldet sich an und boniert eine Cola dazu
  expect(find.byKey(const Key('discount-button')), findsNothing);
  expect(find.byKey(const Key('receipt-discount')), findsOneWidget);
  await t.tap(find.byKey(const Key('receipt-discount')));
  await t.pumpAndSettle();
  expect(find.byKey(const Key('discount-sheet')), findsNothing);
  expect(cartOf(t).discount!.percent, 10);
});
testWidgets('Schalter wird ausgeschaltet, während ein Rabatt am Bon liegt: er bleibt und zählt', ...);
testWidgets('Betrag: 20,00 € auf eine Zeile mit 6,50 € wird gekappt, "Neu" zeigt 0,00 €', ...);
testWidgets('"Entfernen" nimmt den Rabatt weg; "Bon leeren" und "Rückgängig" bringen die Rabatte zurück', ...);
testWidgets('Menge der Zeile ändern: der Prozent-Rabatt rechnet mit (2 × Cola mit 10 %: −0,58 €, 3 ×: −0,87 €)', ...);
```

- [ ] **Step 2: Laufen lassen, sie scheitern**

Run: `cd app && ~/flutter/bin/flutter test test/features/discount_test.dart`
Expected: FAIL (`discount-button` gibt es nicht).

- [ ] **Step 3: Umsetzen** nach den Regeln oben; Texte in fünf Sprachen.

- [ ] **Step 4: Laufen lassen, alles grün**

Run: `cd app && ~/flutter/bin/flutter test test/features/discount_test.dart test/features/kassa_test.dart test/features/cash_test.dart test/features/card_test.dart test/features/stufe_1a_off_test.dart test/golden/kassa_golden_test.dart test/l10n_review_test.dart && ~/flutter/bin/flutter analyze`
Expected: PASS, kein Golden ändert sich.

- [ ] **Step 5: Commit** `Stufe 1a Task 11: Rabatt an der Kassa`.

### Task 12: Freier Betrag

Spec 5.5.

**Files:**
- Create: `app/lib/features/kassa/open_amount_sheet.dart`, `app/test/features/open_amount_test.dart`
- Modify: `app/lib/domain/cart.dart`, `app/lib/domain/kitchen_ticket.dart`, `app/lib/features/kassa/{cart_controller,cart_panel,cart_line_row,kassa_screen}.dart`, `app/lib/l10n/app_*.arb`
- Test: die neue Datei, `app/test/domain/{cart,kitchen_ticket}_test.dart`, `app/test/data/stats_repository_test.dart`, `server/test/overview.test.ts`

**Interfaces:**
- Consumes: `openAmountAccess` (Task 1), `DiscountSheet` (Task 11, Rabatt geht wie bei jeder Zeile).
- Produces:

```dart
// domain/cart.dart
const openAmountMaxCents = 999999;                                   // 9.999,99 €
const openAmountRates = [TaxRate.normal, TaxRate.reduced1, TaxRate.reduced2, TaxRate.zero];   // 20, 10, 13, 0
String openAmountItemId(TaxRate rate);                               // 'open-amount-20'
bool isOpenAmountItemId(String itemId);
String openAmountName(TaxRate rate);                                 // 'Diverses 20 %' (so steht es am Bon)
class CartLine { bool get isOpenAmount; }
class Cart { Cart addOpenAmount({required int amountCents, required TaxRate rate, String? lineId}); }
// features/kassa/cart_controller.dart
void addOpenAmount({required int amountCents, required TaxRate rate});
// features/kassa/open_amount_sheet.dart
class OpenAmountSheet extends ConsumerStatefulWidget {
  const OpenAmountSheet({super.key, required this.onClose});
  final VoidCallback onClose;
}
```

Regeln:
- `addOpenAmount` legt immer eine neue Zeile an (zwei freie Beträge mit demselben Satz verschmelzen nie), Menge 1. Der Artikel der Zeile entsteht im Code: Id `openAmountItemId(rate)`, Name `openAmountName(rate)`, Preis `amountCents`, kein Pfand, keine Auswahl. `ArgumentError` bei Betrag unter 1 oder über `openAmountMaxCents` und bei einem Satz außerhalb von `openAmountRates`.
- `toJson` schreibt bei so einer Zeile zusätzlich `"open": {"cents": 1250, "taxPercent": 20}`. `fromJson` baut die Zeile daraus, ohne den Katalog zu fragen; ist `open` unlesbar oder außerhalb der Grenzen, fällt die Zeile weg. `rebind` lässt sie stehen.
- Darf die angemeldete Person (`openAmountAccess.allows(staff)`), steht im Kopf der Bon-Spalte die Taste "Freier Betrag" (`open-amount-button`), auch am leeren Bon. Das Blatt (`_Side.openAmount`, Schlüssel `open-amount-sheet`): "Betrag" mit Zahlenfeld (`KeypadInput(maxIntDigits: 4)`), "Steuersatz" mit vier Tasten (`open-rate-20`, `open-rate-10`, `open-rate-13`, `open-rate-0`, keine ist vorgewählt), "Auf den Bon" (`open-amount-add`, aus, solange der Betrag 0 ist oder der Satz fehlt).
- Die Zeile am offenen Bon heißt in der Bediensprache `openAmountLine` ("Diverses {percent} %"); gespeichert und gedruckt wird der deutsche Name. Menge und Rabatt gehen wie bei jeder Zeile.
- Küchenbon: `buildKitchenTicket` lässt Zeilen mit `isOpenAmountItemId(l.itemId)` weg. Übersicht (Tablet und Server): Die Zeile steht bei "meistverkauft" als "Diverses 20 %" je Satz und bei den Kategorien unter "Sonstiges"; dafür ist kein Code nötig, die Tests halten es fest.
- ARB: `openAmountTitle` "Freier Betrag", `openAmountAmount` "Betrag", `openAmountTax` "Steuersatz", `openAmountAdd` "Auf den Bon", `openAmountLine` "Diverses {percent} %".

- [ ] **Step 1: Die Tests schreiben, die scheitern**

```dart
// cart_test.dart
test('freier Betrag: eigene Zeile je Tipp, Steuersatz zählt, Entwurf bleibt lesbar', () {
  final c = const Cart.empty().addOpenAmount(amountCents: 1250, rate: TaxRate.normal).addOpenAmount(amountCents: 300, rate: TaxRate.normal);
  expect([for (final l in c.lines) (l.item.id, l.item.name, l.quantity, l.goodsCents, l.isOpenAmount)],
      [('open-amount-20', 'Diverses 20 %', 1, 1250, true), ('open-amount-20', 'Diverses 20 %', 1, 300, true)]);
  expect(c.pricing.grossByRate, {TaxRate.normal: 1550});
  final back = Cart.fromJson(c.toJson(), catalog);
  expect([for (final l in back.lines) l.goodsCents], [1250, 300]);
  expect(c.rebind(catalog).lines, hasLength(2));
});
test('Grenzen: 0, 10.000,00 € und der Satz 19 % werfen ArgumentError', () {
  for (final cents in [0, 1000000]) {
    expect(() => const Cart.empty().addOpenAmount(amountCents: cents, rate: TaxRate.normal), throwsArgumentError);
  }
  expect(() => const Cart.empty().addOpenAmount(amountCents: 100, rate: TaxRate.special), throwsArgumentError);
  expect(const Cart.empty().addOpenAmount(amountCents: 999999, rate: TaxRate.zero).totalCents, 999999);
});

// features/open_amount_test.dart
testWidgets('12,50 € zu 10 % auf den Bon, bar bezahlt: Zeile "Diverses 10 %" am Bon', (t) async {
  await pumpKassa(t); await setSettings(t, (s) => s.copyWith(openAmountAccess: FeatureAccess.all));
  await t.tap(find.byKey(const Key('open-amount-button'))); await t.pumpAndSettle();
  await tapKeys(t, '1 2 , 5 0');                                     // Tasten wie im Bar-Blatt
  expect(buttonOf(t, 'open-amount-add').onPressed, isNull);          // der Satz fehlt noch
  await t.tap(find.byKey(const Key('open-rate-10')));
  await t.tap(find.byKey(const Key('open-amount-add'))); await t.pumpAndSettle();
  expect(textOf(t, const Key('cart-total')), '12,50 €');
  await t.tap(find.byKey(const Key('pay-cash'))); await t.pumpAndSettle();
  await t.tap(find.byKey(const Key('finish-sale'))); await t.pumpAndSettle();
  expect(await queryRows(t, 'SELECT item_id, name, unit_price_cents, gross10_cents FROM receipt_lines'),
      [{'item_id': 'open-amount-10', 'name': 'Diverses 10 %', 'unit_price_cents': 1250, 'gross10_cents': 1250}]);
});
testWidgets('nur Chef: Anna hat die Taste nicht; die Zeile des Chefs bleibt und geht mit Minus weg', ...);
testWidgets('Englisch: die Zeile heißt am Bildschirm in der Bediensprache, im gespeicherten Bon "Diverses 20 %"', ...);
```

Dazu: `kitchen_ticket_test.dart` `'freier Betrag kommt nicht auf den Küchenbon; ein Bon nur aus freien Beträgen gibt null'`; `stats_repository_test.dart` `'freier Betrag: "Diverses 20 %" bei meistverkauft, "Sonstiges" bei den Kategorien'`; `overview.test.ts` dasselbe am Server mit einem Bon in `v: 2`, dessen Zeile `itemId: 'open-amount-20'` trägt.

- [ ] **Step 2: Laufen lassen, sie scheitern**

Run: `cd app && ~/flutter/bin/flutter test test/domain/cart_test.dart test/features/open_amount_test.dart test/domain/kitchen_ticket_test.dart`
Expected: FAIL (`addOpenAmount` gibt es nicht).

- [ ] **Step 3: Umsetzen** nach Signaturen und Regeln oben; Texte in fünf Sprachen.

- [ ] **Step 4: Laufen lassen, alles grün**

Run: `cd app && ~/flutter/bin/flutter test test/domain/ test/features/open_amount_test.dart test/features/discount_test.dart test/features/kassa_test.dart test/features/kitchen_service_test.dart test/features/stufe_1a_off_test.dart test/data/stats_repository_test.dart test/l10n_review_test.dart && ~/flutter/bin/flutter analyze`; `cd server && npx vitest run test/overview.test.ts`
Expected: PASS.

- [ ] **Step 5: Commit** `Stufe 1a Task 12: Freier Betrag`.

### Task 13: Bondruck, Abschluss und Monatsabrechnung mit den neuen Zeilen

Spec 5.3 (am Bon; Abschluss zeigt Trinkgeld je Mitarbeiter), 5.4 (am Bon), 5.7 (Abschluss, Monatsabrechnung, Bons im Detail).

**Files:**
- Modify: `app/lib/domain/{receipt_layout,report_layout,day,period_report}.dart`, `app/lib/data/{day_repository,period_report_repository,stats_repository}.dart`, `app/lib/features/close/income_card.dart`, `app/lib/features/bons/receipt_detail.dart`, `app/lib/l10n/app_*.arb`, `app/test/support/report_samples.dart`
- Test: `app/test/domain/{receipt_layout,report_layout}_test.dart`, `app/test/data/{day_repository,period_report_repository,stats_repository}_test.dart`, `app/test/features/{close,close_month,bons,report_print}_test.dart`

**Interfaces:**
- Consumes: `Receipt.{payments, tipCents, discountCents, discount, subtotalCents}`, `ReceiptLine.{discountCents, discount}`, `ReceiptDiscount.label` (Task 2 und 10).
- Produces:

```dart
// domain/day.dart
class StaffTip { const StaffTip({required this.staffId, required this.staffName, required this.cents}); }
// DaySummary und PeriodReport, neue Felder (im Konstruktor mit Vorgabe 0 und leer):
final int discountCount;          // Bons mit Rabatt: Verkauf +1, Storno -1
final int discountCents;          // Summe der Rabatte, Storno zieht ab
final int cardTipCents;           // Trinkgeld der Kartenzahlungen, Storno zieht ab
final List<StaffTip> tipsByStaff; // nach Name, Zeilen mit 0 fehlen; die Person steht in tip_staff_id der Zahlung
int get cardAccountCents;         // cardRevenueCents + cardTipCents
// features/close/income_card.dart: IncomeFigures bekommt dieselben Felder
```

Kundenbon (deutsch, feste Texte), nur wo es etwas zu zeigen gibt; ein Bon ohne Rabatt, Trinkgeld und zweite Zahlung druckt Zeile für Zeile wie in 1.10.0:

```
2 x Cola 0,33 l                 5,80
1 x Huhn Bowl                  11,90
  XXL (+2,00)
  Rabatt 10 % Stammgast        -1,19        eingerückt unter der Zeile, nach ihren Optionen
------------------------------------
Zwischensumme                  16,51        nur mit Bon-Rabatt: subtotalCents
Rabatt 10 % Aktion             -1,65
Pfand                           0,50
SUMME EUR                      15,36
…Steuer wie bisher, aus den Beträgen nach Rabatt…
Bar                            10,00        jede Zahlung in ihrer Reihenfolge
Karte                           6,00        chargedCents: mit Trinkgeld
  davon Trinkgeld               0,64
  VISA **** 4242
```

Beim Storno stehen dieselben Zeilen mit umgekehrtem Vorzeichen. Berichte (deutsch), jede neue Zeile nur, wenn sie nicht 0 ist:

```
EINNAHMEN
Bar          12 Bons          300,00
Karte         5 Bons          120,00
Gesamt       16 Bons          420,00
Rabatte       3 Bons          -12,40        b.row3('Rabatte', bonsText(discountCount), amount(-discountCents))
------------------------------------
TRINKGELD KARTE                              nur mit tipsByStaff
Anna                            6,40
Chef                           -3,20
Gesamt                          3,20
Am Kartenkonto                123,20         cardAccountCents
```

Am Bildschirm: Abschluss und Monat zeigen in der Karte "Einnahmen" unter denselben Bedingungen "Rabatte" (`income-discounts`), "Trinkgeld Karte" (`income-card-tip`) mit einer Zeile je Person (`income-tip-<staffId>`) und "Am Kartenkonto" (`income-card-account`). Das Bon-Detail zeigt unter einer Zeile ihren Rabatt (`detail-line-discount-<Stelle>`), über der Summe Zwischensumme und Bon-Rabatt (`detail-discount`) und unter der Karte "davon Trinkgeld" (`detail-tip`). Die Übersicht am Tablet rechnet "meistverkauft" und Kategorien je Zeile mit dem Wert nach Rabatt (Preis mal Menge minus `discount_cents`), wie der Server seit Task 5. ARB: `closeDiscounts` "Rabatte", `closeCardTip` "Trinkgeld Karte", `closeCardAccount` "Am Kartenkonto", `bonsSubtotal` "Zwischensumme", `bonsTipIncluded` "davon Trinkgeld".

- [ ] **Step 1: Die Tests schreiben, die scheitern**

```dart
// receipt_layout_test.dart (rows(ops): die Paare links/rechts der Druckzeilen, Helfer der Datei)
test('Bon mit Zeilen-Rabatt, Bon-Rabatt, Bar-Teil, Karte und Trinkgeld', () {
  final r = mixedDiscounted;   // `discounted` aus Task 10, bar 10,00, Karte 5,36, Trinkgeld 0,64
  expect(rows(layoutReceipt(r, business)), containsAllInOrder([
    ('1 x Huhn Bowl', '11,90'), ('  Rabatt 10 % Stammgast', '-1,19'),
    ('Zwischensumme', '16,51'), ('Rabatt 10 % Aktion', '-1,65'), ('Pfand', '0,50'), ('SUMME EUR', '15,36'),
    ('Bar', '10,00'), ('Karte', '6,00'), ('  davon Trinkgeld', '0,64'),
  ]));
  expect(rows(layoutReceipt(r, business)).map((x) => x.$1), isNot(contains('Gegeben')));
});
test('Storno davon: dieselben Zeilen mit Minus', () {
  expect(rows(layoutReceipt(voidOf(mixedDiscounted), business, voidedNumber: 1)), containsAllInOrder([
    ('  Rabatt 10 % Stammgast', '1,19'), ('Zwischensumme', '-16,51'), ('Rabatt 10 % Aktion', '1,65'), ('SUMME EUR', '-15,36'),
    ('Bar', '-10,00'), ('Karte', '-6,00'), ('  davon Trinkgeld', '-0,64'),
  ]));
});
test('Betrag-Rabatt ohne Prozent: "Rabatt Mitarbeiter"', ...);

// report_layout_test.dart
test('Tagesabschluss mit Rabatten und Trinkgeld', () {
  final s = daySample(cardRevenueCents: 12000, discountCount: 3, discountCents: 1240, cardTipCents: 320,
      tipsByStaff: const [StaffTip(staffId: 'a', staffName: 'Anna', cents: 640), StaffTip(staffId: 'c', staffName: 'Chef', cents: -320)]);
  final text = lines(layoutDayReport(s, business, registerName: null, drawer: true, printedAt: now));
  expect(text, containsAllInOrder([
    contains('Rabatte'), 'TRINKGELD KARTE', startsWith('Anna'), startsWith('Chef'), startsWith('Gesamt'), startsWith('Am Kartenkonto'),
  ]));
  expect(text.firstWhere((l) => l.startsWith('Rabatte')), allOf(contains('3 Bons'), endsWith('-12,40')));
  expect(text.firstWhere((l) => l.startsWith('Am Kartenkonto')), endsWith('123,20'));
});
test('ohne Rabatt und Trinkgeld: kein Wort davon im Ausdruck', () {
  final text = lines(layoutDayReport(daySample(), business, registerName: null, drawer: true, printedAt: now)).join('\n');
  for (final word in ['Rabatte', 'TRINKGELD', 'Kartenkonto']) { expect(text, isNot(contains(word))); }
});

// day_repository_test.dart
test('Rabatte und Trinkgeld des Tages, Trinkgeld je Person; Storno durch den Chef zieht bei Anna ab', () async {
  await shop.receipts.finalizeCashSale(saleId: 'r1', cart: discounted, givenCents: 2000, staff: shop.anna);        // Rabatt 2,84
  await shop.receipts.finalizeCardSale(saleId: 't1', cart: cartCard, staff: shop.anna, provider: 'sumup', tipCents: 35);
  await shop.receipts.finalizeCardSale(saleId: 't2', cart: cartCard, staff: shop.chef, provider: 'sumup', tipCents: 100);
  var s = (await shop.days.summary())!;
  expect((s.discountCount, s.discountCents, s.cardTipCents, s.cardRevenueCents, s.cardAccountCents), (1, 284, 135, 1930, 2065));
  expect([for (final x in s.tipsByStaff) (x.staffName, x.cents)], [('Anna', 35), ('Chef', 100)]);
  await shop.receipts.voidReceipt('t1', staff: shop.chef);
  await shop.receipts.voidReceipt('r1', staff: shop.chef);
  s = (await shop.days.summary())!;
  expect((s.discountCount, s.discountCents, s.cardTipCents), (0, 0, 100));
  expect([for (final x in s.tipsByStaff) (x.staffName, x.cents)], [('Chef', 100)]);
});
```

Dazu: `period_report_repository_test.dart` `'Monat: Rabatte und Trinkgeld je Person; ein Storno im Folgemonat steht dort als Minus bei der Person, die kassiert hat'`; `stats_repository_test.dart` `'meistverkauft und Kategorien nach Rabatt'` (Bon `r1`: Cola 5,22, Huhn Bowl 9,64); `close_test.dart` `'Karte Einnahmen zeigt Rabatte, Trinkgeld je Person und "Am Kartenkonto"; ohne sie keine der Zeilen'`; `bons_test.dart` `'Detail zeigt Zeilen-Rabatt, Bon-Rabatt und Trinkgeld'`.

- [ ] **Step 2: Laufen lassen, sie scheitern**

Run: `cd app && ~/flutter/bin/flutter test test/domain/receipt_layout_test.dart test/domain/report_layout_test.dart test/data/day_repository_test.dart`
Expected: FAIL (keine Zeile "Zwischensumme", kein Feld `discountCount`).

- [ ] **Step 3: Umsetzen** nach den Bildern und Regeln oben; Texte am Bildschirm in fünf Sprachen.

- [ ] **Step 4: Laufen lassen, alles grün**

Run: `cd app && ~/flutter/bin/flutter test test/domain/ test/data/ test/features/close_test.dart test/features/close_month_test.dart test/features/close_print_test.dart test/features/report_print_test.dart test/features/bons_test.dart test/features/overview_test.dart test/golden/close_golden_test.dart test/golden/close_month_golden_test.dart test/golden/bons_golden_test.dart test/l10n_review_test.dart && ~/flutter/bin/flutter analyze`
Expected: PASS, kein Golden ändert sich. Dann pushen und die Workflows lesen.

- [ ] **Step 5: Commit** `Stufe 1a Task 13: Bondruck, Abschluss und Monatsabrechnung mit Rabatt und Trinkgeld`.

## Teil 4: Prüfung und Übergabe

### Task 14: Texte in fünf Sprachen prüfen, Bilder der neuen Blätter

Spec 3 (Sprachen), 7 (Bilder in hell und dunkel, Deutsch und Arabisch).

**Files:**
- Create: `app/test/golden/stufe_1a_golden_test.dart`, `app/test/golden/goldens/1a_*.png`
- Modify: `app/test/features/l10n_layout_test.dart`, `app/test/features/l10n_kassa_test.dart`, `docs/uebersetzungen/{en,zh,tr,ar}.md` (erzeugt), bei Befunden die ARB-Dateien und die Blätter
- Test: die genannten Dateien, `app/test/features/language_test.dart`, `app/test/l10n_review_test.dart`

**Interfaces:**
- Consumes: `TipSheet`, das Bar-Blatt mit "Teil bar", `DiscountSheet`, `OpenAmountSheet`, die Rabatt-Reihen in `CartPanel`, `PaymentSection`; `setSettings`, `pumpKassa(pin:)` (Task 6).
- Produces: sechzehn Bilder der Blätter und zwei Bilder des Bons: `1a_trinkgeld`, `1a_teil_bar`, `1a_rabatt`, `1a_freier_betrag`, je als `_hell.png`, `_dunkel.png`, `_arabisch_hell.png`, `_arabisch_dunkel.png`; dazu `1a_bon_mit_rabatt_hell.png` und `1a_bon_mit_rabatt_arabisch_hell.png`.

- [ ] **Step 1: Die Tests schreiben**

```dart
// l10n_layout_test.dart: in der Schleife über fünf Sprachen und die Größen 1280×800 und 1024×600
testWidgets('${language.name} ${size.width.toInt()}×${size.height.toInt()}: die neuen Blätter ohne Überlauf', (t) async {
  // alle vier Schalter an, Chef angemeldet, Bon: Huhn Bowl mit Auswahl, 2 × Cola
  // nacheinander öffnen und wieder schließen: open-amount-sheet, discount-sheet (Zeile, mit Betrag-Zahlenfeld), discount-sheet (Bon),
  // Bar-Blatt mit cash-mode-split, tip-sheet (mit "Anderer Betrag"), Einstellungen mit der Karte "Zahlen"
  expect(t.takeException(), isNull);   // nach jedem Blatt: kein "overflowed"
});
testWidgets('ar: Beträge und Zahlenfeld der neuen Blätter stehen von links nach rechts', (t) async {
  // tip-due, split-rest, discount-new: Directionality.of(...) == TextDirection.ltr; die Taste "1" liegt links von "3"
});
// l10n_kassa_test.dart
testWidgets('en, zh, tr, ar: die Tasten "Rabatt" und "Freier Betrag" stehen in der Bediensprache', (t) async {
  // erwartet auf discount-button: 'Discount', '折扣', 'İndirim', 'خصم'
});

// stufe_1a_golden_test.dart
for (final (language, dark) in [(AppLanguage.de, false), (AppLanguage.de, true), (AppLanguage.ar, false), (AppLanguage.ar, true)]) {
  testWidgets('Trinkgeld (${language.name}, ${dark ? 'dunkel' : 'hell'})', (t) async {
    await openTipSheet(t, language, dark ? Brightness.dark : Brightness.light);   // Cola + Teigtaschen, tip-pays-1000 gewählt
    await expectLater(find.byType(KassaApp), matchesGoldenFile('goldens/1a_trinkgeld${language == AppLanguage.ar ? '_arabisch' : ''}_${dark ? 'dunkel' : 'hell'}.png'));
  });
  // ebenso: Teil bar (5,00 getippt), Rabatt (Zeile, Stammgast und 10 % gewählt), Freier Betrag (12,50 getippt, 10 % gewählt)
}
```

- [ ] **Step 2: Laufen lassen**

Run: `cd app && ~/flutter/bin/flutter test test/features/l10n_layout_test.dart test/features/l10n_kassa_test.dart test/features/language_test.dart test/l10n_review_test.dart`
Expected: Befunde (Überlauf, fehlender Schlüssel, unübersetzter Text) scheitern hier und werden behoben; die Golden-Datei scheitert, weil die Bilder fehlen.

- [ ] **Step 3: Beheben und Bilder erzeugen**

`~/flutter/bin/flutter gen-l10n` (die Datei `build/l10n_untranslated.json` ist leer), `dart run tool/l10n_review.dart`, dann `~/flutter/bin/flutter test --update-goldens test/golden/stufe_1a_golden_test.dart`. Jedes der achtzehn Bilder ansehen: nichts abgeschnitten, Arabisch gespiegelt und mit verbundener Schrift, Beträge links nach rechts, dunkel lesbar.

- [ ] **Step 4: Laufen lassen, alles grün**

Run: `cd app && ~/flutter/bin/flutter test test/features/l10n_layout_test.dart test/features/l10n_kassa_test.dart test/features/l10n_areas_test.dart test/features/language_test.dart test/l10n_review_test.dart test/no_text_field_test.dart test/golden/ && ~/flutter/bin/flutter analyze`
Expected: PASS; außer den neuen Bildern hat sich kein Golden geändert (`git status app/test/golden/goldens`).

- [ ] **Step 5: Commit** `Stufe 1a Task 14: Texte in fünf Sprachen geprüft, Bilder der neuen Blätter`.

### Task 15: Prüfwerkzeug des BMF und Zusammenspiel von Tablet und Server

Spec 7 (Prüfwerkzeug über eine Kette mit Rabatt, Trinkgeld, gemischter Zahlung und Storno; `tool/e2e.sh`).

**Files:**
- Modify: `app/test/rksv/pruefwerkzeug_test.dart`, `app/test_e2e/push_and_sync_test.dart`
- Test: dieselben, über `tool/rksv/pruefen.sh` und `tool/e2e.sh`

**Interfaces:**
- Consumes: `RksvRig.sellCard(id, cart, cashPartCents:, tipCents:)` (Task 2), `Cart.setLineDiscount/setReceiptDiscount/addOpenAmount` (Task 9 und 12), die Adressen der Verwaltung aus Task 5.
- Produces: nichts für andere Aufgaben.

- [ ] **Step 1: Die Kette und den Lauf gegen den Server erweitern**

```dart
// pruefwerkzeug_test.dart, nach dem Verkauf 'gross' und vor dem Storno von 'nur-10', jeweils nach tick():
await rig.sell('rabatt', const Cart.empty().add(cola).add(huhnBowl, options: [xxl, nudeln])
    .setLineDiscount(/* Bowl */, const Discount.percent(10, DiscountReason.regular))
    .setReceiptDiscount(const Discount.percent(10, DiscountReason.promotion)));
await rig.sellCard('trinkgeld', const Cart.empty().add(teigtaschen).add(cola), tipCents: 35);
await rig.sellCard('gemischt', const Cart.empty().add(teigtaschen).add(cola).addOpenAmount(amountCents: 1250, rate: TaxRate.reduced2),
    cashPartCents: 1000, tipCents: 125);
await rig.sell('einladung', const Cart.empty().add(teigtaschen).setReceiptDiscount(const Discount.percent(100, DiscountReason.invitation)));
await rig.receipts.voidReceipt('gemischt', staff: rig.chef);
// erwartete Arten: 'start', 12 × 'sale', 2 × 'voided' (in der Reihenfolge der Kette), dann wie bisher 'sale', 'sale', 'collective', …
```

Die vorhandenen Erwartungen (`rig.verifyChain(1)`, keine Beanstandung des Werkzeugs) bleiben. `push_and_sync_test.dart` bekommt `'gemischter Bon mit Rabatt und Trinkgeld kommt am Server an'`: am Tablet verkaufen (`discounted` aus Task 10, bar 10,00, Karte 5,36, Trinkgeld 0,64), abgleichen, dann über die Verwaltung lesen: `GET …/receipts/:id` hat zwei Zahlungen, `tipCents 64`, `discountCents 284`; `GET …/days/:id` hat `cashCents 1000`, `cardCents 536`, `cardTipCents 64`, `discountCount 1`.

- [ ] **Step 2: Prüfwerkzeug laufen lassen**

Run: `tool/rksv/pruefen.sh`
Expected: PASS, das Werkzeug beanstandet keinen Eintrag. Fehlt das Werkzeug ("Das Prüfwerkzeug fehlt unter …"), ist dieser Schritt nicht erledigt: offen lassen und im Bericht nennen, nicht überspringen.

- [ ] **Step 3: Zusammenspiel laufen lassen**

Run: `tool/e2e.sh` (kein APK-Bau zur selben Zeit im Ordner)
Expected: PASS, alle Tests in `app/test_e2e`.

- [ ] **Step 4: Befunde beheben**, jeweils mit einem Test in der Aufgabe, der der Code gehört, und beide Läufe wiederholen.

- [ ] **Step 5: Commit** `Stufe 1a Task 15: Prüfwerkzeug und Zusammenspiel mit Rabatt, Trinkgeld, gemischter Zahlung`.

### Task 16: Prüfliste für Niko, Version 1.11.0, Abschnitt 10 der Spec

Spec 5.8, 7 (Prüfliste), 10.

**Files:**
- Create: `docs/testen/stufe-1a-pruefliste.md`
- Modify: `app/pubspec.yaml` (`version: 1.11.0+13`), `app/lib/core/app_info.dart` (`appVersion = '1.11.0'`), `docs/superpowers/specs/2026-11-26-stufe-1a-zahlen-design.md` (Abschnitt 10), `PRODUCT.md` (ein Absatz zu den vier Funktionen und ihren Schaltern)
- Test: `app/test/features/settings_test.dart` (prüft Version gegen `pubspec.yaml`)

**Interfaces:**
- Consumes: alles Vorige.
- Produces: nichts für andere Aufgaben. Diese Aufgabe baut keine Installationsdatei und lädt nichts hoch; das ist ein eigener Schritt nach dem Plan, nach Nikos Ja, und nach dem Server.

Die Prüfliste, in einfachen Worten und zum Abhaken, Aufbau wie `docs/testen/sprachen-pruefliste.md` (bei jedem Punkt: was tun, was man sehen soll):
- **0. Update von 1.10.0:** Bons und Einstellungen sind da, unten steht "Kassa Version 1.11.0", in der Karte "Zahlen" ist alles aus, ein Verkauf bar und einer mit Karte laufen wie immer (kein neuer Schritt).
- **A. Trinkgeld bei Karte (echtes Terminal):** Schalter an; "Gast zahlt" mit Vorschlag, mit "Anderer Betrag", "Ohne Trinkgeld"; Nachfrage bei Vertippen; der Betrag am Terminal; Bon mit "davon Trinkgeld"; Entnahme mit Grund "Trinkgeld"; Abschluss zeigt Trinkgeld je Person und "Am Kartenkonto", Vergleich mit der Abrechnung von SumUp.
- **B. Teil bar, Rest Karte (echtes Terminal):** Bar-Teil tippen, Rest am Terminal, Lade springt auf, Bon mit zwei Zahlungen; Karte am Terminal abbrechen: Hinweis "bar zurückgeben", kein Bon; Rest unter 1,00 €: Taste grau mit Grund.
- **C. Rabatt:** auf eine Zeile, auf den ganzen Bon, als Betrag; "Einladung" und "Abschließen"; "Nur Chef" mit Anna prüfen; Bon mit Rabatt-Zeilen und Zwischensumme; Abschluss zeigt "Rabatte".
- **D. Freier Betrag:** 12,50 € zu 10 %, Zeile "Diverses 10 %" am Bon, nicht am Küchenbon.
- **E. Storno:** gemischten Bon mit Trinkgeld stornieren; der Dialog nennt Bar-Teil und Karten-Teil; im Abschluss steht das Minus bei der Person.
- **F. Im Browser:** Bon "Bar + Karte" unter beiden Filtern, Detail mit Zahlungen, Trinkgeld und Rabatt; Tag und Monatsabrechnung mit den neuen Zeilen.
- **G. Sprachen:** die neuen Blätter einmal in Englisch und Arabisch ansehen.
- Hinweis oben: Kartenzahlungen im Test sind echte Buchungen; kleine Beträge nehmen und in der SumUp-App zurückbuchen.

Abschnitt 10 der Spec bekommt jede Abweichung und Entscheidung aus dem Bau, mindestens diese aus dem Plan: Zählung gemischter Bons bei "Bar" und "Karte"; `goodsCents` ist der Warenwert nach Rabatt; "Abschließen" nur bei Summe 0 mit Rabatt; der Hinweis nach gescheiterter Karte bleibt stehen; beim freien Betrag ist kein Steuersatz vorgewählt; `receipt_lines` am Server hat zwei Spalten mehr; die Regeln werden bei jedem Bon geprüft, nicht nur mit Signatur; der Server erkennt einen Bon wieder, der erst als `v: 1` und dann als `v: 2` kommt; Trinkgeld je Person liest der Server aus `payload.payments`; der Verweis "R15" in 5.4a meint die Regel aus `receipt_repository_test.dart` ("Storno gehört zum Tag, der beim Storno offen ist").

- [ ] **Step 1: Version setzen und den Test der Version laufen lassen**

Run: `cd app && ~/flutter/bin/flutter test test/features/settings_test.dart`
Expected: FAIL, solange nur eine der zwei Stellen geändert ist; PASS mit `1.11.0+13` in `pubspec.yaml` und `'1.11.0'` in `app_info.dart`.

- [ ] **Step 2: Prüfliste, Abschnitt 10 und `PRODUCT.md` schreiben.** In der Prüfliste steht keine Server-Adresse und kein echter Betrag.

- [ ] **Step 3: Alles committen und pushen**, Titel `Stufe 1a Task 16: Prüfliste, Version 1.11.0, Entscheidungen beim Bau`.

- [ ] **Step 4: GitHub lesen**

Workflows `app` und `server` für den letzten Commit sind grün (Ergebnis lesen; scheitert etwas, hier nur die betroffenen Dateien wiederholen und beheben).

- [ ] **Step 5: Gesamtprüfung durch einen frischen Prüfer** über den ganzen Zweig gegen Spec und Plan, mit den fünf Punkten aus "Review Focus"; Befunde beheben. Danach steht der Zweig bereit für Nikos Ja. Kein Bau der Installationsdatei, kein Ausrollen in diesem Plan.

---

## Abdeckung der Spec

| Spec | Aufgabe |
| --- | --- |
| 5.1 Schalter | 1 (Daten), 6 (Abschnitt "Zahlen", Test "alles aus"), 11 und 12 ("nur Chef") |
| 5.2 Gemischt zahlen | 2 (Bon), 7 (offene Zahlung trägt Bar-Teil und Trinkgeld), 8 |
| 5.3 Trinkgeld | 2 (Signatur, eine Stelle im Code), 7, 13 (am Bon, im Abschluss) |
| 5.4 Rabatt | 9 (Regel), 10 (Bon, Storno, Summe 0), 11 (Blatt), 13 (am Bon) |
| 5.4a Storno und Trinkgeld | 2 (Spiegelbild, "Trinkgeld für"), 8 (Dialog), 13 (Minus bei der Person) |
| 5.5 Freier Betrag | 12 |
| 5.6 Daten | 1 (Tablet), 2 und 10 (feste Regeln), 4 (Abgleich, Server-Migration), 9 und 12 (Entwurf) |
| 5.7 Auswertungen | 3 (Tablet aus Zahlungen), 5 (Server und Browser), 13 (neue Zeilen) |
| 5.8 Version | 1 (Datenbank 8), 4 (Migration 0004), 16 (1.11.0 Build 13) |
| 7 Prüfung | 1 (Migration), 4 und 5 (Server), 9 und 10 (zufällige Bons), 14 (Bilder), 15 (Prüfwerkzeug, `tool/e2e.sh`), 16 (Prüfliste) |
