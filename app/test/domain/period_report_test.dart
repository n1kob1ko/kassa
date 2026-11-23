import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/domain/period_report.dart';

void main() {
  test('YearMonth: Grenzen und Nachbarn', () {
    const m = YearMonth(2026, 12);
    expect(m.start, DateTime(2026, 12));
    expect(m.end, DateTime(2027, 1));
    expect(m.lastDay, DateTime(2026, 12, 31));
    expect(m.next, const YearMonth(2027, 1));
    expect(const YearMonth(2026, 1).previous, const YearMonth(2025, 12));
    expect(const YearMonth(2024, 2).lastDay.day, 29);
    expect(m.key, '2026-12');
    expect(
      YearMonth.of(DateTime(2026, 10, 31, 23, 59)),
      const YearMonth(2026, 10),
    );
    expect(
      const YearMonth(2026, 3).compareTo(const YearMonth(2025, 12)),
      greaterThan(0),
    );
    expect(
      const YearMonth(2026, 3).hashCode,
      const YearMonth(2026, 3).hashCode,
    );
  });

  test('MonthRange: Monate und Titel', () {
    const r = MonthRange(YearMonth(2025, 11), YearMonth(2026, 2));
    expect(r.months.map((m) => m.key), [
      '2025-11',
      '2025-12',
      '2026-01',
      '2026-02',
    ]);
    expect(r.single, isFalse);
    expect(r.key, '2025-11..2026-02');
    expect(periodTitle(r), 'November 2025 bis Februar 2026');
    expect(
      periodTitle(const MonthRange(YearMonth(2026, 1), YearMonth(2026, 10))),
      'Jänner bis Oktober 2026',
    );
    const okt = MonthRange(YearMonth(2026, 10), YearMonth(2026, 10));
    expect(periodTitle(okt), 'Oktober 2026');
    expect(okt.single, isTrue);
    expect(okt.months, [const YearMonth(2026, 10)]);
  });

  test('MonthChoice: allows', () {
    final c = MonthChoice(
      first: const YearMonth(2026, 9),
      last: const YearMonth(2026, 10),
      nextAvailable: DateTime(2026, 12),
    );
    expect(c.allows(const YearMonth(2026, 8)), isFalse);
    expect(c.allows(const YearMonth(2026, 9)), isTrue);
    expect(c.allows(const YearMonth(2026, 10)), isTrue);
    expect(c.allows(const YearMonth(2026, 11)), isFalse);
    expect(
      MonthChoice(nextAvailable: DateTime(2026, 12))
          .allows(const YearMonth(2026, 9)),
      isFalse,
    );
  });
}
