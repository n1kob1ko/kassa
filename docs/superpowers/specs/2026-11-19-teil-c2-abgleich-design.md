# Kassa Teil C, Stufe 2: Abgleich, Fotos, Umsätze

Stand: 19.11.2026. Entwurf von Claude, Freigabe durch Niko steht aus.

Dieses Dokument ergänzt den Entwurf für Teil C (`2026-11-18-teil-c-server-und-verwaltung-design.md`, dort vor allem 5.5 bis 5.8, 5.10, 5.13 und 5.14) und den Entwurf zur Signatur (`2026-11-18-rksv-signatur-design.md`, dort 6.11 und Punkt 6a in Abschnitt 9). Wo sich die Dokumente widersprechen, gilt für Stufe 2 dieses. Alles, was hier nicht steht, gilt weiter wie dort, in `PRODUCT.md`, `DESIGN.md` und `docs/design-regeln.md`.

## 1. Worum es geht

Seit Stufe 1 kennt der Server den Betrieb, die Speisekarte, die Mitarbeiter und die Kassa. Die Bons liegen aber weiter nur am Tablet. Daraus folgt:

1. Geht das Tablet kaputt oder verloren, sind Bons, Tagesabschlüsse und das Protokoll der Signatur weg.
2. Ein Preis lässt sich im Browser nicht ändern, ein Foto nicht hochladen.
3. Umsätze sieht man nur am Tablet.
4. Fehler am Tablet muss Niko abtippen oder fotografieren.
5. Der Server selbst hat keine Sicherung.

Niko am 19.11.2026: Stufe 2 bauen, während er auf den USB-Verteiler wartet. Beschrieben war sie ihm so: Bons werden am Server gesichert, Artikel gleichen sich ab, dazu Fotos und Umsätze im Browser.

**Erfolg heißt:** Niko boniert am Tablet und sieht den Bon kurz darauf im Browser. Er ändert im Browser einen Preis und sieht ihn am Tablet, und umgekehrt. Er lädt ein Foto hoch und sieht es auf der Artikel-Taste. Er sieht die Umsätze im Browser, auch am Handy. Er schaltet das Internet aus, boniert weiter, schaltet es ein, und alles kommt nach. Nichts davon hält an der Theke je auf.

## 2. Ziele, Nicht-Ziele, Anti-Ziele

**Ziele**

- Bons mit Zeilen, Optionen und Zahlung, Tage, Bargeld-Bewegungen und das Protokoll der Signatur gehen vom Tablet zum Server. Auch alles, was schon am Tablet liegt.
- Preis, "Im Verkauf", Favorit, Pfand und Kennzeichen eines Artikels gleichen sich in beide Richtungen ab.
- Fotos für Artikel und ein Logo für den Betrieb: im Browser hochladen, am Tablet sehen.
- Im Browser: Umsätze, Bons, Tagesabschlüsse, Preis und Schalter eines Artikels, Protokoll der Signatur herunterladen, Fehlerberichte (nur Anbieter).
- Fehlerberichte und Ergebnisse von "Geräte testen" gehen an den Server.
- Der Server sichert seine Datenbank jede Nacht.

**Nicht-Ziele von Stufe 2** (bewusst später)

- **Eine Kassa auf ein Ersatz-Tablet übernehmen** (Bons, Nummern, Zählerstand, Kette der Signatur). Stufe 2 sichert alles, was dafür nötig ist. Die Übernahme selbst wird ein eigener Schritt vor der Inbetriebnahme bei YICHI (S3 der Signatur). Niko hat das am 19.11.2026 so gewählt ("Erst sichern, Übernahme später").
- Artikel anlegen, umbenennen, verschieben, Kategorien, Auswahl-Vorlagen, Betriebsdaten ändern, Chef-Zugang: Stufe 3.
- Fotos für Kategorien. Das Tablet zeigt Kategorien als Liste mit Text, ein Foto hätte dort keinen Platz.
- Logo am gedruckten Bon, Kundenanzeige, Steuersatz 4,9 %.
- Mehrere Kassen in einem Betrieb als geprüfter Fall. Die Daten lassen es zu (wie in Teil C).
- Sofortige Übertragung in Echtzeit, Abgleich bei geschlossener App.

**Anti-Ziele**

