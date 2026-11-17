# Kassa: Entwurf

Stand: 17.11.2026. Dieses Dokument beschreibt, was Kassa in der ersten Version ist und wie es gebaut wird. Es ist die Grundlage für den Umsetzungsplan. Nichts wird gebaut, bevor Niko es freigegeben hat.

Wer was entschieden hat, steht dabei. "Niko" heißt: von Niko so gesagt. "Claudes Entscheidung" heißt: von Claude festgelegt, weil Niko die Technik abgegeben hat, und hier zum Gegenprüfen aufgeschrieben. "Zu prüfen" heißt: noch nicht belegt, darf nicht als Tatsache behandelt werden.

Verwandte Unterlagen: `PRODUCT.md` im Repo (Produktkontext), die Bildschirm-Entwürfe unter https://claude.ai/artifact/LcysCovwYcfv18pH1PMahC (Version 15) die Speisekarte des Pilotbetriebs als Daten (liegt außerhalb des Repos, siehe 5.9) und Nikos Regel-Listen in `docs/design-regeln.md`.

## 1. Worum es geht

Niko baut ein Kassensystem für die Gastronomie in Österreich und verkauft es als Produkt an viele unterschiedliche Betriebe. Vorbilder sind Square POS, Clover POS und Toast. Es soll für den Imbiss oder Stand funktionieren, wo nur boniert und kassiert wird, und später für große Restaurants mit mehreren Geräten, Kellnern und Stationen.

Der Grund, warum ein Betrieb wechselt: Kartenzahlung in einem Schritt. Der erste Pilotbetrieb (asiatische Bowls, Sushi, Ramen) hat heute eine Windows-Kassa und ein SumUp Air. Für jede Kartenzahlung braucht er ein Extra-Handy mit der SumUp-App, tippt den Betrag dort noch einmal ein und drückt danach in der Windows-Kassa "Kartenzahlung", damit der Bon druckt. Mit Kassa geht der Betrag von selbst ans Terminal, und der Bon druckt von selbst.

Erfolg der ersten Version heißt: Der Pilotbetrieb boniert mit Kassa auf einem Android-Tablet schneller und mit weniger Geräten als heute, rechtssicher nach der Registrierkassensicherheitsverordnung (RKSV), und Niko kann einen zweiten Betrieb einrichten, indem er dessen Logo und Speisekarte einspielt. "Einrichten" heißt hier: Der Betrieb ist angelegt und lässt sich am Tablet durchtesten. Damit er echt verkaufen darf, braucht er seine eigene Signatur (siehe 5.8, "Weitere Betriebe").

## 2. Ziele, Nicht-Ziele, Anti-Ziele

**Ziele der Version 1 (Imbiss-Modus)**

- Bonieren über große Artikel-Tasten nach Kategorien, mit Auswahl-Vorlagen (zum Beispiel die Bowl-Auswahl aus Größe, Basis, Extra-Topping, Extra-Sauce), Pfand pro Artikel, Kennzeichen wie VEGAN und SCHARF.
- Menge ändern, Zeile löschen, Bon leeren mit Rückgängig, Storno eines fertigen Bons.
- Bar zahlen mit Vorschlägen und eigenem Betrag über ein Zahlenfeld, Rückgeld. Karte zahlen über SumUp in einem Schritt.
- Pfand zurückgeben: Leergut wird als Minus-Zeile boniert (Claudes Entscheidung, siehe 5.3).
- Bondruck. Geldlade öffnet bei Barzahlung und ist pro Kassa abschaltbar (Niko, 17.11.2026: manche Betriebe haben keinen Platz für eine Lade).
- Bereiche Bons, Übersicht (Dashboard), Artikel, Abschluss (Tagesabschluss), Einstellungen, so wie im Entwurf gezeigt. Dazu Bargeld einlegen und entnehmen während des Tages (Claudes Entscheidung, siehe 5.3).
- Bar bonieren geht ohne Internet weiter.
- RKSV: Signatur, Datenerfassungsprotokoll, QR-Code am Bon, die vorgeschriebenen Sonderbelege.
- Eigenes Konto pro Betrieb mit getrennten Daten, Mitarbeiter melden sich mit PIN an.
- Verwaltung im Browser für den Betrieb (Artikel, Preise, Umsätze).
- Werkzeug für Niko als Anbieter: Betrieb anlegen, Logo, Speisekarte und Fotos einspielen (Niko, 17.11.2026).
- Zuschaltbare Kundenanzeige.

**Nicht-Ziele der Version 1** (bewusst später): Tische, Kellner-Handgeräte, Küchen- und Bar-Stationen, Lagerstand, Gutscheine, Online-Bestellungen, Rabatte und frei eingetippte Beträge, Trinkgeld, Selbstanmeldung von Betrieben, Abo-Abrechnung, Hardware-Komplettpaket, iPad- und Windows-Version, Online-Signatur statt Chipkarte, andere Kartenterminals als SumUp, eigene Farben pro Betrieb, andere Sprachen als Deutsch, Menüs zum Fixpreis über mehrere Steuersätze, Kundenanzeige über ein Kabel.

**Anti-Ziele** (das soll Kassa nie tun)

- An der Theke eine Tastatur verlangen. Jede Eingabe geht über große Tasten, Schalter und das Zahlenfeld. Namen und Texte werden nur in der Browser-Verwaltung getippt.
- Stehen bleiben, wenn Internet, Drucker, Kartenterminal oder Signaturkarte ausfallen. Bar bonieren geht immer weiter.
- Einen fertigen Bon löschen oder ändern. Korrekturen laufen über Storno.
- Preise für Kassa selbst erfinden. Die sind nicht festgelegt.

## 3. Rahmenbedingungen

