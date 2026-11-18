import { expect, test } from 'vitest';
import { ago, codeGroups, count, countdown, dateText, megabytes } from './format';

const NOW = new Date('2026-11-18T12:00:00.000Z');
const before = (ms: number) => new Date(NOW.getTime() - ms);
const MIN = 60_000;
const HOUR = 60 * MIN;
const DAY = 24 * HOUR;

test('ago: gerade eben, Minuten, Stunden, Tage', () => {
  expect(ago(before(0), NOW)).toBe('gerade eben');
  expect(ago(before(59_000), NOW)).toBe('gerade eben');
  expect(ago(before(MIN), NOW)).toBe('vor 1 Minute');
  expect(ago(before(5 * MIN), NOW)).toBe('vor 5 Minuten');
  expect(ago(before(59 * MIN), NOW)).toBe('vor 59 Minuten');
  expect(ago(before(HOUR), NOW)).toBe('vor 1 Stunde');
  expect(ago(before(2 * HOUR + 30 * MIN), NOW)).toBe('vor 2 Stunden');
  expect(ago(before(DAY), NOW)).toBe('vor 1 Tag');
  expect(ago(before(3 * DAY), NOW)).toBe('vor 3 Tagen');
});

test('ago: eine Zeit in der Zukunft (Uhren weichen ab) ist "gerade eben"', () => {
  expect(ago(new Date(NOW.getTime() + 5 * MIN), NOW)).toBe('gerade eben');
});

test('megabytes mit deutschem Komma', () => {
  expect(megabytes(25_300_000)).toBe('24,1 MB');
  expect(megabytes(1024 * 1024)).toBe('1,0 MB');
  expect(megabytes(0)).toBe('0,0 MB');
});

test('codeGroups teilt in 4 und 4', () => {
  expect(codeGroups('48201937')).toBe('4820 1937');
  expect(codeGroups('00000042')).toBe('0000 0042');
});

test('countdown als Minuten und Sekunden, nie negativ', () => {
  expect(countdown(872_000)).toBe('14:32');
  expect(countdown(900_000)).toBe('15:00');
  expect(countdown(59_001)).toBe('1:00');
  expect(countdown(5_000)).toBe('0:05');
  expect(countdown(-3000)).toBe('0:00');
});

test('dateText als Tag.Monat.Jahr in Wiener Zeit', () => {
  expect(dateText(new Date('2026-11-18T23:30:00.000Z'))).toBe('19.11.2026');
});

test('count: Einzahl und Mehrzahl', () => {
  expect(count(1, 'Kassa', 'Kassen')).toBe('1 Kassa');
  expect(count(0, 'Kassa', 'Kassen')).toBe('0 Kassen');
  expect(count(3, 'Artikel')).toBe('3 Artikel');
});
