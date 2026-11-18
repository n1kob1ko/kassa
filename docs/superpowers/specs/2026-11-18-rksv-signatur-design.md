# Kassa: RKSV-Signatur (Entwurf)

Stand: 18. November 2026. Auftrag von Niko im Thread: "Mach mal das rksv".
Dieser Entwurf führt Abschnitt 5.8 des Gesamt-Entwurfs (`2026-11-17-kassa-design.md`) aus. Wo beide sich widersprechen, gilt dieser, und die Abweichung steht in Abschnitt 5.

## 1. Worum es geht und warum

Jeder Bon einer Registrierkasse in Österreich muss elektronisch signiert, mit dem vorigen Bon verkettet und in ein Protokoll geschrieben werden (Registrierkassensicherheitsverordnung, RKSV). Am Bon steht dafür ein QR-Code. Ohne das darf YICHI mit der Kassa nicht echt verkaufen. Bis jetzt trägt jeder Bon den Vermerk "TESTBON".

Erfolg heißt: Die Kassa erzeugt Bons, ein Protokoll und Sonderbelege, die das Prüfwerkzeug des Finanzministeriums ohne Fehler annimmt, und der Startbeleg von YICHI besteht die Prüfung mit der App "BMF Belegcheck".

## 2. Was schon feststeht

- **Chipkarte zuerst** (Niko, 17.11.2026): YICHI verwendet vorerst die vorhandene Signaturkarte. Ein Online-Dienst kommt später.
- **Signatur hinter einer Schnittstelle.** Der Wechsel der Signatur (Karte, später Online-Dienst) darf den Rest der Kassa nicht berühren.
- **Bonieren geht immer weiter.** Fällt die Signatur aus, verkauft die Kassa weiter und kennzeichnet die Bons.
- **Anmeldung bei FinanzOnline macht ein Mensch** (Betrieb oder Steuerberatung). Die Kassa zeigt die Angaben dafür.
- **Android-Tablet**, ein USB-Anschluss, also Verteiler mit Ladeeingang für Kartenleser und Drucker.
- **Touch-Regel:** Keine Texteingabe an der Theke. Die PIN der Karte kommt über ein Zahlenfeld.
- **Öffentliches Repo:** keine Schlüssel, keine PIN, keine echten Umsätze im Repo.
- **Ab der ersten übergebenen Installationsdatei:** jede Änderung an der Datenbank braucht eine Migration mit Test.

## 3. Was die Recherche am 18.11.2026 ergeben hat

| Punkt | Ergebnis | Quelle | Sicherheit |
| --- | --- | --- | --- |
| Aufbau des Codes, Verkettung, Umsatzzähler | Der Mustercode des Finanzministeriums legt jedes Detail fest und ist lesbar. Er ist die Vorlage für den Bau. | github.com/BMF-RKSV-Technik/at-registrierkassen-mustercode (Quelltext gelesen) | hoch |
| Prüfwerkzeug | Version 1.1.0, zwei Java-Programme: eines prüft die Ausgabe des Protokolls, eines einzelne QR-Codes. Braucht eine Datei mit Schlüssel und Zertifikaten. | README desselben Repos | hoch. Die Datei selbst konnte von hier nicht geladen werden (bei Niko angefragt). |
| Karten laufen ab | Karten vom Typ ACOS-ID 2.1 erfüllen seit 7. Juni 2025 die Anforderungen nicht mehr, dürfen übergangsweise weiterlaufen und müssen bis spätestens Mai 2027 getauscht sein. CardOS 5.3 ist voraussichtlich bis Mai 2027 betroffen. A-Trust verkauft die "nächste Kartengeneration". | bmf.gv.at, Seite "Ablauf der Bescheinigung für RKSV Signaturkarten" | hoch |
| 4,9 % Umsatzsteuer | Seit 1. Juli 2026 für ausgewählte Nahrungsmittel. Der Betrag steht im Code im Feld "Betrag-Satz-Besonders", zusammen mit 19 %. Am Bon steht der Satz getrennt. | Mitteilung im README des BMF-Repos vom 13.03.2026, Entwurf der Verordnung auf bmf.gv.at | mittel: gelesen als Ankündigung und Entwurf, nicht als kundgemachter Text |
| Digitaler Bon | Seit 1. Oktober 2026 soll ein digitaler Bon die Belegpflicht erfüllen (zum Beispiel QR-Code an der Kundenanzeige). Freiwillig. | Blog eines Kassenherstellers | niedrig, am Gesetz zu prüfen |
| Wortlaut der RKSV (§§ 6 bis 17, Anlage) | Nur in Teilen gelesen. Das Rechtsinformationssystem ist von hier nicht erreichbar (bei Niko angefragt). | gesetzefinden.at (lückenhaft) | Der Wortlaut wird vor dem Bau der bindenden Teile geprüft, siehe Abschnitt 9. |
| Befehle der A-Trust-Karte | Erledigt am 18.11.2026: A-Trust veröffentlicht die Befehle der Karte. "Karte prüfen" liest damit das Zertifikat und erstellt eine Probe-Unterschrift, siehe 6.9 und Abschnitt 11. Zuerst stand hier: noch keine Unterlage gefunden, öffentlich nur der Treiber `card-atrust-acos.c` im Projekt OpenSC. | Unterlagen von A-Trust | hoch für die Befehle, an echter Hardware noch ungeprüft |

Folge aus dem Ablauf der Karten: Welche Karte YICHI hat, entscheidet, ob sich der Bau für diese Karte überhaupt lohnt. Ist es eine der beiden alten Arten, muss YICHI bis Mai 2027 ohnehin eine neue Karte kaufen, und die Kassa sollte dann gleich für die neue gebaut werden.

