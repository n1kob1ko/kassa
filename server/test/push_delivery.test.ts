import { randomUUID } from 'node:crypto';
import { afterAll, beforeAll, expect, test } from 'vitest';
import { withBusiness } from '../src/db/tenant.js';
import { testApp, type TestApp } from './support/app.js';
import { allKeys, createProvider, FORBIDDEN_KEYS, send, siteFor } from './support/admin_data.js';
import { pushEntries, sampleReceipt } from './support/push.js';
import { freshToken, readStufe1b } from './support/stufe_1b.js';
import { authed, type TestUser } from './support/users.js';

// Eintrag "delivery": wie der Beleg zu einem Bon erteilt wurde (gedruckt, digital angeboten). Nur anfügen.

let a: TestApp;
let provider: TestUser;

beforeAll(async () => {
  a = await testApp();
  provider = await createProvider(a.app, a.db);
});
afterAll(async () => {
  await a.close();
});

const detail = async (businessId: string, id: string) =>
  (await a.app.inject({ method: 'GET', url: `/api/admin/businesses/${businessId}/receipts/${id}`, headers: authed(provider.cookie) })).json();

const delivery = (seq: number, receiptId: string, deliveryKind: string, at: string) => ({ seq, kind: 'delivery', receiptId, deliveryKind, at });

test('delivery: printed und digital angefügt, noch einmal duplicate, unbekannter Bon invalid; das Detail der Verwaltung zeigt beide', async () => {
  const s = await siteFor(a, provider);
  const other = await siteFor(a, provider, 'Anderer Betrieb');
  const token = freshToken();
  const r = { ...readStufe1b().receipts[0]!, id: randomUUID(), businessDayId: randomUUID(), publicToken: token };
  const foreign = { ...readStufe1b().receipts[0]!, id: randomUUID(), businessDayId: randomUUID(), publicToken: freshToken() };
  await send(a, s, [['receipt', r]]);
  await send(a, other, [['receipt', foreign]]);
  const before = await withBusiness(a.db, s.businessId, async (c) =>
    (await c.query('select content_hash, payload, received_at from receipts where id = $1', [r.id])).rows[0],
  );

  const res = await pushEntries(a.app, s.token, s.deviceId, [
    delivery(1, r.id, 'printed', '2026-11-27T11:03:05Z'),
    delivery(2, r.id, 'digital', '2026-11-27T11:03:09.123Z'),
    // Dieselbe Art noch einmal, auch zu anderer Zeit: duplicate, die erste Zeit bleibt.
    delivery(3, r.id, 'printed', '2026-11-27T12:00:00Z'),
    delivery(4, randomUUID(), 'printed', '2026-11-27T11:03:05Z'),
    // Der Bon eines anderen Betriebs ist hier unbekannt.
    delivery(5, foreign.id, 'printed', '2026-11-27T11:03:05Z'),
    delivery(6, r.id, 'emailed', '2026-11-27T11:03:05Z'),
    delivery(7, 'keine-uuid', 'printed', '2026-11-27T11:03:05Z'),
    delivery(8, r.id, 'printed', 'gestern'),
  ]);
  expect(res.status).toBe(200);
  expect(res.results).toEqual([
    { seq: 1, status: 'accepted' },
    { seq: 2, status: 'accepted' },
    { seq: 3, status: 'duplicate' },
    { seq: 4, status: 'rejected', reason: 'invalid' },
    { seq: 5, status: 'rejected', reason: 'invalid' },
    { seq: 6, status: 'rejected', reason: 'invalid' },
    { seq: 7, status: 'rejected', reason: 'invalid' },
    { seq: 8, status: 'rejected', reason: 'invalid' },
  ]);

  // Der Bon selbst bleibt unverändert.
  const after = await withBusiness(a.db, s.businessId, async (c) =>
    (await c.query('select content_hash, payload, received_at from receipts where id = $1', [r.id])).rows[0],
  );
  expect(after).toEqual(before);

  const d = await detail(s.businessId, r.id);
  expect(d.deliveries).toEqual([
    { kind: 'printed', at: '2026-11-27T11:03:05.000Z' },
    { kind: 'digital', at: '2026-11-27T11:03:09.123Z' },
  ]);
  expect(d.pageUrl).toBe(`/beleg/${token}`);
  expect([...allKeys(d)].filter((k) => FORBIDDEN_KEYS.includes(k))).toEqual([]);
  // Der andere Betrieb hat keinen Eintrag bekommen.
  expect(Object.keys(await detail(other.businessId, foreign.id))).not.toContain('deliveries');
  const rows = await withBusiness(a.db, other.businessId, async (c) => (await c.query('select * from receipt_deliveries')).rows);
  expect(rows).toEqual([]);
});

test('ohne Eintrag und ohne Schlüssel fehlen deliveries und pageUrl im Detail ganz', async () => {
  const s = await siteFor(a, provider);
  const old = sampleReceipt({ id: randomUUID() });
  const withToken = { ...readStufe1b().receipts[0]!, id: randomUUID(), businessDayId: randomUUID(), publicToken: freshToken() };
  await send(a, s, [['receipt', old], ['receipt', withToken]]);
  const d1 = await detail(s.businessId, old.id);
  expect(Object.keys(d1)).not.toContain('deliveries');
  expect(Object.keys(d1)).not.toContain('pageUrl');
  const d2 = await detail(s.businessId, withToken.id);
  expect(Object.keys(d2)).not.toContain('deliveries');
  expect(d2.pageUrl).toBe(`/beleg/${withToken.publicToken}`);
  // Die Liste trägt weder Schlüssel noch Seite.
  const list = await a.app.inject({ method: 'GET', url: `/api/admin/businesses/${s.businessId}/receipts`, headers: authed(provider.cookie) });
  expect(list.body).not.toContain(withToken.publicToken);
});

test('delivery vor dem Bon: invalid, danach angefügt', async () => {
  const s = await siteFor(a, provider);
  const r = { ...readStufe1b().receipts[0]!, id: randomUUID(), businessDayId: randomUUID(), publicToken: freshToken() };
  const first = await pushEntries(a.app, s.token, s.deviceId, [delivery(1, r.id, 'digital', '2026-11-27T11:03:05Z')]);
  expect(first.results).toEqual([{ seq: 1, status: 'rejected', reason: 'invalid' }]);
  await send(a, s, [['receipt', r]]);
  const second = await pushEntries(a.app, s.token, s.deviceId, [delivery(2, r.id, 'digital', '2026-11-27T11:03:05Z')]);
  expect(second.results).toEqual([{ seq: 2, status: 'accepted' }]);
  expect((await detail(s.businessId, r.id)).deliveries).toEqual([{ kind: 'digital', at: '2026-11-27T11:03:05.000Z' }]);
});
