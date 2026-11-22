// Die Signatureinheit der Karte über dem Halter und dem nachgebauten Leser.
// Die Karte hat die erfundene PIN 246813.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/rksv/card/atrust_card.dart';
import 'package:kassa/rksv/card/card_facts.dart';
import 'package:kassa/rksv/card/card_signature_unit.dart';
import 'package:kassa/rksv/card/card_signer.dart';
import 'package:kassa/rksv/card/certificate.dart';
import 'package:kassa/rksv/card/pin_guard.dart';
import 'package:kassa/rksv/card/reader_transport.dart';
import 'package:kassa/rksv/rksv_secrets.dart';
import 'package:kassa/rksv/signature_unit.dart';
import 'package:kassa/rksv/self_signed_certificate.dart';
import 'package:pointycastle/export.dart';

import '../../support/fake_card_reader.dart';
import '../../support/scripted_reader.dart' show bytesOf;
import '../fixtures/test_card.dart';

const _acosId41Atr = '3BDF97008131FE4680319052410464050401AC73D622C0F9';
const _pin = '246813';
const _input = 'eyJhbGciOiJFUzI1NiJ9.X1IxLUFUMV9CZWlzcGllbA';
const _mismatch = 'Die Unterschrift der Karte passt nicht zum Zertifikat.';
const _failed = 'Die Signatur der Karte ist gescheitert.';

Uint8List _hashOf(String input) =>
    SHA256Digest().process(Uint8List.fromList(ascii.encode(input)));

/// [rs] (64 Bytes r || s) als DER, wie manche Karten antworten.
Uint8List _der(Uint8List rs) {
  List<int> integer(List<int> v) {
    var i = 0;
    while (i < v.length - 1 && v[i] == 0) {
      i++;
    }
    final body = [if (v[i] & 0x80 != 0) 0, ...v.sublist(i)];
    return [0x02, body.length, ...body];
  }

  final content = [...integer(rs.sublist(0, 32)), ...integer(rs.sublist(32))];
  return Uint8List.fromList([0x30, content.length, ...content]);
}

class _Rig {
  _Rig({Uint8List Function(Uint8List hash)? signer, Uint8List? certificate})
    : reader = FakeCardReader(
        card: FakeCard(
          atr: bytesOf(_acosId41Atr),
          profile: profileForAtr(bytesOf(_acosId41Atr))!,
          pin: _pin,
          certificate: testCertificate,
          signer: signer ?? testSigner,
          verifyPerSignature: false,
        ),
      ) {
    halter = CardSigner(
      transport: reader,
      secrets: secrets,
      guard: MemoryPinGuard(),
    );
    unit = CardSignatureUnit(
      signer: halter,
      zdaId: cardZdaId,
      certificateDer: certificate ?? testCertificate,
    );
  }

  final FakeCardReader reader;
  final secrets = MemoryRksvSecrets();
  late final CardSigner halter;
  late final CardSignatureUnit unit;

  FakeCard get card => reader.card!;

  Future<void> store() => secrets.writeCardPin(
    CardPin(kind: 'acosId41', numberHex: compactHex(fakeCardNumber), pin: _pin),
  );
}

/// Ein Halter, der nie zur Karte geht und mit [error] scheitert.
class _FailingSigner extends CardSigner {
  _FailingSigner(this.error)
    : super(
        transport: FakeCardReader(),
        secrets: MemoryRksvSecrets(),
        guard: MemoryPinGuard(),
      );

  final Object error;

  @override
  Future<Uint8List> sign(Uint8List hash) async => throw error;
}

/// Ein Zertifikat mit einem anderen, erfundenen Schlüssel.
Uint8List _otherCertificate() {
  final params = ECCurve_secp256r1();
  final d = BigInt.from(123456789);
  return buildSelfSignedCertificate(
    key: ECPrivateKey(d, params),
    publicKey: ECPublicKey(params.G * d, params),
    serial: BigInt.from(4711),
    commonName: 'Beispiel-Imbiss andere Karte',
    from: DateTime.utc(2026),
  );
}

