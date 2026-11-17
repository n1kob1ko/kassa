// Bargeld-Vorschläge und Rückgeld. Alle Beträge in ganzen Cent.

/// Denominations used to suggest round cash amounts, in cents.
const _steps = [500, 1000, 2000, 5000, 10000];

/// Suggested cash amounts for a total: the exact total first, then the next
/// multiple of each step above the total, ascending and without duplicates.
/// A total of 0 yields just `[0]`.
List<int> cashSuggestions(int totalCents) {
  if (totalCents == 0) return [0];
  final rounded = <int>{};
  for (final step in _steps) {
    rounded.add((totalCents ~/ step + 1) * step);
  }
  final ascending = rounded.toList()..sort();
  return [totalCents, ...ascending];
}

/// Change due for [givenCents] paid against [totalCents].
/// A negative result means the amount given is still short by that much.
int changeCents({required int givenCents, required int totalCents}) =>
    givenCents - totalCents;
