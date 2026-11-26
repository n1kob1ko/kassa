// Trinkgeld bei Kartenzahlung: was der Gast zahlen könnte und wann die Kassa
// nachfragt. Reines Dart.

/// Was der Gast zahlen könnte, über [dueCents]: nächster voller Euro, nächste
/// Fünfer-Stufe, nächste Zehner-Stufe, jeweils echt größer, aufsteigend, ohne
/// Doppelte, höchstens drei.
List<int> tipSuggestions(int dueCents) {
  final out = <int>[];
  for (final step in const [100, 500, 1000]) {
    final next = (dueCents ~/ step + 1) * step;
    if (!out.contains(next)) out.add(next);
  }
  return out;
}

/// Wahr, wenn das Trinkgeld höher ist als 30 % der Summe des Bons und höher
/// als 5,00 €.
bool tipNeedsConfirm({required int totalCents, required int tipCents}) =>
    tipCents > 500 && tipCents * 100 > totalCents * 30;