## 4. Ziele, Nicht-Ziele, Anti-Ziele

**Ziele**

1. Jeder Bon (Verkauf und Storno, bar und Karte) wird beim Abschließen signiert, verkettet und ins Protokoll geschrieben.
2. Der Bon trägt Kassen-Kennung, QR-Code und die Beträge je Steuersatz.
3. Sonderbelege: Startbeleg, Monatsbeleg, Jahresbeleg, Nullbeleg auf Wunsch, Sammelbeleg nach einem Ausfall, Schlussbeleg.
4. Ausfall der Signatur hält den Verkauf nie auf.
5. Das Protokoll lässt sich in der vorgeschriebenen Form als Datei ausgeben.
6. Ein Bildschirm "Karte prüfen" zeigt früh, ob Tablet, Verteiler, Leser und Karte zusammen funktionieren.
7. Alles ist ohne Hardware testbar, und die Ausgabe besteht das Prüfwerkzeug des Finanzministeriums.

**Nicht-Ziele (bewusst später)**

- Online-Signatur (fiskaly, A-Trust HSM).
- Anmeldung bei FinanzOnline durch die Kassa selbst.
- Digitaler Bon.
- Der Steuersatz 4,9 %. Er ändert das Format der Speisekarte in App und Server und betrifft zubereitete Speisen voraussichtlich nicht. Braucht ihn YICHI doch, wird er vorgezogen (Frage an die Steuerberatung, siehe 9).
- Übungsmodus mit eigenen Übungsbelegen.
- Abgleich des Protokolls zum Server (kommt mit Stufe C2 des Servers).
- Mehrere Signaturkarten pro Kassa, mehrere Kassen an einer Karte.

**Anti-Ziele (wäre ein Fehlschlag, auch wenn es technisch läuft)**

- Eine Kassa, die wegen der Signatur nicht verkaufen kann.
- Ein Bon, der echt aussieht, aber nicht gültig signiert ist. Solange die Kassa nicht mit echter Karte in Betrieb genommen ist, steht "TESTBON" am Bon.
- Eine Lücke oder ein doppelter Eintrag in der Kette nach einem Absturz.
- PIN oder Schlüssel im Klartext in der Datenbank, im Protokoll der App, im Fehlerbericht oder im Repo.

## 5. Wege

**A. Kartenversuch zuerst (so steht es im Gesamt-Entwurf).** Erst wenn Tablet und Karte nachweislich reden, wird der Rest gebaut. Vorteil: kein Bau auf Verdacht. Nachteil: Verteiler und Leser hängen noch nicht am Tablet, der Kartentyp ist unbekannt, und bis dahin steht alles.

**B. Kern zuerst, Karte als letzter Stecker (gewählt).** Protokoll, Kette, Zähler, QR-Code, Sonderbelege, Ausfall und Ausgabe braucht jede Signatur, auch ein späterer Online-Dienst. Das wird jetzt gebaut und mit einer Probe-Signatur am Tablet sichtbar. "Karte prüfen" wird als erstes Stück ausgeliefert, damit der Versuch stattfinden kann, sobald die Hardware da ist. Die Karte als echte Signatur folgt, wenn der Versuch gelungen und der Kartentyp bekannt ist. Vorteil: nichts wartet, nichts ist umsonst gebaut. Nachteil: Der Kern ist vor dem Kartenversuch fertig. Scheitert der Versuch, bleibt nur der Online-Dienst.

**C. Online-Signatur jetzt.** Kein Leser, kein Verteiler für die Signatur, keine ablaufende Karte. Niko hat das am 17.11.2026 abgelehnt, weil Anfrage und Vertrag dauern. Bleibt der Ausweg, falls der Kartenversuch scheitert oder die Karte getauscht werden muss und Niko dann lieber wechselt.

**Entscheidung:** B, von Claude gewählt, Niko am 18.11.2026 im Thread mitgeteilt. Abweichung vom Gesamt-Entwurf: dort stand der Kartenversuch vor allem anderen.

## 6. Entwurf

### 6.1 Zustände der Kassa

| Zustand | Bon | Signatur | Wie man hinkommt |
| --- | --- | --- | --- |
| Nicht eingerichtet | "TESTBON", kein QR-Code (wie heute) | keine | Auslieferungszustand |
| Probe | "TESTBON", mit QR-Code | Probe-Signatur: ein Schlüssel, den die Kassa selbst erzeugt | Einstellungen, Signatur, "Zum Ausprobieren einschalten" |
| In Betrieb | echter Bon mit QR-Code | Chipkarte | Einrichtung mit Karte, Startbeleg |
| In Betrieb, Signatur ausgefallen | echter Bon mit Vermerk "Sicherheitseinrichtung ausgefallen" | keine, bis sie wieder geht | von selbst |
| Außer Betrieb | wie "Nicht eingerichtet" | keine | "Kassa außer Betrieb nehmen" (Schlussbeleg) |

Der Wechsel von Probe zu In Betrieb beginnt eine neue Kette mit neuem Startbeleg und Umsatzzähler 0. Jeder Eintrag im Protokoll trägt die Nummer seiner Kette. Die Probe-Einträge bleiben stehen, werden aber nie ausgegeben; so wird im Protokoll nie etwas gelöscht. Die Bons selbst und ihre laufenden Nummern bleiben.

