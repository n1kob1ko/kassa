# Stufe 1b: Pfand zurück, Rechnung an Firma, digitaler Beleg, Gutschein Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Die Kassa gibt Pfand zurück (auch als Auszahlung), druckt einen bezahlten Bon als Rechnung an eine Firma, bietet den Bon als Seite im Internet hinter einem QR-Code an und verkauft und löst Wertgutscheine mit Guthaben ein. Jede Funktion ist pro Kassa schaltbar und nach dem Update aus. Abschluss, Monatsabrechnung, Übersicht, Bons und die Verwaltung im Browser rechnen richtig.

**Architecture:** "Pfand zurück" und "Gutschein" sind Zeilen mit fester Kennung nach dem Muster des freien Betrags aus 1a (`deposit-return-<cents>`: Preis 0, Pfand unter 0; `voucher-sale`: Wert als Preis zum Satz 0, nie Rabatt). Eine Gutschein-Zahlung ist eine dritte Art in der Liste der Zahlungen. Das Guthaben eines Gutscheins ist die Summe seiner Bewegungen (nur anfügen, eindeutig je Gutschein und Bon); Tablet und Server vereinigen die Bewegungen, die sie kennen. Rechnungsempfänger und Belegerteilung sind eigene Einträge neben dem Bon, der Bon und seine Signatur bleiben unverändert. Der Bon geht als `v: 3` zum Server, der `v: 1` und `v: 2` weiter versteht (Migration `0005`). Die ersten sieben Aufgaben ändern nur Daten und Auswertungen, danach kommen Schalter und Funktionen.

**Tech Stack:** Flutter (flutter_riverpod, drift, `package:material_ui`, gen-l10n, `qr`), Fastify + PostgreSQL (TypeScript, Node 22, zod, vitest), React 19 + TanStack Query (vitest).

**Spec:** `docs/superpowers/specs/2026-11-27-stufe-1b-gutschein-beleg-rechnung-pfand-design.md`. Wer eine Aufgabe umsetzt, liest den genannten Abschnitt der Spec mit. Stufe 1a (`docs/superpowers/specs/2026-11-26-stufe-1a-zahlen-design.md`) ist gebaut und gilt weiter.

## Global Constraints

- Zweig `claude/project-thread-jyl5f5`. Kein PR. Nichts wird ausgerollt: weder Server noch Installationsdatei. Das geschieht erst nach Nikos Ja, und dann zuerst der Server, dann die App.
- Plan und alle Doku auf Deutsch mit einfachen Worten. Namen im Code englisch. Texte an der Kassa deutsch mit österreichischen Begriffen (bonieren, Bon, Storno).
- Jeder neue Text an der Kassa steht in allen fünf ARB-Dateien (`de`, `en`, `zh`, `tr`, `ar`), Schlüssel englisch in lowerCamelCase mit Bereich vorn. Nach jeder Änderung an den ARB-Dateien: `~/flutter/bin/flutter gen-l10n` (die Datei `build/l10n_untranslated.json` bleibt leer) und `~/flutter/bin/dart run tool/l10n_review.dart` (sonst scheitert `test/l10n_review_test.dart`; das Werkzeug schreibt die Listen in `docs/uebersetzungen/*.md` neu, sie gehören in denselben Commit). Wörter: Pfand zurück = Deposit return, 退押金, Depozito iadesi, إرجاع الرهن. Gutschein = Voucher, 礼券, Hediye çeki, قسيمة. Rechnung = Invoice, 发票, Fatura, فاتورة. Guthaben = Balance, 余额, Bakiye, الرصيد. Firmenkunde = Business customer, 企业客户, Kurumsal müşteri, عميل شركة.
- Kundenbon, Rechnung, Gutschein-Abschnitt (`receipt_layout.dart`, `voucher_layout.dart`), Berichte (`report_layout.dart`), die Seite des Bons am Server und die Bildschirme der Einrichtung bleiben Deutsch.
- Tests zuerst (TDD). "Vorhanden" heißt: Der Test gab es schon in 1.11.0 (Commit `a06aeb3`). Kein vorhandener Test verliert eine Erwartung. Vorhandene Erwartungen ändern sich nur an den Stellen, die dieser Plan beim Namen nennt (Task 1: Datenbank-Version 8 wird 9, und zwei Vergleiche aller Trigger bekommen die neuen Schutz-Trigger dazu; Task 5: Liste der Server-Migrationen bekommt `0005`, und die Tests über die Form des Bons im Abgleich bekommen `v: 3` statt `v: 2` mit den neuen leeren Feldern (`app/test/sync/push_wire_test.dart`, `app/test/sync/receipt_1_10_0_test.dart`; die vier gemeinsamen Dateien `shared/fixtures/stats/{overview,months,mixed}.json` und `shared/fixtures/rksv/dep.json` werden einmal in der Form `v: 3` neu geschrieben, mit festem Zufall für den Schlüssel der Seite; Beweis: zurück in die Form `v: 2` gerechnet sind sie gleich den alten Dateien, kein Betrag und keine Signatur ändert sich); Task 7: vorhandene Tests am Server und im Web, die eine ganze Abrechnung (Tag, Monat, Zeitraum) mit einer Datei oder einem festen Objekt vergleichen, nehmen die fünf neuen Zahlen vorher heraus und prüfen sie einzeln, jeder alte Wert bleibt genau verglichen; Task 8 und Task 20: Bilder der Einstellungen; Task 12: dritte Ausnahme in `test/no_text_field_test.dart`). Jede davon steht im Bericht der Aufgabe und wird Niko genannt.
- **HARD STOP:** Lehnt die Sitzung einen Befehl oder eine Änderung ab (Sicherheitsprüfung, Berechtigung), wird nichts umgangen: nicht derselbe Schritt auf anderem Weg, kein anderer Dateiname, kein anderes Werkzeug. Die Aufgabe endet mit `BLOCKED` und dem Wortlaut der Ablehnung. `.claude/settings.json` gehört Niko und wird nie angefasst. Nichts wird gelöscht außer Dateien, die die Aufgabe selbst angelegt hat.
- Datenbank am Tablet: Version 8 wird 9, mit Migration und Test auf einer Datenbank aus 1.11.0 (`test/data/fixtures/kassa_v8.sqlite`). Der Schlüssel der Installationsdatei wird nicht angefasst. `app/lib/rksv/` wird nicht angefasst.
- Version: App `1.12.0+14`, Server-Migration `0005`. `0001` bis `0004` nie ändern. Bon im Abgleich `v: 3`; der Server nimmt `v: 1` und `v: 2` weiter an.
- Alle vier neuen Schalter sind aus beziehungsweise auf "immer drucken", nach dem Update und bei neuer Installation. Sind sie aus, ist kein Tipp und kein Bildschirm anders als in 1.11.0 mit denselben Einstellungen: `test/features/stufe_1b_off_test.dart` (Task 8) und `test/features/stufe_1a_off_test.dart` bleiben in jeder späteren Aufgabe grün, und vorhandene Goldens ändern sich nicht (Ausnahme: Einstellungen in Task 8 und 20).
- Nur Tippen: kein Textfeld im Verkauf. Das einzige neue Textfeld steht in `lib/features/customers/customer_form.dart` (Task 12). Kein Widget, das die Prüfung in `test/no_text_field_test.dart` nur dem Namen nach umgeht. Eingaben sonst über Tasten und die vorhandenen Zahlenfelder (`Keypad`, `KeypadInput`, `TypedAmount`, `AmountEntry`). Tippflächen mindestens 48 dp. Farben und Maße nur aus `KassaTokens`/`KassaColors`, im Web aus `styles/tokens.css`.
- Feste Geld-Regeln (Spec 5.6), im Code geprüft und getestet: Summe der Zahlungen ohne Trinkgeld = Summe des Bons. Summe des Bons = Warenwert nach Rabatt plus Pfand (verlangt minus zurück). Beträge je Steuersatz zusammen = Summe des Bons plus Trinkgeld. Reihenfolge der Zahlungen: Gutscheine, höchstens eine Bar-Zahlung, höchstens eine Karte zuletzt. Eine Zahlung unter 0 gibt es im Verkauf nur bar und nur bei Summe unter 0. Gutschein-Zeile und Gutschein-Zahlung stehen nie auf demselben Bon. Umsatz = Summe des Bons minus verkaufte Gutscheine.
- Die Absicherung der Kartenzahlung bekommt keine Lücke: Die offene Zahlung steht in `pending_card_payments`, bevor das Terminal etwas erfährt; ihr `cartJson` trägt die gewählten Gutscheine. Ab dem Aufruf des Terminals endet jeder Fehler als "unklar", nie als "gescheitert". Wird eine unklare Zahlung als bezahlt bestätigt, entsteht der Bon immer, auch wenn ein Gutschein dabei unter 0 fällt.
- Tests laufen so: am Tablet einzelne Dateien mit `cd app && ~/flutter/bin/flutter test <pfad>`; am Server `server/tool/test-db.sh start`, dann `cd server && npx vitest run test/<datei>` und `npm run typecheck`; im Web `cd web && npm test && npm run typecheck`. Die ganzen Suiten laufen auf GitHub (Workflows `app` und `server`) nach einem Push. Nie Flutter-Tests starten, während im selben Ordner ein APK-Bau läuft.
- Kleine Helfer in den Test-Beispielen, die es noch nicht gibt, entstehen im selben Schritt: in der Test-Datei selbst, oder in `test/support/`, wenn eine zweite Datei sie braucht. Sie enthalten keine Erwartungen. Vorhandene Helfer: `pumpKassa`, `pumpKassaWith`, `setSettings`, `cartOf`, `tapKeys`, `textOf`, `buttonOf`, `queryRows`, `printerOf`, `shop` (`test/support/sales.dart`), `randomCart` (`test/support/random_cart.dart`).
- Nach Änderungen an `database.dart`: `~/flutter/bin/dart run build_runner build`. `flutter analyze` ohne Befund vor jedem Commit.
- Commit-Nachrichten deutsch, Form `Stufe 1b Task N: <was>`, jede endet mit genau diesen zwei Zeilen:
  ```
  Co-Authored-By: Claude Fable 5.2 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01DHykqgFLoUjNABiyhcqtuv
  ```
- Das Repo ist öffentlich: keine Schlüssel, keine Server-Adresse, keine echten Umsätze, keine echten Firmen. Beispiele sind erfunden ("Beispiel-Imbiss", "Muster GmbH, Musterweg 1, 1010 Wien, ATU00000000").

## Review Focus

1. **Bon, den 1.11.0 schon gesendet hat, kommt nach dem Update noch einmal:** Das Tablet schickt ihn jetzt als `v: 3`. Der Server antwortet `duplicate`, nicht `conflict`, und schreibt keinen Bericht. Dasselbe für einen Bon aus 1.10.0 (`v: 1`), der als `v: 3` wiederkommt (Tests in Task 5).
2. **Guthaben ändert sich zwischen "Einlösen" und Abschließen:** Derselbe Gutschein liegt am offenen Bon und wurde inzwischen mit einem anderen Bon verbraucht (zweites Tablet, Abgleich). Bar und "nur Gutschein": nichts wird gespeichert, das Blatt zeigt das neue Guthaben. Karte, die schon belastet ist (bestätigte unklare Zahlung): Der Bon entsteht, der Gutschein ist überzogen (Tests in Task 4 und 11).
3. **Bon unter 0 mit allem, was 1a kann:** Pfand zurück größer als die Ware, dazu Rabatt 100 %, freier Betrag, "Teil bar". Es gibt genau eine Bar-Zahlung unter 0, nie Karte, nie Trinkgeld, nie Gutschein; Storno ist das Spiegelbild; die Signatur trägt den Betrag unter 0 im Satz 0 (Tests in Task 3, 4, 9 und 19).
4. **Öffentliche Seite mit fremdem oder kaputtem Schlüssel:** leer, zu lang, Sonderzeichen, Schlüssel eines anderen Betriebs, richtiger Schlüssel nach Storno. Unbekannt und falsch geben dieselbe Antwort, nie Daten eines anderen Bons, keine Cookies, gebremst (Tests in Task 14).
5. **Kein Internet bei "digital und Druck auf Wunsch":** Der Server bestätigt den Bon nicht. Nach 3 Sekunden druckt die Kassa von selbst, genau einmal, auch wenn die Person schon "Nächster Kunde" getippt hat; ohne Drucker steht der Hinweis da. Kommt die Bestätigung später, wird nichts doppelt gedruckt (Tests in Task 15).

---

## File Structure

Neu am Tablet (`app/lib/`):

| Datei | Aufgabe der Datei |
| --- | --- |
| `domain/voucher.dart` | `Voucher`, Bewegungen, Zustand, `formatVoucherCode` |
| `domain/voucher_layout.dart` | Der gedruckte Abschnitt "Gutschein" |
| `domain/customer.dart` | `Customer`, `ReceiptRecipient`, Regeln für Pflichtfelder |
| `data/voucher_repository.dart` | Gutscheine suchen, Guthaben, Bewegungen vom Server einspielen |
| `data/customer_repository.dart` | Firmenkunden und Rechnungsempfänger |
| `data/delivery_repository.dart` | Belegerteilung je Bon ("gedruckt", "digital") |
| `features/kassa/more_sheet.dart` | Blatt "Mehr" im Kopf der Bon-Spalte |
| `features/kassa/deposit_return_sheet.dart` | Blatt "Pfand zurück" |
| `features/kassa/voucher_sheet.dart` | Blatt "Gutschein" mit "Verkaufen" und "Prüfen" |
| `features/kassa/voucher_code_entry.dart` | Code tippen, Gutschein suchen, bei zwei Treffern wählen (für "Prüfen" und "Einlösen") |
| `features/kassa/voucher_redeem_sheet.dart` | Blatt "Gutschein einlösen" |
| `features/kassa/receipt_qr.dart` | QR-Code der Seite eines Bons, mit Warten auf den Server |
| `features/customers/customer_picker.dart` | Liste der Firmenkunden zu einem Bon |
| `features/customers/customer_form.dart` | "Neuer Kunde": das einzige Formular mit Tastatur |
| `features/settings/receipt_section.dart` | Abschnitt "Kundenbon" |

Geändert am Tablet: `data/database.dart` (Version 9), `data/{receipt,card_payment,day,period_report,stats,settings,outbox}_repository.dart`, `domain/{receipt,receipt_rules,cart,day,period_report,receipt_layout,report_layout,kitchen_ticket,menu_import}.dart`, `features/kassa/{sale_service,cart_controller,cart_panel,cart_line_row,cash_sheet,sale_done,kassa_screen,unclear_card_payment}.dart`, `features/bons/{receipt_list,receipt_detail}.dart`, `features/close/*`, `features/settings/{settings_screen,payment_section}.dart`, `sync/{push_wire,server_changes,wire}.dart`, `devices/printer.dart`, `l10n/app_*.arb`.

Server: neu `server/migrations/0005_vouchers.sql`, `server/src/public/receipt_page.ts`, `server/src/public/qr.ts`, `server/src/admin/{vouchers,customers}.ts`, `server/src/device/{push_customer,push_recipient,push_delivery}.ts`; geändert `server/src/device/{push,push_schema,pull}.ts`, `server/src/admin/{months,days,overview,receipts}.ts`, `server/src/app.ts`, `server/src/menu/parse_menu.ts`. Gemeinsam: neu `shared/fixtures/sync/push_request_v3.json`, `shared/fixtures/sync/receipt_1_11_0_v2.json`, `shared/fixtures/sync/receipt_1_11_0_as_v3.json`; `shared/fixtures/stats/*.json` bekommen neue Bons in `v: 3`.

Web: neu `web/src/pages/{VouchersPage,CustomersPage}.tsx`, `web/src/api/{vouchers,customers}.ts`; geändert `web/src/api/{receipts,days,months}.ts`, `web/src/pages/{ReceiptsPage,ReceiptDetail,DayDetail,PeriodDetail,BusinessLayout}.tsx`, `web/src/routes.tsx`.

Doku: neu `docs/testen/stufe-1b-pruefliste.md`; geändert die Spec (Abschnitt 10), `PRODUCT.md`.

Beispiel-Bons in den Tests (aus `app/test/support/sales.dart`): `cart` = 2 × Cola (5,80 zu 20 %, Pfand 0,50, also 0,25 je Stück) + Huhn Bowl XXL Nudeln (11,90 zu 10 %), Summe 18,20. `cartCard` = Teigtaschen (6,50 zu 10 %) + Cola (2,90 zu 20 %, Pfand 0,25), Summe 9,65. Der einzige Pfand-Betrag der Beispiel-Karte ist 0,25 €.

---

## Teil 1: Daten und Auswertungen (noch nichts Neues zu sehen)

### Task 1: Datenbank 9 am Tablet mit Migration

Spec 5.6 (Datenbank am Tablet), 5.1 (Vorgaben), 7 (Migration).

**Files:**
- Create: `app/tool/make_kassa_v8_fixture.dart`, `app/test/data/fixtures/kassa_v8.sqlite`, `app/test/data/migration_v9_test.dart`, `app/drift_schemas/drift_schema_v9.json`, `app/test/data/generated_migrations/schema_v9.dart`
- Modify: `app/lib/data/database.dart` (+ `.g.dart`), `app/lib/data/settings_repository.dart`, `app/test/data/generated_migrations/schema.dart`
- Test: `app/test/data/migration_v9_test.dart`, `app/test/data/settings_repository_test.dart`; vorhandene Migrationstests bleiben grün

**Interfaces:**
- Consumes: `FeatureAccess` (1a).
- Produces: die Spalten und Tabellen unten (Namen in drift, in der Datei in snake_case) und

```dart
// core/app_language.dart (neben KitchenMode)
enum ReceiptMode { alwaysPrint, printAndDigital, digitalOnRequest }
// RegisterSettings, neue Felder mit copyWith; withoutPrinter() und withoutKitchenPrinter() reichen sie durch:
final FeatureAccess depositReturnAccess;  // off
final bool voucherEnabled;                // false
final bool invoiceEnabled;                // false
final ReceiptMode receiptMode;            // alwaysPrint
```

| Tabelle | Neu (Vorgabe) |
| --- | --- |
| `SettingsRows` | `depositReturnAccess` text (`'off'`), `voucher` bool (false), `invoice` bool (false), `receiptMode` text (`'alwaysPrint'`) |
| `ReceiptRows` | `publicToken` text (leer erlaubt) |
| `PaymentRows` | `voucherId` text, `voucherCode` text, `voucherBalanceAfterCents` int (alle leer erlaubt) |
| `VoucherRows` (neu, `vouchers`) | `id` text Schlüssel, `code` text, `valueCents` int, `createdAt`, `soldReceiptId` text (leer erlaubt), `soldLinePosition` int (leer erlaubt), `isTest` bool. Index auf `code` |
| `VoucherMovementRows` (neu, `voucher_movements`) | `voucherId` text, `receiptId` text, `kind` text (`sale`, `redeem`, `void_sale`, `void_redeem`), `amountCents` int (mit Vorzeichen), `createdAt`. Schlüssel `{voucherId, receiptId}` |
| `CustomerRows` (neu, `customers`) | `id` text Schlüssel, `name`, `addressLine1`, `addressLine2` text, `vatId` text (leer erlaubt), `archived` bool (false), `updatedAt`, `lastUsedAt` (leer erlaubt) |
| `ReceiptRecipientRows` (neu, `receipt_recipients`) | `receiptId` text, `version` int, `customerId` text (leer erlaubt), `name`, `addressLine1`, `addressLine2`, `vatId` (leer erlaubt), `createdAt`, `staffId`, `staffName`. Schlüssel `{receiptId, version}` |
| `ReceiptDeliveryRows` (neu, `receipt_deliveries`) | `receiptId` text, `kind` text (`printed`, `digital`), `at`. Schlüssel `{receiptId, kind}` |

Regeln für Schritt 9 (`_stepTo9`):
- Bestehende Zeilen bekommen die Vorgaben; kein Bon aus 1.11.0 bekommt einen `publicToken`.
- Die Tabellen `voucher_movements`, `receipt_recipients` und `receipt_deliveries` nehmen kein UPDATE und kein DELETE an (Trigger wie bei den Bons). `vouchers` nimmt kein DELETE an und kein UPDATE von `code` und `valueCents`.
- `SyncStateRows` bekommt `catchUpPending` (bool, Vorgabe false). Schritt 9 setzt es auf wahr, wenn das erste Laden schon erledigt ist (`initial_pull_done`). So weiß das Tablet nach dem Update, dass es Firmenkunden und Gutscheine nachholen muss, die der Server schon kennt (1.11.0 hat sie überlesen; das Nachholen selbst bauen Task 13 und 16). `pull_cursor`, `initialPullDone` und die Kopplung bleiben, wie sie sind.
- Liste "noch zu senden": Für die neuen Tabellen gibt es **keine** Trigger. Task 12 und Task 15 tragen Empfänger (`recipient`, `ref = '<receiptId>/<version>'`), Belegerteilung (`delivery`, `ref = '<receiptId>/<kind>'`) und Firmenkunden (`customer`) selbst ein, im selben Datenbank-Schritt wie die Zeile. So bleibt die Liste der Trigger für "noch zu senden" wie in 1.11.0.
- Die neuen Schutz-Trigger (kein UPDATE, kein DELETE) sind die einzigen neuen Trigger. Zwei vorhandene Tests vergleichen alle Trigger vor und nach dem Update (`migration_v7_test.dart:122`, `migration_v8_test.dart:172`); ihre Erwartung wird "die alten und genau die neuen Schutz-Trigger" (genannte Änderung, erst nach Nikos Ja).
- `kassa_v8.sqlite` entsteht mit `tool/make_kassa_v8_fixture.dart` aus dem Code von 1.11.0, **bevor** `database.dart` geändert wird (Muster: `tool/make_kassa_v7_fixture.dart`). Inhalt: ein Tag, ein Bar-Bon aus `cart`, ein Bon "Teil bar, Rest Karte" mit Trinkgeld, ein Bon mit Zeilen- und Bon-Rabatt, ein Bon mit freiem Betrag, ein Storno, ein offener Bon mit Rabatt als Entwurf, eine offene Kartenzahlung mit Bar-Teil und Trinkgeld, alle vier Schalter aus 1a an, gekoppelt mit erfundener Kassen-Kennung, `pull_cursor` 57, erstes Laden erledigt.

