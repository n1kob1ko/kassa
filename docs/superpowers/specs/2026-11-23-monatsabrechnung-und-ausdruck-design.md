# Kassa: Monatsabrechnung und Ausdruck für Tag und Monat

Stand: 23.11.2026. Entwurf von Claude, wartet auf Nikos Freigabe. Bilder der Bildschirme und Zettel: https://claude.ai/artifact/63kcWgcCYNasZ3c2nh8FkL (Zahlen erfunden).

Dieses Dokument ergänzt den Gesamtentwurf (`2026-11-17-kassa-design.md`, dort "Abschluss" und "Übersicht" in Abschnitt 5) und den Entwurf zum Abgleich (`2026-11-19-teil-c2-abgleich-design.md`, dort die Seiten Umsätze und Tagesabschlüsse). Wo sich die Dokumente widersprechen, gilt für dieses Thema dieses. Alles, was hier nicht steht, gilt weiter wie dort, in `PRODUCT.md`, `DESIGN.md` und `docs/design-regeln.md`.

## 1. Worum es geht

Niko am 23.11.2026: "Wo Tages und Monats Abrechnung wie wird das gemacht". Die Antwort aus dem Code von 1.8.0:

- Den Tagesabschluss gibt es (Bereich Abschluss am Tablet, Seite Tagesabschlüsse im Browser). Er lässt sich nicht drucken, obwohl der freigegebene Gesamtentwurf sagt: "'Tag abschließen' druckt den Bericht."
- Eine Abrechnung für einen Kalendermonat gibt es nicht. Tablet und Browser zeigen nur Heute, 7 Tage und 30 Tage.
- Den Monatsbeleg und den Jahresbeleg der Signatur schreibt die Kassa von selbst. Sie sind Belege mit Betrag 0 und keine Abrechnung.

Niko hat danach auf der Karte "Monatsabrechnung und Ausdruck" gewählt.

**Erfolg heißt:** Niko tippt am Tablet auf Abschluss, dann auf Monat, sieht den November mit Umsatz, Bar, Karte und Steuer nach Satz und druckt ihn mit einem Tipp am Bondrucker. Er schließt einen Tag ab, und der Tagesabschluss kommt von selbst aus dem Drucker. Im Browser öffnet er denselben Monat, sieht dieselben Zahlen und druckt sie auf A4 oder sichert sie als PDF.

Wofür Niko die Abrechnung braucht und wer sie bekommt, ist gefragt und noch offen (siehe Abschnitt 9). Der Entwurf nimmt an: für die eigene Kontrolle und für die Buchhaltung.

## 2. Ziele, Nicht-Ziele, Anti-Ziele

**Ziele**

- Am Tablet im Bereich Abschluss ein Umschalter "Tag" und "Monat". Unter Monat die Monatsabrechnung für einen Kalendermonat, den Monat wählt man mit zwei großen Pfeiltasten.
- "Monat drucken" am Bondrucker.
- Der Tagesabschluss kommt nach "Tag abschließen" von selbst aus dem Bondrucker und lässt sich mit "Bericht drucken" noch einmal drucken.
- Im Browser unter Abschlüsse die Monate neben den Tagen, mit denselben Zahlen wie am Tablet. Tag und Monat lassen sich dort drucken (A4, über den Druckdialog auch als PDF).
- Der Tag im Browser zeigt zusätzlich Bar, Karte, Storno und Steuer nach Satz, so wie am Tablet.

**Nicht-Ziele** (bewusst später oder gar nicht)

- Ein eigener Schritt "Monat abschließen". Der Monat endet mit dem Kalender, niemand muss etwas tun.
- Datei für die Buchhaltung (CSV, Excel, DATEV), Versand per E-Mail. Hängt an Nikos Antwort in Abschnitt 9.
- Zwischenstand des laufenden Tages drucken, ohne abzuschließen.
- Ältere Tagesabschlüsse am Tablet nachdrucken. Am Tablet geht der zuletzt abgeschlossene Tag, alle anderen stehen im Browser.
- Jahresabrechnung, Vergleich mit dem Vormonat, Auswertung nach Mitarbeiter oder Artikel, Monat als Zeitraum in der Übersicht.
- Aufteilung nach Kassen, wenn ein Betrieb mehrere hat. Der Browser zeigt die Summe des Betriebs.

**Anti-Ziele**

