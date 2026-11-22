# Kassa: Signatur mit der Chipkarte (Stufe S2c)

Stand: 22.11.2026. Baut auf `2026-11-18-rksv-signatur-design.md` (Kern, "Karte prüfen", dort Stufe S2) und `2026-11-19-rksv-online-signatur-design.md` (Online-Signatur, Abschnitt 12: Stand von 1.7.0) auf. Wo dieser Text nichts sagt, gelten die beiden.

## 1. Worum es geht und warum

Niko will mit der Signaturkarte von A-Trust (a.sign RK CHIP) am USB-Kartenleser signieren, ohne Internet, so wie es seine Windows-Kassa tut (Niko, 20.11.2026: "wenn der Chip per USB eingebunden wird braucht es kein Internet"). In der Karte "Signatur" will er die Kassen-ID eingeben und den AES-Schlüssel sehen, den er für die Anmeldung der Kassa bei FinanzOnline braucht; die Karte wird dort mit der Seriennummer ihres Zertifikats angemeldet.

Version 1.6.0 am Tablet kann die Karte nur prüfen ("Karte prüfen": lesen und drei Probe-Unterschriften). Version 1.7.0 (gebaut, nicht ausgeliefert) kann den echten Betrieb, aber nur über A-Trust online. Diese Stufe macht die Karte zur dritten Signatureinheit neben Probe-Signatur und A-Trust online.

Niko hat zum Testen eine Karte einer anderen Kassa. Mit ihr darf nichts bei FinanzOnline angemeldet werden. Darum gibt es die Karte auch als Probe.

## 2. Ziele, Nicht-Ziele, Anti-Ziele

**Ziele**

1. "Mit Karte ausprobieren": Die Karte signiert jeden Bon einer Probe-Kette. Die Bons bleiben Testbons.
2. "Signatur einrichten" mit der Karte: Karte und PIN, Angaben für FinanzOnline, "Jetzt in Betrieb nehmen" mit Startbeleg von der Karte. Danach signiert die Karte jeden Bon.
3. Kein Internet für die Signatur mit der Karte.
4. Der Chef kann die Kassen-ID vor der Inbetriebnahme überschreiben (auf beiden Wegen, Karte und online).
5. Fehlt die Karte oder der Leser, verkauft die Kassa weiter (Ausfall wie bisher), und die Signatur kommt von selbst wieder, sobald die Karte wieder steckt.
6. Die Karte wird nie durch die Kassa gesperrt.

**Nicht-Ziele**

- Karte tauschen im laufenden Betrieb (neues Zertifikat in derselben Kette).
- Wechsel einer laufenden Kassa zwischen Karte und online.
- Karten anderer Anbieter, Protokoll T=0, kontaktlose Leser, mehrere Leser zugleich.
- Die sechs offenen Fragen aus 1.7.0 (Online-Entwurf 12.6), darunter der Ausweg bei einem verlorenen AES-Schlüssel.
- Änderungen am Server und an der Datenbank des Tablets (bleibt Version 6).

**Anti-Ziele**

- Eine PIN geht an eine andere Karte als die, für die sie eingegeben wurde.
- Die Kassa schickt eine PIN weiter, nachdem die Karte sie abgelehnt hat.
- Ein Bon wartet an der Theke auf ein Fenster von Android oder länger als die Frist des Journals.
- PIN, AES-Schlüssel oder Bytes eines Befehls mit PIN stehen in einem Bericht, einem Protokoll, einer Fehlermeldung, einem Test mit echten Werten oder im Repo.
- Ein Eintrag im Protokoll trägt eine Signatur, die nicht zum Zertifikat der Kette passt.

## 3. Vorgaben

