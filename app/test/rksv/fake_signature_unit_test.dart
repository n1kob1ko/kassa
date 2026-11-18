import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/rksv/card/certificate.dart';
import 'package:kassa/rksv/signature_unit.dart';
import 'package:pointycastle/digests/sha256.dart';

import '../support/fake_signature_unit.dart';
import 'fixtures/test_card.dart';

void main() {
  final cert = CardCertificate.parse(testCertificate);

  test('FakeSignatureUnit: ok signiert gültig, info nennt AT100', () async {
    final fake = FakeSignatureUnit();
    final info = await fake.info();
    expect(info.zdaId, 'AT100');
    expect(info.serialHex, 'cf36cd7808');
    expect(info.certificateDer, testCertificate);
    final sig = await fake.sign('abc.def');
    expect(sig.length, 64);
    final hash = SHA256Digest().process(
      Uint8List.fromList(ascii.encode('abc.def')),
    );
    expect(cert.verify(hash, sig), isTrue);
    expect(fake.signCalls, 1);
  });

  test('FakeSignatureUnit: error wirft SignatureFailure', () async {
    final fake = FakeSignatureUnit()..mode = FakeMode.error;
    await expectLater(fake.sign('x'), throwsA(isA<SignatureFailure>()));
    expect(fake.signCalls, 1);
  });

  test('FakeSignatureUnit: silent antwortet erst nach release()', () async {
    final fake = FakeSignatureUnit()..mode = FakeMode.silent;
    Uint8List? result;
    final pending = fake.sign('x').then((v) => result = v);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(result, isNull);
    fake.release();
    await pending;
    expect(result, isNotNull);
    expect(result!.length, 64);
  });
}
