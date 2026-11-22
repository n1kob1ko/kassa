// Der Schritt "Karte und PIN" ohne Bildschirm: CardSetup über einem echten
// Prüflauf und einem echten Halter, gegen den nachgebauten Leser mit Karte.
// PINs stehen nur in den Körpern der Tests.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/rksv/card/card_check.dart';
import 'package:kassa/rksv/card/card_facts.dart';
import 'package:kassa/rksv/card/card_setup.dart';
import 'package:kassa/rksv/card/card_signer.dart';
import 'package:kassa/rksv/card/certificate.dart';
import 'package:kassa/rksv/card/pin_guard.dart';
import 'package:kassa/rksv/rksv_secrets.dart';

import '../../support/fake_card_reader.dart';
import '../../support/settings_pump.dart' show testSignatureCard;

const _storeProblem = 'Das Tablet konnte die PIN nicht sicher speichern.';
const _cardNumber = '0102030405060708';

/// Ein Speicher, der die PIN annimmt, aber beim Zurücklesen nichts findet.
class _ForgettingSecrets extends MemoryRksvSecrets {
  @override
  Future<CardPin?> cardPin() async => null;
}

class _Rig {
  _Rig({FakeCard? card, MemoryRksvSecrets? secrets, MemoryPinGuard? guard})
    : reader = FakeCardReader(card: card ?? testSignatureCard()),
      secrets = secrets ?? MemoryRksvSecrets(),
      guard = guard ?? MemoryPinGuard() {
    signer = CardSigner(
      transport: reader,
      secrets: this.secrets,
      guard: this.guard,
    );
    check = CardCheck(
      transport: reader,
      guard: this.guard,
      signer: signer,
      now: () => DateTime(2026, 11, 22, 10),
      appVersion: 'test',
    );
    setup = CardSetup(check: check, secrets: this.secrets, signer: signer);
  }

  final FakeCardReader reader;
  final MemoryRksvSecrets secrets;
  final MemoryPinGuard guard;
  late final CardSigner signer;
  late final CardCheck check;
  late final CardSetup setup;

  FakeCard get card => reader.card!;

  CardFacts facts({String? numberHex}) {
    final certificate = CardCertificate.parse(card.certificate);
    return CardFacts(
      kind: card.profile.kind.name,
      numberHex: numberHex ?? _cardNumber,
      certificateDer: certificate.der,
      serialHex: certificate.serial.toRadixString(16),
    );
  }

  Future<void> store(String pin, {String? numberHex}) => secrets.writeCardPin(
    CardPin(
      kind: card.profile.kind.name,
      numberHex: numberHex ?? _cardNumber,
      pin: pin,
    ),
  );
}

Uint8List _hash() => Uint8List(32)..fillRange(0, 32, 7);

