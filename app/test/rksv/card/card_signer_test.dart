// Der Halter der Karte gegen den nachgebauten Leser mit Karte. PINs stehen
// nur in den Körpern; die Karte hat die erfundene PIN 246813.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/rksv/card/atrust_card.dart';
import 'package:kassa/rksv/card/card_signer.dart';
import 'package:kassa/rksv/card/pin_guard.dart';
import 'package:kassa/rksv/card/reader_transport.dart';
import 'package:kassa/rksv/rksv_secrets.dart';

import '../../support/fake_card_reader.dart';
import '../../support/scripted_reader.dart' show bytesOf;
import '../fixtures/test_card.dart';

const tpdu = 0x00010030;
const shortApdu = 0x00020030;
const acosId41Atr = '3BDF97008131FE4680319052410464050401AC73D622C0F9';
const cardPinDigits = '246813';
const number = '0102030405060708';

/// [hexText] mit dem Prüfbyte der ATR dahinter.
String withTck(String hexText) {
  final bytes = bytesOf(hexText);
  var check = 0;
  for (var i = 1; i < bytes.length; i++) {
    check ^= bytes[i];
  }
  return hexText + check.toRadixString(16).padLeft(2, '0').toUpperCase();
}

final acosAtr = withTck('3BBF11008131FE45455041${'00' * 12}');

FakeCard cardOf(
  String atrHex, {
  String pin = cardPinDigits,
  Uint8List? number,
  bool verifyPerSignature = true,
}) {
  final atr = bytesOf(atrHex);
  return FakeCard(
    atr: atr,
    profile: profileForAtr(atr)!,
    pin: pin,
    certificate: testCertificate,
    number: number,
    signer: testSigner,
    verifyPerSignature: verifyPerSignature,
  );
}

CardPin storedPin({
  String kind = 'acosId41',
  String numberHex = number,
  String pin = cardPinDigits,
}) => CardPin(kind: kind, numberHex: numberHex, pin: pin);

Uint8List hashOf(int seed) =>
    Uint8List.fromList(List.generate(32, (i) => (seed * 31 + i) & 0xFF));

Matcher fails(CardSignProblem problem) => throwsA(
  isA<CardSignException>().having((e) => e.problem, 'problem', problem),
);

/// Reicht alles an den nachgebauten Leser weiter und wartet bei jedem
/// Austausch [delay]; zählt, wie viele Austausche zugleich laufen.
class DelayedReader implements ReaderTransport {
  DelayedReader(this.inner, this.delay);

  final FakeCardReader inner;
  final Duration delay;
  int inFlight = 0;
  int maxInFlight = 0;

  @override
  Future<List<UsbDeviceInfo>> list() => inner.list();

  @override
  Future<Uint8List> open(String address) => inner.open(address);

  @override
  Future<Uint8List> exchange(Uint8List? out, {required Duration limit}) async {
    inFlight++;
    if (inFlight > maxInFlight) maxInFlight = inFlight;
    try {
      await Future<void>.delayed(delay);
      return await inner.exchange(out, limit: limit);
    } finally {
      inFlight--;
    }
  }

  @override
  Future<void> close() => inner.close();

  @override
  Future<TabletInfo> info() => inner.info();
}

/// Ein Wächter, dessen Lesen oder Löschen scheitert.
class BrokenGuard extends MemoryPinGuard {
  BrokenGuard({this.failReads = false, this.failClears = false});

  bool failReads;
  bool failClears;

  @override
  Future<int?> retriesLeft(String cardNumber) async {
    if (failReads) throw StateError('Wächter nicht lesbar');
    return super.retriesLeft(cardNumber);
  }

  @override
  Future<void> clear(String cardNumber) async {
    if (failClears) throw StateError('Wächter löscht nicht');
    return super.clear(cardNumber);
  }
}

