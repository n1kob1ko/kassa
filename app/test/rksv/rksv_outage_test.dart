import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/domain/receipt.dart';
import 'package:kassa/rksv/core/rksv_code.dart';
import 'package:kassa/rksv/online/atrust_client.dart';
import 'package:kassa/rksv/online/atrust_session_keeper.dart';
import 'package:kassa/rksv/online/online_signature_unit.dart';
import 'package:kassa/rksv/rksv_journal.dart';
import 'package:kassa/rksv/rksv_state.dart';
import 'package:kassa/rksv/signature_unit.dart';

import '../support/fake_atrust.dart';
import '../support/fake_signature_unit.dart';
import '../support/rksv_rig.dart';
import '../support/sales.dart' show cart;

const _silent = 'Die Signatur hat nicht geantwortet.';

/// Der Satz, mit dem die Attrappe bei [FakeMode.error] scheitert: Er wird
/// der Grund des Ausfalls (P2).
const _error = 'Die Attrappe signiert nicht.';
const _ms = Duration(milliseconds: 1);

/// Wartet in gedachter Zeit auf [f], ohne die Zeit weiterzudrehen.
T _await<T>(FakeAsync async, Future<T> f) {
  late T value;
  Object? error;
  var done = false;
  f.then(
    (v) {
      value = v;
      done = true;
    },
    onError: (Object e) {
      error = e;
      done = true;
    },
  );
  async.flushMicrotasks();
  if (!done) fail('Nicht fertig, ohne dass die Zeit weiterläuft.');
  if (error != null) throw error!;
  return value;
}

/// Ein eigener Aufbau mit laufender Probe, ganz in gedachter Zeit.
void _inFakeTime(void Function(FakeAsync async, RksvRig rig) body) {
  fakeAsync((async) {
    final rig = _await(async, RksvRig.open());
    try {
      _await(async, rig.service.enableProbe(staff: rig.chef));
      body(async, rig);
    } finally {
      _await(async, rig.close());
    }
  });
}

