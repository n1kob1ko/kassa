import type { FastifyInstance } from 'fastify';
import { afterAll, beforeAll, expect, test } from 'vitest';
import { sha256 } from '../src/auth/secrets.js';
import { withBusiness, withSystem } from '../src/db/tenant.js';
import { testApp, type TestApp } from './support/app.js';
import { send, siteFor } from './support/admin_data.js';
import { sampleReceipt } from './support/push.js';
import { insertRegister, insertStaff } from './support/registers.js';
import { insertBusiness, authed, createChef, createProvider, type TestUser } from './support/users.js';

let a: TestApp;
let provider: TestUser;
let nextCode: (() => number) | undefined;
beforeAll(async () => {
  a = await testApp({ randomCode: () => (nextCode ? nextCode() : Math.floor(Math.random() * 100_000_000)) });
  provider = await createProvider(a.app, a.db);
});
afterAll(async () => {
  await a.close();
});

const app = (): FastifyInstance => a.app;
const pair = (b: string, payload: unknown, cookie = provider.cookie) =>
  app().inject({ method: 'POST', url: `/api/admin/businesses/${b}/pairing-codes`, headers: authed(cookie), payload: payload as object });
const list = (b: string, cookie = provider.cookie) =>
  app().inject({ method: 'GET', url: `/api/admin/businesses/${b}/registers`, headers: { cookie } });
const block = (b: string, id: string, what: 'block' | 'unblock' = 'block', cookie = provider.cookie) =>
  app().inject({ method: 'POST', url: `/api/admin/businesses/${b}/registers/${id}/${what}`, headers: authed(cookie), payload: {} });

/** Ein Betrieb mit einer Chefin: Nur dafür gibt es Kopplungscodes. */
const chefBusiness = async () => {
  const b = await insertBusiness(a.db);
  await insertStaff(a.db, b);
  return b;
};

const codes = (b: string) =>
  withBusiness(a.db, b, async (c) => (await c.query('select * from pairing_codes order by expires_at, register_name')).rows);
const auditRows = (action: string) =>
  withSystem(a.db, async (c) => (await c.query('select * from audit_log where action = $1 order by id', [action])).rows);

test('Betrieb ohne aktiven Chef: 409 no_chef, kein Code; mit Chef geht es', async () => {
  const b = await insertBusiness(a.db);
  const none = await pair(b, { name: 'Kassa 1' });
  expect(none.statusCode).toBe(409);
  expect(none.json()).toEqual({ error: { code: 'no_chef', message: 'Lege zuerst einen Chef mit PIN an.' } });
  await insertStaff(a.db, b, { name: 'Ali', role: 'staff' });
  await insertStaff(a.db, b, { name: 'Alte Chefin', role: 'chef', archived: true });
  expect((await pair(b, { name: 'Kassa 1' })).statusCode).toBe(409);
  expect(await codes(b)).toHaveLength(0);
  expect((await auditRows('pairing_code.create')).filter((r) => r.business_id === b)).toHaveLength(0);
  await insertStaff(a.db, b, { name: 'Chefin', role: 'chef' });
  expect((await pair(b, { name: 'Kassa 1' })).statusCode).toBe(201);
  expect(await codes(b)).toHaveLength(1);
});

test('Code hat genau 8 Ziffern, expiresAt ist jetzt plus 15 Minuten', async () => {
  const b = await chefBusiness();
  const res = await pair(b, { name: '  Kassa 1 ' });
  expect(res.statusCode).toBe(201);
  expect(res.json().code).toMatch(/^[0-9]{8}$/);
  expect(res.json().expiresAt).toBe('2026-11-18T10:15:00.000Z');
  expect((await codes(b))[0].register_name).toBe('Kassa 1');
});

test('in der Datenbank steht nur der Prüfwert, nicht der Code', async () => {
  const b = await chefBusiness();
  const { code } = (await pair(b, { name: 'Kassa 1' })).json();
  const rows = await codes(b);
  expect(rows).toHaveLength(1);
  expect(Buffer.compare(rows[0].code_hash, sha256(code))).toBe(0);
  expect(JSON.stringify(rows)).not.toContain(code);
  expect(rows[0].used_at).toBeNull();
});