- "Tag abschließen" wartet nie auf den Drucker und scheitert nie an ihm.
- Ein Bericht ändert nichts: kein Bon, keine Bon-Nummer, kein Eintrag im Protokoll der Signatur, nichts in der Datenbank.
- Tablet, Zettel und Browser zeigen für dieselben Bons nie verschiedene Zahlen.
- Nichts an der Signatur ändert sein Verhalten. Der Ordner `app/lib/rksv/` wird nicht angefasst, die Datenbank am Tablet bleibt Version 6.
- Am Tablet wird nichts getippt, auch der Monat nicht.

## 3. Rahmenbedingungen

- **Stand der App:** 1.8.0 Build 10 ist übergeben und wartet auf Nikos Test mit der Chipkarte. Diese Arbeit baut auf demselben Commit (`1eacd76`) auf dem Zweig `claude/project-thread-cdsc7e` und wird 1.9.0 Build 11. Die Signatur gehört einem anderen Thread (Zweig `claude/project-thread-xtooco`). Beide berühren `close_screen.dart` und `printer.dart`; wer später fertig wird, führt zusammen.
- **Keine neue Tabelle.** Alle Zahlen kommen aus den gespeicherten Bons. Am Tablet keine Migration, am Server keine Migration.
- **Der Server läuft** bei Railway und ist auf einen Commit festgelegt. Zur Übergabe gehören das Ausrollen des neuen Stands und das Hochladen der Installationsdatei. Für beides braucht es vorher Nikos Ja.
- **Das Repo ist öffentlich.** Beispielzahlen sind erfunden.
- **Flutter** ist in der Bau-Umgebung nicht von selbst da (`tool/setup_flutter.sh`). Die gemeinsamen Prüfdaten schreibt ein Test der App (`KASSA_WRITE_FIXTURES=1`, `app/test/sync/shared_fixtures_test.dart`); erst danach kann der Test der Gleichheit am Server bestehen.
- **Kein Tablet und kein Bondrucker in der Bau-Umgebung.** Was nur am echten Gerät zu sehen ist, kommt in eine Prüfliste für Niko (`docs/testen/monatsabrechnung-pruefliste.md`).
- **Recht, soweit geprüft:** Die RKSV verlangt den Monatsbeleg und den Jahresbeleg (gibt es, siehe `kassa-rksv-recht-2026` im Projekt-Speicher). Einen gedruckten Tages- oder Monatsbericht verlangt sie nach Claudes Stand nicht. Das ist keine Rechtsauskunft; ob die Steuerberatung von YICHI eine bestimmte Form will, ist offen.

## 4. Wege, die zur Wahl standen

**Woher die Zahlen des Monats kommen**

| | Weg | Urteil |
|---|---|---|
| **1** | **Bei jedem Öffnen aus den Bons rechnen** (Tablet aus seiner Datenbank, Server in PostgreSQL) | **Gewählt.** Stimmt immer mit den Bons überein, braucht keine Migration, gilt sofort auch für alle Monate vor dem Update. Bons sind unveränderlich, ein vergangener Monat ändert sich also nicht mehr. |
| 2 | Einen "Monatsabschluss" speichern, wenn jemand "Monat abschließen" tippt | Wie bei alten Kassen. Braucht eine Migration (Version 7), einen Schritt, den man vergisst, und Regeln für den vergessenen Fall. Bringt keine anderen Zahlen. |
| 3 | Monat nur im Browser | Ohne Internet kein Monat, und Niko will den Ausdruck am Bondrucker. |

**Was ein Monat ist**

| | Weg | Urteil |
|---|---|---|
| **1** | **Kalendermonat nach dem Datum am Bon** | **Gewählt.** So rechnen schon die Übersicht, der Server und der Monatsbeleg. Ein vergessener Tagesabschluss, der vom 30. bis zum 3. offen bleibt, schiebt keinen Umsatz in den falschen Monat. Preis: Bedient ein Lokal am Monatsletzten über Mitternacht, ist die Summe der Tagesabschlüsse nicht auf den Cent die Summe des Monats. |
| 2 | Summe der Tagesabschlüsse, die im Monat geöffnet wurden | Tag und Monat passen immer zusammen, aber ein vergessener Abschluss verfälscht den Monat, und Übersicht und Monat würden verschieden rechnen. |

**Wo der Monat am Tablet steht**

