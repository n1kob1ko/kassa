# Kassa: Monatsabrechnung und Ausdruck für Tag und Monat

Stand: 23.11.2026. Entwurf von Claude, von Niko am 23.11.2026 freigegeben ("Passt, so bauen"). Gebaut als Version 1.9.0 (Build 11), noch nicht ausgespielt. Bilder der Bildschirme und Zettel: https://claude.ai/artifact/63kcWgcCYNasZ3c2nh8FkL (Zahlen erfunden).

Dieses Dokument ergänzt den Gesamtentwurf (`2026-11-17-kassa-design.md`, dort "Abschluss" und "Übersicht" in Abschnitt 5) und den Entwurf zum Abgleich (`2026-11-19-teil-c2-abgleich-design.md`, dort die Seiten Umsätze und Tagesabschlüsse). Wo sich die Dokumente widersprechen, gilt für dieses Thema dieses. Alles, was hier nicht steht, gilt weiter wie dort, in `PRODUCT.md`, `DESIGN.md` und `docs/design-regeln.md`.

## 1. Worum es geht

Niko am 23.11.2026: "Wo Tages und Monats Abrechnung wie wird das gemacht". Die Antwort aus dem Code von 1.8.0:

- Den Tagesabschluss gibt es (Bereich Abschluss am Tablet, Seite Tagesabschlüsse im Browser). Er lässt sich nicht drucken, obwohl der freigegebene Gesamtentwurf sagt: "'Tag abschließen' druckt den Bericht."
- Eine Abrechnung für einen Kalendermonat gibt es nicht. Tablet und Browser zeigen nur Heute, 7 Tage und 30 Tage.
- Den Monatsbeleg und den Jahresbeleg der Signatur schreibt die Kassa von selbst. Sie sind Belege mit Betrag 0 und keine Abrechnung.

Niko hat danach auf der Karte "Monatsabrechnung und Ausdruck" gewählt.

**Erfolg heißt:** Niko tippt am Tablet auf Abschluss, dann auf Monat, sieht den letzten abgeschlossenen Monat mit Umsatz, Bar, Karte und Steuer nach Satz und druckt ihn mit einem Tipp am Bondrucker. Am Zettel steht der Zeitraum genau, von bis. Er schließt einen Tag ab, und der Tagesabschluss kommt von selbst aus dem Drucker. Im Browser öffnet er denselben Monat, sieht dieselben Zahlen und druckt sie auf A4 oder sichert sie als PDF.

Wofür: Der Chef braucht einen Ausdruck, zum Beispiel für das Finanzamt, auch über mehrere Monate (Niko am 23.11.2026).

## 2. Ziele, Nicht-Ziele, Anti-Ziele

**Ziele**

- Am Tablet im Bereich Abschluss ein Umschalter "Tag" und "Monat". Unter Monat die Monatsabrechnung für einen abgeschlossenen Kalendermonat, den Monat wählt man mit großen Tasten.
- "Drucken" am Bondrucker, immer mit dem Zeitraum als Datum von bis.
- Mehrere Monate auf einem Ausdruck. Niko am 23.11.2026: "wenn der Chef kommt und sagt, er braucht für das Finanzamt einen Ausdruck, z. B. Jänner bis November 2025, dann soll alles auf einen kommen."
- Der Monats- oder Jahresbeleg der Signatur lässt sich am Tablet nachdrucken, auch nach dem Tagesabschluss. Niko fragte am 23.11.2026, wie er Start-, Schluss-, Monats- und Jahresbeleg bekommt; heute zeigt der Bereich Bons nur die Belege des offenen Tages.
- Der Tagesabschluss kommt nach "Tag abschließen" von selbst aus dem Bondrucker und lässt sich mit "Bericht drucken" noch einmal drucken.
- Im Browser unter Abschlüsse die Monate neben den Tagen, mit denselben Zahlen wie am Tablet. Tag und Monat lassen sich dort drucken (A4, über den Druckdialog auch als PDF).
- Der Tag im Browser zeigt zusätzlich Bar, Karte, Storno und Steuer nach Satz, so wie am Tablet.

**Nicht-Ziele** (bewusst später oder gar nicht)

