# Imbiss-Modus Teil A: Kassa-App am Tablet (ohne Server) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eine Android-App, mit der Niko am Tablet die Speisekarte eines Betriebs aus einer Datei einspielt, sich mit PIN anmeldet, boniert, bar kassiert, Bons ansieht und storniert, die Übersicht sieht, Artikel pflegt und den Tag abschließt. Alles läuft auf dem Gerät, ohne Server.

**Architecture:** Flutter-App im Ordner `app/`. Der Rechenkern (`lib/domain/`) ist reines Dart ohne Flutter und ohne Datenbank. Darunter eine SQLite-Datenbank über drift (`lib/data/`), darüber pro Bereich ein Ordner in `lib/features/`. Fertige Bons sind in der Datenbank durch Trigger gegen Ändern und Löschen gesperrt.

**Tech Stack:** Flutter 3.50.0 (Dart 3.14.0), flutter_riverpod 3.5.x (einfache `Notifier`, keine Code-Erzeugung), drift 2.35.x mit drift_flutter 0.3.x, uuid 4.6.x, crypto 3.0.x, file_picker 13.4.x, lucide_icons_flutter 4.0.x, mocktail 1.0.x. Schrift Figtree als Datei in der App.

**Spec:** `docs/superpowers/specs/2026-11-17-kassa-design.md` (Abschnitte 5.3, 5.4, 5.5, 5.11, 5.14, Anhang A). Dazu `PRODUCT.md` und `docs/design-regeln.md`.

## Wo dieser Plan steht

Schritt 2 des Entwurfs ("Imbiss-Modus") ist in drei Pläne geteilt, weil es drei unabhängige Teile sind. Jeder endet mit etwas, das Niko am Tablet ausprobieren kann.

| Plan | Inhalt | Stand |
|---|---|---|
| **Teil A (dieser Plan)** | App am Tablet ohne Server: einspielen, anmelden, bonieren, bar, Bons, Übersicht, Artikel, Abschluss, Einstellungen | geschrieben |
| Teil B | Bondruck über USB, Netzwerk, Bluetooth, Geldlade, Seite "Geräte testen", Fehlerberichte | wird nach Teil A geschrieben |
| Teil C | Server, schlichte Anbieter-Seite, Kopplung, Abgleich, Fotos | wird nach Teil B geschrieben |

Nicht in Teil A: Drucken, Geldlade öffnen, Kartenzahlung (Schritt 3), Signatur (Schritt 3), Server, Fotos, Kundenanzeige. Die Taste "Karte" ist sichtbar, aber gesperrt.

## Global Constraints

- Plattform: Android-Tablet im Querformat. Entwurfsgröße 1280 × 800, die App passt sich an 10 bis 13 Zoll an: Spalten für Kategorien und Bon bleiben fest, die Artikelfläche bekommt mehr oder weniger Spalten.
- Oberfläche auf Deutsch mit österreichischen Begriffen: bonieren, Bon, Storno, Tagesabschluss, Geldlade, Kundenanzeige.
- An der Theke gibt es keine Tastatur. In der ganzen App kommt kein Textfeld vor. Eingaben gehen über Tasten, Schalter und das Zahlenfeld.
- Geldbeträge sind immer ganze Cent (`int`), Preise sind brutto. Nie `double` für Geld.
- Ein fertiger Bon wird nie geändert oder gelöscht. Korrekturen laufen über Storno.
- Steuersätze: 20 %, 10 %, 13 %, 0 % und der Sondersatz 19 %. Pfand wird ohne Umsatzsteuer geführt.
- Tippflächen mindestens 48 dp, Hauptaktionen 64 bis 80 dp hoch. Zahlen in gleich breiten Ziffern, wo sie untereinander stehen.
- Akzentfarbe Petrol `#0F766E`, Schrift Figtree, helle und dunkle Ansicht. Maße, Farben und Zustände kommen aus `DESIGN.md` (Task 1).
- Bewegung 120 bis 320 ms, nur um Zustände zu zeigen, abgeschaltet, wenn das System "Animationen entfernen" meldet.
- Die App macht in Teil A keine Netzwerkzugriffe.
- Das Repo ist öffentlich. Daten von Betrieben, Namen von Betrieben, Zugangsdaten und Schlüssel kommen nie ins Repo. Tests und Beispiele verwenden den erfundenen "Beispiel-Imbiss".
- Bezeichner im Code sind englisch, Texte in der Oberfläche deutsch. Wörterbuch: Bon = `Receipt`, Bon-Zeile = `ReceiptLine`, Artikel = `Item`, Kategorie = `Category`, Auswahl-Vorlage = `ModifierTemplate`, Gruppe = `ModifierGroup`, Option = `ModifierOption`, Pfand = `deposit`, Storno = `void`, Tagesabschluss = `DayClose`, Tag = `BusinessDay`, Bargeld-Bewegung = `CashMovement`, Mitarbeiter = `Staff`, Betrieb = `Business`, Kassa (Gerät) = `Register`.
- Gebaut wird testgetrieben. Git: Commits auf dem Arbeits-Branch, ohne Pull Request, Commit-Texte auf Deutsch.
- Alle Befehle laufen aus `app/`, wenn nichts anderes dasteht. Die Flutter-Version steht in `app/.flutter-version`.

## Review Focus

Diese fünf Fälle nennt der Entwurf nicht, sie treffen aber jemanden an der Theke. Jeder hat seinen Test in der genannten Aufgabe.

1. **Doppelter Tipp auf "Abschließen" oder App-Absturz mitten im Bezahlen.** Erwartet: genau ein Bon, nie zwei, nie keiner. Test in Task 8 (`finalizeSale` mit gleicher `saleId`).
2. **Fehlerhafte Speisekarten-Datei** (fehlende Angabe, doppelte Kennung, unbekannte Kategorie, falscher Steuersatz, Datei mit BOM). Erwartet: eine Liste aller Fehler in einfachen Worten, nichts wird halb eingespielt. Tests in Task 4, Task 7 und Task 12.
3. **Uhr und Mitternacht.** Verkauf über Mitternacht, Tablet-Uhr springt zurück, Abschluss vergessen. Erwartet: Bon-Nummern bleiben lückenlos aufsteigend, kein Bon fällt aus Tag oder Übersicht. Tests in Task 8 und Task 9.
4. **Ungewöhnliche Beträge.** Summe 0,00 €, Summe über 9.999,99 €, Menge 99, Artikel mit Preis 0. Erwartet: Bezahlen geht, das Zahlenfeld reicht für den Betrag. Tests in Task 3, Task 5 und Task 14.
5. **App im Hintergrund beendet, große Systemschrift, kleines Tablet.** Erwartet: Der offene Bon ist nach dem Neustart noch da, nichts läuft über den Rand, Bar bleibt erreichbar. Tests in Task 13 (Bon-Entwurf wiederherstellen) und Task 11 (Bildvergleich bei 960 × 600 und Schriftgröße 1,3).

---

## Dateien

```
app/
  .flutter-version                 3.50.0
  pubspec.yaml
  analysis_options.yaml
  assets/fonts/Figtree-*.ttf, OFL.txt
  assets/demo/beispiel-imbiss.json    erfundene Karte im Einspiel-Format
  lib/
    main.dart                      Start, ProviderScope, Querformat
    app.dart                       MaterialApp, Thema, Weiche Einrichtung / Anmeldung / Bereiche
    core/money.dart                formatEuro, KeypadInput
    core/clock.dart                Clock (für Tests ersetzbar)
    domain/catalog.dart            Category, Item, ModifierTemplate, ModifierGroup, ModifierOption, TaxRate, ItemTag
    domain/menu_import.dart        parseMenuFile, MenuImportException
    domain/cart.dart               Cart, CartLine, Selection
    domain/pricing.dart            grossByRate, taxBreakdown, TaxLine
    domain/cash.dart               cashSuggestions, changeCents
    domain/receipt.dart            Receipt, ReceiptLine, Payment, ReceiptKind
    domain/day.dart                BusinessDay, CashMovement, DaySummary
    domain/stats.dart              Overview, StatsRange
    data/database.dart             drift-Tabellen und Trigger
    data/catalog_repository.dart
    data/staff_repository.dart
    data/settings_repository.dart
    data/receipt_repository.dart
    data/day_repository.dart
    data/stats_repository.dart
    data/providers.dart            Riverpod-Provider für Datenbank, Repositories, Clock
    ui/tokens.dart, ui/theme.dart  Werte aus DESIGN.md
    ui/keypad.dart, ui/app_toggle.dart, ui/segmented.dart, ui/app_header.dart, ui/primary_button.dart, ui/undo_toast.dart
    features/setup/                Ersteinrichtung
    features/login/                PIN-Anmeldung, Sitzung
    features/kassa/                Kassenbildschirm, Auswahl, Bon, Bar
    features/bons/
    features/overview/
    features/items/
    features/close/
    features/settings/
  test/                            spiegelt lib/, dazu test/golden/
tool/
  setup_flutter.sh                 lädt die Flutter-Version aus app/.flutter-version nach ~/flutter
  setup_android.sh                 Android-Werkzeuge für den Bau der Installationsdatei
  build_apk.sh
.github/workflows/app.yml          flutter analyze und flutter test bei jedem Push
DESIGN.md
```

---

### Task 1: DESIGN.md und die fehlenden Bildschirme

Kein Code. Der Entwurf verlangt, dass Niko die fehlenden Bildschirme sieht, bevor sie gebaut werden. Task 12 und Task 18 warten auf sein Ja zu diesen Bildschirmen, alle anderen Aufgaben nicht.

**Files:**
- Create: `DESIGN.md`
- Modify: der Entwurf im Artifact "Kassa Kassenbildschirm Entwürfe" (Quelle `Main.dc.html` in den Projektdateien unter `kassa-entwurf/quelle/`, nicht im Repo)

**Interfaces:**
- Produces: `DESIGN.md` mit den Abschnitten Farben (hell und dunkel, jeder Wert mit Namen), Schrift (Größen, Gewichte 600, 700, 800), Abstände, Ecken, Schatten, Bewegung, Tippflächen, Bausteine (Kopfleiste, Reiter, Artikel-Taste mit Bild und kompakt, Schalter, Segmente, Zahlenfeld, Hauptaktion, Hinweis mit Rückgängig), Aufbau der Spalten. Task 2 übernimmt die Werte nach `ui/tokens.dart`.

- [ ] **Step 1:** Skill `impeccable` laden (`context`, dann `document`). `DESIGN.md` aus `Main.dc.html` ableiten: alle CSS-Variablen (`--akzent`, `--akzent-hell`, `--akzent-tinte`, `--grund`, `--karte`, `--fuell`, `--fuell2`, `--linie`, `--tinte`, `--tinte2`, `--rot`, `--gruen`, `--warn-bg`, `--warn-tinte`, `--vegan-bg`, `--vegan-fg`, `--scharf-bg`, `--scharf-fg`, `--schatten`) für hell und dunkel als feste Farbwerte ausrechnen (`color-mix` auflösen), Raster der Artikel (4 Spalten bei 1280, Zeilenhöhe 157 mit Bild und 90 kompakt, Abstand 10), Bon-Leiste unten (180 + Rest), Zahlenfeld (3 Spalten, Abstand 8).
- [ ] **Step 2:** Vier Bildschirme im Stil des Entwurfs ergänzen und veröffentlichen: (a) Ersteinrichtung mit "Speisekarte einspielen" und "Mit Beispieldaten starten", (b) PIN-Anmeldung mit vier Punkten und Zahlenfeld, zugleich "PIN festlegen", (c) im Abschluss "Bargeld einlegen" und "Bargeld entnehmen" mit Zahlenfeld und Gründen zum Antippen (Bank, Einkauf, Wechselgeld, Sonstiges), (d) im Abschluss "In der Lade lassen" nach dem Zählen. Vor dem Veröffentlichen den Stand des Artifacts lesen, wie in den Projektnotizen beschrieben.
- [ ] **Step 3:** Bildschirmfotos der vier Bildschirme an Niko schicken und um ein Ja bitten. Rückmeldungen einarbeiten.
- [ ] **Step 4:** Commit `DESIGN.md`.