| | Weg | Urteil |
|---|---|---|
| **1** | **Im Bereich Abschluss, Umschalter "Tag" und "Monat"** | **Gewählt.** Niko sucht Tag und Monat am selben Ort. Kein neuer Reiter in der Kopfleiste. |
| 2 | In der Übersicht als vierter Zeitraum | Die Übersicht ist ein Diagramm zum Schauen; Steuer nach Satz und Drucken passen dort nicht hin. |
| 3 | Neuer Reiter "Berichte" | Ein Reiter mehr für eine Seite. |

## 5. Der Entwurf

### 5.1 Regeln für die Zahlen

Sie gelten gleich am Tablet, am Zettel und am Server.

- **R1 Monat.** Ein Kalendermonat, vom Ersten 0:00 bis vor dem nächsten Ersten 0:00. Am Tablet in der Zeit des Geräts, am Server in der Zeitzone des Betriebs (wie `overview.ts`). Maßgeblich ist die Zeit am Bon (`createdAt`).
- **R2 Was zählt.** Verkaufs-Bons und Storno-Bons. Ein Storno-Bon zählt negativ in dem Monat, in dem storniert wurde (wie beim Tag; Niko hat in Teil A bestätigt, dass ein Storno zum Tag des Stornos zählt). Liegt der Storno in einem späteren Tag oder Monat als der Bon, können Anzahl und Betrag einer Zeile negativ sein. Sie stehen dann so da, nichts wird versteckt oder auf 0 gesetzt (wie heute beim Tag und in der Übersicht). Sonderbelege (Start, Monat, Jahr, Null, Sammel, Schluss) zählen nicht.
- **R3 Testbons.** Ein Bon ist echt, wenn er in einer Kette der Signatur mit `live` steht (wie `push_wire.dart`). Gibt es an diesem Tablet (im Browser: in diesem Betrieb) irgendeinen echten Beleg, gleich welcher Art, also schon ab dem Startbeleg der Inbetriebnahme (so prüft es `overview.ts`), zählen im Monat nur echte Bons. Gibt es keinen, zählen alle, und Bildschirm, Zettel und Browser tragen den Vermerk "Testbetrieb". So ist es schon bei den Umsätzen im Browser.
- **R4 Einnahmen.** Gesamt ist die Summe der Bons mit Pfand. Bar sind Bons mit Barzahlung, Karte alle anderen (wie beim Tag). Dazu je die Anzahl Bons: Verkäufe minus Storno-Bons.
- **R5 Storno.** Anzahl der Storno-Bons und ihre Summe als positive Zahl. Die Zeile fehlt, wenn es keinen gibt.
- **R6 Steuer.** Je Satz die Summe brutto des Monats, daraus Netto und Steuer mit `taxBreakdown` aus `pricing.dart` (kaufmännisch gerundet, einmal auf der Monatssumme). Sätze ohne Betrag fehlen. Der Server rechnet mit derselben Formel in ganzen Cent.
- **R7 Pfand.** Summe des Pfands als eigene Zeile "Pfand, ohne MwSt". Die Zeile fehlt bei 0.
- **R8 Tage.** Eine Zeile je Kalendertag mit mindestens einem gezählten Bon: Datum, Anzahl Bons, Umsatz. Aufsteigend.
- **R9 Laufender Monat.** Lässt sich ansehen und drucken und trägt den Vermerk "Monat läuft noch" mit Datum und Uhrzeit des Stands.
- **R10 Welche Monate.** Vom Monat des ältesten gezählten Bons bis zum laufenden Monat. Gibt es keinen gezählten Bon, gibt es nur den laufenden Monat, leer. Zukunft gibt es nicht.
- **R11 Gleichheit.** Tablet und Server rechnen dieselben Prüfdaten (`shared/fixtures/stats/`, neue Datei für den Monat) und müssen auf den Cent dasselbe liefern.

Die Zahlen des Tagesabschlusses bleiben, wie sie sind (`DayRepository._summarize`).

### 5.2 Tablet: Bereich Abschluss

In der Kopfzeile des Bereichs steht rechts vom Datum ein Umschalter mit zwei Segmenten: **Tag** und **Monat** (`ui/segmented.dart`). Beim Öffnen des Bereichs ist immer Tag gewählt.

**Tag** bleibt wie heute. Neu:

- Nach "Tag abschließen" druckt die Kassa den Tagesabschluss von selbst, wenn ein Drucker eingerichtet ist. Der Abschluss ist da schon gespeichert.
- In der Spalte "Tag abgeschlossen" steht über "Zur Kassa" die Taste **Bericht drucken**. Sie druckt den zuletzt abgeschlossenen Tag noch einmal. Die Spalte und damit die Taste gibt es, solange kein neuer Tag offen ist (wie heute). Danach steht der Tag im Browser. Darüber steht das Ergebnis des letzten Drucks: "Bericht gedruckt." oder die Meldung des Druckers mit denselben Worten wie bei den Bons (zum Beispiel "Drucker nicht bereit").
- Ohne eingerichteten Drucker druckt nichts, und die Taste fehlt.

**Monat**

```
Monatsabrechnung  November 2026  [Monat läuft noch]      [ Tag | Monat ]    |  Monat
                                                                             |
+-- Einnahmen ----------------+-- Steuer --------- Umsatz  davon MwSt --+    |   [ < ]  November 2026  [ > ]
| Bar        412 Bons  6.930,40 | MwSt 20 %      3.180,00     530,00    |    |
| Karte      655 Bons 12.481,70 | MwSt 10 %     16.112,60   1.464,78    |    |   Umsatz
| Gesamt   1.067 Bons 19.412,10 | Pfand, ohne MwSt  119,50              |    |   19.412,10 EUR
| Storniert    9 Bons    141,20 |                                       |    |
+-------------------------------+---------------------------------------+    |   Stand: heute, 14:05
                                                                             |
+-- Tage -------------------------------------------------------------+     |   Monatsbeleg der Signatur:
| So., 1.11.     38 Bons                                     702,40   |     |   kommt von selbst mit dem
| Mo., 2.11.     51 Bons                                     911,80   |     |   ersten Bon im Dezember.
| ...                                                                 |     |
+---------------------------------------------------------------------+     |   [      Monat drucken      ]
```

- Links dieselben Karten wie beim Tag: "Einnahmen" und "Steuer" in einer Karte, darunter die Karte "Tage". Die linke Seite scrollt, die rechte Spalte steht fest (wie beim Tag).
- Rechts die feste Spalte "Monat": zwei Pfeiltasten (je mindestens 64 dp, links älter, rechts neuer) mit dem Monat dazwischen, darunter der Umsatz groß in Tabellenziffern, der Stand, der Hinweis zum Monatsbeleg und unten die Haupttaste **Monat drucken**.
- Die Pfeile sind am ersten und am laufenden Monat gesperrt und sehen so aus. Beim Öffnen von Monat ist der laufende Monat gewählt.
- Beim Wechsel des Monats bleiben die alten Zahlen stehen, bis die neuen da sind (wie die Übersicht). Kein Springen der Karten.
- Leerer Monat: "In diesem Monat gibt es keine Bons." Die Taste zum Drucken ist gesperrt.
- "Monat drucken" ist während des Drucks gesperrt, damit ein Doppeltipp nicht zweimal druckt. Das Ergebnis steht über der Taste wie beim Tag. Ohne eingerichteten Drucker ist die Taste gesperrt, darüber steht "Kein Drucker eingerichtet."
- Vermerk "Testbetrieb" (R3) als ruhige Pille neben dem Monat.
- **Hinweis zum Monatsbeleg** (nur, wenn die Signatur eingerichtet ist, Probe oder Betrieb): Gibt es einen Monats- oder Jahresbeleg mit Zeit ab dem Ersten des Folgemonats, steht "Monatsbeleg der Signatur: erstellt am 1.12. um 10:02." (bei einem Jahresbeleg "Jahresbeleg"; es gilt der früheste solche Beleg). Sonst: "Monatsbeleg der Signatur: kommt von selbst mit dem ersten Bon im Dezember." Der Hinweis liest nur die Bons, er ruft nichts in `rksv/` auf.
- Nur für den Chef, wie der ganze Bereich. Hell und dunkel, Maße und Farben aus `DESIGN.md`.

### 5.3 Die Zettel

Beide sind Berichte und keine Belege: ohne QR-Code, ohne Signatur, ohne Bon-Nummer. Sie öffnen die Geldlade nicht. Breite wie die Bons (Einstellung des Druckers: 48 "Normal" oder 42 "Schmal"), Zeichen wie die Bons (`printable`). Die Zettel müssen wie der Bon auch mit 32 Zeichen stimmen und werden damit geprüft; eine neue Einstellung kommt nicht dazu.

Tagesabschluss, 42 Zeichen:

