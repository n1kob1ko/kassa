import { afterAll, beforeAll, expect, test } from 'vitest';
import { withBusiness, withSystem } from '../src/db/tenant.js';
import { MenuImportError, parseMenuFile } from '../src/menu/parse_menu.js';
import { testApp, type TestApp } from './support/app.js';
import { createBusiness, menuFixture } from './support/businesses.js';
import { authed, createChef, createProvider, type TestUser } from './support/users.js';

let a: TestApp;
let provider: TestUser;
beforeAll(async () => {
  a = await testApp();
  provider = await createProvider(a.app, a.db);
});
afterAll(async () => {
  await a.close();
});

const post = (url: string, menuFile: unknown, cookie = provider.cookie) =>
  a.app.inject({ method: 'POST', url, headers: authed(cookie), payload: { menuFile } });
const get = (url: string, cookie?: string) =>
  a.app.inject({ method: 'GET', url, headers: cookie ? { cookie } : {} });

const rows = <T = any>(b: string, sql: string) =>
  withBusiness(a.db, b, async (c) => (await c.query(sql)).rows as T[]);

test('Anlegen aus der Beispieldatei: 201, 3 Artikel, 2 Kategorien, 1 Vorlage', async () => {
  const res = await post('/api/admin/businesses', menuFixture('beispiel-imbiss'));
  expect(res.statusCode).toBe(201);
  const body = res.json();
  expect(body.business).toEqual({ id: expect.stringMatching(/^[0-9a-f-]{36}$/), name: 'Beispiel-Imbiss' });
  expect(body.summary).toEqual({
    categories: { added: 2, changed: 0, archived: 0 },
    items: { added: 3, changed: 0, archived: 0 },
    templates: { added: 1, changed: 0, archived: 0 },
  });
  const id = body.business.id;
  expect(await rows(id, 'select 1 from items')).toHaveLength(3);
  expect(await rows(id, 'select 1 from categories')).toHaveLength(2);
  expect(await rows(id, 'select 1 from modifier_templates')).toHaveLength(1);
});

test('ungültige Datei: 422 menu_invalid mit denselben problems wie parseMenuFile', async () => {
  const text = menuFixture('fehler-mehrere');
  let expected: string[] = [];
  try {
    parseMenuFile(text);
  } catch (e) {
    expected = (e as MenuImportError).problems;
  }
  expect(expected.length).toBeGreaterThan(1);
  const before = (await withSystem(a.db, (c) => c.query('select count(*)::int as n from businesses'))).rows[0].n;
  const res = await post('/api/admin/businesses', text);
  expect(res.statusCode).toBe(422);
  expect(res.json()).toEqual({
    error: { code: 'menu_invalid', message: expect.any(String) },
    problems: expected,
  });
  const after = (await withSystem(a.db, (c) => c.query('select count(*)::int as n from businesses'))).rows[0].n;
  expect(after).toBe(before);
});

test('Datei mit 1 MB und einem Byte: 413 file_too_large, mit genau 1 MB nicht', async () => {
  const base = menuFixture('beispiel-imbiss').trimEnd();
  const pad = (n: number) => base.slice(0, -1) + `,"quelle":"${'x'.repeat(n)}"}`;
  const limit = 1024 * 1024;
  const over = pad(limit - Buffer.byteLength(pad(0)) + 1);
  expect(Buffer.byteLength(over)).toBe(limit + 1);
  const res = await post('/api/admin/businesses', over);
  expect(res.statusCode).toBe(413);
  expect(res.json().error.code).toBe('file_too_large');
  const exact = pad(limit - Buffer.byteLength(pad(0)));
  expect(Buffer.byteLength(exact)).toBe(limit);
  expect((await post('/api/admin/businesses', exact)).statusCode).toBe(201);
});

test('Datei mit Byte-Order-Mark wird wie ohne eingespielt', async () => {
  const text = menuFixture('mit-bom');
  expect(text.charCodeAt(0)).toBe(0xfeff);
  const res = await post('/api/admin/businesses', text);
  expect(res.statusCode).toBe(201);
  const plain = await post('/api/admin/businesses', text.slice(1));
  expect(plain.json().summary).toEqual(res.json().summary);
});

test('Preis über der Grenze: 422 menu_invalid mit einer Zeile, kein Betrieb', async () => {
  const file = JSON.parse(menuFixture('beispiel-imbiss'));
  file.artikel[0].preis_cent = 5_000_000_000;
  file.artikel[2].pfand_cent = 1e20;
  const before = (await withSystem(a.db, (c) => c.query('select count(*)::int as n from businesses'))).rows[0].n;
  const res = await post('/api/admin/businesses', JSON.stringify(file));
  expect(res.statusCode).toBe(422);
  const body = res.json();
  expect(body.error.code).toBe('menu_invalid');
  expect(body.problems).toHaveLength(2);
  expect(body.problems[0]).toContain('"huhn-bowl"');
  expect(body.problems[1]).toContain('"cola"');
  const after = (await withSystem(a.db, (c) => c.query('select count(*)::int as n from businesses'))).rows[0].n;
  expect(after).toBe(before);
});

