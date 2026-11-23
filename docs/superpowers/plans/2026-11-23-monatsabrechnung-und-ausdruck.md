# Monatsabrechnung und Ausdruck Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Am Tablet unter Abschluss eine Monatsabrechnung für abgeschlossene Monate (ein Monat oder mehrere) mit Ausdruck am Bondrucker, ein gedruckter Tagesabschluss, und dieselben Monate im Browser mit Druckansicht.

**Architecture:** Alle Zahlen werden bei jedem Öffnen aus den gespeicherten Bons gerechnet, am Tablet in einem neuen `PeriodReportRepository` (drift), am Server in `admin/months.ts` (PostgreSQL). Beide prüfen sich über eine gemeinsame Beispieldatei. Die Zettel sind reine Layout-Funktionen (`PrintOp`-Listen) und laufen durch die Warteschlange des vorhandenen `ReceiptPrinter`. Keine neue Tabelle, keine Migration.

**Tech Stack:** Flutter 3.50 (flutter_riverpod, drift, `package:material_ui`), Fastify + PostgreSQL 16 (TypeScript, zod, vitest), React 19 + react-router + TanStack Query (vitest, Playwright).

**Spec:** `docs/superpowers/specs/2026-11-23-monatsabrechnung-und-ausdruck-design.md` (Regeln R1 bis R12 in 5.1, Zettel in 5.3). Bilder: https://claude.ai/artifact/63kcWgcCYNasZ3c2nh8FkL, Quelldateien `/mnt/project-files/kassa-entwurf/monat/project/*.dc.html` (Maße und Farben der Bildschirme).

## Global Constraints

- Zweig `claude/project-thread-cdsc7e`, nur dorthin pushen. Kein PR. Commit-Nachrichten deutsch, ohne Modellnamen.
- Das Repo ist öffentlich: keine Schlüssel, keine echten Zahlen. Beispielzahlen sind erfunden.
- `app/lib/rksv/` wird nicht angefasst. Die Datenbank am Tablet bleibt Version 6, am Server keine Migration.
- Ein Bericht schreibt nichts: kein Bon, keine Bon-Nummer, kein Eintrag im Protokoll der Signatur, kein Schreiben in die Datenbank.
- "Tag abschließen" wartet nie auf den Drucker und scheitert nie an ihm.
- Am Tablet wird nichts getippt (`app/test/no_text_field_test.dart` bleibt grün). Tippflächen mindestens 48 dp, Monatstasten und Jahrespfeile mindestens 56 dp.
- Oberfläche deutsch, Bezeichner englisch. Monatsnamen aus `germanMonths` ("Jänner"). Farben, Maße, Abstände nur aus `KassaTokens`/`KassaColors` und `DESIGN.md`; im Web nur aus `styles/tokens.css`. Hell und dunkel.
- Texte, wörtlich: "Bericht drucken", "Bericht gedruckt.", "Abrechnung gedruckt.", "Kein Drucker eingerichtet.", "In diesem Zeitraum gibt es keine Bons.", "Die erste Monatsabrechnung gibt es ab 1. Dezember." (Datum des Ersten des Folgemonats), "Kommt von selbst mit dem nächsten Bon.", "Testbetrieb", "Kein Beleg".
- Tests zuerst (TDD). Flutter: `~/flutter/bin/flutter` (ist installiert, sonst `tool/setup_flutter.sh`). Hier nur die betroffenen Testdateien laufen lassen; die ganze App-Suite läuft auf GitHub (Workflow `app`). Server: `cd server && npx vitest run test/<datei>`. Web: `cd web && npm test`, `npm run typecheck`.
- Bildvergleiche (Goldens) neu erzeugen mit `flutter test --update-goldens <datei>`; vorhandene Goldens dürfen sich nicht ändern, außer die Aufgabe sagt es.
- `/mnt/project-files/` ist ein Netz-Ordner: Pfad mit Schrägstrich am Ende, nie den ganzen Ordner durchsuchen.

## Review Focus

1. **Bons mit Datum in der Zukunft oder zurückgestellte Uhr:** Monate ab dem laufenden Monat erscheinen nie, die Abrechnung stürzt nicht ab (Test in Aufgabe 1).
2. **Langer Zeitraum mit leeren Monaten** (35 Monate, die meisten ohne Bons): eine Zeile je Monat, auch 0, und kein Laden aller Bons der Datenbank (Test in Aufgabe 1, Zettel in Aufgabe 2).
3. **Zeitraum wechseln oder doppelt tippen, während gedruckt wird:** ein Druck, und die Meldung des alten Zeitraums verschwindet beim Wechsel (Test in Aufgabe 5).
4. **Von Hand getippte Adresse im Browser** (`/monate/2026-13`, `/monate/abc`, `/monate/2026-10..2026-01`): das Blatt sagt "Diese Abrechnung gibt es nicht.", nichts stürzt ab (Tests in Aufgabe 6 und 7).
5. **Drucken im dunklen Modus des Browsers:** die Druckansicht ist schwarz auf weiß (Test in Aufgabe 7).

---

### Task 1: Rechnen am Tablet (Monat, Zeitraum, Auswahl)

**Files:**
- Create: `app/lib/domain/period_report.dart`, `app/lib/domain/period_selection.dart`, `app/lib/data/period_report_repository.dart`
- Modify: `app/lib/domain/day.dart` (zwei Felder), `app/lib/data/day_repository.dart` (`_summarize`), `app/lib/data/providers.dart` (Provider), `app/lib/core/money.dart` (`groupThousands`), `app/test/support/sales.dart` (`TestShop.periods`)
- Test: `app/test/domain/period_report_test.dart`, `app/test/domain/period_selection_test.dart`, `app/test/data/period_report_repository_test.dart`, `app/test/data/day_repository_test.dart`, `app/test/core/money_test.dart`

**Interfaces (Produces):**