class Rig {
  Rig({
    FakeCard? card,
    int features = tpdu,
    bool granted = true,
    MemoryRksvSecrets? secrets,
    MemoryPinGuard? guard,
    ReaderTransport Function(FakeCardReader reader)? wrap,
  }) : reader = FakeCardReader(
         card: card ?? cardOf(acosId41Atr),
         features: features,
         devices: [FakeCardReader.readerDevice(granted: granted)],
       ),
       secrets = secrets ?? MemoryRksvSecrets(),
       guard = guard ?? MemoryPinGuard() {
    signer = CardSigner(
      transport: wrap == null ? reader : wrap(reader),
      secrets: this.secrets,
      guard: this.guard,
    );
  }

  final FakeCardReader reader;
  final MemoryRksvSecrets secrets;
  final MemoryPinGuard guard;
  late final CardSigner signer;

  FakeCard get card => reader.card!;

  int get powerOns => reader.events.where((e) => e == 'powerOn').length;

  /// Befehle an die Karte, gleich auf welcher Stufe.
  int get commands =>
      reader.events.where((e) => e.startsWith('command')).length;

  Future<void> store([CardPin? pin]) =>
      secrets.writeCardPin(pin ?? storedPin());

  Future<Uint8List> sign(int seed) => signer.sign(hashOf(seed));
}

