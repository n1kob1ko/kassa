# Sprachen und Küchenbon Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Die Kassa am Tablet ist in fünf Sprachen bedienbar (Deutsch, Englisch, Chinesisch, Türkisch, Arabisch von rechts nach links), die Speisekarte hat ein Wörterbuch mit Übersetzungen, und ein neuer Küchenbon kommt in einer eigenen Sprache als Bild aus dem Bondrucker oder einem Küchendrucker.

**Architecture:** Texte der Oberfläche über Flutters `gen-l10n` (ARB-Dateien, erzeugte Klasse `L10n`, im Repo eingecheckt). Übersetzungen der Speisekarte als Wörterbuch pro Betrieb (Name aus der Speisekarte zu Übersetzung je Sprache): eigene Tabelle am Server (`translations`, Migration `0003`), neue Art `translations` im Holen, eigene Tabelle am Tablet (Datenbank 7), Nachschlagen über `MenuDictionary`. Der Küchenbon ist ein reiner Aufbau (`KitchenTicket`), wird mit `dart:ui` zu einem 1-Bit-Bild gezeichnet und als Raster (`GS v 0`) durch die Warteschlange des vorhandenen Druckers geschickt.

**Tech Stack:** Flutter 3.50 (flutter_riverpod, drift, `package:material_ui`, `flutter_localizations`, `intl`), Fastify + PostgreSQL (TypeScript, zod, vitest), React 19 + react-router + TanStack Query (vitest, Playwright).

**Spec:** `docs/superpowers/specs/2026-11-26-sprachen-und-kuechenbon-design.md`. Bilder: `docs/superpowers/specs/bilder/2026-11-26-sprachen-entwurf.html` (Aufbau des Küchenbons, Abschnitte Sprache und Küche, Sprachtaste, Seite Übersetzungen).

## Global Constraints

- Zweig `claude/project-thread-0rpvma`, nur dorthin pushen. Kein PR. Commit-Nachrichten deutsch, ohne Modellnamen, mit den zwei Schlusszeilen aus der Sitzung.
- Das Repo ist öffentlich: keine Schlüssel, keine echten Zahlen. Beispiele sind erfunden ("Beispiel-Imbiss").
- `app/lib/rksv/` wird nicht angefasst. Kundenbon (`receipt_layout.dart`), Berichte (`report_layout.dart`), Testdruck und "Angaben für FinanzOnline" bleiben Deutsch und unverändert.
- Deutsch bleiben auch die Bildschirme der Einrichtung: `features/setup/`, und in `features/settings/`: `signature_panel`, `signer_choice_screen`, `credentials_screen`, `card_check_screen`, `card_setup_screen`, `card_panel`, `card_pin_sheet`, `cash_box_id_sheet`, `setup_facts_screen`, `probe_question`, `go_live_question`, `rksv_task_row`, `protocol_export_sheet`, `printer_panel`, `device_test_screen`, `connection_check_screen`, `server_panel`, `pair_question`, `reimport_panel`. Dort keine Texte herausziehen.
- Sprachen und Kürzel: `de`, `en`, `zh`, `tr`, `ar`. Namen in der Auswahl immer: `Deutsch`, `English`, `中文`, `Türkçe`, `العربية`. Neu installiert und nach dem Update: `de`.
- Alle bisherigen Tests laufen unverändert auf Deutsch weiter. Ein deutscher Text ändert sich durch das Herausziehen nicht, auch kein Leerzeichen.
- Am Tablet wird nichts getippt (`app/test/no_text_field_test.dart` bleibt grün). Tippflächen mindestens 48 dp, Sprachtasten mindestens 64 dp hoch.
- Beträge, Datum, Uhrzeit sehen in jeder Sprache gleich aus ("12,90 €", 26.11.2026, 14:32, Ziffern 0 bis 9). Beträge stehen immer in Leserichtung links nach rechts.
- Nie ein leerer Name, nie `?` statt eines Namens: fehlt eine Übersetzung oder ist sie leer, gilt der Name aus der Speisekarte.
- Der Verkauf wartet nie auf den Küchenbon und scheitert nie an ihm. Der Küchenbon schreibt nichts in die Datenbank.
- Datenbank am Tablet wird Version 7 (Migration mit Test, Abzug `drift_schemas/drift_schema_v7.json`, erzeugte Test-Schemas). Server: neue Datei `server/migrations/0003_translations.sql`; `0001` und `0002` nie ändern.
- Ein Tablet mit 1.9.0 muss mit dem neuen Server weiter abgleichen, und ein Tablet mit 1.10.0 mit einem alten Server (Antwort ohne `translations`).
- Farben, Maße, Abstände nur aus `KassaTokens`/`KassaColors` und `DESIGN.md`; im Web nur aus `styles/tokens.css`. Hell und dunkel.
- Tests zuerst (TDD). Flutter: `~/flutter/bin/flutter` (sonst `tool/setup_flutter.sh`). Hier nur die betroffenen Testdateien laufen lassen; die ganze Suite läuft auf GitHub (Workflows `app`, `server`). Server: `cd server && npx vitest run test/<datei>` (vorher `server/tool/test-db.sh start`). Web: `cd web && npm test`, `npm run typecheck`.
- Vorhandene Goldens dürfen sich nicht ändern, außer die Aufgabe sagt es.

## Review Focus

1. **Lange oder fremde Namen:** ein türkischer Name mit 45 Zeichen, ein arabischer Name, ein lateinischer Name in arabischer Zeile. Artikeltaste, Bon-Zeile und Küchenbon brechen um, nichts läuft über oder wird abgeschnitten (Tests in Aufgabe 9, 10 und 12).
2. **Übersetzung, die nichts sagt:** nur Leerzeichen, gleich dem Namen, oder ein Name mit Leerzeichen am Rand. Gilt als "keine", das Feld im Browser zeigt sie nicht als übersetzt (Tests in Aufgabe 2 und 4).
3. **Küchendrucker aus, Bondrucker an (und umgekehrt):** der Verkauf ist fertig, der Kundenbon gedruckt, "Küchenbon nicht gedruckt" steht da, "Küchenbon drucken" druckt nach (Tests in Aufgabe 13 und 14).
4. **Alter Bon, geänderte Speisekarte:** Küchenbon für einen Bon, dessen Artikel inzwischen stillgelegt oder umbenannt ist. Er kommt mit den Namen aus dem Bon (Test in Aufgabe 11).
5. **Wechsel der Sprache mitten im Verkauf:** offener Bon bleibt, Beträge bleiben, kein Absturz; nach Neustart gilt die gewählte Sprache (Test in Aufgabe 7).