### Task 2: Projektgerüst, Thema, laufende Tests

**Files:**
- Create: `tool/setup_flutter.sh`, `app/` (über `flutter create --platforms android --org io.github.n1kob1ko --project-name kassa app`), `app/.flutter-version`, `app/analysis_options.yaml`, `app/assets/fonts/*`, `app/lib/main.dart`, `app/lib/app.dart`, `app/lib/ui/tokens.dart`, `app/lib/ui/theme.dart`, `app/lib/core/clock.dart`, `.github/workflows/app.yml`, `.gitignore`
- Test: `app/test/ui/theme_test.dart`, `app/test/no_text_field_test.dart`

**Interfaces:**
- Produces:
  - `abstract class Clock { DateTime now(); }`, `class SystemClock implements Clock`, `class FixedClock implements Clock { FixedClock(this.value); DateTime value; }`
  - `class KassaTokens` mit allen Werten aus `DESIGN.md` als `static const`, dabei `KassaTokens.accent = Color(0xFF0F766E)`, `minTap = 48.0`, `primaryActionHeight = 72.0`, `motionFast = Duration(milliseconds: 120)`, `motionSlow = Duration(milliseconds: 320)`
  - `ThemeData kassaTheme(Brightness brightness)` mit `fontFamily: 'Figtree'` und gleich breiten Ziffern (`FontFeature.tabularFigures()`) im Textstil für Beträge `KassaText.amount(BuildContext)`
  - `class KassaApp extends ConsumerWidget`
  - Android-Paketname `io.github.n1kob1ko.kassa`, App-Name "Kassa", nur Querformat, Textvergrößerung des Systems auf höchstens 1,3 begrenzt

- [ ] **Step 1:** `tool/setup_flutter.sh` schreiben: lädt `https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_$(cat app/.flutter-version)-stable.tar.xz` nach `~/flutter`, wenn `~/flutter/bin/flutter --version` nicht schon diese Version meldet. Ausführen, `flutter --version` zeigt 3.50.0.
- [ ] **Step 2:** Projekt anlegen, Pakete aus "Tech Stack" in `pubspec.yaml` eintragen, `flutter_lints` einschalten. Schriften Regular, Medium, SemiBold, Bold, ExtraBold und `OFL.txt` von `https://raw.githubusercontent.com/erikdkennedy/figtree/master/` laden und in `pubspec.yaml` als Familie `Figtree` mit den Gewichten 400 bis 800 eintragen.
- [ ] **Step 3: Failing tests**

```dart
// test/ui/theme_test.dart
test('Akzent ist Petrol und Schrift ist Figtree', () {
  expect(KassaTokens.accent, const Color(0xFF0F766E));
  expect(kassaTheme(Brightness.light).textTheme.bodyMedium!.fontFamily, 'Figtree');
  expect(kassaTheme(Brightness.dark).brightness, Brightness.dark);
  expect(KassaTokens.minTap, greaterThanOrEqualTo(48));
  expect(KassaTokens.primaryActionHeight, inInclusiveRange(64, 80));
});

// test/no_text_field_test.dart: liest alle Dateien unter lib/ und schlägt fehl,
// wenn eine 'TextField', 'TextFormField' oder 'EditableText' enthält.
test('in der App gibt es kein Textfeld', () {
  final hits = Directory('lib').listSync(recursive: true).whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where((f) => RegExp(r'\b(TextField|TextFormField|EditableText)\b').hasMatch(f.readAsStringSync()));
  expect(hits.map((f) => f.path), isEmpty);
});
```

- [ ] **Step 4:** `flutter test` ausführen, erwartet: FAIL (Namen fehlen).
- [ ] **Step 5:** `tokens.dart`, `theme.dart`, `clock.dart`, `app.dart`, `main.dart` schreiben. `main.dart` sperrt die Ausrichtung auf Querformat.
- [ ] **Step 6:** `flutter analyze` ohne Meldung, `flutter test` PASS.
- [ ] **Step 7:** `.github/workflows/app.yml`: bei Push auf jeden Branch `subosito/flutter-action@v2` mit `flutter-version-file: app/.flutter-version`, dann `flutter pub get`, `flutter analyze`, `flutter test` in `app/`.
- [ ] **Step 8:** Commit, Push, Lauf der Prüfung auf GitHub ansehen, erwartet: grün.

### Task 3: Geld und Zahlenfeld-Eingabe

**Files:**
- Create: `app/lib/core/money.dart`
- Test: `app/test/core/money_test.dart`

**Interfaces:**
- Produces:
  - `String formatEuro(int cents)`
  - `class KeypadInput { const KeypadInput({this.text = '', this.maxIntDigits = 4}); final String text; final int maxIntDigits; KeypadInput tap(String key); int get cents; bool get isEmpty; }` mit den Tasten `'0'` bis `'9'`, `','` und `'back'`

- [ ] **Step 1: Failing tests**

```dart
test('formatEuro', () {
  expect(formatEuro(0), '0,00 €');
  expect(formatEuro(990), '9,90 €');
  expect(formatEuro(128460), '1.284,60 €');
  expect(formatEuro(4064290), '40.642,90 €');
  expect(formatEuro(-25), '−0,25 €'); // U+2212
});
KeypadInput type(String keys, {int max = 4}) => keys.split(' ')
    .fold(KeypadInput(maxIntDigits: max), (k, key) => k.tap(key));
test('Zahlenfeld', () {
  expect(type('1 2 , 5').text, '12,5');
  expect(type('1 2 , 5').cents, 1250);
  expect(type(',').text, '0,');
  expect(type('0 5').text, '5');
  expect(type('1 , 2 3 4').text, '1,23');       // höchstens zwei Stellen nach dem Komma
  expect(type('1 , , 2').text, '1,2');           // nur ein Komma
  expect(type('1 2 3 4 5').text, '1234');        // vier Stellen vor dem Komma
  expect(type('1 2 3 4 5 6 7', max: 6).cents, 12345600);
  expect(type('1 2 back').text, '1');
  expect(type('back').text, '');
  expect(const KeypadInput().cents, 0);
});
```

- [ ] **Step 2:** Test ausführen, erwartet: FAIL.
- [ ] **Step 3:** Beides umsetzen. Regeln wie im Entwurf: Komma auf leerem Feld ergibt `0,`, eine führende Null wird ersetzt.
- [ ] **Step 4:** `flutter test test/core/money_test.dart` PASS.
- [ ] **Step 5:** Commit.

### Task 4: Katalog und Einspiel-Format

**Files:**
- Create: `app/lib/domain/catalog.dart`, `app/lib/domain/staff.dart`, `app/lib/domain/menu_import.dart`, `app/assets/demo/beispiel-imbiss.json`
- Test: `app/test/domain/menu_import_test.dart`

**Interfaces:**
- Produces:
  - `enum TaxRate { normal(20), reduced1(10), reduced2(13), zero(0), special(19); const TaxRate(this.percent); final int percent; static TaxRate fromPercent(int p); }`
  - `enum ItemTag { vegan, spicy }`
  - `class Category { id, name, position }`
  - `class Item { id, name, priceCents, categoryId, taxRate, depositCents, tags (Set<ItemTag>), info (String?), templateId (String?), favorite, inSale, photoPath (String?), position; Item copyWith(...) }`
  - `class ModifierOption { id, name, surchargeCents, isDefault, taxRate (TaxRate?), depositCents (int?) }`
  - `class ModifierGroup { id, name, min, max (int?), options }`
  - `class ModifierTemplate { id, name, groups }`
  - `enum StaffRole { staff, chef }`, `class Staff { id, name, role; bool get isChef; }` in `domain/staff.dart`
  - `class Catalog { businessName, categories, items, templates, staffSeeds; Item item(String id); ModifierTemplate? templateOf(Item item); }` mit `staffSeeds` als `List<({String name, String pin, StaffRole role})>`
  - `Catalog parseMenuFile(String jsonText)` wirft `MenuImportException(List<String> problems)`
  - Kennungen für Gruppen und Optionen: `'<vorlage>/<gruppenIndex>'` und `'<vorlage>/<gruppenIndex>/<optionsIndex>'`

- [ ] **Step 1:** `beispiel-imbiss.json` schreiben: Betrieb "Beispiel-Imbiss", 4 Kategorien (Bowls, Snacks, Süßes, Getränke), 14 Artikel. Darunter: "Huhn Bowl" 990 Cent mit Vorlage `bowl` und Kennzeichen SCHARF, "Tofu Bowl" 950 mit Vorlage `bowl` und VEGAN, "Teigtaschen" 650 mit Info "5 Stück", "Cola 0,33 l" 290 mit 20 % und Pfand 25, "Leitungswasser" 0 Cent. Vorlage `bowl`: Größe (genau 1, Normal als Vorgabe, XXL +200), Basis (genau 1 aus Reis, Nudeln, Salat), Extra-Topping (0 bis 4, je +120, 5 Optionen), Extra-Sauce (0 bis ohne Grenze, je +50, 4 Optionen). Speisen 10 %, Getränke 20 %.
- [ ] **Step 2: Failing tests**

```dart
late String demo; // aus assets/demo/beispiel-imbiss.json gelesen
test('Beispiel-Imbiss wird gelesen', () {
  final c = parseMenuFile(demo);
  expect(c.businessName, 'Beispiel-Imbiss');
  expect(c.categories.map((k) => k.name), ['Bowls', 'Snacks', 'Süßes', 'Getränke']);
  expect(c.items, hasLength(14));
  final cola = c.item('cola');
  expect((cola.priceCents, cola.taxRate, cola.depositCents), (290, TaxRate.normal, 25));
  final bowl = c.item('huhn-bowl');
  expect(bowl.tags, {ItemTag.spicy});
  final groups = c.templateOf(bowl)!.groups;
  expect(groups.map((g) => (g.name, g.min, g.max)),
      [('Größe', 1, 1), ('Basis', 1, 1), ('Extra-Topping', 0, 4), ('Extra-Sauce', 0, null)]);
  expect(groups.first.options.first.isDefault, isTrue);
  expect(groups.first.options.last.surchargeCents, 200);
  expect(c.items.every((i) => i.inSale && !i.favorite), isTrue);
});
test('alle Fehler werden auf einmal gemeldet', () {
  final bad = '''{"betrieb":"X","kategorien":[{"id":"a","name":"A"}],
    "artikel":[{"id":"x","name":"X","preis_cent":100,"kategorie":"b","mwst":7},
               {"id":"x","name":"Y","preis_cent":-1,"kategorie":"a","mwst":10,"auswahl":"fehlt"}],
    "auswahlgruppen":{}}''';
  expect(() => parseMenuFile(bad), throwsA(isA<MenuImportException>().having((e) => e.problems, 'problems', [
    'Artikel "x": Kategorie "b" gibt es nicht.',
    'Artikel "x": Steuersatz 7 ist nicht erlaubt. Erlaubt sind 20, 10, 13, 0 und 19.',
    'Artikel "x" kommt doppelt vor.',
    'Artikel "x": Preis darf nicht negativ sein.',
    'Artikel "x": Auswahl "fehlt" gibt es nicht.',
  ])));
});
test('kein JSON, fehlende Pflichtangabe, BOM', () {
  expect(() => parseMenuFile('hallo'), throwsA(isA<MenuImportException>()
      .having((e) => e.problems.single, 'problem', 'Die Datei ist keine gültige Speisekarten-Datei.')));
  expect(() => parseMenuFile('{"betrieb":"X","kategorien":[],"artikel":[{"id":"x"}],"auswahlgruppen":{}}'),
      throwsA(isA<MenuImportException>().having((e) => e.problems.first, 'problem', 'Artikel "x": Name fehlt.')));
  expect(parseMenuFile('﻿$demo').items, hasLength(14));
});
test('Mitarbeiter in der Datei', () {
  final c = parseMenuFile(demoMit('"mitarbeiter":[{"name":"Anna","pin":"1234","rolle":"mitarbeiter"}]'));
  expect(c.staffSeeds.single, (name: 'Anna', pin: '1234', role: StaffRole.staff));
  expect(parseMenuFile(demo).staffSeeds, isEmpty);
  // pin '12a' ergibt: 'Mitarbeiter "Anna": Die PIN muss aus genau vier Ziffern bestehen.'
});
test('Gruppe mit min größer als max und zu vielen Vorgaben', () { /* erwartet:
  'Auswahl "bowl", Gruppe "Basis": mindestens 2 und höchstens 1 passt nicht zusammen.'
  'Auswahl "bowl", Gruppe "Größe": 2 Vorgaben, aber höchstens 1 wählbar.' */ });
```

