import type { UseQueryResult } from '@tanstack/react-query';
import { createElement } from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, test } from 'vitest';
import type { ApiError } from '../api/client';
import type { DayDetail } from '../api/days';
import type { PeriodSummary } from '../api/months';
import { money } from '../format';
import { DayDetailView } from './DayDetail';
import { PeriodDetailView } from './PeriodDetail';

// Rabatte, Trinkgeld je Person und "Am Kartenkonto" stehen unter denselben Bedingungen wie am Tablet
// (`income_card.dart`, `report_layout.dart`): Rabatte bei Anzahl oder Summe ungleich 0, mit Minus;
// der Block Trinkgeld, sobald jemand Trinkgeld hat, auch wenn die Summe des Tages 0 ist.

const loaded = <T>(data: T) => ({ data, isError: false }) as unknown as UseQueryResult<T, ApiError>;

type Figures = Pick<DayDetail, 'discountCount' | 'discountCents' | 'cardTipCents' | 'cardAccountCents' | 'tipsByStaff'>;

const none: Figures = { discountCount: 0, discountCents: 0, cardTipCents: 0, cardAccountCents: 0, tipsByStaff: [] };

function day(f: Partial<Figures>): string {
  const d: DayDetail = {
    id: 'd1',
    registerName: 'Kassa 1',
    openedAt: '2026-11-17T08:00:00Z',
    closedAt: null,
    expectedCents: null,
    countedCents: null,
    differenceCents: null,
    closedByName: null,
    revenueCents: 1000,
    openingFloatCents: 0,
    leftInDrawerCents: null,
    movements: [],
    receiptCount: 1,
    cashCents: 0,
    cardCents: 1000,
    cashReceiptCount: 0,
    cardReceiptCount: 1,
    voidCount: 0,
    voidedCents: 0,
    depositCents: 0,
    taxLines: [],
    ...none,
    ...f,
  };
  return renderToStaticMarkup(createElement(DayDetailView, { query: loaded(d) }));
}

function period(f: Partial<Figures>): string {
  const s: PeriodSummary = {
    from: '2026-11-01',
    to: '2026-11-30',
    testMode: false,
    receiptCount: 1,
    cashReceiptCount: 0,
    cardReceiptCount: 1,
    voidCount: 0,
    voidedCents: 0,
    revenueCents: 1000,
    cashRevenueCents: 0,
    cardRevenueCents: 1000,
    depositCents: 0,
    taxLines: [],
    rows: [],
    ...none,
    ...f,
  };
  return renderToStaticMarkup(
    createElement(PeriodDetailView, { period: { from: '2026-11', to: '2026-11' }, query: loaded(s) }),
  );
}

/** Die Texte der Elemente mit dieser Test-Kennung, in der Reihenfolge der Seite. */
function byTestId(html: string, id: string): string[] {
  return [...html.matchAll(new RegExp(`data-testid="${id}"[^>]*>([^<]*)<`, 'g'))].map((m) => m[1] as string);
}

for (const [name, render] of [
  ['Tag', day],
  ['Zeitraum', period],
] as const) {
  describe(`${name}: Rabatte und Trinkgeld wie am Tablet`, () => {
    test('ohne Rabatt und ohne Trinkgeld: keine dieser Zeilen, auch nicht "Am Kartenkonto"', () => {
      const html = render({ cardAccountCents: 1000 });
      for (const id of ['discounts', 'card-tip', 'card-tip-staff', 'card-account']) {
        expect(byTestId(html, id), id).toEqual([]);
      }
    });

    test('Rabatte mit Minus', () => {
      expect(byTestId(render({ discountCount: 2, discountCents: 284 }), 'discounts')).toEqual([money(-284)]);
    });

    test('Rabatte mit Summe 0, aber Bons mit Rabatt: die Zeile steht', () => {
      expect(byTestId(render({ discountCount: 1, discountCents: 0 }), 'discounts')).toEqual([money(0)]);
    });

    test('Storno eines Rabatts: Summe negativ, die Zeile zeigt den Spiegel mit Plus', () => {
      expect(byTestId(render({ discountCount: -1, discountCents: -100 }), 'discounts')).toEqual([money(100)]);
    });

    test('Trinkgeld: Summe, je Person und "Am Kartenkonto"', () => {
      const html = render({
        cardTipCents: 300,
        cardAccountCents: 1300,
        tipsByStaff: [
          { staffName: 'Anna', cents: 200 },
          { staffName: 'Ben', cents: 100 },
        ],
      });
      expect(byTestId(html, 'card-tip')).toEqual([money(300)]);
      expect(byTestId(html, 'card-tip-staff')).toEqual([money(200), money(100)]);
      expect(byTestId(html, 'card-account')).toEqual([money(1300)]);
    });

    test('Trinkgeld des Tages 0, aber zwei Personen mit +2,00 und −2,00: beide Zeilen stehen', () => {
      const html = render({
        cardTipCents: 0,
        cardAccountCents: 1000,
        tipsByStaff: [
          { staffName: 'Anna', cents: 200 },
          { staffName: 'Ben', cents: -200 },
        ],
      });
      expect(byTestId(html, 'card-tip')).toEqual([money(0)]);
      expect(byTestId(html, 'card-tip-staff')).toEqual([money(200), money(-200)]);
      expect(byTestId(html, 'card-account')).toEqual([money(1000)]);
    });

    test('zwei Personen mit demselben Namen: beide Zeilen stehen', () => {
      const html = render({
        cardTipCents: 300,
        cardAccountCents: 1300,
        tipsByStaff: [
          { staffName: 'Anna', cents: 200 },
          { staffName: 'Anna', cents: 100 },
        ],
      });
      expect(byTestId(html, 'card-tip-staff')).toEqual([money(200), money(100)]);
    });
  });
}
