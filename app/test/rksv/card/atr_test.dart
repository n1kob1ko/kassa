import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/rksv/card/atr.dart';

import '../../support/scripted_reader.dart';

void main() {
  test('ACOS-ID 4.1: 3BDF97008131FE4680319052410464050401AC73D622C0F9', () {
    final atr = Atr.parse(
      bytesOf('3BDF97008131FE4680319052410464050401AC73D622C0F9'),
    );
    expect(
      atr.bytes,
      bytesOf('3BDF97008131FE4680319052410464050401AC73D622C0F9'),
    );
    expect(atr.inverse, isFalse);
    expect(atr.protocols, [1, 1]);
    expect(atr.ta1, 0x97);
    expect(atr.tc1, 0x00);
    expect(atr.ta2, isNull);
    expect(atr.ifsc, 254);
    expect(atr.waiting, 0x46);
    expect(atr.crc, isFalse);
    expect(atr.historical, bytesOf('80319052410464050401AC73D622C0'));
    expect(atr.checksumOk, isTrue);
    expect(atr.firstProtocol, 1);
  });

  test(
    'ACOS-ID 2.1 kalt: 3BDF96FF910131FE4680319052410264050200AC73D622C017',
    () {
      final atr = Atr.parse(
        bytesOf('3BDF96FF910131FE4680319052410264050200AC73D622C017'),
      );
      expect(atr.protocols, [1, 1]);
      expect(atr.ta1, 0x96);
      expect(atr.tc1, 0xFF);
      expect(atr.ta2, 0x01);
      expect(atr.ifsc, 254);
      expect(atr.waiting, 0x46);
      expect(atr.crc, isFalse);
      expect(atr.historical, bytesOf('80319052410264050200AC73D622C0'));
      expect(atr.firstProtocol, 1);
      expect(atr.checksumOk, isTrue);
    },
  );

  test('CardOS 5.3: 3BDF18008131FE588031B05202046405C903AC73B7B1D422', () {
    final atr = Atr.parse(
      bytesOf('3BDF18008131FE588031B05202046405C903AC73B7B1D422'),
    );
    expect(atr.protocols, [1, 1]);
    expect(atr.ta1, 0x18);
    expect(atr.tc1, 0x00);
    expect(atr.ta2, isNull);
    expect(atr.ifsc, 254);
    expect(atr.waiting, 0x58);
    expect(atr.crc, isFalse);
    expect(atr.historical, bytesOf('8031B05202046405C903AC73B7B1D4'));
    expect(atr.checksumOk, isTrue);
    expect(atr.firstProtocol, 1);
  });

  test('eine ATR ohne Angabe eines Protokolls (3B 02 14 50) hat protocols [0] und kein Prüfbyte', () {
    final atr = Atr.parse(bytesOf('3B 02 14 50'));
    expect(atr.inverse, isFalse);
    expect(atr.protocols, [0]);
    expect(atr.firstProtocol, 0);
    expect(atr.ta1, isNull);
    expect(atr.tc1, isNull);
    expect(atr.ta2, isNull);
    expect(atr.ifsc, 32);
    expect(atr.waiting, 0x4D);
    expect(atr.crc, isFalse);
    expect(atr.historical, bytesOf('14 50'));
    expect(atr.checksumOk, isTrue);
    // Ein Byte mehr wäre ein Prüfbyte, das es hier nicht gibt.
    expect(() => Atr.parse(bytesOf('3B 02 14 50 46')), throwsFormatException);
  });

  test(
    'falsches Prüfbyte: checksumOk false; abgeschnittene ATR: FormatException',
    () {
      const good = '3BDF97008131FE4680319052410464050401AC73D622C0F9';
      final wrong = Atr.parse(
        bytesOf('3BDF97008131FE4680319052410464050401AC73D622C0F8'),
      );
      expect(wrong.checksumOk, isFalse);
      expect(wrong.protocols, [1, 1]);

      final full = bytesOf(good);
      for (var length = 0; length < full.length; length++) {
        expect(
          () => Atr.parse(full.sublist(0, length)),
          throwsFormatException,
          reason: 'nach $length Bytes abgeschnitten',
        );
      }
      // Weder 3B noch 3F am Anfang.
      expect(() => Atr.parse(bytesOf('3C 02 14 50')), throwsFormatException);
    },
  );

  test('3F am Anfang: inverse', () {
    final atr = Atr.parse(bytesOf('3F 02 14 50'));
    expect(atr.inverse, isTrue);
  });

  test('ta2 bestimmt das erste Protokoll', () {
    // TA2 = 10: die Karte bleibt bei Protokoll 0, obwohl TD1 zuerst 1 nennt.
    final atr = Atr.parse(bytesOf('3B 80 91 10 30 01 02 32'));
    expect(atr.protocols, [1, 0]);
    expect(atr.ta2, 0x10);
    expect(atr.firstProtocol, 0);
    expect(atr.ifsc, 0x01);
    expect(atr.waiting, 0x02);
    expect(atr.checksumOk, isTrue);
  });

  test('TC ab der dritten Gruppe mit Bit 0: crc', () {
    final atr = Atr.parse(bytesOf('3B 80 81 41 01 41'));
    expect(atr.protocols, [1, 1]);
    expect(atr.crc, isTrue);
    expect(atr.ifsc, 32);
    expect(atr.checksumOk, isTrue);
  });
}
