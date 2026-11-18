# RKSV S1b: Kern mit Probe-Signatur Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Im Zustand "Probe" signiert die Kassa jeden Bon mit einem Schlüssel vom Tablet, verkettet ihn, führt den verschlüsselten Umsatzzähler, schreibt das Protokoll, druckt den QR-Code, erzeugt Sonderbelege, übersteht einen Ausfall der Signatur und gibt das Protokoll als Datei aus, die das Prüfwerkzeug des Finanzministeriums annimmt.

**Architecture:** Ein reiner Rechenkern unter `app/lib/rksv/core/` baut den Text des Codes, den Umsatzzähler, den Kettenwert und die JWS-Form; seine Werte sind gegen den Mustercode des Finanzministeriums festgenagelt. Eine Signatur-Schnittstelle hat zwei Umsetzungen (Attrappe für Tests, Probe-Signatur am Tablet); die Chipkarte kommt in S2 als dritte. Das `RksvJournal` schreibt je Bon genau einen Protokoll-Eintrag in derselben Datenbank-Transaktion wie der Bon. Sonderbelege sind Bons mit eigener Art ohne Tag und ohne Zahlung.

**Tech Stack:** Flutter 3.50.0, drift (Datenbank Version 4 mit Migration), `pointycastle` (AES, ECDSA, schon im Projekt), neues Paket `qr` (QR-Code am Bildschirm und als Bild für Drucker ohne QR-Befehl), `file_picker` (schon im Projekt, zum Speichern der Datei). Kein Kotlin, keine Änderung am Server.

**Spec:** `docs/superpowers/specs/2026-11-18-rksv-signatur-design.md` (Abschnitte 6.1 bis 6.7, 6.10 bis 6.12, 7, 8). Dazu `docs/design-regeln.md`, `DESIGN.md`, `PRODUCT.md`.

## Wo dieser Plan steht

| Plan | Inhalt | Stand |
|---|---|---|
| S1a | "Karte prüfen", Version 1.3.0 | ausgeliefert am 18.11.2026, Bericht von Niko offen |
| **S1b (dieser Plan)** | Kern mit Probe-Signatur, Version 1.4.0 | geschrieben |
| S2 | Chipkarte als echte Signatur, Einrichtung, Angaben für FinanzOnline, Zustand "In Betrieb" | nach Nikos Bericht, und erst wenn das Prüfwerkzeug ohne Fehler durchläuft |
| S3 | Inbetriebnahme bei YICHI | durch Niko |

## Was vor dem Schreiben geprüft wurde (18.11.2026)

- **Vergleichswerte liegen im Repo:** `app/test/rksv/fixtures/mustercode_vectors.json`, erzeugt von `tool/rksv/vektoren.sh` mit den Bibliotheken des Mustercodes (`regkassen-common-0.14.jar`, `registrierkassen-core-0.12.jar`; sie liegen nicht im Repo, sondern unter `/mnt/project-files/kassa-build/rksv/pruefwerkzeug/regkassen-verification-1.1.1/lib/`). Schlüssel und Kassen-Kennung darin sind erfunden (`BSPIMB01`, AES-Schlüssel = die Bytes 0 bis 31). Diese Datei ist die Wahrheit für Task 1; wer dort einen Wert nicht trifft, ändert den Code, nie die Datei.
- **Gelesene Quellen des Mustercodes** (nur lesen, nichts ins Repo kopieren): `/mnt/project-files/kassa-plan/rksv-quelle/` (`ReceiptRepresentationForSignature.java`, `DemoCashBox.java`, `CryptoUtil.java`, `CashBoxUtils.java`, `ManualJWSModule.java`, `RKSuite.java`).
- **Prüfwerkzeug** 1.1.1 liegt unter `/mnt/project-files/kassa-build/rksv/pruefwerkzeug/regkassen-verification-1.1.1/` (zwei jar-Dateien, nie ins Repo). Beispiel für Eingabe und Ausgabe: `…/pruefwerkzeug/beispiel/example-output-0.7.1/open/TESTSUITE_TEST_SZENARIO_2/` (`dep-export.json`, `cryptographicMaterialContainer.json`). Aufruf: `JAVA_TOOL_OPTIONS= java -jar regkassen-verification-depformat-1.1.1.jar -v -f -i dep-export.json -c cryptographicMaterialContainer.json -o <ordner>`; je Beleg entsteht eine Datei mit `"verificationState": "PASS"` oder einem Fehler.
- **Der Mustercode setzt bei Beträgen ab 1.000 Euro einen Tausenderpunkt** (`1.234.567,89`), weil er die deutsche Zahlenform von Java verwendet. Der Entwurf (6.3) verlangt "ohne Tausenderpunkt". Dieser Plan bleibt beim Entwurf (K2) und lässt das Prüfwerkzeug über einen Bon mit 1.234,56 Euro laufen (Task 7).
- **Wortlaut der RKSV:** `www.ris.bka.gv.at` ist weiter nicht erreichbar (18.11.2026, 17:40). Die Annahmen dazu stehen unter "Am Wortlaut zu prüfen" und kommen in Abschnitt 11.2 des Entwurfs.

## Entscheidungen in diesem Plan (Claude)

| Nr. | Entscheidung | Warum | Preis |
|---|---|---|---|
| K1 | Signiert wird **innerhalb** der Datenbank-Transaktion des Bons. | drift lässt immer nur eine Transaktion zugleich laufen: Reihenfolge der Kette ohne eigenes Schloss, und ein Absturz hinterlässt nichts. | Während des Signierens wartet jeder andere Zugriff auf die Datenbank (Probe: Millisekunden; Karte in S2: bis zur Frist). S2 misst das neu. |
| K2 | Beträge im Code ohne Tausenderpunkt. | Entwurf 6.3. | Weicht bei Bons ab 1.000 Euro vom Mustercode ab; das Prüfwerkzeug entscheidet (Task 7). |
| K3 | Der Umsatzzähler hat 8 Bytes. | Entwurf 6.3; der Mustercode erlaubt 5 bis 8. | Keiner. |
| K4 | Probe und Attrappe tragen das Kennzeichen `R1-AT100` (im Mustercode der gedachte Aussteller für Vorführungen), Seriennummer in Kleinbuchstaben hexadezimal. | Ein Probe-Bon soll nie wie ein Bon mit A-Trust-Karte aussehen. | BMF Belegcheck lehnt Probe-Bons ab. Das ist gewollt. |
| K5 | Jede Kette hat eigene Kassen-Kennung und eigenen AES-Schlüssel. "Probe beenden" schließt die Kette mit einem Schlussbeleg; neu einschalten beginnt eine neue. | Kassen-Kennung plus Belegnummer dürfen sich mit demselben Schlüssel nie wiederholen. | Mehrere Probe-Ketten in der Datenbank. |
| K6 | Sonderbelege haben keine Zahlung und keinen Tag: `Receipt.payment` und `Receipt.businessDayId` werden leerbar. | Entwurf 6.4; keine erfundenen Zahlungen in einer unveränderlichen Tabelle. | Alle Stellen, die `payment` lesen, müssen den leeren Fall behandeln (Task 4). |
| K7 | Ein Bon lässt sich nur stornieren, solange er zur laufenden Kette gehört (oder die Signatur aus ist). | Entwurf 6.1: Sonst sinkt der Zähler ohne signierten Verkauf. | Bons von vor dem Einschalten der Probe sind danach nicht mehr stornierbar. |
| K8 | Monats- und Jahresbeleg entstehen vor dem ersten Bon in einem neuen Monat und tragen dessen Zeit. Liegen mehrere Monate ohne Bon dazwischen, entsteht einer. Wechselt dabei das Jahr, ist es ein Jahresbeleg. | Einfachste Regel, die nie einen Beleg ohne angemeldeten Menschen braucht (Entwurf 6.4). | Am Wortlaut zu prüfen. |
| K9 | Scheitert im Zustand Probe etwas Unerwartetes im Signatur-Schritt (zum Beispiel ist der AES-Schlüssel nicht lesbar), wird der Bon trotzdem gespeichert und die Probe schaltet sich mit einem Hinweis ab. | Anti-Ziel: Die Kassa verkauft immer. | Die Probe-Kette endet ohne Schlussbeleg. Für "In Betrieb" entscheidet S2 neu. |
| K10 | Aufgaben ("Mit BMF Belegcheck prüfen", "Protokoll sichern" und so weiter) entstehen auch in der Probe. | Niko soll den Kern am Tablet sehen. | In der Probe sind es Übungen; die Karte "Signatur" sagt das. |
| K11 | "Protokoll ausgeben" bietet "Alles", "Dieses Vierteljahr" und "Letztes Vierteljahr". | Touch-Regel: kein Tippen von Daten. | Kein freier Zeitraum. |
| K12 | Der QR-Code wird mit dem QR-Befehl des Druckers gedruckt, mit Schalter "QR-Code als Bild drucken" in den Drucker-Einstellungen. | Entwurf 6.10. | Eine Spalte mehr in `settings`. |