- Touch-Regel: Getippt wird nur an zwei Stellen, beide nur für den Chef und nur in der Einrichtung: Zugangsdaten von A-Trust (wie bisher) und neu die Kassen-ID. Die PIN kommt über das Zahlenfeld.
- Öffentliches Repo: keine echten Zertifikate, Kartennummern, PINs, Schlüssel. Tests nehmen erfundene Werte und die Nachbildung des Lesers (`FakeCardReader`).
- Geheimnisse nur über `kassaSecureStorage` (`resetOnError: false`).
- Kein Test spricht mit einem echten System von A-Trust (Q11 gilt weiter).
- Alle Schutzregeln aus "Karte prüfen" gelten weiter: Befehle nur aus den Fabriken von `CardCommand`, VERIFY nur nach Vergleich von Kartenart und Kartennummer, PIN-Wächter.
- Hier gibt es weder Leser noch Karte. Alles wird gegen Nachbildungen getestet; der Kotlin-Teil wird gebaut und gelesen, nicht ausgeführt. Der erste echte Lauf ist Nikos Prüfliste.
- Version 1.8.0 Build 10. Aktualisiert von 1.6.0 und 1.7.0 ohne Umbau der Daten.

## 4. Was geprüft wurde (22.11.2026)

| Punkt | Ergebnis | Quelle |
| --- | --- | --- |
| Art der Sicherheitseinrichtung für eine Karte | `SIGNATURKARTE`; daneben `EIGENES_HSM` und `HSM_DIENSTLEISTER` | BMF, Registrierkassen-Webservice, Stand 12.05.2017, S. 3 |
| Anbieter | `AT1` für A-Trust | ebenda |
| Seriennummer | dezimal oder hexadezimal; FinanzOnline zeigt beide | ebenda; Handbuch 1/2021, 3.2.2 |
| AES-Schlüssel | Base64, 44 Zeichen. Nicht hexadezimal. | Webservice S. 4; Handbuch 3.3.1 |
| Prüfwert | "4-stelliger Code", freiwillig | Handbuch 3.3.1 |
| Kassenidentifikationsnummer | Weder Länge noch erlaubte Zeichen genannt | beide |
| Gründe für den Ausfall einer Signatureinheit | 1 Diebstahl oder sonstiger Verlust, 2 Signatur- bzw. Siegelerstellung unmöglich oder fehlerhaft, 99 Sonstiger Grund | Webservice, Punkt 4.1 |
| Fristen | Ausfall über 48 Stunden binnen einer Woche melden; Außerbetriebnahme der Kassa binnen einer Woche | Handbuch 3.2.4, 3.3.4 |

Der Kern von 1.7.0 nennt für Ketten an A-Trust online "Grund: 3, Ausfall der Verbindung zur Signaturerstellungseinheit" (aus dem Leitfaden der WKO). Die Liste des BMF kennt keine 3. Das wird in dieser Stufe nicht geändert und kommt auf die Liste für Niko.

## 5. Wege

**A. Die Karte bleibt zwischen den Bons eingeschaltet (gewählt).** Ein Halter besitzt den Leser, hält die Sitzung mit der Karte offen und prüft die PIN einmal je Sitzung. Ein Bon kostet dann einen Befehl zur Karte. Preis: Der Halter muss Abstecken, Wiederanstecken und den Bildschirm "Karte prüfen" sauber behandeln.

**B. Leser und Karte für jeden Bon neu öffnen.** So arbeitet "Karte prüfen" heute, das ist erprobt. Aber jeder Bon bräuchte Einschalten, Auswahl, PIN und Unterschrift, also mehrere Sekunden an der Theke und knapp an der Frist von 5 Sekunden. Verworfen.

**C. Erst verkaufen, später signieren.** Verboten: Der Code mit der Signatur steht am gedruckten Bon. Verworfen.

## 6. Entwurf

### 6.1 Einheiten und Zustände

`rksv_chains.unit` bekommt zwei neue Werte (Text ohne Einschränkung, keine Migration):

| Wert | Modus | Bon | Signiert von |
| --- | --- | --- | --- |
| `cardTest` | probe | Testbon mit QR-Code | Karte |
| `card` | live | echter Bon | Karte |

