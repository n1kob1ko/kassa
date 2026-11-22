# RKSV S2c: Signatur mit der Chipkarte (Bauplan)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Die Signaturkarte von A-Trust am USB-Kartenleser signiert jeden Bon, ohne Internet: als Probe ("Mit Karte ausprobieren", Testbons) und im echten Betrieb ("Signatur einrichten" mit Karte, Angaben für FinanzOnline, Startbeleg). Der Chef kann die Kassen-ID vor der Inbetriebnahme überschreiben.

**Architecture:** Ein Halter (`CardSigner`) besitzt den Leser, hält die Sitzung mit der Karte zwischen den Bons offen und prüft die PIN einmal je Sitzung. Darüber liegt `CardSignatureUnit` als dritte Umsetzung von `SignatureUnit`. `rksv_chains.unit` bekommt `cardTest` (Modus probe) und `card` (Modus live). `RksvService` bekommt die Wege für Karten-Probe, Angaben und Inbetriebnahme mit der Karte und teilt den Kern mit dem Online-Weg. Die Oberfläche bekommt die Wahl "Womit signiert die Kassa?", den Schritt "Karte und PIN" und "Kassen-ID ändern".

**Tech Stack:** Flutter 3.50, Dart, drift, flutter_riverpod 3, `pointycastle`, `flutter_secure_storage`. Keine neuen Pakete. Kotlin wird nicht geändert, nur das Manifest.

**Spec:** `docs/superpowers/specs/2026-11-22-rksv-karte-im-betrieb-design.md`. Kern und "Karte prüfen": `docs/superpowers/specs/2026-11-18-rksv-signatur-design.md` (6.1 bis 6.9, 11.1). Stand von 1.7.0: `docs/superpowers/specs/2026-11-19-rksv-online-signatur-design.md` (Abschnitt 12).

**Stand beim Start:** Zweig `claude/project-thread-xtooco` bei 9011071 (App 1.7.0 Build 9, Tablet-Datenbank Version 6).

## Entscheidungen in diesem Plan (Claude)

| Nr. | Entscheidung | Warum | Preis |
|---|---|---|---|
| C1 | Keine Migration, Datenbank bleibt 6. `rksv_chains.unit` ist Text ohne Einschränkung und bekommt `cardTest` und `card`. | Wie Q1 in S2b. | Keiner. |
| C2 | Die PIN wird einmal je Sitzung geprüft: beim ersten Signieren einer Sitzung und noch einmal, wenn die Karte eine Unterschrift mit `6982` (Sicherheitszustand nicht erfüllt) ablehnt, dann genau einmal. | Ein Befehl je Bon statt zwei. Verlangt eine Kartenart die PIN doch je Unterschrift, fängt die Wiederholung das ab. | An echter Hardware ungeprüft, welche Karte was verlangt; im zweiten Fall zwei Befehle mehr je Bon. |
| C3 | Die gespeicherte PIN gilt nur für die Karte, mit der sie in "Karte und PIN" eine gültige Probe-Unterschrift geliefert hat (Kartenart und Kartennummer). | Anti-Ziel: Eine PIN geht nie an eine andere Karte. | Eine getauschte Karte braucht den Schritt neu. |
| C4 | Eine beantwortete Ablehnung der PIN (`63Cx`, `6983`, `6984`) oder zwei PIN-Prüfungen ohne Antwort hintereinander setzen "abgelehnt". Danach geht von selbst keine PIN mehr hinaus, auch nach einem Neustart. Der Zähler "ohne Antwort" wird vor dem Senden geschrieben; schreibt der Speicher nicht, geht keine PIN hinaus. | Die Kassa verbraucht von selbst höchstens zwei der drei Versuche. | Nach zwei Abbrüchen mitten in der PIN-Prüfung (Karte gezogen) muss der Chef die PIN neu eingeben, obwohl sie stimmt. |
| C5 | Bei Ketten mit Karte gilt auch im Ausfall die Frist von 5 Sekunden statt 1. Hat der Halter keine Sitzung, versucht `sign` selbst, eine zu öffnen (läuft gerade ein Aufwärmen, wartet es auf dieses). Die PIN prüft erst das Signieren, nicht das Aufwärmen. | Öffnen, PIN und Unterschrift dauern zusammen länger als 1 Sekunde; mit 1 Sekunde käme die Signatur nie von selbst zurück. Fehlen Leser, Erlaubnis oder Karte, steht das sofort fest und kostet den Bon keine Wartezeit. So signiert schon der erste Bon nach dem Wiederanstecken. | Antwortet eine steckende Karte gar nicht, wartet jeder Bon bis zu den Grenzen der Sitzung (höchstens 5 Sekunden), bis die Karte gezogen ist. |
| C6 | Beim Signieren öffnet der Halter den Leser nur, wenn Android die Erlaubnis schon gegeben hat (`UsbDeviceInfo.granted`). Nur das Aufwärmen mit `ask: true` (Start und Fortsetzen der App, "Nochmal prüfen", Einrichtung) darf das Fenster von Android auslösen. | Kein Fenster von Android mitten im Bon. | Nach dem Wiederanstecken ohne gemerkte Erlaubnis kommt das Fenster erst beim nächsten Aufwärmen. |
| C7 | Das Manifest meldet die App für USB-Geräte der Klasse 11 an (`USB_DEVICE_ATTACHED` mit Filter). Kotlin bleibt, wie es ist. | Android bietet dann "immer für dieses Gerät öffnen" an, und die Erlaubnis gilt nach dem Anstecken von selbst. `launchMode` ist `singleTop`, die laufende Kassa startet nicht neu. | An echter Hardware ungeprüft. Android zeigt beim ersten Anstecken ein eigenes Fenster. |
| C8 | Kassen-ID: 1 bis 20 Zeichen aus `A-Z`, `0-9` und `-`, Eingabe wird groß geschrieben. Geändert wird das `PendingSetup` (Kennung neu, AES-Schlüssel bleibt). Eine Kennung, die eine Kette dieses Tablets trägt, ist nicht erlaubt. | Das BMF nennt keine Regel; der Unterstrich trennt die Felder im Code und ist ausgeschlossen. | Strenger als FinanzOnline vielleicht erlaubt. |
| C9 | Tastatur gibt es jetzt in zwei Dateien: `credentials_screen.dart` und `cash_box_id_sheet.dart`. | Niko will die Kassen-ID eingeben (20.11.2026). | Zweite Ausnahme von der Touch-Regel, nur Chef, nur Einrichtung. |
| C10 | Die Wege des Online-Betriebs (`enableOnlineProbe`, `prepareSetup`, `goLive`) behalten Namen und Parameter. Die Karte bekommt `enableCardProbe`, `prepareCardSetup`, `goLiveWithCard`; der Kern dahinter ist einer. | Die vielen Tests des Online-Wegs bleiben gültig. | Drei Methoden mehr. |
| C11 | Aussteller-Zertifikate gibt es bei der Karte nicht: leere Liste in Kette und Protokoll. | Die Karte liefert nur ihr eigenes Zertifikat. | Das Prüfwerkzeug bekommt das Zertifikat der Karte über seine Schlüsseldatei (wie bei der Probe). |
| C12 | Ausfall über 48 Stunden bei `card`: `Grund: 2, Signatur- bzw. Siegelerstellung unmöglich oder fehlerhaft` (BMF Webservice 4.1). Der Text für Ketten an A-Trust online bleibt, wie er ist. | Spec 4. | Die Nummer 3 des Online-Wegs bleibt ungeklärt (Liste für Niko). |
| C13 | Während "Karte prüfen" oder "Karte und PIN" läuft, hat der Halter keine Sitzung; ein Bon in dieser Zeit ist ein Ausfall mit "Die Karte wird gerade geprüft.". | Ein Leser, ein Besitzer. | Der Chef darf während des Verkaufs nicht prüfen, ohne einen Bon mit Vermerk zu riskieren. |