- [ ] **Step 1: `kassa_v8.sqlite` aus dem jetzigen Stand erzeugen** (`cd app && ~/flutter/bin/dart run tool/make_kassa_v8_fixture.dart`), Datei einchecken.

- [ ] **Step 2: Die Tests schreiben, die scheitern**

```dart
// migration_v9_test.dart
test('8 → 9: Bons, Zahlungen, Entwurf und offene Kartenzahlung aus 1.11.0 bleiben', () async {
  final db = KassaDatabase(NativeDatabase(await copyFixture('kassa_v8.sqlite')));
  expect(await userVersion(db), 9);
  expect(await rows(db, 'SELECT COUNT(*) AS c FROM receipts WHERE public_token IS NOT NULL'), [{'c': 0}]);
  expect(await rows(db, 'SELECT kind, voucher_id FROM payments ORDER BY receipt_id, position'), fixturePayments);   // wie vorher, voucher_id überall NULL
  expect(await rows(db, "SELECT deposit_return_access, voucher, invoice, receipt_mode FROM settings"),
      [{'deposit_return_access': 'off', 'voucher': 0, 'invoice': 0, 'receipt_mode': 'alwaysPrint'}]);
  expect(await rows(db, 'SELECT split_payment, card_tip, discount_access, open_amount_access FROM settings'),
      [{'split_payment': 1, 'card_tip': 1, 'discount_access': 'all', 'open_amount_access': 'all'}]);
  expect((await SettingsRepository(db).readDraft()), isNotNull);
  expect(await CardPaymentRepository(db).pending(), hasLength(1));
  expect(await rows(db, 'SELECT pull_cursor, initial_pull_done, catch_up_pending FROM sync_state'),
      [{'pull_cursor': 57, 'initial_pull_done': 1, 'catch_up_pending': 1}]);   // frische Installation: catch_up_pending 0
});
test('die neuen Tabellen: Bewegungen, Empfänger und Belegerteilung nehmen kein UPDATE und kein DELETE', ...);   // je ein INSERT, dann UPDATE und DELETE: beide werfen
test('ein Gutschein behält Code und Wert: UPDATE von code oder value_cents und DELETE werfen', ...);
test('die Trigger für "noch zu senden" sind dieselben wie in 1.11.0; neu sind nur Schutz-Trigger der neuen Tabellen', ...);
test('frische Installation und Migration haben dasselbe Schema (drift_schema_v9)', ...);   // Muster aus migration_v8_test.dart
// settings_repository_test.dart
test('neue Schalter: Vorgaben aus, speichern und lesen', ...);   // depositReturnAccess chefOnly, voucherEnabled, invoiceEnabled, receiptMode digitalOnRequest
```

- [ ] **Step 3: Laufen lassen, sie scheitern**

Run: `cd app && ~/flutter/bin/flutter test test/data/migration_v9_test.dart`
Expected: FAIL (Version ist 8).

- [ ] **Step 4: Umsetzen.** `schemaVersion => 9`, `_stepTo9`, Schema-Dateien erzeugen wie in 1a Task 1. In den vorhandenen Migrationstests wird nur die erwartete Endversion von 8 auf 9 gehoben (`migration_test.dart`, `migration_v6_test.dart`, `migration_v7_test.dart`, `migration_v8_test.dart`); jede geänderte Zeile steht im Bericht. Wird eine dieser Änderungen abgelehnt: HARD STOP.

- [ ] **Step 5: Laufen lassen, alles grün**

Run: `cd app && ~/flutter/bin/flutter test test/data/ && ~/flutter/bin/flutter analyze`
Expected: PASS.

- [ ] **Step 6: Commit** `Stufe 1b Task 1: Datenbank 9 am Tablet mit Migration`.

### Task 2: Offener Bon: Pfand zurück, Gutschein-Zeile, gewählte Gutscheine

Spec 5.2, 5.5 (Zeilen, Rechnen), 5.6 (Entwurf).

**Files:**
- Modify: `app/lib/domain/cart.dart`, `app/lib/domain/kitchen_ticket.dart`, `app/lib/domain/menu_import.dart`, `server/src/menu/parse_menu.ts`
- Create: `shared/fixtures/menu/inputs/fehler-artikel-kennung-pfand-zurueck.json`, `shared/fixtures/menu/inputs/fehler-artikel-kennung-gutschein.json` (mit den erwarteten Fehlern nach dem Muster von `fehler-artikel-kennung-freier-betrag.json`)
- Test: `app/test/domain/{cart,kitchen_ticket,menu_import}_test.dart`, `app/test/domain/cart_random_test.dart` (falls vorhanden, sonst die Datei mit den zufälligen Bons aus 1a), `server/test/menu*.test.ts`

**Interfaces:**
- Consumes: `Cart`, `CartLine`, `CartPricing`, `Discount`, das Muster des freien Betrags (1a Task 12).
- Produces:

```dart
// domain/cart.dart
String depositReturnItemId(int depositCents);        // 'deposit-return-25'
bool isDepositReturnItemId(String itemId);
const depositReturnName = 'Pfand zurück';            // so steht es am Bon
const voucherSaleItemId = 'voucher-sale';
bool isVoucherSaleItemId(String itemId);
const voucherSaleName = 'Gutschein';
const voucherMinCents = 100;                         // 1,00 €
const voucherMaxCents = 50000;                       // 500,00 €
const voucherPresetCents = [1000, 2000, 2500, 5000];
bool isReservedItemId(String itemId);                // open-amount-…, deposit-return-…, voucher-sale

class AppliedVoucher {                               // ein Gutschein, der am offenen Bon liegt
  const AppliedVoucher({required this.voucherId, required this.code, required this.balanceCents});
}
class VoucherUse {                                   // was er von diesem Bon deckt
  const VoucherUse({required this.voucherId, required this.code, required this.amountCents, required this.balanceAfterCents});
}
class CartLine { bool get isDepositReturn; bool get isVoucherSale; }
class Cart {
  final List<AppliedVoucher> vouchers;               // in der Reihenfolge des Einlösens
  Cart setDepositReturn({required int depositCents, required int quantity});
  int depositReturnQuantity(int depositCents);       // 0 ohne Zeile
  Cart addVoucherSale({required int valueCents, String? lineId});
  bool get hasVoucherSale;
  Cart applyVoucher(AppliedVoucher voucher);
  Cart removeVoucher(String voucherId);
  Cart withVoucherBalance(String voucherId, int balanceCents);
}
class CartPricing {
  int get voucherSaleCents;                          // Summe der Gutschein-Zeilen
  List<VoucherUse> get voucherUses;
  int get voucherCents;                              // Summe der voucherUses
  int get dueCents;                                  // totalCents - voucherCents: noch zu zahlen
}
```

Regeln:
- **Pfand zurück:** höchstens eine Zeile je Betrag. Der Artikel entsteht im Code: Id `depositReturnItemId(c)`, Name `depositReturnName`, Preis 0, Pfand `-c`, Satz 0, keine Auswahl. `setDepositReturn` mit Menge 0 nimmt die Zeile weg; `ArgumentError` bei Betrag unter 1 oder Menge außerhalb 0 bis 99. `setQuantity` geht wie bei jeder Zeile. `setLineDiscount` auf dieser Zeile wirft `ArgumentError`. Die Zeile hat Warenwert 0, bekommt also nie einen Anteil am Bon-Rabatt.
- **Gutschein-Zeile:** `addVoucherSale` legt immer eine neue Zeile an, Menge 1, Id `voucherSaleItemId`, Name `voucherSaleName`, Preis `valueCents`, Satz 0. `ArgumentError` bei Wert außerhalb `voucherMinCents` bis `voucherMaxCents`. `setQuantity` über 1 und `setLineDiscount` werfen `ArgumentError`. Der Bon-Rabatt rechnet von der Zwischensumme **ohne** Gutschein-Zeilen und wird nur auf die anderen Zeilen verteilt; `pricing.goodsCents` und `grossByRate[TaxRate.zero]` enthalten die Gutschein-Zeilen.
- **Gewählte Gutscheine:** `applyVoucher` wirft `StateError`, wenn der Bon eine Gutschein-Zeile hat oder derselbe Gutschein schon gewählt ist; `addVoucherSale` wirft `StateError`, wenn Gutscheine gewählt sind. `voucherUses`: In der Reihenfolge von `vouchers` deckt jeder `min(balanceCents, Rest)`; ein Gutschein, der 0 deckt, fehlt in der Liste. Ist `totalCents <= 0`, ist die Liste leer. Ein leerer Bon hat keine gewählten Gutscheine mehr (`remove` der letzten Zeile leert `vouchers`).
- **Entwurf:** `toJson` schreibt bei Pfand zurück `"depositReturn": {"cents": 25}`, bei der Gutschein-Zeile `"voucherSale": {"cents": 2500}`, und am Bon `"vouchers": [{"id": …, "code": …, "balanceCents": …}]` nur, wenn die Liste nicht leer ist. `fromJson` baut beides ohne den Katalog; unlesbar oder außerhalb der Grenzen fällt die Zeile weg. `rebind` lässt alles stehen. Ein Bon ohne die neuen Dinge ergibt Byte für Byte dasselbe JSON wie in 1.11.0, und ein Entwurf aus 1.11.0 bleibt lesbar.
- **Küchenbon:** `buildKitchenTicket` lässt Zeilen mit `isReservedItemId(l.itemId)` weg.
- **Import der Speisekarte** (Tablet und Server): Kennungen, für die `isReservedItemId` gilt, werden abgelehnt, mit demselben Fehler wie bisher `open-amount-`.

- [ ] **Step 1: Die Tests schreiben, die scheitern**

```dart
// cart_test.dart
test('Pfand zurück: eine Zeile je Betrag, Summe sinkt, Menge 0 nimmt sie weg', () {
  final c = cart.setDepositReturn(depositCents: 25, quantity: 3);
  final line = c.lines.last;
  expect((line.item.id, line.item.name, line.quantity, line.goodsCents, line.depositCents, line.isDepositReturn),
      ('deposit-return-25', 'Pfand zurück', 3, 0, -75, true));
  expect((c.goodsCents, c.depositCents, c.totalCents), (1770, -25, 1745));
  expect(c.setDepositReturn(depositCents: 25, quantity: 5).lines, hasLength(3));
  expect(c.depositReturnQuantity(25), 3);
  expect(c.setDepositReturn(depositCents: 25, quantity: 0).totalCents, 1820);
  expect(const Cart.empty().setDepositReturn(depositCents: 25, quantity: 3).totalCents, -75);
  expect(() => c.setLineDiscount(line.lineId, const Discount.percent(10, DiscountReason.regular)), throwsArgumentError);
});
test('Gutschein-Zeile: eigene Zeile je Tipp, Satz 0, kein Rabatt, kein Anteil am Bon-Rabatt', () {
  final c = cartCard.addVoucherSale(valueCents: 2500).setReceiptDiscount(const Discount.percent(10, DiscountReason.promotion));
  expect((c.pricing.voucherSaleCents, c.pricing.receiptDiscountCents, c.goodsCents, c.totalCents), (2500, 94, 3346, 3371));
  expect(c.pricing.lines.last.discountCents, 0);
  expect(c.pricing.grossByRate[TaxRate.zero], 2500);
  expect(() => c.setQuantity(c.lines.last.lineId, 2), throwsArgumentError);
  for (final cents in [99, 50001]) {
    expect(() => const Cart.empty().addVoucherSale(valueCents: cents), throwsArgumentError);
  }
});
test('gewählte Gutscheine decken der Reihe nach; noch zu zahlen ist der Rest', () {
  const a = AppliedVoucher(voucherId: 'v-a', code: '11112222', balanceCents: 500);
  const b = AppliedVoucher(voucherId: 'v-b', code: '33334444', balanceCents: 300);
  final c = cartCard.applyVoucher(a).applyVoucher(b);
  expect([for (final u in c.pricing.voucherUses) (u.voucherId, u.amountCents, u.balanceAfterCents)], [('v-a', 500, 0), ('v-b', 300, 0)]);
  expect((c.pricing.voucherCents, c.pricing.dueCents), (800, 165));
  final big = cartCard.applyVoucher(const AppliedVoucher(voucherId: 'v-c', code: '55556666', balanceCents: 2500)).applyVoucher(a);
  expect([for (final u in big.pricing.voucherUses) (u.voucherId, u.amountCents, u.balanceAfterCents)], [('v-c', 965, 1535)]);
  expect(big.pricing.dueCents, 0);
  expect(c.removeVoucher('v-a').pricing.dueCents, 665);
  expect(c.withVoucherBalance('v-a', 100).pricing.dueCents, 565);
  expect(() => c.applyVoucher(a), throwsStateError);
  expect(() => c.addVoucherSale(valueCents: 1000), throwsStateError);
  expect(() => cartCard.addVoucherSale(valueCents: 1000).applyVoucher(a), throwsStateError);
});
test('Entwurf: Pfand zurück, Gutschein-Zeile und gewählte Gutscheine überstehen toJson und fromJson; ohne sie ist das JSON wie in 1.11.0', () {
  final c = cart.setDepositReturn(depositCents: 25, quantity: 2).applyVoucher(const AppliedVoucher(voucherId: 'v-a', code: '11112222', balanceCents: 500));
  final back = Cart.fromJson(c.toJson(), catalog);
  expect((back.totalCents, back.pricing.dueCents, back.vouchers.single.code), (c.totalCents, c.pricing.dueCents, '11112222'));
  expect(jsonEncode(cart.toJson()), draft1_11_0);            // der Text, den 1.11.0 für `cart` schreibt (aus kassa_v8.sqlite oder im Test festgehalten)
  expect(Cart.fromJson({...c.toJson(), 'vouchers': 'kaputt'}, catalog).vouchers, isEmpty);
});
```

Dazu: `kitchen_ticket_test.dart` `'Pfand zurück und Gutschein kommen nicht auf den Küchenbon'`; `menu_import_test.dart` und der Server-Test lesen die zwei neuen Fehler-Dateien; die Datei mit den zufälligen Bons bekommt Pfand zurück und Gutschein-Zeilen in `randomCart` (neuer Schalter `withStufe1b: true`, die alten Aufrufe bleiben, wie sie sind) und prüft: Summe der Zeilen = Bon, kein Rabatt auf Gutschein- und Pfand-Zeilen, `dueCents >= 0`, sobald `totalCents >= 0`.

- [ ] **Step 2: Laufen lassen, sie scheitern**

Run: `cd app && ~/flutter/bin/flutter test test/domain/cart_test.dart`
Expected: FAIL (`setDepositReturn` gibt es nicht).

- [ ] **Step 3: Umsetzen** nach Signaturen und Regeln oben.

- [ ] **Step 4: Laufen lassen, alles grün**

Run: `cd app && ~/flutter/bin/flutter test test/domain/ test/features/kassa_test.dart test/features/stufe_1a_off_test.dart test/features/discount_test.dart test/features/open_amount_test.dart && ~/flutter/bin/flutter analyze`; `cd server && npx vitest run test/parse_menu.test.ts` (oder die Datei, die `fehler-artikel-kennung-freier-betrag.json` heute liest)
Expected: PASS.

- [ ] **Step 5: Commit** `Stufe 1b Task 2: Offener Bon mit Pfand zurück, Gutschein-Zeile und gewählten Gutscheinen`.

### Task 3: Bon-Modell, Gutschein-Modell und die festen Regeln

Spec 5.6 (Regeln), 5.5 (Zustände).

**Files:**
- Create: `app/lib/domain/voucher.dart`, `app/test/domain/voucher_test.dart`
- Modify: `app/lib/domain/receipt.dart`, `app/lib/domain/receipt_rules.dart`
- Test: `app/test/domain/receipt_rules_test.dart`, `app/test/domain/voucher_test.dart`

**Interfaces:**
- Consumes: `isDepositReturnItemId`, `isVoucherSaleItemId` (Task 2).
- Produces:

```dart
// domain/receipt.dart
enum PaymentKind { cash, card, voucher }
class Payment { ..., this.voucherId, this.voucherCode, this.voucherBalanceAfterCents });   // nur bei kind voucher gesetzt
class SoldVoucher {                                   // ein Gutschein, der auf diesem Bon verkauft wurde
  const SoldVoucher({required this.voucherId, required this.code, required this.valueCents, required this.linePosition});
}                                                     // valueCents beim Storno negativ
class Receipt { ..., this.publicToken, this.soldVouchers = const [] });
  final String? publicToken;
  final List<SoldVoucher> soldVouchers;
  int get voucherCents;                               // Summe der Gutschein-Zahlungen
  int get voucherSaleCents;                           // Summe der Gutschein-Zeilen (Preis mal Menge), beim Storno negativ
  int get depositReturnCents;                         // Pfand der Zeilen "Pfand zurück": im Verkauf <= 0
  int get depositReturnQuantity;                      // Stück, beim Storno negativ
  int get revenueCents;                               // totalCents - voucherSaleCents
  Set<PaymentKind> get paymentKinds;
// `paymentKind` (cash, card, mixed) bleibt, wie es ist, und sieht Gutscheine nicht.

// domain/receipt_rules.dart: ReceiptRule bekommt
//   paymentOrder (Gutscheine, höchstens eine Bar-Zahlung, höchstens eine Karte zuletzt; ersetzt oneCardLast nicht, beide gelten),
//   negativeOnlyCash (im Verkauf: Betrag < 0 nur bar und nur bei totalCents < 0; dann ist es die einzige Zahlung),
//   voucherNotWithSale (Gutschein-Zeile und Gutschein-Zahlung nie zusammen),
//   voucherFields (kind voucher hat voucherId und voucherCode, givenCents == amountCents, changeCents == 0, tipCents == 0; andere Arten haben keine voucher-Felder)
// checkReceiptRules bekommt `bool isVoid = false`: Beim Storno gelten die Vorzeichen gespiegelt.

// domain/voucher.dart
enum VoucherMovementKind { sale, redeem, voidSale, voidRedeem }     // in der Datenbank 'sale', 'redeem', 'void_sale', 'void_redeem'
class VoucherMovement { voucherId, receiptId, kind, amountCents, createdAt }
enum VoucherState { active, empty, voided, overdrawn }
class Voucher {
  const Voucher({required this.id, required this.code, required this.valueCents, required this.createdAt,
      required this.isTest, this.soldReceiptId, required this.movements});
  int get balanceCents;                               // Summe der Bewegungen
  VoucherState get state;                             // overdrawn: Guthaben < 0; voided: es gibt voidSale und Guthaben == 0; empty: Guthaben == 0; sonst active
  bool get untouched;                                 // nur die Bewegung sale
}
String formatVoucherCode(String code);                // '12345678' → '1234 5678'
bool isVoucherCode(String code);                      // genau 8 Ziffern
```

- [ ] **Step 1: Die Tests schreiben, die scheitern**

```dart
// receipt_rules_test.dart (Helfer `check(...)` wie in der Datei)
test('Reihenfolge: Gutschein, bar, Karte besteht; bar vor Gutschein und zwei Bar-Zahlungen scheitern an paymentOrder', ...);
test('Betrag unter 0: besteht bar bei Summe -75; scheitert mit Karte, mit Gutschein und neben einer zweiten Zahlung an negativeOnlyCash', ...);
test('Storno mit isVoid: gespiegelte Beträge bestehen', ...);
test('Gutschein-Zeile und Gutschein-Zahlung auf einem Bon scheitern an voucherNotWithSale', ...);
test('Gutschein-Zahlung ohne Code, mit Rückgeld oder mit Trinkgeld scheitert an voucherFields', ...);
test('codeSums: Bon nur mit Pfand zurück trägt -75 im Satz 0; Gutschein-Zeile 2500 im Satz 0', () {
  expect(codeSums(lineGross: const [{}], depositCents: -75, tipCents: 0), [0, 0, 0, -75, 0]);
  expect(codeSums(lineGross: const [{TaxRate.zero: 2500}], depositCents: 0, tipCents: 0), [0, 0, 0, 2500, 0]);
});
// voucher_test.dart
test('Guthaben und Zustand folgen aus den Bewegungen', () {
  // sale +2500 → active, untouched; + redeem -965 → active 1535; + redeem -1535 → empty;
  // sale +2500, voidSale -2500 → voided; sale +2500, redeem -2500, redeem -500 → overdrawn (-500)
});
test('formatVoucherCode und isVoucherCode', () {
  expect(formatVoucherCode('12345678'), '1234 5678');
  expect([isVoucherCode('12345678'), isVoucherCode('1234567'), isVoucherCode('1234 5678'), isVoucherCode('1234567a')], [true, false, false, false]);
});
```

- [ ] **Step 2: Laufen lassen, sie scheitern**

Run: `cd app && ~/flutter/bin/flutter test test/domain/receipt_rules_test.dart test/domain/voucher_test.dart`
Expected: FAIL (`PaymentKind.voucher` gibt es nicht).

- [ ] **Step 3: Umsetzen.** Jede `switch`-Anweisung über `PaymentKind` im Code bekommt den Fall `voucher` so, dass sich für Bons ohne Gutschein nichts ändert; wo eine Anzeige fehlt, steht vorerst der deutsche Text "Gutschein" (die Oberfläche folgt in Task 11 und 17).

- [ ] **Step 4: Laufen lassen, alles grün**

Run: `cd app && ~/flutter/bin/flutter test test/domain/ test/data/receipt_repository_test.dart && ~/flutter/bin/flutter analyze`
Expected: PASS.

- [ ] **Step 5: Commit** `Stufe 1b Task 3: Bon-Modell, Gutschein-Modell und feste Regeln`.

### Task 4: Bons speichern: Auszahlung, Gutschein verkaufen, einlösen, Storno

Spec 5.2, 5.5, 5.6.

**Files:**
- Create: `app/lib/data/voucher_repository.dart`, `app/test/data/voucher_repository_test.dart`
- Modify: `app/lib/data/receipt_repository.dart`, `app/lib/data/providers.dart`, `app/test/support/sales.dart`
- Test: `app/test/data/receipt_repository_test.dart`, `app/test/data/receipt_random_test.dart`, `app/test/data/voucher_repository_test.dart`, `app/test/rksv/rksv_journal_test.dart` (bleibt grün)

**Interfaces:**
- Consumes: Task 1 bis 3.
- Produces:

```dart
// data/receipt_repository.dart
class VoucherBalanceException implements Exception {          // das Guthaben reicht nicht mehr
  const VoucherBalanceException(this.voucherId, this.balanceCents);
}
class VoucherSaleRedeemedException implements Exception {}    // Storno eines Gutschein-Verkaufs, der schon eingelöst ist
class NothingDueException implements Exception {}             // bar oder Karte, obwohl nichts mehr zu zahlen ist
// finalizeCashSale und finalizeCardSale: zahlen `cart.pricing.dueCents`; davor stehen die Gutschein-Zahlungen aus
// `cart.pricing.voucherUses`. finalizeCardSale bekommt `bool allowOverdraw = false`.
Future<Receipt> finalizeVoucherSale({required String saleId, required Cart cart, required Staff staff});
//   nur wenn dueCents == 0 und voucherCents > 0, sonst ArgumentError; es entsteht keine Bar-Zahlung
Future<Receipt> finalizePayout({required String saleId, required Cart cart, required Staff staff});
//   nur wenn totalCents < 0, sonst ArgumentError; eine Bar-Zahlung über totalCents, givenCents 0, changeCents 0

// data/voucher_repository.dart
class VoucherRepository {
  Future<List<Voucher>> findByCode(String code);      // 0, 1 oder mehrere (zwei Kassen können denselben Code vergeben haben)
  Future<Voucher?> byId(String id);
  Future<int> balanceOf(String voucherId);
  Future<List<Voucher>> soldOn(String receiptId);
}
final voucherRepositoryProvider = Provider<VoucherRepository>(…);
```

Regeln (alles im selben Datenbank-Schritt wie der Bon):
- Jeder Bon der Art Verkauf oder Storno bekommt einen `publicToken`: 16 zufällige Bytes aus `Random.secure()`, base64url ohne `=` (22 Zeichen). Sonderbelege bekommen keinen.
- **Gutschein-Zahlung:** Für jede `VoucherUse` liest die Kassa das Guthaben aus den Bewegungen. Ist es kleiner als der Betrag, wirft sie `VoucherBalanceException` und speichert nichts. Mit `allowOverdraw: true` (nur `finalizeCardSale`) wird trotzdem geschrieben. Gespeichert wird eine Zahlung `voucher` (`givenCents = amountCents`, `changeCents = 0`, `voucherBalanceAfterCents` = Guthaben danach) und eine Bewegung `redeem` mit `-amountCents`. Ein Übungs-Gutschein (`isTest`) lässt sich nur auf einem Übungs-Bon einlösen, ein echter nur auf einem echten: sonst `VoucherBalanceException` mit dem Guthaben 0. Ob ein Bon ein Übungs-Bon ist, entscheidet dieselbe Regel wie in `push_wire.dart` (`test`: keine Kette mit `live`).
- **Gutschein-Zeile:** Für jede Zeile mit `voucherSaleItemId` entsteht ein Gutschein: Kennung UUID, Code aus 8 zufälligen Ziffern (`Random.secure()`), der in `vouchers` noch nicht vorkommt, Wert, `isTest`, `soldReceiptId`, `soldLinePosition`; dazu die Bewegung `sale` mit `+valueCents`. Die gespeicherte Zeile bekommt `info = 'Code 1234 5678'`. `Receipt.soldVouchers` kommt beim Lesen aus `vouchers`.
- **Storno:** Zahlungen werden gespiegelt wie bisher; eine Gutschein-Zahlung schreibt die Bewegung `void_redeem` mit `+amount` zum Storno-Bon und trägt das Guthaben danach. Hat der Bon Gutscheine verkauft, muss jeder `untouched` sein, sonst `VoucherSaleRedeemedException` und nichts ist gespeichert; je Gutschein entsteht die Bewegung `void_sale` mit `-valueCents`. `soldVouchers` des Storno-Bons trägt dieselben Gutscheine mit negativem Wert.
- `finalizeCashSale`: `givenCents` muss mindestens `dueCents` sein. Ist `dueCents == 0` und es gibt Gutschein-Zahlungen, wirft sie `NothingDueException` (dafür ist `finalizeVoucherSale` da). Ein Bon mit Summe 0 ohne Gutschein geht wie in 1.11.0. `finalizeCardSale`: Karte = `dueCents - cashPartCents`; die Grenzen aus 1a gelten gegen `dueCents`.
- Wiederholung mit derselben `saleId` gibt den gespeicherten Bon zurück und bucht nichts doppelt.

- [ ] **Step 1: Die Tests schreiben, die scheitern**

```dart
// receipt_repository_test.dart (shop, cart, cartCard aus test/support/sales.dart)
test('Pfand zurück auf einem Bon mit Ware: Summe 17,45 €, bar bezahlt', () async {
  final r = await shop.receipts.finalizeCashSale(saleId: 'p1', cart: cart.setDepositReturn(depositCents: 25, quantity: 3), givenCents: 2000, staff: shop.anna);
  expect((r.goodsCents, r.depositCents, r.totalCents, r.depositReturnCents, r.depositReturnQuantity), (1770, -25, 1745, -75, 3));
  expect((r.payments.single.amountCents, r.payments.single.changeCents), (1745, 255));
  expect(r.publicToken, hasLength(22));
});
test('nur Pfand zurück: Auszahlung über 0,75 €, Storno ist das Spiegelbild', () async {
  final back = const Cart.empty().setDepositReturn(depositCents: 25, quantity: 3);
  final r = await shop.receipts.finalizePayout(saleId: 'p2', cart: back, staff: shop.anna);
  expect((r.totalCents, r.payments.single.kind, r.payments.single.amountCents, r.payments.single.givenCents, r.payments.single.changeCents),
      (-75, PaymentKind.cash, -75, 0, 0));
  final v = await shop.receipts.voidReceipt('p2', staff: shop.chef);
  expect((v.totalCents, v.payments.single.amountCents, v.lines.single.quantity), (75, 75, -3));
  expect(() => shop.receipts.finalizePayout(saleId: 'p3', cart: cart, staff: shop.anna), throwsArgumentError);
});
test('Gutschein verkaufen: Gutschein mit Code und Bewegung, die Zeile trägt den Code, kein Umsatz', () async {
  final r = await shop.receipts.finalizeCashSale(saleId: 'g1', cart: cartCard.addVoucherSale(valueCents: 2500), givenCents: 4000, staff: shop.anna);
  final sold = r.soldVouchers.single;
  expect((r.totalCents, r.voucherSaleCents, r.revenueCents, sold.valueCents, sold.linePosition), (3465, 2500, 965, 2500, 2));
  expect(isVoucherCode(sold.code), isTrue);
  expect(r.lines.last.info, 'Code ${formatVoucherCode(sold.code)}');
  final voucher = (await shop.vouchers.findByCode(sold.code)).single;
  expect((voucher.balanceCents, voucher.state, voucher.untouched, voucher.soldReceiptId), (2500, VoucherState.active, true, 'g1'));
});
test('mit Gutschein bezahlen: ganz, mit Rest bar, mit Rest Karte; das Guthaben sinkt', () async {
  final v = await sellVoucher(shop, 2500);                       // Helfer: verkauft bar, gibt den Voucher zurück
  final all = await shop.receipts.finalizeVoucherSale(saleId: 'e1', cart: cartCard.applyVoucher(applied(v)), staff: shop.anna);
  expect([for (final p in all.payments) (p.kind, p.amountCents, p.voucherCode, p.voucherBalanceAfterCents)], [(PaymentKind.voucher, 965, v.code, 1535)]);
  final small = await sellVoucher(shop, 500);
  final cash = await shop.receipts.finalizeCashSale(saleId: 'e2', cart: cartCard.applyVoucher(applied(small)), givenCents: 500, staff: shop.anna);
  expect([for (final p in cash.payments) (p.kind, p.amountCents, p.changeCents)], [(PaymentKind.voucher, 500, 0), (PaymentKind.cash, 465, 35)]);
  final small2 = await sellVoucher(shop, 500);
  final card = await shop.receipts.finalizeCardSale(saleId: 'e3', cart: cartCard.applyVoucher(applied(small2)), staff: shop.anna, provider: 'sumup', tipCents: 35);
  expect([for (final p in card.payments) (p.kind, p.amountCents, p.tipCents)], [(PaymentKind.voucher, 500, 0), (PaymentKind.card, 465, 35)]);
  expect(await shop.vouchers.balanceOf(v.id), 1535);
});
test('Guthaben reicht nicht mehr: VoucherBalanceException, nichts gespeichert; mit allowOverdraw entsteht der Kartenbon und der Gutschein ist überzogen', () async {
  final v = await sellVoucher(shop, 500);
  final stale = cartCard.applyVoucher(applied(v));
  await shop.receipts.finalizeVoucherSale(saleId: 'x1', cart: Cart.empty().add(cola).applyVoucher(applied(v)), staff: shop.anna);   // verbraucht 3,15 €
  await expectLater(shop.receipts.finalizeCashSale(saleId: 'x2', cart: stale, givenCents: 500, staff: shop.anna),
      throwsA(isA<VoucherBalanceException>().having((e) => e.balanceCents, 'balanceCents', 185)));
  expect(await shop.receipts.find('x2'), isNull);
  await shop.receipts.finalizeCardSale(saleId: 'x3', cart: stale, staff: shop.anna, provider: 'sumup', allowOverdraw: true);
  expect((await shop.vouchers.byId(v.id))!.state, VoucherState.overdrawn);
});
test('Storno gibt das Guthaben zurück; ein Gutschein-Verkauf lässt sich nur unberührt stornieren', () async {
  final v = await sellVoucher(shop, 2500, saleId: 'g2');
  await shop.receipts.finalizeVoucherSale(saleId: 'e4', cart: cartCard.applyVoucher(applied(v)), staff: shop.anna);
  await expectLater(shop.receipts.voidReceipt('g2', staff: shop.chef), throwsA(isA<VoucherSaleRedeemedException>()));
  final back = await shop.receipts.voidReceipt('e4', staff: shop.chef);
  expect((back.payments.single.amountCents, back.payments.single.voucherBalanceAfterCents), (-965, 2500));
  final gone = await shop.receipts.voidReceipt('g2', staff: shop.chef);
  expect((gone.soldVouchers.single.valueCents, (await shop.vouchers.byId(v.id))!.state), (-2500, VoucherState.voided));
});
test('Übungs-Gutschein gilt nicht im echten Betrieb und umgekehrt', ...);          // Kette probe, dann live (Rig aus test/support/rksv_rig.dart)
test('dieselbe saleId zweimal: ein Bon, eine Bewegung', ...);

// receipt_random_test.dart: ein zweiter Test neben dem aus 1a
test('200 zufällige Bons mit Pfand zurück, Gutschein-Verkauf und Gutschein-Zahlung: Regeln halten, Storno ist das Spiegelbild, am Ende hat jeder Gutschein wieder sein Guthaben vom Verkauf oder ist storniert', ...);
```

- [ ] **Step 2: Laufen lassen, sie scheitern**

Run: `cd app && ~/flutter/bin/flutter test test/data/receipt_repository_test.dart`
Expected: FAIL (`finalizePayout` gibt es nicht).

- [ ] **Step 3: Umsetzen** nach Signaturen und Regeln oben. `shop` in `test/support/sales.dart` bekommt `vouchers` (ein `VoucherRepository`).

- [ ] **Step 4: Laufen lassen, alles grün**

Run: `cd app && ~/flutter/bin/flutter test test/data/ test/domain/ test/rksv/rksv_journal_test.dart test/features/sale_service_test.dart && ~/flutter/bin/flutter analyze`
Expected: PASS.

- [ ] **Step 5: Commit** `Stufe 1b Task 4: Bons mit Auszahlung, Gutschein-Verkauf, Gutschein-Zahlung und Storno`.

### Task 5: Abgleich `v: 3`, Server-Migration 0005, der Server nimmt drei Formen

Spec 5.6 (Abgleich), 5.5 (mehrere Kassen: der Server kennt jede Bewegung).

**Files:**
- Create: `server/migrations/0005_vouchers.sql`, `shared/fixtures/sync/push_request_v3.json`, `shared/fixtures/sync/receipt_1_11_0_v2.json`, `shared/fixtures/sync/receipt_1_11_0_as_v3.json`, `app/test/data/fixtures/kassa_v8_receipts_1_11_0.sqlite`, `tool/fixtures/receipt_1_11_0.md`
- Modify: `app/lib/sync/push_wire.dart`, `server/src/device/{push,push_schema}.ts`
- Test: `app/test/sync/push_wire_test.dart`, `app/test/sync/receipt_1_11_0_test.dart` (neu), `server/test/push.test.ts`, `server/test/migrate.test.ts`

**Interfaces:**
- Consumes: Task 1 bis 4.
- Produces: Bon `v: 3` = `v: 2` plus

```jsonc
"publicToken": "…22 Zeichen…" | null,
"vouchers": [{"id": "<uuid>", "code": "12345678", "valueCents": 2500, "linePosition": 2}],   // verkauft; beim Storno valueCents negativ
"payments": [{ …wie v: 2…, "kind": "cash" | "card" | "voucher",
               "voucherId": "<uuid>" | null, "voucherCode": "12345678" | null, "voucherBalanceAfterCents": 1535 | null }]
```

Server-Migration `0005_vouchers.sql`:

| Tabelle | Inhalt |
| --- | --- |
| `receipts` | neue Spalten `voucher_cents`, `voucher_sale_cents`, `deposit_return_cents` (int, Vorgabe 0; alte Bons behalten 0, kein UPDATE nötig), `public_token` text |
| `receipt_links` (neu) | `token` text Schlüssel, `business_id`, `receipt_id`. Ohne Zeilen-Schutz je Betrieb, weil die Seite ohne Anmeldung sucht; der Schlüssel ist das Geheimnis. Nur anfügen |
| `vouchers` (neu) | `business_id`, `id` uuid, `code` text, `value_cents`, `created_at`, `is_test`, `sold_receipt_id` uuid, `register_id` uuid, `change_seq`. Schlüssel (`business_id`, `id`), Index auf (`business_id`, `code`) |
| `voucher_movements` (neu) | `business_id`, `voucher_id`, `receipt_id`, `kind`, `amount_cents`, `created_at`, `change_seq`. Schlüssel (`business_id`, `voucher_id`, `receipt_id`). Nur anfügen |
| `customers` (neu) | `business_id`, `id` uuid, `name`, `address_line1`, `address_line2`, `vat_id`, `archived`, `updated_at`, `change_seq` |
| `receipt_recipients` (neu) | `business_id`, `receipt_id`, `version`, `customer_id`, `name`, `address_line1`, `address_line2`, `vat_id`, `created_at`, `staff_id`, `staff_name`. Nur anfügen |
| `receipt_deliveries` (neu) | `business_id`, `receipt_id`, `kind` (`printed`, `digital`), `at`. Nur anfügen |

Alle neuen Tabellen außer `receipt_links` bekommen den Zeilen-Schutz je Betrieb und die Rechte wie die Tabellen aus `0002`; "nur anfügen" heißt derselbe Trigger wie bei `receipts`. `change_seq` zählt wie bei den Artikeln (für den Abgleich zum Tablet in Task 13 und 16). `payment_kind` kennt zusätzlich `voucher` (nur Gutschein); sobald zwei Arten zahlen, steht `mixed`.

Regeln am Server:
- `v: 3` wird wie `v: 2` geprüft und gespeichert. Dazu: `voucher_cents` = Summe der Gutschein-Zahlungen, `voucher_sale_cents` = Summe (`unitPriceCents * quantity`) der Zeilen mit `itemId` `voucher-sale`, `deposit_return_cents` = Summe (`unitDepositCents * quantity`) der Zeilen, deren `itemId` mit `deposit-return-` beginnt. Mit `publicToken` entsteht die Zeile in `receipt_links`.
- Aus dem Bon entstehen Gutscheine und Bewegungen: je Eintrag in `vouchers` ein Gutschein (falls noch nicht da; `is_test` vom Bon) und eine Bewegung mit `amount_cents = valueCents` (`sale`, beim Storno `void_sale`); je Gutschein-Zahlung eine Bewegung mit `amount_cents = -amountCents` (`redeem`, beim Storno `void_redeem`). Kommt derselbe Bon noch einmal, entsteht nichts doppelt.
- Der Server prüft die neuen festen Regeln aus den Global Constraints (Reihenfolge, Betrag unter 0 nur bar, Gutschein-Zeile nie mit Gutschein-Zahlung) und lehnt sonst mit `invalid` ab, wie bei den Regeln aus 1a. Er prüft **nicht**, ob das Guthaben reicht: Das Tablet hat den Bon schon signiert.
- Ein Bon, den der Server als `v: 1` oder `v: 2` schon hat und der als `v: 3` wiederkommt, ist `duplicate` (Muster `asV1` aus 1a: der Vergleich nimmt die Felder, die es in der alten Form gab). Kein Bericht.
- Tablets mit 1.10.0 und 1.11.0 arbeiten weiter: `v: 1` und `v: 2` werden angenommen wie bisher, die neuen Spalten bleiben 0.

- [ ] **Step 1: Bon aus 1.11.0 festhalten.** Wie `tool/fixtures/receipt_1_10_0.md` für 1.10.0: mit dem Code von `a06aeb3` (1.11.0) auf `kassa_v8.sqlite` einen Bon "Teil bar, Rest Karte" mit Trinkgeld und Rabatt verkaufen; die Datenbank als `kassa_v8_receipts_1_11_0.sqlite` und den gesendeten Eintrag als `receipt_1_11_0_v2.json` ablegen; der Weg steht in `tool/fixtures/receipt_1_11_0.md`.

- [ ] **Step 2: Die Tests schreiben, die scheitern**

```dart
// push_wire_test.dart
test('Bon v: 3: Gutschein-Verkauf geht mit vouchers hinaus, Gutschein-Zahlung mit Code und Restguthaben, publicToken ist dabei', ...);
test('push_request_v3.json: was das Tablet für die Beispiel-Bons baut, ist genau die Datei', ...);   // Muster: der Test für push_request_v2.json
// receipt_1_11_0_test.dart
test('der Bon aus 1.11.0 geht nach dem Update als v: 3 hinaus und ist genau receipt_1_11_0_as_v3.json', ...);
```

```ts
// push.test.ts
test('v: 3 mit Gutschein-Verkauf: Gutschein, Bewegung sale, voucher_sale_cents; noch einmal gesendet: duplicate, nichts doppelt', ...);
test('v: 3 mit Gutschein-Zahlung und Rest bar: payment_kind mixed, voucher_cents 500, Bewegung redeem -500', ...);
test('v: 3 Storno: Bewegungen void_redeem und void_sale mit umgekehrtem Vorzeichen', ...);
test('v: 3 nur Pfand zurück: total_cents -75, deposit_return_cents -75, cash_cents -75', ...);
test('v: 3 mit publicToken: Zeile in receipt_links; derselbe Schlüssel bei einem zweiten Bon ist invalid', ...);
test('receipt_1_11_0_v2.json, dann receipt_1_11_0_as_v3.json: duplicate, kein Bericht', ...);
test('receipt_1_10_0_v1.json, dann derselbe Bon als v: 3: duplicate, kein Bericht', ...);
test('v: 3 mit bar vor Gutschein, mit Karte unter 0, mit Gutschein-Zeile und Gutschein-Zahlung: invalid', ...);
test('v: 1 und v: 2 werden weiter angenommen, voucher_cents bleibt 0', ...);
// migrate.test.ts
test('0005 läuft auf einer Datenbank mit Stand 0004 und alten Bons: neue Spalten 0, receipts bleibt unveränderlich', ...);
```

In `migrate.test.ts` bekommt die erwartete Liste der Migrationen `0005_vouchers.sql` dazu (genannte Änderung einer vorhandenen Erwartung).

- [ ] **Step 3: Laufen lassen, sie scheitern**

Run: `cd server && npx vitest run test/push.test.ts test/migrate.test.ts`
Expected: FAIL (`v: 3` ist `invalid`).

- [ ] **Step 4: Umsetzen** nach den Regeln oben.

- [ ] **Step 5: Laufen lassen, alles grün**

Run: `cd app && ~/flutter/bin/flutter test test/sync/ && ~/flutter/bin/flutter analyze`; `cd server && npx vitest run test/push.test.ts test/migrate.test.ts test/push_schema.test.ts && npm run typecheck`
Expected: PASS.

- [ ] **Step 6: Commit** `Stufe 1b Task 5: Abgleich v: 3 und Server-Migration 0005`.

### Task 6: Auswertungen am Tablet rechnen mit Pfand zurück und Gutscheinen

Spec 5.7.

**Files:**
- Modify: `app/lib/domain/{day,period_report,stats}.dart`, `app/lib/data/{day,period_report,stats}_repository.dart`, `app/lib/data/receipt_tally.dart`
- Test: `app/test/data/{day_repository,period_report_repository,stats_repository}_test.dart`

**Interfaces:**
- Consumes: Task 4.
- Produces:

```dart
// DaySummary und PeriodReport (und was sie je Monat führen) bekommen:
final int voucherPaidCents;       // mit Gutschein bezahlt, Storno abgezogen
final int voucherSoldCount;       // verkaufte Gutscheine, Storno abgezogen
final int voucherSoldCents;
final int depositReturnCount;     // Stück, Storno abgezogen
final int depositReturnCents;     // ausbezahltes oder verrechnetes Pfand als positive Zahl
// revenueCents ist ab jetzt ohne verkaufte Gutscheine.
```

Regeln:
- `revenueCents` = Summe (`totalCents - voucherSaleCents`) der Bons. `cashRevenueCents` und `cardRevenueCents` kommen weiter aus den Zahlungen (sie enthalten das Geld für verkaufte Gutscheine und die Pfand-Auszahlung mit Minus). Es gilt immer: `cashRevenueCents + cardRevenueCents + voucherPaidCents - voucherSoldCents == revenueCents`.
- `expectedCashCents` bleibt die Formel aus 1a.
- `cashReceiptCount` und `cardReceiptCount` zählen wie bisher nach `paymentKind`; ein Bon nur mit Gutschein zählt in keinem von beiden.
- "Meistverkauft" und Kategorien: Zeilen mit `isDepositReturnItemId` oder `isVoucherSaleItemId` kommen nicht vor; der Umsatz der Übersicht ist ohne verkaufte Gutscheine.
- Die Steuerzeilen (`taxLines`) enthalten im Satz 0 weiter alles, was signiert wird (also auch Gutschein-Zeilen); der Ausdruck trennt das in Task 17.

- [ ] **Step 1: Die Tests schreiben, die scheitern**