Kennung des Anbieters ist für beide `AT1`. Alle fünf Kartenarten, die "Karte prüfen" für die Probe-Unterschrift freigibt, gelten auch hier. Als Zertifikat der Kette gilt das von der Karte gelesene; Aussteller-Zertifikate gibt es keine (leere Liste im Protokoll).

Eine Kette `cardTest` verhält sich wie die Online-Probe: Ein Fehler der Einheit mit eigenem Satz ist ein Ausfall, ein unerwarteter Fehler beendet die Probe mit dem bekannten Hinweis. Eine Kette `card` verhält sich wie `atrust`: Jeder Fehler ist ein Ausfall (Q6).

### 6.2 Der Halter der Karte

Ein Halter für die ganze App. Er allein öffnet den Leser für das Signieren.

- **Sitzung:** Leser öffnen (ohne Frage von Android, siehe 6.6), Karte einschalten, Kartenart und Kartennummer mit der gespeicherten vergleichen, Ordner der Signatur wählen. Die Sitzung bleibt offen, bis ein Fehler der Verbindung sie beendet oder jemand sie freigibt.
- **Signieren:** mit offener Sitzung nur der Befehl zur Unterschrift (bei der ersten Generation davor der Hash). Antwortet die Karte "Sicherheitszustand nicht erfüllt", prüft der Halter die PIN einmal und unterschreibt noch einmal. Das erste Signieren einer Sitzung prüft die PIN gleich.
- **Prüfung der Signatur:** Jede Unterschrift wird am Tablet gegen das Zertifikat der Kette geprüft. Passt sie nicht: "Die Unterschrift der Karte passt nicht zum Zertifikat."
- **Aufwärmen:** Ohne offene Sitzung versucht der Halter im Hintergrund, eine zu öffnen: beim Start und Fortsetzen der App, nach jedem gescheiterten Signieren, bei "Nochmal prüfen" und wenn die Kassa in den Vordergrund kommt. Nie mehr als ein Versuch zugleich. So gelingt der nächste Bon innerhalb der kurzen Frist im Ausfall (1 Sekunde), und der Sammelbeleg entsteht von selbst.
- **Frist:** Die Frist setzt wie bisher das Journal. Läuft sie ab, arbeitet der Halter im Hintergrund zu Ende; eine dabei geöffnete Sitzung bleibt für den nächsten Bon.
- **Ein Bon zugleich:** Aufrufe laufen nacheinander.
- **"Karte prüfen":** Startet der Bildschirm einen Lauf, gibt der Halter zuerst seine Sitzung frei und öffnet erst wieder, wenn der Lauf zu Ende ist. Ein Bon in dieser Zeit ist ein Ausfall mit dem Satz "Die Karte wird gerade geprüft."

Sätze des Ausfalls (jeder ohne Geheimnis): "Kein Kartenleser gefunden.", "Der Zugriff auf den Kartenleser ist nicht erlaubt.", "Keine Karte im Kartenleser.", "Im Kartenleser steckt eine andere Karte.", "Die Karte hat die PIN abgelehnt.", "Die PIN der Karte fehlt.", "Die Karte antwortet nicht.", "Die Karte hat die Unterschrift abgelehnt.", "Die Unterschrift der Karte passt nicht zum Zertifikat.", "Die Karte wird gerade geprüft."

### 6.3 PIN

