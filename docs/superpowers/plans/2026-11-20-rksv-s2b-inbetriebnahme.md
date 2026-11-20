# RKSV S2b: Echter Betrieb mit A-Trust (Bauplan)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Der Chef gibt am Tablet die Zugangsdaten von A-Trust ein, prüft die Verbindung zum echten System, sieht und druckt die Angaben für FinanzOnline und nimmt die Kassa in Betrieb. Ab dann sind die Bons echt. Er kann die Kassa auch wieder außer Betrieb nehmen.

**Architecture:** Die Online-Einheit aus S2a bleibt. Neu ist ein zweiter Sitzungshalter für das echte System, der seine Zugangsdaten bei jeder Anmeldung aus dem geschützten Speicher liest. `RksvService` bekommt `prepareSetup`, `goLive` und `decommission`. Im Zustand `live` wird jeder Fehler der Signatureinheit ein Ausfall, nie ein gescheiterter Verkauf. Die Oberfläche bekommt den Weg "Signatur einrichten" mit drei Bildschirmen und die Karte "Signatur" den Zustand "In Betrieb".

**Tech Stack:** Flutter 3.50, Dart, drift, flutter_riverpod 3, `http`, `pointycastle`, `flutter_secure_storage`. Keine neuen Pakete.

**Spec:** `docs/superpowers/specs/2026-11-19-rksv-online-signatur-design.md` (6.1, 6.3, 6.4, 6.6, 6.7, 6.8, 11.7). Kern: `docs/superpowers/specs/2026-11-18-rksv-signatur-design.md` (6.1, 6.4, 6.5, 11.2).

**Stand beim Start:** Zweig `claude/project-thread-xtooco` bei 260faa7 (App 1.6.0 Build 8, Tablet-Datenbank Version 6, Teil C Stufe 2 ist enthalten). Die Online-Probe ist am Tablet bestätigt (20.11.2026).

## Entscheidungen in diesem Plan (Claude)

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

## Global Constraints

- **Die Kassa verkauft immer.** Kein Fehler von Netz, A-Trust, geschütztem Speicher oder Signatureinheit darf einen Verkauf oder ein Storno verhindern oder länger als die Frist verzögern (5 Sekunden, während eines Ausfalls 1 Sekunde). Im Zustand `live` scheitert ein Verkauf nur, wenn die Datenbank nicht schreibt.
- **Schutz des Kontos.** Nach 401 oder 403 auf eine Anmeldung schickt die Kassa an dieses System keine einzige Anfrage mehr, bis der Chef ausdrücklich tippt oder neue Zugangsdaten speichert. Jedes Tippen ist genau eine Anmeldung. Das gilt nach einem Neustart weiter, für jeden Bon, für "Nochmal prüfen" und für die Anmeldung im Voraus.
- **Geheimnisse.** Benutzername, Passwort und Sitzungsschlüssel stehen nie in der Datenbank, in einem Log, in `toString`, in einer Fehlermeldung, im Bericht von "Verbindung prüfen", im ausgegebenen Protokoll oder in einer Nachricht an den Server. Der Sitzungsschlüssel liegt nur im Arbeitsspeicher. Der AES-Schlüssel steht außer im geschützten Speicher nur am Bildschirm "Angaben für FinanzOnline" und auf dem Zettel "Angaben drucken".
- **Echt heißt echt.** Eine Kette mit `mode = live` entsteht nur durch `goLive` mit Angaben (`ConnectionFacts`) vom echten System. Das Testsystem ergibt immer Testbons. Eine `live`-Kette wird nie gelöscht und nie umgeschrieben.
- **Kein Schritt ohne Nachfrage.** "Jetzt in Betrieb nehmen" und "Kassa außer Betrieb nehmen" fragen genau einmal deutlich nach.
- **Tastatur** gibt es nur im Bildschirm "Zugangsdaten von A-Trust". Alles andere bleibt Touch.
- **Unberührt:** `server/`, `web/`, `.github/workflows/`, `app/lib/sync/` (außer Tests), `app/lib/rksv/card/`, die Datenbank-Version, `server/migrations/`.
- **Texte** am Bildschirm und am Bon sind deutsch, in der Du-Form, genau wie in diesem Plan. Kein Gedankenstrich. Bezeichner englisch.
- **Version:** setzt der Controller am Ende auf 1.7.0 Build 9. Kein Task ändert sie oder erzeugt Versions-Vergleichsbilder neu.
- **Tests:** gezielt lokal, die ganze Suite läuft auf GitHub (`app`). Vergleichsbilder nur neu oder dort ändern, wo der Task es nennt.

## Review Focus

1. **Abbruch mitten in der Inbetriebnahme** (App beendet, Netz weg, A-Trust antwortet nicht auf den Startbeleg): Danach ist entweder alles wie vorher, samt laufender Probe, oder die Kassa ist in Betrieb mit signiertem Startbeleg. Test in Task 3.
2. **Neue Zugangsdaten, während eine Sitzung der alten läuft:** Der nächste Bon meldet mit den neuen an, die alte Sitzung wird nicht mehr benutzt. Test in Task 1.
3. **Der Chef schreibt die Angaben ab und startet erst Tage später:** Kassen-Kennung und AES-Schlüssel sind dieselben, und die Kette verwendet sie. Test in Task 3.
4. **Der geschützte Speicher liest die Zugangsdaten nicht** (oder sie fehlen), während die Kassa in Betrieb ist: Der Verkauf läuft, der Bon trägt den Vermerk, keine Anfrage geht hinaus. Test in Task 2.
5. **Abgelehnt im echten Betrieb:** Verkäufe laufen mit Vermerk, bis der Chef neue Zugangsdaten speichert; danach genau eine Anmeldung beim nächsten Tippen oder Bon. Test in Task 1 und Task 7.

---

### Task 0: Bilder der neuen Bildschirme (Controller)