---

## Stufe 1: Daten

### Task 1: Sprache, Einstellungen und Datenbank 7 am Tablet

**Files:**
- Create: `app/lib/core/app_language.dart`, `app/test/data/migration_v7_test.dart`, `app/tool/make_kassa_v6_fixture.dart`, `app/drift_schemas/drift_schema_v7.json`
- Modify: `app/lib/data/database.dart` (+ `.g.dart`), `app/lib/data/settings_repository.dart`, `app/test/data/generated_migrations/*`, `app/test/data/settings_repository_test.dart`

**Interfaces (Produces):**

```dart
// core/app_language.dart
enum AppLanguage {
  de('Deutsch'), en('English'), zh('中文'), tr('Türkçe'), ar('العربية');
  const AppLanguage(this.nativeName);
  final String nativeName;
  bool get isRtl;                 // nur ar
  Locale get locale;              // Locale(name)
  static AppLanguage byCode(String? code);   // unbekannt oder null: de
}
enum KitchenMode { off, receiptPrinter, kitchenPrinter }

// RegisterSettings, neue Felder (alle mit copyWith):
final AppLanguage language;                 // de
final KitchenMode kitchenMode;              // off
final AppLanguage kitchenLanguage;          // de
final PrinterKind kitchenPrinterKind;       // none
final String? kitchenPrinterAddress;
final String? kitchenPrinterName;
final int kitchenPrinterColumns;            // 48
final Set<String> kitchenSkipCategories;    // leer
RegisterSettings withoutKitchenPrinter();
```

Tabellen: `settings` bekommt `language` (Text, Vorgabe `'de'`), `kitchen_mode` (`'off'`), `kitchen_language` (`'de'`), `kitchen_printer_kind` (`'none'`), `kitchen_printer_address`, `kitchen_printer_name` (beide leer erlaubt), `kitchen_printer_columns` (48), `kitchen_skip_categories` (Text, JSON-Liste, Vorgabe `'[]'`). Neue Tabelle `translations` (`source` Text Primärschlüssel, `values_json` Text). Schritt 7 läuft in einer Transaktion wie `_stepTo6` und ist wiederholbar (prüft `sqlite_master` auf `translations`). Er setzt zusätzlich `sync_state.pull_cursor = 0`, damit das Tablet alles einmal neu holt (Spec 5.4).

- [ ] Test `migration_v7_test.dart`: von der Version-6-Datei (aus `tool/make_kassa_v6_fixture.dart`, Muster wie v5) auf 7: Schema stimmt mit dem Abzug (`SchemaVerifier`), Einstellungen behalten ihre alten Werte und haben die Vorgaben oben, `translations` ist leer, `pull_cursor` ist 0 und `initial_pull_done` bleibt, Bons und Trigger sind unverändert (Zählung vorher und nachher), ein zweiter Lauf des Schritts ändert nichts.
- [ ] Test `settings_repository_test.dart`: speichern und lesen aller neuen Felder; unbekannter Text in `language` gibt `de`; kaputtes JSON in `kitchen_skip_categories` gibt die leere Menge.
- [ ] Umsetzen, `dart run build_runner build`, Abzug mit `dart run drift_dev schema dump` und Test-Schemas mit `dart run drift_dev schema generate` (wie bei Version 6).
- [ ] `flutter test test/data/` grün, `flutter analyze` ohne Befund. Commit.

### Task 2: Wörterbuch am Tablet und in der Speisekarten-Datei

**Files:**
- Create: `app/lib/domain/menu_dictionary.dart`, `app/lib/data/translation_repository.dart`, `shared/fixtures/menu/uebersetzungen.json`, `shared/fixtures/menu/fehler-uebersetzung-*.json` mit `expected/`
- Modify: `app/lib/domain/catalog.dart` (`Catalog.translations`), `app/lib/domain/menu_import.dart`, `app/lib/data/catalog_repository.dart` (`importCatalog`), `app/lib/data/providers.dart`
- Test: `app/test/domain/menu_dictionary_test.dart`, `app/test/domain/menu_import_test.dart`, `app/test/data/translation_repository_test.dart`, `app/test/data/catalog_repository_test.dart`

**Interfaces (Produces):**

```dart
// domain/menu_dictionary.dart (reines Dart)
class MenuDictionary {
  const MenuDictionary(this.entries);         // source -> {lang code -> text}
  static const empty = MenuDictionary({});
  final Map<String, Map<String, String>> entries;
  /// Name in [language]; für de, ohne Treffer oder bei leerem Text: [source].
  String text(String source, AppLanguage language);
  String? textOrNull(String? source, AppLanguage language);   // null bleibt null
}
const translationLanguages = ['en', 'zh', 'tr', 'ar'];

// data/translation_repository.dart
class TranslationRepository {
  Stream<MenuDictionary> watch();
  Future<MenuDictionary> current();
  /// Schreibt Einträge; ein Eintrag ohne Sprachen löscht die Zeile.
  Future<void> upsert(Map<String, Map<String, String>> entries);
  Future<void> clear();
}
// providers.dart
final translationRepositoryProvider; final menuDictionaryProvider /* StreamProvider<MenuDictionary> */;
```

Regeln der Datei (gleich in App und Server, gemeinsame Prüfdaten): Schlüssel `uebersetzungen` ganz oben, freiwillig, ein Objekt `Name -> {Kürzel -> Text}`. Name und Text werden am Rand von Leerzeichen befreit. Leerer Text oder Text gleich dem Namen zählt als "keine". Fehlermeldungen wörtlich:

- kein Objekt: `"uebersetzungen" muss eine Liste von Namen mit ihren Übersetzungen sein.`
- Name nicht in der Speisekarte (Kategorie, Artikel, Info, Gruppe, Option): `Übersetzung "<Name>": Diesen Namen gibt es in der Speisekarte nicht.`
- Kürzel unbekannt: `Übersetzung "<Name>": Die Sprache "<Kürzel>" kennt die Kassa nicht. Erlaubt sind en, zh, tr und ar.`
- Text kein Text: `Übersetzung "<Name>", Sprache "<Kürzel>": Der Text fehlt.`
- Text über 200 Zeichen: `Übersetzung "<Name>", Sprache "<Kürzel>": Höchstens 200 Zeichen.`