## Global Constraints

- **Die Kassa verkauft immer.** Kein Fehler von Leser, Karte, geschütztem Speicher oder Halter verhindert einen Verkauf oder ein Storno oder verzögert ihn über die Frist des Journals (5 Sekunden). Bei `card` ist jeder Fehler der Einheit ein Ausfall (Q6); bei `cardTest` wie bei `atrustTest` (Satz der Einheit: Ausfall; unerwarteter Fehler: Probe endet mit dem bekannten Hinweis).
- **Schutz der Karte.** Befehle nur aus den Fabriken von `CardCommand`. VERIFY nur, wenn Kartenart und Kartennummer der eingeschalteten Karte den gespeicherten gleichen. Nach "abgelehnt" (C4) geht keine PIN mehr hinaus, bis der Chef sie neu eingegeben hat. Die Kassa verbraucht von selbst nie den dritten Versuch.
- **Geheimnisse.** PIN und AES-Schlüssel stehen nie in der Datenbank, in einem Log, in `toString`, in einer Fehlermeldung, im Bericht von "Karte prüfen", im Protokoll oder in einer Nachricht an den Server. Bytes eines VERIFY stehen nie in einem Text. Im geschützten Speicher nur über `kassaSecureStorage`.
- **Echt heißt echt.** Eine Kette `card` entsteht nur durch `goLiveWithCard`. `cardTest` ergibt immer Testbons (Modus probe). Eine `live`-Kette wird nie gelöscht und nie umgeschrieben.
- **Jede Unterschrift wird geprüft.** Kein Eintrag bekommt eine Signatur, die am Tablet nicht zum Zertifikat der Kette passt.
- **Tests** nehmen `FakeCardReader`, `FakeCard`, `MemoryRksvSecrets`, `MemoryPinGuard` und erfundene Werte. Kein Test spricht mit einem System von A-Trust (Q11). Keine echten Zertifikate, Kartennummern oder PINs im Repo.
- **Tastatur** nur in `credentials_screen.dart` und `cash_box_id_sheet.dart` (C9). Die PIN kommt über das vorhandene Zahlenfeld (`card_pin_sheet.dart`).
- **Unberührt:** `server/`, `web/`, `.github/workflows/`, `app/lib/sync/`, die Datenbank-Version, `server/migrations/`, Kotlin, der USB-Teil des Druckers, `atr.dart`, `ccid.dart`, `t1.dart`, `card_session.dart`, `atrust_card.dart` (keine neuen Befehle), der Ablauf des Online-Wegs (`app/lib/rksv/online/`, außer wo ein Task es nennt).
- **Texte** am Bildschirm und am Bon sind deutsch, in der Du-Form, genau wie in diesem Plan. Kein Gedankenstrich. Bezeichner englisch. Design-Regeln: vorhandene Bausteine und Abstände der Einstellungen verwenden, Tippflächen mindestens 48, kein neuer Stil.
- **Version:** setzt der Controller am Ende auf 1.8.0 Build 10. Kein Task ändert sie oder erzeugt Versions-Vergleichsbilder neu.
- **Tests laufen** gezielt lokal, die ganze Suite auf GitHub (`app`). Vergleichsbilder nur neu oder dort ändern, wo der Task es nennt.

## Review Focus

1. **Karte oder Leser weg mitten im Verkauf, dann wieder da:** Der Bon wird innerhalb der Frist fertig und trägt den Vermerk; nach dem Wiederanstecken signiert der nächste Bon, und der Sammelbeleg entsteht. Test in Task 1 (Halter) und Task 2 (Journal).
2. **Eine andere Karte steckt:** Keine PIN geht hinaus, Ausfall "Im Kartenleser steckt eine andere Karte.". Test in Task 1.
3. **Die gespeicherte PIN stimmt nicht mehr:** genau ein VERIFY, danach nie wieder, auch nach einem Neustart mit demselben Speicher; zwei VERIFY ohne Antwort hintereinander zählen gleich. Test in Task 1.
4. **Die Karte wird beim Startbeleg der Inbetriebnahme gezogen:** Alles bleibt wie vorher, samt laufender Probe und `PendingSetup`. Test in Task 3.
5. **Kassen-ID:** Kleinbuchstaben, Unterstrich, 21 Zeichen, leer, Kennung einer vorhandenen Kette; Ändern nach dem Drucken behält den AES-Schlüssel. Test in Task 3 und Task 5.

