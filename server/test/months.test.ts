import { randomUUID } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { afterAll, beforeAll, beforeEach, describe, expect, test } from 'vitest';
import { testApp, type TestApp } from './support/app.js';
import { createProvider, send, setTimeZone, siteFor, type Site } from './support/admin_data.js';
import { pairDevice } from './support/device.js';
import { sampleReceipt, sampleReceiptV2 } from './support/push.js';
import { sendStufe1b, voidOfV3 } from './support/stufe_1b.js';
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

/** Der Storno-Bon zu einem Bon in `v: 2`: alle Beträge mit Minus, das Trinkgeld bleibt bei seiner Person. */
function voidOfV2(r: Record<string, any>, o: Record<string, unknown>): Record<string, any> {
  const neg = (n: number) => (n === 0 ? 0 : -n);
  const gross = (g: Record<string, number>) => Object.fromEntries(Object.entries(g).map(([k, v]) => [k, neg(v)]));
  return {
    ...r,
    id: randomUUID(),
    kind: 'voided',
    voidsReceiptId: r.id,
    goodsCents: neg(r.goodsCents),
    depositCents: neg(r.depositCents),
    totalCents: neg(r.totalCents),
    tipCents: neg(r.tipCents),
    discountCents: neg(r.discountCents),
    lines: r.lines.map((l: Record<string, any>) => ({ ...l, quantity: neg(l.quantity), gross: gross(l.gross), discountCents: neg(l.discountCents) })),
    payments: r.payments.map((p: Record<string, any>) => ({ ...p, amountCents: neg(p.amountCents), givenCents: 0, changeCents: 0, tipCents: neg(p.tipCents) })),
    ...o,
  };
}

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
      // Die neuen Felder kennt die Abrechnung der App noch nicht: in diesem Beispiel ohne Trinkgeld und Rabatt.
      const { discountCount, discountCents, cardTipCents, cardAccountCents, tipsByStaff, voucherPaidCents, voucherSoldCount, voucherSoldCents, depositReturnCount, depositReturnCents, ...rest } = r.json();
      expect({ voucherPaidCents, voucherSoldCount, voucherSoldCents, depositReturnCount, depositReturnCents }, key).toEqual({ voucherPaidCents: 0, voucherSoldCount: 0, voucherSoldCents: 0, depositReturnCount: 0, depositReturnCents: 0 });
      const fileSummary = fx.expected.summaries[key] as { cardRevenueCents: number };
      expect({ discountCount, discountCents, cardTipCents, cardAccountCents, tipsByStaff }, key).toEqual({
        discountCount: 0, discountCents: 0, cardTipCents: 0, cardAccountCents: fileSummary.cardRevenueCents, tipsByStaff: [],
      });
      expect(rest, key).toEqual(fx.expected.summaries[key]);
    }
  });

  test('gemeinsames Beispiel mixed.json: bar, Karte, bar + Karte mit Trinkgeld und bar mit Rabatt wie die App', async () => {
    type Mixed = {
      now: string;
      timeZone: string;
      receipts: Record<string, unknown>[];
      expected: { months: unknown[]; summary: Record<string, unknown> };
    };
    const fx = JSON.parse(readFileSync(new URL('../../shared/fixtures/stats/mixed.json', import.meta.url), 'utf8')) as Mixed;
    const s = await siteFor(a, provider);
    await setTimeZone(a, s.businessId, fx.timeZone);
    await send(a, s, fx.receipts.map((r) => ['receipt', r]));
    a.now.value = new Date(fx.now);
    const chef = await createChef(a.db, s.businessId);

    expect((await list(s, chef.cookie)).json()).toEqual({ testMode: true, nextAvailable: '2026-08-01', months: fx.expected.months });
    const r = await summary(s, '2026-06', '2026-06', chef.cookie);
    expect(r.statusCode).toBe(200);
    const { voucherPaidCents, voucherSoldCount, voucherSoldCents, depositReturnCount, depositReturnCents, ...rest } = r.json();
    expect({ voucherPaidCents, voucherSoldCount, voucherSoldCents, depositReturnCount, depositReturnCents }).toEqual({ voucherPaidCents: 0, voucherSoldCount: 0, voucherSoldCents: 0, depositReturnCount: 0, depositReturnCents: 0 });
    expect(rest).toEqual(fx.expected.summary);
    // Von Hand: ein Bon mit Rabatt (1,19 € auf der Huhn Bowl, 1,65 € auf den Bon); 0,80 € Trinkgeld für Anna auf dem
    // gemischten Bon; am Kartenkonto 9,65 + 8,20 + 0,80. Der gemischte Bon zählt bei bar und bei Karte, im Gesamt einmal.
    expect(r.json()).toMatchObject({
      receiptCount: 4,
      cashReceiptCount: 3,
      cardReceiptCount: 2,
      revenueCents: 1930 + 1820 + 1536,
      discountCount: 1,
      discountCents: 119 + 165,
      cardTipCents: 80,
      cardAccountCents: 965 + 820 + 80,
      tipsByStaff: [{ staffName: 'Anna', cents: 80 }],
    });
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
    const { voucherPaidCents, voucherSoldCount, voucherSoldCents, depositReturnCount, depositReturnCents, ...september } = (await summary(s, '2026-09', '2026-09')).json();
    expect({ voucherPaidCents, voucherSoldCount, voucherSoldCents, depositReturnCount, depositReturnCents }).toEqual({ voucherPaidCents: 0, voucherSoldCount: 0, voucherSoldCents: 0, depositReturnCount: 0, depositReturnCents: 0 });
    expect(september).toEqual({
      from: '2026-09', to: '2026-09', testMode: true,
      receiptCount: 2, cashReceiptCount: 1, cardReceiptCount: 1, voidCount: 0, voidedCents: 0,
      revenueCents: 1795, cashRevenueCents: 1190, cardRevenueCents: 605, depositCents: 25,
      discountCount: 0, discountCents: 0, cardTipCents: 0, cardAccountCents: 605, tipsByStaff: [],
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

  test('Zusammenfassung mit Trinkgeld je Person und Rabatt', async () => {
    const s = await siteFor(a, provider);
    a.now.value = new Date('2026-11-18T12:00:00.000Z');
    const cash = receipt('2026-09-30T08:00:00.000Z', { number: 1 });
    const mixed = sampleReceiptV2({ createdAt: '2026-09-30T09:00:00.000Z', number: 2 });
    // Der Storno im Oktober storniert Chefin, das Trinkgeld bleibt bei Anna, als Minus.
    const storno = voidOfV2(mixed, { createdAt: '2026-10-02T09:00:00.000Z', number: 3 });
    await send(a, s, [['receipt', cash], ['receipt', mixed], ['receipt', storno]]);

    expect((await summary(s, '2026-09', '2026-09')).json()).toMatchObject({
      receiptCount: 2, revenueCents: 2526, cashRevenueCents: 1990, cardRevenueCents: 536, cashReceiptCount: 2, cardReceiptCount: 1,
      discountCount: 1, discountCents: 284, cardTipCents: 64, cardAccountCents: 600,
      tipsByStaff: [{ staffName: 'Anna', cents: 64 }],
    });
    const october = (await summary(s, '2026-10', '2026-10')).json();
    expect(october).toMatchObject({
      receiptCount: -1, voidCount: 1, revenueCents: -1536, cashRevenueCents: -1000, cardRevenueCents: -536,
      cashReceiptCount: -1, cardReceiptCount: -1,
      discountCount: -1, discountCents: -284, cardTipCents: -64, cardAccountCents: -600,
    });
    expect(october.tipsByStaff).toEqual([{ staffName: 'Anna', cents: -64 }]);
    // Über beide Monate hebt sich alles auf: Zeilen mit 0 fehlen.
    expect((await summary(s, '2026-09', '2026-10')).json()).toMatchObject({
      receiptCount: 1, revenueCents: 990, cashRevenueCents: 990, cardRevenueCents: 0,
      discountCount: 0, discountCents: 0, cardTipCents: 0, cardAccountCents: 0, tipsByStaff: [],
    });
  });

  test('Trinkgeld je Person: gruppiert nach Kennung, Name des spätesten Bons, nach Name sortiert', async () => {
    const s = await siteFor(a, provider);
    a.now.value = new Date('2026-11-18T12:00:00.000Z');
    const withTip = (createdAt: string, number: number, staffId: string, staffName: string, tip: number) => {
      const r = sampleReceiptV2({ createdAt, number });
      return { ...r, tipCents: tip, payments: [r.payments[0], { ...r.payments[1], tipCents: tip, tipStaffId: staffId, tipStaffName: staffName }] };
    };
    await send(a, s, [
      ['receipt', withTip('2026-10-05T09:00:00.000Z', 1, 'anna', 'Anna', 100)],
      ['receipt', withTip('2026-10-06T09:00:00.000Z', 2, 'ben', 'Ben', 50)],
      ['receipt', withTip('2026-10-07T09:00:00.000Z', 3, 'anna', 'Anna Berger', 30)],
      ['receipt', receipt('2026-10-08T09:00:00.000Z', { number: 4 })],
    ]);
    expect((await summary(s, '2026-10', '2026-10')).json()).toMatchObject({
      cardTipCents: 180, cardRevenueCents: 3 * 536, cardAccountCents: 3 * 536 + 180,
      tipsByStaff: [{ staffName: 'Anna Berger', cents: 130 }, { staffName: 'Ben', cents: 50 }],
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

describe('Monate mit Gutscheinen und Pfand zurück (Stufe 1b)', () => {
  const NEW = ['voucherPaidCents', 'voucherSoldCount', 'voucherSoldCents', 'depositReturnCount', 'depositReturnCents'] as const;
  const newFigures = (body: Record<string, unknown>) => NEW.map((k) => body[k]);

  test('Monat mit Gutschein-Verkauf, Gutschein-Zahlung und Pfand-Auszahlung: Umsatz ohne verkauften Gutschein, die fünf neuen Zahlen stimmen', async () => {
    const s = await siteFor(a, provider);
    const fx = await sendStufe1b(a, s);
    a.now.value = new Date(fx.now);
    const chef = await createChef(a.db, s.businessId);

    const r = await summary(s, '2026-10', '2026-10', chef.cookie);
    expect(r.statusCode).toBe(200);
    const body = r.json();
    // Die ganze Abrechnung wie die App (gemeinsame Datei stufe_1b.json).
    expect(body).toEqual(fx.expected.summary);
    // Von Hand: 18,20 + 25,00 + 9,65 − 0,75 ohne den Gutschein über 25,00.
    expect(body.revenueCents).toBe(2710);
    expect(newFigures(body)).toEqual([965, 1, 2500, 3, 75]);
    expect([body.cashRevenueCents, body.cardRevenueCents]).toEqual([4245, 0]);
    // Der Bon nur mit Gutschein zählt weder bei bar noch bei Karte.
    expect([body.receiptCount, body.cashReceiptCount, body.cardReceiptCount]).toEqual([4, 3, 0]);
    expect(body.cashRevenueCents + body.cardRevenueCents + body.voucherPaidCents - body.voucherSoldCents).toBe(body.revenueCents);
    expect(body.rows).toEqual([{ key: '2026-10-14', receiptCount: 4, revenueCents: 2710 }]);
    expect((await list(s, chef.cookie)).json().months).toEqual(fx.expected.months);
  });

  test('Storno von Gutschein-Zahlung und Pfand-Auszahlung im nächsten Monat: die neuen Zahlen ziehen ab', async () => {
    const s = await siteFor(a, provider);
    const fx = await sendStufe1b(a, s);
    const [, , c, d] = fx.receipts as [unknown, unknown, Record<string, any>, Record<string, any>];
    const at = '2026-11-02T09:00:00.000Z';
    await send(a, s, [
      ['receipt', voidOfV3(c, { id: randomUUID(), number: 5, createdAt: at, businessDayId: null })],
      ['receipt', voidOfV3(d, { id: randomUUID(), number: 6, createdAt: at, businessDayId: null })],
    ]);
    a.now.value = new Date('2026-12-05T11:00:00.000Z');
    const chef = await createChef(a.db, s.businessId);

    const nov = (await summary(s, '2026-11', '2026-11', chef.cookie)).json();
    expect([nov.revenueCents, nov.cashRevenueCents, nov.cardRevenueCents]).toEqual([-890, 75, 0]);
    expect(newFigures(nov)).toEqual([-965, 0, 0, -3, -75]);
    expect([nov.receiptCount, nov.voidCount, nov.voidedCents]).toEqual([-2, 2, 890]);
    const both = (await summary(s, '2026-10', '2026-11', chef.cookie)).json();
    // Übrig bleiben A (bar 18,20) und B (Gutschein über 25,00 bar verkauft).
    expect([both.revenueCents, both.cashRevenueCents, both.cardRevenueCents]).toEqual([1820, 4320, 0]);
    expect(newFigures(both)).toEqual([0, 1, 2500, 0, 0]);
    expect(both.rows).toEqual([
      { key: '2026-10', receiptCount: 4, revenueCents: 2710 },
      { key: '2026-11', receiptCount: -2, revenueCents: -890 },
    ]);
  });

  test('Monat nur mit Bons in v: 1 und v: 2: die alten Zahlen wie bisher, die fünf neuen 0', async () => {
    const s = await siteFor(a, provider);
    a.now.value = new Date('2026-12-15T12:00:00.000Z');
    await send(a, s, [
      ['receipt', receipt('2026-10-05T09:00:00.000Z', { number: 1 })],
      ['receipt', sampleReceiptV2({ createdAt: '2026-10-06T09:00:00.000Z', number: 2 })],
    ]);
    const body = (await summary(s, '2026-10', '2026-10')).json();
    expect(body).toMatchObject({ receiptCount: 2, revenueCents: 990 + 1536, cashRevenueCents: 990 + 1000, cardRevenueCents: 536 });
    expect([body.cashReceiptCount, body.cardReceiptCount]).toEqual([2, 1]);
    expect(newFigures(body)).toEqual([0, 0, 0, 0, 0]);
  });
});
