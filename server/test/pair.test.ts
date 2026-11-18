import type { FastifyInstance } from 'fastify';
import { afterAll, beforeAll, describe, expect, test } from 'vitest';
import { loggerOptions } from '../src/app.js';
import { sha256 } from '../src/auth/secrets.js';
import { withBusiness, withSystem } from '../src/db/tenant.js';
import { SlidingWindow } from '../src/rate_limit.js';
import { testApp, type TestApp } from './support/app.js';
import { createBusiness } from './support/businesses.js';
import { createPairingCode, normalize, PAIR_DEVICE, pull, syncFixture } from './support/device.js';
import { createProvider, type TestUser } from './support/users.js';

const START = new Date('2026-11-18T10:00:00Z');
const MINUTE = 60 * 1000;

let a: TestApp;
let provider: TestUser;
let businessA: string;
let businessB: string;
const logLines: string[] = [];
beforeAll(async () => {
  a = await testApp({}, { logger: loggerOptions({ write: (s: string) => void logLines.push(s) }) });
  provider = await createProvider(a.app, a.db);
  businessA = (await createBusiness(a.app, provider.cookie)).id;
  businessB = (await createBusiness(a.app, provider.cookie)).id;
});
afterAll(async () => {
  await a.close();
});

const app = (): FastifyInstance => a.app;

/** Jeder Test bekommt seine eigene Internet-Adresse, damit die Fehlversuche anderer Tests nicht mitzählen. */
let ipCounter = 0;
const nextIp = () => `10.0.0.${++ipCounter}`;

const pair = (payload: object, ip: string) =>
  app().inject({ method: 'POST', url: '/api/device/pair', payload, remoteAddress: ip });
const pairBody = (code: string, previousBusinessId: string | null = null) => ({ code, previousBusinessId, ...PAIR_DEVICE });
const code = (b = businessA, name = 'Kassa 1') => createPairingCode(app(), provider.cookie, b, name);

const registers = (b: string) =>
  withBusiness(a.db, b, async (c) => (await c.query('select * from registers order by paired_at, id')).rows);
const auditRows = (action: string) =>
  withSystem(a.db, async (c) => (await c.query('select * from audit_log where action = $1 order by id', [action])).rows);

const expectInvalidCode = (res: { statusCode: number; json(): any }) => {
  expect(res.statusCode).toBe(404);
  expect(res.json()).toEqual({ error: { code: 'invalid_code', message: 'Der Code stimmt nicht oder ist abgelaufen.' } });
};

test('richtiger Code: Antwort wie pair_response.json, Kassa steht in der Liste', async () => {
  const c = await code(businessA, 'Kassa 1');
  const res = await pair(pairBody(c), nextIp());
  expect(res.statusCode).toBe(200);
  const body = res.json();
  expect(normalize(body)).toEqual(syncFixture('pair_response'));
  expect(body.businessId).toBe(businessA);

  const list = await app().inject({
    method: 'GET',
    url: `/api/admin/businesses/${businessA}/registers`,
    headers: { cookie: provider.cookie },
  });
  const listed = list.json().registers.find((r: { id: string }) => r.id === body.registerId);
  expect(listed).toEqual({
    id: body.registerId,
    name: 'Kassa 1',
    pairedAt: START.toISOString(),
    lastSeenAt: START.toISOString(),
    appVersion: '1.2.0',
    deviceModel: 'Redmi Pad Pro',
    blocked: false,
  });
  const entries = (await auditRows('register.pair')).filter((r) => r.detail.registerId === body.registerId);
  expect(entries).toHaveLength(1);
  expect(entries[0].business_id).toBe(businessA);
});

test('derselbe Code ein zweites Mal: 404 invalid_code', async () => {
  const c = await code();
  const ip = nextIp();
  expect((await pair(pairBody(c), ip)).statusCode).toBe(200);
  expectInvalidCode(await pair(pairBody(c), ip));
});

test('zwei Anfragen gleichzeitig mit demselben Code: genau eine 200, eine 404', async () => {
  const before = (await registers(businessA)).length;
  const c = await code();
  const results = await Promise.all([pair(pairBody(c), nextIp()), pair(pairBody(c), nextIp())]);
  expect(results.map((r) => r.statusCode).sort()).toEqual([200, 404]);
  expectInvalidCode(results.find((r) => r.statusCode === 404)!);
  expect(await registers(businessA)).toHaveLength(before + 1);
});

test('Code nach 15 Minuten und einer Sekunde: 404 invalid_code', async () => {
  const c = await code();
  a.now.value = new Date(START.getTime() + 15 * MINUTE + 1000);
  try {
    expectInvalidCode(await pair(pairBody(c), nextIp()));
  } finally {
    a.now.value = START;
  }
});