test('menuFile fehlt oder ist kein Text: 400 bad_request', async () => {
  expect((await post('/api/admin/businesses', 5)).statusCode).toBe(400);
  const res = await a.app.inject({ method: 'POST', url: '/api/admin/businesses', headers: authed(provider.cookie), payload: {} });
  expect(res.statusCode).toBe(400);
  expect(res.json().error.code).toBe('bad_request');
});

test('zwei Betriebe aus derselben Datei: jeder hat seine eigene "cola"', async () => {
  const one = await createBusiness(a.app, provider.cookie);
  const two = await createBusiness(a.app, provider.cookie);
  expect(one.id).not.toBe(two.id);
  const changed = JSON.parse(menuFixture('beispiel-imbiss'));
  changed.artikel[2].preis_cent = 999;
  expect((await post(`/api/admin/businesses/${one.id}/menu`, JSON.stringify(changed))).statusCode).toBe(200);
  expect((await rows(one.id, `select price_cents from items where id = 'cola'`))[0].price_cents).toBe(999);
  expect((await rows(two.id, `select price_cents from items where id = 'cola'`))[0].price_cents).toBe(290);
  expect(await rows(two.id, 'select 1 from items')).toHaveLength(3);
});

test('Liste und Betrieb: Zahlen, sortiert nach Name, Kategorien mit Artikelzahl', async () => {
  const x = await createBusiness(a.app, provider.cookie);
  const file = JSON.parse(menuFixture('beispiel-imbiss'));
  file.betrieb = 'AAA Erster Imbiss';
  const made = (await post('/api/admin/businesses', JSON.stringify(file))).json().business;
  const list = (await get('/api/admin/businesses', provider.cookie)).json().businesses;
  const names = list.map((r: any) => r.name);
  expect(names).toEqual([...names].sort((p: string, q: string) => p.localeCompare(q, 'de')));
  expect(names[0]).toBe('AAA Erster Imbiss');
  expect(list.find((r: any) => r.id === x.id)).toEqual({
    id: x.id,
    name: 'Beispiel-Imbiss',
    counts: { items: 3, staff: 0, registers: 0 },
  });
  expect(made.name).toBe('AAA Erster Imbiss');

  const res = await get(`/api/admin/businesses/${x.id}`, provider.cookie);
  expect(res.statusCode).toBe(200);
  expect(res.json()).toEqual({
    business: {
      id: x.id,
      name: 'Beispiel-Imbiss',
      addressLines: ['Musterstraße 1', '1010 Wien'],
      vatId: 'ATU12345678',
      receiptFooter: 'Danke und bis bald!',
      counts: { categories: 2, items: 3, templates: 1, staff: 0, registers: 0 },
    },
    categories: [
      { id: 'bowls', name: 'Bowls', itemCount: 2, archived: false },
      { id: 'getraenke', name: 'Getränke', itemCount: 1, archived: false },
    ],
  });
});

test('Neu einspielen: 200 mit summary und ignoredStaff', async () => {
  const b = await createBusiness(a.app, provider.cookie, 'mitarbeiter-in-datei');
  const res = await post(`/api/admin/businesses/${b.id}/menu`, menuFixture('mitarbeiter-in-datei'));
  expect(res.statusCode).toBe(200);
  expect(res.json()).toEqual({
    summary: {
      categories: { added: 0, changed: 0, archived: 0 },
      items: { added: 0, changed: 0, archived: 0 },
      templates: { added: 0, changed: 0, archived: 0 },
    },
    ignoredStaff: 2,
  });
  expect(await rows(b.id, 'select 1 from staff')).toHaveLength(0);
  const bad = await post(`/api/admin/businesses/${b.id}/menu`, menuFixture('fehler-mehrere'));
  expect(bad.statusCode).toBe(422);
  expect(bad.json().error.code).toBe('menu_invalid');
  const big = await post(`/api/admin/businesses/${b.id}/menu`, 'x'.repeat(1024 * 1024 + 1));
  expect(big.statusCode).toBe(413);
  expect(big.json().error.code).toBe('file_too_large');
});