- [ ] **Step 3:** Test ausführen, erwartet: FAIL.
- [ ] **Step 4:** Klassen und `parseMenuFile` umsetzen. Format nach Anhang A des Entwurfs. `kennzeichen` ist ein Wort (`VEGAN`, `SCHARF`), auch eine Liste wird angenommen. Optionen dürfen zusätzlich `mwst` und `pfand_cent` tragen. Reihenfolge in der Datei wird zu `position`. Fehler stehen in der Reihenfolge der Datei, pro Artikel in dieser Reihenfolge geprüft: doppelte Kennung, Name, Preis, Kategorie, Steuersatz, Pfand, Auswahl. Zusätzlich zum Anhang A darf die Datei zum Testen `mitarbeiter` enthalten (`name`, `pin` mit vier Ziffern, `rolle` gleich `chef` oder `mitarbeiter`). Die Beispieldatei im Repo enthält keine.
- [ ] **Step 5:** PASS, Commit.

### Task 5: Bon-Rechenkern

**Files:**
- Create: `app/lib/domain/cart.dart`, `app/lib/domain/pricing.dart`
- Test: `app/test/domain/cart_test.dart`, `app/test/domain/pricing_test.dart`

**Interfaces:**
- Consumes: Klassen aus Task 4.
- Produces:
  - `class Selection { factory Selection.defaults(ModifierTemplate t); Selection toggle(ModifierGroup g, ModifierOption o); bool isChosen(ModifierOption o); bool get isComplete; List<ModifierGroup> get missing; List<ModifierOption> get chosen; int get surchargeCents; }`
  - `class CartLine { lineId, item, quantity, options (List<ModifierOption>); int get unitPriceCents; int get unitDepositCents; int get goodsCents; int get depositCents; }`
  - `class Cart { const Cart.empty(); List<CartLine> lines; Cart add(Item item, {List<ModifierOption> options = const [], String? lineId}); Cart setQuantity(String lineId, int quantity); Cart remove(String lineId); int get goodsCents; int get depositCents; int get totalCents; bool get isEmpty; Map<String, dynamic> toJson(); static Cart fromJson(Map<String, dynamic> json, Catalog catalog); }`
  - `Map<TaxRate, int> grossByRate(Cart cart)`
  - `class TaxLine { rate, grossCents, netCents, taxCents }`, `List<TaxLine> taxBreakdown(Map<TaxRate, int> gross)`

- [ ] **Step 1: Failing tests** (Katalog ist der Beispiel-Imbiss)

```dart
test('gleiche Artikel ohne Auswahl werden eine Zeile', () {
  final cart = const Cart.empty().add(cola).add(cola).add(teigtaschen);
  expect(cart.lines.map((l) => (l.item.id, l.quantity)), [('cola', 2), ('teigtaschen', 1)]);
  expect((cart.goodsCents, cart.depositCents, cart.totalCents), (1230, 50, 1280));
});
test('Artikel mit Auswahl bleiben eigene Zeilen, Aufpreise zählen', () {
  var sel = Selection.defaults(bowlTemplate);          // Größe Normal vorgewählt
  expect(sel.isComplete, isFalse);
  expect(sel.missing.map((g) => g.name), ['Basis']);
  sel = sel.toggle(basis, reis).toggle(basis, nudeln); // genau 1: Nudeln ersetzt Reis
  expect(sel.chosen.map((o) => o.name), ['Normal', 'Nudeln']);
  sel = sel.toggle(groesse, xxl).toggle(sauce, teriyaki);
  expect(sel.surchargeCents, 250);
  final cart = const Cart.empty().add(huhnBowl, options: sel.chosen).add(huhnBowl, options: sel.chosen);
  expect(cart.lines, hasLength(2));
  expect(cart.lines.first.unitPriceCents, 1240);
});
test('höchstens 4 Toppings: das fünfte wird nicht angenommen', () {
  var sel = Selection.defaults(bowlTemplate);
  for (final o in topping.options) { sel = sel.toggle(topping, o); }
  expect(sel.chosen.where((o) => topping.options.contains(o)), hasLength(4));
});
test('Menge', () {
  var cart = const Cart.empty().add(cola, lineId: 'a');
  cart = cart.setQuantity('a', 99).setQuantity('a', 100);
  expect(cart.lines.single.quantity, 99);
  expect(cart.setQuantity('a', 0).isEmpty, isTrue);
});
test('Summe 0 ist erlaubt', () => expect(const Cart.empty().add(leitungswasser).totalCents, 0));
test('Bon übersteht Speichern und Laden', () {
  final cart = const Cart.empty().add(cola).add(huhnBowl, options: [normal, reis]);
  expect(Cart.fromJson(cart.toJson(), catalog).totalCents, cart.totalCents);
});

// pricing_test.dart
test('Steuer pro Satz, Pfand ohne Steuer', () {
  final cart = const Cart.empty().add(cola).add(cola).add(teigtaschen); // 580 zu 20 %, 650 zu 10 %, 50 Pfand
  expect(grossByRate(cart), {TaxRate.normal: 580, TaxRate.reduced1: 650});
  final lines = taxBreakdown(grossByRate(cart));
  expect(lines.map((t) => (t.rate.percent, t.grossCents, t.netCents, t.taxCents)),
      [(20, 580, 483, 97), (10, 650, 591, 59)]);
});
test('Option mit eigenem Steuersatz zählt zu ihrem Satz', () {
  const drink = ModifierOption(id: 'm/0/0', name: 'Getränk', surchargeCents: 200, isDefault: false, taxRate: TaxRate.normal);
  expect(grossByRate(const Cart.empty().add(teigtaschen, options: [drink])),
      {TaxRate.reduced1: 650, TaxRate.normal: 200});
});
```

- [ ] **Step 2:** Tests ausführen, erwartet: FAIL.
- [ ] **Step 3:** Umsetzen. Steuer: `taxCents = (gross * percent / (100 + percent))`, kaufmännisch gerundet, `netCents = gross - taxCents`. `taxBreakdown` sortiert nach Satz absteigend und lässt Sätze ohne Betrag weg. Pfand einer Option ersetzt nicht das Pfand des Artikels, es kommt dazu.
- [ ] **Step 4:** PASS, Commit.

### Task 6: Bar-Vorschläge und Rückgeld

**Files:**
- Create: `app/lib/domain/cash.dart`
- Test: `app/test/domain/cash_test.dart`

**Interfaces:**
- Produces: `List<int> cashSuggestions(int totalCents)` (erster Eintrag ist der passende Betrag), `int changeCents({required int givenCents, required int totalCents})` (negativ heißt: fehlt noch)

- [ ] **Step 1: Failing tests**

```dart
test('Vorschläge', () {
  expect(cashSuggestions(1290), [1290, 1500, 2000, 5000, 10000]);
  expect(cashSuggestions(2340), [2340, 2500, 3000, 4000, 5000, 10000]);
  expect(cashSuggestions(500), [500, 1000, 2000, 5000, 10000]);
  expect(cashSuggestions(0), [0]);
  expect(cashSuggestions(1234500), [1234500, 1235000, 1236000, 1240000]);
});
test('Rückgeld', () {
  expect(changeCents(givenCents: 2000, totalCents: 1290), 710);
  expect(changeCents(givenCents: 1000, totalCents: 1290), -290);
});
```

- [ ] **Step 2:** FAIL prüfen.
- [ ] **Step 3:** Umsetzen. Stufen 500, 1000, 2000, 5000, 10000. Pro Stufe der nächste Vielfache über der Summe (`((total + 1) / stufe).ceil() * stufe`), Doppelte weglassen. Bei Summe 0 gibt es nur den passenden Betrag.
- [ ] **Step 4:** PASS, Commit.

### Task 7: Datenbank, Katalog, Mitarbeiter, Einstellungen

**Files:**
- Create: `app/lib/data/database.dart`, `app/lib/data/catalog_repository.dart`, `app/lib/data/staff_repository.dart`, `app/lib/data/settings_repository.dart`, `app/lib/data/providers.dart`
- Test: `app/test/data/catalog_repository_test.dart`, `app/test/data/staff_repository_test.dart`, `app/test/data/settings_repository_test.dart`

**Interfaces:**
- Consumes: Klassen aus Task 4 (auch `Staff`, `StaffRole`), `Clock` aus Task 2.
- Produces:
  - `class KassaDatabase extends _$KassaDatabase { KassaDatabase(QueryExecutor e); }` mit Tabellen für alle Zeilen aus Abschnitt 5.4 des Entwurfs außer dem RKSV-Protokoll. In Tests `KassaDatabase(NativeDatabase.memory())`.
  - `class CatalogRepository { Future<void> importCatalog(Catalog c); Stream<Catalog?> watch(); Future<Catalog?> current(); Future<void> updateItem(String itemId, {int? priceCents, bool? inSale, bool? favorite, int? depositCents, Set<ItemTag>? tags}); }`
  - `class StaffRepository { Future<Staff> create({required String name, required String pin, required StaffRole role}); Future<Staff?> findByPin(String pin); Future<List<Staff>> all(); }` wirft `PinTakenException` und `InvalidPinException` (PIN ist nicht genau vier Ziffern)
  - `enum AppThemeMode { system, light, dark }`, `class RegisterSettings { cashDrawerEnabled (true), showImages (false), themeMode (system), voidRequiresChef (false); copyWith }`
  - `class SettingsRepository { Stream<RegisterSettings> watch(); Future<RegisterSettings> current(); Future<void> save(RegisterSettings s); Future<String?> readDraft(); Future<void> writeDraft(String? json); }` (Entwurf des offenen Bons)
  - `data/providers.dart`: `databaseProvider`, `clockProvider`, `catalogRepositoryProvider`, `staffRepositoryProvider`, `settingsRepositoryProvider`

- [ ] **Step 1: Failing tests**

