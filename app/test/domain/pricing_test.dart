import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/domain/cart.dart';
import 'package:kassa/domain/catalog.dart';
import 'package:kassa/domain/pricing.dart';

import '../support/demo_fixtures.dart';

void main() {
  test('Steuer pro Satz, Pfand ohne Steuer', () {
    final cart = const Cart.empty().add(cola).add(cola).add(teigtaschen);
    expect(grossByRate(cart), {TaxRate.normal: 580, TaxRate.reduced1: 650});
    final lines = taxBreakdown(grossByRate(cart));
    expect(
      lines.map((t) => (t.rate.percent, t.grossCents, t.netCents, t.taxCents)),
      [(20, 580, 483, 97), (10, 650, 591, 59)],
    );
  });

  test('Option mit eigenem Steuersatz zählt zu ihrem Satz', () {
    const drink = ModifierOption(
      id: 'm/0/0',
      name: 'Getränk',
      surchargeCents: 200,
      isDefault: false,
      taxRate: TaxRate.normal,
    );
    expect(grossByRate(const Cart.empty().add(teigtaschen, options: [drink])), {
      TaxRate.reduced1: 650,
      TaxRate.normal: 200,
    });
  });

  test('Aufpreis und Menge zählen vervielfacht, Sätze ohne Betrag fehlen', () {
    final cart = const Cart.empty()
        .add(huhnBowl, options: [xxl])
        .add(huhnBowl, options: [xxl])
        .add(leitungswasser);
    expect(grossByRate(cart), {TaxRate.reduced1: 2 * (990 + 200)});
  });

  test('Rundung ohne double, Sätze absteigend', () {
    final lines = taxBreakdown({
      TaxRate.reduced1: 5,
      TaxRate.normal: 3,
      TaxRate.zero: 0,
    });
    expect(lines.map((t) => (t.rate.percent, t.netCents, t.taxCents)), [
      (20, 2, 1),
      (10, 5, 0),
    ]);
  });

  test('Steuer ist für negative Beträge das Spiegelbild der positiven', () {
    for (final gross in [
      {TaxRate.normal: 580, TaxRate.reduced1: 1190},
      {TaxRate.normal: 3, TaxRate.reduced1: 5},
    ]) {
      final plus = taxBreakdown(gross);
      final minus = taxBreakdown({
        for (final e in gross.entries) e.key: -e.value,
      });
      expect(
        minus.map((t) => (t.rate, t.grossCents, t.netCents, t.taxCents)),
        plus.map((t) => (t.rate, -t.grossCents, -t.netCents, -t.taxCents)),
      );
    }
  });
}
