import type { UseQueryResult } from '@tanstack/react-query';
import { createElement } from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { MemoryRouter } from 'react-router';
import { describe, expect, test } from 'vitest';
import type { ApiError } from '../api/client';
import type { PeriodSummary } from '../api/months';
import { money } from '../format';
import { movementKindText, splitVouchers, voucherStateText, type Voucher, type VoucherDetail, type VoucherList } from '../api/vouchers';
import { PeriodDetailView } from './PeriodDetail';
import { VoucherDetailView, VoucherListView } from './VouchersPage';

const loaded = <T>(data: T) => ({ data, isError: false }) as unknown as UseQueryResult<T, ApiError>;
const inRouter = (el: ReturnType<typeof createElement>) => renderToStaticMarkup(createElement(MemoryRouter, null, el));

const voucher = (o: Partial<Voucher>): Voucher => ({
  id: 'v1',
  code: '12345678',
  createdAt: '2026-11-17T10:00:00.000Z',
  valueCents: 2500,
  balanceCents: 2500,
  state: 'active',
  isTest: false,
  ...o,
});

describe('Gutscheine', () => {
  test('Zustand und Art der Bewegung als Wort; echte und Übungs-Gutscheine getrennt', () => {
    expect(['active', 'empty', 'voided', 'overdrawn'].map((s) => voucherStateText(s as Voucher['state']))).toEqual([
      'Gültig',
      'Aufgebraucht',
      'Storniert',
      'Überzogen',
    ]);
    expect(['sale', 'redeem', 'void_sale', 'void_redeem'].map((k) => movementKindText(k as 'sale'))).toEqual([
      'Verkauf',
      'Eingelöst',
      'Storno des Verkaufs',
      'Storno der Einlösung',
    ]);
    const a = voucher({ id: 'a' });
    const t = voucher({ id: 't', isTest: true });
    const b = voucher({ id: 'b' });
    expect(splitVouchers([a, t, b])).toEqual({ real: [a, b], practice: [t] });
  });

  test('Liste: oben "Offene Gutscheine", je Zeile Code "1234 5678", Datum, Wert, Guthaben, Zustand; überzogen fällt auf; Übungs-Gutscheine darunter', () => {
    const list: VoucherList = {
      openCents: 4035,
      vouchers: [
        voucher({ id: 'over', code: '87654321', valueCents: 1000, balanceCents: -930, state: 'overdrawn' }),
        voucher({ id: 'ok', balanceCents: 1535 }),
        voucher({ id: 'test', code: '11112222', valueCents: 2000, balanceCents: 2000, isTest: true }),
      ],
    };
    const html = inRouter(createElement(VoucherListView, { query: loaded(list), detailTo: (id: string) => `/b/b/gutscheine/${id}`, openId: null }));
    expect(html).toContain('Offene Gutscheine');
    expect(html).toContain(money(4035));
    expect(html).toContain('1234 5678');
    expect(html).toContain('8765 4321');
    expect(html).toContain('17.11.2026');
    expect(html).toContain(money(1535));
    // Überzogen: das Wort und die eigene Darstellung.
    expect(html).toMatch(/data-state="overdrawn"[^>]*>/);
    expect(html).toContain('Überzogen');
    expect(html).toContain(money(-930));
    // Der Übungs-Gutschein steht in einem eigenen Abschnitt nach den echten.
    const practice = html.indexOf('>Übungs-Gutscheine</h2>');
    expect(practice).toBeGreaterThan(0);
    expect(practice).toBeGreaterThan(html.indexOf('8765 4321'));
    expect(html.indexOf('1111 2222')).toBeGreaterThan(practice);
    expect(html).toContain('href="/b/b/gutscheine/over"');
  });

  test('Liste ohne Übungs-Gutschein hat keinen solchen Abschnitt; ohne Gutschein ein leerer Zustand', () => {
    const one = inRouter(
      createElement(VoucherListView, { query: loaded({ openCents: 2500, vouchers: [voucher({})] }), detailTo: () => '/', openId: null }),
    );
    expect(one).not.toContain('>Übungs-Gutscheine</h2>');
    const none = inRouter(createElement(VoucherListView, { query: loaded({ openCents: 0, vouchers: [] }), detailTo: () => '/', openId: null }));
    expect(none).toContain('Noch kein Gutschein.');
  });

  test('Detail: Wert, Guthaben, Zustand und die Bewegungen mit Link zum Bon', () => {
    const d: VoucherDetail = {
      ...voucher({ balanceCents: 1535 }),
      movements: [
        { kind: 'sale', amountCents: 2500, createdAt: '2026-11-17T10:00:00.000Z', receiptId: 'r1', receiptNumber: 12, registerName: 'Kassa 1' },
        { kind: 'redeem', amountCents: -965, createdAt: '2026-11-18T11:00:00.000Z', receiptId: 'r2', receiptNumber: 3, registerName: 'Kassa 2' },
      ],
    };
    const html = inRouter(createElement(VoucherDetailView, { businessId: 'b', query: loaded(d) }));
    expect(html).toContain('1234 5678');
    expect(html).toContain(money(2500));
    expect(html).toContain(money(1535));
    expect(html).toContain('Gültig');
    expect(html).toContain('Verkauf');
    expect(html).toContain('Eingelöst');
    expect(html).toContain(money(-965));
    expect(html).toContain('href="/b/b/bons/r1"');
    expect(html).toContain('href="/b/b/bons/r2"');
    expect(html).toContain('Bon 3');
    expect(html).toContain('Kassa 2');
  });
});

describe('Monat: Offene Gutscheine am Monatsende', () => {
  const summary = (o: Partial<PeriodSummary>): PeriodSummary => ({
    from: '2026-11',
    to: '2026-11',
    testMode: false,
    receiptCount: 1,
    cashReceiptCount: 1,
    cardReceiptCount: 0,
    voidCount: 0,
    voidedCents: 0,
    revenueCents: 1000,
    cashRevenueCents: 1000,
    cardRevenueCents: 0,
    depositCents: 0,
    discountCount: 0,
    discountCents: 0,
    cardTipCents: 0,
    cardAccountCents: 0,
    tipsByStaff: [],
    voucherPaidCents: 0,
    voucherSoldCount: 0,
    voucherSoldCents: 0,
    depositReturnCount: 0,
    depositReturnCents: 0,
    taxLines: [],
    rows: [],
    ...o,
  });
  const render = (s: PeriodSummary) =>
    renderToStaticMarkup(createElement(PeriodDetailView, { period: { from: '2026-11', to: '2026-11' }, query: loaded(s) }));

  test('mit openVoucherCents steht die Reihe da, ohne nicht', () => {
    const html = render(summary({ openVoucherCents: 1035 }));
    expect(html).toContain('Offene Gutscheine am Monatsende');
    expect(html).toContain(`data-testid="open-vouchers">${money(1035)}`);
    expect(render(summary({}))).not.toContain('Offene Gutscheine');
  });
});