Bons aus der Zeit vor der Inbetriebnahme (ohne Signatur oder mit Probe-Signatur) lassen sich nach der Inbetriebnahme nicht mehr stornieren. Die Kassa sagt dann: "Dieser Bon stammt aus der Testzeit und kann nicht storniert werden." Sonst würde ein Storno den echten Umsatzzähler verringern, ohne dass es einen signierten Verkauf dazu gibt.

Die Probe dient nur dazu, dass Niko den Kern am Tablet sieht, bevor die Karte geht. Sie darf nie mit dem echten Betrieb verwechselt werden: "TESTBON" am Bon, in den Einstellungen "Probe-Signatur, nicht für den echten Betrieb".

### 6.2 Der Ablauf bei jedem Bon

1. Die Kassa bestimmt die laufende Nummer und die Beträge je Steuersatz (beides gibt es schon).
2. Sie zählt die Summe in Cent zum Umsatzzähler dazu (Storno zieht ab) und verschlüsselt den neuen Stand.
3. Sie bildet den Kettenwert aus dem vorigen Eintrag.
4. Sie baut den Text des Codes und lässt ihn signieren. Dafür gilt eine kurze Frist (Vorschlag 5 Sekunden). Antwortet die Signatur nicht oder mit Fehler, wird der Bon als "Sicherheitseinrichtung ausgefallen" gekennzeichnet.
5. Bon, Zahlung, Protokoll-Eintrag und neuer Zählerstand werden in **einem** Schritt in die Datenbank geschrieben. Entweder steht alles oder nichts.
6. Der Bon wird gedruckt.

Es wird immer nur ein Bon zugleich abgeschlossen, weil die Kette eine feste Reihenfolge braucht.

### 6.3 Der Code im Einzelnen

Vorlage ist der Mustercode des Finanzministeriums. Der Plan schreibt jeden Wert daraus ab und belegt ihn mit einem Testfall. Hier steht, was die Kassa damit tut.

- **Felder in dieser Reihenfolge**, getrennt durch `_`: Kennzeichen `R1-AT1` (Stufe 1, A-Trust; bei einem anderen Aussteller dessen Kennzeichen aus dem Zertifikat), Kassen-Kennung, Belegnummer, Datum und Uhrzeit (Ortszeit ohne Zeitzone, `2026-11-18T13:05:09`), fünf Beträge, verschlüsselter Umsatzzähler, Seriennummer des Zertifikats, Kettenwert.
- **Fünf Beträge** mit Komma und zwei Nachkommastellen, ohne Tausenderpunkt: Normal (20 %), Ermäßigt-1 (10 %), Ermäßigt-2 (13 %), Null (0 %), Besonders (19 %). Die Kassa führt diese fünf Summen pro Bon-Zeile schon. Pfand wird heute ohne Umsatzsteuer geführt und zählt deshalb zu Null (zu klären, siehe 9).
- **Umsatzzähler:** Summe aller Beträge in Cent, 8 Byte, verschlüsselt mit AES-256 im Zählermodus. Der Startwert der Verschlüsselung entsteht aus Kassen-Kennung und Belegnummer. Beim Storno steht statt des Zählers das Kürzel für Storno, der Zähler wird trotzdem verringert.
- **Kettenwert:** die ersten 8 Byte der SHA-256-Summe des vorigen Eintrags, beim Startbeleg der Kassen-Kennung.
- **Signatur:** ECDSA mit der Kurve P-256 über SHA-256, als JWS mit dem Kopf `{"alg":"ES256"}`. Im Protokoll steht die kompakte JWS-Form, im QR-Code der Text mit angehängter Signatur.
- **Ausfall:** An der Stelle der Signatur steht der feste Text "Sicherheitseinrichtung ausgefallen" in der vorgeschriebenen Kodierung.

### 6.4 Sonderbelege

Sonderbelege sind Bons mit Betrag 0 und einer eigenen Art. Sie bekommen eine laufende Nummer aus derselben Reihe wie Verkäufe, erscheinen in der Liste der Bons mit ihrer Bezeichnung und zählen in Übersicht und Abschluss nicht als Verkauf.

Ein Sonderbeleg gehört zu keinem Tag: Er öffnet keinen Tag und löst keinen Hinweis auf einen vergessenen Abschluss aus. Als Mitarbeiter steht, wer gerade angemeldet ist. Das ist immer jemand, denn die Belege, die von selbst entstehen (Monatsbeleg, Jahresbeleg, Sammelbeleg), entstehen in dem Moment, in dem ein angemeldeter Mitarbeiter den ersten Bon abschließt, und die übrigen löst der Chef aus.

| Beleg | Wann | Was die Kassa tut |
| --- | --- | --- |
| Startbeleg | bei der Inbetriebnahme | erzeugen, drucken, Aufgabe "Mit BMF Belegcheck prüfen" anzeigen |
| Monatsbeleg | vor dem ersten Bon in einem neuen Kalendermonat | von selbst erzeugen, nicht drucken |
| Jahresbeleg | der Monatsbeleg, der das Jahr abschließt | von selbst erzeugen und drucken, Aufgabe "Mit BMF Belegcheck prüfen, bis 15. Februar" anzeigen |
| Nullbeleg | auf Wunsch, etwa bei einer Kontrolle | Taste in den Einstellungen, drucken |
| Sammelbeleg | wenn die Signatur nach einem Ausfall wieder geht | von selbst vor dem nächsten Bon |
| Schlussbeleg | "Kassa außer Betrieb nehmen" | erzeugen, drucken, Kassa geht in "Außer Betrieb" |

