import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kassa/rksv/online/atrust_client.dart';
import 'package:kassa/rksv/self_signed_certificate.dart';
import 'package:pointycastle/export.dart';

import '../fixtures/test_card.dart';

const _base = 'https://hs-abnahme.a-trust.at/asignrkonline/v2';

Uint8List _certificate(BigInt serial) {
  final params = ECCurve_secp256r1();
  final d = BigInt.parse(testPrivateKeyHex, radix: 16);
  return buildSelfSignedCertificate(
    key: ECPrivateKey(d, params),
    publicKey: ECPublicKey(params.G * d, params),
    serial: serial,
    commonName: 'Beispiel-Imbiss Test',
    from: DateTime.utc(2016, 3, 1),
  );
}

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

http.Response _html(int status) => http.Response(
  '<html><body>Fehler geheim-seite</body></html>',
  status,
  headers: {'content-type': 'text/html'},
);

AtrustClient _client(Future<http.Response> Function(http.Request) handler) =>
    AtrustClient(MockClient(handler), AtrustSystem.test);

AtrustClient _throwing(Object error) => _client((_) async => throw error);

Future<AtrustProblem> _problem(Future<Object?> call) async {
  try {
    await call;
  } on AtrustException catch (e) {
    return e.problem;
  }
  fail('keine AtrustException');
}