`importCatalog`: Einträge aus der Datei ersetzen die gespeicherten je Name und Sprache; was nicht in der Datei steht, bleibt.

- [ ] Tests: `MenuDictionary.text` (Treffer, kein Treffer, leer, de, Leerzeichen am Rand der Quelle); Datei mit `uebersetzungen` gelesen; jede Fehlermeldung über die gemeinsamen Dateien in `shared/fixtures/menu/` (Muster der vorhandenen `fehler-*.json` mit `expected/`); Einspielen behält alte Einträge und überschreibt genannte; `watch()` meldet nach `upsert`.
- [ ] Umsetzen. `flutter test test/domain/menu_dictionary_test.dart test/domain/menu_import_test.dart test/data/translation_repository_test.dart test/data/catalog_repository_test.dart`. Commit.

### Task 3: Wörterbuch am Server (Tabelle, Datei, Holen)

**Files:**
- Create: `server/migrations/0003_translations.sql`, `server/src/menu/translations.ts`, `server/test/translations_import.test.ts`
- Modify: `server/src/menu/parse_menu.ts`, `server/src/menu/import_menu.ts`, `server/src/device/pull.ts`, `server/test/parse_menu.test.ts`, `server/test/import_menu.test.ts`, `server/test/pull.test.ts`, `server/test/schema.test.ts`

**Interfaces (Produces):**

```sql
create table translations (
  business_id uuid not null references businesses (id),
  source text not null,
  values jsonb not null,          -- {"en": "...", "tr": "..."}; {} heißt gelöscht
  change_seq bigint not null,
  primary key (business_id, source)
);
-- Sperre business_isolation wie in 0001, grant select, insert, update, delete to kassa_app
```

```ts
// menu/translations.ts
export const TRANSLATION_LANGS = ['en', 'zh', 'tr', 'ar'] as const;
export type Translations = Record<string, Partial<Record<(typeof TRANSLATION_LANGS)[number], string>>>;
/** Prüft `uebersetzungen` gegen die Namen der Speisekarte; Meldungen wörtlich wie in Aufgabe 2. */
export function parseTranslations(raw: unknown, menuNames: Set<string>, problems: string[]): Translations;
/** Alle Namen einer Speisekarte: Kategorien, Artikel, Infos, Gruppen, Optionen. */
export function menuNames(menu: { categories; items; templates }): Set<string>;
/** Schreibt Einträge (je Name und Sprache ersetzen, Rest bleibt). Nur in withBusinessWrite. Gibt die Zahl geänderter Namen zurück. */
export async function applyTranslations(c: pg.PoolClient, businessId: string, t: Translations): Promise<number>;
```

`ParsedMenu` bekommt `translations: Translations`; `ImportSummary` bekommt `translations: number`. `pull.ts`: neue Art `translations`, Zeile `{ source, values }`, in der Antwort als Liste `translations` (immer vorhanden, auch leer). Nur geänderte Zeilen bekommen eine neue Änderungs-Nummer.

- [ ] Tests: Migration legt Tabelle mit Sperre an (ein Betrieb sieht die Zeilen des anderen nicht); `parse_menu` mit den gemeinsamen Dateien aus Aufgabe 2; Einspielen ersetzt und behält; zweimal dieselbe Datei ändert keine Änderungs-Nummer; `pull` liefert `translations` ab `since` und in der Reihenfolge der Nummern, ein gelöschter Eintrag kommt mit `values: {}`.
- [ ] Umsetzen, `npx vitest run test/parse_menu.test.ts test/import_menu.test.ts test/pull.test.ts test/schema.test.ts test/translations_import.test.ts`, `npm run typecheck`. Commit.

### Task 4: Adressen der Verwaltung für Übersetzungen

**Files:**
- Create: `server/src/admin/translations.ts`, `server/test/translations.test.ts`
- Modify: `server/src/app.ts` (einhängen), `server/src/admin/businesses.ts` (Antwort des Einspielens nennt `translations`)

**Interfaces (Produces):**

```
GET  /api/admin/businesses/:b/translations
     -> { sections: [{ kind: 'categories' | 'category' | 'extras', title: string,
                       rows: [{ source: string, values: { en?: string, zh?: string, tr?: string, ar?: string } }] }],
          total: number, done: { en: number, zh: number, tr: number, ar: number } }
PUT  /api/admin/businesses/:b/translations      body { source, lang, value }   ('' löscht)
     -> { source, values }
POST /api/admin/businesses/:b/translations/import   (nur Anbieter)  body: Text der Datei { "uebersetzungen": {...} }
     -> { changed: number }   | 422 { code: 'translations_invalid', problems: string[] }
```

Abschnitte in dieser Reihenfolge: "Kategorien" (Namen der aktiven Kategorien), dann je aktive Kategorie ihr Name als Titel mit den Namen und Infos ihrer aktiven Artikel, dann "Auswahl und Extras" (Gruppen- und Optionsnamen der Vorlagen, die ein aktiver Artikel nutzt). Jeder Name steht nur beim ersten Vorkommen. `total` ist die Zahl der Zeilen, `done[lang]` die Zahl mit nicht leerer Übersetzung. `PUT`: `source` muss ein Name der Tabelle sein (sonst 404), `lang` aus den vier, `value` am Rand gekürzt, höchstens 200 Zeichen, gleich dem Namen zählt als leer; Zugriff wie bei Artikeln (`requireBusinessAccess`), Eintrag im Verlauf `translation.update`.

- [ ] Tests: Aufbau und Reihenfolge der Abschnitte, doppelter Name nur einmal, stillgelegte fehlen; `PUT` setzt, ändert, löscht, zählt `done` neu, erhöht die Änderungs-Nummer nur bei Änderung; fremder Betrieb 404, Chef eines anderen Betriebs 403/404 wie bei Artikeln; `import` nur Anbieter, meldet Fehler wörtlich, ändert bei Fehlern nichts; Wert nur aus Leerzeichen zählt als leer.
- [ ] Umsetzen, `npx vitest run test/translations.test.ts test/businesses.test.ts`, `npm run typecheck`. Commit.

### Task 5: Abgleich am Tablet

**Files:**
- Modify: `app/lib/sync/wire.dart` (`WireTranslation`, `PullResponse.translations`), `app/lib/sync/server_changes.dart`, `app/test/support/fake_server.dart`
- Test: `app/test/sync/` (vorhandene Dateien für `wire` und `server_changes` erweitern)