Der Controller zeichnet vor Task 5 die Bildschirme nach `docs/design-regeln.md` und dem Bestand (dunkel und hell wie "Verbindung prüfen") und legt sie unter `/mnt/project-files/kassa-entwurf/rksv/s2b-*.png` ab: Zugangsdaten (leer, gespeichert), Verbindung prüfen am echten System mit "Weiter", Angaben für FinanzOnline, "Bevor du startest" mit der Nachfrage, Karte "Signatur" in Betrieb, in Betrieb mit abgelehnten Zugangsdaten, außer Betrieb. Niko bekommt sie gezeigt; der Bau wartet nicht auf eine Antwort. Die Texte dieses Plans gewinnen, wo ein Bild abweicht.

### Task 1: Zugangsdaten, Halter je System, Regel Q9

**Files:**
- Modify: `app/lib/rksv/rksv_secrets.dart`, `app/lib/rksv/online/atrust_client.dart`, `app/lib/rksv/online/atrust_session_keeper.dart`, `app/lib/rksv/online/online_signature_unit.dart`, `app/lib/rksv/online/online_providers.dart`, `app/lib/rksv/rksv_providers.dart`, alle Aufrufer von `atrustTestKeeperProvider`
- Test: `app/test/rksv/online/atrust_session_keeper_test.dart`, `app/test/rksv/online/online_signature_unit_test.dart`, `app/test/rksv/rksv_secrets_test.dart`, `app/test/support/fake_atrust.dart`, `app/test/rksv/online/atrust_testsystem_test.dart` (nur die neue Form des Konstruktors; dieser Test läuft allein auf GitHub gegen das Testsystem)

**Interfaces (Produces):**
- `final class AtrustCredentials { const AtrustCredentials(this.user, this.password); final String user, password; }` in `rksv_secrets.dart`, `toString()` gibt nur `'AtrustCredentials'`.
- `final class PendingSetup { const PendingSetup({required this.cashBoxId, required this.aesKey}); final String cashBoxId; final Uint8List aesKey; }`, `toString()` ohne Inhalt.
- `RksvSecrets` neu: `Future<AtrustCredentials?> atrustCredentials()`, `Future<void> writeAtrustCredentials(AtrustCredentials? c)` (null löscht), `Future<PendingSetup?> pendingSetup()`, `Future<void> writePendingSetup(PendingSetup? s)` (null löscht). Geändert: `Future<bool> atrustRejected({bool live = false})`, `Future<void> writeAtrustRejected(bool rejected, {bool live = false})`. Schlüssel: `rksv_atrust_user`, `rksv_atrust_password`, `rksv_setup_cash_box_id`, `rksv_setup_aes`, `rksv_atrust_rejected_live`; `rksv_atrust_rejected` bleibt für das Testsystem. `MemoryRksvSecrets` zieht mit (samt `failReads`, `hangReads`, `hangWrites`).
- `AtrustProblem.noCredentials` mit dem Satz `Die Zugangsdaten von A-Trust fehlen.` und `AtrustProblem.refused` mit dem Satz `A-Trust hat die Signatur abgelehnt.`.
- `AtrustSessionKeeper({required AtrustClient client, required Future<AtrustCredentials?> Function() credentials, required RksvSecrets secrets, required Clock clock, bool live = false})`. `live` wählt das Kennzeichen. Neu: `void forget()` verwirft die gehaltene Sitzung ohne Anfrage (für neue Zugangsdaten). Fehlen die Zugangsdaten: `session()` wirft `AtrustException(AtrustProblem.noCredentials)`, ohne Anfrage und ohne "abgelehnt" zu setzen.
- F5 aus Entwurf 11.7, Punkt 7: Gilt "abgelehnt", sobald eine Anmeldung antwortet, endet sie mit `AtrustProblem.rejected` und ihre Sitzung wird weder gehalten noch ausgegeben.
- `final atrustKeeperProvider = Provider.family<AtrustSessionKeeper, AtrustSystem>(...)`: `test` mit dem öffentlichen Test-Benutzer (wie bisher, `restore()` beim Erzeugen), `live` mit `secrets.atrustCredentials` und `live: true`. `atrustTestKeeperProvider` entfällt. `connectionCheckProvider` bleibt in diesem Task, wie er ist, und nimmt `atrustKeeperProvider(AtrustSystem.test)`; Task 4 macht ihn zur Familie.
- `onlineSignatureUnitOf`: bei `RksvUnit.atrust` eine `OnlineSignatureUnit` mit `AtrustClient(..., AtrustSystem.live)` und `atrustKeeperProvider(AtrustSystem.live)`. Dies und die Provider in `online_providers.dart` sind die einzigen Stellen, die `AtrustSystem.live` bauen.
- Q13: `static const abandonedLimit = Duration(seconds: 120)`. Hat eine aufgegebene Anmeldung noch nicht geantwortet und ist sie jünger als `abandonedLimit`, wirft `session()` sofort `AtrustException(AtrustProblem.noInternet)` ohne Anfrage; `warmUp()` tut nichts. Antwortet sie (gleich wie) oder ist die Zeit um, darf die nächste Anmeldung hinaus. `allowOneLogin()` hebt die Sperre nicht auf.
- Q14: Scheitert `writeAtrustRejected(true, ...)`, bleibt "abgelehnt" im Arbeitsspeicher gesetzt und der Halter versucht das Schreiben bei jedem `session()`, `warmUp()` und `restore()` erneut, bis es gelingt. Kein Fehler davon erreicht den Aufrufer.
- `OnlineSignatureUnit` (Q9): Scheitert das Signieren mit einer Sitzung, die in diesem Aufruf frisch geholt wurde, wieder mit `sessionExpired`, merkt sich die Einheit diese Sitzung. Solange der Halter dieselbe Sitzung ausgibt, führt `sessionExpired` zu `SignatureFailure('A-Trust hat die Signatur abgelehnt.')` ohne neue Anmeldung.

