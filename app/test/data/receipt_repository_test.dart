import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/receipt_repository.dart';
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
      (r.payment.kind, r.payment.givenCents, r.payment.changeCents),
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
    expect(v.payment.amountCents, -r.totalCents);
    expect(
      (v.payment.kind, v.payment.givenCents, v.payment.changeCents),
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
}
