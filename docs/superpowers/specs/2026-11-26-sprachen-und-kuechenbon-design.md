# Kassa: Sprachen und Küchenbon

Stand: 26.11.2026. Entwurf von Claude, von einem zweiten Prüfer gegengelesen, von Niko am 26.11.2026 freigegeben ("Passt, so bauen"). Bilder der Bildschirme und Zettel zum Antippen: https://claude.ai/artifact/6bgRKBY6A8dJEYL6QUVbnz , Quelle im Repo unter `docs/superpowers/specs/bilder/2026-11-26-sprachen-entwurf.html` (Betrieb, Artikel und Preise sind erfunden). Die Bilder zeigen, was Niko freigibt: Aufbau des Küchenbons, die Abschnitte Sprache und Küche in den Einstellungen, die Sprachtaste bei der Anmeldung, die Seite Übersetzungen. Wo Bild und Text sich widersprechen, gilt der Text; Farben, Abstände und Tasten folgen `DESIGN.md`.

Dieses Dokument ergänzt den Gesamtentwurf (`2026-11-17-kassa-design.md`). Dort stehen "andere Sprachen als Deutsch" und "Küchenzettel" unter den Nicht-Zielen der Version 1; beides hebt dieses Dokument auf. Wo sich die Dokumente widersprechen, gilt für dieses Thema dieses. Alles, was hier nicht steht, gilt weiter wie dort, in `PRODUCT.md`, `DESIGN.md` und `docs/design-regeln.md`.

## 1. Worum es geht

Niko am 26.11.2026: "man soll sprachen in der kassa einstellen können. chinesisch deutsch englisch türkisch arabisch und man soll auch einstellen können zb ich boniere auf deutsch und der küchenbon ist aber türkisch".

Was der Code von 1.9.0 heute tut:

- Alle Texte der App sind fest auf Deutsch eingebaut (rund 1.100 verschiedene Texte in 22.600 Zeilen Oberfläche). Es gibt keine Sprachwahl und keinen Aufbau von rechts nach links.
- Die Kassa druckt keinen Küchenbon. Der Gesamtentwurf hat ihn weggelassen, weil die Küche bei YICHI über Nikos Bestellanzeige läuft.
- Artikel, Kategorien und Extras haben genau einen Namen. Der steht auf der Taste, am Bon am Bildschirm und am gedruckten Bon.
- Der Bondrucker bekommt Text im Zeichensatz PC858. Türkische Buchstaben verlieren ihre Zeichen (ş wird s, ğ wird g), chinesische und arabische Schrift wird zu Fragezeichen.

Niko hat am 26.11.2026 auf der Karte "Wo soll der Küchenbon herauskommen?" **"Beides wählbar"** gewählt: pro Kassa einstellbar, am Bondrucker der Kassa oder an einem eigenen Drucker in der Küche.

**Erfolg heißt:** Eine Bedienung, die kein Deutsch liest, tippt am Anmeldebildschirm auf die Sprachtaste, wählt 中文, und die Kassa spricht Chinesisch, samt den Namen auf den Artikeltasten. Niko stellt in den Einstellungen "Küchenbon: Türkisch" ein. Vorne wird auf Deutsch boniert, der Kunde bekommt seinen Bon wie bisher auf Deutsch mit Signatur, und in der Küche kommt ein Zettel mit großer Schrift auf Türkisch heraus. Stellt er Arabisch ein, steht die ganze Kassa von rechts nach links, und der Küchenbon zeigt richtige arabische Schrift.

## 2. Ziele, Nicht-Ziele, Anti-Ziele

**Ziele**

- **Bediensprache** der Kassa wählbar: Deutsch, Englisch, Chinesisch (vereinfachte Schrift), Türkisch, Arabisch. Wechsel ohne Neustart, in den Einstellungen und am Anmeldebildschirm.
- **Arabisch von rechts nach links:** der ganze Aufbau spiegelt sich (Kategorien rechts, Bon links), Zahlen und Preise bleiben, wie sie sind.
- **Übersetzungen der Speisekarte:** Jeder Name der Speisekarte (Kategorie, Artikel, Zusatzangabe, Auswahlgruppe, Option) kann in jeder der vier anderen Sprachen einen übersetzten Namen haben. Gepflegt in der Verwaltung im Browser und über die Speisekarten-Datei. Fehlt eine Übersetzung, steht der Name aus der Speisekarte da.
- **Küchenbon,** neu: Nach jedem Verkauf kommt ein Zettel für die Küche heraus, in einer eigenen, von der Bediensprache getrennten Sprache. Pro Kassa einstellbar: aus, am Bondrucker der Kassa, an einem eigenen Drucker in der Küche.
- Der Küchenbon zeigt jede der fünf Schriften richtig, auf jedem Bondrucker.