```dart
// day_repository_test.dart
test('ein Tag mit Barbon, Gutschein-Verkauf, Gutschein-Zahlung und Pfand-Auszahlung', () async {
  // A: cart bar (18,20). B: Gutschein 25,00 € bar verkauft. C: cartCard mit dem Gutschein bezahlt (9,65). D: 3 × Pfand zurück ausbezahlt (-0,75).
  final s = await summaryOfToday();
  expect((s.revenueCents, s.cashRevenueCents, s.cardRevenueCents), (2710, 4245, 0));
  expect((s.voucherPaidCents, s.voucherSoldCount, s.voucherSoldCents, s.depositReturnCount, s.depositReturnCents), (965, 1, 2500, 3, 75));
  expect(s.expectedCashCents, s.openingFloatCents + 4245);
  expect((s.receiptCount, s.cashReceiptCount, s.cardReceiptCount), (4, 3, 0));
});
test('Storno von C und D: voucherPaidCents 0, depositReturnCount 0, revenueCents 1820', ...);
```

Dazu in `day_repository_test.dart`: `'200 zufällige Bons mit Pfand zurück und Gutscheinen, danach alle storniert (Einlösungen vor den Verkäufen): Umsatz 0, alle fünf neuen Zahlen 0, erwartetes Bargeld = Wechselgeld'`. Dazu derselbe Tag in `period_report_repository_test.dart` (ein Monat) und in `stats_repository_test.dart` (`'Gutschein und Pfand zurück stehen nicht bei meistverkauft; der Umsatz ist ohne den verkauften Gutschein'`).

- [ ] **Step 2: Laufen lassen, sie scheitern**

Run: `cd app && ~/flutter/bin/flutter test test/data/day_repository_test.dart`
Expected: FAIL (`voucherPaidCents` gibt es nicht).

- [ ] **Step 3: Umsetzen.**

- [ ] **Step 4: Laufen lassen, alles grün**

Run: `cd app && ~/flutter/bin/flutter test test/data/ test/features/close_test.dart test/features/month_test.dart test/features/overview_test.dart && ~/flutter/bin/flutter analyze`
Expected: PASS.

- [ ] **Step 5: Commit** `Stufe 1b Task 6: Auswertungen am Tablet mit Pfand zurück und Gutscheinen`.

### Task 7: Verwaltung: Auswertungen am Server und im Browser

Spec 5.7.

**Files:**
- Create: `shared/fixtures/stats/stufe_1b.json`
- Modify: `server/src/admin/{months,days,overview,receipts}.ts`, `web/src/api/{receipts,days,months}.ts`, `web/src/pages/{ReceiptsPage,ReceiptDetail,DayDetail,PeriodDetail}.tsx`
- Test: `server/test/{months,days,overview,receipts}.test.ts`, `app/test/data/stats_repository_test.dart` (liest die gemeinsamen Dateien), `web/src/pages/income_rows.test.ts`, `web/src/pages/receipt_payments.test.ts` (neu)

**Interfaces:**
- Consumes: die Spalten aus Task 5.
- Produces: Tag, Monat und Zeitraum liefern zusätzlich `voucherPaidCents`, `voucherSoldCount`, `voucherSoldCents`, `depositReturnCount`, `depositReturnCents` (Bedeutung wie Task 6). Die Liste der Bons liefert je Bon `voucherCents` und nimmt den Filter `payment=voucher` (zeigt jeden Bon mit `voucher_cents != 0`). Das Detail eines Bons liefert die Zahlungen mit `voucherCode` und `voucherBalanceAfterCents` und die verkauften Gutscheine (`vouchers`).

Regeln:
- Umsatz ist überall `total_cents - voucher_sale_cents`. Übersicht und "meistverkauft" lassen Zeilen mit `voucher-sale` und `deposit-return-` weg. Wo die Übersicht nach Zahlungsart teilt (Server und Browser), kommt "Gutschein" als dritte Art dazu, nur wenn nicht 0.
- Die vorhandenen gemeinsamen Dateien `shared/fixtures/stats/{mixed,months,overview}.json` ändern sich in dieser Aufgabe nicht (sie bekommen in Task 5 einmal die Form `v: 3`, sonst nichts), und sie bekommen keine neuen Bons. Vorhandene Tests über sie ändern sich nur so, wie die Global Constraints es für Task 7 nennen. Die vier Bons aus Task 6 kommen in `v: 3` in die **neue** Datei `stufe_1b.json` (Bons, erwarteter Tag, erwarteter Monat, erwartete Übersicht), erzeugt und gelesen nach dem Muster von `mixed.json`: Tablet und Server lesen dieselbe Datei und kommen auf dieselben Zahlen.
- Web: `DayDetail` und `PeriodDetail` zeigen "Mit Gutschein bezahlt", "Gutscheine verkauft" (Anzahl, Summe) und "Pfand zurück" (Anzahl, Summe) nur, wenn der Wert nicht 0 ist. `ReceiptsPage`: Zahlungsart aus allen Arten des Bons ("Gutschein + Bar"), Filter "Gutschein". `ReceiptDetail`: je Gutschein-Zahlung "Gutschein 1234 5678" mit Betrag und "Restguthaben", je verkauftem Gutschein Wert und Code. Vorhandene Tests vergleichen weiter jeden alten Wert genau und prüfen die neuen einzeln dazu.

- [ ] **Step 1: Die Tests schreiben, die scheitern**

```ts
// months.test.ts, days.test.ts
test('Monat mit Gutschein-Verkauf, Gutschein-Zahlung und Pfand-Auszahlung: Umsatz ohne verkauften Gutschein, die fünf neuen Zahlen stimmen', ...);   // 2710, 965, 1, 2500, 3, 75
// receipts.test.ts
test('Filter voucher zeigt nur Bons mit Gutschein-Zahlung; das Detail trägt Code und Restguthaben', ...);
// overview.test.ts
test('Gutschein und Pfand zurück stehen nicht bei meistverkauft', ...);
// web: receipt_payments.test.ts
test('Zahlungsart: "Gutschein", "Gutschein + Bar", "Gutschein + Karte", "Bar + Karte" bleibt', ...);
```

- [ ] **Step 2: Laufen lassen, sie scheitern**

Run: `cd server && npx vitest run test/months.test.ts test/receipts.test.ts`
Expected: FAIL.

- [ ] **Step 3: Umsetzen.**

- [ ] **Step 4: Laufen lassen, alles grün**