```dart
test('Einspielen und Lesen', () async {
  await repo.importCatalog(parseMenuFile(demo));
  final c = (await repo.current())!;
  expect(c.items, hasLength(14));
  expect(c.templateOf(c.item('huhn-bowl'))!.groups, hasLength(4));
});
test('erneutes Einspielen behält Favorit und Im-Verkauf, nimmt den Preis aus der Datei, legt fehlende Artikel still', () async {
  await repo.importCatalog(parseMenuFile(demo));
  await repo.updateItem('cola', favorite: true, inSale: false, priceCents: 310);
  await repo.importCatalog(parseMenuFile(demoOhneTeigtaschen));
  final c = (await repo.current())!;
  expect((c.item('cola').favorite, c.item('cola').inSale, c.item('cola').priceCents), (true, false, 290));
  expect(c.items.any((i) => i.id == 'teigtaschen'), isFalse);
});
test('scheitert das Einspielen, bleibt der alte Stand', () async { /* Katalog mit Artikel, dessen Kategorie fehlt,
  direkt an importCatalog: wirft, danach current() unverändert */ });
test('updateItem', () async {
  await repo.updateItem('cola', priceCents: 320, tags: {ItemTag.vegan});
  expect(((await repo.current())!.item('cola').priceCents), 320);
});

// staff
test('PIN', () async {
  final chef = await staff.create(name: 'Chef', pin: '4711', role: StaffRole.chef);
  expect((await staff.findByPin('4711'))!.id, chef.id);
  expect(await staff.findByPin('0000'), isNull);
  expect(() => staff.create(name: 'Anna', pin: '4711', role: StaffRole.staff), throwsA(isA<PinTakenException>()));
  expect(() => staff.create(name: 'Ben', pin: '12a', role: StaffRole.staff), throwsA(isA<InvalidPinException>()));
});
test('die PIN steht nicht im Klartext in der Datenbank', () async {
  await staff.create(name: 'Chef', pin: '4711', role: StaffRole.chef);
  final rows = await db.customSelect('SELECT * FROM staff').get();
  expect(rows.single.data.values.join('|'), isNot(contains('4711')));
});

// settings
test('Voreinstellungen und Speichern', () async {
  final s = await settings.current();
  expect((s.cashDrawerEnabled, s.showImages, s.themeMode, s.voidRequiresChef), (true, false, AppThemeMode.system, false));
  await settings.save(s.copyWith(cashDrawerEnabled: false));
  expect((await settings.current()).cashDrawerEnabled, isFalse);
});
```

- [ ] **Step 2:** FAIL prüfen.
- [ ] **Step 3:** Tabellen anlegen, `dart run build_runner build` ausführen, Repositories schreiben. `importCatalog` läuft in einer Transaktion. Stillgelegte Artikel bekommen `archived = true` und bleiben in der Tabelle. PIN: zufälliges Salz pro Mitarbeiter, gespeichert wird SHA-256 über Salz und PIN. Die Tests brauchen SQLite auf dem Rechner: Bringt das Paket es nicht selbst mit, in `.github/workflows/app.yml` vor den Tests `sudo apt-get install -y libsqlite3-dev` ergänzen. Vor dem Schreiben die aktuelle Anleitung von drift lesen (Einrichtung mit `drift_flutter`).
- [ ] **Step 4:** PASS, Commit (erzeugte `*.g.dart` mit einchecken).

### Task 8: Bons speichern und stornieren

**Files:**
- Create: `app/lib/domain/receipt.dart`, `app/lib/data/receipt_repository.dart`
- Modify: `app/lib/data/database.dart` (Tabellen `receipts`, `receipt_lines`, `receipt_line_options`, `payments`, `business_days` und Trigger), `app/lib/data/providers.dart`
- Test: `app/test/data/receipt_repository_test.dart`, `app/test/support/sales.dart`

**Interfaces:**
- Consumes: `Cart` (Task 5), `Staff` (Task 7), `Clock`.
- Produces:
  - `enum ReceiptKind { sale, voided }`, `enum PaymentKind { cash, card }`
  - `class ReceiptLineOption { groupName, optionName, surchargeCents }`
  - `class ReceiptLine { position, itemId, name, info, unitPriceCents, quantity, unitDepositCents, options; int get goodsCents; }`
  - `class Payment { kind, amountCents, givenCents, changeCents }`
  - `class Receipt { id, number, createdAt, staffName, businessDayId, kind, voidsReceiptId, voidedByReceiptId, lines, payment, goodsCents, depositCents, totalCents, grossByRate (Map<TaxRate,int>); bool get isVoided; List<TaxLine> get taxLines; }`
  - `class ReceiptRepository { Future<Receipt> finalizeCashSale({required String saleId, required Cart cart, required int givenCents, required Staff staff}); Future<Receipt> voidReceipt(String receiptId, {required Staff staff}); Future<Receipt> byId(String id); Stream<List<Receipt>> watchDay(String businessDayId); }`
  - Ausnahmen: `EmptyCartException`, `InsufficientCashException`, `AlreadyVoidedException`, `CannotVoidAVoidException`
  - `receiptRepositoryProvider`
  - Tabelle `business_days` (`id`, `openedAt`, `closedAt`, `openingFloatCents`, `countedCents`, `leftInDrawerCents`, `expectedCents`, `differenceCents`, `closedByName`). `finalizeCashSale` nimmt den offenen Tag oder legt einen an. Den Rest dazu baut Task 9.

- [ ] **Step 1: Failing tests** (Uhr ist eine `FixedClock`, Start 2026-11-17 11:00. `cart` ist in allen Tests ab hier der Bon aus dem ersten Test zu 18,20 €. `sell(id)` verkauft ihn bar mit 20,00 € als Anna. Diese Helfer stehen in `test/support/sales.dart` und werden von Task 9, 10 und den Bereichs-Tests mitbenutzt.)

```dart
test('Bon bekommt Nummer 1, Zeilen, Summen, Zahlung', () async {
  final cart = const Cart.empty().add(cola).add(cola).add(huhnBowl, options: [xxl, nudeln]);
  final r = await receipts.finalizeCashSale(saleId: 's1', cart: cart, givenCents: 2000, staff: anna);
  expect((r.number, r.kind, r.staffName), (1, ReceiptKind.sale, 'Anna'));
  expect((r.goodsCents, r.depositCents, r.totalCents), (1770, 50, 1820));
  expect(r.grossByRate, {TaxRate.normal: 580, TaxRate.reduced1: 1190});
  expect((r.payment.kind, r.payment.givenCents, r.payment.changeCents), (PaymentKind.cash, 2000, 180));
  expect(r.lines.last.options.map((o) => (o.groupName, o.optionName, o.surchargeCents)),
      [('Größe', 'XXL', 200), ('Basis', 'Nudeln', 0)]);
});
test('gleiche saleId zweimal ergibt genau einen Bon', () async {
  final a = await receipts.finalizeCashSale(saleId: 's1', cart: cart, givenCents: 2000, staff: anna);
  final b = await receipts.finalizeCashSale(saleId: 's1', cart: cart, givenCents: 2000, staff: anna);
  expect(b.id, a.id);
  expect(await db.customSelect('SELECT COUNT(*) c FROM receipts').getSingle().then((r) => r.read<int>('c')), 1);
});
test('Nummern steigen lückenlos, auch wenn die Uhr zurückspringt', () async {
  await sell('s1'); clock.value = DateTime(2026, 11, 17, 9); await sell('s2'); await sell('s3');
  expect((await receipts.watchDay(dayId).first).map((r) => r.number).toList()..sort(), [1, 2, 3]);
});
test('leerer Bon und zu wenig Geld werden abgelehnt', () async {
  expect(() => receipts.finalizeCashSale(saleId: 'x', cart: const Cart.empty(), givenCents: 0, staff: anna),
      throwsA(isA<EmptyCartException>()));
  expect(() => receipts.finalizeCashSale(saleId: 'y', cart: cart, givenCents: 100, staff: anna),
      throwsA(isA<InsufficientCashException>()));
});
test('Summe 0 mit gegeben 0 geht', () async {
  final r = await receipts.finalizeCashSale(saleId: 'z', cart: const Cart.empty().add(leitungswasser), givenCents: 0, staff: anna);
  expect(r.totalCents, 0);
});
test('Storno erzeugt einen eigenen Bon mit negativen Beträgen', () async {
  final r = await sell('s1');
  final v = await receipts.voidReceipt(r.id, staff: chef);
  expect((v.number, v.kind, v.voidsReceiptId, v.totalCents), (2, ReceiptKind.voided, r.id, -r.totalCents));
  expect(v.lines.first.quantity, -r.lines.first.quantity);
  expect(v.payment.amountCents, -r.totalCents);
  expect((await receipts.byId(r.id)).isVoided, isTrue);
  expect(() => receipts.voidReceipt(r.id, staff: chef), throwsA(isA<AlreadyVoidedException>()));
  expect(() => receipts.voidReceipt(v.id, staff: chef), throwsA(isA<CannotVoidAVoidException>()));
});
test('ein Bon behält Namen und Preis, auch wenn der Artikel sich ändert', () async {
  final r = await sell('s1');
  await catalogRepo.updateItem('cola', priceCents: 999);
  expect((await receipts.byId(r.id)).lines.first.unitPriceCents, 290);
});
test('die Datenbank weist Ändern und Löschen von Bons ab', () async {
  await sell('s1');
  for (final sql in ['UPDATE receipts SET total_cents = 1', 'DELETE FROM receipts',
      'UPDATE receipt_lines SET quantity = 5', 'DELETE FROM payments']) {
    expect(() => db.customStatement(sql), throwsA(anything), reason: sql);
  }
});
```

- [ ] **Step 2:** FAIL prüfen.
- [ ] **Step 3:** Umsetzen. `finalizeCashSale` läuft in einer Transaktion: vorhandenen Bon mit `id == saleId` zurückgeben, sonst Nummer = höchste Nummer + 1, Zeilen, Optionen und Zahlung schreiben. Ob ein Bon storniert ist, ergibt sich aus einem Storno-Bon, der auf ihn zeigt (eindeutiger Index auf `voids_receipt_id`), nicht aus einem geänderten Feld. Trigger `BEFORE UPDATE` und `BEFORE DELETE` auf `receipts`, `receipt_lines`, `receipt_line_options`, `payments` mit `RAISE(ABORT, 'Bons sind unveränderlich')`.
- [ ] **Step 4:** PASS, Commit.

### Task 9: Tag, Bargeld und Tagesabschluss

**Files:**
- Create: `app/lib/domain/day.dart`, `app/lib/data/day_repository.dart`
- Modify: `app/lib/data/database.dart` (Tabelle `cash_movements`, Trigger), `app/lib/data/providers.dart`
- Test: `app/test/data/day_repository_test.dart`

**Interfaces:**
- Consumes: `ReceiptRepository` (Task 8).
- Produces:
  - `enum CashMovementKind { deposit, withdrawal }`, `enum CashReason { bank, purchase, change, other }`
  - `class BusinessDay { id, openedAt, closedAt, openingFloatCents (int?), countedCents, leftInDrawerCents, expectedCents, differenceCents, closedByName; bool get isOpen; }`
  - `class DaySummary { day, receiptCount, revenueCents, cashRevenueCents, cardRevenueCents, depositCents, taxLines, openingFloatCents, cashInCents, cashOutCents, expectedCashCents, movements }`
  - `class DayRepository { Future<BusinessDay?> openDay(); Future<BusinessDay?> lastClosedDay(); Future<bool> needsOpeningFloat(); Future<void> setOpeningFloat(int cents); Future<void> addMovement({required CashMovementKind kind, required int amountCents, required CashReason reason, required Staff staff}); Future<DaySummary?> summary(); Future<BusinessDay> close({required int countedCents, required int leftInDrawerCents, required Staff staff}); Future<bool> hasForgottenClose(); }`
  - Ausnahmen: `NoOpenDayException`, `LeftInDrawerTooHighException`, `InvalidAmountException`
  - `dayRepositoryProvider`