## Am Wortlaut zu prüfen (Annahmen, bis das Rechtsinformationssystem erreichbar ist)

1. Ein Monatsbeleg ist ein Beleg mit Betrag 0; der letzte des Jahres ist der Jahresbeleg, wird gedruckt und bis 15. Februar mit BMF Belegcheck geprüft. Er darf vor dem ersten Bon des neuen Monats erstellt werden. Für Monate ganz ohne Betrieb braucht es keinen eigenen.
2. Ausfall: Dauert er länger als 48 Stunden, ist er bei FinanzOnline zu melden; nach dem Ende ein Sammelbeleg mit Betrag 0 als erster signierter Beleg, und das Ende ist zu melden.
3. Das Protokoll ist vierteljährlich zu sichern.
4. Bargeld einlegen und entnehmen gehört nicht ins Protokoll.

## Global Constraints

- **Die Kassa verkauft immer.** Kein Fehler der Signatur, des geschützten Speichers oder des Protokolls darf einen Verkauf oder ein Storno verhindern oder länger als die Frist verzögern (5 Sekunden, während eines Ausfalls 1 Sekunde).
- **Kette ohne Lücke und ohne Doppel.** Bon, Zahlung, Protokoll-Eintrag und Zählerstand stehen in einer Transaktion. Positionen einer Kette sind lückenlos ab 1. Ein Eintrag wird nie geändert und nie gelöscht (Trigger).
- **Geheimnisse:** AES-Schlüssel und Schlüssel der Probe-Signatur liegen nur im geschützten Speicher (`flutter_secure_storage`), nie in der Datenbank, in einem Log, in `toString`, in einer Fehlermeldung oder in der ausgegebenen Datei. Die Datei für das Prüfwerkzeug mit dem AES-Schlüssel schreibt nur der Test aus Task 7 in ein Temp-Verzeichnis, mit dem erfundenen Schlüssel der Attrappe.
- **"TESTBON" bleibt** in den Zuständen "Nicht eingerichtet" und "Probe" auf jedem Bon. In den Einstellungen steht bei der Probe: "Probe-Signatur, nicht für den echten Betrieb".
- **Vergleichswerte:** Task 1 trifft jeden Wert aus `mustercode_vectors.json`.
- **Datenbank:** Version 4 mit Migration und Test von Version 3 mit vorhandenen Bons. Die Trigger für unveränderliche Bons gelten nach der Migration weiter.
- **Öffentliches Repo:** keine echten Umsätze, keine Server-Adresse, nichts aus `/mnt/project-files/` (Ausnahme: das erfundene Test-Zertifikat, schon im Repo). Testdaten sind der erfundene "Beispiel-Imbiss".
- **Sprache:** Bezeichner englisch, Texte am Bildschirm und am Bon deutsch in der du-Form, genau wie in diesem Plan. Kein Gedankenstrich in deutschen Texten. Commit-Meldungen deutsch.
- **Touch-Regel:** kein Textfeld (`test/no_text_field_test.dart`). Neue Tasten mindestens 64 dp hoch, Hauptaktionen 76 dp, wie im Bestand.
- **Bildschirme** folgen `docs/design-regeln.md`, `DESIGN.md` und den Bildern unter `/mnt/project-files/kassa-entwurf/rksv/` (Task 0). Material-Widgets aus `package:material_ui/material_ui.dart`.
- Nur der Chef sieht und bedient die Tasten der Karte "Signatur" (`staff.isChef`), wie bei den anderen Chef-Bereichen der Einstellungen.
- Nicht anfassen: `app/lib/rksv/card/` (S1a), `PrinterChannel.kt`, `CardReaderChannel.kt`, `server/`.

## Review Focus

1. **Absturz oder Ausnahme zwischen Signieren und Speichern:** Nichts ist gespeichert, der nächste Bon setzt die Kette mit derselben Position und Nummer fort (Test in Task 5).
2. **Späte Antwort der Signatur:** Eine Antwort nach der Frist wird verworfen; der Bon trägt den Ausfall-Vermerk und es entsteht kein zweiter Eintrag (Task 6).
3. **Bon ab 1.000 Euro, negative Summen, Pfand:** Form der Beträge, Pfand zählt zu "Null", Summe der fünf Beträge ist die Summe des Bons (Task 1, 5).
4. **Uhr des Tablets springt zurück:** kein Monatsbeleg, keine Schleife; der Bon wird ganz normal eingetragen (Task 6).
5. **Geschützter Speicher nicht lesbar:** Der Verkauf läuft, die Probe schaltet sich ab (Task 5).
6. **Storno eines Bons aus einer früheren Kette** oder von vor der Probe: abgelehnt mit dem Satz aus Task 5, nichts wird geschrieben.
7. **Doppeltes Antippen:** Zwei Abschlüsse zugleich ergeben zwei Bons mit aufeinanderfolgenden Positionen (Task 5).

## Dateien im Überblick

| Datei | Aufgabe |
|---|---|
| `app/lib/rksv/core/rksv_code.dart` | Rechenkern: Beträge, Zeit, Zähler, Kettenwert, Text des Codes, JWS, QR-Text |
| `app/lib/rksv/signature_unit.dart` | Schnittstelle `SignatureUnit`, `SignerInfo`, `SignatureFailure` |
| `app/lib/rksv/probe_signature_unit.dart` | Probe-Signatur: Schlüssel erzeugen, selbst ausgestelltes Zertifikat, signieren |
| `app/lib/rksv/self_signed_certificate.dart` | baut das Zertifikat der Probe-Signatur |
| `app/lib/rksv/rksv_secrets.dart` | `RksvSecrets` (geschützter Speicher) mit Umsetzung im Speicher für Tests |
| `app/lib/rksv/rksv_state.dart` | `RksvMode`, `RksvState`, `RksvTask`, Texte der Aufgaben |
| `app/lib/data/rksv_repository.dart` | Zustand, Ketten, Zertifikate, Einträge lesen und beobachten, Aufgaben erledigen |
| `app/lib/rksv/rksv_journal.dart` | der Schritt je Bon: rechnen, signieren, Eintrag und Zähler schreiben, Aufgaben anlegen |
| `app/lib/rksv/rksv_service.dart` | Probe ein und aus, Nullbeleg, "Nochmal prüfen", Protokoll ausgeben |
| `app/lib/rksv/dep_export.dart` | Datei in der Form des Finanzministeriums |
| `app/lib/rksv/rksv_providers.dart` | Provider |
| `app/test/support/fake_signature_unit.dart` | Attrappe |

---

### Task 0: Bilder (macht der Controller, kein Unterauftrag)

Der Controller zeichnet mit `/mnt/project-files/kassa-entwurf/rksv/zeichnen.py` die neuen Ansichten und schickt sie Niko: Karte "Signatur" in den Zuständen "Nicht eingerichtet", "Probe" (mit zwei Aufgaben) und "Probe, Signatur ausgefallen"; die Rückfrage vor dem Einschalten; das Blatt "Protokoll ausgeben"; ein Bon am Bildschirm mit QR-Code; ein gedruckter Bon mit Kassen-Kennung und QR-Code; die Kassa mit dem Hinweis zum Ausfall. Tasks 9 und 10 warten auf die Bilder, nicht auf Nikos Antwort (Entwurf 6.10).

---

### Task 1: Rechenkern

**Files:**
- Create: `app/lib/rksv/core/rksv_code.dart`
- Test: `app/test/rksv/core/rksv_code_test.dart` (liest `test/rksv/fixtures/mustercode_vectors.json`)

**Interfaces (Produces):**

