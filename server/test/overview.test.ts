import { randomUUID } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { afterAll, beforeAll, describe, expect, test } from 'vitest';
import { withBusiness } from '../src/db/tenant.js';
import { testApp, type TestApp } from './support/app.js';
import { allKeys, createProvider, FORBIDDEN_KEYS, send, setTimeZone, siteFor } from './support/admin_data.js';
import { sampleReceipt } from './support/push.js';
import { authed, createChef, type TestUser } from './support/users.js';

let a: TestApp;
let provider: TestUser;

beforeAll(async () => {
  a = await testApp();
  provider = await createProvider(a.app, a.db);
});
afterAll(async () => {
  await a.close();
});

const overview = (businessId: string, range: string | null, cookie = provider.cookie) =>
  a.app.inject({
    method: 'GET',
    url: `/api/admin/businesses/${businessId}/overview${range === null ? '' : `?range=${range}`}`,
    headers: authed(cookie),
  });

const receipt = (createdAt: string, o: Record<string, unknown> = {}) =>
  sampleReceipt({ id: randomUUID(), createdAt, ...o });

type Fixture = {
  now: string;
  timeZone: string;
  categories: { id: string; name: string; position: number }[];
  items: { id: string; name: string; priceCents: number; categoryId: string; taxPercent: number; depositCents: number }[];
  receipts: Record<string, unknown>[];
  expected: Record<string, Record<string, unknown>>;
};

