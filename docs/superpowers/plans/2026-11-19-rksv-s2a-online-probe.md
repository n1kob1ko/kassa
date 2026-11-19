# RKSV S2a: Online-Probe mit A-Trust Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Im Zustand "Online-Probe" lässt die Kassa jeden Bon über das Testsystem von A-Trust (a.sign RK HSM) signieren, zeigt mit "Verbindung prüfen", ob Tablet, Internet und A-Trust zusammen funktionieren, und kann das Konto bei A-Trust nie von selbst sperren. Die Bons bleiben Testbons.

**Architecture:** Unter `app/lib/rksv/online/` liegen drei Schichten ohne Oberfläche: ein Client, der genau die Web-Anfragen von A-Trust kennt; ein Sitzungshalter, der sich im Voraus anmeldet, nie doppelt und nach einer Ablehnung nie wieder von selbst; und die `OnlineSignatureUnit`, die die vorhandene Schnittstelle `SignatureUnit` erfüllt (Hashwert hin, 64 Bytes zurück, am Tablet gegen das Zertifikat geprüft). Die Kette merkt sich ihre Einheit; das `RksvJournal` bleibt, wie es ist, und bekommt nur die passende Einheit gereicht.

**Tech Stack:** Flutter 3.50.0, drift (Datenbank Version 5 mit Migration), `http` und `pointycastle` (beide schon im Projekt). Keine neuen Pakete, kein Kotlin, keine Änderung am Server. Ein eigener GitHub-Workflow für den Lauf gegen das Testsystem.

**Spec:** `docs/superpowers/specs/2026-11-19-rksv-online-signatur-design.md` (Abschnitte 6.1 bis 6.6, 6.8 bis 6.10, 7, 8, 9 Punkte 5 bis 7). Dazu der Kern `docs/superpowers/specs/2026-11-18-rksv-signatur-design.md`, `docs/design-regeln.md`, `DESIGN.md`, `PRODUCT.md`. Handbuch von A-Trust: `/mnt/project-files/kassa-plan/atrust/asignRKHSM_DE.txt` (Kopie des Handbuchs 3.1 als Text, nie ins Repo).

## Wo dieser Plan steht

| Plan | Inhalt | Stand |
|---|---|---|
| S1a, S1b | "Karte prüfen" (1.3.0), Kern mit Probe-Signatur (1.4.0) | ausgeliefert |
| **S2a (dieser Plan)** | Online-Probe, Version 1.5.0 Build 7 | geschrieben, wartet auf Nikos Freigabe des Entwurfs |
| S2b | Einrichtung mit echtem Konto, Angaben für FinanzOnline, Inbetriebnahme | eigener Plan nach Nikos Ergebnis aus S2a |
| S3 | Inbetriebnahme bei YICHI | durch Niko |

## Was vor dem Schreiben geprüft wurde (19.11.2026)

- **Handbuch 3.1 von A-Trust ganz gelesen.** Alle Adressen, Felder und Statuscodes unten stammen daraus. Am System probiert ist noch nichts: `hs-abnahme.a-trust.at` ist aus der Arbeitsumgebung gesperrt. Task 1 holt das über GitHub nach.
- **Vorhanden und zu verwenden:** `SignatureUnit`, `SignerInfo`, `SignatureFailure` (`app/lib/rksv/signature_unit.dart`); `RksvJournal` mit `SignatureUnitOf` und den Fristen 5 s und 1 s; `CardCertificate.parse` mit `publicKey`, `serial`, `issuer`, `notBefore`, `notAfter` und der Prüfung einer Signatur (`app/lib/rksv/card/certificate.dart`); `certificateSerialHex`; `rksv_certificates.issuers` (JSON-Liste, Base64) und ihre Ausgabe in `buildDepExport`; `ShareSheet`; `CardCheckScreen` als Vorlage für einen Prüf-Bildschirm; `RksvRig`, `FakeSignatureUnit`, `MemoryRksvSecrets` für Tests.
- **`workflow_dispatch` startet nur Workflows, die auf dem Hauptzweig liegen.** Der Zweig `claude/project-thread-xtooco` ist nicht der Hauptzweig. Der Lauf gegen das Testsystem startet deshalb bei `push`, wenn sich bestimmte Pfade ändern.

## Entscheidungen in diesem Plan (Claude)

| Nr. | Entscheidung | Warum | Preis |
|---|---|---|---|
| P1 | Das Kennzeichen "Zugangsdaten abgelehnt" liegt im geschützten Speicher (`RksvSecrets`), nicht in der Datenbank. | Signiert wird in der Transaktion des Bons. Eine Anmeldung im Hintergrund, die in die Datenbank schreiben will, müsste auf diese Transaktion warten. Der geschützte Speicher kennt keine Transaktionen. | Die Oberfläche liest das Kennzeichen über den Sitzungshalter, nicht über `RksvRepository.watch()`. Weicht von Entwurf 6.9 ab ("Der Stand bekommt das Kennzeichen"). |
| P2 | Die Online-Einheit wandelt jeden eigenen Fehler in `SignatureFailure` mit einem deutschen Satz. Das Journal übernimmt diesen Satz als Grund des Ausfalls (bisher ein fester Satz). | Entwurf 7: Der Grund steht im Hinweis. | Bei abgelaufener Frist bleibt der Satz des Journals "Die Signatur hat nicht geantwortet.", weil das Journal die Einheit nicht kennt. |
| P3 | "Verbindung prüfen" läuft vor dem Einschalten und außerhalb jeder Transaktion. Der Startbeleg wird danach wie jeder Bon in der Transaktion signiert, mit 5 Sekunden Frist. | Kern K1 bleibt. | Fällt das Netz zwischen Prüfung und Startbeleg aus, beginnt keine Kette, und der Chef tippt noch einmal. |
| P4 | Kern K9 (die Probe schaltet sich nach einem unerwarteten Fehler ab) gilt weiter für beide Arten der Probe, aber nur für Fehler außerhalb der Einheit (etwa ein nicht lesbarer AES-Schlüssel). | Die Kassa verkauft immer. | Keiner. |
| P5 | Task 1 (Erkundung) läuft zuerst und macht der Controller. Seine Befunde trägt er unter "Befunde aus Task 1" in diesen Plan ein, bevor Task 2 beginnt. Widerspricht ein Befund einer Annahme unten, ändert der Controller die betroffene Zeile und hält es im Protokoll fest. | Die Form der Antworten ist im Handbuch nicht vollständig beschrieben. | Task 2 wartet auf einen GitHub-Lauf. |
| P6 | Der Test-Benutzer von A-Trust (`u123456789` / `123456789`) und der gesperrte Test-Benutzer (`u039193334` / `60z7dx`) stehen als Konstanten im Code. | Beide sind öffentlich (Handbuch 4). Die Online-Probe braucht kein Tippen. | Jeder kann damit signieren. Deshalb bleibt alles Testbon. |
| P7 | Eine Sitzung gilt als abgelaufen nach 55 Minuten ohne Benutzung oder bei neuem Kalendertag (Ortszeit des Tablets). | Entwurf 6.2. A-Trust sagt 60 Minuten und Mitternacht. | Liegt Mitternacht bei A-Trust anders als am Tablet, fängt Schritt "401 beim Signieren, einmal neu anmelden" es auf. |
| P8 | Kein eigenes Zertifikat von A-Trust in der App. Vertraut GitHub dem HTTPS-Zertifikat nicht, hält der Bau nach Task 1 an, und der Controller meldet sich bei Niko. | Entwurf 9, Punkt 5. | S2a kann an Task 1 enden. |

