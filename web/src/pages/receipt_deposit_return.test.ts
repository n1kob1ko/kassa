import type { UseQueryResult } from '@tanstack/react-query';
import { createElement } from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, test } from 'vitest';
import type { ApiError } from '../api/client';
import type { Payment, ReceiptDetail, ReceiptLine } from '../api/receipts';
import { money } from '../format';
import { ReceiptDetailView } from './ReceiptDetail';

// Stufe 1b: "Pfand zurück" und die Auszahlung im Detail eines Bons, wie am Papier und auf der Seite des Bons. Eine Zeile
// "Pfand zurück" zeigt ihr Pfand mit Minus, "Pfand" nur das verlangte Pfand, eine Auszahlung "Bar ausbezahlt" ohne
// Minus und ohne Gegeben und Rückgeld.

const cash: Payment = {
  position: 0,
  kind: 'cash',
  amountCents: 0,
  givenCents: 0,
  changeCents: 0,
  tipCents: 0,
  tipStaffName: null,
  provider: null,
  providerTxCode: null,
  cardScheme: null,
  cardLast4: null,
  voucherCode: null,
  voucherBalanceAfterCents: null,
};

const line = (l: Partial<ReceiptLine>): ReceiptLine => ({
  position: 0,
  itemId: 'bier',
  name: 'Bier',
  info: null,
  unitPriceCents: 0,
  quantity: 1,
  unitDepositCents: 0,
  options: [],
  discountCents: 0,
  discount: null,
  ...l,
});

const depositReturn = (position: number, quantity: number) =>
  line({ position, itemId: 'deposit-return-25', name: 'Pfand zurück', quantity, unitDepositCents: -25 });

function render(r: Partial<ReceiptDetail>): string {
  const receipt: ReceiptDetail = {
    id: 'r1',
    number: 7,
    registerName: 'Kassa 1',
    createdAt: '2026-11-27T11:00:00Z',
    kind: 'sale',
    staffName: 'Anna',
    totalCents: 0,
    paymentKind: 'cash',
    voucherCents: 0,
    paymentKinds: ['cash'],
    test: false,
    voided: false,
    goodsCents: 0,
    depositCents: 0,
    lines: [],
    payments: [],
    vouchers: [],
    tipCents: 0,
    discountCents: 0,
    discount: null,
    voidsReceiptId: null,
    voidedByReceiptId: null,
    rksv: null,
    ...r,
  };
  const query = { data: receipt, isError: false } as unknown as UseQueryResult<ReceiptDetail, ApiError>;
  return renderToStaticMarkup(createElement(ReceiptDetailView, { businessId: 'b', query, linkTo: () => ({ to: '/', state: null }) }));
}

function byTestId(html: string, id: string): string[] {
  return [...html.matchAll(new RegExp(`data-testid="${id}"[^>]*>([^<]*)<`, 'g'))].map((m) => m[1] as string);
}

/** Die Beträge der Zeilen, in der Reihenfolge des Bons. */
const lineAmounts = (html: string) => [...html.matchAll(/class="[^"]*lineAmount[^"]*">([^<]*)</g)].map((m) => m[1]);

describe('Pfand zurück und Auszahlung im Detail eines Bons', () => {
  test('nur 3 x Pfand zurück zu 0,25: die Zeile -0,75, kein "Pfand", "Bar ausbezahlt 0,75" ohne Gegeben und Rückgeld', () => {
    const html = render({
      totalCents: -75,
      depositCents: -75,
      lines: [depositReturn(0, 3)],
      payments: [{ ...cash, amountCents: -75 }],
    });
    expect(lineAmounts(html)).toEqual([money(-75)]);
    expect(byTestId(html, 'deposit')).toEqual([]);
    expect(byTestId(html, 'total')).toEqual([money(-75)]);
    expect(byTestId(html, 'paid-out')).toEqual([money(75)]);
    expect(html).toContain('Bar ausbezahlt');
    expect(byTestId(html, 'given')).toEqual([]);
    expect(byTestId(html, 'change')).toEqual([]);
  });

  test('Bier 4,00 mit 0,25 Pfand und 1 x Pfand zurück: die Zeile -0,25, "Pfand 0,25", bar wie bisher', () => {
    const html = render({
      totalCents: 400,
      goodsCents: 400,
      depositCents: 0,
      lines: [line({ unitPriceCents: 400, unitDepositCents: 25 }), depositReturn(1, 1)],
      payments: [{ ...cash, amountCents: 400, givenCents: 500, changeCents: 100 }],
    });
    expect(lineAmounts(html)).toEqual([money(400), money(-25)]);
    expect(byTestId(html, 'deposit')).toEqual([money(25)]);
    expect(byTestId(html, 'given')).toEqual([money(500)]);
    expect(byTestId(html, 'change')).toEqual([money(100)]);
    expect(byTestId(html, 'paid-out')).toEqual([]);
    expect(html).not.toContain('Bar ausbezahlt');
  });
});

// Ein Storno spiegelt jede Zahlung mit Minus. Nur der Storno einer Auszahlung (Summe über 0) heißt "Bar ausbezahlt";
// jeder Storno, den es in 1.11.0 gab, liest sich wie vorher.
describe('Storno im Detail eines Bons', () => {
  const card: Payment = { ...cash, kind: 'card', cardScheme: 'VISA', cardLast4: '4242' };

  test('Storno eines Bar-Verkaufs: "Zahlungsart Bar", kein Betrag, kein "Bar ausbezahlt", wie in 1.11.0', () => {
    const html = render({
      kind: 'voided',
      totalCents: -990,
      goodsCents: -990,
      lines: [line({ unitPriceCents: 990, quantity: -1 })],
      payments: [{ ...cash, amountCents: -990, givenCents: 0, changeCents: 0 }],
    });
    expect(byTestId(html, 'payment-kind')).toEqual(['Bar']);
    expect(byTestId(html, 'payment-amount')).toEqual([]);
    expect(byTestId(html, 'paid-out')).toEqual([]);
    expect(byTestId(html, 'given')).toEqual([]);
    expect(html).not.toContain('Bar ausbezahlt');
  });

  test('Storno von Bar und Karte: beide mit Betrag mit Minus, wie in 1.11.0', () => {
    const html = render({
      kind: 'voided',
      totalCents: -1500,
      goodsCents: -1500,
      paymentKind: 'mixed',
      paymentKinds: ['cash', 'card'],
      lines: [line({ unitPriceCents: 1500, quantity: -1 })],
      payments: [
        { ...cash, amountCents: -500, givenCents: 0, changeCents: 0 },
        { ...card, position: 1, amountCents: -1000, givenCents: null, changeCents: null },
      ],
    });
    expect(byTestId(html, 'payment-kind')).toEqual(['Bar', 'Karte']);
    expect(byTestId(html, 'payment-amount')).toEqual([money(-500), money(-1000)]);
    expect(byTestId(html, 'paid-out')).toEqual([]);
    expect(html).not.toContain('Bar ausbezahlt');
  });

  test('Storno einer Auszahlung: "Bar ausbezahlt" mit Minus, ohne Gegeben und Rückgeld, wie am Papier', () => {
    const html = render({
      kind: 'voided',
      totalCents: 75,
      depositCents: 75,
      lines: [depositReturn(0, -3)],
      payments: [{ ...cash, amountCents: 75, givenCents: 0, changeCents: 0 }],
    });
    expect(byTestId(html, 'paid-out')).toEqual([money(-75)]);
    expect(byTestId(html, 'given')).toEqual([]);
    expect(byTestId(html, 'change')).toEqual([]);
  });
});
