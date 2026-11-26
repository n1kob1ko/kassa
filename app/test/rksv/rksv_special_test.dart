import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/domain/receipt.dart';
import 'package:kassa/rksv/core/rksv_code.dart';
import 'package:kassa/rksv/rksv_service.dart';
import 'package:kassa/rksv/rksv_state.dart';

import '../support/fake_signature_unit.dart';
import '../support/rksv_rig.dart';
import '../support/sales.dart' show cart;

const _checkStart = ('check-start-1', RksvTaskKind.checkStart, '');

void main() {
  late RksvRig rig;

  setUp(() async => rig = await RksvRig.open());
  tearDown(() => rig.close());

  /// Der Zählerstand im Code des Bons [receiptId].
  Future<int> counterOf(String receiptId) async {
    final f = await rig.codeFieldsOf(receiptId);
    return decryptCounter(
      aesKey: (await rig.secrets.aesKey(1))!,
      cashBoxId: f[2],
      receiptId: f[3],
      field: f[10],
    );
  }

  test('zeroReceipt bei mode off: RksvProblem, nichts geschrieben', () async {
    await expectLater(
      rig.service.zeroReceipt(staff: rig.chef),
      throwsA(
        isA<RksvProblem>().having(
          (p) => p.message,
          'message',
          'Die Signatur ist nicht eingeschaltet.',
        ),
      ),
    );
    expect(await rig.count('receipts'), 0);
  });

  group('mit Probe', () {
    setUp(() => rig.service.enableProbe(staff: rig.chef));

    test('Startbeleg: Aufgabe checkStart je Kette', () async {
      expect(await rig.tasks(), [_checkStart]);
      final task = (await rig.rksv.current()).tasks.single;
      expect(task.createdAt, rig.clock.now());
      expect(
        rksvTaskText(task),
        'Startbeleg mit der App "BMF Belegcheck" prüfen.',
      );
      // Die Aufgabe der alten Kette endet mit ihr.
      await rig.service.disableProbe(staff: rig.chef);
      expect(await rig.tasks(), isEmpty);
      await rig.service.enableProbe(staff: rig.chef);
      expect(await rig.tasks(), [
        ('check-start-2', RksvTaskKind.checkStart, ''),
      ]);
    });

    test('Monatswechsel: vor dem ersten Verkauf im Dezember steht ein '
        'Monatsbeleg mit Betrag 0; ein zweiter Verkauf im Dezember erzeugt '
        'keinen weiteren', () async {
      await rig.sell('s1', cart);
      rig.clock.value = DateTime(2026, 12, 1, 8);
      final s2 = await rig.sell('s2', cart);

      expect(await rig.entryKinds(), ['start', 'sale', 'month', 'sale']);
      final monthEntry = (await rig.entries(1))[2];
      expect(monthEntry.damaged, isFalse);
      final month = await rig.receipts.byId(monthEntry.receiptId);
      expect(month.kind, ReceiptKind.month);
      expect(month.number, 3);
      expect(
        (month.totalCents, month.payments.firstOrNull, month.businessDayId),
        (0, null, null),
      );
      expect(month.lines, isEmpty);
      expect(month.createdAt, DateTime(2026, 12, 1, 8));
      expect(month.staffName, 'Anna');
      expect((await rig.codeFieldsOf(month.id)).sublist(5, 10), [
        '0,00',
        '0,00',
        '0,00',
        '0,00',
        '0,00',
      ]);
      expect(await counterOf(month.id), 1820);
      expect(s2.number, 4);

      rig.clock.value = DateTime(2026, 12, 31, 23, 59);
      await rig.sell('s3', cart);
      expect(await rig.entryKinds(), [
        'start',
        'sale',
        'month',
        'sale',
        'sale',
      ]);
      expect(await rig.tasks(), [_checkStart]);
      await rig.verifyChain(1);
    });

    test('Monatswechsel: auch vor einem Storno', () async {
      await rig.sell('s1', cart);
      rig.clock.value = DateTime(2026, 12, 2, 10);
      final v = await rig.receipts.voidReceipt('s1', staff: rig.chef);
      expect(await rig.entryKinds(), ['start', 'sale', 'month', 'voided']);
      expect(v.number, 4);
      final month = (await rig.entries(1))[2];
      expect((await rig.receipts.byId(month.receiptId)).staffName, 'Chef');
      await rig.verifyChain(1);
    });

    test('Jahreswechsel: Jahresbeleg statt Monatsbeleg, Aufgabe checkYear mit '
        'dem alten Jahr', () async {
      await rig.sell('s1', cart);
      rig.clock.value = DateTime(2027, 1, 2, 10);
      await rig.sell('s2', cart);
      expect(await rig.entryKinds(), ['start', 'sale', 'year', 'sale']);
      final year = await rig.receipts.byId((await rig.entries(1))[2].receiptId);
      expect(
        (year.kind, year.totalCents, year.businessDayId),
        (ReceiptKind.year, 0, null),
      );
      expect(await counterOf(year.id), 1820);
      final tasks = await rig.tasks();
      expect(
        tasks,
        contains(('check-year-2026', RksvTaskKind.checkYear, '2026')),
      );
      final checkYear = (await rig.rksv.current()).tasks.firstWhere(
        (t) => t.kind == RksvTaskKind.checkYear,
      );
      expect(
        rksvTaskText(checkYear),
        'Jahresbeleg 2026 mit der App "BMF Belegcheck" prüfen, '
        'bis 15. Februar.',
      );
      expect(checkYear.createdAt, DateTime(2027, 1, 2, 10));

      // Im Jänner nichts mehr, im Februar ein Monatsbeleg.
      rig.clock.value = DateTime(2027, 1, 20);
      await rig.sell('s3', cart);
      rig.clock.value = DateTime(2027, 2, 1);
      await rig.sell('s4', cart);
      expect(await rig.entryKinds(), [
        'start',
        'sale',
        'year',
        'sale',
        'sale',
        'month',
        'sale',
      ]);
      expect(
        (await rig.tasks()).where((t) => t.$2 == RksvTaskKind.checkYear),
        hasLength(1),
      );
      await rig.verifyChain(1);
    });

    test('drei Monate Pause: genau ein Monatsbeleg', () async {
      rig.clock.value = DateTime(2027, 1, 5, 12);
      await rig.sell('s1', cart);
      rig.clock.value = DateTime(2027, 4, 20, 12);
      await rig.sell('s2', cart);
      expect(await rig.entryKinds(), [
        'start',
        'year',
        'sale',
        'month',
        'sale',
      ]);
      await rig.verifyChain(1);
    });

    test('Review Focus 4: Uhr zurück in den Vormonat: kein Sonderbeleg, '
        'Verkauf eingetragen, verifyChain besteht', () async {
      await rig.sell('s1', cart);
      rig.clock.value = DateTime(2026, 10, 20, 9);
      final s2 = await rig.sell('s2', cart);
      expect(s2.rksv!.damaged, isFalse);
      expect(await rig.journal.dueBefore(rig.clock.now()), isNull);
      await rig.sell('s3', cart);
      expect(await rig.entryKinds(), ['start', 'sale', 'sale', 'sale']);
      expect(await rig.count('receipts'), 4);
      expect(await rig.tasks(), [_checkStart]);
      await rig.verifyChain(1);
      expect(await rig.journal.chainIsSound(1), isTrue);
    });

    test('Review Focus 4: Uhr zurück ins Vorjahr: kein Sonderbeleg', () async {
      rig.clock.value = DateTime(2025, 12, 1, 9);
      await rig.sell('s1', cart);
      expect(await rig.entryKinds(), ['start', 'sale']);
      await rig.verifyChain(1);
    });

    test('Vierteljahr: erster Eintrag im Jänner nach Einträgen im Dezember → '
        'backupProtocol; kein zweites Mal im selben Vierteljahr', () async {
      rig.clock.value = DateTime(2026, 12, 10);
      await rig.sell('s1', cart); // Monatsbeleg, noch im 4. Vierteljahr
      expect(await rig.tasks(), [_checkStart]);

      rig.clock.value = DateTime(2027, 1, 3);
      await rig.sell('s2', cart);
      expect(await rig.tasks(), [
        _checkStart,
        ('check-year-2026', RksvTaskKind.checkYear, '2026'),
        ('backup-2027-Q1', RksvTaskKind.backupProtocol, ''),
      ]);
      expect(
        rksvTaskText((await rig.rksv.current()).tasks.last),
        'Protokoll sichern: "Protokoll ausgeben" und die Datei aufheben.',
      );

      rig.clock.value = DateTime(2027, 2, 2);
      await rig.sell('s3', cart);
      await rig.rksv.completeTask('backup-2027-Q1');
      rig.clock.value = DateTime(2027, 3, 31, 23, 59);
      await rig.sell('s4', cart);
      expect(
        (await rig.tasks()).where((t) => t.$2 == RksvTaskKind.backupProtocol),
        isEmpty,
      );

      rig.clock.value = DateTime(2027, 4, 1);
      await rig.sell('s5', cart);
      expect(
        (await rig.tasks()).where((t) => t.$2 == RksvTaskKind.backupProtocol),
        [('backup-2027-Q2', RksvTaskKind.backupProtocol, '')],
      );
      await rig.verifyChain(1);
    });

    test('zeroReceipt: Eintrag mit Betrag 0, Zähler unverändert; bei mode off '
        'RksvProblem', () async {
      await rig.sell('s1', cart);
      final zero = await rig.service.zeroReceipt(staff: rig.chef);
      expect(zero.kind, ReceiptKind.zero);
      expect(
        (zero.number, zero.totalCents, zero.payments.firstOrNull),
        (3, 0, null),
      );
      expect(zero.staffName, 'Chef');
      expect(zero.rksv!.damaged, isFalse);
      expect((await rig.codeFieldsOf(zero.id)).sublist(5, 10), [
        '0,00',
        '0,00',
        '0,00',
        '0,00',
        '0,00',
      ]);
      expect(await counterOf(zero.id), 1820);
      expect((await rig.stateRow()).counterCents, 1820);
      await rig.verifyChain(1);

      await rig.service.disableProbe(staff: rig.chef);
      await expectLater(
        rig.service.zeroReceipt(staff: rig.chef),
        throwsA(
          isA<RksvProblem>().having(
            (p) => p.message,
            'message',
            'Die Signatur ist nicht eingeschaltet.',
          ),
        ),
      );
      expect(await rig.count('receipts'), 4);
    });

    test('zeroReceipt im neuen Monat: zuerst der Monatsbeleg', () async {
      rig.clock.value = DateTime(2026, 12, 1, 7);
      await rig.service.zeroReceipt(staff: rig.chef);
      expect(await rig.entryKinds(), ['start', 'month', 'zero']);
      await rig.verifyChain(1);
    });

    test('zeroReceipt im Ausfall: ein Versuch für den Sammelbeleg, dann der '
        'Nullbeleg mit Ausfall-Vermerk', () async {
      rig.fake.mode = FakeMode.error;
      await rig.sell('s1', cart);
      final before = rig.fake.signCalls;
      final zero = await rig.service.zeroReceipt(staff: rig.chef);
      expect(zero.rksv!.damaged, isTrue);
      expect(rig.fake.signCalls - before, 1);
      expect(await rig.entryKinds(), ['start', 'sale', 'zero']);
      await rig.verifyChain(1);
    });
  });
}
