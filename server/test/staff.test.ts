import { readFileSync } from 'node:fs';
import type { FastifyInstance } from 'fastify';
import { afterAll, beforeAll, expect, test } from 'vitest';
import { pinHash } from '../src/admin/staff.js';
import { withBusiness, withSystem } from '../src/db/tenant.js';
import { testApp, type TestApp } from './support/app.js';
import { insertBusiness, authed, createChef, createProvider, type TestUser } from './support/users.js';

const fixture = JSON.parse(
  readFileSync(new URL('../../shared/fixtures/pin_hash.json', import.meta.url), 'utf8'),
) as { salt: string; pin: string; hash: string };

let a: TestApp;
let provider: TestUser;
beforeAll(async () => {
  a = await testApp();
  provider = await createProvider(a.app, a.db);
});
afterAll(async () => {
  await a.close();
});

const app = (): FastifyInstance => a.app;
const list = (b: string, cookie = provider.cookie) =>
  app().inject({ method: 'GET', url: `/api/admin/businesses/${b}/staff`, headers: { cookie } });
const create = (b: string, payload: unknown, cookie = provider.cookie) =>
  app().inject({ method: 'POST', url: `/api/admin/businesses/${b}/staff`, headers: authed(cookie), payload: payload as object });
const patch = (b: string, id: string, payload: unknown, cookie = provider.cookie) =>
  app().inject({ method: 'PATCH', url: `/api/admin/businesses/${b}/staff/${id}`, headers: authed(cookie), payload: payload as object });

/** Ein Betrieb mit einer Chefin (PIN 1111). */
async function businessWithChef(): Promise<{ b: string; chefId: string }> {
  const b = await insertBusiness(a.db);
  const res = await create(b, { name: 'Chefin', role: 'chef', pin: '1111' });
  expect(res.statusCode).toBe(201);
  return { b, chefId: res.json().staff.id };
}

const staffRow = (b: string, id: string) =>
  withBusiness(a.db, b, async (c) => (await c.query('select * from staff where id = $1', [id])).rows[0]);

test('pinHash trifft den Wert aus shared/fixtures/pin_hash.json', () => {
  expect(pinHash(fixture.salt, fixture.pin)).toBe(fixture.hash);
});

test('erster Mitarbeiter als staff: 422 first_must_be_chef', async () => {
  const b = await insertBusiness(a.db);
  const res = await create(b, { name: 'Max', role: 'staff', pin: '2222' });
  expect(res.statusCode).toBe(422);
  expect(res.json().error.code).toBe('first_must_be_chef');
  expect((await list(b)).json().staff).toEqual([]);
});

test('anlegen: 201, Antwort und Liste enthalten weder pinSalt noch pinHash', async () => {
  const b = await insertBusiness(a.db);
  const res = await create(b, { name: '  Chefin  ', role: 'chef', pin: '1111' });
  expect(res.statusCode).toBe(201);
  expect(res.json()).toEqual({
    staff: { id: expect.stringMatching(/^[0-9a-f-]{36}$/), name: 'Chefin', role: 'chef', archived: false },
  });
  await create(b, { name: 'Anna', role: 'staff', pin: '2222' });
  const l = await list(b);
  expect(l.statusCode).toBe(200);
  for (const text of [res.body, l.body]) {
    expect(text).not.toMatch(/pinSalt|pinHash|pin_salt|pin_hash|1111|2222/);
  }
  const row = await staffRow(b, res.json().staff.id);
  expect(row.pin_salt).toMatch(/^[0-9a-f]{32}$/);
  expect(row.pin_hash).toBe(pinHash(row.pin_salt, '1111'));
});

test('Liste: aktive zuerst, dann nach Name', async () => {
  const { b } = await businessWithChef();
  const zoe = (await create(b, { name: 'Zoe', role: 'staff', pin: '3333' })).json().staff.id;
  await create(b, { name: 'Berta', role: 'staff', pin: '4444' });
  await patch(b, zoe, { archived: true });
  const names = (await list(b)).json().staff.map((s: { name: string }) => s.name);
  expect(names).toEqual(['Berta', 'Chefin', 'Zoe']);
});

test.each(['12a4', '123', '12345', '', ' 123', 1234, null])('PIN %j: 422 pin_invalid', async (pin) => {
  const { b } = await businessWithChef();
  const res = await create(b, { name: 'Anna', role: 'staff', pin });
  expect(res.statusCode).toBe(422);
  expect(res.json().error).toEqual({ code: 'pin_invalid', message: 'Die PIN muss aus genau vier Ziffern bestehen.' });
});

test('Name und Rolle: 422 name_invalid und role_invalid', async () => {
  const { b } = await businessWithChef();
  for (const name of ['', '   ', 'x'.repeat(41), 5]) {
    const res = await create(b, { name, role: 'staff', pin: '2222' });
    expect(res.statusCode).toBe(422);
    expect(res.json().error.code).toBe('name_invalid');
  }
  expect((await create(b, { name: 'x'.repeat(40), role: 'staff', pin: '2222' })).statusCode).toBe(201);
  for (const role of ['boss', undefined, 1]) {
    const res = await create(b, { name: 'Anna', role, pin: '5555' });
    expect(res.statusCode).toBe(422);
    expect(res.json().error.code).toBe('role_invalid');
  }
});

