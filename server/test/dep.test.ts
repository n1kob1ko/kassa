import { randomUUID } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { afterAll, beforeAll, describe, expect, test } from 'vitest';
import { withSystem } from '../src/db/tenant.js';
import { testApp, type TestApp } from './support/app.js';
import { createProvider, send, siteFor, type Site } from './support/admin_data.js';
import { pairDevice } from './support/device.js';
import { sampleReceipt } from './support/push.js';
import { freshToken } from './support/stufe_1b.js';
import { authed, createChef, type TestUser } from './support/users.js';

const dep = JSON.parse(readFileSync(new URL('../../shared/fixtures/rksv/dep.json', import.meta.url), 'utf8')) as {
  certificates: object[];
  chain: Record<string, unknown>;
  entries: object[];
  expected: object;
};

let a: TestApp;
let provider: TestUser;
beforeAll(async () => {
  a = await testApp();
  provider = await createProvider(a.app, a.db);
});
afterAll(async () => {
  await a.close();
});

const get = (s: Pick<Site, 'businessId'>, registerId: string, query: string, cookie = provider.cookie) =>
  a.app.inject({ method: 'GET', url: `/api/admin/businesses/${s.businessId}/registers/${registerId}/dep${query}`, headers: authed(cookie) });
const auditRows = () =>
  withSystem(a.db, async (c) => (await c.query(`select * from audit_log where action = 'rksv.dep_download' order by id`)).rows);

/** Spielt das gemeinsame Beispiel so ein, wie das Tablet es sendet. */
async function sendExample(s: Pick<Site, 'token' | 'deviceId'>): Promise<void> {
  await send(a, s, [
    ...dep.certificates.map((c): [string, object] => ['rksv_certificate', c]),
    ['rksv_chain', dep.chain],
    // Der Schlüssel der Seite gilt über alle Betriebe, das Beispiel geht an mehrere: jeder gesendete Bon mit Schlüssel
    // bekommt einen eigenen (wie in support/stufe_1b.ts). Er steht nicht in der Protokoll-Datei.
    ...dep.entries.map((e): [string, object] => [
      'receipt',
      (e as { publicToken?: string | null }).publicToken ? { ...e, publicToken: freshToken() } : e,
    ]),
  ]);
}

