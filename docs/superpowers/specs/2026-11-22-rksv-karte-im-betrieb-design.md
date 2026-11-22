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

- **Sitzung:** Leser öffnen (ohne Frage von Android, siehe 6.6), Karte einschalten, Kartenart (jedes Mal neu aus der Antwort der Karte) und Kartennummer mit der gespeicherten vergleichen, Ordner der Signatur wählen. Die Sitzung bleibt offen, bis ein Fehler der Verbindung sie beendet oder jemand sie freigibt.
- **Signieren:** mit offener Sitzung nur der Befehl zur Unterschrift (bei der ersten Generation davor der Hash). Antwortet die Karte "Sicherheitszustand nicht erfüllt", prüft der Halter die PIN einmal und unterschreibt noch einmal. Das erste Signieren einer Sitzung prüft die PIN gleich.
- **Prüfung der Signatur:** Jede Unterschrift wird am Tablet gegen das Zertifikat der Kette geprüft. Passt sie nicht: "Die Unterschrift der Karte passt nicht zum Zertifikat."
- **Aufwärmen:** Ohne offene Sitzung versucht der Halter im Hintergrund, eine zu öffnen: beim Start und Fortsetzen der App (dazu zählt, dass Android der laufenden Kassa das Anstecken des Lesers meldet), nach einem gescheiterten Signieren und bei "Nochmal prüfen". Nie mehr als ein Versuch zugleich. Das Aufwärmen prüft keine PIN. Einen eigenen Kanal für das Anstecken gibt es nicht.
- **Signieren ohne Sitzung:** Der Bon versucht selbst zu öffnen. Fehlen Leser, Erlaubnis oder Karte, steht das sofort fest. Bei Ketten mit Karte gilt darum auch im Ausfall die Frist von 5 Sekunden statt 1: Öffnen, PIN und Unterschrift passen nicht in eine Sekunde. So signiert schon der erste Bon nach dem Wiederanstecken. Der Sammelbeleg entsteht wie bisher mit diesem Bon oder mit "Nochmal prüfen"; ohne Verkauf entsteht keiner.
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
- Es gibt genau eine gespeicherte Karte je Kassa; PIN und "abgelehnt" gelten für sie. Der PIN-Wächter von "Karte prüfen" bleibt daneben, wie er ist, und erfährt jede beantwortete Ablehnung.
- Eine abgelehnte oder fehlende PIN ist für den Verkauf ein Ausfall wie jeder andere (Vermerk am Bon, Hinweis in der Kassa, Aufgabe nach 48 Stunden). Der Hinweis bietet dem Chef "PIN neu eingeben" an.
- Ein abgelaufenes Zertifikat der Karte hält weder Einrichtung noch Betrieb auf; "Karte und PIN" zeigt den Hinweis wie "Karte prüfen".

### 6.4 Einrichtung

In der Karte "Signatur" (nur der Chef):

- **"Mit Karte ausprobieren"** (Zeile neben "Mit A-Trust ausprobieren", nur wenn die Signatur aus ist, also auch nach "Außer Betrieb"): führt zu "Karte und PIN" und beginnt danach die Probe-Kette `cardTest` mit Startbeleg von der Karte.
- **"Signatur einrichten"** öffnet zuerst die Wahl "Womit signiert die Kassa?": "Signaturkarte am Kartenleser" (Hilfe: "Ohne Internet. Die Karte muss immer im Leser stecken.") und "A-Trust online" (Hilfe: "Braucht Internet und die Zugangsdaten von A-Trust."). "A-Trust online" führt in den Ablauf von 1.7.0, unverändert.

Der Kartenweg:

1. **Karte und PIN.** Die fünf Zeilen von "Karte prüfen" (Leser, Zugriff, Karte, Zertifikat, Probe-Unterschrift) mit PIN über das Zahlenfeld. Ist Zeile 5 grün, speichert die Kassa die PIN (6.3) und bietet "Weiter" an. Sind für diese Karte schon eine PIN gespeichert und nicht abgelehnt, zeigt der Schritt "Karte und PIN sind gespeichert." mit "Weiter" und "PIN neu eingeben".
2. **Angaben für FinanzOnline.** Wie in 1.7.0, mit: Art "Signaturkarte", Anbieter "AT1 = A-TRUST", Seriennummer des Zertifikats (hexadezimal und dezimal), Kassenidentifikationsnummer, AES-Schlüssel (44 Zeichen), Prüfwert. "Angaben drucken". Rechts "Bevor du startest" wie in 1.7.0.
3. **"Jetzt in Betrieb nehmen"** mit der Frage von 1.7.0. Eine laufende Probe endet mit Schlussbeleg, die Kette `card` beginnt, die Karte signiert den Startbeleg. Scheitert etwas, bleibt alles wie vorher (Q7). Aufgaben wie in 1.7.0.

**Kassen-ID ändern.** In "Angaben für FinanzOnline" steht bei der Kassenidentifikationsnummer die Taste "Ändern". Sie öffnet ein Feld mit Tastatur. Erlaubt: 1 bis 20 Zeichen aus A bis Z, 0 bis 9 und Bindestrich; Kleinbuchstaben werden groß. Kein Unterstrich (er trennt die Felder im Code). Nicht erlaubt ist eine Kennung, die eine Kette dieses Tablets schon trägt. Hinweis im Feld: "Nimm keine Kennung, die bei FinanzOnline schon angemeldet ist." Die Änderung gilt für das PendingSetup, also bis zur Inbetriebnahme; danach ist die Kennung fest. Das PendingSetup gehört zu keinem der beiden Wege: Wer die Kennung ändert und dann den anderen Weg wählt, sieht dort dieselbe Kennung und denselben AES-Schlüssel. Gesperrt sind die Kennungen aller Ketten dieses Tablets, auch die der Proben. Der AES-Schlüssel bleibt beim Ändern derselbe. Ein schon gedruckter Zettel ist danach ungültig; das Feld sagt es.

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

## 10. Abweichungen beim Bau

Stand: 22.11.2026, nach den sieben Tasks des Bauplans `docs/superpowers/plans/2026-11-22-rksv-s2c-karte-im-betrieb.md`. Wo dieser Abschnitt etwas anderes sagt als die Abschnitte 1 bis 9, gilt dieser Abschnitt.

### 10.1 Entscheidungen im Plan

- **C1:** Keine Migration, die Datenbank bleibt Version 6; `rksv_chains.unit` bekommt die Werte `cardTest` und `card`.
- **C2:** Die PIN wird einmal je Sitzung geprüft, beim ersten Signieren und genau einmal mehr, wenn die Karte eine Unterschrift mit `6982` ablehnt.
- **C3:** Die gespeicherte PIN gilt nur für die Karte (Kartenart und Kartennummer), mit der sie in "Karte und PIN" eine gültige Probe-Unterschrift geliefert hat.
- **C4:** Eine beantwortete Ablehnung der PIN oder zwei PIN-Prüfungen ohne Antwort setzen "abgelehnt"; danach geht von selbst keine PIN mehr hinaus, auch nach einem Neustart. Der Zähler wird vor dem Senden geschrieben.
- **C5:** Bei Ketten mit Karte gilt auch im Ausfall die Frist von 5 Sekunden; ohne Sitzung öffnet das Signieren selbst eine, die PIN prüft erst das Signieren.
- **C6:** Beim Signieren öffnet der Halter den Leser nur mit schon gegebener Erlaubnis von Android; nur das Aufwärmen mit `ask: true` darf das Fenster von Android auslösen.
- **C7:** Das Manifest meldet die App für USB-Geräte der Klasse 11 an; Kotlin bleibt, wie es ist.
- **C8:** Kassen-ID: 1 bis 20 Zeichen aus A bis Z, 0 bis 9 und Bindestrich, groß geschrieben; geändert wird das `PendingSetup`, der AES-Schlüssel bleibt; Kennungen der Ketten dieses Tablets sind gesperrt.
- **C9:** Eine Tastatur gibt es in zwei Dateien: `credentials_screen.dart` und `cash_box_id_sheet.dart`.
- **C10:** Die Wege des Online-Betriebs behalten Namen und Parameter; die Karte bekommt `enableCardProbe`, `prepareCardSetup` und `goLiveWithCard` über demselben Kern.
- **C11:** Bei der Karte gibt es keine Aussteller-Zertifikate: leere Liste in Kette und Protokoll; das Prüfwerkzeug bekommt das Zertifikat der Karte über seine Schlüsseldatei.
- **C12:** Ein Ausfall über 48 Stunden bei `card` trägt "Grund: 2, Signatur- bzw. Siegelerstellung unmöglich oder fehlerhaft"; der Text der Online-Ketten bleibt.
- **C13:** Während "Karte prüfen" oder "Karte und PIN" läuft, hat der Halter keine Sitzung; ein Bon in dieser Zeit ist ein Ausfall mit "Die Karte wird gerade geprüft."