test('gleiche PIN im selben Betrieb: 409 pin_taken, in einem anderen Betrieb erlaubt', async () => {
  const { b } = await businessWithChef();
  const res = await create(b, { name: 'Anna', role: 'staff', pin: '1111' });
  expect(res.statusCode).toBe(409);
  expect(res.json().error).toEqual({ code: 'pin_taken', message: 'Diese PIN ist schon vergeben.' });
  const other = await businessWithChef();
  expect((await list(other.b)).json().staff).toHaveLength(1);
  // 1111 ist in other.b schon die PIN der dortigen Chefin, in einem dritten Betrieb ist sie frei.
  const third = await insertBusiness(a.db);
  expect((await create(third, { name: 'Chef', role: 'chef', pin: '1111' })).statusCode).toBe(201);
});

test('PIN ändern auf eine vergebene: 409, auf die eigene: 200', async () => {
  const { b, chefId } = await businessWithChef();
  const anna = (await create(b, { name: 'Anna', role: 'staff', pin: '2222' })).json().staff.id;
  expect((await patch(b, anna, { pin: '1111' })).statusCode).toBe(409);
  expect((await patch(b, anna, { pin: '2222' })).statusCode).toBe(200);
  expect((await patch(b, chefId, { pin: '9999' })).statusCode).toBe(200);
  const row = await staffRow(b, chefId);
  expect(row.pin_hash).toBe(pinHash(row.pin_salt, '9999'));
});

test('zwei gleichzeitige Anlegen mit derselben PIN: genau 201 und 409', async () => {
  const { b } = await businessWithChef();
  const results = await Promise.all([
    create(b, { name: 'Anna', role: 'staff', pin: '7777' }),
    create(b, { name: 'Bernd', role: 'staff', pin: '7777' }),
  ]);
  expect(results.map((r) => r.statusCode).sort()).toEqual([201, 409]);
  expect((await list(b)).json().staff).toHaveLength(2);
});

test('PIN eines stillgelegten Mitarbeiters ist wieder frei', async () => {
  const { b } = await businessWithChef();
  const anna = (await create(b, { name: 'Anna', role: 'staff', pin: '2222' })).json().staff.id;
  expect((await patch(b, anna, { archived: true })).json().staff.archived).toBe(true);
  expect((await create(b, { name: 'Bernd', role: 'staff', pin: '2222' })).statusCode).toBe(201);
});

test('wieder aktivieren mit inzwischen vergebener PIN: 409 pin_taken', async () => {
  const { b } = await businessWithChef();
  const anna = (await create(b, { name: 'Anna', role: 'staff', pin: '2222' })).json().staff.id;
  await patch(b, anna, { archived: true });
  await create(b, { name: 'Bernd', role: 'staff', pin: '2222' });
  const res = await patch(b, anna, { archived: false });
  expect(res.statusCode).toBe(409);
  expect(res.json().error.code).toBe('pin_taken');
  expect((await staffRow(b, anna)).archived).toBe(true);
  // Mit neuer PIN geht es.
  const ok = await patch(b, anna, { archived: false, pin: '3333' });
  expect(ok.statusCode).toBe(200);
  expect(ok.json().staff.archived).toBe(false);
});

test('wieder aktivieren mit freier PIN: 200 und die alte PIN gilt weiter', async () => {
  const { b } = await businessWithChef();
  const anna = (await create(b, { name: 'Anna', role: 'staff', pin: '2222' })).json().staff.id;
  await patch(b, anna, { archived: true });
  expect((await patch(b, anna, { archived: false })).statusCode).toBe(200);
  expect((await create(b, { name: 'Bernd', role: 'staff', pin: '2222' })).statusCode).toBe(409);
});

test('letzten Chef stilllegen oder herabstufen: 409 last_chef, mit zweitem Chef erlaubt', async () => {
  const { b, chefId } = await businessWithChef();
  for (const change of [{ archived: true }, { role: 'staff' }]) {
    const res = await patch(b, chefId, change);
    expect(res.statusCode).toBe(409);
    expect(res.json().error).toEqual({ code: 'last_chef', message: 'Mindestens ein Chef muss bleiben.' });
  }
  expect(await staffRow(b, chefId)).toMatchObject({ role: 'chef', archived: false });
  const second = (await create(b, { name: 'Zweiter', role: 'chef', pin: '2222' })).json().staff.id;
  expect((await patch(b, chefId, { role: 'staff' })).statusCode).toBe(200);
  // Jetzt ist "Zweiter" der letzte Chef.
  expect((await patch(b, second, { archived: true })).statusCode).toBe(409);
  expect((await patch(b, chefId, { role: 'chef' })).statusCode).toBe(200);
  expect((await patch(b, second, { archived: true })).statusCode).toBe(200);
});