**Tests (Namen sinngemäß, echte Zusicherungen auf die Liste der Anfragen von `FakeAtrust`):**
- Geheimnisse: Zugangsdaten schreiben, lesen, löschen; `PendingSetup` ebenso; "abgelehnt" für Test und echt sind getrennt; `toString` von `AtrustCredentials` und `PendingSetup` enthält weder Benutzer, Passwort noch Schlüssel.
- Halter echt: ohne Zugangsdaten keine Anfrage und `noCredentials`; mit Zugangsdaten genau ein PUT mit diesen; 401 setzt nur das Kennzeichen `live`, das Kennzeichen des Testsystems bleibt false, und umgekehrt.
- Review Focus 2: Sitzung mit Zugangsdaten A gehalten, Zugangsdaten B gespeichert und `forget()`, nächstes `session()` schickt ein PUT mit B; die alte Sitzung wird nicht mehr ausgegeben.
- Review Focus 5 (Teil 1): nach 401 keine Anfrage bei `session()` und `warmUp()`; nach `writeAtrustRejected(false, live: true)` und `allowOneLogin()` genau ein PUT.
- F5: aufgegebene Anmeldung antwortet spät mit 401, während eine neue läuft; die neue antwortet 200: `session()` der Wartenden endet mit `rejected`, der Halter hält keine Sitzung, danach keine Anfrage.
- Q13: Anmeldung hängt (keine Antwort): nach 20 Sekunden `noInternet`; weitere `session()` in den nächsten 120 Sekunden schicken nichts und enden sofort mit `noInternet`; nach 120 Sekunden geht genau eine neue Anmeldung hinaus; antwortet die hängende vorher mit 200 und der Halter hat keine Sitzung, wird sie gehalten und der nächste Bon signiert ohne neue Anmeldung.
- Q14: `MemoryRksvSecrets.hangWrites` oder ein scheiternder Schreibzugriff beim Setzen von "abgelehnt": `rejected` ist sofort wahr, keine weitere Anfrage; sobald der Speicher wieder schreibt, steht das Kennzeichen nach dem nächsten `session()` im Speicher (ein neuer Halter mit demselben Speicher schickt dann nichts).
- Q9: Signieren antwortet immer 403: erster Bon schickt Signieren, eine Anmeldung, Signieren und scheitert mit `A-Trust hat die Signatur abgelehnt.`; der zweite Bon schickt genau ein Signieren und keine Anmeldung; gibt der Halter eine neue Sitzung aus (Uhr 56 Minuten weiter), darf wieder ein Mal neu angemeldet werden.
- Bestand: Alle bisherigen Tests des Halters und der Einheit laufen mit der neuen Form des Konstruktors.

- [ ] Tests schreiben und scheitern sehen
- [ ] Umsetzen
- [ ] `flutter analyze`, `flutter test test/rksv test/features/connection_check_test.dart test/features/outage_banner_test.dart test/features/sale_outage_test.dart test/features/signature_panel_test.dart` grün
- [ ] Commit: `RKSV S2b Task 1: Zugangsdaten im geschützten Speicher, Halter je System`

### Task 2: Journal und Bon im echten Betrieb

**Files:**
- Modify: `app/lib/rksv/rksv_journal.dart`, `app/lib/data/receipt_repository.dart` (nur wo K9 und `rethrow` stehen), `app/lib/features/bons/void_question.dart` (Satz zum Storno), `app/lib/features/bons/receipt_detail.dart` (nur falls der Satz dort gewählt wird), `app/test/support/rksv_rig.dart`
- Test: `app/test/rksv/rksv_live_test.dart` (neu), `app/test/sync/` (ein Test zu `test`), `app/test/domain/receipt_layout_test.dart` oder der vorhandene Test des Bon-Layouts

**Interfaces:**
- Consumes: Task 1 (`AtrustProblem.noCredentials`, Halter echt, `onlineSignatureUnitOf` für `atrust`).
- Produces: `RksvRig.open(...)` bekommt einen Weg, eine laufende `live`-Kette am nachgebauten A-Trust anzulegen (`RksvRig.seedLive({FakeAtrust? atrust})` oder ein Parameter; der Implementierer wählt die Form nach dem Bestand und nennt sie im Bericht). Bis Task 3 `goLive` liefert, legt der Rig die Kette direkt an.
- Verhalten (Q6): In `_sign` wird im Zustand `live` jeder Fehler aus `unitOf(chain)` und aus `unit.sign` zu einem Ausfall. Der Grund ist der Satz der Einheit, sonst `Die Signatur ist ausgefallen.`. `endProbeAfterError` bleibt für `probe`. Ein Fehler der Datenbank wirft weiter.
- Die Aufgabe "Ausfall melden" bekommt bei Ketten mit Einheit `atrust` oder `atrustTest` den Grund ins Detail: `<Beginn>. Grund: 3, Ausfall der Verbindung zur Signaturerstellungseinheit` (der Satz der Aufgabe bleibt, er endet dann auf diesen Text und einen Punkt).
- Storno: Gehört ein Bon nicht zur laufenden Kette und ist die Kassa in Betrieb, sagt die Bon-Ansicht `Dieser Bon stammt aus der Testzeit und kann nicht storniert werden.`. In der Probe bleibt der bisherige Satz.

**Tests:**
- Review Focus 4: Kette `live`, `MemoryRksvSecrets.failReads = true` für die Zugangsdaten (oder keine Zugangsdaten): Verkauf wird gespeichert, Eintrag mit Ausfall, Grund `Die Zugangsdaten von A-Trust fehlen.` oder der Satz zum Speicher, `FakeAtrust.requests` leer, Dauer unter der Frist.
- `unitOf` wirft im Zustand `live` einen `StateError`: Verkauf gespeichert, Ausfall mit `Die Signatur ist ausgefallen.`, die Kette läuft weiter (kein K9), `mode` bleibt `live`.
- Derselbe Fehler im Zustand `probe`: K9 wie bisher (Bestandstest bleibt grün).
- Datenbank-Fehler beim Schreiben des Eintrags im Zustand `live`: der Verkauf scheitert und nichts bleibt zurück (Bestandstest R1 aus S1b bleibt grün).
- Ausfall über 48 Stunden an einer `atrust`-Kette: Aufgabe mit dem Grund 3 im Text.
- Bon einer `live`-Kette: Der Druck enthält weder `TESTBON` noch `Keine gültige Rechnung`; mit Ausfall enthält er `Sicherheitseinrichtung ausgefallen`. Die Bon-Ansicht zeigt nicht `Testbon mit Probe-Signatur.`.
- Q10: `push_wire` liefert für einen Bon einer `live`-Kette `test: false`, auch mit Ausfall-Eintrag; ein Bon von vor der Inbetriebnahme (Probe-Kette oder ohne Kette) liefert vor und nach der Inbetriebnahme `test: true` und byte-gleiche Nachrichten.
- Storno eines Bons aus der Probe-Zeit im Zustand `live`: Satz `Dieser Bon stammt aus der Testzeit und kann nicht storniert werden.`; Storno eines Bons der laufenden `live`-Kette geht und wird signiert.
- `chainIsSound` ist für eine `live`-Kette mit Verkauf, Storno, Ausfall und Sammelbeleg wahr.