```dart
const String jwsHeader = 'eyJhbGciOiJFUzI1NiJ9';
const String damagedSignatureText = 'Sicherheitseinrichtung ausgefallen';
const String stornoCounterField = 'U1RP'; // base64 von "STO"

/// '12,90', '-0,25', '0,00', '1234,56'. Nie ein Tausenderpunkt, nie '-0,00'.
String formatCodeAmount(int cents);
/// Ortszeit ohne Zeitzone: '2026-11-18T13:05:09'.
String formatCodeTime(DateTime local);
/// AES-256 im Zählermodus. IV = die ersten 16 Bytes von SHA-256(UTF-8(cashBoxId + receiptId)).
/// Klartext = [counterCents] als 8 Bytes, Zweierkomplement, höchstes Byte zuerst. Ergebnis base64 mit '='.
String encryptCounter({required Uint8List aesKey, required String cashBoxId, required String receiptId, required int counterCents});
/// Umkehrung, für Tests und die Prüfung der eigenen Kette.
int decryptCounter({required Uint8List aesKey, required String cashBoxId, required String receiptId, required String field});
/// base64 der ersten 8 Bytes von SHA-256(UTF-8(input)). input = voriger Eintrag (JWS) oder, beim ersten, die Kassen-Kennung.
String chainValue(String input);

final class CodeFields {
  const CodeFields({required this.zdaId, required this.cashBoxId, required this.receiptId,
      required this.time, required this.sumsCents, required this.counterField,
      required this.certSerial, required this.chain});
  final String zdaId;        // 'AT1', 'AT100'
  final String cashBoxId;
  final String receiptId;
  final DateTime time;
  final List<int> sumsCents; // genau 5: Normal, Ermäßigt-1, Ermäßigt-2, Null, Besonders
  final String counterField; // encryptCounter(...) oder stornoCounterField
  final String certSerial;
  final String chain;
}
/// '_R1-AT1_BSPIMB01_1_2026-11-18T13:05:09_0,00_0,00_0,00_0,00_0,00_<Zähler>_<Serie>_<Kette>'
String codeText(CodeFields f);
/// '<jwsHeader>.<base64url ohne '=' von UTF-8(text)>': das, was signiert wird.
String jwsSigningInput(String text);
/// signingInput + '.' + base64url ohne '=' der 64 Bytes R|S.
String jwsCompact(String text, Uint8List signature);
/// wie jwsCompact, aber mit damagedSignatureText an der Stelle der Signatur.
String jwsDamaged(String text);
bool isDamagedJws(String jws);
/// Text des QR-Codes: Nutzlast + '_' + Signatur als base64 MIT '=' (nicht url-sicher).
String qrText(String jws);
/// DER-Signatur (SEQUENCE aus zwei INTEGER) zu 64 Bytes R|S. Für S2; hier nur Rechenkern und Test.
Uint8List derSignatureToConcat(Uint8List der);
```

`codeText` wirft `ArgumentError`, wenn `sumsCents.length != 5`, wenn `cashBoxId` oder `receiptId` ein `_` enthält oder leer ist.

- [ ] **Step 1: Tests schreiben** (alle Erwartungen aus der JSON-Datei, nicht abgetippt):
  - `encryptCounter trifft alle sieben Werte des Mustercodes` (`counters[]`, Schlüssel `aesKeyBase64`, Kennung `cashBoxId`) und `decryptCounter` kehrt jeden um.
  - `chainValue` trifft `chainFromCashBoxId` (Eingabe: Kassen-Kennung), `chainAfterJws1` (Eingabe `jws1`), `chainAfterJws2` (Eingabe `jws2Damaged`).
  - `codeText` trifft `text1` (Beleg 1, 2026-11-18 13:05:09, alles 0, Zähler 0), `text2` (Beleg 2, 13:07:41, Summen 1290/450/0/25/0, Zähler 1765), `text3Storno` (Beleg 3, 2026-12-01 00:00:00, −1290/−450/0/−25/0, Feld `stornoMarker`), `text4` (Beleg 4, 2027-01-02 09:00:00, 99999/0/5/0/−1, Zähler 100003). Seriennummer `1a2b3c`, Kennzeichen `AT1`.
  - `jwsCompact(text1, fakeSignature)` ist `jws1`; `qrText(jws1)` ist `qr1`; `jwsDamaged(text2)` ist `jws2Damaged`; `qrText(jws2Damaged)` ist `qr2Damaged`; `isDamagedJws` ist für `jws2Damaged` wahr und für `jws1` falsch.
  - `derSignatureToConcat(derSignatureHex)` ist `concatSignatureBase64`; eine DER-Signatur mit kurzem R (31 Bytes) wird links mit 0 aufgefüllt; Müll wirft `FormatException`.
  - `formatCodeAmount`: 0 → `0,00`; 5 → `0,05`; −1 → `-0,01`; 123456 → `1234,56`; −129000 → `-1290,00`.
  - `codeText` wirft bei vier Summen und bei `_` in der Kassen-Kennung.
- [ ] **Step 2:** `flutter test test/rksv/core/rksv_code_test.dart` schlägt fehl (Datei fehlt).
- [ ] **Step 3: Umsetzen.** AES über `pointycastle` (Zählermodus `CTRStreamCipher(AESEngine())`, oder ein AES-Block über den IV und XOR; beide ergeben dasselbe). Kein Flutter-Import in dieser Datei.
- [ ] **Step 4:** Tests bestehen, `flutter analyze` ohne Meldung.
- [ ] **Step 5: Commit** `RKSV-Rechenkern: Zähler, Kette, Code, JWS gegen den Mustercode`.

---

### Task 2: Signatur-Schnittstelle, Attrappe, Probe-Signatur

**Files:**
- Create: `app/lib/rksv/signature_unit.dart`, `app/lib/rksv/self_signed_certificate.dart`, `app/lib/rksv/probe_signature_unit.dart`, `app/lib/rksv/rksv_secrets.dart`, `app/test/support/fake_signature_unit.dart`
- Test: `app/test/rksv/probe_signature_unit_test.dart`, `app/test/rksv/self_signed_certificate_test.dart`, `app/test/rksv/fake_signature_unit_test.dart`

**Interfaces:**
- Consumes: `jwsSigningInput` (Task 1); `CardCertificate.parse` aus `app/lib/rksv/card/certificate.dart` (S1a, nur lesen) zum Prüfen im Test; Test-Zertifikat und Schlüssel aus `app/test/rksv/fixtures/test_card.dart`.
- Produces:

```dart
final class SignerInfo {
  const SignerInfo({required this.zdaId, required this.serialHex, required this.certificateDer,
      this.issuerCertificatesDer = const []});
  final String zdaId;      // 'AT100' für Probe und Attrappe
  final String serialHex;  // Kleinbuchstaben, ohne führende Nullen
  final Uint8List certificateDer;
  final List<Uint8List> issuerCertificatesDer;
}
final class SignatureFailure implements Exception {
  const SignatureFailure(this.reason);
  final String reason; // deutscher Satz ohne Geheimnisse
}
abstract interface class SignatureUnit {
  Future<SignerInfo> info();
  /// ECDSA P-256 über SHA-256 der ASCII-Bytes von [signingInput]. Ergebnis: 64 Bytes R|S.
  /// Wirft [SignatureFailure].
  Future<Uint8List> sign(String signingInput);
}

abstract interface class RksvSecrets {
  Future<Uint8List?> aesKey(int chain);
  Future<void> writeAesKey(int chain, Uint8List key);      // 32 Bytes
  Future<Uint8List?> probeKey(int chain);                   // privater Schlüssel, 32 Bytes
  Future<void> writeProbeKey(int chain, Uint8List key);
}
class SecureRksvSecrets implements RksvSecrets { … }  // Schlüsselnamen 'rksv_aes_<chain>', 'rksv_probe_key_<chain>', Werte base64
class MemoryRksvSecrets implements RksvSecrets { … }  // für Tests, mit `bool failReads`

/// Selbst ausgestelltes X.509-Zertifikat (Version 3, ecdsa-with-SHA256, Kurve P-256).
/// Inhaber und Aussteller: CN=<commonName>. Gültig von [from] zehn Jahre.
Uint8List buildSelfSignedCertificate({required ECPrivateKey key, required ECPublicKey publicKey,
    required BigInt serial, required String commonName, required DateTime from});

class ProbeSignatureUnit implements SignatureUnit {
  ProbeSignatureUnit({required Uint8List privateKey, required Uint8List certificateDer});
  /// Neuer Schlüssel aus `Random.secure()` und Zertifikat mit CN "Kassa Probe-Signatur <cashBoxId>",
  /// Seriennummer = 8 zufällige Bytes (positiv).
  static ({Uint8List privateKey, Uint8List certificateDer, String serialHex}) create(
      {required String cashBoxId, required DateTime now, Random? random});
}

// test/support
class FakeSignatureUnit implements SignatureUnit {
  FakeSignatureUnit(); // Schlüssel und Zertifikat aus test_card.dart, zdaId 'AT100'
  FakeMode mode = FakeMode.ok;       // ok, error, silent
  int signCalls = 0;
  /// Bei silent: sign() kehrt nie zurück, bis [release] gerufen wird (dann mit gültiger Signatur).
  void release();
}
```

`ProbeSignatureUnit.sign` und `FakeSignatureUnit.sign` verwenden den deterministischen Signierer (`ECDSASigner(null, HMac(SHA256Digest(), 64))`, wie in `test_card.dart`), damit Tests feste Werte haben.

