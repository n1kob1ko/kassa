import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/asn1.dart';
import 'package:pointycastle/export.dart';

/// Gesamtlänge (Kopf plus Inhalt) eines DER-Elements aus seinen ersten Bytes,
/// oder null, wenn die Bytes dafür noch nicht reichen. Auch null für Längen,
/// die es in einem Zertifikat nicht gibt (unbestimmte Länge, mehr als vier
/// Längenbytes): dort wird die Länge nie klar.
///
/// Die Karte liefert die Zertifikatsdatei mit Füllbytes hinter dem Zertifikat;
/// mit dieser Länge liest man genau das Zertifikat.
int? derTotalLength(Uint8List start) {
  if (start.length < 2) return null;
  final first = start[1];
  if (first < 0x80) return 2 + first;
  final count = first & 0x7f;
  if (count == 0 || count > 4) return null;
  if (start.length < 2 + count) return null;
  var length = 0;
  for (var i = 0; i < count; i++) {
    length = (length << 8) | start[2 + i];
  }
  return 2 + count + length;
}

/// Das Signaturzertifikat einer Karte (X.509, Schlüssel auf P-256).
class CardCertificate {
  CardCertificate._({
    required this.der,
    required this.serial,
    required this.issuer,
    required this.subject,
    required this.notBefore,
    required this.notAfter,
    required this.publicKey,
  });

  /// Liest ein Zertifikat. Bytes hinter dem äußeren DER-Element (Füllbytes der
  /// Karte) werden ignoriert. Wirft [FormatException] (und sonst nichts), wenn
  /// die Bytes kein Zertifikat mit Schlüssel auf P-256 sind.
  static CardCertificate parse(Uint8List der) {
    try {
      return _parse(der);
    } catch (_) {
      // Jeder Fehler, auch die FormatExceptions der Bibliotheken, wird zu
      // einem festen Text: deren Texte und `source` enthalten Eingabebytes.
      throw const FormatException('Kein gültiges Zertifikat.');
    }
  }

  /// Das Zertifikat selbst, ohne Füllbytes.
  final Uint8List der;

  /// Nie negativ (die Bytes werden als vorzeichenlose Zahl gelesen).
  final BigInt serial;

  /// CN des Ausstellers, sonst der ganze Name, etwa `C=AT, O=Beispiel`.
  final String issuer;

  /// CN des Inhabers, sonst der ganze Name.
  final String subject;

  /// Beide UTC.
  final DateTime notBefore, notAfter;

  /// 65 Bytes: 04 || X || Y.
  final Uint8List publicKey;

  /// Prüft eine ECDSA-Unterschrift über [sha256], den fertigen 32-Byte-Hash
  /// (er wird nicht noch einmal gehasht). [signature] sind genau 64 Bytes
  /// r || s, alles andere wird als DER (`30 len 02 .. 02 ..`) gelesen. Jede
  /// kaputte Eingabe ergibt false, es wird nichts geworfen.
  bool verify(Uint8List sha256, Uint8List signature) {
    try {
      if (sha256.length != 32) return false;
      final rs = _decodeSignature(signature);
      if (rs == null) return false;
      final (r, s) = rs;
      final n = _curve.n;
      if (r < BigInt.one || r >= n || s < BigInt.one || s >= n) return false;
      final point = _curve.curve.decodePoint(publicKey);
      if (point == null) return false;
      final signer = ECDSASigner(null);
      signer.init(
        false,
        PublicKeyParameter<ECPublicKey>(ECPublicKey(point, _curve)),
      );
      return signer.verifySignature(sha256, ECSignature(r, s));
    } catch (_) {
      return false;
    }
  }
}

final ECDomainParameters _curve = ECCurve_secp256r1();

final BigInt _p = BigInt.parse(
  'ffffffff00000001000000000000000000000000ffffffffffffffffffffffff',
  radix: 16,
);
final BigInt _b = BigInt.parse(
  '5ac635d8aa3a93e7b3ebbd55769886bc651d06b0cc53b0f63bce3c3e27d2604b',
  radix: 16,
);