**Nicht-Ziele** (bewusst später oder gar nicht)

- **Der Kundenbon in einer anderen Sprache.** Er bleibt Deutsch, mit den Namen aus der Speisekarte. Dasselbe gilt für Tagesabschluss, Monatsabrechnung, Sonderbelege, den Zettel "Angaben für FinanzOnline" und den Testdruck.
- **Die Einrichtung in anderen Sprachen.** Deutsch bleiben vorerst: Ersteinrichtung und Koppeln, alles zur Signatur (RKSV), Kartenterminal einrichten, Drucker einrichten, Geräte testen, Verbindung prüfen, Protokoll exportieren. Das sind die Schritte, die Niko beim Einrichten macht, und die Bildschirme der Signatur gehören einem anderen Thread, der noch daran arbeitet. Eine spätere Stufe kann sie nachziehen.
- **Die Verwaltung im Browser in anderen Sprachen.** Sie bleibt Deutsch.
- **Automatische Übersetzung** der Speisekarte auf Knopfdruck. Bräuchte einen bezahlten Übersetzungsdienst am Server. Für YICHI und weitere Betriebe kann Claude die Übersetzungen als Datei vorbereiten.
- **Sprache pro Mitarbeiter,** die sich beim Anmelden von selbst umstellt. Die Sprache gilt für die Kassa; wer eine andere braucht, wechselt am Anmeldebildschirm mit zwei Tipps.
- Weitere Sprachen, traditionelles Chinesisch, arabische Ziffern (٠١٢٣).
- Küche: Anbindung an Nikos Bestellanzeige, Gänge, "Bestellung fertig", mehrere Küchendrucker nach Station (Küche, Bar, Grill), Tischnummern.
- Kundenanzeige in anderen Sprachen (es gibt sie noch nicht).

**Anti-Ziele**

- Am Kundenbon, an den Berichten und an der Signatur ändert sich nichts. Der Ordner `app/lib/rksv/` wird nicht angefasst. Der Küchenbon ist kein Beleg: keine Bon-Nummer aus eigener Zählung, kein Eintrag im Protokoll, kein QR-Code, kein Preis.
- Der Verkauf wartet nie auf den Küchenbon und scheitert nie an ihm.
- Niemand bleibt in einer Sprache stecken, die er nicht lesen kann: Die Sprachtaste ist am Anmeldebildschirm immer da, mit einem Zeichen, das ohne Lesen verständlich ist, und jede Sprache steht in ihrer eigenen Schrift da.
- Nie ein leerer Name und nie ein Fragezeichen statt eines Namens, weder am Bildschirm noch am Küchenbon.
- Am Tablet wird weiterhin nichts getippt. Übersetzungen tippt man im Browser.
- Ein Bildschirm, der in einer Sprache überläuft oder abgeschnittene Tasten zeigt.

## 3. Rahmenbedingungen

- **Stand der App:** 1.9.0 Build 11 (Monatsabrechnung) ist ausgerollt und wartet auf Nikos Test. Diese Arbeit baut darauf auf, auf dem Zweig `claude/project-thread-0rpvma` (`main` gibt es im Repo nicht), und wird **1.10.0 Build 12, Datenbank am Tablet Version 7**. Jede Änderung an der Datenbank braucht eine Migration mit Test.
- **Andere Threads:** Die Signatur (Zweig `claude/project-thread-xtooco`) und die Website (`claude/project-thread-oz4h7z`) laufen daneben. Das Herausziehen der Texte berührt viele Dateien der Oberfläche. Die Bildschirme der Signatur bleiben darum unberührt (siehe Nicht-Ziele); wer später fertig wird, führt zusammen.
- **Der Server läuft** bei Railway und ist auf einen Commit festgelegt. Die Übersetzungen brauchen eine neue Tabelle am Server (Migration `0003`). Ausrollen und Hochladen der Installationsdatei erst nach Nikos Ja.
- **Alte Tablets:** Ein Tablet mit 1.9.0 muss mit dem neuen Server weiter abgleichen können. Es überliest, was es nicht kennt (geprüft: `PullResponse.fromJson` liest nur die bekannten Schlüssel).
- **Das Repo ist öffentlich.** Beispiele sind erfunden; die Speisekarte von YICHI darf im Repo stehen.
- **Kein Tablet, kein Bondrucker und niemand, der Chinesisch, Türkisch oder Arabisch als Muttersprache liest,** in der Bau-Umgebung. Die Übersetzungen der Oberfläche schreibt Claude. Was nur am echten Gerät oder von einem Muttersprachler zu prüfen ist, kommt in eine Prüfliste für Niko (`docs/testen/sprachen-pruefliste.md`), dazu je Sprache eine Liste aller Texte zum Gegenlesen.
- **Geprüft am 26.11.2026 (Versuch in der Bau-Umgebung):** Flutter zeichnet türkischen, chinesischen und arabischen Text (mit richtiger Verbindung der Buchstaben und Leserichtung) in ein Bild, das sich in ein Schwarz-Weiß-Raster für den Drucker umsetzen lässt. Die Schrift Figtree der App enthält alle türkischen Buchstaben. Den Rasterdruck (`GS v 0`) nutzt die App schon für den QR-Code.
- **Recht, soweit geprüft:** Die RKSV regelt den Beleg für den Kunden. Ein Zettel für die Küche ohne Preise ist kein Beleg. Das ist keine Rechtsauskunft.

