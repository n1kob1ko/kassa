# RKSV S1a: "Karte prüfen" Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Der Chef sieht in den Einstellungen Zeile für Zeile, ob Tablet, Verteiler, USB-Kartenleser und die Signaturkarte von A-Trust zusammenarbeiten: Leser gefunden, Zugriff erlaubt, Karte erkannt, Zertifikat gelesen, Probe-Unterschrift mit der PIN erstellt und geprüft. Ein Bericht lässt sich teilen.

**Architecture:** Ein kleiner Kotlin-Kanal reicht rohe Nachrichten zwischen Dart und dem Kartenleser am USB-Anschluss hin und her und weiß sonst nichts. Alles Wissen über Kartenleser (CCID), Übertragung (T=1) und Karte (Befehle von A-Trust) liegt in reinem Dart unter `app/lib/rksv/card/` und wird gegen einen nachgebauten Leser mit nachgebauter Karte getestet. Der Bildschirm "Karte prüfen" steuert einen Prüflauf, der den Leser für jeden Lauf öffnet und wieder freigibt.

**Tech Stack:** Flutter 3.50.0, Kotlin 2.4.20, neues Dart-Paket `pointycastle` (Zertifikat lesen, Unterschrift prüfen, in Tests unterschreiben). Keine Änderung an der Datenbank, keine Änderung am Server.

**Spec:** `docs/superpowers/specs/2026-11-18-rksv-signatur-design.md` (Abschnitte 6.7, 6.9, 6.10, 7, 8). Dazu `docs/design-regeln.md`, `DESIGN.md`, `PRODUCT.md`.

## Wo dieser Plan steht

| Plan | Inhalt | Stand |
|---|---|---|
| **S1a (dieser Plan)** | "Karte prüfen": Leser, Karte, Zertifikat, Probe-Unterschrift, Bericht. Version 1.3.0 | geschrieben |
| S1b | Kern mit Probe-Signatur: Code, Kette, Zähler, QR-Code am Bon, Sonderbelege, Ausfall, Protokoll ausgeben | danach, eigener Plan |
| S2 | Chipkarte als echte Signatur, Einrichtung, Angaben für FinanzOnline | nach Nikos Bericht aus S1a |
| S3 | Inbetriebnahme bei YICHI | durch Niko |

Niko hat den Entwurf am 18.11.2026 freigegeben. S1a wird zuerst ausgeliefert, weil sein Ergebnis über S2 entscheidet.

## Was vor dem Schreiben geprüft wurde (18.11.2026)

- **Befehle der Karte sind belegt.** A-Trust veröffentlicht sie in `github.com/A-Trust/RKSV` (Stand `d113d00` vom 4.11.2026): "A-Trust cash register smart card, Developer Manual" Version 0.3 und Beispiel-Code in Java. Beides liegt unter `/mnt/project-files/kassa-plan/karte-quelle/` (`APDU_API.pdf`, `apdu.txt`, `atrust-java/`). Damit gibt dieser Plan auch Zeile 5 (PIN und Probe-Unterschrift) für alle fünf Kartenarten von A-Trust frei, anders als im Entwurf als Möglichkeit vorgesehen. Für jede andere Karte bleibt Zeile 5 gesperrt.
- **A-Trust schreibt T=1 vor** ("Communication with the smart card should use the T1 protocol"). Alle acht bekannten Antworten der Karten beim Einschalten (ATR) bieten nur T=1 an.
- Als Nachschlagewerk für Kartenleser liegt der freie Treiber `CCID` von Ludovic Rousseau unter `/mnt/project-files/kassa-plan/karte-quelle/ccid-referenz/` (`commands.c`, `ccid.h`, `ifdhandler.c`, `ccid_usb.c`, `proto-t1.c`, `atr.c`). **Nur lesen, nichts abschreiben** (LGPL). Wo dieser Plan und der Treiber sich widersprechen, gilt der Plan; der Widerspruch gehört in den Bericht der Aufgabe.
- Ein erfundenes Test-Zertifikat mit Schlüssel liegt unter `/mnt/project-files/kassa-plan/karte-quelle/test-zertifikat/` (Seriennummer 889977665544, gültig bis 30.06.2031, Aussteller "Beispiel CA", Inhaber "Beispiel-Imbiss Signaturkarte", 379 Bytes).
- Es gibt hier weder Kartenleser noch Karte noch Emulator. Der Kotlin-Teil wird nur gebaut und gelesen, nicht ausgeführt. An echten Geräten prüft Niko mit der Prüfliste aus Task 8.

## Entscheidungen in diesem Plan (Claude)

| Nr. | Entscheidung | Warum | Preis |
|---|---|---|---|
| K1 | Die Kassa handelt mit der Karte keine höhere Geschwindigkeit aus (kein PPS). | Ein Schritt weniger, der an einer einzigen Karte schiefgehen kann. | Das Zertifikat lesen dauert rund eine Sekunde länger. |
| K2 | Nur T=1, kein T=0. | A-Trust schreibt T=1 vor. | Eine fremde Karte mit T=0 zeigt "kennt die Kassa nicht". |
| K3 | Der USB-Teil des Druckers (`PrinterChannel.kt`) wird nicht angefasst; die Frage nach der USB-Erlaubnis steht ein zweites Mal im neuen Kanal. | Entwurf 6.7: Der Drucker-Teil bleibt unberührt. | Rund 80 Zeilen doppelt. |
| K4 | Der Bericht geht als Text über das Teilen-Fenster von Android. | Kein neues Paket, funktioniert mit Mail und Messenger. | Kein Anhang als Datei. |
| K5 | Nach einer gelungenen Probe-Unterschrift folgen zwei weitere, um die Dauer zu messen. | Die Dauer entscheidet, ob die Karte die Frist von 5 Sekunden pro Bon hält. | Zwei Sekunden länger. |
| K6 | Ein PIN-Wächter merkt sich einen Fehlversuch und schickt bei nur noch einem Versuch keine PIN mehr. | YICHI hat nur diese eine Karte. | Ein Dialog mehr, falls der Zähler in der alten Kassa wieder aufgefüllt wurde. |
| K7 | Die PIN wird in S1a nicht gespeichert. | Sie wird erst bei der Einrichtung gebraucht (S2). | Für jede Probe neu eingeben. |

## Global Constraints

- Plattform: Android-Tablet im Querformat, Entwurfsgröße 1280 × 800, `minSdk = 26`.
- Oberfläche auf Deutsch, einfache Worte, Du-Form. Texte nennen keine Planschritte und keine Fachwörter (kein "CCID", "ATR", "APDU", "T=1" am Bildschirm; im Bericht sind sie erlaubt). Die Texte in diesem Plan gelten wörtlich.
- In der ganzen App kommt kein Textfeld vor (`test/no_text_field_test.dart`). Die PIN wird über das vorhandene Zahlenfeld (`lib/ui/keypad.dart`) eingegeben.
- Tippflächen mindestens 48 dp, Hauptaktionen 64 bis 80 dp hoch. Farben, Maße und Bewegung aus `DESIGN.md` und `lib/ui/tokens.dart`. Bewegung 120 bis 320 ms, abgeschaltet bei "Animationen entfernen". Neue Bildschirme folgen den Bildern aus Task 0.
- **Schutz der Karte, gilt für jede Zeile Code:**
  - Zur Karte gehen ausschließlich die Befehle aus der Tabelle in Task 4. Es gibt keinen Weg, einen frei zusammengesetzten Befehl zu schicken (`CardCommand` hat keinen öffentlichen Konstruktor).
  - VERIFY geht nur nach einem ausdrücklichen Antippen von "Unterschrift erstellen" hinaus, nie beim Öffnen des Bildschirms, nie bei "Nochmal prüfen". Nach einer Antwort ungleich `9000` auf VERIFY wird in diesem Lauf kein weiterer Befehl mit PIN geschickt und nichts von selbst wiederholt. Auch die Übertragungsschicht wiederholt einen Block mit PIN nie von selbst (siehe Task 3).
  - Nie VERIFY ohne Daten, nie einen Befehl zum Ändern oder Entsperren der PIN, nie die PIN-Eingabe des Lesers (CCID "Secure", Nachricht `0x69`).
  - Zeile 5 gibt es nur für eine Karte, deren ATR in der Tabelle aus Task 4 steht.