- [ ] **Step 1: Failing tests**

```dart
test('der erste Bon öffnet den Tag, Wechselgeld fehlt am ersten Tag', () async {
  expect(await days.openDay(), isNull);
  await sell('s1');
  expect((await days.openDay())!.openedAt, DateTime(2026, 11, 17, 11));
  expect(await days.needsOpeningFloat(), isTrue);
  await days.setOpeningFloat(15000);
  expect(await days.needsOpeningFloat(), isFalse);
});
test('Soll = Wechselgeld + Bar-Einnahmen + Einlagen - Entnahmen, Storno zählt ab', () async {
  await days.setOpeningFloat(15000);
  final a = await sell('s1'); /* 1820 */ await sell('s2'); /* 1820 */
  await receipts.voidReceipt(a.id, staff: chef);
  await days.addMovement(kind: CashMovementKind.deposit, amountCents: 5000, reason: CashReason.change, staff: chef);
  await days.addMovement(kind: CashMovementKind.withdrawal, amountCents: 2000, reason: CashReason.purchase, staff: chef);
  final s = (await days.summary())!;
  expect((s.receiptCount, s.revenueCents, s.cashRevenueCents), (1, 1820, 1820));
  expect((s.cashInCents, s.cashOutCents, s.expectedCashCents), (5000, 2000, 19820));
  expect(s.taxLines.map((t) => (t.rate.percent, t.grossCents)), [(20, 580), (10, 1190)]);
});
test('Abschließen: Unterschied, in der Lade gelassen wird Wechselgeld des nächsten Tages', () async {
  await days.setOpeningFloat(15000); await sell('s1');
  final closed = await days.close(countedCents: 16800, leftInDrawerCents: 15000, staff: chef);
  expect((closed.expectedCents, closed.differenceCents, closed.isOpen), (16820, -20, false));
  expect(await days.openDay(), isNull);
  clock.value = DateTime(2026, 11, 18, 10); await sell('s2');
  expect((await days.openDay())!.openingFloatCents, 15000);
  expect(await days.needsOpeningFloat(), isFalse);
});
test('ein Tag endet mit dem Abschluss, nicht um Mitternacht', () async {
  await sell('s1'); clock.value = DateTime(2026, 11, 18, 1, 30); await sell('s2');
  expect((await days.summary())!.receiptCount, 2);
});
test('vergessener Abschluss', () async {
  await sell('s1');
  expect(await days.hasForgottenClose(), isFalse);
  clock.value = DateTime(2026, 11, 18, 9);
  expect(await days.hasForgottenClose(), isTrue);
});
test('ungültige Eingaben', () async {
  expect(() => days.close(countedCents: 0, leftInDrawerCents: 0, staff: chef), throwsA(isA<NoOpenDayException>()));
  await sell('s1');
  expect(() => days.close(countedCents: 1000, leftInDrawerCents: 2000, staff: chef), throwsA(isA<LeftInDrawerTooHighException>()));
  expect(() => days.addMovement(kind: CashMovementKind.deposit, amountCents: 0, reason: CashReason.other, staff: chef),
      throwsA(isA<InvalidAmountException>()));
});
test('eine Bargeld-Bewegung öffnet auch einen Tag; abgeschlossene Tage sind gesperrt', () async {
  await days.addMovement(kind: CashMovementKind.deposit, amountCents: 5000, reason: CashReason.change, staff: chef);
  final d = await days.close(countedCents: 5000, leftInDrawerCents: 5000, staff: chef);
  expect(() => db.customStatement("UPDATE business_days SET counted_cents = 1 WHERE id = '${d.id}'"), throwsA(anything));
});
```

- [ ] **Step 2:** FAIL prüfen.
- [ ] **Step 3:** Umsetzen. `setOpeningFloat` geht nur, solange es keinen abgeschlossenen Tag gibt, und öffnet bei Bedarf den Tag. "Vergessen" heißt: Es gibt einen offenen Tag, und sein `openedAt` liegt an einem früheren Kalendertag als `clock.now()`. Trigger: `cash_movements` nie ändern oder löschen, `business_days` nicht mehr ändern, sobald `closed_at` gesetzt ist.
- [ ] **Step 4:** PASS, Commit.

### Task 10: Zahlen für die Übersicht

**Files:**
- Create: `app/lib/domain/stats.dart`, `app/lib/data/stats_repository.dart`
- Modify: `app/lib/data/providers.dart`
- Test: `app/test/data/stats_repository_test.dart`

**Interfaces:**
- Produces:
  - `enum StatsRange { today, days7, days30 }`
  - `class Bucket { label, start, cents }`, `class ItemStat { name, quantity, cents }`, `class CategoryStat { name, cents }`
  - `class Overview { revenueCents, previousRevenueCents, receiptCount, buckets, cashCents, cardCents, topItems (höchstens 5, nach Menge), byCategory (absteigend, Pfand als eigene Zeile "Pfand" am Ende) }`
  - `class StatsRepository { Future<Overview> overview(StatsRange range); }`, `statsRepositoryProvider`

- [ ] **Step 1: Failing tests**

```dart
test('heute: Balken pro Stunde von der ersten Verkaufsstunde bis jetzt', () async {
  clock.value = DateTime(2026, 11, 17, 11, 10); await sell('s1'); // 1820
  clock.value = DateTime(2026, 11, 17, 13, 40); await sell('s2');
  final o = await stats.overview(StatsRange.today);
  expect(o.buckets.map((b) => (b.label, b.cents)), [('11', 1820), ('12', 0), ('13', 1820)]);
  expect((o.revenueCents, o.receiptCount, o.cashCents, o.cardCents), (3640, 2, 3640, 0));
  expect(o.topItems.first.name, 'Cola 0,33 l');
  expect(o.topItems.first.quantity, 4);
  expect(o.byCategory.last, isA<CategoryStat>().having((c) => (c.name, c.cents), 'Pfand', ('Pfand', 100)));
  expect(o.byCategory.fold<int>(0, (s, c) => s + c.cents), o.revenueCents);
});
test('Storno zählt Umsatz, Anzahl und Mengen wieder ab', () async {
  final r = await sell('s1'); await receipts.voidReceipt(r.id, staff: chef);
  final o = await stats.overview(StatsRange.today);
  expect((o.revenueCents, o.receiptCount, o.topItems), (0, 0, isEmpty));
});
test('7 Tage: sieben Balken nach Kalendertag, Vergleich mit den sieben Tagen davor', () async {
  clock.value = DateTime(2026, 11, 9, 12); await sell('alt');
  clock.value = DateTime(2026, 11, 17, 0, 30); await sell('nachts');
  final o = await stats.overview(StatsRange.days7);
  expect(o.buckets, hasLength(7));
  expect((o.buckets.last.label, o.buckets.last.cents), ('17.11.', 1820));
  expect((o.revenueCents, o.previousRevenueCents), (1820, 1820));
});
test('ohne Bons: leere Übersicht', () async {
  final o = await stats.overview(StatsRange.today);
  expect((o.revenueCents, o.buckets, o.topItems), (0, isEmpty, isEmpty));
});
```

- [ ] **Step 2:** FAIL prüfen.
- [ ] **Step 3:** Umsetzen. Die Übersicht rechnet nach Kalendertagen der Gerätezeit, nicht nach Tagesabschluss. Storno-Bons zählen mit ihren negativen Werten zu dem Zeitpunkt, an dem storniert wurde.
- [ ] **Step 4:** PASS, Commit.

### Task 11: Bausteine der Oberfläche

**Files:**
- Create: `app/lib/ui/keypad.dart`, `app/lib/ui/app_toggle.dart`, `app/lib/ui/segmented.dart`, `app/lib/ui/primary_button.dart`, `app/lib/ui/undo_toast.dart`, `app/lib/ui/app_header.dart`, `app/test/support/pump.dart`, `app/test/support/widget_board.dart`
- Test: `app/test/ui/keypad_test.dart`, `app/test/ui/widgets_test.dart`, `app/test/golden/widgets_golden_test.dart`

**Interfaces:**
- Consumes: `KassaTokens`, `kassaTheme` (Task 2), `KeypadInput` (Task 3).
- Produces:
  - `Keypad({required ValueChanged<String> onKey, bool showComma = true})`, Tasten mit `Key('key-0')` bis `Key('key-9')`, `Key('key-comma')`, `Key('key-back')`, Semantik "Komma" und "Letzte Ziffer löschen"
  - `AppToggle({required bool value, required ValueChanged<bool>? onChanged, required String label})`
  - `Segmented<T>({required List<(T, String)> segments, required T selected, required ValueChanged<T> onSelected})`
  - `PrimaryButton({required String label, required VoidCallback? onPressed, String? sublabel, bool filled = true})`, Höhe `KassaTokens.primaryActionHeight`
  - `void showUndoToast(BuildContext context, {required String message, required VoidCallback onUndo})`, sichtbar 5 Sekunden, Taste "Rückgängig"
  - `enum AppArea { kassa, bons, overview, items, close }`, `AppHeader({required AppArea area, required ValueChanged<AppArea> onArea, required String staffName, required bool isChef, required VoidCallback onStaff, required VoidCallback onSettings})`. Reiter "Kassa", "Bons", "Übersicht", "Artikel", "Abschluss" mit `Key('tab-<name>')`. Ohne Chef-Rolle nur "Kassa" und "Bons", keine Einstellungen-Taste.
  - `Future<void> pumpApp(WidgetTester t, Widget child, {Size size = const Size(1280, 800), Brightness brightness = Brightness.light, double textScale = 1.0, List<Override> overrides = const []})` lädt Figtree für Bildvergleiche
  - In `test/support/pump.dart` außerdem: `String textOf(WidgetTester t, Key key)`, `Future<void> tapKeys(WidgetTester t, String keys)` (Tasten des Zahlenfelds, durch Leerzeichen getrennt), `Future<void> typePin(WidgetTester t, String pin)`, `List<Override> memoryOverrides({String? pickedFile, Clock? clock})` (Datenbank im Speicher, eingespielter Beispiel-Imbiss, Chef "Chef" mit PIN 4711, Mitarbeiterin "Anna" mit PIN 1234, feste Uhr)
  - `WidgetBoard` ist ein Test-Widget, das alle Bausteine in allen Zuständen nebeneinander zeigt
  - Die Helfer `pumpKassa`, `pumpBonsWithSales` und ähnliche in den späteren Tests bauen auf `pumpApp` und `memoryOverrides` auf und stehen in der jeweiligen Testdatei.

- [ ] **Step 1: Failing tests**

```dart
testWidgets('Zahlenfeld meldet Tasten, jede Taste ist mindestens 48 dp', (t) async {
  final keys = <String>[];
  await pumpApp(t, Keypad(onKey: keys.add));
  await t.tap(find.byKey(const Key('key-7'))); await t.tap(find.byKey(const Key('key-comma'))); await t.tap(find.byKey(const Key('key-back')));
  expect(keys, ['7', ',', 'back']);
  expect(t.getSize(find.byKey(const Key('key-7'))).shortestSide, greaterThanOrEqualTo(48));
});
testWidgets('Kopfleiste zeigt Mitarbeitern nur Kassa und Bons', (t) async {
  await pumpApp(t, AppHeader(area: AppArea.kassa, onArea: (_) {}, staffName: 'Anna', isChef: false, onStaff: () {}, onSettings: () {}));
  expect(find.byKey(const Key('tab-Bons')), findsOneWidget);
  expect(find.byKey(const Key('tab-Abschluss')), findsNothing);
  expect(find.byKey(const Key('settings')), findsNothing);
});
testWidgets('Hinweis mit Rückgängig ruft onUndo', (t) async { /* showUndoToast, Tipp auf "Rückgängig", erwartet: onUndo einmal */ });
testWidgets('Schalter und Segmente melden den neuen Wert', (t) async { /* AppToggle false -> true, Segmented wählt zweites */ });
// Bildvergleich: eine Tafel mit allen Bausteinen, hell und dunkel, 1280x800 und 960x600 mit textScale 1.3
testWidgets('Bausteine sehen aus wie im Entwurf', (t) async {
  for (final (name, size, b, scale) in [('hell', const Size(1280, 800), Brightness.light, 1.0),
      ('dunkel', const Size(1280, 800), Brightness.dark, 1.0), ('klein', const Size(960, 600), Brightness.light, 1.3)]) {
    await pumpApp(t, const WidgetBoard(), size: size, brightness: b, textScale: scale);
    expect(t.takeException(), isNull); // kein Überlauf
    await expectLater(find.byType(WidgetBoard), matchesGoldenFile('widgets_$name.png'));
  }
});
```

