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
      // Erst in 64 Bytes r|s bringen, dann genau diese prüfen: Gespeichert
      // wird, was geprüft wurde.
      final signature =
          signatureAsRs(answer) ?? (throw const SignatureFailure(_mismatch));
      if (!certificate.verify(hash, signature)) {
        throw const SignatureFailure(_mismatch);
      }
      return signature;
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