- Ein eigener Schritt "Monat abschließen". Der Monat endet mit dem Kalender, niemand muss etwas tun.
- Datei für die Buchhaltung (CSV, Excel, DATEV), Versand per E-Mail. Hängt an Nikos Antwort in Abschnitt 9.
- Zwischenstand des laufenden Tages oder des laufenden Monats, am Bildschirm oder am Zettel. Den laufenden Monat zeigen weiter Übersicht und Umsätze (30 Tage).
- Ältere Tagesabschlüsse am Tablet nachdrucken. Am Tablet geht der zuletzt abgeschlossene Tag, alle anderen stehen im Browser.
- Zeiträume mit einzelnen Tagen (es gibt nur ganze Monate), Vergleich mit dem Vormonat, Auswertung nach Mitarbeiter oder Artikel, Monat als Zeitraum in der Übersicht.
- Start- und Schlussbeleg nach dem Tagesabschluss am Tablet nachdrucken. Beide druckt die Kassa beim Erstellen; die Seite dazu (Einstellungen, Signatur) gehört dem Thread der Signatur.
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
- **R8 Tage.** Eine Zeile je Kalendertag mit mindestens einem gezählten Bon: Datum, Anzahl Bons, Umsatz. Aufsteigend. Die Tage stehen am Bildschirm des Tablets und im Browser, nicht am Zettel (Niko am 23.11.2026 als Kommentar am Bild des Zettels: "Gib die Tage weg").
- **R9 Nur abgeschlossene Monate.** Eine Monatsabrechnung gibt es erst, wenn der Monat vorbei ist, also ab dem Ersten des Folgemonats 0:00 (Tablet: Zeit des Geräts, Server: Zeitzone des Betriebs). Den laufenden Monat gibt es weder am Tablet noch am Zettel noch im Browser. Niko am 23.11.2026 als Kommentar am Bild des Zettels: "Wichtig ist, dass das Datum genau steht, also von bis. Monatsabschluss geht ja mitten im November nicht, da der Monat nicht vorbei ist." Dass der laufende Monat auch am Bildschirm fehlt, ist Claudes Lesart.
- **R9a Zeitraum.** Jede Monatsabrechnung nennt ihren Zeitraum mit Datum von bis (erster und letzter Tag des Monats), jeder Tagesabschluss Beginn und Ende mit Datum und Uhrzeit.
- **R10 Welche Monate.** Vom Monat des ältesten gezählten Bons bis zum letzten abgeschlossenen Monat. Gibt es keinen solchen Monat, gibt es keine Monatsabrechnung, und Tablet und Browser sagen, ab wann es die erste gibt.
- **R12 Mehrere Monate.** Ein Zeitraum ist ein Monat oder mehrere aufeinanderfolgende abgeschlossene Monate, auch über den Jahreswechsel, vom ersten Tag des ersten bis zum letzten Tag des letzten Monats. Einnahmen, Storno, Pfand und Brutto je Satz sind die Summen über den Zeitraum. Netto und Steuer je Satz sind die Summen der Werte der einzelnen Monate (R6 je Monat), damit ein Ausdruck über mehrere Monate auf den Cent die Summe der einzelnen Monatsabrechnungen ist. Statt der Tage (R8) gibt es bei mehreren Monaten eine Zeile je Monat: Monat, Anzahl Bons, Umsatz. Jeder Monat des Zeitraums hat seine Zeile, auch einer ohne Bons (0 Bons, 0,00), damit der Ausdruck lückenlos ist. Diese Zeilen stehen auch am Zettel (Claudes Vorschlag; die Liste der Tage hat Niko vom Zettel gestrichen).
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
Monatsabrechnung  Oktober 2026                           [ Tag | Monat ]    |  Zeitraum
                                                                             |
+-- Einnahmen ----------------+-- Steuer --------- Umsatz  davon MwSt --+    |  [ Ein Monat | Von bis ]
| Bar        412 Bons  6.930,40 | MwSt 20 %      3.180,00     530,00    |    |
| Karte      655 Bons 12.481,70 | MwSt 10 %     16.112,60   1.464,78    |    |  [ < ]       2026       [ > ]
| Gesamt   1.067 Bons 19.412,10 | Pfand, ohne MwSt  119,50              |    |
| Storniert    9 Bons    141,20 |                                       |    |  [ Jän ] [ Feb ] [ März]
+-------------------------------+---------------------------------------+    |  [ Apr ] [ Mai ] [ Juni]
                                                                             |  [ Juli] [ Aug ] [ Sep ]
+-- Monatsbeleg der Signatur ------------------------------------------+    |  [*Okt*] ( Nov ) ( Dez )
| Erstellt am 1.11. um 10:02, Bon Nr. 12400              [ Drucken ]   |    |
+---------------------------------------------------------------------+     |  1.10. bis 31.10.2026
                                                                             |