## 4. Wege, die zur Wahl standen

**Wie der Küchenbon fremde Schriften druckt**

| | Weg | Urteil |
|---|---|---|
| **1** | **Den ganzen Küchenbon als Bild drucken.** Die App zeichnet den Zettel selbst und schickt ihn als Raster. | **Gewählt.** Geht mit jedem Bondrucker, der ein Bild druckt, in jeder Schrift, auch Arabisch mit verbundenen Buchstaben von rechts nach links. Was die Vorschau in den Einstellungen zeigt, kommt genau so heraus. Große, gut lesbare Schrift. Preis: mehr Daten je Zettel, über Bluetooth etwas langsamer. |
| 2 | Zeichensätze des Druckers umschalten (PC857 für Türkisch, GB18030 für Chinesisch, PC864 für Arabisch) | Hängt am Modell: viele günstige Drucker haben keine chinesische oder arabische Schrift eingebaut, und Arabisch müsste die App selbst in verbundene Formen umrechnen. Nicht prüfbar ohne den Drucker jedes Betriebs. |
| 3 | Text für Deutsch und Englisch, Bild für den Rest | Zwei Zettel-Aufbauten zu pflegen und zu prüfen, und der Küchenbon sähe je nach Sprache anders aus. |

**Woher die übersetzten Namen der Speisekarte kommen**

| | Weg | Urteil |
|---|---|---|
| **1** | **Ein Wörterbuch pro Betrieb:** Name aus der Speisekarte, dazu die Übersetzung je Sprache. | **Gewählt.** "Avocado" wird einmal übersetzt, auch wenn es in mehreren Auswahlgruppen steht. Übersetzungen überleben das neue Einspielen der Speisekarte, solange der Name gleich bleibt (die Kennungen der Optionen ändern sich beim Einspielen, die Namen nicht). Der Küchenbon lässt sich auch für einen alten Bon nachdrucken, weil der Bon die Namen trägt. Preis: Ein Wort mit zwei Bedeutungen bekommt nur eine Übersetzung. |
| 2 | Übersetzungen als Felder an jedem Artikel, jeder Kategorie, jeder Option | Vier neue Felder an fünf Arten von Einträgen, an Server und Tablet, im Abgleich und beim Einspielen. Die Optionen einer Vorlage werden beim Einspielen neu geschrieben, ihre Übersetzungen gingen dabei verloren oder müssten umständlich gerettet werden. |
| 3 | Eine eigene Speisekarte je Sprache | Fünf Karten, die bei jeder Preisänderung auseinanderlaufen. |
| 4 | Beim Drucken automatisch übersetzen | Braucht Internet und einen bezahlten Dienst, und niemand sieht vorher, was in der Küche ankommt. |

**Wie die Texte der Oberfläche in die App kommen**

| | Weg | Urteil |
|---|---|---|
| **1** | **Flutters eigenes Werkzeug (`gen-l10n`): eine Datei je Sprache (`app_de.arb` usw.)** | **Gewählt.** Der übliche Weg. Mehrzahl-Formen je Sprache (Arabisch hat sechs), Platzhalter mit Typ, und das Werkzeug meldet jeden Text, der in einer Sprache fehlt. Die Dateien kann man einem Muttersprachler zum Gegenlesen geben. |
| 2 | Eigene Dart-Klassen je Sprache | Fehlende Texte fallen schon beim Übersetzen des Programms auf, aber Mehrzahl-Regeln und das Format zum Weitergeben müsste man selbst bauen. |
| 3 | Texte vom Server laden | Die Kassa muss ohne Internet in jeder Sprache laufen. |

**Wo die Sprache gilt**