```
                  YICHI
              Musterstraße 1
                1010 Wien

              TAGESABSCHLUSS
           Dienstag, 17.11.2026

Kassa                                Theke
Geöffnet                             09:02
Abgeschlossen               21:14 von Mira
Bons Nr.                     1042 bis 1139
------------------------------------------
EINNAHMEN
Bar              38 Bons            488,10
Karte            58 Bons            796,50
Gesamt           96 Bons          1.284,60
Storniert         2 Bons             20,50
------------------------------------------
STEUER
MwSt 20 %
  Brutto                            212,50
  Netto                             177,08
  Steuer                             35,42
MwSt 10 %
  Brutto                          1.062,60
  Netto                             966,00
  Steuer                             96,60
Pfand, ohne MwSt                      9,50
------------------------------------------
GELDLADE
Wechselgeld am Morgen               150,00
Bar-Einnahmen                       488,10
11:00 Eingelegt: Wechselgeld         50,00
15:30 Entnommen: Einkauf            -20,00
Soll                                668,10
Gezählt                             668,00
Unterschied                          -0,10
In der Lade gelassen                150,00
Entnommen                           518,00
------------------------------------------
        Gedruckt 17.11.2026 21:14
                Kein Beleg
```

Monatsabrechnung, 42 Zeichen:

```
                  YICHI
              Musterstraße 1
                1010 Wien

             MONATSABRECHNUNG
              November 2026
             Monat läuft noch

Stand                     23.11.2026 14:05
Kassa                                Theke
Bons Nr.                     1042 bis 2135
------------------------------------------
EINNAHMEN
Bar             412 Bons          6.930,40
Karte           655 Bons         12.481,70
Gesamt        1.067 Bons         19.412,10
Storniert         9 Bons            141,20
------------------------------------------
STEUER
MwSt 20 %
  Brutto                          3.180,00
  Netto                           2.650,00
  Steuer                            530,00
MwSt 10 %
  Brutto                         16.112,60
  Netto                          14.647,82
  Steuer                          1.464,78
Pfand, ohne MwSt                    119,50
------------------------------------------
TAGE
So 01.11.        38 Bons            702,40
Mo 02.11.        51 Bons            911,80
...
------------------------------------------
        Gedruckt 23.11.2026 14:06
                Kein Beleg
```

- Kopf: Name und Adresse des Betriebs wie am Bon, ohne UID und ohne Schlusssatz.
- Tagesabschluss: Datum ist der Tag, an dem der Tag geöffnet wurde. Ohne Geldlade heißt der Teil "BARGELD". Bewegungen einzeln in der Reihenfolge der Zeit, mit Uhrzeit davor. "Bons Nr." nennt die kleinste und größte Nummer der gezählten Bons (auch am Monat); ohne Bon fehlt die Zeile.
- Monatsabrechnung: "Monat läuft noch" und "Stand" nur beim laufenden Monat. "Testbetrieb" unter dem Titel, wenn R3 es sagt.
- Passt eine Zeile nicht in 32 Zeichen, bricht sie wie am Bon um; Beträge stehen immer rechtsbündig.

### 5.4 Browser

- Der Punkt "Tagesabschlüsse" in der Leiste heißt neu **Abschlüsse** (am Handy "Abschluss"). Oben auf der Seite ein Umschalter **Tage** und **Monate**. Die Adresse der Tage bleibt `/b/<Betrieb>/tage`, die Monate stehen unter `/b/<Betrieb>/monate`, ein Monat unter `/b/<Betrieb>/monate/2026-11`.
- **Monate:** Liste, der neueste zuerst. Je Zeile der Monat, "läuft noch" als Pille, Anzahl Bons und Umsatz. Ein Tipp öffnet das Blatt von rechts wie bei einem Tag: Einnahmen, Storno, Steuer nach Satz, Pfand, Tage. Oben im Blatt die Taste **Drucken**.
- **Tag:** Das Blatt eines Tages bekommt die Zeilen Bar, Karte, Storniert und die Steuer nach Satz dazu und ebenfalls **Drucken**. Ein offener Tag lässt sich drucken; der Ausdruck trägt dann "offen" und zeigt keine Zahlen des Abschlusses (gezählt, Unterschied, in der Lade gelassen).
- **Drucken** öffnet den Druckdialog des Browsers (`window.print()`). Eine Druckansicht zeigt nur das Blatt: schwarz auf weiß, A4 hoch, oben Betrieb und Zeitraum, unten "Erstellt am". Als PDF sichert man über den Druckdialog. Keine neue Bibliothek.
- Laden mit Platzhaltern, Fehler mit "Nochmal versuchen", leer mit Erklärung, alles wie auf den vorhandenen Seiten. Geht am Handy (390 px) und am Rechner, hell und dunkel.
- Bei mehreren Kassen zeigt der Monat die Summe des Betriebs.

