import { createElement } from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, test } from 'vitest';
import type { TaxLine } from '../api/days';
import { money } from '../format';
import { TaxTable } from './PeriodDetail';

// Wie am Tablet (report_layout.dart): unter dem Satz 0 (fehlt er, nach allen Sätzen) "davon Gutscheine", wenn
// Gutscheine verkauft wurden. Ohne verkaufte Gutscheine bleibt die Tabelle, wie sie war.

const zero: TaxLine = { percent: 0, grossCents: 2500, netCents: 2500, taxCents: 0 };
const ten: TaxLine = { percent: 10, grossCents: 1100, netCents: 1000, taxCents: 100 };

const render = (lines: TaxLine[], voucherSoldCents: number, depositCents = 0) =>
  renderToStaticMarkup(createElement(TaxTable, { lines, depositCents, voucherSoldCents }));

/** Die Zeilen der Tabelle als Texte ohne Tags, Zellen mit " | " getrennt. */
const rows = (html: string) =>
  [...html.matchAll(/<tr>(.*?)<\/tr>/g)].map((m) =>
    [...(m[1] as string).matchAll(/<t[hd][^>]*>(.*?)<\/t[hd]>/g)].map((c) => c[1] as string).join(' | '),
  );

describe('Steuer: davon Gutscheine', () => {
  test('ein Gutschein über 25,00 verkauft: die Zeile direkt unter MwSt 0 %', () => {
    expect(rows(render([zero, ten], 2500, 25))).toEqual([
      'Steuer | Umsatz | davon MwSt',
      `MwSt 0 % | ${money(2500)} | ${money(0)}`,
      `davon Gutscheine | ${money(2500)} | `,
      `MwSt 10 % | ${money(1100)} | ${money(100)}`,
      `Pfand, ohne MwSt | ${money(25)} | `,
    ]);
  });

  test('Storno im Zeitraum: auch mit Minus', () => {
    expect(rows(render([{ ...zero, grossCents: -2500, netCents: -2500 }], -2500))).toContain(
      `davon Gutscheine | ${money(-2500)} | `,
    );
  });

  test('kein Satz 0: die Zeile nach allen Sätzen', () => {
    expect(rows(render([ten], 2500)).slice(1)).toEqual([
      `MwSt 10 % | ${money(1100)} | ${money(100)}`,
      `davon Gutscheine | ${money(2500)} | `,
    ]);
  });

  test('keine Gutscheine verkauft: keine Zeile', () => {
    expect(render([zero, ten], 0)).not.toContain('davon Gutscheine');
  });
});