Matcher _failure(String reason) =>
    throwsA(isA<SignatureFailure>().having((e) => e.reason, 'reason', reason));

void main() {
  test('cardZdaId ist AT1', () => expect(cardZdaId, 'AT1'));

  test('CardFacts hält Art, Nummer, Zertifikat und Seriennummer', () {
    final facts = CardFacts(
      kind: 'acosId41',
      numberHex: '0102030405060708',
      certificateDer: testCertificate,
      serialHex: 'cf36cd7808',
    );
    expect(
      (facts.kind, facts.numberHex, facts.certificateDer, facts.serialHex),
      ('acosId41', '0102030405060708', testCertificate, 'cf36cd7808'),
    );
  });

  test(
    'info: Kennung, Seriennummer und Zertifikat, keine Aussteller',
    () async {
      final info = await _Rig().unit.info();
      expect(info.zdaId, 'AT1');
      expect(
        info.serialHex,
        CardCertificate.parse(testCertificate).serial.toRadixString(16),
      );
      expect(info.serialHex, 'cf36cd7808');
      expect(info.certificateDer, testCertificate);
      expect(info.issuerCertificatesDer, isEmpty);
    },
  );

  test('gültige Unterschrift: 64 Bytes r|s über SHA-256 der ASCII-Bytes, '
      'die Karte bekam genau diesen Hash', () async {
    final rig = _Rig();
    await rig.store();
    final signature = await rig.unit.sign(_input);
    expect(signature, hasLength(64));
    expect(signature, testSigner(_hashOf(_input)));
    expect(
      CardCertificate.parse(testCertificate).verify(_hashOf(_input), signature),
      isTrue,
    );
    expect(rig.card.signCount, 1);
  });

  test('antwortet die Karte mit DER, kommen trotzdem 64 Bytes r|s', () async {
    final rig = _Rig(signer: (hash) => _der(testSigner(hash)));
    await rig.store();
    final signature = await rig.unit.sign(_input);
    expect(signature, hasLength(64));
    expect(signature, testSigner(_hashOf(_input)));
  });

  test('DER mit kurzem r: links mit Nullen auf 32 Bytes', () async {
    // Ein Eingang, dessen r oder s mit einem Null-Byte beginnt: In DER ist
    // diese Zahl kürzer als 32 Bytes.
    late Uint8List expected;
    var input = '';
    for (var i = 0; ; i++) {
      input = '$_input$i';
      expected = testSigner(_hashOf(input));
      if (expected[0] == 0 || expected[32] == 0) break;
    }
    final rig = _Rig(signer: (hash) => _der(testSigner(hash)));
    await rig.store();
    final signature = await rig.unit.sign(input);
    expect(signature, expected);
  });

  test('DER mit einer negativen Zahl: der Satz, keine Signatur', () async {
    // Ein Eingang, dessen r mit gesetztem obersten Bit beginnt; die Karte
    // lässt die Null davor weg.
    var input = '';
    for (var i = 0; ; i++) {
      input = '$_input$i';
      if (testSigner(_hashOf(input))[0] & 0x80 != 0) break;
    }
    final rig = _Rig(
      signer: (hash) {
        final rs = testSigner(hash);
        final der = _der(rs);
        final sPart = der.sublist(2 + 2 + 33);
        return Uint8List.fromList([
          0x30,
          2 + 32 + sPart.length,
          0x02,
          32,
          ...rs.sublist(0, 32),
          ...sPart,
        ]);
      },
    );
    await rig.store();
    await expectLater(rig.unit.sign(input), _failure(_mismatch));
  });

  test('aus DER zurückgegebene 64 Bytes passen zum Zertifikat', () async {
    final rig = _Rig(signer: (hash) => _der(testSigner(hash)));
    await rig.store();
    final signature = await rig.unit.sign(_input);
    expect(signature, hasLength(64));
    expect(
      CardCertificate.parse(testCertificate).verify(_hashOf(_input), signature),
      isTrue,
    );
  });

  test('falsches Zertifikat: der Satz, keine Signatur', () async {
    final rig = _Rig(certificate: _otherCertificate());
    await rig.store();
    await expectLater(rig.unit.sign(_input), _failure(_mismatch));
    expect(rig.card.signCount, 1);
  });

  test(
    'eine Antwort der Karte, die keine Unterschrift ist: der Satz',
    () async {
      final rig = _Rig(signer: (hash) => Uint8List.fromList(hash));
      await rig.store();
      await expectLater(rig.unit.sign(_input), _failure(_mismatch));
    },
  );

  for (final problem in CardSignProblem.values) {
    test(
      '${problem.name}: SignatureFailure mit dem Satz des Halters',
      () async {
        final unit = CardSignatureUnit(
          signer: _FailingSigner(CardSignException(problem)),
          zdaId: cardZdaId,
          certificateDer: testCertificate,
        );
        await expectLater(
          unit.sign(_input),
          _failure(CardSignException(problem).sentence),
        );
      },
    );
  }

  test(
    'jeder andere Fehler: "Die Signatur der Karte ist gescheitert."',
    () async {
      final unit = CardSignatureUnit(
        signer: _FailingSigner(StateError('kaputt')),
        zdaId: cardZdaId,
        certificateDer: testCertificate,
      );
      await expectLater(unit.sign(_input), _failure(_failed));
    },
  );

  test('ein Zertifikat, das sich nicht lesen lässt: gescheitert, die Karte '
      'unterschreibt nicht', () async {
    final rig = _Rig(certificate: Uint8List.fromList([0x30, 0x03, 1, 2, 3]));
    await rig.store();
    await expectLater(rig.unit.sign(_input), _failure(_failed));
    expect(rig.card.signCount, 0);
  });

  group('am echten Halter', () {
    test('ohne Karte: der Satz, ohne gespeicherte PIN: der Satz', () async {
      final rig = _Rig();
      await expectLater(
        rig.unit.sign(_input),
        _failure('Die PIN der Karte fehlt.'),
      );
      await rig.store();
      rig.card.removed = true;
      await expectLater(
        rig.unit.sign(_input),
        _failure('Keine Karte im Kartenleser.'),
      );
    });

    test('nach einem Fehler läuft warmUp: Die Karte ist wieder da, der '
        'Halter hat ohne weiteren Bon eine Sitzung, und der nächste Bon '
        'signiert', () async {
      final rig = _Rig();
      await rig.store();
      await rig.unit.sign(_input);
      expect(rig.halter.ready, isTrue);

      final broken = rig.reader.exchanges + 1;
      rig.reader.onExchange = (n) {
        if (n == broken) {
          throw const ReaderException(ReaderProblem.io);
        }
      };
      await expectLater(
        rig.unit.sign(_input),
        _failure('Die Karte antwortet nicht.'),
      );
      final powerOns = rig.reader.events.where((e) => e == 'powerOn').length;
      await pumpEventQueue();
      expect(rig.halter.ready, isTrue);
      expect(
        rig.reader.events.where((e) => e == 'powerOn').length,
        powerOns + 1,
      );
      expect(await rig.unit.sign(_input), testSigner(_hashOf(_input)));
    });

    test('während paused: "Die Karte wird gerade geprüft."', () async {
      final rig = _Rig();
      await rig.store();
      await rig.halter.paused(() async {
        await expectLater(
          rig.unit.sign(_input),
          _failure('Die Karte wird gerade geprüft.'),
        );
      });
    });
  });

  test('toString nennt nur die Art', () {
    expect(_Rig().unit.toString(), 'CardSignatureUnit');
  });
}