- [ ] Tests schreiben und scheitern sehen
- [ ] Umsetzen
- [ ] `flutter analyze`, `flutter test test/rksv test/data test/sync test/domain test/features/bons_rksv_test.dart test/features/bons_test.dart` grün
- [ ] Commit: `RKSV S2b Task 2: Im echten Betrieb ist jeder Fehler der Signatur ein Ausfall`

### Task 3: Einrichtung, Inbetriebnahme, Außerbetriebnahme im Service

**Files:**
- Modify: `app/lib/rksv/rksv_service.dart`, `app/lib/rksv/rksv_state.dart`, `app/lib/data/rksv_repository.dart` (Stand "außer Betrieb"), `app/test/support/rksv_rig.dart`
- Create: `app/lib/rksv/setup_facts.dart`
- Test: `app/test/rksv/go_live_test.dart` (neu), `app/test/rksv/setup_facts_test.dart` (neu)

**Interfaces:**
- Consumes: `ConnectionFacts` (`system`, `zdaId`, `certificate`), `PendingSetup`, `RksvSecrets`.
- Produces:
  - `final class SetupFacts { kind, provider, certSerialHex, certSerialDecimal, cashBoxId, aesKeyBase64, aesChecksum }` (alles `String`) in `setup_facts.dart`. `kind` ist `Hardware-Sicherheitsmodul (HSM) eines Dienstleisters`, `provider` ist `<zdaId> = A-TRUST` (am echten System `AT1 = A-TRUST`).
  - `String aesKeyChecksum(String aesKeyBase64)`: der Prüfwert des Finanzministeriums. Der Rechenweg steht im Mustercode `AESCheckSum.java` unter `/mnt/project-files/kassa-plan/rksv-quelle/mustercode/regkassen-democashbox/src/main/java/at/asitplus/regkassen/demo/` (nur lesen, nichts ins Repo kopieren, in Dart neu schreiben). Der Test braucht mindestens einen Vergleichswert, der nicht aus dem eigenen Code stammt: aus dem Mustercode selbst (Kommentar oder Beispiel) oder mit `java` und `lib/registrierkassen-core-0.12.jar` des Prüfwerkzeugs erzeugt; woher er kommt, steht im Bericht. Findet sich keiner, meldet der Implementierer DONE_WITH_CONCERNS.
  - `Future<SetupFacts> RksvService.prepareSetup({required ConnectionFacts facts})`: `facts.system` muss `live` sein und `mode` darf nicht `live` sein, sonst `StateError`. Legt `PendingSetup` an, wenn keines da ist (Kassen-Kennung und AES-Schlüssel wie bei `_startOnlineChain`), sonst nimmt es das vorhandene. Schreibt nichts in die Datenbank.
  - `Future<Receipt> RksvService.goLive({required Staff staff, required ConnectionFacts facts})` (Q7): eine Transaktion. `facts.system != live` oder kein `PendingSetup` oder `mode == live`: `StateError`. Läuft eine Probe: Schlussbeleg, Kette beenden, Aufgaben der Probe weg (wie `disableProbe`). Dann neue Kette `mode: live`, `unit: atrust`, Kennung und AES-Schlüssel aus `PendingSetup`, Zertifikat und Aussteller aus `facts`; Stand `live`; Startbeleg mit `mustSign: true`; der AES-Schlüssel geht mit `RksvJournal.rememberLiveKey(chain, key)` in den Arbeitsspeicher (Q17). Aufgaben: `registerFinanzOnline` (Detail: Datum heute plus 7 Tage, `dd.MM.yyyy`) und `checkStart`. Nach der Transaktion `writePendingSetup(null)`; scheitert das, bleibt es ohne Folgen. Fehler wie bei `enableOnlineProbe`: `RksvProblem` mit dem Satz der Einheit oder dem allgemeinen Satz, und nichts bleibt zurück.
  - `Future<Receipt> RksvService.decommission({required Staff staff})` (Q8): `mode != live`: `StateError`. Schlussbeleg (ohne `mustSign`; im Ausfall trägt er den Vermerk), Kette beenden, `mode: off`, Ausfall gelöscht, die offenen Aufgaben bleiben, dazu `reportDecommission` (Detail: Datum heute plus 7 Tage) und, falls nicht schon offen, `backupProtocol`.
  - `RksvTaskKind.registerFinanzOnline` mit `Signatureinheit und Kassa bei FinanzOnline anmelden, bis <Detail>.` und `RksvTaskKind.reportDecommission` mit `Außerbetriebnahme bei FinanzOnline melden, bis <Detail>. Grund: 6, planmäßige Außerbetriebnahme.`.
  - `RksvState.decommissioned` (bool): `mode` ist `off` und die Kette mit der höchsten Nummer ist eine beendete `live`-Kette. `RksvRepository.watch()` liefert es.
  - `zeroReceipt`, `retrySignature`, `exportProtocol` gelten auch im Zustand `live` (`probe: false` im Protokoll einer `live`-Kette).
  - `exportProtocol` wählt die Kette nach Q15: laufende `live`-Kette, sonst jüngste beendete `live`-Kette, sonst wie bisher.
  - `RksvRig`: `goLive` über den echten Weg (nachgebauter A-Trust mit `AtrustSystem.live`), ersetzt die direkte Anlage aus Task 2.