| | Weg | Urteil |
|---|---|---|
| **1** | **Pro Kassa, umschaltbar in den Einstellungen und am Anmeldebildschirm** | **Gewählt.** Niko: "sprachen in der kassa einstellen". Ein Wert, kein Abgleich mit dem Server nötig. Wechsel der Schicht: zwei Tipps. |
| 2 | Pro Mitarbeiter, stellt sich beim Anmelden um | Schöner für gemischte Teams, braucht aber ein Feld am Mitarbeiter in Tablet, Server und Verwaltung. Kann später dazukommen, ohne dass sich Weg 1 ändert. |
| 3 | Wie das Tablet eingestellt ist | Niemand am Stand findet die Android-Einstellungen, und Kassa und Tablet sollen nicht voneinander abhängen. |

## 5. Der Entwurf

### 5.1 Sprachen

| Kürzel | Steht in der Auswahl als | Richtung |
|---|---|---|
| `de` | Deutsch | links nach rechts |
| `en` | English | links nach rechts |
| `zh` | 中文 | links nach rechts |
| `tr` | Türkçe | links nach rechts |
| `ar` | العربية | rechts nach links |

Die Auswahl zeigt jede Sprache immer in ihrer eigenen Schrift, gleich welche Sprache gerade gilt. Neu installiert ist die Kassa Deutsch, auch nach dem Update.

### 5.2 Bediensprache am Tablet

**Einstellen.** In den Einstellungen steht als erster Abschnitt **Sprache** mit fünf großen Tasten nebeneinander (mindestens 64 px hoch, die gewählte in Petrol). Ein Tipp stellt sofort um, ohne Rückfrage und ohne Neustart; der Wechsel ist selbst die Bestätigung. Am Anmeldebildschirm (PIN) steht oben in der Ecke eine Taste mit Weltkugel und dem Namen der jetzigen Sprache; sie öffnet dieselben fünf Tasten als Blatt von unten. Die Sprache ist eine Einstellung der Kassa und bleibt über Abmelden und Neustart.

**Was übersetzt wird:** alles, was die Bedienung im Alltag sieht: Anmeldung, Kopfleiste und Reiter, Kassa (Kategorien, Artikeltasten, Auswahl und Extras, Bon, Bar mit Rückgeld, Karte samt Wartezustand und Fehlern, "Verkauf fertig", Hinweise und Rückgängig-Meldungen, Hinweis zur ausgefallenen Signatur: übersetzt werden Überschrift, Tasten und ein neuer fester Satz, der sagt, dass die Kassa weiterläuft und der Chef Bescheid wissen muss; der Satz mit dem genauen Grund kommt aus `app/lib/rksv/`, bleibt Deutsch und wird weiter wörtlich verglichen), Bons (Liste, Bon am Bildschirm in seinen Rahmentexten, Storno-Rückfrage), Übersicht, Artikel, Abschluss (Tag und Monat, Geldlade zählen, Einlage und Entnahme), die Hauptseite der Einstellungen und die Meldungen des Druckers. Deutsch bleibt, was in den Nicht-Zielen steht.

**Namen der Speisekarte am Bildschirm.** Kategorien, Artikeltasten, Zusatzangaben ("5 Stück"), Auswahlgruppen, Optionen und die Zeilen im offenen Bon zeigen den Namen in der Bediensprache, wenn das Wörterbuch (5.4) einen hat, sonst den Namen aus der Speisekarte. Die Kennzeichen VEGAN und SCHARF sind Texte der App und werden mit übersetzt. Im Bereich Bons steht ein gespeicherter Bon mit den Namen, mit denen er gedruckt wurde.

**Zahlen, Geld, Datum.** In jeder Sprache gleich und wie am Bon: Beträge als "12,90 €" mit Komma, Datum als 26.11.2026, Uhrzeit 14:32, Ziffern 0 bis 9. Monatsnamen und Wochentage werden übersetzt.

**Arabisch.** Die App stellt die Leserichtung um: Kategorien rechts, Artikel in der Mitte, Bon links; Text rechtsbündig; Pfeile und "Zurück" gespiegelt; Wischen zum Schließen in die andere Richtung. Nicht gespiegelt werden: Ziffernfelder (1 2 3 bleibt links oben), Beträge, Uhrzeiten, das Diagramm der Übersicht (Zeit läuft weiter von links nach rechts), Fotos und Logos. Dafür werden alle festen "links"/"rechts" im Aufbau (rund 180 Stellen) auf "Anfang"/"Ende" umgestellt. Ein Name aus der Speisekarte in lateinischer Schrift steht in einer arabischen Zeile richtig herum (Flutter ordnet gemischte Richtungen).

