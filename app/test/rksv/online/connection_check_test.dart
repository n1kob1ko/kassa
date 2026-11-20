import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kassa/core/clock.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/rksv/card/card_check.dart' show RowState;
import 'package:kassa/rksv/online/atrust_client.dart';
import 'package:kassa/rksv/online/atrust_session_keeper.dart';
import 'package:kassa/rksv/online/connection_check.dart';
import 'package:kassa/rksv/online/online_providers.dart';
import 'package:kassa/rksv/rksv_providers.dart';
import 'package:kassa/rksv/rksv_secrets.dart';
import 'package:pointycastle/digests/sha256.dart';

import '../../support/fake_atrust.dart';

const _zda = 'GET /u123456789/ZDA';
const _certificate = 'GET /u123456789/Certificate';
const _login = 'PUT /Session/u123456789';

const _wait = 'Erst wenn die Zeile darüber grün ist.';
const _rejected = 'A-Trust hat die Zugangsdaten abgelehnt.';
const _rejectedHint =
    'Die Kassa versucht es nicht von selbst noch einmal. "Nochmal prüfen" ist '
    'genau ein Versuch.';
const _notValid = 'Das Zertifikat von A-Trust ist nicht gültig.';
const _later = 'Später noch einmal versuchen.';
const _sendReport = 'Bitte den Bericht schicken.';

/// Ein Speicher, dessen Schreiben des Kennzeichens nie fertig wird.
class _HangingSecrets extends MemoryRksvSecrets {
  @override
  Future<void> writeAtrustRejected(bool rejected, {bool live = false}) =>
      Completer<void>().future;
}

/// Ein Client, dessen erste Anfrage mit einem fremden Fehler scheitert.
class _BrokenClient extends AtrustClient {
  _BrokenClient() : super(FakeAtrust().client, AtrustSystem.test);

  @override
  Future<String> zdaId(String user) async => throw StateError('geheim');
}

/// `TT.MM.JJJJ` in Ortszeit, wie die Prüfung Daten schreibt.
String _localDate(DateTime utc) {
  final t = utc.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.day)}.${two(t.month)}.${t.year}';
}

class _Setup {
  _Setup({
    FakeAtrust? atrust,
    this.system = AtrustSystem.test,
    MemoryRksvSecrets? secrets,
    this.credentials = const AtrustCredentials(
      atrustTestUser,
      atrustTestPassword,
    ),
    this.liveChainSerial,
  }) : atrust = atrust ?? FakeAtrust(),
       secrets = secrets ?? MemoryRksvSecrets() {
    // Jede Anfrage dauert 0,2 Sekunden auf der Uhr der Prüfung.
    this.atrust.onRequest = (_) =>
        clock.value = clock.value.add(const Duration(milliseconds: 200));
  }

  final FakeAtrust atrust;
  final AtrustSystem system;
  final MemoryRksvSecrets secrets;

  /// Die Zugangsdaten des Kontos; null: keine gespeichert.
  final AtrustCredentials? credentials;

  /// Die Seriennummer der laufenden Kette `live`; null: keine.
  final Future<String?> Function()? liveChainSerial;
  final clock = FixedClock(DateTime(2026, 11, 19, 10, 15, 30));

  late AtrustSessionKeeper keeper = makeKeeper();
  late ConnectionCheck check = makeCheck();

  AtrustSessionKeeper makeKeeper() => AtrustSessionKeeper(
    client: AtrustClient(atrust.client, system),
    credentials: () async => credentials,
    secrets: secrets,
    clock: clock,
    live: system == AtrustSystem.live,
  );

  ConnectionCheck makeCheck() => ConnectionCheck(
    client: AtrustClient(atrust.client, system),
    keeper: keeper,
    user: () async => credentials?.user,
    clock: clock,
    liveChainSerial: liveChainSerial,
  );

  int get logins => atrust.requests.where((r) => r == _login).length;
}

(RowState, String, String?) _row(ConnectionCheckState s, ConnectionRow row) {
  final r = s.rows[row]!;
  return (r.state, r.message, r.hint);
}

void _expectWaiting(ConnectionCheckState s, List<ConnectionRow> rows) {
  for (final row in rows) {
    expect(s.rows[row]!.state, RowState.waiting, reason: row.name);
  }
}