**Tests:**
- `prepareSetup`: zweimal aufgerufen ergibt dieselbe Kennung und denselben Schlüssel; nach einem neuen `RksvService` und neuem Start (gleicher Speicher) wieder dieselben; Angaben vom Testsystem: `StateError`; der Prüfwert stimmt mit dem Vergleichswert überein; `certSerialDecimal` ist die Dezimalzahl zu `certSerialHex` (auch bei mehr als 64 Bit).
- Review Focus 3: `prepareSetup`, Uhr drei Tage weiter, `goLive`: Kette trägt Kennung aus `SetupFacts`, der AES-Schlüssel der Kette ist der gezeigte; `pendingSetup()` ist danach null.
- `goLive` aus `off`: Startbeleg signiert vom nachgebauten A-Trust, Stand `live`, Einheit `atrust`, zwei Aufgaben mit dem richtigen Datum, Zähler 0.
- `goLive` aus laufender Probe und aus laufender Online-Probe: Schlussbeleg der alten Kette, alte Kette beendet, Aufgaben der Probe weg, neue Kette `live`.
- Review Focus 1: A-Trust antwortet beim Startbeleg nicht (oder 500, oder falsche Signatur): `RksvProblem`, der Stand ist genau wie vorher, die Probe läuft weiter und hat keinen Schlussbeleg, es gibt keine neue Kette, kein neuer Bon; `PendingSetup` ist noch da.
- `goLive` ohne `PendingSetup`, mit Angaben vom Testsystem, im Zustand `live`: jeweils `StateError` und keine Anfrage.
- `decommission`: Schlussbeleg, Kette beendet, `mode off`, `decommissioned` wahr, Aufgabe mit Datum; offene Aufgaben von vorher bleiben; während eines Ausfalls trägt der Schlussbeleg den Vermerk. Danach ein Verkauf: Bon ohne Eintrag, `test: true`.
- Nach `decommission` wieder `prepareSetup` und `goLive`: neue Kette mit neuer Kennung, `decommissioned` falsch.
- `exportProtocol` einer `live`-Kette; das Prüfwerkzeug-Format ist unverändert (Bestandstest).
- Q15: nach `decommission` gibt `exportProtocol` die beendete `live`-Kette aus (mit Schlussbeleg); danach `enableProbe` und ein Verkauf: `exportProtocol` gibt weiter die `live`-Kette aus, nicht die Probe; ohne jede `live`-Kette bleibt es beim Bestand. `decommission` legt `backupProtocol` genau einmal an.

- [ ] Tests schreiben und scheitern sehen
- [ ] Umsetzen
- [ ] `flutter analyze`, `flutter test test/rksv test/data` grün
- [ ] Commit: `RKSV S2b Task 3: Einrichtung, Inbetriebnahme und Außerbetriebnahme`

### Task 4: "Verbindung prüfen" am echten System

**Files:**
- Modify: `app/lib/rksv/online/connection_check.dart`, `app/lib/rksv/online/online_providers.dart`, alle Aufrufer von `connectionCheckProvider`
- Test: `app/test/rksv/online/connection_check_test.dart`

**Interfaces:**
- Consumes: Task 1 (Halter echt, `noCredentials`, Familie der Provider).
- Produces: `ConnectionCheck({required AtrustClient client, required AtrustSessionKeeper keeper, required Future<String?> Function() user, required Clock clock})`: Der Benutzer wird je Lauf gelesen (Test-Benutzer fest, echt aus dem geschützten Speicher). `final connectionCheckProvider = Provider.family<ConnectionCheck, AtrustSystem>(...)`; `connectionCheckProvider(AtrustSystem.live)` baut die Prüfung für das echte System. `ConnectionFacts.system` ist dann `live`.
- Am echten System: Fehlt der Benutzer, bekommt Zeile "A-Trust" ein Kreuz mit `Die Zugangsdaten von A-Trust fehlen.`, ohne Anfrage. Ein abgelaufenes oder noch nicht gültiges Zertifikat ist ein Kreuz in Zeile "Zertifikat" mit `Das Zertifikat von A-Trust ist nicht gültig.` (am Testsystem bleibt es die Unterzeile, R3 aus S2a). Der Bericht nennt am echten System keinen Benutzernamen (Q12): wo der Bericht am Testsystem den Benutzer nennt, steht `echtes Konto`.
- An beiden Systemen (Entwurf 11.7, Punkt 5): Gilt "abgelehnt" und hat der Chef nicht getippt, steht in Zeile "A-Trust" sofort das Kreuz mit dem Satz zu den abgelehnten Zugangsdaten, ohne Wartesatz und ohne Anfrage. Scheitert schon das Laden oder Aufheben von "abgelehnt" (geschützter Speicher), endet der Lauf mit einem Kreuz in der ersten Zeile, und "Bericht teilen" gibt es trotzdem.

**Tests:** "abgelehnt" ohne Tippen zeigt sofort das Kreuz mit dem Satz und nie den Wartesatz; `failReads` beim Laden von "abgelehnt": Kreuz in der ersten Zeile und ein Bericht ist da; vier Haken am nachgebauten echten System mit gespeicherten Zugangsdaten, `facts.system == live`; ohne Zugangsdaten keine Anfrage und der Satz; abgelaufenes Zertifikat am echten System ist ein Kreuz und es gibt keine `ConnectionFacts`; "abgelehnt" (echt) ohne Tippen: keine Anfrage; mit Tippen genau eine Anmeldung; der Bericht enthält weder Benutzer noch Passwort noch Sitzung (Zeichenketten gezielt gesetzt und gesucht); die Tests am Testsystem bleiben grün.

- [ ] Tests schreiben und scheitern sehen
- [ ] Umsetzen
- [ ] `flutter analyze`, `flutter test test/rksv/online test/features/connection_check_test.dart` grün
- [ ] Commit: `RKSV S2b Task 4: Verbindung prüfen am echten System`

### Task 5: Bildschirm "Zugangsdaten von A-Trust"

