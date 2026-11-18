import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/asn1.dart';
import 'package:pointycastle/export.dart';

/// ECDSA P-256 über den fertigen SHA-256-Wert [sha256], deterministisch nach
/// RFC 6979. Ergebnis: 64 Bytes r || s, links mit Nullen aufgefüllt.
Uint8List ecdsaSignSha256(BigInt privateScalar, Uint8List sha256) {
  final params = ECCurve_secp256r1();
  final signer = ECDSASigner(null, HMac(SHA256Digest(), 64));
  signer.init(
    true,
    PrivateKeyParameter<ECPrivateKey>(ECPrivateKey(privateScalar, params)),
  );
  final sig = signer.generateSignature(sha256) as ECSignature;
  final out = Uint8List(64);
  for (final (offset, v) in [(0, sig.r), (32, sig.s)]) {
    for (var i = 31; i >= 0; i--) {
      out[offset + i] = (v >> (8 * (31 - i))).toUnsigned(8).toInt();
    }
  }
  return out;
}

/// Seriennummer eines Zertifikats als Kleinbuchstaben-Hex ohne führende Nullen.
String certificateSerialHex(Uint8List der) {
  final outer = ASN1Parser(der).nextObject() as ASN1Sequence;
  final tbs = outer.elements![0] as ASN1Sequence;
  final first = tbs.elements![0];
  final serial = first.tag == 0xA0 ? tbs.elements![1] : first;
  var v = BigInt.zero;
  for (final b in serial.valueBytes!) {
    v = (v << 8) | BigInt.from(b);
  }
  return v.toRadixString(16);
}

// Alles weitere schreibt DER von Hand, damit jedes Byte feststeht: die
// Prüfung des Finanzministeriums liest das Zertifikat mit einem Java-Parser.

Uint8List _tlv(int tag, List<int> content) {
  final n = content.length;
  final length = n < 0x80
      ? [n]
      : n < 0x100
      ? [0x81, n]
      : [0x82, n >> 8, n & 0xff];
  return Uint8List.fromList([tag, ...length, ...content]);
}

Uint8List _seq(List<List<int>> parts) =>
    _tlv(0x30, [for (final p in parts) ...p]);

Uint8List _oid(List<int> body) => _tlv(0x06, body);

/// Positive Zahl, kürzeste Form, mit führendem 0x00, wenn das Top-Bit gesetzt
/// ist.
Uint8List _unsignedInteger(BigInt v) {
  assert(v >= BigInt.zero);
  final bytes = <int>[];
  var rest = v;
  do {
    bytes.insert(0, (rest & BigInt.from(0xff)).toInt());
    rest >>= 8;
  } while (rest > BigInt.zero);
  if (bytes.first & 0x80 != 0) bytes.insert(0, 0);
  return _tlv(0x02, bytes);
}

String _two(int v) => v.toString().padLeft(2, '0');

Uint8List _time(DateTime t) {
  final u = t.toUtc();
  final rest =
      '${_two(u.month)}${_two(u.day)}${_two(u.hour)}'
      '${_two(u.minute)}${_two(u.second)}Z';
  if (u.year < 2050) {
    return _tlv(0x17, ascii.encode('${_two(u.year % 100)}$rest'));
  }
  return _tlv(0x18, ascii.encode('${u.year.toString().padLeft(4, '0')}$rest'));
}

final _algorithm = _seq([
  _oid([0x2a, 0x86, 0x48, 0xce, 0x3d, 0x04, 0x03, 0x02]), // ecdsa-with-SHA256
]);

/// Selbst ausgestelltes X.509-Zertifikat (Version 3, ecdsa-with-SHA256, Kurve
/// P-256). Inhaber und Aussteller: CN=[commonName]. Gültig von [from] zehn
/// Jahre. Das Zertifikat hat keine Erweiterungen.
Uint8List buildSelfSignedCertificate({
  required ECPrivateKey key,
  required ECPublicKey publicKey,
  required BigInt serial,
  required String commonName,
  required DateTime from,
}) {
  final start = from.toUtc();
  final end = DateTime.utc(
    start.year + 10,
    start.month,
    start.day,
    start.hour,
    start.minute,
    start.second,
  );
  final name = _seq([
    _tlv(
      0x31,
      _seq([
        _oid([0x55, 0x04, 0x03]), // commonName
        _tlv(0x0c, utf8.encode(commonName)),
      ]),
    ),
  ]);
  final spki = _seq([
    _seq([
      _oid([0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02, 0x01]), // id-ecPublicKey
      _oid([0x2a, 0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07]), // prime256v1
    ]),
    _tlv(0x03, [0x00, ...publicKey.Q!.getEncoded(false)]),
  ]);
  final tbs = _seq([
    [0xA0, 0x03, 0x02, 0x01, 0x02], // version 3
    _unsignedInteger(serial),
    _algorithm,
    name,
    _seq([_time(start), _time(end)]),
    name,
    spki,
  ]);
  final raw = ecdsaSignSha256(key.d!, SHA256Digest().process(tbs));
  Uint8List half(int offset) => Uint8List.sublistView(raw, offset, offset + 32);
  BigInt number(Uint8List b) =>
      b.fold(BigInt.zero, (acc, x) => (acc << 8) | BigInt.from(x));
  final signature = _seq([
    _unsignedInteger(number(half(0))),
    _unsignedInteger(number(half(32))),
  ]);
  return _seq([
    tbs,
    _algorithm,
    _tlv(0x03, [0x00, ...signature]),
  ]);
}