void main() {
  final sig = Uint8List.fromList(List.generate(64, (i) => 250 - i));
  // Bytes mit Zeichen, die in Base64-URL anders aussehen als in Base64.
  final sigUrl = Uint8List.fromList(List.generate(64, (i) => 0xfb + (i % 5)));
  final session = AtrustSession('sid-1', 'schluessel-1');
  final hash = Uint8List.fromList(List.generate(32, (i) => i));

  group('Anfragen', () {
    test('zdaId', () async {
      late http.Request r;
      final c = _client((req) async {
        r = req;
        return _json({'zdaid': 'AT1'});
      });
      expect(await c.zdaId('u123456789'), 'AT1');
      expect(r.method, 'GET');
      expect(r.url.toString(), '$_base/u123456789/ZDA');
      expect(r.headers['Content-Type'], 'application/json');
    });

    test('certificate', () async {
      final der = _certificate(BigInt.parse('2159b9f6', radix: 16));
      late http.Request r;
      final c = _client((req) async {
        r = req;
        return _json({
          'Signaturzertifikat': base64.encode(der),
          'Zertifizierungsstellen': [
            base64.encode([1, 2, 3]),
            base64.encode([4, 5]),
          ],
          'ZertifikatsseriennummerHex': '2159B9F6',
          'alg': 'ES256',
        });
      });
      final cert = await c.certificate('u123456789');
      expect(r.method, 'GET');
      expect(r.url.toString(), '$_base/u123456789/Certificate');
      expect(r.headers['Content-Type'], 'application/json');
      expect(cert.certificateDer, der);
      expect(cert.issuersDer, [
        Uint8List.fromList([1, 2, 3]),
        Uint8List.fromList([4, 5]),
      ]);
      expect(cert.serialHex, '2159b9f6');
      expect(cert.alg, 'ES256');
    });

    test('login', () async {
      late http.Request r;
      final c = _client((req) async {
        r = req;
        return _json({'sessionid': 'sid-1', 'sessionkey': 'schluessel-1'});
      });
      final s = await c.login('u123456789', '123456789');
      expect(r.method, 'PUT');
      expect(r.url.toString(), '$_base/Session/u123456789');
      expect(r.headers['Content-Type'], 'application/json');
      expect(jsonDecode(r.body), {'password': '123456789'});
      expect(s.id, 'sid-1');
      expect(s.key, 'schluessel-1');
    });

    test('signHash', () async {
      late http.Request r;
      final c = _client((req) async {
        r = req;
        return _json({'signature': base64.encode(sig)});
      });
      expect(await c.signHash(session, hash), sig);
      expect(r.method, 'POST');
      expect(r.url.toString(), '$_base/Session/sid-1/Sign/Hash');
      expect(r.headers['Content-Type'], 'application/json');
      expect(jsonDecode(r.body), {
        'sessionkey': 'schluessel-1',
        'hash': base64.encode(hash),
      });
    });

    test('logout', () async {
      late http.Request r;
      final c = _client((req) async {
        r = req;
        return _json({'result': true});
      });
      await c.logout(session);
      expect(r.method, 'DELETE');
      expect(r.url.toString(), '$_base/Session/sid-1');
      expect(r.headers['Content-Type'], 'application/json');
    });

    test('logout: 200 mit beliebigem Körper ist Erfolg', () async {
      await _client((_) async => http.Response('', 200)).logout(session);
      await _client((_) async => http.Response('<x>', 200)).logout(session);
    });

    test('live nutzt die Adresse des Echtbetriebs', () async {
      Uri? url;
      final c = AtrustClient(
        MockClient((req) async {
          url = req.url;
          return _json({'zdaid': 'AT1'});
        }),
        AtrustSystem.live,
      );
      await c.zdaId('u');
      expect(url.toString(), 'https://rksv.a-trust.at/asignrkonline/v2/u/ZDA');
    });

    test('Benutzername und Sitzungskennung werden kodiert', () async {
      final urls = <String>[];
      final c = _client((req) async {
        urls.add(req.url.toString());
        return _json({
          'zdaid': 'AT1',
          'result': true,
          'signature': base64.encode(sig),
        });
      });
      await c.zdaId('u 1/2');
      await c.signHash(AtrustSession('a b/c', 'k'), hash);
      await c.logout(AtrustSession('a b/c', 'k'));
      expect(urls, [
        '$_base/u%201%2F2/ZDA',
        '$_base/Session/a%20b%2Fc/Sign/Hash',
        '$_base/Session/a%20b%2Fc',
      ]);
    });
  });

  group('Signatur', () {
    for (final (name, encode) in <(String, String Function(List<int>))>[
      ('Base64 mit =', (b) => base64.encode(b)),
      ('Base64 ohne =', (b) => base64.encode(b).replaceAll('=', '')),
      ('Base64-URL mit =', (b) => base64Url.encode(b)),
      ('Base64-URL ohne =', (b) => base64Url.encode(b).replaceAll('=', '')),
    ]) {
      test(name, () async {
        final text = encode(sigUrl);
        if (name.contains('URL')) {
          expect(text, anyOf(contains('-'), contains('_')));
        }
        final c = _client((_) async => _json({'signature': text}));
        expect(await c.signHash(session, hash), sigUrl);
      });
    }

    for (final n in [63, 70, 0]) {
      test('$n Bytes sind unreadable', () async {
        final c = _client(
          (_) async => _json({'signature': base64.encode(Uint8List(n))}),
        );
        expect(
          await _problem(c.signHash(session, hash)),
          AtrustProblem.unreadable,
        );
      });
    }
  });

  group('Fehler', () {
    test('SocketException ist noInternet', () async {
      final c = _throwing(const SocketException('weg'));
      expect(await _problem(c.zdaId('u')), AtrustProblem.noInternet);
      expect(await _problem(c.login('u', 'p')), AtrustProblem.noInternet);
    });

    test('ClientException ist noInternet', () async {
      final c = _throwing(http.ClientException('weg'));
      expect(await _problem(c.logout(session)), AtrustProblem.noInternet);
    });

    test('HandshakeException und TlsException sind untrusted', () async {
      expect(
        await _problem(_throwing(const HandshakeException('x')).zdaId('u')),
        AtrustProblem.untrusted,
      );
      expect(
        await _problem(_throwing(const TlsException('x')).zdaId('u')),
        AtrustProblem.untrusted,
      );
    });

    test('fremde Ausnahme wird zu AtrustException', () async {
      final c = _throwing(StateError('irgendwas'));
      expect(await _problem(c.zdaId('u')), AtrustProblem.server);
    });

    test('keine Anfrage folgt einer Weiterleitung', () async {
      final sent = <http.Request>[];
      final c = _client((r) async {
        sent.add(r);
        return _html(500);
      });
      for (final call in [
        c.zdaId('u'),
        c.certificate('u'),
        c.login('u', 'p'),
        c.signHash(session, hash),
        c.logout(session),
      ]) {
        await _problem(call);
      }
      expect(sent, hasLength(5));
      for (final r in sent) {
        expect(r.followRedirects, isFalse, reason: r.method);
      }
    });

    for (final status in [401, 403]) {
      test('login $status ist rejected', () async {
        final c = _client((_) async => _html(status));
        expect(await _problem(c.login('u', 'p')), AtrustProblem.rejected);
      });
      test('signHash $status ist sessionExpired', () async {
        final c = _client((_) async => _html(status));
        expect(
          await _problem(c.signHash(session, hash)),
          AtrustProblem.sessionExpired,
        );
      });
      test('zdaId, certificate, logout $status sind server', () async {
        final c = _client((_) async => _html(status));
        expect(await _problem(c.zdaId('u')), AtrustProblem.server);
        expect(await _problem(c.certificate('u')), AtrustProblem.server);
        expect(await _problem(c.logout(session)), AtrustProblem.server);
      });
    }

    for (final status in [400, 404, 500, 503, 204, 302]) {
      test(
        'Status $status ist server, der HTML-Körper wird nicht gelesen',
        () async {
          final c = _client((_) async => _html(status));
          for (final call in [
            c.zdaId('u'),
            c.certificate('u'),
            c.login('u', 'p'),
            c.signHash(session, hash),
            c.logout(session),
          ]) {
            try {
              await call;
              fail('keine Ausnahme');
            } on AtrustException catch (e) {
              // login/signHash nur bei 401/403 anders
              expect(e.problem, AtrustProblem.server);
              expect(e.status, status);
            }
          }
        },
      );
    }

    test('200 mit kaputtem JSON, leerem Körper, falschem Typ', () async {
      for (final body in ['', '<html>', '[]', '"x"', '{"zdaid":']) {
        final c = _client((_) async => http.Response(body, 200));
        expect(await _problem(c.zdaId('u')), AtrustProblem.unreadable);
        expect(await _problem(c.login('u', 'p')), AtrustProblem.unreadable);
        expect(
          await _problem(c.signHash(session, hash)),
          AtrustProblem.unreadable,
        );
        expect(await _problem(c.certificate('u')), AtrustProblem.unreadable);
      }
    });

    test('200 mit fehlendem oder falschem Feld', () async {
      expect(
        await _problem(_client((_) async => _json({})).zdaId('u')),
        AtrustProblem.unreadable,
      );
      expect(
        await _problem(_client((_) async => _json({'zdaid': 5})).zdaId('u')),
        AtrustProblem.unreadable,
      );
      expect(
        await _problem(
          _client((_) async => _json({'sessionid': 'a'})).login('u', 'p'),
        ),
        AtrustProblem.unreadable,
      );
      expect(
        await _problem(
          _client((_) async => _json({'signature': 'kein base64 !!'}))
              .signHash(session, hash),
        ),
        AtrustProblem.unreadable,
      );
    });

    group('Zertifikat', () {
      final der = _certificate(BigInt.parse('2159b9f6', radix: 16));
      Map<String, Object?> body({
        Object? cert,
        Object? issuers,
        Object? serial = '2159B9F6',
        Object? alg = 'ES256',
      }) => {
        'Signaturzertifikat': cert ?? base64.encode(der),
        'Zertifizierungsstellen':
            issuers ??
            [
              base64.encode([1]),
            ],
        'ZertifikatsseriennummerHex': serial,
        'alg': alg,
      };

      Future<AtrustProblem> run(Map<String, Object?> b) =>
          _problem(_client((_) async => _json(b)).certificate('u'));

      test('nicht lesbares Zertifikat', () async {
        expect(
          await run(body(cert: base64.encode([1, 2, 3]))),
          AtrustProblem.unreadable,
        );
        expect(await run(body(cert: '%%%')), AtrustProblem.unreadable);
      });

      test('abweichende Seriennummer', () async {
        expect(await run(body(serial: '2159B9F7')), AtrustProblem.unreadable);
      });

      test('führende Nullen und Schreibweise zählen nicht', () async {
        final c = _client((_) async => _json(body(serial: '002159b9F6')));
        expect((await c.certificate('u')).serialHex, '2159b9f6');
      });

      test('fehlende oder falsche Felder', () async {
        for (final key in body().keys) {
          final b = body()..remove(key);
          expect(await run(b), AtrustProblem.unreadable, reason: key);
        }
        expect(await run(body(issuers: 'x')), AtrustProblem.unreadable);
        expect(await run(body(issuers: [1])), AtrustProblem.unreadable);
        expect(await run(body(issuers: ['%%%'])), AtrustProblem.unreadable);
      });
    });
  });

  group('Geheimnisse', () {
    test('AtrustSession.toString nennt weder id noch key', () {
      final text = AtrustSession('abc', 'geheim').toString();
      expect(text, isNot(contains('geheim')));
      expect(text, isNot(contains('abc')));
    });

    test('AtrustException.toString nennt nur problem und Status', () {
      expect(
        const AtrustException(AtrustProblem.rejected).toString(),
        'AtrustException(rejected)',
      );
      expect(
        const AtrustException(AtrustProblem.server, status: 500).toString(),
        'AtrustException(server, 500)',
      );
    });

    test('keine Ausnahme enthält das Passwort', () async {
      final c = _client((_) async => _html(403));
      try {
        await c.login('u', 'meinpasswort');
        fail('keine Ausnahme');
      } on AtrustException catch (e) {
        expect(e.toString(), isNot(contains('meinpasswort')));
        expect(e.sentence, isNot(contains('meinpasswort')));
      }
    });

    test('die Sätze', () {
      const s = {
        AtrustProblem.noInternet: 'Kein Internet.',
        AtrustProblem.untrusted:
            'Das Tablet vertraut dem Zertifikat von A-Trust nicht.',
        AtrustProblem.rejected: 'A-Trust hat die Zugangsdaten abgelehnt.',
        AtrustProblem.sessionExpired:
            'Die Anmeldung bei A-Trust ist abgelaufen.',
        AtrustProblem.server: 'A-Trust meldet einen Fehler.',
        AtrustProblem.unreadable: 'Die Antwort von A-Trust war nicht lesbar.',
      };
      for (final e in s.entries) {
        expect(AtrustException(e.key).sentence, e.value);
      }
      expect(s.length, AtrustProblem.values.length);
    });

    test('Konstanten', () {
      expect(atrustTestUser, 'u123456789');
      expect(atrustTestPassword, '123456789');
      expect(AtrustSystem.test.base, _base);
      expect(
        AtrustSystem.live.base,
        'https://rksv.a-trust.at/asignrkonline/v2',
      );
    });
  });
  group('detail für den Bericht', () {
    Future<AtrustException> caught(Future<Object?> call) async {
      try {
        await call;
      } on AtrustException catch (e) {
        return e;
      }
      fail('keine AtrustException');
    }

    test('HandshakeException: Typ, Text der TLS-Bibliothek, Fehler des '
        'Betriebssystems; nicht im Satz und nicht in toString', () async {
      final e = await caught(
        _throwing(
          const HandshakeException(
            'Handshake error in client',
            OSError('CERTIFICATE_VERIFY_FAILED: unable to get issuer', 1),
          ),
        ).zdaId('u'),
      );
      expect(e.problem, AtrustProblem.untrusted);
      expect(
        e.detail,
        allOf([
          contains('HandshakeException'),
          contains('Handshake error in client'),
          contains('CERTIFICATE_VERIFY_FAILED: unable to get issuer'),
          contains('1'),
        ]),
      );
      expect(e.sentence, isNot(contains('CERTIFICATE_VERIFY_FAILED')));
      expect(e.toString(), isNot(contains('CERTIFICATE_VERIFY_FAILED')));
      expect(e.toString(), isNot(contains('HandshakeException')));
    });

    test('SocketException: Typ und Fehler des Betriebssystems', () async {
      final e = await caught(
        _throwing(
          const SocketException(
            'geheim',
            osError: OSError('Network is unreachable', 101),
          ),
        ).zdaId('u'),
      );
      expect(e.problem, AtrustProblem.noInternet);
      expect(
        e.detail,
        allOf([
          contains('SocketException'),
          contains('Network is unreachable'),
          contains('101'),
        ]),
      );
      expect(e.detail, isNot(contains('geheim')));
    });

    test('fremde Ausnahme: nur der Typ', () async {
      final e = await caught(_throwing(StateError('geheim')).zdaId('u'));
      expect(e.detail, 'StateError');
    });

    // Der Text einer TlsException ist ein fester Text der TLS-Bibliothek und
    // steht im Bericht; der Text anderer Ausnahmen kann Pfad oder Körper der
    // Anfrage enthalten.
    test('Benutzer, Passwort und Sitzung aus Text, Adresse und Port der '
        'Ausnahme stehen nie in detail oder toString', () async {
      const user = 'beispiel-benutzer';
      const password = 'beispiel-passwort';
      const sid = 'beispiel-sitzung-4711';
      final secrets = [user, password, sid];
      final uri = Uri.parse(
        '$_base/Session/$sid/Sign/Hash?u=$user&p=$password',
      );
      final errors = <Object>[
        http.ClientException('$user $password $sid', uri),
        SocketException(
          '$user $password $sid',
          address: InternetAddress('10.4.7.11'),
          port: 4711,
        ),
        StateError('$user $password $sid $uri'),
        ArgumentError('$user $password $sid'),
      ];
      for (final error in errors) {
        for (final call in [
          (AtrustClient c) => c.login(user, password),
          (AtrustClient c) => c.signHash(AtrustSession(sid, 'k'), hash),
        ]) {
          final e = await caught(call(_throwing(error)));
          final detail = e.detail ?? '';
          for (final secret in [...secrets, '10.4.7.11', '4711']) {
            expect(detail, isNot(contains(secret)), reason: '$error');
            expect(e.toString(), isNot(contains(secret)), reason: '$error');
          }
        }
      }
    });
  });
}