- **Österreich.** Registrierkassenpflicht nach RKSV, Belegerteilungspflicht. Oberfläche auf Deutsch mit österreichischen Begriffen: bonieren, Bon, Storno, Tagesabschluss, Geldlade, Kundenanzeige.
- **Android-Tablet von Anfang an** (Niko, 17.11.2026). Windows am vorhandenen PC war kurz die Wahl und wurde verworfen, weil sich das SumUp Air nur von Android oder iOS aus direkt ansteuern lässt (belegt auf developer.sumup.com/terminal-payments). Der Windows-PC beim Pilotbetrieb fällt weg.
- **Vorhandenes weiterverwenden.** Der Pilotbetrieb behält das SumUp Air und vorerst die RKSV-Chipkarte (Niko, 17.11.2026: Online-Signatur erst später, weil Anfragen und Termine jetzt zu lange dauern).
- **Ein USB-Anschluss am Tablet.** Kartenleser, Bondrucker und Laden teilen ihn sich über einen Verteiler mit Stromversorgung.
- **Bedienung.** Fettige oder nasse Finger, Schlange vor der Theke, grelles Tageslicht oder wenig Licht, Personal mit unterschiedlichen Deutschkenntnissen.
- **Niko ist kein Entwickler.** Alles, was er freigibt oder entscheidet, wird in einfachen Worten vorgelegt. Die Technik hat er abgegeben.
- **Testgeräte gibt es noch nicht.** Niko hat ein Xiaomi Redmi Pad Pro (rund 12 Zoll) und kauft Drucker, Verteiler und Kartenleser erst.
- **Arbeitsweise** (Niko): alle Skills und Design-Regeln verwenden, vorerst ohne Pull Requests auf dem Arbeits-Branch committen.

## 4. Wege, die zur Wahl standen

**Form des Produkts.** Vorgelegt wurden drei Wege. Niko hat B gewählt.

| Weg | Was es wäre | Warum nicht oder warum |
|---|---|---|
| A | Reine Web-Anwendung im Browser | Verworfen: kein verlässlicher Zugriff auf Bondrucker, Kartenterminal und Signaturkarte, schwach ohne Internet. |
| **B** | **App für Tablets und Kassengeräte plus Verwaltung im Browser** | **Gewählt von Niko.** Die App spricht direkt mit den Geräten und läuft ohne Internet, die Verwaltung braucht keine Installation. |
| C | Klassische Windows-Kasse | Verworfen: bindet an den PC, kein direkter Weg zum SumUp Air. |

**Technik der App.** Niko hat die Wahl abgegeben. Claudes Entscheidung: Weg 1.

| Weg | Was es wäre | Abwägung |
|---|---|---|
| **1** | **Flutter (Sprache Dart), Geräte-Anbindung in kleinen Kotlin-Teilen** | **Gewählt.** Ein Code für Android jetzt, iPad und Windows später. Eigene Zeichnung der Oberfläche, dadurch sieht der Entwurf auf jedem Gerät gleich aus. SQLite für den Betrieb ohne Internet ist ausgereift. Preis: SumUp, USB-Drucker und Kartenleser brauchen je ein kleines Stück Kotlin. |
| 2 | Kotlin mit Jetpack Compose, nur Android | Bester Zugriff auf Android-Geräte, aber iPad und Windows wären später ein eigener Aufwand. Widerspricht dem Ziel, eine Windows-Version möglich zu halten. |
| 3 | React Native | Ein Code für Android und iPad, aber Windows ist schwächer unterstützt, und die Geräte-Anbindung braucht genauso eigene Android-Teile. |

**Signatur.** Drei Wege wurden mit Niko besprochen. Er hat die Chipkarte gewählt, der Online-Dienst kommt später.

| Weg | Abwägung |
|---|---|
| **Vorhandene Chipkarte mit Kartenleser am Tablet** | **Gewählt von Niko.** Kein Termin, keine Anfrage nötig, signiert auch ohne Internet. Preis: Ansteuerung der Karte ist selbst zu bauen und noch nicht belegt (siehe 5.8), die Karte muss je nach Typ bis Mai 2027 getauscht werden. |
| fiskaly SIGN AT (Online-Dienst) | Claudes ursprüngliche Empfehlung: nimmt Protokoll und Meldungen ab, kostet laufend, Preise nur auf Anfrage. Kommt später. |
| A-Trust a.sign RK HSM (Online-Signatur) | Nur über Partnervertrag, liefert nur die Signatur. Preise nur auf Anfrage. Kommt später als Alternative. |

## 5. Was gebaut wird

### 5.1 Die Teile

1. **Kassa-App** auf dem Android-Tablet. Hier wird boniert. Sie hält alle Daten, die sie zum Arbeiten braucht, selbst auf dem Gerät.
2. **Server** in der Cloud. Hält die Daten aller Betriebe getrennt, gleicht mit den Kassen ab, liefert Auswertungen.
3. **Verwaltung im Browser** für den Betrieb: Artikel, Preise, Fotos, Mitarbeiter, Umsätze.
4. **Anbieter-Werkzeug** für Niko, im selben Browser-Programm mit eigener Rolle: Betriebe anlegen und einrichten.
5. **Kundenanzeige**: zweites Android-Gerät, das dem Kunden Bestellung und Summe zeigt (siehe 5.3).

### 5.2 Aufbau an der Theke

- Android-Tablet auf einem Ständer, der den USB-Anschluss frei lässt. Empfohlen 10 bis 12 Zoll, aktuelles Android, mindestens 4 GB Arbeitsspeicher.
- USB-Verteiler mit Eingang fürs Ladegerät. Daran: Kartenleser mit der RKSV-Chipkarte, und der Bondrucker, falls er per USB angeschlossen ist.
- Bondrucker mit 80 mm Papier. Kassa unterstützt drei Anschlussarten: USB, Netzwerk, Bluetooth.
- Geldlade, falls vorhanden, hängt am Bondrucker und wird von ihm geöffnet.
- SumUp Air, per Bluetooth mit dem Tablet verbunden.

### 5.3 Die Kassa-App

Die Bildschirme sind im Entwurf festgelegt und von Niko für den Kassenbildschirm bestätigt ("sieht gut aus", 17.11.2026). Die weiteren Bereiche hat Niko verlangt und gesehen, eine ausdrückliche Rückmeldung dazu steht aus. Mit der Freigabe dieses Dokuments gelten sie so, wie sie im Entwurf stehen, als Vorlage für den Bau. Änderungen daran bleiben danach möglich.

**Bereiche** (Reiter in der Kopfleiste): Kassa, Bons, Übersicht, Artikel, Abschluss. Einstellungen über die Taste rechts oben.