- Die PIN wird im geschützten Speicher abgelegt, zusammen mit Kartenart und Kartennummer, und nur, nachdem genau diese Karte mit genau dieser PIN eine gültige Probe-Unterschrift geliefert hat (Schritt "Karte und PIN").
- Vor jeder PIN-Prüfung im Betrieb: Kartenart und Kartennummer der eingeschalteten Karte gleichen den gespeicherten. Sonst geht nichts hinaus.
- Lehnt die Karte die gespeicherte PIN ab (Antwort mit Fehlversuch oder "gesperrt"), merkt sich die Kassa "abgelehnt" im geschützten Speicher und im Arbeitsspeicher und schickt die PIN nie wieder, bis der Chef sie im Schritt "Karte und PIN" neu eingegeben hat. Der PIN-Wächter bekommt den Stand der Karte wie bei "Karte prüfen".
- Kommt auf eine PIN-Prüfung keine Antwort, zählt die Kassa das. Nach zwei solchen Fällen ohne gelungene Prüfung dazwischen schickt sie die PIN nicht mehr von selbst ("abgelehnt", wie oben). Der Zähler wird geschrieben, bevor die PIN hinausgeht; schreibt der Speicher nicht, geht keine PIN hinaus.
- Folge: Im schlimmsten Fall verbraucht die Kassa von selbst zwei der drei Versuche, nie den dritten.
- Die PIN steht außerhalb des geschützten Speichers nur für die Dauer eines Befehls im Arbeitsspeicher.

### 6.4 Einrichtung

In der Karte "Signatur" (nur der Chef):

- **"Mit Karte ausprobieren"** (Zeile neben "Mit A-Trust ausprobieren", nur wenn die Signatur aus ist): führt zu "Karte und PIN" und beginnt danach die Probe-Kette `cardTest` mit Startbeleg von der Karte.
- **"Signatur einrichten"** öffnet zuerst die Wahl "Womit signiert die Kassa?": "Signaturkarte am Kartenleser" (Hilfe: "Ohne Internet. Die Karte muss immer im Leser stecken.") und "A-Trust online" (Hilfe: "Braucht Internet und die Zugangsdaten von A-Trust."). "A-Trust online" führt in den Ablauf von 1.7.0, unverändert.

Der Kartenweg:

1. **Karte und PIN.** Die fünf Zeilen von "Karte prüfen" (Leser, Zugriff, Karte, Zertifikat, Probe-Unterschrift) mit PIN über das Zahlenfeld. Ist Zeile 5 grün, speichert die Kassa die PIN (6.3) und bietet "Weiter" an. Sind für diese Karte schon eine PIN gespeichert und nicht abgelehnt, zeigt der Schritt "Karte und PIN sind gespeichert." mit "Weiter" und "PIN neu eingeben".
2. **Angaben für FinanzOnline.** Wie in 1.7.0, mit: Art "Signaturkarte", Anbieter "AT1 = A-TRUST", Seriennummer des Zertifikats (hexadezimal und dezimal), Kassenidentifikationsnummer, AES-Schlüssel (44 Zeichen), Prüfwert. "Angaben drucken". Rechts "Bevor du startest" wie in 1.7.0.
3. **"Jetzt in Betrieb nehmen"** mit der Frage von 1.7.0. Eine laufende Probe endet mit Schlussbeleg, die Kette `card` beginnt, die Karte signiert den Startbeleg. Scheitert etwas, bleibt alles wie vorher (Q7). Aufgaben wie in 1.7.0.

**Kassen-ID ändern.** In "Angaben für FinanzOnline" steht bei der Kassenidentifikationsnummer die Taste "Ändern". Sie öffnet ein Feld mit Tastatur. Erlaubt: 1 bis 20 Zeichen aus A bis Z, 0 bis 9 und Bindestrich; Kleinbuchstaben werden groß. Kein Unterstrich (er trennt die Felder im Code). Nicht erlaubt ist eine Kennung, die eine Kette dieses Tablets schon trägt. Hinweis im Feld: "Nimm keine Kennung, die bei FinanzOnline schon angemeldet ist." Die Änderung gilt für das PendingSetup, also bis zur Inbetriebnahme; danach ist die Kennung fest. Der AES-Schlüssel bleibt beim Ändern derselbe. Ein schon gedruckter Zettel ist danach ungültig; das Feld sagt es.