- [ ] **Step 1: Tests schreiben:**
  - `das selbst ausgestellte Zertifikat lässt sich lesen`: `CardCertificate.parse` liefert Seriennummer, Inhaber `Kassa Probe-Signatur BSPIMB01`, gültig bis zehn Jahre nach `from`, und den öffentlichen Schlüssel des Paars.
  - `das Zertifikat ist mit seinem eigenen Schlüssel gültig signiert` (Signatur über den TBS-Teil mit `ECDSASigner` prüfen).
  - `ProbeSignatureUnit.sign: 64 Bytes, gültig gegen das Zertifikat, zweimal gleicher Text ergibt dieselbe Signatur`.
  - `ProbeSignatureUnit.create: zwei Aufrufe ergeben verschiedene Schlüssel und Seriennummern; info() nennt AT100 und die Seriennummer in Kleinbuchstaben`.
  - `FakeSignatureUnit: ok signiert gültig, error wirft SignatureFailure, silent antwortet erst nach release()`.
  - `MemoryRksvSecrets: lesen nach schreiben; failReads wirft`; `SecureRksvSecrets` mit `FlutterSecureStorage.setMockInitialValues`.
  - `toString von ProbeSignatureUnit und SignatureFailure enthält keinen Schlüssel`.
- [ ] **Step 2:** Tests schlagen fehl. **Step 3:** Umsetzen. **Step 4:** Tests und `flutter analyze`.
- [ ] **Step 5: Commit** `Signatur-Schnittstelle mit Attrappe und Probe-Signatur`.

---

### Task 3: Datenbank Version 4 und Zustand

**Files:**
- Modify: `app/lib/data/database.dart` (Tabellen, `schemaVersion => 4`, Migration), `app/lib/data/database.g.dart` (erzeugt), `app/lib/data/settings_repository.dart` (`printerQrAsImage`), `app/lib/data/providers.dart`
- Create: `app/lib/rksv/rksv_state.dart`, `app/lib/data/rksv_repository.dart`, `app/drift_schemas/drift_schema_v4.json`, `app/test/data/generated_migrations/schema_v4.dart`, `app/test/data/fixtures/kassa_v3.sqlite`
- Test: `app/test/data/migration_test.dart` (erweitern), `app/test/data/rksv_repository_test.dart`

**Schema (Version 4):**

- `receipts.business_day_id` wird leerbar. Dafür die Tabelle mit `m.alterTable(TableMigration(receiptRows))` neu aufbauen: vorher die Trigger `receipts_no_update` und `receipts_no_delete` entfernen, danach neu anlegen, und den Index `receipts_voids_receipt_id` neu anlegen. Fremdschlüssel sind während der Migration aus (`PRAGMA foreign_keys = OFF` vor, `ON` nach der Migration; siehe drift-Dokumentation zu `alterTable`), danach `PRAGMA foreign_key_check` ohne Treffer.
- `receipts.kind` kennt zusätzlich `start`, `month`, `year`, `zero`, `collective`, `closing` (Text, keine Änderung der Spalte).
- `settings.printer_qr_as_image` BOOLEAN, Standard falsch.
- Neue Tabelle `rksv_chains`: `chain` INTEGER Primärschlüssel, `mode` TEXT (`probe` oder `live`), `cash_box_id` TEXT, `zda_id` TEXT, `started_at` DATETIME, `ended_at` DATETIME leerbar. Trigger: kein DELETE; UPDATE nur, solange `OLD.ended_at IS NULL`.
- Neue Tabelle `rksv_certificates`: `serial_hex` TEXT Primärschlüssel, `certificate` BLOB, `issuers` TEXT (JSON-Liste aus base64, Standard `[]`). Trigger: kein UPDATE, kein DELETE.
- Neue Tabelle `rksv_entries`: `chain` INTEGER verweist auf `rksv_chains`, `position` INTEGER, `receipt_id` TEXT eindeutig, verweist auf `receipts`, `jws` TEXT, `damaged` BOOLEAN, `cert_serial` TEXT; Primärschlüssel (`chain`, `position`). Trigger: kein UPDATE, kein DELETE, Meldung `Das Protokoll ist unveränderlich`.
- Neue Tabelle `rksv_state`, genau eine Zeile (`id` = 1): `mode` TEXT Standard `off` (`off`, `probe`, `live`), `chain` INTEGER leerbar, `counter_cents` INTEGER Standard 0, `outage_since` DATETIME leerbar, `outage_reason` TEXT leerbar, `tasks` TEXT Standard `[]`, `notice` TEXT leerbar. Die Zeile entsteht in `onCreate` und in der Migration.

Der letzte Monat mit Monatsbeleg steht nicht in `rksv_state`: Er ergibt sich aus dem letzten Eintrag der Kette (Abweichung von Entwurf 6.6, in 11.2 festhalten).

**Interfaces (Produces):**

```dart
// rksv_state.dart
enum RksvMode { off, probe, live }
enum RksvTaskKind { checkStart, checkYear, reportOutage, reportOutageEnd, backupProtocol }
final class RksvTask {
  const RksvTask({required this.id, required this.kind, required this.createdAt, this.detail = ''});
  final String id; final RksvTaskKind kind; final DateTime createdAt; final String detail;
  Map<String, Object?> toJson(); static RksvTask fromJson(Map<String, Object?> j);
}
/// Der Satz der Aufgabe am Bildschirm.
String rksvTaskText(RksvTask t);
final class RksvState {
  final RksvMode mode; final int? chain; final String? cashBoxId; final int counterCents;
  final DateTime? outageSince; final String? outageReason; final List<RksvTask> tasks; final String? notice;
  bool get outage => outageSince != null;
}

// rksv_repository.dart
class RksvRepository {
  RksvRepository(KassaDatabase db);
  Future<RksvState> current();
  Stream<RksvState> watch();
  Future<void> completeTask(String id);   // entfernt die Aufgabe; unbekannte Id: nichts
  Future<void> clearNotice();
}
final rksvRepositoryProvider, rksvStateProvider (StreamProvider<RksvState>)  // in providers.dart
```

Texte der Aufgaben (`detail` in Klammern beschrieben):

| Art | Text |
|---|---|
| `checkStart` | `Startbeleg mit der App "BMF Belegcheck" prüfen.` |
| `checkYear` | `Jahresbeleg <detail> mit der App "BMF Belegcheck" prüfen, bis 15. Februar.` (detail = das abgeschlossene Jahr) |
| `reportOutage` | `Ausfall der Signatur bei FinanzOnline melden. Beginn: <detail>.` (detail = `18.11.2026 13:05`) |
| `reportOutageEnd` | `Ende des Ausfalls bei FinanzOnline melden. Ende: <detail>.` |
| `backupProtocol` | `Protokoll sichern: "Protokoll ausgeben" und die Datei aufheben.` |

- [ ] **Step 1: Fixture.** Mit dem Stand vor diesem Task eine Datei `kassa_v3.sqlite` erzeugen (wie `kassa_v2.sqlite` entstanden ist: kleines Test-Skript, das eine Datenbank der Version 3 mit einem Tag, zwei Bons samt Zeilen, Optionen und Zahlungen und einem Storno füllt). Schema der Version 3 liegt schon als `drift_schema_v3.json` vor.
- [ ] **Step 2: Tests schreiben:**
  - `Schema: Version 3 wird zu Version 4` (`SchemaVerifier`, wie die vorhandenen).
  - `echte Datei von Version 3: Bons, Zeilen, Zahlungen und Storno bleiben; UPDATE und DELETE auf receipts scheitern weiter; ein Bon ohne Tag lässt sich einfügen; rksv_state hat genau eine Zeile mit mode off`.
  - `rksv_entries: UPDATE und DELETE scheitern`; `rksv_chains: UPDATE nach ended_at scheitert, DELETE scheitert`.
  - `RksvRepository`: frischer Stand ist `off` ohne Aufgaben; `completeTask` entfernt genau eine; `watch` meldet die Änderung; kaputtes JSON in `tasks` ergibt eine leere Liste statt einer Ausnahme.
  - `rksvTaskText` für alle fünf Arten.
- [ ] **Step 3:** Tests schlagen fehl. **Step 4:** Tabellen, Migration, `dart run build_runner build`, `dart run drift_dev schema dump lib/data/database.dart drift_schemas/` und `dart run drift_dev schema generate drift_schemas/ test/data/generated_migrations/` (genaue Aufrufe: so, wie Version 3 entstanden ist; im Bericht nennen).
- [ ] **Step 5:** Ganze Suite einmal, `flutter analyze`. **Commit** `Datenbank Version 4: Protokoll, Ketten, Signatur-Stand, Bons ohne Tag`.

---

### Task 4: Arten der Bons, Bons ohne Zahlung und ohne Tag

**Files:**
- Modify: `app/lib/domain/receipt.dart`, `app/lib/data/receipt_repository.dart` (nur Lesen/`_hydrate`, `watchDay`), `app/lib/data/stats_repository.dart`, `app/lib/data/day_repository.dart`, `app/lib/features/bons/receipt_list.dart`, `receipt_detail.dart`, `void_question.dart`, `app/lib/features/kassa/sale_service.dart`, `sale_done.dart`, `app/lib/domain/receipt_layout.dart`, `app/lib/devices/printer.dart`
- Test: die vorhandenen Tests dieser Dateien, erweitert

**Interfaces (Produces):**

