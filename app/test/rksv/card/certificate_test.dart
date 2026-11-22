import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/rksv/card/certificate.dart';

import '../fixtures/test_card.dart';

Uint8List _sha(int fill) => Uint8List.fromList(List.filled(32, fill));

/// DER-Kodierung von r und s als SEQUENCE zweier INTEGER.
Uint8List _der(Uint8List rs) {
  Uint8List integer(Uint8List v) {
    var start = 0;
    while (start < v.length - 1 && v[start] == 0) {
      start++;
    }
    var body = v.sublist(start);
    if (body[0] & 0x80 != 0) body = Uint8List.fromList([0, ...body]);
    return Uint8List.fromList([0x02, body.length, ...body]);
  }

  final inner = [...integer(rs.sublist(0, 32)), ...integer(rs.sublist(32))];
  return Uint8List.fromList([0x30, inner.length, ...inner]);
}

/// Baut ein Zertifikat aus dem Test-Zertifikat, in dem ein Stück ersetzt ist.
Uint8List _replace(String from, String to) {
  final hex = testCertificateHex;
  expect(hex.contains(from), isTrue);
  return hexToBytes(hex.replaceFirst(from, to));
}

void main() {
  final cert = CardCertificate.parse(testCertificate);

  test('Test-Zertifikat: serial 889977665544, issuer "Beispiel CA", subject "Beispiel-Imbiss Signaturkarte"', () {
    expect(cert.serial, BigInt.parse('889977665544'));
    expect(cert.issuer, 'Beispiel CA');
    expect(cert.subject, 'Beispiel-Imbiss Signaturkarte');
    expect(cert.der, testCertificate);
  });

  test('Test-Zertifikat: notAfter 2031-06-30 23:59:59 UTC, notBefore 2026-01-01 00:00:00 UTC', () {
    expect(cert.notBefore, DateTime.utc(2026, 1, 1));
    expect(cert.notAfter, DateTime.utc(2031, 6, 30, 23, 59, 59));
    expect(cert.notBefore.isUtc, isTrue);
    expect(cert.notAfter.isUtc, isTrue);
  });

  test('Test-Zertifikat: publicKey ist karte.pub.hex', () {
    expect(cert.publicKey, hexToBytes(testPublicKeyHex));
    expect(cert.publicKey.length, 65);
  });

  test('verify: eine Unterschrift von testSigner ist gültig, als r || s und als DER', () {
    final hash = _sha(0x5a);
    final sig = testSigner(hash);
    expect(sig.length, 64);
    expect(cert.verify(hash, sig), isTrue);
    expect(cert.verify(hash, _der(sig)), isTrue);
  });

  test('verify: ein gekipptes Bit im Hash, in r oder in s ist ungültig', () {
    final hash = _sha(0x5a);
    final sig = testSigner(hash);
    final badHash = Uint8List.fromList(hash)..[10] ^= 0x01;
    expect(cert.verify(badHash, sig), isFalse);
    final badR = Uint8List.fromList(sig)..[5] ^= 0x01;
    expect(cert.verify(hash, badR), isFalse);
    final badS = Uint8List.fromList(sig)..[40] ^= 0x01;
    expect(cert.verify(hash, badS), isFalse);
    expect(cert.verify(hash, _der(badS)), isFalse);
  });

  test('verify: 63 Bytes, 0 Bytes und Müll ergeben false, kein Fehler', () {
    final hash = _sha(0x5a);
    final sig = testSigner(hash);
    expect(cert.verify(hash, sig.sublist(0, 63)), isFalse);
    expect(cert.verify(hash, Uint8List(0)), isFalse);
    expect(
      cert.verify(hash, Uint8List.fromList(List.filled(70, 0xff))),
      isFalse,
    );
    expect(cert.verify(hash, Uint8List(64)), isFalse); // r = s = 0
    final der = _der(sig);
    expect(cert.verify(hash, Uint8List.fromList([...der, 0])), isFalse);
    expect(cert.verify(hash, Uint8List.fromList([...sig, 0])), isFalse);
    expect(cert.verify(hash, der.sublist(0, der.length - 1)), isFalse);
    // r nicht unter der Kurvenordnung
    final big = Uint8List.fromList([
      ...List.filled(32, 0xff),
      ...sig.sublist(32),
    ]);
    expect(cert.verify(hash, big), isFalse);
    // Hash mit falscher Länge
    expect(cert.verify(Uint8List(0), sig), isFalse);
    expect(cert.verify(Uint8List(31), sig), isFalse);
  });

  test('parse: abgeschnittenes Zertifikat und beliebige Bytes werfen FormatException', () {
    for (var n = 0; n < testCertificate.length; n++) {
      expect(
        () => CardCertificate.parse(testCertificate.sublist(0, n)),
        throwsA(isA<FormatException>()),
        reason: 'Länge $n',
      );
    }
    expect(
      () => CardCertificate.parse(Uint8List.fromList(List.filled(300, 0xff))),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => CardCertificate.parse(
        Uint8List.fromList([0x30, 0x03, 0x02, 0x01, 0x01]),
      ),
      throwsA(isA<FormatException>()),
    );
    // Jedes einzelne Byte kaputt: immer derselbe feste Text, ohne Bytes.
    for (final mask in [0xff, 0x01, 0x80]) {
      for (var i = 0; i < testCertificate.length; i++) {
        final broken = Uint8List.fromList(testCertificate)..[i] ^= mask;
        try {
          CardCertificate.parse(broken);
        } on FormatException catch (e) {
          expect(e.message, 'Kein gültiges Zertifikat.', reason: 'Byte $i');
          expect(e.source, isNull, reason: 'Byte $i');
        }
      }
    }
    try {
      CardCertificate.parse(Uint8List.fromList([0x30, 0x82, 0xff]));
      fail('sollte werfen');
    } on FormatException catch (e) {
      expect(e.message, isNot(contains('ff')));
    }
  });

  test('parse: ein Zertifikat mit RSA-Schlüssel wirft FormatException', () {
    // AlgorithmIdentifier ecPublicKey/prime256v1 (21 Bytes) durch
    // rsaEncryption/NULL (15 Bytes) ersetzen, die drei Längen passend kürzen.
    var hex = testCertificateHex.replaceFirst(
      '301306072a8648ce3d020106082a8648ce3d030107',
      '300d06092a864886f70d0101010500',
    );
    hex = hex.replaceFirst('3059300d', '3053300d');
    hex = hex.replaceFirst('3082011d', '30820117');
    hex = hex.replaceFirst('30820177', '30820171');
    final rsa = hexToBytes(hex);
    expect(derTotalLength(rsa), rsa.length);
    expect(() => CardCertificate.parse(rsa), throwsA(isA<FormatException>()));
  });

  test('parse: eine andere Kurve oder Schlüsselart wirft FormatException', () {
    final otherCurve = _replace('2a8648ce3d030107', '2a8648ce3d030106');
    expect(
      () => CardCertificate.parse(otherCurve),
      throwsA(isA<FormatException>()),
    );
    final notEc = _replace('2a8648ce3d0201', '2a8648ce3d0202');
    expect(() => CardCertificate.parse(notEc), throwsA(isA<FormatException>()));
  });

  test(
    'parse: Bytes hinter dem Zertifikat (Füllbytes der Karte) werden ignoriert',
    () {
      final padded = Uint8List.fromList([
        ...testCertificate,
        ...List.filled(40, 0xff),
      ]);
      final c = CardCertificate.parse(padded);
      expect(c.der, testCertificate);
      expect(c.serial, cert.serial);
      expect(c.publicKey, cert.publicKey);
    },
  );

  test('issuer ohne CN ist der ganze Name, subject bleibt der CN', () {
    // CN (2.5.4.3) im Aussteller durch OU (2.5.4.11) ersetzen, gleiche Länge.
    final c = CardCertificate.parse(
      _replace(
        '0603550403'
            '0c0b426569737069656c204341',
        '060355040b'
            '0c0b426569737069656c204341',
      ),
    );
    expect(c.issuer, 'C=AT, O=Beispiel, OU=Beispiel CA');
    expect(c.subject, 'Beispiel-Imbiss Signaturkarte');
  });

  test('derTotalLength: 30 82 01 77 ergibt 379; 30 10 ergibt 18; ein Byte ergibt null', () {
    expect(derTotalLength(Uint8List.fromList([0x30, 0x82, 0x01, 0x77])), 379);
    expect(derTotalLength(Uint8List.fromList([0x30, 0x10])), 18);
    expect(derTotalLength(Uint8List.fromList([0x30])), isNull);
    expect(derTotalLength(Uint8List(0)), isNull);
    expect(derTotalLength(Uint8List.fromList([0x30, 0x82, 0x01])), isNull);
    expect(derTotalLength(Uint8List.fromList([0x30, 0x81])), isNull);
    expect(derTotalLength(Uint8List.fromList([0x30, 0x81, 0x90])), 147);
    expect(derTotalLength(testCertificate), testCertificate.length);
  });

  group('signatureAsRs', () {
    Uint8List sigOf(int fill) => testSigner(_sha(fill));

    test('64 Bytes bleiben, wie sie sind (eine Kopie)', () {
      final sig = sigOf(1);
      final rs = signatureAsRs(sig)!;
      expect(rs, sig);
      expect(identical(rs, sig), isFalse);
    });

    test('DER wird zu 64 Bytes r || s, auch mit kurzem r oder s', () {
      var shortFound = false;
      for (var fill = 0; fill < 256 && !shortFound; fill++) {
        final sig = sigOf(fill);
        expect(signatureAsRs(_der(sig)), sig, reason: 'fill $fill');
        shortFound = sig[0] == 0 || sig[32] == 0;
      }
      expect(shortFound, isTrue, reason: 'kein kurzes r oder s gefunden');
    });

    test('eine negative Zahl (oberstes Bit ohne Null davor) ergibt null', () {
      for (var fill = 0; fill < 256; fill++) {
        final sig = sigOf(fill);
        if (sig[0] & 0x80 == 0) continue;
        final r = sig.sublist(0, 32);
        final der = _der(sig);
        // Die Null vor r weglassen.
        final sBody = der.sublist(2 + 2 + 33);
        final negative = Uint8List.fromList([
          0x30,
          2 + 32 + sBody.length,
          0x02,
          32,
          ...r,
          ...sBody,
        ]);
        expect(signatureAsRs(negative), isNull);
        return;
      }
      fail('kein r mit oberstem Bit gefunden');
    });

    test('Müll, Reste und zu große Zahlen ergeben null', () {
      final der = _der(sigOf(2));
      expect(signatureAsRs(Uint8List(0)), isNull);
      expect(signatureAsRs(sigOf(2).sublist(0, 63)), isNull);
      expect(signatureAsRs(Uint8List.fromList([...der, 0])), isNull);
      expect(signatureAsRs(der.sublist(0, der.length - 1)), isNull);
      final big = Uint8List.fromList([
        0x30,
        0x26,
        0x02,
        0x21,
        0x01,
        ...List.filled(32, 0),
        0x02,
        0x01,
        0x01, //
      ]);
      expect(signatureAsRs(big), isNull);
    });
  });
}
