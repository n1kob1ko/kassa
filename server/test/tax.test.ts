import { expect, test } from 'vitest';
import { taxLinesOf, taxOf } from '../src/admin/tax.js';

test.each([
  [580, 20, 97],
  [1190, 10, 108],
  [-580, 20, -97],
  [1160, 20, 193],
  [0, 20, 0],
  [100, 13, 12],
  [119, 19, 19],
])('taxOf(%i, %i) = %i', (gross, percent, tax) => {
  expect(taxOf(gross, percent)).toBe(tax);
});

test('taxOf gibt nie minus null zurück', () => {
  expect(Object.is(taxOf(0, 20), 0)).toBe(true);
  expect(Object.is(taxOf(-0, 20), 0)).toBe(true);
});

test('taxLinesOf: nach Satz absteigend, Sätze ohne Betrag fehlen', () => {
  expect(taxLinesOf({ 10: 1190, 20: 580, 13: 0, 0: 50 })).toEqual([
    { percent: 20, grossCents: 580, netCents: 483, taxCents: 97 },
    { percent: 10, grossCents: 1190, netCents: 1082, taxCents: 108 },
    { percent: 0, grossCents: 50, netCents: 50, taxCents: 0 },
  ]);
});
