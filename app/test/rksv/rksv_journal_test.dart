import 'dart:convert';

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:drift/native.dart' show SqliteException;
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/receipt_repository.dart';
import 'package:kassa/data/settings_repository.dart';
import 'package:kassa/domain/cart.dart';
import 'package:kassa/domain/receipt.dart';
import 'package:kassa/rksv/core/rksv_code.dart';
import 'package:kassa/rksv/rksv_journal.dart';

import '../support/demo_fixtures.dart';
import '../support/fake_signature_unit.dart';
import '../support/rksv_rig.dart';
import '../support/sales.dart' show cart, cartCard;

const _notice =
    'Die Probe-Signatur wurde beendet, weil sie nicht mehr arbeiten konnte. '
    'Der Verkauf läuft normal weiter.';

void main() {
  late RksvRig rig;

  setUp(() async => rig = await RksvRig.open());
  tearDown(() => rig.close());

  test('Fristen: 5 Sekunden, während eines Ausfalls 1 Sekunde', () {
    expect(RksvJournal.signLimit, const Duration(seconds: 5));
    expect(RksvJournal.signLimitDuringOutage, const Duration(seconds: 1));
  });

  test('mode off: Verkauf wie bisher, kein Eintrag', () async {
    final r = await rig.sell('s1', cart);
    expect(r.number, 1);
    expect(r.totalCents, 1820);
    expect(r.payment!.amountCents, 1820);
    expect(r.businessDayId, isNotNull);
    expect(r.rksv, isNull);
    final v = await rig.receipts.voidReceipt('s1', staff: rig.chef);
    expect(v.number, 2);
    expect(await rig.count('rksv_entries'), 0);
    expect(rig.fake.signCalls, 0);
    expect((await rig.stateRow()).counterCents, 0);
  });

  group('mit Probe', () {
    setUp(() => rig.service.enableProbe(staff: rig.chef));

    test('drei Verkäufe (20 %, 10 % mit Pfand, Karte) und ein Storno: '
        'verifyChain besteht; Pfand steht im Betrag Null; das Storno trägt '
        'U1RP und senkt den Zähler', () async {
      final s1 = await rig.sell(
        's1',
        Cart.empty().add(cola.copyWith(depositCents: 0)),
      );
      final s2 = await rig.sell('s2', cart);
      final s3 = await rig.sellCard('s3', cartCard);
      final v = await rig.receipts.voidReceipt('s2', staff: rig.chef);

      // Vor keinem Bon war ein Sonderbeleg fällig: die Nummern folgen dicht
      // auf den Startbeleg.
      final rows = await (rig.db.select(
        rig.db.receiptRows,
      )..orderBy([(t) => OrderingTerm.asc(t.number)])).get();
      expect(
        [for (final r in rows) (r.number, r.kind)],
        [(1, 'start'), (2, 'sale'), (3, 'sale'), (4, 'sale'), (5, 'voided')],
      );
      expect(
        [for (final e in await rig.entries(1)) (e.position, e.receiptId)],
        [(1, rows.first.id), (2, 's1'), (3, 's2'), (4, 's3'), (5, v.id)],
      );
      await rig.verifyChain(1);

      expect((await rig.codeFieldsOf('s1')).sublist(3, 10), [
        '2',
        '2026-11-18T13:05:09',
        '2,90',
        '0,00',
        '0,00',
        '0,00',
        '0,00',
      ]);
      // 2 x Cola (20 %), Huhn Bowl mit XXL und Nudeln (10 %), 0,50 Pfand.
      expect((await rig.codeFieldsOf('s2')).sublist(5, 10), [
        '5,80',
        '11,90',
        '0,00',
        '0,50',
        '0,00',
      ]);
      expect((await rig.codeFieldsOf('s3')).sublist(5, 10), [
        '2,90',
        '6,50',
        '0,00',
        '0,25',
        '0,00',
      ]);
      final storno = await rig.codeFieldsOf(v.id);
      expect(storno.sublist(5, 11), [
        '-5,80',
        '-11,90',
        '0,00',
        '-0,50',
        '0,00',
        'U1RP',
      ]);
      expect((s1.totalCents, s2.totalCents, s3.totalCents), (290, 1820, 965));
      expect((await rig.stateRow()).counterCents, 290 + 965);
      expect(rig.fake.signCalls, 5);
      expect(await rig.journal.chainIsSound(1), isTrue);

      // Am Bon steht, was das Protokoll weiß.
      final read = (await rig.receipts.byId('s2')).rksv!;
      expect(read.cashBoxId, (await rig.chainRow(1)).cashBoxId);
      expect(read.damaged, isFalse);
      expect(read.probe, isTrue);
      expect(read.qrText, startsWith('_R1-AT100_${read.cashBoxId}_3_'));
    });

    test('Bon über 1.234,56 Euro: Betrag im Code ohne Punkt, verifyChain '
        'besteht', () async {
      final big = const Cart.empty().add(
        teigtaschen.copyWith(priceCents: 123456),
      );
      await rig.sell('gross', big);
      expect((await rig.codeFieldsOf('gross')).sublist(5, 10), [
        '0,00',
        '1234,56',
        '0,00',
        '0,00',
        '0,00',
      ]);
      await rig.verifyChain(1);
      expect((await rig.stateRow()).counterCents, 123456);
    });

    test(
      'Signatur meldet einen Fehler: Bon gespeichert, Eintrag mit '
      'Ausfall-Vermerk, Ausfall seit jetzt mit Grund; verifyChain besteht',
      () async {
        rig.fake.mode = FakeMode.error;
        final r = await rig.sell('s1', cart);
        expect(r.number, 2);
        expect(r.rksv!.damaged, isTrue);
        final e = (await rig.entryOf('s1'))!;
        expect(e.damaged, isTrue);
        expect(isDamagedJws(e.jws), isTrue);
        expect(e.certSerial, (await rig.fake.info()).serialHex);
        var state = await rig.stateRow();
        expect(state.outageSince, rig.clock.now());
        // Der Grund ist der Satz der Einheit (hier der Attrappe).
        expect(state.outageReason, 'Die Attrappe signiert nicht.');
        expect(state.counterCents, 1820);

        rig.clock.value = rig.clock.value.add(const Duration(minutes: 1));
        await rig.sell('s2', cart);
        state = await rig.stateRow();
        expect(state.outageSince, DateTime(2026, 11, 18, 13, 5, 9));
        expect((state.mode, state.notice), ('probe', null));
        await rig.verifyChain(1);
        expect(await rig.journal.chainIsSound(1), isTrue);
      },
    );

    test('Review Focus 5: failReads im Speicher: der Verkauf gelingt, mode '
        'ist off, notice gesetzt, kein Eintrag für diesen Bon', () async {
      await rig.sell('s1', cart);
      rig.secrets.failReads = true;
      final r = await rig.sell('s2', cart);
      expect(r.number, 3);
      expect(r.rksv, isNull);
      expect(await rig.entryOf('s2'), isNull);
      final state = await rig.stateRow();
      expect(state.mode, 'off');
      expect(state.chain, isNull);
      expect(state.notice, _notice);
      expect((await rig.chainRow(1)).endedAt, rig.clock.now());
      // Danach läuft die Kassa ohne Signatur weiter.
      final next = await rig.sell('s3', cart);
      expect(next.number, 4);
      expect(await rig.count('rksv_entries'), 2);
      rig.secrets.failReads = false;
      await rig.verifyChain(1);
    });

    test('Review Focus 5: der Speicher antwortet nicht: der Verkauf ist '
        'nach der Frist fertig, mode off, notice gesetzt, kein Eintrag '
        '(echte Frist, 5 Sekunden)', () async {
      await rig.sell('s1', cart);
      rig.secrets.hangReads = true;
      final watch = Stopwatch()..start();
      final r = await rig.sell('s2', cart);
      watch.stop();
      expect(watch.elapsed, greaterThanOrEqualTo(RksvJournal.signLimit));
      expect(watch.elapsed, lessThan(const Duration(seconds: 7)));
      expect(r.number, 3);
      expect(r.rksv, isNull);
      expect(await rig.entryOf('s2'), isNull);
      final state = await rig.stateRow();
      expect((state.mode, state.chain, state.notice), ('off', null, _notice));
      expect(rig.fake.signCalls, 2);
      // Die Kassa verkauft danach ohne Wartezeit weiter.
      final next = await rig.sell('s3', cart);
      expect(next.number, 4);
      rig.secrets.hangReads = false;
      await rig.verifyChain(1);
    });

    test('Review Focus 5: im Ausfall gilt auch für den Speicher die Frist von '
        '1 Sekunde', () async {
      rig.fake.mode = FakeMode.error;
      await rig.sell('s1', cart);
      expect((await rig.stateRow()).outageSince, isNotNull);
      rig.secrets.hangReads = true;
      final watch = Stopwatch()..start();
      final v = await rig.receipts.voidReceipt('s1', staff: rig.chef);
      watch.stop();
      expect(
        watch.elapsed,
        greaterThanOrEqualTo(RksvJournal.signLimitDuringOutage),
      );
      expect(watch.elapsed, lessThan(const Duration(seconds: 3)));
      expect(await rig.entryOf(v.id), isNull);
      expect((await rig.stateRow()).mode, 'off');
      expect((await rig.stateRow()).notice, _notice);
    });

    test('Review Focus 5: bei einem Storno ebenso', () async {
      await rig.sell('s1', cart);
      rig.secrets.failReads = true;
      final v = await rig.receipts.voidReceipt('s1', staff: rig.chef);
      expect(v.kind, ReceiptKind.voided);
      expect(await rig.entryOf(v.id), isNull);
      expect((await rig.stateRow()).mode, 'off');
    });

    test('Review Focus 6: Storno eines Bons von vor enableProbe wirft '
        'NotInCurrentChainException, nichts geschrieben', () async {
      await rig.service.disableProbe(staff: rig.chef);
      await rig.sell('alt', cart);
      await rig.service.enableProbe(staff: rig.chef);
      final receipts = await rig.count('receipts');
      final entries = await rig.count('rksv_entries');
      await expectLater(
        rig.receipts.voidReceipt('alt', staff: rig.chef),
        throwsA(isA<NotInCurrentChainException>()),
      );
      expect(await rig.count('receipts'), receipts);
      expect(await rig.count('rksv_entries'), entries);
      expect((await rig.receipts.byId('alt')).isVoided, isFalse);
    });

    test('Review Focus 6: ebenso ein Bon aus einer beendeten Kette', () async {
      await rig.sell('s1', cart);
      await rig.service.disableProbe(staff: rig.chef);
      await rig.service.enableProbe(staff: rig.chef);
      final receipts = await rig.count('receipts');
      final entries = await rig.count('rksv_entries');
      await expectLater(
        rig.receipts.voidReceipt('s1', staff: rig.chef),
        throwsA(isA<NotInCurrentChainException>()),
      );
      expect(await rig.count('receipts'), receipts);
      expect(await rig.count('rksv_entries'), entries);
      // Ein Bon der laufenden Kette lässt sich stornieren.
      await rig.sell('s2', cart);
      await rig.receipts.voidReceipt('s2', staff: rig.chef);
      await rig.verifyChain(2);
    });

    test('Review Focus 6: nach dem Abschalten durch K9 gilt wieder off, '
        'alte Bons lassen sich stornieren', () async {
      await rig.sell('s1', cart);
      rig.secrets.failReads = true;
      await rig.sell('s2', cart);
      final v = await rig.receipts.voidReceipt('s1', staff: rig.chef);
      expect(v.rksv, isNull);
    });

    test('Review Focus 7: zwei finalizeCashSale zugleich (Future.wait) '
        'ergeben Positionen n und n+1', () async {
      final both = await Future.wait([
        rig.sell('a', cart),
        rig.sell('b', cartCard),
      ]);
      expect({for (final r in both) r.number}, {2, 3});
      final entries = await rig.entries(1);
      expect([for (final e in entries) e.position], [1, 2, 3]);
      expect({entries[1].receiptId, entries[2].receiptId}, {'a', 'b'});
      await rig.verifyChain(1);
    });

    test('gleiche saleId zweimal: ein Bon, ein Eintrag', () async {
      final both = await Future.wait([
        rig.sell('s1', cart),
        rig.sell('s1', cart),
      ]);
      expect(both[0].number, both[1].number);
      await rig.sell('s1', cart);
      await rig.sellCard('s1', cart);
      expect(await rig.count('receipts'), 2);
      expect(await rig.count('rksv_entries'), 2);
      expect(rig.fake.signCalls, 2);
      await rig.verifyChain(1);
    });

    test('Summen ungleich totalCents: StateError', () async {
      // Ein Bon der laufenden Kette, dessen Zeilen nicht zur Summe passen
      // (es gibt keine): Das Storno darf so nicht ins Protokoll.
      final db = rig.db;
      await db
          .into(db.receiptRows)
          .insert(
            ReceiptRowsCompanion.insert(
              id: 'kaputt',
              number: 2,
              createdAt: rig.clock.now(),
              staffId: rig.anna.id,
              staffName: rig.anna.name,
              businessDayId: const Value(null),
              kind: ReceiptKind.sale.name,
              goodsCents: 1000,
              depositCents: 0,
              totalCents: 1000,
            ),
          );
      await db
          .into(db.paymentRows)
          .insert(
            PaymentRowsCompanion.insert(
              receiptId: 'kaputt',
              kind: PaymentKind.cash.name,
              amountCents: 1000,
              givenCents: 1000,
              changeCents: 0,
            ),
          );
      await db
          .into(db.rksvEntryRows)
          .insert(
            RksvEntryRowsCompanion.insert(
              chain: 1,
              position: 2,
              receiptId: 'kaputt',
              jws: 'a.b.c',
              damaged: false,
              certSerial: (await rig.chainRow(1)).certSerial,
            ),
          );
      await expectLater(
        rig.receipts.voidReceipt('kaputt', staff: rig.chef),
        throwsStateError,
      );
      expect(await rig.count('receipts'), 2);
      expect(await rig.count('rksv_entries'), 2);
      expect((await rig.stateRow()).mode, 'probe');
    });

    test('chainIsSound: true für die eigene Kette, false nach einem fremden '
        'Eintrag', () async {
      await rig.sell('s1', cart);
      expect(await rig.journal.chainIsSound(1), isTrue);
      await rig.db
          .into(rig.db.receiptRows)
          .insert(
            ReceiptRowsCompanion.insert(
              id: 'fremd',
              number: 3,
              createdAt: rig.clock.now(),
              staffId: rig.anna.id,
              staffName: rig.anna.name,
              businessDayId: const Value(null),
              kind: ReceiptKind.zero.name,
              goodsCents: 0,
              depositCents: 0,
              totalCents: 0,
            ),
          );
      final cashBoxId = (await rig.chainRow(1)).cashBoxId;
      final text =
          '_R1-AT100_${cashBoxId}_3_2026-11-18T13:05:09'
          '_0,00_0,00_0,00_0,00_0,00_AAAAAAAAAAA=_1_AAAAAAAAAAA=';
      await rig.db
          .into(rig.db.rksvEntryRows)
          .insert(
            RksvEntryRowsCompanion.insert(
              chain: 1,
              position: 3,
              receiptId: 'fremd',
              jws: jwsDamaged(text),
              damaged: true,
              certSerial: '1',
            ),
          );
      expect(await rig.journal.chainIsSound(1), isFalse);
    });

    test('chainIsSound: false bei einer Lücke in den Positionen', () async {
      await rig.sell('s1', cart);
      final last = (await rig.entries(1)).last;
      await rig.db
          .into(rig.db.receiptRows)
          .insert(
            ReceiptRowsCompanion.insert(
              id: 'luecke',
              number: 3,
              createdAt: rig.clock.now(),
              staffId: rig.anna.id,
              staffName: rig.anna.name,
              businessDayId: const Value(null),
              kind: ReceiptKind.zero.name,
              goodsCents: 0,
              depositCents: 0,
              totalCents: 0,
            ),
          );
      await rig.db
          .into(rig.db.rksvEntryRows)
          .insert(
            RksvEntryRowsCompanion.insert(
              chain: 1,
              position: last.position + 2,
              receiptId: 'luecke',
              jws: last.jws,
              damaged: last.damaged,
              certSerial: last.certSerial,
            ),
          );
      expect(await rig.journal.chainIsSound(1), isFalse);
    });
  });

  test('Review Focus 1: wirft das Einfügen des Eintrags, ist weder Bon noch '
      'Eintrag gespeichert; der nächste Verkauf bekommt dieselbe Nummer und '
      'Position', () async {
    await rig.startLive();
    await rig.sell('s1', cart);
    await rig.db.customStatement(
      'CREATE TEMP TRIGGER fail_entry BEFORE INSERT ON rksv_entries BEGIN '
      "SELECT RAISE(ABORT, 'Absturz zwischen Signieren und Speichern'); END",
    );
    final settings = SettingsRepository(rig.db);
    await settings.writeDraft('{"x":1}');
    await expectLater(
      rig.sell('s2', cart),
      throwsA(
        isA<SqliteException>().having(
          (e) => e.message,
          'message',
          contains('Absturz zwischen Signieren und Speichern'),
        ),
      ),
    );
    expect(await rig.receipts.find('s2'), isNull);
    expect(await rig.count('receipts'), 1);
    expect(await rig.count('payments'), 1);
    expect(await rig.count('receipt_lines'), 2);
    expect(await rig.count('rksv_entries'), 1);
    expect((await rig.stateRow()).counterCents, 1820);
    expect((await rig.stateRow()).mode, 'live');
    expect(await settings.readDraft(), '{"x":1}');

    await rig.db.customStatement('DROP TRIGGER fail_entry');
    final next = await rig.sell('s3', cart);
    expect(next.number, 2);
    expect((await rig.entryOf('s3'))!.position, 2);
    await rig.verifyChain(1);
  });

  test('qrText aus einem gültigen Eintrag', () async {
    await rig.startLive();
    await rig.sell('s1', cart);
    final e = (await rig.entryOf('s1'))!;
    expect((await rig.receipts.byId('s1')).rksv!.qrText, qrText(e.jws));
    expect(
      base64Url.decode(base64Url.normalize(e.jws.split('.')[2])),
      hasLength(64),
    );
  });
}