Eine Aufgabe ist eine Zeile auf dem Bildschirm Einstellungen, Signatur, mit einer Taste "Erledigt". Offene Aufgaben zeigt auch der Bildschirm Abschluss. Sie sperren nichts.

Fristen und genaue Bedingungen (welcher Monatsbeleg der Jahresbeleg ist, was bei einem ganzen Monat ohne Betrieb gilt, Frist für die Prüfung des Startbelegs) werden vor dem Bau am Wortlaut geprüft, siehe 9.

### 6.5 Ausfall der Signatur

- Erkennt die Kassa beim Signieren einen Fehler oder läuft die Frist ab, gilt die Signatur als ausgefallen. Der Zeitpunkt wird gespeichert.
- Solange der Ausfall dauert: Jeder Bon bekommt den Vermerk, sichtbar am Bon und im Code. Die Kassa versucht bei jedem Bon einmal zu signieren, ohne den Verkauf zu verzögern (nach dem ersten Fehlschlag mit kürzerer Frist, Vorschlag 1 Sekunde). In der Kassa steht ein ruhiger Hinweis "Signatur ausgefallen seit 13:05" mit der Taste "Nochmal prüfen".
- Geht die Signatur wieder: Die Kassa erzeugt den Sammelbeleg und entfernt den Hinweis.
- Dauert der Ausfall länger als 48 Stunden: Aufgabe "Ausfall bei FinanzOnline melden" mit Beginn und Grund zum Abschreiben. Nach dem Ende: Aufgabe "Ende des Ausfalls melden".
- Fällt die Kassa selbst aus (Tablet kaputt), ist das kein Fall für die Software. Die Prüfliste nennt, was dann zu tun ist.

### 6.6 Daten

Neue Version der Datenbank mit Migration und Test.

- `receipts.kind` bekommt die Arten der Sonderbelege. Der Verweis auf den Tag darf bei Sonderbelegen leer sein.
- Neue Tabelle **Protokoll**: ein Eintrag je Bon mit Nummer der Kette, laufender Stelle in der Kette, Verweis auf den Bon, der kompakten JWS-Form, dem Kennzeichen "Signatur ausgefallen" und der Seriennummer des Zertifikats. Einträge werden nie geändert und nie gelöscht. Die Datenbank erzwingt das wie bei den Bons.
- Neue Tabelle **Signatur-Stand** mit genau einer Zeile: Zustand (6.1), Kassen-Kennung, Umsatzzähler in Cent, Beginn eines Ausfalls, letzter Monat mit Monatsbeleg, Zertifikat und Aussteller-Zertifikate, offene Aufgaben.
- **Nicht in der Datenbank:** der AES-Schlüssel, der Schlüssel der Probe-Signatur und die PIN der Karte. Sie liegen im geschützten Speicher von Android (`flutter_secure_storage`, schon im Projekt).
- Die Kassen-Kennung erzeugt die Kassa selbst (Buchstaben und Ziffern, kurz genug zum Abtippen in FinanzOnline). Sie wird nie getippt. Sie bleibt vorerst nur auf dem Tablet. Der Server übernimmt sie mit dem Abgleich in Stufe C2.

Wird die App nach der Inbetriebnahme gelöscht, ihre Daten gelöscht oder das Tablet zurückgesetzt, sind Protokoll, Kette und Zählerstand weg. Der AES-Schlüssel ist dann noch bei FinanzOnline hinterlegt und steht auf dem ausgedruckten Zettel (6.8). Wiederherstellung auf einem neuen Tablet gehört zur Stufe C2 des Servers und ist hier kein Ziel. Bis dahin ist die ausgegebene Datei (6.11) die einzige Sicherung. Deshalb steht vor S3 eine Entscheidung von Niko, siehe 9.

### 6.7 Signatur-Schnittstelle

Eine Schnittstelle mit zwei Aufgaben: Auskunft geben (Aussteller-Kennzeichen, Seriennummer, Zertifikat) und einen Text signieren. Drei Umsetzungen:

1. **Attrappe** für Tests, mit festem Schlüssel, und einstellbar auf "antwortet nicht" und "antwortet mit Fehler".
2. **Probe-Signatur** für den Zustand Probe: Schlüssel und selbst ausgestelltes Zertifikat, auf dem Tablet erzeugt.
3. **Chipkarte** (Stufe 2): Kartenleser am USB-Anschluss.

Die Chipkarte besteht aus zwei Schichten. Unten ein kleiner Kotlin-Teil, der Kartenleser am USB-Anschluss findet, die Karte einschaltet und Befehle hin und her reicht. Darüber, in Dart, die Befehle der Karte (Anwendung wählen, PIN prüfen, Zertifikat lesen, signieren). So lässt sich die obere Schicht mit einer Attrappe des Lesers testen. Der vorhandene USB-Teil für den Drucker bleibt unberührt; Leser und Drucker hängen als zwei Geräte am Verteiler.

### 6.8 Einrichtung und FinanzOnline

Der Weg "Signatur einrichten" in den Einstellungen, nur für den Chef:

1. Karte prüfen (6.9), PIN über das Zahlenfeld eingeben. Die PIN wird verschlüsselt gespeichert.
2. Die Kassa erzeugt Kassen-Kennung und AES-Schlüssel und zeigt die **Angaben für FinanzOnline**: Kassen-Kennung, AES-Schlüssel mit Prüfwert, Seriennummer des Zertifikats. Taste "Angaben drucken" druckt sie auf einen Zettel zum Abtippen und Aufheben.
3. Hinweis mit den Schritten, die ein Mensch tun muss: an der alten Kassa den Schlussbeleg erstellen, die neue Kassa in FinanzOnline anmelden.
4. "Jetzt in Betrieb nehmen": Startbeleg erzeugen und drucken. Ab jetzt sind die Bons echt.

