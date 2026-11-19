import { randomUUID } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, test } from 'vitest';
import { withBusiness } from '../src/db/tenant.js';
import { testApp, type TestApp } from './support/app.js';
import { allKeys, createProvider, FORBIDDEN_KEYS, send, setTimeZone, siteFor, type Site } from './support/admin_data.js';
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

const get = (url: string, cookie = provider.cookie) => a.app.inject({ method: 'GET', url, headers: authed(cookie) });
const list = (s: Site, query = '') => get(`/api/admin/businesses/${s.businessId}/receipts${query}`);
const bon = (createdAt: string, o: Record<string, unknown> = {}) => sampleReceipt({ id: randomUUID(), createdAt, ...o });
const card = { kind: 'card', amountCents: 990, givenCents: 0, changeCents: 0, provider: 'sumup', providerTxCode: 'T1', cardScheme: 'VISA', cardLast4: '1234' };

describe('Bons', () => {
  test('Liste: neueste zuerst, Kopf mit Kassa und Mitarbeiter', async () => {
    const s = await siteFor(a, provider);
    const early = bon('2026-11-19T08:00:00.000Z', { number: 1 });
    const late = bon('2026-11-19T09:00:00.000Z', { number: 2, staffName: 'Anna', payment: card });
    await send(a, s, [['receipt', early], ['receipt', late]]);
    const res = await list(s);
    expect(res.statusCode).toBe(200);
    expect(res.json()).toEqual({
      receipts: [
        { id: late.id, number: 2, registerName: 'Kassa 1', createdAt: '2026-11-19T09:00:00.000Z', kind: 'sale', staffName: 'Anna', totalCents: 990, paymentKind: 'card', test: true, voided: false },
        { id: early.id, number: 1, registerName: 'Kassa 1', createdAt: '2026-11-19T08:00:00.000Z', kind: 'sale', staffName: 'Chefin', totalCents: 990, paymentKind: 'cash', test: true, voided: false },
      ],
      next: null,
    });
  });

  test('Seiten über before: 50 pro Seite, auch bei gleichem Zeitpunkt', async () => {
    const s = await siteFor(a, provider);
    const all = Array.from({ length: 120 }, (_, i) =>
      // Je drei Bons haben denselben Zeitpunkt.
      bon(new Date(Date.UTC(2026, 10, 19, 6, 0, 0) + Math.floor(i / 3) * 1000).toISOString(), { number: i + 1 }),
    );
    for (let i = 0; i < all.length; i += 60) await send(a, s, all.slice(i, i + 60).map((r) => ['receipt', r]));
    const seen: string[] = [];
    let before = '';
    const sizes: number[] = [];
    for (let page = 0; page < 5; page++) {
      const body = (await list(s, before)).json();
      sizes.push(body.receipts.length);
      seen.push(...body.receipts.map((r: { id: string }) => r.id));
      if (body.next === null) break;
      before = `?before=${encodeURIComponent(body.next)}`;
    }
    expect(sizes).toEqual([50, 50, 20]);
    expect(new Set(seen).size).toBe(120);
    expect(new Set(seen)).toEqual(new Set(all.map((r) => r.id)));
  });

  test('before kaputt: 422', async () => {
    const s = await siteFor(a, provider);
    const forged = (t: string) => Buffer.from(JSON.stringify({ t, i: randomUUID() })).toString('base64url');
    for (const before of [
      'abc',
      '!!!',
      Buffer.from('{"t":1}').toString('base64url'),
      Buffer.from('kein json').toString('base64url'),
      forged('2026-13-19T08:00:00.123456Z'),
      forged('2026-02-30T08:00:00.123456Z'),
      forged('2026-11-19T25:00:00.123456Z'),
    ]) {
      const res = await list(s, `?before=${before}`);
      expect(res.statusCode, before).toBe(422);
      expect(res.json().error.code).toBe('before_invalid');
    }
  });

  test('Filter: Tag in der Zeitzone des Betriebs', async () => {
    const s = await siteFor(a, provider);
    await setTimeZone(a, s.businessId, 'Europe/Vienna');
    const a1 = bon('2026-11-18T22:30:00.000Z', { number: 1 }); // 18.11. 23:30 Wien
    const a2 = bon('2026-11-18T23:30:00.000Z', { number: 2 }); // 19.11. 00:30 Wien
    const a3 = bon('2026-11-19T22:59:00.000Z', { number: 3 }); // 19.11. 23:59 Wien
    const a4 = bon('2026-11-19T23:00:00.000Z', { number: 4 }); // 20.11. 00:00 Wien
    await send(a, s, [a1, a2, a3, a4].map((r) => ['receipt', r]));
    const ids = async (q: string) => (await list(s, q)).json().receipts.map((r: { id: string }) => r.id);
    expect(await ids('?day=2026-11-19')).toEqual([a3.id, a2.id]);
    expect(await ids('?day=2026-11-18')).toEqual([a1.id]);
    expect((await list(s, '?day=2026-13-40')).statusCode).toBe(422);
    expect((await list(s, '?day=gestern')).statusCode).toBe(422);
    for (const day of ['0000-01-01', '2026-02-30', '1800-01-01', '10000-01-01']) {
      const res = await list(s, `?day=${day}`);
      expect(res.statusCode, day).toBe(422);
      expect(res.json().error.code).toBe('day_invalid');
    }
  });

  test('Filter: Zahlungsart und nur Stornos', async () => {
    const s = await siteFor(a, provider);
    const cash = bon('2026-11-19T08:00:00.000Z', { number: 1 });
    const kartenbon = bon('2026-11-19T09:00:00.000Z', { number: 2, payment: card });
    const storno = bon('2026-11-19T10:00:00.000Z', { number: 3, kind: 'voided', voidsReceiptId: cash.id, totalCents: -990, goodsCents: -990, payment: { ...cash.payment, amountCents: -990 } });
    await send(a, s, [cash, kartenbon, storno].map((r) => ['receipt', r]));
    const ids = async (q: string) => (await list(s, q)).json().receipts.map((r: { id: string }) => r.id);
    expect(await ids('?payment=card')).toEqual([kartenbon.id]);
    expect(await ids('?payment=cash')).toEqual([storno.id, cash.id]);
    // Beide Hälften des Paars, der Kartenbon ohne Storno nicht.
    expect(await ids('?voided=1')).toEqual([storno.id, cash.id]);
    expect(await ids('?voided=1&payment=card')).toEqual([]);
    expect((await list(s, '?payment=bitcoin')).statusCode).toBe(422);
  });

  test('Storno-Paar zeigt aufeinander', async () => {
    const s = await siteFor(a, provider);
    const sale = bon('2026-11-19T08:00:00.000Z', { number: 1 });
    const storno = bon('2026-11-19T10:00:00.000Z', { number: 2, kind: 'voided', voidsReceiptId: sale.id, totalCents: -990, goodsCents: -990 });
    await send(a, s, [sale, storno].map((r) => ['receipt', r]));
    const rows = (await list(s)).json().receipts;
    expect(rows.find((r: { id: string }) => r.id === sale.id).voided).toBe(true);
    expect(rows.find((r: { id: string }) => r.id === storno.id).voided).toBe(false);
    const d1 = (await get(`/api/admin/businesses/${s.businessId}/receipts/${sale.id}`)).json();
    const d2 = (await get(`/api/admin/businesses/${s.businessId}/receipts/${storno.id}`)).json();
    expect(d1).toMatchObject({ voidsReceiptId: null, voidedByReceiptId: storno.id, voided: true });
    expect(d2).toMatchObject({ voidsReceiptId: sale.id, voidedByReceiptId: null, kind: 'voided' });
  });

  test('Detail mit Zeilen, Optionen und Zahlung', async () => {
    const s = await siteFor(a, provider);
    const r = bon('2026-11-19T08:00:00.000Z', { number: 7, depositCents: 25, totalCents: 1015 });
    await send(a, s, [['receipt', r]]);
    const res = await get(`/api/admin/businesses/${s.businessId}/receipts/${r.id}`);
    expect(res.statusCode).toBe(200);
    expect(res.json()).toEqual({
      id: r.id, number: 7, registerName: 'Kassa 1', createdAt: '2026-11-19T08:00:00.000Z', kind: 'sale', staffName: 'Chefin',
      totalCents: 1015, paymentKind: 'cash', test: true, voided: false,
      goodsCents: 990, depositCents: 25,
      lines: [{
        position: 0, itemId: 'huhn-bowl', name: 'Huhn Bowl', info: null, unitPriceCents: 990, quantity: 1, unitDepositCents: 0,
        options: [{ groupName: 'Größe', optionName: 'Normal', surchargeCents: 0 }],
      }],
      payment: { kind: 'cash', amountCents: 990, givenCents: 1000, changeCents: 10, provider: null, providerTxCode: null, cardScheme: null, cardLast4: null },
      voidsReceiptId: null, voidedByReceiptId: null, rksv: null,
    });
  });

  test('Detail: Zahlung mit Kennung des Zahlungsanbieters', async () => {
    const s = await siteFor(a, provider);
    const r = bon('2026-11-19T08:00:00.000Z', { payment: card });
    await send(a, s, [['receipt', r]]);
    const body = (await get(`/api/admin/businesses/${s.businessId}/receipts/${r.id}`)).json();
    expect(body.payment).toMatchObject({ kind: 'card', provider: 'sumup', providerTxCode: 'T1', cardScheme: 'VISA', cardLast4: '1234' });
  });

  test('Signatur: Kassen-Kennung, beschädigt, Probe; nie die Signatur selbst', async () => {
    const s = await siteFor(a, provider);
    const chain = (n: number, mode: string, cashBoxId: string) => ({ chain: n, mode, cashBoxId, zdaId: 'AT0', certSerial: '1a2b', startedAt: '2026-11-19T07:00:00.000Z', endedAt: null });
    await send(a, s, [
      ['rksv_chain', chain(1, 'probe', 'KASSA1')],
      ['rksv_chain', chain(2, 'live', 'KASSA2')],
    ]);
    const probe = bon('2026-11-19T08:00:00.000Z', { number: 1, rksv: { chain: 1, position: 1, jws: 'GEHEIM.JWS.WERT', damaged: false, certSerial: '1a2b' } });
    const live = bon('2026-11-19T09:00:00.000Z', { number: 2, rksv: { chain: 2, position: 1, jws: 'GEHEIM.JWS.ZWEI', damaged: true, certSerial: '1a2b' } });
    await send(a, s, [probe, live].map((r) => ['receipt', r]));
    const d1 = (await get(`/api/admin/businesses/${s.businessId}/receipts/${probe.id}`)).json();
    const d2 = (await get(`/api/admin/businesses/${s.businessId}/receipts/${live.id}`)).json();
    expect(d1.rksv).toEqual({ cashBoxId: 'KASSA1', damaged: false, probe: true });
    expect(d2.rksv).toEqual({ cashBoxId: 'KASSA2', damaged: true, probe: false });
    expect(JSON.stringify([d1, d2])).not.toMatch(/JWS|1a2b/);
  });

  test('unbekannte oder ungültige Kennung: 404', async () => {
    const s = await siteFor(a, provider);
    for (const id of [randomUUID(), 'nicht-uuid']) {
      const res = await get(`/api/admin/businesses/${s.businessId}/receipts/${id}`);
      expect(res.statusCode).toBe(404);
      expect(res.json().error.code).toBe('not_found');
    }
  });

  test('Bon einer gelöschten Kassa steht weiter in der Liste', async () => {
    const s = await siteFor(a, provider);
    const r = bon('2026-11-19T08:00:00.000Z');
    await send(a, s, [['receipt', r]]);
    await withBusiness(a.db, s.businessId, (c) => c.query('delete from registers where id = $1', [s.registerId]));
    const rows = (await list(s)).json().receipts;
    expect(rows).toHaveLength(1);
    expect(rows[0].registerName).toBe('');
  });

  test('zweiter Betrieb sieht nichts, Chef darf, nicht angemeldet: 401', async () => {
    const s1 = await siteFor(a, provider, 'Eins');
    const s2 = await siteFor(a, provider, 'Zwei');
    const r = bon('2026-11-19T08:00:00.000Z');
    await send(a, s1, [['receipt', r]]);
    const chef1 = await createChef(a.db, s1.businessId);
    const chef2 = await createChef(a.db, s2.businessId);
    expect((await list(s1, '')).json().receipts).toHaveLength(1);
    expect((await get(`/api/admin/businesses/${s1.businessId}/receipts`, chef1.cookie)).json().receipts).toHaveLength(1);
    expect((await get(`/api/admin/businesses/${s1.businessId}/receipts`, chef2.cookie)).statusCode).toBe(404);
    expect((await get(`/api/admin/businesses/${s1.businessId}/receipts/${r.id}`, chef2.cookie)).statusCode).toBe(404);
    // Der Bon eines anderen Betriebs ist im eigenen Betrieb nicht zu finden.
    expect((await get(`/api/admin/businesses/${s2.businessId}/receipts/${r.id}`)).statusCode).toBe(404);
    expect((await list(s2)).json().receipts).toEqual([]);
    for (const url of [`/api/admin/businesses/${s1.businessId}/receipts`, `/api/admin/businesses/${s1.businessId}/receipts/${r.id}`]) {
      expect((await a.app.inject({ method: 'GET', url })).statusCode).toBe(401);
    }
  });

  test('keine Antwort enthält staffId, payload oder content_hash', async () => {
    const s = await siteFor(a, provider);
    const r = bon('2026-11-19T08:00:00.000Z');
    await send(a, s, [['receipt', r]]);
    for (const url of [`/api/admin/businesses/${s.businessId}/receipts`, `/api/admin/businesses/${s.businessId}/receipts/${r.id}`]) {
      const keys = allKeys((await get(url)).json());
      expect([...keys].filter((k) => FORBIDDEN_KEYS.includes(k))).toEqual([]);
    }
  });
});
