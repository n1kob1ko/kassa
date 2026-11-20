# Kassa: Online-Signatur von A-Trust (Entwurf)

Stand: 19. November 2026. Auftrag von Niko: "ich werd das von A Trust holen wegen dem signieren", danach auf der Entscheidungskarte "Online (a.sign RK HSM)".
Dieser Entwurf setzt `2026-11-18-rksv-signatur-design.md` fort (dort "der Kern"). Er ersetzt dort die Stufe S2 "Chipkarte als echte Signatur" und die Teile von 6.7 und 6.8, die von der Karte handeln. Alles andere im Kern gilt weiter. Wo beide sich widersprechen, gilt dieser.

## 1. Worum es geht und warum

Die Kassa signiert seit Version 1.4.0 jeden Bon, aber nur mit einem Schlüssel, den sie selbst erzeugt (Probe). Für den echten Betrieb bei YICHI braucht sie eine Signatur, die das Finanzamt anerkennt. Niko holt sie bei A-Trust als Online-Dienst "a.sign RK HSM": Der Schlüssel liegt bei A-Trust, die Kassa schickt je Bon eine Anfrage über das Internet. Am Tablet braucht es dafür keinen Kartenleser und keinen Verteiler.

Erfolg heißt: Ein Bon, den A-Trust signiert hat, besteht das Prüfwerkzeug des Finanzministeriums, und der Startbeleg von YICHI besteht die App "BMF Belegcheck".

## 2. Was feststeht

- **A-Trust, online** (Niko, 19.11.2026). Kein fiskaly, keine Chipkarte als nächster Schritt. "Karte prüfen" bleibt in der App, wie es ist.
- **Bonieren geht immer weiter.** Fällt das Internet oder A-Trust aus, verkauft die Kassa weiter und kennzeichnet die Bons (Kern 6.5).
- **Niko schließt den Partnervertrag mit A-Trust.** A-Trust verkauft den Dienst nur an Partner (Kassenhersteller, Wiederverkäufer, Entwickler). Niko legt als Partner je Betrieb ein Konto an und bekommt dafür Benutzername und Passwort.
- **Öffentliches Repo:** keine echten Zugangsdaten, kein Passwort, keine echten Zertifikate von YICHI im Repo.
- **Touch-Regel:** keine Texteingabe an der Theke. Die Einrichtung durch den Chef ist davon ausgenommen (siehe 5, Weg 3).
- **Jede Änderung an der Datenbank** braucht eine Migration mit Test.

## 3. Was gelesen wurde

| Punkt | Ergebnis | Quelle | Sicherheit |
| --- | --- | --- | --- |
| Schnittstelle | Web-Anfragen mit JSON. Adresse echt `https://rksv.a-trust.at/asignrkonline/v2`, Test `https://hs-abnahme.a-trust.at/asignrkonline/v2`. | Handbuch 3.1 im Repo `A-Trust/RKSV`, Ordner `a.sign RK HSM-Online` | hoch (gelesen), am System noch nicht probiert |
| Signieren | Vier Formen: Daten, Hashwert, Klartext, fertiger JWS. Jede gibt es mit Passwort je Anfrage (etwa eine halbe Sekunde langsamer) oder mit Sitzung. | Handbuch 2.3, 2.4 | hoch |
| Sitzung | Anmelden liefert `sessionid` und `sessionkey`. Gilt eine Stunde, jede Signatur verlängert um eine Stunde, um Mitternacht endet sie. | Handbuch 2.4.1 | hoch |
| Zertifikat | `GET {Benutzer}/Certificate` liefert Zertifikat, Aussteller-Zertifikate, Seriennummer dezimal und hex, `alg` `ES256`. Ohne Passwort. `GET {Benutzer}/ZDA` liefert das Kennzeichen des Ausstellers, im Beispiel `AT1`. | Handbuch 2.5, 2.7 | hoch |
| Fehler | 401 falscher Benutzer oder falsches Passwort, 401 Sitzung abgelaufen, 403 gesperrt, 400 kaputte Eingabe, 500 Fehler bei A-Trust. | Handbuch Anhang A | mittel: Der Text der Antwort ist nicht beschrieben |
| Sperre | Ein Konto wird gesperrt, wenn das Passwort "zu oft" falsch war. Wie oft, steht nirgends. | Handbuch 4.1.1 | niedrig |
| Testsystem | Öffentlich, mit einem Test-Benutzer, den A-Trust im Handbuch nennt, und einem Benutzer, der schon gesperrt ist. | Handbuch 4, docs.a-trust.at | hoch |
| Pakete | Basic 10.000 Signaturen im Jahr, Advanced 30.000, Premium unbegrenzt, je 5 Jahre. Was beim Überschreiten geschieht, steht nirgends. | Seite von A-Trust | mittel |
| Konto anlegen | Der Partner lädt im Webshop von A-Trust Guthaben auf, wählt Paket und Ordnungsbegriff (UID, GLN oder Steuernummer), gibt eine E-Mail an und bekommt Benutzername und Passwort einmal angezeigt (als PDF zu speichern). | Aktivierungshilfe von A-Trust | hoch |
| FinanzOnline | Signatureinheit anmelden mit Art "Hardware-Sicherheitsmodul (HSM) eines Dienstleisters", Anbieter "AT1 = A-TRUST", Seriennummer des Zertifikats (dezimal oder hex). Kassa anmelden mit Kassenidentifikationsnummer, AES-Schlüssel (44 Zeichen) und Prüfwert. Anmeldung und Prüfung des Startbelegs innerhalb einer Woche nach Inbetriebnahme. Ausfall über 48 Stunden melden, Grund 3 "Ausfall der Verbindung zur Signatur- bzw. Siegelerstellungseinheit". | Leitfaden der WKO | mittel: Leitfaden, nicht Wortlaut |

Das Rechtsinformationssystem zeigt von hier eine Roboter-Prüfung und ist weiter nicht lesbar. Die Punkte, die am Wortlaut zu prüfen sind (Kern 9, Punkte 7 bis 13, und Kern 11.2), bleiben offen und gehören vor die Inbetriebnahme, siehe 9.

## 4. Ziele, Nicht-Ziele, Anti-Ziele

**Ziele**

1. Eine Signatureinheit "A-Trust online" hinter der vorhandenen Schnittstelle. Der Rest der Kassa (Kette, Zähler, Protokoll, Sonderbelege, Ausfall) bleibt, wie er ist.
2. **Online-Probe:** Niko kann die Online-Signatur am Tablet sofort ausprobieren, ohne Vertrag, über das Testsystem von A-Trust. Die Bons bleiben Testbons.
3. "Verbindung prüfen" zeigt Zeile für Zeile, ob Tablet, Internet und A-Trust zusammen funktionieren, und wie lange eine Signatur dauert.
4. **Inbetriebnahme:** Zugangsdaten eingeben, Angaben für FinanzOnline anzeigen und drucken, Startbeleg, ab dann echte Bons. Dazu "Kassa außer Betrieb nehmen".
5. Das Konto bei A-Trust wird nie durch die Kassa gesperrt.
6. Alles ist ohne Internet testbar, und ein Protokoll mit Signaturen vom Testsystem besteht das Prüfwerkzeug des Finanzministeriums.

**Nicht-Ziele (bewusst später)**

- Konten bei A-Trust über die Partner-Schnittstelle anlegen (vom Server oder aus der Verwaltung).
- Zugangsdaten über die Verwaltung im Browser aufs Tablet bringen.
- Neues Zertifikat nach fünf Jahren ("Sorglos-Paket"), Passwort ändern.
- Chipkarte als echte Signatur. fiskaly.
- Mehrere Kassen an einem Konto.
- Alles, was im Kern Nicht-Ziel ist (4,9 %, digitaler Bon, Abgleich des Protokolls zum Server).

**Anti-Ziele**

- Eine Kassa, die ohne Internet nicht verkaufen kann.
- Ein echter Bon mit einer Signatur vom Testsystem. Das Testsystem ist fest an "Testbon" gebunden, die echte Adresse fest an "In Betrieb".
- Ein gesperrtes Konto, weil die Kassa ein falsches Passwort von selbst wiederholt hat.
- Passwort oder Sitzungsschlüssel in der Datenbank, in einem Log, in einem Fehlertext, im Bericht oder im Repo.

## 5. Wege

**Weg 1: Wer mit A-Trust spricht.**

- **A. Das Tablet direkt (gewählt).** Braucht nur Internet am Tablet. Fällt unser Server aus, signiert die Kassa weiter. Die Zugangsdaten liegen im geschützten Speicher des Tablets.
- **B. Über unseren Server.** Der Server hielte die Zugangsdaten aller Betriebe und signierte für sie. Bequem für viele Betriebe, aber ein Ausfall des Servers wäre ein Ausfall der Signatur bei allen, und der Server würde zum lohnenden Ziel. Verworfen.

**Weg 2: Welcher Befehl.**

