import { randomUUID } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { afterAll, beforeAll, describe, expect, test } from 'vitest';
import { withBusiness } from '../src/db/tenant.js';
import { testApp, type TestApp } from './support/app.js';
import { allKeys, createProvider, FORBIDDEN_KEYS, send, setTimeZone, siteFor } from './support/admin_data.js';
import { sampleReceipt, sampleReceiptV2 } from './support/push.js';
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

  test('gemeinsames Beispiel mixed.json: bar, Karte und bar + Karte mit Trinkgeld wie die App', async () => {
    const fx = JSON.parse(readFileSync(new URL('../../shared/fixtures/stats/mixed.json', import.meta.url), 'utf8')) as Omit<Fixture, 'expected'> & {
      expected: { overview: Record<string, Record<string, unknown>> };
    };
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
    // Eigene Sitzung: sie gleitet mit der Uhr des Beispiels und soll die des Anbieters nicht verkürzen.
    const chef = await createChef(a.db, s.businessId);
    const before = a.now.value;
    a.now.value = new Date(fx.now);
    const fields = ['revenueCents', 'previousRevenueCents', 'receiptCount', 'voidCount', 'buckets', 'cashCents', 'cardCents', 'topItems', 'byCategory'];
    for (const range of ['today', 'days7', 'days30']) {
      const body = (await overview(s.businessId, range, chef.cookie)).json();
      for (const k of fields) expect(body[k], `${range}.${k}`).toEqual(fx.expected.overview[range]![k]);
    }
    // Von Hand: Umsatz ohne Trinkgeld 9,65 + 9,65 + 18,20; bar 9,65 + 10,00; Karte 9,65 + 8,20.
    expect((await overview(s.businessId, 'days7', chef.cookie)).json()).toMatchObject({ revenueCents: 3750, cashCents: 1965, cardCents: 1785 });
    a.now.value = before;
  });

  test('Bon in v: 2: Umsatz nach Rabatt ohne Trinkgeld, Bar und Karte aus den Zahlungen, Artikel nach Rabatt', async () => {
    const s = await siteFor(a, provider);
    a.now.value = new Date('2026-11-19T12:00:00.000Z');
    await send(a, s, [['receipt', sampleReceiptV2({ createdAt: '2026-11-19T09:00:00.000Z' })]]);
    const body = (await overview(s.businessId, 'today')).json();
    expect(body).toMatchObject({ revenueCents: 1536, receiptCount: 1, cashCents: 1000, cardCents: 536 });
    expect(body.topItems).toEqual([
      { name: 'Cola 0,33 l', quantity: 2, cents: 522 },
      { name: 'Huhn Bowl', quantity: 1, cents: 964 },
    ]);
    expect(body.byCategory).toEqual([{ name: 'Sonstiges', cents: 1486 }, { name: 'Pfand', cents: 50 }]);

    // Ein Bon in v: 1 rechnet wie bisher.
    const old = await siteFor(a, provider);
    await send(a, old, [['receipt', receipt('2026-11-19T09:00:00.000Z')]]);
    const before = (await overview(old.businessId, 'today')).json();
    expect(before).toMatchObject({ revenueCents: 990, receiptCount: 1, cashCents: 990, cardCents: 0 });
    expect(before.topItems).toEqual([{ name: 'Huhn Bowl', quantity: 1, cents: 990 }]);
    expect(before.byCategory).toEqual([{ name: 'Sonstiges', cents: 990 }]);
  });

  test('freier Betrag: "Diverses 20 %" bei meistverkauft, "Sonstiges" bei den Kategorien', async () => {
    const s = await siteFor(a, provider);
    await withBusiness(a.db, s.businessId, async (c) => {
      await c.query(
        `insert into categories (business_id, id, name, position, change_seq) values ($1, 'getraenke', 'Getränke', 0, nextval('change_seq'))`,
        [s.businessId],
      );
      await c.query(
        `insert into items (business_id, id, name, price_cents, category_id, tax_percent, deposit_cents, position, change_seq)
         values ($1, 'cola', 'Cola 0,33 l', 290, 'getraenke', 20, 0, 0, nextval('change_seq'))`,
        [s.businessId],
      );
    });
    const gross = (cents: number, rate: string) => ({ '20': 0, '10': 0, '13': 0, '0': 0, '19': 0, [rate]: cents });
    const line = (position: number, itemId: string, name: string, unitPriceCents: number, quantity: number, rate: string) => ({
      position,
      itemId,
      name,
      info: null,
      unitPriceCents,
      quantity,
      unitDepositCents: 0,
      gross: gross(unitPriceCents * quantity, rate),
      options: [],
      discountCents: 0,
      discount: null,
    });
    const base = sampleReceiptV2();
    a.now.value = new Date('2026-11-19T12:00:00.000Z');
    await send(a, s, [
      [
        'receipt',
        {
          ...base,
          createdAt: '2026-11-19T09:00:00.000Z',
          goodsCents: 2530,
          depositCents: 0,
          totalCents: 2530,
          tipCents: 0,
          discountCents: 0,
          discount: null,
          lines: [
            line(0, 'cola', 'Cola 0,33 l', 290, 2, '20'),
            line(1, 'open-amount-20', 'Diverses 20 %', 1250, 1, '20'),
            line(2, 'open-amount-20', 'Diverses 20 %', 300, 1, '20'),
            line(3, 'open-amount-10', 'Diverses 10 %', 400, 1, '10'),
          ],
          payments: [{ ...base.payments[0], amountCents: 2530, givenCents: 3000, changeCents: 470 }],
        },
      ],
    ]);
    const body = (await overview(s.businessId, 'today')).json();
    expect(body).toMatchObject({ revenueCents: 2530, receiptCount: 1, cashCents: 2530, cardCents: 0 });
    expect(body.topItems).toEqual([
      { name: 'Diverses 20 %', quantity: 2, cents: 1550 },
      { name: 'Cola 0,33 l', quantity: 2, cents: 580 },
      { name: 'Diverses 10 %', quantity: 1, cents: 400 },
    ]);
    expect(body.byCategory).toEqual([{ name: 'Sonstiges', cents: 1950 }, { name: 'Getränke', cents: 580 }]);
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
