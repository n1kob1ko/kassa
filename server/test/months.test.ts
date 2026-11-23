import { randomUUID } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { afterAll, beforeAll, beforeEach, describe, expect, test } from 'vitest';
import { testApp, type TestApp } from './support/app.js';
import { createProvider, send, setTimeZone, siteFor, type Site } from './support/admin_data.js';
import { pairDevice } from './support/device.js';
import { sampleReceipt } from './support/push.js';
import { authed, createChef, type TestUser } from './support/users.js';

let a: TestApp;
let provider: TestUser;

beforeAll(async () => {
  a = await testApp();
  provider = await createProvider(a.app, a.db);
});
// Die Uhr geht in einigen Tests weit zurück oder vor: jeder Test beginnt wieder bei der Standardzeit.
beforeEach(() => {
  a.now.value = new Date('2026-11-18T10:00:00Z');
});
afterAll(async () => {
  await a.close();
});

const get = (url: string, cookie = provider.cookie) => a.app.inject({ method: 'GET', url, headers: authed(cookie) });
const list = (s: Site, cookie?: string) => get(`/api/admin/businesses/${s.businessId}/months`, cookie);
const summary = (s: Site, from: string, to: string, cookie?: string) =>
  get(`/api/admin/businesses/${s.businessId}/months/summary?from=${from}&to=${to}`, cookie);

const receipt = (createdAt: string, o: Record<string, unknown> = {}) =>
  sampleReceipt({ id: randomUUID(), createdAt, ...o });

type Fixture = {
  now: string;
  timeZone: string;
  receipts: Record<string, unknown>[];
  expected: { months: unknown[]; summaries: Record<string, unknown> };
};

