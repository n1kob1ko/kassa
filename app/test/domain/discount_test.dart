import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/domain/cart.dart';
import 'package:kassa/domain/catalog.dart';
import 'package:kassa/domain/discount.dart';

import '../support/sales.dart' show cart;

/// Ein Bon mit einer Zeile: Artikel zu [itemRate], eine Option mit eigenem
/// Satz [optionRate], Rabatt [discount] auf der Zeile.
Cart _oneLine({
  required int priceCents,
  required TaxRate itemRate,
  required int surchargeCents,
  required TaxRate optionRate,
  required Discount discount,
}) {
  final option = ModifierOption(
    id: 'm/0/0',
    name: 'Option',
    surchargeCents: surchargeCents,
    taxRate: optionRate,
  );
  final item = Item(
    id: 'x',
    name: 'Artikel',
    priceCents: priceCents,
    categoryId: 'c',
    taxRate: itemRate,
    templateId: 't',
    position: 0,
  );
  final c = const Cart.empty().add(item, options: [option], lineId: 'a');
  return c.setLineDiscount('a', discount);
}

void main() {
  test('allocate: das Beispiel der Spec und der Gleichstand', () {
    expect(allocate(213, [1782, 350]), [178, 35]); // 10 % Aktion von 21,32
    expect(allocate(2, [3, 3, 3]), [
      1,
      1,
      0,
    ]); // gleicher Rest: die frühere Zeile
    expect(allocate(1, [0, 5, 5]), [0, 1, 0]);
    expect(allocate(0, [5, 5]), [0, 0]);
    expect(() => allocate(11, [5, 5]), throwsArgumentError);
  });

  test('allocate: negativer Betrag oder negatives Gewicht ist ein Fehler', () {
    expect(() => allocate(-1, [5, 5]), throwsArgumentError);
    expect(() => allocate(1, [5, -1]), throwsArgumentError);
    expect(allocate(0, const []), isEmpty);
  });

  test('Discount.of: kaufmännisch gerundet, Betrag gekappt', () {
    expect(const Discount.percent(10, DiscountReason.regular).of(1980), 198);
    expect(const Discount.percent(10, DiscountReason.promotion).of(2132), 213);
    expect(
      const Discount.percent(15, DiscountReason.staff).of(290),
      44,
    ); // 43,5 wird 44
    expect(const Discount.amount(500, DiscountReason.staff).of(290), 290);
    expect(const Discount.percent(100, DiscountReason.invitation).of(0), 0);
  });

  test('Discount.of: kein Rabatt auf einen Wert unter 0', () {
    expect(const Discount.amount(500, DiscountReason.staff).of(-100), 0);
    expect(const Discount.percent(50, DiscountReason.staff).of(-100), 0);
  });

  test('Discount als JSON: hin und zurück', () {
    const p = Discount.percent(10, DiscountReason.regular);
    const a = Discount.amount(200, DiscountReason.staff);
    expect(p.toJson(), {'percent': 10, 'reason': 'regular'});
    expect(a.toJson(), {'amountCents': 200, 'reason': 'staff'});
    for (final d in [p, a]) {
      final back = Discount.fromJson(d.toJson())!;
      expect(
        (back.percent, back.amountCents, back.reason),
        (d.percent, d.amountCents, d.reason),
      );
    }
  });

  group('Discount.fromJson: alles Unlesbare ist null', () {
    for (final (name, json) in <(String, Object?)>[
      ('null', null),
      ('keine Map', 'zehn Prozent'),
      ('Prozent ist Text', {'percent': '10', 'reason': 'regular'}),
      ('Betrag ist Kommazahl', {'amountCents': 2.5, 'reason': 'staff'}),
      ('Grund ist keine Zeichenkette', {'percent': 10, 'reason': 3}),
      ('unbekannter Grund', {'percent': 10, 'reason': 'geburtstag'}),
      ('ohne Grund', {'percent': 10}),
      ('Prozent 0', {'percent': 0, 'reason': 'regular'}),
      ('Prozent 150', {'percent': 150, 'reason': 'regular'}),
      ('Betrag 0', {'amountCents': 0, 'reason': 'staff'}),
      ('negativer Betrag', {'amountCents': -200, 'reason': 'staff'}),
      ('weder Prozent noch Betrag', {'reason': 'staff'}),
      (
        'Prozent und Betrag zugleich',
        {'percent': 10, 'amountCents': 200, 'reason': 'staff'},
      ),
    ]) {
      test(name, () => expect(Discount.fromJson(json), isNull));
    }
  });

  test('Discount: gleich bei gleichem Prozent, Betrag und Grund', () {
    const a = Discount.percent(10, DiscountReason.regular);
    expect(a, const Discount.percent(10, DiscountReason.regular));
    expect(
      a.hashCode,
      const Discount.percent(10, DiscountReason.regular).hashCode,
    );
    expect(a, isNot(const Discount.percent(20, DiscountReason.regular)));
    expect(a, isNot(const Discount.percent(10, DiscountReason.staff)));
    expect(
      const Discount.amount(500, DiscountReason.staff),
      const Discount.amount(500, DiscountReason.staff),
    );
    expect(
      const Discount.amount(500, DiscountReason.staff),
      isNot(const Discount.amount(400, DiscountReason.staff)),
    );
    // 100 % ist nicht dasselbe wie ein Betrag.
    expect(
      const Discount.percent(100, DiscountReason.invitation),
      isNot(const Discount.amount(100, DiscountReason.invitation)),
    );
    expect(a.toString(), 'Discount(10 %, regular)');
    expect(
      const Discount.amount(119, DiscountReason.complaint).toString(),
      'Discount(119 Cent, complaint)',
    );
  });

  test('discountReasonLabel: deutsch, unbekannte Namen bleiben', () {
    expect(
      [for (final r in DiscountReason.values) discountReasonLabel(r.name)],
      ['Stammgast', 'Mitarbeiter', 'Reklamation', 'Aktion', 'Einladung'],
    );
    expect(discountReasonLabel('geburtstag'), 'geburtstag');
  });

  test('Zeilen-Rabatt und Bon-Rabatt zusammen', () {
    final bowl = cart.lines[1].lineId;
    final p = cart
        .setLineDiscount(
          bowl,
          const Discount.percent(10, DiscountReason.regular),
        )
        .setReceiptDiscount(
          const Discount.percent(10, DiscountReason.promotion),
        )
        .pricing;
    expect(
      (p.subtotalCents, p.receiptDiscountCents, p.discountCents),
      (1651, 165, 284),
    );
    expect(
      [
        for (final l in p.lines)
          (l.listCents, l.ownDiscountCents, l.shareCents),
      ],
      [(580, 0, 58), (1190, 119, 107)],
    );
    expect(p.grossByRate, {TaxRate.normal: 522, TaxRate.reduced1: 964});
    expect((p.goodsCents, p.depositCents, p.totalCents), (1486, 50, 1536));
  });

  test('Zeile mit zwei Steuersätzen: der Rabatt verteilt sich nach derselben Regel', () {
    // Artikel 10,00 zu 10 %, Option +3,00 mit eigenem Satz 20 %, Rabatt 1,00 als Betrag
    final line = _oneLine(
      priceCents: 1000,
      itemRate: TaxRate.reduced1,
      surchargeCents: 300,
      optionRate: TaxRate.normal,
      discount: const Discount.amount(100, DiscountReason.staff),
    );
    expect(line.pricing.grossByRate, {
      TaxRate.normal: 277,
      TaxRate.reduced1: 923,
    });
  });

  test('Option mit Minus-Aufpreis und 100 %: kein Satz wird durch den Rabatt negativ, die Zeile ergibt 0', () {
    // Artikel 5,00 zu 10 %, Option -1,00 mit eigenem Satz 20 %, Einladung
    final line = _oneLine(
      priceCents: 500,
      itemRate: TaxRate.reduced1,
      surchargeCents: -100,
      optionRate: TaxRate.normal,
      discount: const Discount.percent(100, DiscountReason.invitation),
    );
    expect(line.pricing.grossByRate, {
      TaxRate.normal: -100,
      TaxRate.reduced1: 100,
    });
    expect(line.pricing.goodsCents, 0);
  });

  test('Einladung auf den Bon: Summe ist das Pfand', () {
    expect(
      cart
          .setReceiptDiscount(
            const Discount.percent(100, DiscountReason.invitation),
          )
          .totalCents,
      50,
    );
  });

  test('ohne Rabatt: dieselben Zahlen wie vorher', () {
    final p = cart.pricing;
    expect(
      (p.subtotalCents, p.receiptDiscountCents, p.discountCents),
      (1770, 0, 0),
    );
    expect(
      (cart.goodsCents, cart.depositCents, cart.totalCents),
      (1770, 50, 1820),
    );
    expect(p.grossByRate, {TaxRate.normal: 580, TaxRate.reduced1: 1190});
    expect(
      [for (final l in cart.lines) l.listGrossByRate],
      [
        {TaxRate.normal: 580},
        {TaxRate.reduced1: 1190},
      ],
    );
  });
}
