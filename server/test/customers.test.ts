import type { FastifyInstance } from 'fastify';
import { afterAll, beforeAll, expect, test } from 'vitest';
import { withBusiness, withSystem } from '../src/db/tenant.js';
import { testApp, type TestApp } from './support/app.js';
import { authed, createChef, createProvider, insertBusiness, type TestUser } from './support/users.js';

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
const url = (b: string, id?: string) => `/api/admin/businesses/${b}/customers${id ? `/${id}` : ''}`;
const list = (b: string, cookie = provider.cookie) => app().inject({ method: 'GET', url: url(b), headers: { cookie } });
const create = (b: string, payload: unknown, cookie = provider.cookie) =>
  app().inject({ method: 'POST', url: url(b), headers: authed(cookie), payload: payload as object });
const patch = (b: string, id: string, payload: unknown, cookie = provider.cookie) =>
  app().inject({ method: 'PATCH', url: url(b, id), headers: authed(cookie), payload: payload as object });
const row = async (b: string, id: string) =>
  (await withBusiness(a.db, b, (c) => c.query('select * from customers where id = $1', [id]))).rows[0];

const MUSTER = { name: 'Muster GmbH', addressLine1: 'Musterweg 1', addressLine2: '1010 Wien', vatId: 'ATU00000000' };

test('Verwaltung: anlegen, ändern, archivieren; ein anderer Betrieb sieht nichts; ohne Anmeldung 401', async () => {
  const b = await insertBusiness(a.db);
  expect((await list(b)).json()).toEqual({ customers: [] });

  a.now.value = new Date('2026-11-27T10:00:00.000Z');
  const res = await create(b, { name: '  Muster GmbH ', addressLine1: ' Musterweg 1', addressLine2: '1010 Wien ', vatId: '' });
  expect(res.statusCode).toBe(201);
  const created = res.json().customer;
  expect(created).toEqual({
    id: expect.stringMatching(/^[0-9a-f-]{36}$/),
    name: 'Muster GmbH',
    addressLine1: 'Musterweg 1',
    addressLine2: '1010 Wien',
    vatId: null,
    archived: false,
    updatedAt: '2026-11-27T10:00:00.000Z',
  });
  const seq0 = Number((await row(b, created.id)).change_seq);

  a.now.value = new Date('2026-11-27T10:05:00.000Z');
  const changed = await patch(b, created.id, { addressLine1: 'Musterweg 2', vatId: 'ATU00000000' });
  expect(changed.statusCode).toBe(200);
  expect(changed.json().customer).toEqual({ ...created, addressLine1: 'Musterweg 2', vatId: 'ATU00000000', updatedAt: '2026-11-27T10:05:00.000Z' });
  const seq1 = Number((await row(b, created.id)).change_seq);
  expect(seq1).toBeGreaterThan(seq0);

  const zweite = (await create(b, { ...MUSTER, name: 'Alpha KG' })).json().customer;
  const archived = await patch(b, created.id, { archived: true });
  expect(archived.json().customer.archived).toBe(true);
  expect(Number((await row(b, created.id)).change_seq)).toBeGreaterThan(seq1);
  // Aktive zuerst, dann nach Name.
  expect((await list(b)).json().customers.map((c: { name: string; archived: boolean }) => [c.name, c.archived])).toEqual([
    ['Alpha KG', false],
    ['Muster GmbH', true],
  ]);
  expect((await patch(b, created.id, { archived: false })).json().customer.archived).toBe(false);

  // Ein anderer Betrieb und sein Chef: sehen nichts, ändern nichts.
  const other = await insertBusiness(a.db);
  const chefOther = await createChef(a.db, other);
  expect((await list(other)).json()).toEqual({ customers: [] });
  const before = await row(b, created.id);
  for (const r of [
    await list(b, chefOther.cookie),
    await create(b, MUSTER, chefOther.cookie),
    await patch(b, created.id, { name: 'Gehackt' }, chefOther.cookie),
    await patch(other, created.id, { name: 'Gehackt' }),
  ]) {
    expect(r.statusCode).toBe(404);
  }
  expect(await row(b, created.id)).toEqual(before);
  expect((await list(b)).json().customers).toHaveLength(2);

  // Der Chef des Betriebs darf.
  const chef = await createChef(a.db, b);
  expect((await list(b, chef.cookie)).statusCode).toBe(200);
  expect((await patch(b, zweite.id, { name: 'Alpha OG' }, chef.cookie)).json().customer.name).toBe('Alpha OG');

  // Ohne Anmeldung.
  expect((await app().inject({ method: 'GET', url: url(b) })).statusCode).toBe(401);
  const anonPost = await app().inject({ method: 'POST', url: url(b), headers: { 'x-kassa-request': '1' }, payload: MUSTER });
  expect(anonPost.statusCode).toBe(401);
  const anonPatch = await app().inject({ method: 'PATCH', url: url(b, created.id), headers: { 'x-kassa-request': '1' }, payload: { archived: true } });
  expect(anonPatch.statusCode).toBe(401);
});

test('Pflichtfelder und Längen wie am Tablet: 422 mit dem Feld', async () => {
  const b = await insertBusiness(a.db);
  const cases: [Record<string, unknown>, string][] = [
    [{ ...MUSTER, name: '  ' }, 'name_invalid'],
    [{ ...MUSTER, name: 'x'.repeat(81) }, 'name_invalid'],
    [{ ...MUSTER, addressLine1: '' }, 'address_line1_invalid'],
    [{ ...MUSTER, addressLine2: 'y'.repeat(81) }, 'address_line2_invalid'],
    [{ ...MUSTER, addressLine2: 5 }, 'address_line2_invalid'],
    [{ ...MUSTER, vatId: 'A'.repeat(21) }, 'vat_id_invalid'],
    [{ ...MUSTER, vatId: 7 }, 'vat_id_invalid'],
  ];
  for (const [payload, code] of cases) {
    const res = await create(b, payload);
    expect(res.statusCode, code).toBe(422);
    expect(res.json().error.code).toBe(code);
  }
  expect((await create(b, { ...MUSTER, name: 'x'.repeat(80), vatId: 'A'.repeat(20) })).statusCode).toBe(201);
  // Ohne UID geht es.
  const { vatId: _v, ...noVat } = MUSTER;
  const id = (await create(b, noVat)).json().customer.id;
  expect((await row(b, id)).vat_id).toBeNull();

  expect((await patch(b, id, {})).statusCode).toBe(400);
  expect((await patch(b, id, { archived: 'ja' })).statusCode).toBe(400);
  expect((await patch(b, id, { name: '' })).json().error.code).toBe('name_invalid');
  expect((await patch(b, 'abc', { name: 'X' })).statusCode).toBe(404);
  expect((await patch(b, '00000000-0000-4000-8000-000000000000', { name: 'X' })).statusCode).toBe(404);
  expect((await create(b, 'kein Objekt')).statusCode).toBe(400);
});

test('Verlauf nennt customer.create und customer.update mit Kennung und Feldern, ohne Name, Adresse oder UID', async () => {
  const b = await insertBusiness(a.db);
  const id = (await create(b, MUSTER)).json().customer.id;
  await patch(b, id, { name: 'Muster AG', archived: true });
  const rows = (
    await withSystem(a.db, (c) => c.query(`select action, detail from audit_log where business_id = $1 order by id`, [b]))
  ).rows;
  expect(rows).toEqual([
    { action: 'customer.create', detail: { customerId: id } },
    { action: 'customer.update', detail: { customerId: id, fields: ['name', 'archived'] } },
  ]);
});