**Files:**
- Create: `app/lib/features/settings/credentials_screen.dart`
- Modify: `app/test/no_text_field_test.dart` (genau diese Datei zulassen), `app/lib/features/settings/connection_check_screen.dart` (Parameter für das System, Taste unten)
- Test: `app/test/features/credentials_screen_test.dart`, `app/test/golden/credentials_golden_test.dart` (Bilder `zugangsdaten_leer_hell`, `zugangsdaten_leer_dunkel`, `zugangsdaten_gespeichert_hell`)

**Interfaces:**
- Consumes: `RksvSecrets.atrustCredentials`, `writeAtrustCredentials`, `writeAtrustRejected(false, live: true)`, `atrustKeeperProvider(AtrustSystem.live).forget()`, Bild `s2b-*` aus Task 0.
- Produces: `class CredentialsScreen extends ConsumerStatefulWidget { const CredentialsScreen({this.edit = false}); final bool edit; }` (nur Chef; `edit: true` zeigt gleich die Felder, auch wenn Zugangsdaten gespeichert sind). `ConnectionCheckScreen({AtrustSystem system = AtrustSystem.test, void Function(ConnectionFacts facts)? onContinue})`: am Testsystem unverändert; am echten System steht nach vier Haken unten `Weiter`, wenn `onContinue` gesetzt ist, sonst keine Taste unten. `CredentialsScreen` übergibt `onContinue` nur, wenn die Kassa nicht in Betrieb ist (Task 6 hängt dort den nächsten Bildschirm an; bis dahin schließt der Rückruf die Prüfung). Am echten System steht rechts statt `Das ist das Testsystem von A-Trust. Bons bleiben Testbons.` der Text `Das ist das echte System von A-Trust. Jede Prüfung zählt bei A-Trust als eine Signatur.` (Q16).
- Texte:
  - Titel `Zugangsdaten von A-Trust`. Darunter: `Benutzername und Passwort hast du von A-Trust bekommen, als das Konto für diesen Betrieb angelegt wurde. Die Kassa speichert sie geschützt auf diesem Tablet.`
  - Felder `Benutzername` und `Passwort`. Das Passwort ist verdeckt, daneben `Anzeigen` und `Verbergen`.
  - Haupttaste `Speichern und prüfen`. Leeres Feld: `Bitte beides ausfüllen.`
  - Sind Zugangsdaten gespeichert: statt der Felder `Zugangsdaten sind gespeichert.` mit dem Benutzernamen darunter, Tasten `Weiter`, `Neu eingeben` und `Löschen`. Nachfrage `Zugangsdaten löschen?` mit `Löschen` und `Abbrechen`. Im Zustand "In Betrieb" gibt es `Löschen` und `Weiter` nicht.
  - Scheitert das Speichern: `Die Zugangsdaten konnten nicht gespeichert werden. Bitte noch einmal.`
- Verhalten: Der Benutzername wird ohne Leerzeichen am Rand gespeichert, das Passwort genau wie getippt. Tastatur ohne Vorschläge, ohne Autokorrektur, ohne Großschreiben, ohne Ausfüllhilfe von Android. `Speichern und prüfen` schreibt die Zugangsdaten, hebt "abgelehnt" (echt) auf, ruft `forget()` und öffnet "Verbindung prüfen" am echten System mit `chefTapped: true`. `Löschen` entfernt Zugangsdaten und `PendingSetup`. Die Felder werden beim Verlassen geleert. Die Regeln aus `docs/design-regeln.md` gelten (Tastenhöhen wie in der Karte "Signatur", Fokus sichtbar, das Feld rollt über die Tastatur).

**Tests:** Speichern schreibt genau die getippten Werte (Benutzername gekürzt, Passwort mit Leerzeichen am Ende unverändert) und öffnet die Prüfung; leeres Feld speichert nichts; `Anzeigen` zeigt das Passwort; mit gespeicherten Zugangsdaten steht der Benutzername da und kein Passwort im Baum; `Löschen` nach der Nachfrage entfernt beides; im Zustand `live` fehlen `Löschen` und `Weiter`, und die Prüfung nach dem Speichern hat unten keine Taste; mit `edit: true` stehen die Felder da, obwohl Zugangsdaten gespeichert sind; ein Mitarbeiter ohne Chef-Recht kommt nicht auf den Bildschirm; "abgelehnt" ist nach dem Speichern aufgehoben und der Halter hat keine Sitzung mehr; `no_text_field_test` findet nur diese Datei.

- [ ] Tests schreiben und scheitern sehen
- [ ] Umsetzen, Vergleichsbilder der drei neuen Bilder erzeugen und ansehen
- [ ] `flutter analyze`, `flutter test test/features test/golden/credentials_golden_test.dart test/golden/connection_check_golden_test.dart test/no_text_field_test.dart` grün
- [ ] Commit: `RKSV S2b Task 5: Zugangsdaten von A-Trust eingeben`

### Task 6: Angaben für FinanzOnline und "Jetzt in Betrieb nehmen"

**Files:**
- Create: `app/lib/features/settings/setup_facts_screen.dart`, `app/lib/features/settings/go_live_question.dart`
- Modify: `app/lib/domain/receipt_layout.dart` oder die Stelle, an der der Nullbeleg-Druck gebaut wird (Zettel), `app/lib/features/settings/connection_check_screen.dart` (Rückruf aus Task 5 anschließen)
- Test: `app/test/features/setup_flow_test.dart`, `app/test/golden/setup_golden_test.dart` ergänzen oder `app/test/golden/setup_facts_golden_test.dart` (Bilder `angaben_finanzonline_hell`, `angaben_finanzonline_dunkel`, `in_betrieb_frage_hell`)

