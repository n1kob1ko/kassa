import { afterAll, beforeAll, describe, expect, test } from 'vitest';
import { withBusiness, withSystem } from '../src/db/tenant.js';
import { testApp, type TestApp } from './support/app.js';
import { createBusiness } from './support/businesses.js';
import { fixtureBusiness, pairDevice, pull } from './support/device.js';
import { entry, pushEntries } from './support/push.js';
import { authed, createChef, type TestUser } from './support/users.js';
import { randomUUID } from 'node:crypto';

let a: TestApp;
let provider: TestUser;
let businessId: string;
let token: string;
const deviceId = randomUUID();

beforeAll(async () => {
  a = await testApp();
  ({ provider, businessId } = await fixtureBusiness(a));
  ({ token } = await pairDevice(a.app, provider.cookie, businessId));
});
afterAll(async () => {
  await a.close();
});

const base = (b = businessId) => `/api/admin/businesses/${b}/items`;
const list = (b = businessId, cookie = provider.cookie) => a.app.inject({ method: 'GET', url: base(b), headers: authed(cookie) });
const patch = (id: string, payload: unknown, b = businessId, cookie = provider.cookie) =>
  a.app.inject({ method: 'PATCH', url: `${base(b)}/${id}`, headers: authed(cookie), payload: payload as object });
const row = async (b: string, id: string) =>
  (await withBusiness(a.db, b, (c) => c.query('select * from items where id = $1', [id]))).rows[0];
const auditRows = () =>
  withSystem(a.db, async (c) => (await c.query(`select * from audit_log where action = 'item.update' order by id`)).rows);