```dart
enum ReceiptKind { sale, voided, start, month, year, zero, collective, closing }
extension ReceiptKindX on ReceiptKind {
  bool get isSpecial;          // start … closing
  String? get specialTitle;    // 'Startbeleg', 'Monatsbeleg', 'Jahresbeleg', 'Nullbeleg', 'Sammelbeleg', 'Schlussbeleg'; sonst null
}
final class RksvStamp {
  const RksvStamp({required this.cashBoxId, required this.qrText, required this.damaged, required this.probe});
  final String cashBoxId; final String qrText; final bool damaged; final bool probe;
}
class Receipt {
  final String? businessDayId;   // leer bei Sonderbelegen
  final Payment? payment;        // leer bei Sonderbelegen
  final RksvStamp? rksv;         // leer, wenn der Bon keinen Protokoll-Eintrag hat
  …
}
```

`_hydrate` füllt `rksv` aus `rksv_entries` und `rksv_chains` (`qrText(jws)` aus Task 1, `probe` = `mode == 'probe'`).

Regeln:
- `watchDay(dayId)` liefert die Bons des Tages **und** die Sonderbelege, deren `createdAt` zwischen `openedAt` dieses Tages und `openedAt` des nächsten Tages liegt (für den ersten Tag auch alle davor, für den neuesten Tag alle danach). Reihenfolge nach Nummer.
- Übersicht, Abschluss und Statistik zählen nur `sale` und `voided`.
- Liste der Bons: Ein Sonderbeleg zeigt seine Bezeichnung (`specialTitle`) statt "Bar"/"Karte" und den Betrag `0,00 €`; er ist in keinem der Filter "Bar", "Karte", "Storno", nur in "Alle". Er lässt sich nicht stornieren und nicht als Bar-Bon "nachdrucken mit Lade öffnen".
- Bon-Ansicht und Druck eines Sonderbelegs: Bezeichnung in Großbuchstaben an der Stelle von "STORNO", keine Zeilen, `SUMME EUR 0,00`, kein Zahlungs-Block. (QR-Code und Kassen-Kennung folgen in Task 8.)

- [ ] **Step 1: Tests schreiben:** `_hydrate` liest einen Bon ohne Tag und ohne Zahlung; `watchDay` ordnet Sonderbelege wie beschrieben zu (drei Tage, Sonderbelege davor, dazwischen, danach); Statistik und Tagessummen ändern sich durch einen Sonderbeleg nicht; `layoutReceipt` eines Startbelegs (genaue Zeilen: Kopf, `STARTBELEG`, Bon-Kopf, Linie, `SUMME EUR 0,00`, kein `Bar`); Liste zeigt "Monatsbeleg" und keinen Storno-Knopf in der Ansicht.
- [ ] **Step 2:** Tests schlagen fehl. **Step 3:** Umsetzen; der Compiler zeigt jede Stelle, die `payment` oder `businessDayId` liest. Keine neue Logik zum Erzeugen von Sonderbelegen in diesem Task (Tests fügen sie direkt in die Datenbank ein).
- [ ] **Step 4:** Ganze Suite, `flutter analyze`. Vergleichsbilder dürfen sich nicht ändern. **Commit** `Sonderbelege als Art von Bon: ohne Zahlung, ohne Tag`.

---

### Task 5: Der Schritt je Bon: Journal, Probe ein und aus

**Files:**
- Create: `app/lib/rksv/rksv_journal.dart`, `app/lib/rksv/rksv_service.dart`, `app/lib/rksv/rksv_providers.dart`, `app/test/support/rksv_rig.dart` (Aufbau für Tests: Datenbank im Speicher, feste Uhr, `MemoryRksvSecrets`, `FakeSignatureUnit`, und `verifyChain`)
- Modify: `app/lib/data/receipt_repository.dart` (`_write`, `voidReceipt`, neu `createSpecial`), `app/lib/data/providers.dart`
- Test: `app/test/rksv/rksv_journal_test.dart`, `app/test/rksv/rksv_service_test.dart`

**Interfaces:**
- Consumes: Task 1 bis 4.
- Produces:

```dart
/// Liefert die Signatur-Einheit einer Kette; in der App: Probe-Signatur aus RksvSecrets und rksv_certificates.
typedef SignatureUnitOf = Future<SignatureUnit> Function(int chain);

class RksvJournal {
  RksvJournal(KassaDatabase db, RksvSecrets secrets, SignatureUnitOf unitOf, Clock clock);
  static const signLimit = Duration(seconds: 5);
  static const signLimitDuringOutage = Duration(seconds: 1);

  /// Läuft in der Transaktion des Bons, nachdem seine Zeilen stehen. Tut nichts bei mode off.
  /// [mustSign]: kein Ausfall-Eintrag, sondern SignatureFailure (für Sammelbeleg und Startbeleg).
  Future<void> record({required String receiptId, required int number, required DateTime createdAt,
      required ReceiptKind kind, required List<int> sumsCents, bool mustSign = false});
  /// Welcher Beleg vor einem Verkauf oder Storno fällig ist: collective (bei Ausfall), sonst year, month, oder null.
  /// In Task 5 liefert sie immer null; die Regeln kommen in Task 6.
  Future<ReceiptKind?> dueBefore(DateTime now);
  /// Prüft die laufende Kette gegen sich selbst (Kettenwerte, Zähler, Positionen). Für Tests und "Protokoll ausgeben".
  Future<bool> chainIsSound(int chain);
}

class RksvService {
  /// Neue Kette: Kassen-Kennung, AES-Schlüssel, Probe-Schlüssel und Zertifikat erzeugen, Startbeleg signieren.
  /// Wirft RksvProblem, wenn der geschützte Speicher nicht schreibt oder die Signatur scheitert; dann bleibt alles wie vorher.
  Future<Receipt> enableProbe({required Staff staff});
  /// Schlussbeleg, Kette beenden, mode off.
  Future<Receipt> disableProbe({required Staff staff});
}
final class RksvProblem implements Exception { final String message; }

// ReceiptRepository
ReceiptRepository(KassaDatabase db, Clock clock, DayRepository days, {RksvJournal? journal});
/// start, zero, closing (vom Chef ausgelöst) und month, year, collective (von selbst).
Future<Receipt> createSpecial(ReceiptKind kind, {required Staff staff, bool mustSign = false});
class NotInCurrentChainException implements Exception {}   // von voidReceipt
```

**Ablauf in `_write` für `sale` und `voided`, wenn ein Journal da ist und `mode != off`:**

1. `dueBefore(now)`: Ist etwas fällig, zuerst diesen Sonderbeleg schreiben. `collective` in einer eigenen inneren Transaktion mit `mustSign: true`; scheitert die Signatur, wird nur der Sammelbeleg zurückgerollt und der Ausfall dauert an. `month`/`year` ohne `mustSign`.
2. Bon, Zeilen, Zahlung einfügen (wie bisher).
3. `journal.record(...)` mit `sumsCents` = Summen der Zeilen je Satz in der Reihenfolge Normal (20), Ermäßigt-1 (10), Ermäßigt-2 (13), Null (0), Besonders (19); `depositCents` des Bons zählt zu Null. Stimmt die Summe der fünf nicht mit `totalCents` überein: `StateError` (Programmfehler, Test).

**`record` im Einzelnen:**

1. Zustand lesen. Kette, Kassen-Kennung, Zählerstand, letzter Eintrag (JWS) der Kette.
2. Neuer Zähler = alter Zähler + Summe der fünf Beträge (bei Storno negativ). Feld: `stornoCounterField` bei `voided`, sonst `encryptCounter` mit `receiptId` = Nummer des Bons als Dezimalzahl.
3. Kettenwert aus dem letzten Eintrag, beim ersten Eintrag der Kette aus der Kassen-Kennung.
4. `info()` der Einheit (Kennzeichen, Seriennummer), `codeText`, `sign(jwsSigningInput(text)).timeout(Frist)`; Frist = `signLimitDuringOutage`, wenn ein Ausfall läuft, sonst `signLimit`.
5. Bei `SignatureFailure` oder Fristablauf: mit `mustSign` weiterwerfen; sonst Eintrag mit `jwsDamaged(text)`, `damaged = true`, und `outage_since`/`outage_reason` setzen, falls leer (Grund: `Die Signatur hat nicht geantwortet.` oder `Die Signatur hat einen Fehler gemeldet.`). Eine Antwort nach der Frist wird verworfen.
6. Eintrag schreiben (`position` = letzte + 1), Zähler schreiben. Bei `collective`: `outage_since` und `outage_reason` leeren.
7. Aufgaben (Task 6 ergänzt diesen Schritt).