- **A. Sitzung und Hashwert (gewählt).** Die Kassa meldet sich einmal an und schickt je Bon nur den Hashwert. A-Trust erfährt keine Beträge, und das Passwort geht nicht mit jedem Bon über die Leitung. Passt genau auf die vorhandene Schnittstelle (Text hinein, 64 Bytes heraus).
- **B. Fertiger JWS mit Passwort je Anfrage.** Am einfachsten, aber je Bon eine halbe Sekunde langsamer, und der ganze Code des Bons mit den Beträgen geht an A-Trust. Verworfen.

**Weg 3: Wie die Zugangsdaten aufs Tablet kommen.**

- **A. Der Chef tippt sie einmal bei der Einrichtung ein (gewählt).** Das ist Einrichtung, nicht Theke. Kein Geheimnis auf dem Server.
- **B. Über die Verwaltung im Browser.** Passt zu Nikos Ziel, neue Betriebe selbst einzurichten, braucht aber den Abgleich mit dem Server und Geheimnisse auf dem Server. Später, zusammen mit dem Anlegen der Konten über die Partner-Schnittstelle.

Alle drei sind Claudes Entscheidungen. Niko hat das Wie bisher Claude überlassen.

## 6. Entwurf

### 6.1 Zustände der Kassa

Die Tabelle aus Kern 6.1 bekommt eine Zeile dazu, und "In Betrieb" meint jetzt A-Trust statt Chipkarte.

| Zustand | Bon | Wer signiert |
| --- | --- | --- |
| Nicht eingerichtet | "TESTBON", kein QR-Code | niemand |
| Probe | "TESTBON", mit QR-Code | Schlüssel am Tablet (wie 1.4.0) |
| Online-Probe | "TESTBON", mit QR-Code | Testsystem von A-Trust |
| In Betrieb | echter Bon mit QR-Code | A-Trust, echtes Konto |
| In Betrieb, Signatur ausgefallen | echter Bon mit Vermerk | niemand, bis es wieder geht |
| Außer Betrieb | wie "Nicht eingerichtet" | niemand |

Jede Kette merkt sich, welche Einheit sie signiert (Probe, A-Trust Test, A-Trust echt). Ein Wechsel der Einheit beendet die laufende Kette mit einem Schlussbeleg und beginnt eine neue (Kern K5). Zwischen Probe und Online-Probe wechselt man über "Probe beenden" und neu einschalten.

### 6.2 Der Ablauf je Bon

Die Online-Einheit erfüllt die vorhandene Schnittstelle `SignatureUnit`.

1. Aus dem zu signierenden Text bildet sie den SHA-256-Hashwert.
2. Hat sie keine Sitzung, meldet sie sich an (`PUT Session/{Benutzer}`).
3. Sie lässt den Hashwert signieren (`POST Session/{sessionid}/Sign/Hash`).
4. Antwortet A-Trust mit 401, ist die Sitzung abgelaufen: Sitzung verwerfen, genau einmal neu anmelden und Schritt 3 wiederholen.
5. Die Antwort muss 64 Bytes ergeben (Base64 oder Base64-URL, beides wird angenommen). Die Kassa prüft die Signatur am Tablet gegen das gespeicherte Zertifikat. Stimmt sie nicht, gilt der Versuch als gescheitert.

Für alles zusammen gelten die Fristen des Kerns: 5 Sekunden, im Ausfall 1 Sekunde. Eine Antwort, die nach der Frist kommt, wird verworfen. Signiert wird weiter innerhalb der Datenbank-Transaktion des Bons (Kern K1); die Prüfliste misst die Dauer am echten Tablet.

**Anmelden im Voraus.** Damit das Anmelden (etwa eine halbe Sekunde) möglichst nie in die Frist eines Bons fällt, hält die Online-Einheit ihre Sitzung selbst:

- Sie meldet sich im Hintergrund an, außerhalb jeder Transaktion: wenn die Online-Probe oder der Betrieb beginnt, wenn die App startet oder wieder nach vorn kommt und eine Kette mit A-Trust läuft, und wenn ein Versuch gescheitert ist, weil die Sitzung fehlte.
- Eine Sitzung gilt für die Einheit als abgelaufen, wenn sie seit 55 Minuten nicht benutzt wurde oder der Kalendertag gewechselt hat. Dann wird sie nicht mehr verwendet.
- Fehlt beim Bon trotzdem die Sitzung, meldet sich die Einheit innerhalb der Frist an (Schritt 2). Reicht die Frist nicht (im Ausfall bei langsamem Netz), läuft das Anmelden im Hintergrund fertig, und der nächste Versuch findet die Sitzung vor. So endet ein Ausfall auch bei langsamem Netz von selbst.
- Es läuft nie mehr als eine Anmeldung zugleich. Für jede Anmeldung, auch im Hintergrund, gilt 6.3.

Kennzeichen des Ausstellers, Seriennummer und Zertifikate liest die Kassa einmal beim Einschalten (`ZDA`, `Certificate`) und speichert sie zur Kette. Je Bon fragt sie dafür nicht nach. Die Seriennummer im Code leitet sie wie bisher aus dem Zertifikat selbst ab und vergleicht sie mit der Angabe von A-Trust.

Das Kennzeichen im Code ist das, was A-Trust nennt, auch am Testsystem (vermutlich `AT1`). Das eigene Kennzeichen `AT100` (Kern K4) bleibt der Probe mit selbst erzeugtem Schlüssel vorbehalten, weil Kennzeichen und Zertifikat zusammenpassen müssen. Ein Bon der Online-Probe ist an "TESTBON" und am Test-Zertifikat zu erkennen, und "BMF Belegcheck" lehnt ihn ab, weil weder Kassa noch Zertifikat bei FinanzOnline angemeldet sind. (Claudes Entscheidung.)

### 6.3 Fehler und Schutz des Kontos

| Was geschieht | Was die Kassa tut |
| --- | --- |
| Kein Internet, Frist abgelaufen, 500 von A-Trust, kaputte Antwort, Signatur passt nicht zum Zertifikat | Ausfall wie im Kern: Bon mit Vermerk, Hinweis in der Kassa, bei jedem Bon ein kurzer neuer Versuch, danach Sammelbeleg |
| 401 beim Signieren | Sitzung neu, ein Mal (6.2) |
| 401 oder 403 beim **Anmelden** | Die Zugangsdaten gelten als **abgelehnt**. Die Kassa meldet sich nicht mehr von selbst an. Ausfall läuft weiter. |

Im Zustand "abgelehnt" spricht die Kassa nicht mehr mit A-Trust, auch nicht bei "Nochmal prüfen" in der Kassa und auch nicht bei "Verbindung prüfen" ohne Antippen des Chefs (strenger als hier beschrieben, siehe 11). Der Hinweis sagt dann: "A-Trust hat die Zugangsdaten abgelehnt. Bitte den Chef holen." Nur der Chef hebt den Zustand in den Einstellungen auf, mit einem ausdrücklichen Antippen, und jedes Antippen ist genau ein Versuch. So kann die Kassa das Konto nicht sperren. Der Zustand überlebt einen Neustart.

Im echten Betrieb gilt: Jeder Fehler der Signatureinheit, erwartet oder nicht, ist ein Ausfall. Der Bon wird mit Vermerk gespeichert. Nur wenn die Datenbank selbst nicht schreibt, scheitert der Verkauf. (Kern K9, das Abschalten bei einem unerwarteten Fehler, gilt weiter nur im Zustand Probe und dort nur für Fehler außerhalb der Signatureinheit, etwa einen nicht lesbaren AES-Schlüssel. Die Online-Einheit meldet jeden eigenen Fehler als Ausfall.)

### 6.4 Geheimnisse und was A-Trust erfährt

- Benutzername und Passwort liegen nur im geschützten Speicher von Android, der Sitzungsschlüssel nur im Arbeitsspeicher. Nichts davon steht in der Datenbank, in einem Log, in einem Fehlertext, in `toString`, im Bericht oder im ausgegebenen Protokoll.
- A-Trust erfährt je Bon den Hashwert und das Konto. Keine Beträge, keine Artikel, keine Kassen-Kennung.
- Die Adressen von A-Trust stehen fest im Code und lassen sich nicht ändern. Die Verbindung ist immer HTTPS mit den Zertifikaten, denen Android vertraut.
- Der Test-Benutzer von A-Trust steht im Code. Er ist öffentlich (Handbuch von A-Trust) und kein Geheimnis. Jeder kann damit signieren; deshalb bleiben Bons der Online-Probe Testbons.

### 6.5 Online-Probe

In den Einstellungen, Karte "Signatur", im Zustand "Nicht eingerichtet" gibt es neben "Zum Ausprobieren einschalten" die Zeile **"Mit A-Trust ausprobieren"**. Antippen fragt einmal nach, läuft dann "Verbindung prüfen" (6.6) durch und beginnt bei Erfolg eine Kette mit Startbeleg, signiert vom Testsystem. Ab dann verhält sich alles wie in der Probe: QR-Code, Protokoll, Sonderbelege, Aufgaben als Übung, "Probe beenden".