test('previousBusinessId eines anderen Betriebs: 409 other_business, der Code gilt danach noch', async () => {
  const before = (await registers(businessA)).length;
  const c = await code();
  const ip = nextIp();
  const res = await pair(pairBody(c, businessB), ip);
  expect(res.statusCode).toBe(409);
  expect(res.json().error.code).toBe('other_business');
  expect(typeof res.json().error.message).toBe('string');
  expect(await registers(businessA)).toHaveLength(before);
  expect(await registers(businessB)).toHaveLength(0);

  // Ein unbekannter Betrieb ist ebenfalls ein anderer.
  const unknown = await pair(pairBody(c, '00000000-0000-4000-8000-000000000000'), ip);
  expect(unknown.statusCode).toBe(409);

  const again = await pair(pairBody(c), ip);
  expect(again.statusCode).toBe(200);
  expect(again.json().businessId).toBe(businessA);
});

test('previousBusinessId desselben Betriebs: 200, zweiter Eintrag Kassa', async () => {
  const b = (await createBusiness(app(), provider.cookie)).id;
  const ip = nextIp();
  const first = await pair(pairBody(await code(b)), ip);
  expect(first.statusCode).toBe(200);
  const second = await pair(pairBody(await code(b), b.toUpperCase()), ip);
  expect(second.statusCode).toBe(200);
  expect(second.json().businessId).toBe(b);
  expect(second.json().registerId).not.toBe(first.json().registerId);
  expect(second.json().token).not.toBe(first.json().token);
  expect(await registers(b)).toHaveLength(2);
});

test('11. Fehlversuch derselben Adresse in 15 Minuten: 429, nach 15 Minuten wieder 404', async () => {
  const ip = nextIp();
  const valid = await code();
  try {
    // Eine Antwort 409 und ein gelungenes Koppeln zählen nicht als Fehlversuch und setzen nichts zurück.
    expect((await pair(pairBody(valid, businessB), ip)).statusCode).toBe(409);
    for (let i = 0; i < 5; i++) expectInvalidCode(await pair(pairBody('00000000'), ip));
    expect((await pair(pairBody(await code()), ip)).statusCode).toBe(200);
    a.now.value = new Date(START.getTime() + 5 * MINUTE);
    for (let i = 0; i < 5; i++) expectInvalidCode(await pair(pairBody('0000000x'), ip));

    const limited = await pair(pairBody('00000000'), ip);
    expect(limited.statusCode).toBe(429);
    expect(limited.json().error.code).toBe('too_many_attempts');
    expect(limited.json().error.message).toBe('Zu viele Versuche. Bitte in 10 Minuten nochmal.');
    expect(limited.json().retryAfterSeconds).toBe(600);
    expect(limited.headers['retry-after']).toBe('600');
    // Gesperrt ist gesperrt, auch mit dem richtigen Code.
    expect((await pair(pairBody(valid), ip)).statusCode).toBe(429);
    // Eine andere Adresse ist nicht betroffen.
    expectInvalidCode(await pair(pairBody('00000000'), nextIp()));

    // Nach 15 Minuten fallen die ersten fünf heraus, die zweiten fünf zählen noch.
    a.now.value = new Date(START.getTime() + 15 * MINUTE);
    expectInvalidCode(await pair(pairBody('00000000'), ip));
    expect((await pair(pairBody('00000000'), ip)).statusCode).toBe(404);
    for (let i = 0; i < 3; i++) await pair(pairBody('00000000'), ip);
    expect((await pair(pairBody('00000000'), ip)).statusCode).toBe(429);

    a.now.value = new Date(START.getTime() + 30 * MINUTE);
    expectInvalidCode(await pair(pairBody('00000000'), ip));
  } finally {
    a.now.value = START;
  }
});

test('40 falsche Codes gleichzeitig von einer Adresse: höchstens 10 erreichen die Datenbank, der Rest 429', async () => {
  const ip = nextIp();
  const results = await Promise.all(
    Array.from({ length: 40 }, (_, i) => pair(pairBody(String(10_000_000 + i)), ip)),
  );
  const status = results.map((r) => r.statusCode);
  expect(status.filter((s) => s === 404).length).toBeLessThanOrEqual(10);
  expect(status.filter((s) => s === 404).length + status.filter((s) => s === 429).length).toBe(40);
  for (const r of results.filter((x) => x.statusCode === 429)) {
    expect(r.json().error.code).toBe('too_many_attempts');
    expect(r.json().retryAfterSeconds).toBeGreaterThan(0);
  }
  // Auch der richtige Code kommt jetzt nicht mehr durch.
  expect((await pair(pairBody(await code()), ip)).statusCode).toBe(429);
});