### 10.2 Entscheidungen während des Baus

**Halter und PIN**

- Vor jedem VERIFY fragt der Halter den PIN-Wächter von "Karte prüfen". Weiß der Wächter, dass die Karte nur noch einen Versuch hat, schickt der Halter keine PIN und meldet "Die Karte hat die PIN abgelehnt."; nach einer angenommenen PIN löscht er den Eintrag des Wächters. Scheitert das Lesen des Wächters, geht nichts hinaus. Abschnitt 6.3 sagte, der Wächter bleibe daneben, wie er ist; jetzt hält er auch den Halter zurück.
- Jeder Aufruf des Halters in den geschützten Speicher hat eine Grenze von 2 Sekunden (`CardSigner.storageLimit`). Ein Speicher, der hängt, ist ein Ausfall ("Die Karte antwortet nicht."), nie eine blockierte Warteschlange.
- Schließt der Halter gerade eine Sitzung, wartet ein neues Öffnen, bis das Schließen fertig ist.
- Ein VERIFY, das die Karte mit etwas anderem als "angenommen" beantwortet, zählt vorsichtig: Andere Statuswörter als die der Ablehnung lassen den Zähler "ohne Antwort" erhöht stehen. In "Karte und PIN" markiert jede beantwortete Nicht-Annahme der gespeicherten PIN diese als abgelehnt.
- Es gibt eine einzige Stelle, die die Unterschrift der Karte liest: `signatureAsRs` in `certificate.dart` macht aus der Antwort der Karte 64 Bytes; die Einheit prüft genau diese 64 Bytes und speichert sie.

**Service**

- `liveChainSerial` bleibt die Seriennummer einer Kette, die online über A-Trust signiert, und ist bei einer Kette mit Karte null (der Plan sagte anderes und wurde berichtigt); `cardChainSerial` liefert die Seriennummer der Karte. Sonst hielte "Verbindung prüfen" am echten System auf einer Kassa mit Karte jedes Konto von A-Trust für ein anderes Konto.
- `changeCashBoxId` prüft in dieser Reihenfolge: in Betrieb oder keine vorbereiteten Angaben (Programmierfehler), Speicher lesbar, Form, dieselbe Kennung wie vorher (dann wird nichts geschrieben), Kennung schon von einer Kette dieser Kassa verwendet, Schreiben und Zurücklesen.
- Scheitert der Start der Karten-Probe, bleibt der AES-Schlüssel der nicht entstandenen Kette im geschützten Speicher; der nächste Start überschreibt ihn (wie beim Online-Weg).
- Die Aufgabe zu einem langen Ausfall in einer Karten-Probe trägt denselben Grund wie die Kette `card` (Grund 2). Abschnitt 6.5 nannte ihn nur für die Kette mit Karte im Betrieb.

**"Karte und PIN"**

