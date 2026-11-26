import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/domain/tip.dart';

void main() {
  test('Vorschläge: voller Euro, Fünfer, Zehner, ohne Doppelte', () {
    expect(tipSuggestions(4680), [4700, 5000]);
    expect(tipSuggestions(4210), [4300, 4500, 5000]);
    expect(tipSuggestions(4700), [4800, 5000]);
    expect(tipSuggestions(965), [1000]);
  });

  test('Nachfrage nur über 30 % der Summe und über 5,00 €', () {
    expect(tipNeedsConfirm(totalCents: 4680, tipCents: 45320), isTrue);
    expect(tipNeedsConfirm(totalCents: 4680, tipCents: 320), isFalse);
    // 50 %, aber nicht über 5,00 €
    expect(tipNeedsConfirm(totalCents: 1000, tipCents: 500), isFalse);
    expect(tipNeedsConfirm(totalCents: 1000, tipCents: 501), isTrue);
    // genau 30 %
    expect(tipNeedsConfirm(totalCents: 4000, tipCents: 1200), isFalse);
  });
}