Neu gegenüber der Probe: Ein Ausfall lässt sich von Hand auslösen (WLAN aus). Die Prüfliste nutzt das.

Scheitert "Verbindung prüfen", beginnt keine Kette, und der Bildschirm zeigt, welche Zeile gescheitert ist.

### 6.6 Verbindung prüfen

Ein Bildschirm wie "Karte prüfen": Zeile für Zeile mit Haken oder Kreuz und einem Satz.

1. A-Trust erreicht (mit Dauer).
2. Zertifikat geladen: Aussteller, Seriennummer, gültig bis. Geprüft wird: Verfahren ES256, Kurve P-256, heute gültig (am Testsystem ist ein abgelaufenes Zertifikat kein Fehler, siehe 11).
3. Angemeldet.
4. Probe-Unterschrift erstellt und am Tablet gegen das Zertifikat geprüft (mit Dauer). Das verbraucht eine Signatur aus dem Paket.

Schlägt eine Zeile fehl, steht dort, was zu tun ist ("WLAN prüfen", "Zugangsdaten prüfen", "Später noch einmal"). Unten "Bericht teilen": die Zeilen, die Dauern, die Statuscodes und das Zertifikat, nie Passwort oder Sitzungsschlüssel. Der Bildschirm läuft beim Einschalten der Online-Probe, bei der Einrichtung und später jederzeit über die Zeile "Verbindung prüfen" (nur Chef). Eine abgelehnte Anmeldung zählt hier als der eine ausdrückliche Versuch aus 6.3.

### 6.7 Einrichtung und Inbetriebnahme

Der Weg "Signatur einrichten" in den Einstellungen, nur für den Chef. Er ersetzt Kern 6.8.

1. **Zugangsdaten eingeben:** Benutzername und Passwort von A-Trust, mit der Tastatur, einmal. Das Passwort ist verdeckt, mit "Anzeigen".
2. **Verbindung prüfen** (6.6) gegen das echte System. Ohne vier Haken geht es nicht weiter.
3. **Angaben für FinanzOnline:** Die Kassa erzeugt Kassen-Kennung und AES-Schlüssel und zeigt: Art "Hardware-Sicherheitsmodul (HSM) eines Dienstleisters", Anbieter "AT1 = A-TRUST", Seriennummer des Zertifikats, Kassenidentifikationsnummer, AES-Schlüssel, Prüfwert. "Angaben drucken" druckt sie auf einen Zettel.
4. **Hinweis**, was ein Mensch tun muss: an der alten Kassa den Schlussbeleg erstellen, Signatureinheit und Kassa bei FinanzOnline anmelden, Startbeleg mit "BMF Belegcheck" prüfen, alles innerhalb einer Woche.
5. **"Jetzt in Betrieb nehmen":** Die Kassa fragt einmal deutlich nach, weil der Schritt nicht zurückgeht. Läuft eine Probe, endet sie mit Schlussbeleg. Dann Startbeleg, signiert von A-Trust, gedruckt. Ab jetzt sind die Bons echt, ohne "TESTBON". Es entstehen die Aufgaben "Bei FinanzOnline anmelden, bis <Datum>" und "Startbeleg prüfen".

Bricht der Chef vor Schritt 5 ab, bleibt die Kassa im alten Zustand; eingegebene Zugangsdaten bleiben gespeichert und lassen sich ersetzen oder löschen.

**"Kassa außer Betrieb nehmen"** erstellt den Schlussbeleg, druckt ihn und setzt die Kassa auf "Außer Betrieb", nach deutlicher Nachfrage.

Bons aus der Testzeit lassen sich nach der Inbetriebnahme nicht stornieren (Kern 6.1), mit dem Satz "Dieser Bon stammt aus der Testzeit und kann nicht storniert werden."

Die Aufgabe "Ausfall bei FinanzOnline melden" nennt zusätzlich den Grund zum Auswählen: "3, Ausfall der Verbindung zur Signaturerstellungseinheit".

### 6.8 Bildschirme

Karte "Signatur" in den Einstellungen:

- Zustand in einem Wort: "Nicht eingerichtet", "Probe", "Online-Probe", "In Betrieb", jeweils mit "Signatur ausgefallen", wenn es so ist.
- Nicht eingerichtet: "Zum Ausprobieren einschalten", "Mit A-Trust ausprobieren", "Signatur einrichten" (ab S2b), "Karte prüfen".
- Online-Probe und In Betrieb: zusätzlich "Verbindung prüfen". Bei abgelehnten Zugangsdaten ein Hinweis mit "Erneut anmelden" (Online-Probe) oder "Zugangsdaten neu eingeben" (In Betrieb).
- In Betrieb: "Kassa außer Betrieb nehmen" statt "Probe beenden".

Alle neuen Bildschirme folgen `docs/design-regeln.md` und dem Bestand ("Karte prüfen" ist die Vorlage für "Verbindung prüfen"). Claude zeichnet sie als erste Aufgabe des Plans und zeigt sie Niko; der Bau wartet nicht auf eine Antwort.

### 6.9 Daten

Neue Version der Datenbank mit Migration und Test:

- Die Kette bekommt ihre Einheit (Probe, A-Trust Test, A-Trust echt). Vorhandene Ketten sind Probe.
- Zur Kette gehören auch die Aussteller-Zertifikate, damit sie im ausgegebenen Protokoll stehen.
- Der Stand bekommt das Kennzeichen "Zugangsdaten abgelehnt". (Im Bau liegt es im geschützten Speicher, nicht im Stand, siehe 11.)
- Im geschützten Speicher neu: Benutzername und Passwort von A-Trust.

### 6.10 Wie geprüft wird

- **Ohne Internet:** Tests der Online-Einheit gegen einen nachgebauten A-Trust im Test (jede Zeile aus 6.2 und 6.3, dazu: späte Antwort, kaputtes JSON, falsche Länge, falsche Signatur, Mitternacht).
- **Gegen das Testsystem von A-Trust:** ein eigener Lauf auf GitHub, getrennt vom Lauf `app`, damit ein Ausfall bei A-Trust `app` nicht rot macht. Er läuft auf Knopfdruck und bei Änderungen an der Online-Einheit. Er meldet sich an, signiert, prüft, probiert den gesperrten Test-Benutzer (ein Versuch) und erzeugt eine kleine Kette (Startbeleg, Verkäufe, Storno, Nullbeleg, Schlussbeleg).
  Grund für GitHub: Aus Claudes Arbeitsumgebung ist `hs-abnahme.a-trust.at` gesperrt. Gibt Niko die Adresse frei, läuft dasselbe auch dort.
- **Prüfwerkzeug des Finanzministeriums:** Das Protokoll aus dem Lauf gegen das Testsystem muss bestehen. Der erste Schritt des Baus stellt fest, ob das Werkzeug das Zertifikat des Testsystems annimmt. Wenn nicht, steht das in Abschnitt 11, und der Beweis verschiebt sich auf Nikos echtes Konto.
- **Am Tablet:** Prüfliste zur Online-Probe (einschalten, vier Haken, Verkauf, QR-Code, WLAN aus und wieder an mit Sammelbeleg, Dauer je Bon, Protokoll ausgeben). Zur Inbetriebnahme eine eigene Prüfliste.
- **Migration:** Test von der Datenbank der Version 1.4.0 auf die neue, mit einer laufenden und einer beendeten Probe-Kette.

## 7. Stufen

| Stufe | Inhalt | Niko bekommt |
| --- | --- | --- |
| S2a | Online-Einheit, Online-Probe, "Verbindung prüfen", Schutz des Kontos, Lauf gegen das Testsystem. | Eine Installationsdatei, mit der das Tablet über A-Trust signiert (Testbons), und eine Prüfliste. Geht ohne Vertrag. |
| S2b | Einrichtung mit echten Zugangsdaten, Angaben für FinanzOnline, Inbetriebnahme, "Kassa außer Betrieb nehmen". Eigener Plan nach Nikos Ergebnis aus S2a. | Eine Installationsdatei, mit der YICHI in Betrieb gehen kann. Zum Prüfen braucht es Nikos Konto bei A-Trust. |
| S3 | Inbetriebnahme bei YICHI (Kern 7). | Eine Prüfliste für den Tag der Umstellung. |

Der erste Plan umfasst nur S2a. Aus der Schlussprüfung von S1b (Kern 11.2) gehört in S2a, was mit der Online-Probe zum ersten Mal am Tablet sichtbar wird, weil ein Ausfall jetzt echt eintreten kann:

- Ein Testbon mit Ausfall-Vermerk zeigt am Bildschirm auch "Testbon".
- Der Grund eines Ausfalls steht im Hinweis und in der Karte "Signatur", in einem Satz ("Kein Internet.", "A-Trust antwortet nicht.", "A-Trust hat die Zugangsdaten abgelehnt.").
- Der Hinweis zeigt kein altes "Geht noch nicht." mehr.
- Ein `StateError` in der Karte "Signatur" bekommt einen Satz.