test('ein gelungenes Koppeln verbraucht keinen der 10 Versuche', async () => {
  const ip = nextIp();
  for (let i = 0; i < 9; i++) expectInvalidCode(await pair(pairBody('00000000'), ip));
  for (let i = 0; i < 3; i++) expect((await pair(pairBody(await code()), ip)).statusCode).toBe(200);
  expectInvalidCode(await pair(pairBody('00000000'), ip));
  expect((await pair(pairBody('00000000'), ip)).statusCode).toBe(429);
});

test('409 other_business verbraucht keinen der 10 Versuche', async () => {
  const ip = nextIp();
  const c = await code();
  for (let i = 0; i < 9; i++) expectInvalidCode(await pair(pairBody('00000000'), ip));
  for (let i = 0; i < 3; i++) expect((await pair(pairBody(c, businessB), ip)).statusCode).toBe(409);
  expectInvalidCode(await pair(pairBody('00000000'), ip));
  expect((await pair(pairBody('00000000'), ip)).statusCode).toBe(429);
});

test('ohne CLIENT_IP_HEADER ändern X-Forwarded-For und X-Real-IP die Adresse nicht', async () => {
  const ip = nextIp();
  for (let i = 0; i < 10; i++) expectInvalidCode(await pair(pairBody('00000000'), ip));
  for (const headers of [{ 'x-forwarded-for': '1.2.3.4' }, { 'x-real-ip': '1.2.3.5' }, { 'x-forwarded-for': '1.2.3.6, 1.2.3.7' }]) {
    const res = await app().inject({ method: 'POST', url: '/api/device/pair', payload: pairBody('00000000'), remoteAddress: ip, headers });
    expect(res.statusCode, JSON.stringify(headers)).toBe(429);
  }
});

describe('mit CLIENT_IP_HEADER=x-real-ip', () => {
  let p: TestApp;
  beforeAll(async () => {
    p = await testApp({ config: { clientIpHeader: 'x-real-ip' } });
  });
  afterAll(async () => {
    await p.close();
  });
  const send = (headers: Record<string, string | string[]>) =>
    p.app.inject({ method: 'POST', url: '/api/device/pair', payload: pairBody('00000000'), remoteAddress: '10.9.9.9', headers });

  test('verschiedene X-Real-IP zählen getrennt, X-Forwarded-For zählt nicht', async () => {
    for (let i = 0; i < 10; i++) expect((await send({ 'x-real-ip': '203.0.113.1' })).statusCode).toBe(404);
    expect((await send({ 'x-real-ip': '203.0.113.1' })).statusCode).toBe(429);
    expect((await send({ 'x-real-ip': '203.0.113.1', 'x-forwarded-for': '198.51.100.7' })).statusCode).toBe(429);
    expect((await send({ 'x-real-ip': '203.0.113.2' })).statusCode).toBe(404);
    expect((await send({ 'x-real-ip': '203.0.113.2', 'x-forwarded-for': '203.0.113.1' })).statusCode).toBe(404);
  });

  test('ohne, mit leerer oder mit mehrfacher Kopfzeile gilt die Adresse der Verbindung', async () => {
    for (let i = 0; i < 10; i++) expect((await send({})).statusCode).toBe(404);
    expect((await send({})).statusCode).toBe(429);
    expect((await send({ 'x-real-ip': '' })).statusCode).toBe(429);
    expect((await send({ 'x-real-ip': ['203.0.113.50', '203.0.113.51'] })).statusCode).toBe(429);
    expect((await send({ 'x-real-ip': '203.0.113.52' })).statusCode).toBe(404);
  });
});

test('Code mit Buchstaben oder 7 Ziffern: 404 invalid_code', async () => {
  const c = await code();
  const ip = nextIp();
  for (const bad of [`${c.slice(0, 7)}x`, c.slice(0, 7), `${c}0`, ` ${c}`, '', 48201937, null]) {
    expectInvalidCode(await pair({ ...pairBody(c), code: bad }, ip));
  }
  const { code: _omit, ...withoutCode } = pairBody(c);
  expectInvalidCode(await pair(withoutCode, ip));
  // Die Fehlversuche haben den richtigen Code nicht verbraucht.
  expect((await pair(pairBody(c), ip)).statusCode).toBe(200);
});

test('Anfrage ohne JSON-Objekt oder mit falscher previousBusinessId: 400 bad_request', async () => {
  const c = await code();
  const ip = nextIp();
  for (const payload of [[c], { ...pairBody(c), previousBusinessId: 'kein-uuid' }, { ...pairBody(c), appVersion: 5 }]) {
    const res = await pair(payload, ip);
    expect(res.statusCode).toBe(400);
    expect(res.json().error.code).toBe('bad_request');
  }
  const ok = await pair({ code: c }, ip);
  expect(ok.statusCode).toBe(200);
  const reg = (await registers(businessA)).find((r) => r.id === ok.json().registerId);
  expect(reg.app_version).toBeNull();
  expect(reg.device_model).toBeNull();
});

