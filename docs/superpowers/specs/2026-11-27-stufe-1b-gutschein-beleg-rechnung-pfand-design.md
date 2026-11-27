# Kassa Stufe 1b: Pfand zurück, Rechnung an Firma, digitaler Beleg, Gutschein

Stand: 27.11.2026. Entwurf, noch nicht freigegeben.

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