+-- Tage -------------------------------------------------------------+     |
| Do., 1.10.     38 Bons                                     702,40   |     |  [        Drucken        ]
| ...                                                                 |     |
```

- Links dieselben Karten wie beim Tag: "Einnahmen" und "Steuer" in einer Karte, darunter "Monatsbeleg der Signatur" und die Karte "Tage" (bei mehreren Monaten "Monate", R12). Die linke Seite scrollt, die rechte Spalte steht fest (wie beim Tag).
- Rechts die feste Spalte "Zeitraum":
  - Umschalter **Ein Monat** und **Von bis**. Beim Öffnen ist "Ein Monat" gewählt.
  - Jahr mit zwei Pfeiltasten (je mindestens 56 dp), darunter die zwölf Monate als Tasten in drei Spalten (je mindestens 56 dp hoch). Ein Monat, der nicht abgeschlossen ist (R9) oder vor dem ersten Monat liegt (R10), ist gesperrt und sieht so aus. Die Pfeile sind am ersten und am letzten Jahr mit wählbaren Monaten gesperrt.
  - **Ein Monat:** Ein Tipp auf einen Monat zeigt diesen Monat. Beim Öffnen ist der letzte abgeschlossene Monat gewählt.
  - **Von bis:** Der erste Tipp setzt den Beginn, der zweite das Ende; alle Monate dazwischen sind markiert. Ein Tipp vor dem Beginn setzt den Beginn neu, ein dritter Tipp beginnt von vorn. Das Jahr lässt sich zwischen den zwei Tipps wechseln. Solange nur der Beginn gewählt ist, gilt dieser eine Monat.
  - Darunter der Zeitraum als Datum von bis und unten die Haupttaste **Drucken**.
- Überschrift links: bei einem Monat "Monatsabrechnung Oktober 2026", bei mehreren "Abrechnung Jänner bis Oktober 2026" (über den Jahreswechsel mit beiden Jahren).
- Gibt es noch keinen abgeschlossenen Monat: statt der Karten der Satz "Die erste Monatsabrechnung gibt es ab 1. Dezember." (der Erste des Folgemonats), alle Monate gesperrt, keine Taste zum Drucken.
- Beim Wechsel des Zeitraums bleiben die alten Zahlen stehen, bis die neuen da sind (wie die Übersicht). Kein Springen der Karten.
- Zeitraum ohne Bons: "In diesem Zeitraum gibt es keine Bons." Die Taste zum Drucken ist gesperrt.
- "Drucken" ist während des Drucks gesperrt, damit ein Doppeltipp nicht zweimal druckt. Das Ergebnis steht über der Taste wie beim Tag. Ohne eingerichteten Drucker ist die Taste gesperrt, darüber steht "Kein Drucker eingerichtet."
- Vermerk "Testbetrieb" (R3) als ruhige Pille neben der Überschrift.
- **Monatsbeleg der Signatur** (nur bei "Ein Monat" und nur, wenn die Signatur eingerichtet ist oder war): Gezeigt wird der früheste Monats- oder Jahresbeleg mit Zeit ab dem Ersten des Folgemonats: "Erstellt am 1.11. um 10:02, Bon Nr. 12400" (bei einem Jahresbeleg heißt die Karte "Jahresbeleg der Signatur") und die Taste **Drucken**. Sie druckt den gespeicherten Beleg noch einmal, so wie "Drucken" im Bereich Bons (`SaleService.reprint`), mit QR-Code. Gibt es keinen: "Kommt von selbst mit dem nächsten Bon.", ohne Taste. Die Karte liest nur die gespeicherten Bons, sie ruft nichts in `rksv/` auf und erstellt nie einen Beleg.
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
Von                       17.11.2026 09:02
Bis                       17.11.2026 21:14
Abgeschlossen von                     Mira
Bons Nr.                   13174 bis 13269
------------------------------------------
EINNAHMEN
Bar                 38 Bons         488,10
Karte               58 Bons         796,50
Gesamt              96 Bons       1.284,60
Storniert            2 Bons          20,50
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
               Oktober 2026

Zeitraum         01.10.2026 bis 31.10.2026
Kassa                                Theke
Bons Nr.                   11292 bis 12399
------------------------------------------
EINNAHMEN
Bar                412 Bons       6.930,40
Karte              655 Bons      12.481,70
Gesamt           1.067 Bons      19.412,10
Storniert            9 Bons         141,20
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
        Gedruckt 23.11.2026 14:06
                Kein Beleg
```

