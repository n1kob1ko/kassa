import { randomUUID } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, test } from 'vitest';
import { loggerOptions } from '../src/app.js';
import { withBusiness } from '../src/db/tenant.js';
import { MAX_SERVER_REPORTS_PER_DAY, writeServerReport } from '../src/reports.js';
import { testApp, type TestApp } from './support/app.js';
import { createBusiness } from './support/businesses.js';
import { createStaff, fixtureBusiness, pairDevice } from './support/device.js';
import { entry, pushEntries, sampleReceipt } from './support/push.js';
import type { TestUser } from './support/users.js';

let f: TestApp;
let provider: TestUser;
let businessId: string;
let token: string;
let registerId: string;
let b2: string;
let t2: string;
const deviceId: string = randomUUID();
const logLines: string[] = [];

beforeAll(async () => {
  f = await testApp({}, { logger: loggerOptions({ write: (s: string) => void logLines.push(s) }) });
  ({ provider, businessId } = await fixtureBusiness(f));
  ({ token, registerId } = await pairDevice(f.app, provider.cookie, businessId));
  b2 = (await createBusiness(f.app, provider.cookie)).id;
  await createStaff(f.app, provider.cookie, b2, { name: 'Chefin', role: 'chef', pin: '1234' });
  t2 = (await pairDevice(f.app, provider.cookie, b2)).token;
});
afterAll(async () => {
  await f.close();
});

const rejected = (biz: string) =>
  withBusiness(f.db, biz, async (c) =>
    (await c.query(`select * from reports where source = 'server' and kind = 'push_rejected' order by at, (content->>'seq')::int, id`)).rows,
  );
const send = (entries: object[], t = token) => pushEntries(f.app, t, deviceId, entries);
const statuses = (r: { results: { status: string; reason?: string }[] }) => r.results.map((x) => (x.reason ? `${x.status}/${x.reason}` : x.status));
const logged = (msg: string) => logLines.map((l) => JSON.parse(l)).filter((l) => l.msg === msg);

describe('abgelehnte Einträge', () => {
  test('unlesbarer Bon und unbekannte Art in der Mitte: je ein Bericht push_rejected, die anderen accepted', async () => {
    const before = (await rejected(businessId)).length;
    const res = await send([
      entry(1, 'receipt', sampleReceipt()),
      entry(2, 'receipt', { ...sampleReceipt(), totalCents: 'viel' }),
      { seq: 3, kind: 'unbekannt' },
      entry(4, 'receipt', sampleReceipt()),
    ]);
    expect(statuses(res)).toEqual(['accepted', 'rejected/invalid', 'rejected/invalid', 'accepted']);
    // Die Antwort bleibt in der festen Form, ohne Pfade.
    expect(res.results[1]).toEqual({ seq: 2, status: 'rejected', reason: 'invalid' });
    const found = (await rejected(businessId)).slice(before);
    expect(found.map((r) => r.content)).toEqual([
      { entryKind: 'receipt', seq: 2, reason: 'invalid', paths: ['receipt.totalCents'] },
      { entryKind: 'unbekannt', seq: 3, reason: 'invalid', paths: [] },
    ]);
    expect(found[0].register_id).toBe(registerId);
    expect(JSON.stringify(found)).not.toContain('viel');
    expect(JSON.stringify(found)).not.toContain('Huhn');
  });

  test('unbekannter Artikel: ein Bericht mit Grund unknown_item, ohne Inhalt', async () => {
    const before = (await rejected(businessId)).length;
    const res = await send([entry(5, 'item_change', { itemId: 'gibt-es-nicht', field: 'priceCents', value: 123, changedAt: '2026-11-18T09:00:00.000Z' })]);
    expect(statuses(res)).toEqual(['rejected/unknown_item']);
    const found = (await rejected(businessId)).slice(before);
    expect(found.map((r) => r.content)).toEqual([{ entryKind: 'item_change', seq: 5, reason: 'unknown_item' }]);
    expect(JSON.stringify(found)).not.toContain('gibt-es-nicht');
  });

  test('abgelehnter Bericht des Tablets: kein Bericht des Servers, nur eine Zeile im Protokoll', async () => {
    const before = (await rejected(businessId)).length;
    const lines = logged('Eintrag abgelehnt').length;
    const res = await send([entry(6, 'report', { id: 'keine-uuid', kind: 'error' })]);
    expect(statuses(res)).toEqual(['rejected/invalid']);
    expect(await rejected(businessId)).toHaveLength(before);
    const line = logged('Eintrag abgelehnt').slice(lines);
    expect(line).toHaveLength(1);
    expect(line[0]).toMatchObject({ businessId, registerId, seq: 6, kind: 'report', reason: 'invalid' });
  });

  test('Fehler der Datenbank, der immer wieder käme (gleiche Position, NUL im Text): rejected/invalid mit Bericht', async () => {
    const before = (await rejected(businessId)).length;
    const r = sampleReceipt();
    const twice = { ...r, lines: [r.lines[0], { ...r.lines[0], gross: { '20': 0, '10': 0, '13': 0, '0': 0, '19': 0 } }] };
    const nul = sampleReceipt({ staffName: 'Chef\u0000in' });
    const res = await send([entry(7, 'receipt', twice), entry(8, 'receipt', nul), entry(9, 'receipt', sampleReceipt())]);
    expect(statuses(res)).toEqual(['rejected/invalid', 'rejected/invalid', 'accepted']);
    const found = (await rejected(businessId)).slice(before);
    expect(found.map((x) => x.content.seq)).toEqual([7, 8]);
    expect(found[0].content).toMatchObject({ entryKind: 'receipt', seq: 7, reason: 'invalid', sqlState: '23505' });
    expect(found[1].content.sqlState).toMatch(/^22/);
    // Nichts vom Bon blieb halb liegen.
    const rows = await withBusiness(f.db, businessId, async (c) => (await c.query('select 1 from receipts where id = any($1)', [[r.id, nul.id]])).rows);
    expect(rows).toHaveLength(0);
  });

  test('ganze Sendung unlesbar: 422 und eine Zeile im Protokoll', async () => {
    const lines = logged('Sendung abgelehnt').length;
    const res = await f.app.inject({
      method: 'POST',
      url: '/api/device/sync/push',
      headers: { authorization: `Bearer ${token}` },
      payload: { deviceId, entries: [{ kind: 'day' }] },
    });
    expect(res.statusCode).toBe(422);
    const line = logged('Sendung abgelehnt').slice(lines);
    expect(line).toHaveLength(1);
    expect(line[0]).toMatchObject({ businessId, registerId });
  });

  test('zweiter Betrieb sieht keinen Bericht des ersten, und seiner bleibt bei ihm', async () => {
    expect(await rejected(b2)).toEqual([]);
    const mine = (await rejected(businessId)).length;
    expect(statuses(await send([{ seq: 1, kind: 'unbekannt' }], t2))).toEqual(['rejected/invalid']);
    expect(await rejected(b2)).toHaveLength(1);
    expect(await rejected(businessId)).toHaveLength(mine);
  });
});