---

### Task 1: PIN im geschützten Speicher und der Halter der Karte

**Files:**
- Create: `app/lib/rksv/card/card_signer.dart`
- Modify: `app/lib/rksv/rksv_secrets.dart` (Schnittstelle, `SecureRksvSecrets`, `MemoryRksvSecrets`)
- Test: `app/test/rksv/card/card_signer_test.dart` (neu), `app/test/rksv/rksv_secrets_test.dart`

**Interfaces:**
- Consumes: `ReaderTransport`, `UsbDeviceInfo.granted`/`isCardReader`, `CcidReader`, `CardSession`, `CardCommand`, `profileForAtr`, `PinGuard`, so wie `CardCheck` sie für `_signOnCard` und `_signRound` verwendet (dort nachlesen, nicht `CardCheck` umbauen).
- Produces in `rksv_secrets.dart`:
  - `final class CardPin { const CardPin({required this.kind, required this.numberHex, required this.pin}); final String kind; /* CardKind.name */ final String numberHex; /* Großbuchstaben */ final String pin; }` mit `toString() => 'CardPin'`.
  - `final class CardPinStatus { const CardPinStatus({this.rejected = false, this.unanswered = 0}); }`
  - `RksvSecrets.cardPin()`, `writeCardPin(CardPin?)` (Schlüssel `rksv_card_pin`, ein JSON-Wert; `null` löscht; Schreiben setzt den Status zurück), `cardPinStatus()`, `writeCardPinStatus(CardPinStatus)` (Schlüssel `rksv_card_pin_status`; fehlt der Wert: `const CardPinStatus()`; unlesbar: `rejected: true`).
- Produces in `card_signer.dart`:
  - `enum CardSignProblem { noReader, noPermission, noCard, otherCard, pinMissing, pinRejected, silent, refused, busy }`
  - `final class CardSignException implements Exception { const CardSignException(this.problem); final CardSignProblem problem; String get sentence; }` mit den Sätzen: `Kein Kartenleser gefunden.` / `Der Zugriff auf den Kartenleser ist nicht erlaubt.` / `Keine Karte im Kartenleser.` / `Im Kartenleser steckt eine andere Karte.` / `Die PIN der Karte fehlt.` / `Die Karte hat die PIN abgelehnt.` / `Die Karte antwortet nicht.` / `Die Karte hat die Unterschrift abgelehnt.` / `Die Karte wird gerade geprüft.`
  - `class CardSigner { CardSigner({required ReaderTransport transport, required RksvSecrets secrets, required PinGuard guard}); Future<Uint8List> sign(Uint8List hash); Future<void> warmUp({bool ask = false}); Future<void> release(); Future<T> paused<T>(Future<T> Function() body); void pinChanged(); bool get ready; CardSignProblem? get lastProblem; }`
  - `sign`: 32 Bytes Hash hinein, rohe Antwort der Karte auf die Unterschrift heraus (was `CardCommand.sign` liefert). Aufrufe laufen nacheinander. Wirft nur `CardSignException`.
  - Sitzung öffnen: `list()`, erster Leser (`isCardReader`); beim Signieren nur mit `granted` (C6), sonst `noPermission`; `warmUp(ask: true)` öffnet auch ohne. Karte einschalten, Art aus der ATR, Kartennummer lesen, mit `CardPin` vergleichen (`otherCard`), Hauptordner und Ordner der Signatur wählen, bei `separateHash` `prepareSignature`. Ohne `CardPin`: `pinMissing`, ohne die Karte einzuschalten.
  - PIN (C2, C4): VERIFY beim ersten Signieren der Sitzung und einmal nach `6982`. Vor jedem VERIFY `unanswered + 1` schreiben (scheitert das Schreiben: `silent`, nichts geht hinaus); nach `9000` Status zurück auf leer; nach einer beantworteten Ablehnung `rejected: true` schreiben und dem `PinGuard` die Zahl der Versuche melden wie `CardCheck._wrongVerify`. Gilt `rejected` oder `unanswered >= 2` (Speicher oder Arbeitsspeicher): `pinRejected`, ohne VERIFY. `pinChanged()` vergisst den Stand im Arbeitsspeicher und die Sitzung.
  - Fehler der Verbindung beenden die Sitzung (`silent` oder `noCard`); der nächste Aufruf öffnet neu (C5): `sign` ohne Sitzung öffnet selbst, und läuft gerade ein `warmUp`, wartet es auf dieses. Nach jedem gescheiterten `sign` ruft der Halter `warmUp()` (ohne `await`), außer bei `pinRejected`, `pinMissing`, `otherCard` und `busy`.
  - Kartenart und Profil kommen bei jedem Öffnen aus der ATR (`profileForAtr`) und werden mit `CardPin.kind` verglichen; nichts davon wird aus "Karte prüfen" übernommen.
  - "Ohne Antwort" heißt: Der Befehl VERIFY endet ohne Statuswort (Ausnahme der Sitzung oder Grenze abgelaufen), gleich aus welchem Grund. Status und `CardPin` sind je ein Wert für die ganze Kassa (es gibt genau eine gespeicherte Karte); der `PinGuard` bleibt daneben, wie er ist.
  - `warmUp`: höchstens ein Versuch zugleich, wirft nie; öffnet die Sitzung, prüft keine PIN. Läuft gerade einer, wartet ein zweiter Aufruf auf denselben.
  - `paused(body)`: gibt die Sitzung frei, hält `sign` und `warmUp` mit `busy` ab, bis `body` fertig ist; verschachtelt erlaubt.
  - Die Frist setzt der Aufrufer. Wird ein `sign` nach der Frist fertig, endet es ohne unbehandelte Ausnahme, und die Sitzung bleibt. Ein `sign`, das hinter einem solchen noch laufenden Aufruf wartet, wartet weiter; die Grenzen der Sitzung (3 und 5 Sekunden je Befehl) beenden das Warten.