describe('Umsätze', () => {
  test('gemeinsames Beispiel: dieselben Zahlen wie die App', async () => {
    const fx = JSON.parse(readFileSync(new URL('../../shared/fixtures/stats/overview.json', import.meta.url), 'utf8')) as Fixture;
    const s = await siteFor(a, provider);
    await setTimeZone(a, s.businessId, fx.timeZone);
    await withBusiness(a.db, s.businessId, async (c) => {
      for (const k of fx.categories) {
        await c.query(
          `insert into categories (business_id, id, name, position, change_seq) values ($1, $2, $3, $4, nextval('change_seq'))`,
          [s.businessId, k.id, k.name, k.position],
        );
      }
      for (const [i, it] of fx.items.entries()) {
        await c.query(
          `insert into items (business_id, id, name, price_cents, category_id, tax_percent, deposit_cents, position, change_seq)
           values ($1, $2, $3, $4, $5, $6, $7, $8, nextval('change_seq'))`,
          [s.businessId, it.id, it.name, it.priceCents, it.categoryId, it.taxPercent, it.depositCents, i],
        );
      }
    });
    await send(a, s, fx.receipts.map((r) => ['receipt', r]));
    a.now.value = new Date(fx.now);

    // Die Namen der Felder in der Datei (Overview der App) und in der Antwort sind dieselben.
    const fields: [string, string][] = [
      ['revenueCents', 'revenueCents'],
      ['previousRevenueCents', 'previousRevenueCents'],
      ['receiptCount', 'receiptCount'],
      ['voidCount', 'voidCount'],
      ['buckets', 'buckets'],
      ['cashCents', 'cashCents'],
      ['cardCents', 'cardCents'],
      ['topItems', 'topItems'],
      ['byCategory', 'byCategory'],
    ];
    for (const range of ['today', 'days7', 'days30']) {
      const res = await overview(s.businessId, range);
      expect(res.statusCode).toBe(200);
      const body = res.json();
      expect(body.range).toBe(range);
      expect(body.testMode).toBe(true);
      for (const [expectedKey, responseKey] of fields) {
        expect(body[responseKey], `${range}.${responseKey}`).toEqual(fx.expected[range]![expectedKey]);
      }
    }
    expect([...allKeys((await overview(s.businessId, 'today')).json())].filter((k) => FORBIDDEN_KEYS.includes(k))).toEqual([]);
  });

  test('Europe/Vienna: ein Bon um 23:30 UTC zählt zum nächsten Tag', async () => {
    const s = await siteFor(a, provider);
    a.now.value = new Date('2026-11-19T12:00:00.000Z');
    await send(a, s, [
      ['receipt', receipt('2026-11-18T22:30:00.000Z', { number: 1, totalCents: 500, goodsCents: 500 })], // 23:30 am 18.11. in Wien
      ['receipt', receipt('2026-11-18T23:30:00.000Z', { number: 2, totalCents: 700, goodsCents: 700 })], // 00:30 am 19.11. in Wien
    ]);
    const today = (await overview(s.businessId, 'today')).json();
    expect(today.revenueCents).toBe(700);
    expect(today.previousRevenueCents).toBe(0);
    expect(today.buckets[0]).toEqual({ label: '0', start: '2026-11-18T23:00:00.000Z', cents: 700 });
    expect(today.buckets).toHaveLength(14); // Stunde 0 bis 13 (12:00 UTC = 13 Uhr in Wien)
    const week = (await overview(s.businessId, 'days7')).json();
    expect(week.revenueCents).toBe(1200);
    expect(week.buckets.at(-1)).toEqual({ label: '19.11.', start: '2026-11-18T23:00:00.000Z', cents: 700 });
    expect(week.buckets.at(-2)).toEqual({ label: '18.11.', start: '2026-11-17T23:00:00.000Z', cents: 500 });
  });

  test('unbekannte Zeitzone: es gilt Europe/Vienna', async () => {
    const s = await siteFor(a, provider);
    await setTimeZone(a, s.businessId, 'Mars/Olympus');
    a.now.value = new Date('2026-11-19T12:00:00.000Z');
    await send(a, s, [['receipt', receipt('2026-11-18T23:30:00.000Z', { totalCents: 700, goodsCents: 700 })]]);
    const res = await overview(s.businessId, 'today');
    expect(res.statusCode).toBe(200);
    expect(res.json().revenueCents).toBe(700);
  });

  test('nur Testbons: testMode wahr, sie zählen', async () => {
    const s = await siteFor(a, provider);
    a.now.value = new Date('2026-11-19T12:00:00.000Z');
    await send(a, s, [['receipt', receipt('2026-11-19T09:00:00.000Z', { test: true })]]);
    const body = (await overview(s.businessId, 'today')).json();
    expect(body.testMode).toBe(true);
    expect(body.revenueCents).toBe(990);
    expect(body.receiptCount).toBe(1);
  });

  test('ein echter Bon: testMode falsch, Testbons zählen nicht mehr', async () => {
    const s = await siteFor(a, provider);
    a.now.value = new Date('2026-11-19T12:00:00.000Z');
    await send(a, s, [
      ['receipt', receipt('2026-11-19T09:00:00.000Z', { number: 1, test: true })],
      ['receipt', receipt('2026-11-19T10:00:00.000Z', { number: 2, test: false, totalCents: 300, goodsCents: 300 })],
    ]);
    const body = (await overview(s.businessId, 'today')).json();
    expect(body.testMode).toBe(false);
    expect(body.revenueCents).toBe(300);
    expect(body.receiptCount).toBe(1);
  });

  test('zwei Kassen: Summe über beide', async () => {
    const s1 = await siteFor(a, provider);
    const { pairDevice } = await import('./support/device.js');
    const second = await pairDevice(a.app, provider.cookie, s1.businessId);
    a.now.value = new Date('2026-11-19T12:00:00.000Z');
    await send(a, s1, [['receipt', receipt('2026-11-19T09:00:00.000Z', { number: 1 })]]);
    await send(a, { token: second.token, deviceId: randomUUID() }, [
      ['receipt', receipt('2026-11-19T09:30:00.000Z', { number: 1, totalCents: 410, goodsCents: 410 })],
    ]);
    const body = (await overview(s1.businessId, 'today')).json();
    expect(body.revenueCents).toBe(990 + 410);
    expect(body.receiptCount).toBe(2);
    expect(body.cashCents).toBe(1400);
  });

  test('kein Bon: alles 0, leere Listen', async () => {
    const s = await siteFor(a, provider);
    for (const range of ['today', 'days7', 'days30']) {
      const body = (await overview(s.businessId, range)).json();
      expect(body).toMatchObject({
        range,
        testMode: true,
        revenueCents: 0,
        previousRevenueCents: 0,
        receiptCount: 0,
        voidCount: 0,
        cashCents: 0,
        cardCents: 0,
        topItems: [],
        byCategory: [],
      });
      expect(body.buckets.every((b: { cents: number }) => b.cents === 0)).toBe(true);
    }
    expect((await overview(s.businessId, 'today')).json().buckets).toEqual([]);
  });

  test('hasReceipts: falsch ohne Bon, wahr nach einem Bon vor mehr als 30 Tagen, der zweite Betrieb bleibt falsch', async () => {
    const s1 = await siteFor(a, provider, 'Mit altem Bon');
    const s2 = await siteFor(a, provider, 'Ohne Bon');
    a.now.value = new Date('2026-11-19T12:00:00.000Z');
    for (const range of ['today', 'days7', 'days30']) {
      expect((await overview(s1.businessId, range)).json().hasReceipts, range).toBe(false);
    }
    await send(a, s1, [['receipt', receipt('2026-09-01T09:00:00.000Z')]]);
    for (const range of ['today', 'days7', 'days30']) {
      const body = (await overview(s1.businessId, range)).json();
      expect(body.hasReceipts, range).toBe(true);
      expect(body.receiptCount, range).toBe(0);
      expect((await overview(s2.businessId, range)).json().hasReceipts, range).toBe(false);
    }
  });

  test('range unbekannt: 422', async () => {
    const s = await siteFor(a, provider);
    const res = await overview(s.businessId, 'year');
    expect(res.statusCode).toBe(422);
    expect(res.json().error.code).toBe('range_invalid');
  });

  test('zweiter Betrieb sieht nichts, Chef darf, nicht angemeldet: 401', async () => {
    const s1 = await siteFor(a, provider, 'Eins');
    const s2 = await siteFor(a, provider, 'Zwei');
    a.now.value = new Date('2026-11-19T12:00:00.000Z');
    await send(a, s1, [['receipt', receipt('2026-11-19T09:00:00.000Z')]]);
    const chef1 = await createChef(a.db, s1.businessId);
    const chef2 = await createChef(a.db, s2.businessId);
    expect((await overview(s1.businessId, 'today', chef1.cookie)).json().revenueCents).toBe(990);
    expect((await overview(s1.businessId, 'today', chef2.cookie)).statusCode).toBe(404);
    expect((await overview(s2.businessId, 'today')).json().revenueCents).toBe(0);
    const anonymous = await a.app.inject({ method: 'GET', url: `/api/admin/businesses/${s1.businessId}/overview?range=today` });
    expect(anonymous.statusCode).toBe(401);
  });
});