- [ ] **Step 2:** FAIL prüfen.
- [ ] **Step 3:** Bausteine nach `DESIGN.md` umsetzen. Druck-Feedback beim Tippen sofort (Skalierung und Farbwechsel, 120 ms), Animationen aus, wenn `MediaQuery.disableAnimations` gesetzt ist.
- [ ] **Step 4:** `flutter test --update-goldens test/golden/widgets_golden_test.dart`, die drei Bilder mit den Bildschirmfotos des Entwurfs (Projektdateien, Ordner `kassa-entwurf`) vergleichen und Abweichungen beheben. Danach `flutter test` PASS.
- [ ] **Step 5:** Commit.

### Task 12: Ersteinrichtung und Anmeldung

Wartet auf Nikos Ja zu den Bildschirmen aus Task 1.

**Files:**
- Create: `app/lib/features/setup/setup_screen.dart`, `app/lib/features/setup/menu_file_picker.dart`, `app/lib/features/login/pin_screen.dart`, `app/lib/features/login/session.dart`, `app/lib/features/shell/shell_screen.dart`
- Modify: `app/lib/app.dart`
- Test: `app/test/features/setup_test.dart`, `app/test/features/login_test.dart`

**Interfaces:**
- Consumes: `CatalogRepository`, `StaffRepository`, `parseMenuFile`, `Catalog.staffSeeds` (Task 4), `AppHeader`, `Keypad`.
- Produces:
  - `abstract class MenuFilePicker { Future<String?> pickText(); }`, `menuFilePickerProvider` (echte Umsetzung mit `file_picker`, in Tests ersetzt)
  - `class SessionController extends Notifier<Staff?> { Future<bool> login(String pin); void logout(); }`, `sessionProvider`
  - `ShellScreen` mit Kopfleiste und dem gewählten Bereich. Bereiche, die es noch nicht gibt, zeigen bis zu ihrer Aufgabe einen leeren Platzhalter.
  - Ablauf in `KassaApp`: kein Katalog → `SetupScreen`. Katalog da, aber niemand angemeldet → `PinScreen`. Sonst `ShellScreen`.

- [ ] **Step 1: Failing tests**

```dart
testWidgets('Einrichtung mit Beispieldaten: Chef-PIN zweimal, dann Kassa', (t) async {
  await pumpApp(t, const KassaApp(), overrides: memoryOverrides());
  await t.tap(find.text('Mit Beispieldaten starten')); await t.pumpAndSettle();
  expect(find.text('Chef-PIN festlegen'), findsOneWidget);
  await typePin(t, '4711'); expect(find.text('PIN wiederholen'), findsOneWidget);
  await typePin(t, '4711'); await t.pumpAndSettle();
  expect(find.byKey(const Key('tab-Kassa')), findsOneWidget);
  expect(find.text('Chef'), findsOneWidget);
});
testWidgets('unterschiedliche PINs: Hinweis und noch einmal', (t) async { /* 4711, dann 4712:
  'Die PINs sind nicht gleich. Bitte noch einmal.' und wieder 'Chef-PIN festlegen' */ });
testWidgets('fehlerhafte Datei zeigt alle Fehler und spielt nichts ein', (t) async {
  await pumpApp(t, const KassaApp(), overrides: memoryOverrides(pickedFile: '{"betrieb":"X","kategorien":[],"artikel":[{"id":"x"}],"auswahlgruppen":{}}'));
  await t.tap(find.text('Speisekarte einspielen')); await t.pumpAndSettle();
  expect(find.text('Artikel "x": Name fehlt.'), findsOneWidget);
  expect(find.text('Speisekarte einspielen'), findsOneWidget);
});
testWidgets('Datei mit Mitarbeitern legt diese an', (t) async { /* Datei mit
  "mitarbeiter":[{"name":"Anna","pin":"1234","rolle":"mitarbeiter"}]: nach der Einrichtung meldet '1234' Anna an,
  Reiter 'Abschluss' fehlt */ });
testWidgets('falsche PIN: Hinweis, Punkte leeren sich', (t) async {
  await pumpLoggedOut(t); await typePin(t, '0000'); await t.pump();
  expect(find.text('Diese PIN kennt die Kassa nicht.'), findsOneWidget);
});
testWidgets('Tipp auf den Namen in der Kopfleiste meldet ab', (t) async { /* danach PinScreen */ });
```

- [ ] **Step 2:** FAIL prüfen.
- [ ] **Step 3:** Umsetzen nach den Bildschirmen aus Task 1. Mitarbeiter aus `Catalog.staffSeeds` werden beim Einspielen angelegt. Die PIN wird nach der vierten Ziffer von selbst geprüft.
- [ ] **Step 4:** PASS, Commit.

### Task 13: Kassenbildschirm

**Files:**
- Create: `app/lib/features/kassa/kassa_screen.dart`, `category_rail.dart`, `item_grid.dart`, `item_tile.dart`, `modifier_panel.dart`, `cart_panel.dart`, `cart_controller.dart` (alle in `app/lib/features/kassa/`)
- Test: `app/test/features/kassa_test.dart`, `app/test/golden/kassa_golden_test.dart`

**Interfaces:**
- Consumes: `Cart`, `Selection` (Task 5), `CatalogRepository`, `SettingsRepository.readDraft/writeDraft` (Task 7), Bausteine (Task 11).
- Produces:
  - `class CartController extends Notifier<Cart> { void add(Item item, {List<ModifierOption> options}); void setQuantity(String lineId, int q); void remove(String lineId); void clear(); void restore(Cart cart); }`, `cartProvider`. Jede Änderung schreibt den Bon-Entwurf, beim Start wird er gelesen.
  - Schlüssel: `Key('cat-<id>')`, `Key('item-<id>')`, `Key('opt-<optionId>')`, `Key('add-to-cart')`, `Key('line-<lineId>')`, `Key('qty-plus-<lineId>')`, `Key('qty-minus-<lineId>')`, `Key('remove-<lineId>')`, `Key('clear-cart')`, `Key('cart-total')`, `Key('pay-cash')`, `Key('pay-card')`
  - `KassaScreen({required VoidCallback onPayCash})`

- [ ] **Step 1: Failing tests**

```dart
testWidgets('Tipp auf Artikel legt ihn auf den Bon, Pfand steht getrennt', (t) async {
  await pumpKassa(t);
  await t.tap(find.byKey(const Key('cat-getraenke'))); await t.pump();
  await t.tap(find.byKey(const Key('item-cola'))); await t.tap(find.byKey(const Key('item-cola'))); await t.pump();
  expect(find.text('2 × Cola 0,33 l'), findsOneWidget);
  expect(find.text('Pfand'), findsOneWidget); expect(find.text('0,50 €'), findsOneWidget);
  expect(textOf(t, const Key('cart-total')), '6,30 €');
});
testWidgets('Artikel mit Auswahl: "Auf den Bon" erst, wenn die Pflichtgruppen gewählt sind', (t) async {
  await pumpKassa(t); await t.tap(find.byKey(const Key('item-huhn-bowl'))); await t.pump();
  expect(t.widget<PrimaryButton>(find.byKey(const Key('add-to-cart'))).onPressed, isNull);
  expect(find.text('Basis wählen'), findsOneWidget);
  await t.tap(find.byKey(const Key('opt-bowl/1/0'))); await t.tap(find.byKey(const Key('opt-bowl/0/1'))); await t.pump();
  await t.tap(find.byKey(const Key('add-to-cart'))); await t.pump();
  expect(textOf(t, const Key('cart-total')), '11,90 €');
  expect(find.text('XXL, Reis'), findsOneWidget);
});
testWidgets('Bon leeren lässt sich rückgängig machen', (t) async {
  await pumpKassaWith(t, ['cola', 'teigtaschen']);
  await t.tap(find.byKey(const Key('clear-cart'))); await t.pump();
  expect(textOf(t, const Key('cart-total')), '0,00 €');
  await t.tap(find.text('Rückgängig')); await t.pump();
  expect(textOf(t, const Key('cart-total')), '9,65 €');
});
testWidgets('leerer Bon: Bar ist gesperrt. Karte ist in dieser Version immer gesperrt', (t) async {
  await pumpKassa(t);
  expect(t.widget<PrimaryButton>(find.byKey(const Key('pay-cash'))).onPressed, isNull);
  expect(t.widget<PrimaryButton>(find.byKey(const Key('pay-card'))).onPressed, isNull);
});
testWidgets('Artikel, die nicht im Verkauf sind, lassen sich nicht antippen', (t) async { /* cola inSale false:
  Tipp ändert den Bon nicht, Taste zeigt 'Nicht im Verkauf' */ });
testWidgets('Favoriten stehen als erste Kategorie, wenn es welche gibt', (t) async { /* ohne Favorit: keine
  Kategorie 'Favoriten', erste Kategorie 'Bowls' gewählt. Mit Favorit cola: 'Favoriten' zuerst und gewählt */ });
testWidgets('der offene Bon ist nach einem Neustart wieder da', (t) async {
  await pumpKassaWith(t, ['cola']); await pumpKassa(t, sameDatabase: true); // neuer ProviderScope, gleiche Datenbank
  expect(textOf(t, const Key('cart-total')), '3,15 €');
});
testWidgets('lange Namen und 99 Stück laufen nicht über', (t) async { /* Artikel mit 60 Zeichen Namen, Menge 99,
  Größe 960x600, textScale 1.3: t.takeException() ist null */ });
// Bildvergleich: Kassa mit drei Zeilen am Bon und offene Bowl-Auswahl, hell und dunkel bei 1280x800, hell bei 960x600
```

- [ ] **Step 2:** FAIL prüfen.
- [ ] **Step 3:** Umsetzen nach `DESIGN.md`: Kategorien links, Artikel in der Mitte, Bon rechts, unten Bar und Karte. Spaltenzahl der Artikel aus der Breite der Mitte (Zielbreite einer Taste wie im Entwurf bei 4 Spalten und 1280 dp). Kompakte Tasten als Voreinstellung, Tasten mit Bild, wenn `showImages` an ist (ohne Foto der Platzhalter). Der Bon ändert sich sofort beim Tippen. Eine Zeile verschwindet über ihre Löschen-Taste oder wenn die Menge auf 0 geht. Die Auswahl öffnet in der Mitte anstelle der Artikel. Unter "Karte" steht klein "kommt mit Schritt 3".
- [ ] **Step 4:** Bilder erzeugen, mit `kassenbildschirm-*.png` aus den Projektdateien vergleichen, PASS, Commit.

### Task 14: Bar zahlen

**Files:**
- Create: `app/lib/features/kassa/cash_sheet.dart`, `app/lib/features/kassa/sale_done.dart`
- Modify: `app/lib/features/kassa/kassa_screen.dart`
- Test: `app/test/features/cash_test.dart`

