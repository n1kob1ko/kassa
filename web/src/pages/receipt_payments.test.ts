import type { UseQueryResult } from '@tanstack/react-query';
import { createElement } from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, test } from 'vitest';
import type { ApiError } from '../api/client';
import type { Payment, ReceiptDetail } from '../api/receipts';
import { money } from '../format';
import { ReceiptDetailView } from './ReceiptDetail';
import { paymentKindsText, voucherCodeText } from './receipt_payments';

// Die Zahlungsart eines Bons aus allen Arten seiner Zahlungen, wie am Tablet: Gutschein zuerst, dann bar, dann Karte.

describe('Zahlungsart aus allen Arten des Bons', () => {
  test('Zahlungsart: "Gutschein", "Gutschein + Bar", "Gutschein + Karte", "Bar + Karte" bleibt', () => {
    expect(paymentKindsText(['voucher'])).toBe('Gutschein');
    expect(paymentKindsText(['voucher', 'cash'])).toBe('Gutschein + Bar');
    expect(paymentKindsText(['voucher', 'card'])).toBe('Gutschein + Karte');
    expect(paymentKindsText(['cash', 'card'])).toBe('Bar + Karte');
    expect(paymentKindsText(['voucher', 'cash', 'card'])).toBe('Gutschein + Bar + Karte');
  });

  test('wie bisher: "Bar", "Karte", ohne Zahlung leer; die Reihenfolge der Eingabe zählt nicht, doppelte Arten einmal', () => {
    expect(paymentKindsText(['cash'])).toBe('Bar');
    expect(paymentKindsText(['card'])).toBe('Karte');
    expect(paymentKindsText([])).toBe('');
    expect(paymentKindsText(['card', 'voucher', 'voucher'])).toBe('Gutschein + Karte');
  });

  test('Code eines Gutscheins in zwei Vierergruppen', () => {
    expect(voucherCodeText('12345678')).toBe('1234 5678');
  });
});

const cashPayment: Payment = {
  position: 0,
  kind: 'cash',
  amountCents: 465,
  givenCents: 500,
  changeCents: 35,
  tipCents: 0,
  tipStaffName: null,
  provider: null,
  providerTxCode: null,
  cardScheme: null,
  cardLast4: null,
  voucherCode: null,
  voucherBalanceAfterCents: null,
};

function render(r: Partial<ReceiptDetail>): string {
  const receipt: ReceiptDetail = {
    id: 'r1',
    number: 7,
    registerName: 'Kassa 1',
    createdAt: '2026-10-14T10:00:00Z',
    kind: 'sale',
    staffName: 'Anna',
    totalCents: 965,
    paymentKind: 'mixed',
    voucherCents: 500,
    paymentKinds: ['voucher', 'cash'],
    test: false,
    voided: false,
    goodsCents: 940,
    depositCents: 25,
    lines: [],
    payments: [
      { ...cashPayment, kind: 'voucher', amountCents: 500, givenCents: 500, changeCents: 0, voucherCode: '12345678', voucherBalanceAfterCents: 1035 },
      { ...cashPayment, position: 1 },
    ],
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

/** Die Texte der Elemente mit dieser Test-Kennung, in der Reihenfolge der Seite. */
function byTestId(html: string, id: string): string[] {
  return [...html.matchAll(new RegExp(`data-testid="${id}"[^>]*>([^<]*)<`, 'g'))].map((m) => m[1] as string);
}

describe('Gutscheine im Detail eines Bons', () => {
  test('Gutschein + Bar: je Gutschein-Zahlung "Gutschein 1234 5678" mit Betrag und Restguthaben', () => {
    const html = render({});
    expect(html).toContain('Zahlungen · Gutschein + Bar');
    expect(byTestId(html, 'payment-kind')).toEqual(['Gutschein', 'Bar']);
    expect(byTestId(html, 'voucher-label')).toEqual(['Gutschein 1234 5678']);
    expect(byTestId(html, 'voucher-amount')).toEqual([money(500)]);
    expect(byTestId(html, 'voucher-balance')).toEqual([money(1035)]);
    expect(html).toContain('Restguthaben');
    // Bei bar weiter Gegeben und Rückgeld, nicht bei der Gutschein-Zahlung.
    expect(byTestId(html, 'given')).toEqual([money(500)]);
  });

  test('nur Gutschein: eine Zahlung, Zahlungsart Gutschein', () => {
    const html = render({
      paymentKind: 'voucher',
      paymentKinds: ['voucher'],
      voucherCents: 965,
      payments: [{ ...cashPayment, kind: 'voucher', amountCents: 965, givenCents: 965, changeCents: 0, voucherCode: '87654321', voucherBalanceAfterCents: 0 }],
    });
    expect(byTestId(html, 'payment-kind')).toEqual(['Gutschein']);
    expect(byTestId(html, 'voucher-label')).toEqual(['Gutschein 8765 4321']);
    expect(byTestId(html, 'voucher-amount')).toEqual([money(965)]);
    expect(byTestId(html, 'voucher-balance')).toEqual([money(0)]);
    expect(byTestId(html, 'given')).toEqual([]);
  });

  test('verkaufter Gutschein: Wert und Code', () => {
    const html = render({
      paymentKind: 'cash',
      paymentKinds: ['cash'],
      voucherCents: 0,
      payments: [{ ...cashPayment, amountCents: 2500, givenCents: 2500, changeCents: 0 }],
      vouchers: [{ code: '12345678', valueCents: 2500, linePosition: 0 }],
    });
    expect(byTestId(html, 'sold-voucher')).toEqual(['Gutschein 1234 5678']);
    expect(byTestId(html, 'sold-voucher-value')).toEqual([money(2500)]);
    expect(byTestId(html, 'voucher-label')).toEqual([]);
  });

  test('ein Bon ohne Gutschein zeigt nichts davon', () => {
    const html = render({ paymentKind: 'cash', paymentKinds: ['cash'], voucherCents: 0, payments: [cashPayment] });
    for (const id of ['voucher-label', 'voucher-amount', 'voucher-balance', 'sold-voucher', 'sold-voucher-value']) {
      expect(byTestId(html, id), id).toEqual([]);
    }
    expect(html).not.toContain('Gutschein');
  });
});
