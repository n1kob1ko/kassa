// Die Signaturkarten von A-Trust (a.sign RK CHIP): welche Art an der ATR zu
// erkennen ist, wo Zertifikat und Kartennummer liegen, und die vollständige
// Liste der Befehle, die je zur Karte gehen. Quelle: A-Trust, "cash register
// smart card manual" 0.3 und das Beispiel in Java von A-Trust.
//
// Schutz der Karte: Einen Befehl gibt es nur über die Fabriken von
// [CardCommand]. Es gibt keinen Weg, einen Befehl aus freien Bytes zu bauen.

import 'dart:typed_data';

enum CardKind { acos, cardOs53, acosId2, acosId3, acosId41 }

/// Wie die PIN in den 8 Bytes von VERIFY steht.
enum PinFormat {
  /// Die Ziffern als Zeichen, Rest `00`.
  ascii,

  /// ISO 9564 Format 2: `2` und Länge, je zwei Ziffern in einem Byte, Rest `F`.
  format2,
}

// final: Kein anderer Code kann ein Profil mit eigener PIN-Referenz oder
// eigenem PIN-Format nachbauen (`implements`).
final class CardProfile {
  const CardProfile._({
    required this.kind,
    required this.label,
    required this.notice,
    required this.applications,
    required this.signatureFolder,
    required this.certificateFile,
    required this.numberFolder,
    required this.numberFile,
    required this.pinFormat,
    required this.pinReference,
    required this.separateHash,
  });

  final CardKind kind;

  /// Text am Bildschirm.
  final String label;

  /// Hinweis zum Tausch, sonst `null`.
  final String? notice;

  /// AIDs, die auf der Karte da sein müssen.
  final List<List<int>> applications;

  /// Je 2 Bytes.
  final List<int> signatureFolder, certificateFile, numberFolder, numberFile;
  final PinFormat pinFormat;

  /// P2 von VERIFY.
  final int pinReference;

  /// Der Hash geht mit eigenem Befehl zur Karte (`putHash`); nur bei [CardKind.acos].
  final bool separateHash;
}

const _acos = CardProfile._(
  kind: CardKind.acos,
  label: 'a.sign RK CHIP (erste Generation, ACOS)',
  notice:
      'Das ist eine Karte der ersten Generation. Frag bei A-Trust nach, wie '
      'lange sie noch gilt.',
  applications: [
    [0xA0, 0x00, 0x00, 0x01, 0x18, 0x45, 0x43],
    [0xA0, 0x00, 0x00, 0x01, 0x18, 0x45, 0x4E],
  ],
  signatureFolder: [0xDF, 0x70],
  certificateFile: [0xC0, 0x02],
  numberFolder: [0xDF, 0x71],
  numberFile: [0xD0, 0x01],
  pinFormat: PinFormat.ascii,
  pinReference: 0x81,
  separateHash: true,
);

const _signatureApplication = [0xD0, 0x40, 0x00, 0x00, 0x22, 0x00, 0x01];
const _exchangeBy2027 =
    'Diese Kartenart muss bis spätestens Mai 2027 getauscht werden.';

CardProfile _acosId(CardKind kind, String label, String? notice) =>
    CardProfile._(
      kind: kind,
      label: label,
      notice: notice,
      applications: const [_signatureApplication],
      signatureFolder: const [0xDF, 0x01],
      certificateFile: const [0xC0, 0x00],
      numberFolder: const [0x3F, 0x00],
      numberFile: const [0xD0, 0x01],
      pinFormat: PinFormat.format2,
      pinReference: 0x8A,
      separateHash: false,
    );

const _cardOs53 = CardProfile._(
  kind: CardKind.cardOs53,
  label: 'a.sign RK CHIP (CardOS 5.3)',
  notice: 'Diese Kartenart muss voraussichtlich bis Mai 2027 getauscht werden.',
  applications: [_signatureApplication],
  signatureFolder: [0xDF, 0x01],
  certificateFile: [0xC0, 0x00],
  numberFolder: [0x3F, 0x00],
  numberFile: [0xD0, 0x01],
  pinFormat: PinFormat.format2,
  pinReference: 0x81,
  separateHash: false,
);