void main() {
  group('signAndStore', () {
    test(
      'richtige PIN: gespeichert für Art und Nummer, Rückgabe null',
      () async {
        final rig = _Rig();
        await rig.check.run();
        final kind = rig.card.profile.kind.name;
        expect(rig.check.readCard, (kind: kind, numberHex: _cardNumber));

        expect(await rig.setup.signAndStore('123456'), isNull);
        final stored = await rig.secrets.cardPin();
        expect(stored, isNotNull);
        expect(stored!.kind, kind);
        expect(stored.numberHex, _cardNumber);
        expect(stored.pin, '123456');
        expect(rig.check.facts, isNotNull);
        expect(rig.check.state.rows[CheckRow.signature]!.state, RowState.ok);
        expect(await rig.setup.storedFor(rig.check.facts!), isTrue);
        // Die PIN steht in keinem Text des Schritts.
        expect(rig.setup.toString(), isNot(contains('123456')));
        expect(rig.check.state.report, isNot(contains('123456')));
      },
    );

    test('ein Ablehnen im Halter vergisst er nach der neuen PIN', () async {
      final rig = _Rig();
      await rig.store('111111');
      // Der Halter bekommt "abgelehnt" und schickt danach nichts mehr.
      await expectLater(
        rig.signer.sign(_hash()),
        throwsA(
          isA<CardSignException>().having(
            (e) => e.problem,
            'problem',
            CardSignProblem.pinRejected,
          ),
        ),
      );
      await rig.check.run();
      expect(await rig.setup.signAndStore('123456'), isNull);
      // pinChanged: der Halter signiert wieder mit der neuen PIN.
      final signature = await rig.signer.sign(_hash());
      expect(signature, isNotEmpty);
      await rig.signer.release();
    });

    test('falsche PIN: nichts gespeichert, Rückgabe leer', () async {
      final rig = _Rig();
      await rig.check.run();
      expect(await rig.setup.signAndStore('654321'), '');
      expect(await rig.secrets.cardPin(), isNull);
      expect(rig.check.facts, isNull);
      expect(rig.check.state.rows[CheckRow.signature]!.state, RowState.problem);
      expect(rig.card.verifyCount, 1);
    });

    test('ohne Lauf: keine PIN zur Karte, Rückgabe leer', () async {
      final rig = _Rig();
      expect(rig.check.readCard, isNull);
      expect(await rig.setup.signAndStore('123456'), '');
      expect(rig.card.verifyCount, 0);
      expect(await rig.secrets.cardPin(), isNull);
    });

    test('Speicher schreibt nicht: Satz', () async {
      final secrets = MemoryRksvSecrets();
      final rig = _Rig(secrets: secrets);
      await rig.check.run();
      secrets.failWrites = true;
      expect(await rig.setup.signAndStore('123456'), _storeProblem);
      secrets.failWrites = false;
      expect(await secrets.cardPin(), isNull);
    });

    test('Speicher liest die PIN nicht zurück: Satz', () async {
      final rig = _Rig(secrets: _ForgettingSecrets());
      await rig.check.run();
      expect(await rig.setup.signAndStore('123456'), _storeProblem);
    });
  });

  group('storedFor', () {
    test('nur für dieselbe Karte und nicht abgelehnt', () async {
      final rig = _Rig();
      final facts = rig.facts();
      expect(await rig.setup.storedFor(facts), isFalse);

      await rig.store('123456');
      expect(await rig.setup.storedFor(facts), isTrue);
      expect(
        await rig.setup.storedFor(rig.facts(numberHex: '0909090909090909')),
        isFalse,
      );

      await rig.secrets.writeCardPinStatus(const CardPinStatus(unanswered: 1));
      expect(await rig.setup.storedFor(facts), isTrue);
      await rig.secrets.writeCardPinStatus(const CardPinStatus(unanswered: 2));
      expect(await rig.setup.storedFor(facts), isFalse);
      await rig.secrets.writeCardPinStatus(const CardPinStatus(rejected: true));
      expect(await rig.setup.storedFor(facts), isFalse);
    });

    test(
      'ein Speicher, der nicht liest, zählt als nicht gespeichert',
      () async {
        final secrets = MemoryRksvSecrets();
        final rig = _Rig(secrets: secrets);
        await rig.store('123456');
        secrets.failReads = true;
        expect(await rig.setup.storedFor(rig.facts()), isFalse);
      },
    );

    test('storedForReadCard: nach dem Lauf für die gelesene Karte', () async {
      final rig = _Rig();
      expect(await rig.setup.storedForReadCard(), isFalse);
      await rig.store('123456');
      expect(await rig.setup.storedForReadCard(), isFalse);
      await rig.check.run();
      expect(await rig.setup.storedForReadCard(), isTrue);
    });
  });

  group('signWithStored', () {
    test('gespeicherte PIN: Zeile 5 grün, Angaben da', () async {
      final rig = _Rig();
      await rig.store('123456');
      await rig.check.run();
      expect(await rig.setup.signWithStored(), isNull);
      expect(rig.check.facts, isNotNull);
      expect(rig.card.verifyCount, greaterThan(0));
      expect(await rig.setup.storedForReadCard(), isTrue);
    });

    test('PIN einer anderen Karte: kein VERIFY', () async {
      final rig = _Rig();
      await rig.store('123456', numberHex: '0909090909090909');
      await rig.check.run();
      expect(await rig.setup.signWithStored(), '');
      expect(rig.card.verifyCount, 0);
      expect(rig.check.facts, isNull);
    });

    test('abgelehnte PIN: kein VERIFY', () async {
      final rig = _Rig();
      await rig.store('123456');
      await rig.secrets.writeCardPinStatus(const CardPinStatus(rejected: true));
      await rig.check.run();
      expect(await rig.setup.signWithStored(), '');
      expect(rig.card.verifyCount, 0);
    });

    test('Karte lehnt die gespeicherte PIN ab: ein VERIFY, danach '
        'abgelehnt', () async {
      final rig = _Rig();
      await rig.store('111111');
      await rig.check.run();
      expect(await rig.setup.signWithStored(), '');
      expect(rig.card.verifyCount, 1);
      expect(rig.check.facts, isNull);
      expect((await rig.secrets.cardPinStatus()).rejected, isTrue);
      expect(await rig.setup.storedForReadCard(), isFalse);
      // Ein zweiter Aufruf schickt nichts mehr.
      expect(await rig.setup.signWithStored(), '');
      expect(rig.card.verifyCount, 1);
    });
  });
}