Vor Schritt 4 fragt die Kassa einmal deutlich nach, weil der Schritt nicht zurückgenommen werden kann.

### 6.9 Karte prüfen

Ein Bildschirm in den Einstellungen, der ohne eingerichtete Signatur funktioniert. Er zeigt Zeile für Zeile, was geht, mit grünem Haken oder rotem Kreuz und einem Satz in einfachen Worten:

1. Kartenleser gefunden (Name des Geräts).
2. Zugriff erlaubt (Android fragt einmal).
3. Karte erkannt (Antwort der Karte beim Einschalten, daraus die Art der Karte).
4. Zertifikat gelesen (Aussteller, Seriennummer, gültig bis).
5. Nach Eingabe der PIN: Probe-Unterschrift erstellt und auf dem Tablet gegen das Zertifikat geprüft.

Unten die Taste "Bericht teilen". Der Bericht enthält die Zeilen, die Art des Lesers und die rohen Antworten der Karte, aber nie die PIN. Niko schickt ihn in den Thread. Schlägt eine Zeile fehl, steht dort, was Niko tun kann (anderer Anschluss, Karte anders herum, Verteiler ohne Strom).

Die PIN-Eingabe warnt: Nach drei falschen Versuchen sperrt sich die Karte. Der Bildschirm zeigt die verbleibenden Versuche, wenn die Karte sie nennt, und fragt nach einem Fehlversuch nicht von selbst erneut.

Dieser Bildschirm ist der Machbarkeitstest aus dem Gesamt-Entwurf. Er wird als erstes Stück ausgeliefert.

**Schutz der Karte.** YICHI hat nur diese eine Karte, und ein falscher Befehl mit der PIN kann einen der drei Versuche kosten. Deshalb gilt:

- Die Zeilen 1 bis 4 schicken nie eine PIN und laufen für jede Karte. Eine unbekannte Karte zeigt der Bildschirm mit ihrer rohen Antwort an, statt zu raten.
- Zeile 5 gibt es nur für Kartenarten, deren Befehle aus einer belegten Quelle stammen (Unterlage von A-Trust oder der Treiber von OpenSC für genau diese Art). Für alle anderen ist die Taste gesperrt, mit dem Satz "Für diese Karte ist die PIN-Prüfung noch nicht freigegeben. Schick mir den Bericht."
- Die PIN wird nur nach einem ausdrücklichen Antippen geschickt, genau einmal, nie von selbst wiederholt. Wo die Karte es erlaubt, fragt die Kassa vorher die verbleibenden Versuche ab und schickt bei nur noch einem Versuch nichts mehr.

Welche Kartenarten Zeile 5 in S1 freigibt, legt der Plan anhand der gefundenen Unterlagen fest. Es ist in Ordnung, wenn S1 mit keiner freigegebenen Art ausgeliefert wird: Der Bericht aus den Zeilen 1 bis 4 nennt dann die Art der Karte, und Zeile 5 folgt in einer nächsten Version.

### 6.10 Bon und Bildschirme

- **Bon:** Kassen-Kennung im Kopf, QR-Code unter den Summen, darunter bei Ausfall der Satz "Sicherheitseinrichtung ausgefallen". "TESTBON" bleibt in den Zuständen "Nicht eingerichtet" und "Probe". Der QR-Code wird über den QR-Befehl des Druckers gedruckt. Kann ein Drucker das nicht, druckt die Kassa ihn als Bild (Schalter in den Drucker-Einstellungen).
- **Liste der Bons:** Der Bon zeigt den QR-Code am Bildschirm. Sonderbelege stehen mit ihrer Bezeichnung in der Liste.
- **Einstellungen, Karte "Signatur":** Zustand in einem Wort (wie bei der Karte "Server"), offene Aufgaben, Tasten "Karte prüfen", "Signatur einrichten", "Nullbeleg drucken", "Protokoll ausgeben", "Kassa außer Betrieb nehmen". Nur der Chef sieht die Tasten.
- **Kassa:** bei Ausfall der Hinweis aus 6.5, sonst nichts Neues. Der Verkauf wird durch die Signatur nicht langsamer als die Frist aus 6.2.

Alle neuen Bildschirme folgen `docs/design-regeln.md` und dem bestehenden Stil. Claude zeichnet die neuen Bildschirme als erste Aufgabe des Plans und zeigt sie Niko. Der Bau der Bildschirme beginnt, sobald Niko die Bilder bekommen hat, und wartet nicht auf eine Antwort (wie in Teil C). Der Rechenkern hängt nicht davon ab.

### 6.11 Protokoll ausgeben

"Protokoll ausgeben" schreibt eine Datei in der Form des Finanzministeriums (eine Gruppe je Zertifikat, darin die Einträge in Reihenfolge) an einen Ort, den der Chef über das Android-Fenster wählt, zum Beispiel einen USB-Stick oder Google Drive. Zur Auswahl: alles oder ein Zeitraum. Zu Beginn jedes Vierteljahres zeigt die Kassa die Aufgabe "Protokoll sichern" (Pflicht und Frist am Wortlaut zu prüfen, siehe 9).

### 6.12 Wie geprüft wird