```dart
// domain/period_report.dart (reines Dart)
class YearMonth implements Comparable<YearMonth> {
  const YearMonth(this.year, this.month);          // month 1..12
  factory YearMonth.of(DateTime t);
  final int year; final int month;
  DateTime get start;      // DateTime(year, month)
  DateTime get end;        // DateTime(year, month + 1), ausschließlich
  DateTime get lastDay;    // DateTime(year, month + 1, 0)
  YearMonth get next; YearMonth get previous;
  String get key;          // "2026-10"
  // ==, hashCode, compareTo
}
class MonthRange {                                   // ==, hashCode
  const MonthRange(this.from, this.to);              // from <= to
  final YearMonth from; final YearMonth to;
  bool get single;
  List<YearMonth> get months;                        // aufsteigend, beide Enden
  String get key;                                    // "2026-10..2026-10"
}
/// "Oktober 2026", "Jänner bis Oktober 2026", "November 2025 bis Februar 2026".
String periodTitle(MonthRange r);
class PeriodRow { const PeriodRow({required this.start, required this.receiptCount, required this.revenueCents}); }
class PeriodReport {
  range, testMode,
  receiptCount, cashReceiptCount, cardReceiptCount,   // Verkäufe minus Storno-Bons
  voidCount, voidedCents,                             // voidedCents positiv
  revenueCents, cashRevenueCents, cardRevenueCents, depositCents,
  List<TaxLine> taxLines,                             // R6 je Monat, über den Zeitraum summiert, nach Satz absteigend
  int? firstNumber, int? lastNumber,                  // kleinste und größte Nummer der gezählten Bons
  List<PeriodRow> rows;   // ein Monat: je Kalendertag mit Bon (R8); mehrere: je Monat, auch leere (R12)
  bool get isEmpty;       // firstNumber == null
}
class MonthChoice {
  const MonthChoice({this.first, this.last, required this.nextAvailable});
  final YearMonth? first; final YearMonth? last;      // beide null: noch kein abgeschlossener Monat
  final DateTime nextAvailable;                       // Erster des Folgemonats von jetzt
  bool allows(YearMonth m);
}

// domain/period_selection.dart (reines Dart)
class PeriodSelection {
  const PeriodSelection({this.rangeMode = false, this.from, this.to});
  PeriodSelection tap(YearMonth m);
  PeriodSelection withMode({required bool rangeMode});   // behält from, setzt to = null (Von bis) bzw. to = from
  MonthRange? get range;                                 // nur from: MonthRange(from, from)
  bool marks(YearMonth m);                               // m liegt im gewählten Bereich
}

// data/period_report_repository.dart
class PeriodReportRepository {
  PeriodReportRepository(KassaDatabase db, Clock clock);
  Future<MonthChoice> choice();
  Future<PeriodReport> report(MonthRange range);  // ArgumentError, wenn ein Monat nicht in choice() liegt
  Future<String?> signatureReceiptId(YearMonth month); // frühester Bon der Art month oder year mit createdAt >= month.end
  Future<bool> hasSignature();                    // es gibt eine Zeile in RksvChainRows
}

// domain/day.dart: DaySummary bekommt `this.firstNumber, this.lastNumber` (int?, optional, Standard null)
// core/money.dart: String groupThousands(int n)  // 1067 -> "1.067", -12285 -> "-12.285"
// data/providers.dart
final periodReportRepositoryProvider = Provider<PeriodReportRepository>(...);
```

Regeln für `PeriodSelection.tap`: Ein Monat: `from = to = m`. Von bis: ohne `from` wird `m` der Beginn; mit Beginn und ohne Ende: `m < from` setzt den Beginn neu, sonst ist `m` das Ende (auch `m == from`); mit Beginn und Ende beginnt der Tipp von vorn (`from = m`, `to = null`).

Regeln für das Repository (Spec R1 bis R12):
- Gezählt werden Bons der Art `sale` und `voided` mit `createdAt` in `[month.start, month.end)`. Abgefragt wird mit Zeitgrenzen in SQL; nie alle Bons, Zahlungen oder Zeilen der Datenbank laden (anders als `StatsRepository`).
- Echt (R3): Gibt es irgendeinen Eintrag in `RksvEntryRows`, dessen Kette in `RksvChainRows` `mode == 'live'` hat, zählen nur Bons mit so einem Eintrag und `testMode` ist falsch. Sonst zählen alle und `testMode` ist wahr.
- Bar ist `PaymentRows.kind == 'cash'`, Karte alles andere (wie `DayRepository._summarize`).
- Steuer: je Monat `taxBreakdown` auf der Brutto-Summe des Monats je Satz; Brutto, Netto und Steuer je Satz über die Monate addieren; Sätze mit Brutto 0 im ganzen Zeitraum fehlen.
- `choice()`: `last` ist der Monat vor dem laufenden (Uhr), `first` der Monat des ältesten gezählten Bons. Liegt `first` nach `last` oder gibt es keinen Bon: beide `null`.

- [ ] **Step 1: Tests für die reinen Klassen schreiben** (`period_report_test.dart`, `period_selection_test.dart`, `money_test.dart`)

```dart
test('YearMonth: Grenzen und Nachbarn', () {
  const m = YearMonth(2026, 12);
  expect(m.start, DateTime(2026, 12)); expect(m.end, DateTime(2027, 1));
  expect(m.lastDay, DateTime(2026, 12, 31)); expect(m.next, const YearMonth(2027, 1));
  expect(const YearMonth(2026, 1).previous, const YearMonth(2025, 12));
  expect(const YearMonth(2024, 2).lastDay.day, 29); expect(m.key, '2026-12');
  expect(YearMonth.of(DateTime(2026, 10, 31, 23, 59)), const YearMonth(2026, 10));
});
test('MonthRange: Monate und Titel', () {
  const r = MonthRange(YearMonth(2025, 11), YearMonth(2026, 2));
  expect(r.months.map((m) => m.key), ['2025-11', '2025-12', '2026-01', '2026-02']);
  expect(periodTitle(r), 'November 2025 bis Februar 2026');
  expect(periodTitle(const MonthRange(YearMonth(2026, 1), YearMonth(2026, 10))), 'Jänner bis Oktober 2026');
  expect(periodTitle(const MonthRange(YearMonth(2026, 10), YearMonth(2026, 10))), 'Oktober 2026');
});
test('Von bis: Beginn, Ende, Tipp davor, dritter Tipp', () {
  const okt = YearMonth(2026, 10), jan = YearMonth(2026, 1), mrz = YearMonth(2026, 3);
  var s = const PeriodSelection(rangeMode: true).tap(mrz);
  expect(s.range, const MonthRange(mrz, mrz));
  s = s.tap(jan);                                   // vor dem Beginn: neuer Beginn
  expect((s.from, s.to), (jan, null));
  s = s.tap(okt);
  expect(s.range, const MonthRange(jan, okt)); expect(s.marks(mrz), isTrue);
  s = s.tap(mrz);                                   // dritter Tipp beginnt von vorn
  expect((s.from, s.to), (mrz, null));
});
test('Ein Monat: jeder Tipp wählt genau diesen Monat', ...);
test('groupThousands', () { expect(groupThousands(1067), '1.067'); expect(groupThousands(-12285), '-12.285'); expect(groupThousands(96), '96'); });
```

- [ ] **Step 2: Laufen lassen, sie scheitern** (`flutter test test/domain/period_report_test.dart test/domain/period_selection_test.dart test/core/money_test.dart`: Klassen fehlen)
- [ ] **Step 3: `period_report.dart`, `period_selection.dart`, `groupThousands` schreiben**, Tests grün.
- [ ] **Step 4: Tests für das Repository schreiben** (`period_report_repository_test.dart`, mit `TestShop`, `shop.periods`). `shop.sell(id)` ist der Barbon über 18,20 € (Brutto 20 %: 5,80, Brutto 10 %: 11,90, Pfand 0,50). Uhr vor jedem Verkauf setzen, am Ende auf "jetzt". Die Brutto-Werte je Satz vor dem Schreiben der Erwartungen einmal am Bon nachsehen (`receipt.taxLines`); weichen sie ab, gelten die des Bons und die Steuer daraus nach `taxBreakdown`.

