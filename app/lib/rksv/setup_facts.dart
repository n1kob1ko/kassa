// Angaben für FinanzOnline (Entwurf 6.7, Schritt 3): was der Chef bei der
// Anmeldung von Signatureinheit und Kassa einträgt.

import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/digests/sha256.dart';

/// Art der Signatureinheit, wie FinanzOnline sie zur Auswahl anbietet: am
/// echten System von A-Trust.
const setupKind = 'Hardware-Sicherheitsmodul (HSM) eines Dienstleisters';

/// Dasselbe für die Signaturkarte.
const setupKindCard = 'Signaturkarte';

/// Alles als Text, wie es am Bildschirm und auf dem Zettel steht. Der
/// AES-Schlüssel ist ein Geheimnis: toString nennt nichts davon.
final class SetupFacts {
  const SetupFacts({
    required this.kind,
    required this.provider,
    required this.certSerialHex,
    required this.certSerialDecimal,
    required this.cashBoxId,
    required this.aesKeyBase64,
    required this.aesChecksum,
  });

  /// [setupKind] oder [setupKindCard].
  final String kind;

  /// `<zdaId> = A-TRUST`, am echten System `AT1 = A-TRUST`.
  final String provider;

  /// Seriennummer des Zertifikats, Kleinbuchstaben ohne führende Nullen.
  final String certSerialHex;

  /// Dieselbe Seriennummer als Dezimalzahl (beliebig lang).
  final String certSerialDecimal;
  final String cashBoxId;

  /// Base64 (nicht Base64-URL), 44 Zeichen.
  final String aesKeyBase64;

  /// [aesKeyChecksum] von [aesKeyBase64].
  final String aesChecksum;

  @override
  String toString() => 'SetupFacts';
}

/// Prüfwert des Finanzministeriums zum AES-Schlüssel (Mustercode
/// `AESCheckSum`, N = 3): SHA-256 über den Base64-Text des Schlüssels, davon
/// die ersten drei Bytes, Base64 ohne "=".
String aesKeyChecksum(String aesKeyBase64) {
  final hash = SHA256Digest().process(
    Uint8List.fromList(ascii.encode(aesKeyBase64)),
  );
  return base64.encode(hash.sublist(0, 3)).replaceAll('=', '');
}

/// Die Angaben zur Art [kind] der Signatureinheit, zu Kennung [zdaId] und
/// Seriennummer [certSerialHex] des Zertifikats von A-Trust (am echten
/// System oder auf der Karte) und zu Kassen-Kennung [cashBoxId] und
/// AES-Schlüssel [aesKey] (32 Bytes) der künftigen Kette.
SetupFacts setupFactsOf({
  required String kind,
  required String zdaId,
  required String certSerialHex,
  required String cashBoxId,
  required Uint8List aesKey,
}) {
  final key = base64.encode(aesKey);
  return SetupFacts(
    kind: kind,
    provider: '$zdaId = A-TRUST',
    certSerialHex: certSerialHex,
    certSerialDecimal: BigInt.parse(certSerialHex, radix: 16).toString(),
    cashBoxId: cashBoxId,
    aesKeyBase64: key,
    aesChecksum: aesKeyChecksum(key),
  );
}