## Global Constraints

- **Die Kassa verkauft immer.** Kein Fehler von Netz, A-Trust, geschütztem Speicher oder Protokoll darf einen Verkauf oder ein Storno verhindern oder länger als die Frist verzögern (5 Sekunden, während eines Ausfalls 1 Sekunde).
- **Schutz des Kontos.** Nach 401 oder 403 auf eine Anmeldung schickt die Kassa keine einzige Anfrage mehr an A-Trust, bis der Chef in den Einstellungen ausdrücklich tippt. Jedes Tippen ist genau eine Anmeldung. Das gilt nach einem Neustart weiter, und es gilt für "Nochmal prüfen" in der Kassa, für die Anmeldung im Hintergrund und für jeden Bon.
- **Geheimnisse.** Passwort und Sitzungsschlüssel stehen nie in der Datenbank, in einem Log, in `toString`, in einer Fehlermeldung, im Bericht von "Verbindung prüfen" oder im ausgegebenen Protokoll. Der Sitzungsschlüssel liegt nur im Arbeitsspeicher.
- **Testsystem heißt Testbon.** Eine Kette mit der Einheit `atrustTest` hat immer den Modus `probe`. Die Adresse des echten Systems wird in S2a nirgends angesprochen.
- **Adressen fest im Code**, immer HTTPS: Test `https://hs-abnahme.a-trust.at/asignrkonline/v2`, echt `https://rksv.a-trust.at/asignrkonline/v2`.
- **Kette ohne Lücke und ohne Doppel**, wie im Kern.
- **Touch-Regel:** kein Textfeld (`app/test/no_text_field_test.dart` bleibt grün). Tasten in Zeilen 56 dp, in Blättern mindestens 64 dp, Hauptaktionen 76 dp (Kern R5).
- **Öffentliches Repo:** nichts aus `/mnt/project-files/`, keine Dateien des Finanzministeriums, keine echten Zugangsdaten.
- **Unteraufträge** führen nie `git clean`, `git reset --hard`, `git checkout -- .`, `git stash` oder ein Formatieren des ganzen Repos aus, erzeugen Vergleichsbilder nie für die ganze Suite neu und ändern die Version nicht.
- **Tests:** lokal nur die betroffenen Dateien (`flutter test <Datei>`), die ganze Suite läuft auf GitHub (Lauf `app`). `flutter analyze` ohne Befund.
- **Sätze am Bildschirm** in einfachem Deutsch, ohne Fachwörter, nach `docs/design-regeln.md`.

## Review Focus

1. **Antwort nach der Frist.** Kommt die Antwort von A-Trust, nachdem das Journal aufgegeben hat, darf nichts mehr in die Datenbank geschrieben werden und keine Ausnahme unbehandelt bleiben. Eine dabei erhaltene Sitzung darf bleiben. Test in Task 3.
2. **Zwei Anmeldungen zugleich.** Ein Bon und die Anmeldung im Hintergrund fragen gleichzeitig nach einer Sitzung: Es geht genau ein `PUT Session` hinaus. Test in Task 3.
3. **Abgelaufene Sitzung.** 401 beim Signieren führt zu genau einer neuen Anmeldung und genau einem zweiten Versuch, nie zu einer Schleife. Eine Sitzung von gestern oder älter als 55 Minuten wird nicht verwendet. Tests in Task 3.
4. **Abgelehnt bleibt abgelehnt.** Nach 401 oder 403 beim Anmelden: kein Netzverkehr bei Bon, "Nochmal prüfen", Start der App, Rückkehr in die App. Erst das Antippen des Chefs hebt es auf. Tests in Task 3 und Task 6.
5. **Unerwartete Antworten.** Signatur in Base64 und in Base64-URL, mit und ohne `=`; falsche Länge; leeres oder kaputtes JSON; fehlende Felder; eine Signatur, die nicht zum Zertifikat passt: immer `SignatureFailure` mit Satz, nie ein anderer Fehler. Tests in Task 2 und Task 3.

## Befunde aus Task 1

Lauf `atrust-testsystem` Nummer 1 am 19.11.2026 (Commit 16f08ca), bestanden.

| Punkt | Befund | Folge |
|---|---|---|
| HTTPS | GitHub vertraut dem Zertifikat von `hs-abnahme.a-trust.at`. | P8 greift nicht. Das Tablet zeigt es in "Verbindung prüfen". |
| `ZDA` | 200, `{"zdaid":"AT1"}`, `application/json; charset=utf-8`. | Kennzeichen der Online-Probe ist `AT1`. |
| `Certificate` | 200. Felder `Signaturzertifikat`, `Zertifizierungsstellen` (2 Stück), `Zertifikatsseriennummer` (`559528438`), `ZertifikatsseriennummerHex` (`2159B9F6`, Großbuchstaben), `alg` (`ES256`). Inhaber `UID: ATU12345678`, Aussteller `a-sign-Premium-Test-Sig-02`. | Vergleich der Seriennummer ohne Groß- und Kleinschreibung, wie geplant. |
| **Gültigkeit** | Das Zertifikat des Test-Benutzers ist **abgelaufen**: gültig 10.03.2016 bis 10.05.2020. | "Verbindung prüfen" darf am Testsystem ein abgelaufenes Zertifikat nicht als Problem melden (Task 5 geändert). Weicht von Entwurf 6.6 ab ("heute gültig"); für das echte System bleibt die Prüfung. |
| Aussteller-Zertifikate | Beide haben RSA-Schlüssel. `CardCertificate.parse` lehnt sie ab (nur P-256). | Aussteller-Zertifikate werden nur gespeichert und ausgegeben, nie mit `CardCertificate.parse` gelesen. |
| Anmelden | 200, Felder `sessionid` (32 Zeichen) und `sessionkey` (44 Zeichen). | wie geplant |
| `Sign/Hash` | 200, Feld `signature`, **Base64-URL ohne `=`**, 64 Bytes, passt zum Zertifikat. Dauer von GitHub aus 125 bis 129 ms je Signatur. | Der Client nimmt weiter beide Alphabete an. |
| Unbekannte Sitzung | 401, Körper ist eine HTML-Seite ("401 - Unauthorized"), kein JSON. | Fehler nur am Statuscode erkennen, den Körper bei Status ungleich 200 nie lesen. |
| Gesperrter Benutzer | 403, HTML-Seite. | wie geplant (`rejected`) |
| Abmelden | 200, `{"result":true}`. **Danach signiert dieselbe Sitzung weiter mit 200.** | Auf das Abmelden ist kein Verlass. Task 8 Punkt 3 geändert: der Weg "401, neu anmelden" wird am Testsystem mit einer erfundenen Sitzung geprüft. |
| Unbekannte Adresse | 404, HTML-Seite. | `server` |