**Interfaces:**
- Consumes: `cashSuggestions`, `changeCents` (Task 6), `ReceiptRepository.finalizeCashSale` (Task 8), `KeypadInput(maxIntDigits: 6)`, `sessionProvider`, `cartProvider`.
- Produces: Schlüssel `Key('given-<cents>')`, `Key('other-amount')`, `Key('finish-sale')`, `Key('change')`, `Key('next-customer')`

- [ ] **Step 1: Failing tests**

```dart
testWidgets('passend ist vorgewählt, Vorschlag zeigt Rückgeld', (t) async {
  await openCash(t, ['cola', 'teigtaschen', 'teigtaschen']); // 16,15 €
  expect(find.byKey(const Key('given-1615')), findsOneWidget);
  await t.tap(find.byKey(const Key('given-2000'))); await t.pump();
  expect(textOf(t, const Key('change')), '3,85 €');
});
testWidgets('anderer Betrag: zu wenig sperrt Abschließen und zeigt "Fehlt noch"', (t) async {
  await openCash(t, ['cola', 'teigtaschen', 'teigtaschen']);
  await t.tap(find.byKey(const Key('other-amount'))); await tapKeys(t, '1 0');
  expect(find.text('Fehlt noch'), findsOneWidget); expect(textOf(t, const Key('change')), '6,15 €');
  expect(t.widget<PrimaryButton>(find.byKey(const Key('finish-sale'))).onPressed, isNull);
  await tapKeys(t, 'back back 1 7 , 5'); 
  expect(textOf(t, const Key('change')), '1,35 €');
});
testWidgets('Abschließen speichert den Bon, leert den Bon und zeigt das Rückgeld', (t) async {
  await openCash(t, ['cola']); await t.tap(find.byKey(const Key('given-500')));
  await t.tap(find.byKey(const Key('finish-sale'))); await t.pumpAndSettle();
  expect(find.text('Bon Nr. 1'), findsOneWidget); expect(find.text('Rückgeld 1,85 €'), findsOneWidget);
  await t.tap(find.byKey(const Key('next-customer'))); await t.pump();
  expect(textOf(t, const Key('cart-total')), '0,00 €');
});
testWidgets('zwei schnelle Tipps auf Abschließen ergeben einen Bon', (t) async {
  await openCash(t, ['cola']);
  await t.tap(find.byKey(const Key('finish-sale'))); await t.tap(find.byKey(const Key('finish-sale'), skipOffstage: false), warnIfMissed: false);
  await t.pumpAndSettle();
  expect(await receiptCount(t), 1);
});
testWidgets('Summe 0,00 € lässt sich abschließen', (t) async { /* leitungswasser: finish-sale aktiv, Bon Nr. 1 */ });
testWidgets('Summe über 9.999,99 €: der Betrag lässt sich eintippen', (t) async { /* 99 x Artikel zu 150,00:
  other-amount, '1 5 0 0 0' ergibt gegeben 15.000,00 €, Abschließen aktiv */ });
```

- [ ] **Step 2:** FAIL prüfen.
- [ ] **Step 3:** Umsetzen. Die `saleId` entsteht einmal beim Öffnen des Bar-Blatts (uuid). Nach dem Abschließen: Bon-Entwurf löschen, Fertig-Ansicht zeigen. Texte: mit Geldlade "Rückgeld aus der Lade geben", ohne Geldlade "Rückgeld geben". Gedruckt wird in Teil A nichts.
- [ ] **Step 4:** PASS, Commit.

### Task 15: Bereich Bons

**Files:**
- Create: `app/lib/features/bons/bons_screen.dart`, `receipt_list.dart`, `receipt_detail.dart`
- Test: `app/test/features/bons_test.dart`, Bildvergleich in `app/test/golden/bons_golden_test.dart`

**Interfaces:**
- Consumes: `ReceiptRepository.watchDay`, `voidReceipt`, `DayRepository.openDay`, `SettingsRepository`, `sessionProvider`.
- Produces: Schlüssel `Key('receipt-<number>')`, `Key('filter-<alle|bar|karte|storniert>')`, `Key('void-receipt')`, `Key('confirm-void')`

- [ ] **Step 1: Failing tests**

```dart
testWidgets('Liste des offenen Tages, neuester zuerst, Detail rechts', (t) async {
  await pumpBonsWithSales(t, 3);
  expect(t.getTopLeft(find.byKey(const Key('receipt-3'))).dy, lessThan(t.getTopLeft(find.byKey(const Key('receipt-1'))).dy));
  await t.tap(find.byKey(const Key('receipt-2'))); await t.pump();
  expect(find.text('Bon Nr. 2'), findsOneWidget); expect(find.text('Bar'), findsWidgets);
  expect(find.text('20 % MwSt'), findsOneWidget);
});
testWidgets('Stornieren fragt einmal nach und legt einen Storno-Bon an', (t) async {
  await pumpBonsWithSales(t, 1); await t.tap(find.byKey(const Key('receipt-1'))); await t.pump();
  await t.tap(find.byKey(const Key('void-receipt'))); await t.pump();
  expect(find.text('Bon Nr. 1 stornieren?'), findsOneWidget);
  await t.tap(find.byKey(const Key('confirm-void'))); await t.pumpAndSettle();
  expect(find.text('Storniert'), findsWidgets);
  expect(find.byKey(const Key('receipt-2')), findsOneWidget);
  expect(find.byKey(const Key('void-receipt')), findsNothing); // schon storniert
});
testWidgets('Filter "storniert" zeigt nur stornierte Bons', (t) async { /* 2 Verkäufe, einer storniert */ });
testWidgets('mit "Storno nur für den Chef" sieht die Mitarbeiterin keine Storno-Taste', (t) async { /* voidRequiresChef */ });
testWidgets('ohne Bons steht ein Hinweis', (t) async { /* 'Heute gibt es noch keine Bons.' */ });
```

- [ ] **Step 2:** FAIL prüfen.
- [ ] **Step 3:** Umsetzen nach dem Bild "Bons" im Entwurf. "Nochmal drucken" kommt erst mit Teil B und wird hier nicht gezeigt.
- [ ] **Step 4:** PASS, Commit.

### Task 16: Bereich Übersicht

**Files:**
- Create: `app/lib/features/overview/overview_screen.dart`, `revenue_chart.dart`
- Test: `app/test/features/overview_test.dart`, Bildvergleich in `app/test/golden/overview_golden_test.dart`

**Interfaces:**
- Consumes: `StatsRepository.overview` (Task 10), `Segmented` (Task 11).
- Produces: Schlüssel `Key('range-<today|days7|days30>')`, `Key('bar-<index>')`, `Key('revenue')`, `Key('bar-detail')`

- [ ] **Step 1: Failing tests**

```dart
testWidgets('zeigt Umsatz, Anzahl, Zahlungsarten und Meistverkauft', (t) async {
  await pumpOverviewWithSales(t); // zwei Verkäufe zu 18,20 € um 11 und 13 Uhr
  expect(textOf(t, const Key('revenue')), '36,40 €');
  expect(find.text('2 Bons'), findsOneWidget);
  expect(find.text('Cola 0,33 l'), findsOneWidget);
});
testWidgets('Tipp auf einen Balken zeigt dessen Wert', (t) async {
  await pumpOverviewWithSales(t); await t.tap(find.byKey(const Key('bar-0'))); await t.pump();
  expect(textOf(t, const Key('bar-detail')), '11 Uhr: 18,20 €');
});
testWidgets('Umschalten auf 7 Tage lädt sieben Balken', (t) async {
  await pumpOverviewWithSales(t); await t.tap(find.byKey(const Key('range-days7'))); await t.pumpAndSettle();
  expect(find.byKey(const Key('bar-6')), findsOneWidget); expect(find.byKey(const Key('bar-7')), findsNothing);
});
testWidgets('ohne Bons: Hinweis statt leerer Balken', (t) async { /* 'Noch keine Bons in diesem Zeitraum.' */ });
```

- [ ] **Step 2:** FAIL prüfen.
- [ ] **Step 3:** Umsetzen nach dem Bild "Übersicht". Balken selbst gezeichnet (kein Diagramm-Paket): höchstens 24 dp breit, oben 4 dp gerundet, eine Farbe, Tippfläche größer als der Balken, Beschriftung nur an jedem zweiten oder fünften Balken. Zahlungsarten als ein geteilter Balken mit Beschriftung "Bar" und "Karte". Zahlen in Tinte, nicht in der Akzentfarbe.
- [ ] **Step 4:** PASS, Commit.

### Task 17: Bereich Artikel

**Files:**
- Create: `app/lib/features/items/items_screen.dart`, `item_detail.dart`
- Test: `app/test/features/items_test.dart`

**Interfaces:**
- Consumes: `CatalogRepository.watch`, `updateItem`, `KeypadInput(maxIntDigits: 4)`, `AppToggle`.
- Produces: Schlüssel `Key('row-<itemId>')`, `Key('fav-<itemId>')`, `Key('insale-<itemId>')`, `Key('edit-price')`, `Key('save-price')`, `Key('toggle-deposit')`, `Key('toggle-vegan')`, `Key('toggle-spicy')`

- [ ] **Step 1: Failing tests**

```dart
testWidgets('"Im Verkauf" aus wirkt sofort in der Kassa', (t) async {
  await pumpItems(t); await t.tap(find.byKey(const Key('insale-cola'))); await t.pump();
  expect((await catalog(t)).item('cola').inSale, isFalse);
});
testWidgets('Preis über das Zahlenfeld ändern', (t) async {
  await pumpItems(t); await t.tap(find.byKey(const Key('row-cola'))); await t.tap(find.byKey(const Key('edit-price')));
  await tapKeys(t, '3 , 2'); await t.tap(find.byKey(const Key('save-price'))); await t.pump();
  expect((await catalog(t)).item('cola').priceCents, 320);
  expect(find.text('3,20 €'), findsWidgets);
});
testWidgets('leerer Preis lässt sich nicht speichern', (t) async { /* save-price gesperrt, solange nichts getippt ist */ });
testWidgets('Pfand-Schalter setzt 25 Cent oder 0', (t) async { /* teigtaschen: an ergibt 25, wieder aus ergibt 0 */ });
testWidgets('Vegan und Scharf lassen sich einzeln schalten, Favorit über den Stern', (t) async { /* tags, favorite */ });
```

- [ ] **Step 2:** FAIL prüfen.
- [ ] **Step 3:** Umsetzen nach dem Bild "Artikel". Namen, Fotos und neue Artikel gibt es hier nicht, darunter steht der Hinweis "Namen, Fotos und neue Artikel kommen aus der Verwaltung."
- [ ] **Step 4:** PASS, Commit.

### Task 18: Bereich Abschluss

Wartet auf Nikos Ja zu den Bildschirmen aus Task 1.

**Files:**
- Create: `app/lib/features/close/close_screen.dart`, `cash_movement_sheet.dart`, `count_cash_sheet.dart`, `forgotten_close_banner.dart`
- Modify: `app/lib/features/shell/shell_screen.dart` (Hinweis auf vergessenen Abschluss)
- Test: `app/test/features/close_test.dart`, Bildvergleich in `app/test/golden/close_golden_test.dart`

**Interfaces:**
- Consumes: `DayRepository` (Task 9), `KeypadInput(maxIntDigits: 6)`, `SettingsRepository`.
- Produces: Schlüssel `Key('set-float')`, `Key('cash-in')`, `Key('cash-out')`, `Key('reason-<bank|purchase|change|other>')`, `Key('save-movement')`, `Key('expected-cash')`, `Key('difference')`, `Key('count-next')`, `Key('close-day')`, `Key('forgotten-close')`

