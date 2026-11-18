import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/rksv/card/certificate.dart';
import 'package:kassa/rksv/self_signed_certificate.dart';
import 'package:pointycastle/asn1.dart';
import 'package:pointycastle/export.dart';

import 'fixtures/test_card.dart';

({ECPrivateKey priv, ECPublicKey pub}) _pair() {
  final params = ECCurve_secp256r1();
  final d = BigInt.parse(testPrivateKeyHex, radix: 16);
  return (
    priv: ECPrivateKey(d, params),
    pub: ECPublicKey(params.G * d, params),
  );
}

void main() {
  final from = DateTime.utc(2026, 11, 18, 8, 30, 15);
  final serial = BigInt.parse('c0ffee1234567890', radix: 16); // top bit set

  Uint8List build() {
    final k = _pair();
    return buildSelfSignedCertificate(
      key: k.priv,
      publicKey: k.pub,
      serial: serial,
      commonName: 'Kassa Probe-Signatur BSPIMB01',
      from: from,
    );
  }

  test('das selbst ausgestellte Zertifikat lässt sich lesen', () {
    final cert = CardCertificate.parse(build());
    expect(cert.serial, serial);
    expect(cert.subject, 'Kassa Probe-Signatur BSPIMB01');
    expect(cert.issuer, 'Kassa Probe-Signatur BSPIMB01');
    expect(cert.notBefore, from);
    expect(cert.notAfter, DateTime.utc(2036, 11, 18, 8, 30, 15));
    expect(cert.publicKey, hexToBytes(testPublicKeyHex));
  });

  test('das Zertifikat ist mit seinem eigenen Schlüssel gültig signiert', () {
    final der = build();
    final outer = ASN1Parser(der).nextObject() as ASN1Sequence;
    final tbs = outer.elements![0];
    final tbsBytes = tbs.encodedBytes!;
    final sigBits = outer.elements![2].valueBytes!;
    expect(sigBits[0], 0, reason: 'keine ungenutzten Bits');
    final sig =
        ASN1Parser(Uint8List.fromList(sigBits.sublist(1))).nextObject()
            as ASN1Sequence;
    final r = (sig.elements![0] as ASN1Integer).integer!;
    final s = (sig.elements![1] as ASN1Integer).integer!;
    final k = _pair();
    final signer = ECDSASigner(null);
    signer.init(false, PublicKeyParameter<ECPublicKey>(k.pub));
    expect(
      signer.verifySignature(
        SHA256Digest().process(tbsBytes),
        ECSignature(r, s),
      ),
      isTrue,
    );
  });

  test('strenges DER: Version 3, positive Seriennummer, UTCTime, Algorithmen', () {
    final der = build();
    final outer = ASN1Parser(der).nextObject() as ASN1Sequence;
    final tbs = outer.elements![0] as ASN1Sequence;
    final e = tbs.elements!;
    expect(e[0].tag, 0xA0);
    expect(e[0].encodedBytes, [0xA0, 3, 2, 1, 2]);
    // Seriennummer: Top-Bit gesetzt, also führende 0x00, kein negativer Wert.
    expect(e[1].valueBytes, [
      0x00,
      0xc0,
      0xff,
      0xee,
      0x12,
      0x34,
      0x56,
      0x78,
      0x90,
    ]);
    const ecdsaSha256 = [
      0x30, 0x0a, 0x06, 0x08, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x04, 0x03, 0x02, //
    ];
    expect(e[2].encodedBytes, ecdsaSha256);
    expect(outer.elements![1].encodedBytes, ecdsaSha256);
    // Aussteller gleich Inhaber, Daten als UTCTime.
    expect(e[3].encodedBytes, e[5].encodedBytes);
    final validity = (e[4] as ASN1Sequence).elements!;
    expect(validity[0].tag, 0x17);
    expect(validity[1].tag, 0x17);
    expect(String.fromCharCodes(validity[0].valueBytes!), '261118083015Z');
    // SubjectPublicKeyInfo: id-ecPublicKey, prime256v1, unkomprimierter Punkt.
    final spki = (e[6] as ASN1Sequence).elements!;
    expect(spki[0].encodedBytes, [
      0x30, 0x13, 0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02, 0x01, //
      0x06, 0x08, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07,
    ]);
    expect(spki[1].valueBytes, [0, ...hexToBytes(testPublicKeyHex)]);
    expect(e.length, 7, reason: 'keine Erweiterungen');
  });

  test('Daten ab 2050 werden als GeneralizedTime geschrieben', () {
    final k = _pair();
    final der = buildSelfSignedCertificate(
      key: k.priv,
      publicKey: k.pub,
      serial: BigInt.from(5),
      commonName: 'X',
      from: DateTime.utc(2045, 1, 2, 3, 4, 5),
    );
    final outer = ASN1Parser(der).nextObject() as ASN1Sequence;
    final validity =
        ((outer.elements![0] as ASN1Sequence).elements![4] as ASN1Sequence)
            .elements!;
    expect(validity[0].tag, 0x17);
    expect(validity[1].tag, 0x18);
    expect(String.fromCharCodes(validity[1].valueBytes!), '20550102030405Z');
    expect(
      CardCertificate.parse(der).notAfter,
      DateTime.utc(2055, 1, 2, 3, 4, 5),
    );
  });

  test('Seriennummer ohne gesetztes Top-Bit bekommt kein führendes 0x00', () {
    final k = _pair();
    final der = buildSelfSignedCertificate(
      key: k.priv,
      publicKey: k.pub,
      serial: BigInt.from(0x1234),
      commonName: 'X',
      from: from,
    );
    final outer = ASN1Parser(der).nextObject() as ASN1Sequence;
    final tbs = outer.elements![0] as ASN1Sequence;
    expect(tbs.elements![1].valueBytes, [0x12, 0x34]);
  });
}