- **Die PIN** steht nie in einem Protokoll, Bericht, Fehlertext, `debugPrint`, `toString` oder Test-Namen und wird nirgends gespeichert. Sie lebt nur für die Dauer eines Laufs im Speicher.
- Der Leser wird für jeden Lauf geöffnet und danach wieder freigegeben (`powerOff`, `close`), auch im Fehlerfall. Ein Lauf endet spätestens nach 20 Sekunden mit einem Ergebnis.
- Kein Gerät sperrt den Verkauf: Der Bildschirm "Karte prüfen" ändert nichts an Bons, Drucker oder Kartenzahlung. `PrinterChannel.kt` und `lib/devices/` bleiben unverändert.
- Das Repo ist öffentlich. Keine echten Zertifikate, Seriennummern oder Berichte von YICHI ins Repo. Tests verwenden das erfundene Test-Zertifikat. Die Unterlagen unter `/mnt/project-files/` kommen nicht ins Repo (das Test-Zertifikat ausgenommen).
- Bezeichner im Code englisch, Oberfläche deutsch. Neue Wörter: Kartenleser = `reader`, Signaturkarte = `card`, Prüflauf = `CardCheck`, Bericht = `report`.
- Gebaut wird testgetrieben. Git: Commits auf `claude/project-thread-xtooco`, ohne Pull Request, Commit-Texte auf Deutsch, mit den Abschlusszeilen, die der Auftrag nennt.
- Alle Befehle laufen aus `app/`, wenn nichts anderes dasteht. Flutter liegt in `~/flutter` (`export PATH="$HOME/flutter/bin:$PATH"`). Vor jedem Commit: `flutter analyze` ohne Meldung und die Tests der Aufgabe grün.
- Ein Bau der Installationsdatei läuft nur in Task 1 und Task 8, je einmal am Ende (`../tool/build_apk.sh arm64`). Die Datei wird nie committet.
- Zahlen in diesem Plan sind hexadezimal, wenn sie als Bytes dastehen (`6F`, `0x6F`), sonst dezimal. Mehrbyte-Felder der USB-Nachrichten sind "little endian".

## Review Focus

Diese fünf Fälle beschreibt der Entwurf nicht im Einzelnen, sie treffen aber Niko am Tablet oder die Karte von YICHI. Jeder hat seinen Test in der genannten Aufgabe.

1. **Die PIN taucht irgendwo auf.** Erwartet: Nach einer Probe-Unterschrift mit der PIN `493817` enthält der Bericht weder `493817` noch `26493817` noch `343933383137`, in keiner Schreibweise der Hex-Zeichen; die Zeile zum VERIFY zeigt `00 20 00 8A 08 ** ** ** ** ** ** ** **`. Die Ziffern stehen nicht in der Semantik des PIN-Fensters. Tests in Task 6 und Task 7.
2. **Falsche PIN.** Erwartet: Pro Antippen geht genau ein VERIFY zur Karte. Nach `63C2` kein zweites von selbst. Nach `63C1` schickt die Kassa keine PIN mehr, auch nicht nach Neustart der App, bis der Chef den Wächter ausdrücklich zurücksetzt. `6983` zeigt "Die Karte ist gesperrt." Tests in Task 6.
3. **Leser abgezogen oder Karte gezogen, mitten im Lauf.** Erwartet: Die betroffene Zeile zeigt den Fehler, die folgenden Zeilen sind gesperrt, der Leser ist freigegeben, "Nochmal prüfen" funktioniert sofort, nichts dreht sich endlos. Tests in Task 2 und Task 6.
4. **Drucker und Leser am selben Verteiler.** Erwartet: Nur ein Gerät mit einer Schnittstelle der Klasse `0B` gilt als Kartenleser. Der Drucker (Klasse `07`) wird nie geöffnet. Ist nur der Drucker da: "Kein Kartenleser gefunden." Der Bericht listet beide Geräte. Tests in Task 1 und Task 6.
5. **Der Leser überlässt die Übertragung der Kassa (TPDU) und die Leitung hakt.** Erwartet: Eine Antwort in zwei Teilen (Zertifikat), eine Bitte um mehr Zeit während der Unterschrift (WTX) und ein einzelner Block mit falscher Prüfsumme werden verkraftet. Dauerndes WTX oder Müll enden nach begrenzter Zeit mit einem Fehler, nie in einer Schleife. Tests in Task 3 und Task 6.

---

### Task 0: Bildschirme zeichnen und Niko zeigen (macht Claude selbst, kein Unterauftrag)

**Files:**
- Create: `/mnt/project-files/kassa-entwurf/rksv/` (Bilder und Quelle, nicht im Repo)

Gezeichnet wird im Stil der bestehenden Tablet-Bilder (`/mnt/project-files/kassa-entwurf/quelle/teilc.py`): (1) Einstellungen mit der neuen Karte "Signatur", (2) "Karte prüfen" vor dem Start, (3) "Karte prüfen" mit allen fünf Zeilen grün, (4) "Karte prüfen" mit einem Fehler in Zeile 3 und gesperrten Zeilen 4 und 5, (5) das PIN-Fenster. Niko bekommt die Bilder im Thread. Der Bau der Bildschirme (Task 7) beginnt, sobald die Bilder verschickt sind, und wartet nicht auf eine Antwort (Entwurf 6.10).

- [ ] Bilder erzeugen, ansehen, an Niko schicken. Die Pfade der Bilder stehen im Auftrag für Task 7.

---

### Task 1: Kotlin-Kanäle für Kartenleser und Teilen, Dart-Seite dazu

**Files:**
- Create: `app/android/app/src/main/kotlin/io/github/n1kob1ko/kassa/CardReaderChannel.kt`, `app/android/app/src/main/kotlin/io/github/n1kob1ko/kassa/ShareChannel.kt`, `app/lib/rksv/card/reader_transport.dart`, `app/lib/rksv/card/share_sheet.dart`
- Modify: `app/android/app/src/main/kotlin/io/github/n1kob1ko/kassa/MainActivity.kt` (beide Kanäle anlegen und in `disposeChannels` freigeben)
- Test: `app/test/rksv/card/reader_transport_test.dart`, `app/test/rksv/card/share_sheet_test.dart`

**Interfaces:**
- Consumes: Muster aus `PrinterChannel.kt` (ein Arbeits-Thread, Antwort genau einmal auf dem Haupt-Thread, Frage nach der USB-Erlaubnis mit Zeitgrenze) und `lib/devices/channel_transport.dart`. `PrinterChannel.kt` wird nicht geändert (K3).
- Produces:

Kanal `kassa/cardreader` (MethodChannel):

| Methode | Argumente | Antwort | Fehlercodes |
|---|---|---|---|
| `list` | keine | Liste aller angesteckten USB-Geräte: `{address: '<vendorId>:<productId>' dezimal, name: String (Produktname oder ''), vendorId: int, productId: int, deviceClass: int, granted: bool, interfaces: [{klass: int, subclass: int, protocol: int}]}` | keine |
| `open` | `{address: String}` | `{descriptors: Uint8List}` (Ergebnis von `UsbDeviceConnection.getRawDescriptors()`) | `not_found`, `no_permission`, `not_ccid`, `busy` |
| `exchange` | `{out: Uint8List?, timeoutMs: int}` | `Uint8List`: genau eine vollständige Nachricht des Lesers | `not_open`, `timeout`, `io` |
| `close` | keine | `null`, gelingt immer | keine |
| `info` | keine | `{model: String, android: String}`, z. B. `'Xiaomi 23073RPBFG'`, `'14 (API 34)'` | keine |

Kanal `kassa/share`: Methode `text` mit `{subject: String, text: String}`, öffnet das Teilen-Fenster (`Intent.ACTION_SEND`, `text/plain`, über `Intent.createChooser`), Antwort `true`, oder `false`, wenn Android kein Ziel hat.

```dart
// reader_transport.dart
const cardReaderChannel = MethodChannel('kassa/cardreader');
enum ReaderProblem { noChannel, notFound, noPermission, notCcid, busy, notOpen, timeout, io }
class ReaderException implements Exception { const ReaderException(this.problem); final ReaderProblem problem; }
class UsbInterfaceInfo { const UsbInterfaceInfo(this.klass, this.subclass, this.protocol); }
class UsbDeviceInfo {
  // address, name, vendorId, productId, deviceClass, granted, interfaces
  bool get isCardReader; // eine Schnittstelle mit klass == 0x0B
}
class TabletInfo { const TabletInfo(this.model, this.android); }
abstract interface class ReaderTransport {
  Future<List<UsbDeviceInfo>> list();          // ohne Kanal: leere Liste
  Future<Uint8List> open(String address);      // rohe Deskriptoren
  Future<Uint8List> exchange(Uint8List? out, {required Duration limit});
  Future<void> close();                        // wirft nie
  Future<TabletInfo> info();                   // ohne Kanal: TabletInfo('', '')
}
class ChannelReaderTransport implements ReaderTransport { ChannelReaderTransport({MethodChannel channel = cardReaderChannel}); }
// share_sheet.dart
abstract interface class ShareSheet { Future<bool> text({required String subject, required String text}); }
class ChannelShareSheet implements ShareSheet { … }  // ohne Kanal oder bei Fehler: false
```