**Kassa.** Kategorien links, Artikel in der Mitte, Bon rechts, unten Bar und Karte (Aufbau von Niko vorgegeben).
- Artikel-Tasten mit Foto oder kompakt ohne Foto, umschaltbar. Erste Kategorie sind die Favoriten.
- Ein Tipp legt den Artikel auf den Bon. Gleiche Artikel ohne Auswahl werden zu einer Zeile zusammengezählt.
- Hat ein Artikel eine Auswahl-Vorlage, öffnet sich die Auswahl in der Mitte. Pflichtgruppen sind markiert, Vorgaben sind schon gewählt (Größe Normal), Aufpreise stehen bei der Option. "Auf den Bon" geht erst, wenn alle Pflichtgruppen gewählt sind.
- Pfand kommt bei Artikeln mit Pfand von selbst dazu und steht am Bon getrennt.
- **Pfand zurück** (Claudes Entscheidung, im Entwurf noch nicht gezeichnet): Eine Taste bei den Getränken legt pro Tipp eine Minus-Zeile "Pfand zurück" mit 0,25 € auf den Bon. Sie lässt sich mit einem Einkauf verrechnen. Ist die Summe negativ, zeigt Bar den Betrag zum Auszahlen, und Karte ist gesperrt. Grund: Wer Einweg-Pfandgetränke verkauft, muss nach Claudes Wissensstand Leergut zurücknehmen (zu prüfen, samt Ausnahmen für kleine Verkaufsstellen). Ob der Pilotbetrieb Getränke zum Trinken im Lokal ohne Pfand verkauft, ist bei Niko erfragt. Bis zur Antwort gibt es dafür keinen Schalter.
- "Bon leeren" lässt sich einige Sekunden lang rückgängig machen.
- **Bar:** Vorschläge (passend, nächste runde Beträge) oder "Anderer Betrag" mit Zahlenfeld. Rückgeld wird angezeigt. Ist der Betrag zu klein, steht "Fehlt noch" da und Abschließen ist gesperrt. Beim Abschließen druckt der Bon, die Geldlade öffnet sich, falls eingeschaltet.
- **Karte:** Der Betrag geht ans SumUp Air. Nach der Bestätigung ist der Bon abgeschlossen und druckt von selbst. Bei Abbruch oder Fehler bleibt der Bon offen, mit einer Meldung, was passiert ist.
- Ohne Internet: Hinweis in der Kopfleiste, Karte ist gesperrt, Bar geht weiter.

**Bons.** Liste der Bons des Tages mit Filter (alle, bar, Karte, storniert), rechts der Bon im Detail. "Nochmal drucken" druckt eine Kopie. "Stornieren" fragt einmal nach und erzeugt einen Storno-Bon.

**Übersicht.** Umsatz für heute, 7 Tage, 30 Tage. Balken pro Stunde oder Tag zum Antippen, Zahlungsarten, meistverkaufte Artikel, Umsatz nach Kategorie. Zahlen kommen aus den Bons auf dem Gerät, bei mehreren Kassen später vom Server.

**Artikel.** Pro Artikel: "Im Verkauf" und Favorit per Schalter, Preis über das Zahlenfeld, Pfand, Vegan und Scharf per Schalter. Namen, Fotos und neue Artikel nur in der Browser-Verwaltung.

**Abschluss.** Einnahmen nach Zahlungsart, Steuer nach Satz, Bargeld: Wechselgeld am Morgen, Bar-Einnahmen, Soll, gezählter Betrag über das Zahlenfeld, Unterschied. "Tag abschließen" druckt den Bericht. Ohne Geldlade heißt der Teil "Bargeld" statt "Geldlade".

Claudes Entscheidungen zu Bargeld und Tag, im Entwurf noch nicht gezeichnet. Die Bildschirme dazu kommen zu Beginn von Schritt 2 in den Entwurf und zu Niko:
- **Wechselgeld.** Beim Abschließen gibt man über das Zahlenfeld ein, wie viel in der Lade bleibt. Das ist das Wechselgeld des nächsten Tages. Der Rest gilt als entnommen. Beim allerersten Tag wird das Wechselgeld beim ersten Öffnen des Bereichs eingegeben.
- **Bargeld einlegen und entnehmen** während des Tages (Bank, Einkauf, Wechselgeld holen): zwei Tasten im Bereich Abschluss, Betrag über das Zahlenfeld, Grund aus einer kurzen Liste zum Antippen. Beides zählt ins Soll. Ob solche Bewegungen ins RKSV-Protokoll gehören, ist zu prüfen.
- **Ein Tag** beginnt mit dem ersten Bon nach dem letzten Abschluss und endet mit "Tag abschließen", nicht um Mitternacht. Ein Lokal, das bis 2 Uhr offen hat, schließt danach ab, und alles zählt zu diesem Tag. Nach dem Abschluss beginnt der nächste Bon einen neuen Tag.
- **Vergessener Abschluss.** Ist der letzte Tag bei der ersten Anmeldung am nächsten Kalendertag noch offen, weist Kassa darauf hin und bietet den Abschluss an. Bonieren wird nie gesperrt.
- Die Übersicht rechnet nach Kalendertagen. Monats- und Jahresbeleg der RKSV hängen am Kalender und nicht am Tagesabschluss (siehe 5.8).

**Einstellungen pro Kassa.** Zustand von Bondrucker und Kartenterminal, Geldlade ein oder aus, Kundenanzeige ein oder aus (der Schalter erscheint erst mit Schritt 4), Artikel mit Bildern, dunkle Ansicht. Dazu eine Seite "Geräte testen" (siehe 5.14).

**Kundenanzeige** (Claudes Entscheidung zur Bauform). In Schritt 4 wird die Variante mit zweitem Gerät gebaut: ein beliebiges Android-Gerät, auf dem Kassa im Modus "Kundenanzeige" läuft, einmal per Code mit der Kassa gekoppelt, verbunden über das WLAN im Lokal. Das geht ohne Internet, solange das WLAN läuft. Der eingebaute zweite Bildschirm eines Kassengeräts kommt mit dem Hardware-Komplettpaket. Ein Bildschirm am Kabel wird nicht unterstützt, weil der eine USB-Anschluss schon belegt ist.

**Küche.** Küchenstationen sind kein Ziel der Version 1. Wie die Bestellung beim Pilotbetrieb heute in die Küche kommt, ist bei Niko erfragt (siehe 8). Druckt die alte Kassa dort einen Zettel für die Küche, bekommt Version 1 einen abschaltbaren zweiten Ausdruck ohne Preise am selben Drucker. Sonst nichts.