**Unerwarteter Fehler in `record`** (alles außer `SignatureFailure` mit `mustSign`), nur bei `mode == probe` (K9): `_write` fängt ihn, rollt den Journal-Teil zurück (innere Transaktion um `record`), setzt `mode = off`, `chain = null`, `ended_at` der Kette und `notice = 'Die Probe-Signatur wurde beendet, weil sie nicht mehr arbeiten konnte. Der Verkauf läuft normal weiter.'`. Der Bon bleibt gespeichert, ohne Eintrag.

**Storno (K7):** `voidReceipt` wirft `NotInCurrentChainException`, wenn `mode != off` und der Bon keinen Eintrag in der laufenden Kette hat. Satz für die Oberfläche (Task 10): bei Probe `Dieser Bon ist älter als die Probe-Signatur und kann nicht storniert werden.`, bei `live` (S2) `Dieser Bon stammt aus der Testzeit und kann nicht storniert werden.`

**`enableProbe`:** Kassen-Kennung = 10 Zeichen aus `ABCDEFGHJKLMNPQRSTUVWXYZ23456789` (`Random.secure()`); AES-Schlüssel 32 zufällige Bytes; `ProbeSignatureUnit.create`; beides in `RksvSecrets` schreiben und zurücklesen (stimmt es nicht: `RksvProblem('Das Tablet konnte den Schlüssel nicht sicher speichern.')`); dann in einer Transaktion: Zeile in `rksv_chains` (nächste Nummer, `probe`, `AT100`), Zertifikat in `rksv_certificates`, `rksv_state` (`probe`, Kette, Zähler 0), `createSpecial(start, mustSign: true)`.

**`verifyChain` im Test-Aufbau** (`rksv_rig.dart`), unabhängig vom Journal geschrieben: liest alle Einträge einer Kette, prüft Positionen 1..n, jeden Kettenwert, jede Signatur gegen das Zertifikat (oder den Ausfall-Text), entschlüsselt jeden Zähler und vergleicht mit der laufenden Summe der Beträge aus dem Code, und dass `rksv_state.counter_cents` der letzte Stand ist.

- [ ] **Step 1: Tests schreiben:**
  - `mode off: Verkauf wie bisher, kein Eintrag`.
  - `enableProbe: Startbeleg mit Betrag 0, Position 1, Kettenwert aus der Kassen-Kennung, Zähler 0; Zustand probe`.
  - `drei Verkäufe (20 %, 10 % mit Pfand, Karte) und ein Storno: verifyChain besteht; Pfand steht im Betrag Null; das Storno trägt U1RP und senkt den Zähler`.
  - `Bon über 1.234,56 Euro: Betrag im Code ohne Punkt, verifyChain besteht`.
  - `Review Focus 1: wirft das Einfügen des Eintrags, ist weder Bon noch Eintrag gespeichert; der nächste Verkauf bekommt dieselbe Nummer und Position`.
  - `Review Focus 5: failReads im Speicher: der Verkauf gelingt, mode ist off, notice gesetzt, kein Eintrag für diesen Bon`.
  - `Review Focus 6: Storno eines Bons von vor enableProbe wirft NotInCurrentChainException, nichts geschrieben`; ebenso ein Bon aus einer beendeten Kette.
  - `Review Focus 7: zwei finalizeCashSale zugleich (Future.wait) ergeben Positionen n und n+1`.
  - `gleiche saleId zweimal: ein Bon, ein Eintrag`.
  - `disableProbe: Schlussbeleg als letzter Eintrag, ended_at gesetzt, mode off; danach enableProbe: neue Kette mit neuer Kassen-Kennung, Position 1`.
  - `enableProbe mit Speicher, der nicht schreibt: RksvProblem, Zustand unverändert off, keine Kette`.
  - `Summen ungleich totalCents: StateError`.
- [ ] **Step 2:** Tests schlagen fehl. **Step 3:** Umsetzen. **Step 4:** Ganze Suite, `flutter analyze`.
- [ ] **Step 5: Commit** `Jeder Bon wird signiert, verkettet und ins Protokoll geschrieben (Probe)`.

---

### Task 6: Sonderbelege von selbst, Ausfall, Aufgaben

**Files:**
- Modify: `app/lib/rksv/rksv_journal.dart`, `app/lib/rksv/rksv_service.dart`
- Test: `app/test/rksv/rksv_special_test.dart`, `app/test/rksv/rksv_outage_test.dart`

**Interfaces (Produces):**

```dart
// RksvService
Future<Receipt> zeroReceipt({required Staff staff});          // Nullbeleg; bei mode off: RksvProblem
/// "Nochmal prüfen": versucht den Sammelbeleg. true, wenn die Signatur wieder geht.
Future<bool> retrySignature({required Staff staff});
```

**Regeln:**

- `dueBefore(now)`: läuft ein Ausfall → `collective`. Sonst sei `last` die Zeit des letzten Eintrags der Kette: `now.year > last.year` → `year`; sonst `now.month > last.month` im selben Jahr → `month`; sonst nichts. Liegt `now` vor `last` (Uhr zurückgestellt): nichts.
- Monats- und Jahresbeleg entstehen ohne Druck des Monatsbelegs; der Jahresbeleg wird gedruckt (das Drucken löst `sale_service` aus, Task 10; hier nur das Erzeugen).
- Während eines Ausfalls: Jeder Verkauf versucht zuerst den Sammelbeleg (Frist 1 Sekunde). Gelingt er, ist der Ausfall zu Ende und der Verkauf wird normal signiert (Frist 5 Sekunden). Gelingt er nicht, bekommt der Verkauf den Ausfall-Eintrag **ohne** zweiten Signaturversuch.
- Aufgaben, jeweils nur, wenn es die Id noch nicht gibt:
  - Startbeleg geschrieben → `checkStart`, Id `check-start-<chain>`.
  - Jahresbeleg geschrieben → `checkYear`, Id `check-year-<Jahr>`, detail = `last.year`.
  - Eintrag geschrieben und der Ausfall dauert länger als 48 Stunden → `reportOutage`, Id `report-outage-<chain>-<position des ersten Ausfall-Eintrags>`, detail = Beginn als `TT.MM.JJJJ HH:MM`.
  - Sammelbeleg geschrieben und der Ausfall hat länger als 48 Stunden gedauert → `reportOutageEnd`, Id `report-outage-end-<chain>-<position des Sammelbelegs>`, detail = Zeit des Sammelbelegs.
  - Erster Eintrag in einem neuen Kalender-Vierteljahr, wenn die Kette schon Einträge aus einem früheren hat → `backupProtocol`, Id `backup-<Jahr>-Q<n>`.

- [ ] **Step 1: Tests schreiben:**
  - `Monatswechsel: vor dem ersten Verkauf im Dezember steht ein Monatsbeleg mit Betrag 0; ein zweiter Verkauf im Dezember erzeugt keinen weiteren`.
  - `Jahreswechsel: Jahresbeleg statt Monatsbeleg, Aufgabe checkYear mit dem alten Jahr`.
  - `drei Monate Pause: genau ein Monatsbeleg`.
  - `Review Focus 4: Uhr zurück in den Vormonat: kein Sonderbeleg, Verkauf eingetragen, verifyChain besteht`.
  - `Ausfall: FakeMode.error → Bon gespeichert, Eintrag damaged, Ausfall seit jetzt, Grund gesetzt; Kette besteht`.
  - `Review Focus 2: FakeMode.silent → nach 5 Sekunden (fake_async) Ausfall-Eintrag; release() danach ändert nichts; signCalls == 1`.
  - `im Ausfall: nächster Verkauf wartet höchstens 1 Sekunde, kein zweiter Signaturversuch (signCalls steigt um 1)`.
  - `Signatur wieder da: vor dem nächsten Verkauf steht der Sammelbeleg, signiert, danach der Verkauf signiert; Ausfall beendet`.
  - `retrySignature: true und Sammelbeleg, wenn sie geht; false und nichts geschrieben, wenn nicht; false ohne Ausfall`.
  - `Ausfall länger als 48 Stunden: Aufgabe reportOutage mit dem Beginn; nach dem Sammelbeleg reportOutageEnd; ein kurzer Ausfall erzeugt keine`.
  - `Vierteljahr: erster Eintrag im Jänner nach Einträgen im Dezember → backupProtocol; kein zweites Mal im selben Vierteljahr`.
  - `zeroReceipt: Eintrag mit Betrag 0, Zähler unverändert; bei mode off RksvProblem`.
  - `Storno während eines Ausfalls: U1RP, damaged, Zähler gesenkt`.
- [ ] **Step 2:** Tests schlagen fehl. **Step 3:** Umsetzen. **Step 4:** Ganze Suite, `flutter analyze`.
- [ ] **Step 5: Commit** `Monats-, Jahres- und Sammelbeleg, Ausfall der Signatur, Aufgaben`.

---

### Task 7: Protokoll ausgeben und Lauf des Prüfwerkzeugs

