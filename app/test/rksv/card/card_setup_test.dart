// Der Schritt "Karte und PIN" ohne Bildschirm: CardSetup über einem echten
// Prüflauf und einem echten Halter, gegen den nachgebauten Leser mit Karte.
// PINs stehen nur in den Körpern der Tests.

import 'dart:typed_data';

import 'package:kassa/rksv/card/reader_transport.dart';

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

/// Ein Wächter, der nach dem "Tod" der App nichts mehr annimmt.
class _MortalGuard extends MemoryPinGuard {
  bool dead = false;

  @override
  Future<void> recordFailure(String cardNumber, int retriesLeft) async {
    if (dead) throw StateError('tot');
    return super.recordFailure(cardNumber, retriesLeft);
  }

  @override
  Future<void> clear(String cardNumber) async {
    if (dead) throw StateError('tot');
    return super.clear(cardNumber);
  }
}

/// Der Leser eines Lebens der App: Sobald die Karte ein VERIFY gesehen hat,
/// stirbt die App ([onVerify]); danach geht von ihr nichts mehr zur Karte.
class _DyingReader implements ReaderTransport {
  _DyingReader(this.inner, this.onVerify);

  final FakeCardReader inner;
  final void Function() onVerify;
  bool _dead = false;

  @override
  Future<List<UsbDeviceInfo>> list() => inner.list();

  @override
  Future<Uint8List> open(String address) => inner.open(address);

  @override
  Future<Uint8List> exchange(Uint8List? out, {required Duration limit}) async {
    if (_dead) throw const ReaderException(ReaderProblem.io);
    final before = inner.card!.verifyCount;
    try {
      return await inner.exchange(out, limit: limit);
    } finally {
      if (inner.card!.verifyCount > before) {
        _dead = true;
        onVerify();
      }
    }
  }

  @override
  Future<void> close() => inner.close();

  @override
  Future<TabletInfo> info() => inner.info();
}

/// Ein Leben der App über demselben Leser, Speicher und Wächter: Halter,
/// Prüflauf und "Karte und PIN" neu, wie nach einem Neustart.
class _Life {
  _Life(FakeCardReader reader, MemoryRksvSecrets secrets, _MortalGuard guard) {
    // Wie ein Neustart: Was die tote App noch schreiben wollte, kam nicht an.
    secrets.failWrites = false;
    guard.dead = false;
    final transport = _DyingReader(reader, () {
      secrets.failWrites = true;
      guard.dead = true;
    });
    signer = CardSigner(transport: transport, secrets: secrets, guard: guard);
    check = CardCheck(
      transport: transport,
      guard: guard,
      signer: signer,
      now: () => DateTime(2026, 11, 22, 10),
      appVersion: 'test',
    );
    setup = CardSetup(check: check, secrets: secrets, signer: signer);
  }

  late final CardSigner signer;
  late final CardCheck check;
  late final CardSetup setup;

  /// Ein Bon des Halters, dessen VERIFY ohne Antwort bleibt.
  Future<Object?> halterDies(FakeCardReader reader) async {
    reader.dropVerifyAnswers = 1;
    try {
      await signer.sign(_hash());
      return null;
    } catch (e) {
      return e;
    } finally {
      reader.dropVerifyAnswers = 0;
    }
  }

  /// "Karte und PIN" mit der gespeicherten PIN, deren VERIFY ohne Antwort
  /// bleibt.
  Future<void> setupDies(FakeCardReader reader) async {
    await check.run();
    reader.dropVerifyAnswers = 1;
    try {
      await setup.signWithStored();
    } finally {
      reader.dropVerifyAnswers = 0;
    }
  }
}

final _pinRejected = isA<CardSignException>().having(
  (e) => e.problem,
  'problem',
  CardSignProblem.pinRejected,
);

