import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/domain/day.dart';

BusinessDay _day(DateTime openedAt) => BusinessDay(id: 'd', openedAt: openedAt);

void main() {
  group('vergessener Abschluss', () {
    test('kein offener Tag: nicht vergessen', () {
      expect(isForgottenClose(null, DateTime(2026, 11, 18, 9)), isFalse);
    });

    test('am selben Tag nicht vergessen', () {
      final open = _day(DateTime(2026, 11, 17, 11));
      expect(isForgottenClose(open, DateTime(2026, 11, 17, 23, 59)), isFalse);
    });

    test('Dienstag 11 Uhr geöffnet: Mittwoch 0:30 und 3:59 noch nicht', () {
      final open = _day(DateTime(2026, 11, 17, 11));
      expect(isForgottenClose(open, DateTime(2026, 11, 18, 0, 30)), isFalse);
      expect(isForgottenClose(open, DateTime(2026, 11, 18, 3, 59)), isFalse);
    });

    test('Dienstag 11 Uhr geöffnet: ab Mittwoch 4:00 vergessen', () {
      final open = _day(DateTime(2026, 11, 17, 11));
      expect(isForgottenClose(open, DateTime(2026, 11, 18, 4)), isTrue);
      expect(isForgottenClose(open, DateTime(2026, 11, 18, 9)), isTrue);
      expect(isForgottenClose(open, DateTime(2026, 11, 20, 1)), isTrue);
    });

    test(
      'nach Mitternacht geöffnet (Mittwoch 1:00): erst ab Donnerstag 4:00',
      () {
        final open = _day(DateTime(2026, 11, 18, 1));
        expect(isForgottenClose(open, DateTime(2026, 11, 18, 9)), isFalse);
        expect(isForgottenClose(open, DateTime(2026, 11, 19, 3, 59)), isFalse);
        expect(isForgottenClose(open, DateTime(2026, 11, 19, 4)), isTrue);
      },
    );
  });
}
