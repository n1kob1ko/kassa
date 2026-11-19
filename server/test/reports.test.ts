import { randomUUID } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, test } from 'vitest';
import { withBusiness } from '../src/db/tenant.js';
import { testApp, type TestApp } from './support/app.js';
import { createProvider, siteFor, type Site } from './support/admin_data.js';
import { authed, createChef, type TestUser } from './support/users.js';

let a: TestApp;
let provider: TestUser;
let one: Site;
let two: Site;

beforeAll(async () => {
  a = await testApp();
  provider = await createProvider(a.app, a.db);
  one = await siteFor(a, provider, 'Imbiss Eins');
  two = await siteFor(a, provider, 'Imbiss Zwei');
});
afterAll(async () => {
  await a.close();
});

/** Legt einen Bericht an; ohne `receivedAt` gilt now() der Transaktion. */
async function addReport(s: Site, o: { id?: string; receivedAt?: string; kind?: string; content?: object } = {}): Promise<string> {
  const id = o.id ?? randomUUID();
  await withBusiness(a.db, s.businessId, (c) =>
    c.query(
      `insert into reports (business_id, id, register_id, source, kind, at, app_version, device_model, count, content, received_at)
       values ($1, $2, $3, 'device', $4, '2026-11-19T08:11:00.123Z', '1.5.0', 'Redmi Pad Pro', 2, $5, coalesce($6::timestamptz, now()))`,
      [s.businessId, id, s.registerId, o.kind ?? 'error', JSON.stringify(o.content ?? { type: 'RangeError' }), o.receivedAt ?? null],
    ),
  );
  return id;
}

const list = (before: string | null, cookie = provider.cookie) =>
  a.app.inject({
    method: 'GET',
    url: `/api/admin/reports${before === null ? '' : `?before=${encodeURIComponent(before)}`}`,
    headers: authed(cookie),
  });

describe('Fehlerberichte für den Anbieter', () => {
  test('Berichte zweier Betriebe, neueste zuerst, mit Namen', async () => {
    const x = await addReport(one, { receivedAt: '2026-11-19T08:00:00Z' });
    const y = await addReport(two, { receivedAt: '2026-11-19T09:00:00Z', kind: 'device_test' });
    const z = await addReport(one, { receivedAt: '2026-11-19T10:00:00Z' });
    const res = await list(null);
    expect(res.statusCode).toBe(200);
    const body = res.json();
    const mine = body.reports.filter((r: { id: string }) => [x, y, z].includes(r.id));
    expect(mine.map((r: { id: string }) => r.id)).toEqual([z, y, x]);
    expect(mine[0]).toEqual({
      id: z,
      businessName: 'Imbiss Eins',
      registerName: expect.any(String),
      source: 'device',
      kind: 'error',
      at: '2026-11-19T08:11:00.123Z',
      appVersion: '1.5.0',
      deviceModel: 'Redmi Pad Pro',
      count: 2,
      content: { type: 'RangeError' },
    });
    expect(mine[1].businessName).toBe('Imbiss Zwei');
    expect(body.next).toBeNull();
  });

  test('Chef bekommt 404, ohne Anmeldung 401', async () => {
    const chef = await createChef(a.db, one.businessId);
    expect((await list(null, chef.cookie)).statusCode).toBe(404);
    const anon = await a.app.inject({ method: 'GET', url: '/api/admin/reports' });
    expect(anon.statusCode).toBe(401);
  });

  test('Seiten über before: 50 pro Seite, nichts doppelt, nichts verloren, auch bei gleicher Eingangszeit', async () => {
    const t = await testApp();
    try {
      const p = await createProvider(t.app, t.db);
      const s1 = await siteFor(t, p, 'Blatt Eins');
      const s2 = await siteFor(t, p, 'Blatt Zwei');
      const ids: string[] = [];
      for (const s of [s1, s2]) {
        // Eine Transaktion pro Betrieb: alle 60 Berichte haben denselben received_at.
        await withBusiness(t.db, s.businessId, async (c) => {
          for (let i = 0; i < 60; i++) {
            const id = randomUUID();
            ids.push(id);
            await c.query(
              `insert into reports (business_id, id, register_id, source, kind, at, content)
               values ($1, $2, $3, 'device', 'error', now(), '{}')`,
              [s.businessId, id, s.registerId],
            );
          }
        });
      }
      const seen: string[] = [];
      let before: string | null = null;
      const sizes: number[] = [];
      for (let page = 0; page < 10; page++) {
        const res: Awaited<ReturnType<typeof t.app.inject>> = await t.app.inject({
          method: 'GET',
          url: `/api/admin/reports${before === null ? '' : `?before=${encodeURIComponent(before)}`}`,
          headers: authed(p.cookie),
        });
        expect(res.statusCode).toBe(200);
        const body: { reports: { id: string }[]; next: string | null } = res.json();
        sizes.push(body.reports.length);
        seen.push(...body.reports.map((r: { id: string }) => r.id));
        before = body.next;
        if (before === null) break;
      }
      expect(sizes).toEqual([50, 50, 20]);
      expect(seen).toHaveLength(120);
      expect([...seen].sort()).toEqual([...ids].sort());
    } finally {
      await t.close();
    }
  });

  test('ein unlesbares before ist 422 before_invalid, nie 500', async () => {
    const id = randomUUID();
    for (const bad of [
      'abc',
      '2026-11-19T08:00:00.000Z',
      `2026-11-19 08:00:00+00_nichtuuid`,
      `2026-02-31 08:00:00+00_${id}`,
      `2026-13-01 08:00:00+00_${id}`,
      `2026-11-19 25:00:00+00_${id}`,
      `_${id}`,
      `2026-11-19 08:00:00+00_`,
      `'; drop table reports; --_${id}`,
    ]) {
      const res = await list(bad);
      expect(res.statusCode, bad).toBe(422);
      expect(res.json().error.code).toBe('before_invalid');
    }
  });
});