**Schrift.** Deutsch, Englisch und Türkisch in Figtree wie bisher. Für Chinesisch und Arabisch bringt die App je eine Schrift in zwei Stärken mit (Noto Sans SC mit den rund 7.900 gebräuchlichen Zeichen der vereinfachten Schrift, gemessen 2,5 MB je Stärke; Noto Sans Arabic, 0,15 MB je Stärke; zusammen rund 5,5 MB, die Installationsdatei wächst von 24 auf etwa 30 MB), damit Bildschirm und Küchenbon auf jedem Gerät gleich aussehen, auch auf günstigen Kassengeräten ohne vollständige Schriften. Die Größe ist eine Schätzung, keine Grenze. Ein seltenes Zeichen, das der mitgelieferten Schrift fehlt, zeichnet Flutter mit der Schrift des Geräts; so bleibt auch eine frei getippte Übersetzung ohne Fragezeichen.

**Länge der Texte.** Türkische und englische Texte sind oft länger als deutsche, chinesische kürzer und höher. Tasten und Zeilen dürfen umbrechen oder die Schrift um eine Stufe verkleinern, aber nie abschneiden. Ein Test zeichnet die Hauptbildschirme in allen fünf Sprachen bei 1280×800 und scheitert, wenn etwas überläuft.

### 5.3 Küchenbon

**Einstellen** (Einstellungen, neuer Abschnitt **Küche**):

- **Küchenbon:** Aus, Am Bondrucker, Am Küchendrucker (drei Segmente, neu installiert: Aus).
- **Sprache am Küchenbon:** dieselben fünf Tasten wie bei der Bediensprache, unabhängig von ihr (neu: Deutsch).
- **Küchendrucker** (nur bei "Am Küchendrucker"): Zeile wie beim Bondrucker, öffnet dieselbe Seite zum Suchen und Wählen (Netzwerk, USB, Bluetooth, Papierbreite). Bondrucker und Küchendrucker sind zwei getrennte Geräte.
- **Kategorien für die Küche:** eine Zeile je Kategorie mit Schalter (neu: alle an). Getränke schaltet man ab. Hat ein Verkauf keinen Artikel aus einer Kategorie für die Küche, kommt kein Küchenbon.
- **Vorschau:** das Bild eines Beispiel-Küchenbons in der gewählten Sprache, mit drei Artikeln der eigenen Speisekarte. **Probe drucken** schickt genau dieses Bild an den gewählten Drucker.

Alle fünf sind Einstellungen der Kassa am Tablet und gehen nicht zum Server.

**Wann er kommt.** Nach jedem abgeschlossenen Verkauf (bar oder Karte), sobald der Bon gespeichert ist:

- *Am Bondrucker:* zuerst der Kundenbon (mit Geldlade wie bisher), dann ein Schnitt, dann der Küchenbon, dann ein Schnitt.
- *Am Küchendrucker:* Kundenbon und Küchenbon gehen gleichzeitig an ihre Drucker.
- Nach einem Storno kommt ein Küchenbon mit der Überschrift STORNO und den Zeilen des stornierten Bons.
- Sonderbelege (Start, Monat, Jahr, Null) erzeugen keinen Küchenbon.

**Wenn er nicht kommt.** Der Verkauf ist da schon fertig. "Verkauf fertig" zeigt dann die Zeile "Küchenbon nicht gedruckt" mit dem Grund in den Worten des Druckers und der Taste **Küchenbon drucken**. Im Bereich Bons hat jeder Verkauf des offenen Tages dieselbe Taste (druckt noch einmal, mit dem Vermerk KOPIE). Ist als Ort "Am Küchendrucker" gewählt, aber keiner eingerichtet, steht das als Hinweis in den Einstellungen, und die Kassa druckt keinen Küchenbon.

**Was darauf steht** (von oben nach unten, bei Arabisch gespiegelt):

```
MUTFAK                        128      Überschrift "Küche" in der Küchensprache, Bon-Nummer groß
26.11.2026  14:32  ·  Ayşe             Datum, Uhrzeit, Bedienung
────────────────────────────────
2 ×  Tavuk şiş dürüm                   Anzahl und Name, große fette Schrift
       Acı sos                         Optionen eingerückt, ohne Preis
       Soğansız
1 ×  Mercimek çorbası
────────────────────────────────
```

- Die Bon-Nummer ist die des Kundenbons, damit Theke und Küche vom selben Bon reden.
- Je Zeile Anzahl, Name und Zusatzangabe, darunter die gewählten Optionen. Vorgewählte Optionen (zum Beispiel Größe "Normal") stehen auch da, weil die Küche sie braucht. Namen kommen aus dem Wörterbuch in der Küchensprache, sonst aus dem Bon.
- Keine Preise, keine Summe, kein Pfand, keine Steuer, kein QR-Code, keine Adresse.
- Gleiche Artikel mit gleichen Optionen stehen wie am Bon in einer Zeile mit ihrer Anzahl.
- Breite nach dem Papier des Druckers: 576 Punkte bei 80 mm, 384 bei 58 mm. Schrift so groß, dass man sie vom Herd aus liest (Name rund 5 mm hoch).