- **Rechenkern** (Zähler, Verschlüsselung, Kette, Code, JWS): Tests mit festen Werten. Die Werte stammen aus dem Mustercode des Finanzministeriums, der dafür auf dem Bau-Rechner ausgeführt wird, nicht aus eigener Rechnung.
- **Ganze Abläufe** mit der Attrappe: Verkauf, Storno, Monatswechsel, Jahreswechsel, Ausfall und Sammelbeleg, Absturz zwischen Signieren und Speichern, Wechsel von Probe zu In Betrieb.
- **Prüfwerkzeug des Finanzministeriums:** Ein Skript im Repo erzeugt mit der Attrappe ein Protokoll samt der Datei mit Schlüssel und Zertifikat und lässt beide Programme darüber laufen. Das Prüfwerkzeug selbst kommt nicht ins Repo (sein Quelltext ist nicht offen); es liegt unter `/mnt/project-files/kassa-build/rksv/`. Fehlt es, bricht das Skript mit einem klaren Satz ab.
- **Wann S1 fertig ist:** wenn die Tests mit den Werten aus dem Mustercode bestehen und das Skript für das Prüfwerkzeug da ist. Liegt das Prüfwerkzeug bis dahin nicht vor, wird S1 trotzdem ausgeliefert, und der Lauf bleibt als offener Punkt stehen. S2 wird erst geplant, wenn der Lauf ohne Fehler durch ist.
- **Migration:** Test von der heutigen Datenbank auf die neue, mit vorhandenen Bons.
- **Hardware:** Jeder Versuch am Tablet kommt mit einer Prüfliste zum Abhaken (`docs/testen/`).

## 7. Stufen

| Stufe | Inhalt | Niko bekommt |
| --- | --- | --- |
| S1 | "Karte prüfen" (6.9). Der Kern mit Probe-Signatur: Code, Kette, Zähler, QR-Code am Bon, Sonderbelege, Ausfall, Protokoll ausgeben. Prüfung mit dem Werkzeug des Finanzministeriums. | Eine Installationsdatei mit "Karte prüfen" und dem Zustand Probe, dazu eine Prüfliste. Sein Bericht aus "Karte prüfen" entscheidet über S2. |
| S2 | Chipkarte als echte Signatur, Einrichtung (6.8), Angaben für FinanzOnline. Eigener Plan, sobald Kartentyp und Bericht da sind. | Eine Installationsdatei, mit der YICHI in Betrieb gehen kann. |
| S3 | Inbetriebnahme bei YICHI: Schlussbeleg an der alten Kassa, Anmeldung, Startbeleg, Prüfung mit BMF Belegcheck. | Eine Prüfliste für den Tag der Umstellung. Das tut Niko mit dem Betrieb. |

Scheitert der Kartenversuch oder muss die Karte getauscht werden, entscheidet Niko vor S2 neu: neue Karte oder Online-Dienst. S1 gilt in beiden Fällen unverändert.

Der erste Plan umfasst nur S1. Von S2 legt er nur die Schnittstelle fest (6.7). Die Abschnitte 6.7 (Chipkarte) und 6.8 beschreiben S2, damit S1 nichts verbaut.

## 8. Technik-Festlegungen (Claude)

- Rechenkern in Dart unter `app/lib/rksv/`, ohne Abhängigkeit zur Oberfläche.
- Neue Pakete: `pointycastle` (AES, ECDSA, Zertifikate lesen) und `qr` (QR-Code am Bildschirm). Beide reines Dart.
- Kotlin nur für den USB-Kartenleser (Stufe 2 und "Karte prüfen").
- Der Server bleibt unberührt.

## 9. Offen

**Bei Niko (angefragt am 18.11.2026)**

1. Typ oder Kaufjahr der Signaturkarte von YICHI und Modell des Kartenlesers.
2. Die zwei Dateien des Finanzministeriums (`regkassen-verification-1.1.0.zip`, `regkassen-test-cases-1.0.0.zip`).
3. Freigabe von `www.ris.bka.gv.at` für den Wortlaut.

**Bei YICHI oder der Steuerberatung**

4. Fällt etwas aus dem Angebot von YICHI unter 4,9 %?
5. Einwegpfand: mit oder ohne Umsatzsteuer, und mit welchem Satz am Bon und im Code?
6. Wer meldet die Kassa in FinanzOnline an, und wann wird umgestellt?

**Entscheidung von Niko vor S3**

6a. Geht YICHI in Betrieb, bevor der Server das Protokoll sichert (Stufe C2)? Dann ist die ausgegebene Datei die einzige Sicherung, und ein verlorenes Tablet heißt ein verlorenes Protokoll. Claudes Rat: C2 vor S3 bauen.

**Prüft Claude am Wortlaut, bevor der betroffene Teil gebaut wird**

7. Pflichtangaben am Bon (§ 11) und Form der Beträge im Code (Anlage).
8. Monats- und Jahresbeleg: Bedingungen, Druck, Frist der Prüfung (§ 8).
9. Startbeleg: Frist der Prüfung (§ 6).
10. Ausfall: 48 Stunden, Frist und Inhalt der Meldung, Sammelbeleg (§ 17).
11. Sicherung des Protokolls: Vierteljahr, Ort, Aufbewahrung (§ 7).
12. Storno und Seriennummer des Zertifikats im Code: genaue Form laut Mustercode und Festlegungen des BMF.
13. Ob Bargeld einlegen und entnehmen ins Protokoll gehört (nach heutigem Stand nein, weil es keine Barumsätze sind).

## 10. Dem Bau überlassen

Namen von Klassen und Tabellen, Aufteilung in Dateien, genaue Fristen in Sekunden, Aussehen der Zeilen im Bildschirm "Karte prüfen" innerhalb der Design-Regeln, Form des gedruckten Zettels mit den Angaben für FinanzOnline.