void main() {
  test('vier Haken mit FakeAtrust: Sätze mit Dauer, Fakten gesetzt, genau '
      'vier Anfragen, signiert wird der SHA-256 von "Kassa Verbindung '
      'pruefen"', () async {
    final s = _Setup();
    final result = await s.check.run(chefTapped: false);

    expect(result.running, isFalse);
    expect(_row(result, ConnectionRow.reach), (
      RowState.ok,
      'A-Trust erreicht (0,2 Sekunden).',
      null,
    ));
    expect(_row(result, ConnectionRow.certificate), (
      RowState.ok,
      'Zertifikat geladen: Nummer 2159b9f6.',
      'Test-Zertifikat von A-Trust (Beispiel-Imbiss Test), abgelaufen am '
          '${_localDate(DateTime.utc(2026, 3, 10))}. Für die Online-Probe ist '
          'das in Ordnung.',
    ));
    expect(_row(result, ConnectionRow.login), (
      RowState.ok,
      'Angemeldet.',
      null,
    ));
    expect(_row(result, ConnectionRow.signature), (
      RowState.ok,
      'Probe-Unterschrift erstellt und geprüft (0,2 Sekunden).',
      null,
    ));

    final facts = result.facts!;
    expect(facts.zdaId, 'AT1');
    expect(facts.system, AtrustSystem.test);
    expect(facts.certificate.serialHex, '2159b9f6');
    expect(facts.certificate.certificateDer, s.atrust.certificateDer);
    expect(facts.certificate.issuersDer, s.atrust.issuersDer);

    expect(s.atrust.requests, [
      _zda,
      _certificate,
      _login,
      startsWith('POST /Session/'),
    ]);
    final body = jsonDecode(s.atrust.signBodies.single) as Map;
    expect(
      body['hash'],
      base64.encode(
        SHA256Digest().process(
          Uint8List.fromList(ascii.encode('Kassa Verbindung pruefen')),
        ),
      ),
    );
    expect(identical(s.check.state.value, result), isTrue);
  });

  test('state: während des Laufs running und Zeile für Zeile running, am '
      'Ende nicht mehr', () async {
    final s = _Setup();
    final seen = <(bool, RowState, RowState)>[];
    s.check.state.addListener(() {
      final v = s.check.state.value;
      seen.add((
        v.running,
        v.rows[ConnectionRow.reach]!.state,
        v.rows[ConnectionRow.signature]!.state,
      ));
    });
    expect(s.check.state.value.running, isFalse);
    _expectWaiting(s.check.state.value, ConnectionRow.values);
    await s.check.run(chefTapped: false);
    // Zuerst läuft die Prüfung, ob die Zugangsdaten abgelehnt sind.
    expect(seen.first, (true, RowState.waiting, RowState.waiting));
    expect(seen, contains((true, RowState.running, RowState.waiting)));
    expect(seen, contains((true, RowState.ok, RowState.running)));
    expect(seen.last, (false, RowState.ok, RowState.ok));
  });

  test('offline: Zeile 1 Problem mit "WLAN prüfen.", Zeilen 2 bis 4 '
      'waiting, keine Fakten', () async {
    final s = _Setup()..atrust.offline = true;
    final result = await s.check.run(chefTapped: false);
    expect(_row(result, ConnectionRow.reach), (
      RowState.problem,
      'Kein Internet.',
      'WLAN prüfen.',
    ));
    _expectWaiting(result, [
      ConnectionRow.certificate,
      ConnectionRow.login,
      ConnectionRow.signature,
    ]);
    expect(result.rows[ConnectionRow.signature]!.message, _wait);
    expect(result.facts, isNull);
    expect(s.atrust.requests, [_zda]);
  });

  test('Rat bei Zeile 1: untrusted "Bitte den Bericht schicken.", '
      'Serverfehler "Später noch einmal versuchen."', () async {
    final untrusted = ConnectionCheck(
      client: AtrustClient(
        MockClient((_) async => throw const TlsException('fremd')),
        AtrustSystem.test,
      ),
      keeper: _Setup().keeper,
      user: () async => atrustTestUser,
      clock: FixedClock(DateTime(2026, 11, 19)),
    );
    final a = await untrusted.run(chefTapped: false);
    expect(_row(a, ConnectionRow.reach), (
      RowState.problem,
      'Das Tablet vertraut dem Zertifikat von A-Trust nicht.',
      _sendReport,
    ));

    final s = _Setup();
    final server = ConnectionCheck(
      client: AtrustClient(
        MockClient((_) async => throw StateError('kaputt')),
        AtrustSystem.test,
      ),
      keeper: s.keeper,
      user: () async => atrustTestUser,
      clock: s.clock,
    );
    final b = await server.run(chefTapped: false);
    expect(_row(b, ConnectionRow.reach), (
      RowState.problem,
      'A-Trust meldet einen Fehler.',
      _later,
    ));
    expect(b.facts, isNull);
  });

  test(
    'Testsystem, Zertifikat noch gültig: Zeile ok mit "gültig bis"',
    () async {
      final s = _Setup(atrust: FakeAtrust(validFrom: DateTime.utc(2020, 6, 1)));
      final result = await s.check.run(chefTapped: false);
      expect(_row(result, ConnectionRow.certificate), (
        RowState.ok,
        'Zertifikat geladen: Nummer 2159b9f6.',
        'Test-Zertifikat von A-Trust (Beispiel-Imbiss Test), gültig bis '
            '${_localDate(DateTime.utc(2030, 6, 1))}.',
      ));
      expect(result.facts, isNotNull);
    },
  );

  test('echtes System (MockClient, keine echte Adresse): gültiges '
      'Zertifikat ergibt vier Haken mit "gültig bis" und Aussteller', () async {
    final s = _Setup(
      atrust: FakeAtrust(validFrom: DateTime.utc(2020, 6, 1)),
      system: AtrustSystem.live,
    );
    final result = await s.check.run(chefTapped: false);
    expect(_row(result, ConnectionRow.certificate), (
      RowState.ok,
      'Zertifikat geladen: Nummer 2159b9f6, gültig bis '
          '${_localDate(DateTime.utc(2030, 6, 1))}.',
      'Ausgestellt von Beispiel-Imbiss Test.',
    ));
    expect(result.facts!.system, AtrustSystem.live);
  });

  test('echtes System: abgelaufenes Zertifikat ist in Zeile 2 ein Problem, '
      'keine Anmeldung', () async {
    final s = _Setup(system: AtrustSystem.live);
    final result = await s.check.run(chefTapped: false);
    expect(result.rows[ConnectionRow.reach]!.state, RowState.ok);
    expect(_row(result, ConnectionRow.certificate), (
      RowState.problem,
      _notValid,
      _sendReport,
    ));
    _expectWaiting(result, [ConnectionRow.login, ConnectionRow.signature]);
    expect(result.facts, isNull);
    expect(s.atrust.requests, [_zda, _certificate]);
  });

  test(
    'echtes System: Zertifikat erst später gültig ist ein Problem',
    () async {
      final s = _Setup(
        atrust: FakeAtrust(validFrom: DateTime.utc(2027, 1, 2, 12)),
        system: AtrustSystem.live,
      );
      final result = await s.check.run(chefTapped: false);
      expect(_row(result, ConnectionRow.certificate), (
        RowState.problem,
        _notValid,
        _sendReport,
      ));
      expect(result.facts, isNull);
    },
  );

  test('alg nicht ES256: Zeile 2 Problem mit Grund', () async {
    final s = _Setup()..atrust.alg = 'ES384';
    final result = await s.check.run(chefTapped: false);
    expect(_row(result, ConnectionRow.certificate), (
      RowState.problem,
      'Das Zertifikat von A-Trust passt nicht: Verfahren ES384 statt ES256.',
      _sendReport,
    ));
    _expectWaiting(result, [ConnectionRow.login, ConnectionRow.signature]);
    expect(result.facts, isNull);
  });

  test('401 beim Anmelden: Zeile 3 Problem, keeper.rejected wahr, Zeile 4 '
      'waiting', () async {
    final s = _Setup()..atrust.loginStatus = 401;
    final result = await s.check.run(chefTapped: false);
    expect(result.rows[ConnectionRow.certificate]!.state, RowState.ok);
    expect(_row(result, ConnectionRow.login), (
      RowState.problem,
      _rejected,
      _rejectedHint,
    ));
    _expectWaiting(result, [ConnectionRow.signature]);
    expect(result.facts, isNull);
    expect(s.keeper.rejected.value, isTrue);
    expect(s.logins, 1);
  });

  test('R7: bei rejected schickt run(chefTapped: false) keine einzige '
      'Anfrage; run(chefTapped: true) genau ein PUT', () async {
    final s = _Setup()..atrust.loginStatus = 403;
    await s.check.run(chefTapped: false);
    expect(s.keeper.rejected.value, isTrue);
    s.atrust.requests.clear();

    final again = await s.check.run(chefTapped: false);
    expect(s.atrust.requests, isEmpty);
    _expectWaiting(again, [
      ConnectionRow.certificate,
      ConnectionRow.login,
      ConnectionRow.signature,
    ]);
    expect(_row(again, ConnectionRow.reach), (
      RowState.problem,
      _rejected,
      _rejectedHint,
    ));
    expect(again.facts, isNull);

    // Chef tippt, A-Trust lehnt wieder ab: genau ein PUT, wieder abgelehnt.
    final tapped = await s.check.run(chefTapped: true);
    expect(s.logins, 1);
    expect(tapped.rows[ConnectionRow.login]!.state, RowState.problem);
    expect(s.keeper.rejected.value, isTrue);
    expect(await s.secrets.atrustRejected(), isTrue);

    // Chef tippt, jetzt nimmt A-Trust an: genau ein weiteres PUT, vier Haken.
    s.atrust.loginStatus = 200;
    s.atrust.requests.clear();
    final ok = await s.check.run(chefTapped: true);
    expect(s.atrust.requests, [
      _zda,
      _certificate,
      _login,
      startsWith('POST /Session/'),
    ]);
    expect(ok.facts, isNotNull);
    expect(s.keeper.rejected.value, isFalse);
  });

  test('nach einem Neustart: das gespeicherte "abgelehnt" gilt schon vor der '
      'ersten Anfrage', () async {
    final s = _Setup();
    await s.secrets.writeAtrustRejected(true);
    final result = await s.check.run(chefTapped: false);
    expect(s.atrust.requests, isEmpty);
    expect(result.rows[ConnectionRow.reach]!.message, _rejected);
  });

  test('Frist 20 Sekunden je Zeile: A-Trust antwortet nicht', () {
    fakeAsync((async) {
      final s = _Setup()..atrust.delay = const Duration(seconds: 21);
      ConnectionCheckState? result;
      s.check.run(chefTapped: false).then((r) => result = r);
      async.elapse(ConnectionCheck.timeLimit - const Duration(milliseconds: 1));
      expect(result, isNull);
      expect(s.check.state.value.running, isTrue);
      async.elapse(const Duration(milliseconds: 1));
      expect(_row(result!, ConnectionRow.reach), (
        RowState.problem,
        'A-Trust hat nicht geantwortet.',
        _later,
      ));
      _expectWaiting(result!, [
        ConnectionRow.certificate,
        ConnectionRow.login,
        ConnectionRow.signature,
      ]);
      expect(result!.running, isFalse);
      // Die späte Antwort ändert nichts und hinterlässt keinen Fehler.
      async.elapse(const Duration(seconds: 5));
      expect(
        s.check.state.value.rows[ConnectionRow.reach]!.state,
        RowState.problem,
      );
      expect(s.atrust.requests, [_zda]);
    });
  });

  test('Frist gilt auch für allowOneLogin: hängt der Speicher, ist Zeile 1 '
      'nach 20 Sekunden ein Problem, keine Anfrage', () {
    fakeAsync((async) {
      final s = _Setup(secrets: _HangingSecrets());
      ConnectionCheckState? result;
      s.check.run(chefTapped: true).then((r) => result = r);
      async.elapse(ConnectionCheck.timeLimit);
      expect(_row(result!, ConnectionRow.reach), (
        RowState.problem,
        'A-Trust hat nicht geantwortet.',
        _later,
      ));
      _expectWaiting(result!, [
        ConnectionRow.certificate,
        ConnectionRow.login,
        ConnectionRow.signature,
      ]);
      expect(s.atrust.requests, isEmpty);
    });
  });

  test('zweiter run während eines Laufs liefert dessen Ergebnis, kein '
      'zweiter Lauf', () async {
    final s = _Setup();
    final a = s.check.run(chefTapped: false);
    final b = s.check.run(chefTapped: true);
    final results = await Future.wait([a, b]);
    expect(identical(results[0], results[1]), isTrue);
    expect(s.atrust.requests, hasLength(4));
  });

  test('Nachprüfung A5: ein Lauf, der vor keeper.forget() begann, endet ohne '
      'Angaben, ohne Unterschrift und ohne weitere Anmeldung', () async {
    final s = _Setup(atrust: FakeAtrust()..holdLogins = true);
    expect(s.check.outdated, isFalse);
    final run = s.check.run(chefTapped: false);
    for (var i = 0; i < 20 && s.atrust.heldLogins.isEmpty; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(s.atrust.requests, [_zda, _certificate, _login]);
    s.keeper.forget();
    expect(s.check.outdated, isTrue);
    s.atrust.heldLogins.single.complete(200);
    final result = await run;
    expect(result.facts, isNull);
    expect(result.running, isFalse);
    _expectWaiting(result, ConnectionRow.values);
    expect(s.atrust.requests, [_zda, _certificate, _login]);
    expect(s.check.outdated, isTrue);

    // Der nächste Lauf gehört zur neuen Runde und gibt Angaben.
    s.atrust.holdLogins = false;
    final fresh = await s.check.run(chefTapped: false);
    expect(s.check.outdated, isFalse);
    expect(fresh.facts, isNotNull);
    expect(s.logins, 2);
  });

  test('Signatur passt nicht zum Zertifikat: Zeile 4 Problem mit dem Satz '
      'der Einheit', () async {
    final s = _Setup()..atrust.wrongSignature = true;
    final result = await s.check.run(chefTapped: false);
    expect(_row(result, ConnectionRow.signature), (
      RowState.problem,
      'Die Signatur von A-Trust passt nicht zum Zertifikat.',
      _sendReport,
    ));
    expect(result.facts, isNull);
  });

  test('report(): vier Zeilen mit Zustand, Satz, Dauer, Statuscode, dazu '
      'Adresse, ZDA, Zertifikat in Base64 und Zeit; nie Passwort oder '
      'Sitzung', () async {
    final s = _Setup();
    await s.check.run(chefTapped: false);
    final session = await s.keeper.session();
    final report = s.check.report();
    expect(
      report,
      allOf([
        contains('Verbindung prüfen am 19.11.2026 10:15:30'),
        contains('Adresse: https://hs-abnahme.a-trust.at/asignrkonline/v2'),
        contains('A-Trust: gut. A-Trust erreicht (0,2 Sekunden).\n'),
        contains(
          'Zertifikat: gut. Zertifikat geladen: Nummer 2159b9f6. Test-Zertifikat',
        ),
        contains('Anmeldung: gut. Angemeldet. Dauer 0,2 Sekunden.'),
        contains(
          'Probe-Unterschrift: gut. Probe-Unterschrift erstellt und geprüft '
          '(0,2 Sekunden).\n',
        ),
        contains('ZDA: AT1'),
        contains(
          'Zertifikat (Base64): ${base64.encode(s.atrust.certificateDer)}',
        ),
        for (final i in s.atrust.issuersDer)
          contains('Aussteller (Base64): ${base64.encode(i)}'),
      ]),
    );
    expect(
      'Dauer 0,2 Sekunden.'.allMatches(report),
      hasLength(2), // Zertifikat und Anmeldung; die anderen nennen sie im Satz
    );
    expect(report, isNot(contains(atrustTestPassword)));
    expect(report.toLowerCase(), isNot(contains('passwort')));
    expect(report.toLowerCase(), isNot(contains('password')));
    expect(report, isNot(contains(session.key)));
    expect(report, isNot(contains(session.id)));

    // Mit Fehler: der Statuscode steht dabei.
    final r = _Setup()..atrust.loginStatus = 401;
    await r.check.run(chefTapped: false);
    expect(
      r.check.report(),
      allOf([
        contains(
          'Anmeldung: Fehler. $_rejected $_rejectedHint Dauer 0,2 Sekunden. '
          'Status 401.',
        ),
        contains('Probe-Unterschrift: offen.'),
      ]),
    );
  });

  test('report(): Zeile 1 mit untrusted nennt Typ und Fehler des '
      'Betriebssystems, die Zeile am Bildschirm nicht', () async {
    final s = _Setup();
    final check = ConnectionCheck(
      client: AtrustClient(
        MockClient(
          (_) async => throw const HandshakeException(
            'Handshake error in client',
            OSError('CERTIFICATE_VERIFY_FAILED: unable to get issuer', 1),
          ),
        ),
        AtrustSystem.test,
      ),
      keeper: s.keeper,
      user: () async => atrustTestUser,
      clock: s.clock,
    );
    final result = await check.run(chefTapped: false);
    expect(_row(result, ConnectionRow.reach), (
      RowState.problem,
      'Das Tablet vertraut dem Zertifikat von A-Trust nicht.',
      _sendReport,
    ));
    expect(
      check.report(),
      contains(
        'A-Trust: Fehler. Das Tablet vertraut dem Zertifikat von A-Trust '
        'nicht. $_sendReport Dauer 0,0 Sekunden. Fehlerart: '
        'HandshakeException, Handshake error in client, Betriebssystem: '
        'CERTIFICATE_VERIFY_FAILED: unable to get issuer (1).',
      ),
    );
  });

  test('report(): unerwarteter Fehler nennt nur seinen Typ', () async {
    final s = _Setup();
    final check = ConnectionCheck(
      client: _BrokenClient(),
      keeper: s.keeper,
      user: () async => atrustTestUser,
      clock: s.clock,
    );
    final result = await check.run(chefTapped: false);
    expect(_row(result, ConnectionRow.reach), (
      RowState.problem,
      'Die Prüfung ist gescheitert.',
      _sendReport,
    ));
    final report = check.report();
    expect(
      report,
      contains(
        'A-Trust: Fehler. Die Prüfung ist gescheitert. $_sendReport '
        'Dauer 0,0 Sekunden. Fehlerart: StateError.',
      ),
    );
    expect(report, isNot(contains('geheim')));
  });

  test('report(): Benutzer, Passwort und Sitzung aus einer Ausnahme stehen '
      'nicht im Bericht', () async {
    const user = 'beispiel-benutzer';
    const password = 'beispiel-passwort';
    const sid = 'beispiel-sitzung-4711';
    final atrust = FakeAtrust();
    final client = AtrustClient(
      MockClient((r) async {
        if (r.method == 'PUT') {
          throw http.ClientException(
            '$user $password $sid',
            Uri.parse('${r.url}?p=$password&s=$sid'),
          );
        }
        final copy = http.Request(r.method, r.url)
          ..headers.addAll(r.headers)
          ..bodyBytes = r.bodyBytes;
        return http.Response.fromStream(await atrust.client.send(copy));
      }),
      AtrustSystem.test,
    );
    final secrets = MemoryRksvSecrets();
    final clock = FixedClock(DateTime(2026, 11, 19, 10));
    final check = ConnectionCheck(
      client: client,
      keeper: AtrustSessionKeeper(
        client: client,
        credentials: () async => AtrustCredentials(user, password),
        secrets: secrets,
        clock: clock,
      ),
      user: () async => user,
      clock: clock,
    );
    final result = await check.run(chefTapped: false);
    expect(
      result.rows[ConnectionRow.login]!.state,
      RowState.problem,
      reason: check.report(),
    );
    final report = check.report();
    expect(report, contains('Anmeldung: Fehler. Kein Internet.'));
    expect(report, contains('Fehlerart: ClientException.'));
    for (final secret in [user, password, sid]) {
      expect(report, isNot(contains(secret)));
    }
  });

  group('echtes System', () {
    const user = 'u-beispiel-4711';
    const password = 'geheim-beispiel-4711';
    const liveLogin = 'PUT /Session/$user';

    _Setup live({
      FakeAtrust? atrust,
      AtrustCredentials? credentials,
      Future<String?> Function()? liveChainSerial,
    }) => _Setup(
      atrust: atrust ?? FakeAtrust(validFrom: DateTime.utc(2020, 6, 1)),
      system: AtrustSystem.live,
      credentials: credentials ?? const AtrustCredentials(user, password),
      liveChainSerial: liveChainSerial,
    );

    group('Schlussprüfung: das Konto der laufenden Kette', () {
      const other =
          'Diese Zugangsdaten gehören zu einem anderen Konto als diese Kassa.';

      test(
        'anderes Zertifikat als die laufende Kette: Kreuz bei '
        '"Zertifikat", keine Anmeldung, keine Unterschrift, keine Fakten',
        () async {
          var asked = 0;
          final s = live(
            liveChainSerial: () async {
              asked++;
              return '7a3f0001';
            },
          );
          final result = await s.check.run(chefTapped: false);
          expect(asked, 1);
          expect(result.rows[ConnectionRow.reach]!.state, RowState.ok);
          expect(_row(result, ConnectionRow.certificate), (
            RowState.problem,
            other,
            null,
          ));
          _expectWaiting(result, [
            ConnectionRow.login,
            ConnectionRow.signature,
          ]);
          expect(result.facts, isNull);
          expect(s.atrust.requests, [
            'GET /$user/ZDA',
            'GET /$user/Certificate',
          ]);
          expect(s.logins, 0);
        },
      );

      test(
        'dasselbe Zertifikat (auch in Großbuchstaben): vier Haken',
        () async {
          final s = live(liveChainSerial: () async => '2159B9F6');
          final result = await s.check.run(chefTapped: false);
          expect(result.facts, isNotNull);
          for (final row in ConnectionRow.values) {
            expect(result.rows[row]!.state, RowState.ok, reason: row.name);
          }
        },
      );

      test('ohne laufende Kette live: nichts ändert sich', () async {
        final s = live(liveChainSerial: () async => null);
        final result = await s.check.run(chefTapped: false);
        expect(result.facts, isNotNull);
        expect(s.atrust.requests, hasLength(4));
      });

      test('am Testsystem wird nicht verglichen', () async {
        var asked = 0;
        final s = _Setup(
          liveChainSerial: () async {
            asked++;
            return '7a3f0001';
          },
        );
        final result = await s.check.run(chefTapped: false);
        expect(result.facts, isNotNull);
        expect(asked, 0);
      });

      test('connectionCheckProvider(live) liest die laufende Kette aus der '
          'Datenbank', () async {
        final atrust = FakeAtrust(validFrom: DateTime.utc(2020, 6, 1));
        final secrets = MemoryRksvSecrets();
        await secrets.writeAtrustCredentials(
          const AtrustCredentials(user, password),
        );
        driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
        final db = KassaDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            atrustHttpClientProvider.overrideWithValue(atrust.client),
            rksvSecretsProvider.overrideWithValue(secrets),
            clockProvider.overrideWithValue(
              FixedClock(DateTime(2026, 11, 19, 10)),
            ),
          ],
        );
        addTearDown(container.dispose);
        final check = container.read(
          connectionCheckProvider(AtrustSystem.live),
        );
        // Ohne laufende Kette: vier Haken.
        expect((await check.run(chefTapped: false)).facts, isNotNull);

        await db
            .into(db.rksvCertificateRows)
            .insert(
              RksvCertificateRowsCompanion.insert(
                serialHex: '7a3f0001',
                certificate: Uint8List.fromList([1, 2, 3]),
              ),
            );
        await db
            .into(db.rksvChainRows)
            .insert(
              RksvChainRowsCompanion.insert(
                chain: const Value(1),
                mode: 'live',
                unit: const Value('atrust'),
                cashBoxId: 'R4TW9KD2PX',
                zdaId: 'AT1',
                certSerial: '7a3f0001',
                startedAt: DateTime(2026, 11, 17, 9),
              ),
            );
        await (db.update(db.rksvStateRows)..where((r) => r.id.equals(1))).write(
          const RksvStateRowsCompanion(mode: Value('live'), chain: Value(1)),
        );
        final result = await check.run(chefTapped: false);
        expect(result.facts, isNull);
        expect(_row(result, ConnectionRow.certificate).$2, other);
      });
    });

    test('vier Haken mit gespeicherten Zugangsdaten, facts.system ist live, '
        'die Anfragen gehen an den gespeicherten Benutzer', () async {
      final s = live();
      final result = await s.check.run(chefTapped: false);
      expect(result.facts, isNotNull);
      expect(result.facts!.system, AtrustSystem.live);
      for (final row in ConnectionRow.values) {
        expect(result.rows[row]!.state, RowState.ok, reason: row.name);
      }
      expect(s.atrust.requests, [
        'GET /$user/ZDA',
        'GET /$user/Certificate',
        liveLogin,
        startsWith('POST /Session/'),
      ]);
    });

    test('ohne Zugangsdaten: Kreuz in Zeile 1 mit dem Satz, keine Anfrage, '
        'keine Fakten', () async {
      final s = _Setup(system: AtrustSystem.live, credentials: null);
      final result = await s.check.run(chefTapped: false);
      expect(result.rows[ConnectionRow.reach]!.state, RowState.problem);
      expect(
        result.rows[ConnectionRow.reach]!.message,
        'Die Zugangsdaten von A-Trust fehlen.',
      );
      _expectWaiting(result, [
        ConnectionRow.certificate,
        ConnectionRow.login,
        ConnectionRow.signature,
      ]);
      expect(result.facts, isNull);
      expect(s.atrust.requests, isEmpty);
      expect(s.check.report(), contains('A-Trust: Fehler.'));
    });

    test('abgelaufenes Zertifikat: Kreuz in Zeile 2, später gesperrt, keine '
        'ConnectionFacts, keine Anmeldung', () async {
      final s = live(atrust: FakeAtrust());
      final result = await s.check.run(chefTapped: false);
      expect(_row(result, ConnectionRow.certificate), (
        RowState.problem,
        _notValid,
        _sendReport,
      ));
      _expectWaiting(result, [ConnectionRow.login, ConnectionRow.signature]);
      expect(result.facts, isNull);
      expect(s.atrust.requests, ['GET /$user/ZDA', 'GET /$user/Certificate']);
    });

    test('abgelehnt ohne Tippen: Kreuz in Zeile 1 mit dem Satz, keine Anfrage; '
        'mit Tippen genau eine Anmeldung', () async {
      final s = live()..atrust.loginStatus = 401;
      await s.check.run(chefTapped: false);
      expect(s.keeper.rejected.value, isTrue);
      s.atrust.requests.clear();

      final again = await s.check.run(chefTapped: false);
      expect(s.atrust.requests, isEmpty);
      expect(_row(again, ConnectionRow.reach), (
        RowState.problem,
        _rejected,
        _rejectedHint,
      ));
      expect(again.rows[ConnectionRow.reach]!.message, isNot(_wait));

      s.atrust.loginStatus = 200;
      final tapped = await s.check.run(chefTapped: true);
      expect(s.atrust.requests.where((r) => r == liveLogin), hasLength(1));
      expect(tapped.facts, isNotNull);
      expect(s.keeper.rejected.value, isFalse);
    });

    test('der Bericht nennt weder Benutzer noch Passwort noch Sitzung, auch '
        'nicht bei Fehlern', () async {
      final s = live();
      await s.check.run(chefTapped: false);
      final session = await s.keeper.session();
      final report = s.check.report();
      expect(report, contains('Konto: echtes Konto'));
      for (final secret in [user, password, session.key, session.id]) {
        expect(report, isNot(contains(secret)));
      }
      expect(report.toLowerCase(), isNot(contains('passwort')));

      final expired = live(atrust: FakeAtrust());
      await expired.check.run(chefTapped: false);
      final rejected = live()..atrust.loginStatus = 401;
      await rejected.check.run(chefTapped: false);
      final missing = _Setup(system: AtrustSystem.live, credentials: null);
      await missing.check.run(chefTapped: false);
      for (final r in [expired, rejected, missing]) {
        final text = r.check.report();
        for (final secret in [user, password]) {
          expect(text, isNot(contains(secret)));
        }
      }
    });

    test('der Benutzer wird je Lauf neu gelesen', () async {
      var name = 'u-erste';
      final s = live();
      final check = ConnectionCheck(
        client: AtrustClient(s.atrust.client, AtrustSystem.live),
        keeper: s.keeper,
        user: () async => name,
        clock: s.clock,
      );
      await check.run(chefTapped: false);
      name = 'u-zweite';
      s.atrust.requests.clear();
      await check.run(chefTapped: false);
      expect(s.atrust.requests.first, 'GET /u-zweite/ZDA');
    });

    test('connectionCheckProvider(live): echtes System mit den Zugangsdaten '
        'aus dem Speicher, kein Netzverkehr beim Erzeugen', () async {
      final atrust = FakeAtrust(validFrom: DateTime.utc(2020, 6, 1));
      final secrets = MemoryRksvSecrets();
      await secrets.writeAtrustCredentials(
        const AtrustCredentials(user, password),
      );
      // Die Datenbank sagt, ob eine Kette live läuft (B21); hier keine.
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      final db = KassaDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          atrustHttpClientProvider.overrideWithValue(atrust.client),
          rksvSecretsProvider.overrideWithValue(secrets),
          clockProvider.overrideWithValue(
            FixedClock(DateTime(2026, 11, 19, 10)),
          ),
        ],
      );
      addTearDown(container.dispose);
      final check = container.read(connectionCheckProvider(AtrustSystem.live));
      await pumpEventQueue();
      expect(atrust.requests, isEmpty);
      expect(check.system, AtrustSystem.live);
      final result = await check.run(chefTapped: false);
      expect(result.facts!.system, AtrustSystem.live);
      expect(atrust.requests.first, 'GET /$user/ZDA');
    });
  });

  test('abgelehnt ohne Tippen am Testsystem: nie der Wartesatz', () async {
    final s = _Setup()..atrust.loginStatus = 401;
    await s.check.run(chefTapped: false);
    final again = await s.check.run(chefTapped: false);
    expect(again.rows[ConnectionRow.reach]!.message, isNot(_wait));
    expect(again.rows[ConnectionRow.reach]!.message, _rejected);
  });

  test('Laden von "abgelehnt" scheitert: Kreuz in der ersten Zeile, ein '
      'Bericht ist da, keine Anfrage', () async {
    final s = _Setup(secrets: MemoryRksvSecrets()..failReads = true);
    final result = await s.check.run(chefTapped: false);
    expect(_row(result, ConnectionRow.reach), (
      RowState.problem,
      'Die Kassa konnte den Stand der Anmeldung nicht lesen.',
      _later,
    ));
    _expectWaiting(result, [
      ConnectionRow.certificate,
      ConnectionRow.login,
      ConnectionRow.signature,
    ]);
    expect(result.facts, isNull);
    expect(s.atrust.requests, isEmpty);
    final report = s.check.report();
    expect(report, contains('A-Trust: Fehler. Die Kassa konnte'));
    expect(report, contains('Verbindung prüfen am 19.11.2026'));
  });

  test(
    'Aufheben von "abgelehnt" scheitert: Kreuz in der ersten Zeile',
    () async {
      final s = _Setup()..atrust.loginStatus = 401;
      await s.check.run(chefTapped: false);
      s.secrets.failWrites = true;
      final result = await s.check.run(chefTapped: true);
      expect(result.rows[ConnectionRow.reach]!.state, RowState.problem);
      expect(result.facts, isNull);
      expect(s.check.report(), contains('A-Trust: Fehler.'));
    },
  );

  test('report() vor dem ersten Lauf: Zeilen offen, Zeit "-"', () {
    final report = _Setup().check.report();
    expect(report, contains('Verbindung prüfen am -'));
    expect(report, contains('A-Trust: offen.'));
    expect(report, contains('ZDA: -'));
    expect(report, contains('Zertifikat (Base64): -'));
  });

  test('connectionCheckProvider: Testsystem, Halter der App, kein '
      'Netzverkehr beim Erzeugen', () async {
    final atrust = FakeAtrust();
    final container = ProviderContainer(
      overrides: [
        atrustHttpClientProvider.overrideWithValue(atrust.client),
        rksvSecretsProvider.overrideWithValue(MemoryRksvSecrets()),
        clockProvider.overrideWithValue(FixedClock(DateTime(2026, 11, 19, 10))),
      ],
    );
    addTearDown(container.dispose);
    final check = container.read(connectionCheckProvider(AtrustSystem.test));
    await pumpEventQueue();
    expect(atrust.requests, isEmpty);
    expect(check.system, AtrustSystem.test);

    final result = await check.run(chefTapped: false);
    expect(result.facts, isNotNull);
    expect(atrust.requests.where((r) => r == _login), hasLength(1));
    // Dieselbe Sitzung wie die Bons: der Halter der App hat sie schon.
    await container.read(atrustKeeperProvider(AtrustSystem.test)).session();
    expect(atrust.requests.where((r) => r == _login), hasLength(1));
  });
}