- Ist schon eine PIN gespeichert, macht "Karte und PIN" die Probe-Unterschrift mit der gespeicherten PIN, ohne Zahlenfeld, damit die Angaben der Karte (Zertifikat, Seriennummer) für den nächsten Schritt da sind. Abschnitt 6.4 sagte nur, der Schritt zeige "Karte und PIN sind gespeichert." mit "Weiter". Die Probe ist dieselbe wie in "Karte prüfen": drei Runden mit je einem VERIFY, Runde zwei und drei nur, wenn die erste angenommen wurde.
- Diese Probe markiert die gespeicherte PIN nur dann als abgelehnt, wenn sie gegen die Versuche der Karte gezählt hat (beantwortete Nicht-Annahme, oder VERIFY gesendet ohne Antwort), nicht, wenn Leser oder Karte vor dem VERIFY scheiterten oder die Unterschrift nach einem angenommenen VERIFY scheiterte.
- `signAndStore` speichert eine PIN nur, wenn seine eigene Probe-Unterschrift gelaufen ist und Zeile 5 grün gemacht hat; eine frühere grüne Zeile zählt nicht.
- Zeile 5 zeigt "wartet", bis das Nachsehen nach der gespeicherten PIN fertig ist; erst dann erscheint "PIN eingeben".
- "Karte und PIN" hat "Nochmal prüfen" bekommen (die Sätze der Zeilen verweisen darauf) und ist eine Seite der Hülle wie die anderen Seiten der Einstellungen.

**Wege und Texte**

- Die Hilfe von "Signatur einrichten" heißt in jedem Zustand, der die Zeile zeigt, "Für den echten Betrieb, mit Signaturkarte oder A-Trust online."
- Zurück: von "Angaben für FinanzOnline" (Karte) zu "Karte und PIN", von dort zur Wahl, von der Wahl zu den Einstellungen. "Zugangsdaten von A-Trust", von der Wahl aus geöffnet, führt zurück zur Wahl.
- Beide Wege von "Angaben für FinanzOnline" haben bei der Kassen-ID die Taste "Ändern"; die Vergleichsbilder der Online-Seite haben sich genau um diese Taste geändert.
- Auf dem Kartenweg heißt Schritt 2 rechts "Signaturkarte und Kassa bei FinanzOnline anmelden, spätestens eine Woche nach dem Start." Abschnitt 6.4 sagte "wie in 1.7.0" ("Signatureinheit"). Die Aufgabe nach dem Start sagt weiter "Signatureinheit und Kassa bei FinanzOnline anmelden, bis …".
- Vor `goLiveWithCard` wartet der Bildschirm höchstens 20 Sekunden darauf, dass der Leser offen ist, und nimmt dann in jedem Fall in Betrieb; ohne Karte steht der Satz der Karte da, und die Kassa ist nicht in Betrieb.
- Der Hinweis "Die Karte hat die PIN abgelehnt." mit "PIN neu eingeben" erscheint in der Karte "Signatur" auch während der Karten-Probe, und auch dann, wenn der PIN-Wächter die PIN zurückhält. Mitarbeiter ohne Chef-Recht sehen den Satz, nicht die Taste.
- Eine Karten-Probe im Ausfall zeigt die Pille "Karten-Probe, Signatur ausgefallen".

**Schlusskorrektur nach der Prüfung des ganzen Zweigs**

- A1: Stirbt eine Sitzung, die schon vor dem Aufruf offen war, und ging in diesem Aufruf noch kein VERIFY hinaus, öffnet der Halter einmal neu (ohne Android zu fragen) und signiert noch einmal, mit dem ersten VERIFY der neuen Sitzung; scheitert das Öffnen, gilt sein Problem (ein abgezogener Leser heißt so "Kein Kartenleser gefunden.").
- A2: Vor jedem VERIFY trägt auch der Halter im PIN-Wächter einen Versuch weniger ein, nach derselben Regel wie "Karte prüfen" (bekannter Stand weniger eins, sonst drei weniger eins); schreibt der Wächter nicht, geht keine PIN hinaus. So verbrauchen Halter und "Karte prüfen" zusammen von selbst höchstens zwei Versuche.
- A3: Wartet ein Öffnen gerade auf die Antwort von Android, wartet ein Bon nicht darauf, sondern endet sofort mit "Der Zugriff auf den Kartenleser ist nicht erlaubt."
- B1: Bei Ketten mit Karte folgt der Grund des Ausfalls dem letzten gescheiterten Versuch (Bon, Sammelbeleg, "Nochmal prüfen"), der Beginn bleibt; Ketten an A-Trust und die Probe bleiben, wie sie waren. Dafür schreibt `ReceiptRepository._tryCollective` nach dem Zurückrollen den Satz über `RksvJournal.noteFailedAttempt`. Nach einer neuen PIN versucht "Karte und PIN" beim Verlassen einmal den Sammelbeleg ("Fertig" ohne zu warten, "Probe starten" und "Weiter" davor).
- B2: Der Hinweis mit "PIN neu eingeben" in der Karte "Signatur" steht auch bei "Die PIN der Karte fehlt.", mit dem Satz, der gilt, und nur einmal.
- C1: Läuft beim Öffnen von "Karte und PIN" schon ein Prüflauf, wartet die Seite auf ihn und macht weiter, als hätte sie ihn gestartet; für "PIN neu eingeben" liest sie danach selbst, mit der Seriennummer der Kette.
- C2: Nach "Zähler ist wieder voll" sucht die Seite die gespeicherte PIN neu und zeigt "Karte und PIN sind gespeichert." mit "PIN neu eingeben"; eine Probe-Unterschrift macht sie nicht von selbst (die macht "Nochmal prüfen"), die Haupttaste wartet auf Zeile 5.
- C3: Ist die Seriennummer der laufenden Kette nicht lesbar, liest "PIN neu eingeben" die Karte nicht und zeigt "Das hat nicht geklappt. Bitte noch einmal."; "Nochmal prüfen" versucht es wieder.
- C4: Die Angaben für FinanzOnline kommen nach jedem Schließen des Blatts "Kassen-ID ändern" neu vom Dienst, auch ohne Ergebnis.
- C5: Android darf nach dem Kartenleser fragen beim ersten Bild der Kassa nach dem Start, bei jedem Fortsetzen und bei "Nochmal prüfen"; ein Wechsel der Bereiche wärmt ohne Frage auf.

