import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/domain/catalog.dart';
import 'package:kassa/domain/pricing.dart';
import 'package:kassa/domain/receipt.dart';
import 'package:kassa/domain/receipt_rules.dart';

import '../support/sales.dart' show cart;

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
}
