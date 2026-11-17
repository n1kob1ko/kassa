# Teil B: Bondruck, Geldlade und Kartenzahlung mit SumUp Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Die Kassa-App druckt den Bon von selbst, öffnet bei Barzahlung die Geldlade und schickt bei "Karte" den Betrag direkt ans SumUp-Gerät, ohne zweites Handy und ohne doppeltes Eintippen.

**Architecture:** Drucker und Kartenterminal sitzen je hinter einer Dart-Schnittstelle mit einer Attrappe für Tests. Der Bon wird in reinem Dart zu Zeilen gesetzt (`lib/domain/`) und in einem zweiten Schritt zu ESC/POS-Bytes gemacht (`lib/devices/`). Netzwerkdruck läuft direkt aus Dart, USB, Bluetooth und SumUp über drei kleine Kotlin-Kanäle. Ein Verkaufsdienst (`SaleService`) hält die Reihenfolge fest: zuerst der Bon in der Datenbank, dann Druck und Lade. Kein Gerät kann einen Verkauf sperren.

**Tech Stack:** Flutter 3.50.0, drift 2.35.x (Schema-Version 2 mit Migration), Kotlin 2.4.20, Android Gradle Plugin 9.3.1, SumUp `com.sumup:merchant-sdk:7.2.0` aus `https://maven.sumup.com/releases`, ESC/POS mit Zeichensatz PC858. Keine neuen Dart-Pakete.

**Spec:** `docs/superpowers/specs/2026-11-17-kassa-design.md` (Abschnitte 5.6, 5.7, 5.14, 8). Dazu `DESIGN.md` (Zeilen zu "Warte auf Karte", "Bezahlt", Status-Pillen, Bons-Knöpfe, Geräte) und `PRODUCT.md`.

## Wo dieser Plan steht

| Plan | Inhalt | Stand |
|---|---|---|
| Teil A | App am Tablet ohne Server | fertig, Version 1.0.1 läuft auf Nikos Tablet |
| **Teil B (dieser Plan)** | Bondruck über Netzwerk, USB, Bluetooth, Geldlade, "Geräte testen", Kartenzahlung mit SumUp | geschrieben |
| Teil C | Server, Anbieter-Seite, Kopplung, Abgleich, Fotos, Fehlerberichte | danach |
| Danach | RKSV-Signatur mit der Chipkarte | danach |

Niko hat den Umfang am 17.11.2026 so festgelegt: zuerst Bondruck und Kartenzahlung direkt aus der Kassa, dann Server und Browser-Verwaltung, dann die Signatur.

**Nicht in Teil B:** Signatur und QR-Code am Bon (darum trägt jeder gedruckte Bon den Vermerk "TESTBON"), Logo am Bon (Bilder kommen mit dem Server), Kassen-Kennung am Bon (kommt mit der Signatur), Fehlerberichte an den Server, Trinkgeld, andere Terminals als SumUp, Rückbuchung auf die Karte aus der Kassa.

## Was vor dem Schreiben geprüft wurde (18.11.2026)

- `maven.sumup.com` ist in Nikos Cloud-Umgebung freigeschaltet. Die App baut mit `merchant-sdk:7.2.0`, wenn vier Dinge gesetzt sind: das SumUp-Repository, `minSdk = 26`, die Versionsliste `androidx.compose:compose-bom:2024.09.00` und "core library desugaring". Das steht in Task 11. Ein Probe-Bau mit diesen vier Dingen lief am 18.11.2026 durch. Die Installationsdatei wächst dadurch von rund 10 MB auf rund 24 MB. Das SDK bringt die Erlaubnisse für Internet, Bluetooth und Standort selbst mit.
- Das SDK verlangt mindestens 1,00 € pro Zahlung.
- Das SDK hat keine Rückbuchung. Der Entwurf sieht dafür den Hinweis vor, sie in der SumUp-App zu machen.
- Das SDK kann eine frühere Zahlung nicht nachschlagen. Das geht nur über die Transactions-Schnittstelle von SumUp mit einem Zugang, den die App ohne Server nicht hat. **Abweichung von 5.6:** In Teil B entscheidet nach einem Absturz der Mensch an der Kassa ("Zahlung durchgegangen" oder "nicht durchgegangen"), das Nachfragen bei SumUp kommt mit dem Server in Teil C. Der Entwurf wird in Task 14 entsprechend ergänzt.
- Der Affiliate Key hängt an der App-Kennung `io.github.n1kob1ko.kassa`. Er steht nie im Repo, sondern in `/mnt/project-files/kassa-build/sumup.properties`.
- Ohne Schlüssel baut und läuft die App trotzdem. Das Kartenterminal meldet dann "nicht eingerichtet".
- Es gibt hier weder Drucker noch SumUp-Gerät noch Emulator. Alles wird mit Attrappen getestet, an echten Geräten testet Niko mit der Prüfliste aus Task 14.

## Global Constraints

- Plattform: Android-Tablet im Querformat, Entwurfsgröße 1280 × 800, passend für 10 bis 13 Zoll. Ab Teil B `minSdk = 26` (Android 8).
- Oberfläche auf Deutsch mit österreichischen Begriffen: bonieren, Bon, Storno, Tagesabschluss, Geldlade.
- In der ganzen App kommt kein Textfeld vor (`test/no_text_field_test.dart` prüft das). Eingaben gehen über Tasten, Schalter und Zahlenfelder.
- Geldbeträge sind immer ganze Cent (`int`). Nie `double` für Geld, auch nicht auf dem Weg zu SumUp (dort `BigDecimal` aus Cent).
- Ein fertiger Bon wird nie geändert oder gelöscht. Die Trigger aus Teil A bleiben.
- **Jede Änderung am Datenbank-Schema braucht eine Migration und einen Migrationstest.** Version 1 ist ausgeliefert.
- Kein Gerät sperrt den Verkauf. Fällt der Drucker aus, wird der Bon trotzdem gespeichert. Bar bonieren geht immer.
- Tippflächen mindestens 48 dp, Hauptaktionen 64 bis 80 dp hoch. Farben, Maße und Bewegung aus `DESIGN.md` und `lib/ui/tokens.dart`. Bewegung 120 bis 320 ms, abgeschaltet bei "Animationen entfernen".
- Texte in der App nennen keine Planschritte ("kommt später", "Teil C"). Meldungen sagen in einfachen Worten, was los ist und was man tun kann.
- Das Repo ist öffentlich. Umsätze, Zugangsdaten und Schlüssel (auch der SumUp Affiliate Key) kommen nie ins Repo. Tests und Beispiele verwenden den erfundenen "Beispiel-Imbiss".
- Bezeichner im Code sind englisch, Texte in der Oberfläche deutsch. Neue Wörter: Bondrucker = `ReceiptPrinter`, Kartenterminal = `CardTerminal`, Kartenzahlung = `CardPayment`, Geldlade öffnen = `openDrawer`.
- Gebaut wird testgetrieben. Git: Commits auf dem Arbeits-Branch `claude/project-thread-xtooco`, ohne Pull Request, Commit-Texte auf Deutsch. Jeder Commit endet mit den Abschlusszeilen, die der Auftrag nennt.
- Alle Befehle laufen aus `app/`, wenn nichts anderes dasteht. Flutter liegt in `~/flutter` (`export PATH="$HOME/flutter/bin:$PATH"`).
- Nach jeder Änderung an Tabellen: `dart run build_runner build`. Vor jedem Commit: `flutter analyze` ohne Meldung und die Tests der Aufgabe grün.
- Ein Bau der Installationsdatei dauert einige Minuten. Er läuft nur in den Aufgaben, die Kotlin oder Gradle anfassen (6, 11, 14), dort je einmal am Ende.

## Review Focus

Diese fünf Fälle nennt der Entwurf nicht, sie treffen aber jemanden an der Theke. Jeder hat seinen Test in der genannten Aufgabe.

1. **Zeichen, die der Drucker nicht kennt.** Ein Artikel heißt "Phở Bò", "Crème brûlée" oder trägt chinesische Zeichen. Erwartet: Der Bon druckt lesbar weiter (ä, ö, ü, ß und € bleiben, andere Buchstaben verlieren den Akzent, Unbekanntes wird "?"), keine Zeile wird breiter als das Papier, der Betrag bleibt rechts. Tests in Task 3 und Task 4.
2. **Drucker aus, Kabel gezogen, Papier leer, mitten im Verkauf.** Erwartet: genau ein Bon in der Datenbank, die Fertig-Ansicht meldet "Drucker nicht bereit" mit "Nochmal drucken", der nächste Kunde kann sofort boniert werden. Der Druck wartet höchstens 5 Sekunden. Tests in Task 5 und Task 8.
3. **Android beendet die Kassa, während der SumUp-Bildschirm offen ist, oder die App stürzt zwischen Zahlung und Bon ab.** Erwartet: Die Zahlung geht nicht verloren und wird nie doppelt boniert. Beim nächsten Start fragt die Kassa, ob die Zahlung durchging. Tests in Task 10 und Task 13.
4. **Zwei schnelle Tipps auf "Karte", Tipp auf "Karte" bei 0,50 € oder ohne Internet.** Erwartet: höchstens eine Zahlung läuft, unter 1,00 € und ohne Internet ist "Karte" aus und sagt warum, "Bar" bleibt. Tests in Task 12.
5. **Erlaubnis verweigert oder Gerät weg.** Bluetooth-Erlaubnis abgelehnt, USB-Drucker abgesteckt, gespeicherter Drucker existiert nicht mehr, SumUp abgemeldet. Erwartet: eine Meldung in einfachen Worten mit dem nächsten Schritt, kein Absturz, kein endloses Warten. Tests in Task 6, Task 7 und Task 12.

---

## Dateien

```
app/
  drift_schemas/                         Schema-Abbilder Version 1 und 2 (Task 1)
  lib/
    core/enums.dart                      enumByNameOr (Task 1)
    data/
      database.dart                      Version 2, neue Spalten und Tabelle (Task 1)
      card_payment_repository.dart       offene Kartenzahlungen (Task 10)
      receipt_repository.dart            finalizeCardSale, Entwurf im selben Schritt löschen (Task 8, 10)
      settings_repository.dart           Drucker-Einstellungen (Task 1)
    domain/
      business_info.dart                 Betriebsdaten für den Bon (Task 2)
      print_document.dart                PrintOp und Geschwister (Task 3)
      receipt_layout.dart                Bon zu Zeilen (Task 3)
    devices/
      escpos.dart                        Zeilen zu Bytes (Task 4)
      printer.dart                       ReceiptPrinter, PrinterTransport, PrintOutcome (Task 5)
      network_transport.dart             Druck über Netzwerk (Task 5)
      channel_transport.dart             Druck über USB und Bluetooth (Task 6)
      printer_discovery.dart             Geräte suchen (Task 6, 7)
      card_terminal.dart                 CardTerminal und Ergebnis-Typen (Task 10)
      sumup_terminal.dart                SumUp über den Kotlin-Kanal (Task 11)
      internet.dart                      Internet da oder nicht (Task 11)
      device_providers.dart              Provider für Drucker, Terminal, Internet (Task 5, 10, 11)
    features/
      kassa/sale_service.dart            speichern, drucken, Lade, Karte (Task 8, 10)
      kassa/card_wait.dart               "Warte auf Karte" (Task 12)
      kassa/unclear_card_payment.dart    Frage nach einem Absturz (Task 13)
      settings/printer_panel.dart        Drucker einrichten (Task 7)
      settings/card_panel.dart           SumUp anmelden, Leser verbinden (Task 12)
      settings/device_test_screen.dart   "Geräte testen" (Task 9)
  android/app/src/main/kotlin/io/github/n1kob1ko/kassa/
    MainActivity.kt                      Kanäle anmelden, onActivityResult weiterreichen
    KassaApplication.kt                  SumUpState.init (Task 11)
    PrinterChannel.kt                    USB und Bluetooth (Task 6)
    SumUpChannel.kt                      SumUp (Task 11)
    InternetChannel.kt                   Internet-Zustand (Task 11)
  test/
    devices/…, domain/receipt_layout_test.dart, data/migration_test.dart, features/…
    support/fake_devices.dart            FakePrinter, FakeCardTerminal (Task 5, 10)
docs/testen/teil-b-pruefliste.md         Prüfliste für Niko (Task 14)
tool/build_apk.sh                        liest zusätzlich sumup.properties (Task 11)
```