test('100 Codes: alle 8 Zeichen lang, auch die mit führender Null', async () => {
  const b = await chefBusiness();
  nextCode = () => 42;
  try {
    const first = await pair(b, { name: 'Kassa 1' });
    expect(first.json().code).toBe('00000042');
  } finally {
    nextCode = undefined;
  }
  const seen = new Set<string>();
  for (let i = 0; i < 100; i++) {
    const res = await pair(b, { name: `K${i}` });
    expect(res.statusCode).toBe(201);
    expect(res.json().code).toHaveLength(8);
    seen.add(res.json().code);
  }
  expect(seen.size).toBeGreaterThan(90);
});

test('ältere Codes bleiben gültig', async () => {
  const b = await chefBusiness();
  await pair(b, { name: 'Kassa 1' });
  await pair(b, { name: 'Kassa 2' });
  expect(await codes(b)).toHaveLength(2);
});

test('Name nach dem Kürzen leer, zu lang oder kein Text: 422 name_invalid', async () => {
  const b = await chefBusiness();
  for (const name of ['   ', '', 'x'.repeat(31), 5, null]) {
    const res = await pair(b, { name });
    expect(res.statusCode).toBe(422);
    expect(res.json().error.code).toBe('name_invalid');
  }
  expect((await pair(b, { name: 'x'.repeat(30) })).statusCode).toBe(201);
  expect(await codes(b)).toHaveLength(1);
});

test('neuer Code räumt benutzte und abgelaufene Codes dieses Betriebs weg, andere nicht', async () => {
  const b = await chefBusiness();
  const other = await chefBusiness();
  const old = new Date('2026-11-18T09:00:00Z');
  const future = new Date('2026-11-18T11:00:00Z');
  const add = (biz: string, hash: string, name: string, expires: Date, used: Date | null) =>
    withBusiness(a.db, biz, (c) =>
      c.query(
        'insert into pairing_codes (code_hash, business_id, register_name, expires_at, used_at) values ($1, $2, $3, $4, $5)',
        [sha256(hash), biz, name, expires, used],
      ),
    );
  await add(b, 'abgelaufen', 'abgelaufen', old, null);
  await add(b, 'benutzt', 'benutzt', future, old);
  await add(b, 'gueltig', 'gueltig', future, null);
  await add(other, 'fremd-abgelaufen', 'fremd-abgelaufen', old, null);
  expect((await pair(b, { name: 'neu' })).statusCode).toBe(201);
  expect((await codes(b)).map((r) => r.register_name).sort()).toEqual(['gueltig', 'neu']);
  expect((await codes(other)).map((r) => r.register_name)).toEqual(['fremd-abgelaufen']);
});

test('gleicher Code schon vergeben: neuer Code wird gezogen', async () => {
  const b = await chefBusiness();
  const other = await chefBusiness();
  nextCode = () => 7;
  try {
    expect((await pair(other, { name: 'Kassa 1' })).json().code).toBe('00000007');
    const seq = [7, 7, 8];
    nextCode = () => seq.shift()!;
    const res = await pair(b, { name: 'Kassa 2' });
    expect(res.statusCode).toBe(201);
    expect(res.json().code).toBe('00000008');
    expect(seq).toEqual([]);
  } finally {
    nextCode = undefined;
  }
  expect(await codes(b)).toHaveLength(1);
  expect(await codes(other)).toHaveLength(1);
});

test('fünfmal derselbe Code: 500 internal, nichts angelegt, kein Verlauf', async () => {
  const b = await chefBusiness();
  const other = await chefBusiness();
  nextCode = () => 9;
  try {
    expect((await pair(other, { name: 'Kassa 1' })).statusCode).toBe(201);
    let calls = 0;
    nextCode = () => (calls++, 9);
    const res = await pair(b, { name: 'Kassa 2' });
    expect(res.statusCode).toBe(500);
    expect(res.json().error.code).toBe('internal');
    expect(calls).toBe(5);
  } finally {
    nextCode = undefined;
  }
  expect(await codes(b)).toHaveLength(0);
  const log = await withSystem(a.db, async (c) => (await c.query('select * from audit_log where business_id = $1', [b])).rows);
  expect(log).toHaveLength(0);
});

