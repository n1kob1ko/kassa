import { expect, test } from 'vitest';
import { labelStep, niceTop } from './BarChart';

test('niceTop: die kleinste runde obere Linie, die den größten Wert fasst', () => {
  expect(niceTop(0)).toBe(100);
  expect(niceTop(50)).toBe(100);
  expect(niceTop(10_160)).toBe(12_000);
  expect(niceTop(24_245)).toBe(25_000);
  expect(niceTop(3215)).toBe(4000);
  expect(niceTop(100_000)).toBe(100_000);
  expect(niceTop(100_001)).toBe(120_000);
});

test('labelStep: 30 Tage bei 360 px zeigen jede siebte Beschriftung, breit alle', () => {
  expect(labelStep(30, 6, 260)).toBe(7);
  expect(labelStep(7, 6, 260)).toBe(2);
  expect(labelStep(7, 6, 520)).toBe(1);
  expect(labelStep(1, 6, 0)).toBe(1);
});
