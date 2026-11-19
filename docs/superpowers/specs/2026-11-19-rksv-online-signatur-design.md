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
| R1 | `connectionCheckProvider` liegt in `online_providers.dart`. | Alles zur Online-Einheit steht an einem Ort. | Keiner. |
| R2, R6 | `AtrustSessionKeeper.restore()` ist wiederholbar. Der Bauer der Einheit im Journal wartet nicht darauf. Der Halter liest das gespeicherte Kennzeichen "abgelehnt" selbst und schickt nichts, solange es unbekannt ist. | Ein Fehler beim Bauen der Einheit würde die Probe abschalten, statt einen Ausfall zu verzeichnen. | Keiner. |
| R3 | Am Testsystem ist ein abgelaufenes Zertifikat kein Problem. | Siehe 11.3. Weicht von 6.6 ab. | Die Prüfung "gültig" gilt erst für das echte System. |
| R4 | Der Weg "401, neu anmelden" wird am echten System mit einer erfundenen Sitzung getestet. | Eine abgemeldete Sitzung signiert dort weiter. | Der Test nutzt eine erfundene Sitzung statt einer abgelaufenen. |
| R5 | Der frühe Lauf des Prüfwerkzeugs von Hand entfällt. | Von der Entwicklungsumgebung aus ist das Testsystem gesperrt. | Die Frage klärte der Lauf in Task 8. |
| R7 | Bei abgelehnten Zugangsdaten schickt "Verbindung prüfen" ohne Antippen des Chefs gar keine Anfrage. | Schutz des Kontos. Strenger als 6.3. | Keiner. |
| R8 | Die Probe-Unterschrift in "Verbindung prüfen" signiert den ASCII-Text `Kassa Verbindung pruefen`. | Die Einheit signiert nur ASCII (der Plan hatte einen Umlaut). | Keiner. |
| R9 | Der Satz zu abgelehnten Zugangsdaten erscheint in der Kassa nur, solange eine Online-Probe läuft. | Das Kennzeichen kann eine beendete Probe überdauern. | Keiner. |
| R10 | Im Hinweis der Kassa steht der Grund in einer eigenen Zeile. | Die Zeichnungen hatten einen einzigen Absatz. | Keiner. |
| R11 | "Geht noch nicht." verschwindet, wenn sich der Ausfall oder sein Grund ändert, nicht bei jedem Verkauf. | Ein altes Ergebnis soll nicht stehen bleiben. | Keiner. |
| R12 | Der Test gegen das echte System hat einen Probelauf gegen den Nachbau, der überall läuft. | Der Weg ist so auch ohne Internet geprüft. | Keiner. |

Weitere Entscheidungen beim Bau:

- Die Migration von Datenbankversion 3 auf 4 legt die Tabelle der Ketten mit festem SQL an, weil die erzeugte Tabelle schon die neue Spalte enthält. Geprüft sind alle Wege 1 nach 5, 2 nach 5, 3 nach 5 und 4 nach 5. Sie ergeben dasselbe Schema wie eine neue Datenbank. Nach einer Migration steht die Spalte `unit` zuletzt.
- Die Karte "Signatur" zeigt den Grund eines Ausfalls auch bei der einfachen Probe. Der Satz für einen `StateError` gilt für jede Aktion der Karte. Die Frage "Speisekarte neu einspielen" scrollt ins Bild, weil die neue Zeile sie sonst unter den Rand schob.

### 11.5 Ergebnis der Läufe

**Lauf gegen das Testsystem** (GitHub `atrust-testsystem`, Nummer 6, Commit 2a19820, 19.11.2026), bestanden:

- "Verbindung prüfen" gibt vier Haken.
- 20 Signaturen mit genau einer Anmeldung, jede am Zertifikat geprüft.
- Eine erfundene Sitzung gibt "abgelaufen".
- Der gesperrte Test-Benutzer wird abgewiesen, danach geht keine Anfrage mehr hinaus.
- Eine Kette aus Startbeleg, Verkauf, Storno, Monatsbeleg, Verkauf über 1.234,56 Euro, Nullbeleg und Schlussbeleg wurde von A-Trust signiert und ist in sich stimmig.

**Prüfwerkzeug des Finanzministeriums** (`tool/rksv/pruefen_datei.sh`) über genau diese Kette (7 Belege vom 18.11.2019 bis 02.12.2019, Ausstellerkennzeichen AT1, Zertifikat 2159b9f6): alle 30 Ergebnisdateien PASS. Das Werkzeug nimmt das Test-Zertifikat an, solange die Belege innerhalb von dessen Gültigkeit liegen.

### 11.6 Bekannte kleine Punkte

Nicht in S2a behoben, außer die Schlussprüfung entscheidet anders.

- Solange das Tablet offline ist, löst jeder Bon zwei Anmeldeversuche aus (den des Bons und einen im Hintergrund). Das ist begrenzt, keine Schleife.
- Scheitert das Schreiben des Kennzeichens "abgelehnt" in den geschützten Speicher, gilt es nur im Arbeitsspeicher. Nach einem Neustart ginge eine Anmeldung mehr hinaus.
- Der Zweig der Prüfung "Schlüssel nicht P-256" ist nicht erreichbar, weil der Client ein solches Zertifikat schon als nicht lesbar meldet.
- Der Hinweis unter einer gescheiterten Probe-Unterschrift wird durch den Vergleich von Sätzen gefunden.
- Der Bildschirm "Verbindung prüfen" wiederholt den Rahmen von "Karte prüfen", statt ihn zu teilen.
- Die Einheit einer Kette ließe sich in der Datenbank ändern, solange die Kette läuft. Kein Code tut es, kein Trigger verbietet es.
- Im ersten Ausfall kann ein Verkauf ein Mal bis zu 5 Sekunden auf die Signatur warten (dazu die übliche Zeit, in der Prüfliste "bis zu 6 Sekunden"). Danach wartet er etwa 1 Sekunde.