/// Der Stand der gespeicherten PIN, wie ihn das Speichern hinterlässt.
final _unchanged = isA<CardPinStatus>()
    .having((s) => s.rejected, 'rejected', isFalse)
    .having((s) => s.unanswered, 'unanswered', 0);

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
    test('nach einer grünen Zeile 5: eine PIN, die nicht 4 oder 6 Ziffern '
        'hat, speichert nichts und ruft pinChanged nicht', () async {
      final rig = _Rig();
      await rig.check.run();
      expect(await rig.setup.signAndStore('123456'), isNull);
      expect(rig.check.facts, isNotNull);
      // Danach eine andere gespeicherte PIN, die der Halter ablehnt.
      await rig.store('111111');
      await expectLater(rig.signer.sign(_hash()), throwsA(_pinRejected));
      final verifies = rig.card.verifyCount;
      final status = await rig.secrets.cardPinStatus();
      expect(status.rejected, isTrue);

      expect(await rig.setup.signAndStore('123'), '');
      expect(rig.card.verifyCount, verifies);
      expect((await rig.secrets.cardPin())!.pin, '111111');
      expect((await rig.secrets.cardPinStatus()).rejected, isTrue);
      // Ohne pinChanged bleibt der Halter bei "abgelehnt", auch wenn der
      // Speicher den Stand vergisst: kein VERIFY.
      await rig.secrets.writeCardPinStatus(const CardPinStatus());
      await expectLater(rig.signer.sign(_hash()), throwsA(_pinRejected));
      expect(rig.card.verifyCount, verifies);
      await rig.signer.release();
    });

    test('nach einer grünen Zeile 5: hält der Wächter zurück, speichert sie '
        'nichts', () async {
      final rig = _Rig();
      await rig.check.run();
      expect(await rig.setup.signAndStore('123456'), isNull);
      await rig.store('111111');
      await rig.guard.recordFailure(_cardNumber, 1);
      final verifies = rig.card.verifyCount;

      expect(await rig.setup.signAndStore('123456'), '');
      expect(rig.card.verifyCount, verifies);
      expect((await rig.secrets.cardPin())!.pin, '111111');
      expect(rig.check.facts, isNull);
    });

    test('ohne Karte nach einer grünen Zeile 5: nichts gespeichert', () async {
      final rig = _Rig();
      await rig.check.run();
      expect(await rig.setup.signAndStore('123456'), isNull);
      await rig.store('111111');
      rig.card.removed = true;
      expect(await rig.setup.signAndStore('123456'), '');
      expect((await rig.secrets.cardPin())!.pin, '111111');
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
      // Genau die drei Runden der Probe-Unterschrift von "Karte prüfen"
      // (eine zur Prüfung, zwei für die Dauer, K5), je mit VERIFY; die zweite
      // und dritte nur nach einem angenommenen ersten.
      expect(rig.card.verifyCount, 3);
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
      expect(rig.check.lastSignCountedAgainstPin, isTrue);
      expect((await rig.secrets.cardPinStatus()).rejected, isTrue);
      expect(await rig.setup.storedForReadCard(), isFalse);
      // Ein zweiter Aufruf schickt nichts mehr.
      expect(await rig.setup.signWithStored(), '');
      expect(rig.card.verifyCount, 1);
    });

    test('Karte vor dem VERIFY weg: nicht abgelehnt, der Halter signiert '
        'danach mit der Karte wieder', () async {
      final rig = _Rig();
      await rig.store('123456');
      await rig.check.run();
      rig.card.removed = true;
      expect(await rig.setup.signWithStored(), '');
      expect(rig.card.verifyCount, 0);
      expect(rig.check.lastSignCountedAgainstPin, isFalse);
      expect(await rig.secrets.cardPinStatus(), _unchanged);
      rig.card.removed = false;
      expect(await rig.signer.sign(_hash()), isNotEmpty);
      await rig.signer.release();
    });

    test('VERIFY ohne Antwort: abgelehnt', () async {
      final rig = _Rig();
      await rig.store('123456');
      await rig.check.run();
      rig.reader.dropVerifyAnswers = 1;
      expect(await rig.setup.signWithStored(), '');
      expect(rig.card.verifyCount, 1);
      expect(rig.check.lastSignCountedAgainstPin, isTrue);
      expect((await rig.secrets.cardPinStatus()).rejected, isTrue);
    });

    test(
      'VERIFY angenommen, Unterschrift passt nicht: nicht abgelehnt',
      () async {
        final base = testSignatureCard();
        final rig = _Rig(
          card: FakeCard(
            atr: base.atr,
            profile: base.profile,
            certificate: base.certificate,
            signer: (_) => Uint8List(64),
          ),
        );
        await rig.store('123456');
        await rig.check.run();
        expect(await rig.setup.signWithStored(), '');
        expect(rig.card.verifyCount, 1);
        expect(
          rig.check.state.rows[CheckRow.signature]!.state,
          RowState.problem,
        );
        expect(rig.check.lastSignCountedAgainstPin, isFalse);
        expect(await rig.secrets.cardPinStatus(), _unchanged);
        expect(await rig.setup.storedForReadCard(), isTrue);
      },
    );

    test('ein neuer Lauf setzt das Kennzeichen zurück', () async {
      final rig = _Rig();
      await rig.store('111111');
      await rig.check.run();
      await rig.setup.signWithStored();
      expect(rig.check.lastSignCountedAgainstPin, isTrue);
      await rig.check.run();
      expect(rig.check.lastSignCountedAgainstPin, isFalse);
    });
  });
  group('Halter und Karte prüfen zählen gemeinsam (falsche gespeicherte PIN, '
      'die App stirbt nach jedem VERIFY)', () {
    late FakeCardReader reader;
    late MemoryRksvSecrets secrets;
    late _MortalGuard guard;

    Future<void> start() async {
      reader = FakeCardReader(card: testSignatureCard());
      secrets = MemoryRksvSecrets();
      guard = _MortalGuard();
      await secrets.writeCardPin(
        CardPin(
          kind: reader.card!.profile.kind.name,
          numberHex: _cardNumber,
          pin: '111111',
        ),
      );
    }

    /// Ein neues Leben: Der Halter schickt nichts, Karte prüfen zeigt die
    /// Zeile des Wächters und schickt auch nichts.
    Future<void> expectStopped() async {
      final life = _Life(reader, secrets, guard);
      await expectLater(life.signer.sign(_hash()), throwsA(_pinRejected));
      await life.check.run();
      expect(life.check.state.guardBlocks, isTrue);
      expect(
        life.check.state.rows[CheckRow.signature]!.message,
        'Die Karte hat vermutlich nur noch einen Versuch.',
      );
      expect(await life.setup.signWithStored(), '');
      expect(await guard.retriesLeft(_cardNumber), 1);
      expect(reader.card!.verifyCount, 2);
      expect(reader.card!.retriesLeft, 1);
    }

    test('erst Karte und PIN, dann zwei Bons: zwei VERIFY', () async {
      await start();
      await _Life(reader, secrets, guard).setupDies(reader);
      expect(reader.card!.verifyCount, 1);
      expect(await guard.retriesLeft(_cardNumber), 2);
      await _Life(reader, secrets, guard).halterDies(reader);
      expect(reader.card!.verifyCount, 2);
      await expectStopped();
    });

    test('erst zwei Bons, dann Karte und PIN: zwei VERIFY, der Wächter kennt '
        '1', () async {
      await start();
      await _Life(reader, secrets, guard).halterDies(reader);
      expect(await guard.retriesLeft(_cardNumber), 2);
      await _Life(reader, secrets, guard).halterDies(reader);
      expect(await guard.retriesLeft(_cardNumber), 1);
      expect(reader.card!.verifyCount, 2);
      await expectStopped();
    });

    test('Bon, Karte und PIN, Bon: zwei VERIFY', () async {
      await start();
      await _Life(reader, secrets, guard).halterDies(reader);
      await _Life(reader, secrets, guard).setupDies(reader);
      expect(reader.card!.verifyCount, 2);
      await expectStopped();
    });
  });
}