## 11. Abweichungen beim Bau

Hier steht, was beim Bau anders entschieden wurde, als der Entwurf es oben beschreibt oder offenlässt, und was es kostet. Der Stand gilt für die Version 1.3.0.

### 11.1 S1a "Karte prüfen"

**Was anders ist als in 6.9.** Zeile 5 (Probe-Unterschrift mit PIN) ist schon in der ersten Version dabei, nicht erst in einer späteren. Die Befehle von A-Trust liegen vor, und die Kassa gibt Zeile 5 für fünf Kartenarten frei: die erste Generation (ACOS), CardOS 5.3, ACOS-ID 2.1, ACOS-ID 3 und ACOS-ID 4.1. Für jede andere Karte zeigt der Bildschirm ihre rohe Antwort und sperrt die PIN-Prüfung wie in 6.9 beschrieben. Der Satz dazu lautet im Bau "Für diese Karte ist die Probe-Unterschrift nicht freigegeben." und nicht wie in 6.9 "Für diese Karte ist die PIN-Prüfung noch nicht freigegeben. Schick mir den Bericht." (die Bitte um den Bericht steht in Zeile 3, beim Hinweis mit der Antwort der Karte; Zeile 5 nennt sie nicht).

6.9 sagt, die PIN gehe genau einmal zur Karte. Im Bau geht sie nach einer richtigen PIN dreimal hinaus: einmal für die erste Probe-Unterschrift und zweimal für die Messung der Dauer (K5). Nach einer falschen PIN wird nichts von selbst wiederholt.

**Entscheidungen im Plan**

| Nr. | Entscheidung | Warum | Preis |
|---|---|---|---|
| K1 | Die Kassa handelt mit der Karte keine höhere Geschwindigkeit aus. | Ein Schritt weniger, der an einer einzigen Karte schiefgehen kann. | Das Zertifikat lesen dauert rund eine Sekunde länger. |
| K2 | Nur das Protokoll T=1, kein T=0. | A-Trust schreibt T=1 vor. | Eine fremde Karte mit T=0 zeigt "kennt die Kassa nicht". |
| K3 | Der USB-Teil des Druckers wird nicht angefasst. Die Frage nach der USB-Erlaubnis steht ein zweites Mal im neuen Kanal. | Entwurf 6.7: Der Drucker-Teil bleibt unberührt. | Rund 80 Zeilen doppelt. |
| K4 | Der Bericht geht als Text über das Teilen-Fenster von Android. | Kein neues Paket, funktioniert mit Mail und Messenger. | Kein Anhang als Datei. |
| K5 | Nach einer gelungenen Probe-Unterschrift folgen zwei weitere, um die Dauer zu messen. | Die Dauer entscheidet, ob die Karte die Frist von 5 Sekunden pro Bon hält. | Zwei Sekunden länger, und die PIN geht nach einer richtigen PIN dreimal zur Karte statt einmal. |
| K6 | Ein PIN-Wächter merkt sich einen Fehlversuch und schickt bei nur noch einem Versuch keine PIN mehr. | YICHI hat nur diese eine Karte. | Ein Dialog mehr, falls der Zähler in der alten Kassa wieder aufgefüllt wurde. |
| K7 | Die PIN wird in S1a nicht gespeichert. | Sie wird erst bei der Einrichtung gebraucht (S2). | Für jede Probe neu eingeben. |

**Entscheidungen während des Baus**

