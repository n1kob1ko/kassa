// Erfundenes Test-Zertifikat ("Beispiel-Imbiss", "Beispiel CA", P-256).
// Der Schlüssel ist nicht echt und gehört zu keiner Karte.
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

const String testCertificateHex =
    '308201773082011da003020102020600cf36cd7808300a06082a8648ce3d0403'
    '023036310b30090603550406130241543111300f060355040a0c084265697370'
    '69656c3114301206035504030c0b426569737069656c204341301e170d323630'
    '3130313030303030305a170d3331303633303233353935395a304f310b300906'
    '035504061302415431183016060355040a0c0f426569737069656c2d496d6269'
    '73733126302406035504030c1d426569737069656c2d496d6269737320536967'
    '6e617475726b617274653059301306072a8648ce3d020106082a8648ce3d0301'
    '0703420004682c6d5e5428ebb28798b1d1ab6be98bc30f31f2a76662fcd12277'
    '2cda747afa69989bb6e137d9c9ecf048f75342ead4583387a25a4aade2744070'
    'e67986c677300a06082a8648ce3d0403020348003045022100fb96e285fd11c6'
    'd0ec121f1a0d4cc5f3213d71d91501f8c10fac523eed65c9dd0220062dde80dd'
    '2d0a94f9f0e87392acc4a266e4645924d7747b4005289abb870725';

/// Privater Schlüssel (Skalar d) des Test-Zertifikats.
const String testPrivateKeyHex =
    '4d7d02d0d6d09fa963812e0ae582dfc471d841d65c20b07a0df1aebed51b8bd1';

/// Öffentlicher Punkt, 04 || X || Y.
const String testPublicKeyHex =
    '04682c6d5e5428ebb28798b1d1ab6be98bc30f31f2a76662fcd122772cda747a'
    'fa69989bb6e137d9c9ecf048f75342ead4583387a25a4aade2744070e67986c6'
    '77';

Uint8List hexToBytes(String hex) {
  final out = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(hex.substring(2 * i, 2 * i + 2), radix: 16);
  }
  return out;
}

final Uint8List testCertificate = hexToBytes(testCertificateHex);

/// Unterschreibt einen fertigen SHA-256-Wert (er wird nicht noch einmal
/// gehasht) deterministisch nach RFC 6979. Ergebnis: 64 Bytes r || s, beide
/// links mit Nullen auf 32 Bytes aufgefüllt.
Uint8List testSigner(Uint8List sha256) {
  final params = ECCurve_secp256r1();
  final key = ECPrivateKey(BigInt.parse(testPrivateKeyHex, radix: 16), params);
  final signer = ECDSASigner(null, HMac(SHA256Digest(), 64));
  signer.init(true, PrivateKeyParameter<ECPrivateKey>(key));
  final sig = signer.generateSignature(sha256) as ECSignature;
  final out = Uint8List(64);
  for (final (offset, v) in [(0, sig.r), (32, sig.s)]) {
    for (var i = 31; i >= 0; i--) {
      out[offset + i] = (v >> (8 * (31 - i))).toUnsigned(8).toInt();
    }
  }
  return out;
}