---

### Task 1: Datenbank Version 2 mit Migration

**Files:**
- Create: `app/drift_schemas/drift_schema_v1.json`, `app/drift_schemas/drift_schema_v2.json`, `app/test/data/generated_migrations/` (erzeugt), `app/test/data/fixtures/kassa_v1.sqlite`, `app/test/data/migration_test.dart`, `app/lib/core/enums.dart`
- Modify: `app/lib/data/database.dart`, `app/lib/data/settings_repository.dart`, `app/test/data/settings_repository_test.dart`

**Interfaces:**
- Produces:
  - `T enumByNameOr<T extends Enum>(List<T> values, String? name, T fallback)` in `core/enums.dart`
  - `enum PrinterKind { none, network, usb, bluetooth }`
  - `RegisterSettings` bekommt `printerKind` (Vorgabe `none`), `printerAddress` (`String?`), `printerName` (`String?`), `printerColumns` (`int`, Vorgabe 48), alle auch in `copyWith`. Zum Leeren von Adresse und Name: `RegisterSettings withoutPrinter()`.
  - Neue Spalten `settings`: `printer_kind` (Text, Vorgabe `'none'`), `printer_address` (Text, leer erlaubt), `printer_name` (Text, leer erlaubt), `printer_columns` (Zahl, Vorgabe 48)
  - Neue Spalten `business`: `address_lines` (Text, Vorgabe `''`, Zeilen durch `\n` getrennt), `vat_id` (Text, leer erlaubt), `receipt_footer` (Text, leer erlaubt)
  - Neue Spalten `payments`: `provider`, `provider_tx_code`, `card_scheme`, `card_last4` (alle Text, leer erlaubt)
  - Neue Tabelle `PendingCardPaymentRows` (`pending_card_payments`): `id` Text (Primärschlüssel), `cartJson` Text, `amountCents` Zahl, `staffId` Text, `staffName` Text, `startedAt` Zeit, `state` Text (`'started'` oder `'unknown'`)
  - `KassaDatabase.schemaVersion == 2`

- [ ] **Step 1: Stand von Version 1 festhalten, bevor eine Tabelle geändert wird**

```bash
dart run drift_dev schema dump lib/data/database.dart drift_schemas/
```
Erwartet: `drift_schemas/drift_schema_v1.json`. Dann die echte Datei von Version 1 erzeugen: ein Einmal-Skript `tool/make_v1_fixture.dart` (wird nicht committet) öffnet `KassaDatabase(NativeDatabase(File('test/data/fixtures/kassa_v1.sqlite')))`, spielt den Beispiel-Katalog ein, legt Anna und Chef an, speichert die Einstellungen `RegisterSettings(cashDrawerEnabled: false, themeMode: AppThemeMode.dark)`, schließt einen Barverkauf (2 × Cola, gegeben 10,00 €) ab und schließt die Datenbank. Die Datei wird committet.

- [ ] **Step 2: Failing tests** in `test/data/migration_test.dart`

```dart
test('Schema: Version 1 wird zu Version 2', () async {
  final verifier = SchemaVerifier(GeneratedHelper());
  final connection = await verifier.startAt(1);
  final db = KassaDatabase(connection);
  await verifier.migrateAndValidate(db, 2);
  await db.close();
});
test('echte Datei von Version 1: Daten, Trigger und Einstellungen bleiben', () async {
  final file = await copyFixture('kassa_v1.sqlite'); // Kopie in ein Temp-Verzeichnis
  final db = KassaDatabase(NativeDatabase(file));
  final settings = await SettingsRepository(db).current();
  expect(settings.cashDrawerEnabled, isFalse);
  expect(settings.themeMode, AppThemeMode.dark);
  expect(settings.printerKind, PrinterKind.none);
  expect(settings.printerColumns, 48);
  final receipts = await db.select(db.receiptRows).get();
  expect(receipts, hasLength(1));
  final payment = await db.select(db.paymentRows).getSingle();
  expect(payment.provider, isNull);
  await expectLater(db.customStatement('UPDATE receipts SET total_cents = 1'), throwsA(isA<SqliteException>()));
  await expectLater(db.customStatement('DELETE FROM payments'), throwsA(isA<SqliteException>()));
  expect(await db.select(db.pendingCardPaymentRows).get(), isEmpty);
  await db.close();
});
test('unbekannter gespeicherter Wert fällt auf die Vorgabe zurück', () async {
  final db = KassaDatabase(NativeDatabase.memory());
  await db.customStatement("INSERT INTO settings (id, theme_mode, printer_kind) VALUES (1, 'neon', 'laser')");
  final s = await SettingsRepository(db).current();
  expect(s.themeMode, AppThemeMode.system);
  expect(s.printerKind, PrinterKind.none);
});
```
In `settings_repository_test.dart`: Speichern und Lesen von `printerKind: PrinterKind.network, printerAddress: '192.168.1.50:9100', printerName: 'Bondrucker', printerColumns: 42`, und `withoutPrinter()` setzt Art auf `none`, Adresse und Name auf `null`.

- [ ] **Step 3: FAIL prüfen** (`flutter test test/data/migration_test.dart`: Version ist 1, Spalten fehlen).
- [ ] **Step 4: Umsetzen.** Spalten und Tabelle ergänzen, `schemaVersion => 2`, `onUpgrade: (m, from, to) async { if (from < 2) { … } }` mit `m.addColumn` je Spalte und `m.createTable(pendingCardPaymentRows)`. `onCreate` bleibt, wie es ist. `themeMode` und `printerKind` über `enumByNameOr` lesen. Danach `dart run build_runner build`, `dart run drift_dev schema dump lib/data/database.dart drift_schemas/` und `dart run drift_dev schema generate drift_schemas/ test/data/generated_migrations/`.
- [ ] **Step 5: PASS prüfen** (`flutter test test/data`), `flutter analyze`, Commit "Datenbank Version 2: Drucker-Einstellungen, Betriebsdaten, Kartenzahlung, mit Migration".

### Task 2: Betriebsdaten für den Bon aus der Speisekarten-Datei

**Files:**
- Create: `app/lib/domain/business_info.dart`
- Modify: `app/lib/domain/catalog.dart`, `app/lib/domain/menu_import.dart`, `app/lib/data/catalog_repository.dart`, `app/assets/demo/beispiel-imbiss.json`, `docs/superpowers/specs/2026-11-17-kassa-design.md` (Anhang A)
- Test: `app/test/domain/menu_import_test.dart`, `app/test/data/catalog_repository_test.dart`

**Interfaces:**
- Consumes: Spalten `address_lines`, `vat_id`, `receipt_footer` (Task 1)
- Produces: `class BusinessInfo { const BusinessInfo({required this.name, this.addressLines = const [], this.vatId, this.receiptFooter}); }`, `Catalog.business` (`BusinessInfo`), `Catalog.businessName` bleibt als Abkürzung für `business.name`.

Neue freiwillige Angaben in der Datei: `"adresse"` (Liste von höchstens 4 Texten), `"uid"` (Text), `"bon_ende"` (Text, höchstens 200 Zeichen). Fehlt etwas, bleibt es leer. Ein neues Einspielen ersetzt alle drei.

- [ ] **Step 1: Failing tests**

```dart
test('Adresse, UID und Bon-Ende werden gelesen', () {
  final c = parseMenuFile(demoWith({'adresse': ['Musterstraße 1', '1010 Wien'], 'uid': 'ATU12345678', 'bon_ende': 'Danke und bis bald!'}));
  expect(c.business.addressLines, ['Musterstraße 1', '1010 Wien']);
  expect(c.business.vatId, 'ATU12345678');
  expect(c.business.receiptFooter, 'Danke und bis bald!');
});
test('ohne die Angaben bleibt alles leer', () {
  final c = parseMenuFile(demoWith({'adresse': null, 'uid': null, 'bon_ende': null}));   // null entfernt die Angabe
  expect(c.business.addressLines, isEmpty); expect(c.business.vatId, isNull); expect(c.business.receiptFooter, isNull);
});
test('falsche Form wird in einfachen Worten gemeldet', () {
  List<String> problemsOf(String json) { try { parseMenuFile(json); return const []; } on MenuImportException catch (e) { return e.problems; } }
  expect(problemsOf(demoWith({'adresse': 'Musterstraße 1'})), contains('"adresse" muss eine Liste von Zeilen sein.'));
  expect(problemsOf(demoWith({'adresse': ['a', 'b', 'c', 'd', 'e']})), contains('"adresse" darf höchstens 4 Zeilen haben.'));
  expect(problemsOf(demoWith({'uid': 12})), contains('"uid" muss ein Text sein.'));
  expect(problemsOf(demoWith({'bon_ende': 'x' * 201})), contains('"bon_ende" darf höchstens 200 Zeichen haben.'));
});
test('Einspielen speichert die Betriebsdaten, neues Einspielen ersetzt sie', () async { /* importCatalog zweimal, current().business prüfen */ });
```
`demoWith(Map<String, Object?> changes)` ist ein neuer Helfer im Test: Er liest `assets/demo/beispiel-imbiss.json`, setzt die Angaben (ein Wert `null` entfernt die Angabe) und gibt den JSON-Text zurück.

- [ ] **Step 2:** FAIL prüfen.
- [ ] **Step 3:** Umsetzen. Die Beispiel-Datei bekommt `"adresse": ["Musterstraße 1", "1010 Wien"]`, `"uid": "ATU12345678"`, `"bon_ende": "Danke und bis bald!"`. Anhang A im Entwurf um die drei Angaben ergänzen.
- [ ] **Step 4:** PASS (`flutter test test/domain test/data`), alle Bildvergleiche unverändert (`flutter test test/golden`), Commit.

### Task 3: Bon zu Zeilen setzen (reines Dart)

**Files:**
- Create: `app/lib/domain/print_document.dart`, `app/lib/domain/receipt_layout.dart`
- Test: `app/test/domain/receipt_layout_test.dart`

**Interfaces:**
- Consumes: `Receipt`, `ReceiptLine`, `Payment` (bekommt in Task 10 Kartenfelder, hier noch nicht), `BusinessInfo`, `TaxLine`
- Produces:

```dart
enum PrintAlign { left, center, right }
enum PrintSize { normal, doubleHeight, doubleBoth }
sealed class PrintOp { const PrintOp(); }
class PrintText extends PrintOp { const PrintText(this.text, {this.align = PrintAlign.left, this.bold = false, this.size = PrintSize.normal}); … }
class PrintFeed extends PrintOp { const PrintFeed(this.lines); … }
class PrintCut extends PrintOp { const PrintCut(); }
class PrintDrawerKick extends PrintOp { const PrintDrawerKick(); }

List<PrintOp> layoutReceipt(Receipt r, BusinessInfo business, {int columns = 48, int? voidedNumber, bool testMarker = true});
List<PrintOp> layoutTestPrint(BusinessInfo business, DateTime now, {int columns = 48});
String printable(String text);          // Zeichen, die der Drucker kann (siehe Regeln)
String amount(int cents);               // "18,20", "-2,90", "1.234,50", ohne Euro-Zeichen
```

**Regeln des Aufbaus** (jede `PrintText`-Zeile ist nach `printable` höchstens `columns` Zeichen lang, bei `doubleBoth` höchstens `columns ~/ 2`):

1. Kopf, zentriert: Name des Betriebs fett in `doubleBoth` (passt er nicht in `columns ~/ 2`, dann fett in normaler Größe, umbrochen), darunter die Adresszeilen, darunter `UID <vatId>`, wenn vorhanden.
2. Trennlinie: `'-' * columns`.
3. Bei einem Storno-Bon: zentriert und fett `STORNO`, darunter zentriert `zu Bon Nr. <voidedNumber>`.
4. Eine Zeile links `Bon Nr. <number>`, rechts Datum und Uhrzeit als `17.11.2026 11:00`. Darunter `Bedienung: <staffName>`. Trennlinie.
5. Je Bon-Zeile: links `<Menge> x <Name>` (mit `info` als `<Name> <info>`), rechts `amount(goodsCents)`. Passt links nicht neben den Betrag, wird am Wort umbrochen, der Betrag steht in der ersten Zeile, Folgezeilen sind 4 Zeichen eingerückt. Bei Menge über 1 oder unter -1 folgt eine Zeile `    je <amount(unitPriceCents)>`. Je Option eine Zeile `    <optionName>`, mit Aufpreis `    <optionName> (+2,00)`.
6. Trennlinie. Wenn `depositCents != 0`: links `Pfand`, rechts der Betrag. Dann links `SUMME EUR`, rechts `amount(totalCents)`, fett in `doubleHeight`. Trennlinie.
7. Je Steuersatz in der Reihenfolge von `taxLines`: links `<Satz> % MwSt <amount(taxCents)>  Netto <amount(netCents)>`, rechts `amount(grossCents)`.
8. Zahlung. Bar: links `Bar`, rechts `amount(amountCents)`. Wenn `givenCents != amountCents`, zwei weitere Zeilen `Gegeben` und `Rückgeld`. Karte: links `Karte`, rechts `amount(amountCents)`.
9. Wenn `receiptFooter` da ist: Leerzeile, der Text zentriert und umbrochen.
10. Wenn `testMarker`: Leerzeile, zentriert und fett `TESTBON`, darunter zentriert `Keine gültige Rechnung`.
11. Ende: `PrintFeed(3)`, `PrintCut()`.