Mehrere Monate, 42 Zeichen:

```
                  YICHI
              Musterstraße 1
                1010 Wien

                ABRECHNUNG
         Jänner bis Oktober 2026

Zeitraum         01.01.2026 bis 31.10.2026
Kassa                                Theke
Bons Nr.                       1 bis 12399
------------------------------------------
EINNAHMEN
Bar              4.702 Bons      80.412,30
Karte            7.583 Bons     144.547,30
Gesamt          12.285 Bons     224.959,60
Storniert           96 Bons       1.502,40
------------------------------------------
STEUER
MwSt 20 %
  Brutto                         36.850,00
  Netto                          30.708,33
  Steuer                          6.141,67
MwSt 10 %
  Brutto                        186.725,10
  Netto                         169.750,09
  Steuer                         16.975,01
Pfand, ohne MwSt                  1.384,50
------------------------------------------
MONATE
Jänner 2026      1.190 Bons      21.840,30
Februar 2026     1.121 Bons      20.615,80
März 2026        1.302 Bons      23.904,10
April 2026       1.240 Bons      22.731,60
Mai 2026         1.318 Bons      24.118,90
Juni 2026        1.287 Bons      23.560,40
Juli 2026        1.203 Bons      21.977,20
August 2026      1.215 Bons      22.190,30
September 2026   1.342 Bons      24.608,90
Oktober 2026     1.067 Bons      19.412,10
------------------------------------------
        Gedruckt 23.11.2026 14:06
                Kein Beleg
```

- Kopf: Name und Adresse des Betriebs wie am Bon, ohne UID und ohne Schlusssatz.
- Tagesabschluss: Datum in der Überschrift ist der Tag, an dem der Tag geöffnet wurde. "Von" und "Bis" nennen Beginn und Abschluss mit Datum und Uhrzeit, auch wenn der Tag über Mitternacht geht. Ohne Geldlade heißt der Teil "BARGELD". Bewegungen einzeln in der Reihenfolge der Zeit, mit Uhrzeit davor. "Bons Nr." nennt die kleinste und größte Nummer der gezählten Bons (auch am Monat); ohne Bon fehlt die Zeile.
- Monatsabrechnung: ohne die Liste der Tage (R8). "Zeitraum" nennt den ersten und den letzten Tag des Monats (R9a). Bei mehreren Monaten heißt der Zettel "ABRECHNUNG" mit "Jänner bis Oktober 2026" darunter und bekommt den Teil "MONATE" (R12). "Testbetrieb" unter dem Titel, wenn R3 es sagt.
- Zeilen mit Anzahl ("Bar  38 Bons  488,10"): Die Anzahl endet 15 Zeichen vor dem rechten Rand, der Betrag steht rechtsbündig. Passt die Beschriftung nicht davor (etwa "September 2026" bei 32 Zeichen), steht sie in einer eigenen Zeile darüber.
- Passt eine Zeile nicht in 32 Zeichen, bricht sie wie am Bon um; Beträge stehen immer rechtsbündig.

### 5.4 Browser

- Der Punkt "Tagesabschlüsse" in der Leiste heißt neu **Abschlüsse** (am Handy "Abschluss"). Oben auf der Seite ein Umschalter **Tage** und **Monate**. Die Adresse der Tage bleibt `/b/<Betrieb>/tage`, die Monate stehen unter `/b/<Betrieb>/monate`, ein Monat unter `/b/<Betrieb>/monate/2026-10`.
- **Monate:** Liste der abgeschlossenen Monate (R9, R10), der neueste zuerst, auch Monate ohne Bons. Je Zeile der Monat, Anzahl Bons und Umsatz. Ein Tipp öffnet das Blatt von rechts wie bei einem Tag: Zeitraum von bis, Einnahmen, Storno, Steuer nach Satz, Pfand, Tage. Oben im Blatt die Taste **Drucken**.
- **Mehrere Monate:** Über der Liste zwei Auswahlfelder "Von" und "Bis" mit den abgeschlossenen Monaten und die Taste **Anzeigen**. Sie öffnet dasselbe Blatt für den Zeitraum (R12), mit "Monate" statt "Tage", unter `/b/<Betrieb>/monate/2026-01..2026-10`. "Bis" vor "Von" lässt sich nicht wählen.
- **Tag:** Das Blatt eines Tages bekommt die Zeilen Bar, Karte, Storniert und die Steuer nach Satz dazu und ebenfalls **Drucken**. Ein offener Tag lässt sich drucken; der Ausdruck trägt dann "offen" und zeigt keine Zahlen des Abschlusses (gezählt, Unterschied, in der Lade gelassen).
- **Drucken** öffnet den Druckdialog des Browsers (`window.print()`). Eine Druckansicht zeigt nur das Blatt: schwarz auf weiß, A4 hoch, oben Betrieb und Zeitraum, unten "Erstellt am". Als PDF sichert man über den Druckdialog. Keine neue Bibliothek.
- Laden mit Platzhaltern, Fehler mit "Nochmal versuchen", leer mit Erklärung, alles wie auf den vorhandenen Seiten. Geht am Handy (390 px) und am Rechner, hell und dunkel.
- Bei mehreren Kassen zeigt der Monat die Summe des Betriebs.