Der frühe Lauf des Prüfwerkzeugs von Hand (Task 1, Step 4) ist entfallen: Ohne Zugang zum Testsystem lässt sich von hier keine Signatur erzeugen. Die Frage klärt Task 8.

---

### Task 0: Bilder (macht der Controller, kein Unterauftrag)

Zeichnet die neuen Bildschirme im bestehenden Stil und zeigt sie Niko, ohne auf Antwort zu warten: Karte "Signatur" im Zustand "Nicht eingerichtet" mit der neuen Zeile, im Zustand "Online-Probe", mit Ausfall und Grund, mit abgelehnten Zugangsdaten; Blatt "Mit A-Trust ausprobieren?"; Bildschirm "Verbindung prüfen" (läuft, vier Haken, Kreuz in Zeile 1, Kreuz in Zeile 3). Die Bilder liegen unter `/mnt/project-files/kassa-entwurf/rksv/s2a-*.png` (erzeugt mit `zeichnen_s2a.py` im selben Ordner) und gehen als Vorlage an Task 6 und Task 7.

### Task 1: Erkundung des Testsystems (macht der Controller)

**Files:**
- Create: `.github/workflows/atrust-testsystem.yml`
- Create: `app/test/rksv/online/atrust_testsystem_test.dart`

- [ ] **Step 1: Workflow.** Name `atrust-testsystem`. Auslöser: `push` auf jeden Zweig mit `paths`: `app/lib/rksv/online/**`, `app/test/rksv/online/**`, `.github/workflows/atrust-testsystem.yml`; dazu `workflow_dispatch`. Ein Job auf `ubuntu-latest` wie in `app.yml` (Checkout, `subosito/flutter-action@v2` mit `flutter-version-file: app/.flutter-version`, `flutter pub get`), dann `flutter test test/rksv/online/atrust_testsystem_test.dart` mit `KASSA_ATRUST_TEST: '1'`.
- [ ] **Step 2: Erkundungstest.** Läuft nur mit `KASSA_ATRUST_TEST=1`, sonst `markTestSkipped`. Mit `package:http` direkt, ohne Code der App. Er druckt mit `print` (nie den Sitzungsschlüssel):
  - `GET /u123456789/ZDA`: Status, Körper.
  - `GET /u123456789/Certificate`: Status, Namen der Felder, `alg`, beide Seriennummern, Zahl der Aussteller-Zertifikate, Aussteller, Inhaber, gültig von und bis (mit `CardCertificate.parse`), das Zertifikat selbst in Base64.
  - `PUT /Session/u123456789`: Status, Namen der Felder, Länge von `sessionid` und `sessionkey`.
  - `POST /Session/{id}/Sign/Hash` mit dem SHA-256 von `Kassa Erkundung` in Base64: Status, Namen der Felder, die Signatur, ihr Alphabet (enthält `+` `/` oder `-` `_`, endet auf `=`), Länge nach dem Dekodieren, ob sie zum Zertifikat passt, Dauer in Millisekunden. Zehn Mal hintereinander, Dauer je Aufruf.
  - `POST /Session/unbekannt/Sign/Hash`: Status und Körper (so sieht "Sitzung abgelaufen" aus).
  - `PUT /Session/u039193334` mit `60z7dx`, **ein** Mal: Status und Körper (so sieht "gesperrt" aus).
  - `DELETE /Session/{id}`: Status, Körper.
  - Ein Aufruf an eine Adresse, die es nicht gibt (`/u123456789/Nichts`): Status.
  Kein Aufruf mit einem falschen Passwort für `u123456789`: Das Konto teilen sich alle Tester.
- [ ] **Step 3:** Committen, pushen, den Lauf abwarten, die Ausgabe lesen (`get_job_logs`).
- [ ] **Step 4:** Befunde oben eintragen: Kennzeichen des Ausstellers, Form der Signatur, Körper der Fehler, Dauern, ob GitHub dem HTTPS-Zertifikat vertraut (sonst P8). Mit dem Zertifikat aus der Ausgabe von Hand eine kleine Datei für das Prüfwerkzeug bauen und laufen lassen, um Entwurf 9 Punkt 7 früh zu klären (Ergebnis eintragen; ein FAIL hält den Bau nicht an).

### Task 2: Client für A-Trust

**Files:**
- Create: `app/lib/rksv/online/atrust_client.dart`
- Test: `app/test/rksv/online/atrust_client_test.dart`

**Interfaces:**
- Consumes: `package:http` (`http.Client`), `CardCertificate.parse`.
- Produces:

```dart
enum AtrustSystem {
  test('https://hs-abnahme.a-trust.at/asignrkonline/v2'),
  live('https://rksv.a-trust.at/asignrkonline/v2');
  const AtrustSystem(this.base);
  final String base;
}

/// Öffentliche Test-Benutzer aus dem Handbuch von A-Trust (P6).
const atrustTestUser = 'u123456789';
const atrustTestPassword = '123456789';

final class AtrustCertificate {
  final Uint8List certificateDer;
  final List<Uint8List> issuersDer;
  final String serialHex; // wie A-Trust sie nennt, Kleinbuchstaben, ohne führende Nullen
  final String alg;
}

/// toString nennt weder id noch key.
final class AtrustSession { final String id; final String key; }

enum AtrustProblem { noInternet, untrusted, rejected, sessionExpired, server, unreadable }

/// [sentence] ist ein deutscher Satz ohne Geheimnisse. toString nennt nur problem.
final class AtrustException implements Exception {
  final AtrustProblem problem;
  final int? status;
  String get sentence;
}

class AtrustClient {
  AtrustClient(http.Client client, this.system);
  final AtrustSystem system;
  Future<String> zdaId(String user);
  Future<AtrustCertificate> certificate(String user);
  Future<AtrustSession> login(String user, String password);
  Future<Uint8List> signHash(AtrustSession session, Uint8List sha256); // 64 Bytes R|S
  Future<void> logout(AtrustSession session);
}
```

