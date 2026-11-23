/**
 * Zeiträume der Monatsabrechnung: ein Monat ('2026-10') oder mehrere aufeinanderfolgende ('2026-01..2026-10').
 * Alles wird aus den Zeichenketten gerechnet, ohne Zeitzone (der Server liefert Monate und Tage schon in der Zeit
 * des Betriebs).
 */

export type Period = { from: string; to: string };

const MONTH = /^\d{4}-(0[1-9]|1[0-2])$/;
const UTC = 'UTC';
const MONTH_NAME = new Intl.DateTimeFormat('de-AT', { month: 'long', timeZone: UTC });
const WEEKDAY = new Intl.DateTimeFormat('de-AT', { weekday: 'short', timeZone: UTC });

function parts(month: string): [number, number] {
  const [y, m] = month.split('-').map(Number) as [number, number];
  return [y, m];
}

function name(month: string): string {
  const [y, m] = parts(month);
  return MONTH_NAME.format(new Date(Date.UTC(y, m - 1, 1)));
}

function year(month: string): string {
  return month.slice(0, 4);
}

/** Die Kennung aus der Adresse; `null` bei Unsinn, Monat 13 oder "Bis" vor "Von". */
export function parsePeriodId(id: string): Period | null {
  const [from, to, ...rest] = id.split('..');
  if (rest.length > 0 || from === undefined) return null;
  const end = to ?? from;
  if (!MONTH.test(from) || !MONTH.test(end) || end < from) return null;
  return { from, to: end };
}

/** Kennung für die Adresse: ein Monat als '2026-10', mehrere als '2026-01..2026-10'. */
export function periodId(p: Period): string {
  return p.from === p.to ? p.from : `${p.from}..${p.to}`;
}

/** "Oktober 2026", "Jänner bis Oktober 2026", "November 2025 bis Februar 2026" (wie `periodTitle` am Tablet). */
export function periodTitle(p: Period): string {
  if (p.from === p.to) return monthLabel(p.from);
  if (year(p.from) === year(p.to)) return `${name(p.from)} bis ${monthLabel(p.to)}`;
  return `${monthLabel(p.from)} bis ${monthLabel(p.to)}`;
}

/** Erster Tag des ersten bis letzter Tag des letzten Monats: "01.10.2026 bis 31.10.2026". */
export function periodDates(p: Period): string {
  const [fy, fm] = parts(p.from);
  const [ty, tm] = parts(p.to);
  const last = new Date(Date.UTC(ty, tm, 0)).getUTCDate();
  const pad = (n: number) => String(n).padStart(2, '0');
  return `01.${pad(fm)}.${fy} bis ${last}.${pad(tm)}.${ty}`;
}

/** "Oktober 2026". */
export function monthLabel(month: string): string {
  return `${name(month)} ${year(month)}`;
}

/** Ein Tag der Aufstellung ('2026-10-01') wie am Tablet: "Do., 1.10.". */
export function dayLabel(day: string): string {
  const [y, m, d] = day.split('-').map(Number) as [number, number, number];
  const weekday = WEEKDAY.format(new Date(Date.UTC(y, m - 1, d))).replace(/\.?$/, '.');
  return `${weekday}, ${d}.${m}.`;
}

/** Ein Tag ('2026-12-01') als "1. Dezember": ab wann es die erste Monatsabrechnung gibt. */
export function dayMonthText(day: string): string {
  return `${Number(day.slice(8, 10))}. ${name(day.slice(0, 7))}`;
}