| Test | Aufbau | Erwartung |
|---|---|---|
| Monatsgrenzen | Verkäufe am 30.9. 23:59, 1.10. 00:00, 31.10. 23:59, 1.11. 00:00; jetzt 17.11.2026 | `report(Okt)`: `revenueCents 3640`, `receiptCount 2`, `rows` = [(1.10., 1, 1820), (31.10., 1, 1820)] |
| Storno in anderem Monat | Verkauf 30.10., `voidReceipt` am 2.11.; jetzt 5.12. | Okt: `(1820, 1, voidCount 0)`; Nov: `revenueCents -1820`, `receiptCount -1`, `voidCount 1`, `voidedCents 1820`, Steuerzeilen negativ |
| Sonderbelege zählen nicht | `insertSpecialReceipt(kind: month)` im Oktober neben einem Verkauf | `receiptCount 1`, `firstNumber == lastNumber` = Nummer des Verkaufs |
| Bar und Karte | `sell` + `insertCardReceipt(…, 965)` im Oktober | `cash (1820, 1)`, `card (965, 1)`, gesamt `(2785, 2)` |
| Steuer und Pfand | zwei Verkäufe im Oktober | 20 %: Brutto 1160, Steuer 193, Netto 967; 10 %: Brutto 2380, Steuer 216, Netto 2164; `depositCents 100` |
| Mehrere Monate: Steuer ist die Summe der Monate | je ein Verkauf im September und Oktober | `report(Sep..Okt)`: 20 %: Brutto 1160, Steuer 194 (97 + 97), Netto 966; `rows` = [(1.9., 1, 1820), (1.10., 1, 1820)]; Summe der zwei Einzelberichte gleich dem Bericht über beide |
| Über den Jahreswechsel | Verkäufe Dez 2025 und Feb 2026; jetzt März 2026 | `report(Dez..Feb).rows` hat drei Zeilen, Jänner mit `(0, 0)` |
| Auswahl | ohne Bon; nur Bons im laufenden Monat; Bons ab September | `first/last` null und `nextAvailable == DateTime(2026, 12, 1)`; null; `first Sep`, `last Okt` |
| Laufender Monat und falsche Reihenfolge | jetzt 17.11. | `report(Nov)` und `report(MonthRange(Okt, Sep))` werfen `ArgumentError` |
| Nur Testbons | Verkäufe ohne Signatur | `testMode` wahr, alle zählen |
| Testbons und echte gemischt | zwei Verkäufe im Oktober, einer mit Eintrag in einer Kette `mode: 'live'` (Zeilen direkt in `rksvChainRows` und `rksvEntryRows` einfügen) | `testMode` falsch, `receiptCount 1`; `choice().first` richtet sich nach dem echten Bon |
| Leerer Monat | Verkauf im September, jetzt November | `report(Okt).isEmpty`, `rows` leer, `taxLines` leer, `choice().last == Okt` |
| Bon in der Zukunft (Review Focus 1) | Verkauf mit Datum 3.2.2027, jetzt 17.11.2026 | `choice().last == Okt 2026`; `report` für Monate bis Oktober zählt ihn nicht, nichts wirft |
| Langer Zeitraum (Review Focus 2) | ein Verkauf im Dez 2023, einer im Okt 2026 | `report(Dez 2023..Okt 2026).rows.length == 35`, Summe 3640 |
| Signaturbeleg | `insertSpecialReceipt(month)` am 1.11. 10:02 und am 1.12. | `signatureReceiptId(Okt)` ist der vom 1.11.; für November der vom 1.12.; ohne Beleg `null` |

Dazu in `day_repository_test.dart`: `summary().firstNumber/lastNumber` sind die kleinste und größte Nummer der Verkaufs- und Storno-Bons des Tages, ohne Bon `null`.

- [ ] **Step 5: Laufen lassen, sie scheitern** (`flutter test test/data/period_report_repository_test.dart test/data/day_repository_test.dart`)
- [ ] **Step 6: `PeriodReportRepository`, die zwei Felder in `DaySummary`/`_summarize`, den Provider und `TestShop.periods` schreiben.**
- [ ] **Step 7: Tests grün**, dazu `flutter analyze` ohne Meldung.
- [ ] **Step 8: Commit** `Monatsabrechnung: Rechnen am Tablet (Monat, Zeitraum, Auswahl)`

---

### Task 2: Die Zettel (Tagesabschluss, Monat, mehrere Monate)

**Files:**
- Create: `app/lib/domain/print_builder.dart`, `app/lib/domain/report_layout.dart`, `app/lib/core/german_dates.dart`
- Modify: `app/lib/domain/receipt_layout.dart` (nutzt `PrintBuilder`), `app/lib/features/bons/bons_screen.dart` (Listen nach `core/german_dates.dart`, dort `export`), `app/lib/domain/day.dart` (`reasonLabel` hierher), `app/lib/features/close/close_format.dart` (`reasonLabel` nur noch `export`; `bonsLabel` mit `groupThousands`)
- Test: `app/test/domain/report_layout_test.dart`; `app/test/domain/receipt_layout_test.dart` bleibt unverändert grün

**Interfaces:**
- Consumes: `PeriodReport`, `MonthRange`, `periodTitle`, `groupThousands`, `DaySummary.firstNumber/lastNumber` (Aufgabe 1).
- Produces:

```dart
// domain/print_builder.dart: der bisherige private _Builder aus receipt_layout.dart, öffentlich, dazu:
class PrintBuilder {
  PrintBuilder(this.columns);
  // text, centered, rule, blank, row, indented wie bisher
  /// Kopf wie am Bon: Name (groß, wenn er in die halbe Breite passt) und Adresse, ohne UID.
  void businessHead(BusinessInfo business);
  /// [label], [middle] endet 15 Zeichen vor dem rechten Rand, [right] rechtsbündig. Passt
  /// `label + ' ' + middle` nicht vor diese Spalte, steht [label] allein in der Zeile darüber.
  void row3(String label, String middle, String right);
}
String dateTimeText(DateTime t);   // "17.11.2026 21:14" (bisher _dateTime)
String dateText(DateTime t);       // "01.10.2026"

// domain/report_layout.dart
List<PrintOp> layoutDayReport(DaySummary s, BusinessInfo business,
    {required String? registerName, required bool drawer, required DateTime printedAt, int columns = 48});
List<PrintOp> layoutPeriodReport(PeriodReport r, BusinessInfo business,
    {required String? registerName, required DateTime printedAt, int columns = 48});
String bonsText(int n);   // "1 Bon", "1.067 Bons", "-1 Bons"
```