**Kotlin, `CardReaderChannel`:**
- `open`: Gerät über `address` suchen (`not_found`). Erlaubnis fehlt: `UsbManager.requestPermission` und auf die Antwort warten, höchstens 60 Sekunden, Ablehnung oder Zeit um: `no_permission`. Schnittstelle der Klasse `0x0B` mit je einem Bulk-Endpunkt hinein und hinaus suchen (`not_ccid`). `openDevice` gibt `null` oder `claimInterface(intf, true)` gibt `false`: `busy`. Ein schon offener Leser wird vorher geschlossen. Es ist immer höchstens ein Leser offen.
- `exchange`: Ist `out` gesetzt, wird es mit einem `bulkTransfer` hinausgeschrieben; ist seine Länge ein Vielfaches der Paketgröße des Endpunkts, folgt ein `bulkTransfer` der Länge 0. Dann wird gelesen, bis eine vollständige Nachricht da ist: 10 Bytes Kopf, die Bytes 1 bis 4 nennen die Länge der Daten (little endian), also insgesamt `10 + Länge` Bytes. Lesepuffer 65 556 Bytes; eine genannte Länge über 65 546 ist `io`. Die Zeitgrenze `timeoutMs` gilt für den ganzen Aufruf. `bulkTransfer` kleiner 0 nach abgelaufener Zeit: `timeout`, sonst `io`. Ohne offenen Leser: `not_open`.
- `close`: `releaseInterface`, `close`, Fehler schlucken. `dispose()` des Kanals schließt ebenfalls.
- Alles Blockierende auf einem eigenen Thread dieses Kanals; jede Antwort genau einmal auf dem Haupt-Thread.
- Der Kanal kennt keine Nachrichtentypen und verändert keine Bytes.

- [ ] **Step 1: Failing tests** (Kanal mit `TestDefaultBinaryMessengerBinding` nachgestellt)

```dart
test('list wird zu UsbDeviceInfo; nur Klasse 0x0B gilt als Kartenleser', …);       // Drucker (07) und Leser (0B) in einer Liste
test('ein Gerät mit Geräteklasse 0 und zwei Schnittstellen (03 und 0B) ist ein Kartenleser', …);
test('list ohne Kanal ist leer; info ohne Kanal ist leer', …);
test('open gibt die Deskriptoren zurück', …);
test('Fehlercodes: not_found, no_permission, not_ccid, busy, not_open, timeout, io', …); // je der passende ReaderProblem
test('ein unbekannter Fehlercode wird io; MissingPluginException wird noChannel', …);
test('exchange reicht out und timeoutMs durch; out == null bleibt null', …);
test('close wirft nie, auch wenn der Kanal einen Fehler meldet', …);
test('ShareSheet.text reicht Betreff und Text durch; ohne Kanal false', …);
```

- [ ] **Step 2:** FAIL. **Step 3:** Dart und Kotlin umsetzen, `MainActivity` ergänzen. **Step 4:** PASS, `flutter analyze`.
- [ ] **Step 5: Bau prüfen:** `../tool/build_apk.sh arm64` läuft durch. Commit des Codes, die Datei nicht.

---

### Task 2: Kartenleser-Nachrichten (CCID) in Dart

**Files:**
- Create: `app/lib/rksv/card/ccid.dart`, `app/lib/rksv/card/probe_log.dart`
- Test: `app/test/rksv/card/ccid_test.dart`, `app/test/support/scripted_reader.dart`

**Interfaces:**
- Consumes: `ReaderTransport`, `ReaderException` (Task 1)
- Produces:

```dart
// probe_log.dart: sammelt Zeilen für den Bericht
class ProbeLog {
  void line(String text);
  void bytes(String label, Uint8List data, {bool secret = false}); // secret: nur '[geheim, N Bytes]'
  List<String> get lines;
}
String hex(Uint8List data); // 'AA BB CC', Großbuchstaben, mit Leerzeichen

// ccid.dart
enum ExchangeLevel { character, tpdu, shortApdu, extendedApdu }
class CcidDescriptor {
  static CcidDescriptor parse(Uint8List rawDescriptors); // FormatException, wenn keiner da ist
  final int voltageSupport, protocols, maxIfsd, features, maxMessageLength;
  ExchangeLevel get level;
  bool has(int feature);
}
abstract final class CcidFeature {
  static const autoConfig = 0x02, autoActivation = 0x04, autoVoltage = 0x08,
      autoNegotiation = 0x40, autoPps = 0x80, autoIfsd = 0x400;
}
enum CcidProblem { cardAbsent, cardMute, commandFailed, badAnswer }
class CcidException implements Exception { const CcidException(this.problem, {this.error}); final CcidProblem problem; final int? error; }
class CcidReader {
  CcidReader(ReaderTransport transport, CcidDescriptor descriptor, {ProbeLog? log});
  Future<Uint8List> powerOn();                                   // ATR
  Future<void> powerOff();                                       // wirft nie
  Future<void> setParameters(int protocol, Uint8List data);
  Future<Uint8List> transfer(Uint8List data, {int bwi = 0, bool secret = false, Duration limit = const Duration(seconds: 3)});
}
```

**Der Deskriptor.** `rawDescriptors` ist eine Folge von Einträgen, jeder beginnt mit Länge und Typ. Gesucht ist der Eintrag mit Typ `21` und Länge `36` (54 Bytes), der nach dem Schnittstellen-Eintrag (Typ `04`) mit Klasse `0B` (Byte 5 des Eintrags) und vor dem nächsten Schnittstellen-Eintrag steht. Felder im Eintrag (Byte ab 0): `bVoltageSupport` 5, `dwProtocols` 6 bis 9, `dwMaxIFSD` 28 bis 31, `dwFeatures` 40 bis 43, `dwMaxCCIDMessageLength` 44 bis 47. Stufe aus `dwFeatures & 0x00070000`: `0x00010000` TPDU, `0x00020000` kurze APDU, `0x00040000` erweiterte APDU, sonst Zeichen.

**Nachrichten.** Kopf 10 Bytes: Typ, Länge der Daten (4 Bytes), Steckplatz `00`, laufende Nummer, drei Bytes je nach Typ. Die Nummer beginnt bei 0 und wächst mit jeder gesendeten Nachricht (nach 255 wieder 0).

| Richtung | Typ | Bytes 7 bis 9 | Daten |
|---|---|---|---|
| hin: Karte einschalten | `62` | Spannung, `00 00` | keine |
| hin: Karte ausschalten | `63` | `00 00 00` | keine |
| hin: Parameter setzen | `61` | Protokoll (`01` für T=1), `00 00` | 7 Bytes bei T=1 |
| hin: Block übertragen | `6F` | `bwi`, `00 00` | der Block |
| zurück: Datenblock | `80` | Status, Fehler, `00` | ATR oder Antwort |
| zurück: Steckplatz-Status | `81` | Status, Fehler, Takt | keine |
| zurück: Parameter | `82` | Status, Fehler, Protokoll | Parameter |

Status: Bits 0 und 1 sagen `0` Karte aktiv, `1` Karte da, aber aus, `2` keine Karte. Bits 6 und 7 sagen `0` gut, `1` gescheitert, `2` "brauche mehr Zeit".

- **Mehr Zeit:** Dann kommt die eigentliche Antwort später mit derselben Nummer. `exchange(null, …)` erneut aufrufen, höchstens 30-mal und insgesamt höchstens 20 Sekunden, danach `ReaderException(timeout)`.
- **Gescheitert:** Karte laut Status nicht da: `cardAbsent`. Fehlerbyte `FE`: `cardMute`. Sonst `commandFailed` mit dem Fehlerbyte.
- **Falsche Antwort:** Stimmt die Nummer nicht, bis zu dreimal weiterlesen (eine alte Antwort hing noch in der Leitung), dann `badAnswer`. Falscher Typ oder weniger als 10 Bytes: `badAnswer`.
- **Einschalten:** Hat der Leser `autoVoltage` oder `autoActivation`, Spannung `00`. Sonst der Reihe nach `01` (5 V), `02` (3 V), `03` (1,8 V), jeweils nur, wenn das passende Bit in `voltageSupport` gesetzt ist (`01`, `02`, `04`); nach einem gescheiterten Versuch erst ausschalten. `cardAbsent` bricht die Reihe sofort ab. Antwort ohne Daten: `cardMute`.
- **Ausschalten** schluckt jeden Fehler.
- Jede Nachricht hin und zurück geht mit `log.bytes` ins Protokoll; bei `secret: true` in `transfer` beide Richtungen als geheim.

- [ ] **Step 1: Failing tests** (`ScriptedReader`: eine `ReaderTransport`-Attrappe mit einer Liste erwarteter Aufrufe und ihrer Antworten; ein unerwarteter Aufruf lässt den Test scheitern)

```dart
test('Deskriptor: Felder aus einem echten Beispiel', …);
// Eintrag: 36 21 10 01 00 07 03 00 00 00 C0 12 00 00 C0 12 00 00 00 80 25 00 00 00 B0 04 00 00
//          FE 00 00 00 00 00 00 00 00 00 00 00 30 00 01 00 0F 01 00 00 00 00 00 00 00 01
// davor Geräte-, Konfigurations- und Schnittstellen-Eintrag (Klasse 0B), danach zwei Endpunkte
// erwartet: voltageSupport 7, protocols 3, maxIfsd 254, features 0x00010030, level tpdu, maxMessageLength 271
test('Deskriptor: Schnittstelle der Klasse 07 davor wird übersprungen; ohne Eintrag FormatException', …);
test('powerOn schickt 62 00000000 00 00 00 0000 und gibt die ATR zurück', …);
// Antwort 80 18000000 00 00 00 00 00 3BDF97008131FE4680319052410464050401AC73D622C0F9
test('powerOn ohne autoVoltage versucht 5 V, dann 3 V, schaltet dazwischen aus', …);
test('powerOn: Status 42 mit Fehler FE und keine Karte ergibt cardAbsent; Status 41 mit FE ergibt cardMute', …);
test('setParameters schickt 61 07000000 00 nn 01 0000 und die 7 Bytes', …);
test('transfer zählt die Nummer hoch und prüft sie in der Antwort', …);
test('transfer: Status 80 heißt weiterlesen; nach 30 Runden timeout', …);
test('transfer: eine Antwort mit alter Nummer wird übersprungen', …);
test('transfer: Typ 81 statt 80 ist badAnswer; 9 Bytes sind badAnswer', …);
test('ReaderException(io) aus dem Transport wird durchgereicht', …);   // Review Focus 3
test('secret: das Protokoll zeigt [geheim, N Bytes] statt der Bytes, in beiden Richtungen', …);
test('powerOff schluckt Fehler', …);
```