**Technik.** Ein reiner Aufbau-Schritt (`kitchen_ticket.dart`, ohne Flutter) macht aus Bon, Wörterbuch und Sprache die Zeilen des Zettels. Ein Zeichner (`kitchen_ticket_image.dart`, mit `dart:ui`) setzt sie zu einem Bild, schwarz oder weiß je Punkt, und `escpos.dart` schickt es in Streifen als Raster (`GS v 0`). Bild-Aufträge bekommen ein längeres Zeitlimit als die 5 Sekunden der Textbons.

### 5.4 Übersetzungen der Speisekarte

**Das Wörterbuch.** Pro Betrieb eine Liste: Name aus der Speisekarte (genau so geschrieben, Groß- und Kleinschreibung zählt, Leerzeichen am Rand nicht), dazu je Sprache `en`, `zh`, `tr`, `ar` ein übersetzter Name oder keiner. Die Sprache der Speisekarte selbst gilt als Deutsch und steht am Kundenbon. Nachgeschlagen wird für: Kategorie, Artikel, Zusatzangabe des Artikels, Auswahlgruppe, Option. Kein Treffer oder leere Übersetzung: der Name aus der Speisekarte.

**Verwaltung im Browser,** neue Seite **Übersetzungen** in der Navigation des Betriebs (für Anbieter und Chef):

- Oben ein Umschalter für die Sprache (English, 中文, Türkçe, العربية) und der Stand "62 von 140 übersetzt".
- Darunter eine Tabelle, gegliedert wie die Speisekarte: Kategorien, dann je Kategorie ihre Artikel (mit Zusatzangabe), dann "Auswahl und Extras" mit Gruppen und Optionen. Jede Zeile: links der Name aus der Speisekarte, rechts ein Feld für die gewählte Sprache. Jeder Name steht nur einmal da.
- Speichern beim Verlassen des Feldes, mit sofortiger Anzeige und Rückmeldung wie beim Preis. Leeren löscht die Übersetzung. Das arabische Feld schreibt von rechts nach links.
- Filter "Nur fehlende". Mit der Tabulator-Taste springt man von Feld zu Feld nach unten.
- Stillgelegte Artikel und Kategorien stehen nicht in der Tabelle; ihre Übersetzungen bleiben gespeichert.

**Speisekarten-Datei.** Neuer freiwilliger Schlüssel ganz oben:

```json
"uebersetzungen": {
  "Hühnerspieß": { "en": "Chicken skewer", "tr": "Tavuk şiş", "zh": "鸡肉串", "ar": "سيخ دجاج" },
  "Scharfe Sauce": { "tr": "Acı sos" }
}
```

Beim Einspielen (Ersteinrichtung am Tablet und "Speisekarte neu einspielen" im Browser) gewinnt die Datei bei jedem Eintrag, der in ihr steht; was nicht in ihr steht, bleibt. Unbekannte Sprachkürzel und Namen, die es in der Speisekarte nicht gibt, meldet das Einspielen als Fehler mit dem Namen. Dieselben Regeln gelten für "Speisekarte neu einspielen" am Tablet (`reimport_panel.dart`, für Kassen ohne Server).

**Nur Übersetzungen einspielen.** Auf der Seite Übersetzungen steht für den Anbieter die Taste "Übersetzungen einspielen". Sie nimmt eine Datei, die nur den Schlüssel `uebersetzungen` enthält, und ändert nichts an Artikeln und Preisen. Geprüft wird gegen die Speisekarte des Betriebs, mit denselben Fehlermeldungen. So kommen Übersetzungen in einen laufenden Betrieb, ohne dass eine alte Datei Preise überschreibt.

**Abgleich.** Der Server führt die Übersetzungen in einer eigenen Tabelle mit Änderungs-Nummer und schickt sie dem Tablet beim Holen als neue Art `translations`. Das Tablet speichert sie in einer eigenen Tabelle und zeigt sie sofort. Nach dem Update auf 1.10.0 holt das Tablet den Stand des Servers einmal vollständig neu, damit ihm keine Übersetzung fehlt, die ein älterer Stand überlesen hat. Das geschieht über das gewöhnliche Holen ab Änderungs-Nummer 0 (`applyPage`), nicht über das erste Laden nach dem Koppeln (`replaceAll`), denn der offene Bon und wartende Artikel-Änderungen müssen bleiben. Vom Tablet zum Server geht nichts.

### 5.5 Daten

