// Die Steuer wie taxBreakdown in app/lib/domain/pricing.dart: ganze Cent, kaufmännisch gerundet auf dem Betrag,
// das Vorzeichen kommt zurück (ein Storno ist das genaue Spiegelbild des Bons).

export type TaxLine = { percent: number; grossCents: number; netCents: number; taxCents: number };

/** Die Sätze, die es gibt, absteigend. */
export const RATES = [20, 19, 13, 10, 0] as const;

/** Die Steuer im Brutto-Betrag. Für 580 Cent bei 20 % sind es 97. */
export function taxOf(grossCents: number, percent: number): number {
  const a = Math.abs(grossCents);
  const abs = Math.floor((a * percent * 2 + (100 + percent)) / (2 * (100 + percent)));
  return grossCents < 0 ? -abs : abs;
}

/** Brutto je Satz (Prozent als Schlüssel) zu Zeilen: nach Satz absteigend, Sätze ohne Betrag fehlen. */
export function taxLinesOf(gross: Record<number, number>): TaxLine[] {
  return RATES.filter((p) => (gross[p] ?? 0) !== 0).map((p) => {
    const g = gross[p]!;
    const tax = taxOf(g, p);
    return { percent: p, grossCents: g, netCents: g - tax, taxCents: tax };
  });
}

/** Zeilen mehrerer Zeiträume (je Monat gerechnet) addieren. Sätze, die sich aufheben, fehlen. */
export function sumTaxLines(lists: TaxLine[][]): TaxLine[] {
  const sums = new Map<number, TaxLine>();
  for (const l of lists.flat()) {
    const old = sums.get(l.percent) ?? { percent: l.percent, grossCents: 0, netCents: 0, taxCents: 0 };
    sums.set(l.percent, {
      percent: l.percent,
      grossCents: old.grossCents + l.grossCents,
      netCents: old.netCents + l.netCents,
      taxCents: old.taxCents + l.taxCents,
    });
  }
  return RATES.flatMap((p) => {
    const l = sums.get(p);
    return l && l.grossCents !== 0 ? [l] : [];
  });
}

/** Die Spalten von receipt_lines je Satz. */
export const GROSS_COLUMNS: Record<number, string> = {
  20: 'gross20_cents',
  10: 'gross10_cents',
  13: 'gross13_cents',
  0: 'gross0_cents',
  19: 'gross19_cents',
};