- Die Kassa wartet an der Theke nie auf den Server. Kein Verkauf, kein Storno, kein Abschluss hängt am Abgleich.
- Der Server ändert oder löscht nie einen Bon, eine Bargeld-Bewegung oder einen Eintrag im Protokoll.
- Kein Betrieb sieht je Daten eines anderen. Das gilt auch für Fotos und Protokolle.
- Der AES-Schlüssel der Signatur und der Geräte-Schlüssel verlassen das Tablet nie. Der Server bekommt nur, was auch auf dem Bon und in der ausgegebenen Protokoll-Datei steht.
- Ein Fehlerbericht enthält nie Bon-Zeilen, Beträge, Namen oder Kartendaten.
- Nichts, was die Signatur aus Version 1.4.0 kann, ändert sein Verhalten.

## 3. Rahmenbedingungen

- **Die App ist übergeben** (1.2.0 bis 1.4.0, Datenbank am Tablet Version 4). Stufe 2 bringt Version 5 mit Migration und Test. Tablets, die schon gekoppelt sind und Bons haben, müssen diese nach dem Update von selbst hinaufschicken.
- **Der Server läuft** bei Railway (Projekt "kassa", PostgreSQL 18, Ablage "dateien", Region ams). Der Dienst ist auf einen Commit festgelegt. Zur Übergabe gehört, den neuen Stand dort auszurollen; die neuen Tabellen richtet der Server beim Start selbst ein.
- **Die Bau-Umgebung** hat PostgreSQL 16, Node 22, Flutter und einen Browser, aber kein Tablet. Lange Läufe (alle Tests der App) laufen auf GitHub.
- **Das Repo ist öffentlich.** Keine Schlüssel, keine Server-Adresse, keine Daten von Betrieben (Ausnahme: Name und Speisekarte von YICHI).
- **Die Signatur gehört einem anderen Thread.** Stufe 2 liest ihre Tabellen und ändert sie nicht. Die nächste Stufe der Signatur (S2, Chipkarte) baut danach auf Version 5 der Datenbank auf.

## 4. Wege, die zur Wahl standen

Die großen Entscheidungen (eigener schlanker Abgleich, ein Dienst, Trennung der Betriebe in der Datenbank) stehen im Entwurf für Teil C, Abschnitt 4, und sind freigegeben. Für Stufe 2 kamen dazu:

**Was das Tablet als "noch zu senden" führt**

| Weg | Abwägung |
|---|---|
| **Eine eigene Liste am Tablet. Jeder Eintrag entsteht im selben Schritt wie die Sache selbst.** | **Gewählt**, so steht es in Teil C 5.6. Trägt auch Dinge ohne Nummer (Artikel-Änderung, Bericht), hält fest, was abgelehnt wurde, und übersteht neues Koppeln. Die Einträge schreibt die Datenbank am Tablet selbst (Trigger), sobald ein Bon, ein Tag, eine Bewegung, eine Kette oder ein Zertifikat entsteht oder sich ändert. So kann keine Stelle im Code es vergessen, auch keine, die später mit der Signatur dazukommt. Ein Test prüft es für jede Art. |
| Ohne Liste: "alle Bons mit Nummer größer als die zuletzt gesendete" | Weniger Code für Bons, aber für Tage (ändern sich), Artikel-Änderungen und Berichte bräuchte es doch eine Liste. Zwei Wege statt einem. |

**Wie der Server Bons hält**

| Weg | Abwägung |
|---|---|
| **Der Bon liegt einmal ganz so, wie er ankam (ein Stück), und daneben stehen Kopf und Zeilen in eigenen Spalten für Listen und Auswertungen.** | **Gewählt.** Das Original bleibt unverändert und kann später genau so auf ein Ersatz-Tablet zurück. Auswertungen bleiben schnell. Preis: Angaben stehen doppelt; beide entstehen im selben Schritt aus derselben Nachricht. |
| Nur eigene Tabellen | Sparsamer, aber die Rückgabe an ein Tablet müsste den Bon wieder zusammensetzen, und jede vergessene Angabe wäre verloren. |
| Nur das Stück | Auswertungen müssten in jedes Stück hineinlesen. |

**Bilder**

| Weg | Abwägung |
|---|---|
| **Der Server rechnet jedes Bild neu: höchstens 800 Pixel breit, Format WebP, ohne eingebettete Angaben, dazu eine Farbe als Platzhalter.** | **Gewählt.** Kleine Dateien (wichtig am Tablet mit mobilem Internet), ein Format für Foto und Logo (auch mit durchsichtigem Hintergrund), nie eine Datei unverändert ausgeliefert. |
| JPEG für Fotos, PNG für Logos | Zwei Formate, größere Dateien, kein Gewinn. |
| Echte unscharfe Vorschau (BlurHash) | Am Tablet liegen die Fotos auf dem Gerät und sind sofort da. Im Browser genügt die Farbe. Zwei Bibliotheken mehr für kaum sichtbaren Nutzen. |

