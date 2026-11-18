import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/rksv/card/atrust_card.dart';

import '../../support/scripted_reader.dart';

/// `AABBCC` ohne Leerzeichen, Großbuchstaben.
String compact(Uint8List data) =>
    data.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join();

CardProfile profileOf(String atrHex) => profileForAtr(bytesOf(atrHex))!;

const acosAtrA = '3BBF11008131FE45455041';
const acosAtrB = '3BBF11008131FE454D4341';
const cardOsAtrA = '3BDF18008131FE588031B05202046405C903AC73B7B1D422';
const cardOsAtrB = '3BDF18008131FE588031905241016405C903AC73B7B1D444';
const acosId2Cold = '3BDF96FF910131FE4680319052410264050200AC73D622C017';
const acosId2Warm = '3BDF18FF910131FE4680319052410264050200AC73D622C099';
const acosId3Atr = '3BDF97008131FE4680319052410364050201AC73D622C0F8';
const acosId41Atr = '3BDF97008131FE4680319052410464050401AC73D622C0F9';

final hash = Uint8List.fromList(List.generate(32, (i) => i + 1));
final hashHex = compact(hash);

void main() {
  test('profileForAtr: jede der acht ATRs aus der Tabelle ergibt ihre Art; eine fremde ATR null', () {
    const expected = {
      acosAtrA: CardKind.acos,
      acosAtrB: CardKind.acos,
      cardOsAtrA: CardKind.cardOs53,
      cardOsAtrB: CardKind.cardOs53,
      acosId2Cold: CardKind.acosId2,
      acosId2Warm: CardKind.acosId2,
      acosId3Atr: CardKind.acosId3,
      acosId41Atr: CardKind.acosId41,
    };
    for (final MapEntry(key: atr, value: kind) in expected.entries) {
      expect(profileOf(atr).kind, kind, reason: atr);
    }
    expect(
      profileForAtr(bytesOf('3B8F8001804F0CA000000306030001000000006A')),
      isNull,
    );
    expect(profileForAtr(bytesOf('3BBF11008131FE4545')), isNull);
    expect(profileForAtr(Uint8List(0)), isNull);

    final acos = profileOf(acosAtrA);
    expect(acos.label, 'a.sign RK CHIP (erste Generation, ACOS)');
    expect(
      acos.notice,
      'Das ist eine Karte der ersten Generation. Frag bei A-Trust nach, '
      'wie lange sie noch gilt.',
    );
    expect(acos.applications, [
      bytesOf('A0000001184543'),
      bytesOf('A000000118454E'),
    ]);
    expect(acos.signatureFolder, [0xDF, 0x70]);
    expect(acos.certificateFile, [0xC0, 0x02]);
    expect(acos.numberFolder, [0xDF, 0x71]);
    expect(acos.numberFile, [0xD0, 0x01]);
    expect(acos.pinFormat, PinFormat.ascii);
    expect(acos.pinReference, 0x81);
    expect(acos.separateHash, isTrue);

    final cardOs = profileOf(cardOsAtrB);
    expect(cardOs.label, 'a.sign RK CHIP (CardOS 5.3)');
    expect(
      cardOs.notice,
      'Diese Kartenart muss voraussichtlich bis Mai 2027 getauscht werden.',
    );
    expect(cardOs.applications, [bytesOf('D0400000220001')]);
    expect(cardOs.signatureFolder, [0xDF, 0x01]);
    expect(cardOs.certificateFile, [0xC0, 0x00]);
    expect(cardOs.numberFolder, [0x3F, 0x00]);
    expect(cardOs.numberFile, [0xD0, 0x01]);
    expect(cardOs.pinFormat, PinFormat.format2);
    expect(cardOs.pinReference, 0x81);
    expect(cardOs.separateHash, isFalse);

    const exchangeBy2027 =
        'Diese Kartenart muss bis spätestens Mai 2027 getauscht werden.';
    final labels = {
      acosId2Cold: ('a.sign RK CHIP (ACOS-ID 2.1)', exchangeBy2027),
      acosId2Warm: ('a.sign RK CHIP (ACOS-ID 2.1)', exchangeBy2027),
      acosId3Atr: ('a.sign RK CHIP (ACOS-ID 3)', exchangeBy2027),
      acosId41Atr: ('a.sign RK CHIP (ACOS-ID 4.1)', null),
    };
    for (final MapEntry(key: atr, value: (label, notice)) in labels.entries) {
      final p = profileOf(atr);
      expect(p.label, label, reason: atr);
      expect(p.notice, notice, reason: atr);
      expect(p.applications, [bytesOf('D0400000220001')], reason: atr);
      expect(p.signatureFolder, [0xDF, 0x01], reason: atr);
      expect(p.certificateFile, [0xC0, 0x00], reason: atr);
      expect(p.numberFolder, [0x3F, 0x00], reason: atr);
      expect(p.numberFile, [0xD0, 0x01], reason: atr);
      expect(p.pinFormat, PinFormat.format2, reason: atr);
      expect(p.pinReference, 0x8A, reason: atr);
      expect(p.separateHash, isFalse, reason: atr);
    }
  });

  test('profileForAtr: eine längere ATR, die mit 3BBF11008131FE45455041 beginnt, ist acos', () {
    final longer = profileForAtr(
      bytesOf('3BBF11008131FE45455041000000000000000000000000AA'),
    );
    expect(longer?.kind, CardKind.acos);
    final cardOsLonger = profileForAtr(bytesOf('${cardOsAtrA}00'));
    expect(cardOsLonger?.kind, CardKind.cardOs53);
  });

  test('Befehle Byte für Byte: jede Zeile der Tabelle', () {
    expect(
      compact(CardCommand.selectFile([0xDF, 0x01]).bytes),
      '00A4000C02DF01',
    );
    expect(
      compact(CardCommand.selectFile([0x3F, 0x00]).bytes),
      '00A4000C023F00',
    );
    expect(
      compact(CardCommand.selectApplication(bytesOf('D0400000220001')).bytes),
      '00A4040C07D0400000220001',
    );
    expect(compact(CardCommand.readBinary(0).bytes), '00B0000000');
    expect(compact(CardCommand.readCardNumber().bytes), '00B0000008');
    expect(
      compact(CardCommand.prepareSignature().bytes),
      '002241B606840188800144',
    );
    expect(compact(CardCommand.putHash(hash).bytes), '002A908120$hashHex');
    final acos = profileOf(acosAtrA);
    final acosId41 = profileOf(acosId41Atr);
    expect(compact(CardCommand.sign(acos, hash).bytes), '002A9E9A00');
    expect(
      compact(CardCommand.sign(acosId41, hash).bytes),
      '002A9E9A20${hashHex}40',
    );

    for (final command in [
      CardCommand.selectFile([0xDF, 0x01]),
      CardCommand.selectApplication(bytesOf('D0400000220001')),
      CardCommand.readBinary(0),
      CardCommand.readCardNumber(),
      CardCommand.prepareSignature(),
      CardCommand.putHash(hash),
      CardCommand.sign(acos, hash),
      CardCommand.sign(acosId41, hash),
    ]) {
      expect(command.secret, isFalse, reason: command.label);
      expect(command.label, isNotEmpty);
    }

    // Die Bytes lassen sich von außen nicht ändern.
    final select = CardCommand.selectFile([0x3F, 0x00]);
    expect(() => select.bytes[1] = 0x20, throwsUnsupportedError);
    // Falsche Längen gehen gar nicht erst hinaus.
    expect(() => CardCommand.selectFile([0x3F]), throwsArgumentError);
    expect(
      () => CardCommand.selectFile([0x3F, 0x00, 0x01]),
      throwsArgumentError,
    );
    expect(() => CardCommand.selectFile([0x3F, 0x100]), throwsArgumentError);
    expect(() => CardCommand.selectApplication([]), throwsArgumentError);
    expect(() => CardCommand.putHash(Uint8List(31)), throwsArgumentError);
    expect(
      () => CardCommand.sign(acosId41, Uint8List(33)),
      throwsArgumentError,
    );
    expect(() => CardCommand.readBinary(-1), throwsArgumentError);
    expect(() => CardCommand.readBinary(0x10000), throwsArgumentError);
  });

  test('readBinary(256) == 00B0010000; readBinary(0x8100) nutzt nur 7 Bits im ersten Byte', () {
    expect(compact(CardCommand.readBinary(256).bytes), '00B0010000');
    expect(compact(CardCommand.readBinary(0x7FFF).bytes), '00B07FFF00');
    // Bit 8 im ersten Byte hieße "kurze Kennung der Datei" (implizite
    // Auswahl); es bleibt immer 0.
    expect(compact(CardCommand.readBinary(0x8100).bytes), '00B0010000');
    expect(compact(CardCommand.readBinary(0xFFFF).bytes), '00B07FFF00');
  });

  test('verifyPin acosId41 mit 123456: 0020008A0826123456FFFFFFFF, secret', () {
    final command = CardCommand.verifyPin(profileOf(acosId41Atr), '123456');
    expect(compact(command.bytes), '0020008A0826123456FFFFFFFF');
    expect(command.secret, isTrue);
  });

  test('verifyPin cardOs53 mit 1234: 0020008108241234FFFFFFFFFF', () {
    final command = CardCommand.verifyPin(profileOf(cardOsAtrA), '1234');
    expect(compact(command.bytes), '0020008108241234FFFFFFFFFF');
    expect(command.secret, isTrue);
  });

  test('verifyPin acos mit 123456: 00200081083132333435360000', () {
    final command = CardCommand.verifyPin(profileOf(acosAtrB), '123456');
    expect(compact(command.bytes), '00200081083132333435360000');
    expect(command.secret, isTrue);
    expect(
      compact(CardCommand.verifyPin(profileOf(acosAtrB), '1234').bytes),
      '00200081083132333400000000',
    );
  });

  test('verifyPin lehnt 5 Ziffern, 7 Ziffern, Buchstaben und leer ab (ArgumentError)', () {
    for (final profile in [
      profileOf(acosAtrA),
      profileOf(cardOsAtrA),
      profileOf(acosId41Atr),
    ]) {
      for (final pin in [
        '12345',
        '1234567',
        '12a456',
        'abcd',
        '',
        '12 456',
        '１２３４',
        '12345678',
      ]) {
        Object? error;
        try {
          CardCommand.verifyPin(profile, pin);
        } catch (e) {
          error = e;
        }
        expect(error, isA<ArgumentError>(), reason: profile.label);
        // Der Fehlertext nennt die Eingabe nicht.
        if (pin.isNotEmpty) {
          expect(error.toString(), isNot(contains(pin)));
        }
      }
    }
  });

  test('sign acosId41: 002A9E9A20 + Hash + 40; sign acos: 002A9E9A00', () {
    expect(
      compact(CardCommand.sign(profileOf(acosId41Atr), hash).bytes),
      '002A9E9A20${hashHex}40',
    );
    expect(
      compact(CardCommand.sign(profileOf(cardOsAtrA), hash).bytes),
      '002A9E9A20${hashHex}40',
    );
    expect(
      compact(CardCommand.sign(profileOf(acosAtrA), hash).bytes),
      '002A9E9A00',
    );
  });

  test('CardCommand.toString nennt label, aber weder Bytes noch PIN', () {
    final verify = CardCommand.verifyPin(profileOf(acosId41Atr), '493817');
    final select = CardCommand.selectFile([0xDF, 0x01]);
    for (final command in [verify, select, CardCommand.putHash(hash)]) {
      final text = command.toString();
      expect(text, contains(command.label));
      final spaced = command.bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join(' ');
      for (final form in [compact(command.bytes), spaced]) {
        expect(text.toUpperCase(), isNot(contains(form.toUpperCase())));
      }
    }
    final text = verify.toString();
    for (final secret in [
      '493817',
      '26493817',
      '26 49 38 17',
      '34 39 33 38 31 37',
      '343933383137',
    ]) {
      expect(text, isNot(contains(secret)));
    }
    expect(select.toString(), isNot(contains('DF01')));
  });
}