### 5.5 Server

- `GET /api/admin/businesses/:b/months`: Liste der Monate nach R10 mit Umsatz, Anzahl Bons und ob der Monat läuft.
- `GET /api/admin/businesses/:b/months/:month` (`JJJJ-MM`): die Zahlen nach 5.1. Unbekanntes Format oder Monat außerhalb von R10: 404 mit Text.
- `GET /api/admin/businesses/:b/days/:id` liefert zusätzlich Bar, Karte, Storno und Steuerzeilen des Tages, gerechnet wie am Tablet.
- Zugriff und Trennung der Betriebe wie bei den vorhandenen Adressen (`requireBusinessAccess`, `withBusiness`). Kalendergrenzen rechnet PostgreSQL in der Zeitzone des Betriebs.

## 6. Technik in Kürze

- **App.** Rechnen: neue Methode für den Monat im vorhandenen `StatsRepository` oder in einem eigenen Repository daneben, Ergebnis als reines Dart-Objekt in `domain/`. Zettel: neue Datei `domain/report_layout.dart` mit `layoutDayReport` und `layoutMonthReport` (reines Dart, wie `receipt_layout.dart`). `ReceiptPrinter` bekommt `printDayReport` und `printMonthReport`; sie laufen durch dieselbe Warteschlange und dieselbe Zeitgrenze wie Bons. Oberfläche in `features/close/`.
- **Server.** Neue Datei `admin/months.ts`, Erweiterung von `admin/days.ts`. Die Formel aus R6 als eine Funktion mit eigenem Test.
- **Web.** `MonthsPage`, `MonthDetail`, Erweiterung von `DayDetail`, eine Druckansicht (`@media print`), Umschalter als Verweise.

## 7. Prüfen

- Zuerst die Tests, dann der Code (TDD), wie in den bisherigen Teilen.
- Rechnen: Monatsgrenzen (letzte und erste Minute), Storno in einem anderen Monat als der Bon, nur Testbons, Testbons und echte Bons gemischt, leerer Monat, Sonderbelege, alle Steuersätze, Pfand. Am Server zusätzlich Mitternacht in der Zeitzone des Betriebs und der Wechsel der Sommerzeit.
- Gleichheit Tablet und Server über gemeinsame Prüfdaten (R11).
- Zettel: fester Text für 32, 42 und 48 Zeichen, mit und ohne Geldlade, laufender Monat, Testbetrieb, lange Namen.
- Oberfläche: Bildvergleiche für Monat hell und dunkel, leer, laufend, gesperrte Pfeile, "Tag abgeschlossen" mit Taste und mit Druckfehler. Im Web Tests der Seiten und ein Durchlauf im Browser bis zur Druckansicht.
- "Tag abschließen" bei ausgeschaltetem Drucker: Der Tag ist abgeschlossen, die Meldung steht da, "Bericht drucken" geht danach.
- Alle Tests der App laufen auf GitHub vom Zweig. Am echten Drucker prüft Niko mit der Prüfliste.

## 8. Was dem Bau überlassen ist

Namen von Klassen und Dateien über das Genannte hinaus, die Form der SQL-Abfragen, Abstände und Größen innerhalb von `DESIGN.md`, die genaue Druckansicht, die Aufteilung in Aufgaben.

## 9. Offen

1. **Niko:** Was passiert heute bei der Windows-Kassa mit dem Tages- und dem Monatsabschluss, wer bekommt ihn und in welcher Form? Davon hängt ab, ob zusätzlich eine Datei für die Buchhaltung dazukommt.
2. **Steuerberatung von YICHI:** ob sie die Monatsabrechnung in einer bestimmten Form will.
3. **Bekannt und nicht Teil dieser Arbeit:** Der Tagesabschluss und die Übersicht am Tablet zählen Testbons mit. Am Tag der Inbetriebnahme stehen deshalb Testbons von vorher im Tagesabschluss. Der Monat zählt sie nach R3 nicht.