final _acosId2 = _acosId(
  CardKind.acosId2,
  'a.sign RK CHIP (ACOS-ID 2.1)',
  _exchangeBy2027,
);
final _acosId3 = _acosId(
  CardKind.acosId3,
  'a.sign RK CHIP (ACOS-ID 3)',
  _exchangeBy2027,
);
final _acosId41 = _acosId(
  CardKind.acosId41,
  'a.sign RK CHIP (ACOS-ID 4.1)',
  null,
);

/// Anfang der ATR und Art, in der Reihenfolge von A-Trust.
final _known = <(String, CardProfile)>[
  ('3BBF11008131FE45455041', _acos),
  ('3BBF11008131FE454D4341', _acos),
  ('3BDF18008131FE588031B05202046405C903AC73B7B1D422', _cardOs53),
  ('3BDF18008131FE588031905241016405C903AC73B7B1D444', _cardOs53),
  ('3BDF96FF910131FE4680319052410264050200AC73D622C017', _acosId2),
  ('3BDF18FF910131FE4680319052410264050200AC73D622C099', _acosId2),
  ('3BDF97008131FE4680319052410364050201AC73D622C0F8', _acosId3),
  ('3BDF97008131FE4680319052410464050401AC73D622C0F9', _acosId41),
];

/// Die Art der Karte, wenn die ATR mit einer aus der Tabelle beginnt, sonst
/// `null`.
CardProfile? profileForAtr(Uint8List atr) {
  final text = atr
      .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join();
  for (final (start, profile) in _known) {
    if (text.startsWith(start)) return profile;
  }
  return null;
}

// final: Ohne `implements` gibt es keinen frei zusammengesetzten Befehl und
// keinen Befehl mit PIN, der sich als nicht geheim ausgibt.
final class CardCommand {
  CardCommand._(List<int> bytes, this.label, {this.secret = false})
    : bytes = Uint8List.fromList(bytes).asUnmodifiableView();

  /// Der ganze Befehl; lässt sich nicht ändern.
  final Uint8List bytes;

  /// Name für das Protokoll; nennt keine Bytes.
  final String label;

  /// Der Befehl trägt die PIN.
  final bool secret;

  static CardCommand selectFile(List<int> fileId) {
    _checkBytes(fileId, 'fileId', length: 2);
    return CardCommand._([
      0x00,
      0xA4,
      0x00,
      0x0C,
      0x02,
      ...fileId,
    ], 'SELECT FILE');
  }

  static CardCommand selectApplication(List<int> aid) {
    _checkBytes(aid, 'aid');
    if (aid.isEmpty || aid.length > 16) {
      throw ArgumentError.value(aid.length, 'aid', 'nicht 1 bis 16 Bytes');
    }
    return CardCommand._([
      0x00,
      0xA4,
      0x04,
      0x0C,
      aid.length,
      ...aid,
    ], 'SELECT APPLICATION');
  }

  /// Liest bis zu 256 Bytes ab [offset]. Vom oberen Byte zählen nur 7 Bits;
  /// das achte hieße "kurze Kennung der Datei".
  static CardCommand readBinary(int offset) {
    if (offset < 0 || offset > 0xFFFF) {
      throw ArgumentError.value(offset, 'offset', 'nicht 0 bis FFFF');
    }
    return CardCommand._([
      0x00,
      0xB0,
      (offset >> 8) & 0x7F,
      offset & 0xFF,
      0x00,
    ], 'READ BINARY');
  }

  /// Liest genau [length] Bytes (1 bis 255) ab [offset]; nur nach einer
  /// Antwort `6Cxx` der Karte auf [readBinary], mit xx als [length].
  static CardCommand readBinaryExact(int offset, int length) {
    if (offset < 0 || offset > 0xFFFF) {
      throw ArgumentError.value(offset, 'offset', 'nicht 0 bis FFFF');
    }
    if (length < 1 || length > 0xFF) {
      throw ArgumentError.value(length, 'length', 'nicht 1 bis FF');
    }
    return CardCommand._([
      0x00,
      0xB0,
      (offset >> 8) & 0x7F,
      offset & 0xFF,
      length,
    ], 'READ BINARY');
  }