**Tests:** zwei Bons hintereinander: ein Einschalten, ein VERIFY, zwei Unterschriften; `6982` bei der zweiten Unterschrift: genau ein weiteres VERIFY; Review Focus 1 (Leser nach n Aufrufen weg, `sign` wirft; ohne Leser und ohne Karte wirft das nächste `sign` ohne einen Befehl an die Karte; nach "wieder da" signiert schon das nächste `sign` ohne `warmUp`; ein `sign` während eines laufenden `warmUp` wartet auf dieses und öffnet nicht ein zweites Mal); Review Focus 2 (andere Kartennummer und andere Kartenart: kein VERIFY in `FakeCard`); Review Focus 3 (falsche gespeicherte PIN: ein VERIFY, `rejected` im Speicher, ein neuer `CardSigner` mit demselben Speicher schickt keins; zwei VERIFY ohne Antwort: danach keins mehr; ein gelungenes dazwischen setzt zurück; Speicher schreibt nicht: kein VERIFY); ohne Erlaubnis: `sign` öffnet nicht, `warmUp(ask: true)` öffnet; ohne `CardPin`: `pinMissing` ohne Einschalten; `paused`: `sign` währenddessen `busy`, danach geht es; zwei `sign` zugleich laufen nacheinander; die PIN steht in keinem `toString`, keiner Ausnahme und in `FakeCardReader`s Protokoll nur maskiert; `rksv_secrets_test`: Hin und Zurück, Löschen, unlesbarer Status.

- [ ] Tests schreiben und scheitern sehen
- [ ] Umsetzen
- [ ] `flutter analyze`, `flutter test test/rksv/card test/rksv/rksv_secrets_test.dart` grün
- [ ] Commit: `RKSV S2c Task 1: PIN im geschützten Speicher und Halter der Karte`

### Task 2: Karten-Einheit, Journal und "Karte prüfen" neben dem Halter

**Files:**
- Create: `app/lib/rksv/card/card_signature_unit.dart`, `app/lib/rksv/card/card_facts.dart`
- Modify: `app/lib/rksv/rksv_state.dart` (`RksvUnit`), `app/lib/rksv/rksv_journal.dart` (`signatureUnitOf`, Frist C5, Grund C12), `app/lib/rksv/rksv_providers.dart`, `app/lib/rksv/card/card_providers.dart`, `app/lib/rksv/card/card_check.dart`, `app/android/app/src/main/AndroidManifest.xml`
- Create: `app/android/app/src/main/res/xml/usb_card_reader_filter.xml`
- Test: `app/test/rksv/card/card_signature_unit_test.dart`, `app/test/rksv/rksv_card_journal_test.dart` (neu), `app/test/rksv/card/card_check_test.dart`, `app/test/android_usb_filter_test.dart` (neu), `app/test/support/rksv_rig.dart`

**Interfaces:**
- Consumes: `CardSigner` (Task 1), `CardCertificate`, `SignatureUnit`, `SignerInfo`.
- Produces:
  - `enum RksvUnit { probe, atrustTest, atrust, cardTest, card }`. Jede Stelle, die über `RksvUnit` oder `chain.unit` entscheidet, behandelt die neuen Werte ausdrücklich (kein stilles `default`).
  - `final class CardFacts { const CardFacts({required this.kind, required this.numberHex, required this.certificateDer, required this.serialHex}); }` in `card_facts.dart`; `zdaId` der Karte ist die Konstante `cardZdaId = 'AT1'`.
  - `class CardSignatureUnit implements SignatureUnit { CardSignatureUnit({required CardSigner signer, required String zdaId, required Uint8List certificateDer}); }`: `info()` wie die Online-Einheit, ohne Aussteller. `sign`: SHA-256 der ASCII-Bytes, `signer.sign`, Ergebnis in 64 Bytes R|S bringen (liefert die Karte DER, umwandeln), gegen das Zertifikat prüfen (`Die Unterschrift der Karte passt nicht zum Zertifikat.`). `CardSignException` wird `SignatureFailure(sentence)`, alles andere `SignatureFailure('Die Signatur der Karte ist gescheitert.')`.
  - `typedef CardUnitOf = Future<SignatureUnit> Function(RksvChainRow chain, RksvCertificateRow certificate);` und `signatureUnitOf(db, secrets, {required OnlineUnitOf online, required CardUnitOf card})`: `cardTest` verlangt Modus probe (sonst `StateError`), `card` baut die Einheit. `probeSignatureUnitOf` lehnt beide ab.
  - `cardSignerProvider` (ein Halter für die App, `ref.onDispose(release)`), `cardSignatureUnitOf(Ref)`.
  - Journal: bei `cardTest` und `card` gilt auch im Ausfall `signLimit` (C5). Aufgabe `reportOutage` bei `card`: Detail `<Beginn>. Grund: 2, Signatur- bzw. Siegelerstellung unmöglich oder fehlerhaft` (C12). `cardTest` verhält sich wie `atrustTest`, `card` wie `atrust`.
  - `CardCheck`: neuer Parameter `CardSigner? signer`; `run()` und `sign()` laufen in `signer.paused` (C13). `CardFacts? get facts`: gesetzt, sobald Zeile 5 des letzten Laufs grün ist, sonst `null`. `run({String? expectSerialHex})`: weicht die Seriennummer des gelesenen Zertifikats ab, wird Zeile 4 ein Kreuz mit `Das ist nicht die Karte dieser Kassa.` und Zeile 5 nicht angeboten. Sonst bleibt `CardCheck` wie es ist.
  - Manifest (C7): in der `activity` ein zweiter `intent-filter` mit `android.hardware.usb.action.USB_DEVICE_ATTACHED` und `meta-data` auf `@xml/usb_card_reader_filter`; die Datei enthält `<usb-device class="11" />`.
  - `RksvRig`: eine Karten-Kette anlegen können (`FakeCardReader` mit `FakeCard`, gespeicherte `CardPin`), für die Tests ab Task 3.