void main() {
  test('Die Sätze der Probleme', () {
    const sentences = {
      CardSignProblem.noReader: 'Kein Kartenleser gefunden.',
      CardSignProblem.noPermission:
          'Der Zugriff auf den Kartenleser ist nicht erlaubt.',
      CardSignProblem.noCard: 'Keine Karte im Kartenleser.',
      CardSignProblem.otherCard: 'Im Kartenleser steckt eine andere Karte.',
      CardSignProblem.pinMissing: 'Die PIN der Karte fehlt.',
      CardSignProblem.pinRejected: 'Die Karte hat die PIN abgelehnt.',
      CardSignProblem.silent: 'Die Karte antwortet nicht.',
      CardSignProblem.refused: 'Die Karte hat die Unterschrift abgelehnt.',
      CardSignProblem.busy: 'Die Karte wird gerade geprüft.',
    };
    expect(sentences.keys.toSet(), CardSignProblem.values.toSet());
    for (final MapEntry(:key, :value) in sentences.entries) {
      expect(CardSignException(key).sentence, value);
    }
  });

  group('Signieren mit offener Sitzung', () {
    test(
      'zwei Bons: ein Einschalten, ein VERIFY, zwei Unterschriften',
      () async {
        final rig = Rig(card: cardOf(acosId41Atr, verifyPerSignature: false));
        await rig.store();
        expect(await rig.sign(1), testSigner(hashOf(1)));
        expect(await rig.sign(2), testSigner(hashOf(2)));
        expect(rig.powerOns, 1);
        expect(rig.card.verifyCount, 1);
        expect(rig.card.signCount, 2);
        expect(rig.signer.ready, isTrue);
        expect(rig.signer.lastProblem, isNull);
        final status = await rig.secrets.cardPinStatus();
        expect(status.rejected, isFalse);
        expect(status.unanswered, 0);
      },
    );

    for (final (name, atr, features) in [
      ('ACOS-ID 4.1, TPDU', acosId41Atr, tpdu),
      ('ACOS-ID 4.1, APDU', acosId41Atr, shortApdu),
      ('ACOS, TPDU', acosAtr, tpdu),
    ]) {
      test('$name: 6982 bei der zweiten Unterschrift, genau ein weiteres '
          'VERIFY', () async {
        final rig = Rig(card: cardOf(atr), features: features);
        await rig.store(
          storedPin(kind: profileForAtr(bytesOf(atr))!.kind.name),
        );
        expect(await rig.sign(1), testSigner(hashOf(1)));
        expect(rig.card.verifyCount, 1);
        expect(await rig.sign(2), testSigner(hashOf(2)));
        expect(rig.card.verifyCount, 2);
        expect(rig.card.signCount, 2);
        expect(rig.powerOns, 1);
      });
    }

    test('zwei sign zugleich laufen nacheinander', () async {
      late DelayedReader delayed;
      final rig = Rig(
        card: cardOf(acosId41Atr, verifyPerSignature: false),
        wrap: (r) =>
            delayed = DelayedReader(r, const Duration(milliseconds: 2)),
      );
      await rig.store();
      final both = await Future.wait([rig.sign(1), rig.sign(2)]);
      expect(both[0], testSigner(hashOf(1)));
      expect(both[1], testSigner(hashOf(2)));
      expect(delayed.maxInFlight, 1);
      expect(rig.powerOns, 1);
      expect(rig.card.verifyCount, 1);
    });

    test('Ein Hash, der nicht 32 Bytes hat, geht nicht zur Karte', () async {
      final rig = Rig();
      await rig.store();
      await expectLater(
        rig.signer.sign(Uint8List(31)),
        fails(CardSignProblem.refused),
      );
      expect(rig.commands, 0);
    });
  });

  group('Review Focus 1: Leser oder Karte weg, dann wieder da', () {
    test('Leser nach n Aufrufen weg, ohne Leser und ohne Karte kein Befehl, '
        'nach dem Wiederanstecken signiert das nächste sign', () async {
      final rig = Rig(card: cardOf(acosId41Atr, verifyPerSignature: false));
      await rig.store();
      await rig.sign(1);

      rig.reader.failAfterExchanges = rig.reader.exchanges;
      await expectLater(rig.sign(2), fails(CardSignProblem.silent));
      expect(rig.signer.ready, isFalse);
      await pumpEventQueue();
      expect(rig.signer.lastProblem, CardSignProblem.silent);

      // Leser abgezogen.
      final device = rig.reader.devices.single;
      rig.reader.devices.clear();
      rig.reader.failAfterExchanges = null;
      final received = rig.card.received.length;
      final exchanges = rig.reader.exchanges;
      await expectLater(rig.sign(3), fails(CardSignProblem.noReader));
      await pumpEventQueue();
      expect(rig.reader.exchanges, exchanges);
      expect(rig.signer.lastProblem, CardSignProblem.noReader);

      // Leser wieder da, die Karte nicht.
      rig.reader.devices.add(device);
      final card = rig.reader.card;
      rig.reader.card = null;
      await expectLater(rig.sign(4), fails(CardSignProblem.noCard));
      await pumpEventQueue();
      expect(card!.received.length, received);
      expect(rig.signer.lastProblem, CardSignProblem.noCard);

      // Karte wieder da: schon das nächste sign signiert.
      rig.reader.card = card;
      expect(await rig.sign(5), testSigner(hashOf(5)));
      expect(rig.signer.ready, isTrue);
      expect(rig.signer.lastProblem, isNull);
      expect(card.signCount, 2);
      expect(card.verifyCount, 2);
    });

    test('Karte gezogen mitten in der Sitzung: noCard', () async {
      final rig = Rig(card: cardOf(acosId41Atr, verifyPerSignature: false));
      await rig.store();
      await rig.sign(1);
      rig.card.removed = true;
      await expectLater(rig.sign(2), fails(CardSignProblem.noCard));
      expect(rig.signer.ready, isFalse);
    });

    test('Nach einem gescheiterten sign wärmt der Halter selbst auf', () async {
      final rig = Rig(card: cardOf(acosId41Atr, verifyPerSignature: false));
      await rig.store();
      await rig.sign(1);
      final broken = rig.reader.exchanges + 1;
      rig.reader.onExchange = (n) {
        if (n == broken) throw const ReaderException(ReaderProblem.io);
      };
      await expectLater(rig.sign(2), fails(CardSignProblem.silent));
      await pumpEventQueue();
      expect(rig.signer.ready, isTrue);
      expect(rig.signer.lastProblem, isNull);
      expect(rig.powerOns, 2);
      // Das Aufwärmen prüft keine PIN.
      expect(rig.card.verifyCount, 1);
      expect(await rig.sign(3), testSigner(hashOf(3)));
      expect(rig.powerOns, 2);
      expect(rig.card.verifyCount, 2);
    });

    test('ein sign während eines laufenden warmUp wartet auf dieses und '
        'öffnet nicht ein zweites Mal', () async {
      final rig = Rig(
        wrap: (r) => DelayedReader(r, const Duration(milliseconds: 2)),
      );
      await rig.store();
      final warming = rig.signer.warmUp();
      final second = rig.signer.warmUp();
      final signed = rig.sign(1);
      await warming;
      await second;
      expect(await signed, testSigner(hashOf(1)));
      expect(rig.reader.opened, hasLength(1));
      expect(rig.powerOns, 1);
    });

    test('warmUp prüft keine PIN und wirft nie', () async {
      final rig = Rig();
      await rig.store();
      await rig.signer.warmUp();
      expect(rig.signer.ready, isTrue);
      expect(rig.card.verifyCount, 0);

      final empty = Rig();
      await empty.store();
      empty.reader.devices.clear();
      await empty.signer.warmUp();
      expect(empty.signer.ready, isFalse);
      expect(empty.signer.lastProblem, CardSignProblem.noReader);
    });

    test('Wird ein sign nach der Frist fertig, bleibt die Sitzung', () async {
      final rig = Rig(
        card: cardOf(acosId41Atr, verifyPerSignature: false),
        wrap: (r) => DelayedReader(r, const Duration(milliseconds: 5)),
      );
      await rig.store();
      await expectLater(
        rig.sign(1).timeout(const Duration(milliseconds: 1)),
        throwsA(isA<TimeoutException>()),
      );
      // Das nächste wartet hinter dem noch laufenden und nutzt seine Sitzung.
      expect(await rig.sign(2), testSigner(hashOf(2)));
      expect(rig.signer.ready, isTrue);
      expect(rig.powerOns, 1);
      expect(rig.card.signCount, 2);
      expect(rig.card.verifyCount, 1);
    });

    test(
      'Scheitert ein sign nach der Frist, bleibt keine Ausnahme offen',
      () async {
        final rig = Rig(
          card: cardOf(acosId41Atr, verifyPerSignature: false),
          wrap: (r) => DelayedReader(r, const Duration(milliseconds: 5)),
        );
        await rig.store();
        await rig.signer.warmUp();
        rig.reader.failAfterExchanges = rig.reader.exchanges;
        await expectLater(
          rig.sign(1).timeout(const Duration(milliseconds: 1)),
          throwsA(isA<TimeoutException>()),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(rig.signer.lastProblem, CardSignProblem.silent);
      },
    );
  });

  group('Review Focus 2: eine andere Karte steckt', () {
    test('andere Kartennummer: kein VERIFY, kein Aufwärmen danach', () async {
      final rig = Rig(
        card: cardOf(
          acosId41Atr,
          number: Uint8List.fromList([9, 9, 9, 9, 9, 9, 9, 9]),
        ),
      );
      await rig.store();
      await expectLater(rig.sign(1), fails(CardSignProblem.otherCard));
      await pumpEventQueue();
      expect(rig.card.verifyCount, 0);
      expect(rig.reader.opened, hasLength(1));
      expect(rig.signer.ready, isFalse);
      expect(rig.signer.lastProblem, CardSignProblem.otherCard);
      await rig.signer.warmUp();
      expect(rig.signer.ready, isFalse);
      expect(rig.card.verifyCount, 0);
    });

    test('andere Kartenart: kein VERIFY', () async {
      final rig = Rig();
      await rig.store(storedPin(kind: 'cardOs53'));
      await expectLater(rig.sign(1), fails(CardSignProblem.otherCard));
      expect(rig.card.verifyCount, 0);
      expect(rig.card.received, isEmpty);
    });
  });

  group('Der PIN-Wächter vor jedem VERIFY', () {
    test(
      'Wächter kennt 1: kein VERIFY, pinRejected, Status unverändert',
      () async {
        final guard = MemoryPinGuard();
        await guard.recordFailure(number, 1);
        final rig = Rig(guard: guard);
        await rig.store();
        await expectLater(rig.sign(1), fails(CardSignProblem.pinRejected));
        await pumpEventQueue();
        expect(rig.card.verifyCount, 0);
        final status = await rig.secrets.cardPinStatus();
        expect(status.rejected, isFalse);
        expect(status.unanswered, 0);
        expect(await guard.retriesLeft(number), 1);

        // Nicht gemerkt: Setzt der Chef den Wächter zurück, geht es.
        await guard.clear(number);
        expect(await rig.sign(2), testSigner(hashOf(2)));
        expect(rig.card.verifyCount, 1);
      },
    );

    test('Wächter kennt 0: kein VERIFY', () async {
      final guard = MemoryPinGuard();
      await guard.recordFailure(number, 0);
      final rig = Rig(guard: guard);
      await rig.store();
      await expectLater(rig.sign(1), fails(CardSignProblem.pinRejected));
      expect(rig.card.verifyCount, 0);
    });

    test('Wächter vor dem 6982-VERIFY gefragt', () async {
      final guard = MemoryPinGuard();
      final rig = Rig(guard: guard);
      await rig.store();
      await rig.sign(1);
      await guard.recordFailure(number, 1);
      await expectLater(rig.sign(2), fails(CardSignProblem.pinRejected));
      expect(rig.card.verifyCount, 1);
    });

    test(
      'Wächter kennt 2: VERIFY geht hinaus, danach ist der Eintrag weg',
      () async {
        final guard = MemoryPinGuard();
        await guard.recordFailure(number, 2);
        final rig = Rig(guard: guard);
        await rig.store();
        expect(await rig.sign(1), testSigner(hashOf(1)));
        expect(rig.card.verifyCount, 1);
        expect(await guard.retriesLeft(number), isNull);
      },
    );

    test('Wächter nicht lesbar: kein VERIFY, silent', () async {
      final rig = Rig(guard: BrokenGuard(failReads: true));
      await rig.store();
      await expectLater(rig.sign(1), fails(CardSignProblem.silent));
      await pumpEventQueue();
      expect(rig.card.verifyCount, 0);
      expect((await rig.secrets.cardPinStatus()).unanswered, 0);
    });

    test(
      'Ein Wächter, der nicht löscht, hält die Unterschrift nicht auf',
      () async {
        final guard = BrokenGuard(failClears: true);
        await guard.recordFailure(number, 2);
        final rig = Rig(guard: guard);
        await rig.store();
        expect(await rig.sign(1), testSigner(hashOf(1)));
        expect(rig.card.verifyCount, 1);
      },
    );
  });

  group('Review Focus 3: die gespeicherte PIN stimmt nicht', () {
    test('falsche PIN: ein VERIFY, abgelehnt im Speicher, auch ein neuer '
        'Halter schickt keins', () async {
      final guard = MemoryPinGuard();
      final rig = Rig(guard: guard);
      await rig.store(storedPin(pin: '111111'));
      await expectLater(rig.sign(1), fails(CardSignProblem.pinRejected));
      expect(rig.card.verifyCount, 1);
      expect(rig.card.retriesLeft, 2);
      expect((await rig.secrets.cardPinStatus()).rejected, isTrue);
      expect(await guard.retriesLeft(number), 2);

      await expectLater(rig.sign(2), fails(CardSignProblem.pinRejected));
      await pumpEventQueue();
      expect(rig.card.verifyCount, 1);

      final again = Rig(card: rig.card, secrets: rig.secrets, guard: guard);
      await expectLater(again.sign(3), fails(CardSignProblem.pinRejected));
      expect(rig.card.verifyCount, 1);
      expect(rig.card.retriesLeft, 2);
    });

    test('Abgelehnt nur im Arbeitsspeicher gilt auch', () async {
      final rig = Rig();
      await rig.store(storedPin(pin: '111111'));
      await expectLater(rig.sign(1), fails(CardSignProblem.pinRejected));
      // Der Speicher vergisst den Status, der Halter nicht.
      await rig.secrets.writeCardPinStatus(const CardPinStatus());
      await expectLater(rig.sign(2), fails(CardSignProblem.pinRejected));
      expect(rig.card.verifyCount, 1);
    });

    test('Eine gesperrte Karte meldet der Halter dem Wächter mit 0', () async {
      final guard = MemoryPinGuard();
      final card = cardOf(acosId41Atr)..retriesLeft = 0;
      final rig = Rig(card: card, guard: guard);
      await rig.store();
      await expectLater(rig.sign(1), fails(CardSignProblem.pinRejected));
      expect(await guard.retriesLeft(number), 0);
      expect((await rig.secrets.cardPinStatus()).rejected, isTrue);
    });

    test('zwei VERIFY ohne Antwort: danach keins mehr', () async {
      final rig = Rig();
      await rig.store();
      rig.reader.dropVerifyAnswers = 2;
      await expectLater(rig.sign(1), fails(CardSignProblem.silent));
      expect((await rig.secrets.cardPinStatus()).unanswered, 1);
      await expectLater(rig.sign(2), fails(CardSignProblem.silent));
      expect((await rig.secrets.cardPinStatus()).unanswered, 2);
      expect(rig.card.verifyCount, 2);

      await expectLater(rig.sign(3), fails(CardSignProblem.pinRejected));
      expect(rig.card.verifyCount, 2);

      final again = Rig(card: rig.card, secrets: rig.secrets);
      await expectLater(again.sign(4), fails(CardSignProblem.pinRejected));
      expect(rig.card.verifyCount, 2);
    });

    test('Ohne Antwort nur im Arbeitsspeicher zählt auch', () async {
      final rig = Rig();
      await rig.store();
      rig.reader.dropVerifyAnswers = 2;
      await expectLater(rig.sign(1), fails(CardSignProblem.silent));
      await rig.secrets.writeCardPinStatus(const CardPinStatus());
      await expectLater(rig.sign(2), fails(CardSignProblem.silent));
      await rig.secrets.writeCardPinStatus(const CardPinStatus());
      await expectLater(rig.sign(3), fails(CardSignProblem.pinRejected));
      expect(rig.card.verifyCount, 2);
    });

    test('ein gelungenes VERIFY dazwischen setzt zurück', () async {
      final rig = Rig(card: cardOf(acosId41Atr, verifyPerSignature: false));
      await rig.store();
      rig.reader.dropVerifyAnswers = 1;
      await expectLater(rig.sign(1), fails(CardSignProblem.silent));
      expect((await rig.secrets.cardPinStatus()).unanswered, 1);
      expect(await rig.sign(2), testSigner(hashOf(2)));
      expect((await rig.secrets.cardPinStatus()).unanswered, 0);

      await rig.signer.release();
      rig.reader.dropVerifyAnswers = 1;
      await expectLater(rig.sign(3), fails(CardSignProblem.silent));
      expect((await rig.secrets.cardPinStatus()).unanswered, 1);
      expect(await rig.sign(4), testSigner(hashOf(4)));
      expect(rig.card.verifyCount, 4);
      expect((await rig.secrets.cardPinStatus()).unanswered, 0);
    });

    test('Schreibt der Speicher nicht, geht kein VERIFY hinaus', () async {
      final rig = Rig();
      await rig.store();
      rig.secrets.failWrites = true;
      await expectLater(rig.sign(1), fails(CardSignProblem.silent));
      await pumpEventQueue();
      expect(rig.card.verifyCount, 0);
      expect(rig.card.signCount, 0);
    });

    test('pinChanged vergisst den Stand und die Sitzung', () async {
      final rig = Rig(card: cardOf(acosId41Atr, verifyPerSignature: false));
      await rig.store(storedPin(pin: '111111'));
      await expectLater(rig.sign(1), fails(CardSignProblem.pinRejected));
      expect(rig.signer.ready, isTrue);

      await rig.store();
      rig.signer.pinChanged();
      await pumpEventQueue();
      expect(rig.signer.ready, isFalse);
      expect(await rig.sign(2), testSigner(hashOf(2)));
      expect(rig.powerOns, 2);
      expect(rig.card.verifyCount, 2);
    });
  });

  group('Erlaubnis, PIN, Pause', () {
    test(
      'ohne Erlaubnis öffnet sign nicht, warmUp(ask: true) öffnet',
      () async {
        final rig = Rig(granted: false);
        await rig.store();
        await expectLater(rig.sign(1), fails(CardSignProblem.noPermission));
        await pumpEventQueue();
        expect(rig.reader.opened, isEmpty);
        await rig.signer.warmUp();
        expect(rig.reader.opened, isEmpty);
        expect(rig.signer.lastProblem, CardSignProblem.noPermission);

        await rig.signer.warmUp(ask: true);
        expect(rig.reader.opened, [FakeCardReader.readerAddress]);
        expect(rig.signer.ready, isTrue);
        expect(await rig.sign(2), testSigner(hashOf(2)));
      },
    );

    test('Verweigert Android das Öffnen, ist das noPermission', () async {
      final rig = Rig();
      rig.reader.permission = false;
      await rig.store();
      await expectLater(rig.sign(1), fails(CardSignProblem.noPermission));
    });

    test('ohne CardPin: pinMissing, ohne die Karte einzuschalten', () async {
      final rig = Rig();
      await expectLater(rig.sign(1), fails(CardSignProblem.pinMissing));
      await pumpEventQueue();
      expect(rig.powerOns, 0);
      expect(rig.reader.opened, isEmpty);
      await rig.signer.warmUp();
      expect(rig.powerOns, 0);
      expect(rig.signer.lastProblem, CardSignProblem.pinMissing);
    });

    test(
      'paused: die Sitzung ist frei, sign ist busy, danach geht es',
      () async {
        final rig = Rig(card: cardOf(acosId41Atr, verifyPerSignature: false));
        await rig.store();
        await rig.sign(1);
        final closed = rig.reader.closed;

        final result = await rig.signer.paused(() async {
          expect(rig.signer.ready, isFalse);
          expect(rig.reader.events.last, 'powerOff');
          expect(rig.reader.closed, closed + 1);
          await expectLater(rig.sign(2), fails(CardSignProblem.busy));
          await rig.signer.warmUp(ask: true);
          expect(rig.signer.lastProblem, CardSignProblem.busy);
          // Verschachtelt.
          await rig.signer.paused(() async {
            await expectLater(rig.sign(3), fails(CardSignProblem.busy));
          });
          await expectLater(rig.sign(4), fails(CardSignProblem.busy));
          await pumpEventQueue();
          expect(rig.signer.ready, isFalse);
          return 7;
        });
        expect(result, 7);
        expect(rig.powerOns, 1);
        expect(await rig.sign(5), testSigner(hashOf(5)));
        expect(rig.powerOns, 2);
      },
    );

    test('paused wartet auf ein laufendes sign', () async {
      final rig = Rig(
        card: cardOf(acosId41Atr, verifyPerSignature: false),
        wrap: (r) => DelayedReader(r, const Duration(milliseconds: 2)),
      );
      await rig.store();
      final signed = rig.sign(1);
      var signedFirst = false;
      unawaited(signed.then((_) => signedFirst = true));
      await rig.signer.paused(() async {
        expect(signedFirst, isTrue);
        expect(rig.signer.ready, isFalse);
      });
      expect(await signed, testSigner(hashOf(1)));
    });
  });

  group('Geheimnisse', () {
    test('die PIN steht in keinem Text und im Protokoll des Lesers nur '
        'maskiert', () async {
      for (final features in [tpdu, shortApdu]) {
        final rig = Rig(features: features);
        await rig.store();
        await rig.sign(1);
        await rig.sign(2);
        await rig.store(storedPin(pin: '111111'));
        rig.signer.pinChanged();
        await expectLater(rig.sign(3), fails(CardSignProblem.pinRejected));
        final texts = [
          ...rig.reader.events,
          ...rig.reader.transfers,
          ...rig.card.received,
          storedPin().toString(),
          for (final p in CardSignProblem.values) ...[
            CardSignException(p).toString(),
            CardSignException(p).sentence,
          ],
          rig.signer.toString(),
        ];
        expect(rig.card.received.where((r) => r.startsWith('002000')), [
          '0020008A08****************',
          '0020008A08****************',
          '0020008A08****************',
        ]);
        for (final text in texts) {
          expect(text, isNot(contains(cardPinDigits)));
          expect(text, isNot(contains('111111')));
          // Die PIN in Format 2.
          expect(text, isNot(contains('26246813')));
          expect(text, isNot(contains('26111111')));
        }
      }
    });
  });
}