Aufbau der Zettel: genau wie die drei Blöcke in Spec 5.3. Reihenfolge: Kopf, Leerzeile, Titel (fett, mittig), Untertitel (mittig), bei `testMode` "Testbetrieb" (mittig), Leerzeile, Kopfzeilen, Linie, "EINNAHMEN" (fett), Linie, "STEUER" (fett), Linie, beim Tag "GELDLADE" oder ohne Lade "BARGELD" (fett), bei mehreren Monaten "MONATE" (fett), Linie, "Gedruckt <Datum Zeit>" (mittig), "Kein Beleg" (mittig), `PrintFeed(3)`, `PrintCut()`. Zeilen fehlen, wenn ihr Wert fehlt: "Kassa" ohne Namen, "Bis" und "Abgeschlossen von" am offenen Tag, "Bons Nr." ohne Bon, "Storniert" bei 0, "Pfand, ohne MwSt" bei 0, "Gezählt", "Unterschied", "In der Lade gelassen", "Entnommen" am offenen Tag. "Soll" ist `day.expectedCents ?? s.expectedCashCents`, "Entnommen" ist gezählt minus in der Lade gelassen. Bewegung: `"HH:MM Eingelegt: <Grund>"` mit positivem, `"HH:MM Entnommen: <Grund>"` mit negativem Betrag.

- [ ] **Step 1: Tests schreiben.** Die Beispielobjekte tragen die Zahlen aus Spec 5.3 (Betrieb "YICHI", "Musterstraße 1", "1010 Wien", Kassa "Theke").

```dart
test('Tagesabschluss, 42 Zeichen: Text wie im Entwurf', () {
  expect(texts(layoutDayReport(daySample, yichi, registerName: 'Theke', drawer: true,
      printedAt: DateTime(2026, 11, 17, 21, 14), columns: 42)), daySlip42);   // Block "Tagesabschluss" aus Spec 5.3, Zeile für Zeile, ohne die Leerzeilen (PrintFeed)
});
test('Monatsabrechnung, 42 Zeichen: Text wie im Entwurf, ohne Tage', ...);     // Block "Monatsabrechnung"
test('Mehrere Monate, 42 Zeichen: ABRECHNUNG mit MONATE', ...);                // Block "Mehrere Monate"
for (final w in [32, 42, 48]) test('Breite $w: keine Zeile ist länger, Beträge stehen rechts', ...);
test('32 Zeichen: "September 2026" steht in eigener Zeile über Anzahl und Betrag', ...);
test('ohne Geldlade heißt der Teil BARGELD', ...);
test('ohne Namen der Kassa fehlt die Zeile Kassa', ...);
test('Testbetrieb steht unter dem Untertitel', ...);
test('Monat nur mit Storno: "-1 Bons" und "-18,20" rechtsbündig', ...);
test('Tag über Mitternacht: Titel trägt den Tag des Öffnens, Bis den nächsten Tag', ...);
test('langer Name des Betriebs bricht um, nicht druckbare Zeichen werden ersetzt', ...);
test('kein QR-Code, keine Lade: nur PrintText und PrintFeed, am Ende PrintFeed(3) und PrintCut', ...);
test('Jahreswechsel: Untertitel "November 2025 bis Februar 2026", Zeitraum "01.11.2025 bis 28.02.2026"', ...);
```

- [ ] **Step 2: Laufen lassen, sie scheitern** (`flutter test test/domain/report_layout_test.dart`)
- [ ] **Step 3: `PrintBuilder` herausziehen** (reines Verschieben, `receipt_layout.dart` verwendet ihn), `flutter test test/domain/receipt_layout_test.dart test/devices` bleibt grün.
- [ ] **Step 4: `german_dates.dart`, `reasonLabel` umziehen, `report_layout.dart` schreiben.**
- [ ] **Step 5: Tests grün**, `flutter analyze` ohne Meldung, `flutter test test/features/close_test.dart test/features/bons_test.dart` grün.
- [ ] **Step 6: Commit** `Monatsabrechnung: Zettel für Tagesabschluss, Monat und mehrere Monate`

---

### Task 3: Drucken (Drucker und Dienst)

**Files:**
- Create: `app/lib/features/close/report_print.dart`
- Modify: `app/lib/devices/printer.dart`, `app/lib/devices/device_providers.dart` (`_NoPrinter`), `app/test/support/fake_devices.dart`, `app/test/features/device_test_test.dart` (`_ThrowingPrinter`)
- Test: `app/test/devices/printer_test.dart`, `app/test/features/report_print_test.dart`

**Interfaces:**
- Consumes: `layoutDayReport`, `layoutPeriodReport` (Aufgabe 2).
- Produces:

```dart
// ReceiptPrinter (Schnittstelle), in EscPosPrinter über _run(checkStatus: true, …), ohne Lade
Future<PrintOutcome> printDayReport(DaySummary summary, {required String? registerName, required bool drawer});
Future<PrintOutcome> printPeriodReport(PeriodReport report, {required String? registerName});

// FakePrinter: Einträge im log "day-report:<Tag-Id>" und "period-report:<range.key>"

// features/close/report_print.dart
class ReportPrintService {
  Future<PrintOutcome> printDay(DaySummary summary);
  Future<PrintOutcome> printPeriod(PeriodReport report);
}
final reportPrintProvider = Provider<ReportPrintService>(...);
/// Wahr, wenn in den Einstellungen ein Drucker eingerichtet ist.
final printerSetUpProvider = Provider<bool>(...);   // settingsStreamProvider, printerKind != none
```

Der Dienst liest Einstellungen (`cashDrawerEnabled`, `printerKind`) und den Namen der Kassa (`syncStateRepositoryProvider`, `registerName`, kann fehlen). Ohne eingerichteten Drucker: `PrintOutcome.failed(notSetUp)` ohne Aufruf des Druckers. Jede Ausnahme wird `failed(unreachable)` (wie `SaleService.printSetupFacts`).

- [ ] **Step 1: Tests schreiben**

```dart
// printer_test.dart
test('printDayReport schickt den Zettel ohne Befehl für die Lade', ...);      // Bytes enthalten "TAGESABSCHLUSS", nicht die Bytes von encodeDrawerKick()
test('printPeriodReport läuft durch dieselbe Warteschlange wie ein Bon', ...); // Bon hängt, Bericht wartet, Reihenfolge bleibt
test('Papier leer: failed(paperOut), nichts wird gesendet', ...);
test('Zeitgrenze: failed(timeout)', ...);
// report_print_test.dart
test('ohne eingerichteten Drucker: notSetUp, der Drucker wird nicht gerufen', ...);
test('Name der Kassa und Geldlade kommen aus dem Stand des Abgleichs und den Einstellungen', ...);
test('wirft der Drucker, ist das Ergebnis unreachable', ...);
```

