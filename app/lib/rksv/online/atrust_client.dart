import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../card/certificate.dart';
import '../self_signed_certificate.dart';

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
  const AtrustCertificate({
    required this.certificateDer,
    required this.issuersDer,
    required this.serialHex,
    required this.alg,
  });

  final Uint8List certificateDer;

  /// Nur Base64-dekodiert, nie gelesen (die Aussteller haben RSA-Schlüssel).
  final List<Uint8List> issuersDer;

  /// Aus dem Zertifikat gelesen: Kleinbuchstaben, ohne führende Nullen.
  final String serialHex;
  final String alg;
}

/// toString nennt weder id noch key.
final class AtrustSession {
  const AtrustSession(this.id, this.key);

  final String id;
  final String key;

  @override
  String toString() => 'AtrustSession()';
}

enum AtrustProblem {
  noInternet,
  untrusted,
  rejected,
  sessionExpired,
  server,
  unreadable,
}

/// [sentence] ist ein deutscher Satz ohne Geheimnisse. toString nennt nur
/// problem (und den Status).
final class AtrustException implements Exception {
  const AtrustException(this.problem, {this.status, this.detail});

  final AtrustProblem problem;
  final int? status;

  /// Nur für den Bericht von "Verbindung prüfen" (ConnectionCheck.report):
  /// die Art des Fehlers darunter, etwa der Typ und der Fehlertext des
  /// Betriebssystems. Nie im Satz, in toString, am Bildschirm, in der
  /// Datenbank oder in einem Protokoll.
  final String? detail;

  String get sentence => switch (problem) {
    AtrustProblem.noInternet => 'Kein Internet.',
    AtrustProblem.untrusted =>
      'Das Tablet vertraut dem Zertifikat von A-Trust nicht.',
    AtrustProblem.rejected => 'A-Trust hat die Zugangsdaten abgelehnt.',
    AtrustProblem.sessionExpired => 'Die Anmeldung bei A-Trust ist abgelaufen.',
    AtrustProblem.server => 'A-Trust meldet einen Fehler.',
    AtrustProblem.unreadable => 'Die Antwort von A-Trust war nicht lesbar.',
  };

  @override
  String toString() =>
      'AtrustException(${problem.name}${status == null ? '' : ', $status'})';
}

/// Die Anfragen an den Signaturdienst von A-Trust und sonst nichts. Der
/// Client setzt keine Frist; die setzt der Aufrufer.
class AtrustClient {
  AtrustClient(this._client, this.system);

  final http.Client _client;
  final AtrustSystem system;

  Future<String> zdaId(String user) async {
    final json = _object(
      await _send('GET', '${Uri.encodeComponent(user)}/ZDA'),
    );
    return _unreadable(() => _string(json, 'zdaid'));
  }

  Future<AtrustCertificate> certificate(String user) async {
    final json = _object(
      await _send('GET', '${Uri.encodeComponent(user)}/Certificate'),
    );
    return _unreadable(() {
      final der = _decodeBase64(_string(json, 'Signaturzertifikat'));
      final issuers = json['Zertifizierungsstellen'];
      if (issuers is! List) throw const FormatException();
      final issuersDer = [
        for (final i in issuers)
          _decodeBase64(i is String ? i : throw const FormatException()),
      ];
      final stated = _string(json, 'ZertifikatsseriennummerHex');
      final alg = _string(json, 'alg');
      CardCertificate.parse(der); // nur der Beweis, dass es lesbar ist
      final serial = certificateSerialHex(der);
      if (_withoutLeadingZeros(stated) != serial) {
        throw const FormatException();
      }
      return AtrustCertificate(
        certificateDer: der,
        issuersDer: issuersDer,
        serialHex: serial,
        alg: alg,
      );
    });
  }