**Files:**
- Create: `app/lib/rksv/dep_export.dart`, `app/test/rksv/dep_export_test.dart`, `app/test/rksv/pruefwerkzeug_test.dart`, `tool/rksv/pruefen.sh`
- Modify: `app/lib/rksv/rksv_service.dart`, `app/lib/rksv/rksv_providers.dart`

**Interfaces (Produces):**

```dart
enum ExportRange { all, thisQuarter, lastQuarter }
/// JSON in der Form des Finanzministeriums:
/// {"Belege-Gruppe":[{"Signaturzertifikat":"<base64 DER>","Zertifizierungsstellen":["<base64>",…],"Belege-kompakt":["<jws>",…]}]}
/// Eine Gruppe je zusammenhängender Folge von Einträgen mit derselben Seriennummer, Einträge in Reihenfolge.
Future<String> buildDepExport(KassaDatabase db, {required int chain, DateTime? from, DateTime? until});
/// 'kassa-protokoll-PROBE-<Kennung>-<JJJJMMTT>.json' bei Probe, sonst ohne 'PROBE-'.
String depFileName({required String cashBoxId, required bool probe, required DateTime now});

abstract interface class ProtocolSaver { Future<bool> save(String fileName, Uint8List bytes); } // false: abgebrochen
class FilePickerProtocolSaver implements ProtocolSaver { … }  // FilePicker.saveFile(fileName:, bytes:)

// RksvService
/// Welche Kette: die laufende, sonst die zuletzt beendete; gibt es keine: RksvProblem.
Future<ExportOutcome> exportProtocol(ExportRange range, {required DateTime now});
enum ExportOutcome { saved, cancelled, empty }   // empty: kein Eintrag im Zeitraum
```

- [ ] **Step 1: Tests schreiben:** Form der Datei für eine Kette mit Start, zwei Verkäufen, Ausfall-Eintrag (ein Ausfall-Eintrag bleibt in der Gruppe seines Zertifikats); `lastQuarter` enthält nur die Einträge des Vierteljahres; `empty`, wenn keiner; `cancelled`, wenn der Speichern-Dialog abgebrochen wird; Dateiname; die Datei enthält weder den AES-Schlüssel noch den Probe-Schlüssel (base64 beider gesucht).
- [ ] **Step 2: `pruefwerkzeug_test.dart`:** übersprungen, wenn die Umgebungsvariable `KASSA_RKSV_TOOL` fehlt (`skip:` mit dem Satz `Prüfwerkzeug nicht da: KASSA_RKSV_TOOL zeigt auf keinen Ordner.`). Sonst: mit `rksv_rig.dart` und der Attrappe ein Protokoll erzeugen (Startbeleg; Verkäufe mit 20 %, 10 %, 13 %, 0 %, 19 % und Pfand; ein Verkauf über 1.234,56 Euro; Storno; zwei Bons im Ausfall, dann Sammelbeleg; Monatswechsel; Jahreswechsel; Nullbeleg; Schlussbeleg), `dep-export.json` und `cryptographicMaterialContainer.json` (`{"base64AESKey": …, "certificateOrPublicKeyMap": {"<serialHex>": {"id": "<serialHex>", "signatureDeviceType": "CERTIFICATE", "signatureCertificateOrPublicKey": "<base64 DER>"}}}`) in ein Temp-Verzeichnis schreiben, `java -jar <KASSA_RKSV_TOOL>/regkassen-verification-depformat-1.1.1.jar -v -f -i … -c … -o <temp>/aus` mit leerem `JAVA_TOOL_OPTIONS` starten, und erwarten: Es gibt je Beleg Ergebnis-Dateien, und in jeder steht `"verificationState":"PASS"` (Leerzeichen egal). Bei einem Fehler nennt die Meldung die Datei und ihren Text. Den Ausgang des Programms und die letzten 20 Zeilen seiner Ausgabe druckt der Test immer.
- [ ] **Step 3: `tool/rksv/pruefen.sh`:** setzt `KASSA_RKSV_TOOL` (erster Parameter oder `/mnt/project-files/kassa-build/rksv/pruefwerkzeug/regkassen-verification-1.1.1`), bricht mit `Das Prüfwerkzeug fehlt unter <ordner>.` ab, wenn die jar-Datei fehlt, und ruft `flutter test test/rksv/pruefwerkzeug_test.dart` aus `app/`.
- [ ] **Step 4:** Umsetzen, Tests. `tool/rksv/pruefen.sh` einmal laufen lassen und das Ergebnis wörtlich in den Bericht schreiben, auch wenn es scheitert. Scheitert ein Beleg: nicht am Prüfwerkzeug vorbei anpassen, sondern mit Datei und Text als DONE_WITH_CONCERNS melden.
- [ ] **Step 5: Commit** `Protokoll ausgeben, Lauf mit dem Prüfwerkzeug des Finanzministeriums`.

---

### Task 8: QR-Code und Kassen-Kennung am gedruckten Bon

**Files:**
- Modify: `app/lib/domain/print_document.dart`, `app/lib/domain/receipt_layout.dart`, `app/lib/devices/escpos.dart`, `app/lib/devices/printer.dart`, `app/pubspec.yaml` (`qr`), `app/lib/features/settings/printer_panel.dart`, `app/lib/data/settings_repository.dart` (falls in Task 3 noch nicht verdrahtet)
- Test: `app/test/domain/receipt_layout_test.dart`, `app/test/devices/escpos_test.dart`, `app/test/devices/printer_test.dart`, `app/test/features/` (Schalter)

**Interfaces (Produces):**

```dart
/// Ein QR-Code, mittig. [data] ist reines ASCII.
class PrintQr extends PrintOp { const PrintQr(this.data); final String data; }
Uint8List encodeEscPos(List<PrintOp> document, {bool qrAsImage = false, int columns = 48});
```

**Bon (Ergänzung zu `layoutReceipt`):**
- Nach der Zeile `Bedienung: …`, wenn `r.rksv != null`: `Kassen-ID: <cashBoxId>`.
- Nach dem Zahlungs-Block (bei Sonderbelegen nach der Summe), wenn `r.rksv != null`: Leerzeile, `PrintQr(r.rksv.qrText)`, und bei `damaged` darunter mittig `Sicherheitseinrichtung ausgefallen`.
- `testMarker` entfällt als Parameter: "TESTBON" steht, wenn `r.rksv == null || r.rksv.probe`.

**ESC/POS für `PrintQr`** (mittig über `ESC a 1`, danach zurück auf links):
- Modell 2: `1D 28 6B 04 00 31 41 32 00`
- Größe der Punkte n: `1D 28 6B 03 00 31 43 n`, n = 5 bei 42 Spalten und mehr, sonst 4
- Fehlerkorrektur M: `1D 28 6B 03 00 31 45 31`
- Daten speichern: `1D 28 6B pL pH 31 50 30` + Daten, mit pL + 256·pH = Länge + 3
- Drucken: `1D 28 6B 03 00 31 51 30`

**Als Bild** (`qrAsImage`): Matrix aus dem Paket `qr` (Fehlerkorrektur M), Rand 4 Module, jedes Modul n Punkte, als Rasterbild `1D 76 30 00 xL xH yL yH` + Zeilen; Breite des Bildes = Breite des Papiers in Punkten (12 je Spalte), der Code steht mittig.

**Drucker-Einstellungen:** Schalter `QR-Code als Bild drucken` mit Hilfe `Einschalten, wenn am Bon statt des QR-Codes nur Zeichen stehen.` (Key `printer-qr-image`), nur sichtbar, wenn ein Drucker eingerichtet ist.

- [ ] **Step 1: Tests schreiben:** Layout eines Probe-Verkaufs (Kassen-ID, `PrintQr` mit genau dem QR-Text, `TESTBON`), eines Ausfall-Bons (Satz unter dem Code), eines Bons ohne Eintrag (wie heute, kein `PrintQr`); Bytes von `PrintQr('ABC')` bei 48 und 32 Spalten genau wie oben; als Bild: Kopf `1D 76 30 00`, Breite 72 Bytes bei 48 Spalten, erste und letzte Bildzeile leer (Rand); ein Text mit 300 Zeichen lässt sich kodieren; Schalter speichert.
- [ ] **Step 2:** Tests schlagen fehl. **Step 3:** Umsetzen (API des Pakets `qr` in `~/.pub-cache` nachlesen). **Step 4:** Ganze Suite, `flutter analyze`.
- [ ] **Step 5: Commit** `Bon mit Kassen-Kennung und QR-Code`.

---

### Task 9: Karte "Signatur" in den Einstellungen

**Files:**
- Modify: `app/lib/features/settings/signature_panel.dart`, `settings_screen.dart`
- Create: `app/lib/features/settings/probe_question.dart`, `app/lib/features/settings/protocol_export_sheet.dart`, `app/lib/features/settings/rksv_task_row.dart`
- Test: `app/test/features/signature_panel_test.dart`, `app/test/golden/signature_panel_golden_test.dart`

