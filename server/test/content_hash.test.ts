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

test('eine Zeit zählt: Date mit anderem Zeitpunkt ergibt eine andere Prüfsumme', () => {
  const a = contentHash({ at: new Date('2026-11-19T10:00:00.000Z') });
  expect(a.equals(contentHash({ at: new Date('2026-11-19T10:00:01.000Z') }))).toBe(false);
  expect(a.equals(contentHash({ at: new Date('2026-11-19T10:00:00Z') }))).toBe(true);
  expect(a.equals(contentHash({ at: '2026-11-19T10:00:00.000Z' }))).toBe(true);
});

test('was sich nicht darstellen lässt, wirft', () => {
  expect(() => contentHash(undefined)).toThrow();
  expect(() => contentHash({ f: () => 1 })).toThrow();
  expect(() => contentHash({ n: Number.NaN })).toThrow();
  expect(() => contentHash({ n: Number.POSITIVE_INFINITY })).toThrow();
  expect(() => contentHash({ n: 10n })).toThrow();
  expect(() => contentHash([undefined])).toThrow();
  expect(() => contentHash({ d: new Date('x') })).toThrow();
});
