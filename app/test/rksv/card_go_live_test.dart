// Karten-Probe, Angaben für FinanzOnline und Inbetriebnahme mit der
// Signaturkarte im Service (Plan S2c, Task 3, C8, C10, C11; Review Focus 4
// und 5). Echter Halter über dem nachgebauten Leser mit der Karte des Rigs.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/domain/receipt.dart';
import 'package:kassa/rksv/card/atrust_card.dart';
import 'package:kassa/rksv/card/card_facts.dart';
import 'package:kassa/rksv/dep_export.dart';
import 'package:kassa/rksv/rksv_secrets.dart';
import 'package:kassa/rksv/rksv_service.dart';
import 'package:kassa/rksv/rksv_state.dart';
import 'package:kassa/rksv/self_signed_certificate.dart';
import 'package:kassa/rksv/setup_facts.dart';
import 'package:pointycastle/export.dart';

import '../support/fake_atrust.dart';
import '../support/fake_card_reader.dart';
import '../support/rksv_rig.dart';
import '../support/sales.dart' show cart;
import '../support/scripted_reader.dart' show bytesOf;
import 'fixtures/test_card.dart';

const _due = '25.11.2026';
const _serial = 'cf36cd7808';
const _noCard = 'Keine Karte im Kartenleser.';
const _otherCard = 'Im Kartenleser steckt eine andere Karte.';
const _pinRejected = 'Die Karte hat die PIN abgelehnt.';
const _formProblem =
    'Die Kassen-ID darf nur Buchstaben, Ziffern und Bindestriche haben, '
    'höchstens 20 Zeichen.';
const _usedProblem = 'Diese Kassen-ID hat diese Kassa schon verwendet.';
const _storageProblem =
    'Das Tablet konnte den Schlüssel nicht sicher speichern.';
const _generatedId = r'^[A-HJ-NP-Z2-9]{10}$';

Matcher _problem(String message) =>
    throwsA(isA<RksvProblem>().having((p) => p.message, 'message', message));

/// Dieselbe Karte wie die des Rigs, aber mit einer anderen Kartennummer.
FakeCard _otherRigCard() {
  final atr = bytesOf(rigCardAtr);
  return FakeCard(
    atr: atr,
    profile: profileForAtr(atr)!,
    pin: rigCardPin,
    certificate: testCertificate,
    signer: testSigner,
    number: Uint8List.fromList([9, 8, 7, 6, 5, 4, 3, 2]),
    verifyPerSignature: false,
  );
}

/// Eine Karte mit dem Schlüssel der Karte des Rigs, aber einem eigenen
/// Zertifikat mit der Seriennummer 4711 (hex 1267).
FakeCard _ownCertificateCard() {
  final params = ECCurve_secp256r1();
  final d = BigInt.parse(testPrivateKeyHex, radix: 16);
  final atr = bytesOf(rigCardAtr);
  return FakeCard(
    atr: atr,
    profile: profileForAtr(atr)!,
    pin: rigCardPin,
    certificate: buildSelfSignedCertificate(
      key: ECPrivateKey(d, params),
      publicKey: ECPublicKey(params.G * d, params),
      serial: BigInt.from(4711),
      commonName: 'Beispiel-Imbiss Signaturkarte',
      from: DateTime.utc(2026),
    ),
    signer: testSigner,
    verifyPerSignature: false,
  );
}