**Sicherung der Datenbank**

| Weg | Abwägung |
|---|---|
| **Das Standard-Werkzeug von PostgreSQL (`pg_dump`) im Abbild des Servers, in derselben Hauptversion wie die Datenbank.** | **Gewählt.** Die Datei lässt sich mit jedem PostgreSQL-Werkzeug zurückspielen, auch wenn unser Server nicht läuft. Preis: Die Version im Abbild muss zur Datenbank passen; der Server prüft das beim Start und meldet es. |
| Eigene Sicherung in Node (jede Tabelle als Datei) | Unabhängig von Versionen, aber ein eigenes Format, das nur unser Code zurückspielen kann. |
| Nur die Sicherungen von Railway | Hängt an Nikos Tarif und liegt am selben Ort wie die Datenbank. Kann zusätzlich bleiben. |

## 5. Was gebaut wird

### 5.1 Die Liste "noch zu senden" am Tablet

- Neue Tabelle am Tablet. Ein Eintrag hat: laufende Nummer, Art, Kennung der Sache, bei Artikel-Änderungen Feld, Wert und Zeitpunkt, Zustand (wartet, abgelehnt), bei Ablehnung den Grund.
- **Arten:** Tag, Bargeld-Bewegung, Bon, Artikel-Änderung, Bericht, Zertifikat der Signatur, Kette der Signatur.
- Ein Eintrag entsteht in derselben Transaktion wie die Sache, geschrieben von der Datenbank selbst: Bon speichern (Verkauf bar und Karte, Storno, Sonderbeleg), Tag öffnen, Wechselgeld setzen, Tag abschließen, Bargeld-Bewegung, Artikel ändern, Kette beginnen oder beenden, Zertifikat ablegen, Bericht ablegen. Das gilt auch auf einem Tablet ohne Kopplung; die Liste wartet dann einfach. Einzige Ausnahme sind Artikel-Änderungen: sie entstehen nur an einem gekoppelten Tablet (siehe 5.4).
- Der Inhalt eines Bons, einer Bewegung, eines Zertifikats steht nicht in der Liste. Er wird beim Senden aus den Tabellen gelesen, die sich nicht ändern lassen. Bei Tag und Kette wird der Stand zum Zeitpunkt des Sendens gelesen.
- Ein Bon nimmt seinen Eintrag im Protokoll der Signatur mit (Kette, Stelle, JWS, Ausfall, Zertifikat), falls er einen hat.
- **Reihenfolge:** nach laufender Nummer. Dadurch kommt der Tag vor seinen Bons, der Bon vor seinem Storno, Zertifikat und Kette vor dem ersten Eintrag.
- **Migration auf Version 5:** stellt alles Vorhandene einmal in die Liste, in dieser Reihenfolge: Zertifikate, Ketten, Tage, Bargeld-Bewegungen, Bons nach Nummer. Der Schritt "beim Koppeln alles einstellen" aus Teil C 5.6 entfällt damit: es steht schon dort.
- **Ist das Tablet bei der Migration schon gekoppelt,** stellt sie zusätzlich für jeden Artikel die fünf am Tablet änderbaren Felder als Artikel-Änderung ein, mit dem Zeitpunkt der Migration. Grund: Seit Stufe 1 lassen sich diese Felder am gekoppelten Tablet ändern, ohne dass der Server davon erfährt. Ohne diesen Schritt würde die erste Änderung im Browser (etwa ein Foto) den Preis vom Tablet still zurückdrehen. So gewinnt ein Mal der Stand, mit dem an der Theke verkauft wird.
- **Geräte-Kennung:** Die App erzeugt vor dem ersten Senden eine zufällige Kennung für diese Installation. Sie bleibt, solange die App-Daten bleiben, auch über neues Koppeln hinweg, und geht mit jedem Paket mit.
- Angenommene und schon vorhandene Einträge werden gelöscht. Abgelehnte bleiben mit Grund stehen und werden nicht mehr gesendet.

### 5.2 Senden