void main() {
  group('Frist der Signatur (fake_async)', () {
    test('Review Focus 2: FakeMode.silent → nach 5 Sekunden (fake_async) '
        'Ausfall-Eintrag; release() danach ändert nichts; signCalls == 1', () {
      _inFakeTime((async, rig) {
        rig.fake.mode = FakeMode.silent;
        final before = rig.fake.signCalls;
        Receipt? sold;
        rig.sell('s1', cart).then((r) => sold = r);
        async.elapse(RksvJournal.signLimit - _ms);
        expect(sold, isNull);
        async.elapse(_ms);
        expect(sold, isNotNull);
        expect(sold!.rksv!.damaged, isTrue);

        final entry = _await(async, rig.entryOf('s1'))!;
        expect(entry.damaged, isTrue);
        expect(isDamagedJws(entry.jws), isTrue);
        final state = _await(async, rig.stateRow());
        expect(state.outageSince, rig.clock.now());
        expect(state.outageReason, _silent);
        // Kein unerwartetes Ende der Probe (K9), nur ein Ausfall.
        expect((state.mode, state.chain, state.notice), ('probe', 1, null));

        // Die späte Antwort wird verworfen.
        rig.fake.release();
        async.elapse(const Duration(seconds: 1));
        expect(_await(async, rig.entryOf('s1'))!.jws, entry.jws);
        expect(_await(async, rig.count('rksv_entries')), 2);
        expect(_await(async, rig.count('receipts')), 2);
        expect(_await(async, rig.stateRow()).counterCents, 1820);
        expect(rig.fake.signCalls - before, 1);
        _await(async, rig.verifyChain(1));
      });
    });

    test('Review Focus 1: A-Trust antwortet erst nach der Frist (echte '
        'OnlineSignatureUnit, FakeAtrust.delay 6 Sekunden): der Bon steht '
        'nach 5 Sekunden mit Ausfall-Vermerk und genau einem Eintrag; die '
        'späte Antwort schreibt nichts und hinterlässt keinen Fehler', () {
      fakeAsync((async) {
        final atrust = FakeAtrust()..delay = const Duration(seconds: 6);
        late final AtrustSessionKeeper keeper;
        final rig = _await(
          async,
          RksvRig.open(
            unitOf: (db, secrets) => signatureUnitOf(
              db,
              secrets,
              online: (chain, cert) async => OnlineSignatureUnit(
                client: AtrustClient(atrust.client, AtrustSystem.test),
                keeper: keeper,
                zdaId: chain.zdaId,
                certificateDer: cert.certificate,
              ),
            ),
          ),
        );
        keeper = AtrustSessionKeeper(
          client: AtrustClient(atrust.client, AtrustSystem.test),
          user: atrustTestUser,
          password: atrustTestPassword,
          secrets: rig.secrets,
          clock: rig.clock,
        );
        try {
          _await(async, rig.startAtrustTest(atrust));
          Receipt? sold;
          rig.sell('s1', cart).then((r) => sold = r);
          async.elapse(RksvJournal.signLimit - _ms);
          expect(sold, isNull);
          async.elapse(_ms);
          expect(sold, isNotNull);
          expect(sold!.rksv!.damaged, isTrue);
          expect(atrust.requests, ['PUT /Session/u123456789']);

          final entry = _await(async, rig.entryOf('s1'))!;
          expect((entry.chain, entry.position, entry.damaged), (1, 1, true));
          expect(isDamagedJws(entry.jws), isTrue);
          expect(_await(async, rig.count('rksv_entries')), 1);
          final state = _await(async, rig.stateRow());
          expect(
            (state.outageSince, state.outageReason),
            (rig.clock.now(), _silent),
          );
          expect((state.mode, state.chain, state.notice), ('probe', 1, null));

          // Anmeldung nach 6, Signatur nach 12 Sekunden: Beides kommt an und
          // wird verworfen.
          async.elapse(const Duration(seconds: 20));
          expect(atrust.requests, hasLength(2));
          expect(atrust.requests.last, endsWith('/Sign/Hash'));
          expect(async.pendingTimers, isEmpty);
          expect(_await(async, rig.entryOf('s1'))!.jws, entry.jws);
          expect(_await(async, rig.count('rksv_entries')), 1);
          expect(_await(async, rig.count('receipts')), 1);
          final after = _await(async, rig.stateRow());
          expect(
            (after.outageSince, after.outageReason, after.counterCents),
            (state.outageSince, _silent, 1820),
          );
          _await(async, rig.verifyChain(1));
        } finally {
          _await(async, rig.close());
        }
      });
    });

    test('im Ausfall: nächster Verkauf wartet höchstens 1 Sekunde, kein '
        'zweiter Signaturversuch (signCalls steigt um 1)', () {
      _inFakeTime((async, rig) {
        rig.fake.mode = FakeMode.silent;
        rig.sell('s1', cart);
        async.elapse(RksvJournal.signLimit);
        final since = _await(async, rig.stateRow()).outageSince;
        expect(since, isNotNull);

        final before = rig.fake.signCalls;
        Receipt? sold;
        rig.sell('s2', cart).then((r) => sold = r);
        async.elapse(RksvJournal.signLimitDuringOutage - _ms);
        expect(sold, isNull);
        async.elapse(_ms);
        expect(sold, isNotNull);
        expect(sold!.rksv!.damaged, isTrue);
        expect(rig.fake.signCalls - before, 1);
        // Der Sammelbeleg ist zurückgerollt, der Ausfall dauert an.
        expect(_await(async, rig.entryKinds()), ['start', 'sale', 'sale']);
        final state = _await(async, rig.stateRow());
        expect((state.outageSince, state.outageReason), (since, _silent));

        // Ebenso ein Storno.
        Receipt? voided;
        rig.receipts.voidReceipt('s2', staff: rig.chef).then((r) => voided = r);
        async.elapse(RksvJournal.signLimitDuringOutage);
        expect(voided, isNotNull);
        expect(voided!.rksv!.damaged, isTrue);
        expect(rig.fake.signCalls - before, 2);
        _await(async, rig.verifyChain(1));
      });
    });

    test('im Ausfall: ein Sammelbeleg, der nicht antwortet, wird nach 1 '
        'Sekunde zur SignatureFailure, nichts geschrieben', () {
      _inFakeTime((async, rig) {
        rig.fake.mode = FakeMode.error;
        _await(async, rig.sell('s1', cart));
        rig.fake.mode = FakeMode.silent;
        Object? thrown;
        rig.receipts
            .createSpecial(
              ReceiptKind.collective,
              staff: rig.anna,
              mustSign: true,
            )
            .then<void>((_) {}, onError: (Object e) => thrown = e);
        async.elapse(RksvJournal.signLimitDuringOutage - _ms);
        expect(thrown, isNull);
        async.elapse(_ms);
        expect(
          thrown,
          isA<SignatureFailure>().having((f) => f.reason, 'reason', _silent),
        );
        expect(_await(async, rig.count('receipts')), 2);
        expect(_await(async, rig.count('rksv_entries')), 2);
        final state = _await(async, rig.stateRow());
        expect((state.mode, state.outageReason), ('probe', _error));
        expect(state.outageSince, isNotNull);
      });
    });

    test('Monatsbeleg, der nicht antwortet: der Verkauf wartet höchstens 5 '
        'Sekunden und fragt die Signatur nur einmal; danach Sammelbeleg, '
        'signierter Monatsbeleg, Verkauf', () {
      _inFakeTime((async, rig) {
        rig.clock.value = DateTime(2026, 12, 1, 9);
        rig.fake.mode = FakeMode.silent;
        final before = rig.fake.signCalls;
        Receipt? sold;
        rig.sell('s1', cart).then((r) => sold = r);
        async.elapse(RksvJournal.signLimit - _ms);
        expect(sold, isNull);
        async.elapse(_ms);
        expect(sold, isNotNull);
        expect(sold!.rksv!.damaged, isTrue);
        expect(rig.fake.signCalls - before, 1);
        expect(_await(async, rig.entryKinds()), ['start', 'month', 'sale']);
        expect(_await(async, rig.entries(1))[1].damaged, isTrue);

        // Die Signatur ist vor dem nächsten Verkauf wieder da.
        rig.fake.release();
        rig.fake.mode = FakeMode.ok;
        async.flushMicrotasks();
        rig.clock.value = DateTime(2026, 12, 2, 9);
        _await(async, rig.sell('s2', cart));
        expect(_await(async, rig.entryKinds()), [
          'start',
          'month',
          'sale',
          'collective',
          'month',
          'sale',
        ]);
        final entries = _await(async, rig.entries(1));
        expect(entries.sublist(3).map((e) => e.damaged), [false, false, false]);
        final kinds = _await(async, rig.entryKinds());
        expect([
          for (var i = 0; i < entries.length; i++)
            if (kinds[i] == 'month' && !entries[i].damaged) i,
        ], hasLength(1));
        _await(async, rig.verifyChain(1));
      });
    });

    test('Jahresbeleg, der nicht antwortet, vor einem Storno und vor einem '
        'Nullbeleg: jeweils nur ein Signaturversuch', () {
      _inFakeTime((async, rig) {
        _await(async, rig.sell('s1', cart));
        rig.clock.value = DateTime(2027, 1, 2, 9);
        rig.fake.mode = FakeMode.silent;
        var before = rig.fake.signCalls;
        Receipt? voided;
        rig.receipts.voidReceipt('s1', staff: rig.chef).then((r) => voided = r);
        async.elapse(RksvJournal.signLimit);
        expect(voided, isNotNull);
        expect(rig.fake.signCalls - before, 1);
        expect(_await(async, rig.entryKinds()), [
          'start',
          'sale',
          'year',
          'voided',
        ]);
        _await(async, rig.verifyChain(1));
      });
      _inFakeTime((async, rig) {
        rig.clock.value = DateTime(2026, 12, 1, 9);
        rig.fake.mode = FakeMode.silent;
        final before = rig.fake.signCalls;
        Receipt? zero;
        rig.service.zeroReceipt(staff: rig.chef).then((r) => zero = r);
        async.elapse(RksvJournal.signLimit);
        expect(zero, isNotNull);
        expect(zero!.rksv!.damaged, isTrue);
        expect(rig.fake.signCalls - before, 1);
        expect(_await(async, rig.entryKinds()), ['start', 'month', 'zero']);
      });
    });

    test('retrySignature, wenn die Signatur nicht antwortet: false nach 1 '
        'Sekunde, nichts geschrieben', () {
      _inFakeTime((async, rig) {
        rig.fake.mode = FakeMode.error;
        _await(async, rig.sell('s1', cart));
        rig.fake.mode = FakeMode.silent;
        bool? ok;
        rig.service.retrySignature(staff: rig.chef).then((v) => ok = v);
        async.elapse(RksvJournal.signLimitDuringOutage);
        expect(ok, isFalse);
        expect(_await(async, rig.count('receipts')), 2);
        expect(_await(async, rig.stateRow()).outageSince, isNotNull);
      });
    });
  });

  group('mit Probe', () {
    late RksvRig rig;

    setUp(() async {
      rig = await RksvRig.open();
      await rig.service.enableProbe(staff: rig.chef);
    });
    tearDown(() => rig.close());

    test('Grund des Ausfalls ist der Satz der Einheit: '
        'SignatureFailure("Kein Internet.") steht in outage_reason', () async {
      rig.fake
        ..mode = FakeMode.error
        ..failure = 'Kein Internet.';
      final r = await rig.sell('s1', cart);
      expect(r.rksv!.damaged, isTrue);
      final state = await rig.stateRow();
      expect(
        (state.outageSince, state.outageReason),
        (rig.clock.now(), 'Kein Internet.'),
      );
      // Ein anderer Satz beim nächsten Bon ändert den Grund nicht: Er gehört
      // zum Beginn des Ausfalls.
      rig.fake.failure = 'A-Trust meldet einen Fehler.';
      await rig.sell('s2', cart);
      expect((await rig.stateRow()).outageReason, 'Kein Internet.');
      await rig.verifyChain(1);
    });

    test('Ausfall: FakeMode.error → Bon gespeichert, Eintrag damaged, Ausfall '
        'seit jetzt, Grund gesetzt; Kette besteht', () async {
      rig.fake.mode = FakeMode.error;
      final r = await rig.sell('s1', cart);
      expect(r.number, 2);
      expect(r.rksv!.damaged, isTrue);
      expect(await rig.count('receipts'), 2);
      final e = (await rig.entryOf('s1'))!;
      expect((e.position, e.damaged), (2, true));
      final state = await rig.stateRow();
      expect(state.outageSince, rig.clock.now());
      expect(state.outageReason, _error);
      expect((state.mode, state.counterCents), ('probe', 1820));
      await rig.verifyChain(1);
      expect(await rig.journal.chainIsSound(1), isTrue);
      expect(
        await rig.journal.dueBefore(rig.clock.now()),
        ReceiptKind.collective,
      );
    });

    test('im Ausfall mit Fehler der Signatur: der Verkauf versucht nur den '
        'Sammelbeleg (signCalls steigt um 1)', () async {
      rig.fake.mode = FakeMode.error;
      await rig.sell('s1', cart);
      final before = rig.fake.signCalls;
      final r = await rig.sell('s2', cart);
      expect(rig.fake.signCalls - before, 1);
      expect(r.rksv!.damaged, isTrue);
      expect(await rig.entryKinds(), ['start', 'sale', 'sale']);
      await rig.verifyChain(1);
    });

    test('Signatur wieder da: vor dem nächsten Verkauf steht der Sammelbeleg, '
        'signiert, danach der Verkauf signiert; Ausfall beendet', () async {
      rig.fake.mode = FakeMode.error;
      await rig.sell('s1', cart);
      rig.fake.mode = FakeMode.ok;
      rig.clock.value = DateTime(2026, 11, 18, 13, 20);
      final before = rig.fake.signCalls;
      final s2 = await rig.sell('s2', cart);

      expect(await rig.entryKinds(), ['start', 'sale', 'collective', 'sale']);
      final collective = (await rig.entries(1))[2];
      expect(collective.damaged, isFalse);
      final c = await rig.receipts.byId(collective.receiptId);
      expect(
        (c.number, c.totalCents, c.payment, c.businessDayId),
        (3, 0, null, null),
      );
      expect(c.createdAt, DateTime(2026, 11, 18, 13, 20));
      expect(c.staffName, 'Anna');
      expect((s2.number, s2.rksv!.damaged), (4, false));
      expect(rig.fake.signCalls - before, 2);
      final state = await rig.stateRow();
      expect((state.outageSince, state.outageReason), (null, null));
      expect(state.counterCents, 3640);
      await rig.verifyChain(1);

      // Danach kein weiterer Sammelbeleg.
      await rig.sell('s3', cart);
      expect(await rig.entryKinds(), [
        'start',
        'sale',
        'collective',
        'sale',
        'sale',
      ]);
    });

    test(
      'Ausfall vom 30. November in den Dezember, Signatur wieder da: '
      'Sammelbeleg, dann Monatsbeleg, dann der Verkauf; Kette besteht',
      () async {
        rig.clock.value = DateTime(2026, 11, 30, 22);
        rig.fake.mode = FakeMode.error;
        await rig.sell('s1', cart);
        rig.clock.value = DateTime(2026, 12, 1, 9);
        rig.fake.mode = FakeMode.ok;
        final s2 = await rig.sell('s2', cart);

        expect(await rig.entryKinds(), [
          'start',
          'sale',
          'collective',
          'month',
          'sale',
        ]);
        expect(s2.number, 5);
        expect(s2.rksv!.damaged, isFalse);
        for (final e in (await rig.entries(1)).sublist(2)) {
          expect(e.damaged, isFalse);
        }
        expect((await rig.stateRow()).outageSince, isNull);
        await rig.verifyChain(1);
        expect(await rig.journal.chainIsSound(1), isTrue);
      },
    );

    test('R10: Ausfall ab 30. November, zwei Bons im Dezember mit '
        'Ausfall-Vermerk, Signatur am 2. Dezember wieder da: Sammelbeleg, '
        'Monatsbeleg, Verkauf; genau ein Monatsbeleg', () async {
      rig.clock.value = DateTime(2026, 11, 30, 22);
      rig.fake.mode = FakeMode.error;
      await rig.sell('s1', cart);
      rig.clock.value = DateTime(2026, 12, 1, 9);
      await rig.sell('s2', cart);
      rig.clock.value = DateTime(2026, 12, 1, 10);
      await rig.sell('s3', cart);
      rig.fake.mode = FakeMode.ok;
      rig.clock.value = DateTime(2026, 12, 2, 9);
      final s4 = await rig.sell('s4', cart);
      expect(await rig.entryKinds(), [
        'start',
        'sale',
        'sale',
        'sale',
        'collective',
        'month',
        'sale',
      ]);
      expect(s4.rksv!.damaged, isFalse);
      rig.clock.value = DateTime(2026, 12, 20);
      await rig.sell('s5', cart);
      expect((await rig.entryKinds()).where((k) => k == 'month'), hasLength(1));
      await rig.verifyChain(1);
      expect(await rig.journal.chainIsSound(1), isTrue);
    });

    test('R10: ebenso über den Jahreswechsel: Sammelbeleg, Jahresbeleg mit '
        'checkYear für das alte Jahr', () async {
      rig.clock.value = DateTime(2026, 12, 31, 19);
      await rig.sell('s0', cart); // signiert, mit Monatsbeleg davor
      rig.clock.value = DateTime(2026, 12, 31, 20);
      rig.fake.mode = FakeMode.error;
      await rig.sell('s1', cart);
      rig.clock.value = DateTime(2027, 1, 1, 12);
      await rig.sell('s2', cart);
      rig.fake.mode = FakeMode.ok;
      rig.clock.value = DateTime(2027, 1, 2, 9);
      await rig.sell('s3', cart);
      expect(await rig.entryKinds(), [
        'start',
        'month',
        'sale',
        'sale',
        'sale',
        'collective',
        'year',
        'sale',
      ]);
      expect(
        await rig.tasks(),
        contains(('check-year-2026', RksvTaskKind.checkYear, '2026')),
      );
      expect(
        (await rig.tasks()).where((t) => t.$2 == RksvTaskKind.checkYear),
        hasLength(1),
      );
      await rig.verifyChain(1);
    });

    test('R10: kurzer Ausfall in einem Monat: nur der Sammelbeleg', () async {
      rig.fake.mode = FakeMode.error;
      await rig.sell('s1', cart);
      rig.clock.value = DateTime(2026, 11, 19, 9);
      await rig.sell('s2', cart);
      rig.fake.mode = FakeMode.ok;
      rig.clock.value = DateTime(2026, 11, 20, 9);
      await rig.sell('s3', cart);
      expect(await rig.entryKinds(), [
        'start',
        'sale',
        'sale',
        'collective',
        'sale',
      ]);
      await rig.verifyChain(1);
    });

    test(
      'R10: ein Monatsbeleg, dessen Signatur scheitert, beginnt einen '
      'Ausfall; nach dem Sammelbeleg folgt ein signierter Monatsbeleg',
      () async {
        await rig.sell('s1', cart);
        rig.clock.value = DateTime(2026, 12, 1, 9);
        rig.fake.mode = FakeMode.error;
        final before = rig.fake.signCalls;
        final s2 = await rig.sell('s2', cart);
        expect(rig.fake.signCalls - before, 1);
        expect(s2.rksv!.damaged, isTrue);
        expect(await rig.entryKinds(), ['start', 'sale', 'month', 'sale']);
        final damagedMonth = (await rig.entries(1))[2];
        expect(damagedMonth.damaged, isTrue);
        expect((await rig.stateRow()).outageSince, DateTime(2026, 12, 1, 9));

        rig.fake.mode = FakeMode.ok;
        rig.clock.value = DateTime(2026, 12, 1, 11);
        await rig.sell('s3', cart);
        expect(await rig.entryKinds(), [
          'start',
          'sale',
          'month',
          'sale',
          'collective',
          'month',
          'sale',
        ]);
        expect((await rig.entries(1))[5].damaged, isFalse);
        await rig.verifyChain(1);
      },
    );

    test('ein Sammelbeleg, der scheitert, beendet die Runde: kein Monatsbeleg '
        'im Ausfall', () async {
      rig.clock.value = DateTime(2026, 11, 30, 22);
      rig.fake.mode = FakeMode.error;
      await rig.sell('s1', cart);
      rig.clock.value = DateTime(2026, 12, 1, 9);
      await rig.sell('s2', cart);
      expect(await rig.entryKinds(), ['start', 'sale', 'sale']);
      await rig.verifyChain(1);
    });

    test('retrySignature: true und Sammelbeleg, wenn sie geht; false und '
        'nichts geschrieben, wenn nicht; false ohne Ausfall', () async {
      var calls = rig.fake.signCalls;
      expect(await rig.service.retrySignature(staff: rig.chef), isFalse);
      expect(await rig.count('receipts'), 1);
      expect(rig.fake.signCalls, calls);

      rig.fake.mode = FakeMode.error;
      await rig.sell('s1', cart);
      calls = rig.fake.signCalls;
      expect(await rig.service.retrySignature(staff: rig.chef), isFalse);
      expect(rig.fake.signCalls - calls, 1);
      expect(await rig.count('receipts'), 2);
      expect(await rig.count('rksv_entries'), 2);
      expect((await rig.stateRow()).outageReason, _error);

      rig.fake.mode = FakeMode.ok;
      rig.clock.value = DateTime(2026, 11, 18, 14);
      expect(await rig.service.retrySignature(staff: rig.chef), isTrue);
      expect(await rig.entryKinds(), ['start', 'sale', 'collective']);
      final c = (await rig.entries(1)).last;
      expect(c.damaged, isFalse);
      expect((await rig.receipts.byId(c.receiptId)).staffName, 'Chef');
      final state = await rig.stateRow();
      expect((state.outageSince, state.outageReason), (null, null));

      expect(await rig.service.retrySignature(staff: rig.chef), isFalse);
      expect(await rig.count('receipts'), 3);
      await rig.verifyChain(1);
    });

    test(
      'Storno während eines Ausfalls: U1RP, damaged, Zähler gesenkt',
      () async {
        await rig.sell('s1', cart);
        rig.fake.mode = FakeMode.error;
        final v = await rig.receipts.voidReceipt('s1', staff: rig.chef);
        expect(v.kind, ReceiptKind.voided);
        expect(v.rksv!.damaged, isTrue);
        final f = await rig.codeFieldsOf(v.id);
        expect(f[10], 'U1RP');
        expect(f.sublist(5, 10), ['-5,80', '-11,90', '0,00', '-0,50', '0,00']);
        final state = await rig.stateRow();
        expect(state.counterCents, 0);
        expect(
          (state.outageSince, state.outageReason),
          (rig.clock.now(), _error),
        );
        await rig.verifyChain(1);

        // Ein Storno im laufenden Ausfall ebenso, nach einem Verkauf darin.
        await rig.sell('s2', cart);
        final v2 = await rig.receipts.voidReceipt('s2', staff: rig.chef);
        expect(v2.rksv!.damaged, isTrue);
        expect((await rig.codeFieldsOf(v2.id))[10], 'U1RP');
        expect((await rig.stateRow()).counterCents, 0);
        await rig.verifyChain(1);
      },
    );

    test('Ausfall länger als 48 Stunden: Aufgabe reportOutage mit dem Beginn; '
        'nach dem Sammelbeleg reportOutageEnd; ein kurzer Ausfall erzeugt '
        'keine', () async {
      final start = rig.clock.now(); // 18.11.2026 13:05:09
      rig.fake.mode = FakeMode.error;
      await rig.sell('s1', cart); // Position 2, Beginn des Ausfalls
      rig.clock.value = start.add(const Duration(hours: 47));
      await rig.sell('s2', cart);
      expect(await rig.tasks(), [
        ('check-start-1', RksvTaskKind.checkStart, ''),
      ]);

      rig.clock.value = start.add(const Duration(hours: 48, minutes: 1));
      await rig.sell('s3', cart);
      expect(await rig.tasks(), [
        ('check-start-1', RksvTaskKind.checkStart, ''),
        ('report-outage-1-2', RksvTaskKind.reportOutage, '18.11.2026 13:05'),
      ]);
      expect((await rig.rksv.current()).tasks.last.createdAt, rig.clock.now());
      expect(
        rksvTaskText((await rig.rksv.current()).tasks.last),
        'Ausfall der Signatur bei FinanzOnline melden. '
        'Beginn: 18.11.2026 13:05.',
      );

      // Kein zweites Mal, auch nicht nach "Erledigt".
      rig.clock.value = start.add(const Duration(hours: 50));
      await rig.sell('s4', cart);
      expect((await rig.tasks()).length, 2);
      await rig.rksv.completeTask('report-outage-1-2');
      await rig.sell('s5', cart);
      expect(await rig.tasks(), [
        ('check-start-1', RksvTaskKind.checkStart, ''),
      ]);

      rig.fake.mode = FakeMode.ok;
      rig.clock.value = DateTime(2026, 11, 21, 10, 4, 30);
      await rig.sell('s6', cart);
      expect((await rig.entries(1))[6].position, 7);
      expect(await rig.entryKinds(), [
        'start',
        ...List.filled(5, 'sale'),
        'collective',
        'sale',
      ]);
      expect(await rig.tasks(), [
        ('check-start-1', RksvTaskKind.checkStart, ''),
        (
          'report-outage-end-1-7',
          RksvTaskKind.reportOutageEnd,
          '21.11.2026 10:04',
        ),
      ]);

      // Ein kurzer Ausfall: keine Meldung.
      rig.fake.mode = FakeMode.error;
      rig.clock.value = DateTime(2026, 11, 21, 11);
      await rig.sell('s7', cart);
      rig.fake.mode = FakeMode.ok;
      rig.clock.value = DateTime(2026, 11, 22, 11);
      await rig.sell('s8', cart);
      expect(await rig.entryKinds(), [
        'start',
        ...List.filled(5, 'sale'),
        'collective',
        'sale',
        'sale',
        'collective',
        'sale',
      ]);
      expect((await rig.tasks()).length, 2);
      await rig.verifyChain(1);
    });

    test('Ausfall länger als 48 Stunden ohne Bon dazwischen: der Sammelbeleg '
        'bringt beide Meldungen', () async {
      rig.fake.mode = FakeMode.error;
      await rig.sell('s1', cart);
      rig.fake.mode = FakeMode.ok;
      rig.clock.value = DateTime(2026, 11, 21, 8, 15);
      await rig.sell('s2', cart);
      expect(await rig.tasks(), [
        ('check-start-1', RksvTaskKind.checkStart, ''),
        ('report-outage-1-2', RksvTaskKind.reportOutage, '18.11.2026 13:05'),
        (
          'report-outage-end-1-3',
          RksvTaskKind.reportOutageEnd,
          '21.11.2026 08:15',
        ),
      ]);
    });
  });
}
