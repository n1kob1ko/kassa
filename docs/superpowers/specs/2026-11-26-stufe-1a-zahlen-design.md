# Kassa Stufe 1a: Zahlen (gemischt zahlen, Trinkgeld, Rabatt, freier Betrag)

Stand: 26.11.2026. Entwurf, noch nicht freigegeben.

Gehört zur Roadmap "Kassa: Nächste Schritte für Restaurant und Handel" (https://claude.ai/artifact/7AYwSKehrHpS2wMFGKv1NG). Niko am 26.11.2026: "mach einfach alles aber es sollte getrennt bleiben also man soll sich die art von kassa dann auswählen können".

## 1. Worum es geht

Die Kassa kann heute genau einen Ablauf: bonieren, dann den ganzen Bon bar oder den ganzen Bon mit Karte zahlen. Ein Bon hat genau eine Zahlung, es gibt keinen Rabatt, kein Trinkgeld und keinen Artikel ohne Taste.

Restaurant (Stufe 2 bis 5) und Handel (Stufe 6) brauchen mehr: Ein Gast zahlt einen Teil bar und den Rest mit Karte, gibt Trinkgeld, bekommt einen Rabatt. Das alles ändert das Herz der Kassa, nämlich Bon und Zahlung. Diese Stufe ändert es einmal, bevor Tische darauf aufbauen. Sie ist auch für sich nützlich: Jeder Imbiss kann danach Rabatt geben und Trinkgeld mit Karte annehmen.

Stufe 1 ist geteilt. Diese Datei beschreibt 1a. 1b (Gutschein, digitaler Beleg, Rechnung an Firma, Pfand zurück) bekommt einen eigenen Entwurf.

## 2. Ziele, Nicht-Ziele, Anti-Ziele

**Ziele**

1. Ein Bon kann mehrere Zahlungen tragen. Erster Fall: ein Teil bar, der Rest mit Karte.
2. Trinkgeld bei Kartenzahlung: Der Gast sagt den Endbetrag, die Kassa rechnet das Trinkgeld, das Terminal bucht den Endbetrag. Das Trinkgeld steht getrennt vom Umsatz, pro Mitarbeiter und Tag.
3. Rabatt auf eine Zeile oder auf den ganzen Bon, in Prozent oder als Betrag, immer mit Grund.
4. Freier Betrag: etwas verkaufen, für das es keine Taste gibt, mit Steuersatz.
5. Jede der vier Funktionen ist pro Kassa ein- und ausschaltbar. Nach dem Update ist alles aus.
6. Abschluss, Monatsabrechnung, Übersicht, Bons und die Verwaltung im Browser rechnen mit den neuen Angaben richtig.

**Nicht-Ziele (kommen später)**

- Gutschein, digitaler Beleg, Rechnung an Firma, Pfand zurück: Stufe 1b.
- Getrennt zahlen (mehrere Bons aus einer Bestellung) und mehrere Karten auf einem Bon: Stufe 2.
- Auswahl der Art der Kassa (Imbiss, Restaurant, Handel): Stufe 2, weil es erst dann eine zweite Art gibt. Bis dahin sind die Schalter aus Ziel 5 der Weg, wie ein Imbiss einfach bleibt.
- Trinkgeld bei Barzahlung erfassen. Bares Trinkgeld landet wie heute im Glas oder in der Tasche und geht die Kassa nichts an.
- Trinkgeld unter Mitarbeitern verteilen (Tronc), Trinkgeld am Kartengerät eintippen lassen.
- Automatische Rabatte (Happy Hour, Mittagsmenü), Rabatt-Gründe selbst anlegen.
- Kartenzahlung zurückbuchen (kann das SumUp-SDK nicht, wie bisher).

**Anti-Ziele (so wäre es gescheitert, auch wenn es läuft)**

- Der Imbiss wird langsamer. Sind alle Schalter aus, ist kein Tipp und kein Bildschirm anders als in 1.10.0.
- Geld stimmt nicht: Das erwartete Bargeld im Abschluss weicht vom echten ab, oder Trinkgeld landet im Umsatz.
- Eine Karte wurde belastet, und es gibt keinen Bon dazu. Die bestehende Absicherung (offene Kartenzahlung steht in der Datenbank, bevor das Terminal etwas erfährt) bleibt ohne Lücke.
- Jemand muss an der Theke tippen. Alle Eingaben gehen über Tasten und Zahlenfeld.

## 3. Rahmenbedingungen

- **Bestand im Code (1.10.0, Datenbank am Tablet 7):** `payments` hat `receiptId` als Schlüssel, also eine Zahlung pro Bon. `Receipt.payment` ist ein einzelnes Feld. `ReceiptRepository.finalizeCashSale` und `finalizeCardSale` schreiben Bon, Zeilen, Zahlung und Signatur-Eintrag in einem Schritt. Vor der Signatur wird geprüft, dass die fünf Beträge je Steuersatz zusammen die Summe des Bons ergeben; das Pfand zählt zum Satz 0. Der offene Bon liegt als JSON in `settings.receiptDraft`, die offene Kartenzahlung mit einer Kopie des Bons in `pending_card_payments`.
- **Auswertungen** teilen heute den ganzen Bon einer Zahlungsart zu: `DayRepository._summarize`, `period_report.dart`, am Server `admin/months.ts`, `admin/overview.ts`, `admin/receipts.ts` (Spalte `payment_kind`).
- **Abgleich:** Der Bon geht als Eintrag `receipt` mit `v: 1` und einem Feld `payment` zum Server (`push_wire.dart`, `push_schema.ts`). Der Server muss weiter Tablets mit 1.10.0 verstehen. Wie bisher wird der Server vor der App ausgerollt.
- **Regel seit der ersten Installationsdatei:** Jede Änderung an der Datenbank am Tablet braucht eine Migration mit Test. Der Test-Schlüssel der Installationsdatei bleibt derselbe.
- **Sprachen:** Die Bedienung gibt es in fünf Sprachen. Jeder neue Text an der Kassa braucht alle fünf. Kundenbon, Berichte und Einstellungen der Einrichtung bleiben Deutsch.
- **Recht (gelesen am 26.11.2026, Quellen in der Roadmap):** Trinkgeld für Mitarbeiter ist ein durchlaufender Posten. Steht es auf einem Beleg, wird es als Umsatz mit 0 % signiert (BMF-FAQ für Kassenhersteller 2016, Frage 4). Seit 1.1.2026 haben Mitarbeiter ein Recht auf Auskunft über Trinkgeld, das bargeldlos kam (§ 2j ARAG). Ein Rabatt mindert den Barumsatz; signiert wird, was tatsächlich bezahlt wird.
- **SumUp:** Mindestbetrag 1,00 €. Kein Zurückbuchen und kein Nachschlagen im SDK.

## 4. Wege, die zur Wahl standen

**Mehrere Zahlungen**

| Weg | Was dafür spricht | Was dagegen spricht |
| --- | --- | --- |
| A. Eine Zahlung pro Bon, mit Zusatzfeldern "davon bar" und "Trinkgeld" | Kleinster Umbau | Trägt weder Gutschein (1b) noch eine zweite Karte. Der Umbau käme zweimal |
| **B. Zahlungen als Liste am Bon** | Trägt bar, Karte, später Gutschein. Abschluss und Berichte rechnen aus den Zahlungen statt aus dem Bon | Alle Auswertungen müssen einmal umgestellt werden |
| C. Jede Teilzahlung ist ein eigener Bon | Passt zum getrennten Zahlen | Ein Gast, der halb bar und halb mit Karte zahlt, bekäme zwei Bons. Das ist Stufe 2, nicht dieser Fall |

Gewählt: **B.** Niko hat die Technik abgegeben, das ist Claudes Entscheidung.

**Trinkgeld**

| Weg | Was dafür spricht | Was dagegen spricht |
| --- | --- | --- |
| A. Gar nicht in der Kassa, Betrag am Terminal händisch erhöhen | Kein Bau | Geht mit der direkten Kartenzahlung gar nicht: Die Kassa schickt den Betrag |
| **B. Eigener Betrag an der Kartenzahlung, am Bon ausgewiesen, bei der Signatur im Satz 0** | Entspricht der BMF-Auskunft. Umsatz und Trinkgeld bleiben überall getrennt | Der Umsatzzähler der Signatur enthält das Trinkgeld. Die Berichte müssen es herausrechnen |
| C. Trinkgeld als Artikel "Trinkgeld" mit 0 % | Schnell gebaut | Trinkgeld stünde in Artikel-Auswertung und Umsatz. Kein sauberer Bezug zum Mitarbeiter |

Gewählt: **B.**

**Rabatt**

| Weg | Was dafür spricht | Was dagegen spricht |
| --- | --- | --- |
| A. Rabatt als eigene Zeile mit Minus-Betrag | Sieht aus wie am Papier | Bei Artikeln mit verschiedenen Steuersätzen bräuchte es mehrere Minus-Zeilen. Auswertungen pro Artikel zeigen den vollen Preis |
| **B. Rabatt an jeder Zeile gespeichert, der Bon-Rabatt wird auf die Zeilen verteilt** | Steuer pro Zeile stimmt immer. Storno spiegelt jede Zeile. Am Bon steht der Bon-Rabatt trotzdem als eine Zeile | Verteilen auf Cent braucht eine feste Regel |

Gewählt: **B.**

## 5. Der Entwurf

### 5.1 Schalter

Neuer Abschnitt "Zahlen" in den Einstellungen der Kassa (nur Chef, wie die anderen Abschnitte):

| Schalter | Werte | Nach dem Update |
| --- | --- | --- |
| Teil bar, Rest Karte | aus, an | aus |
| Trinkgeld bei Kartenzahlung | aus, an | aus |
| Rabatt | aus, alle, nur Chef | aus |
| Freier Betrag | aus, alle, nur Chef | aus |

"Nur Chef" heißt: Ist ein Mitarbeiter angemeldet, fehlt die Taste, genau wie heute die Storno-Taste bei `voidRequiresChef`. Eine Abfrage der Chef-PIN mitten im Ablauf gibt es nicht. Ein Rabatt, den der Chef gesetzt hat, bleibt am offenen Bon stehen, wenn danach ein Mitarbeiter weiterboniert; entfernen kann ihn dann nur der Chef. Die Schalter gelten pro Kassa, wie alle Einstellungen heute. Wenn mit Stufe 2 die Art der Kassa dazukommt, setzt sie nur die Vorgaben.

### 5.2 Gemischt zahlen: Teil bar, Rest Karte

Regel: Auf einem Bon gibt es höchstens eine Kartenzahlung, und sie kommt zuletzt. So bleibt die bestehende Absicherung der Kartenzahlung unverändert: Der Bon entsteht in dem Moment, in dem das Terminal "bezahlt" meldet, mit allen Zahlungen in einem Schritt. Sagt der Gast "20 mit Karte, Rest bar", nimmt die Kassierin zuerst das Bargeld und bucht dann die Karte.

Ablauf im Bar-Blatt (nur wenn der Schalter an ist):

```
Bar                              Summe 46,80 €
[ Ganzer Betrag ]  [ Teil bar ]
Bar-Teil            30,00 €      (Zahlenfeld)
Rest mit Karte      16,80 €
                     [ Weiter zur Karte  16,80 € ]
```

- Der Bar-Teil muss größer als 0 sein, und der Rest muss mindestens den Mindestbetrag des Terminals haben. Sonst ist die Taste grau und sagt, warum.
- Der Bar-Teil ist der Betrag, der in der Lade bleibt. Rückgeld rechnet die Kassa hier nicht.
- Danach läuft die Kartenzahlung wie heute (mit Trinkgeld-Schritt, falls an). Meldet das Terminal "bezahlt", entsteht der Bon mit zwei Zahlungen, und die Lade springt auf.
- Scheitert die Karte sicher, ist nichts gespeichert. Die Kassa steht wieder beim offenen Bon und sagt: "Karte nicht bezahlt. 30,00 € bar zurückgeben oder noch einmal versuchen."
- Ist der Ausgang unklar, greift das bestehende Blatt "Unklare Kartenzahlung". Die offene Zahlung trägt Bar-Teil und Trinkgeld mit, damit der Bon nach der Klärung vollständig entsteht.

### 5.3 Trinkgeld bei Kartenzahlung

In Österreich sagt der Gast den Endbetrag ("mach 50"). Die Kassa fragt deshalb nach dem Betrag, den der Gast zahlt, nicht nach dem Trinkgeld.

Ist der Schalter an, kommt nach dem Tipp auf "Karte" ein Blatt:

```
Karte                                 46,80 €
Gast zahlt
[ 47,00 ]  [ 50,00 ]  [ Anderer Betrag ]
Trinkgeld                              3,20 €
[ Ohne Trinkgeld ]     [ Zum Terminal  50,00 € ]
```

- Vorschläge: nächster voller Euro, nächste Fünfer-Stufe, nächste Zehner-Stufe, ohne Doppelte, höchstens drei.
- "Ohne Trinkgeld" ist ein Tipp und geht sofort zum Terminal.
- Schutz vor Vertippen: Ist das Trinkgeld höher als 30 % der Summe und höher als 5,00 €, fragt die Kassa einmal nach ("Trinkgeld 453,20 €?").
- Das Terminal bucht Summe plus Trinkgeld in einem Betrag.
- Ist der Schalter aus, geht "Karte" wie heute direkt zum Terminal.

Am Bon:

```
Summe                   46,80
Karte                   50,00
  davon Trinkgeld        3,20
```

Bei der Signatur zählt das Trinkgeld zum Satz 0 (wie heute das Pfand). Die Prüfung vor der Signatur heißt dann: Die fünf Beträge ergeben zusammen Summe plus Trinkgeld. Diese Zuordnung steht an einer einzigen Stelle im Code, damit sie sich nach einer Auskunft der Steuerberatung ändern lässt.

Ausbezahlt wird Karten-Trinkgeld aus der Lade: Die Liste der Gründe für eine Entnahme bekommt "Trinkgeld". Der Abschluss zeigt Karten-Trinkgeld des Tages pro Mitarbeiter. Das ist die Auskunft, auf die Mitarbeiter seit 1.1.2026 ein Recht haben.

### 5.4 Rabatt

Zwei Stellen, ein Blatt:

- **Zeile:** Ist der Rabatt an, öffnet ein Tipp auf Name und Preis der Bon-Zeile das Blatt für diese Zeile. Minus, Menge und Plus bleiben, wie sie sind. Ist der Rabatt aus (oder "nur Chef" und ein Mitarbeiter angemeldet), tut der Tipp nichts, wie heute, und die Zeile sieht genauso aus wie in 1.10.0.
- **Ganzer Bon:** Im Summenblock eine Taste "Rabatt". Ihr Blatt trägt den Hinweis: "Für eine einzelne Zeile die Zeile im Bon antippen."

```
Rabatt auf: 2x Bowl Lachs                19,80 €
Grund    [Stammgast] [Mitarbeiter] [Reklamation] [Aktion] [Einladung]
Höhe     [5 %] [10 %] [15 %] [20 %] [50 %] [100 %] [Betrag]
Neu                                      17,82 €
                         [ Entfernen ]  [ Übernehmen ]
```

- Ein Grund ist Pflicht. Die fünf Gründe sind fest. "Einladung" wählt 100 % vor.
- "Betrag" öffnet das Zahlenfeld. Der Rabatt kann nie höher sein als der Warenwert. Pfand wird nie rabattiert.
- Zeilen-Rabatt und Bon-Rabatt können zusammen vorkommen. Der Bon-Rabatt rechnet vom Wert nach den Zeilen-Rabatten.
- Im offenen Bon steht der Rabatt als eigene kleine Reihe unter der Zeile ("−10 % Stammgast −1,98") beziehungsweise als eigene Reihe im Summenblock. Ein Tipp auf diese Reihe öffnet das Blatt wieder, dort ändert oder entfernt man ihn.
- Ändert sich der Bon (Menge, neue Zeile), rechnet ein Prozent-Rabatt mit. Ein Betrag-Rabatt bleibt, wird aber auf den Warenwert gekappt.

Rechenregel für das Verteilen, damit alle Geräte auf den Cent gleich rechnen:

1. Zeilen-Rabatt in Prozent: kaufmännisch gerundet vom Warenwert der Zeile.
2. Bon-Rabatt in Prozent: kaufmännisch gerundet von der Summe der Zeilen nach Schritt 1.
3. Der Bon-Rabatt wird im Verhältnis des Werts auf die Zeilen verteilt. Reste von Cents gehen an die Zeilen mit dem größten Rest, bei Gleichstand an die frühere Zeile.
4. Trägt eine Zeile zwei Steuersätze (Option mit eigenem Satz), wird ihr Rabatt nach derselben Regel auf die Sätze verteilt.

Am Bon:

```
2x Bowl Lachs           19,80
   Rabatt 10 % Stammgast -1,98
1x Cola                  3,50
Zwischensumme           21,32
Rabatt 10 % Aktion      -2,13
Summe                   19,19
```

Ist die Summe nach dem Rabatt 0,00 € (Einladung ohne Pfand), gibt es statt "Bar" und "Karte" eine Taste "Abschließen". Der Bon entsteht mit einer Bar-Zahlung über 0,00 €, die Lade bleibt zu.

Storno spiegelt den Bon samt Rabatten und Zahlungen mit umgekehrtem Vorzeichen, wie heute.

### 5.4a Storno und Trinkgeld

- Der Storno-Bon spiegelt auch das Trinkgeld: Die Kartenzahlung steht mit Minus-Betrag und Minus-Trinkgeld darauf. Bei der Signatur zählt das Minus-Trinkgeld zum Satz 0.
- Das Trinkgeld gehört der Person, die kassiert hat, nicht der Person, die storniert. Deshalb trägt jede Zahlung mit Trinkgeld eigene Felder "Trinkgeld für" (Id und Name). Beim Verkauf ist das die Bedienung des Bons, beim Storno die Bedienung des stornierten Bons. Alle Auswertungen pro Mitarbeiter lesen diese Felder.
- Das Minus zählt zum Tag des Stornos, wie der Storno-Bon selbst (bestehende Regel seit Teil A, von Niko bestätigt).
- Der Storno-Dialog nennt, was zurückzugeben ist: den Bar-Teil in bar und den Karten-Teil samt Trinkgeld über SumUp ("30,00 € bar zurückgeben. 20,00 € bei SumUp zurückbuchen, davon 3,20 € Trinkgeld."). Wurde das Trinkgeld schon ausbezahlt, regelt das der Betrieb selbst; die Kassa zeigt es im Abschluss als Minus bei der Person.

### 5.5 Freier Betrag

Ist der Schalter an, steht im Kopf der Bon-Spalte eine Taste "Freier Betrag".

```
Freier Betrag
Betrag               12,50 €     (Zahlenfeld)
Steuersatz   [20 %]  [10 %]  [13 %]  [0 %]
                                   [ Auf den Bon ]
```

- Die Zeile heißt am Bon "Diverses 20 %" (je nach Satz). Der Name wird nicht getippt.
- Menge und Rabatt gehen wie bei jeder Zeile. Höchstbetrag 9.999,99 €.
- Die Zeile hat keinen Artikel in der Speisekarte. In der Auswertung "meistverkauft" steht sie als "Diverses" je Satz. Auf den Küchenbon kommt sie nicht.

### 5.6 Daten

Datenbank am Tablet, Schritt 8:

- `payments`: Schlüssel wird (`receiptId`, `position`). Neue Spalten `tipCents` (Vorgabe 0) und "Trinkgeld für" (Id und Name, leer ohne Trinkgeld). Bestehende Zeilen bekommen Position 0.
- `receipts`: neue Spalten `tipCents`, `discountCents` (Summe aller Rabatte, positiv), dazu die Angaben zum Bon-Rabatt (Prozent oder leer, Betrag, Grund).
- `receipt_lines`: neue Spalten für den Rabatt der Zeile: gesamter Rabatt der Zeile in Cent (eigener plus Anteil am Bon-Rabatt), eigener Rabatt (Prozent oder leer, Betrag, Grund). Die Beträge je Steuersatz stehen wie bisher nach allen Rabatten da.
- `pending_card_payments`: trägt zusätzlich Bar-Teil und Trinkgeld.
- `settings`: die vier Schalter.
- Der Entwurf des offenen Bons (`receiptDraft`) trägt Rabatte und Zeilen mit freiem Betrag. Ein Entwurf aus 1.10.0 bleibt lesbar.

Feste Regeln im Code:

- Summe der Zahlungen (ohne Trinkgeld) = Summe des Bons.
- Summe des Bons = Warenwert nach Rabatt plus Pfand.
- Beträge je Steuersatz zusammen = Summe des Bons plus Trinkgeld.
- Höchstens eine Kartenzahlung pro Bon, an letzter Stelle.

Abgleich: Der Bon geht als `v: 2` zum Server, mit `payments` als Liste und den neuen Feldern. Der Server versteht `v: 1` und `v: 2`. Server-Migration 0004: `receipts` bekommt `cash_cents`, `card_cents`, `tip_cents`, `discount_cents`, für alte Bons aus `payment_kind` und `total_cents` gefüllt; `payment_kind` kennt zusätzlich `mixed`.

### 5.7 Auswertungen

Überall gilt: Bar und Karte kommen aus den Zahlungen, nicht mehr aus dem Bon.

- **Abschluss am Tablet und Ausdruck:** Einnahmen bar und mit Karte aus den Zahlungen. Neu: "Rabatte" (Anzahl, Summe), "Trinkgeld Karte" (Summe und pro Mitarbeiter), "Am Kartenkonto" (Karten-Umsatz plus Trinkgeld, zum Vergleich mit der Abrechnung von SumUp). Erwartetes Bargeld = Wechselgeld + Bar-Zahlungen + Einlagen − Entnahmen.
- **Monatsabrechnung** (Tablet, Server, Browser): dieselben neuen Zeilen, Trinkgeld pro Mitarbeiter.
- **Übersicht:** Umsatz nach Rabatt, ohne Trinkgeld. Zahlungsarten aus den Zahlungen.
- **Bons** (Tablet und Browser): Zahlungsart "Bar", "Karte" oder "Bar + Karte". Im Detail alle Zahlungen, Trinkgeld und Rabatte. Der Filter "Bar" und der Filter "Karte" zeigen gemischte Bons beide.

### 5.8 Version

App 1.11.0 Build 13, Datenbank am Tablet 8, Server-Migration 0004. Reihenfolge beim Ausrollen: zuerst der Server, dann die Installationsdatei. Beides erst nach Nikos Ja.

## 6. Reihenfolge beim Bauen

1. Daten: Zahlungen als Liste, Migration am Tablet, Bon-Modell, feste Regeln. Noch keine neue Funktion sichtbar.
2. Auswertungen am Tablet auf Zahlungen umstellen.
3. Abgleich `v: 2`, Server-Migration, Verwaltung im Browser.
4. Schalter in den Einstellungen.
5. Trinkgeld bei Karte.
6. Teil bar, Rest Karte.
7. Rabatt (Rechenregel, Blatt, Bon, Storno).
8. Freier Betrag.
9. Bondruck, Abschluss-Ausdruck, Monatsabrechnung mit den neuen Zeilen.
10. Texte in fünf Sprachen, Prüfliste, Gesamtprüfung, Installationsdatei.

## 7. Prüfung

- Tests zuerst, wie in allen Teilen bisher. Die Rechenregel für Rabatte bekommt Tests mit vielen zufälligen Bons: Die Summe der Zeilen stimmt immer mit dem Bon überein, kein Betrag wird negativ, Storno ist das genaue Spiegelbild.
- Migration am Tablet mit Test auf einer Datenbank aus 1.10.0.
- Das Prüfwerkzeug des BMF läuft über eine Kette mit Rabatt, Trinkgeld, gemischter Zahlung und Storno.
- Server: Tests für `v: 1` und `v: 2`, Migration mit alten Bons.
- Zusammenspiel Tablet und Server mit `tool/e2e.sh`.
- Bilder der neuen Blätter aus den Tests, in hell und dunkel, in Deutsch und Arabisch (von rechts nach links).
- Prüfliste für Niko in `docs/testen/stufe-1a-pruefliste.md`. Am echten Terminal kann nur Niko prüfen.

## 8. Was Claude festgelegt hat (Niko kann widersprechen)

1. Stufe 1 wird geteilt: zuerst Zahlen (1a), dann Gutschein, digitaler Beleg, Rechnung an Firma, Pfand zurück (1b).
2. Die Auswahl der Art der Kassa kommt mit Stufe 2. Bis dahin halten Schalter den Imbiss einfach.
3. Alles Neue ist nach dem Update aus.
4. Trinkgeld gibt es nur bei Kartenzahlung. Bares Trinkgeld erfasst die Kassa nicht.
5. Trinkgeld steht am Bon und zählt bei der Signatur zum Satz 0 %.
6. Auf einem Bon gibt es höchstens eine Kartenzahlung, und sie kommt zuletzt.
7. Fünf feste Rabatt-Gründe: Stammgast, Mitarbeiter, Reklamation, Aktion, Einladung.
8. Der freie Betrag heißt "Diverses" plus Steuersatz.
9. Karten-Trinkgeld wird als Entnahme mit dem Grund "Trinkgeld" aus der Lade ausbezahlt.
10. "Nur Chef" blendet die Taste für Mitarbeiter aus, es gibt keine PIN-Abfrage mitten im Ablauf.
11. Ein Storno nimmt auch das Trinkgeld zurück, bei der Person, die kassiert hat, am Tag des Stornos.

Der Entwurf wurde am 26.11.2026 von einem zweiten Prüfer gegengelesen. Seine drei Fragen (Storno und Trinkgeld, "nur Chef", Platz der Rabatt-Taste an der Zeile) sind in 5.1, 5.4 und 5.4a beantwortet.

## 9. Offen

Für die Steuerberatung, ändert den Bau nicht, nur eine Stelle im Code:

- Trinkgeld bei Kartenzahlung: am Beleg mit 0 % (so gebaut) oder gar nicht am Beleg?
- Trinkgeld, das der Chef selbst bekommt, ist nach Claudes Wissen Umsatz mit Steuer. Die Kassa behandelt vorerst jedes Trinkgeld gleich.

## 10. Abweichungen und Entscheidungen beim Bau

(wird beim Bauen gefüllt)