Anfragen und Antworten (Handbuch 2.4.1, 2.4.2, 2.4.4, 2.5, 2.7), alle mit `Content-Type: application/json`:

| Methode | Anfrage | Antwort |
|---|---|---|
| `zdaId` | `GET {base}/{user}/ZDA` | `{"zdaid":"AT1"}` |
| `certificate` | `GET {base}/{user}/Certificate` | `Signaturzertifikat` (Base64 DER), `Zertifizierungsstellen` (Liste Base64), `ZertifikatsseriennummerHex`, `alg` |
| `login` | `PUT {base}/Session/{user}` mit `{"password":…}` | `sessionid`, `sessionkey` |
| `signHash` | `POST {base}/Session/{id}/Sign/Hash` mit `{"sessionkey":…,"hash":<Base64 des SHA-256>}` | `signature` |
| `logout` | `DELETE {base}/Session/{id}` | `{"result":true}` |

Zuordnung der Fehler:

| Was | `AtrustProblem` | Satz |
|---|---|---|
| `SocketException`, `http.ClientException` | `noInternet` | `Kein Internet.` |
| `HandshakeException`, `TlsException` | `untrusted` | `Das Tablet vertraut dem Zertifikat von A-Trust nicht.` |
| 401 oder 403 bei `login` | `rejected` | `A-Trust hat die Zugangsdaten abgelehnt.` |
| 401 oder 403 bei `signHash` | `sessionExpired` | `Die Anmeldung bei A-Trust ist abgelaufen.` |
| jeder andere Status außer 200 | `server` | `A-Trust meldet einen Fehler.` |
| 200 mit kaputtem JSON, fehlendem Feld, Signatur nicht 64 Bytes, Zertifikat nicht lesbar | `unreadable` | `Die Antwort von A-Trust war nicht lesbar.` |

`signHash` nimmt die Signatur in Base64 und in Base64-URL an, mit und ohne `=`. Die Seriennummer wird aus dem Zertifikat selbst gelesen (`certificateSerialHex`); weicht `ZertifikatsseriennummerHex` davon ab (ohne Groß- und Kleinschreibung, ohne führende Nullen), ist das `unreadable`. Der Client setzt keine eigene Frist; die setzt der Aufrufer.

- [ ] **Step 1: Tests schreiben** mit `MockClient` aus `package:http/testing.dart`: je Methode die genaue Adresse, Methode, Kopfzeile und der Körper der Anfrage; je Zeile der Fehlertabelle ein Test; Signatur in vier Schreibweisen (Base64, Base64-URL, mit, ohne `=`); Signatur mit 63 und 70 Bytes; leerer Körper; `AtrustSession('abc','geheim').toString()` und `AtrustException(...).toString()` enthalten weder `geheim` noch das Passwort; ein Benutzername mit Leerzeichen wird in der Adresse kodiert.
- [ ] **Step 2:** `flutter test test/rksv/online/atrust_client_test.dart`, erwartet: FAIL (Datei fehlt).
- [ ] **Step 3: Client schreiben.**
- [ ] **Step 4:** Test erneut, erwartet: PASS. `flutter analyze`.
- [ ] **Step 5: Commit.**

### Task 3: Sitzungshalter und Online-Einheit

**Files:**
- Create: `app/lib/rksv/online/atrust_session_keeper.dart`
- Create: `app/lib/rksv/online/online_signature_unit.dart`
- Modify: `app/lib/rksv/rksv_secrets.dart` (Kennzeichen "abgelehnt")
- Test: `app/test/rksv/online/atrust_session_keeper_test.dart`, `app/test/rksv/online/online_signature_unit_test.dart`
- Create: `app/test/support/fake_atrust.dart` (nachgebauter A-Trust für Tests)

**Interfaces:**
- Consumes: `AtrustClient`, `AtrustSession`, `AtrustException`, `Clock`, `SignatureUnit`, `SignerInfo`, `SignatureFailure`, `CardCertificate`.
- Produces:

```dart
// rksv_secrets.dart, in RksvSecrets, SecureRksvSecrets (Schlüssel 'rksv_atrust_rejected')
// und MemoryRksvSecrets:
Future<bool> atrustRejected();
Future<void> writeAtrustRejected(bool rejected);

class AtrustSessionKeeper {
  AtrustSessionKeeper({
    required AtrustClient client,
    required String user,
    required String password,
    required RksvSecrets secrets,
    required Clock clock,
  });

  /// Lädt das gespeicherte Kennzeichen. Vor dem ersten Gebrauch aufrufen.
  Future<void> restore();

  /// Wahr nach 401 oder 403 auf eine Anmeldung, bis [allowOneLogin].
  ValueListenable<bool> get rejected;

  /// Gültige Sitzung, sonst anmelden. Nie zwei Anmeldungen zugleich.
  /// Wirft AtrustException; bei [rejected] sofort, ohne Netz.
  Future<AtrustSession> session();

  /// Anmelden im Hintergrund, wenn keine gültige Sitzung da ist. Wirft nie.
  void warmUp();

  /// Nach erfolgreichem Signieren: Die Sitzung gilt wieder 55 Minuten.
  void used(AtrustSession session);

  /// Die Sitzung gilt nicht mehr (401 beim Signieren).
  void drop(AtrustSession session);

  /// Nur nach ausdrücklichem Antippen des Chefs: hebt [rejected] auf.
  Future<void> allowOneLogin();
}

class OnlineSignatureUnit implements SignatureUnit {
  OnlineSignatureUnit({
    required AtrustClient client,
    required AtrustSessionKeeper keeper,
    required String zdaId,
    required Uint8List certificateDer,
    List<Uint8List> issuerCertificatesDer = const [],
  });
}

// fake_atrust.dart
class FakeAtrust {
  /// Schlüsselpaar und selbst ausgestelltes Zertifikat wie FakeSignatureUnit.
  http.Client get client;           // MockClient
  List<String> requests;            // 'PUT /Session/u123456789', …
  int loginStatus = 200;            // 401, 403 einstellbar
  bool expireSessions = false;      // nächster Sign-Aufruf: 401
  Duration delay = Duration.zero;   // Antwort verzögern (fake_async)
  bool offline = false;             // SocketException
  bool wrongSignature = false;      // gültige Form, falscher Schlüssel
}
```