- [ ] **Step 2:** FAIL. **Step 3:** Umsetzen. **Step 4:** PASS, `flutter analyze`. **Step 5:** Commit.

---

### Task 3: Antwort der Karte beim Einschalten (ATR) und Übertragung T=1

**Files:**
- Create: `app/lib/rksv/card/atr.dart`, `app/lib/rksv/card/t1.dart`
- Test: `app/test/rksv/card/atr_test.dart`, `app/test/rksv/card/t1_test.dart`

**Interfaces:**
- Produces:

```dart
class Atr {
  static Atr parse(Uint8List bytes);        // FormatException bei zu kurzer oder kaputter ATR
  final Uint8List bytes;
  final bool inverse;                       // erstes Byte 3F
  final List<int> protocols;                // in der Reihenfolge der Karte; ohne Angabe [0]
  final int? ta1, tc1, ta2;
  final int ifsc;                           // erstes TA ab der dritten Gruppe, sonst 32
  final int waiting;                        // erstes TB ab der dritten Gruppe, sonst 0x4D
  final bool crc;                           // erstes TC ab der dritten Gruppe, Bit 0
  final Uint8List historical;
  final bool checksumOk;                    // XOR ab dem zweiten Byte ist 0; ohne Prüfbyte true
  int get firstProtocol;                    // bei gesetztem ta2 dessen untere 4 Bits
}

typedef BlockExchange = Future<Uint8List> Function(Uint8List block, {int bwi, bool secret});
class T1Exception implements Exception { const T1Exception(this.reason); final String reason; }
class T1 {
  T1(BlockExchange exchange, {required int ifsc, ProbeLog? log});
  Future<void> negotiateIfsd(int ifsd);     // T1Exception, wenn die Karte nicht bestätigt
  Future<Uint8List> transmit(Uint8List apdu, {bool secret = false}); // Antwort mit den zwei Status-Bytes
}
```

**T=1 in Kürze.** Ein Block: `00`, Steuerbyte, Länge, Inhalt (höchstens 254), Prüfbyte (XOR über alles davor). Nur LRC; eine Karte mit `crc == true` lehnt Task 4 ab.

- **Daten-Block:** Steuerbyte `00` oder `40` (eigene Nummer 0 oder 1), plus `20`, wenn noch Teile folgen. Die eigene Nummer beginnt bei 0 und wechselt nach jedem bestätigten Daten-Block; die der Karte ebenso.
- **Bestätigung:** `80` oder `90` (erwartete Nummer der Gegenseite 0 oder 1), untere Bits `1` für Prüfsummen-Fehler, `2` für anderen Fehler.
- **Steuer-Block:** Anfrage `C0` + Art, Antwort `E0` + Art. Art `0` Neuabgleich, `1` Blockgröße, `3` mehr Zeit.
- **Senden:** Der Befehl wird in Stücke von höchstens `ifsc` Bytes geteilt. Auf jedes Stück außer dem letzten antwortet die Karte mit einer Bestätigung für die nächste Nummer.
- **Empfangen:** Kommt ein Daten-Block mit "es folgt mehr", schickt die Kassa eine Bestätigung mit der nächsten erwarteten Nummer der Karte und sammelt weiter.
- **Mehr Zeit (WTX):** Die Karte schickt `C3` mit einem Byte Faktor. Die Kassa antwortet `E3` mit demselben Byte und gibt den Faktor als `bwi` an den nächsten Austausch. Höchstens 20-mal je Befehl, danach `T1Exception`.
- **Blockgröße von der Karte (`C1`):** Mit `E1` und demselben Byte bestätigen, `ifsc` übernehmen.
- **Fehler:** Falsches Prüfbyte, falsche Länge oder ein unerwarteter Block: Bestätigung mit Fehlerbit schicken und die Antwort neu erwarten, höchstens 3-mal je Befehl. Bestätigt die Karte den eigenen Block nicht (sie nennt wieder die alte Nummer), denselben Block neu senden, höchstens 3-mal. Danach einmal Neuabgleich (`C0`, erwartet `E0`, beide Nummern auf 0) und `T1Exception`.
- **Mit PIN (`secret: true`) wird nie etwas von selbst neu gesendet:** Jeder Fehler, auch der erste, endet sofort mit `T1Exception`. Der Befehl passt immer in einen Block; ist er länger als `ifsc`, `T1Exception`, ohne etwas zu senden.
- `negotiateIfsd(n)`: `C1` mit dem Byte `n` senden, erwartet `E1` mit demselben Byte; höchstens 3 Versuche.

- [ ] **Step 1: Failing tests**

```dart
// atr_test.dart
test('ACOS-ID 4.1: 3BDF97008131FE4680319052410464050401AC73D622C0F9', …);
// protocols [1, 1], ta1 0x97, tc1 0x00, ta2 null, ifsc 254, waiting 0x46, crc false,
// historical 80319052410464050401AC73D622C0, checksumOk true, firstProtocol 1
test('ACOS-ID 2.1 kalt: 3BDF96FF910131FE4680319052410264050200AC73D622C017', …);
// ta1 0x96, tc1 0xFF, ta2 0x01, ifsc 254, waiting 0x46, firstProtocol 1, checksumOk true
test('CardOS 5.3: 3BDF18008131FE588031B05202046405C903AC73B7B1D422', …);
// ta1 0x18, ifsc 254, waiting 0x58, checksumOk true
test('eine ATR ohne Angabe eines Protokolls (3B 02 14 50) hat protocols [0] und kein Prüfbyte', …);
test('falsches Prüfbyte: checksumOk false; abgeschnittene ATR: FormatException', …);

// t1_test.dart (BlockExchange als Liste erwarteter Blöcke und Antworten)
test('ein kurzer Befehl: 00000700A4000C023F0092 hin, 000002900092 zurück, Ergebnis 9000', …);
test('der zweite Befehl trägt die Nummer 1: 00400700A4000C02DF0133, Antwort 0040029000D2', …);
test('Antwort in zwei Teilen: 002004AAAAAAAA24, Kassa schickt 00900090, dann 004003BB900068', …); // Ergebnis AAAAAAAABB9000
test('ein Befehl länger als ifsc wird geteilt; die Karte bestätigt mit 00900090', …);
test('WTX: Karte schickt 00C30102C0, Kassa 00E30102E0 und bwi 2 beim nächsten Austausch', …);
test('WTX 21-mal hintereinander endet mit T1Exception', …);                 // Review Focus 5
test('falsches Prüfbyte in der Antwort: Kassa schickt 00810081 und bekommt die Antwort neu', …); // Review Focus 5
test('dreimal falsches Prüfbyte: Neuabgleich 00C000C0 und T1Exception', …);
test('die Karte bestätigt den eigenen Block nicht (00800080): neu senden, höchstens dreimal', …);
test('Blockgröße von der Karte: 00C10120E0 wird mit 00E10120C0 bestätigt, ifsc ist danach 32', …);
test('negotiateIfsd(254): 00C101FE3E hin, 00E101FE1E zurück', …);
test('negotiateIfsd: falsche Antwort dreimal ergibt T1Exception', …);
test('secret: falsches Prüfbyte in der Antwort ergibt sofort T1Exception, es geht kein weiterer Block hinaus', …); // Review Focus 2
test('secret wird an den Austausch durchgereicht', …);
```

- [ ] **Step 2:** FAIL. **Step 3:** Umsetzen. **Step 4:** PASS, `flutter analyze`. **Step 5:** Commit.

---

### Task 4: Kartensitzung, Befehle von A-Trust, nachgebauter Leser mit Karte

**Files:**
- Create: `app/lib/rksv/card/card_session.dart`, `app/lib/rksv/card/atrust_card.dart`, `app/test/support/fake_card_reader.dart`
- Test: `app/test/rksv/card/card_session_test.dart`, `app/test/rksv/card/atrust_card_test.dart`

**Interfaces:**
- Consumes: `CcidReader`, `CcidDescriptor`, `CcidFeature`, `ExchangeLevel` (Task 2), `Atr`, `T1` (Task 3), `ProbeLog`
- Produces:

```dart
// atrust_card.dart
enum CardKind { acos, cardOs53, acosId2, acosId3, acosId41 }
enum PinFormat { ascii, format2 }
class CardProfile {
  final CardKind kind;
  final String label;        // Text am Bildschirm
  final String? notice;      // Hinweis zum Tausch, sonst null
  final List<List<int>> applications; // AIDs, die da sein müssen
  final List<int> signatureFolder, certificateFile, numberFolder, numberFile; // je 2 Bytes
  final PinFormat pinFormat;
  final int pinReference;    // P2 von VERIFY
  final bool separateHash;   // true nur bei acos
}
CardProfile? profileForAtr(Uint8List atr);

class CardCommand {          // kein öffentlicher Konstruktor
  final Uint8List bytes; final String label; final bool secret;
  static CardCommand selectFile(List<int> fileId);
  static CardCommand selectApplication(List<int> aid);
  static CardCommand readBinary(int offset);
  static CardCommand readCardNumber();
  static CardCommand prepareSignature();                      // nur acos
  static CardCommand verifyPin(CardProfile profile, String pin); // ArgumentError, wenn nicht 4 oder 6 Ziffern
  static CardCommand putHash(Uint8List sha256);               // nur acos
  static CardCommand sign(CardProfile profile, Uint8List sha256);
}
class CardResponse { final Uint8List data; final int status; bool get ok => status == 0x9000; }

// card_session.dart
enum SessionProblem { readerNotSupported, cardNotSupported, connectionLost }
class SessionException implements Exception { const SessionException(this.problem, this.detail); }
class CardSession {
  static Future<CardSession> start(CcidReader reader, CcidDescriptor descriptor, {ProbeLog? log});
  Atr get atr;
  Future<CardResponse> send(CardCommand command);
  Future<void> end();        // schaltet die Karte aus, wirft nie
}
```

**Kartenarten** (Quelle: `atrust-java/CashRegisterSmartCardFactory.java`; Vergleich "beginnt mit", wie dort):

| ATR beginnt mit | Art | `label` | `notice` |
|---|---|---|---|
| `3BBF11008131FE45455041`, `3BBF11008131FE454D4341` | `acos` | "a.sign RK CHIP (erste Generation, ACOS)" | "Das ist eine Karte der ersten Generation. Frag bei A-Trust nach, wie lange sie noch gilt." |
| `3BDF18008131FE588031B05202046405C903AC73B7B1D422`, `3BDF18008131FE588031905241016405C903AC73B7B1D444` | `cardOs53` | "a.sign RK CHIP (CardOS 5.3)" | "Diese Kartenart muss voraussichtlich bis Mai 2027 getauscht werden." |
| `3BDF96FF910131FE4680319052410264050200AC73D622C017`, `3BDF18FF910131FE4680319052410264050200AC73D622C099` | `acosId2` | "a.sign RK CHIP (ACOS-ID 2.1)" | "Diese Kartenart muss bis spätestens Mai 2027 getauscht werden." |
| `3BDF97008131FE4680319052410364050201AC73D622C0F8` | `acosId3` | "a.sign RK CHIP (ACOS-ID 3)" | "Diese Kartenart muss bis spätestens Mai 2027 getauscht werden." |
| `3BDF97008131FE4680319052410464050401AC73D622C0F9` | `acosId41` | "a.sign RK CHIP (ACOS-ID 4.1)" | keiner |

| | `acos` | `cardOs53` | `acosId2`, `acosId3`, `acosId41` |
|---|---|---|---|
| `applications` | `A0000001184543`, `A000000118454E` | `D0400000220001` | `D0400000220001` |
| `signatureFolder` | `DF70` | `DF01` | `DF01` |
| `certificateFile` | `C002` | `C000` | `C000` |
| `numberFolder` | `DF71` | `3F00` | `3F00` |
| `numberFile` | `D001` | `D001` | `D001` |
| `pinFormat` | `ascii` | `format2` | `format2` |
| `pinReference` | `81` | `81` | `8A` |
| `separateHash` | ja | nein | nein |

**Befehle** (Quelle: Developer Manual 0.3 und `atrust-java/`). Das ist die vollständige Liste dessen, was je zur Karte geht:

| Befehl | Bytes | `secret` |
|---|---|---|
| `selectFile(f)` | `00 A4 00 0C 02` f | nein |
| `selectApplication(a)` | `00 A4 04 0C` Länge a | nein |
| `readBinary(o)` | `00 B0` (o >> 8) & 7F, o & FF, `00` | nein |
| `readCardNumber()` | `00 B0 00 00 08` | nein |
| `prepareSignature()` | `00 22 41 B6 06 84 01 88 80 01 44` | nein |
| `verifyPin(p, pin)` | `00 20 00` p.pinReference `08` und 8 Bytes PIN | **ja** |
| `putHash(h)` | `00 2A 90 81 20` h | nein |
| `sign(p, h)` bei `separateHash` | `00 2A 9E 9A 00` | nein |
| `sign(p, h)` sonst | `00 2A 9E 9A 20` h `40` | nein |

PIN in 8 Bytes: `ascii`: die Ziffern als Zeichen, Rest `00` ("123456" wird `31 32 33 34 35 36 00 00`). `format2`: erstes Byte `2` und die Länge, dann je zwei Ziffern in einem Byte, Rest mit `F` gefüllt ("123456" wird `26 12 34 56 FF FF FF FF`, "1234" wird `24 12 34 FF FF FF FF FF`).

**`CardSession.start`:**
1. `reader.powerOn()`, `Atr.parse`. Kaputte ATR: `cardNotSupported`.
2. `descriptor.level == character`: `readerNotSupported`.
3. `atr.firstProtocol != 1` oder `atr.crc` oder (`atr.ta2` gesetzt und Bit `0x10` darin): `cardNotSupported`.
4. Hat der Leser `autoNegotiation` nicht: `setParameters(1, [fd, 0x10 | (atr.inverse ? 2 : 0), atr.tc1 ?? 0, atr.waiting, 0, atr.ifsc, 0])`. `fd` ist `atr.ta1 ?? 0x11`, wenn `atr.ta2` gesetzt ist (die Karte gibt die Geschwindigkeit fest vor), sonst `0x11` (K1). Scheitert der Befehl, steht das im Protokoll, und es geht weiter.
5. Stufe TPDU: `T1` anlegen mit `ifsc: atr.ifsc`. Hat der Leser `autoIfsd` nicht: `negotiateIfsd(min(254, descriptor.maxIfsd))`; scheitert das: `connectionLost`.
6. Stufe kurze oder erweiterte APDU: Befehle gehen unverändert über `reader.transfer`.

`start` reicht `CcidException` und `ReaderException` aus dem Einschalten unverändert durch (keine Karte, stumme Karte, Leser abgezogen).

`send` gibt der Karte für `verifyPin`, `putHash` und `sign` 5 Sekunden, sonst 3. Es schreibt eine Zeile mit `label`, Befehl und Antwort ins Protokoll; bei `secret` stehen statt der 8 Bytes PIN acht `**`, und die Schichten darunter bekommen `secret: true`. Eine Antwort mit weniger als 2 Bytes, `T1Exception`, `CcidException` oder `ReaderException` wird `SessionException(connectionLost, …)`.

**Nachgebauter Leser mit Karte** (`test/support/fake_card_reader.dart`), für diese und die folgenden Aufgaben:

```dart
class FakeCard {
  FakeCard({required this.atr, required this.profile, this.pin = '123456', this.retriesLeft = 3,
            Uint8List? certificate, Uint8List Function(Uint8List hash)? signer});
  int verifyCount = 0; List<String> received = []; // Befehle als Hex, ohne PIN-Vergleich nach außen
  bool removed = false;      // true: Leser meldet "keine Karte"
  bool mute = false;         // true: Karte antwortet nicht auf das Einschalten
}
class FakeCardReader implements ReaderTransport {
  FakeCardReader({this.devices, this.card, this.features = 0x00010030, this.maxIfsd = 254,
                  this.permission = true, this.failAfterExchanges, this.corruptBlockNumber,
                  this.wtxBeforeSign = 0, this.cardIfsc = 254});
}
```

Der Leser antwortet auf die Nachrichten aus Task 2, auf Stufe TPDU oder APDU je nach `features`. Die Karte führt ein kleines Dateisystem (MF, Ordner, Dateien aus dem Profil, Zertifikat, Kartennummer `0102030405060708`), prüft VERIFY gegen `pin` (falsch: `63Cx` und Zähler herunter, bei 0 `6983`; richtig: Zähler auf 3), unterschreibt nur nach richtigem VERIFY (sonst `6982`), bei `acos` nur nach `prepareSignature` und `putHash`. Unbekannte Datei `6A82`, Lesen hinter dem Ende `6B00`, unbekannter Befehl `6D00`. Auf Stufe TPDU spricht sie T=1 mit Blöcken von höchstens `cardIfsc` Bytes. `failAfterExchanges` lässt den Leser nach so vielen Austauschen `ReaderException(io)` werfen (abgezogen). `corruptBlockNumber` verfälscht das Prüfbyte der Antwort mit dieser laufenden Nummer einmal. `wtxBeforeSign` lässt die Karte vor der Unterschrift so oft um mehr Zeit bitten.

- [ ] **Step 1: Failing tests**