- Neue Adresse `POST /api/device/sync/push`. Ein Paket hat höchstens 100 Einträge und 2 MB. Die Antwort nennt pro Eintrag: `accepted`, `duplicate`, `rejected` mit Grund (`conflict`, `invalid`, `unknown_item`) oder `error`.
- **Der Server lehnt so wenig wie möglich ab** (Postels Gesetz): einen Bon nur, wenn er nicht lesbar ist oder dieselbe Kennung schon mit anderem Inhalt da ist. Ein Bon, dessen Tag der Server nicht kennt, wird trotzdem angenommen. Stimmen die Summen eines Bons nicht mit seinen Zeilen überein, wird er angenommen und der Server schreibt einen Bericht.
- **Derselbe Bon nie zweimal:** Der Server bildet eine Prüfsumme über den Inhalt. Sie umfasst genau die Felder der ersten Fassung der Nachricht; kommt später ein Feld dazu, zählt es nur mit, wenn die Nachricht eine neue Fassung nennt. So wird ein alter Bon nach einem Update der App nicht zum Widerspruch.
- Gleiche Kennung, gleicher Inhalt: `duplicate`, egal über welche Kassa des Betriebs er zuerst kam. Gleiche Kennung, anderer Inhalt: `rejected/conflict`, der Server behält seine Fassung und schreibt einen Bericht.
- **Tag:** Solange er offen ist, überschreibt jede Sendung den Stand am Server. Ein abgeschlossener Tag ist endgültig: gleich heißt `duplicate`, anders `conflict`. Ein Tag, der nie abgeschlossen ankommt, bleibt als "nicht abgeschlossen" stehen.
- **Kette der Signatur:** wie ein Tag, endgültig ab ihrem Ende. **Zertifikat, Bargeld-Bewegung, Bericht:** nur anlegen.
- **Ein Paket, das als Ganzes scheitert** (Antwort 4xx, aber nicht "nicht gekoppelt" oder "gesperrt"): Das Tablet sendet die Einträge dieses Pakets einzeln. Ein Eintrag, der auch einzeln scheitert, gilt als abgelehnt. So hält ein kaputter Eintrag die Liste nie auf.
- Kein Internet, Zeitüberschreitung, Fehler am Server: später wieder, mit den wachsenden Abständen aus Stufe 1.
- Scheitert am Server ein einzelner Eintrag an etwas Unerwartetem, antwortet er für diesen Eintrag mit `error`. Das Tablet lässt ihn stehen, sendet die anderen weiter und versucht ihn beim nächsten Lauf wieder.
- **Testbon:** Das Tablet sendet pro Bon, ob er echt ist. Echt ist ein Bon nur, wenn er einen Eintrag in einer Kette im echten Betrieb hat. In Stufe 2 ist das keiner. Abweichung von Teil C 5.5: Die App bekommt dafür kein eigenes Feld, weil die Signatur es inzwischen hergibt.

### 5.3 Ein Lauf des Abgleichs

Reihenfolge in einem Lauf: **senden, holen, Dateien laden.**

- Zuerst senden, damit eigene Artikel-Änderungen am Server sind, bevor das Holen den Stand bringt, der gewonnen hat.
- Scheitert das Senden an "kein Internet", "gesperrt" oder "nicht gekoppelt", endet der Lauf wie bisher. Abgelehnte Einträge halten das Holen nicht auf.
- "Zuletzt abgeglichen" rückt nur weiter, wenn Senden und Holen geklappt haben. Dateien zählen dafür nicht.
- **Auslöser** (zusätzlich zu Start, nach vorn kommen, alle 5 Minuten, Internet zurück, Taste): kurz nach jedem Eintrag in die Liste. Mehrere Einträge kurz hintereinander lösen einen Lauf aus, nicht viele (2 Sekunden Ruhe abwarten).
- Die Kassa zeigt dabei nichts an und wartet auf nichts.

### 5.4 Artikel-Änderungen in beide Richtungen

Regeln wie in Teil C 5.6 (pro Feld gilt die spätere Änderung, Uhrzeit aus der Zukunft wird gekürzt). Dazu:

- Ändert jemand an einem gekoppelten Tablet Preis, "Im Verkauf", Favorit, Pfand oder Kennzeichen, entsteht pro geändertem Feld ein Eintrag mit Wert und Zeitpunkt. An einem Tablet ohne Kopplung entsteht keiner.
- **Beim Koppeln** (auch beim erneuten Koppeln) ersetzt der Stand des Servers den des Tablets, so wie es die Rückfrage sagt. Im selben Schritt werden wartende Artikel-Änderungen gelöscht. Sie gehen nie nachträglich hinauf.
- Solange für ein Feld eines Artikels ein Eintrag wartet, lässt das Holen dieses Feld in Ruhe.
- Ein Eintrag für einen Artikel, den der Server nicht kennt, wird abgelehnt (`unknown_item`).
- Gewinnt die Änderung, zieht der Server eine neue Änderungs-Nummer. Jede Kassa des Betriebs bekommt sie beim nächsten Holen.
- Ändert der Browser ein Feld, gilt die Uhr des Servers.
- **Offener Bon:** Ein Preis vom Server wirkt auf einen offenen Bon genau so wie ein Preis, den jemand am Tablet unter "Artikel" ändert. Der Bau prüft, was die App dabei heute tut, und hält es in einem Test fest. Unterscheiden sich beide Wege, wird der Weg über den Server angeglichen.