Regeln der Einheit (`sign`): SHA-256 der ASCII-Bytes; `keeper.session()`; `client.signHash`; bei `sessionExpired` `keeper.drop`, noch einmal `keeper.session()` und `signHash`, ein zweites `sessionExpired` ist ein Fehler; Signatur mit dem öffentlichen Schlüssel des Zertifikats prüfen, sonst `SignatureFailure('Die Signatur von A-Trust passt nicht zum Zertifikat.')`; nach Erfolg `keeper.used`. Jede `AtrustException` wird zu `SignatureFailure(e.sentence)`, jeder andere Fehler zu `SignatureFailure('Die Signatur von A-Trust ist gescheitert.')`. Scheitert ein Versuch, weil keine Sitzung da war, ruft die Einheit `keeper.warmUp()`. `info()` antwortet ohne Netz aus den übergebenen Werten; `serialHex` kommt aus `certificateSerialHex`.

Regeln des Halters: P7; `rejected` wird bei `AtrustProblem.rejected` gesetzt und mit `writeAtrustRejected(true)` gespeichert, ohne dass `session()` auf das Speichern wartet; `warmUp` tut bei `rejected` nichts; eine laufende Anmeldung wird von allen Aufrufern geteilt; scheitert sie, bekommen alle denselben Fehler, und der nächste Aufruf versucht es neu (außer bei `rejected`).

- [ ] **Step 1: `FakeAtrust` und Tests schreiben.** Halter: erste `session()` meldet an, zweite nicht; zwei gleichzeitige `session()` ergeben ein `PUT`; nach 55 Minuten ohne `used` neue Anmeldung, nach 54 nicht; neuer Kalendertag: neue Anmeldung; `used` verlängert; 401 und 403 setzen `rejected`, danach `session()` ohne Anfrage, `warmUp()` ohne Anfrage; `restore()` nach Neustart mit gespeichertem Kennzeichen: keine Anfrage; `allowOneLogin()` erlaubt genau eine; `offline` setzt `rejected` nicht; `warmUp()` wirft nie (offline, 500, abgelehnt). Einheit: Erfolg ergibt 64 Bytes, die `CardCertificate` gegen den Hashwert bestätigt; die Anfrage enthält den Hashwert und nie den Text; abgelaufene Sitzung: Folge `POST, PUT, POST`; zwei Mal abgelaufen: `SignatureFailure`, genau zwei `POST`; `wrongSignature`: `SignatureFailure` mit dem Satz oben; `offline`: `Kein Internet.`; abgelehnt: `A-Trust hat die Zugangsdaten abgelehnt.` und beim nächsten `sign` keine Anfrage; späte Antwort (Aufrufer gibt nach `timeout` auf, Antwort kommt danach): keine unbehandelte Ausnahme, die Sitzung bleibt benutzbar; `toString()` von Einheit und Halter enthält weder Passwort noch Sitzungsschlüssel.
- [ ] **Step 2:** beide Testdateien laufen lassen, erwartet: FAIL.
- [ ] **Step 3: Halter und Einheit schreiben.**
- [ ] **Step 4:** Tests erneut, erwartet: PASS. Dazu `flutter test test/rksv/rksv_secrets_test.dart` und `flutter analyze`.
- [ ] **Step 5: Commit.**

### Task 4: Datenbank Version 5, Einheit der Kette, Grund des Ausfalls

**Files:**
- Modify: `app/lib/data/database.dart` (Spalte, `schemaVersion` 5, Migration)
- Modify: `app/lib/rksv/rksv_state.dart` (`RksvUnit`, `RksvState.unit`), `app/lib/data/rksv_repository.dart`
- Modify: `app/lib/rksv/rksv_journal.dart` (Verteiler, Grund)
- Modify: `app/lib/rksv/rksv_providers.dart`
- Create: `app/lib/rksv/online/online_providers.dart`
- Test: `app/test/data/migration_v5_test.dart`, `app/test/rksv/online/unit_of_test.dart`, Ergänzung in `app/test/rksv/rksv_outage_test.dart`

**Interfaces:**
- Consumes: Task 3.
- Produces:

```dart
// rksv_state.dart
enum RksvUnit { probe, atrustTest, atrust }
// RksvState bekommt: final RksvUnit? unit;  (Einheit der laufenden Kette, null ohne Kette)

// database.dart, RksvChainRows:
TextColumn get unit => text().withDefault(const Constant('probe'))();

// rksv_journal.dart: ersetzt probeSignatureUnitOf als Einstieg der App
SignatureUnitOf signatureUnitOf(
  KassaDatabase db,
  RksvSecrets secrets, {
  required Future<SignatureUnit> Function(RksvChainRow chain, RksvCertificateRow certificate) online,
});

// online_providers.dart
final atrustHttpClientProvider = Provider<http.Client>(...);      // Tests setzen FakeAtrust.client ein
final atrustTestKeeperProvider = Provider<AtrustSessionKeeper>(...); // Testsystem, Test-Benutzer
```

`signatureUnitOf` liest Kette und Zertifikat wie bisher; `unit == 'probe'` ergibt die Probe-Signatur wie in `probeSignatureUnitOf`; `atrustTest` und `atrust` rufen `online`; ein unbekannter Wert ist ein `StateError`. In S2a liefert `online` für `atrustTest` eine `OnlineSignatureUnit` mit dem Halter aus `atrustTestKeeperProvider`, für `atrust` einen `StateError('Noch nicht gebaut.')`. `rksvJournalProvider` verwendet `signatureUnitOf`.

Journal: Bei `SignatureFailure catch (e)` wird `e.reason` der Grund des Ausfalls (bisher der feste Satz `_reasonError`). Bei Fristablauf bleibt `_reasonSilent`.

Migration 4 nach 5: `m.addColumn(rksvChainRows, rksvChainRows.unit)`; vorhandene Ketten haben danach `probe`.

- [ ] **Step 1: Tests schreiben.** Migration: eine Datenbank der Version 4 mit einer laufenden und einer beendeten Probe-Kette, Einträgen und Stand (nach dem Muster des Tests für Version 4); nach der Migration `unit == 'probe'` bei beiden, Einträge, Stand und Trigger unverändert, `PRAGMA foreign_key_check` leer. Verteiler: Probe-Kette ergibt `ProbeSignatureUnit`, Kette `atrustTest` ruft `online` mit Kette und Zertifikat, unbekannte Einheit wirft `StateError`. Ausfall: Meldet die Einheit `SignatureFailure('Kein Internet.')`, steht `Kein Internet.` in `rksv_state.outage_reason`; bei Fristablauf steht dort `Die Signatur hat nicht geantwortet.`.
- [ ] **Step 2:** Tests laufen lassen, erwartet: FAIL.
- [ ] **Step 3: Umsetzen**, danach `dart run build_runner build` für drift.
- [ ] **Step 4:** die drei Testdateien, dazu `test/rksv/rksv_journal_test.dart`, `test/rksv/rksv_service_test.dart`, `test/data/` und `flutter analyze`, erwartet: PASS.
- [ ] **Step 5: Commit.**

