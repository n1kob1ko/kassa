// Erkundung des öffentlichen Testsystems von A-Trust (a.sign RK HSM).
// Läuft nur mit KASSA_ATRUST_TEST=1 (GitHub-Lauf "atrust-testsystem").
// Benutzer und Passwörter stehen im Handbuch von A-Trust und sind öffentlich.
// Der Sitzungsschlüssel wird nie gedruckt.

// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kassa/rksv/card/certificate.dart';

const _base = 'https://hs-abnahme.a-trust.at/asignrkonline/v2';
const _user = 'u123456789';
const _password = '123456789';
const _blockedUser = 'u039193334';
const _blockedPassword = '60z7dx';
const _json = {'Content-Type': 'application/json'};

String _short(String body) =>
    body.length <= 400 ? body : '${body.substring(0, 400)}… (${body.length})';

Uint8List _decode(String s) {
  final t = s.replaceAll('-', '+').replaceAll('_', '/');
  return base64.decode(t.padRight((t.length + 3) ~/ 4 * 4, '='));
}

void main() {
  test('Erkundung des Testsystems von A-Trust', () async {
    if (Platform.environment['KASSA_ATRUST_TEST'] != '1') {
      markTestSkipped('Nur mit KASSA_ATRUST_TEST=1.');
      return;
    }
    HttpOverrides.global = null;
    final client = http.Client();
    addTearDown(client.close);

    final zda = await client.get(Uri.parse('$_base/$_user/ZDA'));
    print('ZDA: ${zda.statusCode} ${_short(zda.body)}');
    print('ZDA Kopf: ${zda.headers['content-type']}');

    final cert = await client.get(Uri.parse('$_base/$_user/Certificate'));
    print('Certificate: ${cert.statusCode}');
    final certJson = jsonDecode(cert.body) as Map<String, dynamic>;
    print('Certificate Felder: ${certJson.keys.toList()}');
    print('alg: ${certJson['alg']}');
    print('Seriennummer: ${certJson['Zertifikatsseriennummer']}');
    print('SeriennummerHex: ${certJson['ZertifikatsseriennummerHex']}');
    final issuers = certJson['Zertifizierungsstellen'] as List;
    print('Aussteller-Zertifikate: ${issuers.length}');
    final der = base64.decode(certJson['Signaturzertifikat'] as String);
    final parsed = CardCertificate.parse(der);
    print('Aussteller: ${parsed.issuer}');
    print('Inhaber: ${parsed.subject}');
    print('Seriennummer im Zertifikat (hex): ${parsed.serial.toRadixString(16)}');
    print('gültig: ${parsed.notBefore} bis ${parsed.notAfter}');
    print('SIGNATURZERTIFIKAT ${certJson['Signaturzertifikat']}');
    for (final i in issuers) {
      print('ZERTIFIZIERUNGSSTELLE $i');
      try {
        final p = CardCertificate.parse(base64.decode(i as String));
        print('  ${p.subject} von ${p.issuer}, bis ${p.notAfter}');
      } on FormatException {
        print('  (nicht als P-256-Zertifikat lesbar)');
      }
    }

    final login = await client.put(
      Uri.parse('$_base/Session/$_user'),
      headers: _json,
      body: jsonEncode({'password': _password}),
    );
    print('Login: ${login.statusCode}');
    final session = jsonDecode(login.body) as Map<String, dynamic>;
    print('Login Felder: ${session.keys.toList()}');
    final id = session['sessionid'] as String;
    final key = session['sessionkey'] as String;
    print('sessionid Länge ${id.length}, sessionkey Länge ${key.length}');

    final hash = Uint8List.fromList(
      sha256.convert(ascii.encode('Kassa Erkundung')).bytes,
    );
    for (var i = 0; i < 10; i++) {
      final watch = Stopwatch()..start();
      final sign = await client.post(
        Uri.parse('$_base/Session/$id/Sign/Hash'),
        headers: _json,
        body: jsonEncode({'sessionkey': key, 'hash': base64.encode(hash)}),
      );
      watch.stop();
      if (i == 0) {
        print('Sign/Hash: ${sign.statusCode} ${_short(sign.body)}');
        final signJson = jsonDecode(sign.body) as Map<String, dynamic>;
        print('Sign/Hash Felder: ${signJson.keys.toList()}');
        final text = signJson['signature'] as String;
        print(
          'Signatur: plus/slash ${text.contains(RegExp(r'[+/]'))}, '
          'minus/unterstrich ${text.contains(RegExp(r'[-_]'))}, '
          'endet auf = ${text.endsWith('=')}',
        );
        final raw = _decode(text);
        print('Signatur Länge ${raw.length}');
        print('Signatur passt zum Zertifikat: ${parsed.verify(hash, raw)}');
      }
      print('Sign/Hash Dauer $i: ${watch.elapsedMilliseconds} ms');
    }

    final unknown = await client.post(
      Uri.parse('$_base/Session/unbekannt/Sign/Hash'),
      headers: _json,
      body: jsonEncode({'sessionkey': key, 'hash': base64.encode(hash)}),
    );
    print('Unbekannte Sitzung: ${unknown.statusCode} ${_short(unknown.body)}');

    final blocked = await client.put(
      Uri.parse('$_base/Session/$_blockedUser'),
      headers: _json,
      body: jsonEncode({'password': _blockedPassword}),
    );
    print('Gesperrter Benutzer: ${blocked.statusCode} ${_short(blocked.body)}');

    final logout = await client.delete(Uri.parse('$_base/Session/$id'));
    print('Logout: ${logout.statusCode} ${_short(logout.body)}');

    final after = await client.post(
      Uri.parse('$_base/Session/$id/Sign/Hash'),
      headers: _json,
      body: jsonEncode({'sessionkey': key, 'hash': base64.encode(hash)}),
    );
    print('Nach Logout: ${after.statusCode} ${_short(after.body)}');

    final nothing = await client.get(Uri.parse('$_base/$_user/Nichts'));
    print('Unbekannte Adresse: ${nothing.statusCode} ${_short(nothing.body)}');

    expect(zda.statusCode, 200);
    expect(cert.statusCode, 200);
    expect(login.statusCode, 200);
  }, timeout: const Timeout(Duration(minutes: 3)));
}