- **Tablet, Datenbank 7:** Tabelle `translations` (Name, Übersetzungen). Neue Spalten in den Einstellungen: Bediensprache, Küchenbon-Ort, Küchensprache, Küchendrucker (Art, Adresse, Name, Papierbreite), abgeschaltete Kategorien. Migration mit Test wie bei den Schritten davor.
- **Server, Migration `0003`:** Tabelle `translations` mit Sperre pro Betrieb und Änderungs-Nummer. Neue Adressen in der Verwaltung zum Lesen und Ändern, Erweiterung von `parse_menu.ts`, `import_menu.ts` und `pull.ts`.
- **Speisekarten-Datei:** Schlüssel `uebersetzungen`, gelesen von `menu_import.dart` (Tablet) und `parse_menu.ts` (Server) nach denselben Regeln, mit gemeinsamen Prüfdaten.

## 6. Reihenfolge beim Bauen

Eine Auslieferung (1.10.0), gebaut in dieser Reihenfolge, jede Stufe für sich geprüft:

1. **Daten:** Migration am Tablet, Wörterbuch am Server, Datei, Abgleich.
2. **Verwaltung:** Seite Übersetzungen.
3. **Bediensprache:** Texte herausziehen, vier Übersetzungen, Sprachwahl, Arabisch von rechts nach links, Namen der Speisekarte am Bildschirm.
4. **Küchenbon:** Aufbau, Bild, Druck, Einstellungen mit Vorschau, zweiter Drucker.
5. **Prüfung und Übergabe:** Test aller Bildschirme in fünf Sprachen, Prüfliste, Listen zum Gegenlesen. Die Speisekarte von YICHI übersetzt Claude nur, wenn Niko es will (Abschnitt 9); sie käme als Datei nur mit Übersetzungen.

## 7. Prüfung

- Tests zuerst (wie bisher): Aufbau des Küchenbons, Wörterbuch mit Rückfall, Datei mit Fehlermeldungen, Migration 6 nach 7, Abgleich, Adressen am Server, Seite im Browser.
- Der Küchenbon wird als Bild verglichen (je Sprache ein gespeichertes Vergleichsbild), mit den mitgelieferten Schriften, damit der Test überall dasselbe zeichnet.
- Jeder Hauptbildschirm in jeder Sprache ohne Überlauf; Arabisch zusätzlich: Kategorien stehen rechts, Bon links.
- Alle bisherigen Tests laufen unverändert auf Deutsch weiter.
- Die ganze Test-Suite läuft auf GitHub (Nikos Wahl vom 18.11.2026).
- Nur am echten Gerät prüfbar, darum in der Prüfliste: Druck des Bildes am Bondrucker (Geschwindigkeit, Schwärzung, Schnitt zwischen Kundenbon und Küchenbon), zweiter Drucker, Lesbarkeit aus Abstand.

## 8. Was Claude festgelegt hat (Niko kann widersprechen)

1. Chinesisch heißt vereinfachte Schrift (简体), wie am Festland und bei den meisten Lokalen in Österreich üblich.
2. Die Einrichtung (Signatur, Koppeln, Drucker und Kartenterminal einrichten) bleibt vorerst Deutsch.
3. Der Kundenbon und alle Berichte bleiben Deutsch.
4. Die Sprache gilt pro Kassa, nicht pro Mitarbeiter.
5. Der Küchenbon wird immer als Bild gedruckt, auch auf Deutsch.
6. Welche Kategorien auf den Küchenbon kommen, stellt man am Tablet ein (pro Kassa), nicht im Browser.
7. Ein Storno druckt einen Küchenbon mit STORNO.
8. Beträge und Datum sehen in jeder Sprache gleich aus, mit den Ziffern 0 bis 9.
9. Am Hinweis zur ausgefallenen Signatur bleibt der Satz mit dem genauen Grund Deutsch.
10. Die Verwaltung bekommt "Übersetzungen einspielen" (Datei nur mit Übersetzungen).
11. Die Übersetzungen der Oberfläche schreibt Claude; vor dem echten Betrieb soll ein Muttersprachler die chinesische, türkische und arabische Liste gegenlesen.

## 9. Offen bei Niko

- Wer liest die chinesischen, türkischen und arabischen Texte gegen?
- Soll Claude die Speisekarte von YICHI gleich in alle vier Sprachen übersetzen und als Datei zum Einspielen vorbereiten?

## 10. Abweichungen und Entscheidungen beim Bau

Was beim Bauen anders wurde als oben beschrieben oder oben offen war, je mit dem Grund.