**Tests:** Einheit: gültige Unterschrift 64 Bytes; falsches Zertifikat: Satz; jeder `CardSignProblem` gibt seinen Satz; nach einem Fehler läuft `warmUp`. Journal (Review Focus 1): Kette `card`, Karte weg: Bon mit Vermerk und Grund im Stand; Karte wieder da: schon der nächste Bon signiert, der Sammelbeleg entsteht wie bisher mit diesem Bon oder mit "Nochmal prüfen", Ausfall beendet; Frist: eine Karte, die für Öffnen und Unterschrift 2 Sekunden braucht, signiert im Ausfall trotzdem; `cardTest`: Satz der Einheit ist Ausfall, `StateError` beendet die Probe; `cardTest` mit Modus live: `StateError`; Ausfall über 48 Stunden bei `card`: Aufgabe mit dem Text aus C12. `CardCheck`: läuft in `paused` (ein `sign` des Halters währenddessen ist `busy`), `facts` nur nach grüner Zeile 5, `expectSerialHex`. Manifest-Test wie `android_backup_test.dart`.

- [ ] Tests schreiben und scheitern sehen
- [ ] Umsetzen
- [ ] `flutter analyze`, `flutter test test/rksv test/android_usb_filter_test.dart` grün
- [ ] Commit: `RKSV S2c Task 2: Karten-Einheit, Journal, Karte prüfen neben dem Halter`

### Task 3: Karten-Probe, Angaben und Inbetriebnahme im Service

**Files:**
- Modify: `app/lib/rksv/rksv_service.dart`, `app/lib/rksv/setup_facts.dart`, `app/test/support/rksv_rig.dart`
- Test: `app/test/rksv/card_go_live_test.dart` (neu), `app/test/rksv/setup_facts_test.dart`, `app/test/rksv/go_live_test.dart` (nur wo `setupFactsOf` sich ändert)

**Interfaces:**
- Consumes: `CardFacts`, `cardZdaId`, `RksvUnit.cardTest`/`card`, `PendingSetup`.
- Produces:
  - `setup_facts.dart`: `const setupKindCard = 'Signaturkarte';`, `setupFactsOf` bekommt `required String kind`; der Online-Weg übergibt `setupKind`.
  - `Future<Receipt> RksvService.enableCardProbe({required Staff staff, required CardFacts facts})`: wie `enableOnlineProbe`, Kette Modus probe, `unit: cardTest`, `zdaId: cardZdaId`, Zertifikat der Karte, keine Aussteller. Läuft die Signatur schon: `StateError`.
  - `Future<SetupFacts> RksvService.prepareCardSetup({required CardFacts facts})`: wie `prepareSetup` (dieselbe Schlange, dasselbe `PendingSetup`), `kind: setupKindCard`, `provider: 'AT1 = A-TRUST'`. Schon in Betrieb: `StateError`.
  - `Future<Receipt> RksvService.goLiveWithCard({required Staff staff, required CardFacts facts})`: wie `goLive` (Q7, Q17), Kette `mode: live`, `unit: card`. Kein `PendingSetup` oder schon in Betrieb: `StateError`.
  - `Future<void> RksvService.changeCashBoxId(String id)` (C8): läuft in der Schlange von `prepareSetup`. Regel `^[A-Z0-9-]{1,20}$` nach `trim` und Großschreiben. Wirft `RksvProblem` mit `Die Kassen-ID darf nur Buchstaben, Ziffern und Bindestriche haben, höchstens 20 Zeichen.` / `Diese Kassen-ID hat diese Kassa schon verwendet.` / den Sätzen des Speichers wie `prepareSetup`. Ohne `PendingSetup` oder in Betrieb: `StateError`. Schreibt ein neues `PendingSetup` mit demselben AES-Schlüssel und liest es zur Kontrolle zurück.
  - `static String? RksvService.cashBoxIdProblem(String input)`: derselbe Formsatz oder `null`, für das Feld.
  - Der Kern von `enableOnlineProbe`/`enableCardProbe`, `prepareSetup`/`prepareCardSetup` und `goLive`/`goLiveWithCard` ist je einer (C10); die Online-Methoden behalten ihr Verhalten und ihre Tests.
  - `decommission`, `zeroReceipt`, `retrySignature`, `exportProtocol`, `liveChainSerial` gelten für `card` wie für `atrust`.

**Tests:** `enableCardProbe`: Startbeleg von der nachgebauten Karte signiert, Stand probe, Einheit `cardTest`, Bon `test: true`; Karte fehlt: `RksvProblem` mit dem Satz, nichts bleibt zurück. `prepareCardSetup`: zweimal dieselben Werte, `kind` ist `Signaturkarte`, Seriennummer hex und dezimal. `goLiveWithCard` aus off, aus Probe, aus Karten-Probe: Schlussbeleg der alten Kette, neue Kette `card`, zwei Aufgaben, Zähler 0, `pendingSetup()` danach null. Review Focus 4: Karte beim Startbeleg weg (und: falsche Karte, abgelehnte PIN): `RksvProblem`, Stand wie vorher, Probe läuft ohne Schlussbeleg weiter, `PendingSetup` noch da. Danach Verkauf, Storno, Nullbeleg, `decommission` (Schlussbeleg von der Karte; ohne Karte mit Vermerk), `exportProtocol`. Review Focus 5: `changeCashBoxId` mit `kassa-1` ergibt `KASSA-1`; `A_B`, 21 Zeichen, leer, Leerzeichen innen: Formsatz und `PendingSetup` unverändert; Kennung einer vorhandenen Kette: zweiter Satz; AES-Schlüssel bleibt; `prepareCardSetup` und `prepareSetup` danach zeigen die neue Kennung; `goLiveWithCard` verwendet sie.

- [ ] Tests schreiben und scheitern sehen
- [ ] Umsetzen
- [ ] `flutter analyze`, `flutter test test/rksv test/data` grün
- [ ] Commit: `RKSV S2c Task 3: Karten-Probe, Angaben und Inbetriebnahme mit der Karte`