**Anmeldung und Rollen.**
- Das Tablet wird einmal mit einem Kopplungscode aus der Verwaltung an den Betrieb gebunden.
- Mitarbeiter melden sich mit einer PIN an (vier Ziffern über das Zahlenfeld) und lassen sich über die Taste mit ihrem Namen wechseln.
- Rollen: Mitarbeiter (Kassa, Bons), Chef (alles im Betrieb), Anbieter (Niko, alle Betriebe). Claudes Entscheidung: Übersicht, Artikel, Abschluss und Einstellungen brauchen die Chef-Rolle. Storno darf in der Voreinstellung jeder Mitarbeiter, der Betrieb kann es auf den Chef beschränken.

### 5.4 Daten

Geldbeträge sind immer ganze Cent, Preise sind brutto. Jeder Datensatz gehört zu genau einem Betrieb.

| Was | Wichtigste Angaben |
|---|---|
| Betrieb | Name, Adresse, UID-Nummer, Logo, Text am Bon-Ende |
| Kassa (Gerät) | Name, Kassen-Kennung für die RKSV, Einstellungen, Kopplung |
| Mitarbeiter | Name, PIN (nur als Prüfwert gespeichert), Rolle |
| Kategorie | Name, Reihenfolge, Foto |
| Artikel | Name, Preis, Kategorie, Steuersatz, Pfand, Kennzeichen, Zusatzangabe (zum Beispiel "5 Stück"), Favorit, im Verkauf, Foto, Auswahl-Vorlage |
| Auswahl-Vorlage | Name, Gruppen. Eine Vorlage hängt an vielen Artikeln. |
| Gruppe | Name, mindestens und höchstens wählbar, Vorgabe, Optionen |
| Option | Name, Aufpreis, auf Wunsch eigener Steuersatz und eigenes Pfand (sonst gilt der Artikel) |
| Bon | laufende Nummer pro Kassa, Zeitpunkt, Mitarbeiter, Zeilen, Zahlung, Summen pro Steuersatz, Pfand, RKSV-Angaben, Bezug zum stornierten Bon |
| Bon-Zeile | Artikel, Name und Preis zum Zeitpunkt des Bons, Menge, gewählte Optionen, Pfand, Betrag pro Steuersatz. Auch Minus-Zeilen (Pfand zurück) |
| Zahlung | Art (bar, Karte), Betrag, gegeben und Rückgeld, bei Karte die SumUp-Kennung |
| Bargeld-Bewegung | Einlage oder Entnahme, Betrag, Grund, Zeitpunkt, Mitarbeiter |
| Tagesabschluss | Beginn und Ende des Tages, Summen, Wechselgeld am Anfang, Einlagen und Entnahmen, gezählter Betrag, Unterschied, in der Lade gelassen, Mitarbeiter |
| RKSV-Protokoll | ein Eintrag pro Bon in der vorgeschriebenen Form, verkettet |

Ein Bon speichert Namen und Preise selbst. Spätere Änderungen an Artikeln verändern alte Bons nicht.

Claudes Entscheidung zu Menüs: Eine Bon-Zeile kann Beträge in mehr als einem Steuersatz tragen, und eine Option kann einen eigenen Steuersatz und eigenes Pfand haben (zum Beispiel ein Getränk als Option zu einer Speise). Damit lässt sich ein Menü aus Speise und Getränk später abbilden, ohne alte Bons umzubauen. Nicht in Version 1: ein Menü zum Fixpreis, dessen Preis auf zwei Steuersätze aufgeteilt werden muss. Die Karte des Pilotbetriebs braucht beides nicht.

Steuersätze: 20 %, 10 %, 13 %, 0 % und der Sondersatz, wie die RKSV sie getrennt verlangt. In der Karte des Pilotbetriebs sind Speisen mit 10 % und Getränke mit 20 % angenommen (zu prüfen mit dem Betrieb oder dessen Steuerberatung). Pfand wird ohne Umsatzsteuer geführt (zu prüfen, siehe 8).

### 5.5 Ohne Internet und Abgleich

- Die App liest und schreibt nur ihre eigene Datenbank auf dem Gerät. Der Abgleich mit dem Server läuft im Hintergrund.
- Bons entstehen nur auf der Kassa. Jeder Bon hat eine eigene, auf dem Gerät erzeugte Kennung. Der Server nimmt denselben Bon nie zweimal an, egal wie oft er gesendet wird.
- Artikel, Vorlagen, Mitarbeiter und Betriebsdaten gehören dem Server und werden auf die Kassa geholt. Was an der Kassa geändert wird (Preis, im Verkauf, Favorit), geht als Änderung an den Server. Bei gleichzeitigen Änderungen gilt pro Feld die spätere.
- Ohne Internet gehen: Bonieren, Bar, Drucken, Signieren mit der Chipkarte, Bons, Übersicht, Abschluss. Nicht: Kartenzahlung, Abgleich, Einrichtung.
- Fotos werden beim Abgleich heruntergeladen und auf dem Gerät gehalten.

### 5.6 Kartenzahlung mit SumUp

- Anbindung über das SumUp Reader SDK für Android. Es unterstützt das Air (belegt). Die SumUp-Cloud-Schnittstelle unterstützt nur Solo und kommt deshalb vorerst nicht in Frage.
- Der Betrieb meldet sich einmal in den Einstellungen mit seinem SumUp-Konto an.
- Jede Zahlung trägt eine eigene Kennung von Kassa. Stürzt die App zwischen Zahlung und Bon ab, fragt sie beim nächsten Start bei SumUp nach, ob die Zahlung durchging, und schließt den Bon nach oder verwirft ihn.
- Während der Zahlung zeigt SumUp seinen eigenen Bildschirm. Der lässt sich nur begrenzt anpassen (zu prüfen, wie weit).
- **Nicht nur SumUp Air auf Dauer** (Frage von Niko, 17.11.2026). Version 1 bindet SumUp an, weil der Pilotbetrieb ein Air hat, und wird mit dem Air getestet. Andere SumUp-Geräte wie das Solo sollen über dasselbe SDK laufen. Das ist vor einer Zusage an einen Kunden am echten Gerät zu prüfen.
- Die Zahlungsanbindung sitzt hinter einer Schnittstelle (Betrag senden, Ergebnis empfangen, Zahlung nachfragen, abbrechen, rückbuchen). Weitere Anbieter kommen später je nach Bedarf der Kunden als eigene Umsetzung dieser Schnittstelle dazu, zum Beispiel Bankterminals über das ZVT-Protokoll (etwa Hobex), myPOS oder Stripe Terminal. Keiner davon ist bisher geprüft. Welcher Anbieter zu einer Kassa gehört, steht in den Einstellungen der Kassa.
- Storno eines Karten-Bons: Kassa erzeugt den Storno-Bon. Ob die Rückbuchung auf die Karte aus Kassa heraus ausgelöst werden kann, ist zu prüfen. Sonst zeigt Kassa den Hinweis, sie in der SumUp-App zu machen.