Run: `cd server && npx vitest run test/months.test.ts test/days.test.ts test/overview.test.ts test/receipts.test.ts && npm run typecheck`; `cd web && npm test && npm run typecheck`; `cd app && ~/flutter/bin/flutter test test/data/stats_repository_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit** `Stufe 1b Task 7: Auswertungen am Server und im Browser`.

---

## Teil 2: Schalter

### Task 8: Schalter in den Einstellungen, und der Test "alles aus ist wie 1.11.0"

Spec 5.1.

**Files:**
- Create: `app/lib/features/settings/receipt_section.dart`, `app/test/features/stufe_1b_off_test.dart`
- Modify: `app/lib/features/settings/{settings_screen,payment_section}.dart`, `app/lib/l10n/app_*.arb`, Goldens der Einstellungen
- Test: `app/test/features/settings_test.dart`, `app/test/features/stufe_1b_off_test.dart`, `app/test/golden/*einstellungen*`

**Interfaces:**
- Consumes: die Felder aus Task 1; `hasServer` und der Zustand "gekoppelt" (`SyncStateRows.registerId != null`, wie ihn die Einstellungen "Server" heute lesen).
- Produces: Abschnitt "Zahlen" mit drei weiteren Reihen, neuer Abschnitt "Kundenbon" direkt darunter.

Regeln:
- "Zahlen": "Pfand zurück" (`setting-deposit-return`, drei Werte wie "Rabatt"), "Gutschein" (`setting-voucher`, Schalter), "Rechnung an Firma" (`setting-invoice`, Schalter). Reihenfolge nach den vier Reihen aus 1a.
- "Kundenbon" (`receipt-section`): drei Werte als Auswahl untereinander, jeder mit einer Zeile Erklärung: "Immer drucken" (`receipt-mode-alwaysPrint`), "Drucken und digital" (`receipt-mode-printAndDigital`), "Digital und Druck auf Wunsch" (`receipt-mode-digitalOnRequest`). Ist die Kassa nicht mit dem Server gekoppelt, sind die zwei digitalen Werte grau, und darunter steht `settingsReceiptNeedsServer`. Bei einem digitalen Wert steht darunter `settingsReceiptQrHint`.
- ARB: `settingsDepositReturn` "Pfand zurück", `settingsVoucher` "Gutschein", `settingsVoucherInfo` "Wertgutscheine verkaufen und einlösen", `settingsInvoice` "Rechnung an Firma", `settingsInvoiceInfo` "Bon mit Name und Adresse des Kunden drucken", `settingsReceiptTitle` "Kundenbon", `settingsReceiptAlways` "Immer drucken", `settingsReceiptAlwaysInfo` "Nach jedem Verkauf, wie bisher", `settingsReceiptBoth` "Drucken und digital", `settingsReceiptBothInfo` "Drucken und zusätzlich den QR-Code zeigen", `settingsReceiptDigital` "Digital und Druck auf Wunsch", `settingsReceiptDigitalInfo` "QR-Code zeigen, drucken nur auf Tipp", `settingsReceiptNeedsServer` "Geht nur, wenn die Kassa mit dem Server verbunden ist.", `settingsReceiptQrHint` "Der Kunde muss den QR-Code am Bildschirm sehen können."
- `stufe_1b_off_test.dart`: Mit den Vorgaben (alles aus, "immer drucken") und mit allen vier Schaltern aus 1a **an** gibt es keinen der neuen Schlüssel an der Kassa, in "Verkauf fertig" und im Detail eines Bons: `more-button`, `deposit-return-button`, `voucher-button`, `pay-voucher`, `finish-voucher`, `pay-out`, `invoice-button`, `invoice-hint`, `receipt-qr`, `receipt-qr-wait`, `print-receipt-now`, `detail-receipt-qr`. Die Bilder der Kassa aus 1a und 1.10.0 ändern sich nicht. Der Test wächst mit jeder Funktions-Aufgabe um deren Schlüssel nicht mehr: Er nennt sie schon alle.

- [ ] **Step 1: Die Tests schreiben, die scheitern**

```dart
// settings_test.dart
testWidgets('Zahlen: Pfand zurück, Gutschein, Rechnung an Firma sind aus und lassen sich stellen', (t) async {
  // öffnen, tippen: setting-deposit-return auf "Nur Chef", setting-voucher, setting-invoice
  expect(await queryRows(t, 'SELECT deposit_return_access, voucher, invoice FROM settings'),
      [{'deposit_return_access': 'chefOnly', 'voucher': 1, 'invoice': 1}]);
});
testWidgets('Kundenbon: ohne Kopplung sind die digitalen Werte grau, mit Kopplung lässt sich "Digital und Druck auf Wunsch" wählen', ...);
// stufe_1b_off_test.dart
testWidgets('alles aus: keiner der neuen Schlüssel an der Kassa, auf "Verkauf fertig" und im Bon-Detail', ...);
```

- [ ] **Step 2: Laufen lassen, sie scheitern.** Run: `cd app && ~/flutter/bin/flutter test test/features/settings_test.dart` Expected: FAIL.

- [ ] **Step 3: Umsetzen**; Texte in fünf Sprachen. Die Bilder der Einstellungen werden neu gemacht (`--update-goldens` nur für die Dateien der Einstellungen); welche Bilder sich geändert haben, steht im Bericht.

- [ ] **Step 4: Laufen lassen, alles grün**

Run: `cd app && ~/flutter/bin/flutter test test/features/settings_test.dart test/features/stufe_1b_off_test.dart test/features/stufe_1a_off_test.dart test/golden/ test/l10n_review_test.dart test/l10n_layout_test.dart && ~/flutter/bin/flutter analyze`
Expected: PASS; außer den Bildern der Einstellungen ändert sich kein Golden.

- [ ] **Step 5: Commit** `Stufe 1b Task 8: Schalter in den Einstellungen`.

---

## Teil 3: Funktionen

Für alle Aufgaben in diesem Teil gilt: Blätter öffnen in der Bon-Spalte nach dem Muster von `open_amount_sheet.dart` und `discount_sheet.dart` (eigener Wert in `_Side`, Artikel-Fläche abgedunkelt, "Zurück" und die Zurück-Geste schließen). Neue Texte kommen sofort in alle fünf ARB-Dateien. Jede Aufgabe lässt `test/features/stufe_1b_off_test.dart` und `test/features/stufe_1a_off_test.dart` mitlaufen.

### Task 9: Pfand zurück an der Kassa, Taste "Mehr", "Bar auszahlen"

Spec 5.1 (Kopf der Bon-Spalte), 5.2.

**Files:**
- Create: `app/lib/features/kassa/more_sheet.dart`, `app/lib/features/kassa/deposit_return_sheet.dart`, `app/test/features/deposit_return_test.dart`, `app/test/features/more_sheet_test.dart`
- Modify: `app/lib/domain/catalog.dart`, `app/lib/features/kassa/{kassa_screen,cart_panel,cart_line_row,cart_controller,discount_sheet,sale_service,sale_done}.dart`, `app/lib/l10n/app_*.arb`
- Test: die zwei neuen Dateien, `app/test/domain/catalog_test.dart` (neu, falls es sie nicht gibt), `app/test/features/sale_service_test.dart`

**Interfaces:**
- Consumes: `Cart.setDepositReturn`, `depositReturnQuantity` (Task 2), `finalizePayout` (Task 4), `RegisterSettings.depositReturnAccess` (Task 1), `allowed(FeatureAccess, Staff)` aus 1a.
- Produces:

```dart
// domain/catalog.dart
List<int> depositAmounts(Catalog catalog);     // alle Pfand-Beträge > 0 von Artikeln im Verkauf und ihren Auswahlen, ohne Doppelte, aufsteigend
// features/kassa/cart_controller.dart
void setDepositReturns(Map<int, int> quantityByCents);   // setzt jede Reihe des Blatts in einem Schritt
// features/kassa/sale_service.dart
Future<SaleResult> completePayout({required String saleId, required Cart cart, required Staff staff});
// features/kassa/more_sheet.dart
enum HeadAction { openAmount, depositReturn, voucher }
List<HeadAction> headActions({required RegisterSettings settings, required Staff staff, required Catalog catalog});
```

Regeln:
- `headActions`: `openAmount`, wenn der freie Betrag erlaubt ist (wie 1a); `depositReturn`, wenn `depositReturnAccess` die Person erlaubt **und** `depositAmounts(catalog)` nicht leer ist; `voucher`, wenn `voucherEnabled`. In dieser Aufgabe liefert `headActions` den Eintrag `voucher` noch nie (ein fester Schalter im Code, mit Test); Task 10 baut das Blatt und schaltet ihn frei. Genau ein Eintrag: seine eigene Taste im Kopf (`open-amount-button`, `deposit-return-button`, `voucher-button`). Zwei oder drei: nur `more-button` ("Mehr"); das Blatt `more-sheet` zeigt je Eintrag eine große Taste (`more-open-amount`, `more-deposit-return`, `more-voucher`), ein Tipp öffnet das Blatt der Funktion. Kein Eintrag: nichts im Kopf.
- Blatt `deposit-return-sheet`: je Betrag eine Reihe mit `deposit-return-minus-<cents>`, `deposit-return-count-<cents>`, `deposit-return-plus-<cents>` (0 bis 99, Minus bei 0 und Plus bei 99 grau), darunter `deposit-return-total` ("Zurück −0,75 €"), `deposit-return-add` ("Auf den Bon", grau solange die Mengen gleich denen am Bon sind) und `deposit-return-back`. Das Blatt öffnet mit den Mengen, die schon am Bon stehen; "Auf den Bon" ruft `setDepositReturns` und schließt.
- Zeile am Bon: "3 × Pfand zurück" mit "−0,75 €", Minus und Plus wie jede Zeile (Plus bei 99 grau). Die Zeile ist kein Ziel im Rabatt-Blatt und zeigt keinen Rabatt.
- Zahlen: Summe über 0 wie bisher. Summe genau 0 (mit Pfand zurück, auch ohne Rabatt): `finish-free` ("Abschließen"), Lade bleibt zu. Summe unter 0: an Stelle von `pay-cash`, `pay-card` und "Teil bar" steht nur `pay-out` ("Bar auszahlen 0,75 €"); ein Tipp ruft `completePayout`.
- `completePayout`: `finalizePayout`, Kundenbon drucken mit `openDrawer: true` (nach derselben Regel wie beim Barverkauf), Küchenbon wie immer (ein Bon unter 0 kann Ware enthalten).
- "Verkauf fertig" nach einer Auszahlung: an der Stelle von "Rückgeld" steht `payout-done` ("Auszahlen 0,75 €").
- ARB: `kassaMore` "Mehr", `kassaDepositReturn` "Pfand zurück", `depositReturnTotal` "Zurück", `depositReturnAdd` "Auf den Bon", `kassaPayOut` "Bar auszahlen {amount}", `kassaPayOutDone` "Auszahlen".

- [ ] **Step 1: Die Tests schreiben, die scheitern**

```dart
// catalog_test.dart
test('depositAmounts: Beträge von Artikeln und Auswahlen, ohne Doppelte, aufsteigend; archivierte und nicht verkaufte zählen nicht', () {
  expect(depositAmounts(catalog), [25]);                       // Beispiel-Karte
  expect(depositAmounts(catalogWith(becher100, flasche25Option)), [25, 100]);
  expect(depositAmounts(catalogWithoutDeposit), isEmpty);
});
// more_sheet_test.dart
test('headActions: eine Funktion → ihre Taste; zwei → Mehr; Pfand zurück nur mit Pfand in der Karte und nur für erlaubte Personen', ...);
testWidgets('nur freier Betrag an: der Kopf ist wie in 1.11.0 (open-amount-button, kein more-button)', ...);
testWidgets('freier Betrag und Pfand zurück an: Mehr öffnet das Blatt, ein Tipp auf Pfand zurück öffnet dessen Blatt', ...);
testWidgets('Pfand zurück "Nur Chef": Anna sieht keine Taste, der Chef schon', ...);
// deposit_return_test.dart
testWidgets('3 × 0,25 € zurück auf einen Bon mit Ware: Zeile, Summe 17,45 €, bar zahlen wie immer', (t) async {
  // setSettings(depositReturnAccess: all); cart; deposit-return-button; 3 × plus; deposit-return-add
  expect(textOf(t, 'deposit-return-total'), contains('−0,75'));     // im Blatt, vor "Auf den Bon"
  expect(cartOf(t).depositReturnQuantity(25), 3);
  expect(cartOf(t).totalCents, 1745);
  expect(find.byKey(const Key('pay-cash')), findsOneWidget);
});
testWidgets('nur Pfand zurück: "Bar auszahlen 0,75 €", Bon mit einer Bar-Zahlung über −0,75 €, Lade springt auf, "Auszahlen 0,75 €"', (t) async {
  expect(find.byKey(const Key('pay-cash')), findsNothing);
  expect(find.byKey(const Key('pay-card')), findsNothing);
  await t.tap(find.byKey(const Key('pay-out'))); await t.pumpAndSettle();
  expect(await queryRows(t, 'SELECT kind, amount_cents, given_cents, change_cents FROM payments'),
      [{'kind': 'cash', 'amount_cents': -75, 'given_cents': 0, 'change_cents': 0}]);
  expect(printerOf(t).drawerOpened, 1);
  expect(textOf(t, 'payout-done'), contains('0,75'));
});
testWidgets('Pfand zurück gleich Summe der Ware: "Abschließen", keine Zahlung mit Betrag, Lade bleibt zu', ...);   // Cola 2,90 + 0,25 Pfand, zurück 0,25 × … bis Summe 0 über einen Artikel zu 0,25 € im Test-Katalog
testWidgets('Summe unter 0 mit Rabatt 100 %, freiem Betrag und "Teil bar" an: nur pay-out, kein Trinkgeld, kein Gutschein', ...);   // Review Focus 3
testWidgets('das Blatt öffnet mit den Mengen vom Bon; alle auf 0 nimmt die Zeile weg', ...);
testWidgets('die Zeile Pfand zurück ist kein Ziel im Rabatt-Blatt', ...);
// sale_service_test.dart
test('completePayout druckt den Bon, öffnet die Lade und druckt den Küchenbon, wenn Ware dabei ist', ...);
```

- [ ] **Step 2: Laufen lassen, sie scheitern**

Run: `cd app && ~/flutter/bin/flutter test test/features/deposit_return_test.dart test/features/more_sheet_test.dart`
Expected: FAIL (`deposit-return-button` gibt es nicht).

- [ ] **Step 3: Umsetzen** nach den Regeln oben.

- [ ] **Step 4: Laufen lassen, alles grün**

Run: `cd app && ~/flutter/bin/flutter test test/domain/catalog_test.dart test/features/deposit_return_test.dart test/features/more_sheet_test.dart test/features/open_amount_test.dart test/features/discount_test.dart test/features/kassa_test.dart test/features/cash_test.dart test/features/sale_service_test.dart test/features/stufe_1a_off_test.dart test/features/stufe_1b_off_test.dart test/golden/kassa_golden_test.dart test/l10n_review_test.dart && ~/flutter/bin/flutter analyze`
Expected: PASS, kein Golden geändert.

- [ ] **Step 5: Commit** `Stufe 1b Task 9: Pfand zurück an der Kassa, Mehr, Bar auszahlen`.

### Task 10: Gutschein verkaufen und prüfen

Spec 5.5 (Verkaufen, Prüfen, Storno des Verkaufs, Übungsmodus).

**Files:**
- Create: `app/lib/features/kassa/voucher_sheet.dart`, `app/lib/features/kassa/voucher_code_entry.dart`, `app/lib/domain/voucher_layout.dart`, `app/test/features/voucher_sale_test.dart`, `app/test/domain/voucher_layout_test.dart`
- Modify: `app/lib/features/kassa/{kassa_screen,cart_panel,cart_line_row,cart_controller,sale_service,sale_done,more_sheet}.dart`, `app/lib/features/bons/{receipt_detail,void_question}.dart`, `app/lib/devices/printer.dart`, die Test-Drucker in `app/test/support/`, `app/lib/l10n/app_*.arb`
- Test: die neuen Dateien, `app/test/devices/printer_test.dart`, `app/test/features/bons_test.dart`

**Interfaces:**
- Consumes: `Cart.addVoucherSale`, die Grenzen und Vorschläge (Task 2), `Receipt.soldVouchers`, `Voucher`, `formatVoucherCode` (Task 3), `VoucherRepository`, `VoucherSaleRedeemedException` (Task 4), `headActions` (Task 9).
- Produces:

```dart
// domain/voucher_layout.dart
List<PrintOp> layoutVoucher(SoldVoucher voucher, BusinessInfo business,
    {required DateTime soldAt, required bool isTest, int columns = 48});
// devices/printer.dart
Future<PrintOutcome> printVoucher(SoldVoucher voucher, {required DateTime soldAt, required bool isTest});   // in ReceiptPrinter
// features/kassa/sale_service.dart
class SaleResult { final Future<List<PrintOutcome>> voucherPrints; }     // leer ohne verkauften Gutschein
Future<PrintOutcome> printVoucher(Receipt receipt, SoldVoucher voucher);  // Nachdruck, auch aus "Bons"
// features/kassa/voucher_code_entry.dart
class VoucherCodeEntry extends ConsumerStatefulWidget {
  const VoucherCodeEntry({super.key, required this.onFound, required this.onCleared});
  final void Function(Voucher voucher) onFound;     // genau ein Treffer, oder die Person hat unter zweien gewählt
  final VoidCallback onCleared;                     // der Code ist wieder kürzer als 8 Ziffern
}
```

Regeln:
- Blatt `voucher-sheet` mit den Reitern `voucher-tab-sell` und `voucher-tab-check`.
- **Verkaufen:** Tasten `voucher-preset-<cents>` für `voucherPresetCents`, darunter `voucher-other` ("Anderer Betrag", das Zahlenfeld aus `AmountEntry`), `voucher-add` ("Auf den Bon") und `voucher-back`. Ein Vorschlag wählt den Wert, "Auf den Bon" legt die Zeile an und schließt. Außerhalb 1,00 bis 500,00 € ist "Auf den Bon" grau mit dem Grund `voucherRange`. Liegen am Bon gewählte Gutscheine (Task 11), ist "Auf den Bon" grau mit `voucherNotWithRedeem`.
- **Zeile am Bon:** "Gutschein" mit dem Wert; Minus nimmt sie weg, kein Plus, kein Ziel im Rabatt-Blatt.
- **Abschließen:** Bezahlt wird wie jeder Bon (bar, Karte, Teil bar, Trinkgeld). Nach dem Kundenbon druckt die Kassa je verkauftem Gutschein einen Abschnitt (`printVoucher`), in der Reihenfolge der Zeilen und nur, wenn der Kundenbon ohne Fehler gedruckt ist oder nicht von selbst gedruckt wird (Task 15). Ohne Drucker druckt nichts.
- **"Verkauf fertig":** je Gutschein eine Reihe `sold-voucher-<n>` mit Wert und Code ("1234 5678", `sold-voucher-code-<n>`) und der Taste `sold-voucher-print-<n>` ("Gutschein drucken"); scheitert der Druck, steht der Grund in der Reihe wie beim Kundenbon.
- **Abschnitt** (`layoutVoucher`, Deutsch): Kopf des Betriebs wie am Bon, "GUTSCHEIN" fett und mittig, Wert in doppelter Höhe, "Code" und der Code in doppelter Höhe ("1234 5678"), Datum, "Einlösbar bei <Name des Betriebs>", bei `isTest` darunter "ÜBUNG" und "Kein gültiger Gutschein", dann Vorschub und Schnitt.
- **Prüfen:** `VoucherCodeEntry` (Zahlenfeld, Anzeige `voucher-code` als "1234 5…"); nach der achten Ziffer sucht sie mit `findByCode`. Kein Treffer: `voucher-code-problem` mit `voucherUnknown`. Zwei oder mehr Treffer: Reihen `voucher-pick-<i>` mit Wert und Datum, ein Tipp wählt. Das Ergebnis im Reiter: `voucher-check-value`, `voucher-check-balance`, `voucher-check-state` (aktiv, aufgebraucht, storniert, überzogen, dazu "Übungs-Gutschein" bei `isTest`) und die Bewegungen `voucher-check-movement-<i>` mit Datum, Art und Betrag, neueste oben.
- **Bons, Detail:** je verkauftem Gutschein Wert, Code und `detail-voucher-print-<n>`. Storno eines Bons mit eingelöstem Gutschein: `void-failure` zeigt `bonsVoidVoucherRedeemed`, nichts ist gespeichert.
- ARB: `kassaVoucher` "Gutschein", `voucherSell` "Verkaufen", `voucherCheck` "Prüfen", `voucherOther` "Anderer Betrag", `voucherAdd` "Auf den Bon", `voucherRange` "Von 1,00 € bis 500,00 €", `voucherNotWithRedeem` "Dieser Bon wird mit einem Gutschein bezahlt.", `voucherCode` "Code", `voucherValue` "Wert", `voucherBalance` "Guthaben", `voucherUnknown` "Diesen Gutschein kennt die Kassa nicht.", `voucherStateActive` "Gültig", `voucherStateEmpty` "Aufgebraucht", `voucherStateVoided` "Storniert", `voucherStateOverdrawn` "Überzogen", `voucherIsTest` "Übungs-Gutschein", `voucherMoveSale` "Verkauft", `voucherMoveRedeem` "Eingelöst", `voucherMoveVoidSale` "Verkauf storniert", `voucherMoveVoidRedeem` "Einlösung storniert", `voucherPrint` "Gutschein drucken", `bonsVoidVoucherRedeemed` "Der Gutschein wurde schon eingelöst. Der Bon lässt sich nicht stornieren."

- [ ] **Step 1: Die Tests schreiben, die scheitern**

```dart
// voucher_layout_test.dart (Helfer `linesOf(ops)` wie in receipt_layout_test.dart)
test('Abschnitt Gutschein: Betrieb, GUTSCHEIN, Wert, Code in Gruppen, Datum; Übung trägt den Vermerk', () {
  final ops = layoutVoucher(const SoldVoucher(voucherId: 'v', code: '12345678', valueCents: 2500, linePosition: 2), business,
      soldAt: DateTime(2026, 11, 27, 12, 3), isTest: false);
  expect(linesOf(ops), containsAllInOrder([contains('Beispiel-Imbiss'), contains('GUTSCHEIN'), contains('25,00'), contains('1234 5678'), contains('27.11.2026')]));
  expect(linesOf(ops).join('\n'), isNot(contains('ÜBUNG')));
  expect(ops.last, isA<PrintCut>());
});
// voucher_sale_test.dart
testWidgets('25 € auf den Bon, bar bezahlt: Verkauf fertig zeigt Wert und Code, der Drucker bekommt Bon und einen Abschnitt', (t) async {
  // setSettings(voucherEnabled: true); voucher-button; voucher-preset-2500; voucher-add; pay-cash; passend
  final code = (await queryRows(t, 'SELECT code FROM vouchers')).single['code'] as String;
  expect(textOf(t, 'sold-voucher-code-0'), formatVoucherCode(code));
  expect(printerOf(t).printed.map((p) => p.kind), ['receipt', 'voucher']);
});
testWidgets('zwei Gutscheine auf einem Bon: zwei Zeilen, zwei Codes, zwei Abschnitte in der Reihenfolge der Zeilen', ...);
testWidgets('Anderer Betrag: 0,99 € und 500,01 € lassen "Auf den Bon" grau, 37,50 € geht', ...);
testWidgets('die Gutschein-Zeile hat kein Plus und ist kein Ziel im Rabatt-Blatt; Minus nimmt sie weg', ...);
testWidgets('ohne Drucker: kein Druck, der Code steht am Bildschirm', ...);
testWidgets('Prüfen: Code tippen zeigt Wert, Guthaben, Zustand und die Bewegungen; unbekannter Code sagt es', ...);
testWidgets('Prüfen: zwei Gutscheine mit demselben Code stehen zur Wahl', ...);        // zweiter Gutschein direkt in die Datenbank
testWidgets('Übungsmodus: der Abschnitt trägt ÜBUNG, Prüfen zeigt "Übungs-Gutschein"', ...);
// bons_test.dart
testWidgets('Detail: Gutschein nachdrucken; Storno nach dem Einlösen zeigt den Grund und speichert nichts', ...);
```

- [ ] **Step 2: Laufen lassen, sie scheitern**

Run: `cd app && ~/flutter/bin/flutter test test/features/voucher_sale_test.dart test/domain/voucher_layout_test.dart`
Expected: FAIL.

- [ ] **Step 3: Umsetzen.** Jeder Test-Drucker bekommt `printVoucher`. `headActions` liefert ab jetzt `voucher`, wenn `voucherEnabled`; der Test aus Task 9, der das Gegenteil festhält, wird durch `'Gutschein an: voucher-button allein, mit freiem Betrag zusammen unter Mehr'` ersetzt (genannte Änderung, sie gehört zu dieser Aufgabe).

- [ ] **Step 4: Laufen lassen, alles grün**

Run: `cd app && ~/flutter/bin/flutter test test/features/voucher_sale_test.dart test/domain/voucher_layout_test.dart test/features/more_sheet_test.dart test/features/bons_test.dart test/features/kassa_test.dart test/features/sale_service_test.dart test/devices/printer_test.dart test/features/stufe_1a_off_test.dart test/features/stufe_1b_off_test.dart test/l10n_review_test.dart && ~/flutter/bin/flutter analyze`
Expected: PASS.

- [ ] **Step 5: Commit** `Stufe 1b Task 10: Gutschein verkaufen und prüfen`.

### Task 11: Gutschein einlösen

Spec 5.5 (Einlösen), 5.6 (offene Kartenzahlung, Ausnahme bei belasteter Karte).

**Files:**
- Create: `app/lib/features/kassa/voucher_redeem_sheet.dart`, `app/test/features/voucher_redeem_test.dart`
- Modify: `app/lib/features/kassa/{kassa_screen,cart_panel,cart_controller,cash_sheet,tip_sheet,sale_service,sale_done,unclear_card_payment}.dart`, `app/lib/data/card_payment_repository.dart`, `app/lib/l10n/app_*.arb`
- Test: die neue Datei, `app/test/features/{cash,card,split_payment,tip,unclear_card,sale_service}_test.dart`, `app/test/data/card_payment_repository_test.dart`

**Interfaces:**
- Consumes: `Cart.applyVoucher/removeVoucher/withVoucherBalance`, `CartPricing.dueCents/voucherUses` (Task 2), `finalizeVoucherSale`, `finalizeCardSale(allowOverdraw:)`, `VoucherBalanceException`, `VoucherRepository` (Task 4), `VoucherCodeEntry` (Task 10).
- Produces:

```dart
// features/kassa/cart_controller.dart
void applyVoucher(AppliedVoucher voucher);
void removeVoucher(String voucherId);
Future<void> refreshVouchers();          // liest jedes Guthaben neu; ein Gutschein ohne Guthaben fällt vom Bon
// features/kassa/sale_service.dart
Future<SaleResult> completeVoucher({required String saleId, required Cart cart, required Staff staff});
// completeCash und payByCard rechnen mit cart.pricing.dueCents und werfen VoucherBalanceException weiter,
// solange das Terminal noch nichts erfahren hat.
```

Regeln:
- Taste `pay-voucher` ("Gutschein", kleiner, über "Bar" und "Karte"): nur wenn `voucherEnabled`, `dueCents > 0` und der Bon keine Gutschein-Zeile hat.
- Blatt `voucher-redeem-sheet`: oben "Zu zahlen" mit `dueCents`; `VoucherCodeEntry`; nach dem Treffer `voucher-redeem-balance` (Guthaben), `voucher-redeem-use` (wird eingelöst = `min(Guthaben, dueCents)`), `voucher-redeem-left` (bleibt am Gutschein) und `voucher-redeem-go`: "Einlösen 9,65 €", wenn das Guthaben reicht, sonst "Einlösen 5,00 €, Rest 4,65 €". Meldungen in `voucher-code-problem` statt der Zahlen: unbekannt (`voucherUnknown`), Guthaben 0 (`voucherEmpty`), storniert (`voucherVoided`), Guthaben unter 0 (`voucherEmpty`), Übungs-Gutschein im echten Betrieb und umgekehrt (`voucherTestOnly`, `voucherLiveOnly`), liegt schon am Bon (`voucherAlreadyOnReceipt`).
- "Einlösen", Guthaben reicht: `completeVoucher` (also `finalizeVoucherSale`), Kundenbon wie immer, Lade bleibt zu. "Verkauf fertig" zeigt `paid-by-voucher` ("Mit Gutschein bezahlt") und je Gutschein `voucher-left-<n>` ("Bleibt am Gutschein 15,35 €").
- "Einlösen", Guthaben reicht nicht: `applyVoucher`, das Blatt schließt. Im Summenblock steht je gewähltem Gutschein die Reihe `applied-voucher-<i>` ("Gutschein 1234 5678" mit "−5,00 €") mit `applied-voucher-remove-<i>` (×) und darunter `due-row` ("Noch zu zahlen 4,65 €"). "Bar", "Karte", "Teil bar" und Trinkgeld rechnen ab jetzt mit `dueCents`: Vorschläge im Bar-Blatt, Rückgeld, Kleinstbetrag der Karte, Vorschläge fürs Trinkgeld.
- Deckt die Auswahl nach einer Änderung am Bon alles (`dueCents == 0`, Summe über 0), stehen statt "Bar" und "Karte" nur `finish-voucher` ("Mit Gutschein abschließen") und die Reihen zum Entfernen.
- **Karte nach Gutschein:** Bevor das Terminal etwas erfährt, prüft die Kassa jedes Guthaben neu; reicht eines nicht, endet der Versuch ohne Terminal mit der Meldung unten. Die offene Zahlung trägt in `cartJson` die gewählten Gutscheine (das leistet `Cart.toJson` aus Task 2; `card_payment_repository_test.dart` hält es fest), der erwartete Betrag am Terminal ist `dueCents - Bar-Teil + Trinkgeld`. Sobald die Karte belastet ist (das Terminal meldet "bezahlt", oder eine unklare Zahlung wird bestätigt), schreibt die Kassa den Bon mit `allowOverdraw: true`. Wird eine unklare Zahlung verworfen, liegt der Bon wieder an der Kassa, mit den Gutscheinen und frischem Guthaben (`refreshVouchers`).
- **Guthaben hat sich geändert** (`VoucherBalanceException` bei bar, "nur Gutschein" oder vor dem Terminal): nichts ist gespeichert; die Kassa setzt das neue Guthaben am Bon (`withVoucherBalance`, bei 0 fällt der Gutschein weg), bleibt beim Bon und zeigt `voucher-changed` mit `voucherChanged`.
- `refreshVouchers` läuft, wenn der Entwurf nach einem Neustart geladen wird und wenn ein Abgleich Bewegungen eingespielt hat (Task 16 ruft es).
- Das Blatt zur unklaren Kartenzahlung nennt den Gutschein-Teil (`unclear-voucher`), wie es den Bar-Teil nennt.
- ARB: `kassaPayVoucher` "Gutschein", `voucherRedeemTitle` "Gutschein einlösen", `voucherDue` "Zu zahlen", `voucherUse` "Wird eingelöst", `voucherLeft` "Bleibt am Gutschein", `voucherRedeemAll` "Einlösen {amount}", `voucherRedeemPart` "Einlösen {amount}, Rest {rest}", `voucherEmpty` "Dieser Gutschein ist aufgebraucht.", `voucherVoided` "Dieser Gutschein ist storniert.", `voucherTestOnly` "Das ist ein Übungs-Gutschein.", `voucherLiveOnly` "Dieser Gutschein gilt nicht im Übungsmodus.", `voucherAlreadyOnReceipt` "Dieser Gutschein liegt schon am Bon.", `kassaDue` "Noch zu zahlen", `kassaFinishVoucher` "Mit Gutschein abschließen", `kassaPaidByVoucher` "Mit Gutschein bezahlt", `voucherChanged` "Das Guthaben hat sich geändert. Bitte noch einmal ansehen.", `unclearVoucherPart` "Mit Gutschein {amount}".

- [ ] **Step 1: Die Tests schreiben, die scheitern**

```dart
// voucher_redeem_test.dart (Helfer `sellVoucherAtRegister(t, cents)` verkauft bar und gibt den Code zurück)
testWidgets('Guthaben reicht: Einlösen schließt ab, Lade bleibt zu, Verkauf fertig zeigt, was bleibt', (t) async {
  final code = await sellVoucherAtRegister(t, 2500);
  // cartCard an die Kassa; pay-voucher; Code tippen
  expect((textOf(t, 'voucher-redeem-balance'), textOf(t, 'voucher-redeem-use'), textOf(t, 'voucher-redeem-left')),
      (contains('25,00'), contains('9,65'), contains('15,35')));
  await t.tap(find.byKey(const Key('voucher-redeem-go'))); await t.pumpAndSettle();
  expect(await queryRows(t, "SELECT kind, amount_cents, voucher_balance_after_cents FROM payments WHERE kind = 'voucher'"),
      [{'kind': 'voucher', 'amount_cents': 965, 'voucher_balance_after_cents': 1535}]);
  expect(printerOf(t).drawerOpened, 0);
  expect(textOf(t, 'voucher-left-0'), contains('15,35'));
});
testWidgets('Guthaben 5 € auf 9,65 €: Reihe am Bon, "Noch zu zahlen 4,65 €", Rest bar mit Rückgeld aus 4,65 €', ...);   // gegeben 5,00 → Rückgeld 0,35
testWidgets('Rest mit Karte und Trinkgeld: Terminal bekommt 4,65 € + Trinkgeld, Zahlungen in der Reihenfolge Gutschein, Karte', ...);
testWidgets('Rest "Teil bar, Rest Karte": Gutschein, bar, Karte', ...);
testWidgets('zwei Gutscheine nacheinander; × nimmt einen wieder weg', ...);
testWidgets('Bon wird kleiner als die gewählten Gutscheine: "Mit Gutschein abschließen", der zweite Gutschein wird nicht belastet', ...);
testWidgets('Bon mit Gutschein-Zeile hat keine Taste pay-voucher; Summe 0 und Summe unter 0 auch nicht', ...);
testWidgets('Meldungen: unbekannt, aufgebraucht, storniert, liegt schon am Bon, Übungs-Gutschein', ...);
testWidgets('Guthaben ändert sich zwischen Einlösen und Bar: nichts gespeichert, Hinweis, der Bon zeigt das neue Guthaben', ...);   // Review Focus 2: Bewegung direkt in die Datenbank
testWidgets('Guthaben reicht vor der Karte nicht mehr: das Terminal wird nicht gerufen', ...);
testWidgets('Neustart mit gewähltem Gutschein: er liegt wieder am Bon, mit frischem Guthaben', ...);
// unclear_card_test.dart
testWidgets('unklare Kartenzahlung nach Gutschein: das Blatt nennt den Gutschein-Teil; bestätigt entsteht der Bon mit Gutschein und Karte, auch wenn das Guthaben inzwischen 0 ist (überzogen)', ...);
testWidgets('unklare Kartenzahlung verworfen: der Bon liegt wieder an der Kassa, mit dem Gutschein', ...);
// card_payment_repository_test.dart
test('die offene Zahlung trägt die gewählten Gutscheine in cartJson und den Betrag nach Gutschein', ...);
```

- [ ] **Step 2: Laufen lassen, sie scheitern**

Run: `cd app && ~/flutter/bin/flutter test test/features/voucher_redeem_test.dart`
Expected: FAIL (`pay-voucher` gibt es nicht).

- [ ] **Step 3: Umsetzen.**

- [ ] **Step 4: Laufen lassen, alles grün**

Run: `cd app && ~/flutter/bin/flutter test test/features/voucher_redeem_test.dart test/features/voucher_sale_test.dart test/features/cash_test.dart test/features/card_test.dart test/features/split_payment_test.dart test/features/tip_test.dart test/features/unclear_card_test.dart test/features/sale_service_test.dart test/features/kassa_card_outage_test.dart test/data/card_payment_repository_test.dart test/features/stufe_1a_off_test.dart test/features/stufe_1b_off_test.dart test/golden/cash_golden_test.dart test/golden/card_golden_test.dart test/l10n_review_test.dart && ~/flutter/bin/flutter analyze`
Expected: PASS, kein Golden geändert.

- [ ] **Step 5: Commit** `Stufe 1b Task 11: Gutschein einlösen`.

### Task 12: Rechnung an Firma am Tablet

Spec 5.3.

**Files:**
- Create: `app/lib/domain/customer.dart`, `app/lib/data/customer_repository.dart`, `app/lib/features/customers/customer_picker.dart`, `app/lib/features/customers/customer_form.dart`, `app/test/domain/customer_test.dart`, `app/test/data/customer_repository_test.dart`, `app/test/features/invoice_test.dart`
- Modify: `app/lib/domain/receipt_layout.dart`, `app/lib/devices/printer.dart` und die Test-Drucker, `app/lib/data/providers.dart`, `app/lib/features/kassa/{sale_service,sale_done}.dart`, `app/lib/features/bons/receipt_detail.dart`, `app/lib/l10n/app_*.arb`, `app/test/no_text_field_test.dart` (nur die Liste `_allowed`)
- Test: die neuen Dateien, `app/test/domain/receipt_layout_test.dart`, `app/test/no_text_field_test.dart`

**Interfaces:**
- Consumes: `CustomerRows`, `ReceiptRecipientRows` (Task 1), `RegisterSettings.invoiceEnabled`.
- Produces:

```dart
// domain/customer.dart
const invoiceHintAboveCents = 40000;            // über 400,00 €
const invoiceVatIdRequiredAboveCents = 1000000; // über 10.000,00 €
const customerTextMax = 80;                     // Name und jede Adress-Zeile
const customerVatIdMax = 20;
class Customer { id, name, addressLine1, addressLine2, vatId, archived, updatedAt, lastUsedAt }
class ReceiptRecipient { receiptId, version, customerId, name, addressLine1, addressLine2, vatId, createdAt, staffId, staffName }
enum RecipientProblem { nameMissing, addressMissing, vatIdMissing, tooLong }
Set<RecipientProblem> checkRecipient({required String name, required String addressLine1, required String addressLine2,
    required String vatId, required int receiptTotalCents});
String invoiceNumber(Receipt r);                // 'KASSA-1 / 1042'; ohne Kassen-ID nur '1042'

// data/customer_repository.dart
class CustomerRepository {
  Future<List<Customer>> list({String? initial});       // nicht archiviert; zuletzt verwendete oben, dann nach Name; initial: erster Buchstabe, groß
  Future<List<String>> initials();                      // die Anfangsbuchstaben, die vorkommen, sortiert
  Future<Customer> save({String? id, required String name, required String addressLine1, required String addressLine2, String? vatId});
  Future<ReceiptRecipient> setRecipient({required String receiptId, String? customerId, required String name,
      required String addressLine1, required String addressLine2, String? vatId, required Staff staff});
  Future<ReceiptRecipient?> recipientOf(String receiptId);   // die letzte Fassung
}
// domain/receipt_layout.dart: layoutReceipt bekommt `ReceiptRecipient? recipient`
// devices/printer.dart: printReceipt bekommt `ReceiptRecipient? recipient`
// features/kassa/sale_service.dart
Future<PrintOutcome> printInvoice(Receipt receipt, ReceiptRecipient recipient);
```

Regeln:
- `checkRecipient`: Name leer → `nameMissing`; eine der zwei Adress-Zeilen leer → `addressMissing`; UID leer und `receiptTotalCents > invoiceVatIdRequiredAboveCents` → `vatIdMissing`; ein Feld über der Grenze → `tooLong`. Alles wird vorn und hinten von Leerzeichen befreit.
- `save` schreibt den Kunden mit `updatedAt` und trägt **selbst** einen Eintrag `customer` (ref = Kennung) in die Liste "noch zu senden" ein, im selben Datenbank-Schritt. `setRecipient` vergibt `version` = höchste Fassung + 1 (erste ist 0), setzt bei einem Firmenkunden `lastUsedAt` (das zählt nicht als Änderung, kein Eintrag `customer`) speichert eine Kopie von Name, Adresse und UID und trägt selbst einen Eintrag `recipient` (ref = `<receiptId>/<version>`) in "noch zu senden" ein, im selben Datenbank-Schritt. Der Bon und seine Signatur ändern sich nicht (der Test vergleicht die Zeile in `receipts` und das Protokoll vorher und nachher).
- Taste `invoice-button` ("Rechnung an Firma") auf "Verkauf fertig" und im Detail eines Bons, wenn `invoiceEnabled`. Sie fehlt bei einem Storno-Bon, bei einem stornierten Bon, bei Sonderbelegen und bei einem Bon mit dem Vermerk TESTBON (dieselbe Regel wie in `layoutReceipt`). Hat der Bon schon einen Empfänger, steht dort `invoice-recipient` (Name) mit `invoice-print` ("Rechnung drucken") und `invoice-change` ("Ändern").
- `customer-picker` (Blatt): Reihen `customer-row-<id>` (Name, erste Adress-Zeile), darüber die Tasten `customer-initial-<X>` für `initials()` und `customer-initial-all`; `customer-new` ("Neuer Kunde"). Ein Tipp auf eine Reihe zeigt den Kunden mit `invoice-print`.
- `customer-form` (eigene Seite über die ganze Breite, damit die Tastatur Platz hat): Felder `customer-name`, `customer-address1`, `customer-address2`, `customer-vat`, Schalter `customer-keep` ("Als Firmenkunde speichern", an), `customer-save` ("Übernehmen"), `customer-cancel`. "Übernehmen" ist grau, solange `checkRecipient` etwas findet; unter dem Feld steht der Grund. Mit `customer-keep` aus entsteht kein Firmenkunde, nur der Empfänger (`customerId` leer). "Ändern" öffnet das Formular mit den Werten der letzten Fassung; gespeichert wird eine neue Fassung, die alte bleibt.
- `test/no_text_field_test.dart`: Die Liste `_allowed` bekommt genau `lib/features/customers/customer_form.dart` (genannte Änderung einer vorhandenen Erwartung). Wird die Änderung abgelehnt: HARD STOP, kein Ausweichen auf ein anderes Widget.
- **Ausdruck:** `layoutReceipt` mit `recipient`: nach dem Kopf des Betriebs "RECHNUNG" fett und mittig, darunter "Rechnung Nr. ${invoiceNumber(r)}", dann "An:" und eingerückt Name, zwei Adress-Zeilen und, falls vorhanden, "UID …"; der Rest ist der Bon, wie er ist (gleiche Nummer, gleicher QR-Code). Ohne `recipient` ist jede Zeile wie bisher.
- **Hinweis:** `invoice-hint` auf "Verkauf fertig" mit `invoiceHint400`, wenn `invoiceEnabled`, die Summe über `invoiceHintAboveCents` liegt und der Bon noch keinen Empfänger hat.
- ARB: `invoiceButton` "Rechnung an Firma", `invoicePrint` "Rechnung drucken", `invoiceChange` "Ändern", `invoiceHint400` "Über 400 €: Eine Rechnung braucht Name und Adresse des Kunden.", `customerPickerTitle` "Firmenkunde wählen", `customerAll` "Alle", `customerNew` "Neuer Kunde", `customerName` "Name der Firma", `customerAddress1` "Straße und Hausnummer", `customerAddress2` "PLZ und Ort", `customerVatId` "UID (wenn vorhanden)", `customerKeep` "Als Firmenkunde speichern", `customerSave` "Übernehmen", `customerNameMissing` "Bitte den Namen eintragen.", `customerAddressMissing` "Bitte die Adresse eintragen.", `customerVatIdMissing` "Über 10.000 € braucht die Rechnung die UID des Kunden.", `customerTooLong` "Der Text ist zu lang.", `customerEmpty` "Noch kein Firmenkunde gespeichert."

- [ ] **Step 1: Die Tests schreiben, die scheitern**

```dart
// customer_test.dart
test('checkRecipient: Pflichtfelder, UID erst über 10.000 €, Längen', () {
  Set<RecipientProblem> c({String n = 'Muster GmbH', String a1 = 'Musterweg 1', String a2 = '1010 Wien', String v = '', int total = 1820}) =>
      checkRecipient(name: n, addressLine1: a1, addressLine2: a2, vatId: v, receiptTotalCents: total);
  expect(c(), isEmpty);
  expect(c(n: '  '), {RecipientProblem.nameMissing});
  expect(c(a2: ''), {RecipientProblem.addressMissing});
  expect(c(total: 1000000), isEmpty);
  expect(c(total: 1000001), {RecipientProblem.vatIdMissing});
  expect(c(total: 1000001, v: 'ATU00000000'), isEmpty);
  expect(c(n: 'x' * 81), {RecipientProblem.tooLong});
});
// customer_repository_test.dart
test('save trägt den Kunden in die Liste "noch zu senden" ein; setRecipient zählt Fassungen und ändert den Bon nicht', ...);
test('list: zuletzt verwendete oben, dann nach Name; initial filtert; archivierte fehlen', ...);
// receipt_layout_test.dart
test('Rechnung: RECHNUNG, Rechnung Nr. KASSA-1 / 1042, An: mit Name, Adresse und UID; ohne Empfänger ist der Bon Zeile für Zeile wie vorher', ...);
// invoice_test.dart
testWidgets('Verkauf fertig: Rechnung an Firma, Neuer Kunde, drucken: Empfänger gespeichert, Ausdruck trägt RECHNUNG und den Namen', (t) async {
  // setSettings(invoiceEnabled: true); bar verkaufen; invoice-button; customer-new; Felder füllen; customer-save; invoice-print
  expect(await queryRows(t, 'SELECT version, name, address_line1, address_line2, customer_id IS NOT NULL AS kept FROM receipt_recipients'),
      [{'version': 0, 'name': 'Muster GmbH', 'address_line1': 'Musterweg 1', 'address_line2': '1010 Wien', 'kept': 1}]);
  expect(printerOf(t).lastText, allOf(contains('RECHNUNG'), contains('Muster GmbH')));
});
testWidgets('gespeicherten Kunden wählen: ein Tipp, kein Formular; Anfangsbuchstabe filtert', ...);
testWidgets('"Als Firmenkunde speichern" aus: Empfänger ohne Firmenkunde', ...);
testWidgets('Ändern: zweite Fassung, die erste bleibt, gedruckt wird die letzte', ...);
testWidgets('im Detail eines Bons; fehlt bei Storno, storniertem Bon, Testbon und bei Schalter aus', ...);
testWidgets('Summe über 400 €: Hinweis auf Verkauf fertig, weg sobald ein Empfänger da ist', ...);
```

- [ ] **Step 2: Laufen lassen, sie scheitern**

Run: `cd app && ~/flutter/bin/flutter test test/domain/customer_test.dart test/features/invoice_test.dart`
Expected: FAIL.

- [ ] **Step 3: Umsetzen.** Das Formular bleibt über der Tastatur sichtbar (scrollt, achtet auf `viewInsets`), "Weiter" auf der Tastatur springt ins nächste Feld.

- [ ] **Step 4: Laufen lassen, alles grün**

Run: `cd app && ~/flutter/bin/flutter test test/domain/customer_test.dart test/domain/receipt_layout_test.dart test/data/customer_repository_test.dart test/features/invoice_test.dart test/features/bons_test.dart test/no_text_field_test.dart test/devices/printer_test.dart test/features/stufe_1b_off_test.dart test/l10n_review_test.dart && ~/flutter/bin/flutter analyze`
Expected: PASS.

- [ ] **Step 5: Commit** `Stufe 1b Task 12: Rechnung an Firma am Tablet`.

### Task 13: Firmenkunden und Rechnungsempfänger am Server, im Browser und zurück aufs Tablet

Spec 5.3 (Abgleich, Browser).

**Files:**
- Create: `server/src/device/push_customer.ts`, `server/src/device/push_recipient.ts`, `server/src/admin/customers.ts`, `server/test/push_customer.test.ts`, `server/test/customers.test.ts`, `web/src/api/customers.ts`, `web/src/pages/CustomersPage.tsx` (+ `.module.css`), `web/src/pages/customers.test.ts`
- Modify: `server/src/device/{push,pull}.ts`, `server/src/admin/receipts.ts`, `server/src/app.ts`, `app/lib/sync/{push_wire,wire,server_changes,sync_service}.dart`, `app/lib/data/customer_repository.dart`, `web/src/routes.tsx`, `web/src/pages/{BusinessLayout,ReceiptDetail}.tsx`, `web/src/api/receipts.ts`
- Test: die neuen Dateien, `server/test/{pull,receipts}.test.ts`, `app/test/sync/{push_wire,server_changes}_test.dart`

**Interfaces:**
- Consumes: die Tabellen `customers` und `receipt_recipients` aus `0005` (Task 5), `CustomerRepository` (Task 12), die Einträge `customer` und `recipient` in der Liste "noch zu senden" (Task 12), `SyncStateRows.catchUpPending` (Task 1).
- Produces:

```jsonc
// Einträge des Tablets (neben "receipt", "report", "item_change", …)
{"seq": 7, "kind": "customer",  "id": "<uuid>", "name": "Muster GmbH", "addressLine1": "Musterweg 1", "addressLine2": "1010 Wien",
                                "vatId": "ATU00000000" | null, "archived": false, "updatedAt": "2026-11-27T11:03:00Z"}
{"seq": 8, "kind": "recipient", "receiptId": "<uuid>", "version": 0, "customerId": "<uuid>" | null, "name": …, "addressLine1": …,
                                "addressLine2": …, "vatId": … | null, "createdAt": …, "staffId": …, "staffName": …}
// Abholen: neue Liste "customers": [{"id", "name", "addressLine1", "addressLine2", "vatId", "archived"}]
// Verwaltung
GET   /api/admin/businesses/:b/customers            → {"customers": [{id, name, addressLine1, addressLine2, vatId, archived, updatedAt}]}
POST  /api/admin/businesses/:b/customers            (Rollen wie bei den Mitarbeitern)
PATCH /api/admin/businesses/:b/customers/:id        (Felder und `archived`)
GET   /api/admin/businesses/:b/receipts/:id         bekommt "recipient": {name, addressLine1, addressLine2, vatId, version, createdAt, staffName} | null
```

Regeln:
- `customer`: anlegen oder ändern; die Fassung mit dem neueren `updatedAt` gewinnt, eine ältere ist `duplicate`. Jede Änderung zählt `change_seq` weiter. `customer` kommt in `WRITE_KINDS`.
- `recipient`: anfügen; dieselbe (`receiptId`, `version`) noch einmal ist `duplicate`; kennt der Server den Bon nicht, ist es `invalid`. Die Felder werden wie am Tablet geprüft (Pflicht, Längen), sonst `invalid`.
- Abholen: `customers` zählt in derselben Reihe von Änderungs-Nummern wie die Artikel. Die Antwort trägt die Liste `customers` nur, wenn sie nicht leer ist (in Task 16 gilt dasselbe für `vouchers` und `voucherMovements`); so bleiben `pull.test.ts` und die Dateien `pull_full.json` und `pull_delta.json` unverändert. Ein Tablet mit 1.10.0 oder 1.11.0 überliest die neue Liste (der Test liest die Antwort mit dem Schema von 1.11.0: die bekannten Listen sind unverändert).
- **Nachholen nach dem Update:** Ist `catchUpPending` wahr, holt `SyncService` vor dem normalen Abholen einmal alle Seiten ab `since = 0` bis zum eigenen `pullCursor` und gibt sie an `ServerChanges.applyCatchUp(PullResponse page)`. Das spielt nur die neuen Listen ein (hier `customers`, ab Task 16 auch Gutscheine und Bewegungen), fasst Artikel, Kategorien, Mitarbeiter und `pullCursor` nicht an und lässt sich gefahrlos wiederholen. Nach der letzten Seite setzt `ServerChanges.finishCatchUp()` `catchUpPending` auf falsch; bricht der Lauf ab, bleibt es wahr und der nächste Abgleich beginnt wieder bei 0. Das erste Laden nach dem Koppeln (`replaceAll`) spielt die neuen Listen selbst ein.
- Tablet: `PullResponse.customers` ist leer, wenn die Liste fehlt. `ServerChanges` schreibt Kunden über `CustomerRepository.applyServer(List<WireCustomer>)`: anlegen oder ändern, **ohne** Eintrag in "noch zu senden", `lastUsedAt` bleibt. Wartet für denselben Kunden noch ein eigener Eintrag `customer`, bleibt die Fassung des Tablets stehen.
- Browser: Seite "Firmenkunden" unter `/b/:b/firmenkunden` (Eintrag in der Navigation nach "Mitarbeiter"): Liste, anlegen, ändern, archivieren, mit denselben Pflichtfeldern und Längen; Muster `StaffPage`. `ReceiptDetail` zeigt "Rechnung an" mit Name, Adresse, UID.

- [ ] **Step 1: Die Tests schreiben, die scheitern**

```ts
// push_customer.test.ts
test('customer: angelegt, geändert mit neuerem updatedAt, ältere Fassung ist duplicate; change_seq steigt', ...);
test('recipient: angefügt, noch einmal ist duplicate, unbekannter Bon und fehlender Name sind invalid; receipts bleibt unverändert', ...);
// pull.test.ts
test('customers kommen beim Abholen, archivierte mit archived true; die Antwort passt weiter zum Schema von 1.11.0', ...);
// customers.test.ts
test('Verwaltung: anlegen, ändern, archivieren; ein anderer Betrieb sieht nichts; ohne Anmeldung 401', ...);
// receipts.test.ts
test('das Detail trägt den letzten Empfänger', ...);
```
```dart
// push_wire_test.dart
test('Einträge customer und recipient gehen in der Form oben hinaus', ...);
// server_changes_test.dart
test('Kunden vom Server: angelegt und geändert ohne Eintrag in "noch zu senden"; ein eigener, noch nicht gesendeter Kunde bleibt', ...);
test('Nachholen: mit catchUpPending kommt ein Kunde mit Änderungs-Nummer unter dem eigenen pullCursor an; pullCursor und Artikel bleiben; danach ist catchUpPending falsch; ein Abbruch mittendrin lässt es wahr', ...);   // sync_service_test.dart
```

- [ ] **Step 2: Laufen lassen, sie scheitern**

Run: `cd server && npx vitest run test/push_customer.test.ts test/customers.test.ts`
Expected: FAIL.

- [ ] **Step 3: Umsetzen.**

- [ ] **Step 4: Laufen lassen, alles grün**

Run: `cd server && npx vitest run test/push_customer.test.ts test/customers.test.ts test/pull.test.ts test/receipts.test.ts test/push.test.ts && npm run typecheck`; `cd web && npm test && npm run typecheck`; `cd app && ~/flutter/bin/flutter test test/sync/ test/data/customer_repository_test.dart && ~/flutter/bin/flutter analyze`
Expected: PASS.

- [ ] **Step 5: Commit** `Stufe 1b Task 13: Firmenkunden und Empfänger am Server und im Browser`.

### Task 14: Digitaler Beleg am Server: die Seite eines Bons

Spec 5.4 (Die Seite), 7 (öffentliche Seite). Review Focus 4.

**Files:**
- Create: `server/src/public/receipt_page.ts`, `server/src/public/qr.ts`, `server/src/device/push_delivery.ts`, `server/test/receipt_page.test.ts`, `server/test/push_delivery.test.ts`, `shared/fixtures/rksv/qr_text.json`
- Modify: `server/src/app.ts`, `server/src/device/push.ts`, `server/src/admin/receipts.ts`, `server/package.json` (Abhängigkeit `qrcode` und `@types/qrcode`), `web/src/pages/ReceiptDetail.tsx`, `web/src/api/receipts.ts`, `app/test/rksv/core/rksv_code_test.dart` (liest `qr_text.json` mit)
- Test: die neuen Dateien, `server/test/receipts.test.ts`, `server/test/web.test.ts`

**Interfaces:**
- Consumes: `receipt_links`, `receipt_deliveries` (Task 5), der Empfänger (Task 13), `SlidingWindow` (`rate_limit.ts`), `clientAddress` (`client_address.ts`).
- Produces:

```ts
// GET /beleg/:token  → 200 text/html (der Bon) | 404 text/html (immer dieselbe Seite) | 429 text/html
// server/src/public/receipt_page.ts
export function installReceiptPage(app: FastifyInstance): void;
export function renderReceiptPage(view: ReceiptPageView): string;      // reines HTML, alles durch esc()
// server/src/public/qr.ts
export function rksvQrText(jws: string): string;                       // derselbe Text wie app/lib/rksv/core/rksv_code.dart
export function qrSvg(text: string): Promise<string>;                  // <svg …>, schwarz auf weiß, mit Ruhezone
// Eintrag des Tablets
{"seq": 9, "kind": "delivery", "receiptId": "<uuid>", "deliveryKind": "printed" | "digital", "at": "2026-11-27T11:03:05Z"}
// GET /api/admin/businesses/:b/receipts/:id bekommt "deliveries": [{"kind": "printed", "at": …}], "pageUrl": "/beleg/<token>" | null
```

Regeln:
- Ein Schlüssel hat genau 22 Zeichen aus `A–Z a–z 0–9 - _`. Alles andere (leer, länger, Sonderzeichen, Schrägstrich) und jeder unbekannte Schlüssel bekommt dieselbe Antwort: 404 mit einer festen Seite "Diesen Bon gibt es nicht." Die Antwort hängt nicht davon ab, ob der Schlüssel fast stimmt oder zu einem anderen Betrieb gehört.
- Bremse: Je Adresse zählen nur Fehlversuche. Nach 10 Fehlversuchen in 10 Minuten bekommt die Adresse für den Rest des Fensters auf jede Anfrage 429 mit einer festen Seite, auch auf richtige Schlüssel.
- Kopfzeilen jeder Antwort unter `/beleg/`: `Cache-Control: no-store`, `X-Robots-Tag: noindex, nofollow`, `Referrer-Policy: no-referrer`, `Content-Security-Policy: default-src 'none'; style-src 'unsafe-inline'; img-src data:`, kein `Set-Cookie`. `/robots.txt` sperrt `/beleg/`. Die Seite lädt nichts nach (kein Skript, keine Schrift, kein Bild von außen).
- Die Seite sucht in `receipt_links` (ohne Betrieb), liest dann den Bon im Betrieb des Treffers und zeigt, Deutsch und in dieser Reihenfolge: Name, Adresse und UID des Betriebs; bei einem Storno-Bon "STORNO"; bei einem stornierten Bon "Storniert am <Datum>"; bei einem Empfänger "RECHNUNG", die Rechnungsnummer und "An: …" (letzte Fassung); Bon-Nummer, Datum, Kassen-ID; die Zeilen mit Auswahl und Rabatt; Zwischensumme und Bon-Rabatt; Pfand und "Pfand zurück"; Summe; Steuer je Satz; Zahlungen (Karte mit Art und letzten vier Ziffern; Gutschein als "Gutschein •••• 5678" mit Betrag und Restguthaben; die Zeile eines verkauften Gutscheins als "Gutschein" mit "Code •••• 5678"); den QR-Code der Signatur als SVG; den Schlusstext des Betriebs; bei `is_test` "TESTBON, keine gültige Rechnung". Beträge wie am Papier (`1.234,50`).
- Jeder Text aus der Datenbank geht durch `esc()`. Die Seite passt auf 320 px Breite, folgt hell und dunkel des Geräts, und druckt sauber (`@media print`). Farben aus `web/src/styles/tokens.css` als feste Werte in der Seite.
- `rksvQrText` rechnet wie `rksv_code.dart`; beide Seiten prüfen gegen `shared/fixtures/rksv/qr_text.json` (drei Paare aus JWS und QR-Text, mit dem Code des Tablets erzeugt; Schlüssel und Zertifikate darin sind die der Tests).
- Eintrag `delivery`: anfügen; dieselbe (`receiptId`, `deliveryKind`) noch einmal ist `duplicate`; unbekannter Bon ist `invalid`. Der Bon bleibt unverändert.
- Browser, `ReceiptDetail`: Zeile "Beleg" mit "Gedruckt 12:03" und "Digital angeboten 12:03", und ein Link "Seite des Bons" auf `pageUrl`.

- [ ] **Step 1: Die Tests schreiben, die scheitern**

```ts
// receipt_page.test.ts
test('richtiger Schlüssel: 200, die Seite trägt Betrieb, Zeilen, Summe 18,20, Steuer je Satz, Zahlung und ein <svg>', ...);
test('unbekannt, leer, zu lang, mit Sonderzeichen, Schlüssel plus ein Zeichen: immer 404 mit demselben Text und denselben Kopfzeilen', async () => {
  const bodies = new Set<string>();
  for (const t of ['A'.repeat(22), '', 'A'.repeat(23), 'A'.repeat(500), '../../etc/passwd', '%00', token + 'x', token.slice(0, 21)]) {
    const r = await app.inject({ method: 'GET', url: `/beleg/${encodeURIComponent(t)}` });
    expect(r.statusCode).toBe(404);
    bodies.add(r.body);
  }
  expect(bodies.size).toBe(1);
});
test('keine Cookies, no-store, noindex, CSP ohne Skript; robots.txt sperrt /beleg/', ...);
test('zwei Betriebe: der Schlüssel von Betrieb A zeigt nie eine Zeile von Betrieb B', ...);
test('Artikelname "<script>alert(1)</script>" steht als Text auf der Seite, nicht als Element', ...);
test('Storno: der stornierte Bon sagt "Storniert am", der Storno-Bon sagt STORNO', ...);
test('Rechnung: Empfänger der letzten Fassung und Rechnungsnummer; Testbon trägt den Vermerk', ...);
test('Gutschein: der Code steht nur mit den letzten vier Ziffern da, bei Zahlung und bei Verkauf', ...);
test('Bon unter 0: Summe -0,75, "Pfand zurück", Bar -0,75', ...);
test('Bremse: 10 Fehlversuche, dann 429 auch für den richtigen Schlüssel; eine andere Adresse ist nicht betroffen; nach dem Fenster geht es wieder', ...);
test('rksvQrText: die Paare aus qr_text.json', ...);
// push_delivery.test.ts
test('delivery: printed und digital angefügt, noch einmal duplicate, unbekannter Bon invalid; das Detail der Verwaltung zeigt beide', ...);
```

- [ ] **Step 2: Laufen lassen, sie scheitern**

Run: `cd server && npx vitest run test/receipt_page.test.ts test/push_delivery.test.ts`
Expected: FAIL (404 von der Verwaltungs-Seite beziehungsweise `invalid`).

- [ ] **Step 3: Umsetzen.** `npm install qrcode @types/qrcode` in `server/`; scheitert das am Netz, ist die Aufgabe `BLOCKED` (kein eigener QR-Code-Rechner). Die Route steht vor dem Ausliefern der Verwaltung, damit `/beleg/…` nie die Verwaltungs-Seite bekommt.

- [ ] **Step 4: Laufen lassen, alles grün**

Run: `cd server && npx vitest run test/receipt_page.test.ts test/push_delivery.test.ts test/receipts.test.ts test/web.test.ts test/push.test.ts && npm run typecheck`; `cd web && npm test && npm run typecheck`; `cd app && ~/flutter/bin/flutter test test/rksv/core/rksv_code_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit** `Stufe 1b Task 14: Seite eines Bons am Server und Belegerteilung`.

### Task 15: Digitaler Beleg am Tablet

Spec 5.4 (An der Kassa). Review Focus 5.

**Files:**
- Create: `app/lib/data/delivery_repository.dart`, `app/lib/features/kassa/receipt_qr.dart`, `app/test/data/delivery_repository_test.dart`, `app/test/features/digital_receipt_test.dart`
- Modify: `app/lib/core/app_info.dart`, `app/lib/data/{outbox_repository,providers}.dart`, `app/lib/sync/push_wire.dart`, `app/lib/features/kassa/{sale_service,sale_done}.dart`, `app/lib/features/bons/receipt_detail.dart`, `app/lib/l10n/app_*.arb`
- Test: die neuen Dateien, `app/test/features/{sale_service,bons}_test.dart`, `app/test/sync/push_wire_test.dart`

**Interfaces:**
- Consumes: `Receipt.publicToken` (Task 4), `ReceiptDeliveryRows` (Task 1), `RegisterSettings.receiptMode`, `serverUrl`/`hasServer`, der Zustand "gekoppelt", der Eintrag `delivery` am Server (Task 14).
- Produces:

```dart
// core/app_info.dart
String? receiptPageUrl(String? publicToken);     // '$serverUrl/beleg/$publicToken'; null ohne Server oder ohne Schlüssel
// data/delivery_repository.dart
enum DeliveryKind { printed, digital }
class ReceiptDelivery { receiptId, kind, at }
class DeliveryRepository {
  Future<void> record(String receiptId, DeliveryKind kind, {required DateTime at});   // schreibt die Zeile und den Eintrag `delivery` in "noch zu senden"; das zweite Mal ändert nichts
  Future<List<ReceiptDelivery>> of(String receiptId);
}
// data/outbox_repository.dart
Stream<bool> watchSent({required String kind, required String ref});   // true, sobald kein Eintrag mehr wartet; ein abgelehnter Eintrag zählt als nicht gesendet
// features/kassa/sale_service.dart
const receiptFallbackDelay = Duration(seconds: 3);
enum ReceiptFallback { none, printed, noPrinter }
ReceiptMode effectiveReceiptMode(RegisterSettings settings, {required bool paired});   // ohne Server oder ohne Kopplung immer alwaysPrint
class SaleResult { final bool autoPrinted; final Stream<ReceiptFallback> fallback; }
Future<PrintOutcome> printNow(Receipt receipt);   // "Bon drucken": derselbe Druck wie sonst von selbst, höchstens einmal zugleich
// features/kassa/receipt_qr.dart
class ReceiptQr extends ConsumerStatefulWidget { const ReceiptQr({super.key, required this.receipt, this.waitForServer = true, this.qrKey = const Key('receipt-qr')}); }
```

Regeln:
- **Belegerteilung festhalten, bei jedem Wert des Schalters:** `printed`, sobald der Kundenbon (auch als Rechnung, auch aus "Bons") das erste Mal ohne Fehler gedruckt ist; `digital`, sobald `ReceiptQr` den QR-Code das erste Mal wirklich zeigt (nicht den Platzhalter). Der Eintrag `delivery` geht in der Form aus Task 14 zum Server.
- **`alwaysPrint`** (und jede Kassa ohne Server oder Kopplung): alles wie in 1.11.0, kein QR-Code, `autoPrinted` wahr.
- **`printAndDigital`:** drucken wie bisher, dazu `ReceiptQr` auf "Verkauf fertig".
- **`digitalOnRequest`:** Der Kundenbon druckt nicht von selbst (`autoPrinted` falsch). Bei einer Bar-Zahlung (auch Auszahlung) öffnet die Kassa die Lade mit `openDrawer()`. Küchenbon und Gutschein-Abschnitte drucken wie immer. "Verkauf fertig" zeigt `ReceiptQr`, darunter `receipt-qr-caption`, und statt des Druck-Zustands die Taste `print-receipt-now` ("Bon drucken"); nach dem Tipp steht dort der Druck-Zustand wie bisher.
- **`ReceiptQr`:** Hat der Bon keinen Schlüssel (Bon aus 1.11.0), zeigt es nichts. Sonst zeigt es `receipt-qr-wait` (ruhiger Platzhalter in derselben Größe), bis `watchSent(kind: 'receipt', ref: receipt.id)` wahr ist, dann den QR-Code von `receiptPageUrl` (mindestens 200 dp, schwarz auf weiß in hell und dunkel, mit Ruhezone). Mit `waitForServer: false` zeigt es ihn sofort.
- **Ohne Internet:** Bei `digitalOnRequest` startet `SaleService` beim Abschließen eine Uhr über `receiptFallbackDelay`. Ist der Bon dann nicht gesendet und wurde für ihn noch kein Druck gestartet: mit Drucker druckt die Kassa den Bon genau einmal und meldet `ReceiptFallback.printed`; ohne Drucker meldet sie `noPrinter`. Die Uhr gehört dem `SaleService`, nicht dem Bildschirm: Sie läuft weiter, wenn schon "Nächster Kunde" getippt ist. Kommt die Bestätigung später, druckt nichts noch einmal. "Verkauf fertig" zeigt bei `printed` `receipt-offline-note` mit `kassaReceiptOfflinePrinted` und den Druck-Zustand, bei `noPrinter` `kassaReceiptOfflineLater` und den QR-Code trotzdem (`waitForServer: false`).
- **Bons, Detail:** Zeile "Beleg" mit `detail-delivery-printed` und `detail-delivery-digital` (Zeit), immer wenn es Einträge gibt. `detail-receipt-qr` nur, wenn `effectiveReceiptMode` ein digitaler Wert ist und der Bon einen Schlüssel hat. `print-receipt` bleibt, wie es ist.
- ARB: `kassaReceiptQrCaption` "Bon mit dem Handy mitnehmen", `kassaPrintReceiptNow` "Bon drucken", `kassaReceiptOfflinePrinted` "Kein Internet, Bon wird gedruckt.", `kassaReceiptOfflineLater` "Kein Internet: Der digitale Bon ist erst später abrufbar.", `bonsDeliveryTitle` "Beleg", `bonsDeliveryPrinted` "Gedruckt", `bonsDeliveryDigital` "Digital angeboten".

- [ ] **Step 1: Die Tests schreiben, die scheitern**

```dart
// delivery_repository_test.dart
test('record schreibt je Bon und Art einen Eintrag, das zweite Mal nichts; der Eintrag steht in "noch zu senden"', ...);
// digital_receipt_test.dart (Helfer: `pairRegister(t)`, `serverConfirms(t, receiptId)` nimmt den Eintrag aus "noch zu senden")
testWidgets('immer drucken, gekoppelt: kein QR-Code, Druck wie bisher, "gedruckt" festgehalten', ...);
testWidgets('digital gewählt, aber nicht gekoppelt: wie immer drucken', ...);
testWidgets('drucken und digital: Druck und QR-Code; "gedruckt" und "digital" festgehalten', ...);
testWidgets('digital und Druck auf Wunsch, Server bestätigt: Platzhalter, dann QR-Code mit der Adresse des Bons; kein Druck; Lade offen bei Bar; Küchenbon gedruckt', (t) async {
  // setSettings(receiptMode: digitalOnRequest); pairRegister; bar verkaufen
  expect(find.byKey(const Key('receipt-qr-wait')), findsOneWidget);
  await serverConfirms(t, lastReceiptId(t)); await t.pump();
  expect(qrTextOf(t, 'receipt-qr'), endsWith('/beleg/${lastReceipt(t).publicToken}'));
  expect(printerOf(t).printed.where((p) => p.kind == 'receipt'), isEmpty);
  expect(printerOf(t).drawerOpened, 1);
  expect(await queryRows(t, 'SELECT kind FROM receipt_deliveries'), [{'kind': 'digital'}]);
});
testWidgets('"Bon drucken" druckt einmal und hält "gedruckt" fest', ...);
testWidgets('kein Internet: nach 3 Sekunden druckt die Kassa von selbst, genau einmal, mit Hinweis; späte Bestätigung druckt nichts mehr', (t) async {
  // verkaufen, keine Bestätigung
  await t.pump(const Duration(seconds: 2)); expect(printerOf(t).printed.where((p) => p.kind == 'receipt'), isEmpty);
  await t.pump(const Duration(seconds: 1)); await t.pump();
  expect(printerOf(t).printed.where((p) => p.kind == 'receipt'), hasLength(1));
  expect(find.byKey(const Key('receipt-offline-note')), findsOneWidget);
  await serverConfirms(t, lastReceiptId(t)); await t.pump(const Duration(seconds: 5));
  expect(printerOf(t).printed.where((p) => p.kind == 'receipt'), hasLength(1));
});
testWidgets('kein Internet und schon "Nächster Kunde" getippt: der Bon druckt trotzdem nach 3 Sekunden, genau einmal', ...);
testWidgets('kein Internet, "Bon drucken" nach 1 Sekunde getippt: ein Druck, nicht zwei', ...);
testWidgets('kein Internet, kein Drucker: Hinweis "erst später abrufbar", der QR-Code steht trotzdem da', ...);
testWidgets('Karte, nur Gutschein, Auszahlung und Abschließen bei 0: dieselbe Regel für den Kundenbon', ...);
// bons_test.dart
testWidgets('Detail: Zeile Beleg mit den Zeiten; QR-Code nur bei digitalem Wert; ein Bon ohne Schlüssel hat keinen', ...);
```

- [ ] **Step 2: Laufen lassen, sie scheitern**

Run: `cd app && ~/flutter/bin/flutter test test/features/digital_receipt_test.dart`
Expected: FAIL.

- [ ] **Step 3: Umsetzen.** Alle Wege zum Kundenbon (`completeCash`, `completeFree`, `completePayout`, `completeVoucher`, Karte, bestätigte unklare Zahlung) gehen durch eine gemeinsame Stelle in `SaleService`, die nach `effectiveReceiptMode` entscheidet.

- [ ] **Step 4: Laufen lassen, alles grün**

Run: `cd app && ~/flutter/bin/flutter test test/data/delivery_repository_test.dart test/features/digital_receipt_test.dart test/features/sale_service_test.dart test/features/bons_test.dart test/features/cash_test.dart test/features/card_test.dart test/features/unclear_card_test.dart test/features/voucher_sale_test.dart test/features/voucher_redeem_test.dart test/features/deposit_return_test.dart test/features/invoice_test.dart test/sync/push_wire_test.dart test/features/stufe_1a_off_test.dart test/features/stufe_1b_off_test.dart test/l10n_review_test.dart && ~/flutter/bin/flutter analyze`
Expected: PASS, kein Golden geändert.

- [ ] **Step 5: Commit** `Stufe 1b Task 15: Digitaler Beleg am Tablet`.

### Task 16: Gutscheine zwischen Server und Tablets, Seite "Gutscheine" im Browser

Spec 5.5 (Mehrere Kassen, Browser), 5.7 (Offene Gutscheine am Monatsende).

**Files:**
- Create: `server/src/admin/vouchers.ts`, `server/test/vouchers.test.ts`, `shared/fixtures/vouchers/states.json`, `web/src/api/vouchers.ts`, `web/src/pages/VouchersPage.tsx` (+ `.module.css`), `web/src/pages/vouchers.test.ts`
- Modify: `server/src/device/pull.ts`, `server/src/admin/months.ts`, `server/src/app.ts`, `app/lib/sync/{wire,server_changes,sync_service}.dart`, `app/lib/data/voucher_repository.dart`, `web/src/routes.tsx`, `web/src/pages/{BusinessLayout,PeriodDetail}.tsx`, `web/src/api/months.ts`
- Test: die neuen Dateien, `server/test/{pull,months}.test.ts`, `app/test/sync/server_changes_test.dart`, `app/test/data/voucher_repository_test.dart`, `app/test/domain/voucher_test.dart`, `app/test/features/voucher_redeem_test.dart`

**Interfaces:**
- Consumes: `vouchers`, `voucher_movements` mit `change_seq` (Task 5), `Voucher`, `VoucherState` (Task 3), `CartController.refreshVouchers` (Task 11), `VoucherCodeEntry` (Task 10).
- Produces:

```jsonc
// Abholen: zwei neue Listen
"vouchers":         [{"id": "<uuid>", "code": "12345678", "valueCents": 2500, "createdAt": …, "isTest": false, "soldReceiptId": "<uuid>"}],
"voucherMovements": [{"voucherId": "<uuid>", "receiptId": "<uuid>", "kind": "sale" | "redeem" | "void_sale" | "void_redeem", "amountCents": 2500, "createdAt": …}]
// Verwaltung
GET /api/admin/businesses/:b/vouchers        → {"openCents": 4035, "vouchers": [{id, code, createdAt, valueCents, balanceCents, state, isTest}]}
GET /api/admin/businesses/:b/vouchers/:id    → dazu "movements": [{kind, amountCents, createdAt, receiptId, receiptNumber, registerName}]
// Monat und Zeitraum (months.ts) bekommen "openVoucherCents"
```
```dart
// data/voucher_repository.dart
Future<bool> mergeFromServer(List<WireVoucher> vouchers, List<WireVoucherMovement> movements);   // true, wenn etwas Neues dabei war
```

Regeln:
- Der Server schickt jeden Gutschein und jede Bewegung des Betriebs an jedes Tablet, auch an das, von dem sie kommen. Der Gutschein hat immer eine kleinere Änderungs-Nummer als seine erste Bewegung. 1.10.0 und 1.11.0 überlesen die Listen.
- Nachholen nach dem Update: `applyCatchUp` (Task 13) spielt ab jetzt auch `vouchers` und `voucherMovements` ein (Test: ein Gutschein mit Änderungs-Nummer unter dem eigenen `pullCursor` ist nach dem Nachholen bekannt).
- Tablet: `mergeFromServer` fügt an, was es noch nicht kennt (Gutschein nach Kennung, Bewegung nach Gutschein und Bon), und ändert nichts Vorhandenes. Danach ruft `ServerChanges` `refreshVouchers`, wenn etwas Neues dabei war. Das Guthaben ist weiter die Summe aller bekannten Bewegungen.
- Zwei Gutscheine mit demselben Code (einer von hier, einer vom Server): `findByCode` gibt beide, `VoucherCodeEntry` lässt wählen (gebaut in Task 10, hier mit echtem Abgleich geprüft).
- Zustand am Server nach derselben Regel wie am Tablet; beide prüfen gegen `shared/fixtures/vouchers/states.json` (Bewegungen → Guthaben und Zustand: gültig, aufgebraucht, storniert, überzogen, storniert und anderswo eingelöst = überzogen).
- `openCents` und `openVoucherCents`: Summe der Guthaben über 0 aller echten Gutscheine (`is_test` falsch); für einen Monat zählen nur Bewegungen bis zum Ende des Monats (Zeitzone des Betriebs wie in `months.ts`). Übungs-Gutscheine stehen in keiner Summe.
- Browser: Seite "Gutscheine" unter `/b/:b/gutscheine` (Navigation nach "Bons"): oben "Offene Gutscheine" mit `openCents`; Liste mit Code ("1234 5678"), Datum, Wert, Guthaben, Zustand; "Überzogen" fällt auf (Farbe aus den Tokens, dazu das Wort); Übungs-Gutscheine in einem eigenen Abschnitt darunter; im Detail die Bewegungen mit Link zum Bon. `PeriodDetail` zeigt bei einem Monat "Offene Gutscheine am Monatsende", wenn nicht 0.

- [ ] **Step 1: Die Tests schreiben, die scheitern**

```ts
// pull.test.ts
test('Gutscheine und Bewegungen kommen beim Abholen, der Gutschein vor seiner Bewegung; die Antwort passt weiter zum Schema von 1.11.0', ...);
// vouchers.test.ts
test('Liste: Guthaben und Zustand aus den Bewegungen (states.json); openCents ohne Übungs-Gutscheine und ohne überzogene', ...);
test('Detail: Bewegungen mit Bon-Nummer und Kassa; ein anderer Betrieb sieht nichts', ...);
test('zwei Kassen lösen denselben Gutschein über 10,00 € ein, jede 9,65 €, ohne voneinander zu wissen: beide Bons angenommen, Zustand überzogen, Guthaben -930', ...);
// months.test.ts
test('openVoucherCents am Monatsende: ein im November verkaufter und im Dezember eingelöster Gutschein zählt im November ganz', ...);
```
```dart
// server_changes_test.dart
test('Gutschein und Bewegungen vom Server: bekannt nach dem Abgleich, Guthaben stimmt; noch einmal dieselbe Seite ändert nichts', ...);
test('eine Einlösung von einer anderen Kassa senkt das Guthaben hier; ein gewählter Gutschein am offenen Bon bekommt das neue Guthaben', ...);
// voucher_test.dart
test('Zustand: die Fälle aus shared/fixtures/vouchers/states.json', ...);
// voucher_redeem_test.dart
testWidgets('zwei Gutscheine mit demselben Code nach dem Abgleich: die Kassa zeigt beide mit Wert und Datum, gewählt wird einer', ...);
```

- [ ] **Step 2: Laufen lassen, sie scheitern**

Run: `cd server && npx vitest run test/vouchers.test.ts test/pull.test.ts`
Expected: FAIL.

- [ ] **Step 3: Umsetzen.**

- [ ] **Step 4: Laufen lassen, alles grün**

Run: `cd server && npx vitest run test/vouchers.test.ts test/pull.test.ts test/months.test.ts test/push.test.ts && npm run typecheck`; `cd web && npm test && npm run typecheck`; `cd app && ~/flutter/bin/flutter test test/sync/ test/data/voucher_repository_test.dart test/domain/voucher_test.dart test/features/voucher_redeem_test.dart && ~/flutter/bin/flutter analyze`
Expected: PASS.

- [ ] **Step 5: Commit** `Stufe 1b Task 16: Gutscheine im Abgleich und im Browser`.

---

## Teil 4: Ausdruck, Texte, Prüfung

### Task 17: Bondruck, Abschluss, Monatsabrechnung, Bons und Übersicht mit den neuen Zeilen

Spec 5.2 (am Bon), 5.5 (am Bon), 5.7.

**Files:**
- Modify: `app/lib/domain/{receipt_layout,report_layout}.dart`, `app/lib/features/close/{income_card,summary_rows,period_cards,day_closed_view,month_view}.dart`, `app/lib/features/bons/{bons_screen,receipt_list,receipt_detail}.dart`, die Übersicht am Tablet (die Datei mit den Zahlungsarten), `app/lib/l10n/app_*.arb`
- Test: `app/test/domain/{receipt_layout,report_layout}_test.dart`, `app/test/features/{close,close_month,close_print,report_print,bons,overview}_test.dart`

**Interfaces:**
- Consumes: `Receipt.depositReturnCents/depositReturnQuantity/voucherCents/voucherSaleCents/revenueCents/paymentKinds/soldVouchers` (Task 3), die fünf Zahlen in `DaySummary` und `PeriodReport` (Task 6), `formatVoucherCode`.
- Produces: nichts für andere Aufgaben.

Regeln für den Kundenbon (`layoutReceipt`, Deutsch; ein Bon ohne die neuen Dinge druckt Zeile für Zeile wie in 1.11.0):
- Zeile "Pfand zurück": `'3 x Pfand zurück'` mit dem Betrag `-0,75` (Pfand der Zeile, nicht der Warenwert 0), bei Menge über 1 darunter `je -0,25`.
- Die Reihe `Pfand` zeigt nur das verlangte Pfand (`depositCents - depositReturnCents`) und fehlt bei 0.
- Zeile "Gutschein": `'1 x Gutschein'` mit dem Wert, darunter eingerückt `Code 1234 5678` (statt den Code an den Namen zu hängen).
- Steuer: Verkaufte Gutscheine stehen nach den Steuerzeilen als eigene Reihe `Gutschein (kein Umsatz)` mit ihrer Summe.
- Zahlungen: Gutschein vor Bar und Karte als `Gutschein 1234 5678` mit dem Betrag, darunter eingerückt `Restguthaben 15,35`. Bei Summe unter 0: `Bar ausbezahlt` mit dem Betrag ohne Minus; "Gegeben" und "Rückgeld" fehlen. Ein Bon nur mit Gutschein hat keine Reihe "Bar".
- Storno: dieselben Reihen mit umgekehrtem Vorzeichen; bei einer Gutschein-Zahlung steht das Restguthaben nach dem Storno.

Regeln für Abschluss und Monatsabrechnung (Bildschirm und Ausdruck):
- EINNAHMEN: `Bar`, `Karte`, dann nur wenn nicht 0 `Mit Gutschein bezahlt` (Betrag) und `Gutscheine verkauft` (Anzahl, Betrag mit Minus), dann `Gesamt` = Umsatz. So ergibt die Spalte von oben nach unten die Summe.
- Nur wenn nicht 0: `Pfand zurück` (Anzahl, Betrag mit Minus) bei "Storniert" und "Rabatte".
- Steuer: Die Zeile zum Satz 0 bleibt, wie sie signiert wird; darunter, nur wenn nicht 0, `davon Gutscheine` mit der Summe der verkauften Gutscheine.
- Am Bildschirm dieselben Reihen mit den Schlüsseln `income-voucher-paid`, `income-voucher-sold`, `income-deposit-return`, in fünf Sprachen. Erwartetes Bargeld bleibt, wie es ist.
- ARB: `closeVoucherPaid` "Mit Gutschein bezahlt", `closeVoucherSold` "Gutscheine verkauft", `closeDepositReturn` "Pfand zurück", `closeTaxVouchers` "davon Gutscheine".

Regeln für "Bons" und Übersicht am Tablet:
- Liste: Die Zahlungsart nennt alle Arten des Bons in der Reihenfolge der Zahlungen ("Gutschein + Bar", "Gutschein", "Bar + Karte"); eine Auszahlung heißt "Bar". Neuer Filter `filter-voucher` ("Gutschein"): jeder Bon mit einer Gutschein-Zahlung.
- Detail: Gutschein-Zahlung als `detail-payment-<i>` mit "Gutschein 1234 5678", Betrag und "Restguthaben"; verkaufte Gutscheine mit Code (Task 10); "Pfand zurück" als Zeile mit Minus; Summe unter 0 mit Minus.
- Übersicht: Zahlungsarten bar, Karte, Gutschein (Gutschein nur, wenn nicht 0); Umsatz ohne verkaufte Gutscheine (kommt aus Task 6).
- ARB: `bonsPaymentVoucher` "Gutschein", `bonsFilterVoucher` "Gutschein", `bonsVoucherLeft` "Restguthaben".

- [ ] **Step 1: Die Tests schreiben, die scheitern**

```dart
// receipt_layout_test.dart (Helfer `linesOf` wie in der Datei; die Bons kommen aus shop wie in Task 4)
test('Bon mit Pfand zurück: Zeile mit -0,75 und je -0,25, Pfand 0,50 bleibt eigene Reihe, SUMME 17,45', () {
  final t = linesOf(layoutReceipt(withReturn, business));
  expect(t, containsAllInOrder([matches(r'3 x Pfand zurück\s+-0,75'), contains('je -0,25'), matches(r'Pfand\s+0,50'), matches(r'SUMME EUR\s+17,45')]));
});
test('Auszahlung: SUMME -0,75, "Bar ausbezahlt 0,75", kein Gegeben, kein Rückgeld', ...);
test('Gutschein verkauft: Zeile mit Code darunter, "Gutschein (kein Umsatz) 25,00" nach der Steuer', ...);
test('mit Gutschein bezahlt, Rest bar: "Gutschein 1234 5678 5,00", "Restguthaben 0,00", dann "Bar 4,65"', ...);
test('Storno eines Gutschein-Bons: Beträge mit Minus, Restguthaben nach dem Storno', ...);
test('ein Bon aus 1.11.0 (Rabatt, Trinkgeld, Teil bar) druckt Zeile für Zeile wie vorher', ...);      // der festgehaltene Text aus dem vorhandenen Test bleibt
// report_layout_test.dart
test('Tagesabschluss mit dem Tag aus Task 6: Bar 42,45, Mit Gutschein bezahlt 9,65, Gutscheine verkauft 1 und -25,00, Gesamt 27,10, Pfand zurück 3 und -0,75, davon Gutscheine 25,00', ...);
test('ein Tag ohne Gutschein und ohne Pfand zurück druckt wie in 1.11.0', ...);
// close_test.dart, close_month_test.dart
testWidgets('die drei neuen Reihen stehen nur da, wenn es etwas gibt', ...);
// bons_test.dart
testWidgets('Liste: "Gutschein + Bar"; Filter Gutschein zeigt nur Bons mit Gutschein-Zahlung; Detail mit Code und Restguthaben', ...);
// overview_test.dart
testWidgets('Zahlungsarten: bar, Karte, Gutschein', ...);
```

- [ ] **Step 2: Laufen lassen, sie scheitern**

Run: `cd app && ~/flutter/bin/flutter test test/domain/receipt_layout_test.dart test/domain/report_layout_test.dart`
Expected: FAIL.

- [ ] **Step 3: Umsetzen.**

- [ ] **Step 4: Laufen lassen, alles grün**

Run: `cd app && ~/flutter/bin/flutter test test/domain/ test/features/close_test.dart test/features/close_month_test.dart test/features/close_print_test.dart test/features/report_print_test.dart test/features/bons_test.dart test/features/overview_test.dart test/features/stufe_1a_off_test.dart test/features/stufe_1b_off_test.dart test/golden/close_golden_test.dart test/golden/bons_golden_test.dart test/l10n_review_test.dart && ~/flutter/bin/flutter analyze`
Expected: PASS, kein Golden geändert.

- [ ] **Step 5: Commit** `Stufe 1b Task 17: Bondruck, Abschluss, Bons und Übersicht mit den neuen Zeilen`.

### Task 18: Texte in fünf Sprachen prüfen, Bilder der neuen Blätter

Spec 7 (Bilder in hell und dunkel, Deutsch und Arabisch), Global Constraints (Wörter).

**Files:**
- Create: `app/test/golden/stufe_1b_golden_test.dart`, `app/test/golden/goldens/1b_*.png`
- Modify: `app/lib/l10n/app_*.arb` (nur Korrekturen), `app/test/features/l10n_layout_test.dart`, `app/test/features/l10n_kassa_test.dart`
- Test: dieselben, `app/test/l10n_review_test.dart`

**Interfaces:**
- Consumes: alle Blätter aus Task 8 bis 15.
- Produces: 32 Bilder der Blätter: `1b_mehr`, `1b_pfand_zurueck`, `1b_gutschein_verkaufen`, `1b_gutschein_pruefen`, `1b_gutschein_einloesen`, `1b_rechnung_kunde_waehlen`, `1b_rechnung_neuer_kunde`, `1b_verkauf_fertig_digital`, je als `_hell.png`, `_dunkel.png`, `_arabisch_hell.png`, `_arabisch_dunkel.png`. Dazu vier Bilder von Papier (nur Deutsch, hell): `1b_bon_pfand_zurueck_hell.png`, `1b_bon_gutschein_hell.png`, `1b_rechnung_hell.png`, `1b_gutschein_abschnitt_hell.png`.

Regeln:
- Jeder Text aus Task 8 bis 17 steht in allen fünf Sprachen mit den Wörtern aus den Global Constraints; kein Schlüssel fehlt, keiner ist nur kopiertes Deutsch (außer Eigennamen und Zahlen).
- `l10n_layout_test.dart` bekommt die neuen Blätter in allen fünf Sprachen bei der kleinsten Breite der Bon-Spalte: kein Überlauf, keine abgeschnittene Taste. Arabisch: gespiegelt, Beträge und Codes bleiben von links nach rechts ("1234 5678", "−0,75 €").
- Zahlen in den Blättern mit Ziffern gleicher Breite; der Code in zwei Gruppen.
- Der QR-Code im Bild `1b_verkauf_fertig_digital` kommt aus einer festen Beispiel-Adresse (`https://kassa.example/beleg/AAAAAAAAAAAAAAAAAAAAAA`), nie aus der echten Server-Adresse.

- [ ] **Step 1: Den Bilder-Test und die neuen Fälle in `l10n_layout_test.dart` schreiben** (Muster: `stufe_1a_golden_test.dart`).

- [ ] **Step 2: Laufen lassen.** Run: `cd app && ~/flutter/bin/flutter test test/features/l10n_layout_test.dart test/l10n_review_test.dart` Expected: scheitert dort, wo ein Text überläuft oder fehlt; beheben.

- [ ] **Step 3: Bilder erzeugen und ansehen.** `~/flutter/bin/flutter gen-l10n` (die Datei `build/l10n_untranslated.json` ist leer), `~/flutter/bin/dart run tool/l10n_review.dart`, dann `~/flutter/bin/flutter test --update-goldens test/golden/stufe_1b_golden_test.dart`. Jedes der 36 Bilder ansehen: nichts abgeschnitten, Arabisch gespiegelt und mit verbundener Schrift, dunkel lesbar, der QR-Code schwarz auf weiß.

- [ ] **Step 4: Laufen lassen, alles grün**

Run: `cd app && ~/flutter/bin/flutter test test/golden/ test/features/l10n_layout_test.dart test/features/l10n_kassa_test.dart test/l10n_review_test.dart && ~/flutter/bin/flutter analyze`
Expected: PASS; außer den neuen `1b_*`-Bildern ist kein Golden geändert.

- [ ] **Step 5: Commit** `Stufe 1b Task 18: Texte in fünf Sprachen, Bilder der neuen Blätter`.

### Task 19: Prüfwerkzeug des BMF und Zusammenspiel von Tablet und Server

Spec 7 (eigene Kette; `tool/e2e.sh`). Review Focus 1 und 3.

**Files:**
- Modify: `app/test/rksv/pruefwerkzeug_test.dart`, `app/test/support/rksv_rig.dart`, `app/test_e2e/push_and_sync_test.dart`, `server/src/dev/seed.ts`, `tool/e2e.sh`
- Test: dieselben, über `tool/rksv/pruefen.sh` und `tool/e2e.sh`

**Interfaces:**
- Consumes: `finalizePayout`, `finalizeVoucherSale`, `Cart.setDepositReturn/addVoucherSale/applyVoucher` (Task 2 und 4), die Seite `/beleg/:token` (Task 14), die Listen beim Abholen (Task 13 und 16).
- Produces: `RksvRig.payout(id, cart)`, `RksvRig.sellWithVoucher(id, cart, voucher)`; `seed.ts` gibt einen zweiten Kopplungscode `code2` für eine zweite Kassa desselben Betriebs aus, `tool/e2e.sh` reicht ihn als `E2E_CODE2` weiter.

- [ ] **Step 1: Eine eigene Kette für das Prüfwerkzeug**

```dart
// pruefwerkzeug_test.dart: neuer Test neben den vorhandenen, eigene Kassen-ID, Start-Beleg, dann jeweils nach tick():
await rig.sell('pfand-mit-ware', cart.setDepositReturn(depositCents: 25, quantity: 3));                 // 17,45
await rig.payout('pfand-auszahlung', const Cart.empty().setDepositReturn(depositCents: 25, quantity: 3)); // -0,75
await rig.sell('pfand-null', const Cart.empty().add(pfandArtikel025).setDepositReturn(depositCents: 25, quantity: 1));   // Summe 0 über "Abschließen"
final g = await rig.sell('gutschein-verkauf', cartCard.addVoucherSale(valueCents: 2500));               // 34,65, davon 25,00 im Satz 0
final v = (await rig.vouchers.soldOn('gutschein-verkauf')).single;
await rig.sellWithVoucher('gutschein-ganz', cartCard, v);                                               // 9,65 nur Gutschein
await rig.sellCard('gutschein-und-karte', cart.applyVoucher(applied((await rig.vouchers.byId(v.id))!)), tipCents: 35);   // Rest 15,35 deckt 18,20 nicht: Gutschein 15,35, Karte 2,85 + 0,35
await rig.receipts.voidReceipt('gutschein-und-karte', staff: rig.chef);
await rig.receipts.voidReceipt('pfand-auszahlung', staff: rig.chef);
// Erwartung: rig.verifyChain(…) ohne Befund; die Beträge je Satz jedes Belegs ergeben seine Summe plus Trinkgeld;
// der Beleg 'pfand-auszahlung' trägt -0,75 im Satz 0; der Umsatzzähler sinkt dort um 0,75.
```

- [ ] **Step 2: Prüfwerkzeug laufen lassen**

Run: `tool/rksv/pruefen.sh`
Expected: PASS, das Werkzeug beanstandet keinen Eintrag, auch nicht den Beleg unter 0. Fehlt das Werkzeug ("Das Prüfwerkzeug fehlt unter …"), ist dieser Schritt nicht erledigt: offen lassen und im Bericht nennen, nicht überspringen. Beanstandet das Werkzeug den Beleg unter 0, ist das ein Befund für Niko und die Steuerberatung: im Bericht mit dem Wortlaut nennen, nichts am Test abschwächen.

- [ ] **Step 3: Zusammenspiel erweitern**

`push_and_sync_test.dart` bekommt:
- `'Gutschein-Verkauf und Einlösung kommen am Server an; die Seite des Bons zeigt dieselben Zahlen'`: verkaufen, einlösen mit Rest bar, abgleichen; `GET …/vouchers` hat den Gutschein mit Guthaben; `GET /beleg/<publicToken>` gibt 200 und enthält Summe, Gutschein-Betrag und "Restguthaben" wie am Tablet; ein falscher Schlüssel gibt 404.
- `'eine zweite Kassa kennt den Gutschein nach dem Abgleich und kann ihn einlösen'`: mit `E2E_CODE2` koppeln, abholen, `findByCode` findet ihn mit dem Guthaben, einlösen, abgleichen; die erste Kassa sieht nach ihrem Abgleich das neue Guthaben.
- `'Auszahlung, Empfänger und Belegerteilung kommen an'`: Bon unter 0, `setRecipient`, Eintrag "digital"; die Verwaltung zeigt `totalCents -75`, den Empfänger und die Belegerteilung.
- `'ein Bon aus 1.11.0, der schon am Server ist, kommt nach dem Update als v: 3 noch einmal: duplicate'` (mit `receipt_1_11_0_v2.json` und der Datenbank aus Task 5).

- [ ] **Step 4: Zusammenspiel laufen lassen**

Run: `tool/e2e.sh` (kein APK-Bau zur selben Zeit im Ordner)
Expected: PASS, alle Tests in `app/test_e2e`.

- [ ] **Step 5: Befunde beheben**, jeweils mit einem Test in der Aufgabe, der der Code gehört, und beide Läufe wiederholen.

- [ ] **Step 6: Commit** `Stufe 1b Task 19: Prüfwerkzeug und Zusammenspiel mit Pfand zurück, Gutschein, Rechnung, digitalem Beleg`.

### Task 20: Prüfliste für Niko, Version 1.12.0, Abschnitt 10 der Spec

Spec 5.8, 7 (Prüfliste), 9.

**Files:**
- Create: `docs/testen/stufe-1b-pruefliste.md`
- Modify: `app/pubspec.yaml` (`version: 1.12.0+14`), `app/lib/core/app_info.dart` (`appVersion = '1.12.0'`), die Spec (neuer Abschnitt 10), `PRODUCT.md` (ein Absatz zu den vier Funktionen und ihren Schaltern), Goldens der Einstellungen, falls die Version im Bild steht
- Test: `app/test/features/settings_test.dart` (prüft Version gegen `pubspec.yaml`)

**Interfaces:**
- Consumes: alles Vorige.
- Produces: nichts für andere Aufgaben. Diese Aufgabe baut keine Installationsdatei und lädt nichts hoch; das ist ein eigener Schritt nach dem Plan, nach Nikos Ja, und nach dem Server.

Die Prüfliste, in einfachen Worten und zum Abhaken, Aufbau wie `docs/testen/stufe-1a-pruefliste.md` (bei jedem Punkt: was tun, was man sehen soll):
- **0. Update von 1.11.0:** Bons und Einstellungen sind da, unten steht "Kassa Version 1.12.0", in "Zahlen" sind die drei neuen Schalter aus, "Kundenbon" steht auf "Immer drucken", ein Verkauf bar und einer mit Karte laufen wie immer.
- **A. Pfand zurück:** Schalter an; drei Becher auf einen Bon mit Ware; nur Pfand zurück mit "Bar auszahlen", die Lade springt auf; Bon ansehen; "Nur Chef" mit einer Mitarbeiterin prüfen; Storno; Abschluss zeigt "Pfand zurück".
- **B. Gutschein:** verkaufen (25 €, anderer Betrag), Abschnitt mit Code; "Prüfen"; einlösen ganz; einlösen mit Rest bar und mit Rest Karte (echtes Terminal); Storno gibt das Guthaben zurück; Storno eines eingelösten Gutscheins geht nicht; Abschluss zeigt "Mit Gutschein bezahlt" und "Gutscheine verkauft".
- **C. Rechnung an Firma:** nach einem Verkauf "Neuer Kunde" mit Tastatur, Rechnung drucken, Nummer mit Kassen-ID; denselben Kunden beim nächsten Bon mit einem Tipp wählen; aus "Bons" nachträglich; Tippfehler ändern.
- **D. Digitaler Beleg:** "Drucken und digital": QR-Code mit dem Handy lesen, die Seite zeigt den Bon. "Digital und Druck auf Wunsch": kein Druck, "Bon drucken" druckt. WLAN aus: nach 3 Sekunden druckt die Kassa von selbst. Das Tablet so stellen, dass der Kunde den Code sieht.
- **E. Im Browser:** "Gutscheine" mit offenem Guthaben, "Firmenkunden", Bon mit Empfänger und "Beleg", Tag und Monatsabrechnung mit den neuen Zeilen.
- **F. Zwei Kassen** (wenn ein zweites Tablet da ist): Gutschein an der einen verkaufen, an der anderen einlösen.
- **G. Sprachen:** die neuen Blätter einmal in Englisch und Arabisch ansehen.
- Hinweise oben: Kartenzahlungen im Test sind echte Buchungen; im Probebetrieb entstehen Übungs-Gutscheine, die später nicht gelten; die Fragen an die Steuerberatung aus Spec 9.

Abschnitt 10 der Spec bekommt jede Abweichung und Entscheidung aus dem Bau, mindestens diese aus dem Plan: die Punkte 16 bis 19 aus Abschnitt 8; Gutschein-Zeile zählt in `goodsCents`; Umsatz = Summe minus verkaufte Gutscheine; `paymentKind` sieht Gutscheine nicht, ein Bon nur mit Gutschein zählt weder bei "Bar" noch bei "Karte"; nach dem Update holt das Tablet Firmenkunden und Gutscheine nach; der Server prüft kein Guthaben; die Bremse der Seite zählt nur Fehlversuche; "Mit Gutschein abschließen", wenn die Auswahl alles deckt; "Als Firmenkunde speichern" lässt sich ausschalten; `delivery` hält "digital" fest, sobald der QR-Code zu sehen ist; die geänderten Erwartungen in vorhandenen Tests (Version 8 → 9 in vier Dateien, Liste der Server-Migrationen, dritte Ausnahme im Textfeld-Test, Bilder der Einstellungen), jede mit Datei und Zeile; was offen bleibt.

- [ ] **Step 1: Version setzen und den Test der Version laufen lassen**

Run: `cd app && ~/flutter/bin/flutter test test/features/settings_test.dart`
Expected: FAIL, solange nur eine der zwei Stellen geändert ist; PASS mit `1.12.0+14` in `pubspec.yaml` und `'1.12.0'` in `app_info.dart`.

- [ ] **Step 2: Prüfliste, Abschnitt 10 und `PRODUCT.md` schreiben.** In der Prüfliste steht keine Server-Adresse und kein echter Betrag.

- [ ] **Step 3: Alles committen und pushen**, Titel `Stufe 1b Task 20: Prüfliste, Version 1.12.0, Entscheidungen beim Bau`.

- [ ] **Step 4: GitHub lesen.** Workflows `app` und `server` für den letzten Commit sind grün (Ergebnis lesen; scheitert etwas, hier nur die betroffenen Dateien wiederholen und beheben).

---

## Abdeckung der Spec

| Spec | Aufgabe |
| --- | --- |
| 5.1 Schalter und "Mehr" | 1 (Daten), 8 (Einstellungen, Test "alles aus"), 9 ("Mehr", "nur Chef") |
| 5.2 Pfand zurück | 2 (Zeile), 3 und 4 (Regeln, Auszahlung, Storno), 6 und 7 (Auswertungen), 9 (Kassa), 17 (Bon, Abschluss), 19 (Signatur) |
| 5.3 Rechnung an Firma | 1 (Tabellen), 12 (Tablet, Ausdruck, Hinweis über 400 €), 13 (Server, Browser, zurück aufs Tablet), 14 (Seite zeigt den Empfänger) |
| 5.4 Digitaler Beleg | 4 (Schlüssel), 5 (`receipt_links`), 14 (Seite, Belegerteilung am Server), 15 (Kassa, Druck auf Wunsch, 3 Sekunden, Bons) |
| 5.5 Gutschein | 2 (Zeile, Auswahl), 3 (Modell, Zustände), 4 (speichern, Storno, Übung), 10 (verkaufen, prüfen, Abschnitt), 11 (einlösen, Karte danach), 16 (mehrere Kassen, Browser) |
| 5.6 Daten | 1 (Tablet), 3 und 4 (feste Regeln), 5 (Abgleich `v: 3`, Migration 0005), 2 und 11 (Entwurf, offene Kartenzahlung) |
| 5.7 Auswertungen | 6 (Tablet), 7 (Server, Browser), 16 (offene Gutscheine am Monatsende), 17 (Ausdruck, Bons, Übersicht) |
| 5.8 Version | 1 (Datenbank 9), 5 (Migration 0005), 20 (1.12.0 Build 14) |
| 7 Prüfung | 1 (Migration), 4 (zufällige Bons), 5, 13, 14, 16 (Server), 8 (alles aus), 18 (Bilder), 19 (Prüfwerkzeug, `tool/e2e.sh`), 20 (Prüfliste) |
