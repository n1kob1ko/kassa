import { randomUUID } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { afterAll, beforeAll, beforeEach, describe, expect, test } from 'vitest';
import { voucherStatus } from '../src/admin/vouchers.js';
import { testApp, type TestApp } from './support/app.js';
import { createProvider, send, setTimeZone, siteFor, type Site } from './support/admin_data.js';
import { createPairingCode, PAIR_DEVICE } from './support/device.js';
import { voidOfV3, voucherRedeem as redeem, voucherSale as sale } from './support/stufe_1b.js';
import { authed, createChef, createChefAt, type TestUser } from './support/users.js';

// Gutscheine in der Verwaltung (Spec 5.5): Liste mit Guthaben und Zustand aus den Bewegungen, Detail mit den Bons,
// oben die Summe der offenen Guthaben ohne Übungs-Gutscheine.

let a: TestApp;
let provider: TestUser;

beforeAll(async () => {
  a = await testApp();
  provider = await createProvider(a.app, a.db);
});
beforeEach(() => {
  a.now.value = new Date('2026-11-18T10:00:00Z');
});
afterAll(async () => {
  await a.close();
});

type Case = { name: string; valueCents: number; movements: { kind: string; amountCents: number }[]; balanceCents: number; state: string };
const STATES = (
  JSON.parse(readFileSync(new URL('../../shared/fixtures/vouchers/states.json', import.meta.url), 'utf8')) as { cases: Case[] }
).cases;

const get = (url: string, cookie = provider.cookie) => a.app.inject({ method: 'GET', url, headers: authed(cookie) });
const list = (b: string, cookie?: string) => get(`/api/admin/businesses/${b}/vouchers`, cookie);
const detail = (b: string, id: string, cookie?: string) => get(`/api/admin/businesses/${b}/vouchers/${id}`, cookie);

const at = (iso: string) => ({ createdAt: iso });

/** Eine zweite Kassa "Kassa 2" im selben Betrieb. */
async function pairSecond(s: Site): Promise<{ token: string }> {
  const code = await createPairingCode(a.app, provider.cookie, s.businessId, 'Kassa 2');
  const res = await a.app.inject({ method: 'POST', url: '/api/device/pair', payload: { code, previousBusinessId: null, ...PAIR_DEVICE } });
  expect(res.statusCode).toBe(200);
  return { token: res.json().token };
}

describe('Zustand eines Gutscheins', () => {
  test('dieselbe Regel wie am Tablet: die Fälle aus shared/fixtures/vouchers/states.json', () => {
    expect(STATES.length).toBeGreaterThanOrEqual(8);
    for (const c of STATES) {
      expect(voucherStatus(c.movements), c.name).toEqual({ balanceCents: c.balanceCents, state: c.state });
    }
  });
});