### Task 5: Verbindung prüfen und Online-Probe einschalten

**Files:**
- Create: `app/lib/rksv/online/connection_check.dart`
- Modify: `app/lib/rksv/rksv_service.dart`, `app/lib/rksv/rksv_providers.dart`
- Test: `app/test/rksv/online/connection_check_test.dart`, `app/test/rksv/online/online_probe_test.dart`
- Modify: `app/test/support/rksv_rig.dart` (Schalter für `FakeAtrust`)

**Interfaces:**
- Consumes: Tasks 2 bis 4, `RowState` und `RowResult` aus `app/lib/rksv/card/card_check.dart` (wiederverwenden, nicht kopieren; wenn sie dafür in eine eigene Datei müssen, verschieben).
- Produces:

```dart
enum ConnectionRow { reach, certificate, login, signature }

/// Was "Verbindung prüfen" herausgefunden hat. Nur vollständig, wenn alle vier Zeilen ok sind.
final class ConnectionFacts {
  final String zdaId;
  final AtrustCertificate certificate;
}

final class ConnectionCheckState {
  final Map<ConnectionRow, RowResult> rows;
  final bool running;
  final ConnectionFacts? facts; // nur bei vier Haken
}

class ConnectionCheck {
  ConnectionCheck({required AtrustClient client, required AtrustSessionKeeper keeper,
      required String user, required Clock clock});
  static const timeLimit = Duration(seconds: 20); // je Zeile
  ValueListenable<ConnectionCheckState> get state;

  /// [chefTapped]: Der Aufruf kommt von einem Antippen des Chefs und darf
  /// eine abgelehnte Anmeldung ein Mal neu versuchen (keeper.allowOneLogin).
  Future<ConnectionCheckState> run({required bool chefTapped});

  /// Zeilen, Dauern, Statuscodes, Zertifikat (Base64), nie Passwort oder Sitzungsschlüssel.
  String report();
}

// RksvService
Future<Receipt> enableOnlineProbe({required Staff staff, required ConnectionFacts facts});
```

Zeilen und Sätze von `ConnectionCheck`:

| Zeile | ok | Problem |
|---|---|---|
| `reach` (`zdaId`) | `A-Trust erreicht (0,2 Sekunden).` (Dauer in Sekunden mit einer Nachkommastelle, mit Komma) | je `AtrustException.sentence`, dazu der Rat: bei `noInternet` `WLAN prüfen.`, bei `untrusted` `Bitte den Bericht schicken.`, sonst `Später noch einmal versuchen.` |
| `certificate` | Echtes System: `Zertifikat geladen: Nummer <hex>, gültig bis <TT.MM.JJJJ>.`, darunter klein `Ausgestellt von <Aussteller>.` Testsystem: `Zertifikat geladen: Nummer <hex>.`, darunter klein `Test-Zertifikat von A-Trust (<Aussteller>), abgelaufen am <TT.MM.JJJJ>. Für die Online-Probe ist das in Ordnung.` (ist es nicht abgelaufen: `…, gültig bis <TT.MM.JJJJ>.`) | `alg` nicht `ES256` oder Schlüssel nicht P-256: `Das Zertifikat von A-Trust passt nicht: <Grund>.` Nur am echten System auch: heute nicht gültig. |
| `login` | `Angemeldet.` | bei `rejected`: `A-Trust hat die Zugangsdaten abgelehnt.` |
| `signature` | `Probe-Unterschrift erstellt und geprüft (0,2 Sekunden).` | Satz der Einheit |

Eine gescheiterte Zeile lässt die folgenden auf `waiting`. Zeile 4 signiert den SHA-256 von `Kassa Verbindung prüfen` über eine `OnlineSignatureUnit` mit dem eben geladenen Zertifikat.

`enableOnlineProbe` läuft wie `enableProbe` in einer Transaktion und verlangt `mode == off` (sonst `StateError`): neue Kette mit Kassen-Kennung und AES-Schlüssel wie bisher (`_storeSecrets` ohne Probe-Schlüssel), Zertifikat mit `issuers` in `rksv_certificates` (gibt es die Seriennummer schon, bleibt die Zeile), Kette mit `mode: probe`, `unit: atrustTest`, `zdaId: facts.zdaId`, `certSerial` aus dem Zertifikat, dann Startbeleg mit `mustSign: true`. Scheitert die Signatur, `RksvProblem` mit dem Satz der Einheit, und nichts bleibt zurück. `disableProbe` gilt unverändert für beide Arten.

- [ ] **Step 1: Tests schreiben.** Prüfung: vier Haken mit `FakeAtrust`, `facts` gesetzt; offline: Zeile 1 Problem mit `WLAN prüfen.`, Zeilen 2 bis 4 `waiting`, `facts == null`; abgelaufenes Zertifikat: Zeile 2 Problem; 401 beim Anmelden: Zeile 3 Problem, `keeper.rejected` wahr; `run(chefTapped: false)` bei `rejected` schickt kein `PUT`, `run(chefTapped: true)` genau eines; `report()` enthält die vier Zeilen und das Zertifikat, aber weder `123456789` als Passwort-Feld noch den Sitzungsschlüssel von `FakeAtrust`. Online-Probe: nach `enableOnlineProbe` ist `mode == probe`, `unit == atrustTest`, `zdaId` der von `FakeAtrust`, der Startbeleg signiert, `chainIsSound`; Verkauf, Storno, Nullbeleg, Schlussbeleg laufen wie in `rksv_service_test.dart`; `buildDepExport` nennt die Aussteller-Zertifikate; `offline` während des Startbelegs: `RksvProblem('Kein Internet.')`, keine Kette, kein Bon, `mode == off`; Ausfall und Sammelbeleg: `offline` bei einem Verkauf ergibt einen Eintrag mit Vermerk und `outage_reason == 'Kein Internet.'`, danach online und `retrySignature` ergibt den Sammelbeleg; bei `rejected` schickt `retrySignature` keine Anfrage und liefert `false`.
- [ ] **Step 2:** Tests laufen lassen, erwartet: FAIL.
- [ ] **Step 3: Umsetzen.**
- [ ] **Step 4:** beide Testdateien, dazu `test/rksv/` ganz und `test/features/card_check_test.dart` (falls `RowState` verschoben wurde) und `flutter analyze`, erwartet: PASS.
- [ ] **Step 5: Commit.**