1. **Übersetzung gleich dem Namen.** Steht als Übersetzung genau der Name aus der Speisekarte ("Cola", "XXL"), zählt das als übersetzt und wird gespeichert. Nur ein leeres Feld heißt "keine Übersetzung". Sonst käme die Seite Übersetzungen nie auf "Alles übersetzt.".
2. **Wo die Karte "Sprache" steht.** In den Einstellungen ist "Sprache" die erste Karte der rechten Spalte, ohne Scrollen sichtbar, nicht ganz oben links (5.2 sagt "erster Abschnitt"). So bleibt die Karte Signatur oben links ganz sichtbar.
3. **Hinweis zur ausgefallenen Signatur.** Der Grund kommt aus der Signatur und bleibt Deutsch. Steht die Kassa in einer anderen Sprache, folgt darunter ein fester übersetzter Satz: "Die Kassa läuft weiter. Bitte dem Chef Bescheid geben." Steht der Grund in der Bediensprache (auf Deutsch, oder wenn A-Trust die Zugangsdaten abgelehnt hat), heißt der Satz darunter "Du kannst normal weiterverkaufen." in der Bediensprache.
4. **Deutsche Bildschirme in Arabisch.** Was Deutsch bleibt (Einrichtung, Signatur, Drucker, Server), wird in Arabisch nicht gespiegelt, sondern steht als Ganzes von links nach rechts. Ein deutscher Text in einem gespiegelten Rahmen wäre schwer zu lesen.
5. **Was in Arabisch nicht gespiegelt wird:** Ziffernfelder, Beträge, Uhrzeiten und das Diagramm der Übersicht stehen weiter von links nach rechts.
6. **Lange Namen auf Artikeltasten.** Ein langer übersetzter Name wird zuerst kleiner (in Stufen bis 80 %) und erst dann mit "…" gekürzt.
7. **Der Verkauf wartet nicht auf den Küchenbon.** Das Ergebnis des Küchenbons kommt später nach (in der Technik ein `Future`). "Verkauf fertig" zeigt dazu nur etwas, wenn er gescheitert ist: "Küchenbon nicht gedruckt" mit der Taste "Küchenbon drucken".
8. **Kein Küchendrucker eingerichtet.** Ist "Am Küchendrucker" gewählt, aber kein Drucker da, steht ein Hinweis in den Einstellungen, und "Verkauf fertig" zeigt nach jedem Verkauf "Küchenbon nicht gedruckt" mit "Kein Küchendrucker eingerichtet. Es kommt kein Küchenbon." So fällt es sofort auf, wenn in der Küche nichts ankommt.
9. **Kein Nachdruck für stornierte Verkäufe.** Ein stornierter Verkauf hat im Bereich Bons keine Taste "Küchenbon drucken", sonst ginge eine abgesagte Bestellung noch einmal in die Küche. Das Storno selbst druckt den Küchenbon mit STORNO. Hat ein Bon nichts für die Küche, steht nach dem Tippen der Hinweis "Auf diesem Bon ist nichts für die Küche."
10. **Tasten in den Bons.** "Küchenbon drucken" steht neben "Drucken", "Stornieren" in einer zweiten Reihe darunter. Drei gleich breite Tasten in einer Reihe schnitten die Beschriftung ab.
11. **Vorschau des Küchenbons.** Ist der Abschnitt Küche breit genug (Tablet ab 1280 dp Breite), steht die Vorschau neben den Kategorien für die Küche, bei schmalerem Bildschirm (1024 dp) darunter.
12. **Probe-Bon.** Der Beispiel-Zettel nimmt die ersten drei Artikel aus Kategorien für die Küche. Beim ersten Artikel steht je Auswahlgruppe eine Option (die vorgewählte, sonst die erste), höchstens zwei Gruppen.
13. **Reihenfolge am gemeinsamen Drucker.** Am Bondrucker kommt der Küchenbon direkt nach dem Kundenbon desselben Verkaufs, auch wenn schnell hintereinander verkauft wird: Bon A, Küche A, Bon B, Küche B.
14. **Neuer Farbwert "Papier".** Für die Vorschau des Küchenbons gibt es den Farbwert Papier, weiß in hell und dunkel, weil der Zettel auch im dunklen Bild weiß ist.
15. **Chinesische Monate mit Ziffern.** Ausgeschriebene Daten zeigen den Monat auf Chinesisch als Ziffer ("11月17日", "2026年11月"), nicht als Zeichen ("十一月"). So ist es in Kassen und Apps üblich. Das Zahlendatum 26.11.2026 bleibt in jeder Sprache gleich.
16. **"Pfand" in der Übersicht.** In der Übersicht (meistverkaufte Artikel, Umsatz nach Kategorie) steht die Zeile Pfand in der Bediensprache. In den Daten und in den Berichten heißt sie weiter "Pfand".
