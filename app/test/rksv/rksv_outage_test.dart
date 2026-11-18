import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/domain/receipt.dart';
import 'package:kassa/rksv/core/rksv_code.dart';
import 'package:kassa/rksv/rksv_journal.dart';
import 'package:kassa/rksv/rksv_state.dart';
import 'package:kassa/rksv/signature_unit.dart';

import '../support/fake_signature_unit.dart';
import '../support/rksv_rig.dart';
import '../support/sales.dart' show cart;

const _silent = 'Die Signatur hat nicht geantwortet.';
const _error = 'Die Signatur hat einen Fehler gemeldet.';
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
