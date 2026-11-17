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

/// Brutto-Warenwert einer Zeile je Steuersatz, ohne Pfand. Eine Option mit
/// eigenem Steuersatz zählt zu diesem Satz.
Map<TaxRate, int> grossByRateOfLine(CartLine line) {
  final result = <TaxRate, int>{};
  void put(TaxRate rate, int cents) {
    if (cents == 0) return;
    result[rate] = (result[rate] ?? 0) + cents;
  }

  put(line.item.taxRate, line.item.priceCents * line.quantity);
  for (final o in line.options) {
    put(o.taxRate ?? line.item.taxRate, o.surchargeCents * line.quantity);
  }
  return result;
}

/// Brutto-Warenwert je Steuersatz, ohne Pfand.
Map<TaxRate, int> grossByRate(Cart cart) =>
    sumByRate([for (final l in cart.lines) grossByRateOfLine(l)]);

/// Summe mehrerer Aufteilungen; Sätze mit Summe 0 fehlen.
Map<TaxRate, int> sumByRate(Iterable<Map<TaxRate, int>> parts) {
  final result = <TaxRate, int>{};
  for (final part in parts) {
    for (final e in part.entries) {
      result[e.key] = (result[e.key] ?? 0) + e.value;
    }
  }
  result.removeWhere((_, cents) => cents == 0);
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
        // Auf dem Betrag gerundet, dann das Vorzeichen zurück: Storno ist
        // das exakte Spiegelbild des Bons.
        final a = g.abs();
        final absTax = (a * p * 2 + (100 + p)) ~/ (2 * (100 + p));
        final tax = g < 0 ? -absTax : absTax;
        return TaxLine(rate: r, grossCents: g, netCents: g - tax, taxCents: tax);
      }(),
  ];
}
