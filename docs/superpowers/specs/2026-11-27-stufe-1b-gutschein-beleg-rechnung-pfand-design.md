# Kassa Stufe 1b: Pfand zurück, Rechnung an Firma, digitaler Beleg, Gutschein

Stand: 27.11.2026. Niko hat den Entwurf am 27.11.2026 freigegeben ("Passt, so bauen"). Abschnitt 10 hält fest, was beim Bau entschieden wurde.

Gehört zur Roadmap "Kassa: Nächste Schritte für Restaurant und Handel" (https://claude.ai/artifact/7AYwSKehrHpS2wMFGKv1NG) und folgt auf Stufe 1a (`2026-11-26-stufe-1a-zahlen-design.md`, Version 1.11.0). Niko am 26.11.2026: "mach einfach alles aber es sollte getrennt bleiben also man soll sich die art von kassa dann auswählen können".

## 1. Worum es geht

Mit 1.11.0 kann ein Bon mehrere Zahlungen, Trinkgeld, Rabatt und einen freien Betrag tragen. Vier Dinge aus der Roadmap fehlen noch, bevor Tische (Stufe 2) darauf aufbauen:

1. **Pfand zurück.** Die Kassa kann Pfand verlangen, aber nicht zurückgeben. Wer heute einen Becher zurücknimmt, zahlt aus der Lade aus, ohne dass die Kassa es weiß.
2. **Rechnung an Firma.** Ein Gast will den Bon mit Name und Adresse seiner Firma. Über 400 € ist das für eine Rechnung Pflicht.
3. **Digitaler Beleg.** Seit 1.10.2026 muss der Bon nicht mehr gedruckt werden, wenn der Kunde ihn am Bildschirm sehen oder mitnehmen kann. Das spart Papier.
4. **Gutschein.** Wertgutscheine verkaufen und einlösen, mit Guthaben, das die Kassa mitführt.

Jede der vier Funktionen ist für sich nützlich, auch für den Imbiss, und jede ist nach dem Update aus.

## 2. Ziele, Nicht-Ziele, Anti-Ziele

**Ziele**

1. Pfand zurückgeben: auf einem Bon mit Ware oder allein, mit Auszahlung aus der Lade.
2. Zu einem bezahlten Bon einen Rechnungsempfänger (Name, Adresse, UID) erfassen und den Bon als Rechnung drucken. Firmenkunden werden gespeichert und wiederverwendet.
3. Der Kunde kann den Bon als Seite im Internet mitnehmen (QR-Code am Bildschirm). Der Betrieb kann wählen, dass nur noch auf Wunsch gedruckt wird.
4. Wertgutscheine verkaufen (mit Code am Ausdruck) und als Zahlung einlösen, auch teilweise. Das Guthaben bleibt am Gutschein.
5. Jede Funktion hat einen Schalter pro Kassa. Nach dem Update ist alles aus.
6. Abschluss, Monatsabrechnung, Übersicht, Bons und die Verwaltung im Browser rechnen mit den neuen Angaben richtig.

**Nicht-Ziele (kommen später oder gar nicht)**

- Kundenanzeige als zweiter Bildschirm. Sie kommt, sobald das Gerät feststeht (offene Frage aus der Roadmap). Der digitale Beleg ist so gebaut, dass sie später denselben QR-Code zeigt.
- Beleg per E-Mail oder App schicken. Kundenkonto, Stammkunden-Karte, Punkte.
- Gutschein für eine bestimmte Leistung ("1 × Bowl"), Gutschein mit Ablaufdatum, Gutschein online kaufen, Restguthaben bar auszahlen, verlorenen Gutschein sperren und neu ausstellen.
- Gutschein-Code mit der Kamera lesen. Ein Hand-Scanner, der Ziffern "tippt", funktioniert von selbst und kommt mit Stufe 6.
- Bewirtungsbeleg mit Anlass und Teilnehmern. Rechnung auf Ziel (später zahlen), Lieferschein, Mahnung.
- Getrennt zahlen: Stufe 2.
- Kartenzahlung zurückbuchen (kann das SumUp-SDK nicht, wie bisher). Pfand wird nur bar ausbezahlt.

**Anti-Ziele (so wäre es gescheitert, auch wenn es läuft)**

- Der Imbiss wird langsamer. Sind alle Schalter aus, ist kein Tipp und kein Bildschirm anders als in 1.11.0 mit ausgeschalteten Schaltern.
- Geld stimmt nicht: Das erwartete Bargeld weicht vom echten ab, ein verkaufter Gutschein zählt als Umsatz, oder ein Gutschein lässt sich an derselben Kassa zweimal einlösen.
- Ein Kunde bekommt keinen Beleg: Der digitale Beleg ist nicht abrufbar und gedruckt wurde auch nicht.
- Ein fremder Mensch kann Bons eines Betriebs im Internet durchblättern.
- Jemand muss beim Kassieren Text tippen. Text gibt es nur an einer Stelle: einmal pro Firma beim Anlegen des Rechnungsempfängers, nach dem Bezahlen.

## 3. Rahmenbedingungen

- **Bestand im Code (1.11.0, Datenbank am Tablet 8):** Zahlungen sind eine Liste am Bon (`PaymentKind { cash, card }`), feste Regeln in `domain/receipt_rules.dart`. Pfand hängt am Artikel und an Auswahlen (`depositCents`), steht am Bon als `depositCents`, zählt bei der Signatur zum Satz 0 und bekommt keinen Rabatt. Der Umsatz in den Berichten ist die Summe der Bons mit Pfand, ohne Trinkgeld. Der Kundenbon wird heute nach jedem Verkauf gedruckt, wenn ein Drucker eingerichtet ist; der Auftrag öffnet bei Bargeld auch die Lade. "Verkauf fertig" (`sale_done.dart`) zeigt Bon-Nummer, Druckzustand und Rückgeld. Ein Nachdruck aus "Bons" ist genau der Bon, ohne Vermerk.
- **Kopf der Bon-Spalte:** Dort steht seit 1.11.0 die Taste "Freier Betrag". Der Platz reicht für eine Taste, nicht für drei.
- **Server:** `receipts` trägt den ganzen Bon als `payload`, `rksv_entries` die Signatur. Bons sind am Server unveränderlich (Trigger). Alle Adressen brauchen heute eine Anmeldung oder einen Geräte-Schlüssel; eine öffentliche Seite gibt es nur für `/healthz`. Der Abgleich zum Tablet (`device/pull.ts`) schickt Änderungen nach Nummer und Art; Artikel können vom Tablet aus geändert werden (`push_item_change.ts`).
- **Abgleich:** Der Bon geht als `v: 2` zum Server. Der Server versteht `v: 1` und `v: 2` und muss beide weiter verstehen. Der Server wird vor der App ausgerollt.
- **Regeln aus allen Teilen bisher:** Jede Änderung an der Datenbank am Tablet braucht eine Migration mit Test. Jeder neue Text an der Kassa braucht fünf Sprachen; Kundenbon, Berichte und Einrichtung bleiben Deutsch. Keine Texteingabe im Kassenablauf.
- **Recht (gelesen am 26. und 27.11.2026; Claude ist kein Steuerberater):**
  - *Digitaler Beleg* (§ 132a BAO, bmf.gv.at/public/top-themen/elektronischer-beleg.html): Der Betrieb kann den Beleg übermitteln oder die Möglichkeit geben, ihn "mit einem Endgerät vor Ort auszulesen (z.B. per Bildschirmanzeige)". "Der elektronische Beleg ist auf einem Bildschirm anzuzeigen, der dem Kunden zugewandt ist." Eine bestimmte Form ist nicht vorgeschrieben; ein QR-Code wird auf der Seite nicht genannt. Der Kunde kann "immer" Papier verlangen, sofort oder "spätestens bis zum Geschäftsschluss des Tages". "Die Art der Belegerteilung ist im elektronischen Aufzeichnungssystem zu dokumentieren." Zustimmung des Kunden und eine Frist für die Abrufbarkeit nennt die Seite nicht ("ausreichend lange").
  - *Wertgutschein* (WKO, FAQ Arbeitskreis Kassensoftware, Stand 1.12.2016, Fragen 7, 8, 16): Der Verkauf ist kein Barumsatz; "erst wenn der Wertgutschein eingelöst wird, entsteht ein RKSV-pflichtiger Barumsatz". Steht der Verkauf zusammen mit Barumsätzen auf einem Beleg, zählt er zum Betrag mit Satz 0 und wird signiert.
  - *Pfand* (WKO Salzburg, Stand 27.3.2025): Einwegpfand ist kein steuerbarer Umsatz und steht "in einer eigenen Zeile mit 0%" am Beleg. Mehrwegpfand "unterliegt demselben Steuersatz wie das Hauptprodukt". Zur Rückgabe an der Kassa steht dort nichts.
  - *Rechnung* (WKO, 1.4.2025): bis 400 € brutto reicht die Kleinbetragsrechnung; darüber braucht es Name und Adresse des Empfängers, eine fortlaufende Nummer und die UID des Ausstellers; über 10.000 € auch die UID des Empfängers.

## 4. Wege, die zur Wahl standen

**Pfand zurück**

| Weg | Was dafür spricht | Was dagegen spricht |
| --- | --- | --- |
| A. "Bargeld entnehmen" mit Grund "Pfand" | Kein Bau am Bon | Kein Beleg, kein Bezug zur Ware, lässt sich nicht mit einem Kauf verrechnen |
| **B. Eigene Zeile "Pfand zurück" am Bon, mit Minus-Betrag** | Verrechnet sich mit dem Einkauf. Steht am Bon, im Abschluss und in der Signatur. Storno spiegelt es | Ein Bon kann unter 0 fallen; dafür braucht es "Bar auszahlen" |
| C. Rückgabe nur gegen den alten Bon | Kein Missbrauch möglich | Kein Gast hebt den Bon für einen Becher auf |

Gewählt: **B**, mit dem Schalter "nur Chef" gegen Missbrauch.

**Rechnung an Firma**

| Weg | Was dafür spricht | Was dagegen spricht |
| --- | --- | --- |
| A. Empfänger vor dem Bezahlen am offenen Bon wählen | Der erste Ausdruck ist schon die Rechnung | Text tippen mitten im Kassieren, die Schlange wartet |
| **B. Empfänger nach dem Bezahlen zum Bon erfassen, Bon noch einmal als Rechnung drucken** | Kassieren bleibt schnell. Geht auch, wenn der Gast erst später fragt. Der Bon und seine Signatur bleiben unverändert | Zwei Ausdrucke, wenn der erste schon gedruckt ist |
| C. Firmenkunden nur im Browser anlegen | Kein Tippen am Tablet | Der Chef steht an der Theke, nicht am Browser |

Gewählt: **B.** Firmenkunden lassen sich am Tablet und im Browser anlegen.

**Digitaler Beleg**

| Weg | Was dafür spricht | Was dagegen spricht |
| --- | --- | --- |
| **A. QR-Code auf "Verkauf fertig", der zur Seite des Bons am Server führt** | Braucht kein neues Gerät. Derselbe QR-Code passt später auf eine Kundenanzeige | Braucht Internet. Das Tablet muss so stehen, dass der Kunde den Code sieht |
| B. Kundenanzeige (zweiter Bildschirm) | Erfüllt "dem Kunden zugewandt" ohne Drehen | Das Gerät steht nicht fest und fehlt am Test-Tablet |
| C. Beleg per E-Mail | Kunde hat ihn sicher | E-Mail-Adresse tippen, Datenschutz |

Gewählt: **A.** B kommt, sobald das Gerät feststeht, und nutzt dann A.

**Gutschein**

| Weg | Was dafür spricht | Was dagegen spricht |
| --- | --- | --- |
| A. Nur Zahlungsart "Gutschein", Papier-Gutscheine verwaltet der Betrieb selbst | Schnell gebaut | Kein Guthaben, keine Kontrolle, jeder Zettel gilt |
| **B. Gutschein mit Code und Guthaben in der Kassa** | Teilweise einlösen geht. Der Betrieb sieht, was noch offen ist. Kein doppeltes Einlösen | Mehr Bau: Verkauf, Einlösen, Berichte, Abgleich |
| C. Gutschein als freier Betrag | Kein Bau | Zählt als Umsatz und wird beim Einlösen noch einmal Umsatz |

Gewählt: **B.** Der Code hat 8 Ziffern und wird am Zahlenfeld getippt.

Niko hat die Technik abgegeben; alle vier Entscheidungen sind Claudes und stehen in Abschnitt 8.

## 5. Der Entwurf

### 5.1 Schalter und die Taste "Mehr"

In den Einstellungen der Kassa (nur Chef), Abschnitt "Zahlen" bekommt drei Schalter, ein neuer Abschnitt "Kundenbon" einen:

| Schalter | Werte | Nach dem Update |
| --- | --- | --- |
| Pfand zurück | aus, alle, nur Chef | aus |
| Gutschein | aus, an | aus |
| Rechnung an Firma | aus, an | aus |
| Kundenbon | immer drucken, drucken und digital, digital und Druck auf Wunsch | immer drucken |

"Nur Chef" wirkt wie in 1a: Für Mitarbeiter fehlt die Taste, eine PIN-Abfrage mitten im Ablauf gibt es nicht. Die zwei digitalen Werte lassen sich nur wählen, wenn die Kassa mit dem Server gekoppelt ist; sonst sind sie grau und sagen, warum.

**Kopf der Bon-Spalte.** Dort können jetzt bis zu drei Dinge stehen: "Freier Betrag", "Pfand zurück", "Gutschein". Regel: Darf die angemeldete Person genau eines davon, steht dessen Taste dort wie heute. Darf sie zwei oder drei, steht dort eine Taste "Mehr"; sie öffnet in der Bon-Spalte ein Blatt mit einer großen Taste je Funktion. So bleibt eine Kassa, die nur den freien Betrag nutzt, genau wie in 1.11.0.

### 5.2 Pfand zurück

Die Taste gibt es nur, wenn die Speisekarte mindestens einen Pfand-Betrag kennt (an einem Artikel oder an einer Auswahl).

```
Pfand zurück
0,50 €        [ − ]  3  [ + ]
1,00 €        [ − ]  0  [ + ]
Zurück               −1,50 €
              [ Auf den Bon ]
```

- Das Blatt zeigt je Pfand-Betrag der Speisekarte eine Reihe mit Minus, Anzahl und Plus (höchstens 99). "Auf den Bon" ist grau, solange alles 0 ist.
- Am Bon steht je Betrag eine Zeile "Pfand zurück", zum Beispiel "3 × Pfand zurück −1,50 €". Menge mit Minus und Plus wie bei jeder Zeile. Kein Rabatt, kein Küchenbon, nicht bei "meistverkauft".
- Die Summe des Bons sinkt um das zurückgegebene Pfand. Drei Fälle:
  - Summe über 0: zahlen wie immer. Für die Karte gilt der Kleinstbetrag des Terminals wie heute.
  - Summe genau 0: statt "Bar" und "Karte" steht "Abschließen"; die Lade bleibt zu.
  - Summe unter 0: statt "Bar" und "Karte" steht eine Taste "Bar auszahlen 1,50 €". Ein Tipp schließt den Bon ab, die Lade springt auf, "Verkauf fertig" zeigt "Auszahlen 1,50 €". Gespeichert wird eine Bar-Zahlung über −1,50 €.
- Bei der Signatur zählt das zurückgegebene Pfand wie das verlangte zum Satz 0, mit Minus. Am Bon steht das Pfand weiter in einer Zeile ohne MwSt.
- Storno ist das genaue Spiegelbild.
- Abschluss und Monatsabrechnung: neue Zeile "Pfand zurück" (Anzahl, Summe). Das erwartete Bargeld folgt wie bisher aus den Bar-Zahlungen, also auch aus der Auszahlung.

### 5.3 Rechnung an Firma

Ist der Schalter an, steht die Taste "Rechnung an Firma" an zwei Stellen: auf "Verkauf fertig" und in "Bons" im Detail eines Bons. Bei einem Storno, einem stornierten Bon und einem Übungs-Bon fehlt sie.

Ablauf (Blatt in der Bon-Spalte beziehungsweise im Detail):

1. Liste der gespeicherten Firmenkunden, zuletzt verwendete oben. Gesucht wird über Tasten mit den Anfangsbuchstaben, die vorkommen (keine Tastatur). Ein Tipp wählt den Kunden.
2. "Neuer Kunde": Name (Pflicht), Adresse in zwei Zeilen (Pflicht), UID (frei; Pflicht, wenn der Bon über 10.000 € liegt). Hier, und nur hier, kommt die Tastatur des Tablets. Der Test, der Textfelder in der App verbietet (`test/no_text_field_test.dart`), bekommt dafür eine dritte Ausnahme: genau die Datei mit diesem Formular.
3. "Rechnung drucken": Der Bon wird als Rechnung gedruckt.

Regeln:

- Der Empfänger wird als eigener Eintrag zum Bon gespeichert, mit einer Kopie von Name, Adresse und UID. Ändert jemand später den Firmenkunden, bleiben alte Rechnungen, wie sie waren. Der Bon selbst und seine Signatur ändern sich nicht.
- Die Rechnung ist derselbe Beleg: gleiche Bon-Nummer, gleicher QR-Code. Über den Zeilen steht "Rechnung" und der Block "An: Name, Adresse, UID". Die Rechnungsnummer ist die Kassen-ID mit der Bon-Nummer ("Rechnung Nr. KASSA-1 / 1042"), weil Bon-Nummern je Kassa zählen. Netto und Steuer je Satz und die UID des Betriebs stehen schon heute am Bon.
- Ein Empfänger lässt sich korrigieren (Tippfehler). Jede Fassung bleibt gespeichert; es gilt die letzte.
- Liegt die Summe über 400 €, zeigt "Verkauf fertig" einen ruhigen Hinweis: "Über 400 €: Eine Rechnung braucht Name und Adresse des Kunden."
- Firmenkunden und Empfänger gehen zum Server. Im Browser gibt es eine Seite "Firmenkunden" (anlegen, ändern, archivieren); im Detail eines Bons steht der Empfänger. Änderungen kommen wie bei den Artikeln auf alle Tablets des Betriebs.
- Hat der Bon einen Empfänger, zeigt ihn auch der digitale Beleg (5.4).

### 5.4 Digitaler Beleg

**Die Seite.** Jeder Bon ab dieser Version bekommt am Tablet beim Abschließen einen zufälligen Schlüssel (mindestens 128 Bit). Der Server zeigt unter `/beleg/<Schlüssel>` den Bon als Seite: Betrieb, Zeilen, Rabatte, Steuer je Satz, Zahlungen, QR-Code der Signatur, gegebenenfalls Rechnungsempfänger und "storniert am …". Die Seite braucht keine Anmeldung, setzt keine Cookies, ist für Suchmaschinen gesperrt, lässt sich drucken und passt aufs Handy. Wer den Schlüssel nicht kennt, findet nichts: Ein falscher Schlüssel gibt dieselbe Antwort wie ein unbekannter, und die Adresse ist gegen Durchprobieren gebremst. Bons aus älteren Versionen haben keine Seite. Ein Übungs-Bon hat eine Seite mit demselben Vermerk wie am Papier. Der Code eines Gutscheins steht auf der Seite nur mit den letzten vier Ziffern ("•••• 5678"); ganz steht er nur am Papier und an der Kassa. Die Seite bleibt abrufbar, solange der Server den Bon hat.

**An der Kassa.** Bei "immer drucken" ist alles wie in 1.11.0: kein QR-Code, nirgends. Bei "drucken und digital" druckt die Kassa wie heute und zeigt zusätzlich den QR-Code auf "Verkauf fertig". Bei "digital und Druck auf Wunsch":

```
Verkauf fertig            Bon 1042
Rückgeld                    3,20 €

        [ QR-Code ]
   Bon mit dem Handy mitnehmen

[ Bon drucken ]   [ Nächster Kunde ]
```

- Der Bon wird nicht mehr von selbst gedruckt. Die Lade springt bei Bargeld trotzdem auf, der Küchenbon druckt wie immer.
- Der QR-Code erscheint, sobald der Server den Bon bestätigt hat. Bis dahin steht an seiner Stelle ein ruhiger Platzhalter.
- Hat der Server den Bon nach 3 Sekunden nicht bestätigt (kein Internet, Server nicht erreichbar), druckt die Kassa den Bon von selbst, wie heute, und sagt: "Kein Internet, Bon wird gedruckt." Ist kein Drucker eingerichtet, sagt sie: "Kein Internet: Der digitale Bon ist erst später abrufbar." und zeigt den QR-Code trotzdem.
- "Bon drucken" druckt jederzeit, auch später aus "Bons" (bis Geschäftsschluss ist das Pflicht, die Kassa kann es immer).
- Die Kassa hält zu jedem Bon fest, wie der Beleg erteilt wurde: "gedruckt", sobald der Kundenbon das erste Mal ohne Fehler gedruckt ist, und "digital", sobald der QR-Code das erste Mal gezeigt wurde. Beides sind eigene Einträge mit Zeit (der Bon selbst bleibt unverändert), stehen im Detail des Bons am Tablet und im Browser und gehen zum Server. Das gilt bei jedem Wert des Schalters.
- In "Bons" zeigt das Detail eines Bons den QR-Code seiner Seite, wenn einer der zwei digitalen Werte gewählt und die Kassa gekoppelt ist.
- Den Schlüssel bekommt jeder Bon ab dieser Version, auch bei "immer drucken". So hat ein Bon seine Seite, wenn der Betrieb später umstellt.

Die Kassa zeigt den QR-Code auf ihrem eigenen Bildschirm. Der Betrieb muss das Tablet so stellen oder drehen, dass der Kunde ihn sieht; das steht in der Prüfliste und neben dem Schalter.

### 5.5 Gutschein

**Verkaufen.** Taste "Gutschein" im Kopf der Bon-Spalte (oder unter "Mehr"). Das Blatt hat zwei Reiter, "Verkaufen" und "Prüfen".

```
Gutschein      [ Verkaufen ] [ Prüfen ]
[ 10 € ] [ 20 € ] [ 25 € ] [ 50 € ]
Anderer Betrag            (Zahlenfeld)
                  [ Auf den Bon ]
```

- Wert von 1,00 € bis 500,00 €. Jeder Gutschein ist eine eigene Zeile "Gutschein 25,00 €" mit Menge 1; Minus nimmt sie weg.
- Die Zeile bekommt keinen Rabatt (auch keinen Anteil am Bon-Rabatt), kommt nicht auf den Küchenbon und steht nicht bei "meistverkauft".
- Ein Bon, auf dem ein Gutschein verkauft wird, lässt sich nicht mit einem Gutschein bezahlen.
- Beim Abschließen entsteht der Gutschein mit einem zufälligen Code aus 8 Ziffern (gezeigt als "1234 5678"). Die Kassa vergibt keinen Code, den sie schon kennt. Der Gutschein selbst hat eine eigene Kennung; der Code ist nur zum Tippen. Nach dem Kundenbon druckt die Kassa je Gutschein einen eigenen Abschnitt: Logo und Name des Betriebs, "Gutschein", Wert, Code in großen Ziffern, Datum. "Verkauf fertig" zeigt Wert und Code auch am Bildschirm; ohne Drucker schreibt der Betrieb den Code auf seine eigene Karte. Der Abschnitt lässt sich aus "Bons" nachdrucken.
- Ein verkaufter Gutschein ist kein Umsatz. Das Geld dafür (bar oder Karte) steht bei den Einnahmen. Bei der Signatur zählt der Verkauf zum Satz 0.

**Prüfen.** Reiter "Prüfen": Code tippen, die Kassa zeigt Wert, Guthaben und die Bewegungen mit Datum.

**Einlösen.** Ist der Schalter an und die Summe über 0, steht über "Bar" und "Karte" eine kleinere Taste "Gutschein".

```
Gutschein einlösen       Zu zahlen 9,65 €
Code                 1234 5678   (Zahlenfeld)
Guthaben                         25,00 €
Wird eingelöst                    9,65 €
Bleibt am Gutschein              15,35 €
                    [ Einlösen 9,65 € ]
```

- Nach der achten Ziffer sucht die Kassa von selbst. Kennt sie den Code nicht: "Diesen Gutschein kennt die Kassa nicht." Ist er leer: "Dieser Gutschein ist aufgebraucht." Ist er storniert: "Dieser Gutschein ist storniert." Passen zwei Gutscheine zum Code (zwei Kassen haben ohne Abgleich denselben vergeben, bei 8 Ziffern sehr selten), zeigt die Kassa beide mit Wert und Datum, und die Person wählt.
- Reicht das Guthaben für alles, schließt "Einlösen" den Bon sofort ab. Die Lade bleibt zu. "Verkauf fertig" zeigt "Mit Gutschein bezahlt" und was am Gutschein bleibt.
- Reicht es nicht, heißt die Taste "Einlösen 5,00 €, Rest 4,65 €". Danach steht im Summenblock eine Reihe "Gutschein 1234 5678 −5,00 €" (mit × zum Entfernen) und "Noch zu zahlen 4,65 €". Den Rest zahlt der Gast bar, mit Karte (ab dem Kleinstbetrag des Terminals) oder mit einem weiteren Gutschein.
- Ändert sich der Bon danach, rechnet die Kassa neu: Die gewählten Gutscheine decken in ihrer Reihenfolge so viel, wie sie können. Abgebucht wird erst beim Abschließen, im selben Schritt wie der Bon. Bis dahin ist nichts am Gutschein verändert. Die gewählten Gutscheine überstehen einen Neustart der App wie der offene Bon.
- Reihenfolge der Zahlungen am Bon: Gutscheine, dann bar, dann Karte zuletzt. "Teil bar, Rest Karte" und Trinkgeld bei Karte gehen wie in 1a auch nach einem Gutschein. Die offene Kartenzahlung trägt die Gutscheine mit, damit der Bon nach einer unklaren Zahlung vollständig entsteht.
- Am Bon steht je Gutschein "Gutschein 1234 5678 5,00 €" und "Restguthaben 0,00 €".
- Storno eines Bons, der mit Gutschein bezahlt wurde: Das Guthaben kommt zurück. Storno eines Bons, auf dem ein Gutschein verkauft wurde: nur, solange der Gutschein unberührt ist; er gilt danach als storniert. Sonst sagt die Kassa: "Der Gutschein wurde schon eingelöst. Der Bon lässt sich nicht stornieren."

**Mehrere Kassen und ein neues Tablet.** Jeder Gutschein und jede Bewegung (Verkauf, Einlösung, Storno) geht mit dem Bon zum Server. Der Server schickt Gutscheine und Bewegungen an alle Tablets des Betriebs. Ein Tablet rechnet das Guthaben aus allen Bewegungen, die es kennt. Damit gilt ein Gutschein an jeder Kassa des Betriebs, sobald sie abgeglichen ist, und ein Ersatz-Tablet kennt nach dem Koppeln alle offenen Gutscheine. Sind zwei Kassen ohne Internet, kann derselbe Gutschein an beiden eingelöst werden; das Guthaben fällt dann unter 0, und die Verwaltung im Browser zeigt ihn als "überzogen". An einer einzelnen Kassa ist doppeltes Einlösen ausgeschlossen. Dasselbe gilt für das Storno eines Gutschein-Verkaufs: Die Kassa entscheidet nach dem, was sie kennt. Wurde der Gutschein inzwischen an einer anderen Kassa eingelöst, fällt sein Guthaben unter 0 und er steht als "überzogen" da. "Storniert" ist kein eigener Zustand, sondern folgt aus den Bewegungen.

**Übungsmodus.** Solange die Kassa im Probebetrieb ist, sind ihre Bons Übungs-Bons. Ein Gutschein von einem Übungs-Bon ist ein Übungs-Gutschein: Er lässt sich nur im Probebetrieb einlösen, zählt in keiner Summe und steht im Browser getrennt. Im echten Betrieb sagt die Kassa dazu: "Das ist ein Übungs-Gutschein."

**Browser.** Neue Seite "Gutscheine": Liste mit Code, Datum, Wert, Guthaben und Zustand; im Detail die Bewegungen mit dem jeweiligen Bon; oben die Summe aller offenen Guthaben.

### 5.6 Daten

Datenbank am Tablet, Schritt 9:

- `payments`: Art `voucher` mit Gutschein (Kennung, Code) und Restguthaben nach dieser Zahlung.
- `receipts`: Schlüssel der öffentlichen Seite.
- `receipt_lines`: Zeilen "Pfand zurück" und "Gutschein" sind an ihrer Kennung erkennbar (wie der freie Betrag in 1a). "Pfand zurück" ist eine Zeile mit Preis 0 und Pfand unter 0. "Gutschein" ist eine Zeile zum Satz 0 mit dem Wert als Preis; sie zählt zum Warenwert, bekommt aber nie Rabatt.
- Neue Tabellen: Gutscheine, Gutschein-Bewegungen (nur anfügen, eindeutig je Gutschein und Bon), Firmenkunden, Rechnungsempfänger je Bon (nur anfügen), Belegerteilung je Bon (nur anfügen).
- `pending_card_payments` trägt die gewählten Gutscheine mit. Der Entwurf des offenen Bons (`receiptDraft`) trägt Pfand-Rückgaben, Gutschein-Zeilen und gewählte Gutscheine; ein Entwurf aus 1.11.0 bleibt lesbar.
- `settings`: die vier Schalter.

Feste Regeln im Code (die Regeln aus 1a gelten weiter, drei ändern sich):

- Summe des Bons = Warenwert nach Rabatt + Pfand (verlangt minus zurück). Verkaufte Gutscheine stehen im Warenwert, als Zeilen zum Satz 0 ohne Rabatt.
- Umsatz eines Bons = Summe des Bons minus verkaufte Gutscheine.
- Beträge je Steuersatz zusammen = Summe des Bons plus Trinkgeld; Pfand, verkaufte Gutscheine und Trinkgeld zählen zum Satz 0.
- Reihenfolge der Zahlungen: Gutscheine, bar, höchstens eine Karte zuletzt.
- Eine Gutschein-Zahlung ist nie höher als das Guthaben zum Zeitpunkt des Abschließens an dieser Kassa. Einzige Ausnahme: Die Karte ist schon belastet (das Terminal meldet "bezahlt", oder eine unklare Zahlung wird nachträglich als bezahlt bestätigt), und das Guthaben hat sich inzwischen geändert. Die Karte ist dann schon belastet, also entsteht der Bon wie geplant, und der Gutschein steht als "überzogen" da.
- Eine Zahlung unter 0 gibt es nur bar und nur, wenn die Summe des Bons unter 0 liegt (oder im Storno).
- Verkaufte Gutscheine und Gutschein-Zahlung stehen nie auf demselben Bon.

Abgleich: Der Bon geht als `v: 3` zum Server. Der Server versteht `v: 1`, `v: 2` und `v: 3`. Server-Migration 0005: Tabellen für Gutscheine, Bewegungen, Firmenkunden und Empfänger; dazu Tabellen für die Belegerteilung und für die Schlüssel der Seiten; `receipts` bekommt `voucher_cents` (mit Gutschein bezahlt), `voucher_sale_cents` und `deposit_return_cents`.

### 5.7 Auswertungen

- **Umsatz** ist überall die Summe der Bons ohne verkaufte Gutscheine und ohne Trinkgeld. Zurückgegebenes Pfand mindert ihn, so wie verlangtes Pfand ihn heute erhöht.
- **Abschluss am Tablet und Ausdruck:** Einnahmen bar und mit Karte aus den Zahlungen (sie enthalten das Geld für verkaufte Gutscheine und die Pfand-Auszahlung). Neu: "Mit Gutschein bezahlt", "Gutscheine verkauft" (Anzahl, Summe), "Pfand zurück" (Anzahl, Summe). Erwartetes Bargeld = Wechselgeld + Bar-Zahlungen + Einlagen − Entnahmen, unverändert.
- **Monatsabrechnung** (Tablet, Server, Browser): dieselben Zeilen. Im Browser zusätzlich "Offene Gutscheine am Monatsende".
- **Übersicht:** Umsatz wie oben. Zahlungsarten bar, Karte, Gutschein.
- **Bons** (Tablet und Browser): Zahlungsart zeigt alle Arten des Bons ("Gutschein + Bar"). Neuer Filter "Gutschein". Im Detail Gutschein-Zahlungen mit Code, verkaufte Gutscheine mit Code, Art der Belegerteilung, Rechnungsempfänger.

### 5.8 Version

App 1.12.0 Build 14, Datenbank am Tablet 9, Server-Migration 0005, Bon `v: 3`. Reihenfolge beim Ausrollen: zuerst der Server, dann die Installationsdatei. Beides erst nach Nikos Ja. 1.12.0 enthält 1.11.0.

## 6. Reihenfolge beim Bauen

1. Daten: Migration am Tablet, Bon `v: 3`, Server-Migration, die geänderten festen Regeln. Noch nichts sichtbar.
2. Schalter in den Einstellungen und die Taste "Mehr".
3. Pfand zurück (Blatt, Bon unter 0, "Bar auszahlen", Storno, Bondruck).
4. Rechnung an Firma (Firmenkunden, Empfänger, Ausdruck, Abgleich, Browser).
5. Digitaler Beleg (Schlüssel, Seite am Server, "Verkauf fertig", Druck auf Wunsch, Art der Belegerteilung).
6. Gutschein verkaufen und prüfen (Zeile, Code, Ausdruck).
7. Gutschein einlösen (Zahlung, Rest, Karte danach, Storno).
8. Gutscheine zwischen Server und Tablets abgleichen, Seite im Browser.
9. Auswertungen am Tablet, am Server und im Browser.
10. Texte in fünf Sprachen, Bilder, Prüfliste, Gesamtprüfung, Installationsdatei.

## 7. Prüfung

- Tests zuerst. Viele zufällige Bons mit Pfand-Rückgabe, Gutschein-Verkauf, Gutschein-Zahlung, Rabatt und Trinkgeld: Die festen Regeln halten, Storno ist das genaue Spiegelbild, nach Verkauf und Storno steht jedes Guthaben wie vorher, der Tag endet bei 0.
- Gutschein: An einer Kassa lässt sich nie mehr einlösen, als da ist, auch bei zwei Bons kurz hintereinander und nach einer unklaren Kartenzahlung.
- Migration am Tablet mit einer Datenbank aus 1.11.0. Ein offener Bon und eine offene Kartenzahlung aus 1.11.0 bleiben.
- Das Prüfwerkzeug des BMF läuft über eine eigene Kette mit Pfand-Rückgabe (auch Bon unter 0), Gutschein-Verkauf, Gutschein-Zahlung und Storno.
- Server: Tests für `v: 1`, `v: 2`, `v: 3`. Die öffentliche Seite: richtiger Schlüssel, falscher Schlüssel, Bremse, kein Zugriff auf andere Betriebe, keine Cookies.
- Zusammenspiel Tablet und Server mit `tool/e2e.sh`: Bon mit Gutschein kommt an, die Seite des Bons zeigt dieselben Zahlen, ein zweites Tablet kennt den Gutschein.
- Alle Schalter aus: kein Bild der Kassa ändert sich gegenüber 1.11.0.
- Bilder der neuen Blätter in hell und dunkel, in Deutsch und Arabisch.
- Prüfliste für Niko in `docs/testen/stufe-1b-pruefliste.md`.

## 8. Was Claude festgelegt hat (Niko kann widersprechen)

1. Pfand zurück ist eine Zeile am Bon mit Minus. Fällt der Bon unter 0, zahlt die Kassa bar aus.
2. Pfand-Beträge kommen aus der Speisekarte; einen freien Pfand-Betrag gibt es nicht.
3. Der Rechnungsempfänger wird nach dem Bezahlen erfasst, nicht davor. Das ist die einzige Stelle mit Tastatur.
4. Die Rechnung ist der Bon mit Empfänger. Die Rechnungsnummer ist Kassen-ID plus Bon-Nummer, einen eigenen Nummernkreis gibt es nicht.
5. Der digitale Beleg ist eine Seite am Server hinter einem QR-Code. E-Mail gibt es nicht.
6. Bei "digital und Druck auf Wunsch" druckt die Kassa von selbst, wenn der Server den Bon nach 3 Sekunden nicht hat.
7. Die Seite eines Bons bleibt abrufbar, solange der Server den Bon hat.
8. Gutscheine haben einen Code aus 8 Ziffern, kein Ablaufdatum, und das Restguthaben wird nicht bar ausbezahlt.
9. Ein verkaufter Gutschein ist kein Umsatz und wird mit 0 % signiert.
10. Gutscheine gelten an allen Kassen des Betriebs. Ohne Internet an zwei Kassen kann einer doppelt eingelöst werden; das wird angezeigt, nicht verhindert.
11. Ein Bon mit verkauftem Gutschein lässt sich nur stornieren, solange der Gutschein unberührt ist.
12. Im Kopf der Bon-Spalte steht "Mehr", sobald dort zwei oder drei Funktionen erlaubt sind.
13. Alles kommt in einer Version (1.12.0), gebaut in der Reihenfolge aus Abschnitt 6.
14. Gutscheine aus dem Probebetrieb sind Übungs-Gutscheine und gelten im echten Betrieb nicht.
15. "Kundenbon" hat drei Werte; bei "immer drucken" gibt es keinen QR-Code.
16. Firmenkunden sucht man über Tasten mit Anfangsbuchstaben, nicht über ein Suchfeld mit Tastatur. Die Tastatur kommt nur bei "Neuer Kunde".
17. Auf der Seite eines Bons im Internet steht der Code eines Gutscheins nur mit den letzten vier Ziffern.
18. Nach dem Update holt das Tablet einmal die Firmenkunden und Gutscheine nach, die es vorher überlesen hat. Alles andere bleibt, wie es ist.
19. Die Seite eines Bons liegt unter `/beleg/<Schlüssel>`, nicht unter `/b/…`: Dort liegt schon die Verwaltung im Browser.

Der Entwurf wurde am 27.11.2026 von einem zweiten Prüfer gegengelesen. Seine fünf Fragen (gleicher Code an zwei Kassen, Gutscheine im Probebetrieb, QR-Code bei ausgeschalteten Schaltern, Storno eines anderswo eingelösten Gutscheins, Rechnungsnummer bei mehreren Kassen) sind in 5.1, 5.3, 5.4 und 5.5 beantwortet.

## 9. Offen

Für Niko, ändert den Bau nicht:

- Welche Kundenanzeige es wird. Bis dahin muss der Kunde den QR-Code am Tablet sehen können.
- Ob der Gutschein-Ausdruck vom Bondrucker reicht oder ob Betriebe eigene Karten wollen (dann schreiben sie den Code darauf).

Für die Steuerberatung, ändert höchstens eine Stelle im Code:

- Reicht ein QR-Code am Bildschirm der Kassa als "Bildschirm, der dem Kunden zugewandt ist"? Die Seite des BMF nennt keinen QR-Code.
- Reicht es, die Art der Belegerteilung je Bon zu speichern ("gedruckt" oder "digital angeboten")?
- Gutschein-Verkauf: mit 0 % signiert (so gebaut) oder gar nicht in der Kassa?
- Pfand: Die Kassa führt jedes Pfand mit 0 %. Das stimmt für Einwegpfand. Mehrwegpfand (eigener Becher, eigene Flasche) hat nach der WKO den Steuersatz der Ware. Das ist seit der ersten Version so und betrifft auch die Rückgabe.
- Rechnung mit Empfänger als zweiter Ausdruck desselben Bons: in Ordnung, oder braucht der erste einen Vermerk?

## 10. Abweichungen und Entscheidungen beim Bau

Gebaut am 27.11.2026 in 20 Schritten (Version 1.12.0 Build 14). Hier steht, was beim Bau entschieden wurde und wo der Bau vom Entwurf oben abweicht oder ihn genauer macht. Wo eine Entscheidung später geändert wurde, steht nur der Stand am Ende.

### Ablauf beim Bau

- **Gebaut ohne zweite Freigabe des Bauplans.** Nikos Antwort auf die Karte war: "Ich schreibe den Bauplan und baue 1.12.0 auf dem Zweig. Ausgerollt wird nichts ohne dein Ja." Darum liegt alles auf dem Zweig, und nichts ist ausgerollt.
- **Wer schickt und prüft:** Die einzelnen Bauschritte schicken nichts zu GitHub und geben keine Arbeit weiter. Nach jedem geprüften Schritt schickt die Leitung den Stand und liest die Prüfläufe `app` und `server`, wie in 1a. So bleibt ein Ort, der den Stand kennt.
- **Abgelehnte Befehle:** Lehnt die Sitzung einen Befehl ab (Sicherheitsprüfung, Berechtigung), wird er nie auf anderem Weg versucht und nicht an jemand anderen weitergegeben. Der Schritt endet, und Niko wird gefragt. `.claude/settings.json` gehört Niko. So bleibt jede Ablehnung sichtbar.

### Pfand zurück

- **Auszahlung nur über ihren eigenen Weg.** Der normale Bar-Abschluss lehnt einen Bon unter 0 ab; "Bar auszahlen" hat einen eigenen Ablauf. So entsteht eine Auszahlung nie aus Versehen.
- **Reservierte Kennungen:** Das Einspielen der Speisekarte lehnt Artikel ab, deren Kennung mit `deposit-return-` oder `voucher-sale` beginnt, und die Meldung nennt genau die Form, die getroffen wurde. Die Meldung für `open-amount-` aus 1a und ihr Beispiel bleiben. Eine gemeinsame Meldung für alle drei hätte in die Irre geführt.
- **Gleiche Worte auf Papier und Seite.** Die Seite des Bons im Internet schreibt bei einer Auszahlung wie das Papier "Bar ausbezahlt 0,75", ohne "Gegeben" und "Rückgeld". Die Summenzeile "Pfand zurück" gibt es auf der Seite nicht mehr; die Zeile "3 x Pfand zurück -0,75" bleibt. So lesen sich Seite und Papier gleich, und die Zeilen der Seite ergeben weiter die Summe.
- **"pro Bon" in der Übersicht bleibt, wie es ist:** Es teilt durch alle Bons, auch durch Auszahlungen und Bons nur mit Gutschein. Tablet und Server teilen diese Regel und das Beispiel `shared/fixtures/stats/overview.json`; eine Änderung nur auf einer Seite würde sie auseinanderlaufen lassen. An Tagen mit Auszahlungen ist der Schnitt darum etwas kleiner.

### Gutschein

- **Die Gutschein-Zeile zählt zum Warenwert (`goodsCents`).** So gilt weiter: Warenwert nach Rabatt plus Pfand ist die Summe des Bons. Die Zeile bekommt nie Rabatt.
- **Grundlage für den Bon-Rabatt** ist der Warenwert ohne verkaufte Gutscheine; es gibt dafür genau eine Rechnung (`CartPricing.discountBaseCents`), die auch das Blatt "Rabatt" nutzt. So bekommt ein Gutschein auch keinen Anteil am Rabatt.
- **Umsatz = Summe des Bons minus verkaufte Gutscheine,** überall (Tablet, Server, Browser). Ein verkaufter Gutschein ist kein Umsatz.
- **Die alte Spalte "Zahlungsart" (`paymentKind`) kennt keinen Gutschein.** Ein Bon nur mit Gutschein zählt darum weder bei "Bar" noch bei "Karte". Die Zahlungsarten mit Gutschein stehen in einer eigenen Liste (`paymentKinds`); so bleibt die alte Spalte, wie ältere Teile sie erwarten.
- **"Mit Gutschein abschließen":** Decken die gewählten Gutscheine nach einer Änderung am Bon alles, steht statt "Bar" und "Karte" diese Taste. Ohne sie käme der Bon nicht zu Ende.
- **Zustand eines Gutscheins,** an einer Stelle im Code geregelt und getestet: "Überzogen", wenn das Guthaben unter 0 ist; "Storniert", wenn sein Verkauf storniert ist; "Aufgebraucht" bei Guthaben 0 ohne Storno; sonst "Gültig". Der Entwurf nannte die vier Zustände ohne die Regel.
- **Storno eines Gutschein-Verkaufs** geht, solange das Guthaben gleich dem Wert ist und der Verkauf noch nicht storniert ist, also auch nach einer Einlösung, die selbst storniert wurde. "Unberührt" heißt: Von ihm ist nichts verbraucht.
- **Der Server prüft kein Guthaben.** Er nimmt Bons und Bewegungen an, wie die Tablets sie schicken. Die Kassa entscheidet nach dem, was sie kennt; ein Gutschein unter 0 steht im Browser als "überzogen" (5.5).
- **Ist die Karte schon belastet,** entsteht der Bon immer, auch wenn ein Gutschein dabei unter 0 fällt, und auch ohne die Prüfung "Übung oder echt". Die Karte hat das Geld schon genommen, also muss es den Bon geben.
- **Neustart mit unklarer Kartenzahlung:** Beim Bestätigen vergleicht die Kassa nur Zeilen und Rabatt mit dem gespeicherten Bon, nicht die gewählten Gutscheine. Nach einem Neustart kann ein Gutschein aus der Liste gefallen sein (aufgebraucht, oder an einer anderen Kassa eingelöst); sonst bliebe die Ware am Bon stehen, obwohl die Karte bezahlt ist, und jemand würde noch einmal kassieren.
- **Feste Abläufe beim Speichern:** "Testbon oder nicht" ist eine gemeinsame Regel für Speichern und Senden. Ein Code wird so lange neu gezogen, bis er frei ist (der Zufall lässt sich im Test vorgeben). Kommt derselbe Verkauf ein zweites Mal, endet das vor jeder Prüfung des Guthabens. Die verkauften Gutscheine eines Stornos liest die Kassa über den ursprünglichen Bon. So gibt es keine doppelten Bewegungen.
- **Gespiegelte Zahlungen im Storno** tragen wie seit 1.9 "gegeben 0" und "Rückgeld 0", auch die mit Gutschein; die Prüfung der Gutschein-Felder lässt das beim Storno zu. Sonst würden sich gedruckte Storno-Bons ändern.
- **Kleinigkeiten im Code:** "Kein Rabatt" auf eine Zeile zu setzen ist erlaubt und nimmt den Rabatt weg; einen Gutschein als Zahlung auf einen leeren Bon zu legen ist ein Fehler im Code (an der Kassa gibt es die Taste dann nicht). Beides ist getestet.
- **Am Papier** steht nach den Steuerzeilen eingerückt "davon Gutschein (kein Umsatz)", wie im Bericht "davon Gutscheine". Der Betrag steht schon in der Zeile zum Satz 0; wer die Spalte zusammenzählt, würde ihn sonst doppelt zählen. Das Bild dieses Bons wurde dafür neu gemacht (ein Bild dieser Version).
- **Gutschein und Bar:** Ein Bon mit Gutschein und einer Bar-Zahlung ohne Karte druckt "Gegeben" und "Rückgeld" wie ein Bar-Bon, wenn der gegebene Betrag gespeichert ist. Jede Form aus 1.11.0 druckt wie vorher. Der Entwurf sagte dazu nichts.
- **Filter "Gutschein"** in "Bons" zeigt dieselbe Art von Bons wie "Bar" und "Karte" (gültige Verkäufe). Eine Regel für alle Filter der Zahlungsart.
- **Im Browser steht "Gutscheine" nach "Firmenkunden"** (eine Liste für Computer und Handy), nicht nach "Bons", wie der Plan sagte. So bleiben die Leiste am Handy und die Reihenfolge in "Mehr" wie in 1.11.0, und "Speisekarte" behält ihren Platz. Gutscheine sind bei den meisten Betrieben aus.
- **"Offene Gutscheine am Monatsende"** steht in der Antwort des Servers nur, wenn der Betrag nicht 0 ist. So bleiben die alten Vergleiche ganzer Monate unverändert. Für einen Zeitraum über mehrere Monate gilt das Ende seines letzten Monats (getestet).

### Rechnung an Firma

- **Firmenkunden sucht man über Tasten mit Anfangsbuchstaben** (Punkt 16 in Abschnitt 8). Die Tastatur kommt nur bei "Neuer Kunde"; so bleibt das Kassieren ohne Text.
- **"Als Firmenkunde speichern" lässt sich ausschalten.** Wer nur einmal eine Rechnung braucht, legt so keinen Firmenkunden an.
- **"Ändern" ändert nie einen gespeicherten Firmenkunden.** Dort ist "Als Firmenkunde speichern" zuerst aus; eingeschaltet wird ein neuer Firmenkunde gespeichert, und der Empfänger zeigt auf ihn. Gespeicherte Firmenkunden ändert man im Browser. Vorher konnte das Formular mit den Daten einer anderen Firma den gespeicherten Kunden überschreiben, und das ging an alle Tablets.
- **Keine Rechnung bei Summe 0 oder darunter.** Eine Auszahlung ist keine Rechnung, und eine "Rechnung" mit Minus wäre eine Gutschrift. Ein Bon mit verkauftem Gutschein behält die Taste: Firmen kaufen Gutscheine, die Rechnung zeigt dann 0 %.
- **Der Server prüft "UID nötig über 10.000,00 €"** gegen die Summe des Bons. Fehlerberichte und Protokolle nennen nur Kennungen und Arten, keine Namen und Adressen (Datenschutz).

### Digitaler Beleg

- **Die Seite liegt unter `/beleg/<Schlüssel>`** (Punkt 19 in Abschnitt 8), weil unter `/b/…` schon die Verwaltung im Browser liegt.
- **Der Code eines Gutscheins steht auf der Seite nur mit den letzten vier Ziffern** (Punkt 17 in Abschnitt 8). Wer die Seite sieht, kann den Gutschein so nicht einlösen.
- **Die Kassa hält "digital" fest, sobald der QR-Code auf "Verkauf fertig" zu sehen ist.** Das ist der Moment, in dem der Kunde den Bon mitnehmen kann.
- **Der QR-Code in "Bons" zählt nicht als "digital".** Nur "Verkauf fertig" hält es fest, und bei Sonderbelegen steht in "Bons" kein QR-Code. Sonst würde schon das Ansehen eines alten Bons eine Belegerteilung behaupten, die nicht stattfand. Eine Übergabe später über "Bons" ist darum nicht festgehalten.
- **Die Zeile "Beleg" und die Einträge gelten bei jedem Wert des Schalters,** auch bei "Immer drucken" (dann "Gedruckt"). So sagt es 5.4; es ist die eine benannte Ausnahme von "wie in 1.11.0", und ein Test hält sie mit "Immer drucken" und Drucker fest.
- **"Bon drucken" bei "Digital und Druck auf Wunsch":** "Verkauf fertig" zeigt die Taste, bis der erste Druck des Kundenbons gestartet ist (über die Taste oder nach den 3 Sekunden); das Ergebnis dieses Drucks gilt für den Verkauf. Der Bon druckt hier ja nicht von selbst.
- **Küchenbon und Gutschein-Zettel** drucken bei "Digital und Druck auf Wunsch" wie immer, obwohl der Kundenbon nicht druckt. Ein späterer Druck des Kundenbons druckt die Zettel nicht noch einmal. Testbons (Übungsmodus) folgen dem Schalter wie echte Bons; die Kassa entscheidet nur nach Schalter, Schlüssel und Kopplung. Nur ein Bon ohne Schlüssel (aus 1.11.0) und eine nachträglich bestätigte unklare Kartenzahlung drucken wie bei "Immer drucken".
- **Eine unklare Kartenzahlung, die später als bezahlt bestätigt wird,** druckt den Kundenbon immer von selbst, bei jedem Wert des Schalters, und danach erscheint die Meldung wie sonst. Dieser Weg zeigt nie "Verkauf fertig" und darum keinen QR-Code; Papier ist hier die sichere Seite für die Pflicht, einen Beleg zu geben.
- **Sofort senden:** Bei den zwei digitalen Werten schickt eine gekoppelte Kassa den Bon gleich nach dem Verkauf, ohne die üblichen 2 Sekunden Wartezeit (läuft gerade ein Abgleich, kommt der nächste direkt danach). Sonst bliebe dem Server unter 1 Sekunde, bevor die 3 Sekunden ablaufen, und die Kassa würde auch bei gutem Internet drucken.
- **Die Bremse der Seite zählt nur Fehlversuche, und nur verschiedene falsche Schlüssel:** höchstens 10 je Adresse; derselbe falsche Schlüssel zählt nicht noch einmal. Ohne Drucker steht der Code da, bevor der Server den Bon hat; ein ehrlicher Kunde, der zehnmal neu lädt, würde sonst eine ganze gemeinsame Adresse sperren. Wer rät, probiert ohnehin verschiedene Schlüssel. Danach kommt "zu viele Versuche" (Antwort 429).
- **Laufende Abfragen zählen mit:** Vor dem Nachsehen wird der Versuch vorgemerkt; sind vorgemerkte und gezählte Fehlversuche zusammen 10, kommt 429 ohne Nachsehen. Ein Treffer gibt die Vormerkung frei, ein Fehlversuch wird gezählt. Sonst kämen 30 gleichzeitige falsche Schlüssel alle durch. Viele gleichzeitige echte Aufrufe von einer Adresse bekommen dafür kurz 429.
- **Die Bremse sperrt nur Adressen, deren eigene Zahl voll ist.** Ist ihre Tabelle voll, fällt der älteste Eintrag heraus, statt neue Adressen abzuweisen. Vorher hätte ein Bereich von IPv6-Adressen die Tabelle füllen und alle aussperren können; der Speicher bleibt begrenzt.
- **Neuer Text für einen unbekannten Schlüssel:** "Diesen Bon gibt es nicht. Ein neuer Bon ist vielleicht noch nicht da. Bitte in ein paar Minuten noch einmal versuchen." Es bleibt eine einzige feste Seite für falsch und unbekannt.
- **Eine kaputte Adresse** (falsche Prozent-Zeichen unter `/beleg/`, auch in anderer Schreibung) bekommt dieselbe feste Seite mit denselben Kopfzeilen und zählt als Fehlversuch. Vorher kam eine Fehlermeldung des Servers mit der Adresse darin.
- **Strengere Kopfzeilen der Seite:** zusätzlich `frame-ancestors 'none'`, `base-uri 'none'`, `form-action 'none'` und `X-Content-Type-Options: nosniff`. Die Seite lässt sich so nirgends einbetten und nichts abschicken.
- **Der Schlüssel steht nie in Protokollen, Fehlerberichten oder Messwerten.** Aufrufe unter `/beleg/` werden ohne Schlüssel geschrieben. Der Schlüssel ist das einzige Geheimnis der Seite.
- **Ein Storno bekommt seinen eigenen Schlüssel** und damit seine eigene Seite, denn ein Schlüssel gehört am Server zu genau einem Bon.

### Abgleich und Server

- **Nach dem Update holt das Tablet einmal die Firmenkunden und Gutscheine nach** (Punkt 18 in Abschnitt 8), die 1.11.0 beim Abholen überlesen hat. Der Stand des Abholens wird dafür nicht zurückgesetzt: Ein eigenes Merkmal (`sync_state.catch_up_pending`) sagt, dass nur die neuen Listen von Anfang bis zum eigenen Stand zu holen sind. So bleibt "der Abgleich-Stand bleibt" aus dem Test der Migration wahr, und nichts wird doppelt eingespielt.
- **Empfänger und Belegerteilung schreiben ihren Eintrag zum Senden selbst,** im selben Schritt wie die Daten, ohne neue Trigger. So bleibt die Liste der Trigger für das Senden wie in 1.11.0, und fünf alte Erwartungen bleiben gleich. Nur zwei Stellen im Code schreiben diese Tabellen, beide sind getestet.
- **Ein Empfänger wartet auf seinen Bon.** Solange der Bon selbst noch nicht beim Server ist, schickt das Tablet den Empfänger nicht (er bleibt wartend); dasselbe gilt für die Belegerteilung. Vorher konnte ein kurzer Fehler beim Bon den Empfänger für immer ungültig machen.
- **Die Abhol-Antwort lässt leere neue Listen weg** (Firmenkunden, Gutscheine, Bewegungen). So bleiben der alte Test `pull.test.ts:79` und die Beispiele `pull_full.json` und `pull_delta.json` unverändert; das Tablet liest eine fehlende Liste als leer.
- **Neue Felder nur, wenn es sie gibt:** Das Detail eines Bons trägt `recipient`, `deliveries` und `pageUrl` nur, wenn es einen Wert gibt (sie fehlen sonst, statt leer zu sein). So bleiben die alten Vergleiche ganzer Bons, wo es geht, unverändert.
- **Reihenfolge beim Ausrollen statt Sicherung im Code.** Ein Tablet mit 1.12.0 an einem Server ohne Migration 0005 würde neue Einträge als abgelehnt liegen lassen (wie in 1a). Darum gilt fest: zuerst der Server, dann eine Prüfung, dass er einen Bon in der Form `v: 3` annimmt, erst dann die App; alles erst nach Nikos Ja. Ginge das schief, müssten die Einträge von Hand noch einmal geschickt werden.
- **Bon in der Form `v: 3`:** Der Server nimmt `v: 1`, `v: 2` und `v: 3` an. Ein Bon, den der Server schon kennt, wird vor den neuen Regeln wiedererkannt (Antwort `duplicate`); die neuen Regeln und der Schlüssel gelten nur für neue Bons. Passen die verkauften Gutscheine eines Bons nicht zu seinen Gutschein-Zeilen, nimmt der Server ihn an und schreibt einen Bericht (`vouchers`).

### Texte und Sprachen

- **Umschalter wachsen mit ihrem Text.** Der türkische Text "Yalnızca yönetici" wurde bei großer Schrift (1,3) und 1024 dp Breite abgeschnitten, weil die Umschalter eine feste Höhe hatten. Jetzt haben sie eine Mindesthöhe und wachsen; der Test der Sprachen prüft auch ihre Texte. Zehn Bilder der Einstellungen wurden dafür mit Nikos Ja neu gemacht (unten, Punkt 9).
- **Zum Gegenlesen:** Auf Arabisch heißt "Bon" schon seit 1.10 فاتورة, und "Rechnung" heißt ebenfalls فاتورة; "Kundenbon" (فاتورة العميل) steht direkt unter "Rechnung an Firma" (فاتورة لشركة), beide lesen sich fast gleich. Die Taste "Rechnung drucken" heißt auf Arabisch اطبع فاتورة الشركة ("Rechnung der Firma drucken"), damit sie sich vom Kundenbon unterscheidet. "Bar auszahlen" heißt auf Türkisch jetzt "Nakit iade". Die Wörter für "Zurück" im Blatt "Pfand zurück" (Refund, İade, المُرجَع), für "Auszahlen" und die Texte der Gutscheine sollten Muttersprachler lesen.
- **Nach einer Auszahlung** steht oben auf "Verkauf fertig" weiter "Bezahlt". Der Kopf von "Freier Betrag" bleibt wie in 1.11.0 (bei großer Schrift kann er wie vorher gekürzt sein); eine Änderung würde Bilder aus 1.11.0 ändern.
- **Die Rückfrage vor dem Storno** nennt jetzt jeden Weg des Geldes für sich (siehe "Schlussprüfung").

### Schlussprüfung

Nach den drei Prüfungen am Ende wurde noch einmal nachgebessert. Entschieden wurde dabei:

- **Die Rückfrage vor dem Storno** nennt in dieser Reihenfolge: was bar zurückgeht ("1,50 € bar zurückgeben.") oder bei einer Auszahlung hereinkommt ("Du bekommst 0,75 € bar zurück.", ohne Minus), was jeder Gutschein zurückbekommt ("Der Gutschein 1234 5678 bekommt 2,00 € zurück."), was bei SumUp zurückzubuchen ist, und welcher verkaufte Gutschein danach nicht mehr gilt ("Der Gutschein 1234 5678 gilt danach nicht mehr. Bitte den Abschnitt zurücknehmen."). Für jede Form eines Bons, die es in 1.11.0 gab, bleiben die Texte wie vorher ("Du gibst … bar zurück."). Vorher stand bei einer Auszahlung ein Betrag mit Minus und bei einem Bon mit Gutschein die ganze Summe als Bargeld.
- **Kundenbon nach 3 Sekunden** bei "Digital und Druck auf Wunsch": Die Kassa druckt, außer für den Bon wurde schon ein Druck gestartet oder "digital" ist festgehalten (der Kunde hat den QR-Code gesehen). Ob der Server den Bon hat, zählt dafür nicht mehr. Vorher druckte nichts, wenn jemand vor dem QR-Code "Nächster Kunde" tippte und der Server den Bon kurz danach hatte: Der Kunde hatte dann weder Papier noch Code. Ohne Drucker bleibt alles wie vorher.
- **Bremse der Seite hinter einem Proxy:** Steht `PUBLIC_URL` auf https, bremst der Server die Seite nur nach der Adresse aus der Kopfzeile `CLIENT_IP_HEADER`. Fehlt die Einstellung oder trägt eine Anfrage keine Adresse darin, antwortet die Seite nie mit "zu viele Versuche"; der Server schreibt dann je 10 Minuten eine Fehlerzeile ins Protokoll (ohne Schlüssel und Pfad). Sonst hätten alle Kunden die Adresse des Proxys geteilt, und zehn falsche Schlüssel hätten alle ausgesperrt. Ohne https (lokal, Tests) bleibt alles wie vorher.
- **"Gegeben" und "Rückgeld" nach einer Regel** auf Papier, in "Bons" am Tablet und auf der Seite: die einzige Zahlung, oder bei einem Verkauf die eine Bar-Zahlung neben nur Gutscheinen. Eine Auszahlung zeigt überall "Bar ausbezahlt" ohne Minus.
- **Firmenkunde mit fehlender UID über 10.000 €:** Das Formular beginnt dann als neuer Firmenkunde mit den Daten des gewählten. So kann es keinen gespeicherten Firmenkunden mit den Daten einer anderen Firma überschreiben. Den gespeicherten ändert man im Browser.
- **Die Seite des Bons zeigt unter der Karte "Beleg" mit der Kennung der Zahlung,** wie das Papier. Die Kennung steht schon in den Daten, die der Server hat.
- **Im Browser** steht in der Steuer unter 0 % "davon Gutscheine", wie am Tablet. Das Detail eines Bons zeigt "Pfand zurück" mit seinem Pfand, "Pfand" nur als verlangtes Pfand und eine Auszahlung als "Bar ausbezahlt". Eine Belegerteilung an einem anderen Tag trägt ihr Datum. Die Beträge der Übersicht brechen nicht mehr mitten in der Zahl; wird es eng, rutscht der dritte Betrag in die nächste Zeile.

### Tests

- **Prüfwerkzeug des Finanzministeriums:** Es hat alle fünf Ketten angenommen, auch die neue mit Pfand-Rückgabe, Bon unter 0, Gutschein-Verkauf, Gutschein-Zahlung und Storno. Dabei fiel auf: Der Umsatzzähler der Signatur zählt einen verkauften Gutschein (25,00 € im Satz 0) und zählt noch einmal, wenn er eingelöst wird. Das ist eine Frage an die Steuerberatung (der Zähler ist nicht die Grundlage der Steuer).
- **Beispiel-Daten am Server:** `seed.ts` gibt den zweiten Kopplungscode nur mit `SEED_CODE2=1` aus (`tool/e2e.sh` setzt das). Der alte Test `server/test/seed.test.ts:76` erwartet genau Betrieb, Code und Cookie.
- **Die fünf neuen Zahlen der Abrechnung** am Tablet sind benannte Angaben mit 0 als Vorgabe; kein alter Test und kein alter Helfer musste dafür geändert werden.
- **Fester Zufall für die Beispiele:** Die gemeinsamen Beispiele unter `shared/fixtures/` wurden einmal in der Form `v: 3` neu geschrieben, mit festem Zufall für den Schlüssel der Seite (1101, 1102, 1103, 1104). Zurückgerechnet in die Form `v: 2` sind sie gleich den alten Dateien: kein Betrag und keine Signatur hat sich geändert. Der Test am Server, der `dep.json` an viele Betriebe schickt, gibt jedem gesendeten Bon mit Schlüssel einen frischen Schlüssel, weil ein Schlüssel am Server nur einmal vorkommen darf; keine Erwartung hat sich dabei geändert.

### Geänderte oder erweiterte Erwartungen in vorhandenen Tests

Gemeint sind Tests, Beispiele und Bilder, die es in 1.11.0 schon gab (Stand `a06aeb3`). Jede dieser Änderungen hat Niko freigegeben; Punkt 7 hat Niko selbst eingetragen. Zeilen sind die von heute.

1. **Version der Datenbank 8 wurde 9:** `app/test/data/migration_test.dart:412` und `:646`; `migration_v6_test.dart:87`, `:257`, `:286`, `:329`, `:338`, `:396`; `migration_v7_test.dart:84`, `:147`, `:164`, `:178`; `migration_v8_test.dart:103`, `:309`, `:321`, `:329`.
2. **Liste aller Trigger:** `migration_v7_test.dart:122-135` und `migration_v8_test.dart:172-185` vergleichen jetzt "alle alten Trigger plus genau die acht neuen Schutz-Trigger" (keine Änderung und kein Löschen bei Gutscheinen, Bewegungen, Empfängern und Belegerteilung). Die Namen stehen fest im Test.
3. **Liste der Server-Migrationen:** `server/test/migrate.test.ts:151` bekam `0005_vouchers.sql`.
4. **Form des Bons `v: 3`:** `app/test/sync/push_wire_test.dart:270` (Bon aus der Datei von 1.11.0 mit den neuen leeren Feldern, Helfer `asV3Entry` ab Zeile 26), `:476` (nur der Titel), `:494` (`v` 3 statt 2), `:514` und `:531` (die neuen Gutschein-Felder leer an Bar und Karte); `app/test/sync/receipt_1_10_0_test.dart:26` (Titel), `:55` (`everyElement(3)`), `:57` (neue Datei `receipt_1_10_0_as_v3.json`; `_as_v2.json` bleibt und wird am Server weiter geprüft); `app/test/sync/shared_fixtures_test.dart:265`, `:391`, `:535`, `:670` (fester Zufall).
5. **Gemeinsame Beispiele in der Form `v: 3`:** `shared/fixtures/stats/overview.json`, `months.json`, `mixed.json` und `shared/fixtures/rksv/dep.json`, je einmal neu geschrieben; zurückgerechnet gleich den alten Dateien.
6. **Fünf neue Zahlen der Abrechnung, einzeln geprüft:** `server/test/months.test.ts:82-83`, `:109-110`, `:256-257` nehmen "mit Gutschein bezahlt", "Gutscheine verkauft" (Anzahl, Summe) und "Pfand zurück" (Anzahl, Summe) vorher heraus und prüfen sie einzeln mit 0; der Rest wird wie vorher genau verglichen. `server/test/receipts.test.ts:37-38` (Liste: `voucherCents`, `paymentKinds`), `:142` (Detail: dieselben), `:149-150` (an der Zahlung `voucherCode` und `voucherBalanceAfterCents` leer, am Bon `vouchers: []`), `:186` (dieselben Felder an der Kartenzahlung).
7. **Dritte Ausnahme im Textfeld-Test:** `app/test/no_text_field_test.dart:10` bekam `lib/features/customers/customer_form.dart`. Diese Zeile hat Niko selbst eingetragen (Commit `0f61210`), nachdem die Sitzung die Änderung zweimal abgelehnt hatte.
8. **Zwei alte Tests der Einstellungen:** `app/test/features/payment_settings_test.dart:112` erwartet "للمدير فقط" ("Nur Chef") jetzt dreimal statt zweimal (die neue Reihe "Pfand zurück" hat es auch). `app/test/features/settings_test.dart:82-83`: vor dem Tipp auf "Storno nur durch den Chef" wird der Schalter ins Bild geschoben, weil die Seite länger ist.
9. **Bilder der Einstellungen:** In Schritt 8 wurden 35 Bilder neu gemacht, weil die Karte "Zahlen" drei Reihen und den Abschnitt "Kundenbon" bekam: `einstellungen_kueche_{arabisch,chinesisch,dunkel,hell}.png`, `einstellungen_neu_einspielen_hell.png` und alle 30 Bilder `einstellungen_server_*.png`. Danach wurden die zehn Bilder `einstellungen_server_{abgelehnt_1,abgelehnt_2,rueckfrage,wartend,wartend_und_abgelehnt}_{hell,dunkel}_gross.png` noch einmal neu gemacht, weil die Umschalter mit ihrem Text wachsen.
10. **Kleinere Anpassungen ohne neue oder geänderte Erwartung:** `server/test/push.test.ts:414` neuer Titel "v: 3 ohne die neuen Felder ist invalid" (Erwartung gleich), doppelte Importe zusammengelegt (auch in `push_wire_test.dart`); `server/test/dep.test.ts:39-44` frischer Schlüssel je gesendetem Bon (Helfer `freshToken` aus `server/test/support/stufe_1b.ts`, jetzt exportiert); `app/test/features/device_test_test.dart:175-179` und `:199-204`: der Drucker, der im Test immer scheitert, kennt die neuen Aufrufe (Empfänger, Gutschein-Zettel); die Helfer `app/test/support/sales.dart:74` (`TestShop.open` mit wählbarem Zufall) und `app/test/support/random_cart.dart` (Schalter `withStufe1b`, ohne ihn dieselben Bons wie vorher); `app/test/data/generated_migrations/schema.dart` (von drift erzeugt, Version 9 dazu); `web/src/pages/receipt_discount.test.ts:24-25` und `:45`: das Beispiel eines Bons im Test bekam `voucherCents`, `paymentKinds` und `vouchers` mit leeren Werten, keine Erwartung geändert.

### Was offen bleibt

Diese Punkte entscheidet Niko. Sie sind nicht behoben.

- **Bilder mit der Versionsnummer:** 20 Bilder `einstellungen_server_*` zeigen unten "Kassa Version 1.11.0". Mit 1.12.0 sind ihre Tests rot. Sie werden erst nach Nikos Ja neu gemacht (Liste im Bericht von Schritt 20).
- **Zwei Tests der Verwaltung im Browser** (laufen nicht auf GitHub, Niko ist gefragt): `web/e2e/receipts.spec.ts:584` erwartet im Blatt "Mehr" am Handy die Liste aus 1.11.0, ohne "Firmenkunden" und "Gutscheine"; `web/e2e/support/fixtures.ts:13`: die Kopfzeile der Tests muss seit Schritt 14 eine IP-Adresse sein, sonst zählt jeder Test als 127.0.0.1 und trifft die Bremse der Anmeldung.
- **Seltener roter Test:** `server/test/push_report.test.ts` kann etwa einmal in fünfzig Läufen ohne Grund rot sein (eine zufällige Kennung). Das war schon vor 1.12.0 so.
- **Fragen an die Steuerberatung:** die fünf aus Abschnitt 9 (QR-Code als Bildschirm für den Kunden, Art der Belegerteilung je Bon, Gutschein-Verkauf mit 0 %, Einweg- und Mehrwegpfand, Rechnung als zweiter Ausdruck), dazu neu: Der Umsatzzähler der Signatur zählt einen verkauften Gutschein und zählt noch einmal, wenn er eingelöst wird. Ist das in Ordnung?
- **Ausrollen:** zuerst der Server mit Migration 0005, dann die Prüfung, dass er einen Bon `v: 3` annimmt, dann die Installationsdatei; alles erst nach Nikos Ja. Hat ein Tablet die Datenbank einmal in Version 9 geöffnet, kann es nicht mehr zurück auf 1.11.0. Der Server muss darum mit 1.11.0 und 1.12.0 zugleich arbeiten, solange nicht alle Tablets 1.12.0 haben. Im Probebetrieb entstehen Übungs-Gutscheine, die im echten Betrieb nicht gelten. Vor dem Freischalten der Seiten noch zwei Prüfungen am Proxy vor dem Server: Er muss die Kopfzeile mit der Adresse des Kunden selbst setzen und eine mitgeschickte überschreiben, und der Server muss diese Kopfzeile kennen (Einstellung `CLIENT_IP_HEADER`); sonst zählen alle Kunden als eine Adresse, und 10 falsche Schlüssel sperren alle aus. Und es ist zu prüfen, ob der Proxy die aufgerufenen Pfade protokolliert, denn der Pfad `/beleg/…` enthält den Schlüssel; dann muss das Protokoll den Pfad weglassen oder kürzen.
- **Reihenfolge beim Drucken:** Wird ein zweiter Verkauf in etwa 5 Sekunden fertig, kann sein Kundenbon vor den Gutschein-Zetteln des Verkaufs davor drucken.
- **Seltene Fälle:** Fehlt ein gewählter Gutschein plötzlich in der Datenbank, lässt sich eine unklare Kartenzahlung nicht mehr lesen (schwer erreichbar: am Tablet lassen sich Gutscheine nicht löschen). Ein Bon, der über "Bons" digital übergeben wird, ist nicht als "digital" festgehalten. Die Warnung bei 30 % Trinkgeld rechnet mit der ganzen Summe, auch mit Gutschein.
- **Kleinigkeiten:** "Das Guthaben hat sich geändert" steht 6 Sekunden. Namen in chinesischer oder arabischer Schrift lassen sich auf der Rechnung nicht drucken. Auf der Seite des Bons steht kein Name einer Mitarbeiterin. Der "Jahresbeleg" druckt von selbst; ein Übungs-Bon hat eine Seite; "Bon drucken" gibt es nur mit Drucker.
- **Für nach dem Ausrollen:** Die Dateien `app/lib/domain/cart.dart` (etwa 880 Zeilen) und `app/lib/data/receipt_repository.dart` (etwa 1300 Zeilen) sind groß geworden und könnten geteilt werden. Jetzt Code mit Geld zu verschieben, brächte nur Gefahr.
- **Aus der Schlussprüfung bewusst gelassen** (selten oder ohne Folgen für das Geld):
  - Eine unbekannte Zahlungsart in der Datenbank des Tablets würde den Abschluss anhalten. Die Kassa schreibt nie eine; ältere Teile machen es genauso.
  - Die Prüfung der Gutschein-Felder verlangt das Restguthaben an einer Gutschein-Zahlung nicht. Die Kassa schreibt es immer.
  - Kommt beim Abholen der Verkauf eines Gutscheins erst auf der nächsten Seite, steht der Gutschein kurz als "Aufgebraucht" da.
  - Scheitert der Druck nach den 3 Sekunden, wenn schon "Nächster Kunde" getippt ist, sagt die Kassa nichts.
  - Nach einem Fehler beim Speichern, der kein geändertes Guthaben ist, zeigt das Blatt "Gutschein einlösen" "Zu zahlen 0,00 €". Ein neuer Versuch schreibt denselben Bon.
  - Die Lade kann zweimal aufspringen, wenn "Bon drucken" genau beim Öffnen der Lade getippt wird.
  - Aufrufe der Seite mit einem gültigen Schlüssel haben keine Grenze.
  - Ein Bon `v: 3`, der eine Regel bricht, wird abgelehnt, wie es dieser Entwurf sagt, obwohl er schon signiert und gedruckt ist. Das passiert nur bei einem Fehler im Code des Tablets.
  - Die Antwort "dieser Schlüssel gehört zu einem anderen Bon" sagt einem gekoppelten Tablet, dass es den Schlüssel gibt. Bei 128 Bit ist das ohne Folgen.
  - Tests fehlen noch für das Maskieren von Name des Betriebs, Empfänger, Optionen und Fußzeile auf der Seite.
  - Ein Storno eines Bar-Bons druckt weiter "Gegeben 0,00" wie in 1.11.0.
  - Ein Übungs-Gutschein auf einem echten Bon bei einer Kartenzahlung, die schon belastet ist, wird trotzdem gebucht: Die Karte braucht ihren Bon.
  - Bei großer Schrift (1,3), 1024 x 600 und Arabisch ist der Kopf eines Bons in "Bons" um 0,3 Punkte zu breit, wenn drei Zahlungsarten in der Pille stehen.
  - Das Speichern eines Empfängers prüft nicht selbst, ob der Bon eine Rechnung haben darf (Übungs-Bon, Storno, Auszahlung). An der Kassa gibt es die Taste dann nicht, und nur die Kassa ruft es auf. Die Prüfung hätte vier Tests dieser Version geändert, die Empfänger an Übungs-Bons hängen.