**Prüfwerkzeug**

- Das dritte Szenario in `app/test/rksv/pruefwerkzeug_test.dart` ist eine Kette `card`, über `prepareCardSetup`, `changeCashBoxId` und `goLiveWithCard` begonnen und von der nachgebauten Karte über den echten `CardSigner` und die echte `CardSignatureUnit` signiert: Startbeleg, Verkäufe, Storno, zwei Bons mit gezogener Karte, Sammelbeleg, Nullbeleg, Schlussbeleg durch die Außerbetriebnahme. Das Prüfwerkzeug 1.1.1 des BMF hat alle drei Szenarien angenommen (`tool/rksv/pruefen.sh`: `+3: All tests passed!`). Die Hilfsdatei `app/test/support/pruefwerkzeug.dart` brauchte dafür keine Änderung: Das Zertifikat der Karte geht wie bei den anderen Szenarien über die Schlüsseldatei an das Werkzeug.

### 10.3 Was an echter Hardware ungeprüft ist

Nichts aus dieser Stufe lief gegen einen echten Leser oder eine echte Karte; alles wurde gegen die nachgebaute Karte geprüft (`FakeCardReader`, `FakeCard`). Offen am echten Tablet:

- Ob eine Karte die PIN für die ganze Sitzung angenommen hält, so dass ein VERIFY für viele Bons reicht. Das Handbuch von A-Trust (Listing 2 für die älteste Kartenart) wiederholt VERIFY vor jeder Unterschrift. Die Kassa kommt mit einer Karte zurecht, die neu fragt (eine abgelehnte Runde, dann VERIFY und Unterschrift), um den Preis von Zeit je Bon.
- Wie lange Öffnen des Lesers, VERIFY und eine Unterschrift am Redmi Pad über den Verteiler dauern; die Frist je Bon ist 5 Sekunden.
- Ob Android nach jedem Wiederanstecken oder Neustart wieder nach der Erlaubnis für den Leser fragt, und ob der Filter für USB-Klasse 11 im Manifest (C7) die Erlaubnis halten lässt ("immer für dieses Gerät öffnen").
- Leser, Drucker und Kassenlade zusammen am einen USB-Anschluss über den Verteiler mit Strom.
- Abziehen und Wiederanstecken von Karte oder Leser während eines Verkaufs.
- Die echte Karte von YICHI: ihre Art (manche Arten müssen bis Mai 2027 getauscht werden) und ihre PIN.
- Die App "BMF Belegcheck" mit einem Startbeleg, den eine echte Karte signiert hat.

### 10.4 Bekannte Punkte

