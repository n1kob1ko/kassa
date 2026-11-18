import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show InsertMode, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/card_payment_repository.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/receipt_repository.dart';
import 'package:kassa/data/settings_repository.dart';
import 'package:kassa/domain/cart.dart';
import 'package:kassa/domain/catalog.dart';
import 'package:kassa/domain/receipt.dart';

import '../support/demo_fixtures.dart';
import '../support/sales.dart';

void main() {
  late TestShop shop;
  late ReceiptRepository receipts;

  setUp(() async {
    shop = await TestShop.open();
    receipts = shop.receipts;
  });
  tearDown(() => shop.close());

  test('Abschließen löscht den Bon-Entwurf im selben Schritt', () async {
    final settings = SettingsRepository(shop.db);
    await settings.writeDraft('{"x":1}');
    await shop.receipts.finalizeCashSale(
      saleId: 's1',
      cart: cart,
      givenCents: 2000,
      staff: shop.anna,
    );
    expect(await settings.readDraft(), isNull);
  });

  test('scheitert das Speichern, bleibt der Entwurf', () async {
    final settings = SettingsRepository(shop.db);
    await settings.writeDraft('{"x":1}');
    await expectLater(
      shop.receipts.finalizeCashSale(
        saleId: 's1',
        cart: const Cart.empty(),
        givenCents: 0,
        staff: shop.anna,
      ),
      throwsA(isA<EmptyCartException>()),
    );
    expect(await settings.readDraft(), '{"x":1}');
  });

  test('Bon bekommt Nummer 1, Zeilen, Summen, Zahlung', () async {
    final cart = const Cart.empty()
        .add(cola)
        .add(cola)
        .add(huhnBowl, options: [xxl, nudeln]);
    final r = await receipts.finalizeCashSale(
      saleId: 's1',
      cart: cart,
      givenCents: 2000,
      staff: shop.anna,
    );
    expect((r.number, r.kind, r.staffName), (1, ReceiptKind.sale, 'Anna'));
    expect(r.staffId, shop.anna.id);
    expect((r.goodsCents, r.depositCents, r.totalCents), (1770, 50, 1820));
    expect(r.grossByRate, {TaxRate.normal: 580, TaxRate.reduced1: 1190});
    expect(
      (r.payment!.kind, r.payment!.givenCents, r.payment!.changeCents),
      (PaymentKind.cash, 2000, 180),
    );
    expect(
      r.lines.last.options.map(
        (o) => (o.groupName, o.optionName, o.surchargeCents),
      ),
      [('Größe', 'XXL', 200), ('Basis', 'Nudeln', 0)],
    );
    expect(r.createdAt, DateTime(2026, 11, 17, 11));
    expect(
      r.lines.map(
        (l) => (
          l.position,
          l.itemId,
          l.unitPriceCents,
          l.quantity,
          l.unitDepositCents,
        ),
      ),
      [(0, 'cola', 290, 2, 25), (1, 'huhn-bowl', 1190, 1, 0)],
    );
    expect(r.lines.last.grossByRate, {TaxRate.reduced1: 1190});
    expect(r.taxLines.map((t) => (t.rate, t.grossCents)), [
      (TaxRate.normal, 580),
      (TaxRate.reduced1, 1190),
    ]);
    final again = await receipts.byId(r.id);
    expect((again.number, again.totalCents, again.lines.length), (1, 1820, 2));
    expect(again.grossByRate, r.grossByRate);
  });

  test('gleiche saleId zweimal ergibt genau einen Bon', () async {
    final a = await shop.sell('s1');
    final b = await shop.sell('s1');
    expect(b.id, a.id);
    expect(await shop.count('receipts'), 1);
  });

  test('gleiche saleId gleichzeitig ergibt genau einen Bon', () async {
    final both = await Future.wait([shop.sell('s1'), shop.sell('s1')]);
    expect(both[0].id, both[1].id);
    expect(both.map((r) => r.number), [1, 1]);
    expect(await shop.count('receipts'), 1);
    expect(await shop.count('payments'), 1);
  });

  test(
    'verschiedene saleIds gleichzeitig bekommen die Nummern 1 und 2',
    () async {
      final both = await Future.wait([shop.sell('a'), shop.sell('b')]);
      expect(both.map((r) => r.number).toList()..sort(), [1, 2]);
    },
  );

  test('Nummern steigen lückenlos, auch wenn die Uhr zurückspringt', () async {
    await shop.sell('s1');
    shop.clock.value = DateTime(2026, 11, 17, 9);
    await shop.sell('s2');
    await shop.sell('s3');
    final day = await shop.dayId();
    expect((await receipts.watchDay(day).first).map((r) => r.number).toList(), [
      1,
      2,
      3,
    ]);
  });

  test('watchDay meldet jeden neuen Bon', () async {
    await shop.sell('s1');
    final day = await shop.dayId();
    final emitted = <List<int>>[];
    final sub = receipts
        .watchDay(day)
        .listen((l) => emitted.add([for (final r in l) r.number]));
    await pumpEventQueue();
    await shop.sell('s2');
    await pumpEventQueue();
    await sub.cancel();
    expect(emitted.first, [1]);
    expect(emitted.last, [1, 2]);
  });

  test('leerer Bon und zu wenig Geld werden abgelehnt', () async {
    await expectLater(
      receipts.finalizeCashSale(
        saleId: 'x',
        cart: const Cart.empty(),
        givenCents: 0,
        staff: shop.anna,
      ),
      throwsA(isA<EmptyCartException>()),
    );
    await expectLater(
      receipts.finalizeCashSale(
        saleId: 'y',
        cart: cart,
        givenCents: 100,
        staff: shop.anna,
      ),
      throwsA(isA<InsufficientCashException>()),
    );
    expect(await shop.count('receipts'), 0);
  });

  test('Summe 0 mit gegeben 0 geht', () async {
    final r = await receipts.finalizeCashSale(
      saleId: 'z',
      cart: const Cart.empty().add(leitungswasser),
      givenCents: 0,
      staff: shop.anna,
    );
    expect(r.totalCents, 0);
  });

  test('Storno erzeugt einen eigenen Bon mit negativen Beträgen', () async {
    final r = await shop.sell('s1');
    final v = await receipts.voidReceipt(r.id, staff: shop.chef);
    expect(
      (v.number, v.kind, v.voidsReceiptId, v.totalCents),
      (2, ReceiptKind.voided, r.id, -r.totalCents),
    );
    expect(v.staffName, 'Chef');
    expect(v.lines.first.quantity, -r.lines.first.quantity);
    expect(v.lines.last.options.map((o) => o.optionName), ['XXL', 'Nudeln']);
    expect(v.payment!.amountCents, -r.totalCents);
    expect(
      (v.payment!.kind, v.payment!.givenCents, v.payment!.changeCents),
      (PaymentKind.cash, 0, 0),
    );
    expect(v.businessDayId, r.businessDayId);
    expect((await receipts.byId(r.id)).isVoided, isTrue);
    expect((await receipts.byId(r.id)).voidedByReceiptId, v.id);
    expect(v.isVoided, isFalse);
    await expectLater(
      receipts.voidReceipt(r.id, staff: shop.chef),
      throwsA(isA<AlreadyVoidedException>()),
    );
    await expectLater(
      receipts.voidReceipt(v.id, staff: shop.chef),
      throwsA(isA<CannotVoidAVoidException>()),
    );
  });

  test('Storno-Bon hat negierte Steuerbeträge und negiertes Pfand', () async {
    final r = await shop.sell('s1');
    final v = await receipts.voidReceipt(r.id, staff: shop.chef);
    expect(v.grossByRate, {TaxRate.normal: -580, TaxRate.reduced1: -1190});
    expect(v.grossByRate, {
      for (final e in r.grossByRate.entries) e.key: -e.value,
    });
    expect((v.goodsCents, v.depositCents), (-1770, -50));
    expect(
      v.taxLines.map((t) => (t.rate, t.grossCents, t.netCents, t.taxCents)),
      r.taxLines.map((t) => (t.rate, -t.grossCents, -t.netCents, -t.taxCents)),
    );
  });

  test('Storno kopiert die Zeilen vom Bon, nicht aus dem Katalog', () async {
    final r = await shop.sell('s1');
    await shop.catalogRepo.updateItem('cola', priceCents: 999);
    final v = await receipts.voidReceipt(r.id, staff: shop.chef);
    expect(v.lines.first.unitPriceCents, 290);
    expect(v.totalCents, -1820);
  });

  test('Storno gehört zum Tag, der beim Storno offen ist', () async {
    final r = await shop.sell('s1');
    await shop.db.customStatement(
      "UPDATE business_days SET closed_at = 1 WHERE id = '${r.businessDayId}'",
    );
    final v = await receipts.voidReceipt(r.id, staff: shop.chef);
    expect(v.businessDayId, isNot(r.businessDayId));
    expect(v.businessDayId, await shop.dayId());
  });

  test('byId mit unbekannter Id wirft StateError', () async {
    await expectLater(receipts.byId('gibt-es-nicht'), throwsStateError);
  });

  test(
    'ein Bon behält Namen und Preis, auch wenn der Artikel sich ändert',
    () async {
      final r = await shop.sell('s1');
      await shop.catalogRepo.updateItem('cola', priceCents: 999);
      final stored = await receipts.byId(r.id);
      expect(stored.lines.first.unitPriceCents, 290);
      expect(stored.lines.first.name, 'Cola 0,33 l');
    },
  );

  test('die Datenbank weist Ändern und Löschen von Bons ab', () async {
    await shop.sell('s1');
    for (final sql in [
      'UPDATE receipts SET total_cents = 1',
      'DELETE FROM receipts',
      'UPDATE receipt_lines SET quantity = 5',
      'DELETE FROM receipt_lines',
      'UPDATE receipt_line_options SET surcharge_cents = 5',
      'DELETE FROM receipt_line_options',
      'UPDATE payments SET amount_cents = 1',
      'DELETE FROM payments',
    ]) {
      await expectLater(
        shop.db.customStatement(sql),
        throwsA(
          predicate((e) => e.toString().contains('Bons sind unveränderlich')),
        ),
        reason: sql,
      );
    }
    expect(await shop.count('receipt_line_options'), 2);
  });

  test('zwei Stornos desselben Bons scheitern an der Datenbank', () async {
    final r = await shop.sell('s1');
    await receipts.voidReceipt(r.id, staff: shop.chef);
    await expectLater(
      shop.db.customStatement(
        "INSERT INTO receipts (id, number, created_at, staff_id, staff_name, business_day_id, kind, voids_receipt_id, goods_cents, deposit_cents, total_cents) "
        "VALUES ('x', 99, 1, 'a', 'A', '${r.businessDayId}', 'voided', '${r.id}', 0, 0, 0)",
      ),
      throwsA(anything),
    );
  });

  test('Kartenbon: Zahlung mit Anbieter, Beleg-Code und Karte, Entwurf und '
      'offene Zahlung im selben Schritt weg', () async {
    final cards = CardPaymentRepository(shop.db, shop.clock);
    await cards.begin(paymentId: 'c1', cart: cart, staff: shop.anna);
    final settings = SettingsRepository(shop.db);
    await settings.writeDraft('{"lines":[]}');
    final r = await receipts.finalizeCardSale(
      saleId: 'c1',
      cart: cart,
      staff: shop.anna,
      provider: 'sumup',
      txCode: 'TX9',
      cardScheme: 'VISA',
      cardLast4: '4242',
    );
    expect(r.payment!.kind, PaymentKind.card);
    expect(
      (r.payment!.amountCents, r.payment!.givenCents, r.payment!.changeCents),
      (1820, 0, 0),
    );
    final back = await receipts.byId('c1');
    expect(
      (
        back.payment!.provider,
        back.payment!.providerTxCode,
        back.payment!.cardScheme,
        back.payment!.cardLast4,
      ),
      ('sumup', 'TX9', 'VISA', '4242'),
    );
    expect(await cards.pending(), isEmpty);
    expect(await settings.readDraft(), isNull);
  });

  test('Kartenbon: gleiche saleId zweimal ergibt einen Bon', () async {
    final a = await shop.sellCard('c1');
    final b = await shop.sellCard('c1');
    expect(b.id, a.id);
    expect(await shop.count('receipts'), 1);
  });

  test(
    'Kartenbon: leerer Bon wird abgelehnt, die offene Zahlung bleibt',
    () async {
      final cards = CardPaymentRepository(shop.db, shop.clock);
      await cards.begin(paymentId: 'c1', cart: cart, staff: shop.anna);
      await expectLater(
        receipts.finalizeCardSale(
          saleId: 'c1',
          cart: const Cart.empty(),
          staff: shop.anna,
          provider: 'sumup',
        ),
        throwsA(isA<EmptyCartException>()),
      );
      expect(await cards.pending(), hasLength(1));
      expect(await shop.count('receipts'), 0);
    },
  );

  test('Storno eines Karten-Bons: Storno-Bon mit Zahlungsart Karte und '
      'negativem Betrag', () async {
    final sale = await shop.sellCard('c1');
    final v = await receipts.voidReceipt(sale.id, staff: shop.chef);
    expect(v.payment!.kind, PaymentKind.card);
    expect(v.payment!.amountCents, -sale.totalCents);
    expect(v.payment!.providerTxCode, 'TX-c1');
    expect(v.totalCents, -sale.totalCents);
  });

  group('Sonderbelege', () {
    /// Kompakte JWS-Form mit erfundener Nutzlast und Signatur 01 02 03.
    String jws(String payload) =>
        'eyJhbGciOiJFUzI1NiJ9.'
        '${base64Url.encode(utf8.encode(payload)).replaceAll('=', '')}.AQID';

    Future<void> insertChain(int chain, String mode, String cashBoxId) async {
      await shop.db
          .into(shop.db.rksvCertificateRows)
          .insert(
            RksvCertificateRowsCompanion.insert(
              serialHex: '0a1b',
              certificate: Uint8List.fromList([0x30, 0x82]),
            ),
            mode: InsertMode.insertOrIgnore,
          );
      await shop.db
          .into(shop.db.rksvChainRows)
          .insert(
            RksvChainRowsCompanion.insert(
              chain: Value(chain),
              mode: mode,
              cashBoxId: cashBoxId,
              zdaId: 'R1-AT100',
              certSerial: '0a1b',
              startedAt: DateTime(2026, 11, 1),
            ),
          );
    }

    Future<void> insertEntry(
      int chain,
      int position,
      String receiptId,
      String jws, {
      bool damaged = false,
    }) => shop.db
        .into(shop.db.rksvEntryRows)
        .insert(
          RksvEntryRowsCompanion.insert(
            chain: chain,
            position: position,
            receiptId: receiptId,
            jws: jws,
            damaged: damaged,
            certSerial: '0a1b',
          ),
        );

    test('ein Bon ohne Tag und ohne Zahlung wird gelesen', () async {
      await shop.insertSpecialReceipt('m1', 1, ReceiptKind.month);
      final r = await receipts.byId('m1');
      expect(r.kind, ReceiptKind.month);
      expect(r.businessDayId, isNull);
      expect(r.payment, isNull);
      expect(r.lines, isEmpty);
      expect((r.goodsCents, r.depositCents, r.totalCents), (0, 0, 0));
      expect(r.rksv, isNull);
      expect(r.isVoided, isFalse);
    });

    test('Arten: Sonderbelege und ihre Bezeichnungen', () {
      expect(
        {for (final k in ReceiptKind.values) k.name: k.specialTitle},
        {
          'sale': null,
          'voided': null,
          'start': 'Startbeleg',
          'month': 'Monatsbeleg',
          'year': 'Jahresbeleg',
          'zero': 'Nullbeleg',
          'collective': 'Sammelbeleg',
          'closing': 'Schlussbeleg',
        },
      );
      expect(
        [
          for (final k in ReceiptKind.values)
            if (k.isSpecial) k.name,
        ],
        ['start', 'month', 'year', 'zero', 'collective', 'closing'],
      );
    });

    test('rksv kommt aus Protokoll-Eintrag und Kette', () async {
      await insertChain(1, 'probe', 'BSPIMB01');
      await insertChain(2, 'live', 'BSPIMB02');
      await shop.insertSpecialReceipt('st', 1, ReceiptKind.start);
      await shop.sell('s1');
      final sale = (await shop.db.select(shop.db.receiptRows).get())
          .singleWhere((r) => r.number == 2);
      await insertEntry(1, 1, 'st', jws('_R1-AT100_BSPIMB01_1'));
      await insertEntry(
        2,
        1,
        sale.id,
        jws('_R1-AT100_BSPIMB02_2'),
        damaged: true,
      );
      await shop.sell('s2'); // ohne Eintrag

      final start = (await receipts.byId('st')).rksv!;
      expect(
        (start.cashBoxId, start.qrText, start.damaged, start.probe),
        ('BSPIMB01', '_R1-AT100_BSPIMB01_1_AQID', false, true),
      );
      final day = await receipts.watchDay(await shop.dayId()).first;
      final signed = day.singleWhere((r) => r.number == 2).rksv!;
      expect(
        (signed.cashBoxId, signed.qrText, signed.damaged, signed.probe),
        ('BSPIMB02', '_R1-AT100_BSPIMB02_2_AQID', true, false),
      );
      expect(day.singleWhere((r) => r.number == 3).rksv, isNull);
    });

    test('ein kaputter JWS im Protokoll: dieser Bon kommt ohne rksv, die '
        'anderen mit', () async {
      await insertChain(1, 'probe', 'BSPIMB01');
      await shop.sell('s1');
      await shop.sell('s2');
      await shop.sell('s3');
      await insertEntry(1, 1, 's1', jws('_R1-AT100_BSPIMB01_1'));
      await insertEntry(1, 2, 's2', 'kein-jws');
      await insertEntry(1, 3, 's3', 'eyJhbGciOiJFUzI1NiJ9.%%%.AQID');
      expect((await receipts.byId('s2')).rksv, isNull);
      expect((await receipts.byId('s3')).rksv, isNull);
      final day = await receipts.watchDay(await shop.dayId()).first;
      expect(
        [for (final r in day) r.rksv?.qrText],
        ['_R1-AT100_BSPIMB01_1_AQID', null, null],
      );
    });

    test('ein Sonderbeleg lässt sich nicht stornieren, nichts wird '
        'geschrieben', () async {
      await shop.insertSpecialReceipt('st', 1, ReceiptKind.start);
      await expectLater(
        receipts.voidReceipt('st', staff: shop.chef),
        throwsA(isA<CannotVoidSpecialException>()),
      );
      expect(await shop.count('receipts'), 1);
    });

    test('watchDay ordnet Sonderbelege nach der Zeit den Tagen zu', () async {
      await shop.insertDay(
        'a',
        DateTime(2026, 11, 10, 8),
        closedAt: DateTime(2026, 11, 10, 20),
      );
      await shop.insertDay(
        'b',
        DateTime(2026, 11, 12, 8),
        closedAt: DateTime(2026, 11, 12, 20),
      );
      await shop.insertDay('c', DateTime(2026, 11, 14, 8));
      // Sonderbelege: vor dem ersten Tag, zwischen den Tagen, genau beim
      // Beginn eines Tages und nach dem Beginn des neuesten Tages.
      await shop.insertSpecialReceipt(
        'start',
        1,
        ReceiptKind.start,
        at: DateTime(2026, 11, 9, 12),
      );
      await shop.insertCardReceipt(
        'a1',
        2,
        500,
        day: 'a',
        at: DateTime(2026, 11, 10, 9),
      );
      await shop.insertSpecialReceipt(
        'zero-a',
        3,
        ReceiptKind.zero,
        at: DateTime(2026, 11, 11, 12),
      );
      await shop.insertSpecialReceipt(
        'month-b',
        4,
        ReceiptKind.month,
        at: DateTime(2026, 11, 12, 8),
      );
      await shop.insertCardReceipt(
        'b1',
        5,
        500,
        day: 'b',
        at: DateTime(2026, 11, 12, 8),
      );
      await shop.insertSpecialReceipt(
        'zero-b',
        6,
        ReceiptKind.zero,
        at: DateTime(2026, 11, 13, 12),
      );
      await shop.insertCardReceipt(
        'c1',
        7,
        500,
        day: 'c',
        at: DateTime(2026, 11, 14, 9),
      );
      await shop.insertSpecialReceipt(
        'closing',
        8,
        ReceiptKind.closing,
        at: DateTime(2026, 11, 20, 12),
      );

      Future<List<int>> numbersOf(String day) async => [
        for (final r in await receipts.watchDay(day).first) r.number,
      ];
      expect(await numbersOf('a'), [1, 2, 3]);
      expect(await numbersOf('b'), [4, 5, 6]);
      expect(await numbersOf('c'), [7, 8]);
    });

    test('watchDay meldet einen neuen Sonderbeleg', () async {
      await shop.sell('s1');
      final day = await shop.dayId();
      final emitted = <List<int>>[];
      final sub = receipts
          .watchDay(day)
          .listen((l) => emitted.add([for (final r in l) r.number]));
      await pumpEventQueue();
      await shop.insertSpecialReceipt('z', 2, ReceiptKind.zero);
      await pumpEventQueue();
      await sub.cancel();
      expect(emitted.first, [1]);
      expect(emitted.last, [1, 2]);
    });
  });
}