void main() {
  late RksvRig rig;
  late CardFacts facts;

  setUp(() async {
    rig = await RksvRig.open(card: rigCard());
    await rig.storeCardPin();
    facts = rig.cardFacts();
  });
  tearDown(() => rig.close());

  FakeCard card() => rig.cardReader!.card!;

  group('enableCardProbe', () {
    test('Startbeleg von der Karte signiert, Stand probe, Einheit cardTest, '
        'Testbon', () async {
      final start = await rig.service.enableCardProbe(
        staff: rig.chef,
        facts: facts,
      );
      expect(start.kind, ReceiptKind.start);
      expect(start.rksv!.damaged, isFalse);
      expect(start.rksv!.probe, isTrue);
      expect(card().signCount, 1);

      final chain = await rig.chainRow(1);
      expect(
        (chain.mode, chain.unit, chain.zdaId, chain.certSerial, chain.endedAt),
        ('probe', 'cardTest', 'AT1', _serial, null),
      );
      expect(chain.cashBoxId, matches(RegExp(_generatedId)));
      expect(await rig.secrets.aesKey(1), hasLength(32));

      final state = await rig.rksv.current();
      expect(
        (state.mode, state.unit, state.chain, state.counterCents),
        (RksvMode.probe, RksvUnit.cardTest, 1, 0),
      );
      expect(await rig.tasks(), [
        ('check-start-1', RksvTaskKind.checkStart, ''),
      ]);
      expect((await rig.sell('p1', cart)).rksv!.probe, isTrue);
      expect(await rig.entryKinds(1), ['start', 'sale']);
      await rig.verifyChain(1);
    });

    test('das Zertifikat der Karte kommt in die Datenbank, ohne '
        'Aussteller', () async {
      // Eine Karte mit eigenem Zertifikat (nicht dem der Attrappe).
      final own = await RksvRig.open(card: _ownCertificateCard());
      try {
        await own.storeCardPin();
        final ownFacts = own.cardFacts();
        expect(ownFacts.serialHex, '1267');
        await own.service.enableCardProbe(staff: own.chef, facts: ownFacts);
        final cert = await (own.db.select(
          own.db.rksvCertificateRows,
        )..where((t) => t.serialHex.equals('1267'))).getSingle();
        expect(cert.certificate, ownFacts.certificateDer);
        expect(cert.issuers, '[]');
        expect((await own.chainRow(1)).certSerial, '1267');
        await own.verifyChain(1);
      } finally {
        await own.close();
      }
    });

    test('Karte fehlt: RksvProblem mit dem Satz der Einheit, nichts bleibt '
        'zurück', () async {
      card().removed = true;
      await expectLater(
        rig.service.enableCardProbe(staff: rig.chef, facts: facts),
        _problem(_noCard),
      );
      final state = await rig.stateRow();
      expect((state.mode, state.chain, state.tasks), ('off', null, '[]'));
      expect(await rig.count('rksv_chains'), 0);
      expect(await rig.count('rksv_entries'), 0);
      expect(await rig.count('receipts'), 0);

      // Danach mit Karte: wieder Kette 1.
      card().removed = false;
      await rig.service.enableCardProbe(staff: rig.chef, facts: facts);
      expect((await rig.stateRow()).chain, 1);
      await rig.verifyChain(1);
    });

    test('läuft die Signatur schon: StateError', () async {
      await rig.service.enableProbe(staff: rig.chef);
      await expectLater(
        rig.service.enableCardProbe(staff: rig.chef, facts: facts),
        throwsStateError,
      );
      expect(await rig.count('rksv_chains'), 1);
      expect(card().signCount, 0);
    });

    test('disableProbe beendet die Karten-Probe mit Schlussbeleg von der '
        'Karte', () async {
      await rig.service.enableCardProbe(staff: rig.chef, facts: facts);
      final closing = await rig.service.disableProbe(staff: rig.chef);
      expect(closing.rksv!.damaged, isFalse);
      expect(await rig.entryKinds(1), ['start', 'closing']);
      expect((await rig.stateRow()).mode, 'off');
      await rig.verifyChain(1);
    });
  });

  group('prepareCardSetup', () {
    test('zweimal dieselben Werte; Art Signaturkarte, Anbieter AT1, '
        'Seriennummer hex und dezimal; nichts in der Datenbank', () async {
      final first = await rig.service.prepareCardSetup(facts: facts);
      final second = await rig.service.prepareCardSetup(facts: facts);
      expect(first.kind, 'Signaturkarte');
      expect(first.provider, 'AT1 = A-TRUST');
      expect(first.certSerialHex, _serial);
      expect(first.certSerialDecimal, '889977665544');
      expect(first.cashBoxId, matches(RegExp(_generatedId)));
      expect(base64.decode(first.aesKeyBase64), hasLength(32));
      expect(first.aesChecksum, hasLength(4));
      expect(
        (second.cashBoxId, second.aesKeyBase64, second.aesChecksum),
        (first.cashBoxId, first.aesKeyBase64, first.aesChecksum),
      );
      final pending = (await rig.secrets.pendingSetup())!;
      expect(pending.cashBoxId, first.cashBoxId);
      expect(base64.encode(pending.aesKey), first.aesKeyBase64);
      expect(await rig.count('rksv_chains'), 0);
      expect(await rig.count('receipts'), 0);
      expect(card().signCount, 0);
    });

    test('dasselbe PendingSetup wie prepareSetup', () async {
      final atrust = FakeAtrust();
      final both = await RksvRig.open(atrust: atrust, card: rigCard());
      try {
        final online = await both.service.prepareSetup(
          facts: await both.liveFacts(),
        );
        final withCard = await both.service.prepareCardSetup(
          facts: both.cardFacts(),
        );
        expect(withCard.cashBoxId, online.cashBoxId);
        expect(withCard.aesKeyBase64, online.aesKeyBase64);
        expect(online.kind, setupKind);
        expect(withCard.kind, 'Signaturkarte');
      } finally {
        await both.close();
      }
    });

    test('in Betrieb: StateError', () async {
      await rig.startCardChain();
      await expectLater(
        rig.service.prepareCardSetup(facts: facts),
        throwsStateError,
      );
    });

    test('geschützter Speicher schreibt nicht: RksvProblem, kein '
        'PendingSetup', () async {
      rig.secrets.failWrites = true;
      await expectLater(
        rig.service.prepareCardSetup(facts: facts),
        _problem(_storageProblem),
      );
      rig.secrets.failWrites = false;
      expect(await rig.secrets.pendingSetup(), isNull);
    });
  });

  group('goLiveWithCard', () {
    Future<void> expectLiveChain(int chain, String cashBoxId) async {
      final row = await rig.chainRow(chain);
      expect(
        (row.mode, row.unit, row.zdaId, row.certSerial, row.endedAt),
        ('live', 'card', 'AT1', _serial, null),
      );
      expect(row.cashBoxId, cashBoxId);
      final state = await rig.rksv.current();
      expect(
        (state.mode, state.unit, state.chain, state.counterCents),
        (RksvMode.live, RksvUnit.card, chain, 0),
      );
      expect(state.outage, isFalse);
      expect(await rig.tasks(), [
        (
          'register-finanzonline-$chain',
          RksvTaskKind.registerFinanzOnline,
          _due,
        ),
        ('check-start-$chain', RksvTaskKind.checkStart, ''),
      ]);
      expect(await rig.entryKinds(chain), ['start']);
      expect(await rig.secrets.pendingSetup(), isNull);
      await rig.verifyChain(chain);
      expect(await rig.journal.chainIsSound(chain), isTrue);
    }

    test('aus off: Startbeleg von der Karte, Kette card mit den gezeigten '
        'Angaben, zwei Aufgaben, Zähler 0, PendingSetup weg', () async {
      final shown = await rig.service.prepareCardSetup(facts: facts);
      final start = await rig.service.goLiveWithCard(
        staff: rig.chef,
        facts: facts,
      );
      expect(start.kind, ReceiptKind.start);
      expect(start.rksv!.damaged, isFalse);
      expect(start.rksv!.probe, isFalse);
      expect(card().signCount, 1);
      expect(base64.encode((await rig.secrets.aesKey(1))!), shown.aesKeyBase64);
      await expectLiveChain(1, shown.cashBoxId);
    });

    test('aus der Probe: Schlussbeleg der Probe, neue Kette card', () async {
      await rig.service.enableProbe(staff: rig.chef);
      await rig.sell('p1', cart);
      final shown = await rig.service.prepareCardSetup(facts: facts);
      rig.clock.value = DateTime(2026, 11, 18, 14);
      await rig.service.goLiveWithCard(staff: rig.chef, facts: facts);
      expect(await rig.entryKinds(1), ['start', 'sale', 'closing']);
      expect((await rig.chainRow(1)).endedAt, DateTime(2026, 11, 18, 14));
      await rig.verifyChain(1);
      await expectLiveChain(2, shown.cashBoxId);
    });

    test('aus der Karten-Probe: Schlussbeleg von der Karte, neue Kette '
        'card', () async {
      await rig.service.enableCardProbe(staff: rig.chef, facts: facts);
      final shown = await rig.service.prepareCardSetup(facts: facts);
      await rig.service.goLiveWithCard(staff: rig.chef, facts: facts);
      expect(await rig.entryKinds(1), ['start', 'closing']);
      expect([for (final e in await rig.entries(1)) e.damaged], [false, false]);
      expect((await rig.chainRow(1)).endedAt, isNotNull);
      await rig.verifyChain(1);
      await expectLiveChain(2, shown.cashBoxId);
      // Start und Schluss der Probe, Start der Kette card.
      expect(card().signCount, 3);
    });

    test(
      'ohne PendingSetup: StateError, die Karte unterschreibt nicht',
      () async {
        await expectLater(
          rig.service.goLiveWithCard(staff: rig.chef, facts: facts),
          throwsStateError,
        );
        expect(card().signCount, 0);
        expect(await rig.count('rksv_chains'), 0);
      },
    );

    test('in Betrieb: StateError', () async {
      await rig.startCardChain();
      await rig.secrets.writePendingSetup(
        PendingSetup(
          cashBoxId: 'BSPIMNEU22',
          aesKey: Uint8List.fromList(List.filled(32, 7)),
        ),
      );
      await expectLater(
        rig.service.goLiveWithCard(staff: rig.chef, facts: facts),
        throwsStateError,
      );
      expect(await rig.count('rksv_chains'), 1);
      expect(await rig.secrets.pendingSetup(), isNotNull);
    });

    group('Review Focus 4: der Startbeleg scheitert', () {
      late RksvStateRow before;
      late int receiptsBefore;
      late PendingSetup pendingBefore;

      Future<void> probeRunning({required bool withCard}) async {
        await rig.service.prepareCardSetup(facts: facts);
        if (withCard) {
          await rig.service.enableCardProbe(staff: rig.chef, facts: facts);
        } else {
          await rig.service.enableProbe(staff: rig.chef);
        }
        await rig.sell('p1', cart);
        before = await rig.stateRow();
        receiptsBefore = await rig.count('receipts');
        pendingBefore = (await rig.secrets.pendingSetup())!;
      }

      Future<void> expectAsBefore() async {
        final after = await rig.stateRow();
        expect(after.toJson(), before.toJson());
        expect(after.mode, 'probe');
        expect(await rig.count('rksv_chains'), 1);
        expect((await rig.chainRow(1)).endedAt, isNull);
        // Kein Schlussbeleg.
        expect(await rig.entryKinds(1), ['start', 'sale']);
        expect(await rig.count('receipts'), receiptsBefore);
        final pending = (await rig.secrets.pendingSetup())!;
        expect(pending.cashBoxId, pendingBefore.cashBoxId);
        expect(pending.aesKey, pendingBefore.aesKey);
      }

      Future<void> expectProbeGoesOn() async {
        final p2 = await rig.sell('p2', cart);
        expect(p2.rksv!.probe, isTrue);
        expect(await rig.entryKinds(1), ['start', 'sale', 'sale']);
        await rig.verifyChain(1);
      }

      test('Karte gezogen: RksvProblem mit dem Satz, alles wie vorher, die '
          'Probe läuft ohne Schlussbeleg weiter', () async {
        await probeRunning(withCard: false);
        card().removed = true;
        await expectLater(
          rig.service.goLiveWithCard(staff: rig.chef, facts: facts),
          _problem(_noCard),
        );
        await expectAsBefore();
        await expectProbeGoesOn();

        // Karte wieder da: die Inbetriebnahme gelingt mit denselben Angaben.
        card().removed = false;
        await rig.service.goLiveWithCard(staff: rig.chef, facts: facts);
        expect((await rig.chainRow(2)).cashBoxId, pendingBefore.cashBoxId);
        expect(await rig.entryKinds(1), ['start', 'sale', 'sale', 'closing']);
        await rig.verifyChain(2);
      });

      test('Karte gezogen während einer Karten-Probe: alles wie vorher, auch '
          'ohne Schlussbeleg der Karten-Probe', () async {
        await probeRunning(withCard: true);
        card().removed = true;
        await expectLater(
          rig.service.goLiveWithCard(staff: rig.chef, facts: facts),
          _problem(_noCard),
        );
        await expectAsBefore();
        card().removed = false;
        await expectProbeGoesOn();
      });

      test('eine andere Karte steckt: RksvProblem, keine PIN geht hinaus, '
          'alles wie vorher', () async {
        await probeRunning(withCard: false);
        final other = _otherRigCard();
        rig.cardReader!.card = other;
        await expectLater(
          rig.service.goLiveWithCard(staff: rig.chef, facts: facts),
          _problem(_otherCard),
        );
        expect(other.verifyCount, 0);
        expect(other.signCount, 0);
        await expectAsBefore();
        await expectProbeGoesOn();
      });

      test(
        'die Karte lehnt die PIN ab: RksvProblem, alles wie vorher',
        () async {
          await rig.storeCardPin(pin: '135790');
          await probeRunning(withCard: false);
          await expectLater(
            rig.service.goLiveWithCard(staff: rig.chef, facts: facts),
            _problem(_pinRejected),
          );
          expect(card().verifyCount, 1);
          expect(card().signCount, 0);
          await expectAsBefore();
          await expectProbeGoesOn();
        },
      );
    });

    group('danach', () {
      late int chain;

      setUp(() async => chain = await rig.startCardChain());

      test('Verkauf, Storno und Nullbeleg von der Karte signiert', () async {
        final sold = await rig.sell('s1', cart);
        expect(sold.rksv!.damaged, isFalse);
        expect(sold.rksv!.probe, isFalse);
        final voided = await rig.receipts.voidReceipt('s1', staff: rig.chef);
        expect(voided.rksv!.damaged, isFalse);
        expect((await rig.codeFieldsOf(voided.id))[10], 'U1RP');
        final zero = await rig.service.zeroReceipt(staff: rig.chef);
        expect(zero.rksv!.damaged, isFalse);
        expect(await rig.entryKinds(chain), [
          'start',
          'sale',
          'voided',
          'zero',
        ]);
        expect(card().signCount, 4);
        await rig.verifyChain(chain);
        expect(await rig.service.liveChainSerial(), _serial);
        expect(await rig.service.cardChainSerial(), _serial);
      });

      test('decommission: Schlussbeleg von der Karte', () async {
        final closing = await rig.service.decommission(staff: rig.chef);
        expect(closing.rksv!.damaged, isFalse);
        expect(await rig.entryKinds(chain), ['start', 'closing']);
        final state = await rig.rksv.current();
        expect((state.mode, state.chain), (RksvMode.off, null));
        expect(state.decommissioned, isTrue);
        expect(
          [for (final t in await rig.tasks()) t.$1],
          [
            'register-finanzonline-$chain',
            'check-start-$chain',
            'report-decommission-$chain',
            'backup-decommission-$chain',
          ],
        );
        await rig.verifyChain(chain);
        expect(await rig.service.cardChainSerial(), isNull);
      });

      test('decommission ohne Karte: Schlussbeleg mit Vermerk', () async {
        card().removed = true;
        final closing = await rig.service.decommission(staff: rig.chef);
        expect(closing.rksv!.damaged, isTrue);
        final state = await rig.stateRow();
        expect(
          (state.mode, state.outageSince, state.outageReason),
          ('off', null, null),
        );
        expect(
          [for (final e in await rig.entries(chain)) e.damaged],
          [false, true],
        );
        await rig.verifyChain(chain);
      });

      test('exportProtocol: die Kette mit dem Zertifikat der Karte, ohne '
          'Aussteller, ohne PROBE im Namen', () async {
        await rig.sell('s1', cart);
        expect(
          await rig.service.exportProtocol(
            ExportRange.all,
            now: rig.clock.now(),
          ),
          ExportOutcome.saved,
        );
        expect(rig.saver.lastText, await buildDepExport(rig.db, chain: chain));
        expect(rig.saver.saved.last.$1, isNot(contains('PROBE')));
        final group =
            ((jsonDecode(rig.saver.lastText)
                        as Map<String, dynamic>)['Belege-Gruppe']
                    as List)
                .single;
        expect(group['Signaturzertifikat'], base64.encode(testCertificate));
        expect(group['Zertifizierungsstellen'], isEmpty);
        expect(group['Belege-kompakt'], hasLength(2));
      });

      test('retrySignature nach dem Wiederstecken der Karte', () async {
        card().removed = true;
        await rig.sell('s1', cart);
        expect(await rig.service.retrySignature(staff: rig.chef), isFalse);
        card().removed = false;
        expect(await rig.service.retrySignature(staff: rig.chef), isTrue);
        expect(await rig.entryKinds(chain), ['start', 'sale', 'collective']);
      });
    });
  });

  group('cardChainSerial', () {
    test('null ohne Kette und bei der Probe-Signatur', () async {
      expect(await rig.service.cardChainSerial(), isNull);
      await rig.service.enableProbe(staff: rig.chef);
      expect(await rig.service.cardChainSerial(), isNull);
    });

    test('die Seriennummer der Karten-Probe', () async {
      await rig.service.enableCardProbe(staff: rig.chef, facts: facts);
      expect(await rig.service.cardChainSerial(), _serial);
      expect(await rig.service.liveChainSerial(), isNull);
    });

    test('null bei einer Kette am Testsystem', () async {
      final atrust = FakeAtrust();
      final online = await RksvRig.open(atrust: atrust);
      try {
        await online.startAtrustTest(atrust);
        expect(await online.service.cardChainSerial(), isNull);
      } finally {
        await online.close();
      }
    });
  });

  group('Review Focus 5: changeCashBoxId', () {
    late PendingSetup before;

    setUp(() async {
      await rig.service.prepareCardSetup(facts: facts);
      before = (await rig.secrets.pendingSetup())!;
    });

    Future<void> expectUnchanged() async {
      final now = (await rig.secrets.pendingSetup())!;
      expect(now.cashBoxId, before.cashBoxId);
      expect(now.aesKey, before.aesKey);
    }

    test('kassa-1 wird KASSA-1; der AES-Schlüssel bleibt; prepareCardSetup '
        'und goLiveWithCard verwenden die neue Kennung', () async {
      await rig.service.changeCashBoxId(' kassa-1 ');
      final now = (await rig.secrets.pendingSetup())!;
      expect(now.cashBoxId, 'KASSA-1');
      expect(now.aesKey, before.aesKey);
      final shown = await rig.service.prepareCardSetup(facts: facts);
      expect(shown.cashBoxId, 'KASSA-1');
      expect(shown.aesKeyBase64, base64.encode(before.aesKey));
      await rig.service.goLiveWithCard(staff: rig.chef, facts: facts);
      expect((await rig.chainRow(1)).cashBoxId, 'KASSA-1');
      expect(await rig.secrets.aesKey(1), before.aesKey);
      await rig.verifyChain(1);
    });

    test('prepareSetup zeigt die neue Kennung auch', () async {
      final atrust = FakeAtrust();
      final both = await RksvRig.open(atrust: atrust, card: rigCard());
      try {
        final first = await both.service.prepareCardSetup(
          facts: both.cardFacts(),
        );
        await both.service.changeCashBoxId('KASSA-2');
        final online = await both.service.prepareSetup(
          facts: await both.liveFacts(),
        );
        expect(online.cashBoxId, 'KASSA-2');
        expect(online.aesKeyBase64, first.aesKeyBase64);
      } finally {
        await both.close();
      }
    });

    for (final input in [
      'A_B',
      'ABCDEFGHIJKLMNOPQRSTU',
      '',
      '   ',
      'KASSA 1',
      'KASSA-Ä',
    ]) {
      test('"$input": der Formsatz, PendingSetup unverändert', () async {
        expect(RksvService.cashBoxIdProblem(input), _formProblem);
        await expectLater(
          rig.service.changeCashBoxId(input),
          _problem(_formProblem),
        );
        await expectUnchanged();
      });
    }

    test('cashBoxIdProblem: null für gültige Eingaben', () {
      expect(RksvService.cashBoxIdProblem('kassa-1'), isNull);
      expect(RksvService.cashBoxIdProblem(' A '), isNull);
      expect(RksvService.cashBoxIdProblem('ABCDEFGHIJKLMNOPQRST'), isNull);
      expect(RksvService.cashBoxIdProblem('0-9'), isNull);
    });

    test('20 Zeichen gehen', () async {
      await rig.service.changeCashBoxId('abcdefghijklmnopqrst');
      expect(
        (await rig.secrets.pendingSetup())!.cashBoxId,
        'ABCDEFGHIJKLMNOPQRST',
      );
    });

    test('Kennung einer laufenden oder beendeten Kette: der zweite Satz, '
        'PendingSetup unverändert', () async {
      await rig.service.enableCardProbe(staff: rig.chef, facts: facts);
      final probeId = (await rig.chainRow(1)).cashBoxId;
      await expectLater(
        rig.service.changeCashBoxId(probeId.toLowerCase()),
        _problem(_usedProblem),
      );
      await expectUnchanged();
      await rig.service.disableProbe(staff: rig.chef);
      await expectLater(
        rig.service.changeCashBoxId(probeId),
        _problem(_usedProblem),
      );
      await expectUnchanged();
    });

    test('dieselbe Kennung wie das PendingSetup: kein Fehler, nichts '
        'geschrieben', () async {
      rig.secrets.failPendingSetupWrites = true;
      await rig.service.changeCashBoxId(before.cashBoxId.toLowerCase());
      rig.secrets.failPendingSetupWrites = false;
      await expectUnchanged();
    });

    test('der Speicher schreibt nicht: der Satz des Speichers', () async {
      rig.secrets.failPendingSetupWrites = true;
      await expectLater(
        rig.service.changeCashBoxId('KASSA-3'),
        _problem(_storageProblem),
      );
      rig.secrets.failPendingSetupWrites = false;
      await expectUnchanged();
    });

    test('der Speicher liest nicht: der Satz des Speichers', () async {
      rig.secrets.failReads = true;
      await expectLater(
        rig.service.changeCashBoxId('KASSA-3'),
        _problem('Das Tablet konnte den Schlüssel nicht lesen.'),
      );
      rig.secrets.failReads = false;
      await expectUnchanged();
    });

    test('ohne PendingSetup: StateError', () async {
      await rig.secrets.writePendingSetup(null);
      await expectLater(
        rig.service.changeCashBoxId('KASSA-3'),
        throwsStateError,
      );
      expect(await rig.secrets.pendingSetup(), isNull);
    });

    test('in Betrieb: StateError', () async {
      await rig.service.goLiveWithCard(staff: rig.chef, facts: facts);
      final fresh = PendingSetup(
        cashBoxId: 'BSPIMNEU22',
        aesKey: Uint8List.fromList(List.filled(32, 7)),
      );
      await rig.secrets.writePendingSetup(fresh);
      await expectLater(
        rig.service.changeCashBoxId('KASSA-3'),
        throwsStateError,
      );
      expect((await rig.secrets.pendingSetup())!.cashBoxId, 'BSPIMNEU22');
    });
  });
}