### 5.5 Fotos und Logo

- **Hochladen** im Browser: pro Artikel ein Foto, für den Betrieb ein Logo. JPEG, PNG oder WebP, höchstens 10 MB.
- **Der Server** prüft, dass es ein Bild ist (auch gegen übergroße Bilder), dreht es richtig, rechnet es auf höchstens 800 Pixel Breite, entfernt eingebettete Angaben, speichert es als WebP unter dem Betrieb und merkt sich Breite, Höhe und eine mittlere Farbe.
- **Ersetzen** heißt neue Datei mit neuer Kennung. Die alte wird aus der Ablage gelöscht. **Entfernen** geht auch.
- **Zum Tablet:** Beim Holen steht bei Artikel und Betrieb die Kennung der Datei (oder leer). Das Tablet lädt fehlende Dateien über `GET /api/device/files/<Kennung>` in seinen eigenen Ordner, erst in eine vorläufige Datei, dann umbenennen, dann den Pfad am Artikel setzen. Bis dahin bleibt das alte Bild. Dateien, auf die nichts mehr zeigt, räumt es weg.
- Die Kassa zeigt nie ein Bild direkt aus dem Internet.
- **Wer darf:** eine Datei bekommen nur Kassen und Benutzer des Betriebs, dem sie gehört (und der Anbieter).
- **"Bilder anzeigen":** Der Schalter in den Einstellungen ist ab Werk aus. Kommt das erste Foto auf ein Tablet, schaltet die Kassa ihn ein Mal von selbst ein. Danach gilt, was am Tablet eingestellt wird.
- **Logo:** in der Kopfleiste der Kassa und am Anmeldebildschirm (Teil C 5.11 Punkt 6), in der Verwaltung in der Kopfzeile des Betriebs.

### 5.6 Protokoll der Signatur am Server

- Der Server hält pro Gerät (Geräte-Kennung aus 5.1): Zertifikate, Ketten (Art Probe oder echt, Kassen-Kennung, Zertifikat, Beginn, Ende) und die Einträge (Kette, Stelle, Bon, JWS, Ausfall, Zertifikat). Einträge und Zertifikate lassen sich nicht ändern und nicht löschen, Ketten ab ihrem Ende nicht mehr.
- **Warum pro Gerät und nicht pro Kassa:** Wird ein Tablet ein zweites Mal mit demselben Betrieb gekoppelt, entsteht am Server ein neuer Eintrag "Kassa" (Teil C 5.4), die Kette am Tablet läuft aber weiter. Am Gerät hängend bleibt sie ein Stück. Jede Zeile merkt sich zusätzlich, über welche Kassa sie kam. Dasselbe gilt für Tage: ein offener Tag, der unter der alten Kassa begann, wird unter der neuen weitergeschrieben.
- Die Kassa am Server merkt sich die Geräte-Kennung, sobald das erste Paket kommt. Kassen mit derselben Geräte-Kennung zeigen dasselbe Protokoll.
- In der Verwaltung unter "Kassen" steht pro Kassa die Kassen-Kennung der laufenden Kette und die Taste **"Protokoll herunterladen"**. Sie liefert pro Kette eine Datei in der Form des Finanzministeriums, dieselbe Form wie "Protokoll ausgeben" am Tablet.
- App und Server werden gegen dasselbe Beispiel getestet: dieselben Einträge ergeben dieselbe Datei.
- Probe-Ketten werden genauso gesichert. Die Verwaltung kennzeichnet sie als "Probe".
- Der Zählerstand steht verschlüsselt in jedem Eintrag. Mehr braucht die Sicherung nicht. Die Aufgabe "Protokoll sichern" am Tablet bleibt in Stufe 2 unverändert.

### 5.7 Fehlerberichte

Wie Teil C 5.8. Dazu:

- Die App fängt unerwartete Fehler an drei Stellen ab (Fehler in der Oberfläche, Fehler außerhalb davon, Fehler in Hintergrund-Aufgaben). Das Abfangen darf selbst nie einen Fehler auslösen und nie einen Bildschirm ändern.
- Der Bericht wird aus festen Feldern gebaut. Die Meldung eines Fehlers kann Text aus Daten enthalten; darum geht nur die Art des Fehlers und die Aufrufliste hinaus, die Meldung selbst nur für Fehlerarten aus einer festen Liste, die keine Daten tragen. Abweichung von Teil C 5.8 ("die ersten 500 Zeichen der Meldung"), zugunsten des Anti-Ziels.
- Der Server schreibt auch eigene Berichte: Widerspruch bei einem Bon oder Tag, Summen stimmen nicht, Sicherung gescheitert.
- In der Verwaltung: Seite "Fehlerberichte" nur für den Anbieter, neueste zuerst, mit Betrieb, Kassa, Art, Zeitpunkt, App-Version, Zähler.