- [ ] **Step 2: Laufen lassen, sie scheitern.**
- [ ] **Step 3: Schnittstelle, `EscPosPrinter`, `_NoPrinter`, `FakePrinter`, `_ThrowingPrinter`, Dienst und Provider schreiben.**
- [ ] **Step 4: Tests grün**, `flutter analyze` ohne Meldung.
- [ ] **Step 5: Commit** `Monatsabrechnung: Berichte drucken (Drucker und Dienst)`

---

### Task 4: Tablet, Tag: Abschluss druckt von selbst, "Bericht drucken"

**Files:**
- Modify: `app/lib/features/close/close_screen.dart`, `app/lib/features/close/day_closed_view.dart`
- Test: `app/test/features/close_print_test.dart`, `app/test/golden/close_golden_test.dart` (zwei neue Bilder)

**Interfaces:**
- Consumes: `reportPrintProvider`, `printerSetUpProvider` (Aufgabe 3), `closeSummaryProvider`.
- Produces: `DayClosedView` bekommt `onPrint` (`VoidCallback?`, `null`: keine Taste), `printing` (`bool`), `printMessage` (`String?`), `printFailed` (`bool`). Schlüssel: Taste `print-day-report`, Zeile `day-report-result`.

Verhalten: Nach gelungenem `close` holt `_closeDay` die neue Zusammenfassung und ruft `printDay`, ohne darauf zu warten; der Bildschirm zeigt sofort "Der Tag ist abgeschlossen.". Das Ergebnis steht über der Taste: "Bericht gedruckt." oder `outcome.message` (in `c.red`). Die Taste **Bericht drucken** (zweite Taste über "Zur Kassa", `PrimaryButton` nicht gefüllt, Höhe `KassaTokens.mainActionHeight`) druckt den zuletzt abgeschlossenen Tag noch einmal und ist während eines Drucks gesperrt. Ohne eingerichteten Drucker gibt es weder Druck noch Taste noch Zeile.

- [ ] **Step 1: Tests schreiben**

```dart
testWidgets('Tag abschließen druckt den Bericht einmal', ...);         // printerOf(t).log == ['day-report:<Id>'], Text 'Bericht gedruckt.'
testWidgets('Drucker hängt: der Tag ist trotzdem sofort abgeschlossen', ...); // hold gesetzt, 'Der Tag ist abgeschlossen.' sichtbar, lastClosedDay() != null
testWidgets('Drucker nicht bereit: Meldung steht da, "Bericht drucken" geht danach', ...); // next = failed(unreachable), dann ok: zweiter Eintrag, 'Bericht gedruckt.'
testWidgets('ohne Drucker: keine Taste, kein Druck', ...);
testWidgets('später wieder geöffnet (kein neuer Tag): Taste druckt den letzten Tag', ...);
testWidgets('doppelt getippt: ein Druck', ...);
testWidgets('nach dem ersten Bon des neuen Tages ist die Taste weg', ...);
// Goldens: goldens/abschluss_abgeschlossen_bericht_hell.png, goldens/abschluss_abgeschlossen_druckfehler_hell.png
```

- [ ] **Step 2: Laufen lassen, sie scheitern** (`flutter test test/features/close_print_test.dart`)
- [ ] **Step 3: `DayClosedView` und `CloseScreen` anpassen.** Vorlage für das Aussehen: `/mnt/project-files/kassa-entwurf/monat/project/TagAbgeschlossen.dc.html`.
- [ ] **Step 4: Tests grün**, neue Goldens erzeugen und ansehen, `flutter test test/features/close_test.dart test/features/close_tasks_test.dart test/golden/close_golden_test.dart` grün (alte Bilder unverändert).
- [ ] **Step 5: Commit** `Tagesabschluss: druckt nach dem Abschluss von selbst, Taste "Bericht drucken"`

---

### Task 5: Tablet, Monat: Umschalter, Zeitraum wählen, Karten, Drucken

**Files:**
- Create: `app/lib/features/close/month_view.dart`, `app/lib/features/close/period_picker.dart`, `app/lib/features/close/period_cards.dart`, `app/lib/features/close/month_providers.dart`, `app/test/support/month_pump.dart`
- Modify: `app/lib/features/close/close_screen.dart` (Umschalter), `app/lib/features/close/income_card.dart` (`IncomeFigures`), `app/lib/features/close/day_summary_cards.dart` (Aufruf)
- Test: `app/test/features/close_month_test.dart`, `app/test/golden/close_month_golden_test.dart`

**Interfaces:**
- Consumes: Aufgaben 1 und 3; `saleServiceProvider.reprint(Receipt)`; `receiptRepositoryProvider.find(id)`.
- Produces:

```dart
// month_providers.dart
final monthChoiceProvider = FutureProvider.autoDispose<MonthChoice>(...);
final periodReportProvider = FutureProvider.autoDispose.family<PeriodReport, MonthRange>(...);
/// Monats- oder Jahresbeleg zum Monat; null ohne Beleg.
final signatureReceiptProvider = FutureProvider.autoDispose.family<Receipt?, YearMonth>(...);
final hasSignatureProvider = FutureProvider.autoDispose<bool>(...);

// income_card.dart
class IncomeFigures {  // cashCount, cashCents, cardCount, cardCents, count, revenueCents, voidCount, voidedCents, taxLines, depositCents
  factory IncomeFigures.ofDay(DaySummary s);
  factory IncomeFigures.ofPeriod(PeriodReport r);
}
class IncomeCard extends StatelessWidget { const IncomeCard(this.f, {super.key}); final IncomeFigures f; }

// month_view.dart
class MonthView extends ConsumerStatefulWidget { const MonthView({super.key, required this.switcher}); final Widget switcher; }
```

Schlüssel: Umschalter `segment-Tag`, `segment-Monat`; Modus `segment-Ein Monat`, `segment-Von bis`; `year-prev`, `year-next`, `year-label`; Monate `month-1` bis `month-12`; `period-text`; `print-period`; `period-print-result`; `period-title`; `test-mode-pill`; `signature-receipt-card`, `print-signature-receipt`; `period-rows`; `period-empty`; `no-month-yet`.