test('der Schlüssel steht nicht in der Datenbank und nicht im Verlauf', async () => {
  const c = await code();
  const res = await pair(pairBody(c), nextIp());
  const { token, registerId } = res.json();
  expect(token).toMatch(/^[A-Za-z0-9_-]{43}$/);
  await pull(app(), token, '?since=0');
  await pull(app(), `${token}x`, '?since=0');

  const reg = (await registers(businessA)).find((r) => r.id === registerId);
  expect(Buffer.compare(reg.token_hash, sha256(token))).toBe(0);
  const hashHex = sha256(token).toString('hex');
  const dump = JSON.stringify(
    await withBusiness(a.db, businessA, async (cl) => ({
      registers: (await cl.query('select *, encode(token_hash, $1) as h from registers', ['base64'])).rows,
      codes: (await cl.query('select * from pairing_codes')).rows,
    })),
  );
  expect(dump).not.toContain(token);
  const auditDump = JSON.stringify(await withSystem(a.db, async (cl) => (await cl.query('select * from audit_log')).rows));
  for (const s of [token, hashHex, sha256(token).toString('base64'), c]) expect(auditDump).not.toContain(s);
  const logs = logLines.join('\n');
  expect(logs).toContain('/api/device/pair');
  expect(logs).toContain('/api/device/sync/pull');
  for (const s of [token, hashHex, c]) expect(logs).not.toContain(s);
});

describe('SlidingWindow', () => {
  const t = (ms: number) => new Date(START.getTime() + ms);

  test('erlaubt limit Treffer im Fenster, dann false, nach Ablauf wieder true', () => {
    const w = new SlidingWindow(3, 1000);
    expect([w.hit('x', t(0)), w.hit('x', t(100)), w.hit('x', t(200))]).toEqual([true, true, true]);
    expect(w.hit('x', t(300))).toBe(false);
    expect(w.hit('y', t(300))).toBe(true);
    expect(w.retryAfterMs('x', t(300))).toBe(700);
    expect(w.retryAfterMs('y', t(300))).toBe(0);
    // Der Treffer bei 0 fällt nach genau 1000 ms heraus.
    expect(w.retryAfterMs('x', t(1000))).toBe(0);
    expect(w.hit('x', t(1000))).toBe(true);
    expect(w.hit('x', t(1001))).toBe(false);
  });

  test('release gibt einen reservierten Treffer zurück', () => {
    const w = new SlidingWindow(2, 1000);
    expect(w.hit('x', t(0))).toBe(true);
    expect(w.hit('x', t(10))).toBe(true);
    expect(w.hit('x', t(20))).toBe(false);
    w.release('x', t(10));
    expect(w.hit('x', t(30))).toBe(true);
    expect(w.hit('x', t(40))).toBe(false);
    // Nach dem Zurückgeben aller Treffer ist der Schlüssel weg.
    w.release('x', t(0));
    w.release('x', t(30));
    expect(w.size).toBe(0);
  });

  test('abgelaufene Schlüssel fallen beim nächsten hit heraus', () => {
    const w = new SlidingWindow(3, 1000);
    w.hit('a', t(0));
    w.hit('b', t(500));
    expect(w.size).toBe(2);
    w.hit('c', t(1000));
    expect(w.size).toBe(2);
    w.hit('c', t(1600));
    expect(w.size).toBe(1);
  });

  test('höchstens maxKeys Schlüssel: ein neuer gilt dann als über der Grenze, bis alte ablaufen', () => {
    const w = new SlidingWindow(3, 1000, { maxKeys: 2 });
    expect(w.hit('a', t(0))).toBe(true);
    expect(w.hit('b', t(100))).toBe(true);
    expect(w.hit('c', t(200))).toBe(false);
    expect(w.retryAfterMs('c', t(200))).toBe(800);
    // Bekannte Schlüssel zählen weiter.
    expect(w.hit('a', t(300))).toBe(true);
    expect(w.size).toBe(2);
    // b läuft bei 1100 ab, a erst bei 1300.
    expect(w.hit('c', t(1100))).toBe(true);
    expect(w.hit('d', t(1100))).toBe(false);
    expect(w.size).toBe(2);
  });

  test('Vorgabe sind 50 000 Schlüssel', () => {
    const w = new SlidingWindow(1, 1000);
    for (let i = 0; i < 50_000; i++) expect(w.hit(`k${i}`, t(0))).toBe(true);
    expect(w.hit('neu', t(0))).toBe(false);
    expect(w.hit('neu', t(1000))).toBe(true);
    expect(w.size).toBe(1);
  });
});