describe('GET /api/admin/businesses/:b/vouchers', () => {
  test('Liste: Guthaben und Zustand aus den Bewegungen (states.json); openCents ohne Übungs-Gutscheine und ohne überzogene', async () => {
    const s = await siteFor(a, provider);
    // A: 25,00, 9,65 eingelöst. B: 25,00 unberührt. C: 10,00 storniert. D: 10,00, zweimal 9,65 (überzogen). E: 9,65 ganz
    // eingelöst. T: ein Übungs-Gutschein über 20,00.
    const A = sale(2500, at('2026-11-01T09:00:00.000Z'));
    const B = sale(2500, at('2026-11-02T09:00:00.000Z'));
    const C = sale(1000, at('2026-11-03T09:00:00.000Z'));
    const D = sale(1000, at('2026-11-04T09:00:00.000Z'));
    const E = sale(965, at('2026-11-05T09:00:00.000Z'));
    const T = sale(2000, { ...at('2026-11-06T09:00:00.000Z'), test: true });
    await send(a, s, [A, B, C, D, E, T].map((x): [string, object] => ['receipt', x.receipt]));
    await send(a, s, [
      ['receipt', redeem(A.voucher, at('2026-11-10T09:00:00.000Z'))],
      ['receipt', voidOfV3(C.receipt, { id: randomUUID(), number: 99, createdAt: '2026-11-10T09:05:00.000Z' })],
      ['receipt', redeem(D.voucher, at('2026-11-10T09:10:00.000Z'))],
      ['receipt', redeem(D.voucher, at('2026-11-10T09:20:00.000Z'))],
      ['receipt', redeem(E.voucher, at('2026-11-10T09:30:00.000Z'))],
    ]);

    const r = await list(s.businessId);
    expect(r.statusCode).toBe(200);
    const body = r.json();
    expect(body.openCents).toBe(1535 + 2500);
    // Neueste zuerst, jede mit vollem Code; der Übungs-Gutschein steht mit isTest da.
    expect(body.vouchers).toEqual([
      { id: T.voucher.id, code: T.voucher.code, createdAt: '2026-11-06T09:00:00.000Z', valueCents: 2000, balanceCents: 2000, state: 'active', isTest: true },
      { id: E.voucher.id, code: E.voucher.code, createdAt: '2026-11-05T09:00:00.000Z', valueCents: 965, balanceCents: 0, state: 'empty', isTest: false },
      { id: D.voucher.id, code: D.voucher.code, createdAt: '2026-11-04T09:00:00.000Z', valueCents: 1000, balanceCents: -930, state: 'overdrawn', isTest: false },
      { id: C.voucher.id, code: C.voucher.code, createdAt: '2026-11-03T09:00:00.000Z', valueCents: 1000, balanceCents: 0, state: 'voided', isTest: false },
      { id: B.voucher.id, code: B.voucher.code, createdAt: '2026-11-02T09:00:00.000Z', valueCents: 2500, balanceCents: 2500, state: 'active', isTest: false },
      { id: A.voucher.id, code: A.voucher.code, createdAt: '2026-11-01T09:00:00.000Z', valueCents: 2500, balanceCents: 1535, state: 'active', isTest: false },
    ]);
    // Ein Betrieb ohne Gutschein.
    const empty = await siteFor(a, provider);
    expect((await list(empty.businessId)).json()).toEqual({ openCents: 0, vouchers: [] });
  });

  test('Detail: Bewegungen mit Bon-Nummer und Kassa; ein anderer Betrieb sieht nichts', async () => {
    const s = await siteFor(a, provider);
    const second = await pairSecond(s);
    const A = sale(2500, at('2026-11-01T09:00:00.000Z'));
    await send(a, s, [['receipt', A.receipt]]);
    const paid = redeem(A.voucher, at('2026-11-12T09:00:00.000Z'));
    await send(a, { token: second.token, deviceId: randomUUID() }, [['receipt', paid]]);

    const chef = await createChef(a.db, s.businessId);
    const r = await detail(s.businessId, A.voucher.id, chef.cookie);
    expect(r.statusCode).toBe(200);
    expect(r.json()).toEqual({
      id: A.voucher.id,
        code: A.voucher.code,
        createdAt: '2026-11-01T09:00:00.000Z',
        valueCents: 2500,
        balanceCents: 1535,
        state: 'active',
        isTest: false,
        movements: [
          { kind: 'sale', amountCents: 2500, createdAt: '2026-11-01T09:00:00.000Z', receiptId: A.receipt.id, receiptNumber: A.receipt.number, registerName: 'Kassa 1' },
          { kind: 'redeem', amountCents: -965, createdAt: '2026-11-12T09:00:00.000Z', receiptId: paid.id, receiptNumber: paid.number, registerName: 'Kassa 2' },
        ],
    });

    // Ein anderer Betrieb und sein Chef sehen ihn nicht, auch nicht in der Liste; eine unsinnige Kennung ist 404.
    const other = await siteFor(a, provider);
    const chefOther = await createChef(a.db, other.businessId);
    expect((await list(other.businessId)).json()).toEqual({ openCents: 0, vouchers: [] });
    for (const res of [
      await detail(other.businessId, A.voucher.id),
      await detail(s.businessId, A.voucher.id, chefOther.cookie),
      await list(s.businessId, chefOther.cookie),
      await detail(s.businessId, 'abc'),
      await detail(s.businessId, randomUUID()),
    ]) {
      expect(res.statusCode).toBe(404);
      expect(res.json().error.code).toBe('not_found');
    }
    // Ohne Anmeldung.
    expect((await a.app.inject({ method: 'GET', url: `/api/admin/businesses/${s.businessId}/vouchers` })).statusCode).toBe(401);
  });

  test('zwei Kassen lösen denselben Gutschein über 10,00 € ein, jede 9,65 €, ohne voneinander zu wissen: beide Bons angenommen, Zustand überzogen, Guthaben -930', async () => {
    const s = await siteFor(a, provider);
    const second = await pairSecond(s);
    const V = sale(1000, at('2026-11-01T09:00:00.000Z'));
    await send(a, s, [['receipt', V.receipt]]);
    // send wirft, wenn ein Eintrag nicht angenommen ist.
    await send(a, s, [['receipt', redeem(V.voucher, at('2026-11-12T09:00:00.000Z'))]]);
    await send(a, { token: second.token, deviceId: randomUUID() }, [['receipt', redeem(V.voucher, at('2026-11-12T09:01:00.000Z'))]]);

    const body = (await list(s.businessId)).json();
    expect(body.vouchers.map((v: Record<string, unknown>) => [v.id, v.balanceCents, v.state])).toEqual([[V.voucher.id, -930, 'overdrawn']]);
    expect(body.openCents).toBe(0);
    const d = (await detail(s.businessId, V.voucher.id)).json();
    expect(d.movements.map((m: Record<string, unknown>) => [m.kind, m.amountCents, m.registerName])).toEqual([
      ['sale', 1000, 'Kassa 1'],
      ['redeem', -965, 'Kassa 1'],
      ['redeem', -965, 'Kassa 2'],
    ]);
  });
});

describe('Offene Gutscheine am Monatsende', () => {
  const summary = (s: Site, from: string, to: string, cookie: string) =>
    get(`/api/admin/businesses/${s.businessId}/months/summary?from=${from}&to=${to}`, cookie);

  test('Zeitzone des Betriebs: ein Verkauf am 30.11. um 23:30 UTC liegt in Wien schon im Dezember', async () => {
    const s = await siteFor(a, provider);
    await setTimeZone(a, s.businessId, 'Europe/Vienna');
    const early = sale(1000, at('2026-11-10T09:00:00.000Z'));
    const late = sale(2000, at('2026-11-30T23:30:00.000Z'));
    await send(a, s, [
      ['receipt', early.receipt],
      ['receipt', late.receipt],
    ]);
    a.now.value = new Date('2027-01-05T10:00:00.000Z');
    // Nach dem Sprung der Uhr eine frische Anmeldung.
    const chef = (await createChefAt(a.db, s.businessId, a.now.value)).cookie;
    expect((await summary(s, '2026-11', '2026-11', chef)).json().openVoucherCents).toBe(1000);
    expect((await summary(s, '2026-12', '2026-12', chef)).json().openVoucherCents).toBe(3000);
    // Ein Zeitraum: am Ende seines letzten Monats.
    expect((await summary(s, '2026-11', '2026-12', chef)).json().openVoucherCents).toBe(3000);
  });
});