**Inhalt der Karte** (Bilder aus Task 0; Keys in Klammern):

- Zeile `Signatur der Bons` mit Zustand als Pille: `Nicht eingerichtet` (neutral), `Probe` (Akzent), `Probe, Signatur ausgefallen` (Warnung). Hilfe: bei off `Für die Registrierkassen-Pflicht. Noch nicht eingerichtet.`; bei Probe `Probe-Signatur, nicht für den echten Betrieb. Kassen-ID <Kennung>.`
- Steht `notice`: ein ruhiger Hinweis mit dem Text und der Taste `Verstanden` (`rksv-notice-ok`), die `clearNotice` ruft.
- Offene Aufgaben, je eine Zeile mit `rksvTaskText` und der Taste `Erledigt` (`rksv-task-done-<id>`). In der Probe steht darüber klein: `Aufgaben aus der Probe sind zum Üben.`
- Nur für den Chef:
  - bei off: `Zum Ausprobieren einschalten` (`rksv-probe-on`). Rückfrage (Blatt): Titel `Probe-Signatur einschalten?`, Text `Jeder Bon bekommt dann einen QR-Code und wird ins Protokoll geschrieben, so wie später im echten Betrieb. Die Bons bleiben Testbons. Ältere Bons kannst du danach nicht mehr stornieren.`, Tasten `Einschalten` und `Abbrechen`. Danach wird der Startbeleg gedruckt (ohne Drucker: nichts).
  - bei Probe: `Nullbeleg drucken` (`rksv-zero`, der Nullbeleg wird gedruckt), `Protokoll ausgeben` (`rksv-export`), `Probe beenden` (`rksv-probe-off`, Rückfrage: Titel `Probe-Signatur beenden?`, Text `Die Kassa erstellt einen Schlussbeleg. Danach haben neue Bons keinen QR-Code mehr.`, Tasten `Beenden` und `Abbrechen`; der Schlussbeleg wird gedruckt).
  - Gibt es eine beendete Kette und mode off: `Protokoll ausgeben` bleibt sichtbar.
- `Protokoll ausgeben` öffnet ein Blatt mit drei großen Zeilen `Alles`, `Dieses Vierteljahr`, `Letztes Vierteljahr`; nach der Wahl öffnet sich das Fenster von Android. Rückmeldung: `Gespeichert.`, `Nicht gespeichert.` (abgebrochen), `In diesem Zeitraum gibt es keine Einträge.`
- Fehler (`RksvProblem`): ruhige Zeile mit `message`.
- `Karte prüfen` bleibt wie in S1a.

Während eine Aktion läuft, sind die Tasten gesperrt (kein doppelter Startbeleg).

- [ ] **Step 1: Tests schreiben:** Zustände off/Probe/Ausfall; Mitarbeiter ohne Chef-Rolle sieht keine der Tasten; Einschalten mit Rückfrage erzeugt genau einen Startbeleg, auch bei doppeltem Antippen; Abbrechen ändert nichts; Nullbeleg; Export mit den drei Ausgängen (`ProtocolSaver` als Attrappe); Aufgabe erledigen; `notice` und `Verstanden`; `RksvProblem` beim Einschalten zeigt den Satz. Vergleichsbilder: off, Probe mit zwei Aufgaben, Ausfall, jeweils hell, Probe auch dunkel.
- [ ] **Step 2:** Tests schlagen fehl. **Step 3:** Umsetzen nach den Bildern und `docs/design-regeln.md`. **Step 4:** Ganze Suite, `flutter analyze`; vorhandene Vergleichsbilder der Einstellungen ändern sich nur dort, wo die Karte "Signatur" im Bild ist (im Bericht einzeln nennen).
- [ ] **Step 5: Commit** `Einstellungen: Probe-Signatur ein und aus, Nullbeleg, Protokoll ausgeben, Aufgaben`.

---

### Task 10: Kassa, Bons, Abschluss

**Files:**
- Modify: `app/lib/features/kassa/kassa_screen.dart`, `sale_service.dart`, `app/lib/features/bons/receipt_detail.dart`, `app/lib/features/close/close_screen.dart`
- Create: `app/lib/ui/qr_view.dart` (zeichnet den QR-Code aus dem Paket `qr` mit `CustomPainter`, dunkle Module in Tintenfarbe auf Weiß, auch im dunklen Modus Weiß mit Rand), `app/lib/features/kassa/outage_banner.dart`
- Test: `app/test/features/` (Kassa, Bons, Abschluss), `app/test/golden/`

**Inhalt:**

- **Kassa:** Bei Ausfall ein ruhiger Hinweis über dem Warenkorb: `Signatur ausgefallen seit <HH:MM>` (bei einem anderen Tag `seit <TT.MM. HH:MM>`), darunter `Du kannst normal weiterverkaufen.` und die Taste `Nochmal prüfen` (`rksv-retry`, ruft `retrySignature`; danach `Die Signatur geht wieder.` oder `Geht noch nicht.`). Der Hinweis verschwindet, wenn der Ausfall endet.
- **Verkauf:** `sale_service` druckt einen Jahresbeleg, der vor dem Verkauf entstanden ist, vor dem Bon des Verkaufs (Monats- und Sammelbeleg werden nicht gedruckt). Der Ablauf des Verkaufs bleibt sonst gleich.
- **Storno:** `NotInCurrentChainException` zeigt den Satz aus Task 5 an der Stelle, an der heute "schon storniert" steht.
- **Bon-Ansicht:** bei `rksv != null` unter der Zahlung `Kassen-ID <Kennung>` und der QR-Code (`QrView`, 180 dp), bei `damaged` der Satz `Sicherheitseinrichtung ausgefallen`. Sonderbeleg: Bezeichnung als Titel.
- **Abschluss:** offene Aufgaben wie in der Karte "Signatur" (gleiche Zeile `rksv_task_row.dart`), unter den Summen. Sie sperren den Abschluss nicht.

- [ ] **Step 1: Tests schreiben:** Hinweis erscheint und verschwindet; `Nochmal prüfen` mit beiden Ausgängen; Verkauf im Ausfall dauert im Test nie länger als die Frist plus Speichern; Jahresbeleg wird vor dem Verkaufsbon gedruckt, Monatsbeleg nicht; Storno eines alten Bons zeigt den Satz; Bon-Ansicht mit QR-Code (Vergleichsbild hell und dunkel) und ohne; Abschluss zeigt Aufgaben und lässt sich trotzdem abschließen.
- [ ] **Step 2:** Tests schlagen fehl. **Step 3:** Umsetzen. **Step 4:** Ganze Suite, `flutter analyze`.
- [ ] **Step 5: Commit** `Kassa mit Hinweis zum Ausfall, Bon mit QR-Code, Aufgaben im Abschluss`.

---

### Task 11: Prüfliste, Abweichungen, Version

**Files:**
- Create: `docs/testen/rksv-probe-pruefliste.md`
- Modify: `docs/superpowers/specs/2026-11-18-rksv-signatur-design.md` (neuer Abschnitt 11.2 "S1b Kern": Entscheidungen K1 bis K12 mit Preis, die Annahmen "Am Wortlaut zu prüfen", was beim Bau anders wurde), `app/pubspec.yaml` (`version: 1.4.0+6`), `app/lib/core/app_info.dart` (`'1.4.0'`)

Die Prüfliste ist zum Abhaken am Tablet, in einfachen Worten, mit "Das solltest du sehen" je Schritt und den genauen Texten der App: Probe einschalten; Startbeleg; zwei Verkäufe (bar und Karte) mit QR-Code am Bon; QR-Code mit dem Handy lesen (der Text beginnt mit `_R1-AT100_`; BMF Belegcheck lehnt ihn ab, das ist richtig); Storno; Nullbeleg; Protokoll ausgeben und die Datei schicken; QR-Code unlesbar oder Zeichensalat am Bon: Schalter "QR-Code als Bild drucken"; Probe beenden. Dazu "Was du mir schickst". Nichts in der Liste verlangt eine PIN oder die Signaturkarte.

Die Versions-Zeile steht in Vergleichsbildern der Einstellungen. Niko hat am 18.11.2026 erlaubt, sie für eine neue Version neu zu erzeugen. Wie in S1a setzt der Controller die Version und erzeugt die Bilder; der Unterauftrag schreibt nur die beiden Dokumente.

- [ ] **Step 1:** Prüfliste und Abschnitt 11.2 schreiben; jeden zitierten Text gegen den Code prüfen (`grep`).
- [ ] **Step 2: Commit** `Prüfliste für die Probe-Signatur, Abweichungen beim Bau`.
- [ ] **Step 3 (Controller):** Version setzen, Vergleichsbilder neu, ganze Suite, `tool/rksv/pruefen.sh`, Bau mit `KASSA_ALLOW_NO_SUMUP=1 ../tool/build_apk.sh arm64`, Hochladen als 1.4.0 Build 6.
