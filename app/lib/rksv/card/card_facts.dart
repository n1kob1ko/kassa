// Was "Karte prüfen" über eine Karte weiß, deren Probe-Unterschrift gelang:
// die Angaben, mit denen eine Kette mit Karte beginnt. Ohne PIN.

import 'dart:typed_data';

/// Kennung des Anbieters A-Trust für die Signaturkarte (`R1-AT1` im Code).
const cardZdaId = 'AT1';

final class CardFacts {
  const CardFacts({
    required this.kind,
    required this.numberHex,
    required this.certificateDer,
    required this.serialHex,
  });

  /// Die Kartenart (`CardKind.name`), wie in `CardPin.kind`.
  final String kind;

  /// Die Kartennummer, Hex in Großbuchstaben ohne Leerzeichen, wie in
  /// `CardPin.numberHex`.
  final String numberHex;

  /// Das Zertifikat der Karte (DER).
  final Uint8List certificateDer;

  /// Seriennummer des Zertifikats, Kleinbuchstaben, ohne führende Nullen.
  final String serialHex;

  @override
  String toString() => 'CardFacts($kind, $serialHex)';
}