describe('Monate', () => {
  test('gemeinsames Beispiel: Liste und jede Zusammenfassung wie die App', async () => {
    const fx = JSON.parse(readFileSync(new URL('../../shared/fixtures/stats/months.json', import.meta.url), 'utf8')) as Fixture;
    const s = await siteFor(a, provider);
    await setTimeZone(a, s.businessId, fx.timeZone);
    for (let i = 0; i < fx.receipts.length; i += 50) await send(a, s, fx.receipts.slice(i, i + 50).map((r) => ['receipt', r]));
    a.now.value = new Date(fx.now);
    // Eigene Sitzung: sie gleitet mit der Uhr des Beispiels und soll die des Anbieters nicht verkürzen.
    const chef = await createChef(a.db, s.businessId);

    const res = await list(s, chef.cookie);
    expect(res.statusCode).toBe(200);
    expect(res.json()).toEqual({ testMode: true, nextAvailable: '2026-04-01', months: fx.expected.months });
    const keys = Object.keys(fx.expected.summaries);
    expect(keys.length).toBeGreaterThanOrEqual(5);
    for (const key of keys) {
      const [from, to] = key.split('..') as [string, string];
      const r = await summary(s, from, to, chef.cookie);
      expect(r.statusCode, key).toBe(200);
      expect(r.json(), key).toEqual(fx.expected.summaries[key]);
    }
  });

  test('Mitternacht in der Zeitzone des Betriebs: 31.10. 23:30 Wien zählt zum Oktober, 1.11. 00:30 zum November', async () => {
    const s = await siteFor(a, provider);
    a.now.value = new Date('2026-12-15T12:00:00.000Z');
    await send(a, s, [
      ['receipt', receipt('2026-10-31T22:30:00.000Z', { number: 1, totalCents: 500, goodsCents: 500 })],
      ['receipt', receipt('2026-10-31T23:30:00.000Z', { number: 2, totalCents: 700, goodsCents: 700 })],
    ]);
    expect((await list(s)).json().months).toEqual([
      { month: '2026-11', receiptCount: 1, revenueCents: 700 },
      { month: '2026-10', receiptCount: 1, revenueCents: 500 },
    ]);
    expect((await summary(s, '2026-10', '2026-10')).json().rows).toEqual([{ key: '2026-10-31', receiptCount: 1, revenueCents: 500 }]);
    expect((await summary(s, '2026-11', '2026-11')).json().rows).toEqual([{ key: '2026-11-01', receiptCount: 1, revenueCents: 700 }]);
  });

  test('Wechsel der Sommerzeit: Bon am 25.10.2026 02:30 Wien (zweimal) zählt einmal im Oktober', async () => {
    const s = await siteFor(a, provider);
    a.now.value = new Date('2026-12-15T12:00:00.000Z');
    await send(a, s, [
      ['receipt', receipt('2026-10-25T00:30:00.000Z', { number: 1, totalCents: 500, goodsCents: 500 })], // 02:30 Sommerzeit
      ['receipt', receipt('2026-10-25T01:30:00.000Z', { number: 2, totalCents: 700, goodsCents: 700 })], // 02:30 Winterzeit
    ]);
    const months = (await list(s)).json().months;
    expect(months).toEqual([
      { month: '2026-11', receiptCount: 0, revenueCents: 0 },
      { month: '2026-10', receiptCount: 2, revenueCents: 1200 },
    ]);
    expect((await summary(s, '2026-10', '2026-10')).json().rows).toEqual([{ key: '2026-10-25', receiptCount: 2, revenueCents: 1200 }]);
  });

  test('laufender Monat fehlt in der Liste und liefert 404', async () => {
    const s = await siteFor(a, provider);
    a.now.value = new Date('2026-11-18T12:00:00.000Z');
    await send(a, s, [
      ['receipt', receipt('2026-10-05T09:00:00.000Z', { number: 1 })],
      ['receipt', receipt('2026-11-02T09:00:00.000Z', { number: 2 })],
      ['receipt', receipt('2026-12-02T09:00:00.000Z', { number: 3 })],
    ]);
    const body = (await list(s)).json();
    expect(body.months.map((m: { month: string }) => m.month)).toEqual(['2026-10']);
    expect(body.nextAvailable).toBe('2026-12-01');
    for (const [from, to] of [['2026-11', '2026-11'], ['2026-12', '2026-12'], ['2026-10', '2026-11']] as const) {
      const r = await summary(s, from, to);
      expect(r.statusCode, `${from}..${to}`).toBe(404);
      expect(r.json().error).toEqual({ code: 'not_found', message: 'Diese Abrechnung gibt es nicht.' });
    }
    expect((await summary(s, '2026-10', '2026-10')).statusCode).toBe(200);
  });

  test('nur Bons im laufenden Monat: leere Liste', async () => {
    const s = await siteFor(a, provider);
    a.now.value = new Date('2026-11-18T12:00:00.000Z');
    await send(a, s, [['receipt', receipt('2026-11-02T09:00:00.000Z', { number: 1 })]]);
    expect((await list(s)).json()).toEqual({ testMode: true, nextAvailable: '2026-12-01', months: [] });
  });

  test('Testbons und echte gemischt: nur echte zählen, testMode false; nur Testbons: testMode true', async () => {
    const s = await siteFor(a, provider);
    a.now.value = new Date('2026-11-18T12:00:00.000Z');
    await send(a, s, [['receipt', receipt('2026-09-05T09:00:00.000Z', { number: 1, test: true, totalCents: 111, goodsCents: 111 })]]);
    let body = (await list(s)).json();
    expect(body.testMode).toBe(true);
    expect(body.months).toEqual([
      { month: '2026-10', receiptCount: 0, revenueCents: 0 },
      { month: '2026-09', receiptCount: 1, revenueCents: 111 },
    ]);
    expect((await summary(s, '2026-09', '2026-09')).json().testMode).toBe(true);
    await send(a, s, [
      ['receipt', receipt('2026-10-05T09:00:00.000Z', { number: 2, test: false, totalCents: 300, goodsCents: 300 })],
    ]);
    body = (await list(s)).json();
    expect(body.testMode).toBe(false);
    // Der Testbon im September zählt nicht mehr, der erste Monat ist der des ersten echten Bons.
    expect(body.months).toEqual([{ month: '2026-10', receiptCount: 1, revenueCents: 300 }]);
    const r = await summary(s, '2026-10', '2026-10');
    expect(r.json()).toMatchObject({ testMode: false, receiptCount: 1, revenueCents: 300 });
    expect((await summary(s, '2026-09', '2026-10')).statusCode).toBe(404);
  });

  test('Betrieb ohne Bon: leere Liste, nextAvailable ist der Erste des Folgemonats', async () => {
    const s = await siteFor(a, provider);
    a.now.value = new Date('2026-11-30T23:30:00.000Z'); // in Wien schon der 1. Dezember
    expect((await list(s)).json()).toEqual({ testMode: true, nextAvailable: '2027-01-01', months: [] });
    a.now.value = new Date('2026-11-18T12:00:00.000Z');
    expect((await list(s)).json()).toEqual({ testMode: true, nextAvailable: '2026-12-01', months: [] });
    expect((await summary(s, '2026-10', '2026-10')).statusCode).toBe(404);
  });

  test.each(['2026-13', 'abc', '2026-1', ''])('from=%s: 422', async (from) => {
    const s = await siteFor(a, provider);
    a.now.value = new Date('2026-11-18T12:00:00.000Z');
    await send(a, s, [['receipt', receipt('2026-10-05T09:00:00.000Z', { number: 1 })]]);
    for (const r of [await summary(s, from, '2026-10'), await summary(s, '2026-10', from)]) {
      expect(r.statusCode).toBe(422);
      expect(r.json().error).toEqual({ code: 'period_invalid', message: 'Der Zeitraum ist unbekannt.' });
    }
    const missing = await get(`/api/admin/businesses/${s.businessId}/months/summary`);
    expect(missing.statusCode).toBe(422);
  });

  test('to vor from: 422; Monat vor dem ersten: 404', async () => {
    const s = await siteFor(a, provider);
    a.now.value = new Date('2026-11-18T12:00:00.000Z');
    await send(a, s, [['receipt', receipt('2026-09-05T09:00:00.000Z', { number: 1 })]]);
    const reversed = await summary(s, '2026-10', '2026-09');
    expect(reversed.statusCode).toBe(422);
    expect(reversed.json().error.code).toBe('period_invalid');
    const early = await summary(s, '2026-08', '2026-09');
    expect(early.statusCode).toBe(404);
    expect(early.json().error.code).toBe('not_found');
  });

  test('Storno im Folgemonat, Pfand, Steuer und Zahlungsarten in der Zusammenfassung', async () => {
    const s = await siteFor(a, provider);
    a.now.value = new Date('2026-11-18T12:00:00.000Z');
    const sale = receipt('2026-09-30T09:00:00.000Z', {
      number: 1, totalCents: 1190, goodsCents: 1190,
      lines: [{ position: 0, itemId: 'x', name: 'X', info: null, unitPriceCents: 1190, quantity: 1, unitDepositCents: 0, gross: { '20': 0, '10': 1190, '13': 0, '0': 0, '19': 0 }, options: [] }],
    });
    const card = receipt('2026-09-30T10:00:00.000Z', {
      number: 2, totalCents: 605, goodsCents: 580, depositCents: 25,
      lines: [{ position: 0, itemId: 'y', name: 'Y', info: null, unitPriceCents: 290, quantity: 2, unitDepositCents: 0, gross: { '20': 580, '10': 0, '13': 0, '0': 0, '19': 0 }, options: [] }],
      payment: { kind: 'card', amountCents: 605, givenCents: 0, changeCents: 0, provider: 'sumup', providerTxCode: 'T', cardScheme: 'VISA', cardLast4: '4242' },
    });
    const storno = receipt('2026-10-02T09:00:00.000Z', {
      number: 3, kind: 'voided', voidsReceiptId: sale.id, totalCents: -1190, goodsCents: -1190,
      lines: [{ position: 0, itemId: 'x', name: 'X', info: null, unitPriceCents: 1190, quantity: -1, unitDepositCents: 0, gross: { '20': 0, '10': -1190, '13': 0, '0': 0, '19': 0 }, options: [] }],
    });
    await send(a, s, [['receipt', sale], ['receipt', card], ['receipt', storno]]);
    expect((await summary(s, '2026-09', '2026-09')).json()).toEqual({
      from: '2026-09', to: '2026-09', testMode: true,
      receiptCount: 2, cashReceiptCount: 1, cardReceiptCount: 1, voidCount: 0, voidedCents: 0,
      revenueCents: 1795, cashRevenueCents: 1190, cardRevenueCents: 605, depositCents: 25,
      taxLines: [
        { percent: 20, grossCents: 580, netCents: 483, taxCents: 97 },
        { percent: 10, grossCents: 1190, netCents: 1082, taxCents: 108 },
      ],
      rows: [{ key: '2026-09-30', receiptCount: 2, revenueCents: 1795 }],
    });
    // Zwei Monate: Steuer je Monat, dann addiert. Der Satz 10 % hebt sich auf und fehlt.
    expect((await summary(s, '2026-09', '2026-10')).json()).toMatchObject({
      receiptCount: 1, cashReceiptCount: 0, cardReceiptCount: 1, voidCount: 1, voidedCents: 1190,
      revenueCents: 605, cashRevenueCents: 0, cardRevenueCents: 605,
      taxLines: [{ percent: 20, grossCents: 580, netCents: 483, taxCents: 97 }],
      rows: [{ key: '2026-09', receiptCount: 2, revenueCents: 1795 }, { key: '2026-10', receiptCount: -1, revenueCents: -1190 }],
    });
  });

  test('fremder Betrieb: 404 wie bei den Tagen; ohne Anmeldung 401', async () => {
    const s1 = await siteFor(a, provider, 'Eins');
    const s2 = await siteFor(a, provider, 'Zwei');
    a.now.value = new Date('2026-11-18T12:00:00.000Z');
    await send(a, s1, [['receipt', receipt('2026-10-05T09:00:00.000Z', { number: 1 })]]);
    const chef1 = await createChef(a.db, s1.businessId);
    const chef2 = await createChef(a.db, s2.businessId);
    expect((await list(s1, chef1.cookie)).statusCode).toBe(200);
    expect((await summary(s1, '2026-10', '2026-10', chef1.cookie)).statusCode).toBe(200);
    expect((await list(s1, chef2.cookie)).statusCode).toBe(404);
    expect((await summary(s1, '2026-10', '2026-10', chef2.cookie)).statusCode).toBe(404);
    expect((await list(s2)).json().months).toEqual([]);
    for (const url of [`/api/admin/businesses/${s1.businessId}/months`, `/api/admin/businesses/${s1.businessId}/months/summary?from=2026-10&to=2026-10`]) {
      expect((await a.app.inject({ method: 'GET', url })).statusCode).toBe(401);
    }
  });

  test('mehrere Kassen: Summe des Betriebs', async () => {
    const s = await siteFor(a, provider);
    const second = await pairDevice(a.app, provider.cookie, s.businessId);
    a.now.value = new Date('2026-11-18T12:00:00.000Z');
    await send(a, s, [['receipt', receipt('2026-10-05T09:00:00.000Z', { number: 1 })]]);
    await send(a, { token: second.token, deviceId: randomUUID() }, [
      ['receipt', receipt('2026-10-05T09:30:00.000Z', { number: 1, totalCents: 410, goodsCents: 410 })],
    ]);
    expect((await list(s)).json().months).toEqual([{ month: '2026-10', receiptCount: 2, revenueCents: 1400 }]);
    expect((await summary(s, '2026-10', '2026-10')).json()).toMatchObject({ receiptCount: 2, revenueCents: 1400, cashRevenueCents: 1400 });
  });
});
