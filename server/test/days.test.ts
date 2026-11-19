import { randomUUID } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, test } from 'vitest';
import { testApp, type TestApp } from './support/app.js';
import { allKeys, createProvider, FORBIDDEN_KEYS, send, siteFor, type Site } from './support/admin_data.js';
import { sampleDay, sampleReceipt } from './support/push.js';
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
      days: [{ id: day.id, registerName: 'Kassa 1', openedAt: '2026-11-19T08:00:00.000Z', closedAt: null, expectedCents: null, countedCents: null, differenceCents: null, closedByName: null }],
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
    expect(days[0]).toMatchObject({ closedAt: '2026-11-19T17:00:00.000Z', expectedCents: 18500, countedCents: 18000, differenceCents: -500, closedByName: 'Chefin' });
    const d = (await detail(s, open.id)).json();
    expect(d).toMatchObject({ openingFloatCents: 10000, leftInDrawerCents: 10000, receiptCount: 1, revenueCents: 400 });
    expect(d.movements).toEqual([
      { kind: 'withdrawal', amountCents: 2000, reason: 'bank', createdAt: '2026-11-19T10:00:00.000Z', staffName: 'Chefin' },
      { kind: 'deposit', amountCents: 500, reason: 'Wechselgeld', createdAt: '2026-11-19T12:00:00.000Z', staffName: 'Chefin' },
    ]);
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
});