**Im Betrieb mit Karte** zeigt die Karte "Signatur": "Signatur mit der Karte. Kassen-ID …", die Zeilen von 1.7.0 ohne "Verbindung prüfen" und "Zugangsdaten", dafür "Karte und PIN" (Taste "Prüfen"; bei abgelehnter PIN die Taste "PIN neu eingeben" im Hinweis). Im Schritt "Karte und PIN" gilt im Betrieb: Die Seriennummer des gelesenen Zertifikats muss die der Kette sein, sonst Kreuz bei "Zertifikat": "Das ist nicht die Karte dieser Kassa."

### 6.5 Kern

- Der Service nimmt für Probe, Angaben und Inbetriebnahme nicht mehr nur die Angaben der Online-Prüfung, sondern die einer Signatureinheit allgemein: Einheit, Kennung des Anbieters, Zertifikat mit Seriennummer, Aussteller. Online und Karte liefern sie.
- Meldung eines Ausfalls über 48 Stunden bei einer Kette mit Karte: Der Text der Aufgabe trägt "Grund: 2, Signatur- bzw. Siegelerstellung unmöglich oder fehlerhaft".
- "Angaben drucken" und der Zettel nennen die Art der Einheit.
- Außer Betrieb nehmen, Nullbeleg, Monats- und Jahresbeleg, Protokoll ausgeben: unverändert, die Karte signiert.
- Das Prüfwerkzeug des BMF bekommt ein drittes Szenario: eine Kette, die eine nachgebildete Karte signiert.

### 6.6 USB und Android

- Der Halter öffnet den Leser beim Signieren ohne Frage von Android. Fehlt die Erlaubnis, ist das der Satz "Der Zugriff auf den Kartenleser ist nicht erlaubt.", und das Aufwärmen fragt danach einmal (außerhalb des Bons).
- Die App meldet sich bei Android für Kartenleser an (USB-Klasse 11), damit Android anbietet, die Kassa für diesen Leser immer zu öffnen, und die Erlaubnis nach dem Anstecken von selbst gilt. Das Anstecken darf die laufende Kassa nicht neu starten.
- Der USB-Teil des Druckers bleibt unberührt.

### 6.7 Was Niko dazu wissen muss (Prüfliste)

- Mit der Testkarte nur "Mit Karte ausprobieren". Nie in Betrieb nehmen, nie bei FinanzOnline anmelden.
- Die PIN nie in den Chat. Keine PIN raten.
- Im Betrieb muss die Karte immer stecken; der Verteiler braucht Strom.
- Reihenfolge am Tag wie in der Prüfliste von 1.7.0: Vorbereiten, frisch prüfen, alte Kassa abschließen, in Betrieb nehmen, dann binnen einer Woche Karte und Kassa bei FinanzOnline anmelden und den Startbeleg prüfen.

## 7. Wie geprüft wird

Tests gegen `FakeCardReader` für den Halter (offene Sitzung, PIN einmal je Sitzung, Wiederholung nach "Sicherheitszustand nicht erfüllt", andere Karte, abgelehnte PIN, zwei Prüfungen ohne Antwort, Abstecken und Wiederanstecken, Frist, "Karte prüfen" dazwischen), für Service und Journal (Karten-Probe, Inbetriebnahme, Ausfall und Sammelbeleg, Außer Betrieb), für die Bildschirme (Wahl, Karte und PIN, Kassen-ID ändern) mit Vergleichsbildern, und das Prüfwerkzeug des BMF mit einer Kette der nachgebildeten Karte. Die ganze Suite läuft auf GitHub.

## 8. Dem Bau überlassen

Namen von Klassen und Dateien, die genaue Form der gespeicherten Werte, Abstände des Aufwärmens, Aussehen der neuen Bildschirme innerhalb der Design-Regeln und der vorhandenen Bausteine, Text des Zettels.

## 9. Offen bei Niko

- Die echte Karte von YICHI: Art und Ablauf (ACOS-ID 2.1 und CardOS 5.3 müssen bis Mai 2027 getauscht werden).
- Bericht aus "Karte prüfen" mit der Testkarte (Dauer der Unterschrift).
- Die sechs Fragen aus 1.7.0.