### 5.5 Server

- `GET /api/admin/businesses/:b/months`: Liste der Monate nach R9 und R10 mit Umsatz und Anzahl Bons.
- `GET /api/admin/businesses/:b/months/summary?from=JJJJ-MM&to=JJJJ-MM`: die Zahlen nach 5.1 für einen Monat (`from` gleich `to`) oder mehrere (R12). Unbekanntes Format, `to` vor `from`, ein Monat außerhalb von R10 oder ein laufender Monat: 404 oder 422 mit Text.
- `GET /api/admin/businesses/:b/days/:id` liefert zusätzlich Bar, Karte, Storno und Steuerzeilen des Tages, gerechnet wie am Tablet.
- Zugriff und Trennung der Betriebe wie bei den vorhandenen Adressen (`requireBusinessAccess`, `withBusiness`). Kalendergrenzen rechnet PostgreSQL in der Zeitzone des Betriebs.

## 6. Technik in Kürze

- **App.** Rechnen: neue Methode für den Monat im vorhandenen `StatsRepository` oder in einem eigenen Repository daneben, Ergebnis als reines Dart-Objekt in `domain/`. Zettel: neue Datei `domain/report_layout.dart` mit `layoutDayReport` und `layoutMonthReport` (reines Dart, wie `receipt_layout.dart`). `ReceiptPrinter` bekommt `printDayReport` und `printMonthReport` (ein Monat oder mehrere); sie laufen durch dieselbe Warteschlange und dieselbe Zeitgrenze wie Bons. Oberfläche in `features/close/`.
- **Server.** Neue Datei `admin/months.ts`, Erweiterung von `admin/days.ts`. Die Formel aus R6 als eine Funktion mit eigenem Test.
- **Web.** `MonthsPage`, `MonthDetail`, Erweiterung von `DayDetail`, eine Druckansicht (`@media print`), Umschalter als Verweise.

## 7. Prüfen

- Zuerst die Tests, dann der Code (TDD), wie in den bisherigen Teilen.
- Rechnen: Monatsgrenzen (letzte und erste Minute), Storno in einem anderen Monat als der Bon, nur Testbons, Testbons und echte Bons gemischt, leerer Monat, Sonderbelege, alle Steuersätze, Pfand, der laufende Monat ist nicht wählbar, mehrere Monate (auch über den Jahreswechsel) und dass ihre Steuer die Summe der Monate ist. Am Server zusätzlich Mitternacht in der Zeitzone des Betriebs und der Wechsel der Sommerzeit.
- Gleichheit Tablet und Server über gemeinsame Prüfdaten (R11).
- Zettel: fester Text für 32, 42 und 48 Zeichen, mit und ohne Geldlade, ein Monat, mehrere Monate, Testbetrieb, lange Namen, Tag über Mitternacht.
- Oberfläche: Bildvergleiche für Monat hell und dunkel, mehrere Monate, noch kein abgeschlossener Monat, gesperrte Monate, Monatsbeleg mit und ohne Taste, "Tag abgeschlossen" mit Taste und mit Druckfehler. Im Web Tests der Seiten und ein Durchlauf im Browser bis zur Druckansicht.
- "Tag abschließen" bei ausgeschaltetem Drucker: Der Tag ist abgeschlossen, die Meldung steht da, "Bericht drucken" geht danach.
- Alle Tests der App laufen auf GitHub vom Zweig. Am echten Drucker prüft Niko mit der Prüfliste.

## 8. Was dem Bau überlassen ist