Hingenommen bleibt, dass ein Verkauf ein Mal etwa 6 statt 5 Sekunden warten kann; die Prüfliste sagt das. Der Rest aus Kern 11.2 wird in S2b erledigt, soweit er den echten Betrieb betrifft.

## 8. Technik-Festlegungen (Claude)

- Dart unter `app/lib/rksv/online/`, ohne Abhängigkeit zur Oberfläche. Web-Anfragen mit dem vorhandenen Paket `http`; der Client wird übergeben, damit Tests ihn ersetzen. Keine neuen Pakete.
- Prüfen der Signatur mit `pointycastle` (schon im Projekt).
- Der Server bleibt unberührt.
- Der Lauf gegen das Testsystem ist ein eigener Workflow unter `.github/workflows/`.

## 9. Offen

**Bei Niko**

1. Partnervertrag an A-Trust schicken. Danach im Webshop Guthaben aufladen und das Konto für YICHI anlegen (Ordnungsbegriff: UID oder Steuernummer von YICHI).
2. Paket wählen: Jeder Bon und jeder Sonderbeleg ist eine Signatur. Basic reicht für etwa 27 Bons am Tag. A-Trust fragen, was geschieht, wenn das Paket aufgebraucht ist.
3. Wie bisher: wer bei FinanzOnline anmeldet; ob YICHI in Betrieb geht, bevor der Server das Protokoll sichert (Claudes Rat: erst Stufe C2).

**Prüft Claude vor S2b**

4. Die Punkte am Wortlaut der Verordnung (Kern 9, Punkte 7 bis 13). Das Rechtsinformationssystem ist von hier nicht lesbar; Ersatz ist das Bundesgesetzblatt als Datei oder die Steuerberatung.

**Klärt der Bau von S2a zuerst**

5. Ob Android und GitHub dem HTTPS-Zertifikat von A-Trust vertrauen. Vertraut GitHub ihm nicht, hält der Bau an dieser Stelle an, und Claude meldet sich bei Niko mit den Möglichkeiten. Die Kassa liefert in S2a kein eigenes Zertifikat von A-Trust mit (6.4). Vertraut das Tablet ihm nicht, sagt "Verbindung prüfen" das in Zeile 1 mit einem eigenen Satz, und Niko schickt den Bericht.
6. Form der Antworten (Base64 oder Base64-URL, Text der Fehler), Kennzeichen des Ausstellers am Testsystem.
7. Ob das Prüfwerkzeug das Zertifikat des Testsystems annimmt. (Beantwortet: ja, siehe 11.)

## 10. Dem Bau überlassen

Namen von Klassen, Tabellen und Spalten, Aufteilung in Dateien, Wortlaut der Sätze innerhalb der Design-Regeln, Aussehen der Zeilen in "Verbindung prüfen", Form des gedruckten Zettels, wie der GitHub-Lauf das Protokoll für das Prüfwerkzeug bereitstellt.

## 11. Abweichungen beim Bau

Hier steht, was beim Bau von S2a anders entschieden wurde, als der Entwurf es oben beschreibt oder offenlässt, was A-Trusts Testsystem wirklich antwortet, und was es kostet. Der Stand gilt für die Version 1.5.0. Der Abschnitt ist für den, der S2b baut.

### 11.1 Abweichungen von den Abschnitten 6 bis 9

Das sind die Stellen, an denen der Bau von diesem Entwurf abweicht. Wo es zählt, steht dort oben ein Hinweis "siehe 11".

| Stelle | Entwurf sagt | Der Bau tut | Grund |
|---|---|---|---|
| 6.9 (P1) | Der Stand bekommt das Kennzeichen "Zugangsdaten abgelehnt". | Das Kennzeichen liegt im geschützten Speicher (`RksvSecrets`). Die Oberfläche liest es über den Sitzungshalter. | Siehe P1. |
| 6.6 (R3) | Zertifikat "heute gültig". | Am Testsystem ist ein abgelaufenes Zertifikat kein Problem. Die Prüfung bleibt für das echte System. | Das Test-Zertifikat von A-Trust ist seit 10.05.2020 abgelaufen. |
| 6.3 (R7) | Im Zustand "abgelehnt" keine Anmeldung ohne Antippen des Chefs. | Strenger: "Verbindung prüfen" schickt dann gar keine Anfrage, nicht nur keine Anmeldung. | Ein Lauf ohne Antippen darf das Konto in keiner Weise belasten. |
| 6.2 Schritt 4 (R4) | 401 beim Signieren heißt: Sitzung abgelaufen. | Gilt, aber der Test am Testsystem nimmt eine erfundene Sitzung, weil eine abgemeldete dort weiter signiert. | Siehe 11.3. |

Der offene Punkt 7 aus Abschnitt 9 ist beantwortet: Das Prüfwerkzeug des Finanzministeriums nimmt eine Kette an, die mit dem Test-Zertifikat von A-Trust signiert ist, solange die Belege innerhalb der Gültigkeit des Zertifikats liegen (siehe 11.5).

### 11.2 Entscheidungen im Plan

| Nr. | Entscheidung | Warum | Preis |
|---|---|---|---|
| P1 | Das Kennzeichen "Zugangsdaten abgelehnt" liegt im geschützten Speicher, nicht in der Datenbank. | Signiert wird in der Transaktion des Bons. Eine Anmeldung im Hintergrund, die in die Datenbank schreiben will, müsste auf diese Transaktion warten. Der geschützte Speicher kennt keine Transaktionen. | Die Oberfläche liest es über den Sitzungshalter. Weicht von 6.9 ab. |
| P2 | Die Online-Einheit wandelt jeden eigenen Fehler in einen Ausfall mit einem deutschen Satz. Das Journal übernimmt ihn als Grund. | Der Grund steht im Hinweis (Abschnitt 7). | Bei abgelaufener Frist bleibt der feste Satz des Journals "Die Signatur hat nicht geantwortet.". |
| P3 | "Verbindung prüfen" läuft vor dem Einschalten und außerhalb jeder Transaktion. Der Startbeleg wird danach wie jeder Bon mit 5 Sekunden Frist signiert. | Kern K1 bleibt. | Fällt das Netz dazwischen aus, beginnt keine Kette, und der Chef tippt noch einmal. |
| P4 | Kern K9 (Probe schaltet sich nach unerwartetem Fehler ab) gilt für beide Arten der Probe, nur für Fehler außerhalb der Einheit. | Die Kassa verkauft immer. | Keiner. |
| P5 | Task 1 (Erkundung) läuft zuerst, seine Befunde stehen im Plan und hier in 11.3. | Die Form der Antworten ist im Handbuch nicht vollständig beschrieben. | Ein GitHub-Lauf vor dem Bau. |
| P6 | Der öffentliche Test-Benutzer und der gesperrte Test-Benutzer von A-Trust stehen als Konstanten im Code. | Beide sind öffentlich. Die Online-Probe braucht kein Tippen. | Jeder kann damit signieren. Deshalb bleibt alles Testbon. |
| P7 | Eine Sitzung gilt nach 55 Minuten ohne Benutzung oder bei neuem Kalendertag (Ortszeit des Tablets) als abgelaufen. | A-Trust sagt 60 Minuten und Mitternacht. | Liegt Mitternacht bei A-Trust anders, fängt "401, einmal neu anmelden" es auf. |
| P8 | Kein eigenes Zertifikat von A-Trust in der App. | Offener Punkt 5. | Griff nicht: GitHub vertraut dem Zertifikat. |

### 11.3 Befunde vom Testsystem

Gefunden mit dem GitHub-Lauf `atrust-testsystem`. Diese Antworten gelten vor dem Handbuch.

- `ZDA` liefert das Kennzeichen `AT1`. Das ist das Kennzeichen der Online-Probe.
- `Certificate` liefert Zertifikat, zwei Aussteller-Zertifikate, die Seriennummer dezimal und hex (Großbuchstaben) und das Verfahren `ES256`. Die Seriennummer wird ohne Beachtung von Groß- und Kleinschreibung verglichen.
- Das Test-Zertifikat ist abgelaufen (gültig 10.03.2016 bis 10.05.2020). Siehe R3.
- Die Aussteller-Zertifikate haben RSA-Schlüssel. Sie werden nur gespeichert und ausgegeben, nie als Karten-Zertifikat gelesen.
- `Sign/Hash` liefert die Signatur als Base64-URL ohne `=`, 64 Bytes. Der Client nimmt beide Alphabete an.
- Fehler erkennt die Kassa nur am Statuscode: 401 für eine unbekannte Sitzung, 403 für den gesperrten Benutzer, 404 für eine unbekannte Adresse. Der Körper ist eine HTML-Seite und wird bei Status ungleich 200 nie gelesen.
- Nach dem Abmelden signiert dieselbe Sitzung weiter. Auf das Abmelden ist kein Verlass.
- Eine Signatur dauert etwa 0,13 Sekunden (von GitHub aus).