### Task 6: Einstellungen: Zeile, Blatt, Bildschirm "Verbindung prüfen"

**Files:**
- Modify: `app/lib/features/settings/signature_panel.dart`, `app/lib/features/settings/probe_question.dart`
- Create: `app/lib/features/settings/connection_check_screen.dart`
- Test: `app/test/features/connection_check_test.dart`, Ergänzung in `app/test/features/signature_panel_test.dart`, `app/test/golden/connection_check_golden_test.dart`, Ergänzung in `app/test/golden/signature_panel_golden_test.dart`
- Modify: `app/test/support/signature_pump.dart`

**Interfaces:**
- Consumes: `ConnectionCheck`, `RksvService.enableOnlineProbe`, `RksvState.unit`, `atrustTestKeeperProvider`, `ShareSheet`; Bilder aus Task 0.
- Produces: Schlüssel für Tests: `rksv-online-probe-on` (Zeile), `rksv-connection-check` (Zeile), `rksv-relogin` (Taste "Erneut anmelden"), `connection-row-<name>`, `connection-share`, `connection-retry`, `connection-start` (Taste "Online-Probe starten").

Karte "Signatur":

- Zustand `off`, nur Chef: unter "Zum Ausprobieren einschalten" die Zeile **"Mit A-Trust ausprobieren"**, Hilfetext `Die Bons werden über das Testsystem von A-Trust signiert. Braucht Internet. Sie bleiben Testbons.`, Taste `Ausprobieren`.
- Zustand `probe` mit `unit == atrustTest`: Wort `Online-Probe` (mit Ausfall: `Online-Probe, Signatur ausgefallen`), Unterzeile `Signatur vom Testsystem von A-Trust, nicht für den echten Betrieb.`, zusätzlich die Zeile **"Verbindung prüfen"** (`Internet und A-Trust ausprobieren.`, Taste `Prüfen`). "Probe beenden" bleibt.
- Bei Ausfall zeigt die Karte den Grund aus `state.outageReason` in einem Satz unter dem Zustand.
- Bei `keeper.rejected`: Hinweis `A-Trust hat die Zugangsdaten abgelehnt.` mit Taste **"Erneut anmelden"**; sie öffnet "Verbindung prüfen" mit `chefTapped: true`.
- Ein `StateError` aus dem Service zeigt `Das geht gerade nicht. Bitte die Einstellungen neu öffnen.` (statt nichts).

Ablauf "Mit A-Trust ausprobieren": Blatt mit der Frage `Mit A-Trust ausprobieren?`, Text `Jeder Bon wird dann über das Internet vom Testsystem von A-Trust signiert. Die Bons bleiben Testbons. Ältere Bons kannst du danach nicht mehr stornieren.`, Tasten `Abbrechen` und `Weiter`. `Weiter` öffnet "Verbindung prüfen" und startet den Lauf. Bei vier Haken erscheint die Hauptaktion `Online-Probe starten`; sie ruft `enableOnlineProbe`, druckt den Startbeleg wie bei der Probe und kehrt zur Karte zurück. Scheitert das Einschalten, steht der Satz des `RksvProblem` am Bildschirm, und die Taste bleibt.

Bildschirm "Verbindung prüfen": Aufbau, Abstände und Zeilen wie `CardCheckScreen` (gemeinsame Zeilen-Ansicht wiederverwenden, wenn es ohne Umbau von "Karte prüfen" geht; sonst eine eigene, gleich aussehende). Vier Zeilen, unten `Nochmal prüfen` (zählt als Antippen des Chefs) und `Bericht teilen` (Betreff `Kassa: Verbindung zu A-Trust`). Aus der Zeile "Verbindung prüfen" der Karte geöffnet, gibt es keine Taste `Online-Probe starten`.

- [ ] **Step 1: Tests schreiben.** Karte: Zeile nur für den Chef und nur bei `off`; Wort und Unterzeile bei Online-Probe; Grund bei Ausfall; Hinweis und Taste bei `rejected`; Ablauf bis zum Startbeleg mit `FakeAtrust` (Folge der Anfragen: `GET ZDA, GET Certificate, PUT Session, POST Sign/Hash, POST Sign/Hash`); Doppeltipp auf `Online-Probe starten` ergibt eine Kette; offline: kein Start möglich, Zeile 1 zeigt `WLAN prüfen.`; "Erneut anmelden" schickt genau ein `PUT`. Vergleichsbilder hell und dunkel: Karte bei `off` mit beiden Zeilen, Karte bei Online-Probe, Karte bei Online-Probe mit Ausfall und Grund, Karte mit abgelehnten Zugangsdaten, Bildschirm mit vier Haken und Starttaste, Bildschirm mit Kreuz in Zeile 1, Blatt mit der Frage.
- [ ] **Step 2:** Tests laufen lassen, erwartet: FAIL.
- [ ] **Step 3: Umsetzen** nach den Bildern aus Task 0 und `docs/design-regeln.md`.
- [ ] **Step 4:** die genannten Testdateien und `test/no_text_field_test.dart`, `flutter analyze`. Neue Vergleichsbilder nur für die neuen Tests erzeugen (`flutter test --update-goldens <Datei>`), jedes ansehen. Ändert sich ein vorhandenes Bild, im Bericht nennen, welches und warum.
- [ ] **Step 5: Commit.**

### Task 7: Kassa und Bons: Grund des Ausfalls, Anmelden im Voraus

**Files:**
- Modify: `app/lib/features/kassa/outage_banner.dart`, `app/lib/features/kassa/kassa_screen.dart`, `app/lib/features/bons/receipt_detail.dart`
- Test: Ergänzungen in `app/test/features/outage_banner_test.dart`, `app/test/features/bons_rksv_test.dart`, `app/test/features/kassa_test.dart`; Vergleichsbild `kassa_ausfall_grund_hell.png`

**Interfaces:**
- Consumes: `RksvState.outageReason`, `RksvState.unit`, `atrustTestKeeperProvider`.