test('Verlauf pairing_code.create enthält den Code nicht', async () => {
  const b = await chefBusiness();
  const { code } = (await pair(b, { name: 'Kassa 1' })).json();
  const rows = (await auditRows('pairing_code.create')).filter((r) => r.business_id === b);
  expect(rows).toHaveLength(1);
  expect(rows[0].user_id).toBe(provider.user.id);
  expect(JSON.stringify(rows[0])).not.toContain(code);
  expect(rows[0].detail).toEqual({ name: 'Kassa 1' });
});

test('Liste zeigt keine Geräte-Schlüssel, neueste zuerst', async () => {
  const b = await chefBusiness();
  const older = await insertRegister(a.db, b, { name: 'Alt', pairedAt: new Date('2026-11-01T10:00:00Z') });
  const newer = await insertRegister(a.db, b, {
    name: 'Neu',
    pairedAt: new Date('2026-11-10T10:00:00Z'),
    lastSeenAt: new Date('2026-11-17T08:00:00Z'),
    appVersion: '1.2.0',
    deviceModel: 'Redmi Pad Pro',
    blockedAt: new Date('2026-11-12T10:00:00Z'),
  });
  const res = await list(b);
  expect(res.statusCode).toBe(200);
  expect(res.json()).toEqual({
    registers: [
      {
        id: newer,
        name: 'Neu',
        pairedAt: '2026-11-10T10:00:00.000Z',
        lastSeenAt: '2026-11-17T08:00:00.000Z',
        appVersion: '1.2.0',
        deviceModel: 'Redmi Pad Pro',
        blocked: true,
        lastReceiptAt: null,
        chains: [],
      },
      {
        id: older, name: 'Alt', pairedAt: '2026-11-01T10:00:00.000Z', lastSeenAt: null, appVersion: null, deviceModel: null, blocked: false,
        lastReceiptAt: null, chains: [],
      },
    ],
  });
  expect(res.body).not.toMatch(/token/i);
});

test('sperren setzt blocked, aufheben nimmt es weg, beides im Verlauf', async () => {
  const b = await chefBusiness();
  const id = await insertRegister(a.db, b);
  const r1 = await block(b, id);
  expect(r1.statusCode).toBe(200);
  expect(r1.json().register).toMatchObject({ id, name: 'Kassa 1', blocked: true });
  expect((await list(b)).json().registers[0].blocked).toBe(true);
  const r2 = await block(b, id, 'unblock');
  expect(r2.statusCode).toBe(200);
  expect(r2.json().register.blocked).toBe(false);
  expect((await list(b)).json().registers[0].blocked).toBe(false);
  const mine = (rows: { business_id: string; detail: unknown }[]) => rows.filter((r) => r.business_id === b);
  expect(mine(await auditRows('register.block'))).toHaveLength(1);
  expect(mine(await auditRows('register.unblock'))).toHaveLength(1);
  expect(mine(await auditRows('register.block'))[0]?.detail).toEqual({ registerId: id });
});

test('zweimal sperren ist kein Fehler und behält den ersten Zeitpunkt', async () => {
  const b = await chefBusiness();
  const id = await insertRegister(a.db, b);
  expect((await block(b, id)).statusCode).toBe(200);
  const first = await withBusiness(a.db, b, async (c) => (await c.query('select blocked_at from registers where id = $1', [id])).rows[0].blocked_at);
  a.now.value = new Date(a.now.value.getTime() + 60_000);
  expect((await block(b, id)).statusCode).toBe(200);
  const second = await withBusiness(a.db, b, async (c) => (await c.query('select blocked_at from registers where id = $1', [id])).rows[0].blocked_at);
  expect(second).toEqual(first);
  expect((await block(b, id, 'unblock')).statusCode).toBe(200);
  expect((await block(b, id, 'unblock')).statusCode).toBe(200);
});

