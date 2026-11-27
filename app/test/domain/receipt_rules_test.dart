import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/domain/cart.dart'
    show depositReturnItemId, voucherSaleItemId;
import 'package:kassa/domain/catalog.dart';
import 'package:kassa/domain/pricing.dart';
import 'package:kassa/domain/receipt.dart';
import 'package:kassa/domain/receipt_rules.dart';

import '../support/sales.dart' show cart, discounted;

void main() {
  /// Die Zeilen von `cart` (1770 Warenwert, 50 Pfand) als Zeilen eines Bons.
  final lines = [
    for (var i = 0; i < cart.lines.length; i++)
      ReceiptLine(
        position: i,
        itemId: cart.lines[i].item.id,
        name: cart.lines[i].item.name,
        unitPriceCents: cart.lines[i].unitPriceCents,
        quantity: cart.lines[i].quantity,
        unitDepositCents: cart.lines[i].unitDepositCents,
        grossByRate: grossByRateOfLine(cart.lines[i]),
      ),
  ];

  test('codeSums: Pfand und Trinkgeld zählen zum Satz 0', () {
    expect(
      codeSums(
        lineGross: [
          {TaxRate.normal: 580},
          {TaxRate.reduced1: 1190},
        ],
        depositCents: 50,
        tipCents: 80,
      ),
      [580, 1190, 0, 130, 0],
    );
    expect(tipSignatureRate, TaxRate.zero);
  });

  test('jede feste Regel hat einen Bon, der an ihr scheitert', () {
    ReceiptRule? broken({
      int goods = 1770,
      int deposit = 50,
      int total = 1820,
      List<Payment>? payments,
    }) {
      try {
        checkReceiptRules(
          goodsCents: goods,
          depositCents: deposit,
          totalCents: total,
          lines: lines,
          payments: payments ?? const [],
        );
        return null;
      } on ReceiptRuleViolation catch (e) {
        return e.rule;
      }
    }

    const cash = PaymentKind.cash, card = PaymentKind.card;
    Payment p(int pos, PaymentKind k, int a, {int tip = 0}) => Payment(
      position: pos,
      kind: k,
      amountCents: a,
      givenCents: 0,
      changeCents: 0,
      tipCents: tip,
    );
    expect(
      broken(payments: [p(0, cash, 1000), p(1, card, 820, tip: 80)]),
      isNull,
    );
    expect(
      broken(payments: [p(0, cash, 1000), p(1, card, 800)]),
      ReceiptRule.paymentsEqualTotal,
    );
    expect(
      broken(total: 1830, payments: [p(0, cash, 1830)]),
      ReceiptRule.totalIsGoodsPlusDeposit,
    );
    expect(
      broken(goods: 1760, total: 1810, payments: [p(0, cash, 1810)]),
      ReceiptRule.ratesEqualGoods,
    );
    expect(
      broken(payments: [p(0, card, 820), p(1, cash, 1000)]),
      ReceiptRule.oneCardLast,
    );
    expect(
      broken(payments: [p(0, card, 1000), p(1, card, 820)]),
      ReceiptRule.oneCardLast,
    );
    expect(
      broken(payments: [p(0, cash, 1820, tip: 10)]),
      ReceiptRule.tipOnlyOnCard,
    );
    expect(
      broken(payments: [p(0, cash, 1000), p(2, card, 820)]),
      ReceiptRule.positions,
    );
  });

  test('ein Sonderbeleg ohne Zeilen und Zahlungen mit Summe 0 besteht', () {
    expect(
      () => checkReceiptRules(
        goodsCents: 0,
        depositCents: 0,
        totalCents: 0,
        lines: const [],
        payments: const [],
      ),
      returnsNormally,
    );
  });

  test('discountSums: Zeilen-Rabatte ergeben den Rabatt des Bons, Preis mal '
      'Menge minus Rabatt ergibt den Warenwert', () {
    final p = discounted.pricing;
    List<ReceiptLine> linesWith(List<int> discounts) => [
      for (var i = 0; i < discounted.lines.length; i++)
        ReceiptLine(
          position: i,
          itemId: discounted.lines[i].item.id,
          name: discounted.lines[i].item.name,
          unitPriceCents: discounted.lines[i].unitPriceCents,
          quantity: discounted.lines[i].quantity,
          unitDepositCents: discounted.lines[i].unitDepositCents,
          grossByRate: p.lines[i].grossByRate,
          discountCents: discounts[i],
        ),
    ];
    ReceiptRule? broken(List<int> lineDiscounts, int discountCents) {
      try {
        checkReceiptRules(
          goodsCents: 1486,
          depositCents: 50,
          totalCents: 1536,
          discountCents: discountCents,
          lines: linesWith(lineDiscounts),
          payments: const [
            Payment(
              kind: PaymentKind.cash,
              amountCents: 1536,
              givenCents: 2000,
              changeCents: 464,
            ),
          ],
        );
        return null;
      } on ReceiptRuleViolation catch (e) {
        return e.rule;
      }
    }

    expect(broken([58, 226], 284), isNull);
    expect(broken([58, 226], 280), ReceiptRule.discountSums);
    expect(broken([58, 220], 278), ReceiptRule.discountSums);
  });

  group('Stufe 1b', () {
    const cash = PaymentKind.cash,
        card = PaymentKind.card,
        voucher = PaymentKind.voucher;

    /// Eine Zahlung; ein Gutschein bekommt Kennung, Code und gegeben gleich
    /// Betrag, wenn nichts anderes gesagt ist.
    Payment p(
      int pos,
      PaymentKind k,
      int a, {
      int? given,
      int change = 0,
      int tip = 0,
      String? voucherId,
      String? voucherCode,
      int? balanceAfter,
      bool plainVoucher = false,
    }) {
      final isVoucher = k == voucher && !plainVoucher;
      return Payment(
        position: pos,
        kind: k,
        amountCents: a,
        givenCents: given ?? (k == voucher ? a : 0),
        changeCents: change,
        tipCents: tip,
        voucherId: voucherId ?? (isVoucher ? 'v-$pos' : null),
        voucherCode: voucherCode ?? (isVoucher ? '1234567$pos' : null),
        voucherBalanceAfterCents: balanceAfter ?? (isVoucher ? 0 : null),
      );
    }

    /// Drei Mal "Pfand zurück" zu 25 Cent: Warenwert 0, Pfand -75.
    ReceiptLine depositReturn({int quantity = 3}) => ReceiptLine(
      position: 0,
      itemId: depositReturnItemId(25),
      name: 'Pfand zurück',
      unitPriceCents: 0,
      quantity: quantity,
      unitDepositCents: -25,
    );

    /// Ein Gutschein zu 25 € als Zeile zum Satz 0.
    ReceiptLine voucherSale({int position = 0, int quantity = 1}) =>
        ReceiptLine(
          position: position,
          itemId: voucherSaleItemId,
          name: 'Gutschein',
          unitPriceCents: 2500,
          quantity: quantity,
          unitDepositCents: 0,
          grossByRate: {TaxRate.zero: 2500 * quantity},
        );

    /// Prüft einen Bon und gibt die erste verletzte Regel zurück.
    ReceiptRule? check({
      List<ReceiptLine>? withLines,
      int goods = 1770,
      int deposit = 50,
      int? total,
      required List<Payment> payments,
      bool isVoid = false,
    }) {
      try {
        checkReceiptRules(
          goodsCents: goods,
          depositCents: deposit,
          totalCents: total ?? goods + deposit,
          lines: withLines ?? lines,
          payments: payments,
          isVoid: isVoid,
        );
        return null;
      } on ReceiptRuleViolation catch (e) {
        return e.rule;
      }
    }

    List<ReceiptLine> negated(List<ReceiptLine> ls) => [
      for (final l in ls)
        ReceiptLine(
          position: l.position,
          itemId: l.itemId,
          name: l.name,
          unitPriceCents: l.unitPriceCents,
          quantity: -l.quantity,
          unitDepositCents: l.unitDepositCents,
          grossByRate: {for (final e in l.grossByRate.entries) e.key: -e.value},
        ),
    ];

    test('Reihenfolge: Gutschein, bar, Karte besteht; bar vor Gutschein und '
        'zwei Bar-Zahlungen scheitern an paymentOrder', () {
      expect(
        check(
          payments: [
            p(0, voucher, 500),
            p(1, voucher, 300),
            p(2, cash, 520),
            p(3, card, 500, tip: 80),
          ],
        ),
        isNull,
      );
      expect(check(payments: [p(0, voucher, 1820)]), isNull);
      expect(check(payments: [p(0, voucher, 1000), p(1, card, 820)]), isNull);
      expect(
        check(payments: [p(0, cash, 1000), p(1, voucher, 820)]),
        ReceiptRule.paymentOrder,
      );
      expect(
        check(payments: [p(0, cash, 1000), p(1, cash, 820)]),
        ReceiptRule.paymentOrder,
      );
      expect(
        check(payments: [p(0, voucher, 500), p(1, cash, 500), p(2, cash, 820)]),
        ReceiptRule.paymentOrder,
      );
      // Karte vor bar bleibt ein Fall von oneCardLast, wie in 1a.
      expect(
        check(payments: [p(0, card, 820), p(1, cash, 1000)]),
        ReceiptRule.oneCardLast,
      );
    });

    test('Betrag unter 0: besteht bar bei Summe -75; scheitert mit Karte, mit '
        'Gutschein und neben einer zweiten Zahlung an negativeOnlyCash', () {
      final only = [depositReturn()];
      ReceiptRule? minus75(List<Payment> payments) =>
          check(withLines: only, goods: 0, deposit: -75, payments: payments);
      expect(minus75([p(0, cash, -75)]), isNull);
      expect(minus75([p(0, card, -75)]), ReceiptRule.negativeOnlyCash);
      expect(minus75([p(0, voucher, -75)]), ReceiptRule.negativeOnlyCash);
      expect(
        minus75([p(0, cash, -100), p(1, card, 25)]),
        ReceiptRule.negativeOnlyCash,
      );
      expect(
        minus75([p(0, voucher, 25), p(1, cash, -100)]),
        ReceiptRule.negativeOnlyCash,
      );
      // Summe über 0: auch bar darf nicht unter 0 liegen.
      expect(
        check(payments: [p(0, cash, -100), p(1, card, 1920)]),
        ReceiptRule.negativeOnlyCash,
      );
    });

    test('Storno mit isVoid: gespiegelte Beträge bestehen', () {
      // Spiegel von "nur Pfand zurück": +75 bar.
      final back = negated([depositReturn()]);
      expect(
        check(
          withLines: back,
          goods: 0,
          deposit: 75,
          payments: [p(0, cash, 75)],
          isVoid: true,
        ),
        isNull,
      );
      // Spiegel eines Bons mit Gutschein, bar und Karte mit Trinkgeld, so
      // wie ein Storno heute Zahlungen schreibt (gegeben 0, Rückgeld 0).
      final mirrored = [
        p(0, voucher, -500, given: 0),
        p(1, cash, -520),
        p(2, card, -800, tip: -80),
      ];
      expect(
        check(
          withLines: negated(lines),
          goods: -1770,
          deposit: -50,
          payments: mirrored,
          isVoid: true,
        ),
        isNull,
      );
      // Gegeben gleich Betrag geht im Storno auch.
      expect(
        check(
          withLines: negated(lines),
          goods: -1770,
          deposit: -50,
          payments: [p(0, voucher, -1000), p(1, cash, -820)],
          isVoid: true,
        ),
        isNull,
      );
      // Ohne isVoid scheitert ein Storno an negativeOnlyCash, und eine
      // Gutschein-Zahlung mit gegeben 0 an voucherFields.
      expect(
        check(
          withLines: negated(lines),
          goods: -1770,
          deposit: -50,
          payments: [p(0, voucher, -1000), p(1, cash, -820)],
        ),
        ReceiptRule.negativeOnlyCash,
      );
      expect(
        check(
          withLines: negated(lines),
          goods: -1770,
          deposit: -50,
          payments: mirrored,
        ),
        ReceiptRule.voucherFields,
      );
      // Im Storno sind die Regeln gespiegelt: Ein Betrag über 0 nur bar,
      // nur bei Summe über 0 und als einzige Zahlung.
      expect(
        check(
          withLines: back,
          goods: 0,
          deposit: 75,
          payments: [p(0, card, 75)],
          isVoid: true,
        ),
        ReceiptRule.negativeOnlyCash,
      );
      expect(
        check(
          withLines: negated(lines),
          goods: -1770,
          deposit: -50,
          payments: [p(0, cash, 100), p(1, card, -1920)],
          isVoid: true,
        ),
        ReceiptRule.negativeOnlyCash,
      );
    });

    test('Gutschein-Zeile und Gutschein-Zahlung auf einem Bon scheitern an '
        'voucherNotWithSale', () {
      final withSale = [...lines, voucherSale(position: 2)];
      expect(
        check(withLines: withSale, goods: 4270, payments: [p(0, cash, 4320)]),
        isNull,
      );
      expect(
        check(
          withLines: withSale,
          goods: 4270,
          payments: [p(0, voucher, 1000), p(1, cash, 3320)],
        ),
        ReceiptRule.voucherNotWithSale,
      );
      // Auch im Storno.
      expect(
        check(
          withLines: negated(withSale),
          goods: -4270,
          deposit: -50,
          payments: [p(0, voucher, -1000), p(1, cash, -3320)],
          isVoid: true,
        ),
        ReceiptRule.voucherNotWithSale,
      );
    });

    test('Gutschein-Zahlung ohne Code, mit Rückgeld oder mit Trinkgeld '
        'scheitert an voucherFields', () {
      expect(check(payments: [p(0, voucher, 1820)]), isNull);
      expect(
        check(payments: [p(0, voucher, 1820, plainVoucher: true)]),
        ReceiptRule.voucherFields,
      );
      expect(
        check(
          payments: [
            p(0, voucher, 1820, plainVoucher: true, voucherCode: '12345678'),
          ],
        ),
        ReceiptRule.voucherFields,
      );
      expect(
        check(
          payments: [p(0, voucher, 1820, plainVoucher: true, voucherId: 'v1')],
        ),
        ReceiptRule.voucherFields,
      );
      expect(
        check(payments: [p(0, voucher, 1820, given: 2000, change: 180)]),
        ReceiptRule.voucherFields,
      );
      expect(
        check(payments: [p(0, voucher, 1820, given: 2000)]),
        ReceiptRule.voucherFields,
      );
      expect(
        check(payments: [p(0, voucher, 1820, tip: 50)]),
        ReceiptRule.voucherFields,
      );
      // Andere Arten tragen keine Gutschein-Felder.
      expect(
        check(payments: [p(0, cash, 1820, voucherCode: '12345678')]),
        ReceiptRule.voucherFields,
      );
      expect(
        check(payments: [p(0, card, 1820, voucherId: 'v1')]),
        ReceiptRule.voucherFields,
      );
      expect(
        check(payments: [p(0, cash, 1820, balanceAfter: 0)]),
        ReceiptRule.voucherFields,
      );
    });

    test('codeSums: Bon nur mit Pfand zurück trägt -75 im Satz 0; '
        'Gutschein-Zeile 2500 im Satz 0', () {
      expect(codeSums(lineGross: const [{}], depositCents: -75, tipCents: 0), [
        0,
        0,
        0,
        -75,
        0,
      ]);
      expect(
        codeSums(
          lineGross: const [
            {TaxRate.zero: 2500},
          ],
          depositCents: 0,
          tipCents: 0,
        ),
        [0, 0, 0, 2500, 0],
      );
    });

    test('Bon: Gutschein-Summen, Pfand zurück, Umsatz und Zahlungsarten', () {
      Receipt receipt({
        required List<ReceiptLine> ls,
        required List<Payment> ps,
        required int goods,
        required int deposit,
        ReceiptKind kind = ReceiptKind.sale,
      }) => Receipt(
        id: 'r',
        number: 1,
        createdAt: DateTime(2026, 11, 27),
        staffId: 's',
        staffName: 'Anna',
        businessDayId: 'd',
        kind: kind,
        lines: ls,
        payments: ps,
        goodsCents: goods,
        depositCents: deposit,
        totalCents: goods + deposit,
      );

      final sale = receipt(
        ls: [
          ...lines,
          voucherSale(position: 2),
          ReceiptLine(
            position: 3,
            itemId: depositReturnItemId(25),
            name: 'Pfand zurück',
            unitPriceCents: 0,
            quantity: 2,
            unitDepositCents: -25,
          ),
        ],
        ps: [p(0, cash, 1000), p(1, card, 3270)],
        goods: 4270,
        deposit: 0,
      );
      expect(sale.voucherSaleCents, 2500);
      expect(sale.depositReturnCents, -50);
      expect(sale.depositReturnQuantity, 2);
      expect(sale.revenueCents, 4270 - 2500);
      expect(sale.voucherCents, 0);
      expect(sale.paymentKinds, {cash, card});
      expect(sale.paymentKind, ReceiptPaymentKind.mixed);
      expect(sale.publicToken, isNull);
      expect(sale.soldVouchers, isEmpty);

      final paid = receipt(
        ls: lines,
        ps: [p(0, voucher, 500), p(1, voucher, 300), p(2, cash, 1020)],
        goods: 1770,
        deposit: 50,
      );
      expect(paid.voucherCents, 800);
      expect(paid.cashCents, 1020);
      expect(paid.revenueCents, 1820);
      expect(paid.paymentKinds, {voucher, cash});
      // paymentKind sieht Gutscheine nicht.
      expect(paid.paymentKind, ReceiptPaymentKind.cash);
      final onlyVoucher = receipt(
        ls: lines,
        ps: [p(0, voucher, 1820)],
        goods: 1770,
        deposit: 50,
      );
      expect(onlyVoucher.paymentKind, isNull);
      expect(onlyVoucher.paymentKinds, {voucher});

      final voided = receipt(
        kind: ReceiptKind.voided,
        ls: negated([voucherSale(), depositReturn()]),
        ps: [p(0, cash, -2425)],
        goods: -2500,
        deposit: 75,
      );
      expect(voided.voucherSaleCents, -2500);
      expect(voided.depositReturnCents, 75);
      expect(voided.depositReturnQuantity, -3);
      expect(voided.revenueCents, -2425 + 2500);

      const sold = SoldVoucher(
        voucherId: 'v1',
        code: '12345678',
        valueCents: -2500,
        linePosition: 0,
      );
      final withToken = Receipt(
        id: 'r2',
        number: 2,
        createdAt: DateTime(2026, 11, 27),
        staffId: 's',
        staffName: 'Anna',
        businessDayId: 'd',
        kind: ReceiptKind.voided,
        lines: const [],
        payments: const [],
        goodsCents: 0,
        depositCents: 0,
        totalCents: 0,
        publicToken: 'abc',
        soldVouchers: const [sold],
      );
      expect(withToken.publicToken, 'abc');
      expect(withToken.soldVouchers.single.valueCents, -2500);
      expect(withToken.soldVouchers.single.code, '12345678');
      expect(withToken.soldVouchers.single.voucherId, 'v1');
      expect(withToken.soldVouchers.single.linePosition, 0);
    });
  });
}