**Interfaces:**
- Consumes: `prepareSetup`, `goLive`, `SetupFacts`, Druck wie beim Startbeleg der Probe.
- Produces: `class SetupFactsScreen extends ConsumerStatefulWidget { const SetupFactsScreen({required this.facts}); final ConnectionFacts facts; }`.
- Texte:
  - Titel `Angaben für FinanzOnline`. Darunter: `Diese Angaben trägst du bei FinanzOnline ein, wenn du die Signatureinheit und die Kassa anmeldest.`
  - Zeilen (Name links, Wert rechts, Wert in Ziffern-Schrift mit gleich breiten Zeichen): `Art der Sicherheitseinrichtung`, `Anbieter`, `Seriennummer des Zertifikats` (hex, darunter `dezimal <Zahl>`), `Kassenidentifikationsnummer`, `AES-Schlüssel`, `Prüfwert`.
  - Taste `Angaben drucken`. Ohne Drucker oder bei einem Fehler: der Satz, den der Nullbeleg in diesem Fall zeigt.
  - Abschnitt `Bevor du startest` mit drei Punkten: `An der alten Kassa den Schlussbeleg erstellen und sie bei FinanzOnline abmelden.` / `Signatureinheit und Kassa bei FinanzOnline anmelden, spätestens eine Woche nach dem Start.` / `Den Startbeleg mit der App "BMF Belegcheck" prüfen und den Ausdruck aufheben.`
  - Haupttaste `Jetzt in Betrieb nehmen`. Nachfrage: Titel `Jetzt in Betrieb nehmen?`, Text `Das lässt sich nicht zurücknehmen. Ab jetzt ist jeder Bon ein echter Bon für das Finanzamt.`, läuft eine Probe zusätzlich `Die laufende Probe endet mit einem Schlussbeleg.`, Tasten `In Betrieb nehmen` und `Abbrechen`.
  - Danach zurück in die Einstellungen mit der Meldung `Die Kassa ist in Betrieb.`. Scheitert es: der Satz aus `RksvProblem`, der Bildschirm bleibt offen.
- Zettel "Angaben drucken": Überschrift `Angaben für FinanzOnline`, Name des Betriebs, Datum und Uhrzeit, dann je Angabe Name und Wert in eigenen Zeilen. Der AES-Schlüssel steht in zwei Zeilen zu je 22 Zeichen, die Seriennummer hex und dezimal. Unten: `Diesen Zettel sicher aufheben. Der AES-Schlüssel ist geheim.` Kein QR-Code, kein `TESTBON`.
- Der Startbeleg wird nach `goLive` gedruckt wie der Startbeleg der Probe; scheitert der Druck, bleibt die Kassa in Betrieb, und der Beleg lässt sich unter "Bons" drucken.

**Tests:** Der Bildschirm zeigt die sechs Angaben aus `SetupFacts`; zweimal öffnen zeigt dieselben Werte; `Angaben drucken` schickt den Zettel mit allen Werten an den Drucker (Attrappe) und der Schlüssel steht in zwei Zeilen; `Jetzt in Betrieb nehmen` fragt nach, `Abbrechen` ändert nichts, `In Betrieb nehmen` ruft `goLive` genau einmal (Doppeltipp), druckt den Startbeleg und kehrt zurück; mit laufender Probe steht der Zusatzsatz in der Nachfrage; scheitert `goLive`, steht der Satz da und die Kassa ist nicht in Betrieb; der ganze Weg von "Zugangsdaten" über "Verbindung prüfen" bis "In Betrieb" in einem Widget-Test mit dem nachgebauten A-Trust.

- [ ] Tests schreiben und scheitern sehen
- [ ] Umsetzen, neue Vergleichsbilder erzeugen und ansehen
- [ ] `flutter analyze`, `flutter test test/features test/golden/<neue Datei> test/domain` grün
- [ ] Commit: `RKSV S2b Task 6: Angaben für FinanzOnline und Inbetriebnahme`

### Task 7: Karte "Signatur" und Kassa im echten Betrieb

**Files:**
- Modify: `app/lib/features/settings/signature_panel.dart`, `app/lib/features/settings/probe_question.dart` (Nachfrage "außer Betrieb"), `app/lib/features/settings/rksv_task_row.dart`, `app/lib/features/kassa/outage_banner.dart`, `app/lib/features/kassa/kassa_screen.dart`, `app/lib/features/close/` (wo offene Aufgaben stehen)
- Test: `app/test/features/settings_signature_live_test.dart` (neu), `app/test/features/outage_banner_test.dart` (Hinweis), `app/test/golden/signature_panel_golden_test.dart` (Bilder `signatur_in_betrieb_hell`, `signatur_in_betrieb_dunkel`, `signatur_in_betrieb_ausfall_hell`, `signatur_in_betrieb_abgelehnt_hell`, `signatur_ausser_betrieb_hell`), `app/test/golden/kassa_golden_test.dart` (Bild `kassa_ausfall_abgelehnt_hell`)

**Interfaces:**
- Consumes: `RksvState.decommissioned`, `decommission`, `atrustKeeperProvider(AtrustSystem.live).rejected`, `CredentialsScreen`, die neuen Aufgaben.
- Texte und Verhalten der Karte:
  - In den Zuständen "Nicht eingerichtet", "Probe", "Online-Probe" und "Außer Betrieb" gibt es die Zeile `Signatur einrichten` mit `Für den echten Betrieb. Du brauchst die Zugangsdaten von A-Trust.` und der Taste `Einrichten`; sie öffnet `CredentialsScreen`.
  - In Betrieb: Pille `In Betrieb`, im Ausfall `In Betrieb, Signatur ausgefallen`. Hilfe `Signatur von A-Trust. Kassen-ID <Kennung>.`. Im Ausfall steht der Grund darunter wie in der Online-Probe. Zeilen: `Verbindung prüfen` (echtes System), `Nullbeleg drucken`, `Protokoll ausgeben`, `Zugangsdaten` mit `Benutzername und Passwort von A-Trust ändern.` und Taste `Ändern` (öffnet `CredentialsScreen`), `Kassa außer Betrieb nehmen` mit `Die Kassa erstellt einen Schlussbeleg. Danach sind neue Bons wieder Testbons.` und Taste `Außer Betrieb`. Die Zeilen der Probe (`Zum Ausprobieren einschalten`, `Mit A-Trust ausprobieren`, `Probe beenden`) gibt es in Betrieb nicht.
  - Abgelehnt in Betrieb: Hinweis `A-Trust hat die Zugangsdaten abgelehnt.` mit der Taste `Zugangsdaten neu eingeben` (öffnet `CredentialsScreen(edit: true)`). In der Online-Probe bleibt `Erneut anmelden`.
  - Nachfrage: Titel `Kassa außer Betrieb nehmen?`, Text `Das lässt sich nicht zurücknehmen. Die Kassa erstellt den Schlussbeleg und signiert danach keine Bons mehr. Du musst das bei FinanzOnline melden.`, Tasten `Außer Betrieb nehmen` und `Abbrechen`. Danach wird der Schlussbeleg gedruckt.
  - Außer Betrieb: Pille `Außer Betrieb`, Hilfe `Die Kassa ist außer Betrieb. Neue Bons sind Testbons.`. Die offenen Aufgaben stehen weiter da, und die Zeile `Protokoll ausgeben` bleibt (Q15), dazu die Zeilen von "Nicht eingerichtet".
  - Aufgaben im echten Betrieb sind keine Übung: Der Satz `Aufgaben aus der Probe sind zum Üben.` steht nur in der Probe.
