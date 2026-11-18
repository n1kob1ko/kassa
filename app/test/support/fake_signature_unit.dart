import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:kassa/rksv/card/certificate.dart';
import 'package:kassa/rksv/signature_unit.dart';
import 'package:pointycastle/digests/sha256.dart';

import '../rksv/fixtures/test_card.dart';

enum FakeMode { ok, error, silent }

/// Attrappe der Signatureinheit mit Schlüssel und Zertifikat aus
/// `test_card.dart`. Signiert deterministisch.
class FakeSignatureUnit implements SignatureUnit {
  FakeMode mode = FakeMode.ok;
  int signCalls = 0;
  final Completer<void> _released = Completer<void>();

  /// Bei [FakeMode.silent] kehrt sign() nie zurück, bis dies gerufen wird; dann
  /// mit gültiger Signatur.
  void release() {
    if (!_released.isCompleted) _released.complete();
  }

  @override
  Future<SignerInfo> info() async => SignerInfo(
    zdaId: 'AT100',
    serialHex: CardCertificate.parse(testCertificate).serial.toRadixString(16),
    certificateDer: testCertificate,
  );

  @override
  Future<Uint8List> sign(String signingInput) async {
    signCalls++;
    switch (mode) {
      case FakeMode.error:
        throw const SignatureFailure('Die Attrappe signiert nicht.');
      case FakeMode.silent:
        await _released.future;
      case FakeMode.ok:
        break;
    }
    return testSigner(
      SHA256Digest().process(Uint8List.fromList(ascii.encode(signingInput))),
    );
  }
}
