import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/core/money.dart';

KeypadInput type(String keys, {int max = 4}) => keys
    .split(' ')
    .fold(KeypadInput(maxIntDigits: max), (k, key) => k.tap(key));

void main() {
  test('formatEuro', () {
    expect(formatEuro(0), '0,00 €');
    expect(formatEuro(990), '9,90 €');
    expect(formatEuro(128460), '1.284,60 €');
    expect(formatEuro(4064290), '40.642,90 €');
    expect(formatEuro(-25), '−0,25 €'); // U+2212
  });

  test('Zahlenfeld', () {
    expect(type('1 2 , 5').text, '12,5');
    expect(type('1 2 , 5').cents, 1250);
    expect(type(',').text, '0,');
    expect(type('0 5').text, '5');
    expect(
      type('1 , 2 3 4').text,
      '1,23',
    ); // höchstens zwei Stellen nach dem Komma
    expect(type('1 , , 2').text, '1,2'); // nur ein Komma
    expect(type('1 2 3 4 5').text, '1234'); // vier Stellen vor dem Komma
    expect(type('1 2 3 4 5 6 7', max: 6).cents, 12345600);
    expect(type('1 2 back').text, '1');
    expect(type('back').text, '');
    expect(const KeypadInput().cents, 0);
  });

  test('Zahlenfeld ist unveränderlich und behält maxIntDigits', () {
    const start = KeypadInput(maxIntDigits: 2);
    final next = start.tap('7');
    expect(start.text, '');
    expect(next.text, '7');
    expect(next.maxIntDigits, 2);
    expect(next.tap('8').tap('9').text, '78');
    expect(start.isEmpty, isTrue);
    expect(next.isEmpty, isFalse);
  });
}