- Kassa: Der Hinweis zum Ausfall zeigt den Satz `A-Trust hat die Zugangsdaten abgelehnt. Bitte den Chef holen.` ohne `Nochmal prüfen` auch bei einer Kette mit Einheit `atrust`, mit dem Kennzeichen des echten Systems. Beim Start und beim Zurückkommen der App ruft die Kassa bei einer laufenden `atrust`-Kette `restore()` und `warmUp()` am Halter des echten Systems (wie heute bei `atrustTest`) und `RksvJournal.primeLiveKey()` (Q17).

**Tests:** je Zustand die richtigen Zeilen und Sätze (in Betrieb, Ausfall, abgelehnt, außer Betrieb, dazu dass die Probe-Zeilen fehlen); `Außer Betrieb` fragt nach, `Abbrechen` ändert nichts, Bestätigen ruft `decommission` genau einmal und druckt; `Zugangsdaten neu eingeben` öffnet den Bildschirm mit Feldern; nur der Chef sieht die Tasten; Review Focus 5 als Widget-Test: abgelehnt, Verkauf läuft mit Vermerk und ohne Anfrage, neue Zugangsdaten, danach beim nächsten Bon genau eine Anmeldung und ein Sammelbeleg; Kassa-Hinweis bei `atrust` und "abgelehnt"; Anmelden im Voraus beim Start nur mit einer `atrust`-Kette am echten Halter; die neuen Aufgaben erscheinen in der Karte und im Abschluss und gehen mit `Erledigt` weg.

- [ ] Tests schreiben und scheitern sehen
- [ ] Umsetzen, neue Vergleichsbilder erzeugen und ansehen; geänderte Bestandsbilder (Zeile `Signatur einrichten` in den Einstellungen) im Bericht einzeln nennen
- [ ] `flutter analyze`, `flutter test test/features test/golden/signature_panel_golden_test.dart test/golden/settings_golden_test.dart test/golden/kassa_golden_test.dart` grün
- [ ] Commit: `RKSV S2b Task 7: Karte "Signatur" und Kassa im echten Betrieb`

### Task 8: Prüfwerkzeug mit einer echten Kette, Prüfliste, Abschnitt 12

**Files:**
- Modify: `app/test/rksv/pruefwerkzeug_test.dart` (ein Szenario mehr), `docs/superpowers/specs/2026-11-19-rksv-online-signatur-design.md` (neuer Abschnitt 12 "Abweichungen beim Bau von S2b")
- Create: `docs/testen/rksv-inbetriebnahme-pruefliste.md`

**Inhalt:**
- Test: eine `live`-Kette über `goLive` am nachgebauten A-Trust (Start in der Vergangenheit wie R11 aus S1b), mit Startbeleg, Verkäufen, Storno, Ausfall mit Sammelbeleg, Nullbeleg und Schlussbeleg durch `decommission`; `exportProtocol`; das Prüfwerkzeug des Finanzministeriums sagt PASS (der Test läuft wie der Bestand nur, wo das Werkzeug liegt).
- Prüfliste für Niko (Du-Form, einfache Wörter, Kästchen, Texte am Bildschirm genau wie im Code, kein Gedankenstrich): was er braucht (Konto bei A-Trust, Drucker, FinanzOnline-Zugang oder Steuerberatung, App "BMF Belegcheck"), Zugangsdaten eingeben, vier Haken, Angaben abschreiben oder drucken, was vor dem Start an der alten Kassa zu tun ist, in Betrieb nehmen, Startbeleg prüfen, bei FinanzOnline anmelden (Frist eine Woche), ein Verkauf, ein Storno, WLAN aus und wieder an, Protokoll ausgeben, was bei "A-Trust hat die Zugangsdaten abgelehnt." zu tun ist, und der Hinweis: Der Schritt lässt sich nicht zurücknehmen, vor dem echten Tag mit der Steuerberatung abstimmen. Zugangsdaten nie in den Chat.
- Abschnitt 12: Q1 bis Q17, die Entscheidungen des Controllers während des Baus (aus `task-8-facts.md`, das der Controller schreibt), was am Wortlaut der Verordnung geprüft wurde (Startbeleg, Protokoll, Monatsbeleg, Ausfall, Außerbetriebnahme; Quellen: Text der RKSV Stand 11/2015, Leitfaden der WKO 11/2016, Handbuch des BMF 1/2021) und was für die Steuerberatung offen bleibt (Monatsbeleg erst vor dem ersten Bon des neuen Monats, Frist für den Jahresbeleg, Tausch der alten Kassa).

- [ ] Test schreiben, scheitern sehen, umsetzen
- [ ] Prüfliste und Abschnitt 12 schreiben; `grep` nach Gedankenstrichen und `/mnt/project-files`
- [ ] Commit: `RKSV S2b Task 8: Prüfwerkzeug mit echter Kette, Prüfliste, Abschnitt 12`

## Nach den Tasks (Controller)

Schlussprüfung über den ganzen Zweig seit 260faa7, eine Runde Behebung, Version 1.7.0 Build 9 mit den Versions-Vergleichsbildern, GitHub `app` grün, Installationsdatei bauen und über den Server ausliefern, Entscheidungen für Niko als Dokument, Protokoll nach `/mnt/project-files/kassa-plan/`.