`printable`: Buchstaben und Zeichen aus PC858 bleiben (darunter ä ö ü Ä Ö Ü ß é è à ç ñ €). Andere Buchstaben mit Akzent werden zum Grundbuchstaben (ở wird o, ū wird u), typografische Zeichen werden schlicht (" ' - ...), alles Übrige wird `?`. Tabulator und Zeilenumbruch werden ein Leerzeichen.

- [ ] **Step 1: Failing tests** (der Bon aus `test/support/sales.dart`: 2 × Cola, 1 × Huhn Bowl mit XXL und Nudeln, 18,20 €, gegeben 20,00 €)

```dart
String row(String l, String r, [int w = 48]) => l + ' ' * (w - l.length - r.length) + r;
List<String> texts(List<PrintOp> d) => [for (final o in d) if (o is PrintText) o.text];
const business = BusinessInfo(name: 'Beispiel-Imbiss', addressLines: ['Musterstraße 1', '1010 Wien'], vatId: 'ATU12345678', receiptFooter: 'Danke und bis bald!');

test('Barbon: Kopf, Zeilen, Pfand, Summe, Steuer, Zahlung, Ende', () async {
  final r = await saleOf(cart, given: 2000);                   // Helfer im Test, über TestShop
  final d = layoutReceipt(r, business);
  final t = texts(d);
  expect(d.first, isA<PrintText>().having((x) => x.size, 'size', PrintSize.doubleBoth).having((x) => x.text, 'text', 'Beispiel-Imbiss'));
  expect(t, containsAllInOrder([
    'Musterstraße 1', '1010 Wien', 'UID ATU12345678', '-' * 48,
    row('Bon Nr. 1', '17.11.2026 11:00'), 'Bedienung: Anna',
    row('2 x Cola 0,33 l', '5,80'), '    je 2,90',
    row('1 x Huhn Bowl', '11,90'), '    XXL (+2,00)', '    Nudeln',
    row('Pfand', '0,50'), row('SUMME EUR', '18,20'),
    row('20 % MwSt 0,97  Netto 4,83', '5,80'), row('10 % MwSt 1,08  Netto 10,82', '11,90'),
    row('Bar', '18,20'), row('Gegeben', '20,00'), row('Rückgeld', '1,80'),
    'Danke und bis bald!', 'TESTBON', 'Keine gültige Rechnung',
  ]));
  expect(d[d.length - 2], isA<PrintFeed>()); expect(d.last, isA<PrintCut>());
});
test('passend bezahlt: keine Zeilen Gegeben und Rückgeld', …);
test('Storno-Bon: STORNO, zu Bon Nr. 1, negative Beträge', () async {
  /* voidReceipt, layoutReceipt(v, business, voidedNumber: 1) */
  expect(t, containsAllInOrder(['STORNO', 'zu Bon Nr. 1', row('-2 x Cola 0,33 l', '-5,80'), row('SUMME EUR', '-18,20')]));
});
test('keine Zeile ist breiter als das Papier, auch bei 42 und 32 Zeichen', () {
  for (final w in [48, 42, 32]) {
    for (final o in layoutReceipt(longNames, business, columns: w).whereType<PrintText>()) {
      expect(o.text.length, lessThanOrEqualTo(o.size == PrintSize.doubleBoth ? w ~/ 2 : w));
    }
  }
}); // longNames: Artikel "Hausgemachte Teigtaschen mit Gemüsefüllung und Erdnuss-Sauce nach Art des Hauses", Menge 99, Preis 150,00
test('langer Name: Betrag steht rechts in der ersten Zeile, Rest eingerückt', …);
test('Zeichen, die der Drucker nicht kennt', () {
  expect(printable('Phở Bò'), 'Pho Bo'); expect(printable('Crème brûlée'), 'Crème brûlée');
  expect(printable('Größe 0,5 l – 3 €'), 'Größe 0,5 l - 3 €'); expect(printable('麻婆豆腐 Mapo'), '???? Mapo');
  expect(printable('a\tb\nc'), 'a b c');
});
test('ohne Adresse, UID und Bon-Ende fehlen die Zeilen, nichts ist leer gedruckt', …);
test('amount', () { expect(amount(0), '0,00'); expect(amount(-290), '-2,90'); expect(amount(123450), '1.234,50'); });
test('Testdruck nennt Betrieb, Zeit und zeigt ein Lineal über die volle Breite', () {
  final t = texts(layoutTestPrint(business, DateTime(2026, 11, 17, 11)));
  expect(t, containsAll(['Testdruck', '17.11.2026 11:00', '123456789012345678901234567890123456789012345678', 'ä ö ü ß € sind lesbar']));
});
```

- [ ] **Step 2:** FAIL prüfen. **Step 3:** Umsetzen, ohne Flutter und ohne Datenbank. **Step 4:** PASS, Commit.

### Task 4: ESC/POS-Bytes

**Files:**
- Create: `app/lib/devices/escpos.dart`
- Test: `app/test/devices/escpos_test.dart`

**Interfaces:**
- Consumes: `PrintOp` und Geschwister (Task 3)
- Produces: `Uint8List encodeEscPos(List<PrintOp> document)`, `Uint8List encodeDrawerKick()`, `int? pc858(int rune)` (Byte für ein Zeichen oder `null`), `const escposStatusPrinter = [0x10, 0x04, 0x01]`, `const escposStatusPaper = [0x10, 0x04, 0x04]`

**Befehle** (fest, nicht einstellbar): Start `1B 40`, Zeichensatz PC858 `1B 74 13`, Ausrichtung `1B 61 n` (0 links, 1 Mitte, 2 rechts), fett `1B 45 n`, Größe `1D 21 n` (normal `00`, doppelt hoch `01`, doppelt hoch und breit `11`), Zeilenende `0A`, Vorschub `1B 64 n`, Schnitt `1D 56 42 00`, Geldlade `1B 70 00 19 FA`. Jede Textzeile setzt Ausrichtung, fett und Größe nur, wenn sie sich gegenüber der vorigen Zeile ändern. Text wird vor dem Kodieren durch `printable` geschickt, ein Zeichen ohne Byte wird `3F`.

- [ ] **Step 1: Failing tests**

```dart
test('beginnt mit Start und Zeichensatz', () => expect(encodeEscPos([]).sublist(0, 5), [0x1B, 0x40, 0x1B, 0x74, 0x13]));
test('Umlaute und Euro in PC858', () {
  expect(pc858('ä'.runes.first), 0x84); expect(pc858('ö'.runes.first), 0x94); expect(pc858('ü'.runes.first), 0x81);
  expect(pc858('Ä'.runes.first), 0x8E); expect(pc858('Ö'.runes.first), 0x99); expect(pc858('Ü'.runes.first), 0x9A);
  expect(pc858('ß'.runes.first), 0xE1); expect(pc858('€'.runes.first), 0xD5); expect(pc858('A'.runes.first), 0x41);
  expect(pc858('麻'.runes.first), isNull);
});
test('eine fette zentrierte Zeile in doppelter Größe und danach eine normale', () {
  final b = encodeEscPos([const PrintText('AB', align: PrintAlign.center, bold: true, size: PrintSize.doubleBoth), const PrintText('c')]).sublist(5);
  expect(b, [0x1B, 0x61, 1, 0x1B, 0x45, 1, 0x1D, 0x21, 0x11, 0x41, 0x42, 0x0A,
             0x1B, 0x61, 0, 0x1B, 0x45, 0, 0x1D, 0x21, 0x00, 0x63, 0x0A]);
});
test('Vorschub, Schnitt, Geldlade', () {
  expect(encodeEscPos([const PrintFeed(3), const PrintCut()]).sublist(5), [0x1B, 0x64, 3, 0x1D, 0x56, 0x42, 0x00]);
  expect(encodeDrawerKick(), [0x1B, 0x70, 0x00, 0x19, 0xFA]);
  expect(encodeEscPos([const PrintDrawerKick()]).sublist(5), [0x1B, 0x70, 0x00, 0x19, 0xFA]);
});
test('ein ganzer Bon enthält nur Bytes, die der Drucker versteht', () { /* layoutReceipt aus Task 3, kein Byte ist 0x00 außerhalb von Befehlen: Länge > 200, endet mit dem Schnitt */ });
```

- [ ] **Step 2:** FAIL. **Step 3:** Umsetzen (Tabelle PC858 für 0x80 bis 0xFF als Konstante). **Step 4:** PASS, Commit.

### Task 5: Drucker-Schnittstelle, Druckdienst und Netzwerkdruck

**Files:**
- Create: `app/lib/devices/printer.dart`, `app/lib/devices/network_transport.dart`, `app/lib/devices/device_providers.dart`, `app/test/support/fake_devices.dart`
- Test: `app/test/devices/printer_test.dart`, `app/test/devices/network_transport_test.dart`

**Interfaces:**
- Consumes: `encodeEscPos`, `encodeDrawerKick`, `escposStatusPrinter`, `escposStatusPaper` (Task 4), `layoutReceipt`, `layoutTestPrint` (Task 3), `RegisterSettings.printer*` (Task 1), `settingsStreamProvider`, `catalogStreamProvider`, `receiptRepositoryProvider`
- Produces:

```dart
enum PrintProblem { notSetUp, unreachable, noPermission, paperOut, coverOpen, timeout }
class PrintOutcome { const PrintOutcome.ok(); const PrintOutcome.failed(this.problem); final PrintProblem? problem; bool get ok; String get message; }

abstract interface class PrinterTransport {
  /// Schickt die Bytes. Wirft [PrinterException] mit einem [PrintProblem].
  Future<void> send(Uint8List bytes);
  /// Schickt eine Zustandsfrage und gibt das Antwort-Byte zurück. `null`, wenn
  /// der Drucker binnen 1 Sekunde nicht antwortet oder die Frage scheitert.
  Future<int?> status(List<int> request);
}
class PrinterException implements Exception { const PrinterException(this.problem); final PrintProblem problem; }

abstract interface class ReceiptPrinter {
  Future<PrintOutcome> printReceipt(Receipt receipt);
  Future<PrintOutcome> openDrawer();
  Future<PrintOutcome> testPrint();
}
class EscPosPrinter implements ReceiptPrinter { EscPosPrinter({required PrinterTransport? transport, required BusinessInfo business, required int columns, required Clock clock, required Future<int?> Function(String receiptId) numberOfReceipt}); }

typedef TransportFactory = PrinterTransport? Function(RegisterSettings settings);
final transportFactoryProvider = Provider<TransportFactory>(…);   // none: null, network: NetworkTransport, usb und bluetooth: Task 6
final receiptPrinterProvider = Provider<ReceiptPrinter>(…);       // folgt Einstellungen und Betriebsdaten
```
- `NetworkTransport(String address)`: Adresse als `host` oder `host:port`, Vorgabe-Port 9100. Verbindung höchstens 3 Sekunden, das ganze Senden höchstens 5 Sekunden.
- `FakePrinter implements ReceiptPrinter` in `test/support/fake_devices.dart`: führt `log` (`List<String>` in der Reihenfolge der Aufrufe: `'drawer'`, `'print:<Bon-Id>'`, `'test'`), dazu `printed` (die Bon-Ids aus `log`), und hat `PrintOutcome next` (Vorgabe ok) sowie `Completer<void>? hold` (solange gesetzt, wartet jeder Aufruf darauf).

**Meldungen** (`PrintOutcome.message`): `notSetUp` "Kein Bondrucker eingerichtet.", `unreachable` "Drucker nicht bereit. Ist er eingeschaltet und verbunden?", `noPermission` "Kassa darf den Drucker nicht verwenden. Bitte die Erlaubnis geben.", `paperOut` "Drucker nicht bereit. Das Papier ist leer.", `coverOpen` "Drucker nicht bereit. Der Deckel ist offen.", `timeout` "Drucker nicht bereit. Er antwortet nicht."

**Zustand:** Vor jedem Druck fragt `EscPosPrinter` `transport.status(escposStatusPrinter)` ab. Antwort `null` oder ein Byte ohne Bit 3 (`0x08`): drucken. Bit 3 gesetzt heißt offline. Dann fragt er `transport.status(escposStatusPaper)`: Bits `0x60` gesetzt heißt Papier leer (`paperOut`), sonst `coverOpen`. Ein Fehler beim Abfragen ist kein Grund, nicht zu drucken.

- [ ] **Step 1: Failing tests**

```dart
// network_transport_test.dart: ein ServerSocket auf 127.0.0.1 als Drucker
test('schickt die Bytes an den Drucker', () async { /* send([1,2,3]) kommt am Server an */ });
test('niemand hört zu: PrinterException unreachable in unter 4 Sekunden', () async { /* Port ohne Server */ });
test('Adresse ohne Port nimmt 9100', () => expect(NetworkTransport('192.168.1.50').port, 9100));
test('Drucker antwortet auf die Zustandsfrage', () async { /* Server schickt 0x12 zurück, status(escposStatusPrinter) == 0x12 */ });
test('keine Antwort auf die Zustandsfrage ergibt null nach höchstens 1 Sekunde', …);

// printer_test.dart: ein RecordingTransport im Test
test('printReceipt schickt den gesetzten Bon', () async { /* Bytes == encodeEscPos(layoutReceipt(r, business)) */ });
test('Storno-Bon trägt die Nummer des stornierten Bons', …);
test('ohne Drucker: notSetUp, nichts wird geschickt', () async { /* transport: null */ });
test('Drucker offline mit leerem Papier: paperOut, nichts wird gedruckt', () async { /* status 0x1A, dann 0x72 */ });
test('Transport wirft: das Problem kommt als Ergebnis zurück, keine Ausnahme', …);
test('openDrawer schickt genau den Laden-Befehl', …);
test('Senden dauert länger als 5 Sekunden: timeout', () => fakeAsync(…));
```

- [ ] **Step 2:** FAIL. **Step 3:** Umsetzen. **Step 4:** PASS, Commit.

### Task 6: Druck über USB und Bluetooth (Kotlin-Kanal)

**Files:**
- Create: `app/android/app/src/main/kotlin/io/github/n1kob1ko/kassa/PrinterChannel.kt`, `app/lib/devices/channel_transport.dart`, `app/lib/devices/printer_discovery.dart`
- Modify: `app/android/app/src/main/kotlin/io/github/n1kob1ko/kassa/MainActivity.kt`, `app/android/app/src/main/AndroidManifest.xml`, `app/lib/devices/device_providers.dart`
- Test: `app/test/devices/channel_transport_test.dart`

**Interfaces:**
- Consumes: `PrinterTransport`, `PrinterException`, `PrintProblem` (Task 5)
- Produces:
  - Kanal `kassa/printer` (MethodChannel) mit den Methoden `listUsb` und `listBluetooth` (je eine Liste von `{name: String, address: String}`), `send` (`{kind: 'usb'|'bluetooth', address: String, bytes: Uint8List}`), `status` (`{kind, address, request: Uint8List}`, Antwort ein Byte oder `null`).
  - Fehlercodes des Kanals: `unreachable`, `no_permission`, `timeout`.
  - Adresse eines USB-Druckers: `'<vendorId>:<productId>'` dezimal. Adresse eines Bluetooth-Druckers: die MAC-Adresse.
  - `class ChannelTransport implements PrinterTransport { ChannelTransport(PrinterKind kind, String address); }`
  - `class FoundPrinter { const FoundPrinter({required this.kind, required this.name, required this.address}); }`
  - `abstract interface class PrinterDiscovery { Future<List<FoundPrinter>> usb(); Future<List<FoundPrinter>> bluetooth(); Future<List<FoundPrinter>> network(); }` mit `ChannelPrinterDiscovery` und `printerDiscoveryProvider`. `network()` kommt in Task 7, hier gibt es eine leere Liste zurück.

**Kotlin:** USB: Geräte mit einer Schnittstelle der Klasse 7 (Drucker) auflisten, vor dem Senden `UsbManager.requestPermission` und auf die Antwort warten (abgelehnt: `no_permission`), dann `bulkTransfer` auf den OUT-Endpunkt in Stücken von 4096 Bytes mit 5000 ms Zeitgrenze. Bluetooth: gekoppelte Geräte auflisten, Verbindung über `createRfcommSocketToServiceRecord` mit der SPP-Kennung `00001101-0000-1000-8000-00805F9B34FB`, Erlaubnis `BLUETOOTH_CONNECT` zur Laufzeit anfragen (ab Android 12), abgelehnt: `no_permission`. Alles Blockierende läuft auf einem eigenen Thread, die Antwort geht auf dem Haupt-Thread zurück. Manifest: `<uses-feature android:name="android.hardware.usb.host" android:required="false"/>`, `BLUETOOTH_CONNECT`, für Android bis 11 `BLUETOOTH` mit `maxSdkVersion="30"`.

- [ ] **Step 1: Failing tests** (Kanal mit `TestDefaultBinaryMessengerBinding` nachgestellt)

```dart
test('send reicht Art, Adresse und Bytes an den Kanal', …);
test('Fehlercode no_permission wird PrinterException(noPermission)', …);
test('Fehlercode unreachable und jeder unbekannte Code werden unreachable', …);
test('Fehlercode timeout wird timeout', …);
test('listUsb und listBluetooth werden zu FoundPrinter', …);
test('der Kanal fehlt (Test ohne Android): leere Listen, send wirft unreachable', …);
test('transportFactory: usb und bluetooth ergeben ChannelTransport, ohne Adresse null', …);
```

- [ ] **Step 2:** FAIL. **Step 3:** Dart und Kotlin umsetzen. **Step 4:** PASS, `flutter analyze`.
- [ ] **Step 5: Bau prüfen:** `../tool/build_apk.sh arm64` läuft durch. Die Datei wird nicht committet. Commit des Codes.

### Task 7: Bondrucker in den Einstellungen einrichten

**Files:**
- Create: `app/lib/features/settings/printer_panel.dart`, `app/lib/ui/address_keypad.dart`
- Modify: `app/lib/features/settings/settings_screen.dart`, `app/lib/devices/printer_discovery.dart`
- Test: `app/test/features/printer_settings_test.dart`, `app/test/golden/settings_golden_test.dart` (zwei neue Bilder)

**Interfaces:**
- Consumes: `printerDiscoveryProvider`, `FoundPrinter` (Task 6), `receiptPrinterProvider` (Task 5), `SettingsRepository.save`, `SettingsCard`, `SettingsRow`, `Segmented`, `PrimaryButton`, Pillen aus `settings_rows.dart`
- Produces: Schlüssel `Key('printer-row')`, `Key('printer-kind-<network|usb|bluetooth>')`, `Key('printer-found-<address>')`, `Key('printer-search')`, `Key('printer-address')`, `Key('printer-address-save')`, `Key('printer-width-<48|42>')`, `Key('printer-test')`, `Key('printer-remove')`, `Key('printer-result')`. `ChannelPrinterDiscovery.network()` sucht im eigenen Netz.

**Ablauf:** Die Zeile "Bondrucker" in "Geräte an dieser Kassa" zeigt eine Pille: ohne Drucker neutral "Nicht eingerichtet", mit Drucker "<Name>" mit grünem Punkt. Ein Tipp öffnet das Feld darunter in derselben Karte (wie das Feld beim neuen Einspielen, kein Dialog):

1. Wahl der Verbindung (`Segmented`): "Netzwerk", "USB", "Bluetooth".
2. Liste der gefundenen Drucker, jede Zeile 64 dp hoch, antippbar. Während der Suche drei graue Platzhalter-Zeilen. Nichts gefunden: je Verbindung ein Satz, was zu tun ist ("Kein Drucker gefunden. Ist er eingeschaltet und im selben WLAN?", "Kein Drucker am USB-Anschluss gefunden.", "Kein Drucker gekoppelt. Bitte zuerst in den Bluetooth-Einstellungen des Tablets koppeln."). Taste "Nochmal suchen".
3. Nur bei Netzwerk: Taste "Adresse eintippen" öffnet ein Zahlenfeld mit Ziffern, Punkt und Löschen (`AddressKeypad`, kein Textfeld). "Übernehmen" ist erst aktiv, wenn vier Zahlen von 0 bis 255 dastehen.
4. Nach der Wahl: Der Drucker ist gespeichert (Art, Adresse, Name), es erscheinen "Testdruck" (Hauptaktion), die Breite (`Segmented` "Normal" für 48 und "Schmal" für 42, Hilfetext "Schmal wählen, wenn der Testdruck am Rand umbricht.") und "Drucker entfernen".
5. Das Ergebnis des Testdrucks steht als Satz darunter (`printer-result`): "Testdruck geschickt. Kommt Papier?" oder die Meldung aus `PrintOutcome.message`.

**Netzsuche:** eigene IPv4-Adresse des WLANs über `NetworkInterface.list`, dann alle 254 Adressen desselben /24-Netzes auf Port 9100 probieren, je 400 ms Zeitgrenze, höchstens 32 gleichzeitig. Gefundene heißen "Drucker <Adresse>". Die Suche ist hinter `PrinterDiscovery` und wird in Tests ersetzt.

- [ ] **Step 1: Failing tests**

```dart
testWidgets('ohne Drucker steht "Nicht eingerichtet"', …);
testWidgets('Netzwerk: gefundenen Drucker antippen speichert Art, Adresse und Name', (t) async {
  await pumpSettings(t, discovery: FakeDiscovery(network: [const FoundPrinter(kind: PrinterKind.network, name: 'Drucker 192.168.1.50', address: '192.168.1.50:9100')]));
  await t.tap(find.byKey(const Key('printer-row'))); await t.pumpAndSettle();
  await t.tap(find.byKey(const Key('printer-found-192.168.1.50:9100'))); await t.pumpAndSettle();
  final s = await settingsOf(t);
  expect(s.printerKind, PrinterKind.network); expect(s.printerAddress, '192.168.1.50:9100'); expect(s.printerName, 'Drucker 192.168.1.50');
});
testWidgets('Adresse eintippen: 192.168.1.50 wird übernommen, 192.168.1 nicht, 300.1.1.1 nicht', …);
testWidgets('Testdruck: Erfolg und Fehler stehen als Satz da', (t) async { /* FakePrinter.next = failed(unreachable): "Drucker nicht bereit. Ist er eingeschaltet und verbunden?" */ });
testWidgets('Schmal stellt 42 Zeichen ein', …);
testWidgets('Drucker entfernen setzt alles zurück', …);
testWidgets('nichts gefunden: der Satz passt zur Verbindung, Nochmal suchen sucht neu', …);
testWidgets('Suche wirft: es steht "Die Suche hat nicht geklappt." und Nochmal suchen', …);
testWidgets('alle Tippflächen im Feld sind mindestens 48 dp hoch', …);
```
`pumpSettings` bekommt die freiwilligen Parameter `discovery` und `printer`.

- [ ] **Step 2:** FAIL. **Step 3:** Umsetzen. **Step 4:** PASS, Bildvergleiche (hell und dunkel, Feld offen mit gefundenem Drucker) erzeugen und ansehen, Commit.

### Task 8: Verkaufsdienst: speichern, drucken, Lade öffnen, nochmal drucken

**Files:**
- Create: `app/lib/features/kassa/sale_service.dart`
- Modify: `app/lib/data/receipt_repository.dart`, `app/lib/features/kassa/cash_sheet.dart`, `app/lib/features/kassa/sale_done.dart`, `app/lib/features/kassa/kassa_screen.dart`, `app/lib/features/bons/receipt_detail.dart`, `app/lib/features/bons/void_question.dart`, `app/test/support/pump.dart`
- Test: `app/test/features/sale_service_test.dart`, `app/test/features/cash_test.dart`, `app/test/features/bons_test.dart`, `app/test/data/receipt_repository_test.dart`

**Interfaces:**
- Consumes: `ReceiptPrinter`, `PrintOutcome`, `receiptPrinterProvider`, `FakePrinter` (Task 5), `RegisterSettings.cashDrawerEnabled`, `RegisterSettings.printerKind`
- Produces:

```dart
class SaleResult { const SaleResult({required this.receipt, required this.print}); final Receipt receipt; final Future<PrintOutcome> print; }
class SaleService {
  Future<SaleResult> completeCash({required String saleId, required Cart cart, required int givenCents, required Staff staff});
  Future<PrintOutcome> reprint(Receipt receipt);
  Future<SaleResult> voidReceipt(String receiptId, {required Staff staff});   // Storno-Bon speichern und drucken
}
final saleServiceProvider = Provider<SaleService>(…);
```
- `ReceiptRepository.finalizeCashSale` löscht im selben Datenbank-Schritt den Bon-Entwurf (`settings.receipt_draft = NULL`). Ein Absturz direkt nach dem Speichern lässt also keinen Entwurf zurück, der denselben Verkauf noch einmal anbietet.
- Schlüssel: `Key('print-state')`, `Key('reprint')` in der Fertig-Ansicht, `Key('print-receipt')` im Bon-Detail.
- Testumgebung: `memoryOverrides` setzt `receiptPrinterProvider` auf einen `FakePrinter`, den Tests über `printerOf(t)` erreichen.

**Verhalten:**
- `completeCash` wartet auf die Datenbank, nicht auf den Drucker. `SaleResult.print` läuft weiter und endet nach höchstens 5 Sekunden.
- Reihenfolge nach dem Speichern: wenn `cashDrawerEnabled` und ein Drucker eingerichtet ist, zuerst Lade öffnen, dann Bon drucken. Ohne Drucker passiert beides nicht und `print` ergibt `notSetUp`.
- Die Hauptaktion im Bar-Blatt heißt "Abschließen und Bon drucken", wenn ein Drucker eingerichtet ist, sonst "Abschließen".
- Fertig-Ansicht, Zeile `print-state` unter der Bon-Nummer: während des Drucks "Bon wird gedruckt …", danach "Bon gedruckt". Bei einem Problem die Meldung in `warnBg` und daneben die Taste "Nochmal drucken" (64 dp). Ohne Drucker fehlt die Zeile. "Nächster Kunde" ist immer sofort aktiv.
- Bon-Detail: Taste "Drucken" (72 dp, Symbol `printer`) neben "Stornieren", nur mit eingerichtetem Drucker. Das Ergebnis erscheint als Hinweis unten (wie der Rückgängig-Hinweis, ohne Rückgängig).
- Storno: Der Storno-Bon wird gedruckt, die Lade öffnet nicht.

- [ ] **Step 1: Failing tests**

```dart
// receipt_repository_test.dart
test('Abschließen löscht den Bon-Entwurf im selben Schritt', () async {
  await settings.writeDraft('{"x":1}');
  await shop.receipts.finalizeCashSale(saleId: 's1', cart: cart, givenCents: 2000, staff: shop.anna);
  expect(await settings.readDraft(), isNull);
});
test('scheitert das Speichern, bleibt der Entwurf', () async { /* leerer Bon wirft, Entwurf noch da */ });

// sale_service_test.dart
test('Bar mit Lade: erst Lade, dann Bon', () async { expect(printer.log, ['drawer', 'print:s1']); });
test('Lade ausgeschaltet: nur Bon', …);
test('ohne Drucker: Bon gespeichert, print ergibt notSetUp, nichts geschickt', …);
test('Drucker scheitert: der Bon ist trotzdem da, genau einmal', () async {
  printer.next = const PrintOutcome.failed(PrintProblem.unreachable);
  final r = await service.completeCash(saleId: 's1', cart: cart, givenCents: 2000, staff: shop.anna);
  expect((await r.print).ok, isFalse); expect(await receiptCountOf(shop), 1);
});
test('Drucker hängt: completeCash kommt sofort zurück', () => fakeAsync(…));
test('zweimal dieselbe saleId: ein Bon, ein Druck', …);
test('Storno druckt den Storno-Bon und öffnet die Lade nicht', …);

// cash_test.dart
testWidgets('mit Drucker heißt die Taste "Abschließen und Bon drucken", ohne "Abschließen"', …);
testWidgets('Fertig-Ansicht: "Bon gedruckt"', …);
testWidgets('Drucker nicht bereit: Meldung, Nochmal drucken druckt erneut, Nächster Kunde geht sofort', (t) async {
  printerOf(t).next = const PrintOutcome.failed(PrintProblem.paperOut);
  /* Abschließen */ expect(textOf(t, const Key('print-state')), 'Drucker nicht bereit. Das Papier ist leer.');
  printerOf(t).next = const PrintOutcome.ok();
  await t.tap(find.byKey(const Key('reprint'))); await t.pumpAndSettle();
  expect(textOf(t, const Key('print-state')), 'Bon gedruckt'); expect(printerOf(t).printed, hasLength(2));
});
// bons_test.dart
testWidgets('Drucken im Bon-Detail druckt genau diesen Bon', …);
testWidgets('ohne Drucker gibt es die Taste Drucken nicht', …);
```

- [ ] **Step 2:** FAIL. **Step 3:** Umsetzen. `CashSheet` und die Storno-Frage rufen nur noch den `SaleService`. **Step 4:** PASS (`flutter test test/features test/data`), Bildvergleiche der Fertig-Ansicht und des Bon-Details neu erzeugen und ansehen, Commit.

### Task 9: Seite "Geräte testen"

**Files:**
- Create: `app/lib/features/settings/device_test_screen.dart`
- Modify: `app/lib/features/settings/settings_screen.dart`
- Test: `app/test/features/device_test_test.dart`, ein Bildvergleich hell und dunkel

**Interfaces:**
- Consumes: `receiptPrinterProvider`, `settingsStreamProvider`, `SettingsCard`, Pillen
- Produces: Schlüssel `Key('open-device-test')`, `Key('test-printer')`, `Key('test-drawer')`, `Key('test-card')`, `Key('result-printer')`, `Key('result-drawer')`, `Key('result-card')`, `Key('device-test-back')`. Widget `DeviceTestRow({required String title, required String help, required String action, required Future<DeviceTestResult> Function() run, …})` und `class DeviceTestResult { const DeviceTestResult.ok(this.message); const DeviceTestResult.problem(this.message); }`, damit Task 12 die Zeile "Kartenterminal" füllen kann.

**Aufbau:** In "Geräte an dieser Kassa" kommt unten eine Zeile "Geräte testen" mit Pfeil. Sie öffnet eine eigene Seite im Bereich Einstellungen mit "Zurück" oben links. Drei Zeilen, je 88 dp hoch: Titel, ein Satz Hilfe, rechts eine Taste (64 dp). Nach dem Tipp steht unter der Zeile das Ergebnis als Pille mit Satz: in Ordnung (grüner Punkt) oder Problem (`warnBg`).
- "Bondrucker", Taste "Testdruck": Ergebnis "Testdruck geschickt. Kommt Papier?" oder die Druckmeldung.
- "Geldlade", Taste "Lade öffnen": "Befehl geschickt. Ist die Lade aufgegangen?" oder die Druckmeldung. Ist die Lade in den Einstellungen aus, steht statt der Taste "Ausgeschaltet".
- "Kartenterminal": in dieser Aufgabe die Zeile mit dem festen Ergebnis "Noch nicht eingerichtet." ohne Taste. Task 12 ersetzt sie.

Während ein Test läuft, zeigt die Taste einen Fortschrittsring und nimmt keinen zweiten Tipp an.

- [ ] **Step 1: Failing tests:** Testdruck ok und mit Problem, Lade öffnen ok, Lade ausgeschaltet, zwei schnelle Tipps lösen einen Test aus, Zurück führt in die Einstellungen, Tippflächen mindestens 48 dp.
- [ ] **Step 2:** FAIL. **Step 3:** Umsetzen. **Step 4:** PASS, Bildvergleiche, Commit.

### Task 10: Kartenterminal-Schnittstelle und Kartenzahlung im Kern

**Files:**
- Create: `app/lib/devices/card_terminal.dart`, `app/lib/data/card_payment_repository.dart`
- Modify: `app/lib/domain/receipt.dart`, `app/lib/data/receipt_repository.dart`, `app/lib/data/providers.dart`, `app/lib/devices/device_providers.dart`, `app/lib/features/kassa/sale_service.dart`, `app/lib/domain/receipt_layout.dart`, `app/test/support/fake_devices.dart`, `app/test/support/pump.dart`
- Test: `app/test/data/card_payment_repository_test.dart`, `app/test/features/sale_service_test.dart`, `app/test/data/receipt_repository_test.dart`, `app/test/data/day_repository_test.dart`, `app/test/data/stats_repository_test.dart`, `app/test/domain/receipt_layout_test.dart`

**Interfaces:**
- Consumes: Tabelle `pending_card_payments`, Spalten `payments.provider…` (Task 1), `SaleService` (Task 8)
- Produces:

```dart
// card_terminal.dart
enum CardTerminalState { notConfigured, loggedOut, ready }
class CardTerminalStatus { const CardTerminalStatus(this.state, {this.merchantName}); … }
enum CardFailure { declined, cancelled, noInternet, notLoggedIn, noReader, permission, other }
sealed class CardPaymentResult {}
class CardPaid extends CardPaymentResult { const CardPaid({required this.txCode, this.cardScheme, this.cardLast4}); … }
class CardFailed extends CardPaymentResult { const CardFailed(this.failure, {this.detail}); String get message; … }
class CardUnknown extends CardPaymentResult { const CardUnknown(); }
abstract interface class CardTerminal {
  String get providerName;                       // 'sumup'
  int get minimumCents;                          // 100
  Future<CardTerminalStatus> status();
  Future<CardTerminalStatus> login();
  Future<void> logout();
  Future<void> openReaderSettings();
  Future<void> prepare();
  Future<CardPaymentResult> pay({required String paymentId, required int amountCents, required String title});
}
final cardTerminalProvider = Provider<CardTerminal>(…);     // bis Task 11 ein Terminal, das immer notConfigured meldet

// receipt.dart: Payment bekommt provider, providerTxCode, cardScheme, cardLast4 (alle String?, Vorgabe null)

// card_payment_repository.dart
class PendingCardPayment { id, cartJson, amountCents, staffId, staffName, startedAt, unknown (bool) }
class CardPaymentRepository {
  Future<void> begin({required String paymentId, required Cart cart, required Staff staff});
  Future<void> markUnknown(String paymentId);
  Future<void> discard(String paymentId);
  Future<List<PendingCardPayment>> pending();
  Stream<List<PendingCardPayment>> watchPending();
}

// receipt_repository.dart
Future<Receipt> finalizeCardSale({required String saleId, required Cart cart, required Staff staff, required String provider, String? txCode, String? cardScheme, String? cardLast4});
// löscht im selben Schritt den Entwurf und die Zeile in pending_card_payments mit dieser Id

// sale_service.dart
sealed class CardSaleOutcome {}
class CardSaleDone extends CardSaleOutcome { final SaleResult sale; }
class CardSaleFailed extends CardSaleOutcome { final String message; }
class CardSaleUnclear extends CardSaleOutcome { final String paymentId; }
Future<CardSaleOutcome> payByCard({required String paymentId, required Cart cart, required Staff staff});
Future<SaleResult> confirmUnclear(PendingCardPayment p, {required Catalog catalog});
Future<void> discardUnclear(PendingCardPayment p);
```
- `FakeCardTerminal` in `fake_devices.dart`: `statusValue`, `next` (ein `CardPaymentResult` oder eine Funktion), `payments` (Liste der Aufrufe), `Completer`-Variante für "hängt".

**Ablauf von `payByCard`:**
1. `amountCents < terminal.minimumCents` oder leerer Bon: `CardSaleFailed` ohne Aufruf des Terminals.
2. `begin` schreibt die offene Zahlung in die Datenbank, bevor das Terminal etwas erfährt.
3. `terminal.pay(paymentId, amountCents, title: 'Bon <Betrieb>')`.
4. `CardPaid`: `finalizeCardSale` (Bon, Zahlung mit `provider`, `txCode`, Kartenart und letzten vier Ziffern, Entwurf weg, offene Zahlung weg, alles in einem Schritt), dann Druck wie bei Bar, aber ohne Lade.
5. `CardFailed`: offene Zahlung verwerfen, der Bon bleibt offen, `CardSaleFailed(message)`.
6. `CardUnknown` oder eine Ausnahme aus `pay`: `markUnknown`, `CardSaleUnclear`. Der offene Bon wird geleert (er steckt in der offenen Zahlung), damit er nicht ein zweites Mal kassiert wird.
7. Läuft schon eine Kartenzahlung, kommt ein zweiter Aufruf sofort mit `CardSaleFailed('Es läuft schon eine Kartenzahlung.')` zurück.

`confirmUnclear` baut den Bon aus `cartJson` (`Cart.fromJson` mit dem heutigen Katalog) und schließt ihn als Kartenzahlung ohne `txCode` ab. Lässt sich der Bon nicht mehr lesen, bleibt die offene Zahlung stehen und es kommt eine Ausnahme mit Text für die Oberfläche. `discardUnclear` verwirft die offene Zahlung und setzt den Bon wieder ein (`cartProvider.restore`).

**Meldungen** (`CardFailed.message`): `declined` "Die Karte wurde abgelehnt.", `cancelled` "Kartenzahlung abgebrochen.", `noInternet` "Kein Internet. Kartenzahlung geht gerade nicht.", `notLoggedIn` "SumUp ist nicht angemeldet. Bitte in den Einstellungen anmelden.", `noReader` "Kein Kartenleser verbunden. Bitte in den Einstellungen verbinden.", `permission` "Kassa braucht die Erlaubnis für Bluetooth und Standort.", `other` "Die Kartenzahlung hat nicht geklappt." mit `detail` in Klammern, wenn vorhanden.

**Bon:** Bei Karte druckt `layoutReceipt` nach der Zeile `Karte`: `<cardScheme> **** <cardLast4>` (wenn bekannt) und `Beleg <txCode>` (wenn bekannt).

- [ ] **Step 1: Failing tests**

```dart
// sale_service_test.dart
test('Karte bezahlt: ein Bon mit Kartenzahlung, offene Zahlung weg, Entwurf weg, gedruckt ohne Lade', () async {
  terminal.next = const CardPaid(txCode: 'TX1', cardScheme: 'MASTERCARD', cardLast4: '1234');
  final o = await service.payByCard(paymentId: 'p1', cart: cart, staff: shop.anna) as CardSaleDone;
  expect(o.sale.receipt.payment.kind, PaymentKind.card); expect(o.sale.receipt.payment.providerTxCode, 'TX1');
  expect(o.sale.receipt.id, 'p1'); expect(await cardPayments.pending(), isEmpty); expect(printer.log, ['print:p1']);
  expect(terminal.payments.single.amountCents, 1820);
});
test('abgelehnt: kein Bon, keine offene Zahlung, Meldung', …);
test('unklar: kein Bon, offene Zahlung bleibt als unklar', …);
test('pay wirft: wie unklar', …);
test('die offene Zahlung steht in der Datenbank, bevor das Terminal gerufen wird', () async {
  terminal.next = () async { expect((await cardPayments.pending()).single.id, 'p1'); return const CardFailed(CardFailure.cancelled); };
  await service.payByCard(paymentId: 'p1', cart: cart, staff: shop.anna);
});
test('unter 1,00 €: kein Aufruf des Terminals', …);
test('zweiter Aufruf während einer laufenden Zahlung: abgewiesen, ein Aufruf am Terminal', …);
test('unklar bestätigen: Bon als Karte ohne Beleg-Code, offene Zahlung weg', …);
test('unklar verwerfen: kein Bon, offene Zahlung weg, Bon wieder eingesetzt', …);
test('dieselbe paymentId zweimal bezahlt gemeldet: ein Bon', …);
// receipt_repository_test.dart
test('Storno eines Karten-Bons: Storno-Bon mit Zahlungsart Karte und negativem Betrag', …);
// day_repository_test.dart, stats_repository_test.dart
test('Abschluss trennt Bar und Karte: 18,20 bar, 9,90 Karte, erwartetes Bargeld zählt nur bar', …);
test('Übersicht zählt den Kartenanteil', …);
// receipt_layout_test.dart
test('Kartenbon: Karte, MASTERCARD **** 1234, Beleg TX1, keine Zeile Gegeben', …);
```

- [ ] **Step 2:** FAIL. **Step 3:** Umsetzen. **Step 4:** PASS (`flutter test test/data test/domain test/features/sale_service_test.dart`), Commit.

### Task 11: SumUp anbinden (Gradle, Kotlin, Dart)

**Files:**
- Create: `app/android/app/src/main/kotlin/io/github/n1kob1ko/kassa/KassaApplication.kt`, `…/SumUpChannel.kt`, `…/InternetChannel.kt`, `app/lib/devices/sumup_terminal.dart`, `app/lib/devices/internet.dart`
- Modify: `app/android/build.gradle.kts`, `app/android/app/build.gradle.kts`, `app/android/app/src/main/AndroidManifest.xml`, `…/MainActivity.kt`, `app/lib/devices/device_providers.dart`, `tool/build_apk.sh`, `.gitignore` (`sumup.properties`)
- Test: `app/test/devices/sumup_terminal_test.dart`, `app/test/devices/internet_test.dart`

**Interfaces:**
- Consumes: `CardTerminal` und Ergebnis-Typen (Task 10)
- Produces:
  - `class SumUpTerminal implements CardTerminal` über den Kanal `kassa/sumup` mit den Methoden `status` (Antwort `{configured: bool, loggedIn: bool, merchant: String?}`), `login`, `logout`, `openReaderPage`, `prepare`, `pay` (`{paymentId, amountCents, title}`, Antwort `{resultCode: int, message: String?, txCode: String?, cardType: String?, last4: String?}`).
  - `CardPaymentResult mapSumUpResult(Map<Object?, Object?> raw)`: 1 wird `CardPaid` (ohne `txCode` in der Antwort: `CardUnknown`), 2 `declined`, 3 und 7 `permission`, 6 `noInternet`, 8 `notLoggedIn`, 14 `noReader`, 15 `CardUnknown`, 9 `CardUnknown` (die Kennung wurde schon einmal verwendet, also ist offen, was mit der ersten Zahlung war), alles andere `other` mit `message` als `detail`. Antwort `null` (Bildschirm geschlossen ohne Ergebnis) wird `cancelled`.
  - `abstract interface class Internet { Stream<bool> watch(); }`, `ChannelInternet` über `kassa/internet` (EventChannel), `internetProvider` (`StreamProvider<bool>`, in Tests überschrieben, Vorgabe `true`).
  - `cardTerminalProvider` liefert `SumUpTerminal`.

**Gradle:**
- `android/build.gradle.kts`: in `allprojects.repositories` zusätzlich `maven { url = uri("https://maven.sumup.com/releases") }`.
- `android/app/build.gradle.kts`: `minSdk = 26`, in `compileOptions` `isCoreLibraryDesugaringEnabled = true`, `buildFeatures { buildConfig = true }`, im `dependencies`-Block:

```kotlin
coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
implementation(platform("androidx.compose:compose-bom:2024.09.00"))
implementation("com.sumup:merchant-sdk:7.2.0")
```
- Der Schlüssel: Die Umgebungsvariable `KASSA_SUMUP_PROPERTIES` zeigt auf eine Datei mit der Zeile `affiliateKey=…`. Gradle liest sie und setzt `buildConfigField("String", "SUMUP_AFFILIATE_KEY", …)`. Ohne Variable oder Datei ist der Wert leer. `tool/build_apk.sh` setzt die Variable auf `$KASSA_BUILD_DIR/sumup.properties`, wenn die Datei existiert, und sagt sonst in einer Zeile, dass ohne Kartenzahlung gebaut wird.

**Kotlin:**
- `KassaApplication : Application` ruft in `onCreate` `SumUpState.init(this)`, im Manifest als `android:name` eingetragen.
- `SumUpChannel`: `status` meldet `configured = BuildConfig.SUMUP_AFFILIATE_KEY.isNotEmpty()`, `loggedIn = SumUpAPI.isLoggedIn()`, `merchant` aus `SumUpAPI.getCurrentMerchant()`. `login` öffnet `SumUpAPI.openLoginActivity(activity, SumUpLogin.builder(key).build(), REQUEST_LOGIN)`. `pay` baut `SumUpPayment.builder().total(BigDecimal.valueOf(amountCents, 2)).currency(SumUpPayment.Currency.EUR).title(title).foreignTransactionId(paymentId).skipSuccessScreen().configureRetryPolicy(2000, 60000, true).build()` und ruft `SumUpAPI.checkout(activity, payment, REQUEST_PAY)`. `openReaderPage` ruft `SumUpAPI.openCardReaderPage(activity, REQUEST_READER)`, `prepare` ruft `SumUpAPI.prepareForCheckout()`.
- Ergebnisse kommen über `MainActivity.onActivityResult` (die Aktivität bleibt `FlutterActivity`, darum die Aufrufe mit Anfrage-Nummer und nicht die Result-Verträge). Zu jeder Anfrage-Nummer wartet höchstens ein `MethodChannel.Result`. Kommt ein zweiter Aufruf, solange einer wartet, bekommt er den Fehler `busy`.
- Den Fehlschlag-Bildschirm von SumUp lassen wir stehen (kein `skipFailedScreen`): Der Kunde sieht dort, warum die Karte nicht ging.
- `InternetChannel`: `ConnectivityManager.registerDefaultNetworkCallback`, meldet `true`, wenn das Standardnetz `NET_CAPABILITY_VALIDATED` hat, sonst `false`. Erlaubnis `ACCESS_NETWORK_STATE` und `INTERNET` im Manifest.

- [ ] **Step 1: Failing tests** (Kanal nachgestellt)

```dart
test('Ergebnis-Codes werden richtig übersetzt', () {
  expect(mapSumUpResult({'resultCode': 1, 'txCode': 'TX1', 'cardType': 'VISA', 'last4': '4242'}), isA<CardPaid>().having((p) => p.txCode, 'txCode', 'TX1').having((p) => p.cardLast4, 'last4', '4242'));
  expect(mapSumUpResult({'resultCode': 1}), isA<CardUnknown>());
  expect((mapSumUpResult({'resultCode': 2}) as CardFailed).failure, CardFailure.declined);
  expect((mapSumUpResult({'resultCode': 6}) as CardFailed).failure, CardFailure.noInternet);
  expect((mapSumUpResult({'resultCode': 8}) as CardFailed).failure, CardFailure.notLoggedIn);
  expect((mapSumUpResult({'resultCode': 14}) as CardFailed).failure, CardFailure.noReader);
  expect(mapSumUpResult({'resultCode': 15}), isA<CardUnknown>());
  expect(mapSumUpResult({'resultCode': 9}), isA<CardUnknown>());
  expect((mapSumUpResult({'resultCode': 4, 'message': 'x'}) as CardFailed).detail, 'x');
});
test('pay schickt Kennung, Cent und Titel', …);
test('Antwort null wird abgebrochen', …);
test('Kanal-Fehler busy wird "Es läuft schon eine Kartenzahlung."', …);
test('status ohne Schlüssel: notConfigured, mit Schlüssel abgemeldet: loggedOut, angemeldet: ready mit Namen', …);
test('der Kanal fehlt (Test ohne Android): notConfigured, pay ergibt CardFailed other', …);
test('minimumCents ist 100, providerName ist sumup', …);
test('Internet: der Strom reicht true und false durch, ohne Kanal true', …);
```

- [ ] **Step 2:** FAIL. **Step 3:** Umsetzen. **Step 4:** PASS, `flutter analyze`.
- [ ] **Step 5: Bau prüfen.** `../tool/build_apk.sh arm64` läuft durch, mit und ohne `sumup.properties`. Mit `~/android-sdk/build-tools/36.0.0/aapt2 dump permissions <apk>` nachsehen, welche Erlaubnisse das SDK mitbringt, und sie im Commit-Text nennen. Die Größe der Datei notieren. Die Datei wird nicht committet. Kein Schlüssel und keine `sumup.properties` im Commit (`git status` prüfen). Commit.

### Task 12: Karte an der Kassa und in den Einstellungen

**Files:**
- Create: `app/lib/features/kassa/card_wait.dart`, `app/lib/features/settings/card_panel.dart`
- Modify: `app/lib/features/kassa/cart_panel.dart`, `app/lib/features/kassa/kassa_screen.dart`, `app/lib/features/kassa/sale_done.dart`, `app/lib/features/settings/settings_screen.dart`, `app/lib/features/settings/device_test_screen.dart`, `app/lib/features/bons/void_question.dart`, `app/lib/ui/app_header.dart`
- Test: `app/test/features/card_test.dart`, `app/test/features/card_settings_test.dart`, `app/test/features/bons_test.dart`, Bildvergleiche

**Interfaces:**
- Consumes: `SaleService.payByCard`, `CardSaleOutcome`, `cardTerminalProvider`, `FakeCardTerminal`, `internetProvider`, `DeviceTestRow`
- Produces: Schlüssel `Key('pay-card')` (bleibt), `Key('card-wait')`, `Key('card-message')`, `Key('card-row')`, `Key('card-login')`, `Key('card-logout')`, `Key('card-reader')`, `Key('test-card')`. `final cardStatusProvider = FutureProvider<CardTerminalStatus>(…)` (wird nach Anmelden, Abmelden und beim Zurückkommen in die App neu geholt).

**Taste "Karte"** (unter dem Bon, `solid`): aktiv, wenn der Bon nicht leer ist, das Terminal `ready` meldet, Internet da ist und die Summe mindestens 1,00 € beträgt. Sonst ausgeschaltet mit einer kleinen Zeile unter dem Wort, die den ersten zutreffenden Grund nennt: "nicht eingerichtet" (`notConfigured`), "nicht angemeldet" (`loggedOut`), "kein Internet", "ab 1,00 €". Bei leerem Bon steht keine Zeile da. "Bar" ist davon nie betroffen.

**Ablauf:** Tipp auf "Karte" erzeugt eine neue `paymentId` (uuid) und zeigt rechts statt des Bons "Warte auf Karte" (`card-wait`: Karte in `accentSoft`, pulsierender Punkt 14 dp, Titel "Warte auf Karte", Betrag groß, Hinweis "Der Kunde hält Karte oder Handy an das Gerät."). SumUp legt seinen eigenen Bildschirm darüber, abgebrochen wird dort. Danach:
- bezahlt: Fertig-Ansicht mit "Mit Karte bezahlt" statt des Rückgelds, darunter Kartenart und letzte vier Ziffern, Druckzeile wie bei Bar.
- gescheitert: zurück zum Bon, die Meldung steht 6 Sekunden als Hinweis unten (`card-message`), der Bon ist unverändert.
- unklar: die Frage aus Task 13.

Beim Öffnen des Kassenbildschirms und nach jedem Bon ruft die Kassa `terminal.prepare()`, wenn das Terminal `ready` ist (Fehler werden verschluckt).

**Kopfzeile:** Die Pille für das Netz zeigt bei fehlendem Internet "Kein Internet. Bar bonieren geht weiter." in `warnBg`, sonst nichts Neues.

**Einstellungen, Zeile "Kartenterminal"** (`card-row`): Pille "Nicht eingerichtet" (neutral, Hilfetext "Diese Version wurde ohne SumUp gebaut."), "Nicht angemeldet" (`warnBg`) mit Taste "Bei SumUp anmelden", oder "<Name des Händlers>" mit grünem Punkt und zwei Tasten "Kartenleser verbinden" (öffnet die SumUp-Seite für das Gerät) und "Abmelden". Abmelden fragt in der Zeile nach ("Wirklich abmelden?" mit "Abmelden" und "Doch nicht"), kein Dialog.

**Geräte testen, Zeile "Kartenterminal":** Taste "Prüfen". Ergebnis: "Nicht eingerichtet.", "Nicht bei SumUp angemeldet.", "Kein Internet." oder "Angemeldet als <Name>. Für einen echten Test 1,00 € mit Karte bonieren und danach stornieren."

**Storno eines Karten-Bons:** Die Storno-Frage zeigt zusätzlich in `warnBg`: "Das Geld geht nicht von selbst zurück. Bitte die Zahlung in der SumUp-App rückbuchen." Die Taste heißt "Stornieren, Rückbuchung mache ich in SumUp".

- [ ] **Step 1: Failing tests**

```dart
testWidgets('Karte ist aktiv bei Bon, Anmeldung, Internet und mindestens 1,00 €', …);
testWidgets('Gründe unter der Taste: nicht eingerichtet, nicht angemeldet, kein Internet, ab 1,00 €', (t) async {
  /* je Zustand: onPressed == null und der Text steht da; Bar bleibt aktiv */
});
testWidgets('bezahlt: Fertig-Ansicht "Mit Karte bezahlt", VISA **** 4242, Bon Nr. 1, Bon ist leer', …);
testWidgets('abgelehnt: Meldung "Die Karte wurde abgelehnt.", der Bon steht noch da, kein Bon gespeichert', …);
testWidgets('zwei schnelle Tipps auf Karte: ein Aufruf am Terminal', …);
testWidgets('während der Zahlung steht "Warte auf Karte" mit dem Betrag', (t) async { /* Terminal hängt am Completer */ });
testWidgets('jeder Tipp auf Karte nimmt eine neue Kennung', …);
testWidgets('Internet fällt weg: Kopfzeile meldet es, Karte geht aus, Bar bleibt', …);
testWidgets('Einstellungen: Anmelden ruft login und zeigt danach den Händler', …);
testWidgets('Einstellungen: Abmelden fragt nach, Doch nicht lässt alles stehen', …);
testWidgets('Einstellungen: Kartenleser verbinden öffnet die Seite von SumUp', …);
testWidgets('Geräte testen: die vier Ergebnisse', …);
testWidgets('Storno eines Karten-Bons zeigt den Hinweis zur Rückbuchung, bei Bar nicht', …);
testWidgets('kleines Tablet 960 × 600 und Schrift 1,3: Karte und Bar bleiben ganz sichtbar', …);
```

- [ ] **Step 2:** FAIL. **Step 3:** Umsetzen. **Step 4:** PASS, Bildvergleiche (Zahlleiste mit Grund, Warte auf Karte, Fertig mit Karte, Einstellungen angemeldet, je hell und dunkel) erzeugen und ansehen, Commit.

### Task 13: Unklare Kartenzahlung nach einem Absturz

**Files:**
- Create: `app/lib/features/kassa/unclear_card_payment.dart`
- Modify: `app/lib/features/shell/shell_screen.dart`, `app/lib/data/providers.dart`
- Test: `app/test/features/unclear_card_test.dart`, ein Bildvergleich hell und dunkel

**Interfaces:**
- Consumes: `CardPaymentRepository.watchPending`, `SaleService.confirmUnclear`, `SaleService.discardUnclear`, `sessionProvider`
- Produces: `final pendingCardPaymentsProvider = StreamProvider<List<PendingCardPayment>>(…)`, Schlüssel `Key('unclear-card')`, `Key('unclear-paid')`, `Key('unclear-not-paid')`, `Key('unclear-confirm')`, `Key('unclear-back')`.

**Verhalten:** Beim Start der App gilt jede offene Kartenzahlung als unklar, auch eine mit dem Zustand `started` (die App war weg, während SumUp lief). Solange es eine gibt und jemand angemeldet ist, liegt über allen Bereichen ein Blatt (`unclear-card`), das sich nicht wegtippen lässt:

- Titel "War diese Kartenzahlung erfolgreich?"
- Betrag groß, darunter "Gestartet um 12:04 von Anna" und die Zeilen des Bons in Kurzform (höchstens 4, dann "und 3 weitere").
- Hinweis: "Die Kassa hat von SumUp keine Antwort bekommen. Schau in der SumUp-App unter Verkäufe nach, ob <Betrag> um <Uhrzeit> angekommen ist."
- Zwei große Tasten (80 dp): "Ja, ist angekommen" (`unclear-paid`) und "Nein, nicht angekommen" (`unclear-not-paid`).
- Jede Wahl zeigt zuerst, was passiert, und braucht einen zweiten Tipp (`unclear-confirm`): bei Ja "Die Kassa schreibt den Bon als Kartenzahlung und druckt ihn." bei Nein "Die Kassa verwirft die Zahlung und legt die Artikel wieder auf den Bon." Mit "Zurück" (`unclear-back`) kommt man zur Wahl.
- Gibt es mehrere, kommen sie nacheinander, die älteste zuerst.
- Lässt sich der Bon bei Ja nicht mehr bauen (Artikel inzwischen entfernt), steht da: "Der Bon lässt sich nicht mehr zusammenstellen, weil sich die Speisekarte geändert hat. Wähle Nein. Ist das Geld bei SumUp angekommen, buche es in der SumUp-App zurück und kassiere neu." und nur "Nein" bleibt.

- [ ] **Step 1: Failing tests**

```dart
testWidgets('ohne offene Zahlung erscheint nichts', …);
testWidgets('eine gestartete Zahlung aus einem früheren Lauf erscheint nach dem Anmelden', (t) async {
  /* vor pumpApp: cardPayments.begin(paymentId: 'p1', cart: cart, staff: anna) direkt in die Datenbank */
  expect(find.byKey(const Key('unclear-card')), findsOneWidget); expect(find.text('18,20 €'), findsOneWidget);
});
testWidgets('Ja und Bestätigen: ein Bon mit Karte, gedruckt, Blatt weg', …);
testWidgets('Nein und Bestätigen: kein Bon, die Artikel liegen wieder auf dem Bon, Blatt weg', …);
testWidgets('Zurück führt zur Wahl, nichts ist geschrieben', …);
testWidgets('das Blatt lässt sich nicht wegtippen und nicht mit Zurück schließen', …);
testWidgets('zwei offene Zahlungen kommen nacheinander, die ältere zuerst', …);
testWidgets('zwei schnelle Tipps auf Bestätigen ergeben einen Bon', …);
testWidgets('unklar direkt nach einer Zahlung (CardUnknown) zeigt dasselbe Blatt', …);
testWidgets('Bon nicht mehr baubar: nur Nein bleibt', …);
```

- [ ] **Step 2:** FAIL. **Step 3:** Umsetzen. **Step 4:** PASS, Bildvergleich, Commit.

### Task 14: Kleinigkeiten, Prüfliste, Version 1.1.0, Installationsdatei

**Files:**
- Create: `docs/testen/teil-b-pruefliste.md`
- Modify: `app/pubspec.yaml` (`version: 1.1.0+3`), `app/lib/core/app_info.dart` (`appVersion = '1.1.0'`), `app/lib/features/kassa/cart_panel.dart` oder `kassa_screen.dart` (Streifen unter dem Bon), `docs/superpowers/specs/2026-11-17-kassa-design.md` (5.6, 5.7, 8), `download/` (neue Datei, alte entfernen)
- Test: `app/test/features/system_bars_test.dart`

**Interfaces:**
- Consumes: alles Vorige.

- [ ] **Step 1: Failing test für den Streifen.** Mit Systemleisten oben 32 und unten 24 reicht die Bon-Spalte (`CartPanel`) mit ihrer Fläche bis an den unteren Bildschirmrand: `t.getRect(find.byType(CartPanel)).bottom == 800`, und `pay-cash` endet weiter über der Gestenleiste (`<= 776`). Heute bleibt unter der Bon-Spalte ein schmaler Streifen in der Grundfarbe.
- [ ] **Step 2:** FAIL, umsetzen, PASS.
- [ ] **Step 3: Entwurf nachziehen.** In 5.6: Mindestbetrag 1,00 €, keine Rückbuchung im SDK (Hinweis in der Storno-Frage), nach einem Absturz fragt die Kassa den Menschen, das Nachfragen bei SumUp kommt mit dem Server. In 5.7: Zeichensatz PC858, kein Logo und keine Kassen-Kennung am Bon vor Server und Signatur, Vermerk "TESTBON" bis zur Signatur. In 8: Punkt 11 als geklärt vermerken, was offen bleibt (andere SumUp-Geräte als das Air am echten Gerät prüfen).
- [ ] **Step 4: Prüfliste schreiben** (`docs/testen/teil-b-pruefliste.md`, in einfachen Worten, zum Abhaken): Drucker einrichten über die drei Wege, Testdruck, Umlaute und Euro lesbar, Breite, Bon nach Barverkauf, Lade geht auf, Lade aus, Drucker ausschalten und bonieren, Nochmal drucken, Drucken im Bon-Detail, Storno-Bon; SumUp anmelden, Leser verbinden, 1,00 € mit Karte, Karte abbrechen, Karte ablehnen lassen, Flugmodus, unter 1,00 €, App während der Zahlung wegwischen und wieder öffnen, Storno eines Karten-Bons und Rückbuchung in der SumUp-App, Abschluss mit Bar und Karte, Update von 1.0.1 ohne Datenverlust.
- [ ] **Step 5: Alles prüfen.** `flutter analyze`, `flutter test` einmal ganz.
- [ ] **Step 6: Bauen und bereitstellen.** `../tool/build_apk.sh arm64`, die Signatur ist dieselbe wie bei 1.0.1 (`apksigner verify --print-certs`, SHA-256 beginnt mit `4ffe5786`), `versionCode` 3. Datei nach `download/kassa-1.1.0-arm64.apk`, die alte Datei aus `download/` entfernen, die Zeile in `docs/testen/teil-a-pruefliste.md` bleibt gültig. Commit, Push, den Link mit `curl` holen und die Prüfsumme vergleichen.

---

## Selbstprüfung gegen den Entwurf

| Entwurf | Aufgabe |
|---|---|
| 5.6 Anbindung über das SumUp SDK, Air | 11 |
| 5.6 Anmeldung einmal in den Einstellungen | 12 |
| 5.6 eigene Kennung je Zahlung, Absturz zwischen Zahlung und Bon | 10, 13 (Mensch entscheidet, Nachfragen bei SumUp mit dem Server) |
| 5.6 Bildschirm von SumUp während der Zahlung | 11 (Erfolgs-Bildschirm übersprungen, Fehler-Bildschirm bleibt) |
| 5.6 Zahlung hinter einer Schnittstelle | 10 |
| 5.6 Storno eines Karten-Bons, Hinweis auf die SumUp-App | 10, 12 |
| 5.7 ESC/POS, 80 mm | 3, 4 |
| 5.7 USB, Netzwerk, Bluetooth hinter einer Schnittstelle | 5, 6 |
| 5.7 Inhalt des Bons | 2, 3 (ohne Logo, Kassen-Kennung und QR-Code, siehe "Nicht in Teil B") |
| 5.7 Geldlade über den Drucker, nur bei Bar und wenn eingeschaltet | 8 |
| 5.7 Drucker-Ausfall sperrt nicht, "Nochmal drucken" | 5, 8 |
| 5.3 Einstellungen: Zustand von Drucker und Terminal | 7, 12 |
| 5.14 Attrappen für Drucker und Terminal | 5, 10 |
| 5.14 Seite "Geräte testen" | 9, 12 |
| 5.14 Prüfliste an echter Hardware | 14 |
| 5.5 ohne Internet: Bar und Drucken ja, Karte nein | 8, 12 |
| Aus Teil A offen: Absturz zwischen Speichern und Entwurf löschen | 8 |
| Aus Teil A offen: Tests mit Kartenzahlung, Karte in der Storno-Frage | 10, 12 |
| Aus Teil A offen: unbekannte gespeicherte Werte | 1 |
| Aus Teil A offen: Streifen unter dem Bon | 14 |

Bewusst nicht in diesem Plan, weiter in `/mnt/project-files/kassa-plan/teil-a-gesamtpruefung.md` geführt: Optionen-Kennungen nach Position, unmögliche Auswahlgruppen beim Einspielen ablehnen, Bargeld-Bewegungen vor dem ersten Verkauf eines neuen Tages, gemeinsame Helfer nach `ui/` und `core/`, schmale Balken bei 30 Tagen, PIN-Sperre. Sie hängen am Katalog und an der Übersicht, nicht an Druck und Karte, und kommen vor Teil C in einen eigenen kleinen Plan.
