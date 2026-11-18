import 'dart:typed_data';

/// Angaben zur Signatureinheit, die auf jeden Beleg und ins Journal kommen.
final class SignerInfo {
  const SignerInfo({
    required this.zdaId,
    required this.serialHex,
    required this.certificateDer,
    this.issuerCertificatesDer = const [],
  });

  /// 'AT100' für Probe-Signatur und Attrappe.
  final String zdaId;

  /// Seriennummer des Zertifikats, Kleinbuchstaben, ohne führende Nullen.
  final String serialHex;
  final Uint8List certificateDer;
  final List<Uint8List> issuerCertificatesDer;
}

/// Die Signatur ist nicht gelungen. Der Grund ist ein deutscher Satz ohne
/// Geheimnisse.
final class SignatureFailure implements Exception {
  const SignatureFailure(this.reason);
  final String reason;

  @override
  String toString() => 'SignatureFailure: $reason';
}

abstract interface class SignatureUnit {
  Future<SignerInfo> info();

  /// ECDSA P-256 über SHA-256 der ASCII-Bytes von [signingInput].
  /// Ergebnis: 64 Bytes R|S. Wirft [SignatureFailure].
  Future<Uint8List> sign(String signingInput);
}