| Entscheidung | Warum | Preis |
|---|---|---|
| Die Frist von 20 Sekunden beginnt erst, wenn der Leser geöffnet ist, also nach dem Fenster, in dem Android um die Erlaubnis fragt. | Wer zum ersten Mal erlaubt, braucht länger als 20 Sekunden zum Lesen und Antippen. Ein Abbruch bei offenem Fenster zeigte "Das hat zu lange gedauert." über dem Fenster von Android. | Der allererste Lauf kann wegen der Frage von Android etwa eine Minute länger dauern (die Frage selbst endet nach 60 Sekunden). |
| Schließt der Bildschirm den Leser, wird eine offene Frage nach der Erlaubnis abgebrochen. | Sonst bliebe eine Frage hängen, die niemand mehr beantwortet. | Keiner. |
| Nach einer verlorenen Verbindung ist die Sitzung tot und schickt nichts mehr. | Ein späterer Block ginge mit veralteter Blocknummer hinaus. Der Schutz der Karte soll nicht davon abhängen, dass der Bildschirm sich richtig verhält. | Keiner: Ein Lauf endet nach einer verlorenen Verbindung ohnehin. |
| Befehle und Kartenarten lassen sich von außen nicht bauen (`final class`, kein öffentlicher Konstruktor). | Es gibt keinen Weg, einen frei zusammengesetzten Befehl an die Karte zu schicken. | Eine neue Kartenart braucht eine Änderung im Code der Kassa, keine Einstellung. |
| Der PIN-Wächter schreibt voraus: Bevor die PIN zur Karte geht, steht die vorsichtig gezählte Zahl der Versuche im Speicher (einen weniger als bekannt, oder 2, wenn nichts bekannt ist). Bei Erfolg wird sie gelöscht, die echte Antwort der Karte überschreibt sie. Ist das Schreiben nicht möglich, geht keine PIN hinaus. | Ein Ausgang, bei dem keine Antwort kam (Verbindung weg, Zeit abgelaufen, Absturz), muss gegen die Versuche zählen. Sonst könnte die nächste falsche PIN die Karte sperren. | Bricht die Verbindung bei richtiger PIN ab, rechnet die Kassa mit einem Versuch weniger. Bei unbekanntem Stand (2 angenommen) zeigt die Zeile nur "Die Verbindung zur Karte ist abgebrochen." mit einem Hinweis, und die PIN bleibt möglich. Erst beim zweiten Mal, oder wenn schon nur noch zwei Versuche bekannt waren, verweigert die Kassa die PIN, obwohl die Karte in Ordnung ist. Dann hilft nur "Zähler ist wieder voll", nachdem die Karte in der alten Kassa mit der richtigen PIN benutzt wurde. Dazu kommen zwei Schreibvorgänge pro Runde, also sechs pro erfolgreichem Lauf. |
| Die niedrigste bekannte Zahl der Versuche liegt zusätzlich im Arbeitsspeicher. | Fällt der Speicher auf dem Tablet aus, soll die Kassa trotzdem nicht mehr Versuche annehmen, als sie sicher weiß. | Nach einem Neustart der App und kaputtem Speicher fehlt dieses Wissen, die Kassa schickt dann keine PIN. |
| Ist die Karte wirklich gesperrt (Zähler 0, Antwort "Karte gesperrt"), zeigt der Bildschirm "Zähler ist wieder voll" nicht an. | Die Taste würde eine gesperrte Karte als benutzbar ausgeben. Hilfe gibt dort nur A-Trust. | Keiner. |
| Der Bericht vermerkt eine Karte, die ihre Geschwindigkeit fest vorgibt (ACOS-ID 2.1). | Kann ein Leser das nicht, bricht die Verbindung ab. Der Hinweis erspart die Suche. | Eine Zeile mehr im Bericht. |
| Fehlertexte aus dem Lesen des Zertifikats sind fest und nennen keine Bytes. | Aus einem Fehlertext sollen weder Teile des Zertifikats noch Bytes der Karte in den Bericht oder auf den Bildschirm gelangen. | Weniger Einzelheiten beim Suchen eines Fehlers. Die rohen Antworten stehen im Bericht. |
| Ein abgelaufenes Zertifikat ist ein Hinweis, kein Halt. Zeile 4 bleibt grün und sagt "Das Zertifikat ist seit … abgelaufen. Die Probe-Unterschrift geht trotzdem. Teil bitte den Bericht.", Zeile 5 wird angeboten. Der Bericht nennt das Ablaufdatum und das Datum am Tablet, mit dem verglichen wurde. | 6.9 verlangt an dieser Stelle keinen Halt. Die Stufe misst vor allem die Dauer der Unterschrift, und eine falsch gestellte Uhr am Tablet würde den Test sonst beenden. | Am Bildschirm steht bei einem abgelaufenen Zertifikat nicht, wer es ausgestellt hat (der Hinweis nimmt diesen Platz ein). Ein Zertifikat, das erst später gilt, unterscheidet die Kassa nicht. |
| Nach Ablauf der 20 Sekunden wird die Karte nicht mehr ausgeschaltet, nur der Leser freigegeben. | Hing die Übertragung, könnte auch der Befehl zum Ausschalten wieder hängen. | Die Karte bleibt bis zum Abziehen des Lesers oder bis zum nächsten Lauf eingeschaltet. |
| Jede Zeile im Protokoll des Berichts beginnt mit den Millisekunden seit dem Start. Scheitert eine Übertragung auf Android, steht im Bericht, welcher Schritt (`write` oder `read`) nach wie vielen Millisekunden und nach wie vielen Bytes scheiterte und was Android zurückgab. Bytes der Nachricht stehen dort nie. | Ohne echte Hardware hier lässt sich ein Fehler nur aus dem Bericht verstehen. | Der Bericht wird etwas länger. Am Bildschirm ändert sich nichts. |
| Vor VERIFY prüft die Kassa, ob es dieselbe Karte ist, an der Kartenart und der Kartennummer, nicht an der rohen ATR. | Manche Karten antworten nach dem ersten und nach einem weiteren Einschalten verschieden (kalte und warme ATR). Eine gesunde Karte zeigte sonst einmal "Das ist eine andere Karte. Prüf nochmal." | Keiner: Der Wächter gilt ohnehin je Kartennummer. |
| Beim Lesen des Zertifikats gilt eine Antwort `62xx` (etwa `6282`, Ende der Datei erreicht) als letzter Block mit Daten. Auf `6Cxx` (falsche Länge) liest die Kassa denselben Block genau einmal mit der genannten Länge neu. Ein zweites `6Cxx` gilt als nicht lesbar. | A-Trust nennt `6282` für READ BINARY, und andere Kartensoftware liest bei `6Cxx` still nach. Sonst fiele das Ende des Zertifikats weg. | Ein Befehl mehr in der festen Liste (READ BINARY mit genauer Länge, nur lesend). |

**Noch ungeprüft.** Hier gibt es weder Kartenleser noch Karte. Alles wurde gegen Nachbildungen getestet, der Kotlin-Teil wurde gebaut und gelesen, aber nie ausgeführt. Auf echter Hardware ist noch nichts bestätigt: Erkennen des Lesers im Verteiler neben dem Drucker, die Erlaubnisfrage von Android, die Übertragung (auch Antworten in Teilen und Bitten um mehr Zeit), das Lesen des Zertifikats, die Probe-Unterschrift mit der echten Karte von YICHI und ihre Dauer, der Hinweis zum Tausch und der Weg über "Zähler ist wieder voll". Das prüft Niko mit `docs/testen/rksv-karte-pruefen-pruefliste.md`.