### 5.7 Bondruck und Geldlade

- Druckersprache ESC/POS, wie sie Epson, Star und die meisten Bondrucker verstehen. Papier 80 mm.
- Drei Anschlussarten hinter einer Schnittstelle: USB, Netzwerk, Bluetooth.
- Empfohlenes Testgerät: Epson TM-m30III (Claudes Vorschlag, noch nicht gekauft). Ob der vorhandene Drucker des Pilotbetriebs bleiben kann, hängt vom Modell ab, das noch nicht bekannt ist.
- Der Bon enthält: Logo und Daten des Betriebs, Kassen-Kennung, laufende Nummer, Datum und Uhrzeit, Zeilen mit Menge und gewählten Optionen, Pfand getrennt, Summe, Beträge pro Steuersatz, Zahlungsart, QR-Code der RKSV, Text am Bon-Ende.
- Die Geldlade wird über den Drucker geöffnet, nur bei Barzahlung und nur, wenn sie in den Einstellungen eingeschaltet ist.
- Fällt der Drucker aus, wird der Bon trotzdem gespeichert und signiert. Kassa meldet "Drucker nicht bereit" und bietet "Nochmal drucken" an. Claudes Entscheidung: Der Verkauf wird nicht gesperrt.

### 5.8 RKSV

Dieser Teil ist rechtlich bindend. Alles hier wird vor dem Bau gegen den Verordnungstext und die Unterlagen des Finanzministeriums geprüft. Bis dahin gilt es als Claudes Stand des Wissens.

- **Signatur hinter einer Schnittstelle.** Erste Umsetzung: Chipkarte im USB-Kartenleser am Tablet. Spätere Umsetzungen: Online-Dienst. Der Wechsel darf den Rest der Kassa nicht berühren.
- **Protokoll auf dem Gerät.** Jeder Bon wird sofort beim Abschließen signiert und ins Datenerfassungsprotokoll geschrieben, verkettet mit dem vorigen Bon, mit verschlüsseltem Umsatzzähler. Das geht mit der Chipkarte auch ohne Internet. Das Protokoll wird zusätzlich zum Server abgeglichen und lässt sich in der vorgeschriebenen Form ausgeben.
- **Sonderbelege:** Startbeleg, Monatsbeleg, Jahresbeleg, Nullbeleg, Schlussbeleg, Sammelbeleg nach einem Ausfall. Storno ist ein eigener Bon mit negativem Betrag. Monats- und Jahresbeleg erzeugt Kassa von selbst beim ersten Start im neuen Monat, unabhängig vom Tagesabschluss (Fristen zu prüfen).
- **Ausfall der Signatur** (Karte gezogen, Leser defekt): Kassa boniert weiter und kennzeichnet die Bons als "Sicherheitseinrichtung ausgefallen". Sobald die Signatur wieder geht, folgt der Sammelbeleg. Dauert der Ausfall länger als 48 Stunden, erinnert Kassa an die Meldung bei FinanzOnline.
- **Anmeldung bei FinanzOnline** macht in Version 1 ein Mensch (Betrieb oder Steuerberatung). Kassa zeigt dafür die nötigen Angaben an (Kassen-Kennung, Schlüssel) und druckt den Startbeleg zur Prüfung mit der Belegcheck-App des Finanzministeriums. Beim Wechsel von der alten Kassa: Schlussbeleg dort, neue Kassa anmelden, die Karte bleibt angemeldet (Aussage aus der Planung, zu prüfen).
- **Die PIN der Karte** wird einmal eingegeben und verschlüsselt auf dem Gerät gehalten.
- **Prüfung:** Die erzeugten Belege und das Protokoll werden mit dem Prüfwerkzeug und den Beispieldaten des Finanzministeriums getestet (zu prüfen, ob beides in passender Form verfügbar ist).

**Größtes technisches Risiko: die Chipkarte am Android-Tablet.** Android bringt keine Unterstützung für Kartenleser mit. Es braucht einen USB-Leser, den Kassa selbst ansteuert, und die Befehle der A-Trust-Karte. Das ist nicht belegt. Deshalb steht am Anfang von Schritt 3 ein Machbarkeitstest mit echtem Leser und echter Karte, als Wegwerf-Versuch. Scheitert er, ist der Ausweg die Online-Signatur, die dann vorgezogen wird. Dazu kommt: Karten vom Typ ACOS-ID 2.1 müssen laut WKO bis spätestens Mai 2027 getauscht werden, bei CardOS 5.3 ist es unklar. Welchen Typ der Pilotbetrieb hat, ist offen.

Der Pilotbetrieb geht erst in den echten Betrieb, wenn dieser Teil geprüft ist und der Startbeleg die Prüfung besteht.

**Weitere Betriebe.** Der Machbarkeitstest und die erste Umsetzung gelten für den Kartentyp des Pilotbetriebs. Ein zweiter Betrieb hat eine andere Karte, vielleicht einen anderen Typ, oder keine. Claudes Entscheidung: Neue Betriebe sollen über die Online-Signatur laufen, nicht über weitere Kartentypen. Deshalb muss die Online-Signatur fertig sein, bevor der zweite Betrieb echt verkauft, und sie rückt in der Reihenfolge direkt hinter Schritt 4 (siehe 6). Weil die Anfrage bei fiskaly oder A-Trust Vorlaufzeit hat und Niko sie jetzt nicht führen will, ist bei ihm erfragt, ob Claude die Anfrage als fertigen Text vorbereiten soll, damit die Wartezeit neben dem Bau läuft. Dieselbe Online-Signatur ist auch der Ausweg, falls der Machbarkeitstest scheitert oder die Karte des Pilotbetriebs 2027 getauscht werden muss.

### 5.9 Betriebe einrichten

Niko, 17.11.2026: Ein neuer Betrieb schickt Logo und Speisekarte, auf Wunsch auch Fotos, und Niko baut alles ein. für den Pilotbetrieb bleibt es, wie es ist, weil die Daten schon vorliegen.