test('zwei gleichzeitige Herabstufungen der zwei Chefs: genau einer bleibt', async () => {
  const { b, chefId } = await businessWithChef();
  const second = (await create(b, { name: 'Zweiter', role: 'chef', pin: '2222' })).json().staff.id;
  const results = await Promise.all([patch(b, chefId, { role: 'staff' }), patch(b, second, { role: 'staff' })]);
  expect(results.map((r) => r.statusCode).sort()).toEqual([200, 409]);
});

test('jede Änderung erhöht change_seq des Mitarbeiters', async () => {
  const { b, chefId } = await businessWithChef();
  let last = Number((await staffRow(b, chefId)).change_seq);
  for (const change of [{ name: 'Chefin 2' }, { pin: '4321' }, { role: 'chef' }, { archived: false }]) {
    expect((await patch(b, chefId, change)).statusCode).toBe(200);
    const now = Number((await staffRow(b, chefId)).change_seq);
    expect(now).toBeGreaterThan(last);
    last = now;
  }
});

test('PATCH ohne Änderung oder mit falschen Werten', async () => {
  const { b, chefId } = await businessWithChef();
  expect((await patch(b, chefId, {})).statusCode).toBe(400);
  expect((await patch(b, chefId, { name: ' ' })).json().error.code).toBe('name_invalid');
  expect((await patch(b, chefId, { role: 'x' })).json().error.code).toBe('role_invalid');
  expect((await patch(b, chefId, { pin: '1' })).json().error.code).toBe('pin_invalid');
  expect((await patch(b, chefId, { archived: 'ja' })).statusCode).toBe(400);
});

test('Verlauf nennt staff.create und staff.update ohne PIN', async () => {
  const { b, chefId } = await businessWithChef();
  await patch(b, chefId, { name: 'Chefin neu', pin: '8642' });
  const rows = (
    await withSystem(a.db, (c) =>
      c.query(`select action, user_id, detail from audit_log where business_id = $1 order by id`, [b]),
    )
  ).rows;
  expect(rows.map((r) => r.action)).toEqual(['staff.create', 'staff.update']);
  expect(rows[0].user_id).toBe(provider.user.id);
  expect(rows[1].detail).toMatchObject({ staffId: chefId, fields: ['name', 'pin'] });
  expect(JSON.stringify(rows)).not.toMatch(/1111|8642|pin_?salt|pin_?hash|"pin":/i);
});

test('Chef des Betriebs darf, Chef von B sieht und ändert bei A nichts: 404', async () => {
  const A = await businessWithChef();
  const B = await businessWithChef();
  const chefA = await createChef(a.db, A.b);
  const chefB = await createChef(a.db, B.b);
  expect((await list(A.b, chefA.cookie)).statusCode).toBe(200);
  expect((await create(A.b, { name: 'Anna', role: 'staff', pin: '2222' }, chefA.cookie)).statusCode).toBe(201);

  const before = await staffRow(A.b, A.chefId);
  const beforeCount = (await list(A.b)).json().staff.length;
  for (const res of [
    await list(A.b, chefB.cookie),
    await create(A.b, { name: 'Eindringling', role: 'chef', pin: '5555' }, chefB.cookie),
    await patch(A.b, A.chefId, { name: 'Gehackt', archived: true }, chefB.cookie),
  ]) {
    expect(res.statusCode).toBe(404);
    expect(res.json().error.code).toBe('not_found');
  }
  expect(await staffRow(A.b, A.chefId)).toEqual(before);
  expect((await list(A.b)).json().staff).toHaveLength(beforeCount);
});

test('Mitarbeiter-Kennung eines anderen Betriebs: 404 und nichts ändert sich', async () => {
  const A = await businessWithChef();
  const B = await businessWithChef();
  const before = await staffRow(B.b, B.chefId);
  const res = await patch(A.b, B.chefId, { name: 'Gehackt', pin: '9999' });
  expect(res.statusCode).toBe(404);
  expect(res.json().error.code).toBe('not_found');
  expect(await staffRow(B.b, B.chefId)).toEqual(before);
  const res2 = await patch(A.b, '00000000-0000-4000-8000-000000000000', { name: 'X' });
  expect(res2.statusCode).toBe(404);
});

test('kein Betrieb, kein uuid, keine Anmeldung', async () => {
  const { b, chefId } = await businessWithChef();
  expect((await list('00000000-0000-4000-8000-000000000000')).statusCode).toBe(404);
  expect((await list('abc')).statusCode).toBe(404);
  expect((await patch(b, 'abc', { name: 'X' })).statusCode).toBe(404);
  const anon = await app().inject({ method: 'GET', url: `/api/admin/businesses/${b}/staff` });
  expect(anon.statusCode).toBe(401);
  expect(anon.json().error.code).toBe('unauthorized');
  const anonPost = await app().inject({
    method: 'POST',
    url: `/api/admin/businesses/${b}/staff`,
    headers: { 'x-kassa-request': '1' },
    payload: { name: 'A', role: 'staff', pin: '2222' },
  });
  expect(anonPost.statusCode).toBe(401);
  expect(chefId).toBeTruthy();
});