**Interfaces:** Consumes `TranslationRepository` (Aufgabe 2). Produces: `PullResponse.translations` (`List<WireTranslation>`, fehlt der Schlüssel: leere Liste), `WireTranslation { String source; Map<String, String> values; }`.

`applyPage` schreibt die Einträge in derselben Transaktion (leere `values` löschen die Zeile). `replaceAll` leert `translations` vorher. Nach dem Schritt auf Version 7 steht der Cursor auf 0: der nächste Lauf holt alles über `applyPage`; der offene Bon und wartende Artikel-Änderungen bleiben.

- [ ] Tests: Antwort ohne `translations` wird gelesen; Einträge kommen an und `menuDictionaryProvider` meldet sie; Löschen; `replaceAll` leert; Holen ab Cursor 0 nach dem Koppeln lässt den offenen Bon und die wartenden Artikel-Felder stehen.
- [ ] `flutter test test/sync/`. Commit.

## Stufe 2: Verwaltung

### Task 6: Seite Übersetzungen im Browser

**Files:**
- Create: `web/src/api/translations.ts`, `web/src/pages/TranslationsPage.tsx`, `web/src/pages/TranslationsPage.module.css`, `web/src/pages/translations.ts` (reine Helfer), `web/src/pages/translations.test.ts`, `web/e2e/translations.spec.ts`
- Modify: `web/src/routes.tsx` (Adresse `/b/:b/uebersetzungen`, Eintrag "Übersetzungen" nach "Speisekarte"), `web/src/ui/icons.tsx` (`LanguagesIcon`), `web/src/api/businesses.ts` (`summaryText` nennt Übersetzungen)

**Aufbau** (Bild "Übersetzungen der Speisekarte im Browser"): `PageHeader` "Übersetzungen" mit `BusinessName`; für den Anbieter die Taste "Übersetzungen einspielen" (Dialog mit `FileDrop`, Fehler als Liste wie beim Einspielen der Speisekarte, Erfolg als Hinweis "N Namen übersetzt."). Darunter `Segmented` mit English, 中文, Türkçe, العربية (gemerkt in `localStorage`, Vorgabe English), rechts der Stand "62 von 140 übersetzt" mit Balken, und der Schalter "Nur fehlende". Dann je Abschnitt eine Karte mit Zeilen: links der Name, rechts ein `TextField` (`lang` und `dir` nach Sprache, Platzhalter ist der Name, `aria-label` "<Name>: <Sprache>"). Speichern beim Verlassen des Feldes oder mit Enter, optimistisch, bei Fehler alter Wert und Hinweis. Laden als Skeleton in der Form der Tabelle, leerer Betrieb mit `EmptyState` "Noch keine Speisekarte.". Am Handy stehen Name und Feld untereinander.

- [ ] `translations.test.ts`: `visibleSections(sections, lang, onlyMissing)` lässt leere Abschnitte weg; `progressText(done, total)` gibt "62 von 140 übersetzt" und "Alles übersetzt." bei voll.
- [ ] `translations.spec.ts` (Playwright, Muster `menu.spec.ts`): Feld füllen, verlassen, neu laden: Wert steht da und der Stand zählt eins mehr; leeren löscht; arabisches Feld hat `dir="rtl"`; "Nur fehlende" blendet übersetzte aus; Datei einspielen mit Fehler zeigt die Meldung.
- [ ] Umsetzen. `npm test`, `npm run typecheck`, `npm run e2e -- --trace off translations.spec.ts`. Commit.

## Stufe 3: Bediensprache

### Task 7: Grundlage für die Sprachen in der App

**Files:**
- Create: `app/l10n.yaml`, `app/lib/l10n/app_de.arb` (Vorlage), `app_en.arb`, `app_zh.arb`, `app_tr.arb`, `app_ar.arb`, `app/lib/l10n/generated/*` (erzeugt, eingecheckt), `app/lib/ui/language_picker.dart`, `app/assets/fonts/NotoSansSC-Medium.ttf`, `NotoSansSC-Bold.ttf`, `NotoSansArabic-Medium.ttf`, `NotoSansArabic-Bold.ttf`, `app/assets/fonts/OFL-Noto.txt`, `app/test/features/language_test.dart`
- Modify: `app/pubspec.yaml` (`flutter_localizations`, `intl`, Schriften), `app/lib/app.dart`, `app/lib/ui/theme.dart` (`fontFamilyFallback: ['Noto Sans Arabic', 'Noto Sans SC']`), `app/lib/features/settings/settings_screen.dart` (Abschnitt "Sprache" als erster), `app/lib/features/login/pin_screen.dart` (Sprachtaste)

**Interfaces (Produces):**

```dart
// erzeugt: lib/l10n/generated/l10n.dart
abstract class L10n { static L10n of(BuildContext context); static const delegate; static const supportedLocales; }
L10n lookupL10n(Locale locale);                 // ohne BuildContext
// ui/language_picker.dart
class LanguagePicker extends StatelessWidget {   // fünf Tasten, Key('language-<code>')
  const LanguagePicker({required this.value, required this.onChanged, this.keyPrefix = 'language'});
}
Future<void> showLanguageSheet(BuildContext context, WidgetRef ref);   // Blatt von unten, wischbar
// app.dart
final appLanguageProvider = Provider<AppLanguage>(...)   // aus settingsStreamProvider, sonst de
```

`l10n.yaml`: `arb-dir: lib/l10n`, `template-arb-file: app_de.arb`, `output-class: L10n`, `output-localization-file: l10n.dart`, `output-dir: lib/l10n/generated`, `nullable-getter: false`, `untranslated-messages-file: build/l10n_untranslated.json`. `MaterialApp` bekommt `locale`, `supportedLocales` und die Delegates für Material (aus `material_ui`), Widgets und Cupertino. Schriften: die 500er und 700er Schnitte aus den npm-Paketen `@fontsource/noto-sans-sc` (Datei `chinese-simplified`) und `@fontsource/noto-sans-arabic` (Datei `arabic`), mit fonttools von woff2 zu ttf (die Cloud-Umgebung erreicht Google Fonts nicht).

Texte dieser Aufgabe: Abschnitt "Sprache", Blatt-Titel "Sprache", Semantik der Sprachtaste "Sprache ändern". Die Sprachtaste am Anmeldebildschirm steht oben am Ende der Zeile (in Arabisch also links), mindestens 52 dp hoch, Weltkugel (`LucideIcons.globe`) und `nativeName`.