### Task 4: Bildschirm "Karte und PIN" und "Mit Karte ausprobieren"

**Files:**
- Create: `app/lib/features/settings/card_setup_screen.dart`, `app/lib/rksv/card/card_setup.dart`
- Modify: `app/lib/features/settings/card_check_screen.dart` (Zeilen als gemeinsamen Baustein herauslösen, Verhalten unverändert), `app/lib/features/settings/signature_panel.dart` (nur die neue Zeile), `app/lib/rksv/card/card_providers.dart`
- Test: `app/test/features/card_setup_test.dart` (neu), `app/test/golden/card_setup_golden_test.dart` (neu: `karte_und_pin_hell`, `karte_und_pin_dunkel`, `karte_und_pin_gespeichert_hell`)

**Interfaces:**
- Consumes: `CardCheck` (`run`, `sign`, `facts`, `state`), `CardSigner.pinChanged`, `RksvSecrets.cardPin`/`writeCardPin`, `enableCardProbe`, `card_pin_sheet.dart`.
- Produces:
  - `class CardSetup { CardSetup({required CardCheck check, required RksvSecrets secrets, required CardSigner signer}); Future<String?> signAndStore(String pin); Future<bool> storedFor(CardFacts facts); }`: `signAndStore` ruft `check.sign(pin)`; ist danach `check.facts` gesetzt, schreibt es `CardPin` (liest zur Kontrolle zurück), ruft `signer.pinChanged()` und gibt `null` zurück; scheitert das Speichern: `Das Tablet konnte die PIN nicht sicher speichern.`; ohne grüne Zeile 5: `''` (der Bildschirm zeigt dann die Zeile). Die PIN bleibt in keinem Feld. `cardSetupProvider`.
  - `enum CardSetupPurpose { probe, live, repin }` und `class CardSetupScreen extends ConsumerStatefulWidget { const CardSetupScreen({required this.purpose, this.onLive}); final void Function(CardFacts facts)? onLive; }`
  - Texte: Titel `Karte und PIN`. Darunter `Steck die Signaturkarte in den Kartenleser. Die Kassa liest sie und fragt dann einmal nach der PIN.` Die fünf Zeilen und ihre Texte kommen aus `CardCheck` wie in "Karte prüfen". Taste für Zeile 5: `PIN eingeben` (öffnet das Zahlenfeld). Unter den Zeilen, sobald gespeichert: `Karte und PIN sind gespeichert.` Hinweis rechts: `Die PIN bleibt verschlüsselt auf diesem Tablet. So muss sie niemand bei jedem Bon eingeben.` und `Nach drei falschen Eingaben sperrt sich die Karte. Gib nur eine PIN ein, die du sicher weißt.`
  - Haupttaste je Zweck: `probe`: `Probe starten` (ruft `enableCardProbe`, druckt den Startbeleg wie die Probe, zurück in die Einstellungen mit `Die Probe mit der Karte läuft.`); `live`: `Weiter` (ruft `onLive(facts)`); `repin`: `Fertig`. Die Haupttaste ist erst aktiv, wenn für die gelesene Karte eine PIN gespeichert und nicht abgelehnt ist.
  - Ist beim Öffnen für die gelesene Karte schon eine PIN gespeichert und nicht abgelehnt: Zeilen 1 bis 4 laufen, statt Zeile 5 steht `Karte und PIN sind gespeichert.` mit der Nebentaste `PIN neu eingeben`.
  - `repin` übergibt `expectSerialHex` der laufenden Kette (`RksvService.liveChainSerial`).
  - Karte "Signatur": neue Zeile, nur wenn die Signatur aus ist und nur für den Chef, direkt nach "Mit A-Trust ausprobieren": Titel `Mit Karte ausprobieren`, Hilfe `Die Signaturkarte im Kartenleser signiert die Bons. Ohne Internet. Sie bleiben Testbons.`, Taste `Ausprobieren`. Sie öffnet `CardSetupScreen(purpose: probe)`.
  - Scheitert `enableCardProbe`: der Satz aus `RksvProblem`, der Bildschirm bleibt offen.

**Tests:** Der ganze Weg mit `FakeCardReader`: öffnen, vier Haken, PIN am Zahlenfeld, fünfter Haken, "gespeichert", `Probe starten`, Startbeleg signiert, Stand probe mit Einheit `cardTest`; falsche PIN: Zeile 5 wie in "Karte prüfen", nichts gespeichert, Haupttaste aus; Speicher schreibt nicht: Satz; schon gespeichert: kein Zahlenfeld nötig; andere Karte als die gespeicherte: PIN wird neu verlangt; `repin` mit falscher Seriennummer: Kreuz; Doppeltipp auf `Probe starten` ruft einmal; ein Mitarbeiter ohne Chef-Recht sieht die Zeile nicht. "Karte prüfen" verhält sich wie vorher (Bestandstests grün, Vergleichsbilder unverändert).

- [ ] Tests schreiben und scheitern sehen
- [ ] Umsetzen, neue Vergleichsbilder erzeugen und ansehen
- [ ] `flutter analyze`, `flutter test test/features test/golden/card_setup_golden_test.dart test/golden/card_check_golden_test.dart test/rksv/card` grün (heißt die Bilddatei von "Karte prüfen" anders: die vorhandene)
- [ ] Commit: `RKSV S2c Task 4: Karte und PIN, Mit Karte ausprobieren`

### Task 5: Wahl der Signatur, Angaben mit Karte, Kassen-ID ändern

**Files:**
- Create: `app/lib/features/settings/signer_choice_screen.dart`, `app/lib/features/settings/cash_box_id_sheet.dart`
- Modify: `app/lib/features/settings/setup_facts_screen.dart`, `app/lib/features/settings/signature_panel.dart` (nur "Signatur einrichten" öffnet die Wahl), der Zettel "Angaben drucken" (dort, wo S2b ihn gebaut hat), `app/test/no_text_field_test.dart`
- Test: `app/test/features/card_live_flow_test.dart` (neu), `app/test/features/setup_flow_test.dart`, `app/test/golden/signer_choice_golden_test.dart` (neu: `signatur_wahl_hell`, `signatur_wahl_dunkel`, `angaben_finanzonline_karte_hell`, `kassen_id_aendern_hell`)