describe('Artikel in der Verwaltung', () => {
  test('Liste nach Kategorie in der Reihenfolge der Speisekarte, mit Foto und Kennzeichen', async () => {
    await withBusiness(a.db, businessId, (c) => c.query(`update items set archived = true where id = 'teigtaschen'`));
    const res = await list();
    expect(res.statusCode).toBe(200);
    const { categories } = res.json();
    expect(categories.map((c: { id: string }) => c.id)).toEqual(['bowls', 'getraenke']);
    expect(categories[0]).toMatchObject({ id: 'bowls', name: 'Bowls', archived: false });
    expect(categories[0].items.map((i: { id: string }) => i.id)).toEqual(['huhn-bowl', 'teigtaschen']);
    expect(categories[0].items[0]).toEqual({
      id: 'huhn-bowl', name: 'Huhn Bowl', priceCents: 990, inSale: true, favorite: false, archived: false, photo: null,
    });
    expect(categories[0].items[1]).toMatchObject({ id: 'teigtaschen', archived: true });
    expect(categories[1].items.map((i: { id: string }) => i.id)).toEqual(['cola']);
    await withBusiness(a.db, businessId, (c) => c.query(`update items set archived = false where id = 'teigtaschen'`));
  });

  test('Preis ändern: neue Änderungs-Nummer, Tablet holt den Preis', async () => {
    const before = await row(businessId, 'cola');
    a.now.value = new Date('2026-11-19T12:00:00.000Z');
    const res = await patch('cola', { priceCents: 350, favorite: true });
    expect(res.statusCode).toBe(200);
    expect(res.json()).toEqual({
      id: 'cola', name: 'Cola 0,33 l', priceCents: 350, inSale: true, favorite: true, archived: false, photo: null,
    });
    const after = await row(businessId, 'cola');
    expect(after.price_changed_at.toISOString()).toBe('2026-11-19T12:00:00.000Z');
    expect(Number(after.change_seq)).toBeGreaterThan(Number(before.change_seq));
    const pulled = await pull(a.app, token, `?since=${before.change_seq}`);
    const got = pulled.json().items.find((i: { id: string }) => i.id === 'cola');
    expect(got).toMatchObject({ priceCents: 350, favorite: true });
    expect((await list()).json().categories[1].items[0]).toMatchObject({ priceCents: 350, favorite: true });
  });

  test('inSale ausschalten', async () => {
    const res = await patch('teigtaschen', { inSale: false });
    expect(res.statusCode).toBe(200);
    expect(res.json().inSale).toBe(false);
    expect((await row(businessId, 'teigtaschen')).in_sale).toBe(false);
  });

  test('Preis im Browser nach einer Änderung vom Tablet: der Browser gewinnt, weil er später ist', async () => {
    a.now.value = new Date('2026-11-19T13:00:00.000Z');
    // Das Tablet ändert im selben Moment, wie die Uhr des Servers steht.
    const pushed = await pushEntries(a.app, token, deviceId, [
      entry(1, 'item_change', { itemId: 'huhn-bowl', field: 'priceCents', value: 1190, changedAt: '2026-11-19T13:00:00.000Z' }),
    ]);
    expect(pushed.results).toEqual([{ seq: 1, status: 'accepted' }]);
    expect((await row(businessId, 'huhn-bowl')).price_cents).toBe(1190);
    const res = await patch('huhn-bowl', { priceCents: 1290 });
    expect(res.statusCode).toBe(200);
    expect(res.json().priceCents).toBe(1290);
    const after = await row(businessId, 'huhn-bowl');
    expect(after.price_cents).toBe(1290);
    expect(after.price_changed_at.getTime()).toBeGreaterThan(new Date('2026-11-19T13:00:00.000Z').getTime());
    // Das Tablet schickt seine ältere Änderung noch einmal: sie ändert nichts.
    const again = await pushEntries(a.app, token, deviceId, [
      entry(2, 'item_change', { itemId: 'huhn-bowl', field: 'priceCents', value: 1190, changedAt: '2026-11-19T13:00:00.000Z' }),
    ]);
    expect(again.results[0]!.status).toBe('accepted');
    expect((await row(businessId, 'huhn-bowl')).price_cents).toBe(1290);
  });

  test.each([[-1], [1.5], ['9'], [null], [2_000_000_001]])('priceCents %j: 422', async (v) => {
    const before = await row(businessId, 'cola');
    const res = await patch('cola', { priceCents: v });
    expect(res.statusCode).toBe(422);
    expect(res.json().error.code).toBe('item_invalid');
    expect((await row(businessId, 'cola')).change_seq).toBe(before.change_seq);
  });

  test('inSale als Text: 422', async () => {
    expect((await patch('cola', { inSale: 'ja' })).statusCode).toBe(422);
  });

  test('name im Körper: 422, nichts geändert', async () => {
    const before = await row(businessId, 'cola');
    const res = await patch('cola', { priceCents: 111, name: 'Limo' });
    expect(res.statusCode).toBe(422);
    const after = await row(businessId, 'cola');
    expect(after.name).toBe('Cola 0,33 l');
    expect(after.price_cents).toBe(before.price_cents);
    expect(after.change_seq).toBe(before.change_seq);
  });

  test('leerer Körper: 422 nothing_to_change', async () => {
    const res = await patch('cola', {});
    expect(res.statusCode).toBe(422);
    expect(res.json().error.code).toBe('nothing_to_change');
  });

  test('derselbe Wert wie vorher ist in Ordnung', async () => {
    const res = await patch('cola', { priceCents: 350 });
    expect(res.statusCode).toBe(200);
    expect(res.json().priceCents).toBe(350);
  });

  test('unbekannter Artikel: 404, auch mit einem Feld, das nicht stimmt', async () => {
    const res = await patch('gibt-es-nicht', { priceCents: 100 });
    expect(res.statusCode).toBe(404);
    expect(res.json().error.code).toBe('not_found');
  });

  test('Verlauf enthält den Eintrag mit Artikel und neuen Werten', async () => {
    const rows = (await auditRows()).filter((r) => r.business_id === businessId);
    const mine = rows.find((r) => r.detail.itemId === 'cola' && r.detail.fields.priceCents === 350 && r.detail.fields.favorite === true);
    expect(mine).toBeDefined();
    expect(mine.user_id).toBe(provider.user.id);
    expect(mine.detail).toEqual({ itemId: 'cola', fields: { priceCents: 350, favorite: true } });
  });

  test('zweiter Betrieb sieht nichts und ändert nichts; Chef nur im eigenen Betrieb; ohne Anmeldung 401', async () => {
    const other = (await createBusiness(a.app, provider.cookie, 'beispiel-imbiss')).id;
    const chef1 = await createChef(a.db, businessId);
    const chef2 = await createChef(a.db, other);
    expect((await list(businessId, chef1.cookie)).statusCode).toBe(200);
    expect((await list(businessId, chef2.cookie)).statusCode).toBe(404);
    const before = await row(other, 'cola');
    const res = await patch('cola', { priceCents: 1 }, businessId, chef2.cookie);
    expect(res.statusCode).toBe(404);
    expect((await row(other, 'cola')).price_cents).toBe(before.price_cents);
    // Der Artikel eines anderen Betriebs ist über den eigenen nicht erreichbar.
    const cross = await patch('cola', { priceCents: 1 }, other, chef1.cookie);
    expect(cross.statusCode).toBe(404);
    expect((await row(other, 'cola')).price_cents).toBe(before.price_cents);
    expect((await row(businessId, 'cola')).price_cents).toBe(350);
    expect((await list(other)).json().categories[1].items[0].priceCents).toBe(290);
    expect((await a.app.inject({ method: 'GET', url: base() })).statusCode).toBe(401);
    expect((await a.app.inject({ method: 'PATCH', url: `${base()}/cola`, headers: { 'x-kassa-request': '1' }, payload: { priceCents: 1 } })).statusCode).toBe(401);
    expect((await a.app.inject({ method: 'PATCH', url: `${base()}/cola`, payload: { priceCents: 1 } })).statusCode).toBe(403);
  });
});