const _oidEcPublicKey = '1.2.840.10045.2.1';
const _oidPrime256v1 = '1.2.840.10045.3.1.7';
const _oidCommonName = '2.5.4.3';
const _nameLabels = {
  '2.5.4.6': 'C',
  '2.5.4.7': 'L',
  '2.5.4.8': 'ST',
  '2.5.4.10': 'O',
  '2.5.4.11': 'OU',
  '2.5.4.5': 'serialNumber',
};

FormatException _bad() => const FormatException('Kein gültiges Zertifikat.');

CardCertificate _parse(Uint8List input) {
  final total = derTotalLength(input);
  if (total == null || total > input.length || input[0] != 0x30) throw _bad();
  final der = Uint8List.fromList(input.sublist(0, total));

  final outer = _children(ASN1Parser(der).nextObject());
  if (outer.length != 3) throw _bad();
  final tbs = _children(outer[0]);
  var i = tbs.isNotEmpty && tbs[0].tag == 0xA0 ? 1 : 0;
  if (tbs.length < i + 6) throw _bad();

  final serialObject = tbs[i];
  if (serialObject.tag != 0x02) throw _bad();
  final serialBytes = serialObject.valueBytes;
  if (serialBytes == null || serialBytes.isEmpty) throw _bad();
  final serial = _unsigned(serialBytes);

  final issuer = _name(tbs[i + 2]);
  final validity = _children(tbs[i + 3]);
  if (validity.length != 2) throw _bad();
  final notBefore = _time(validity[0]);
  final notAfter = _time(validity[1]);
  final subject = _name(tbs[i + 4]);
  final publicKey = _publicKey(tbs[i + 5]);

  return CardCertificate._(
    der: der,
    serial: serial,
    issuer: issuer,
    subject: subject,
    notBefore: notBefore,
    notAfter: notAfter,
    publicKey: publicKey,
  );
}

List<ASN1Object> _children(ASN1Object o) {
  if (o is! ASN1Sequence && o is! ASN1Set) throw _bad();
  final elements = o is ASN1Sequence ? o.elements : (o as ASN1Set).elements;
  if (elements == null) throw _bad();
  return elements;
}

BigInt _unsigned(Uint8List bytes) {
  var v = BigInt.zero;
  for (final b in bytes) {
    v = (v << 8) | BigInt.from(b);
  }
  return v;
}

String _oid(ASN1Object o) {
  if (o is! ASN1ObjectIdentifier) throw _bad();
  final s = o.objectIdentifierAsString;
  if (s == null) throw _bad();
  return s;
}

String _text(ASN1Object o) {
  final bytes = o.valueBytes;
  if (bytes == null) throw _bad();
  switch (o.tag) {
    case 0x0c: // UTF8String
      return utf8.decode(bytes);
    case 0x1e: // BMPString, UTF-16 big endian
      if (bytes.length.isOdd) throw _bad();
      return String.fromCharCodes([
        for (var k = 0; k < bytes.length; k += 2)
          (bytes[k] << 8) | bytes[k + 1],
      ]);
    case 0x13: // PrintableString
    case 0x16: // IA5String
    case 0x14: // TeletexString
      return latin1.decode(bytes);
    default:
      throw _bad();
  }
}

/// CN, wenn es einen gibt, sonst alle Einträge in der Reihenfolge des
/// Zertifikats als `C=AT, O=Beispiel`.
String _name(ASN1Object name) {
  final parts = <String>[];
  String? cn;
  for (final rdn in _children(name)) {
    for (final atv in _children(rdn)) {
      final pair = _children(atv);
      if (pair.length != 2) throw _bad();
      final oid = _oid(pair[0]);
      final value = _text(pair[1]);
      if (oid == _oidCommonName) cn ??= value;
      parts.add('${_nameLabels[oid] ?? oid}=$value');
    }
  }
  final result = cn ?? parts.join(', ');
  if (result.isEmpty) throw _bad();
  return result;
}

