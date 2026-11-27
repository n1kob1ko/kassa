import { randomUUID } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, test } from 'vitest';
import { testApp, type TestApp } from './support/app.js';
import { allKeys, createProvider, FORBIDDEN_KEYS, send, siteFor, type Site } from './support/admin_data.js';
import { sampleDay, sampleReceipt, sampleReceiptV2 } from './support/push.js';
import { sendStufe1b } from './support/stufe_1b.js';
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

const get = (url: string, cookie = provider.cookie) => a.app.inject({ method: 'GET', url, headers: authed(cookie) });
const list = (s: Site, cookie?: string) => get(`/api/admin/businesses/${s.businessId}/days`, cookie);
const detail = (s: Site, id: string, cookie?: string) => get(`/api/admin/businesses/${s.businessId}/days/${id}`, cookie);
const movement = (dayId: string, o: Record<string, unknown> = {}) => ({
  id: randomUUID(), businessDayId: dayId, kind: 'withdrawal', amountCents: 2000, reason: 'bank',
  createdAt: '2026-11-19T09:00:00.000Z', staffId: 'chefin', staffName: 'Chefin', ...o,
});

describe('Tage', () => {
  test('offener Tag: Liste und Detail', async () => {
    const s = await siteFor(a, provider);
    const day = sampleDay();
    await send(a, s, [['day', day]]);
    const res = await list(s);
    expect(res.statusCode).toBe(200);
    expect(res.json()).toEqual({
      days: [{ id: day.id, registerName: 'Kassa 1', openedAt: '2026-11-19T08:00:00.000Z', closedAt: null, expectedCents: null, countedCents: null, differenceCents: null, closedByName: null, revenueCents: 0 }],
    });
    expect((await detail(s, day.id)).json()).toMatchObject({
      id: day.id, closedAt: null, openingFloatCents: 10000, leftInDrawerCents: null, movements: [], receiptCount: 0, revenueCents: 0,
    });
  });

  test('abgeschlossener Tag mit Bewegungen und Umsatz im Detail', async () => {
    const s = await siteFor(a, provider);
    const open = sampleDay();
    const closed = { ...open, closedAt: '2026-11-19T17:00:00.000Z', countedCents: 18000, leftInDrawerCents: 10000, expectedCents: 18500, differenceCents: -500, closedByName: 'Chefin' };
    const m1 = movement(open.id, { createdAt: '2026-11-19T12:00:00.000Z', kind: 'deposit', amountCents: 500, reason: 'Wechselgeld' });
    const m2 = movement(open.id, { createdAt: '2026-11-19T10:00:00.000Z' });
    const sale = sampleReceipt({ businessDayId: open.id, number: 1 });
    const storno = sampleReceipt({ businessDayId: open.id, number: 2, kind: 'voided', voidsReceiptId: sale.id, totalCents: -990, goodsCents: -990 });
    const sale2 = sampleReceipt({ businessDayId: open.id, number: 3, totalCents: 400, goodsCents: 400, createdAt: '2026-11-19T11:00:00.000Z' });
    const other = sampleReceipt({ businessDayId: randomUUID(), number: 4 });
    await send(a, s, [['day', open], ['cash_movement', m1], ['cash_movement', m2], ['receipt', sale], ['receipt', storno], ['receipt', sale2], ['receipt', other]]);
    await send(a, s, [['day', closed]]);
    const days = (await list(s)).json().days;
    expect(days).toHaveLength(1);
    expect(days[0]).toMatchObject({ closedAt: '2026-11-19T17:00:00.000Z', expectedCents: 18500, countedCents: 18000, differenceCents: -500, closedByName: 'Chefin', revenueCents: 400 });
    const d = (await detail(s, open.id)).json();
    expect(d).toMatchObject({ openingFloatCents: 10000, leftInDrawerCents: 10000, receiptCount: 1, revenueCents: 400 });
    expect(d.movements).toEqual([
      { kind: 'withdrawal', amountCents: 2000, reason: 'bank', createdAt: '2026-11-19T10:00:00.000Z', staffName: 'Chefin' },
      { kind: 'deposit', amountCents: 500, reason: 'Wechselgeld', createdAt: '2026-11-19T12:00:00.000Z', staffName: 'Chefin' },
    ]);
  });

  test('Umsatz in der Liste wie im Detail: je Tag, Stornos ziehen ab, Sonderbelege und andere Betriebe zählen nicht', async () => {
    const s = await siteFor(a, provider, 'Umsatz');
    const other = await siteFor(a, provider, 'Fremd');
    const monday = sampleDay({ openedAt: '2026-11-16T08:00:00.000Z' });
    const tuesday = sampleDay({ openedAt: '2026-11-17T08:00:00.000Z' });
    const quiet = sampleDay({ openedAt: '2026-11-18T08:00:00.000Z' });
    const sale = sampleReceipt({ businessDayId: monday.id, number: 1 });
    const storno = sampleReceipt({ businessDayId: monday.id, number: 2, kind: 'voided', voidsReceiptId: sale.id, totalCents: -990, goodsCents: -990 });
    const card = sampleReceipt({ businessDayId: monday.id, number: 3, totalCents: 1250, goodsCents: 1250 });
    const big = sampleReceipt({ businessDayId: tuesday.id, number: 4, totalCents: 3075, goodsCents: 3050, depositCents: 25 });
    const zero = sampleReceipt({ businessDayId: null, number: 5, kind: 'zero', totalCents: 0, goodsCents: 0, lines: [], payment: null });
    // Derselbe Tag in einem anderen Betrieb: sein Umsatz darf nicht mitzählen.
    const foreign = sampleReceipt({ businessDayId: tuesday.id, number: 1, totalCents: 99_900, goodsCents: 99_900 });
    await send(a, s, [['day', monday], ['day', tuesday], ['day', quiet], ['receipt', sale], ['receipt', storno], ['receipt', card], ['receipt', big], ['receipt', zero]]);
    await send(a, other, [['receipt', foreign]]);

    const days = (await list(s)).json().days as { id: string; revenueCents: number }[];
    expect(days.map((d) => [d.id, d.revenueCents])).toEqual([[quiet.id, 0], [tuesday.id, 3075], [monday.id, 1250]]);
    for (const d of days) expect((await detail(s, d.id)).json().revenueCents).toBe(d.revenueCents);
  });

  test('neueste zuerst, unbekannter Tag: 404', async () => {
    const s = await siteFor(a, provider);
    const old = sampleDay({ openedAt: '2026-11-17T08:00:00.000Z' });
    const recent = sampleDay({ openedAt: '2026-11-19T08:00:00.000Z' });
    await send(a, s, [['day', old], ['day', recent]]);
    expect((await list(s)).json().days.map((d: { id: string }) => d.id)).toEqual([recent.id, old.id]);
    for (const id of [randomUUID(), 'nicht-uuid']) expect((await detail(s, id)).statusCode).toBe(404);
  });

  test('höchstens 100 Tage', async () => {
    const s = await siteFor(a, provider);
    const days = Array.from({ length: 105 }, (_, i) => sampleDay({ openedAt: new Date(Date.UTC(2026, 0, 1) + i * 86_400_000).toISOString() }));
    for (let i = 0; i < days.length; i += 50) await send(a, s, days.slice(i, i + 50).map((d) => ['day', d]));
    const body = (await list(s)).json();
    expect(body.days).toHaveLength(100);
    expect(body.days[0].id).toBe(days[104]!.id);
  });

  test('zweiter Betrieb sieht nichts, Chef darf, nicht angemeldet: 401', async () => {
    const s1 = await siteFor(a, provider, 'Eins');
    const s2 = await siteFor(a, provider, 'Zwei');
    const day = sampleDay();
    await send(a, s1, [['day', day]]);
    const chef1 = await createChef(a.db, s1.businessId);
    const chef2 = await createChef(a.db, s2.businessId);
    expect((await list(s1, chef1.cookie)).json().days).toHaveLength(1);
    expect((await detail(s1, day.id, chef1.cookie)).statusCode).toBe(200);
    expect((await list(s1, chef2.cookie)).statusCode).toBe(404);
    expect((await detail(s1, day.id, chef2.cookie)).statusCode).toBe(404);
    expect((await list(s2)).json().days).toEqual([]);
    expect((await detail(s2, day.id)).statusCode).toBe(404);
    for (const url of [`/api/admin/businesses/${s1.businessId}/days`, `/api/admin/businesses/${s1.businessId}/days/${day.id}`]) {
      expect((await a.app.inject({ method: 'GET', url })).statusCode).toBe(401);
    }
  });

  test('keine Antwort enthält staffId, payload oder content_hash', async () => {
    const s = await siteFor(a, provider);
    const day = sampleDay();
    await send(a, s, [['day', day], ['cash_movement', movement(day.id)]]);
    for (const res of [await list(s), await detail(s, day.id)]) {
      expect([...allKeys(res.json())].filter((k) => FORBIDDEN_KEYS.includes(k))).toEqual([]);
    }
  });
  test('Tag liefert Bar, Karte, Storno, Pfand und Steuer wie am Tablet', async () => {
    const s = await siteFor(a, provider, 'Tagesabrechnung');
    const day = sampleDay();
    const line = (gross: Record<string, number>, quantity = 1) => [
      { position: 0, itemId: 'x', name: 'X', info: null, unitPriceCents: 100, quantity, unitDepositCents: 0, gross: { '20': 0, '10': 0, '13': 0, '0': 0, '19': 0, ...gross }, options: [] },
    ];
    const bar1 = sampleReceipt({ businessDayId: day.id, number: 1, totalCents: 1190, goodsCents: 1190, lines: line({ '10': 1190 }) });
    const card = sampleReceipt({
      businessDayId: day.id, number: 2, totalCents: 605, goodsCents: 580, depositCents: 25, lines: line({ '20': 580 }),
      payment: { kind: 'card', amountCents: 605, givenCents: 0, changeCents: 0, provider: 'sumup', providerTxCode: 'T', cardScheme: 'VISA', cardLast4: '4242' },
    });
    const bar2 = sampleReceipt({ businessDayId: day.id, number: 3, totalCents: 1190, goodsCents: 1190, lines: line({ '10': 1190 }) });
    const storno = sampleReceipt({
      businessDayId: day.id, number: 4, kind: 'voided', voidsReceiptId: bar1.id, totalCents: -1190, goodsCents: -1190, lines: line({ '10': -1190 }, -1),
    });
    const special = sampleReceipt({ businessDayId: day.id, number: 5, kind: 'zero', totalCents: 0, goodsCents: 0, lines: [], payment: null });
    await send(a, s, [['day', day], ['receipt', bar1], ['receipt', card], ['receipt', bar2], ['receipt', storno], ['receipt', special]]);
    const d = (await detail(s, day.id)).json();
    expect(d).toMatchObject({
      receiptCount: 2, revenueCents: 1795,
      cashCents: 1190, cardCents: 605, cashReceiptCount: 1, cardReceiptCount: 1,
      voidCount: 1, voidedCents: 1190, depositCents: 25,
    });
    expect(d.taxLines).toEqual([
      { percent: 20, grossCents: 580, netCents: 483, taxCents: 97 },
      { percent: 10, grossCents: 1190, netCents: 1082, taxCents: 108 },
    ]);
    const empty = sampleDay();
    await send(a, s, [['day', empty]]);
    expect((await detail(s, empty.id)).json()).toMatchObject({
      cashCents: 0, cardCents: 0, cashReceiptCount: 0, cardReceiptCount: 0, voidCount: 0, voidedCents: 0, depositCents: 0, taxLines: [],
    });
  });

  test('Tag mit gemischtem Bon, Trinkgeld und Rabatt', async () => {
    const s = await siteFor(a, provider, 'Gemischt');
    const day = sampleDay();
    // bar 9,90 in v: 1, dazu 15,36 in v: 2: bar 10,00, Karte 5,36, Trinkgeld 0,64 für Anna, Rabatt 2,84.
    await send(a, s, [
      ['day', day],
      ['receipt', sampleReceipt({ businessDayId: day.id, number: 1 })],
      ['receipt', sampleReceiptV2({ businessDayId: day.id, number: 2 })],
    ]);
    const d = (await detail(s, day.id)).json();
    expect(d).toMatchObject({
      receiptCount: 2, revenueCents: 2526, cashCents: 1990, cardCents: 536, cashReceiptCount: 2, cardReceiptCount: 1,
      discountCount: 1, discountCents: 284, cardTipCents: 64, cardAccountCents: 600,
      tipsByStaff: [{ staffName: 'Anna', cents: 64 }],
    });
    expect(d.tipsByStaff).toEqual([{ staffName: 'Anna', cents: 64 }]);
  });

  test('Tag nur mit Bons in v: 1: kein Trinkgeld, kein Rabatt, am Kartenkonto die Karte', async () => {
    const s = await siteFor(a, provider, 'Alt');
    const day = sampleDay();
    const card = { kind: 'card', amountCents: 605, givenCents: 0, changeCents: 0, provider: 'sumup', providerTxCode: 'T', cardScheme: 'VISA', cardLast4: '4242' };
    await send(a, s, [
      ['day', day],
      ['receipt', sampleReceipt({ businessDayId: day.id, number: 1 })],
      ['receipt', sampleReceipt({ businessDayId: day.id, number: 2, totalCents: 605, goodsCents: 605, payment: card })],
    ]);
    expect((await detail(s, day.id)).json()).toMatchObject({
      receiptCount: 2, revenueCents: 1595, cashCents: 990, cardCents: 605, cashReceiptCount: 1, cardReceiptCount: 1,
      discountCount: 0, discountCents: 0, cardTipCents: 0, cardAccountCents: 605, tipsByStaff: [],
    });
  });
});