  /// Die 8 Bytes der Kartennummer aus der eben gewählten Datei.
  static CardCommand readCardNumber() => CardCommand._(const [
    0x00,
    0xB0,
    0x00,
    0x00,
    0x08,
  ], 'READ BINARY Kartennummer');

  /// MANAGE SECURITY ENVIRONMENT; nur bei [CardKind.acos].
  static CardCommand prepareSignature() => CardCommand._(const [
    0x00,
    0x22,
    0x41,
    0xB6,
    0x06,
    0x84,
    0x01,
    0x88,
    0x80,
    0x01,
    0x44,
  ], 'MANAGE SECURITY ENVIRONMENT');

  /// [ArgumentError], wenn [pin] nicht aus 4 oder 6 Ziffern besteht; der
  /// Fehlertext nennt die Eingabe nicht.
  static CardCommand verifyPin(CardProfile profile, String pin) {
    if (!_pinPattern.hasMatch(pin)) {
      throw ArgumentError('Die PIN hat nicht 4 oder 6 Ziffern.', 'pin');
    }
    final digits = [for (final unit in pin.codeUnits) unit - 0x30];
    final block = switch (profile.pinFormat) {
      PinFormat.ascii => [
        ...pin.codeUnits,
        for (var i = pin.length; i < 8; i++) 0x00,
      ],
      PinFormat.format2 => _format2(digits),
    };
    return CardCommand._(
      [0x00, 0x20, 0x00, profile.pinReference, 0x08, ...block],
      'VERIFY',
      secret: true,
    );
  }

  /// PUT HASH; nur bei [CardKind.acos].
  static CardCommand putHash(Uint8List sha256) {
    _checkHash(sha256);
    return CardCommand._([0x00, 0x2A, 0x90, 0x81, 0x20, ...sha256], 'PUT HASH');
  }

  /// COMPUTE DIGITAL SIGNATURE: bei [CardProfile.separateHash] ohne Daten
  /// (der Hash kam mit [putHash]), sonst mit dem Hash und 64 Bytes erwartet.
  static CardCommand sign(CardProfile profile, Uint8List sha256) {
    _checkHash(sha256);
    return CardCommand._(
      profile.separateHash
          ? const [0x00, 0x2A, 0x9E, 0x9A, 0x00]
          : [0x00, 0x2A, 0x9E, 0x9A, 0x20, ...sha256, 0x40],
      'COMPUTE DIGITAL SIGNATURE',
    );
  }

  static final _pinPattern = RegExp(r'^(?:[0-9]{4}|[0-9]{6})$');

  static List<int> _format2(List<int> digits) {
    final block = List.filled(8, 0xFF)..[0] = 0x20 | digits.length;
    for (var i = 0; i < digits.length; i++) {
      final at = 1 + i ~/ 2;
      block[at] = i.isEven
          ? (digits[i] << 4) | 0x0F
          : (block[at] & 0xF0) | digits[i];
    }
    return block;
  }

  static void _checkBytes(List<int> data, String name, {int? length}) {
    if (length != null && data.length != length) {
      throw ArgumentError.value(data.length, name, 'nicht $length Bytes');
    }
    if (data.any((b) => b < 0 || b > 0xFF)) {
      throw ArgumentError.value(data.length, name, 'kein Byte');
    }
  }

  static void _checkHash(Uint8List sha256) {
    if (sha256.length != 32) {
      throw ArgumentError.value(sha256.length, 'sha256', 'nicht 32 Bytes');
    }
  }

  @override
  String toString() =>
      secret ? 'CardCommand($label, geheim)' : 'CardCommand($label)';
}

/// Die Antwort der Karte: Daten und die zwei Status-Bytes.
class CardResponse {
  const CardResponse(this.data, this.status);

  final Uint8List data;
  final int status;

  bool get ok => status == 0x9000;
}