### 11.4 Entscheidungen während des Baus

| Nr. | Entscheidung | Warum | Preis |
|---|---|---|---|
| R1 | `connectionCheckProvider` liegt in `online_providers.dart`. | Der Bildschirm aus Task 6 braucht den Provider, und der Plan hat ihn nicht genannt. | Wäre es falsch, hätte Task 6 ihn selbst gebaut. |
| R2, R6 | `AtrustSessionKeeper.restore()` ist wiederholbar. Der Bauer der Einheit im Journal wartet nicht darauf. Der Halter liest das gespeicherte Kennzeichen "abgelehnt" selbst und schickt nichts, solange es unbekannt ist. | Ein Fehler beim Bauen der Einheit würde die Probe abschalten, statt einen Ausfall zu verzeichnen. | Keiner. |
| R3 | Am Testsystem ist ein abgelaufenes Zertifikat kein Problem. | Siehe 11.3. Weicht von 6.6 ab. | Die Prüfung "gültig" gilt erst für das echte System. |
| R4 | Der Weg "401, neu anmelden" wird am Testsystem von A-Trust mit einer erfundenen Sitzung getestet. | Eine abgemeldete Sitzung signiert dort weiter. | Der Test nutzt eine erfundene Sitzung statt einer abgelaufenen. |
| R5 | Der frühe Lauf des Prüfwerkzeugs von Hand entfällt. | Aus der Umgebung des Baus war keine Signatur vom Testsystem von A-Trust zu bekommen. | Task 8 beantwortete die Frage. |
| R7 | Bei abgelehnten Zugangsdaten schickt "Verbindung prüfen" ohne Antippen des Chefs gar keine Anfrage. | Schutz des Kontos. Strenger als 6.3. | Keiner. |
| R8 | Die Probe-Unterschrift in "Verbindung prüfen" signiert den ASCII-Text `Kassa Verbindung pruefen`. | Die Einheit signiert nur ASCII (der Plan hatte einen Umlaut). | Keiner. |
| R9 | Der Satz zu abgelehnten Zugangsdaten erscheint in der Kassa nur, solange eine Online-Probe läuft. | Das Kennzeichen kann eine beendete Probe überdauern. | Keiner. |
| R10 | Im Hinweis der Kassa steht der Grund in einer eigenen Zeile. | Die Zeichnungen hatten einen einzigen Absatz. | Keiner. |
| R11 | "Geht noch nicht." verschwindet, wenn sich der Ausfall oder sein Grund ändert, nicht bei jedem Verkauf. | Ausfall und Grund sind gleich geblieben, also stimmt das Ergebnis "Geht noch nicht." noch. | Wäre es falsch, kostet es eine Zeile. |
| R12 | Der Test gegen das Testsystem von A-Trust hat einen Probelauf gegen den Nachbau, der überall läuft. | Der echte Lauf geht nur auf GitHub. Fehler im Testcode hätten Läufe gegen das Testsystem von A-Trust gekostet. | Wäre es falsch, kostet es ein paar Sekunden Testzeit am Rechner. |

Weitere Entscheidungen beim Bau:

- Die Migration von Datenbankversion 3 auf 4 legt die Tabelle der Ketten mit festem SQL an, weil die erzeugte Tabelle schon die neue Spalte enthält. Geprüft sind alle Wege 1 nach 5, 2 nach 5, 3 nach 5 und 4 nach 5. Sie ergeben dasselbe Schema wie eine neue Datenbank. Nach einer Migration steht die Spalte `unit` zuletzt.
- Die Zeile zum Ausfall in der Karte "Signatur" zeigt nur den Grund, etwa "Kein Internet.". Die Zeichnung s2a-08 zeigt "Seit 13:05. Kein Internet.". Die Uhrzeit steht im Hinweis der Kassa.
- Die Karte "Signatur" zeigt den Grund eines Ausfalls auch bei der einfachen Probe. Der Satz für einen `StateError` gilt für jede Aktion der Karte. Die Frage "Speisekarte neu einspielen" scrollt ins Bild, weil die neue Zeile sie sonst unter den Rand schob.

### 11.5 Ergebnis der Läufe

**Lauf gegen das Testsystem** (GitHub `atrust-testsystem`, Nummer 6, Commit 2a19820, 19.11.2026), bestanden:

- "Verbindung prüfen" gibt vier Haken.
- 20 Signaturen mit genau einer Anmeldung, jede am Zertifikat geprüft.
- Eine erfundene Sitzung gibt "abgelaufen".
- Der gesperrte Test-Benutzer wird abgewiesen, danach geht keine Anfrage mehr hinaus.
- Eine Kette aus Startbeleg, Verkauf, Storno, Monatsbeleg, Verkauf über 1.234,56 Euro, Nullbeleg und Schlussbeleg wurde von A-Trust signiert und ist in sich stimmig.

**Prüfwerkzeug des Finanzministeriums** (`tool/rksv/pruefen_datei.sh`) über genau diese Kette (7 Belege vom 18.11.2019 bis 02.12.2019, Ausstellerkennzeichen AT1, Zertifikat 2159b9f6): alle 30 Ergebnisdateien PASS. Das Werkzeug nimmt das Test-Zertifikat an, solange die Belege innerhalb von dessen Gültigkeit liegen.

Für den Bau von S2b: Das Ergebnis gilt für Belege mit einem Datum innerhalb der Gültigkeit des Test-Zertifikats von A-Trust (2016 bis 2020). Belege, die heute am Tablet entstehen, liegen außerhalb davon. Ein Protokoll, das aus dem Tablet während der Online-Probe ausgegeben wird, kann das Prüfwerkzeug darum allein deswegen ablehnen.

### 11.6 Bekannte kleine Punkte

Nicht in S2a behoben, außer die Schlussprüfung entscheidet anders.

- Solange das Tablet offline ist, löst jeder Bon zwei Anmeldeversuche aus (den des Bons und einen im Hintergrund). Das ist begrenzt, keine Schleife.
- Scheitert das Schreiben des Kennzeichens "abgelehnt" in den geschützten Speicher, gilt es nur im Arbeitsspeicher. Nach einem Neustart ginge eine Anmeldung mehr hinaus.
- Der Zweig der Prüfung "Schlüssel nicht P-256" ist nicht erreichbar, weil der Client ein solches Zertifikat schon als nicht lesbar meldet.
- Der Hinweis unter einer gescheiterten Probe-Unterschrift wird durch den Vergleich von Sätzen gefunden.
- Der Bildschirm "Verbindung prüfen" wiederholt den Rahmen von "Karte prüfen", statt ihn zu teilen.
- Die Einheit einer Kette ließe sich in der Datenbank ändern, solange die Kette läuft. Kein Code tut es, kein Trigger verbietet es.
- Im ersten Ausfall kann ein Verkauf ein Mal bis zu 5 Sekunden auf die Signatur warten (dazu die übliche Zeit, in der Prüfliste "bis zu 6 Sekunden"). Danach wartet er etwa 1 Sekunde.

### 11.7 Schlussprüfung

Die Prüfung des ganzen Zweigs vor der Übergabe an das Tablet hat diese Punkte geändert:

- A1: Eine Anmeldung bei A-Trust wartet höchstens 20 Sekunden (`AtrustSessionKeeper.loginLimit`). Danach bekommen alle Wartenden "Kein Internet.", und der nächste Bon meldet neu an. Eine späte Antwort zählt trotzdem: 401 oder 403 setzt "abgelehnt", eine Sitzung gilt nur, wenn der Halter keine hat. Der Aufbau einer Verbindung darf 10 Sekunden dauern.
- A2: Der Bericht von "Verbindung prüfen" nennt bei einer gescheiterten Zeile die Fehlerart: den Typ des Fehlers und den Fehlertext des Betriebssystems, bei TLS auch den festen Text der TLS-Bibliothek. Am Bildschirm steht weiter nur der Satz. Eine Zeile mit Haken nennt ihre Dauer im Bericht nur noch ein Mal.
- A3: Der Client folgt keiner Weiterleitung mehr.
- A4: Schritt 5 der Migration ist wiederholbar. Wurde die App zwischen dem Anlegen der Spalte `unit` und dem Schreiben der Version beendet, startet sie trotzdem.

Entscheidungen dazu:

| Nr. | Entscheidung | Warum | Preis |
|---|---|---|---|
| F1 | Die Anmeldung wartet 20 Sekunden. Eine späte erfolgreiche Anmeldung gilt nur, wenn der Halter keine Sitzung hat. | Eine Länge für "A-Trust hat nicht geantwortet" überall. Eine zweite Sitzung würde nur weggeworfen. | Wäre es falsch, kostet es eine Konstante. |
| F2 | Die Fehlerart im Bericht ist der Typ und der Fehlertext des Betriebssystems, nie Text oder Adresse aus der HTTP-Bibliothek. | Die können die Sitzung enthalten. | Ein Bericht, der weniger sagt, als er könnte. |
| F3 | Wie lange eine offene Verbindung ungenutzt bleibt, bleibt bei der Vorgabe (15 Sekunden). Die Prüfliste verspricht dafür weniger. | Eine länger gehaltene Verbindung, die A-Trust schon geschlossen hat, könnte aus einem Verkauf einen Ausfall machen. | Verkäufe bleiben ein paar Zehntelsekunden langsamer, als sie sein könnten. |
| F5 | Der Punkt 7 unten bleibt in Version 1.5.0 und wird in S2b als Erstes behoben. | Er braucht zwei überlappende Anmeldungen desselben Benutzers, die A-Trust verschieden beantwortet. Es geht dabei keine Anmeldung hinaus, also zählt nichts für eine Sperre, und das Konto ist der öffentliche Test-Benutzer. | Am Testsystem ein paar Signaturen, während "abgelehnt" gilt. Vor einem echten Konto muss es zu sein. |

Bekannte Punkte, die in S2a bleiben:

- Auch an einer Kette der Online-Probe steht an einigen Stellen "Probe-Signatur": `receipt_detail.dart:400`, `probe_question.dart:135`, `void_question.dart:13`, `rksv_journal.dart:96`, `rksv_service.dart:35`.
- Ein unterbrochener Aufbau der TLS-Verbindung zeigt "Das Tablet vertraut dem Zertifikat von A-Trust nicht.".
- Scheitert der Schritt vor Zeile 1 (das Laden oder Aufheben von "abgelehnt"), gibt es kein "Bericht teilen".
- Wartende Zeilen zeigen Nummern, kein Schloss.
- Scheitert das Schreiben des Kennzeichens "abgelehnt", wird der Fehler verschluckt. Nach einem Neustart geht dann eine Anmeldung mehr hinaus.

Für den Bau von S2b:

1. Im echten Betrieb lässt ein Fehler beim Bauen der Einheit den Verkauf scheitern: `receipt_repository.dart:531` und `:611` werfen außerhalb der Probe weiter, und `rksv_providers.dart:51` wirft "Noch nicht gebaut.". Entwurf 6.3 will dort einen Ausfall.
2. Das Kennzeichen "abgelehnt" ist ein einziger Schlüssel (`rksv_secrets.dart:54`) für Testsystem und echtes System. Es sollte je System gelten oder gelöscht werden, wenn Zugangsdaten eingegeben werden.
3. Die Zugangsdaten des Halters sind feste Felder des Konstruktors, und der Provider ist nach dem Testsystem benannt. Zugangsdaten aus dem geschützten Speicher einplanen.
4. 403 auf `Sign/Hash` gilt als abgelaufene Sitzung (`atrust_client.dart`, `signHash`). Auf einem echten Konto kann es etwas anderes heißen und würde zwei Anmeldungen je Bon auslösen.
5. Das verschluckte Schreiben des Kennzeichens "abgelehnt" und der Wartesatz von Zeile 1 bei "abgelehnt" werden erreichbar, sobald ein Chef ein falsches Passwort tippen kann.
6. Mit der Grenze für die Anmeldung kann ein hängendes Netz alle 20 Sekunden eine Anmeldung losschicken, bis die erste Antwort kommt. Mit falschen Zugangsdaten auf einem echten Konto zählt das für die Sperrgrenze von A-Trust.
7. Gefunden beim Gegenlesen von A1: Antwortet eine aufgegebene Anmeldung spät mit 401 oder 403, während schon eine neue läuft, und antwortet die neue danach mit 200, dann behält der Halter deren Sitzung, obwohl "abgelehnt" gilt (`atrust_session_keeper.dart`, `_answer`). Wer auf die neue Anmeldung gewartet hat, schickt dann je eine Signatur los, und Zeile 3 von "Verbindung prüfen" zeigt nach dem Tippen des Chefs "Angemeldet", ohne neu anzumelden. Abhilfe: gleich nach der Antwort der Anmeldung prüfen, ob "abgelehnt" gilt, und dann mit "abgelehnt" enden.

## 12. Abweichungen beim Bau von S2b

Hier steht, was beim Bau von S2b anders entschieden wurde, als der Entwurf es oben beschreibt oder offenlässt, was am Wortlaut der Verordnung geprüft wurde und was für die Steuerberatung offen bleibt. Der Stand gilt für die Version 1.7.0. Der Abschnitt ist für den, der nach S2b weiterbaut, und für die Steuerberatung.

### 12.1 Entscheidungen im Plan

Aus dem Plan `docs/superpowers/plans/2026-11-20-rksv-s2b-inbetriebnahme.md`, Abschnitt "Entscheidungen in diesem Plan (Claude)".

