import type { UseQueryResult } from '@tanstack/react-query';
import { createElement } from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, test } from 'vitest';
import type { ApiError } from '../api/client';
import type { ReceiptDetail } from '../api/receipts';
import { money } from '../format';
import { ReceiptDetailView } from './ReceiptDetail';

// Am Verkauf steht ein Rabatt mit Minus, am Storno-Bon sein Spiegel mit Plus (wie am Tablet). Nur die Anzeige.

function render(kind: 'sale' | 'voided'): string {
  const sign = kind === 'sale' ? 1 : -1;
  const discount = { percent: 10, amountCents: 119, reason: 'regular' };
  const r: ReceiptDetail = {
    id: 'r1',
    number: 7,
    registerName: 'Kassa 1',
    createdAt: '2026-11-17T10:00:00Z',
    kind,
    staffName: 'Anna',
    totalCents: sign * 1071,
    paymentKind: 'cash',
    voucherCents: 0,
    paymentKinds: ['cash'],
    test: false,
    voided: false,
    goodsCents: sign * 1190,
    depositCents: 0,
    lines: [
      {
        position: 0,
        itemId: 'huhn-bowl',
        name: 'Huhn Bowl',
        info: null,
        unitPriceCents: 1190,
        quantity: sign,
        unitDepositCents: 0,
        options: [],
        discountCents: sign * 119,
        discount,
      },
    ],
    payments: [],
    vouchers: [],
    tipCents: 0,
    discountCents: sign * 119,
    discount,
    voidsReceiptId: null,
    voidedByReceiptId: null,
    rksv: null,
  };
  const query = { data: r, isError: false } as unknown as UseQueryResult<ReceiptDetail, ApiError>;
  return renderToStaticMarkup(createElement(ReceiptDetailView, { businessId: 'b', query, linkTo: () => ({ to: '/', state: null }) }));
}

/** Der Betrag in einem Element mit dieser Test-Kennung (bei der Zeile der innere Betrag). */
function amountIn(html: string, id: string): string | undefined {
  const at = html.indexOf(`data-testid="${id}"`);
  if (at < 0) return undefined;
  return html.slice(at).match(/(−?[\d.]+,\d\d\s€)/)?.[1];
}

describe('Rabatt am Bon im Browser', () => {
  test('Verkauf: Rabatt auf dem Bon und auf der Zeile mit Minus', () => {
    const html = render('sale');
    expect(amountIn(html, 'discount')).toBe(money(-119));
    expect(amountIn(html, 'line-discount-0')).toBe(money(-119));
  });

  test('Storno-Bon: derselbe Rabatt als Spiegel mit Plus', () => {
    const html = render('voided');
    expect(amountIn(html, 'discount')).toBe(money(119));
    expect(amountIn(html, 'line-discount-0')).toBe(money(119));
  });
});