```dart
// atrust_card_test.dart
test('profileForAtr: jede der acht ATRs aus der Tabelle ergibt ihre Art; eine fremde ATR null', …);
test('profileForAtr: eine längere ATR, die mit 3BBF11008131FE45455041 beginnt, ist acos', …);
test('Befehle Byte für Byte: jede Zeile der Tabelle', …); // u. a. selectFile([0xDF,0x01]) == 00A4000C02DF01
test('readBinary(256) == 00B0010000; readBinary(0x8100) nutzt nur 7 Bits im ersten Byte', …);
test('verifyPin acosId41 mit 123456: 0020008A0826123456FFFFFFFF, secret', …);
test('verifyPin cardOs53 mit 1234: 0020008108241234FFFFFFFFFF', …);
test('verifyPin acos mit 123456: 00200081083132333435360000', …);
test('verifyPin lehnt 5 Ziffern, 7 Ziffern, Buchstaben und leer ab (ArgumentError)', …);
test('sign acosId41: 002A9E9A20 + Hash + 40; sign acos: 002A9E9A00', …);
test('CardCommand.toString nennt label, aber weder Bytes noch PIN', …);

// card_session_test.dart (mit FakeCardReader)
test('Leser auf Stufe TPDU ohne autoIfsd: Parameter 1110004600FE00, dann Blockgröße 254, dann Befehle', …);
test('ACOS-ID 2.1 (feste Geschwindigkeit): Parameter beginnen mit 96', …);
test('Leser mit autoNegotiation (0x40): keine Parameter', …);
test('Leser auf Stufe kurze APDU: Befehl geht unverändert hinaus, keine Blockgröße', …);
test('Leser auf Stufe Zeichen: readerNotSupported', …);
test('Karte mit T=0 zuerst: cardNotSupported', …);
test('Parameter scheitern: Zeile im Protokoll, die Sitzung startet trotzdem', …);
test('send(selectFile(3F00)) ergibt 9000; unbekannte Datei 6A82', …);
test('Karte gezogen während send: SessionException(connectionLost)', …);          // Review Focus 3
test('Protokoll: verifyPin zeigt 00 20 00 8A 08 ** ** ** ** ** ** ** **, die Schichten darunter [geheim, …]', …); // Review Focus 1
test('end schaltet aus und wirft nie', …);
```

- [ ] **Step 2:** FAIL. **Step 3:** Umsetzen. **Step 4:** PASS, `flutter analyze`. **Step 5:** Commit.

---

### Task 5: Zertifikat lesen und Unterschrift prüfen

**Files:**
- Create: `app/lib/rksv/card/certificate.dart`, `app/test/rksv/fixtures/test_card.dart`
- Modify: `app/pubspec.yaml` (`pointycastle`, neueste Version, die zu Dart 3.14 passt)
- Test: `app/test/rksv/card/certificate_test.dart`

**Interfaces:**
- Produces:

```dart
class CardCertificate {
  static CardCertificate parse(Uint8List der);   // FormatException, wenn es kein Zertifikat mit Schlüssel auf P-256 ist
  final Uint8List der;
  final BigInt serial;
  final String issuer;        // CN des Ausstellers, sonst der ganze Name
  final String subject;       // CN des Inhabers, sonst der ganze Name
  final DateTime notBefore, notAfter;   // UTC
  final Uint8List publicKey;  // 65 Bytes, 04 || X || Y
  bool verify(Uint8List sha256, Uint8List signature); // signature: 64 Bytes r || s, oder DER
}
int? derTotalLength(Uint8List start); // Gesamtlänge eines DER-Elements aus seinen ersten Bytes, null wenn noch unklar

// test/rksv/fixtures/test_card.dart
final Uint8List testCertificate;                       // aus karte.der.hex
Uint8List testSigner(Uint8List sha256);                // unterschreibt mit karte.d.hex, 64 Bytes r || s
```

Die Werte für `test_card.dart` stehen in `/mnt/project-files/kassa-plan/karte-quelle/test-zertifikat/` (`karte.der.hex`, `karte.d.hex`, `karte.pub.hex`). Sie sind erfunden und dürfen ins Repo. Der private Schlüssel steht als Hex-Zeichenkette im Test, nicht als PEM-Block.

Das Zertifikat wird mit dem ASN.1-Leser von `pointycastle` zerlegt: Seriennummer, Aussteller, Gültigkeit (UTCTime und GeneralizedTime), Inhaber, öffentlicher Schlüssel. Der Schlüssel muss `ecPublicKey` (1.2.840.10045.2.1) auf `prime256v1` (1.2.840.10045.3.1.7) sein. `verify` prüft ECDSA mit dem übergebenen SHA-256-Wert (der Wert wird nicht noch einmal gehasht) und gibt bei jeder kaputten Eingabe `false` zurück statt zu werfen.

- [ ] **Step 1: Failing tests**

```dart
test('Test-Zertifikat: serial 889977665544, issuer "Beispiel CA", subject "Beispiel-Imbiss Signaturkarte"', …);
test('Test-Zertifikat: notAfter 2031-06-30 23:59:59 UTC, notBefore 2026-01-01 00:00:00 UTC', …);
test('Test-Zertifikat: publicKey ist karte.pub.hex', …);
test('verify: eine Unterschrift von testSigner ist gültig, als r || s und als DER', …);
test('verify: ein gekipptes Bit im Hash, in r oder in s ist ungültig', …);
test('verify: 63 Bytes, 0 Bytes und Müll ergeben false, kein Fehler', …);
test('parse: abgeschnittenes Zertifikat und beliebige Bytes werfen FormatException', …);
test('derTotalLength: 30 82 01 77 ergibt 379; 30 10 ergibt 18; ein Byte ergibt null', …);
```

- [ ] **Step 2:** FAIL. **Step 3:** Umsetzen. **Step 4:** PASS, `flutter analyze`. **Step 5:** Commit.

---

### Task 6: Prüflauf, Bericht und PIN-Wächter

**Files:**
- Create: `app/lib/rksv/card/card_check.dart`, `app/lib/rksv/card/pin_guard.dart`, `app/lib/rksv/card/card_providers.dart`
- Test: `app/test/rksv/card/card_check_test.dart`, `app/test/rksv/card/pin_guard_test.dart`

**Interfaces:**
- Consumes: alles aus Task 1 bis 5, `appVersion`, `FlutterSecureStorage` (wie in `lib/sync/token_store.dart`)
- Produces:

```dart
// pin_guard.dart
abstract interface class PinGuard {
  Future<int?> retriesLeft(String cardNumber);        // null: kein Fehlversuch bekannt
  Future<void> recordFailure(String cardNumber, int retriesLeft);
  Future<void> clear(String cardNumber);
}
class SecurePinGuard implements PinGuard { … }        // Schlüssel 'rksv_pin_guard_<cardNumber>'
class MemoryPinGuard implements PinGuard { … }        // für Tests

// card_check.dart
enum CheckRow { reader, access, card, certificate, signature }
enum RowState { waiting, running, ok, problem, locked }
class RowResult { final RowState state; final String message; final String? hint; }
class CardCheckState {
  final Map<CheckRow, RowResult> rows;
  final bool busy;
  final bool canSign;          // Zeile 4 ist ok, die Karte ist bekannt, der Wächter erlaubt es
  final bool guardBlocks;      // der Wächter kennt nur noch einen Versuch
  final String report;
}
class CardCheck {
  CardCheck({required ReaderTransport transport, required PinGuard guard,
             required DateTime Function() now, required String appVersion});
  CardCheckState get state;
  Stream<CardCheckState> get changes;
  Future<void> run();                  // Zeilen 1 bis 4, schickt nie eine PIN
  Future<void> sign(String pin);       // Zeile 5; tut nichts, wenn !canSign
  Future<void> resetGuard();           // der Chef sagt: Zähler ist wieder voll
}
// card_providers.dart
final readerTransportProvider, shareSheetProvider, pinGuardProvider, cardCheckProvider;
```

**Ablauf von `run`:** `list` (ersten Kartenleser nehmen), `open`, Deskriptor lesen, `CardSession.start`, Art bestimmen, jede Anwendung des Profils mit `selectApplication` prüfen, Kartennummer lesen (`selectFile(3F00)`, `selectFile(numberFolder)` falls ungleich `3F00`, `selectFile(numberFile)`, `readCardNumber`), Zertifikat lesen (`selectFile(3F00)`, `selectFile(signatureFolder)`, `selectFile(certificateFile)`, dann `readBinary(0)`, `readBinary(256)`, … bis die Länge aus `derTotalLength` erreicht ist, eine Antwort kürzer als 256 Bytes kommt oder der Status nicht `9000` ist; höchstens 16 Blöcke; auf die Gesamtlänge kürzen), `CardCertificate.parse`. Am Ende immer `session.end()` und `transport.close()`. Jede Zeile wechselt sichtbar von `waiting` über `running` zum Ergebnis.

**Ablauf von `sign(pin)`:** Wächter fragen. Leser öffnen, Sitzung starten, prüfen, dass ATR und Kartennummer dieselben sind wie beim letzten `run` (sonst Zeile 3 neu mit "Das ist eine andere Karte. Prüf nochmal."), `selectFile(3F00)`, `selectFile(signatureFolder)`, bei `separateHash` `prepareSignature`, dann `verifyPin`. Antwort `9000`: Wächter löschen, unterschreiben (`putHash` und `sign` oder nur `sign`), mit dem Zertifikat prüfen, Dauer ab `verifyPin` messen. War alles gut, noch zweimal `verifyPin` und unterschreiben für die Dauer (K5). Antwort `63Cx`: Wächter merkt sich x, Schluss. Jede andere Antwort: Schluss. Unterschrieben wird der SHA-256-Wert des Textes `Kassa Karte prüfen <now als ISO-8601 UTC>`.

