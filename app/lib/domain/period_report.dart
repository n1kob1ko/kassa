// Monate, Zeiträume und der Bericht über einen Zeitraum. Reines Dart.

import '../core/german_dates.dart';
import 'pricing.dart';

/// Ein Kalendermonat. [month] ist 1 bis 12.
class YearMonth implements Comparable<YearMonth> {
  const YearMonth(this.year, this.month);

  factory YearMonth.of(DateTime t) => YearMonth(t.year, t.month);

  final int year;
  final int month;

  DateTime get start => DateTime(year, month);

  /// Erster des Folgemonats, ausschließlich.
  DateTime get end => DateTime(year, month + 1);

  DateTime get lastDay => DateTime(year, month + 1, 0);

  YearMonth get next => YearMonth.of(end);

  YearMonth get previous => YearMonth.of(DateTime(year, month - 1));

  /// Zum Beispiel `2026-10`.
  String get key => '$year-${month.toString().padLeft(2, '0')}';

  @override
  int compareTo(YearMonth other) => year != other.year
      ? year.compareTo(other.year)
      : month.compareTo(other.month);

  @override
  bool operator ==(Object other) =>
      other is YearMonth && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);

  @override
  String toString() => 'YearMonth($key)';
}

/// Von Monat bis Monat, beide eingeschlossen. [from] liegt nicht nach [to].
class MonthRange {
  const MonthRange(this.from, this.to);

  final YearMonth from;
  final YearMonth to;

  bool get single => from == to;

  /// Aufsteigend, mit beiden Enden.
  List<YearMonth> get months {
    final result = <YearMonth>[];
    for (var m = from; m.compareTo(to) <= 0; m = m.next) {
      result.add(m);
    }
    return result;
  }

  /// Zum Beispiel `2026-10..2026-10`.
  String get key => '${from.key}..${to.key}';

  @override
  bool operator ==(Object other) =>
      other is MonthRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);

  @override
  String toString() => 'MonthRange($key)';
}

/// "Oktober 2026", "Jänner bis Oktober 2026", "November 2025 bis Februar 2026".
String periodTitle(MonthRange r) {
  final from = germanMonths[r.from.month - 1];
  final to = germanMonths[r.to.month - 1];
  if (r.single) return '$from ${r.from.year}';
  if (r.from.year == r.to.year) return '$from bis $to ${r.to.year}';
  return '$from ${r.from.year} bis $to ${r.to.year}';
}

/// Eine Zeile der Aufstellung: ein Kalendertag oder ein Monat ([start]).
class PeriodRow {
  const PeriodRow({
    required this.start,
    required this.receiptCount,
    required this.revenueCents,
  });

  final DateTime start;
  final int receiptCount;
  final int revenueCents;
}

class PeriodReport {
  const PeriodReport({
    required this.range,
    required this.testMode,
    required this.receiptCount,
    required this.cashReceiptCount,
    required this.cardReceiptCount,
    required this.voidCount,
    required this.voidedCents,
    required this.revenueCents,
    required this.cashRevenueCents,
    required this.cardRevenueCents,
    required this.depositCents,
    required this.taxLines,
    required this.firstNumber,
    required this.lastNumber,
    required this.rows,
  });

  final MonthRange range;

  /// Wahr, solange es noch keinen echt signierten Bon gibt: dann zählen alle.
  final bool testMode;

  /// Verkaufs-Bons minus Storno-Bons, auch je Zahlungsart: dort zählt ein
  /// Bon mit mindestens einer Zahlung dieser Art, ein gemischter bei beiden.
  final int receiptCount;
  final int cashReceiptCount;
  final int cardReceiptCount;

  /// Anzahl der Storno-Bons und Summe der stornierten Bons (positiv).
  final int voidCount;
  final int voidedCents;

  /// Summe aller gezählten Bons, Storno negativ, mit Pfand, ohne Trinkgeld.
  final int revenueCents;

  /// Summe der Zahlungen bar bzw. mit Karte, ohne Trinkgeld, Storno negativ.
  final int cashRevenueCents;
  final int cardRevenueCents;
  final int depositCents;

  /// Je Monat gerechnet und über den Zeitraum summiert, nach Satz absteigend.
  final List<TaxLine> taxLines;

  /// Kleinste und größte Nummer der gezählten Bons, `null` ohne Bon.
  final int? firstNumber;
  final int? lastNumber;

  /// Ein Monat: je Kalendertag mit Bon. Mehrere: je Monat, auch leere.
  final List<PeriodRow> rows;

  bool get isEmpty => firstNumber == null;
}

/// Welche Monate abgerechnet werden können: von dem des ältesten Bons bis
/// zum Monat vor dem laufenden. Beide `null`, solange es keinen gibt.
class MonthChoice {
  const MonthChoice({this.first, this.last, required this.nextAvailable});

  final YearMonth? first;
  final YearMonth? last;

  /// Der Erste des Folgemonats von jetzt.
  final DateTime nextAvailable;

  bool allows(YearMonth m) {
    final a = first;
    final b = last;
    if (a == null || b == null) return false;
    return m.compareTo(a) >= 0 && m.compareTo(b) <= 0;
  }
}