describe('Protokoll-Datei', () => {
  test('gemeinsames Beispiel: dieselbe Datei wie die App', async () => {
    const s = await siteFor(a, provider);
    await sendExample(s);
    const res = await get(s, s.registerId, '?chain=1');
    expect(res.statusCode).toBe(200);
    expect(res.headers['content-type']).toMatch(/^application\/json/);
    expect(res.headers['content-disposition']).toBe('attachment; filename="kassa-protokoll-DEMOKASSA1-kette-1.json"');
    expect(res.json()).toEqual(dep.expected);
    expect(res.body).toBe(JSON.stringify(dep.expected));
    expect(Object.keys(res.json())).toEqual(['Belege-Gruppe']);
  });

  test('Kette eines anderen Geräts desselben Betriebs kommt nicht mit', async () => {
    const s = await siteFor(a, provider);
    await sendExample(s);
    const other = await pairDevice(a.app, provider.cookie, s.businessId);
    const second = { token: other.token, deviceId: randomUUID() };
    await send(a, second, [
      ['rksv_certificate', { serialHex: 'ffff', certificate: 'AAAA', issuers: [] }],
      ['rksv_chain', { ...dep.chain, chain: 2, cashBoxId: 'ZWEITE', certSerial: 'ffff' }],
      ['receipt', sampleReceipt({ number: 1, kind: 'start', businessDayId: null, payment: null, rksv: { chain: 2, position: 1, jws: 'a.b.c', damaged: false, certSerial: 'ffff' } })],
    ]);
    const first = await get(s, s.registerId, '?chain=1');
    expect(first.json()).toEqual(dep.expected);
    expect(JSON.stringify(first.json())).not.toContain('a.b.c');
    // Die zweite Kassa hat eine Kette 2, die erste nicht.
    expect((await get(s, s.registerId, '?chain=2')).statusCode).toBe(404);
    const two = await get(s, other.registerId, '?chain=2');
    expect(two.statusCode).toBe(200);
    expect(two.json()).toEqual({ 'Belege-Gruppe': [{ Signaturzertifikat: 'AAAA', Zertifizierungsstellen: [], 'Belege-kompakt': ['a.b.c'] }] });
    expect(two.headers['content-disposition']).toContain('kassa-protokoll-ZWEITE-kette-2.json');
    expect((await get(s, other.registerId, '?chain=1')).statusCode).toBe(404);
  });

  test('Download steht im Verlauf, ohne Signatur', async () => {
    const s = await siteFor(a, provider);
    await sendExample(s);
    const before = (await auditRows()).length;
    expect((await get(s, s.registerId, '?chain=1')).statusCode).toBe(200);
    const rows = await auditRows();
    expect(rows).toHaveLength(before + 1);
    const last = rows.at(-1);
    expect(last.business_id).toBe(s.businessId);
    expect(last.user_id).toBe(provider.user.id);
    expect(last.detail).toEqual({ registerId: s.registerId, chain: 1, cashBoxId: 'DEMOKASSA1' });
    // Ein Fehlversuch steht nicht im Verlauf.
    await get(s, s.registerId, '?chain=9');
    expect(await auditRows()).toHaveLength(before + 1);
  });

  test('Probe-Kette wird geliefert', async () => {
    const s = await siteFor(a, provider);
    await sendExample(s);
    expect(dep.chain.mode).toBe('probe');
    expect((await get(s, s.registerId, '?chain=1')).statusCode).toBe(200);
  });

  test('Kette ohne Einträge: leere Gruppenliste', async () => {
    const s = await siteFor(a, provider);
    await send(a, s, [['rksv_chain', dep.chain]]);
    const res = await get(s, s.registerId, '?chain=1');
    expect(res.statusCode).toBe(200);
    expect(res.json()).toEqual({ 'Belege-Gruppe': [] });
  });

  test.each([[''], ['?chain='], ['?chain=0'], ['?chain=-1'], ['?chain=1.5'], ['?chain=abc'], ['?chain=1e2'], ['?chain=1&chain=2']])(
    'chain %j: 422',
    async (query) => {
      const s = await siteFor(a, provider);
      await sendExample(s);
      const res = await get(s, s.registerId, query);
      expect(res.statusCode).toBe(422);
      expect(res.json().error.code).toBe('chain_invalid');
    },
  );

  test('unbekannte Kassa, Kassa ohne Geräte-Kennung, unbekannte Kette: 404', async () => {
    const s = await siteFor(a, provider);
    expect((await get(s, s.registerId, '?chain=1')).statusCode).toBe(404); // noch nichts gesendet: keine Geräte-Kennung
    await sendExample(s);
    expect((await get(s, randomUUID(), '?chain=1')).statusCode).toBe(404);
    expect((await get(s, 'kein-uuid', '?chain=1')).statusCode).toBe(404);
    expect((await get(s, s.registerId, '?chain=2')).statusCode).toBe(404);
  });

  test('zweiter Betrieb: 404, auch mit der Kassa des ersten', async () => {
    const s1 = await siteFor(a, provider, 'Eins');
    const s2 = await siteFor(a, provider, 'Zwei');
    await sendExample(s1);
    await sendExample(s2);
    const chef1 = await createChef(a.db, s1.businessId);
    const chef2 = await createChef(a.db, s2.businessId);
    expect((await get(s1, s1.registerId, '?chain=1', chef1.cookie)).statusCode).toBe(200);
    expect((await get(s1, s1.registerId, '?chain=1', chef2.cookie)).statusCode).toBe(404);
    // Die Kassa des ersten Betriebs über den zweiten Betrieb: nichts.
    expect((await get(s2, s1.registerId, '?chain=1')).statusCode).toBe(404);
    expect((await get(s1, s2.registerId, '?chain=1')).statusCode).toBe(404);
    expect((await a.app.inject({ method: 'GET', url: `/api/admin/businesses/${s1.businessId}/registers/${s1.registerId}/dep?chain=1` })).statusCode).toBe(401);
  });
});