### 5.8 Sicherung der Datenbank

- Der Server prüft jede Stunde: Ist es nach 3 Uhr (Wiener Zeit) und gibt es für heute noch keine gelungene Sicherung, legt er eine an und schreibt sie in die Ablage. Er behält die letzten 14 gelungenen.
- Ein Neustart mitten in der Nacht schadet nicht: die nächste Prüfung holt nach.
- Scheitert sie, schreibt der Server einen Bericht und eine Zeile ins Protokoll bei Railway.
- Die Seite "Fehlerberichte" zeigt oben "Letzte Sicherung: …", in Warnfarbe, wenn sie älter als 36 Stunden ist.
- Fotos und Installationsdateien liegen in der Ablage und sind nicht Teil der Sicherung. Fotos lassen sich neu hochladen.
- **Zurückspielen:** einmal in der Bau-Umgebung geprobt (Sicherung ziehen, in eine leere Datenbank spielen, vergleichen) und als Anleitung unter `docs/betrieb/` beschrieben. Wo die Werkzeuge vorhanden sind, läuft die Probe als Test mit.

### 5.9 Daten am Server (neu)

Jede Tabelle trägt den Betrieb und ist wie in Stufe 1 in der Datenbank gesperrt. Geldbeträge sind ganze Cent, Zeiten wie vom Tablet gemeldet.

| Was | Wichtigste Angaben | Schreibt |
|---|---|---|
| Bon | Kennung vom Tablet, Kassa, Nummer (pro Kassa eindeutig), Zeit, Art, Mitarbeiter, Tag, stornierter Bon, Summen, Zahlungsart, Testbon, Prüfsumme, das Original als ein Stück | Tablet, nur anlegen |
| Bon-Zeile | Bon, Stelle, Artikel, Name, Menge, Einzelpreis, Pfand, Brutto je Steuersatz, Optionen | Tablet, nur anlegen |
| Tag | Kennung, Kassa, alle Felder des Tablets | Tablet, bis abgeschlossen |
| Bargeld-Bewegung | wie am Tablet, dazu Kassa | Tablet, nur anlegen |
| Zertifikat, Kette, Eintrag der Signatur | siehe 5.6, am Gerät hängend | Tablet |
| Bericht | Kassa (leer bei Berichten des Servers), Art, Zeitpunkt, App-Version, Gerät, Inhalt, Zähler | Tablet und Server, nur anlegen |
| Datei | Kennung, Art (Foto, Logo), Schlüssel in der Ablage, Größe, Breite, Höhe, Farbe | Verwaltung |
| Sicherung | Tag, Schlüssel in der Ablage, Größe, Ergebnis (ohne Betrieb, Tabelle des Systems) | Server |

Dazu am Betrieb: Logo und Zeitzone (Vorgabe Europe/Vienna). An der Kassa: Geräte-Kennung. Am Artikel: Verweis auf die Datei statt des bisherigen Textfelds.

Die Datenbank selbst weist Ändern und Löschen ab bei Bon, Bon-Zeile, Bargeld-Bewegung, Bericht, Eintrag und Zertifikat der Signatur, bei abgeschlossenen Tagen und beendeten Ketten.

### 5.10 Verwaltung im Browser

Alle Seiten nach `DESIGN.md`, für Maus, Tastatur und Handy. Ladezustand in der Form des Inhalts, leerer Zustand mit dem nächsten Schritt, Zahlen mit Tabellenziffern. Niko sieht die Seiten als Bilder bei der Übergabe; die gestaltete Fassung für den Chef bleibt Stufe 3.