test('Chef von A: Liste 404, Betrieb B 404, Betrieb A 200, neu einspielen 404', async () => {
  const A = await createBusiness(a.app, provider.cookie);
  const B = await createBusiness(a.app, provider.cookie);
  const chef = await createChef(a.db, A.id);
  expect((await get('/api/admin/businesses', chef.cookie)).statusCode).toBe(404);
  expect((await get(`/api/admin/businesses/${B.id}`, chef.cookie)).statusCode).toBe(404);
  const own = await get(`/api/admin/businesses/${A.id}`, chef.cookie);
  expect(own.statusCode).toBe(200);
  expect(own.json().business.id).toBe(A.id);
  const changed = JSON.parse(menuFixture('beispiel-imbiss'));
  changed.artikel[2].preis_cent = 1;
  const text = JSON.stringify(changed);
  for (const id of [A.id, B.id]) {
    const res = await post(`/api/admin/businesses/${id}/menu`, text, chef.cookie);
    expect(res.statusCode).toBe(404);
    expect(res.json().error.code).toBe('not_found');
  }
  expect((await post('/api/admin/businesses', text, chef.cookie)).statusCode).toBe(404);
  // Nichts hat sich geändert.
  expect((await rows(A.id, `select price_cents from items where id = 'cola'`))[0].price_cents).toBe(290);
  expect((await rows(B.id, `select price_cents from items where id = 'cola'`))[0].price_cents).toBe(290);
});

test('fremder, unbekannter und kaputter Betrieb: 404 not_found, Einspielen ändert nichts', async () => {
  const A = await createBusiness(a.app, provider.cookie);
  const B = await createBusiness(a.app, provider.cookie);
  const changed = JSON.parse(menuFixture('beispiel-imbiss'));
  changed.artikel = [];
  const unknown = '00000000-0000-4000-8000-000000000000';
  for (const id of [unknown, 'kein-uuid', '1; drop table items']) {
    expect((await get(`/api/admin/businesses/${encodeURIComponent(id)}`, provider.cookie)).statusCode).toBe(404);
    const res = await post(`/api/admin/businesses/${encodeURIComponent(id)}/menu`, JSON.stringify(changed));
    expect(res.statusCode).toBe(404);
    expect(res.json().error.code).toBe('not_found');
  }
  // Das Einspielen in A lässt B unberührt und B zeigt nur seine eigenen Zeilen.
  expect((await post(`/api/admin/businesses/${A.id}/menu`, JSON.stringify(changed))).statusCode).toBe(200);
  expect(await rows(B.id, 'select 1 from items where not archived')).toHaveLength(3);
  expect(await rows(A.id, 'select 1 from items where not archived')).toHaveLength(0);
  const detailB = (await get(`/api/admin/businesses/${B.id}`, provider.cookie)).json();
  expect(detailB.business.counts.items).toBe(3);
  const detailA = (await get(`/api/admin/businesses/${A.id}`, provider.cookie)).json();
  expect(detailA.business.counts.items).toBe(0);
  expect(detailA.categories.map((c: any) => c.itemCount)).toEqual([0, 0]);
});

test('ohne Anmeldung: 401', async () => {
  const b = await createBusiness(a.app, provider.cookie);
  expect((await get('/api/admin/businesses')).statusCode).toBe(401);
  expect((await get(`/api/admin/businesses/${b.id}`)).statusCode).toBe(401);
  const post1 = await a.app.inject({
    method: 'POST',
    url: '/api/admin/businesses',
    headers: { 'x-kassa-request': '1' },
    payload: { menuFile: menuFixture('beispiel-imbiss') },
  });
  expect(post1.statusCode).toBe(401);
  expect(post1.json().error.code).toBe('unauthorized');
  const post2 = await a.app.inject({
    method: 'POST',
    url: `/api/admin/businesses/${b.id}/menu`,
    headers: { 'x-kassa-request': '1' },
    payload: { menuFile: menuFixture('beispiel-imbiss') },
  });
  expect(post2.statusCode).toBe(401);
});

test('POST ohne X-Kassa-Request: 403 csrf', async () => {
  const res = await a.app.inject({
    method: 'POST',
    url: '/api/admin/businesses',
    headers: { cookie: provider.cookie },
    payload: { menuFile: menuFixture('beispiel-imbiss') },
  });
  expect(res.statusCode).toBe(403);
  expect(res.json().error.code).toBe('csrf');
});

test('Anlegen und Einspielen stehen im Verlauf, ohne Dateiinhalt', async () => {
  const b = await createBusiness(a.app, provider.cookie);
  await post(`/api/admin/businesses/${b.id}/menu`, menuFixture('beispiel-imbiss'));
  const log = (
    await withSystem(a.db, (c) =>
      c.query(`select * from audit_log where business_id = $1 order by id`, [b.id]),
    )
  ).rows;
  expect(log.map((r) => r.action)).toEqual(['business.create', 'business.menu_import']);
  for (const r of log) {
    expect(r.user_id).toBe(provider.user.id);
    expect(JSON.stringify(r.detail)).not.toContain('Huhn');
    expect(JSON.stringify(r.detail)).not.toContain('menuFile');
  }
  expect(log[1].detail).toMatchObject({ summary: { items: { added: 0, changed: 0, archived: 0 } }, ignoredStaff: 0 });
});