Verhalten (Spec 5.2, Bilder `Main.dc.html` und `Zeitraum.dc.html`):
- `CloseScreen` zeigt in der Kopfzeile rechts den Umschalter `Segmented` (Tag, Monat). Beim Öffnen des Bereichs ist immer Tag gewählt (auch wenn der Bereich im Hintergrund bestehen bleibt). Bei Monat ersetzt `MonthView` die ganze Zeile aus linker Seite und rechter Spalte; der Umschalter steht dort an derselben Stelle.
- Rechte Spalte (`CloseColumn`, Titel "Zeitraum"): Modus, Jahr mit zwei Pfeiltasten (56 dp), zwölf Tasten in drei Spalten (56 dp hoch) mit "Jän", "Feb", "März", "Apr", "Mai", "Juni", "Juli", "Aug", "Sep", "Okt", "Nov", "Dez"; nicht wählbare Monate (`!choice.allows`) gesperrt und blass; Pfeile am ersten und letzten Jahr mit wählbaren Monaten gesperrt. Darunter der Zeitraum ("1.10. bis 31.10.2026", über den Jahreswechsel "1.11.2025 bis 28.2.2026"), unten die Haupttaste **Drucken**.
- Beim Öffnen: Ein Monat, der letzte abgeschlossene Monat, sein Jahr.
- Links: Titel "Monatsabrechnung Oktober 2026" oder "Abrechnung Jänner bis Oktober 2026" (`periodTitle`), Pille "Testbetrieb" bei `testMode`; Karte Einnahmen und Steuer (`IncomeCard`); Karte "Monatsbeleg der Signatur" bzw. "Jahresbeleg der Signatur" (nur Ein Monat und nur mit `hasSignature`): "Erstellt am 1.11. um 10:02, Bon Nr. 12400" und Taste **Drucken** (`reprint`), ohne Beleg "Kommt von selbst mit dem nächsten Bon." ohne Taste; Karte "Tage" (Zeile "Do., 1.10.", "38 Bons", Betrag) oder "Monate" (Zeile "Jänner 2026", Anzahl, Betrag).
- Die alten Zahlen bleiben stehen, bis die neuen da sind. Leerer Zeitraum: statt der Karten "In diesem Zeitraum gibt es keine Bons.", Drucken gesperrt. Kein abgeschlossener Monat: "Die erste Monatsabrechnung gibt es ab 1. Dezember." (aus `nextAvailable`), alle Monate gesperrt, keine Taste Drucken.
- Drucken: gesperrt während des Drucks; Ergebnis über der Taste ("Abrechnung gedruckt." oder `outcome.message`); ohne eingerichteten Drucker gesperrt mit "Kein Drucker eingerichtet."; ein Wechsel des Zeitraums löscht das Ergebnis.

- [ ] **Step 1: Tests schreiben** (`month_pump.dart`: Verkäufe in vergangenen Monaten anlegen wie `pumpClose`, dann Abschluss öffnen und `segment-Monat` tippen)

```dart
testWidgets('Abschluss öffnet mit Tag; Monat zeigt den letzten abgeschlossenen Monat', ...); // jetzt 17.11.2026: Titel 'Monatsabrechnung Oktober 2026', period-text '1.10. bis 31.10.2026', income-total stimmt
testWidgets('Bereich verlassen und wieder öffnen: wieder Tag', ...);
testWidgets('laufender Monat und Monate vor dem ersten Bon sind gesperrt', ...);       // Tipp auf month-11 ändert nichts
testWidgets('Tipp auf September zeigt September', ...);
testWidgets('Von bis: zwei Tipps, Titel "Abrechnung September bis Oktober 2026", Karte Monate', ...);
testWidgets('Von bis über den Jahreswechsel: Jahr zwischen den Tipps wechseln', ...);   // period-text '1.12.2025 bis 31.1.2026'
testWidgets('Jahrespfeile sind am ersten und letzten Jahr gesperrt', ...);
testWidgets('Drucken ruft den Drucker mit dem gewählten Zeitraum', ...);               // log == ['period-report:2026-09..2026-10'], 'Abrechnung gedruckt.'
testWidgets('doppelt getippt: ein Druck; Zeitraum wechseln löscht die Meldung', ...);  // Review Focus 3
testWidgets('Drucker nicht bereit: Meldung über der Taste', ...);
testWidgets('ohne Drucker: Taste gesperrt, "Kein Drucker eingerichtet."', ...);
testWidgets('leerer Monat: Satz statt Karten, Drucken gesperrt', ...);
testWidgets('noch kein abgeschlossener Monat: "Die erste Monatsabrechnung gibt es ab 1. Dezember."', ...);
testWidgets('Monatsbeleg: Karte mit Zeit und Nummer, Drucken druckt den gespeicherten Beleg', ...); // printerOf(t).printed == [<Id des Monatsbelegs>]
testWidgets('ohne Monatsbeleg: "Kommt von selbst mit dem nächsten Bon.", keine Taste; ohne Signatur keine Karte', ...);
testWidgets('nur Testbons: Pille Testbetrieb', ...);
testWidgets('Schriftgröße 1,3 und 1024 x 768: kein Überlauf', ...);
testWidgets('Monat ändert nichts an der Datenbank', ...);  // Anzahl der Zeilen in receiptRows, rksvEntryRows, outboxRows vor und nach Öffnen und Drucken gleich
// Goldens: abschluss_monat_hell.png, abschluss_monat_dunkel.png, abschluss_monat_von_bis_hell.png,
//          abschluss_monat_kein_monat_hell.png, abschluss_monat_beleg_hell.png
```

- [ ] **Step 2: Laufen lassen, sie scheitern.**
- [ ] **Step 3: `IncomeFigures` einführen** (Tag unverändert, `close_golden_test.dart` grün).
- [ ] **Step 4: Provider, `PeriodPicker`, Karten, `MonthView`, Umschalter in `CloseScreen` schreiben.**
- [ ] **Step 5: Tests grün**, Goldens erzeugen und gegen die Bilder des Entwurfs ansehen, `flutter analyze` ohne Meldung, `flutter test test/features/close_test.dart test/golden/close_golden_test.dart test/no_text_field_test.dart` grün.
- [ ] **Step 6: Commit** `Monatsabrechnung am Tablet: Abschluss mit Tag und Monat, Zeitraum wählen, Drucken`

---

### Task 6: Gemeinsame Prüfdaten und Server

**Files:**
- Create: `shared/fixtures/stats/months.json` (schreibt der Test der App), `server/src/admin/months.ts`, `server/src/admin/tax.ts`, `server/test/months.test.ts`, `server/test/tax.test.ts`
- Modify: `app/test/sync/shared_fixtures_test.dart`, `server/src/admin/days.ts`, `server/src/app.ts` (`installMonthRoutes`), `server/test/days.test.ts`

**Interfaces:**
- Consumes: `PeriodReportRepository` (Aufgabe 1); `requireBusinessAccess`, `withBusiness`, `loadTimeZone`, `ApiError`.
- Produces:

