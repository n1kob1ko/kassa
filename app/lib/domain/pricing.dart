// Steueraufteilung eines Bons. Pfand trägt keine Steuer.

import 'cart.dart';
import 'catalog.dart';

class TaxLine {
  const TaxLine({
    required this.rate,
    required this.grossCents,
    required this.netCents,
    required this.taxCents,
  });

  final TaxRate rate;
  final int grossCents;
  final int netCents;
  final int taxCents;
}

/// Brutto-Warenwert je Steuersatz, ohne Pfand.
Map<TaxRate, int> grossByRate(Cart cart) {
  final result = <TaxRate, int>{};
  void put(TaxRate rate, int cents) {
    if (cents == 0) return;
    result[rate] = (result[rate] ?? 0) + cents;
  }

  for (final l in cart.lines) {
    put(l.item.taxRate, l.item.priceCents * l.quantity);
    for (final o in l.options) {
      put(o.taxRate ?? l.item.taxRate, o.surchargeCents * l.quantity);
    }
  }
  return result;
}

/// Nach Satz absteigend; Sätze ohne Betrag fehlen. Die Steuer wird
/// kaufmännisch gerundet, nur mit ganzen Zahlen.
List<TaxLine> taxBreakdown(Map<TaxRate, int> gross) {
  final rates = [
    for (final e in gross.entries)
      if (e.value != 0) e.key,
  ]..sort((a, b) => b.percent.compareTo(a.percent));
  return [
    for (final r in rates)
      () {
        final g = gross[r]!;
        final p = r.percent;
        final tax = (g * p * 2 + (100 + p)) ~/ (2 * (100 + p));
        return TaxLine(rate: r, grossCents: g, netCents: g - tax, taxCents: tax);
      }(),
  ];
}