- [ ] `language_test.dart`: Tipp auf `language-en` in den Einstellungen stellt sofort um (ein bekannter Text der Seite wechselt) und steht in den Einstellungen der Datenbank; nach neuem Aufbau der App gilt Englisch; `language-ar` gibt `Directionality` rechts nach links; Sprachtaste am Anmeldebildschirm öffnet das Blatt, Wahl schließt es und stellt um; offener Bon bleibt beim Wechsel (Review Focus 5); alle fünf ARB-Dateien haben dieselben Schlüssel (Test liest die Dateien).
- [ ] Umsetzen, `flutter gen-l10n`, `flutter test test/features/language_test.dart test/features/login_test.dart test/features/settings_test.dart`, `flutter analyze`. Goldens von Einstellungen und Anmeldung dürfen sich hier ändern (neuer Abschnitt, neue Taste): neu erzeugen und ansehen. Commit.

### Task 8: Texte herausziehen: Anmeldung, Kopfleiste, gemeinsame Bausteine, Kassa

**Files:** Modify `app/lib/features/login/*`, `app/lib/features/shell/*`, `app/lib/ui/*` (nur Dateien mit Text), `app/lib/features/kassa/*` (alle, auch `outage_banner.dart` und `unclear_card_payment.dart`), `app/lib/devices/printer.dart` (Meldung), ARB-Dateien. Create `app/lib/ui/print_problem_text.dart`.

**Regeln für diese und die nächsten zwei Aufgaben:**

- Jeder sichtbare Text der genannten Dateien wandert nach `app_de.arb` (unverändert) und wird in `en`, `zh`, `tr`, `ar` übersetzt. Im Code steht `L10n.of(context).<schlüssel>`. Schlüssel englisch in lowerCamelCase mit Bereich vorn (`kassaCash`, `bonsVoidQuestion`).
- Texte mit Zahl oder Name sind Nachrichten mit Platzhalter; Mehrzahl mit `{count, plural, ...}` in jeder Sprache nach deren Regeln (Arabisch: zero, one, two, few, many, other).
- Text, der außerhalb eines Widgets entsteht (Dienste, Zustände), wird zu einem Wert (enum oder Klasse), den die Oberfläche übersetzt. `PrintOutcome.message` bleibt für Deutsch bestehen; neu `String printProblemText(L10n l, PrintProblem p)` in `ui/print_problem_text.dart`, und die übersetzten Bildschirme nutzen diese.
- `outage_banner.dart`: Überschrift, Tasten und ein neuer fester Satz werden übersetzt (`outageKeepsWorking`: "Die Kassa läuft weiter. Bitte dem Chef Bescheid geben."). Der Satz mit dem Grund aus `app/lib/rksv/` bleibt wie er ist und wird weiter wörtlich verglichen.
- Übersetzungen kurz und in der Sprache üblicher Kassen (en: Cash, Card, Receipt, Void; tr: Nakit, Kart, Fiş, İptal; zh: 现金, 刷卡, 小票, 作废; ar: نقدًا, بطاقة, الفاتورة, إلغاء). Der Name "Kassa" bleibt als Marke.
- Kein deutscher Test darf sich ändern.

- [ ] Test `app/test/features/l10n_kassa_test.dart`: Kassa in `en`, `zh`, `tr`, `ar` zeigt "Cash"/"现金"/"Nakit"/"نقدًا" auf der Bar-Taste und den übersetzten Titel des Bons; Barzahlung bis "Verkauf fertig" läuft in `tr` durch.
- [ ] Umsetzen, `flutter gen-l10n`; `build/l10n_untranslated.json` ist leer. `flutter test test/features/kassa_test.dart test/features/cash_test.dart test/features/card_test.dart test/features/login_test.dart test/features/outage_banner_test.dart test/features/unclear_card_test.dart test/features/l10n_kassa_test.dart`, `flutter analyze`. Commit.

### Task 9: Texte herausziehen: Bons, Artikel, Übersicht, Abschluss, Einstellungen (Hauptseite), und Namen der Speisekarte am Bildschirm

**Files:** Modify `app/lib/features/bons/*`, `features/items/*`, `features/overview/*`, `features/close/*`, `features/settings/settings_screen.dart`, `settings_rows.dart`, `app/lib/core/german_dates.dart` (bleibt für Zettel), `features/kassa/category_rail.dart`, `item_tile.dart`, `modifier_panel.dart`, `cart_line_row.dart`, `cart_panel.dart`, `features/items/item_row.dart`, `item_detail.dart`, ARB-Dateien. Create `app/lib/ui/menu_text.dart`, `app/lib/ui/dates_text.dart`.

**Interfaces (Produces):**

```dart
// ui/menu_text.dart
/// Schlägt Namen der Speisekarte in der Bediensprache nach.
final menuTextProvider = Provider<String Function(String source)>(...);   // aus menuDictionaryProvider und appLanguageProvider
// ui/dates_text.dart
String monthName(L10n l, int month);      // 1..12, de: "Jänner"
String weekdayName(L10n l, int weekday);  // 1..7
```

Namen der Speisekarte in der Bediensprache: Kategorien (Leiste, Artikel-Bereich), Artikeltasten samt Info, Gruppen und Optionen im Auswahl-Feld, Zeilen des offenen Bons. Im Bereich Bons bleibt ein gespeicherter Bon bei seinen Namen. Kennzeichen VEGAN und SCHARF sind Texte der App (`tagVegan`, `tagSpicy`). Die Zettel (Tagesabschluss, Monatsabrechnung) bleiben Deutsch: `report_layout.dart` und `germanMonths` dort nicht anfassen.

- [ ] Tests: `app/test/features/l10n_areas_test.dart`: je Bereich in `en` ein Text ("Receipts", "Items", "Overview", "Closing") und in `ar` der Titel; `app/test/features/menu_text_test.dart`: mit einem Wörterbuch `{"Huhn Bowl": {"tr": "Tavuk Bowl"}}` zeigt die Artikeltaste in `tr` "Tavuk Bowl", in `de` und `zh` (keine Übersetzung) "Huhn Bowl"; Option und Bon-Zeile ebenso; ein Name mit 45 Zeichen bricht auf der Taste um ohne Überlauf (Review Focus 1); nach dem Verkauf steht im gespeicherten Bon der Name aus der Speisekarte.
- [ ] Umsetzen, `flutter gen-l10n` ohne offene Texte. `flutter test test/features/bons_test.dart test/features/items_test.dart test/features/overview_test.dart test/features/close_test.dart test/features/close_month_test.dart test/features/settings_test.dart test/features/l10n_areas_test.dart test/features/menu_text_test.dart`, `flutter analyze`. Commit.