**Texte** (wörtlich; `<…>` wird eingesetzt):

| Zeile | Lage | `message` | `hint` |
|---|---|---|---|
| Kartenleser | gefunden | "<Name> gefunden." (ohne Namen: "Kartenleser gefunden.") | |
| | keiner | "Kein Kartenleser gefunden." | "Steckt der Leser am Verteiler, und hat der Verteiler Strom?" |
| Zugriff | erlaubt | "Die Kassa darf den Kartenleser verwenden." | |
| | abgelehnt | "Die Kassa darf den Kartenleser nicht verwenden." | "Tipp auf "Nochmal prüfen" und erlaube den Zugriff im Fenster von Android." |
| | belegt | "Der Kartenleser ist gerade belegt." | "Zieh den Leser ab, steck ihn wieder an und prüf nochmal." |
| | Leser unbekannt (`not_ccid`, Deskriptor fehlt, Stufe Zeichen) | "Diesen Kartenleser kennt die Kassa nicht." | "Teil bitte den Bericht." |
| | abgezogen | "Der Kartenleser antwortet nicht mehr." | "Steck ihn wieder an und prüf nochmal." |
| Signaturkarte | erkannt | "<label> erkannt." | `notice` des Profils |
| | keine Karte | "Keine Karte im Leser." | "Steck die Karte mit dem Chip voran bis zum Anschlag hinein." |
| | stumm | "Die Karte antwortet nicht." | "Dreh die Karte um und steck sie nochmal hinein." |
| | fremd (ATR nicht in der Tabelle, oder `cardNotSupported`) | "Die Karte antwortet, aber die Kassa kennt diese Art nicht." | "Antwort der Karte: <ATR als Hex>. Teil bitte den Bericht." |
| | Anwendung fehlt | "Auf der Karte fehlt die Signatur für Registrierkassen." | "Teil bitte den Bericht." |
| | Verbindung weg | "Die Verbindung zur Karte ist abgebrochen." | "Prüf nochmal. Bleibt es dabei, teil bitte den Bericht." |
| Zertifikat | gelesen | "Seriennummer <serial dezimal>, gültig bis <TT.MM.JJJJ>." | "Ausgestellt von <issuer>." |
| | abgelaufen | "Das Zertifikat ist am <TT.MM.JJJJ> abgelaufen." | "Die Karte muss getauscht werden." |
| | nicht lesbar | "Das Zertifikat ließ sich nicht lesen." | "Teil bitte den Bericht." |
| Probe-Unterschrift | bereit (`waiting`) | "Mit der PIN der Signaturkarte erstellt die Kassa eine Unterschrift zur Probe." | |
| | gut | "Unterschrift erstellt und geprüft. Dauer: <s,s> Sekunden." (Mittel der drei, eine Nachkommastelle, Komma) | |
| | PIN falsch, x ≥ 2 | "Die PIN war falsch. Noch <x> Versuche." | "Frag im Betrieb nach der richtigen PIN, bevor du es nochmal versuchst." |
| | PIN falsch, x ≤ 1, und Wächter sperrt | "Die PIN war falsch. Die Karte hat nur noch einen Versuch." | "Die Kassa schickt die PIN jetzt nicht mehr. Wird die Karte in der alten Kassa mit der richtigen PIN verwendet, ist der Zähler wieder voll." |
| | gesperrt (`6983`) | "Die Karte ist gesperrt." | "Wende dich an A-Trust." |
| | abgelehnt (anderer Status) | "Die Karte hat die Unterschrift abgelehnt." | "Teil bitte den Bericht." |
| | passt nicht | "Die Karte hat unterschrieben, aber die Unterschrift passt nicht zum Zertifikat." | "Teil bitte den Bericht." |
| jede | Voraussetzung fehlt (`locked`) | "Erst wenn die Zeile darüber grün ist." | |
| | über 20 Sekunden | "Das hat zu lange gedauert." | "Prüf nochmal. Bleibt es dabei, teil bitte den Bericht." |

Bei `63C0` gilt die Zeile "gesperrt". Für eine fremde Karte ist Zeile 4 `locked` und Zeile 5 `locked` mit der Nachricht "Für diese Karte ist die Probe-Unterschrift nicht freigegeben."

**Bericht** (Text, höchstens 60 000 Zeichen; ist er länger, wird die Mitte des Protokolls durch die Zeile `… gekürzt …` ersetzt):

```
Kassa: Bericht "Karte prüfen"
Version <appVersion>, <Datum und Uhrzeit>, <model>, Android <android>

Ergebnis
1 Kartenleser: <gut|Fehler|offen> <message>
… (alle fünf Zeilen)

USB-Geräte
<address> "<name>" Klasse <deviceClass> Schnittstellen <klass/subclass/protocol, …> <erlaubt|nicht erlaubt>
…

Kartenleser
Deskriptoren: <hex>
Stufe <level>, Merkmale <features hex>, Blockgröße <maxIfsd>

Karte
ATR: <hex>
Art: <label oder "unbekannt">
Kartennummer: <hex>
Zertifikat: <hex des ganzen Zertifikats>
Unterschrift: <Länge> Bytes, <gültig|ungültig>, <ms> ms, <ms> ms, <ms> ms

Protokoll
<Zeilen aus ProbeLog>
```

- [ ] **Step 1: Failing tests** (alle mit `FakeCardReader`, `MemoryPinGuard`, fester Uhr)

```dart
// card_check_test.dart
test('alles gut mit ACOS-ID 4.1 an einem TPDU-Leser: Zeilen 1 bis 4 ok, 5 wartet, canSign', …);
test('alles gut an einem APDU-Leser', …);
test('jede Art aus der Tabelle: run und sign gelingen (acos mit getrenntem Hash)', …);
test('run schickt nie VERIFY: verifyCount bleibt 0', …);                                  // Schutz der Karte
test('kein Gerät; nur ein Drucker (Klasse 07): "Kein Kartenleser gefunden.", open wird nie gerufen', …); // Review Focus 4
test('Drucker und Leser: der Leser wird geöffnet, der Bericht nennt beide Geräte', …);     // Review Focus 4
test('Erlaubnis abgelehnt: Zeile 2 Fehler, Zeilen 3 bis 5 gesperrt', …);
test('keine Karte; stumme Karte; fremde ATR; Anwendung fehlt: je der Text aus der Tabelle', …);
test('Zertifikat in zwei Blöcken (379 Bytes) wird ganz gelesen und auf 379 gekürzt', …);    // Review Focus 5
test('Zertifikat abgelaufen (Uhr nach dem 30.06.2031): Zeile 4 Fehler, canSign false', …);
test('Leser nach dem 5. Austausch abgezogen: Zeile zeigt den Fehler, close wurde gerufen, ein zweiter run gelingt', …); // Review Focus 3
test('ein Lauf, der hängt, endet nach 20 Sekunden mit "Das hat zu lange gedauert." und gibt den Leser frei', …); // fake_async
test('sign mit richtiger PIN: Zeile 5 ok mit Dauer, verifyCount 3, Wächter leer', …);
test('sign mit falscher PIN: genau ein VERIFY, "Noch 2 Versuche.", kein Befehl danach außer Ausschalten', …); // Review Focus 2
test('zweite falsche PIN: "nur noch einen Versuch", guardBlocks, canSign false', …);
test('guardBlocks übersteht eine neue CardCheck-Instanz (SecurePinGuard-Ersatz mit gemeinsamem Speicher)', …); // Review Focus 2
test('sign bei guardBlocks schickt nichts; nach resetGuard geht es wieder', …);
test('gesperrte Karte (6983): Text aus der Tabelle, kein zweites VERIFY', …);
test('Unterschrift passt nicht zum Zertifikat: Text aus der Tabelle', …);
test('WTX vor der Unterschrift wird verkraftet', …);                                       // Review Focus 5
test('ein verfälschtes Prüfbyte beim Zertifikat-Lesen wird verkraftet', …);                // Review Focus 5
test('ein verfälschtes Prüfbyte in der Antwort auf VERIFY: Zeile 5 "Verbindung … abgebrochen", kein zweites VERIFY', …); // Review Focus 2
test('andere Karte zwischen run und sign: kein VERIFY, Zeile 3 "Das ist eine andere Karte. Prüf nochmal."', …);
test('sign ohne vorheriges run und sign bei fremder Karte tun nichts', …);
test('Bericht nach sign mit PIN 493817: enthält weder 493817 noch 26493817 noch 343933383137 (Groß/Klein, mit und ohne Leerzeichen)', …); // Review Focus 1
test('Bericht enthält ATR, Deskriptoren, Zertifikat, die fünf Zeilen und die Dauer', …);
test('Bericht über 60 000 Zeichen wird in der Mitte gekürzt', …);
// pin_guard_test.dart
test('recordFailure, retriesLeft, clear; getrennt je Kartennummer', …);
```