DateTime _time(ASN1Object o) {
  final bytes = o.valueBytes;
  if (bytes == null) throw _bad();
  final text = ascii.decode(bytes, allowInvalid: false);
  final RegExpMatch? m;
  int year;
  if (o.tag == 0x17) {
    m = RegExp(r'^(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)Z$').firstMatch(text);
    if (m == null) throw _bad();
    final yy = int.parse(m[1]!);
    year = yy >= 50 ? 1900 + yy : 2000 + yy;
  } else if (o.tag == 0x18) {
    m = RegExp(r'^(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)Z$').firstMatch(text);
    if (m == null) throw _bad();
    year = int.parse(m[1]!);
  } else {
    throw _bad();
  }
  final parts = [for (var k = 2; k <= 6; k++) int.parse(m[k]!)];
  final t = DateTime.utc(
    year,
    parts[0],
    parts[1],
    parts[2],
    parts[3],
    parts[4],
  );
  if (t.year != year ||
      t.month != parts[0] ||
      t.day != parts[1] ||
      t.hour != parts[2] ||
      t.minute != parts[3] ||
      t.second != parts[4]) {
    throw _bad();
  }
  return t;
}

Uint8List _publicKey(ASN1Object spki) {
  final parts = _children(spki);
  if (parts.length != 2) throw _bad();
  final algorithm = _children(parts[0]);
  if (algorithm.length != 2) throw _bad();
  if (_oid(algorithm[0]) != _oidEcPublicKey ||
      _oid(algorithm[1]) != _oidPrime256v1) {
    throw _bad();
  }
  final bits = parts[1];
  final value = bits.valueBytes;
  if (bits.tag != 0x03 ||
      value == null ||
      value.length != 66 ||
      value[0] != 0 ||
      value[1] != 0x04) {
    throw _bad();
  }
  final point = Uint8List.fromList(value.sublist(1));
  final x = _unsigned(point.sublist(1, 33));
  final y = _unsigned(point.sublist(33));
  if (x >= _p || y >= _p) throw _bad();
  // y^2 = x^3 - 3x + b (mod p)
  final left = (y * y) % _p;
  final right = (x * x * x - BigInt.from(3) * x + _b) % _p;
  if (left != right) throw _bad();
  return point;
}

/// Eine ECDSA-Unterschrift als genau 64 Bytes r || s, jede Zahl links mit
/// Nullen auf 32 Bytes. Liest dieselben Formen wie [CardCertificate.verify]:
/// 64 Bytes r || s (als Kopie zurück) oder DER (`30 len 02 .. 02 ..`).
/// `null` für alles andere, auch für eine negative oder zu große Zahl.
Uint8List? signatureAsRs(Uint8List sig) {
  final rs = _decodeSignature(sig);
  if (rs == null) return null;
  final (r, s) = rs;
  if (r.bitLength > 256 || s.bitLength > 256) return null;
  final out = Uint8List(64);
  for (final (offset, v) in [(0, r), (32, s)]) {
    for (var i = 31; i >= 0; i--) {
      out[offset + i] = (v >> (8 * (31 - i))).toUnsigned(8).toInt();
    }
  }
  return out;
}

(BigInt, BigInt)? _decodeSignature(Uint8List sig) {
  if (sig.length == 64) {
    return (_unsigned(sig.sublist(0, 32)), _unsigned(sig.sublist(32)));
  }
  // DER: 30 len 02 rl r 02 sl s, ohne Reste.
  if (sig.length < 8 || sig[0] != 0x30) return null;
  var pos = 1;
  var seqLength = sig[pos++];
  if (seqLength == 0x81) {
    seqLength = sig[pos++];
  } else if (seqLength >= 0x80) {
    return null;
  }
  if (pos + seqLength != sig.length) return null;
  BigInt? readInteger() {
    if (pos + 2 > sig.length || sig[pos] != 0x02) return null;
    final length = sig[pos + 1];
    pos += 2;
    if (length == 0 || pos + length > sig.length) return null;
    if (sig[pos] & 0x80 != 0) return null; // negativ
    final v = _unsigned(sig.sublist(pos, pos + length));
    pos += length;
    return v;
  }

  final r = readInteger();
  final s = readInteger();
  if (r == null || s == null || pos != sig.length) return null;
  return (r, s);
}