- Die Regel für die Kassen-ID (1 bis 20 Zeichen, A bis Z, 0 bis 9, Bindestrich) ist eine vorsichtige Wahl von Claude; die Unterlagen des BMF nennen weder Länge noch Muster.
- Der Grund eines langen Ausfalls bei Online-Ketten ("Grund: 3, …") stammt aus dem Leitfaden der WKO und ist unverändert; die Dokumentation des Webservice des BMF nennt nur die Gründe 1, 2 und 99. Bei Ketten mit Karte nimmt die Kassa Grund 2. Niko soll mit der Steuerberatung klären, welchen Grund FinanzOnline anbietet.
- Die Probe-Unterschrift mit der gespeicherten PIN läuft jedes Mal neu, wenn "Karte und PIN" aufgeht (zum Beispiel beim Zurückgehen von den Angaben).
- Aufgeschobene kleine Punkte aus den Reviews, in der Schlussprüfung so gelassen: eigene Kopien des Lesens der Kartennummer und der Auswahl aus `CardCheck` in `card_signer.dart`; eine dritte Kopie von Kopfzeile und rechter Karte der Prüfseiten; Import-Kreise `card_providers.dart`/`rksv_providers.dart` und `card_setup_screen.dart`/`signature_panel.dart`; `changeCashBoxId` läuft in der Warteschlange der Einrichtung, das Inbetriebnehmen nicht; zwei Hilfen `_cardChain`. Der Test für `primeLiveKey` mit einer Kette mit Karte und das Warten von "Karte und PIN" auf eine laufende Prüfung kamen in der Schlusskorrektur dazu.
- Ein Verkauf im Ausfall kann bis zu 5 Sekunden für den Sammelbeleg und dazu bis zu 5 Sekunden für die eigene Signatur dauern, wenn eine Karte langsam antwortet und dann scheitert; die Frist je Eintrag hält. Am Tablet zu messen.
- Die Kassa löscht die gespeicherte PIN nie von selbst, auch nicht am Ende einer Probe oder bei der Außerbetriebnahme; die PIN einer neuen Karte ersetzt sie.
- `CardSigner.lastProblem` liest im Code der App niemand; nur die Tests.
- Aus der Nachprüfung der Schlusskorrektur, offen für die erste Version nach Nikos Teil A:
  - Ändert ein gescheitertes "Nochmal prüfen" den Grund des Ausfalls, zeigt der gelbe Hinweis kein "Geht noch nicht.", sondern nur den neuen Grund (`outage_banner.dart`: der Grund gehört zu `_outageKey`).
  - Nach "Zähler ist wieder voll" mit gespeicherter PIN bleiben "Probe starten" und "Weiter" aus, bis "Nochmal prüfen" getippt wird; die Seite sagt das nicht.
  - "Fertig" nach "Zähler ist wieder voll" ohne neue PIN versucht den Sammelbeleg nicht; der Ausfall endet mit dem nächsten Bon.
  - Scheitert das Löschen im PIN-Wächter nach einem angenommenen VERIFY zweimal, hält der Wächter eine richtige PIN zurück, bis der Chef ihn zurücksetzt (vorsichtige Seite).
  - `RksvJournal.noteFailedAttempt` kann bei einem Fehler der Datenbank aus `ReceiptRepository._tryCollective` werfen; dann scheitert dieser eine Verkauf.
  - Eine aufgewärmte Sitzung, die noch kein VERIFY geschickt hat und dann stirbt, kostet den nächsten Bon die Signatur und zählt einmal "ohne Antwort" (der Halter wiederholt nur, solange in diesem Aufruf kein VERIFY hinausging).
  - Nimmt man mit einer zweiten Karte in Betrieb, während die Probe einer anderen Karte läuft, signiert die zweite Karte den Schlussbeleg der Probe einmal; die Einheit verwirft die Unterschrift, der Schlussbeleg trägt den Vermerk des Ausfalls.
- 1.7.0 wurde nie hochgeladen; 1.8.0 enthält es. Die sechs offenen Fragen aus 1.7.0 bleiben offen.
- Die Prüfliste für Niko: `docs/testen/rksv-karte-betrieb-pruefliste.md` (Teil A mit der Testkarte, Teil B mit der Karte von YICHI).