describe('Tag mit Gutscheinen und Pfand zurück (Stufe 1b)', () => {
  const NEW = ['voucherPaidCents', 'voucherSoldCount', 'voucherSoldCents', 'depositReturnCount', 'depositReturnCents'] as const;

  test('Monat mit Gutschein-Verkauf, Gutschein-Zahlung und Pfand-Auszahlung: Umsatz ohne verkauften Gutschein, die fünf neuen Zahlen stimmen', async () => {
    const s = await siteFor(a, provider, 'Gutscheine');
    const fx = await sendStufe1b(a, s);
    const d = (await detail(s, fx.day.id)).json();
    // Jede Zahl des Tages wie die App (gemeinsame Datei stufe_1b.json).
    for (const [k, v] of Object.entries(fx.expected.day)) expect(d[k], k).toEqual(v);
    expect([d.revenueCents, d.cashCents, d.cardCents]).toEqual([2710, 4245, 0]);
    expect(NEW.map((k) => d[k])).toEqual([965, 1, 2500, 3, 75]);
    expect([d.receiptCount, d.cashReceiptCount, d.cardReceiptCount]).toEqual([4, 3, 0]);
    expect(d.cashCents + d.cardCents + d.voucherPaidCents - d.voucherSoldCents).toBe(d.revenueCents);
    // Die Liste der Tage rechnet den Umsatz wie das Detail.
    expect((await list(s)).json().days.map((x: { revenueCents: number }) => x.revenueCents)).toEqual([2710]);
  });

  test('Tag nur mit Bons in v: 1 und v: 2: die fünf neuen Zahlen sind 0', async () => {
    const s = await siteFor(a, provider, 'Alt 1b');
    const day = sampleDay();
    await send(a, s, [
      ['day', day],
      ['receipt', sampleReceipt({ businessDayId: day.id, number: 1 })],
      ['receipt', sampleReceiptV2({ businessDayId: day.id, number: 2 })],
    ]);
    const d = (await detail(s, day.id)).json();
    expect(d).toMatchObject({ receiptCount: 2, revenueCents: 2526, cashCents: 1990, cardCents: 536, cashReceiptCount: 2, cardReceiptCount: 1 });
    expect(NEW.map((k) => d[k])).toEqual([0, 0, 0, 0, 0]);
  });
});
