import type { UseQueryResult } from '@tanstack/react-query';
import { createElement } from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, test } from 'vitest';
import type { ApiError } from '../api/client';
import type { ReceiptDetail } from '../api/receipts';
import { ReceiptDetailView } from './ReceiptDetail';

// Stufe 1b: wie der Beleg erteilt wurde (gedruckt, digital angeboten) und der Weg zur Seite des Bons.

function render(r: Partial<ReceiptDetail>): string {
  const receipt: ReceiptDetail = {
    id: 'r1',
    number: 7,
    registerName: 'Kassa 1',
    createdAt: '2026-11-27T11:00:00Z',
    kind: 'sale',
    staffName: 'Anna',
    totalCents: 990,
    paymentKind: 'cash',
    voucherCents: 0,
    paymentKinds: ['cash'],
    test: false,
    voided: false,
    goodsCents: 990,
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

describe('Beleg im Detail eines Bons', () => {
  test('Zeile "Beleg" mit "Gedruckt 12:03" und "Digital angeboten 12:03", Link "Seite des Bons" auf pageUrl', () => {
    const html = render({
      deliveries: [
        { kind: 'printed', at: '2026-11-27T11:03:05.000Z' },
        { kind: 'digital', at: '2026-11-27T11:03:40.000Z' },
      ],
      pageUrl: '/beleg/Bsp3Verkauf1GutscheinA',
    });
    expect(byTestId(html, 'delivery-title')).toEqual(['Beleg']);
    expect(byTestId(html, 'delivery')).toEqual(['Gedruckt 12:03', 'Digital angeboten 12:03']);
    const link = html.match(/<a [^>]*data-testid="page-link"[^>]*>/)![0];
    expect(link).toContain('href="/beleg/Bsp3Verkauf1GutscheinA"');
    expect(link).toContain('target="_blank"');
    expect(link).toContain('rel="noopener noreferrer"');
    expect(html).toContain('Seite des Bons');
  });

  test('nur der Link, wenn noch nichts erteilt ist; ohne beides kein Abschnitt', () => {
    const onlyPage = render({ pageUrl: '/beleg/Bsp3Verkauf1GutscheinA' });
    expect(byTestId(onlyPage, 'delivery')).toEqual([]);
    expect(onlyPage).toContain('Seite des Bons');
    const none = render({});
    expect(byTestId(none, 'delivery-title')).toEqual([]);
    expect(none).not.toContain('Seite des Bons');
    expect(none).not.toContain('/beleg/');
  });

  test('nur gedruckt: eine Zeile, kein Link ohne Seite', () => {
    const html = render({ deliveries: [{ kind: 'printed', at: '2026-11-27T22:59:00.000Z' }] });
    expect(byTestId(html, 'delivery')).toEqual(['Gedruckt 23:59']);
    expect(html).not.toContain('Seite des Bons');
  });
});
