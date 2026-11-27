import type { UseQueryResult } from '@tanstack/react-query';
import { createElement } from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, test } from 'vitest';
import type { ApiError } from '../api/client';
import type { DayDetail } from '../api/days';
import type { PeriodSummary } from '../api/months';
import type { Overview } from '../api/overview';
import { money } from '../format';
import { DayDetailView } from './DayDetail';
import { OverviewPayments } from './OverviewPage';
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
    voucherPaidCents: 0,
    voucherSoldCount: 0,
    voucherSoldCents: 0,
    depositReturnCount: 0,
    depositReturnCents: 0,
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
    voucherPaidCents: 0,
    voucherSoldCount: 0,
    voucherSoldCents: 0,
    depositReturnCount: 0,
    depositReturnCents: 0,
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

// Stufe 1b: "Mit Gutschein bezahlt", "Gutscheine verkauft" (Anzahl, Summe) und "Pfand zurück" (Anzahl, Summe), nur wenn
// der Wert nicht 0 ist. Die Zahlen der vier Bons aus Task 6 (shared/fixtures/stats/stufe_1b.json).
type VoucherFigures = Pick<DayDetail, 'voucherPaidCents' | 'voucherSoldCount' | 'voucherSoldCents' | 'depositReturnCount' | 'depositReturnCents'>;
const stufe1b: VoucherFigures = { voucherPaidCents: 965, voucherSoldCount: 1, voucherSoldCents: 2500, depositReturnCount: 3, depositReturnCents: 75 };
const NEW_ROWS = ['voucher-paid', 'voucher-sold', 'voucher-sold-count', 'deposit-return', 'deposit-return-count'];

/** Die Texte aller Elemente mit dieser Test-Kennung, auch mit Kindern (ohne Tags). */
function textsOf(html: string, id: string): string[] {
  return [...html.matchAll(new RegExp(`data-testid="${id}"[^>]*>(.*?)</(?:dd|span)>`, 'g'))].map((m) =>
    (m[1] as string).replace(/<[^>]+>/g, ''),
  );
}

for (const [name, render] of [
  ['Tag', (f: Partial<VoucherFigures>) => day(f as Partial<Figures>)],
  ['Zeitraum', (f: Partial<VoucherFigures>) => period(f as Partial<Figures>)],
] as const) {
  describe(`${name}: Gutscheine und Pfand zurück`, () => {
    test('alle fünf Zahlen: drei Zeilen mit Betrag, Gutscheine und Pfand mit Anzahl', () => {
      const html = render(stufe1b);
      expect(byTestId(html, 'voucher-paid')).toEqual([money(965)]);
      expect(byTestId(html, 'voucher-sold')).toEqual([money(2500)]);
      expect(textsOf(html, 'voucher-sold-count')).toEqual(['1 Gutschein']);
      expect(byTestId(html, 'deposit-return')).toEqual([money(75)]);
      expect(textsOf(html, 'deposit-return-count')).toEqual(['3 Stück']);
      expect(html).toContain('Mit Gutschein bezahlt');
      expect(html).toContain('Gutscheine verkauft');
      expect(html).toContain('Pfand zurück');
    });

    test('alles 0 (Bons vor Stufe 1b): keine dieser Zeilen', () => {
      const html = render({});
      for (const id of NEW_ROWS) expect(byTestId(html, id), id).toEqual([]);
      for (const text of ['Mit Gutschein bezahlt', 'Gutscheine verkauft', 'Pfand zurück']) expect(html).not.toContain(text);
    });

    test('nur eine Zahl nicht 0: nur ihre Zeile; Storno mit Minus', () => {
      const html = render({ depositReturnCount: -3, depositReturnCents: -75 });
      expect(byTestId(html, 'deposit-return')).toEqual([money(-75)]);
      expect(textsOf(html, 'deposit-return-count')).toEqual(['-3 Stück']);
      for (const id of ['voucher-paid', 'voucher-sold']) expect(byTestId(html, id), id).toEqual([]);
      const two = render({ voucherSoldCount: 2, voucherSoldCents: 5000 });
      expect(textsOf(two, 'voucher-sold-count')).toEqual(['2 Gutscheine']);
      expect(byTestId(two, 'deposit-return')).toEqual([]);
    });
  });
}

describe('Übersicht: Gutschein als dritte Zahlungsart', () => {
  const overview = (o: Partial<Overview>): string => {
    const data: Overview = {
      range: 'days30',
      testMode: false,
      hasReceipts: true,
      revenueCents: 2710,
      previousRevenueCents: 0,
      receiptCount: 4,
      voidCount: 0,
      buckets: [],
      cashCents: 4245,
      cardCents: 0,
      voucherCents: 965,
      topItems: [],
      byCategory: [],
      ...o,
    };
    return renderToStaticMarkup(createElement(OverviewPayments, { data }));
  };

  test('mit Gutschein bezahlt: Bar, Karte und Gutschein', () => {
    const html = overview({});
    expect(byTestId(html, 'cash')).toEqual([money(4245)]);
    expect(byTestId(html, 'card')).toEqual([money(0)]);
    expect(byTestId(html, 'voucher')).toEqual([money(965)]);
    expect(html).toContain('Gutschein');
  });

  test('ohne Gutschein: nur Bar und Karte, wie bisher', () => {
    const html = overview({ voucherCents: 0, cashCents: 1000, cardCents: 536 });
    expect(byTestId(html, 'voucher')).toEqual([]);
    expect(byTestId(html, 'voucher-share')).toEqual([]);
    expect(html).not.toContain('Gutschein');
    expect(byTestId(html, 'cash-share')).toEqual(['65 %']);
  });
});