Ablauf im Anbieter-Werkzeug:

1. **Betrieb anlegen:** Name, Adresse, UID-Nummer, Text am Bon-Ende, Zugang für den Chef.
2. **Logo hochladen.** Es erscheint am Bon (als Schwarz-Weiß-Bild), in der Kopfleiste der Kassa, am Anmeldebildschirm und auf der Kundenanzeige. Die Farben von Kassa bleiben für alle Betriebe gleich.
3. **Speisekarte einspielen.** Niko lädt die Karte als PDF oder Foto hoch. Ein KI-Dienst liest sie aus und macht einen Vorschlag: Kategorien, Artikel, Preise, Auswahl-Vorlagen, Pfand, Kennzeichen, Zusatzangaben. Niko sieht den Vorschlag als Tabelle, bessert aus und übernimmt ihn. Nichts geht ungeprüft in den Betrieb. Steuersätze schlägt das Werkzeug vor und markiert sie als "bitte prüfen".
4. **Fotos zuordnen**, falls der Betrieb welche schickt: mehrere auf einmal hochladen, das Werkzeug schlägt die Zuordnung nach Dateinamen vor, Niko bestätigt. Artikel ohne Foto zeigen den Platzhalter.
5. **Kassa koppeln:** Kopplungscode erzeugen, am Tablet eingeben. Mitarbeiter und PINs anlegen.

Das Einspiel-Format ist eine Datei mit Kategorien, Artikeln und Auswahl-Vorlagen. Es ist dasselbe Format, in dem die Karte des Pilotbetriebs schon vorliegt (78 Artikel, 9 Kategorien, die Bowl-Auswahl als Vorlage). Der Pilotbetrieb wird in Schritt 2 über genau dieses Format eingerichtet. Die Datei liegt nicht im Repo, solange nicht geklärt ist, ob das Repo öffentlich ist. Sie liegt in den Projektdateien unter `/mnt/project-files/pilot/speisekarte-pilotbetrieb.json`, daneben die Karte als PDF. Das Format selbst steht im Anhang A.

Der KI-Vorschlag und die Oberfläche dazu kommen in Schritt 4. Bis dahin erstellt Claude die Datei für einen Betrieb von Hand, so wie für den Pilotbetrieb.

### 5.10 Verwaltung im Browser

Für den Chef des Betriebs: Artikel, Kategorien, Auswahl-Vorlagen, Preise und Fotos pflegen, Mitarbeiter und PINs, Umsätze und Tagesabschlüsse ansehen, Protokoll der RKSV ausgeben, Kassen koppeln. Hier darf getippt werden. Gleicher Stil wie die App. Die Bildschirme dafür sind noch nicht entworfen und kommen vor dem Bau in Schritt 4 als eigener Entwurf zu Niko.

Claudes Entscheidung für die Zeit davor: In Schritt 2 und 3 gibt es nur eine schlichte Anbieter-Seite ohne eigenen Entwurf, die nur Niko und Claude benutzen. Sie kann: anmelden, Betrieb anlegen, Speisekarten-Datei einspielen, Mitarbeiter und PINs anlegen, Kopplungscode erzeugen. Der Chef des Pilotbetriebs ändert im Pilotbetrieb Preise, Favoriten und "Im Verkauf" am Tablet. Neue Artikel, Namen und Fotos spielt bis Schritt 4 Niko oder Claude über die Datei ein.

### 5.11 Gestaltung