### Task 10: Arabisch von rechts nach links, und kein Überlauf in fünf Sprachen

**Files:** Modify alle übersetzten Dateien unter `app/lib/features/{login,shell,kassa,bons,items,overview,close}/`, `features/settings/settings_screen.dart`, `settings_rows.dart`, `app/lib/ui/*`. Create `app/test/features/l10n_layout_test.dart`, `app/lib/ui/ltr.dart`.

**Regeln:** `EdgeInsets.only(left/right)`, `EdgeInsets.fromLTRB`, `Alignment.*Left/Right`, `Positioned(left/right)`, `BorderRadius.only`, `TextAlign.left/right`, `Border(left/right)` werden zu ihren Formen mit Anfang und Ende (`EdgeInsetsDirectional`, `AlignmentDirectional`, `PositionedDirectional`, `BorderRadiusDirectional`, `TextAlign.start/end`, `BorderDirectional`). Symbole für "zurück" und "weiter" (Pfeile, Winkel) spiegeln sich. Nicht gespiegelt, über `Ltr` (ein `Directionality` links nach rechts): Ziffernfelder (`ui/keypad.dart`, `address_keypad.dart`, PIN, Betrags-Eingabe), jeder Betrag und jede Uhrzeit (Text bleibt in LTR, die Ausrichtung in der Zeile folgt der Sprache), das Diagramm der Übersicht. In den deutsch bleibenden Bildschirmen nichts ändern; sie stehen in einem `Ltr`, damit sie in Arabisch nicht halb gespiegelt sind.

```dart
// ui/ltr.dart
class Ltr extends StatelessWidget { const Ltr({required this.child}); }   // Directionality(textDirection: ltr)
```

- [ ] `l10n_layout_test.dart`: für jede der fünf Sprachen bei 1280×800 und bei 1024×600 werden Anmeldung, Kassa (mit Bon und offenem Auswahl-Feld), Bar-Blatt, Verkauf fertig, Bons mit Detail, Artikel, Übersicht, Abschluss Tag und Monat, Einstellungen gezeichnet: kein Überlauf (kein `FlutterError` mit "overflowed"), jeder `Text` innerhalb seines Elternrahmens. In `ar`: die Kategorien-Leiste liegt rechts vom Artikelraster, der Bon links davon; die Taste "1" des Ziffernfelds liegt links von "3"; ein Betrag "12,90 €" hat `TextDirection.ltr`. Mit einem türkischen Wörterbuch aus langen Namen (45 Zeichen) kein Überlauf (Review Focus 1).
- [ ] Umsetzen. Zusätzlich Goldens `test/golden/l10n_golden_test.dart`: Kassa in `zh` und `ar`, Anmeldung in `ar` (mit den mitgelieferten Schriften geladen). Die deutschen Goldens bleiben unverändert.
- [ ] `flutter test test/features/l10n_layout_test.dart test/golden/`, `flutter analyze`. Commit.

## Stufe 4: Küchenbon

### Task 11: Aufbau des Küchenbons

**Files:** Create `app/lib/domain/kitchen_ticket.dart`, `app/test/domain/kitchen_ticket_test.dart`. Modify ARB-Dateien (Texte des Zettels).

**Interfaces (Produces):**

```dart
enum KitchenTicketKind { order, voided, copy, sample }
class KitchenLine { const KitchenLine({required this.quantity, required this.name, this.info, this.options = const []});
  final int quantity; final String name; final String? info; final List<String> options; }
class KitchenTicket { const KitchenTicket({required this.language, required this.kind, required this.title, this.banner,
    required this.number, required this.time, required this.staffName, required this.lines});
  final AppLanguage language; final KitchenTicketKind kind;
  final String title;      // "KÜCHE" in der Küchensprache
  final String? banner;    // "STORNO", "KOPIE" oder "PROBE" in der Küchensprache, sonst null
  final int number; final DateTime time; final String staffName; final List<KitchenLine> lines; }
class KitchenTexts { const KitchenTexts({required this.title, required this.voided, required this.copy, required this.sample}); }

/// `null`, wenn der Bon kein Verkauf oder Storno ist oder keine Zeile für die Küche hat.
KitchenTicket? buildKitchenTicket(Receipt receipt, {
  required AppLanguage language, required KitchenTexts texts, required MenuDictionary dictionary,
  required Map<String, String> categoryOfItem,       // itemId -> categoryId, aus dem Katalog samt stillgelegten
  required Set<String> skipCategories, bool copy = false,
  int? voidedNumber });                               // Nummer des stornierten Bons, wenn der Aufrufer sie kennt
KitchenTicket sampleKitchenTicket(Catalog catalog, {required AppLanguage language, required KitchenTexts texts,
  required MenuDictionary dictionary, required Set<String> skipCategories, required DateTime now});
```

Regeln: Zeilen in der Reihenfolge des Bons; Anzahl als Betrag (Storno-Bon hat negative); Name `dictionary.text(line.name, language)`, Info und Optionen ebenso über ihren Text; Zeile entfällt, wenn die Kategorie ihres Artikels in `skipCategories` steht; ein Artikel, den der Katalog nicht mehr kennt, zählt als Küche. Storno-Bon: `kind voided`, `banner` = Text STORNO, Nummer ist `voidedNumber` (die Nummer des stornierten Bons), wenn der Aufrufer sie mitgibt, sonst die eigene. `sampleKitchenTicket`: `kind sample`, Banner und Bedienung sind `texts.sample`, Nummer 128, die ersten drei aktiven Artikel aus Kategorien für die Küche mit Anzahl 2, 1, 1 und beim ersten bis zu zwei Optionen seiner Vorlage. Texte in ARB: `kitchenTitle` (KÜCHE, KITCHEN, 厨房, MUTFAK, المطبخ), `kitchenVoided` (STORNO, VOID, 取消, İPTAL, إلغاء), `kitchenCopy` (KOPIE, COPY, 副本, KOPYA, نسخة), `kitchenSample` (PROBE, SAMPLE, 测试, DENEME, تجربة); `KitchenTexts` entsteht aus `lookupL10n(language.locale)`.