```ts
// tax.ts: dieselbe Formel wie taxBreakdown in app/lib/domain/pricing.dart, ganze Cent
export function taxOf(grossCents: number, percent: number): number; // kaufmännisch auf dem Betrag, Vorzeichen zurück
export type TaxLine = { percent: number; grossCents: number; netCents: number; taxCents: number };

// GET /api/admin/businesses/:b/months
{ testMode: boolean, nextAvailable: 'JJJJ-MM-TT',
  months: [{ month: 'JJJJ-MM', receiptCount: number, revenueCents: number }] }   // neueste zuerst, R9 und R10, auch leere

// GET /api/admin/businesses/:b/months/summary?from=JJJJ-MM&to=JJJJ-MM
type PeriodSummary = { from, to, testMode,
  receiptCount, cashReceiptCount, cardReceiptCount, voidCount, voidedCents,
  revenueCents, cashRevenueCents, cardRevenueCents, depositCents,
  taxLines: TaxLine[],                                   // nach Satz absteigend
  rows: [{ key: 'JJJJ-MM-TT' | 'JJJJ-MM', receiptCount, revenueCents }] }  // ein Monat: Tage mit Bon; mehrere: jeder Monat
// 422 period_invalid "Der Zeitraum ist unbekannt." (Format, Monat 13, to vor from)
// 404 not_found "Diese Abrechnung gibt es nicht." (laufender oder späterer Monat, Monat vor dem ersten)

// GET /api/admin/businesses/:b/days/:id zusätzlich:
cashCents, cardCents, cashReceiptCount, cardReceiptCount, voidCount, voidedCents, depositCents, taxLines
```

`months.json`: `{ now, timeZone: 'UTC', receipts: [...], expected: { months: <Antwort der Liste ohne nextAvailable>, summaries: { '<from>..<to>': PeriodSummary } } }`. Die App schreibt `receipts` im Format des Abgleichs (wie `overview.json`) und `expected` aus `PeriodReportRepository`; Namen der Felder wie oben. Inhalt: Bons über mindestens vier Monate mit Jahreswechsel, bar und Karte, Sätze 20 % und 10 %, Pfand, ein Storno im Folgemonat des Bons, ein Sonderbeleg, ein leerer Monat dazwischen, Bons im laufenden Monat. Zusammenfassungen für jeden Einzelmonat und für den ganzen Bereich.

Server: Monatsgrenzen in der Zeitzone des Betriebs in PostgreSQL (`date_trunc('month', created_at at time zone $tz)`), `kind in ('sale','voided')`, Testbons wie `overview.ts` (`exists (select 1 from receipts where not is_test)`), Summen je Monat in SQL (`group by`), Steuer je Monat mit `taxOf` und dann addiert. Der Tag (`days/:id`) zählt wie am Tablet alle Bons des Tages nach `business_day_id`, ohne Filter für Testbons.

- [ ] **Step 1: Test der App erweitern** (`shared_fixtures_test.dart`: neuer Test "Monate", schreibt oder vergleicht `stats/months.json`), dann `KASSA_WRITE_FIXTURES=1 ~/flutter/bin/flutter test test/sync/shared_fixtures_test.dart` und noch einmal ohne die Variable: grün. Die Datei von Hand gegenlesen (Summen, Steuer der Summe aus den Monaten).
- [ ] **Step 2: Tests des Servers schreiben**

```ts
// tax.test.ts
test.each([[580, 20, 97], [1190, 10, 108], [-580, 20, -97], [1160, 20, 193], [0, 20, 0], [100, 13, 12], [119, 19, 19]])('taxOf(%i, %i) = %i', ...);
// months.test.ts
test('gemeinsames Beispiel: Liste und jede Zusammenfassung wie die App', ...);   // toEqual gegen expected
test('Mitternacht in der Zeitzone des Betriebs: 31.10. 23:30 Wien zählt zum Oktober, 1.11. 00:30 zum November', ...);
test('Wechsel der Sommerzeit: Bon am 25.10.2026 02:30 Wien (zweimal) zählt einmal im Oktober', ...);
test('laufender Monat fehlt in der Liste und liefert 404', ...);
test('Testbons und echte gemischt: nur echte zählen, testMode false; nur Testbons: testMode true', ...);
test('Betrieb ohne Bon: leere Liste, nextAvailable ist der Erste des Folgemonats', ...);
test.each(['2026-13', 'abc', '2026-1', ''])('from=%s: 422', ...);               // Review Focus 4
test('to vor from: 422; Monat vor dem ersten: 404', ...);
test('fremder Betrieb: 403 oder 404 wie bei den Tagen; ohne Anmeldung 401', ...);
test('mehrere Kassen: Summe des Betriebs', ...);
// days.test.ts
test('Tag liefert Bar, Karte, Storno, Pfand und Steuer wie am Tablet', ...);
```

- [ ] **Step 3: Laufen lassen, sie scheitern** (`cd server && npx vitest run test/months.test.ts test/tax.test.ts test/days.test.ts`)
- [ ] **Step 4: `tax.ts`, `months.ts`, Erweiterung von `days.ts`, Eintrag in `app.ts` schreiben.**
- [ ] **Step 5: Tests grün**, `npm run typecheck`, dazu `npx vitest run test/overview.test.ts test/tenant.test.ts`.
- [ ] **Step 6: Commit** `Monatsabrechnung am Server: Monate, Zeitraum, Tag mit Bar, Karte und Steuer`

---

### Task 7: Browser: Abschlüsse mit Tagen und Monaten, Drucken

**Files:**
- Create: `web/src/api/months.ts`, `web/src/period.ts`, `web/src/period.test.ts`, `web/src/pages/MonthsPage.tsx` (+ `.module.css`), `web/src/pages/PeriodDetail.tsx` (+ `.module.css`), `web/src/pages/ClosingTabs.tsx` (+ `.module.css`), `web/src/styles/print.css`, `web/e2e/months.spec.ts`
- Modify: `web/src/routes.tsx`, `web/src/pages/DaysPage.tsx`, `web/src/pages/DayDetail.tsx` (+ css), `web/src/api/days.ts`, `web/src/main.tsx` (print.css), `web/e2e/support/seed.ts` (falls ein Helfer für alte Bons fehlt)

**Interfaces:**
- Consumes: die Antworten aus Aufgabe 6.
- Produces:

```ts
// period.ts (rein)
export type Period = { from: string; to: string };                 // 'JJJJ-MM'
export function parsePeriodId(id: string): Period | null;          // '2026-10' | '2026-01..2026-10'; null bei Unsinn, Monat 13, to vor from
export function periodId(p: Period): string;                       // from == to: '2026-10'
export function periodTitle(p: Period): string;                    // wie am Tablet
export function periodDates(p: Period): string;                    // '01.10.2026 bis 31.10.2026'
export function monthLabel(month: string): string;                 // 'Oktober 2026'
// api/months.ts
export function useMonths(b: string);                              // GET months
export function usePeriodSummary(b: string, p: Period | null);     // GET months/summary
```

