import { expect, test } from 'vitest';
import { dayLabel, dayMonthText, monthLabel, parsePeriodId, periodDates, periodId, periodTitle } from './period';

test('parsePeriodId', () => {
  expect(parsePeriodId('2026-10')).toEqual({ from: '2026-10', to: '2026-10' });
  expect(parsePeriodId('2026-01..2026-10')).toEqual({ from: '2026-01', to: '2026-10' });
  for (const bad of ['2026-13', 'abc', '2026-1', '2026-10..2026-01', '2026-10..', '']) expect(parsePeriodId(bad)).toBeNull();
});

test('periodId: ein Monat ohne Bereich, mehrere mit', () => {
  expect(periodId({ from: '2026-10', to: '2026-10' })).toBe('2026-10');
  expect(periodId({ from: '2025-11', to: '2026-02' })).toBe('2025-11..2026-02');
  expect(parsePeriodId(periodId({ from: '2025-11', to: '2026-02' }))).toEqual({ from: '2025-11', to: '2026-02' });
});

test('Titel und Daten', () => {
  expect(periodTitle({ from: '2026-01', to: '2026-10' })).toBe('Jänner bis Oktober 2026');
  expect(periodTitle({ from: '2025-11', to: '2026-02' })).toBe('November 2025 bis Februar 2026');
  expect(periodTitle({ from: '2026-10', to: '2026-10' })).toBe('Oktober 2026');
  expect(periodDates({ from: '2024-02', to: '2024-02' })).toBe('01.02.2024 bis 29.02.2024');
  expect(periodDates({ from: '2025-11', to: '2026-02' })).toBe('01.11.2025 bis 28.02.2026');
  expect(periodDates({ from: '2026-12', to: '2026-12' })).toBe('01.12.2026 bis 31.12.2026');
  expect(monthLabel('2026-01')).toBe('Jänner 2026');
});

test('dayLabel: Wochentag und Tag ohne Zeitzone', () => {
  expect(dayLabel('2026-10-01')).toBe('Do., 1.10.');
  expect(dayLabel('2026-10-04')).toBe('So., 4.10.');
  expect(dayLabel('2026-03-29')).toBe('So., 29.3.');
});

test('dayMonthText: ab wann es die erste gibt', () => {
  expect(dayMonthText('2026-12-01')).toBe('1. Dezember');
  expect(dayMonthText('2027-01-01')).toBe('1. Jänner');
});
