import { describe, expect, test } from 'vitest';
import { imageProblem, MAX_IMAGE_BYTES, parsePrice, priceText } from './validate';

describe('parsePrice', () => {
  test('Komma, Punkt, ganze Euro und eine Nachkommastelle werden Cent', () => {
    expect(parsePrice('9,90')).toBe(990);
    expect(parsePrice('9.90')).toBe(990);
    expect(parsePrice('9')).toBe(900);
    expect(parsePrice('9,9')).toBe(990);
    expect(parsePrice('0,05')).toBe(5);
    expect(parsePrice('0')).toBe(0);
  });

  test('Leerzeichen und ein Eurozeichen am Ende stören nicht', () => {
    expect(parsePrice(' 12,50 ')).toBe(1250);
    expect(parsePrice('12,50 €')).toBe(1250);
    expect(parsePrice('12,50 €')).toBe(1250);
  });

  test('negativ, drei Nachkommastellen, Buchstaben und leer ergeben null', () => {
    expect(parsePrice('-1')).toBeNull();
    expect(parsePrice('-9,90')).toBeNull();
    expect(parsePrice('9,999')).toBeNull();
    expect(parsePrice('abc')).toBeNull();
    expect(parsePrice('9,9a')).toBeNull();
    expect(parsePrice('zehn')).toBeNull();
    expect(parsePrice('')).toBeNull();
    expect(parsePrice('   ')).toBeNull();
    expect(parsePrice(',')).toBeNull();
    expect(parsePrice('9,')).toBeNull();
    expect(parsePrice('1.234,50')).toBeNull();
  });

  test('Obergrenze 99.999,99 €', () => {
    expect(parsePrice('99999,99')).toBe(9_999_999);
    expect(parsePrice('100000')).toBeNull();
    expect(parsePrice('99999,999')).toBeNull();
  });
});

describe('priceText', () => {
  test('Cent als Text im Preisfeld, ohne Eurozeichen und ohne Tausenderpunkt', () => {
    expect(priceText(990)).toBe('9,90');
    expect(priceText(5)).toBe('0,05');
    expect(priceText(0)).toBe('0,00');
    expect(priceText(9_999_999)).toBe('99999,99');
  });

  test('jeder Text von priceText liest parsePrice wieder gleich', () => {
    for (const cents of [0, 1, 99, 100, 990, 123_456, 9_999_999]) expect(parsePrice(priceText(cents))).toBe(cents);
  });
});

describe('imageProblem', () => {
  const file = (type: string, size = 1000) => ({ type, size });

  test('JPEG, PNG und WebP bis 10 MB sind in Ordnung', () => {
    expect(imageProblem(file('image/jpeg'))).toBeNull();
    expect(imageProblem(file('image/png'))).toBeNull();
    expect(imageProblem(file('image/webp', MAX_IMAGE_BYTES))).toBeNull();
  });

  test('andere Arten: ein Satz', () => {
    expect(imageProblem(file('image/gif'))).toBe('Das ist kein Bild. Erlaubt sind JPEG, PNG und WebP.');
    expect(imageProblem(file('text/plain'))).toBe('Das ist kein Bild. Erlaubt sind JPEG, PNG und WebP.');
    expect(imageProblem(file(''))).toBe('Das ist kein Bild. Erlaubt sind JPEG, PNG und WebP.');
  });

  test('größer als 10 MB: ein Satz', () => {
    expect(imageProblem(file('image/jpeg', MAX_IMAGE_BYTES + 1))).toBe('Das Bild ist größer als 10 MB.');
  });
});