**Interfaces:**
- Consumes: `CardSetupScreen(purpose: live, onLive:)`, `prepareCardSetup`, `goLiveWithCard`, `changeCashBoxId`, `cashBoxIdProblem`, `CardSigner.warmUp`, der Online-Ablauf von 1.7.0.
- Produces:
  - `SignerChoiceScreen`: Titel `Womit signiert die Kassa?`, zwei große Flächen: `Signaturkarte am Kartenleser` mit `Ohne Internet. Die Karte muss immer im Leser stecken.` und `A-Trust online` mit `Braucht Internet und die Zugangsdaten von A-Trust.`. Die erste öffnet "Karte und PIN" und danach die Angaben, die zweite den bisherigen Ablauf ab "Zugangsdaten von A-Trust". "Signatur einrichten" in der Karte "Signatur" öffnet diese Wahl; die Hilfe der Zeile wird `Für den echten Betrieb, mit Signaturkarte oder A-Trust online.`
  - `SetupFactsScreen` nimmt beide Quellen: `const SetupFactsScreen({required this.facts})` bleibt für online, dazu `const SetupFactsScreen.card({required CardFacts card})`. Mit Karte: `prepareCardSetup`, vor `goLiveWithCard` wird `CardSigner.warmUp(ask: true)` abgewartet (höchstens 20 Sekunden), Sperre und Meldungen wie beim Online-Weg. Einleitung mit Karte: `Diese Angaben trägst du bei FinanzOnline ein, wenn du die Signaturkarte und die Kassa anmeldest.`
  - Zeile `Kassenidentifikationsnummer` bekommt rechts die Taste `Ändern` (beide Wege). Sie öffnet `CashBoxIdSheet`: Titel `Kassen-ID ändern`, ein Textfeld (vorbelegt, Großbuchstaben, höchstens 20 Zeichen, nur `A-Z`, `0-9`, `-`), Hilfe `Buchstaben, Ziffern und Bindestrich, höchstens 20 Zeichen.`, Hinweise `Nimm keine Kennung, die bei FinanzOnline schon angemeldet ist.` und `Ein schon gedruckter Zettel gilt danach nicht mehr.`, Tasten `Speichern` und `Abbrechen`. Fehler stehen unter dem Feld. Nach `Speichern` zeigt der Bildschirm die neue Kennung.
  - Zettel: die Zeile `Art der Sicherheitseinrichtung` trägt `SetupFacts.kind` (bei der Karte `Signaturkarte`).
  - `no_text_field_test.dart` lässt genau die zwei Dateien aus C9 zu.
  - Nach `goLiveWithCard`: zurück in die Einstellungen mit `Die Kassa ist in Betrieb.`, Startbeleg wird gedruckt wie beim Online-Weg.

**Tests:** Wahl: beide Flächen führen in ihren Ablauf; der Online-Ablauf besteht seine Bestandstests. Kartenweg in einem Widget-Test: Wahl, Karte und PIN, Angaben (sechs Zeilen, Art `Signaturkarte`), `Angaben drucken` (Zettel mit `Signaturkarte`), Frage, `In Betrieb nehmen`, Stand live mit Einheit `card`, Startbeleg von der Karte. Review Focus 5 am Bildschirm: `Ändern`, Eingabe `yichi-1`, gespeichert als `YICHI-1`, Schlüssel und Prüfwert unverändert; Unterstrich lässt sich nicht tippen; leeres Feld: `Speichern` aus; vorhandene Kennung: Satz. Karte beim Start gezogen: Satz, nicht in Betrieb, Bildschirm bleibt. Doppeltipp ruft `goLiveWithCard` einmal.

- [ ] Tests schreiben und scheitern sehen
- [ ] Umsetzen, neue Vergleichsbilder erzeugen und ansehen
- [ ] `flutter analyze`, `flutter test test/features test/golden/signer_choice_golden_test.dart test/no_text_field_test.dart test/domain` grün
- [ ] Commit: `RKSV S2c Task 5: Wahl der Signatur, Angaben mit Karte, Kassen-ID ändern`

### Task 6: Karte "Signatur" und Kassa im Betrieb mit Karte

**Files:**
- Modify: `app/lib/features/settings/signature_panel.dart`, `app/lib/features/kassa/kassa_screen.dart` (`_warmUpSignature`), `app/lib/features/kassa/outage_banner.dart`, `app/lib/data/rksv_repository.dart` oder `app/lib/rksv/rksv_state.dart` (falls der Stand die Einheit braucht)
- Test: `app/test/features/signature_panel_card_test.dart` (neu), `app/test/features/kassa_card_outage_test.dart` (neu), `app/test/golden/signature_golden_test.dart` oder die vorhandene Datei der Karte "Signatur" (neu: `signatur_karte_in_betrieb_hell`, `signatur_karte_in_betrieb_dunkel`, `signatur_karte_probe_hell`, `kassa_ausfall_karte_hell`)

**Interfaces:**
- Consumes: `cardSignerProvider`, `CardSetupScreen(purpose: repin)`, `RksvSecrets.cardPinStatus`, Stand der Signatur mit Einheit.
- Produces (Karte "Signatur"):
  - Probe mit Karte: Hilfe `Signatur mit der Karte, nicht für den echten Betrieb.`, Pille `Karten-Probe`. Zeilen wie bei der Online-Probe, ohne "Verbindung prüfen"; `Probe beenden` bleibt; "Signatur einrichten" bleibt erreichbar.
  - In Betrieb mit Karte: Hilfe `Signatur mit der Karte. Kassen-ID <Kennung>.`, Pillen wie bisher (`In Betrieb`, `In Betrieb, Signatur ausgefallen`). Zeilen: `Karte und PIN` (Hilfe `Kartenleser, Karte und PIN prüfen.`, Taste `Prüfen`, öffnet `CardSetupScreen(purpose: repin)`), `Nullbeleg drucken`, `Protokoll ausgeben`, `Kassa außer Betrieb nehmen`. Nicht: "Verbindung prüfen", "Zugangsdaten".
  - Ist die PIN abgelehnt (`cardPinStatus().rejected` oder `unanswered >= 2`), steht in der Karte ein Hinweis `Die Karte hat die PIN abgelehnt.` mit der Taste `PIN neu eingeben` (nur Chef), genau einmal.
  - "Karte prüfen" bleibt als Zeile wie bisher.