test('Chef des eigenen Betriebs darf alles', async () => {
  const b = await chefBusiness();
  const chef = await createChef(a.db, b);
  const id = await insertRegister(a.db, b);
  expect((await pair(b, { name: 'K' }, chef.cookie)).statusCode).toBe(201);
  expect((await list(b, chef.cookie)).statusCode).toBe(200);
  expect((await block(b, id, 'block', chef.cookie)).statusCode).toBe(200);
});

test('Chef von B: Code für A 404, Liste von A 404, Sperren 404 und nichts ändert sich', async () => {
  const bizA = await chefBusiness();
  const bizB = await chefBusiness();
  const chefB = await createChef(a.db, bizB);
  const regA = await insertRegister(a.db, bizA);
  expect((await pair(bizA, { name: 'K' }, chefB.cookie)).statusCode).toBe(404);
  expect(await codes(bizA)).toHaveLength(0);
  expect((await list(bizA, chefB.cookie)).statusCode).toBe(404);
  expect((await block(bizA, regA, 'block', chefB.cookie)).statusCode).toBe(404);
  expect((await block(bizA, regA, 'unblock', chefB.cookie)).statusCode).toBe(404);
  expect((await list(bizA)).json().registers[0].blocked).toBe(false);
});

test('Kasse eines anderen Betriebs unter eigener Adresse: 404, nichts ändert sich; Liste von B sieht A nicht', async () => {
  const bizA = await chefBusiness();
  const bizB = await chefBusiness();
  const regA = await insertRegister(a.db, bizA);
  const res = await block(bizB, regA);
  expect(res.statusCode).toBe(404);
  expect(res.json().error.code).toBe('not_found');
  expect((await list(bizA)).json().registers[0].blocked).toBe(false);
  expect((await list(bizB)).json().registers).toEqual([]);
  // gesperrte Kasse von A bleibt auch beim Aufheben unter B unberührt
  const regA2 = await insertRegister(a.db, bizA, { blockedAt: new Date('2026-11-12T10:00:00Z') });
  expect((await block(bizB, regA2, 'unblock')).statusCode).toBe(404);
  expect((await list(bizA)).json().registers.find((r: { id: string }) => r.id === regA2).blocked).toBe(true);
});

test('ohne Anmeldung 401, unbekannter Betrieb, unbekannte Kasse oder keine uuid 404', async () => {
  const b = await chefBusiness();
  const id = await insertRegister(a.db, b);
  const anon = (method: 'GET' | 'POST', url: string) =>
    app().inject({ method, url, headers: { 'x-kassa-request': '1' }, ...(method === 'POST' ? { payload: {} } : {}) });
  for (const [m, u] of [
    ['POST', `/api/admin/businesses/${b}/pairing-codes`],
    ['GET', `/api/admin/businesses/${b}/registers`],
    ['POST', `/api/admin/businesses/${b}/registers/${id}/block`],
    ['POST', `/api/admin/businesses/${b}/registers/${id}/unblock`],
  ] as const) {
    const res = await anon(m, u);
    expect(res.statusCode).toBe(401);
    expect(res.json().error.code).toBe('unauthorized');
  }
  const missing = '00000000-0000-4000-8000-000000000000';
  expect((await list(missing)).statusCode).toBe(404);
  expect((await list('abc')).statusCode).toBe(404);
  expect((await pair(missing, { name: 'K' })).statusCode).toBe(404);
  expect((await block(b, missing)).statusCode).toBe(404);
  expect((await block(b, 'abc')).statusCode).toBe(404);
});

const chainOf = (n: number, o: Record<string, unknown> = {}) => ({
  chain: n, mode: 'probe', cashBoxId: `KASSA${n}`, zdaId: 'AT0', certSerial: '1a2b',
  startedAt: '2026-11-19T07:59:00.000Z', endedAt: null, ...o,
});
const rksv = (chain: number, position: number) => ({ chain, position, jws: `a.b.${chain}-${position}`, damaged: false, certSerial: '1a2b' });
const sale = (number: number, createdAt: string, r: object | null) =>
  sampleReceipt({ number, createdAt, test: r === null, rksv: r });