- [ ] **Step 2:** FAIL. **Step 3:** Umsetzen. **Step 4:** PASS, `flutter analyze`. **Step 5:** Commit.

---

### Task 7: Bildschirme "Signatur" und "Karte prüfen"

**Files:**
- Create: `app/lib/features/settings/signature_panel.dart`, `app/lib/features/settings/card_check_screen.dart`, `app/lib/features/settings/card_pin_sheet.dart`
- Modify: `app/lib/features/settings/settings_screen.dart`, `app/lib/features/shell/shell_screen.dart` (dritte Seite neben "Geräte testen", Zurück-Geste wie dort), `app/test/support/settings_pump.dart`
- Test: `app/test/features/card_check_test.dart`, `app/test/golden/card_check_golden_test.dart`

**Interfaces:**
- Consumes: `cardCheckProvider`, `shareSheetProvider`, `CardCheckState`, `CheckRow`, `RowState` (Task 6), `Keypad`, `SettingsCard`, `SettingsRow`, `NeutralPill`, `WarnBox`, `Pressable`; Bilder aus Task 0
- Produces: `SignaturePanel`, `CardCheckScreen({required VoidCallback onBack})`, `showCardPinSheet(BuildContext) → Future<String?>`

**Einstellungen:** Neue Karte "Signatur" in der linken Spalte unter "Geräte an dieser Kassa". Zeile 1: Titel "Signatur der Bons", Hilfe "Für die Registrierkassen-Pflicht. Noch nicht eingerichtet.", rechts die ruhige Pille "Nicht eingerichtet". Zeile 2 zum Antippen (Key `open-card-check`): Titel "Karte prüfen", Hilfe "Kartenleser und Signaturkarte ausprobieren.", rechts der Pfeil.

**"Karte prüfen":** Kopf wie "Geräte testen" (Zurück, Titel "Karte prüfen"). Darunter der Satz "Hier siehst du, ob Tablet, Verteiler, Kartenleser und Signaturkarte zusammenarbeiten. Auf der Karte wird nichts verändert." und klein darunter "Steckt die Karte sonst in der alten Kassa, kann dort in dieser Zeit kein Bon erstellt werden." Dann fünf Zeilen mit Nummer, Titel ("Kartenleser", "Zugriff", "Signaturkarte", "Zertifikat", "Probe-Unterschrift"), Zeichen für den Zustand (wartet: leerer Kreis, läuft: ruhiger Fortschritt, gut: Haken, Fehler: Kreuz, gesperrt: Schloss; nie nur Farbe), `message` und `hint`. In Zeile 5 die Taste "PIN eingeben" (Key `card-check-pin`), nur wenn `canSign`. Bei `guardBlocks` statt dessen die Taste "Zähler ist wieder voll" (Key `card-check-reset-guard`), die erst nach der Rückfrage "Wurde die Karte seit dem Fehlversuch in der alten Kassa mit der richtigen PIN verwendet? Ist die nächste PIN falsch, sperrt sich die Karte." mit "Ja, Zähler ist wieder voll" und "Abbrechen" wirkt. Unten die Hauptaktion (Key `card-check-run`): vor dem ersten Lauf "Jetzt prüfen", danach "Nochmal prüfen", während eines Laufs gesperrt; daneben "Bericht teilen" (Key `card-check-share`), sobald ein Lauf fertig ist. Teilen ruft `ShareSheet.text(subject: 'Kassa: Bericht Karte prüfen', text: report)`; gibt es `false`, erscheint der Hinweis "Teilen geht auf diesem Tablet nicht." Beim Verlassen des Bildschirms läuft ein Lauf zu Ende und gibt den Leser frei.

**PIN-Fenster:** Titel "PIN der Signaturkarte". Warnfeld: "Das ist nicht deine Chef-PIN. Nach drei falschen Versuchen sperrt sich die Karte." Sechs Plätze, gefüllte zeigen einen Punkt, nie die Ziffer. Zahlenfeld `Keypad` mit Löschen. Tasten "Abbrechen" und "Unterschrift erstellen" (Key `card-pin-submit`), die zweite nur bei 4 oder 6 Ziffern aktiv. Nichts wird von selbst abgeschickt. Die Semantik der Plätze sagt "<n> von 6 Ziffern eingegeben", nie die Ziffern. Das Fenster gibt die PIN zurück und behält sie nicht.

- [ ] **Step 1: Failing tests**

```dart
// card_check_test.dart (Widget-Tests mit FakeCardReader über die Provider)
testWidgets('Einstellungen zeigen die Karte "Signatur" mit "Nicht eingerichtet"; Tippen öffnet "Karte prüfen"', …);
testWidgets('vor dem Start: fünf wartende Zeilen, Taste "Jetzt prüfen", kein "Bericht teilen"', …);
testWidgets('"Jetzt prüfen": Zeilen 1 bis 4 werden grün, Taste heißt "Nochmal prüfen", "PIN eingeben" erscheint', …);
testWidgets('das Öffnen des Bildschirms startet keinen Lauf und fragt keine Erlaubnis an', …);
testWidgets('PIN-Fenster: 5 Ziffern lassen "Unterschrift erstellen" gesperrt, 4 und 6 geben frei, 7. Ziffer wird verworfen', …);
testWidgets('PIN-Fenster: weder Text noch Semantik enthalten die Ziffern', …);            // Review Focus 1
testWidgets('richtige PIN: Zeile 5 grün mit Dauer', …);
testWidgets('falsche PIN: Text "Noch 2 Versuche.", das PIN-Fenster öffnet sich nicht von selbst wieder', …); // Review Focus 2
testWidgets('guardBlocks: "PIN eingeben" fehlt, "Zähler ist wieder voll" wirkt erst nach "Ja, …"', …);
testWidgets('"Bericht teilen" übergibt Betreff und Bericht; false zeigt den Hinweis', …);
testWidgets('keine Karte: Zeile 3 mit Kreuz und Hinweis, Zeilen 4 und 5 mit Schloss', …);
testWidgets('Zurück (Taste und Geste) führt zu den Einstellungen', …);
testWidgets('Tippflächen: alle Tasten mindestens 48 dp', …);
// golden: karte_pruefen_start_hell, karte_pruefen_gut_hell, karte_pruefen_gut_dunkel,
//         karte_pruefen_keine_karte_hell, karte_pruefen_pin_hell, einstellungen_signatur_hell
```

- [ ] **Step 2:** FAIL. **Step 3:** Umsetzen nach den Bildern aus Task 0. **Step 4:** PASS (auch `test/no_text_field_test.dart` und die bestehenden Golden-Tests der Einstellungen, deren Bilder sich durch die neue Karte ändern und neu erzeugt werden), `flutter analyze`. **Step 5:** Commit.

---

### Task 8: Prüfliste, Version 1.3.0, Installationsdatei

**Files:**
- Create: `docs/testen/rksv-karte-pruefen-pruefliste.md`
- Modify: `app/pubspec.yaml` (`version: 1.3.0+5`), `docs/superpowers/specs/2026-11-18-rksv-signatur-design.md` (neuer Abschnitt "Abweichungen beim Bau" mit K1 bis K7 und der Freigabe von Zeile 5; Punkt 2 in Abschnitt 9 als erledigt)

**Prüfliste für Niko** (einfache Worte, zum Abhaken, je Schritt "Das solltest du sehen"):
1. Was du brauchst: Tablet mit Version 1.3.0, Verteiler mit Stromanschluss, USB-Kartenleser, die Signaturkarte von YICHI und ihre PIN. Hinweis: Die Karte steckt sonst in der alten Kassa, also außerhalb der Öffnungszeit testen und die Karte danach zurückstecken.
2. Einstellungen, "Karte prüfen", "Jetzt prüfen". Android fragt nach dem Zugriff: erlauben.
3. Zeilen 1 bis 4 grün. Welche Kartenart steht da, und steht ein Hinweis zum Tausch dabei?
4. "PIN eingeben". **Nur wenn du die PIN sicher weißt.** Bei "Die PIN war falsch" nicht raten, sondern im Betrieb nachfragen.
5. Zeile 5 grün, Dauer notieren.
6. "Bericht teilen" und den Text in den Thread schicken (Mail an dich selbst und einfügen geht auch). Die PIN steht nicht im Bericht.
7. Gegenprobe: Drucker am selben Verteiler, Testdruck unter "Geräte testen" geht weiter.
8. Wenn eine Zeile rot ist: den Hinweis befolgen, einmal "Nochmal prüfen", dann den Bericht schicken.

- [ ] **Step 1:** Prüfliste schreiben, Version hochsetzen, Entwurf ergänzen.
- [ ] **Step 2:** Alle Tests (`flutter test`), `flutter analyze`.
- [ ] **Step 3:** `../tool/build_apk.sh arm64` mit `server.properties` wie bei 1.2.0. Die Datei wird nicht committet und nicht in `download/` gelegt (sie enthält die Server-Adresse). Größe und SHA-256 in den Bericht der Aufgabe.
- [ ] **Step 4:** Commit. Das Hochladen auf den Server und die Nachricht an Niko macht Claude selbst.
