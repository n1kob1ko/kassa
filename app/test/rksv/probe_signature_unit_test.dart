import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/rksv/card/certificate.dart';
import 'package:kassa/rksv/probe_signature_unit.dart';
import 'package:kassa/rksv/signature_unit.dart';
import 'package:pointycastle/digests/sha256.dart';

void main() {
  final now = DateTime.utc(2026, 11, 18, 9);

  test('ProbeSignatureUnit.sign: 64 Bytes, gültig gegen das Zertifikat, '
      'zweimal gleicher Text ergibt dieselbe Signatur', () async {
    final made = ProbeSignatureUnit.create(cashBoxId: 'BSPIMB01', now: now);
    final unit = ProbeSignatureUnit(
      privateKey: made.privateKey,
      certificateDer: made.certificateDer,
    );
    const input = 'eyJhbGciOiJFUzI1NiJ9.QUJD';
    final a = await unit.sign(input);
    final b = await unit.sign(input);
    expect(a.length, 64);
    expect(a, b);
    final hash = SHA256Digest().process(
      Uint8List.fromList(ascii.encode(input)),
    );
    expect(CardCertificate.parse(made.certificateDer).verify(hash, a), isTrue);
    final other = await unit.sign('anderer.Text');
    expect(other, isNot(a));
  });

  test('ProbeSignatureUnit.create: verschiedene Schlüssel und Seriennummern; '
      'info() nennt AT100 und die Seriennummer in Kleinbuchstaben', () async {
    final a = ProbeSignatureUnit.create(cashBoxId: 'BSPIMB01', now: now);
    final b = ProbeSignatureUnit.create(cashBoxId: 'BSPIMB01', now: now);
    expect(a.privateKey, isNot(b.privateKey));
    expect(a.serialHex, isNot(b.serialHex));
    expect(a.privateKey.length, 32);
    final cert = CardCertificate.parse(a.certificateDer);
    expect(cert.subject, 'Kassa Probe-Signatur BSPIMB01');
    expect(a.serialHex, cert.serial.toRadix16());
    expect(a.serialHex, matches(RegExp(r'^[1-9a-f][0-9a-f]*$')));
    final info = await ProbeSignatureUnit(
      privateKey: a.privateKey,
      certificateDer: a.certificateDer,
    ).info();
    expect(info.zdaId, 'AT100');
    expect(info.serialHex, a.serialHex);
    expect(info.certificateDer, a.certificateDer);
    expect(info.issuerCertificatesDer, isEmpty);
  });

  test('create ist mit festem Random wiederholbar', () {
    final a = ProbeSignatureUnit.create(
      cashBoxId: 'K1',
      now: now,
      random: Random(7),
    );
    final b = ProbeSignatureUnit.create(
      cashBoxId: 'K1',
      now: now,
      random: Random(7),
    );
    expect(a.privateKey, b.privateKey);
    expect(a.certificateDer, b.certificateDer);
  });

  test('toString von ProbeSignatureUnit und SignatureFailure enthält keinen '
      'Schlüssel', () {
    final made = ProbeSignatureUnit.create(cashBoxId: 'BSPIMB01', now: now);
    final unit = ProbeSignatureUnit(
      privateKey: made.privateKey,
      certificateDer: made.certificateDer,
    );
    final hex = [
      for (final b in made.privateKey) b.toRadixString(16).padLeft(2, '0'),
    ].join();
    final text = unit.toString();
    expect(text, isNot(contains(hex)));
    expect(text, isNot(contains(base64.encode(made.privateKey))));
    expect(text, isNot(contains(made.privateKey.join(','))));
    const failure = SignatureFailure('Die Signatur ging nicht.');
    expect(failure.toString(), isNot(contains(hex)));
    expect(failure.toString(), contains('Die Signatur ging nicht.'));
  });

  test(
    'ein kaputter Schlüssel wirft SignatureFailure ohne Geheimnis',
    () async {
      final made = ProbeSignatureUnit.create(cashBoxId: 'BSPIMB01', now: now);
      final unit = ProbeSignatureUnit(
        privateKey: Uint8List(0),
        certificateDer: made.certificateDer,
      );
      await expectLater(unit.sign('x'), throwsA(isA<SignatureFailure>()));
    },
  );
}

extension on BigInt {
  String toRadix16() => toRadixString(16);
}