- Stil von Niko über Beispielbilder vorgegeben: hell, viel Weißraum, weiche weiße Karten mit runden Ecken, eine Akzentfarbe, Produktfotos auf den Tasten. Akzentfarbe Petrol (#0F766E), Schrift Figtree (Claudes Wahl, Niko: "Farbe ist mir egal, es soll einfach angenehm zum Ansehen sein").
- Der Entwurf ist die Vorlage für Maße, Farben und Zustände. Zu Beginn von Schritt 2 wird daraus `DESIGN.md` geschrieben.
- Alles für Touch: Tippflächen mindestens 48 dp, Hauptaktionen 64 bis 80 dp hoch. Zahlen in gleich breiten Ziffern, wo sie untereinander stehen.
- Helle und dunkle Ansicht. Bewegung kurz (120 bis 320 ms), nur um Zustände zu zeigen, und abschaltbar über die Systemeinstellung.
- Der Entwurf ist für 1280 × 800 gezeichnet. Die App muss sich an Tablets von 10 bis 13 Zoll anpassen: Die Spalten für Kategorien und Bon bleiben fest, die Artikelfläche bekommt mehr oder weniger Spalten.
- Nikos zwei Regel-Listen gelten für jede Oberfläche: die erste mit Animations-Grundsätzen und Bedien-Gesetzen, die zweite mit technischen Bedien-Regeln. Sie stehen im Wortlaut in `docs/design-regeln.md`, samt Claudes Einordnung, welche Regel wo greift.

### 5.12 Technik

Claudes Entscheidungen, weil Niko die Technik abgegeben hat:

- **App:** Flutter. Datenbank auf dem Gerät: SQLite. Anbindung von SumUp, USB-Drucker und Kartenleser über kleine Kotlin-Teile. Netzwerk- und Bluetooth-Druck direkt aus Dart, soweit möglich.
- **Server:** TypeScript auf Node, Datenbank PostgreSQL, Ablage für Logos und Fotos. Betrieb bei Railway, das in Nikos Konto schon verbunden ist. Kosten dafür sind nicht geprüft.
- **Browser-Verwaltung und Anbieter-Werkzeug:** eine Web-Anwendung in TypeScript mit React, zwei Rollen.
- **Ein Repo** mit drei Ordnern: App, Server, Web.
- Trennung der Betriebe: Jede Tabelle trägt den Betrieb, jede Abfrage ist darauf beschränkt, und das wird mit Tests abgesichert.

### 5.13 Sicherheit und Datenschutz

- Anmeldung im Browser mit E-Mail und Passwort. Tablets tragen nach der Kopplung ein eigenes Geräte-Kennzeichen, das sich in der Verwaltung sperren lässt.
- PINs werden nie im Klartext gespeichert. Die PIN der Signaturkarte und die Schlüssel der RKSV liegen im geschützten Speicher von Android.
- Kassa speichert keine Kartendaten. Die Zahlung läuft vollständig bei SumUp.
- Daten liegen in der EU. Welche Verträge Niko als Anbieter mit seinen Betrieben braucht (Auftragsverarbeitung), ist rechtlich zu klären und nicht Teil dieses Entwurfs.

### 5.14 Tests

- Gebaut wird testgetrieben: erst der Test, dann der Code.
- Rechenkern mit vielen Tests: Preise, Auswahl-Vorlagen, Pfand, Steuer pro Satz, Rückgeld, Storno, Tagesabschluss.
- RKSV gegen die Beispieldaten und das Prüfwerkzeug des Finanzministeriums.
- Abgleich: derselbe Bon mehrfach gesendet, Abbruch mitten im Senden, lange ohne Internet.
- Geräte hinter Schnittstellen mit Attrappen für Drucker, Kartenterminal und Signatur, damit alles ohne Hardware testbar ist.
- Bildvergleich der Hauptbildschirme in hell und dunkel und in zwei Tabletgrößen.
- Vor jeder Freigabe eine Prüfliste an echter Hardware: bar, Karte, Druck, Lade, ohne Internet, Karte gezogen, Drucker aus.

**Wer an der Hardware testet** (Claudes Entscheidung). Claude baut und testet in der Cloud mit Attrappen und hat kein Gerät in der Hand. An echter Hardware testet nur Niko. Daraus folgt:
- Jede Version kommt als Installationsdatei über einen Link aufs Tablet, mit einer Anleitung in wenigen Schritten. Vor dem Pilotbetrieb wechselt das auf den internen Test im Google Play Store, damit Updates von selbst kommen. Dafür braucht es ein Entwicklerkonto bei Google auf Nikos Namen (siehe 8).
- Die Seite "Geräte testen" in den Einstellungen prüft Drucker, Geldlade, Kartenleser und Kartenterminal einzeln und zeigt in einfachen Worten, was geht und was nicht.
- Die App schickt Fehlerberichte und das Ergebnis von "Geräte testen" an den Server, damit Claude sie lesen kann, ohne dass Niko etwas abtippen muss. Darin stehen keine Kundendaten und keine Kartendaten.
- Jeder Versuch an Hardware, auch der Machbarkeitstest für die Chipkarte, kommt mit einer Prüfliste zum Abhaken für Niko.

## 6. Reihenfolge

Jeder Schritt endet mit etwas, das Niko am Tablet ausprobieren kann.

1. **Entwurf festlegen.** Dieses Dokument. Danach der Umsetzungsplan.
2. **Imbiss-Modus.** App auf dem Android-Tablet mit Betriebskonto: Der Pilotbetrieb aus der vorhandenen Datei eingerichtet, Bonieren mit Auswahl und Pfand, Bar, Bondruck und Geldlade, Bons, Übersicht, Artikel, Abschluss, Einstellungen, ohne Internet. Dazu Server und die schlichte Anbieter-Seite (siehe 5.10). Am Anfang stehen `DESIGN.md` und die im Entwurf noch fehlenden Bildschirme (Anmeldung mit PIN, Kopplung, Bargeld einlegen und entnehmen, Pfand zurück, Geräte testen), die Niko vor dem Bau sieht. Noch ohne Karte und ohne Signatur, deshalb nur zum Testen.
3. **Karte und RKSV.** Zuerst der Machbarkeitstest für die Chipkarte. Dann SumUp, Signatur, Protokoll, Sonderbelege, QR-Code. Am Ende: Betrieb beim Pilotkunden.
4. **Betriebe einrichten.** Anbieter-Werkzeug mit Logo, Speisekarte über KI-Vorschlag, Fotos. Vollständige Browser-Verwaltung. Kundenanzeige.
5. **Restaurant-Modus.** Tische, Kellner, Stationen. Bekommt einen eigenen Entwurf.

Danach, jeweils mit eigenem Entwurf: zuerst die Online-Signatur, weil ohne sie kein zweiter Betrieb echt verkaufen kann (siehe 5.8). Dann iPad und Windows, Hardware-Komplettpaket, Selbstanmeldung, Abo-Abrechnung. Der Restaurant-Modus und die Online-Signatur können die Plätze tauschen, je nachdem, ob zuerst ein zweiter Imbiss oder ein Restaurant als Kunde kommt.

Gegenüber dem ersten Plan mit vier Schritten ist "Betriebe einrichten" als eigener Schritt dazugekommen, weil Niko es am 17.11.2026 verlangt hat.

## 7. Dem Bau überlassen

Diese Dinge entscheidet, wer den Umsetzungsplan schreibt und baut, ohne Rückfrage bei Niko:

- Aufteilung des Codes, Namen, Bibliotheken innerhalb der gewählten Technik (zum Beispiel für Zustände, Datenbankzugriff, Druck).
- Genaue Form der Schnittstelle zwischen App und Server und des Abgleichs.
- Genaue Tabellen und Felder über 5.4 hinaus.
- Aufbau des gedruckten Bons im Detail, solange die Pflichtangaben stehen.
- Wahl des KI-Modells für das Auslesen der Speisekarte und die Form des Auftrags an die KI.
- Reihenfolge der Arbeit innerhalb eines Schritts.

## 8. Offene Punkte

**Braucht Niko oder den Betrieb**

1. Typ oder Kaufjahr der RKSV-Chipkarte des Pilotbetriebs und Modell des Kartenlesers (Foto). Entscheidet, ob die Karte bleiben darf und ob der Leser am Tablet geht.
2. Modell des Bondruckers des Pilotbetriebs. Entscheidet, ob er bleiben kann.
3. Eine eigene Karte und ein Kartenleser zum Testen. Mit der echten Karte des Pilotbetriebs darf nicht getestet werden, solange dort die alte Kassa läuft. Ob A-Trust Testkarten anbietet, ist zu prüfen.
4. Zugang zu einem SumUp-Konto für Entwickler und ein SumUp-Gerät zum Testen.
5. Betriebsdaten des Pilotbetriebs für den Bon: genauer Name, Adresse, UID-Nummer. Steuersätze der Artikel bestätigen.
6. Wer meldet die Kassa bei FinanzOnline an, der Betrieb oder die Steuerberatung?
7. Ist das Repo öffentlich oder privat? Davon hängt ab, ob Beispieldaten von Betrieben hinein dürfen.
8. Soll Claude die Anfrage an fiskaly (und A-Trust) jetzt als fertigen Text vorbereiten, damit die Wartezeit neben dem Bau läuft?
9. Wie kommt die Bestellung beim Pilotbetrieb heute in die Küche: Zettel aus dem Drucker, Zuruf, Nummer am Bon?
10. Nimmt der Pilotbetrieb Pfand-Leergut zurück und zahlt Pfand aus? Werden Getränke zum Trinken im Lokal ohne Pfand verkauft?
11. Ein Entwicklerkonto bei Google Play auf Nikos Namen. Erst vor dem Pilotbetrieb nötig.

**Klärt Claude vor dem Bau des jeweiligen Schritts**

12. RKSV im Wortlaut: Pflichtangaben am Bon, Form des Protokolls, Sonderbelege, Fristen, Bargeld-Bewegungen. Prüfwerkzeug und Beispieldaten.
13. Ansteuerung der A-Trust-Karte und passende Kartenleser für Android (Machbarkeitstest).
14. Steuerliche Behandlung des Einwegpfands am Bon und im Protokoll, Pflicht zur Rücknahme von Leergut und ihre Ausnahmen.
15. SumUp Reader SDK: Anmeldung, Abfrage einer Zahlung nach Absturz, Rückbuchung, Anpassung des Zahlungsbildschirms, welche SumUp-Geräte außer dem Air das SDK ansteuert.
16. Ob das Redmi Pad Pro am USB-Verteiler gleichzeitig lädt und Geräte erkennt.
17. Kosten des Servers bei Railway.

## 9. Claudes Entscheidungen zum Gegenprüfen

- Technik: Flutter für die App, TypeScript mit PostgreSQL für den Server, React für den Browser, Betrieb bei Railway.
- Rollen: Chef-Rolle für Übersicht, Artikel, Abschluss, Einstellungen. Storno in der Voreinstellung für alle.
- Drucker-Ausfall sperrt den Verkauf nicht.
- Anmeldung bei FinanzOnline in Version 1 von Hand.
- Logo pro Betrieb ja, eigene Farben pro Betrieb nein.
- Der KI-Vorschlag für die Speisekarte kommt erst in Schritt 4, der Pilotbetrieb wird aus der vorhandenen Datei eingerichtet.
- Kundenanzeige kommt in Schritt 4, nach dem Pilotbetrieb.
- Die Chipkarte wird als Wegwerf-Versuch geprüft, bevor der Rest der RKSV gebaut wird.

Nach dem Gegenlesen durch einen zweiten Prüfer am 17.11.2026 dazugekommen:

- Neue Betriebe laufen über die Online-Signatur, nicht über weitere Kartentypen. Sie rückt direkt hinter Schritt 4.
- Bargeld: Wechselgeld ist, was beim Abschluss in der Lade bleibt. Einlegen und Entnehmen während des Tages. Ein Tag endet mit dem Abschluss, nicht um Mitternacht. Ein vergessener Abschluss sperrt nichts.
- "Pfand zurück" als Minus-Zeile ist in Version 1.
- Optionen können einen eigenen Steuersatz und eigenes Pfand tragen. Fixpreis-Menüs über zwei Steuersätze kommen später.
- Kundenanzeige in Schritt 4 als zweites Android-Gerät über das WLAN im Lokal. Eingebauter zweiter Bildschirm erst mit dem Hardware-Paket.
- An echter Hardware testet Niko, mit Installationsdatei per Link, der Seite "Geräte testen", Fehlerberichten an den Server und Prüflisten.
- Bis Schritt 4 gibt es nur eine schlichte Anbieter-Seite ohne eigenen Entwurf. Die Verwaltung für den Chef kommt in Schritt 4 nach eigenem Entwurf.
- Die Freigabe dieses Dokuments gilt auch für die Bereiche Bons, Übersicht, Artikel, Abschluss und Einstellungen, wie sie im Entwurf stehen.

## Anhang A: Einspiel-Format der Speisekarte

Eine JSON-Datei pro Betrieb. Beträge in Cent, Preise brutto. Das Beispiel ist erfunden und zeigt jede Angabe einmal.

```json
{
  "betrieb": "Beispiel-Imbiss",
  "quelle": "Speisekarte.pdf, erhalten am 2026-11-17",
  "hinweise": ["Steuersätze sind eine Annahme und zu prüfen."],
  "kategorien": [
    { "id": "bowls", "name": "Bowls" },
    { "id": "getraenke", "name": "Getränke" }
  ],
  "artikel": [
    { "id": "huhn-bowl", "name": "Huhn Bowl", "preis_cent": 990, "kategorie": "bowls", "mwst": 10, "auswahl": "bowl", "kennzeichen": "SCHARF" },
    { "id": "teigtaschen", "name": "Teigtaschen", "preis_cent": 650, "kategorie": "bowls", "mwst": 10, "info": "5 Stück", "kennzeichen": "VEGAN" },
    { "id": "cola", "name": "Cola 0,33 l", "preis_cent": 290, "kategorie": "getraenke", "mwst": 20, "pfand_cent": 25 }
  ],
  "auswahlgruppen": {
    "bowl": [
      { "name": "Größe", "min": 1, "max": 1, "optionen": [
        { "name": "Normal", "aufpreis_cent": 0, "vorgabe": true },
        { "name": "XXL", "aufpreis_cent": 200 }
      ] },
      { "name": "Extra-Sauce", "min": 0, "max": null, "optionen": [
        { "name": "Teriyaki", "aufpreis_cent": 50 }
      ] }
    ]
  }
}
```

- `kategorien`: Reihenfolge in der Datei ist die Reihenfolge in der Kassa.
- `artikel`: Pflicht sind `id`, `name`, `preis_cent`, `kategorie`, `mwst`. Freiwillig sind `info` (Zusatzangabe beim Preis), `pfand_cent`, `kennzeichen` (ein Wort wie VEGAN oder SCHARF) und `auswahl` (Name einer Auswahl-Vorlage).
- `auswahlgruppen`: pro Vorlage eine Liste von Gruppen. `min` und `max` sagen, wie viele Optionen gewählt werden müssen und dürfen, `max: null` heißt ohne Grenze. `vorgabe: true` ist schon gewählt.
- Favoriten und Fotos stehen nicht in der Datei. Sie werden danach gesetzt.
- Kommt für Schritt 4 dazu, sobald es gebraucht wird: eigener Steuersatz und eigenes Pfand pro Option.