- Produces (Kassa):
  - `_warmUpSignature`: läuft eine Kette `cardTest` oder `card`, ruft es `cardSigner.warmUp(ask: true)` (beim Start und beim Fortsetzen), dazu wie bisher `primeLiveKey`. Für Ketten an A-Trust bleibt alles, wie es ist.
  - Hinweis im Ausfall: zeigt den gespeicherten Grund (Satz der Karte). `Nochmal prüfen` ruft bei einer Kette mit Karte zuerst `cardSigner.warmUp(ask: true)` und dann `retrySignature`. Bei `Die Karte hat die PIN abgelehnt.` oder `Die PIN der Karte fehlt.` steht für den Chef statt `Nochmal prüfen` die Taste `PIN neu eingeben`.
  - Kein Fenster, keine Sperre und kein Warten im Verkauf durch die Karte.

**Tests:** Karte "Signatur" in den Zuständen Karten-Probe, In Betrieb mit Karte, Ausfall, abgelehnte PIN (Hinweis einmal, Taste nur für den Chef), Außer Betrieb nach Karte; die Zeilen stimmen je Zustand; ein Mitarbeiter sieht keine Tasten des Chefs. Kassa: Start mit laufender Karten-Kette ruft `warmUp(ask: true)` einmal; Verkauf mit gezogener Karte endet mit Hinweis und Grund; `Nochmal prüfen` nach "wieder da": Sammelbeleg, Hinweis weg; abgelehnte PIN: `PIN neu eingeben` öffnet "Karte und PIN", danach signiert der nächste Bon. Bestandstests der Online-Zustände bleiben grün, ihre Vergleichsbilder unverändert.

- [ ] Tests schreiben und scheitern sehen
- [ ] Umsetzen, neue Vergleichsbilder erzeugen und ansehen
- [ ] `flutter analyze`, `flutter test test/features test/golden/<Datei der Karte "Signatur"> test/golden/<Datei der Kassa im Ausfall>` grün
- [ ] Commit: `RKSV S2c Task 6: Karte Signatur und Kassa im Betrieb mit Karte`

### Task 7: Prüfwerkzeug mit einer Karten-Kette, Prüfliste, Abschnitt 10

**Files:**
- Modify: `app/test/rksv/pruefwerkzeug_test.dart`, `app/test/support/pruefwerkzeug.dart`, `docs/superpowers/specs/2026-11-22-rksv-karte-im-betrieb-design.md` (neuer Abschnitt 10 "Abweichungen beim Bau")
- Create: `docs/testen/rksv-karte-betrieb-pruefliste.md`

**Interfaces:**
- Consumes: alles aus den Tasks 1 bis 6; die Fakten zum Bau, die der Controller in der Aufgabe mitgibt.
- Produces:
  - Drittes Szenario im Prüfwerkzeug-Test: eine Kette `card`, signiert von `FakeCard` über `CardSigner` und `CardSignatureUnit` (Startbeleg, Verkäufe, Storno, Ausfall durch gezogene Karte mit Sammelbeleg, Nullbeleg, Schlussbeleg), ausgegeben mit `exportProtocol`. `tool/rksv/pruefen.sh` meldet danach `+3: All tests passed!` (das Werkzeug liegt nicht im Repo; ohne es wird der Test wie die anderen übersprungen).
  - Prüfliste für Niko, in einfachen Worten und in der Du-Form, im Aufbau wie `docs/testen/rksv-inbetriebnahme-pruefliste.md`: **Teil A "Mit Karte ausprobieren"** (für die Testkarte: was du brauchst, Karte und PIN, Probe starten, ein Verkauf, QR-Code, Karte ziehen und wieder stecken, Tablet neu starten, Probe beenden, was du mir schickst). **Teil B "In Betrieb nehmen mit der Karte von YICHI"** (Vorbereiten, Der Tag, Nach dem Start; verweist für die Schritte, die gleich sind, nicht auf die andere Liste, sondern schreibt sie aus). Oben die Warnungen: mit der Testkarte nie in Betrieb nehmen und nie bei FinanzOnline anmelden; PIN nie in den Chat, nie raten; auf den Seiten "Angaben für FinanzOnline" und beim Zahlenfeld der PIN nie ein Foto; solange "In Betrieb": App-Daten nie löschen, nie neu installieren, nie auf ein anderes Tablet umziehen.
  - Abschnitt 10 im Entwurf: 10.1 Entscheidungen im Plan (C1 bis C13), 10.2 Entscheidungen während des Baus (aus den Fakten des Controllers), 10.3 Was an echter Hardware ungeprüft ist, 10.4 Bekannte Punkte.

**Tests:** das dritte Szenario; `flutter test test/rksv/pruefwerkzeug_test.dart`.

- [ ] Szenario schreiben und scheitern sehen
- [ ] Umsetzen, Prüfliste und Abschnitt 10 schreiben
- [ ] `flutter analyze`, `flutter test test/rksv` grün; `tool/rksv/pruefen.sh`, wenn das Werkzeug da ist
- [ ] Commit: `RKSV S2c Task 7: Prüfwerkzeug mit Karten-Kette, Prüfliste, Abschnitt 10`

## Nach den Tasks (Controller)

Schlussprüfung über den ganzen Zweig seit 9011071, eine Runde Korrekturen, Version 1.8.0 Build 10 mit den Vergleichsbildern der Versionszeile, Bau der Installationsdatei in der Cloud, Entscheidungen für Niko als Dokument, Auslieferung über den Server erst nach Nikos Ja.
