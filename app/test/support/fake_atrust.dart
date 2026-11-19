import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kassa/rksv/online/atrust_client.dart';
import 'package:kassa/rksv/self_signed_certificate.dart';
import 'package:pointycastle/export.dart';

import '../rksv/fixtures/test_card.dart';

/// Nachgebauter Signaturdienst von A-Trust, der antwortet wie das
/// Testsystem in "Befunde aus Task 1": Anmeldung mit `sessionid` und
/// `sessionkey`, Signatur als Base64-URL ohne `=`, Fehler als HTML-Seite.
///
/// Schlüssel wie [FakeSignatureUnit] (`test_card.dart`), dazu ein selbst
/// ausgestelltes Zertifikat mit der Seriennummer des Testsystems. Das
/// Passwort wird nie gespeichert und nie ausgegeben.
class FakeAtrust {
  /// [validFrom]: Beginn der Gültigkeit des Zertifikats (zehn Jahre lang).
  /// Ohne Angabe ab 10.03.2016, also am 18.11.2026 abgelaufen wie beim
  /// Testsystem. Der Fake antwortet am Pfad jeder [AtrustSystem]-Adresse
  /// (beide haben denselben Pfad); angesprochen wird keine.
  FakeAtrust({DateTime? validFrom}) {
    final params = ECCurve_secp256r1();
    final d = BigInt.parse(testPrivateKeyHex, radix: 16);
    certificateDer = buildSelfSignedCertificate(
      key: ECPrivateKey(d, params),
      publicKey: ECPublicKey(params.G * d, params),
      serial: BigInt.parse('2159b9f6', radix: 16),
      commonName: 'Beispiel-Imbiss Test',
      from: validFrom ?? DateTime.utc(2016, 3, 10),
    );
  }

  /// Das Signaturzertifikat, das `GET …/Certificate` liefert.
  late final Uint8List certificateDer;

  /// Zwei Aussteller wie beim Testsystem; nur Bytes, kein Zertifikat.
  final List<Uint8List> issuersDer = [
    Uint8List.fromList(utf8.encode('Beispiel Aussteller 1')),
    Uint8List.fromList(utf8.encode('Beispiel Aussteller 2')),
  ];

  /// Methode und Pfad ohne Adresse, etwa `PUT /Session/u123456789`. Auch
  /// Anfragen, die an [offline] scheitern.
  final List<String> requests = [];

  /// Körper der Anfragen an `Sign/Hash` (sie enthalten kein Passwort).
  final List<String> signBodies = [];

  /// Status der Anmeldung; 401 oder 403 heißt abgelehnt, 500 Serverfehler.
  int loginStatus = 200;

  /// Der nächste Aufruf von `Sign/Hash` antwortet 401, und seine Sitzung ist
  /// danach unbekannt. Danach steht es wieder auf false.
  bool expireSessions = false;

  /// Jede Antwort kommt erst nach dieser Zeit (für fake_async).
  Duration delay = Duration.zero;

  /// Das Feld `alg` der Antwort auf `GET …/Certificate`.
  String alg = 'ES256';

  /// Jede Anfrage scheitert mit [SocketException].
  bool offline = false;

  /// Signatur in gültiger Form, aber mit einem fremden Schlüssel.
  bool wrongSignature = false;

  /// Wird für jede Anfrage gerufen, nach dem Eintrag in [requests].
  void Function(String request)? onRequest;

  final Map<String, String> _sessions = {};
  int _issued = 0;

  late final http.Client client = MockClient(_handle);

  static final String _base = Uri.parse(AtrustSystem.test.base).path;

  Future<http.Response> _handle(http.Request request) async {
    final path = request.url.path.startsWith(_base)
        ? request.url.path.substring(_base.length)
        : request.url.path;
    final line = '${request.method} $path';
    requests.add(line);
    onRequest?.call(line);
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (offline) throw const SocketException('Kein Netz (Attrappe)');
    final parts = path.split('/').skip(1).toList();
    return switch ((request.method, parts)) {
      ('GET', [_, 'ZDA']) => _json({'zdaid': 'AT1'}),
      ('GET', [_, 'Certificate']) => _json({
        'Signaturzertifikat': base64.encode(certificateDer),
        'Zertifizierungsstellen': [
          for (final i in issuersDer) base64.encode(i),
        ],
        'Zertifikatsseriennummer': '559528438',
        'ZertifikatsseriennummerHex': '2159B9F6',
        'alg': alg,
      }),
      ('PUT', ['Session', _]) => _login(),
      ('POST', ['Session', final id, 'Sign', 'Hash']) => _sign(
        id,
        request.body,
      ),
      ('DELETE', ['Session', _]) => _json({'result': true}),
      _ => _html(404),
    };
  }

  http.Response _login() {
    if (loginStatus != 200) return _html(loginStatus);
    _issued++;
    final id = 'sitzung$_issued'.padRight(32, 'x');
    final key = base64.encode(
      List.generate(32, (i) => (i * 7 + _issued) % 256),
    );
    _sessions[id] = key;
    return _json({'sessionid': id, 'sessionkey': key});
  }

  http.Response _sign(String id, String body) {
    signBodies.add(body);
    if (expireSessions) {
      expireSessions = false;
      _sessions.remove(id);
      return _html(401);
    }
    final Uint8List hash;
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      if (_sessions[id] == null || json['sessionkey'] != _sessions[id]) {
        return _html(401);
      }
      hash = base64.decode(json['hash'] as String);
      if (hash.length != 32) return _html(400);
    } catch (_) {
      return _html(400);
    }
    final signature = wrongSignature
        ? ecdsaSignSha256(BigInt.from(123456789), hash)
        : testSigner(hash);
    return _json({
      'signature': base64Url.encode(signature).replaceAll('=', ''),
    });
  }

  static http.Response _json(Object body) => http.Response(
    jsonEncode(body),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  static http.Response _html(int status) => http.Response(
    '<html><head><title>$status</title></head>'
    '<body><h1>$status - Fehler</h1></body></html>',
    status,
    headers: {'content-type': 'text/html'},
  );
}
