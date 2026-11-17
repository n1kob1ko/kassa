import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/domain/cash.dart';

void main() {
  test('Vorschläge', () {
    expect(cashSuggestions(1290), [1290, 1500, 2000, 5000, 10000]);
    expect(cashSuggestions(2340), [2340, 2500, 3000, 4000, 5000, 10000]);
    expect(cashSuggestions(500), [500, 1000, 2000, 5000, 10000]);
    expect(cashSuggestions(0), [0]);
    expect(cashSuggestions(1234500), [1234500, 1235000, 1236000, 1240000]);
  });
  test('Rückgeld', () {
    expect(changeCents(givenCents: 2000, totalCents: 1290), 710);
    expect(changeCents(givenCents: 1000, totalCents: 1290), -290);
  });
}
