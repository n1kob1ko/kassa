// Die Wahl auf der Monatsauswahl: ein Monat oder von bis. Reines Dart.

import 'period_report.dart';

class PeriodSelection {
  const PeriodSelection({this.rangeMode = false, this.from, this.to});

  final bool rangeMode;
  final YearMonth? from;
  final YearMonth? to;

  PeriodSelection tap(YearMonth m) {
    if (!rangeMode) return PeriodSelection(from: m, to: m);
    final start = from;
    if (start == null || to != null || m.compareTo(start) < 0) {
      return PeriodSelection(rangeMode: true, from: m);
    }
    return PeriodSelection(rangeMode: true, from: start, to: m);
  }

  /// Behält den Beginn: bei von bis fehlt dann das Ende, bei einem Monat ist
  /// das Ende der Beginn.
  PeriodSelection withMode({required bool rangeMode}) => PeriodSelection(
    rangeMode: rangeMode,
    from: from,
    to: rangeMode ? null : from,
  );

  /// Nur der Beginn gewählt: dieser eine Monat.
  MonthRange? get range {
    final start = from;
    if (start == null) return null;
    return MonthRange(start, to ?? start);
  }

  bool marks(YearMonth m) {
    final r = range;
    return r != null && m.compareTo(r.from) >= 0 && m.compareTo(r.to) <= 0;
  }
}