- Der Hinweis in der Kassa zeigt unter "Signatur ausgefallen seit HH:MM" den Grund in einem Satz. Bei `keeper.rejected` steht `A-Trust hat die Zugangsdaten abgelehnt. Bitte den Chef holen.`, und die Taste "Nochmal prüfen" fehlt.
- Das Ergebnis von "Nochmal prüfen" (`Geht noch nicht.`) verschwindet, sobald sich der Stand ändert oder der Hinweis neu erscheint; ein altes Ergebnis wird nie wieder gezeigt.
- Ein Testbon mit Ausfall-Vermerk zeigt in der Bon-Ansicht beides: `Testbon` und `Sicherheitseinrichtung ausgefallen`.
- Anmelden im Voraus: Läuft eine Kette mit `unit == atrustTest`, ruft die Kassa `keeper.restore()` und `keeper.warmUp()` beim Start der App und wenn die App wieder nach vorn kommt (`AppLifecycleState.resumed`; `KassaScreen` beobachtet den Zustand schon). Ohne solche Kette geht keine Anfrage hinaus.

- [ ] **Step 1: Tests schreiben:** Grund im Hinweis; bei `rejected` der Satz und keine Taste; altes `Geht noch nicht.` erscheint nach neuem Ausfall nicht; Bon-Ansicht mit beiden Vermerken; `resumed` mit Online-Kette ergibt ein `PUT Session`, ohne Online-Kette keine Anfrage, bei `rejected` keine Anfrage.
- [ ] **Step 2:** Tests laufen lassen, erwartet: FAIL.
- [ ] **Step 3: Umsetzen.**
- [ ] **Step 4:** die genannten Testdateien, `test/features/sale_outage_test.dart`, `flutter analyze`, erwartet: PASS. Vorhandene Vergleichsbilder des Hinweises nur neu erzeugen, wenn der Grund sie ändert; im Bericht nennen.
- [ ] **Step 5: Commit.**

### Task 8: Lauf gegen das Testsystem und Prüfwerkzeug

**Files:**
- Modify: `app/test/rksv/online/atrust_testsystem_test.dart` (ersetzt die Erkundung aus Task 1)
- Create: `tool/rksv/pruefen_datei.sh`

**Interfaces:**
- Consumes: alles aus Tasks 2 bis 5, `RksvRig`.

Der Test läuft nur mit `KASSA_ATRUST_TEST=1`, mit dem echten `http.Client` gegen `AtrustSystem.test`:

1. `ConnectionCheck.run` ergibt vier Haken.
2. 20 Signaturen über eine `OnlineSignatureUnit`, jede am Zertifikat geprüft; genau eine Anmeldung.
3. `client.signHash` mit einer erfundenen Sitzung (`AtrustSession('unbekannt', <Schlüssel der echten Sitzung>)`) wirft `sessionExpired`; `logout` der echten Sitzung antwortet ohne Fehler. (Am Testsystem signiert eine abgemeldete Sitzung weiter, siehe Befunde.)
4. Der gesperrte Benutzer `u039193334`: `login` wirft `rejected`; ein Halter mit ihm setzt `rejected` und schickt beim zweiten `session()` nichts. Insgesamt höchstens zwei Anmeldungen mit diesem Benutzer je Lauf.
5. Eine Kette im `RksvRig` mit echter Online-Einheit: `enableOnlineProbe`, zwei Verkäufe (einer mit 1.234,56 Euro), ein Storno, ein Nullbeleg, `disableProbe`. Die Zeiten der Bons liegen innerhalb der Gültigkeit des Test-Zertifikats (Start 18.11.2019, Monatswechsel Dezember 2019), also auch in der Vergangenheit der echten Uhr (Kern R11). `chainIsSound` ist wahr.
6. Das ausgegebene Protokoll und die Datei mit Schlüssel und Zertifikat für das Prüfwerkzeug (AES-Schlüssel der Test-Kette, erfunden) schreibt der Test nach `build/atrust/` und druckt beide zwischen den Zeilen `-----DEP-----`, `-----CRYPTO-----`, `-----ENDE-----`, jeweils Base64 in einer Zeile.

`tool/rksv/pruefen_datei.sh <dep-export.json> <cryptographicMaterialContainer.json> [Ordner des Prüfwerkzeugs]` lässt das Prüfwerkzeug über zwei Dateien laufen und endet mit Fehler, wenn in einer Ergebnisdatei der oberste `verificationState` nicht `PASS` ist (Regel wie Kern R9).

- [ ] **Step 1:** Test und Skript schreiben. Lokal läuft der Test nicht (Adresse gesperrt): `flutter test test/rksv/online/atrust_testsystem_test.dart` muss "übersprungen" melden.
- [ ] **Step 2: Commit.** Der Controller pusht, wartet den Lauf `atrust-testsystem` ab, holt beide Dateien aus der Ausgabe, lässt `tool/rksv/pruefen_datei.sh` in der Cloud laufen und trägt das Ergebnis ins Protokoll und in Abschnitt 11 des Entwurfs ein. Lehnt das Prüfwerkzeug das Test-Zertifikat ab, steht dort der genaue Grund, und der Beweis wartet auf Nikos Konto (Entwurf 6.10).

### Task 9: Prüfliste, Abweichungen, Version

**Files:**
- Create: `docs/testen/rksv-online-probe-pruefliste.md`
- Modify: `docs/superpowers/specs/2026-11-19-rksv-online-signatur-design.md` (Abschnitt 11)
- Modify (Controller): `app/pubspec.yaml` (`version: 1.5.0+7`), `app/lib/core/app_info.dart`, Vergleichsbilder mit der Version

- [ ] **Step 1: Prüfliste** im Stil von `docs/testen/rksv-probe-pruefliste.md`, für Niko am Tablet, nur Barverkäufe (die Version hat keinen SumUp-Schlüssel): läuft noch eine Probe, zuerst "Probe beenden"; "Mit A-Trust ausprobieren", vier Haken, Dauer notieren; Startbeleg gedruckt; Verkauf, QR-Code am Bon und am Bildschirm; fühlt sich der Verkauf langsamer an als vorher; WLAN aus, Verkauf, Hinweis mit Grund, Bon mit Vermerk; WLAN an, "Nochmal prüfen", Sammelbeleg, Hinweis weg; App schließen und öffnen, Verkauf; "Verbindung prüfen" und "Bericht teilen" in den Thread; "Protokoll ausgeben" und Datei in den Thread; "Probe beenden". Dazu der Satz, dass ein Verkauf beim ersten Ausfall ein Mal bis zu 6 Sekunden warten kann.
- [ ] **Step 2: Abschnitt 11** des Entwurfs: P1 bis P8, die Befunde aus Task 1, die Entscheidungen während des Baus, das Ergebnis des Prüfwerkzeugs, bekannte kleine Punkte.
- [ ] **Step 3: Commit.** Version, Vergleichsbilder der Version und Auslieferung macht der Controller nach der Schlussprüfung.