  Future<AtrustSession> login(String user, String password) async {
    final json = _object(
      await _send(
        'PUT',
        'Session/${Uri.encodeComponent(user)}',
        body: {'password': password},
        authFailure: AtrustProblem.rejected,
      ),
    );
    return _unreadable(
      () => AtrustSession(
        _string(json, 'sessionid'),
        _string(json, 'sessionkey'),
      ),
    );
  }

  /// Die Signatur: 64 Bytes R|S.
  Future<Uint8List> signHash(AtrustSession session, Uint8List sha256) async {
    final json = _object(
      await _send(
        'POST',
        'Session/${Uri.encodeComponent(session.id)}/Sign/Hash',
        body: {'sessionkey': session.key, 'hash': base64.encode(sha256)},
        authFailure: AtrustProblem.sessionExpired,
      ),
    );
    return _unreadable(() {
      final signature = _decodeBase64(_string(json, 'signature'));
      if (signature.length != 64) throw const FormatException();
      return signature;
    });
  }

  Future<void> logout(AtrustSession session) async {
    await _send('DELETE', 'Session/${Uri.encodeComponent(session.id)}');
  }

  /// Schickt die Anfrage und gibt die Antwort nur bei Status 200 zurück. Der
  /// Körper einer Fehlerantwort (eine HTML-Seite) wird nie gelesen.
  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, Object?>? body,
    AtrustProblem? authFailure,
  }) async {
    final request = http.Request(method, Uri.parse('${system.base}/$path'))
      ..followRedirects = false
      ..headers['Content-Type'] = 'application/json';
    if (body != null) request.body = jsonEncode(body);
    final http.Response response;
    try {
      response = await http.Response.fromStream(await _client.send(request));
    } catch (e) {
      throw AtrustException(switch (e) {
        TlsException() => AtrustProblem.untrusted,
        SocketException() || http.ClientException() => AtrustProblem.noInternet,
        _ => AtrustProblem.server,
      }, detail: _detail(e));
    }
    final status = response.statusCode;
    if (status == 200) return response;
    if (authFailure != null && (status == 401 || status == 403)) {
      throw AtrustException(authFailure, status: status);
    }
    throw AtrustException(AtrustProblem.server, status: status);
  }

  /// Die Art eines Fehlers für den Bericht: der Typ, bei TLS dazu der feste
  /// Text der TLS-Bibliothek, bei TLS und Socket der Fehler des
  /// Betriebssystems. Nie Text, Adresse oder Port der Ausnahme sonst: Pfad
  /// und Körper der Anfrage enthalten Sitzung und Passwort.
  static String _detail(Object e) {
    final (String? tls, OSError? os) = switch (e) {
      TlsException() => (e.message, e.osError),
      SocketException() => (null, e.osError),
      _ => (null, null),
    };
    return [
      '${e.runtimeType}',
      if (tls != null && tls.isNotEmpty) tls,
      if (os != null) 'Betriebssystem: ${os.message} (${os.errorCode})',
    ].join(', ');
  }

  static Map<String, Object?> _object(http.Response response) {
    return _unreadable(() {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      return decoded;
    });
  }

  static String _string(Map<String, Object?> json, String key) {
    final v = json[key];
    if (v is! String || v.isEmpty) throw const FormatException();
    return v;
  }

  /// Base64 oder Base64-URL, mit oder ohne `=`.
  static Uint8List _decodeBase64(String s) {
    final t = s.replaceAll('-', '+').replaceAll('_', '/').replaceAll('=', '');
    return base64.decode(t.padRight((t.length + 3) ~/ 4 * 4, '='));
  }

  static String _withoutLeadingZeros(String s) =>
      s.toLowerCase().replaceFirst(RegExp('^0+'), '');

  /// Alles, was beim Lesen einer 200-Antwort schiefgeht, ist `unreadable`.
  static T _unreadable<T>(T Function() read) {
    try {
      return read();
    } catch (_) {
      throw const AtrustException(AtrustProblem.unreadable);
    }
  }
}
