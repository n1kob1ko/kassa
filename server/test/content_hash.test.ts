import { expect, test } from 'vitest';
import { contentHash } from '../src/device/content_hash.js';

test('gleiche Objekte mit anderer Schlüsselfolge ergeben dieselbe Prüfsumme', () => {
  const a = { id: 'x', gross: { '20': 0, '10': 990 }, lines: [{ b: 1, a: 2 }] };
  const b = { lines: [{ a: 2, b: 1 }], gross: { '10': 990, '20': 0 }, id: 'x' };
  expect(contentHash(a).equals(contentHash(b))).toBe(true);
  expect(contentHash(a)).toHaveLength(32);
});

test('ein geänderter Betrag ergibt eine andere Prüfsumme', () => {
  expect(contentHash({ totalCents: 990 }).equals(contentHash({ totalCents: 991 }))).toBe(false);
});

test('verschachtelte Listen behalten ihre Reihenfolge', () => {
  expect(contentHash({ l: [{ p: 1 }, { p: 2 }] }).equals(contentHash({ l: [{ p: 2 }, { p: 1 }] }))).toBe(false);
});