| Seite | Was sie in Stufe 2 kann |
|---|---|
| **Umsätze** (neu, erste Seite eines Betriebs) | Heute, 7 Tage, 30 Tage. Umsatz mit Vergleich zum Zeitraum davor, Zahl der Bons und Stornos, Balken nach Stunde (heute) oder Tag, bar und Karte, die fünf meistverkauften Artikel, Umsatz nach Kategorie. Über alle Kassen. Hinweis "Testbetrieb", solange es nur Testbons gibt (Regel aus Teil C 5.5). |
| **Bons** (neu) | Liste, neueste zuerst, 50 pro Seite. Filter: Tag, Zahlungsart, nur Stornos. Bon im Detail mit Zeilen, Optionen, Zahlung, Kassa, Kennzeichen "Testbon" und "Storno". Nur ansehen. |
| **Tagesabschlüsse** (neu) | Liste der Tage pro Kassa, offen oder abgeschlossen. Im Detail die Zahlen des Abschlusses und die Bargeld-Bewegungen. Nur ansehen. |
| **Speisekarte** (erweitert) | Artikel nach Kategorie. Pro Artikel: Foto (hochladen, ersetzen, entfernen), Preis ändern, "Im Verkauf" und Favorit schalten. Änderungen sind sofort sichtbar und springen mit Meldung zurück, wenn das Speichern scheitert. "Neu einspielen" bleibt. |
| **Kassen** (erweitert) | Dazu pro Kassa: letzter Bon, Kassen-Kennung, "Protokoll herunterladen". |
| **Betrieb** (neu, klein) | Logo hochladen, ersetzen, entfernen. Name, Adresse, UID nur zur Ansicht. |
| **Fehlerberichte** (neu, nur Anbieter) | siehe 5.7 und 5.8. |

**Die Zahlen der Umsätze** folgen genau den Regeln der Übersicht am Tablet (`stats_repository.dart`): Kalendertage, Verkäufe und Stornos zählen, Sonderbelege nicht, Pfand als eigene Zeile. Kalendertag heißt am Server: in der Zeitzone des Betriebs. App und Server rechnen dasselbe Beispiel (eine Liste von Bons und die erwarteten Zahlen) und müssen auf dasselbe kommen.

### 5.11 Änderungen am Tablet

- **Einstellungen, Karte "Server":** unter "Zuletzt abgeglichen" die Zeile "Wartet noch: 3", wenn etwas wartet. Gibt es abgelehnte Einträge: "1 Eintrag wurde vom Server abgelehnt. Niko weiß Bescheid." in ruhiger Warnfarbe (der Server hat dazu einen Bericht).
- **Rückfrage vor dem Koppeln:** ein Satz mehr, dass Preise, Favoriten und "Im Verkauf" vom Tablet durch den Stand des Servers ersetzt werden. Das war seit Stufe 1 offen und steht so in Teil C 5.4.
- **Artikel-Taste und Artikel-Zeile** zeigen das Foto vom Server, **Kopfleiste und Anmeldung** das Logo.
- Sonst keine neuen Bildschirme. Am Tablet wird weiter nichts getippt.
- **Version 1.5.0 (Build 7)**, Datenbank Version 5.

### 5.12 Aus Stufe 1 aufgeschoben, jetzt dabei

- Eine Obergrenze für Koppel-Versuche über alle Adressen, und IPv6-Adressen zählen pro Netz (/64) statt einzeln.
- Zeitgrenzen für Anfragen am Server (eine hängende Verbindung darf keinen Platz ewig belegen).
- Das Tablet vergleicht die Betriebs-Kennung aus der Antwort beim Koppeln mit der, die es schon kennt.

### 5.13 Sicherheit und Datenschutz

Wie Teil C 5.12. Dazu:

- Jede neue Adresse hat einen Test mit einem zweiten Betrieb, der nichts sehen und nichts ändern darf. Das gilt auch für Dateien und den Download des Protokolls.
- Die Grenzen für Größe gelten vor dem Lesen (Paket 2 MB, Bild 10 MB). Bilder mit übertriebener Pixelzahl werden abgelehnt.
- Der Download des Protokolls und jede Änderung an Artikel, Foto und Logo stehen im Verlauf.
- Die Sicherung enthält Prüfwerte von Passwörtern und PINs. Sie liegt nur in der privaten Ablage und geht über keine Adresse des Servers hinaus.

### 5.14 Tests

Testgetrieben wie bisher (Teil C 5.13). Schwerpunkte:

- **Server:** derselbe Bon mehrfach, anderer Inhalt unter derselben Kennung, Paket mit einem kaputten Eintrag, offener und abgeschlossener Tag, spätere Änderung gewinnt pro Feld, Uhr aus der Zukunft, Sperren gegen Ändern und Löschen, Trennung der Betriebe für jede Adresse, Bild-Prüfung (kein Bild, zu groß, gedreht, mit Ortsangabe), Auswertung gegen das gemeinsame Beispiel, Protokoll-Datei gegen das gemeinsame Beispiel, Sicherung und Zurückspielen.
- **App:** Migration auf Version 5 samt Einstellen des Vorhandenen. Für jede Art: Eintrag entsteht mit der Sache oder gar nicht. Senden gegen einen nachgebauten Server: ohne Internet, Abbruch, Wiederholung, abgelehnter Eintrag, Paket scheitert als Ganzes, gesperrt. Wartende Änderung schützt ihr Feld. Datei laden: Abbruch mitten im Laden, Ersetzen, Aufräumen. Fehler abfangen ohne Folgefehler.
- **Gemeinsame Beispiele** unter `shared/fixtures/sync/` für jede neue Nachricht.
- **Zusammenspiel** (`tool/e2e.sh`): koppeln, Bon erzeugen, senden, am Server sehen, Preis am Server ändern, am Tablet sehen, Preis am Tablet ändern, am Server sehen, Foto laden.
- **Verwaltung:** im echten Browser: Umsätze, Bons, Preis ändern, Foto hochladen, Protokoll herunterladen. Dazu Bilder der Seiten in Breite Handy und Breite Rechner.
- **Übergabe:** Prüfliste `docs/testen/teil-c2-pruefliste.md` für Niko mit Tablet und Browser.

## 6. Dem Bau überlassen

- Genaue Tabellen, Spalten, Adressen und Form der Nachrichten über 5.2 und 5.9 hinaus.
- Bibliotheken: Bildverarbeitung am Server, Diagramme in der Verwaltung, Dateien und Netzwerk in der App.
- Wie die Prüfsumme genau gebildet wird, solange 5.2 gilt.
- Ob die Sicherung im Dienst selbst läuft oder als eigener Lauf bei Railway, solange 5.8 gilt.
- Reihenfolge der Arbeit. Empfohlen: zuerst Server und App für Bons (damit früh etwas am echten Server geprüft werden kann), dann Artikel-Änderungen, Fotos, Seiten, Berichte, Sicherung.

## 7. Offene Punkte

**Braucht Niko**

1. Nach der Übergabe: die Prüfliste am Tablet und im Browser.

**Klärt Claude beim Bau**

2. Ob das Abbild des Servers bei Railway das Sicherungs-Werkzeug in Version 18 bekommt. Geht es nicht, fällt die Sicherung auf den zweiten Weg aus Abschnitt 4 zurück, und Niko erfährt es.
3. Was die App heute mit einem offenen Bon tut, wenn sich ein Preis ändert (5.4).

## 8. Claudes Entscheidungen zum Gegenprüfen

- Das Protokoll der Signatur wird in Stufe 2 mitgesichert und lässt sich im Browser herunterladen. Der AES-Schlüssel bleibt am Tablet.
- Umsätze, Bons und Tagesabschlüsse kommen als einfache Seiten schon in Stufe 2, ohne vorherige Freigabe von Bildern. Die gestaltete Fassung bleibt Stufe 3.
- Im Browser sind in Stufe 2 nur Preis, "Im Verkauf", Favorit und Foto änderbar. Alles andere an Artikeln kommt mit Stufe 3.
- Keine Fotos für Kategorien.
- Bilder werden zu WebP, höchstens 800 Pixel breit, mit einer Farbe als Platzhalter statt BlurHash.
- "Bilder anzeigen" schaltet sich beim ersten Foto ein Mal von selbst ein.
- Kein eigenes Feld "Testbon" in der App: echt ist, was in einer echten Kette signiert ist.
- Die Meldung eines Fehlers geht nur für bekannte, datenfreie Fehlerarten an den Server.
- Der Server nimmt einen Bon auch an, wenn Tag oder Summen nicht passen, und schreibt dann einen Bericht.
- Sicherung täglich nach 3 Uhr, 14 Stück, mit dem Standard-Werkzeug; Fotos sind nicht dabei.
- Der Satz in der Rückfrage vor dem Koppeln wird ergänzt.

Nach dem Gegenlesen durch einen zweiten Prüfer am 19.11.2026 dazugekommen:

- Ein Tablet, das beim Update schon gekoppelt ist, schickt ein Mal seine Preise, Favoriten, "Im Verkauf", Pfand und Kennzeichen hinauf und gewinnt damit gegen den Server.
- Beim Koppeln verfallen wartende Artikel-Änderungen. An einem Tablet ohne Kopplung entstehen keine.
- Protokoll der Signatur und Tage hängen am Gerät (eine Kennung pro Installation der App), nicht am Eintrag "Kassa". So bleibt eine Kette nach erneutem Koppeln ein Stück.
- Zur Übergabe wird der Server bei Railway neu ausgerollt und Version 1.5.0 über den geheimen Link bereitgestellt.