Verhalten (Spec 5.4, Bild `BrowserMonat.dc.html`):
- Leiste: "Abschlüsse", am Handy "Abschluss". Seiten `tage` und `monate` tragen beide den Titel "Abschlüsse" und darunter `ClosingTabs`: zwei Verweise "Tage" und "Monate" im Aussehen des Umschalters (`nav` mit `aria-label="Abschlüsse"`, der aktive mit `aria-current="page"`).
- Route `monate` mit Kind `:id` wie `tage`. `MonthsPage`: oben "Von" und "Bis" als `select` mit den Monaten der Liste und die Taste "Anzeigen"; "Bis" bietet nur Monate ab "Von". Darunter die Liste (Monat, Anzahl Bons, Umsatz). Leer: "Noch keine Monatsabrechnung." mit "Die erste gibt es ab 1. Dezember." (aus `nextAvailable`). Laden mit `RowListSkeleton`, Fehler mit `LoadError`.
- Blatt von rechts (`Dialog variant="side"`), Titel `periodTitle`. Inhalt `PeriodDetailView`: Zeitraum von bis, Chip "Testbetrieb", Bar, Karte, Gesamt (je mit Anzahl), Storniert (nur über 0), Steuer als Tabelle (Satz, Brutto, Netto, Steuer), "Pfand, ohne MwSt" (nur ungleich 0), Liste "Tage" oder "Monate", oben die Taste **Drucken** (`window.print()`). Unsinnige Kennung oder 404: "Diese Abrechnung gibt es nicht." ohne Abfrage bei Unsinn.
- `DayDetailView`: zusätzlich Bar, Karte, Storniert, Steuer nach Satz, Pfand und **Drucken**. Ein offener Tag druckt mit "offen" und ohne Erwartet, Gezählt, Differenz, In der Lade gelassen.
- Druckansicht (`print.css`, `@media print`): nur das Blatt, schwarz auf weiß auch im dunklen Modus, A4 hoch (`@page { size: A4 portrait; margin: 15mm }`), oben Name des Betriebs und Titel, unten "Erstellt am <Datum Zeit>" (beide nur im Druck sichtbar), keine Tasten, keine Leiste. Keine neue Bibliothek.

- [ ] **Step 1: Tests für `period.ts` schreiben**

```ts
test('parsePeriodId', () => {
  expect(parsePeriodId('2026-10')).toEqual({ from: '2026-10', to: '2026-10' });
  expect(parsePeriodId('2026-01..2026-10')).toEqual({ from: '2026-01', to: '2026-10' });
  for (const bad of ['2026-13', 'abc', '2026-1', '2026-10..2026-01', '2026-10..', '']) expect(parsePeriodId(bad)).toBeNull();
});
test('Titel und Daten', () => {
  expect(periodTitle({ from: '2026-01', to: '2026-10' })).toBe('Jänner bis Oktober 2026');
  expect(periodTitle({ from: '2025-11', to: '2026-02' })).toBe('November 2025 bis Februar 2026');
  expect(periodDates({ from: '2024-02', to: '2024-02' })).toBe('01.02.2024 bis 29.02.2024');
  expect(monthLabel('2026-01')).toBe('Jänner 2026');
});
```

- [ ] **Step 2: Laufen lassen, sie scheitern** (`cd web && npx vitest run src/period.test.ts`), dann `period.ts` schreiben, grün.
- [ ] **Step 3: Durchlauf im Browser schreiben** (`e2e/months.spec.ts`, Bons mit `pushEntries` in zwei vergangenen Monaten und im laufenden)

```ts
test('Abschlüsse: Tage und Monate, ein Monat mit Zahlen wie berechnet', ...);       // Leiste "Abschlüsse", Verweis "Monate", Zeile des Vormonats, Blatt mit Gesamt und Steuer
test('laufender Monat steht nicht in der Liste', ...);
test('Von und Bis: Anzeigen öffnet den Zeitraum mit einer Zeile je Monat; Bis bietet nichts vor Von', ...);
test('Adresse von Hand: /monate/2026-13 und /monate/abc zeigen "Diese Abrechnung gibt es nicht."', ...);   // Review Focus 4
test('Druckansicht: nur das Blatt, Betrieb und Zeitraum oben, schwarz auf weiß auch im dunklen Modus', ...); // page.emulateMedia({ media: 'print', colorScheme: 'dark' }); Hintergrund rgb(255, 255, 255), Leiste und Liste nicht sichtbar; Review Focus 5
test('Tag: Bar, Karte, Steuer und Drucken; offener Tag druckt mit "offen"', ...);
test('Handy 390 px: kein Scrollen zur Seite auf Monate und im Blatt', ...);
```

- [ ] **Step 4: Laufen lassen, er scheitert** (`cd web && npm run e2e -- months.spec.ts`).
- [ ] **Step 5: API, Seiten, Blatt, Verweise, Druckansicht schreiben**; `DaysPage` bekommt den neuen Titel und `ClosingTabs`.
- [ ] **Step 6: Tests grün:** `npm test`, `npm run typecheck`, `npm run e2e -- months.spec.ts`, dazu die vorhandenen Durchläufe, die Tage oder die Leiste berühren (`npm run e2e -- flow.spec.ts shots.spec.ts`). Die Seiten im Browser bei 390 px und 1280 px, hell und dunkel, als Bild ansehen.
- [ ] **Step 7: Commit** `Abschlüsse im Browser: Monate neben den Tagen, Zeitraum, Druckansicht`

---

### Task 8: Version 1.9.0, Prüfliste, Gesamtprüfung

**Files:**
- Modify: `app/pubspec.yaml` (`version: 1.9.0+11`), `app/lib/core/app_info.dart` (`'1.9.0'`), `docs/superpowers/specs/2026-11-23-monatsabrechnung-und-ausdruck-design.md` (Stand)
- Create: `docs/testen/monatsabrechnung-pruefliste.md`

- [ ] **Step 1: Version erhöhen**, `flutter test test/widget_test.dart` und die Tests, die die Version prüfen, grün.
- [ ] **Step 2: Prüfliste schreiben** (deutsch, einfache Worte, zum Abhaken, Aufbau wie `docs/testen/teil-c2-pruefliste.md`): Tagesabschluss drucken (mit und ohne Drucker, Drucker aus), "Bericht drucken", Monat wählen, mehrere Monate, Zettel lesen (Zeitraum, Summen, Breite "Normal" und "Schmal"), Monatsbeleg nachdrucken, Browser Monate und Drucken als PDF, Vergleich Tablet und Browser auf den Cent.
- [ ] **Step 3: Alles prüfen:** `flutter analyze`; Zweig pushen und die Workflows `app` und `server` auf GitHub lesen (ganze Suiten); `tool/e2e.sh` hier nicht nötig.
- [ ] **Step 4: Commit** `Kassa 1.9.0 (Build 11): Monatsabrechnung und Ausdruck`, push.

Nicht Teil dieses Plans, erst nach Nikos Ja: Server bei Railway auf den neuen Commit stellen, Installationsdatei bauen und hochladen.
