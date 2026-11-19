/** Zeiten, Größen und Codes, so wie sie auf den Seiten der Verwaltung stehen. Alles deutsch. */

const MINUTE = 60_000;
const HOUR = 60 * MINUTE;
const DAY = 24 * HOUR;

function unit(n: number, one: string, many: string): string {
  return `vor ${n} ${n === 1 ? one : many}`;
}

/** "gerade eben", "vor 5 Minuten", "vor 2 Stunden", "vor 3 Tagen". Eine Zeit in der Zukunft gilt als "gerade eben". */
export function ago(date: Date, now: Date): string {
  const diff = now.getTime() - date.getTime();
  if (diff < MINUTE) return 'gerade eben';
  if (diff < HOUR) return unit(Math.floor(diff / MINUTE), 'Minute', 'Minuten');
  if (diff < DAY) return unit(Math.floor(diff / HOUR), 'Stunde', 'Stunden');
  return unit(Math.floor(diff / DAY), 'Tag', 'Tagen');
}

/** Größe in Megabyte mit einer Nachkommastelle und deutschem Komma: "24,1 MB". */
export function megabytes(bytes: number): string {
  return `${(bytes / (1024 * 1024)).toFixed(1).replace('.', ',')} MB`;
}

/** Den achtstelligen Kopplungscode in zwei Vierergruppen teilen: "4820 1937". */
export function codeGroups(code: string): string {
  return `${code.slice(0, 4)} ${code.slice(4)}`;
}

/** Restzeit als "14:32". Angebrochene Sekunden zählen voll, unter null gibt es nichts. */
export function countdown(ms: number): string {
  const total = Math.max(0, Math.ceil(ms / 1000));
  const minutes = Math.floor(total / 60);
  const seconds = String(total % 60).padStart(2, '0');
  return `${minutes}:${seconds}`;
}

const DATE = new Intl.DateTimeFormat('de-AT', { day: '2-digit', month: '2-digit', year: 'numeric', timeZone: 'Europe/Vienna' });

/** Datum als "18.11.2026" in Wiener Zeit. */
export function dateText(date: Date): string {
  return DATE.format(date);
}

/** "1 Artikel", "3 Artikel": Wörter, die im Plural gleich bleiben, und die mit eigener Mehrzahl. */
export function count(n: number, one: string, many = one): string {
  return `${n} ${n === 1 ? one : many}`;
}

/** Geschütztes Leerzeichen zwischen Betrag und Euro: "12,90 €" bricht nie um. */
const NBSP = ' ';

/**
 * Betrag aus ganzen Cent, deutsch: "1.234.567,89 €". Negativ mit echtem Minuszeichen davor ("−12,90 €").
 * Die Ziffern stehen in Tabellenziffern (base.css), große Zahlen schalten das im eigenen Stil ab.
 */
export function money(cents: number): string {
  const abs = Math.abs(Math.trunc(cents));
  const euros = String(Math.floor(abs / 100)).replace(/\B(?=(\d{3})+(?!\d))/g, '.');
  const rest = String(abs % 100).padStart(2, '0');
  return `${cents < 0 && abs > 0 ? '−' : ''}${euros},${rest}${NBSP}€`;
}

/** Anteil von `part` an `total` in ganzen Prozent, halb auf. Ohne Summe 0. */
export function share(part: number, total: number): number {
  if (total <= 0 || part <= 0) return 0;
  return Math.floor((part * 200 + total) / (2 * total));
}

export type OverviewRange = 'today' | 'days7' | 'days30';

const WEEKDAY = new Intl.DateTimeFormat('de-AT', { weekday: 'long', timeZone: 'Europe/Vienna' });

/**
 * Der Satz unter dem Umsatz: "12 % mehr als in den 7 Tagen davor", "12 % weniger …", "Gleich viel wie …".
 * Heute vergleicht der Server mit demselben Wochentag der Vorwoche bis zur selben Uhrzeit ("als letzten Donnerstag",
 * Wochentag in Wiener Zeit). Ganze Prozent, halb auf; was auf 0 % rundet, ist "gleich viel". Ohne Umsatz davor: null.
 */
export function comparison(range: OverviewRange, cents: number, previousCents: number, now: Date): string | null {
  if (previousCents <= 0) return null;
  const percent = Math.floor((Math.abs(cents - previousCents) * 200 + previousCents) / (2 * previousCents));
  const base = range === 'today' ? `letzten ${WEEKDAY.format(now)}` : `in den ${range === 'days7' ? 7 : 30} Tagen davor`;
  if (percent === 0) return `Gleich viel wie ${base}`;
  return `${percent} % ${cents > previousCents ? 'mehr' : 'weniger'} als ${base}`;
}