Namen von Klassen und Dateien über das Genannte hinaus, die Form der SQL-Abfragen, Abstände und Größen innerhalb von `DESIGN.md`, die genaue Druckansicht, die Aufteilung in Aufgaben.

## 9. Offen

1. **Niko**, zum Teil beantwortet am 23.11.2026: Die Abrechnung braucht der Chef als Ausdruck, zum Beispiel für das Finanzamt, auch über mehrere Monate. Ob zusätzlich eine Datei für die Buchhaltung gebraucht wird, ist weiter offen.
2. **Steuerberatung von YICHI:** ob sie die Monatsabrechnung in einer bestimmten Form will.
3. **Bekannt und nicht Teil dieser Arbeit:** Der Tagesabschluss und die Übersicht am Tablet zählen Testbons mit. Am Tag der Inbetriebnahme stehen deshalb Testbons von vorher im Tagesabschluss. Der Monat zählt sie nach R3 nicht.

## 10. Abweichungen und Entscheidungen beim Bau

Gebaut am 23.11.2026 als 1.9.0 (Build 11) in acht Aufgaben, jede einzeln gebaut und gegengelesen, am Ende eine Prüfung über den ganzen Bau. Diese Punkte hat Claude beim Bau entschieden. Niko kann jeden davon ändern lassen.

1. **Steuer am Bildschirm:** Tablet und Browser zeigen je Satz "Umsatz" und "davon MwSt", wie in den freigegebenen Bildern. Brutto, Netto und Steuer stehen nur am Zettel. Wenn die Buchhaltung Netto auch am Bildschirm will, kommt eine Spalte dazu.
2. **Datum im Browser:** "01.10.2026 bis 31.10.2026" wie am Zettel, nicht "1.10. bis 31.10.2026" wie im Bild.
3. **Kopfzeile des Tages:** Der Umschalter "Tag | Monat" steht auch im Tagesabschluss. Sechs Vergleichsbilder des Abschlusses wurden deshalb neu erzeugt.
4. **Ausdruck im Browser:** Über dem Blatt steht "Monatsabrechnung Oktober 2026", "Abrechnung Jänner bis Oktober 2026" oder "Tagesabschluss 17.11.2026, Theke", damit das Papier sagt, was es ist. Am Bildschirm bleibt der kurze Titel.
5. **Zettel ohne Geldlade:** Statt "In der Lade gelassen" steht "Wechselgeld für morgen".
6. **Schmale Zettel (32 Zeichen):** "Zeitraum" steht dann allein in der Zeile, das Datum darunter.
7. **Adresse im Browser:** Ein Zeitraum hat die Adresse `/monate/2026-01..2026-10`. Der Server liefert dafür jetzt die Seite aus. Als Datei gilt nur noch, was mit Punkt und Buchstaben oder Ziffern endet (`server/src/web.ts`).
8. **Wählbare Monate:** vom Monat des ersten Bons dieser Kassa bis zum letzten abgeschlossenen Monat. Monate davor sind gesperrt.
9. **Tests:** Beim Bau liefen nur die betroffenen Testdateien, die ganzen Tests von App und Server liefen auf GitHub vom Zweig. Die Tests der Verwaltung im Browser mit echtem Browser (Playwright) laufen nicht auf GitHub, sie liefen hier am fertigen Stand.

Bewusst nicht gemacht, weil klein oder selten:

- Die Abfragen der Monate am Server nutzen den Index nicht. Das reicht für das erste Jahr eines Betriebs und gehört davor umgebaut.
- Verlässt man den Abschluss genau in dem Moment, in dem der Tag abgeschlossen wird, druckt der Bericht nicht von selbst. "Bericht drucken" geht danach.
- Bleibt "Monat" über Mitternacht am Monatsersten offen, erscheint der neue Monat erst, wenn man den Bereich neu öffnet.
- Beim Wechsel des Zeitraums steht die große Summe kurz noch vom alten Zeitraum neben dem neuen Datum.

Zu wissen für den Test:

- Eine Kassa, die erst seit November 2026 Bons hat, hat noch keinen abgeschlossenen Monat. Die Monatsabrechnung lässt sich dort ab 1. Dezember prüfen. Bis dahin steht "Die erste Monatsabrechnung gibt es ab 1. Dezember."
- Der Browser zählt alle Kassen eines Betriebs zusammen, das Tablet nur die eigenen Bons. Mit einer Kassa sind beide gleich.