- [ ] **Step 1: Failing tests**

```dart
testWidgets('erster Tag fragt nach dem Wechselgeld', (t) async {
  await pumpCloseWithSales(t, 1); // 18,20 € bar
  expect(find.text('Wie viel Wechselgeld war am Morgen in der Lade?'), findsOneWidget);
  await tapKeys(t, '1 5 0'); await t.tap(find.byKey(const Key('set-float'))); await t.pumpAndSettle();
  expect(textOf(t, const Key('expected-cash')), '168,20 €');
});
testWidgets('Bargeld entnehmen mit Grund senkt das Soll', (t) async {
  await pumpCloseReady(t); // Wechselgeld 150,00, ein Verkauf 18,20
  await t.tap(find.byKey(const Key('cash-out'))); await tapKeys(t, '2 0');
  expect(t.widget<PrimaryButton>(find.byKey(const Key('save-movement'))).onPressed, isNull); // Grund fehlt
  await t.tap(find.byKey(const Key('reason-purchase'))); await t.tap(find.byKey(const Key('save-movement'))); await t.pumpAndSettle();
  expect(textOf(t, const Key('expected-cash')), '148,20 €');
  expect(find.text('Einkauf'), findsOneWidget);
});
testWidgets('Zählen zeigt den Unterschied, dann "In der Lade lassen", dann ist der Tag zu', (t) async {
  await pumpCloseReady(t); await tapKeys(t, '1 6 8');
  expect(textOf(t, const Key('difference')), '−0,20 €');
  await t.tap(find.byKey(const Key('count-next'))); await t.pump();
  expect(find.text('Wie viel bleibt in der Lade?'), findsOneWidget);
  await tapKeys(t, '1 5 0'); await t.tap(find.byKey(const Key('close-day'))); await t.pumpAndSettle();
  expect(find.text('Der Tag ist abgeschlossen.'), findsOneWidget);
  expect(find.text('Entnommen: 18,00 €'), findsOneWidget);
});
testWidgets('mehr in der Lade lassen als gezählt geht nicht', (t) async { /* close-day gesperrt, Hinweis
  'Mehr als gezählt kann nicht in der Lade bleiben.' */ });
testWidgets('ohne Geldlade heißt der Teil "Bargeld"', (t) async { /* cashDrawerEnabled false: 'Bargeld', nicht 'Geldlade' */ });
testWidgets('kein offener Tag: Hinweis und der letzte Abschluss', (t) async { /* 'Es gibt keinen offenen Tag.' */ });
testWidgets('vergessener Abschluss: Hinweis nach der Anmeldung, Bonieren bleibt möglich', (t) async {
  await pumpShellNextMorningWithOpenDay(t);
  expect(find.byKey(const Key('forgotten-close')), findsOneWidget);
  expect(find.text('Der letzte Tag ist noch nicht abgeschlossen.'), findsOneWidget);
  await t.tap(find.byKey(const Key('item-cola'))); await t.pump();
  expect(textOf(t, const Key('cart-total')), '3,15 €');
});
```

- [ ] **Step 2:** FAIL prüfen.
- [ ] **Step 3:** Umsetzen nach dem Bild "Abschluss" und den Bildschirmen aus Task 1. Einnahmen nach Zahlungsart, Steuer nach Satz, Liste der Bargeld-Bewegungen. Gründe: Bank, Einkauf, Wechselgeld, Sonstiges. Der Hinweis auf den vergessenen Abschluss hat für den Chef die Taste "Jetzt abschließen", für Mitarbeiter nur den Text.
- [ ] **Step 4:** PASS, Commit.

### Task 19: Einstellungen

**Files:**
- Create: `app/lib/features/settings/settings_screen.dart`
- Modify: `app/lib/app.dart` (Thema folgt der Einstellung)
- Test: `app/test/features/settings_test.dart`

**Interfaces:**
- Consumes: `SettingsRepository`, `CatalogRepository.importCatalog`, `MenuFilePicker`, `AppToggle`, `Segmented`.
- Produces: Schlüssel `Key('toggle-drawer')`, `Key('toggle-images')`, `Key('theme-<system|light|dark>')`, `Key('toggle-void-chef')`, `Key('reimport')`, `Key('confirm-reimport')`

- [ ] **Step 1: Failing tests**

```dart
testWidgets('Geldlade aus wird gespeichert', (t) async {
  await pumpSettings(t); await t.tap(find.byKey(const Key('toggle-drawer'))); await t.pump();
  expect((await settingsOf(t)).cashDrawerEnabled, isFalse);
});
testWidgets('dunkle Ansicht schaltet das Thema um', (t) async {
  await pumpAppLoggedInAsChef(t); await openSettings(t);
  await t.tap(find.byKey(const Key('theme-dark'))); await t.pumpAndSettle();
  expect(Theme.of(t.element(find.byType(SettingsScreen))).brightness, Brightness.dark);
});
testWidgets('Speisekarte neu einspielen fragt nach und meldet das Ergebnis', (t) async {
  await pumpSettings(t, pickedFile: demoOhneTeigtaschen);
  await t.tap(find.byKey(const Key('reimport'))); await t.pumpAndSettle();
  expect(find.text('Preise und Namen kommen neu aus der Datei. Favoriten und "Im Verkauf" bleiben.'), findsOneWidget);
  await t.tap(find.byKey(const Key('confirm-reimport'))); await t.pumpAndSettle();
  expect(find.text('Speisekarte eingespielt: 13 Artikel.'), findsOneWidget);
});
testWidgets('Geräte, die es in dieser Version noch nicht gibt, sind als solche beschriftet', (t) async {
  await pumpSettings(t);
  expect(find.text('Bondrucker: kommt mit dem nächsten Teil'), findsOneWidget);
  expect(find.text('Kartenterminal: kommt mit Schritt 3'), findsOneWidget);
  expect(find.textContaining('Kundenanzeige'), findsNothing);
});
```

- [ ] **Step 2:** FAIL prüfen.
- [ ] **Step 3:** Umsetzen nach dem Bild "Einstellungen". Unten steht die Versionsnummer der App.
- [ ] **Step 4:** `flutter analyze` ohne Meldung, ganzer `flutter test` PASS, Commit.

### Task 20: Installationsdatei bauen und an Niko geben

**Files:**
- Create: `tool/setup_android.sh`, `tool/build_apk.sh`, `docs/testen/teil-a-pruefliste.md`
- Modify: `app/android/app/build.gradle.kts` (Signatur aus einer Datei außerhalb des Repos), `.gitignore`

**Interfaces:**
- Produces: `tool/build_apk.sh` schreibt `kassa-<version>.apk` in den Ordner `kassa-build` der Projektdateien.

- [ ] **Step 1:** Die Cloud-Umgebung darf `dl.google.com` nicht erreichen (geprüft am 17.11.2026, Antwort 403). Den Host über die Umgebungseinstellung anfragen, Niko bestätigt auf einer Karte. Ohne Freigabe hier stoppen und Niko fragen, nichts vortäuschen.
- [ ] **Step 2:** `tool/setup_android.sh`: Android-Kommandozeilenwerkzeuge nach `~/android-sdk` laden, Lizenzen annehmen, die Plattform und Build-Tools installieren, die `flutter doctor` für Flutter 3.50.0 verlangt. `flutter doctor` zeigt bei "Android toolchain" einen Haken.
- [ ] **Step 3:** Einen Test-Schlüssel erzeugen (`keytool -genkeypair`, Gültigkeit 10000 Tage) und zusammen mit `key.properties` im Ordner `kassa-build` der Projektdateien ablegen, nie im Repo. `build.gradle.kts` liest den Pfad aus der Umgebungsvariable `KASSA_KEY_PROPERTIES`. `.gitignore` um `*.jks`, `*.keystore`, `key.properties` ergänzen. Gibt es den Schlüssel schon, denselben weiterverwenden, sonst lässt sich ein Update nicht über die alte Version installieren.
- [ ] **Step 4:** `tool/build_apk.sh` ausführen: `flutter build apk --release`. Prüfen: `git status` zeigt keinen Schlüssel, die Datei liegt im Ordner `kassa-build`.
- [ ] **Step 5:** `docs/testen/teil-a-pruefliste.md` schreiben, in einfachen Worten zum Abhaken: installieren, Speisekarten-Datei aufs Tablet laden und einspielen, Chef-PIN festlegen, zehn Bons bonieren (mit Bowl-Auswahl und Pfand), bar mit Vorschlag und mit eigenem Betrag, einen Bon stornieren, Übersicht ansehen, Preis ändern, Artikel aus dem Verkauf nehmen, Bargeld entnehmen, Tag abschließen, App wegwischen mit offenem Bon und wieder öffnen, dunkle Ansicht. Zu jedem Punkt, was man sehen soll.
- [ ] **Step 6:** Commit. Installationsdatei, Speisekarten-Datei des Pilotbetriebs und Prüfliste an Niko geben. Rückmeldungen als neue Aufgaben aufnehmen.

---

## Selbstprüfung gegen den Entwurf

| Entwurf | Aufgabe |
|---|---|
| 5.3 Kassa (Tasten, Auswahl, Pfand, Bon leeren, Bar) | 5, 6, 13, 14 |
| 5.3 Karte | nicht in Teil A (Schritt 3), Taste gesperrt in 13 |
| 5.3 Bons, Storno | 8, 15 |
| 5.3 Übersicht | 10, 16 |
| 5.3 Artikel | 7, 17 |
| 5.3 Abschluss, Wechselgeld, Einlegen und Entnehmen, Tag, vergessener Abschluss | 9, 18 |
| 5.3 Einstellungen (Geldlade, Bilder, dunkel) | 7, 19 |
| 5.3 Anmeldung und Rollen, Storno nur für Chef | 7, 11, 12, 15 |
| 5.3 Kopplung mit Code | Teil C. In Teil A ersetzt die Ersteinrichtung aus der Datei die Kopplung. |
| 5.4 Daten | 4, 7, 8, 9 |
| 5.5 ohne Internet | ganze App, kein Netzwerkzugriff |
| 5.9 Einspiel-Format, Anhang A | 4, 12, 19 |
| 5.11 Gestaltung, DESIGN.md | 1, 2, 11 und die Bildvergleiche |
| 5.14 Tests, Bildvergleich in zwei Größen, Prüfliste an echter Hardware | alle, 11, 13, 20 |
| 5.7 Druck, Geldlade öffnen, "Geräte testen", Fehlerberichte | Teil B |
| 5.5 Abgleich, 5.10 Anbieter-Seite, Fotos | Teil C |

Entscheidungen in diesem Plan, die der Entwurf offen lässt:

- Ersteinrichtung ohne Server: Speisekarte aus einer Datei am Tablet, Chef-PIN am Gerät. Die Datei darf zum Testen Mitarbeiter mit PIN enthalten.
- Mitarbeiter sehen nur die Reiter Kassa und Bons.
- Vorschläge beim Bar zahlen: passend, dann der nächste Betrag in Schritten von 5, 10, 20, 50 und 100 €, wie im Entwurf gezeichnet.
- Das Zahlenfeld nimmt beim Bezahlen und Zählen sechs Stellen vor dem Komma, beim Preis vier.
- Der offene Bon wird laufend gespeichert und übersteht einen Neustart der App.
- Artikel-Tasten sind in Teil A kompakt voreingestellt, weil Fotos erst mit dem Server kommen.
- Paketname der App `io.github.n1kob1ko.kassa`. Er lässt sich bis zum Play Store noch ändern, danach nicht mehr.