| Nr. | Entscheidung | Warum | Preis |
|---|---|---|---|
| Q1 | Die Datenbank bleibt Version 6. Es gibt keine Migration. | `rksv_chains.mode` und `unit` sind Text und kennen `live` und `atrust` schon. Alles Neue liegt im geschützten Speicher oder in `rksv_state.tasks`. | Die für S2b reservierte Version 7 bleibt frei. |
| Q2 | Kassen-Kennung und AES-Schlüssel entstehen, wenn der Chef zum ersten Mal die "Angaben für FinanzOnline" öffnet, und liegen bis zur Inbetriebnahme im geschützten Speicher (`PendingSetup`). Die Inbetriebnahme verwendet genau diese Werte. | Die Angaben, die bei FinanzOnline eingetragen werden, müssen zu der Kette passen, auch wenn zwischen Abschreiben und Start Tage liegen. | Bricht der Chef ab, bleiben die Werte liegen, bis er startet oder die Zugangsdaten löscht. |
| Q3 | Benutzername und Passwort werden mit der Tastatur getippt, nur im Bildschirm "Zugangsdaten von A-Trust". `test/no_text_field_test.dart` lässt genau diese eine Datei zu. | Entwurf 6.7, Ausnahme von der Touch-Regel, weil Einrichtung. | Ein Bildschirm mit Tastatur. |
| Q4 | "Abgelehnt" gilt je System: das echte System hat ein eigenes Kennzeichen (`rksv_atrust_rejected_live`). Neue Zugangsdaten speichern hebt es auf. | Entwurf 11.7, Punkt 2. Eine Ablehnung des Test-Benutzers darf den echten Betrieb nicht stilllegen und umgekehrt. | Keiner. |
| Q5 | Der Halter liest die Zugangsdaten bei jeder Anmeldung neu aus dem geschützten Speicher. Fehlen sie, schickt er nichts und meldet "Die Zugangsdaten von A-Trust fehlen.". Speichert der Chef neue, verwirft der Halter seine Sitzung. | Entwurf 11.7, Punkt 3. | Ein Lesezugriff je Anmeldung. |
| Q6 | Im Zustand `live` ist jeder Fehler beim Bauen oder Benutzen der Signatureinheit ein Ausfall mit einem deutschen Satz. Nur ein Fehler der Datenbank lässt den Verkauf scheitern. K9 (Probe schaltet sich ab) bleibt allein für `probe`. | Entwurf 6.3 und 11.7, Punkt 1. | Ein Programmierfehler in der Einheit zeigt sich als Ausfall statt als Absturz. |
| Q7 | `goLive` ist eine einzige Transaktion: laufende Probe mit Schlussbeleg beenden, neue Kette `live`, Startbeleg von A-Trust signiert. Scheitert der Startbeleg, bleibt alles, wie es war, auch die Probe. | Kein halber Zustand. | Die Datenbank ist für die Dauer einer Signatur belegt (wie bei jedem Bon). |
| Q8 | "Außer Betrieb" ist kein neuer Modus: `mode` wird `off`, und der Stand heißt "Außer Betrieb", wenn die jüngste Kette eine beendete `live`-Kette ist. Offene Aufgaben bleiben, dazu kommt "Außerbetriebnahme melden". | Keine Migration (Q1). | Eine Abfrage mehr im Stand. |
| Q9 | Signiert A-Trust mit einer frisch geholten Sitzung wieder nicht (401 oder 403), meldet die Einheit für diese Sitzung nicht noch einmal neu an. Der Bon wird ein Ausfall mit "A-Trust hat die Signatur abgelehnt.". | Entwurf 11.7, Punkt 4: Auf einem echten Konto kann 403 etwas anderes heißen als "Sitzung abgelaufen", etwa ein aufgebrauchtes Paket. Sonst ginge je Bon eine Anmeldung hinaus. | Läuft eine Sitzung wirklich zweimal hintereinander ab, dauert der Ausfall bis zur nächsten frischen Sitzung (55 Minuten Ruhe oder neuer Tag). |
| Q10 | Der Server und die Nachrichten an ihn bleiben unverändert. `rksv_chains.unit` geht weiter nicht zum Server. Das Feld `test` eines Bons kann sich nie ändern: Bon und Protokoll-Eintrag entstehen in derselben Transaktion, und der Modus einer Kette wird nie umgeschrieben (die Inbetriebnahme beginnt eine neue Kette). Tests halten das fest. | Der Hinweis aus Teil C Stufe 2 ("test steckt in der Prüfsumme") braucht so keine Änderung am Server und kein Ausrollen. | Sollte je ein Weg entstehen, der einen Bon ohne seinen Eintrag sendet, meldet der Server einen Konflikt. |
| Q11 | Kein Test und kein Lauf auf GitHub spricht mit dem echten System (`rksv.a-trust.at`). `AtrustSystem.live` wird nur in `online_providers.dart` gebaut. Geprüft wird der echte Weg mit dem nachgebauten A-Trust und am Tablet mit Nikos Konto. | Es gibt noch kein Konto, und ein Test darf nie echte Signaturen verbrauchen. | Der erste echte Lauf ist Nikos Prüfliste. |
| Q12 | Der Benutzername des echten Kontos gilt wie das Passwort als Geheimnis: Er steht in keinem Bericht, Log, Fehlertext oder Ausdruck. Am Bildschirm "Zugangsdaten" ist er zu sehen. | Entwurf 6.4. | Der Bericht von "Verbindung prüfen" nennt am echten System keinen Benutzer. |
| Q13 | Solange eine nach 20 Sekunden aufgegebene Anmeldung noch keine Antwort hat, schickt der Halter keine neue, höchstens 120 Sekunden lang (`AtrustSessionKeeper.abandonedLimit`). In dieser Zeit endet `session()` sofort mit "Kein Internet.". | Entwurf 11.7, Punkt 6: Ein hängendes Netz würde sonst alle 20 Sekunden eine Anmeldung losschicken, und mit einem falschen Passwort zählt jede für die Sperre des Kontos. | Nach einem hängenden Netz dauert der Ausfall bis zu zwei Minuten länger. |
| Q14 | Scheitert das Schreiben des Kennzeichens "abgelehnt", merkt sich der Halter das und versucht es bei jedem `session()`, `warmUp()` und `restore()` wieder, bis es steht. Im Arbeitsspeicher gilt "abgelehnt" sofort. | Entwurf 11.7, Punkt 5: Sonst geht nach einem Neustart eine Anmeldung mit dem falschen Passwort mehr hinaus. | Bleibt der Speicher bis zum Neustart kaputt, geht diese eine Anmeldung doch hinaus. |
| Q15 | "Protokoll ausgeben" nimmt die laufende Kette, wenn sie `live` ist. Sonst nimmt es die jüngste beendete `live`-Kette, wenn es eine gibt, und erst sonst wie bisher die laufende oder jüngste Kette der Probe. Die Außerbetriebnahme legt die Aufgabe "Protokoll sichern" an. | Das Protokoll des echten Betriebs muss aufgehoben werden (7 Jahre) und darf nicht unerreichbar werden, nur weil danach wieder eine Probe läuft. | Nach einem echten Betrieb lässt sich das Protokoll einer Probe nicht mehr ausgeben. Gab es mehrere echte Ketten, ist nur die jüngste erreichbar; die älteren wurden bei ihrer Außerbetriebnahme gesichert. |
| Q16 | "Verbindung prüfen" am echten System sagt dazu: "Jede Prüfung zählt bei A-Trust als eine Signatur." | Die Probe-Unterschrift entsteht mit dem echten Konto und geht vom Paket ab. | Ein Satz mehr. |
| Q17 | Das Journal behält den AES-Schlüssel einer `live`-Kette im Arbeitsspeicher, sobald er einmal gelesen wurde (`rememberLiveKey`, `primeLiveKey`). Ketten der Probe lesen weiter jedes Mal. | Gefunden in Task 2: Ohne den Schlüssel gibt es keinen gültigen Eintrag, und ein geschützter Speicher, der gerade nicht liest, hätte im echten Betrieb den Verkauf scheitern lassen. | Startet die App im echten Betrieb und der geschützte Speicher liest gar nicht, scheitert der Verkauf weiter, bis er wieder liest. |

### 12.2 Abweichungen vom Entwurf (Abschnitte 6 bis 9)

- 6.7 Schritt 3: Kassen-Kennung und AES-Schlüssel entstehen beim ersten Öffnen der "Angaben für FinanzOnline" und bleiben bis zur Inbetriebnahme im geschützten Speicher (Q2). Der Entwurf sagte nicht, wann sie entstehen.
- 6.7 Schritt 4: Der Hinweis steht auf demselben Bildschirm wie die Angaben, rechts unter "Bevor du startest", nicht als eigener Schritt.
- 6.8: Es gibt den Zustand "Außer Betrieb" in der Karte "Signatur". Er ist kein eigener Modus in der Datenbank (Q8).
- 6.9: Die Datenbank bleibt bei Version 6 (Q1). Die für S2b vorgemerkte Version 7 bleibt frei.
- 6.3: Im echten Betrieb ist jeder Fehler der Signatureinheit ein Ausfall (Q6). Ausnahme: Startet die App im echten Betrieb und der geschützte Speicher liest den AES-Schlüssel gar nicht, scheitert der Verkauf, bis er wieder liest (Q17).
- Entwurf 11.7, Entscheidung F1 (S2a) ist geändert: Nach einer aufgegebenen Anmeldung wartet der Halter bis zu 120 Sekunden, bevor er neu anmeldet (Q13).
- Die Angaben am Bildschirm stehen in der Schrift JetBrains Mono (SemiBold, SIL Open Font License 1.1, Datei und Lizenztext unter `app/assets/fonts/`), damit I, l, 1, 0 und O beim Abschreiben zu unterscheiden sind.
- Der Server und die Nachrichten an ihn sind unverändert (Q10).

### 12.3 Entscheidungen während des Baus