describe('Grenze der Berichte des Servers', () => {
  const write = (biz: string, kind: string, at: string, reg: string | null = registerId) =>
    withBusiness(f.db, biz, (c) => writeServerReport(c, { businessId: biz, registerId: reg, kind, content: {} }, new Date(at), f.app.log));
  const count = (biz: string, kind: string) =>
    withBusiness(f.db, biz, async (c) => Number((await c.query('select count(*)::int as n from reports where kind = $1', [kind])).rows[0].n));

  test('höchstens 50 pro Betrieb, Kassa, Art und Wiener Tag; der Rest nur im Protokoll', async () => {
    expect(MAX_SERVER_REPORTS_PER_DAY).toBe(50);
    for (let i = 0; i < 50; i++) await write(businessId, 'cap_test', '2026-11-19T12:00:00.000Z');
    expect(await count(businessId, 'cap_test')).toBe(50);

    const lines = logged('Bericht des Servers über der Grenze').length;
    // 23:59 in Wien ist noch derselbe Tag.
    await write(businessId, 'cap_test', '2026-11-19T22:59:00.000Z');
    expect(await count(businessId, 'cap_test')).toBe(50);
    expect(logged('Bericht des Servers über der Grenze').slice(lines)).toHaveLength(1);

    // Eine andere Art, eine andere Kassa und der nächste Wiener Tag zählen eigens.
    await write(businessId, 'cap_test_2', '2026-11-19T22:59:00.000Z');
    await write(businessId, 'cap_test', '2026-11-19T22:59:00.000Z', null);
    await write(businessId, 'cap_test', '2026-11-19T23:00:00.000Z');
    expect(await count(businessId, 'cap_test_2')).toBe(1);
    expect(await count(businessId, 'cap_test')).toBe(52);
  });

  test('ein zweiter Betrieb ist von der Grenze des ersten nicht betroffen', async () => {
    await write(b2, 'cap_test', '2026-11-19T12:00:00.000Z', null);
    expect(await count(b2, 'cap_test')).toBe(1);
  });
});
