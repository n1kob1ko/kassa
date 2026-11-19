import { expect, test } from 'vitest';
import {
  ago,
  codeGroups,
  comparison,
  count,
  countdown,
  dateInputValue,
  dateText,
  dayHeading,
  dayKey,
  megabytes,
  money,
  share,
  signedMoney,
  timeText,
} from './format';

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

const NBSP = ' ';

test('money: deutsch mit Tausenderpunkt, Komma, zwei Stellen und geschütztem Leerzeichen vor dem Euro', () => {
  expect(money(0)).toBe(`0,00${NBSP}€`);
  expect(money(5)).toBe(`0,05${NBSP}€`);
  expect(money(1290)).toBe(`12,90${NBSP}€`);
  expect(money(123456789)).toBe(`1.234.567,89${NBSP}€`);
  expect(money(100000)).toBe(`1.000,00${NBSP}€`);
});

test('money: negativ mit echtem Minuszeichen davor', () => {
  expect(money(-1290)).toBe(`−12,90${NBSP}€`);
  expect(money(-123456789)).toBe(`−1.234.567,89${NBSP}€`);
  expect(money(-0)).toBe(`0,00${NBSP}€`);
});

// 2026-11-19 ist ein Donnerstag, auch in Wien kurz vor Mitternacht UTC.
const THURSDAY = new Date('2026-11-19T22:30:00.000Z');
const WEDNESDAY_LATE_UTC = new Date('2026-11-18T23:30:00.000Z');

test('comparison: mehr und weniger, ganze Prozent halb auf', () => {
  expect(comparison('days7', 1120, 1000, THURSDAY)).toBe('12 % mehr als in den 7 Tagen davor');
  expect(comparison('days30', 880, 1000, THURSDAY)).toBe('12 % weniger als in den 30 Tagen davor');
  expect(comparison('days7', 1125, 1000, THURSDAY)).toBe('13 % mehr als in den 7 Tagen davor');
  expect(comparison('days7', 1124, 1000, THURSDAY)).toBe('12 % mehr als in den 7 Tagen davor');
  expect(comparison('days7', 0, 965, THURSDAY)).toBe('100 % weniger als in den 7 Tagen davor');
  expect(comparison('days7', 3415, 965, THURSDAY)).toBe('254 % mehr als in den 7 Tagen davor');
});

test('comparison: heute vergleicht mit demselben Wochentag der Vorwoche, in Wiener Zeit', () => {
  expect(comparison('today', 1120, 1000, THURSDAY)).toBe('12 % mehr als letzten Donnerstag');
  // 23:30 UTC ist in Wien schon Donnerstag.
  expect(comparison('today', 880, 1000, WEDNESDAY_LATE_UTC)).toBe('12 % weniger als letzten Donnerstag');
  expect(comparison('today', 1000, 1000, new Date('2026-11-16T10:00:00.000Z'))).toBe('Gleich viel wie letzten Montag');
});

test('comparison: gleich viel, auch wenn es auf 0 % rundet, nie "0 % mehr"', () => {
  expect(comparison('days7', 1000, 1000, THURSDAY)).toBe('Gleich viel wie in den 7 Tagen davor');
  expect(comparison('days30', 100_004, 100_000, THURSDAY)).toBe('Gleich viel wie in den 30 Tagen davor');
  expect(comparison('days30', 99_996, 100_000, THURSDAY)).toBe('Gleich viel wie in den 30 Tagen davor');
});

test('comparison: nichts, wenn der Zeitraum davor 0 ist', () => {
  expect(comparison('days7', 1000, 0, THURSDAY)).toBeNull();
  expect(comparison('today', 0, 0, THURSDAY)).toBeNull();
});

test('share: ganze Prozent halb auf, 0 ohne Summe', () => {
  expect(share(2250, 3215)).toBe(70);
  expect(share(965, 3215)).toBe(30);
  expect(share(1, 3)).toBe(33);
  expect(share(0, 0)).toBe(0);
});

test('timeText: Stunde und Minute in Wiener Zeit, auch über die Zeitumstellung', () => {
  expect(timeText(new Date('2026-11-19T08:05:00.000Z'))).toBe('09:05');
  expect(timeText(new Date('2026-11-18T23:30:00.000Z'))).toBe('00:30');
  expect(timeText(new Date('2026-07-01T10:00:00.000Z'))).toBe('12:00');
});

test('dayKey: Kalendertag in Wiener Zeit', () => {
  expect(dayKey(new Date('2026-11-18T22:59:00.000Z'))).toBe('2026-11-18');
  expect(dayKey(new Date('2026-11-18T23:00:00.000Z'))).toBe('2026-11-19');
});

test('dayHeading: Heute, Gestern, sonst Wochentag und Datum, ein anderes Jahr mit Jahr', () => {
  const now = new Date('2026-11-19T10:00:00.000Z');
  expect(dayHeading(new Date('2026-11-19T06:00:00.000Z'), now)).toBe('Heute');
  // Kurz nach Mitternacht in Wien ist es in UTC noch der Vortag.
  expect(dayHeading(new Date('2026-11-18T23:10:00.000Z'), now)).toBe('Heute');
  expect(dayHeading(new Date('2026-11-18T12:00:00.000Z'), now)).toBe('Gestern');
  expect(dayHeading(new Date('2026-11-17T12:00:00.000Z'), now)).toBe('Di., 17.11.');
  expect(dayHeading(new Date('2026-11-05T12:00:00.000Z'), now)).toBe('Do., 05.11.');
  expect(dayHeading(new Date('2025-12-31T12:00:00.000Z'), now)).toBe('Mi., 31.12.2025');
  // Gestern über den Monatswechsel.
  expect(dayHeading(new Date('2026-11-30T12:00:00.000Z'), new Date('2026-12-01T09:00:00.000Z'))).toBe('Gestern');
});

test('signedMoney: Vorzeichen immer, echtes Minus, 0 ohne Vorzeichen', () => {
  expect(signedMoney(200)).toBe('+2,00\u00a0€');
  expect(signedMoney(-150)).toBe('\u22121,50\u00a0€');
  expect(signedMoney(0)).toBe('0,00\u00a0€');
});

test('dateInputValue: das Datum des Browsers für ein Datumsfeld', () => {
  expect(dateInputValue(new Date(2026, 10, 9, 23, 59))).toBe('2026-11-09');
  expect(dateInputValue(new Date(2026, 0, 1, 0, 0))).toBe('2026-01-01');
});