test('lastReceiptAt und chains nach einem Paket', async () => {
  const s = await siteFor(a, provider);
  await send(a, s, [
    ['rksv_certificate', { serialHex: '1a2b', certificate: 'AQID', issuers: [] }],
    ['rksv_chain', chainOf(1, { endedAt: '2026-11-19T09:30:00.000Z' })],
    ['rksv_chain', chainOf(2, { mode: 'live', startedAt: '2026-11-19T09:31:00.000Z' })],
    ['receipt', sale(1, '2026-11-19T08:05:00.000Z', rksv(1, 1))],
    ['receipt', sale(2, '2026-11-19T08:06:00.000Z', rksv(1, 2))],
    ['receipt', sale(3, '2026-11-19T10:15:30.250Z', rksv(2, 1))],
    ['receipt', sale(4, '2026-11-19T10:00:00.000Z', null)],
  ]);
  const res = await list(s.businessId);
  expect(res.statusCode).toBe(200);
  const [reg] = res.json().registers;
  expect(reg).toMatchObject({ id: s.registerId, lastReceiptAt: '2026-11-19T10:15:30.250Z' });
  expect(reg.chains).toEqual([
    { chain: 1, mode: 'probe', cashBoxId: 'KASSA1', startedAt: '2026-11-19T07:59:00.000Z', endedAt: '2026-11-19T09:30:00.000Z', entries: 2 },
    { chain: 2, mode: 'live', cashBoxId: 'KASSA2', startedAt: '2026-11-19T09:31:00.000Z', endedAt: null, entries: 1 },
  ]);
  expect(res.body).not.toMatch(/jws|a\.b\.|certificate|serial|zda/i);
});

test('Kette ohne Einträge zeigt entries 0; Kassa ohne Bon zeigt lastReceiptAt null', async () => {
  const s = await siteFor(a, provider);
  await send(a, s, [['rksv_chain', chainOf(1)]]);
  const [reg] = (await list(s.businessId)).json().registers;
  expect(reg.lastReceiptAt).toBeNull();
  expect(reg.chains).toEqual([{ chain: 1, mode: 'probe', cashBoxId: 'KASSA1', startedAt: '2026-11-19T07:59:00.000Z', endedAt: null, entries: 0 }]);
});

test('zwei Kassen mit derselben Geräte-Kennung zeigen dieselben Ketten, jede ihren letzten Bon', async () => {
  const s = await siteFor(a, provider);
  await send(a, s, [
    ['rksv_certificate', { serialHex: '1a2b', certificate: 'AQID', issuers: [] }],
    ['rksv_chain', chainOf(1)],
    ['receipt', sale(1, '2026-11-19T08:05:00.000Z', rksv(1, 1))],
  ]);
  const second = await insertRegister(a.db, s.businessId, { name: 'Kassa 2', pairedAt: new Date('2026-11-19T12:00:00Z') });
  await withBusiness(a.db, s.businessId, (c) =>
    c.query('update registers set device_id = (select device_id from registers where id = $1) where id = $2', [s.registerId, second]),
  );
  const regs = (await list(s.businessId)).json().registers as { id: string; lastReceiptAt: string | null; chains: object[] }[];
  expect(regs).toHaveLength(2);
  const one = regs.find((r) => r.id === s.registerId)!;
  const two = regs.find((r) => r.id === second)!;
  expect(two.chains).toEqual(one.chains);
  expect(one.chains).toHaveLength(1);
  expect((one.chains[0] as { entries: number }).entries).toBe(1);
  expect(one.lastReceiptAt).toBe('2026-11-19T08:05:00.000Z');
  expect(two.lastReceiptAt).toBeNull();
});

test('Ketten eines anderen Betriebs erscheinen nicht', async () => {
  const s1 = await siteFor(a, provider, 'Eins');
  const s2 = await siteFor(a, provider, 'Zwei');
  await send(a, s1, [['rksv_chain', chainOf(1)]]);
  await send(a, s2, [['rksv_chain', chainOf(7, { cashBoxId: 'FREMD' })]]);
  expect((await list(s1.businessId)).json().registers[0].chains.map((c: { cashBoxId: string }) => c.cashBoxId)).toEqual(['KASSA1']);
  expect((await list(s2.businessId)).json().registers[0].chains.map((c: { cashBoxId: string }) => c.cashBoxId)).toEqual(['FREMD']);
});