- [ ] Tests: Verkauf mit zwei Zeilen und Optionen in `tr` mit Wörterbuch; fehlende Übersetzung gibt den Namen aus dem Bon; Getränke-Kategorie übersprungen; nur Getränke gibt `null`; Sonderbeleg gibt `null`; Storno hat Banner und positive Anzahl; stillgelegter und unbekannter Artikel bleiben mit dem Namen aus dem Bon (Review Focus 4); `copy: true` setzt Banner KOPIE; Probe mit leerer Speisekarte hat eine Zeile mit dem Probe-Text statt abzustürzen.
- [ ] `flutter test test/domain/kitchen_ticket_test.dart`. Commit.

### Task 12: Küchenbon als Bild und als Druckdaten

**Files:** Create `app/lib/devices/kitchen_ticket_image.dart`, `app/lib/devices/mono_image.dart`, `app/test/devices/kitchen_ticket_image_test.dart`, `app/test/devices/mono_image_test.dart`, `app/test/golden/kitchen_ticket_golden_test.dart`. Modify `app/lib/devices/escpos.dart`, `app/test/devices/escpos_test.dart`, `app/test/support/` (Helfer `loadBundledFonts()`).

**Interfaces (Produces):**

```dart
// devices/mono_image.dart (reines Dart)
class MonoImage { MonoImage(this.width, this.height, this.bits);   // 1 Bit je Punkt, Zeilen auf ganze Bytes
  final int width; final int height; final Uint8List bits; int get rowBytes; bool at(int x, int y);
  factory MonoImage.fromRgba(Uint8List rgba, int width, int height, {int threshold = 160}); }
// devices/escpos.dart
/// Initialisieren, Bild in Streifen zu höchstens 240 Zeilen (GS v 0), 3 Zeilen Vorschub, Schnitt.
Uint8List encodeRasterTicket(MonoImage image);
// devices/kitchen_ticket_image.dart (dart:ui)
/// Breite in Punkten: Spalten des Druckers mal 12 (48 -> 576, 32 -> 384, 42 -> 504).
Future<ui.Image> paintKitchenTicket(KitchenTicket ticket, {required int widthDots});
Future<MonoImage> renderKitchenTicket(KitchenTicket ticket, {required int widthDots});
```

Zettel (Bild "Was aus dem Drucker kommt", Maße für 576 Punkte, bei schmalerem Papier im selben Verhältnis): Rand 12; Kopfzeile Titel 52 px fett am Anfang, Nummer 64 px fett am Ende; Banner (STORNO, KOPIE, PROBE) darüber, 44 px fett, weiß auf schwarzem Balken über die ganze Breite; Zeile Datum, Uhrzeit, Bedienung 26 px; gestrichelte Linie 3 px; je Zeile Anzahl mit "×" und Name 44 px fett, Name bricht um und rückt unter den Namen ein; Info 30 px; Optionen 34 px halbfett eingerückt unter dem Namen; gestrichelte Linie; 24 px Rand unten. Schrift `Figtree` mit Rückfall `Noto Sans Arabic`, `Noto Sans SC`, jeweils ausdrücklich im Textstil. Leserichtung des ganzen Zettels nach `ticket.language.isRtl`; Datum, Uhrzeit und Nummer in LTR. Weißer Grund, schwarze Schrift, keine Graustufen nach der Schwelle.

- [ ] Tests: `MonoImage.fromRgba` (Schwelle, Bit-Reihenfolge, Zeilen auf Bytes); `encodeRasterTicket` (Kopf `1B 40`, je Streifen `1D 76 30 00` mit Breite und Höhe, 500 Zeilen geben 3 Streifen, Ende mit Vorschub und Schnitt); `renderKitchenTicket`: Breite genau `widthDots`, Höhe wächst mit den Zeilen, bei `ar` liegt die Schwärzung der Namenszeile in der rechten Hälfte und bei `tr` in der linken, ein Name mit 45 Zeichen gibt mehr Höhe statt Überlauf (Review Focus 1), kein Punkt außerhalb. Goldens je Sprache (`de`, `en`, `zh`, `tr`, `ar`) bei 576 und `tr` bei 384, plus Storno.
- [ ] `flutter test test/devices/ test/golden/kitchen_ticket_golden_test.dart`. Die Goldens ansehen (Schrift lesbar, Arabisch verbunden, Chinesisch ohne Kästchen). Commit.

### Task 13: Küchenbon drucken (Drucker, Verkauf, Storno)

**Files:** Modify `app/lib/devices/printer.dart` (`printRaster`), `app/lib/devices/device_providers.dart`, `app/lib/features/kassa/sale_service.dart`, `app/test/support/fake_devices.dart`. Create `app/lib/features/kassa/kitchen_service.dart`, `app/test/features/kitchen_service_test.dart`. Modify `app/test/devices/printer_test.dart`, `app/test/features/sale_service_test.dart`.

**Interfaces (Produces):**

```dart
// ReceiptPrinter, neu:
/// Schickt fertige Rasterdaten durch dieselbe Warteschlange wie die Bons. Zeitlimit [rasterCallLimit].
Future<PrintOutcome> printRaster(Future<Uint8List> Function() bytes);
const rasterCallLimit = Duration(seconds: 20);
// device_providers.dart
/// Drucker für den Küchenbon: bei `receiptPrinter` der Bondrucker (dieselbe Instanz), bei `kitchenPrinter` ein
/// eigener mit dem Küchen-Transport, bei `off` null.
final kitchenPrinterProvider = Provider<ReceiptPrinter?>(...);
typedef KitchenImageRenderer = Future<MonoImage> Function(KitchenTicket, {required int widthDots});
final kitchenImageRendererProvider = Provider<KitchenImageRenderer>((ref) => renderKitchenTicket);
// features/kassa/kitchen_service.dart
class KitchenService {
  /// `null`: für diesen Bon ist kein Küchenbon fällig (aus, Sonderbeleg, keine Zeile für die Küche).
  Future<PrintOutcome?> printFor(Receipt receipt, {bool copy = false});
  Future<PrintOutcome> printSample();
}
final kitchenServiceProvider = Provider<KitchenService>(...);
// SaleResult, neu:
final PrintOutcome? kitchen;
```

Ablauf in `SaleService` nach dem Speichern: bei `receiptPrinter` erst der Kundenbon wie bisher, danach der Küchenbon (eigener Auftrag, eigene Schnitte); bei `kitchenPrinter` beide gleichzeitig (`Future.wait`). Storno: ebenso. Ist `kitchenPrinter` gewählt, aber kein Küchendrucker eingerichtet: `PrintOutcome.failed(notSetUp)`. Jede Ausnahme im Küchenbon (Aufbau, Zeichnen, Senden) wird zu `PrintOutcome.failed(unreachable)`; das Ergebnis des Kundenbons und der Verkauf bleiben davon unberührt.

