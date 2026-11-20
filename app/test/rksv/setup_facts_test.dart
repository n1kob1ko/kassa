// Angaben für FinanzOnline (Plan S2b, Task 3): Prüfwert des AES-Schlüssels
// und Seriennummer dezimal.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/rksv/setup_facts.dart';

/// Base64 der Bytes 0 bis 31.
const _key0to31 = 'AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8=';

/// Base64 der Bytes 255 bis 224.
const _key255down = '//79/Pv6+fj39vX08/Lx8O/u7ezr6uno5+bl5OPi4eA=';

void main() {
  group('aesKeyChecksum', () {
    // Vergleichswerte nicht aus dem eigenen Code: nach dem Rechenweg von
    // AESCheckSum.java (SHA-256 über den Base64-Text, die ersten 3 Bytes,
    // Base64 ohne "=") mit java.security.MessageDigest und mit Pythons
    // hashlib gerechnet; beide ergaben dieselben Werte.
    test('stimmt mit den Vergleichswerten überein', () {
      expect(aesKeyChecksum(_key0to31), 'kF8o');
      expect(aesKeyChecksum(_key255down), 'dt/o');
    });

    test('vier Zeichen, Base64 ohne "="', () {
      expect(aesKeyChecksum(_key0to31), hasLength(4));
      expect(aesKeyChecksum(_key0to31), isNot(contains('=')));
    });
  });

  group('setupFactsOf', () {
    final key = Uint8List.fromList(List.generate(32, (i) => i));

    test('Art, Anbieter, Kennung, Schlüssel und Prüfwert', () {
      final f = setupFactsOf(
        zdaId: 'AT1',
        certSerialHex: '2159b9f6',
        cashBoxId: 'BSPIMBECHT',
        aesKey: key,
      );
      expect(f.kind, 'Hardware-Sicherheitsmodul (HSM) eines Dienstleisters');
      expect(f.provider, 'AT1 = A-TRUST');
      expect(f.certSerialHex, '2159b9f6');
      expect(f.certSerialDecimal, '559528438');
      expect(f.cashBoxId, 'BSPIMBECHT');
      expect(f.aesKeyBase64, _key0to31);
      expect(base64.decode(f.aesKeyBase64), key);
      expect(f.aesChecksum, 'kF8o');
    });

    test('certSerialDecimal auch bei mehr als 64 Bit', () {
      const hex = '1a2b3c4d5e6f708192a3b4c5d6e7f8091';
      final f = setupFactsOf(
        zdaId: 'AT1',
        certSerialHex: hex,
        cashBoxId: 'BSPIMBECHT',
        aesKey: key,
      );
      expect(f.certSerialHex, hex);
      // 33 Hex-Ziffern, 129 Bit; die Dezimalzahl mit Python gerechnet.
      expect(f.certSerialDecimal, '556550715675133695464503065076368900241');
    });

    test('toString nennt weder Schlüssel noch Prüfwert', () {
      final f = setupFactsOf(
        zdaId: 'AT1',
        certSerialHex: '2159b9f6',
        cashBoxId: 'BSPIMBECHT',
        aesKey: key,
      );
      expect(f.toString(), isNot(contains(_key0to31)));
      expect(f.toString(), isNot(contains('kF8o')));
    });
  });
}
