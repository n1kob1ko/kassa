// Die Signatureinheit mit der Signaturkarte: SHA-256 des Codes über den
// Halter ([CardSigner]) zur Karte, die Antwort als 64 Bytes r|s, geprüft
// gegen das Zertifikat der Kette. Ein Aufwärmen nach einem Fehler startet der
// Halter selbst.

import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/digests/sha256.dart';

import '../self_signed_certificate.dart';
import '../signature_unit.dart';
import 'card_signer.dart';
import 'certificate.dart';

class CardSignatureUnit implements SignatureUnit {
  CardSignatureUnit({
    required this._signer,
    required this._zdaId,
    required Uint8List certificateDer,
  }) : _certificateDer = Uint8List.fromList(certificateDer);

  static const _mismatch =
      'Die Unterschrift der Karte passt nicht zum Zertifikat.';
  static const _failed = 'Die Signatur der Karte ist gescheitert.';

  final CardSigner _signer;
  final String _zdaId;
  final Uint8List _certificateDer;
  CardCertificate? _certificate;

  /// Aussteller-Zertifikate gibt es bei der Karte nicht (Plan C11).
  @override
  Future<SignerInfo> info() async => SignerInfo(
    zdaId: _zdaId,
    serialHex: certificateSerialHex(_certificateDer),
    certificateDer: _certificateDer,
  );

  @override
  Future<Uint8List> sign(String signingInput) async {
    try {
      final certificate = _certificate ??= CardCertificate.parse(
        _certificateDer,
      );
      final hash = SHA256Digest().process(
        Uint8List.fromList(ascii.encode(signingInput)),
      );
      final answer = await _signer.sign(hash);
      // verify liest 64 Bytes r|s und DER; danach steht fest, dass die
      // Antwort eines von beiden ist.
      if (!certificate.verify(hash, answer)) {
        throw const SignatureFailure(_mismatch);
      }
      return _rs(answer) ?? (throw const SignatureFailure(_mismatch));
    } on SignatureFailure {
      rethrow;
    } on CardSignException catch (e) {
      throw SignatureFailure(e.sentence);
    } catch (_) {
      throw const SignatureFailure(_failed);
    }
  }

  @override
  String toString() => 'CardSignatureUnit';
}

/// [answer] als 64 Bytes r|s: so, wie es ist, wenn es 64 Bytes hat, sonst
/// aus DER (`30 len 02 rl r 02 sl s`); `null`, wenn es keines von beiden
/// ist oder eine Zahl länger als 32 Bytes wäre.
Uint8List? _rs(Uint8List answer) {
  if (answer.length == 64) return Uint8List.fromList(answer);
  if (answer.length < 8 || answer[0] != 0x30) return null;
  var pos = 1;
  var length = answer[pos++];
  if (length == 0x81) {
    length = answer[pos++];
  } else if (length >= 0x80) {
    return null;
  }
  if (pos + length != answer.length) return null;
  final out = Uint8List(64);
  for (final offset in [0, 32]) {
    if (pos + 2 > answer.length || answer[pos] != 0x02) return null;
    var size = answer[pos + 1];
    pos += 2;
    if (size == 0 || pos + size > answer.length) return null;
    var start = pos;
    pos += size;
    while (size > 1 && answer[start] == 0) {
      start++;
      size--;
    }
    if (size > 32) return null;
    out.setRange(offset + 32 - size, offset + 32, answer, start);
  }
  return pos == answer.length ? out : null;
}