| Nr. | Entscheidung | Warum | Preis |
|---|---|---|---|
| B1 | Zugangsdaten werden erst nach dem Lesen noch einmal gegen "abgelehnt", "neue Zugangsdaten" und "aufgegeben" geprüft, bevor die Anmeldung hinausgeht. | Ein langsamer geschützter Speicher hätte sonst Anmeldungen nach einer Ablehnung losgeschickt. | Keiner. |
| B2 | Läuft die Sitzung von selbst ab und A-Trust lehnt die Signatur danach zweimal ab, gehen für diesen Bon zwei Anmeldungen hinaus, danach je Bon keine mehr. | Die Regel Q9 gilt je Sitzung. | Bei aufgebrauchtem Paket zwei Anmeldungen je 55 Minuten, mit richtigen Zugangsdaten, also ohne Sperre. |
| B3 | Zwei Sätze, die der Plan nicht kannte: "Die Kassa konnte nicht in Betrieb genommen werden." und "Das Tablet konnte den Schlüssel nicht lesen." | Der Plan nannte für diese Fehler keinen Satz. | Der Wortlaut kann sich ändern. |
| B4 | Liegen nach der Inbetriebnahme noch vorbereitete Werte im geschützten Speicher, deren Kassen-Kennung schon eine Kette trägt, gelten sie als nicht vorhanden. | Sonst bekäme eine zweite Inbetriebnahme dieselbe Kassen-Kennung. | Keiner. |
| B5 | Endet eine Probe nach einer Außerbetriebnahme, bleiben die Aufgaben der echten Kette stehen. Nur die Aufgaben der Probe gehen weg. | Sonst wären "Außerbetriebnahme melden" und "Protokoll sichern" still verschwunden. | Zwei Aufgaben ohne Kettennummer (Jahresbeleg, Protokoll je Quartal) werden nach ihrem Zeitpunkt zugeordnet. |
| B6 | "Verbindung prüfen" zeigt bei schon abgelehnten Zugangsdaten das Kreuz sofort in der ersten Zeile, ohne Anfrage. Wird die Anmeldung während der Prüfung abgelehnt, steht das Kreuz weiter in Zeile "Anmeldung". | Entwurf 11.7, Punkt 5. | Bestehende Tests erwarten das Kreuz jetzt in Zeile 1. |
| B7 | Der Bericht von "Verbindung prüfen" hat am echten System die Zeile "Konto: echtes Konto". | Wer den Bericht bekommt, sieht, welches System geprüft wurde, ohne den Benutzernamen. | Keiner. |
| B8 | Das Passwortfeld meldet sich der Tastatur als Passwort. Nur das Feld für den Benutzernamen verwendet die Tastatur für sichtbare Passwörter. | Sonst behandelt die Tastatur von Android das Feld nicht geschützt. | Keiner. |
| B9 | "Zurück" aus den "Angaben für FinanzOnline" führt zu den gespeicherten Zugangsdaten, nicht zur Prüfung. | Eine neue Prüfung zählt bei A-Trust als Signatur. | Ein Tippen mehr, wenn man die Prüfung noch einmal sehen will. |
| B10 | Während die Kassa in Betrieb geht oder außer Betrieb geht, sind "Zurück", die Bereiche, die Einstellungen-Taste und Abmelden gesperrt. | Das Ergebnis eines Schritts, der sich nicht zurücknehmen lässt, darf nicht verloren gehen. | Bis zu einer Minute ohne Bedienung, wenn A-Trust und der geschützte Speicher langsam antworten. |
| B11 | "Angaben drucken" zeigt ohne Drucker oder bei einem Fehler den Satz des Druckers. Scheitert der Druck des Startbelegs, steht kein Satz da; der Beleg lässt sich unter "Bons" drucken. | Der Nullbeleg zeigt in diesem Fall keinen Satz, auf den der Plan verwies. | Keiner. |
| B12 | Die Karte "Signatur" darf höher sein als der Bildschirm eines Tablets mit 800 dp Höhe (Probe 840 bis 878 dp, In Betrieb rund 940 dp). Die Einstellungen lassen sich wischen. | Die Zeile "Signatur einrichten" muss auch aus der Probe erreichbar sein. | Für die letzten Zeilen der Karte ist ein Wischen nötig. |
| B13 | Nach "Kassa außer Betrieb nehmen" steht keine eigene Meldung da. Die Pille wechselt auf "Außer Betrieb", der Schlussbeleg wird gedruckt, zwei Aufgaben erscheinen. | Plan und Bild nennen keinen Satz. | Keiner. |
| B14 | Ohne Signatur steht "Protokoll ausgeben" vor den Zeilen zum Einschalten, auch nach einer beendeten Probe. | Bild der Karte "Außer Betrieb". | Die Reihenfolge der Zeilen in "Nicht eingerichtet" hat sich für Geräte mit einer beendeten Probe geändert. |
| B15 | Solange "In Betrieb nehmen" oder "Außer Betrieb" läuft, gilt dieselbe Sperre der Bedienung (ein Mechanismus für beide). `openCredentials` tut für Mitarbeiter ohne Chef-Recht nichts. | Entscheidung B10; ein Mitarbeiter hätte sonst den Bildschirm für den nächsten Chef vorbereitet. | Keiner. |
| B16 | Im Ausfall in Betrieb steht unter der Pille nur der Grund, ohne "Seit 13:05." wie im Bild. | Der Plan sagt "wie in der Online-Probe", dort steht auch keine Uhrzeit. | Die Uhrzeit des Ausfalls steht nur am Bon und in der Aufgabe. |
| B17 | Der geschützte Speicher löscht bei einem Lesefehler nichts mehr. Das gilt für die Signatur, die Kopplung mit dem Server und den Schutz der PIN. | Die Voreinstellung des Bausteins hätte den Schlüssel der echten Kette beim ersten Lesefehler für immer gelöscht. | Ein Lesefehler bleibt ein Fehler, bis der Speicher wieder liest. |
| B18 | Android sichert die Daten der App nicht mit und überträgt sie nicht auf ein neues Gerät. | Eine zurückgespielte Datenbank ohne ihre Schlüssel wäre eine Kassa, die nicht verkaufen kann. | Ein neues Tablet beginnt leer. Die Daten kommen vom Server ("Neu einspielen"). |
| B19 | Vor "In Betrieb nehmen" meldet sich die Kassa bei A-Trust an. | Nach einer langen Pause hätten Anmeldung und Signatur zusammen nur 5 Sekunden gehabt. | Keiner. |
| B20 | Zugangsdaten und vorbereitete Werte werden je als ein Wert gespeichert. | Ein Fehler zwischen zwei Schreibvorgängen hätte einen neuen Benutzernamen mit dem alten Passwort hinterlassen. | Keiner. |
| B21 | "Verbindung prüfen" vergleicht im Betrieb das Zertifikat des Kontos mit dem der laufenden Kette. Passt es nicht, steht ein Kreuz bei "Zertifikat". | Zugangsdaten eines anderen Kontos hätten vier Haken gezeigt, und jeder Bon wäre ein Ausfall geworden. | Ein neues Zertifikat desselben Kontos zeigt auch ein Kreuz. |
| B22 | Kann die Kassa den Schlüssel nicht lesen, steht "Das Tablet konnte den Schlüssel nicht lesen. Bitte nichts löschen und die App nicht neu installieren." | Der alte Satz schickte den Chef im Kreis. | Einen Weg, den Schlüssel neu einzugeben, gibt es noch nicht. |

### 12.4 Was am Wortlaut der Verordnung geprüft wurde (20.11.2026)

Quellen: Text der RKSV, Stand 11/2015; Leitfaden der WKO, Stand 11/2016; Handbuch des BMF zu Registrierkassen in FinanzOnline, Stand 1/2021.

- Startbeleg: Betrag 0, ausdrucken, mit der App "BMF Belegcheck" prüfen, aufheben.
- Anmeldung von Signatureinheit und Kassa bei FinanzOnline: binnen einer Woche nach der Inbetriebnahme.
- Protokoll (Datenerfassungsprotokoll): vierteljährlich auf einem externen Medium sichern.
- Monatsbeleg: zu jedem Monatsende, Betrag 0. Jahresbeleg ist der Monatsbeleg für Dezember: ausdrucken, prüfen, aufheben.
- Ausfall der Signatureinheit: Ein Ausfall, der nicht nur vorübergehend ist, ist ohne unnötigen Aufschub zu melden. Die Fristen "48 Stunden" und "eine Woche" stehen nur in den Leitfäden. Nach dem Ausfall ein Sammelbeleg mit Betrag 0. Grund in FinanzOnline: 3, Ausfall der Verbindung zur Signaturerstellungseinheit.
- Außerbetriebnahme: Schlussbeleg mit Betrag 0, ausdrucken und aufheben; Meldung bei FinanzOnline binnen einer Woche (Handbuch des BMF); Grund 6, planmäßige Außerbetriebnahme.

### 12.5 Offen für die Steuerberatung

- Die Kassa erstellt den Monatsbeleg erst vor dem ersten Bon des neuen Monats. Reicht das?
- Bis wann muss der Jahresbeleg geprüft sein? "Bis 15. Februar" steht in den drei Quellen nicht.
- Wie läuft der Tausch der alten Kassa genau ab (Schlussbeleg dort, Abmeldung, Reihenfolge)?
- Muss das Ende eines Ausfalls gemeldet werden, wenn die Kassa während des Ausfalls außer Betrieb geht?

### 12.6 Bekannte Punkte, die in S2b bleiben

- Geht der Schlüssel der echten Kette wirklich verloren (zum Beispiel weil der Schlüsselspeicher des Tablets kaputt ist), kann die Kassa nicht verkaufen und nicht außer Betrieb gehen. Die App löscht ihn nicht mehr selbst (B17, B18). Einen Weg, den Schlüssel vom Zettel neu einzugeben, gibt es noch nicht. Das braucht eine Tastatur und ist eine Entscheidung für Niko.
- Im Verkauf steht in diesem Fall weiter "Der Bon konnte nicht gespeichert werden. Bitte noch einmal."
- Nach einer zweiten Inbetriebnahme gibt "Protokoll ausgeben" die neue Kette aus. Die offene Aufgabe "Protokoll sichern" der alten Kette führt dann zur falschen Kette (Q15).
- Im Betrieb werden neue Zugangsdaten gespeichert, bevor sie geprüft sind. Ein Tippfehler führt zu einem Ausfall und einer abgelehnten Anmeldung, bis die richtigen eingegeben sind.
- Der Prüfwert des AES-Schlüssels ist nach der Beschreibung des Ministeriums gerechnet. Einen Vergleichswert aus dem Code des Ministeriums gibt es nicht. Der erste echte Beweis ist, dass FinanzOnline ihn annimmt.
- Wird die Kassa während eines Ausfalls außer Betrieb genommen, trägt der Schlussbeleg den Vermerk des Ausfalls. Die Frage dazu sagt das nicht, und es entsteht keine Aufgabe "Ende des Ausfalls melden".
- Die Seiten mit Passwort und AES-Schlüssel lassen sich am Tablet als Bildschirmfoto aufnehmen. Die Prüfliste verbietet es, die App verhindert es nicht.
- Speicher-Aufrufe im Bildschirm "Zugangsdaten von A-Trust" haben keine Zeitgrenze. Hängt der geschützte Speicher, bleibt die Seite leer oder die Taste gesperrt.
- Nach dem Speichern neuer Zugangsdaten kann die Zeile "Anmeldung" bis zu zwei Minuten "Kein Internet." zeigen, wenn davor eine Anmeldung ohne Antwort geblieben ist (Q13).
- Der Satz "A-Trust hat die Zugangsdaten abgelehnt." steht in der Karte "Signatur" zweimal.
- Kleinere Punkte aus den Prüfungen der einzelnen Aufgaben stehen im Protokoll des Baus.