- [ ] Tests: `printRaster` läuft in der Warteschlange hinter einem laufenden Bon und bricht nach dem Limit ab; Verkauf mit `off` ruft den Küchendrucker nie und `kitchen` ist `null`; `receiptPrinter`: Reihenfolge am Transport ist Kundenbon dann Raster; `kitchenPrinter`: Küchen-Transport bekommt das Raster, Bondrucker den Bon; Küchendrucker wirft: Verkauf ist gespeichert, `print.ok`, `kitchen.problem` gesetzt (Review Focus 3); Bondrucker scheitert, Küchendrucker druckt; nur Getränke: `kitchen` ist `null`; Storno druckt mit Banner; `printFor(copy: true)` druckt KOPIE; in den Tests ersetzt ein falscher Zeichner `kitchenImageRendererProvider`.
- [ ] `flutter test test/devices/printer_test.dart test/features/sale_service_test.dart test/features/kitchen_service_test.dart`. Commit.

### Task 14: Küchenbon in der Oberfläche

**Files:** Create `app/lib/features/settings/kitchen_section.dart`, `app/lib/features/settings/kitchen_preview.dart`, `app/test/features/kitchen_settings_test.dart`. Modify `app/lib/features/settings/settings_screen.dart`, `printer_panel.dart` (Parameter für den Küchendrucker, Texte bleiben Deutsch), `app/lib/features/kassa/sale_done.dart`, `app/lib/features/bons/receipt_detail.dart`, ARB-Dateien, `app/test/features/kassa_test.dart`, `bons_test.dart`.

**Aufbau** (Bild "Einstellungen am Tablet"): Abschnitt **Küche** nach "Geräte an dieser Kassa". Zeile "Küchenbon" mit drei Segmenten (`Key('kitchen-mode-off|receiptPrinter|kitchenPrinter')`): "Aus", "Am Bondrucker", "Am Küchendrucker". Ab hier nur sichtbar, wenn nicht "Aus": "Sprache am Küchenbon" mit `LanguagePicker(keyPrefix: 'kitchen-language')`; bei "Am Küchendrucker" die Zeile "Küchendrucker" (Name oder "Nicht eingerichtet", öffnet `PrinterPanel` für den Küchendrucker; ist keiner eingerichtet, steht darunter in Warnfarbe "Kein Küchendrucker eingerichtet. Es kommt kein Küchenbon."); "Kategorien für die Küche" mit einem Schalter je aktiver Kategorie (`Key('kitchen-category-<id>')`, Name in der Bediensprache); daneben (ab 1000 dp Breite, sonst darunter) die Vorschau: das Bild von `paintKitchenTicket(sampleKitchenTicket(...))` auf Papierweiß, höchstens 300 dp breit; Taste "Probe drucken" (`Key('kitchen-sample')`) mit Ergebnis darunter ("Probe gedruckt." oder Meldung des Druckers). Alles speichert sofort.

"Verkauf fertig": ist `result.kitchen` gesetzt und nicht ok, steht unter dem Druckzustand die Zeile "Küchenbon nicht gedruckt" mit der Meldung des Druckers und die Taste "Küchenbon drucken" (`Key('kitchen-reprint')`); nach Erfolg "Küchenbon gedruckt.". Bons, Detail eines Verkaufs des offenen Tages: Taste "Küchenbon drucken" neben "Bon drucken", nur wenn der Küchenbon nicht "Aus" ist; druckt als Kopie.

- [ ] Tests: Umschalten der Segmente blendet die Zeilen ein und speichert; Sprache am Küchenbon ändert die Bediensprache nicht und umgekehrt; Schalter einer Kategorie landet in `kitchenSkipCategories`; Vorschau zeichnet sich neu, wenn die Sprache wechselt; "Probe drucken" ruft `printSample`; "Verkauf fertig" zeigt Zeile und Taste bei gescheitertem Küchenbon und druckt nach; kein Hinweis bei `kitchen == null`; Taste im Bon-Detail nur für Verkäufe und nur wenn eingeschaltet; alle neuen Texte in fünf Sprachen, `l10n_layout_test.dart` um den Abschnitt Küche erweitert.
- [ ] `flutter test test/features/kitchen_settings_test.dart test/features/kassa_test.dart test/features/bons_test.dart test/features/settings_test.dart test/features/l10n_layout_test.dart`, `flutter analyze`. Goldens der Einstellungen neu erzeugen und ansehen. Commit.

## Stufe 5: Prüfung und Übergabe

### Task 15: Version, Prüfliste, Listen zum Gegenlesen

**Files:** Modify `app/pubspec.yaml` (`1.10.0+12`), `app/lib/core/app_info.dart`, `PRODUCT.md` (Satz zur Sprache), `docs/superpowers/specs/2026-11-26-sprachen-und-kuechenbon-design.md` (Abschnitt 10 "Abweichungen und Entscheidungen beim Bau"). Create `app/tool/l10n_review.dart`, `docs/uebersetzungen/en.md`, `zh.md`, `tr.md`, `ar.md`, `docs/testen/sprachen-pruefliste.md`.

`l10n_review.dart` schreibt je Sprache eine Tabelle "Deutsch | Übersetzung | Wo" aus den ARB-Dateien (Schlüssel als "Wo", Bereich aus dem Vorsatz). Die Prüfliste für Niko, in einfachen Worten: Teil A am Tablet ohne Drucker (Sprache wechseln, Anmeldung, Arabisch gespiegelt, Verkauf in jeder Sprache), Teil B im Browser (Übersetzungen eintragen, am Tablet nach dem Abgleich sichtbar), Teil C mit Drucker (Küchenbon in jeder Schrift lesbar, Schnitt zwischen Kundenbon und Küchenbon, Geschwindigkeit, zweiter Drucker, Probe drucken), Teil D zum Gegenlesen (Listen an jemanden geben, der die Sprache spricht).

- [ ] Umsetzen, `dart run tool/l10n_review.dart`, alles committen und pushen.
- [ ] GitHub: Workflows `app` und `server` für den Commit grün (Ergebnis lesen; schlägt etwas fehl, hier nur die betroffenen Tests wiederholen).
- [ ] Gesamtprüfung durch einen frischen Prüfer über den ganzen Zweig gegen Spec und Plan; Befunde beheben.
