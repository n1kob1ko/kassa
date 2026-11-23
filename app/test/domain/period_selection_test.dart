import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/domain/period_report.dart';
import 'package:kassa/domain/period_selection.dart';

void main() {
  const okt = YearMonth(2026, 10),
      jan = YearMonth(2026, 1),
      mrz = YearMonth(2026, 3);

  test('Von bis: Beginn, Ende, Tipp davor, dritter Tipp', () {
    var s = const PeriodSelection(rangeMode: true).tap(mrz);
    expect(s.range, const MonthRange(mrz, mrz));
    s = s.tap(jan); // vor dem Beginn: neuer Beginn
    expect((s.from, s.to), (jan, null));
    s = s.tap(okt);
    expect(s.range, const MonthRange(jan, okt));
    expect(s.marks(mrz), isTrue);
    expect(s.marks(const YearMonth(2026, 11)), isFalse);
    s = s.tap(mrz); // dritter Tipp beginnt von vorn
    expect((s.from, s.to), (mrz, null));
  });

  test('Von bis: derselbe Monat ist Beginn und Ende', () {
    final s = const PeriodSelection(rangeMode: true).tap(mrz).tap(mrz);
    expect((s.from, s.to), (mrz, mrz));
  });

  test('Ein Monat: jeder Tipp wählt genau diesen Monat', () {
    var s = const PeriodSelection().tap(jan);
    expect((s.from, s.to), (jan, jan));
    s = s.tap(okt);
    expect(s.range, const MonthRange(okt, okt));
    expect(s.marks(okt), isTrue);
    expect(s.marks(jan), isFalse);
  });

  test('Ohne Wahl: kein Bereich', () {
    expect(const PeriodSelection().range, isNull);
    expect(const PeriodSelection().marks(jan), isFalse);
  });

  test('Wechsel der Betriebsart behält den Beginn', () {
    var s = const PeriodSelection().tap(mrz).withMode(rangeMode: true);
    expect((s.rangeMode, s.from, s.to), (true, mrz, null));
    s = s.tap(okt).withMode(rangeMode: false);
    expect((s.rangeMode, s.from, s.to), (false, mrz, mrz));
  });
}
