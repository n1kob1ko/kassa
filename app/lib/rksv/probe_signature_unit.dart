import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import 'self_signed_certificate.dart';
import 'signature_unit.dart';

/// Die Probe-Signatur: ein Schlüssel auf dem Tablet mit selbst ausgestelltem
/// Zertifikat. Signiert wie die Karte (ECDSA P-256 über SHA-256), aber ohne
/// Karte; Belege daraus sind keine echten Belege der Registrierkasse.
class ProbeSignatureUnit implements SignatureUnit {
  ProbeSignatureUnit({
    required Uint8List privateKey,
    required Uint8List certificateDer,
  }) : _privateKey = Uint8List.fromList(privateKey),
       _certificateDer = Uint8List.fromList(certificateDer);

  final Uint8List _privateKey;
  final Uint8List _certificateDer;

  /// Neuer Schlüssel und Zertifikat mit CN "Kassa Probe-Signatur [cashBoxId]",
  /// Seriennummer aus 8 zufälligen Bytes (positiv).
  static ({Uint8List privateKey, Uint8List certificateDer, String serialHex})
  create({required String cashBoxId, required DateTime now, Random? random}) {
    final rng = random ?? Random.secure();
    final params = ECCurve_secp256r1();
    BigInt draw(int bytes) => List.generate(
      bytes,
      (_) => rng.nextInt(256),
    ).fold(BigInt.zero, (acc, b) => (acc << 8) | BigInt.from(b));

    var d = draw(32);
    while (d < BigInt.one || d >= params.n) {
      d = draw(32);
    }
    var serial = draw(8);
    while (serial == BigInt.zero) {
      serial = draw(8);
    }
    final der = buildSelfSignedCertificate(
      key: ECPrivateKey(d, params),
      publicKey: ECPublicKey(params.G * d, params),
      serial: serial,
      commonName: 'Kassa Probe-Signatur $cashBoxId',
      from: now,
    );
    final keyBytes = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      keyBytes[31 - i] = ((d >> (8 * i)) & BigInt.from(0xff)).toInt();
    }
    return (
      privateKey: keyBytes,
      certificateDer: der,
      serialHex: serial.toRadixString(16),
    );
  }

  @override
  Future<SignerInfo> info() async => SignerInfo(
    zdaId: 'AT100',
    serialHex: certificateSerialHex(_certificateDer),
    certificateDer: _certificateDer,
  );

  @override
  Future<Uint8List> sign(String signingInput) async {
    try {
      final d = _privateKey.fold(
        BigInt.zero,
        (acc, b) => (acc << 8) | BigInt.from(b),
      );
      if (_privateKey.length != 32 ||
          d < BigInt.one ||
          d >= ECCurve_secp256r1().n) {
        throw const FormatException();
      }
      final hash = SHA256Digest().process(
        Uint8List.fromList(utf8.encode(signingInput)),
      );
      return ecdsaSignSha256(d, hash);
    } catch (_) {
      throw const SignatureFailure(
        'Die Probe-Signatur konnte nicht erstellt werden.',
      );
    }
  }

  @override
  String toString() => 'ProbeSignatureUnit';
}
