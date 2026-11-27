// Die festen Geld-Regeln eines Bons (Spec 5.6) und die fünf Beträge der
// Signatur. Reines Dart.

import 'catalog.dart';
import 'receipt.dart';

/// Die einzige Stelle, die sagt, zu welchem Satz das Trinkgeld bei der
/// Signatur zählt (Spec 5.3 und 9).
const tipSignatureRate = TaxRate.zero;

/// Reihenfolge der fünf Beträge im Code.
const _codeRates = [
  TaxRate.normal,
  TaxRate.reduced1,
  TaxRate.reduced2,
  TaxRate.zero,
  TaxRate.special,
];

/// Die fünf Beträge in der Reihenfolge 20, 10, 13, 0, 19: Zeilen je Satz,
/// Pfand zu 0, Trinkgeld zu [tipSignatureRate].
List<int> codeSums({
  required Iterable<Map<TaxRate, int>> lineGross,
  required int depositCents,
  required int tipCents,
}) => [
  for (final rate in _codeRates)
    lineGross.fold<int>(0, (sum, g) => sum + (g[rate] ?? 0)) +
        (rate == TaxRate.zero ? depositCents : 0) +
        (rate == tipSignatureRate ? tipCents : 0),
];

enum ReceiptRule {
  /// Summe der Zahlungen ohne Trinkgeld = Summe des Bons.
  paymentsEqualTotal,

  /// Summe des Bons = Warenwert nach Rabatt plus Pfand.
  totalIsGoodsPlusDeposit,

  /// Beträge der Zeilen je Satz zusammen = Warenwert.
  ratesEqualGoods,

  /// Höchstens eine Kartenzahlung, an letzter Stelle.
  oneCardLast,

  /// Trinkgeld nur bei Karte.
  tipOnlyOnCard,

  /// Stellen 0, 1, 2 … ohne Lücke.
  positions,

  /// Rabatte der Zeilen zusammen = Rabatt des Bons, und Preis mal Menge
  /// minus Rabatt der Zeilen zusammen = Warenwert.
  discountSums,
}

class ReceiptRuleViolation implements Exception {
  const ReceiptRuleViolation(this.rule);

  final ReceiptRule rule;

  @override
  String toString() =>
      'ReceiptRuleViolation: Der Bon verletzt die Regel ${rule.name}.';
}

/// Wirft bei der ersten verletzten Regel. Ein Bon ohne Zeilen und Zahlungen
/// mit Summe 0 (Sonderbeleg) besteht.
void checkReceiptRules({
  required int goodsCents,
  required int depositCents,
  required int totalCents,
  int discountCents = 0,
  required List<ReceiptLine> lines,
  required List<Payment> payments,
}) {
  void require(bool ok, ReceiptRule rule) {
    if (!ok) throw ReceiptRuleViolation(rule);
  }

  require(
    payments.fold<int>(0, (sum, p) => sum + p.amountCents) == totalCents,
    ReceiptRule.paymentsEqualTotal,
  );
  require(
    totalCents == goodsCents + depositCents,
    ReceiptRule.totalIsGoodsPlusDeposit,
  );
  require(
    lines.fold<int>(
          0,
          (sum, l) => sum + l.grossByRate.values.fold<int>(0, (a, b) => a + b),
        ) ==
        goodsCents,
    ReceiptRule.ratesEqualGoods,
  );
  final cards = [
    for (var i = 0; i < payments.length; i++)
      if (payments[i].kind == PaymentKind.card) i,
  ];
  require(
    cards.isEmpty || (cards.length == 1 && cards.single == payments.length - 1),
    ReceiptRule.oneCardLast,
  );
  require(
    payments.every((p) => p.tipCents == 0 || p.kind == PaymentKind.card),
    ReceiptRule.tipOnlyOnCard,
  );
  for (var i = 0; i < payments.length; i++) {
    require(payments[i].position == i, ReceiptRule.positions);
  }
  require(
    lines.fold<int>(0, (sum, l) => sum + l.discountCents) == discountCents &&
        lines.fold<int>(
              0,
              (sum, l) => sum + l.unitPriceCents * l.quantity - l.discountCents,
            ) ==
            goodsCents,
    ReceiptRule.discountSums,
  );
}
