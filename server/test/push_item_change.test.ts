import { randomUUID } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, test } from 'vitest';
import { withBusiness, withBusinessWrite } from '../src/db/tenant.js';
import { applyItemField } from '../src/device/push_item_change.js';
import { testApp, type TestApp } from './support/app.js';
import { createBusiness } from './support/businesses.js';
import { fixtureBusiness, pairDevice, pull } from './support/device.js';
import { entry, pushEntries } from './support/push.js';
import type { TestUser } from './support/users.js';

let f: TestApp;
let provider: TestUser;
let businessId: string;
let token: string;
const deviceId: string = randomUUID();

beforeAll(async () => {
  f = await testApp();
  ({ provider, businessId } = await fixtureBusiness(f));
  ({ token } = await pairDevice(f.app, provider.cookie, businessId));
});
afterAll(async () => {
  await f.close();
});

const item = async (biz: string, id: string) =>
  (await withBusiness(f.db, biz, (c) => c.query('select * from items where id = $1', [id]))).rows[0];
const change = (itemId: string, field: string, value: unknown, changedAt: string) => ({ itemId, field, value, changedAt });
const send = (seq: number, c: object) => pushEntries(f.app, token, deviceId, [entry(seq, 'item_change', c)]);
const status = (r: { results: { status: string; reason?: string }[] }) => (r.results[0]!.reason ? `${r.results[0]!.status}/${r.results[0]!.reason}` : r.results[0]!.status);
/** Setzt Wert und Zeitpunkt eines Feldes, ohne die Änderungs-Nummer zu ändern. */
const setPriceAt = (biz: string, id: string, cents: number, at: string) =>
  withBusiness(f.db, biz, (c) => c.query('update items set price_cents = $2, price_changed_at = $3 where id = $1', [id, cents, at]));

describe('item_change', () => {
  test('späterer Preis vom Tablet gewinnt und kommt beim Holen', async () => {
    await setPriceAt(businessId, 'huhn-bowl', 990, '2026-11-19T08:00:00.000Z');
    const before = await item(businessId, 'huhn-bowl');
    f.now.value = new Date('2026-11-19T12:00:00.000Z');
    const res = await send(1, change('huhn-bowl', 'priceCents', 1090, '2026-11-19T08:10:00.000Z'));
    expect(res.results).toEqual([{ seq: 1, status: 'accepted' }]);
    const after = await item(businessId, 'huhn-bowl');
    expect(after.price_cents).toBe(1090);
    expect(after.price_changed_at.toISOString()).toBe('2026-11-19T08:10:00.000Z');
    expect(Number(after.change_seq)).toBeGreaterThan(Number(before.change_seq));

    const pulled = await pull(f.app, token, `?since=${before.change_seq}`);
    const got = pulled.json().items.find((i: { id: string }) => i.id === 'huhn-bowl');
    expect(got.priceCents).toBe(1090);
  });

  test('älterer Preis vom Tablet verliert, accepted, der Wert bleibt und kommt beim nächsten Holen zurück', async () => {
    await setPriceAt(businessId, 'cola', 250, '2026-11-19T09:00:00.000Z');
    const before = await item(businessId, 'cola');
    f.now.value = new Date('2026-11-19T12:00:00.000Z');
    const res = await send(1, change('cola', 'priceCents', 300, '2026-11-19T08:00:00.000Z'));
    expect(res.results).toEqual([{ seq: 1, status: 'accepted' }]);
    const after = await item(businessId, 'cola');
    expect(after).toEqual({ ...before, change_seq: after.change_seq });
    expect(Number(after.change_seq)).toBeGreaterThan(Number(before.change_seq));

    // Das Tablet hat 300 und löscht seinen Eintrag: das Holen im selben Lauf bringt den Wert des Servers.
    const pulled = await pull(f.app, token, `?since=${before.change_seq}`);
    expect(pulled.json().items.find((i: { id: string }) => i.id === 'cola').priceCents).toBe(250);
  });

  test('älterer Preis mit demselben Wert: nichts ändert sich, auch die Änderungs-Nummer nicht', async () => {
    await setPriceAt(businessId, 'cola', 250, '2026-11-19T09:00:00.000Z');
    const before = await item(businessId, 'cola');
    const res = await send(1, change('cola', 'priceCents', 250, '2026-11-19T08:00:00.000Z'));
    expect(res.results).toEqual([{ seq: 1, status: 'accepted' }]);
    expect(await item(businessId, 'cola')).toEqual(before);
  });

  test('zwei Änderungen in derselben Sekunde: die spätere gewinnt, dieselbe noch einmal ändert nichts', async () => {
    await setPriceAt(businessId, 'huhn-bowl', 990, '2026-11-19T08:00:00.000Z');
    const start = await item(businessId, 'huhn-bowl');
    f.now.value = new Date('2026-11-19T12:00:00.000Z');
    const at = '2026-11-19T10:00:00.000Z';
    const res = await pushEntries(f.app, token, deviceId, [
      entry(1, 'item_change', change('huhn-bowl', 'priceCents', 1000, at)),
      entry(2, 'item_change', change('huhn-bowl', 'priceCents', 1100, at)),
    ]);
    expect(res.results).toEqual([{ seq: 1, status: 'accepted' }, { seq: 2, status: 'accepted' }]);
    const after = await item(businessId, 'huhn-bowl');
    expect(after.price_cents).toBe(1100);
    expect(after.price_changed_at.toISOString()).toBe(at);
    const pulled = await pull(f.app, token, `?since=${start.change_seq}`);
    expect(pulled.json().items.find((i: { id: string }) => i.id === 'huhn-bowl').priceCents).toBe(1100);

    // Die Antwort ging verloren, das Tablet schickt B noch einmal: kein neuer Stand, keine neue Nummer.
    const again = await send(2, change('huhn-bowl', 'priceCents', 1100, at));
    expect(again.results).toEqual([{ seq: 2, status: 'accepted' }]);
    expect(await item(businessId, 'huhn-bowl')).toEqual(after);

    // Das ganze Paket noch einmal: am Ende steht wieder B.
    const twice = await pushEntries(f.app, token, deviceId, [
      entry(1, 'item_change', change('huhn-bowl', 'priceCents', 1000, at)),
      entry(2, 'item_change', change('huhn-bowl', 'priceCents', 1100, at)),
    ]);
    expect(twice.results.map((r) => r.status)).toEqual(['accepted', 'accepted']);
    expect(await item(businessId, 'huhn-bowl')).toMatchObject({ price_cents: 1100, price_changed_at: new Date(at) });
  });

  test('ältere Änderung mit anderem Wert: ein anderer Betrieb mit gleicher Kennung bekommt keine neue Nummer', async () => {
    const other = (await createBusiness(f.app, provider.cookie, 'beispiel-imbiss')).id;
    const otherBefore = await item(other, 'teigtaschen');
    await setPriceAt(businessId, 'teigtaschen', 500, '2026-11-19T09:00:00.000Z');
    f.now.value = new Date('2026-11-19T12:00:00.000Z');
    const res = await send(1, change('teigtaschen', 'priceCents', 650, '2026-11-19T08:00:00.000Z'));
    expect(res.results).toEqual([{ seq: 1, status: 'accepted' }]);
    expect(await item(other, 'teigtaschen')).toEqual(otherBefore);
    expect((await item(businessId, 'teigtaschen')).price_cents).toBe(500);
  });

  test('Uhr eine Woche in der Zukunft: gilt als jetzt, eine spätere Änderung im Browser gewinnt wieder', async () => {
    await setPriceAt(businessId, 'teigtaschen', 500, '2026-11-19T08:00:00.000Z');
    f.now.value = new Date('2026-11-19T12:00:00.000Z');
    const res = await send(1, change('teigtaschen', 'priceCents', 600, '2026-11-26T12:00:00.000Z'));
    expect(res.results).toEqual([{ seq: 1, status: 'accepted' }]);
    const row = await item(businessId, 'teigtaschen');
    expect(row.price_cents).toBe(600);
    expect(row.price_changed_at.toISOString()).toBe('2026-11-19T12:00:00.000Z');

    // Der Browser ändert eine Stunde später mit der Uhr des Servers.
    const browserAt = new Date('2026-11-19T13:00:00.000Z');
    const outcome = await withBusinessWrite(f.db, businessId, (c) => applyItemField(c, businessId, 'teigtaschen', 'priceCents', 700, browserAt));
    expect(outcome).toBe('applied');
    expect((await item(businessId, 'teigtaschen')).price_cents).toBe(700);
  });

  test('pro Feld: Preis vom Tablet und Favorit vom Server bleiben beide', async () => {
    await setPriceAt(businessId, 'cola', 250, '2026-11-19T07:00:00.000Z');
    await withBusiness(f.db, businessId, (c) =>
      c.query(`update items set favorite = true, favorite_changed_at = '2026-11-19T11:00:00.000Z' where id = 'cola'`),
    );
    f.now.value = new Date('2026-11-19T12:00:00.000Z');
    const r1 = await send(1, change('cola', 'priceCents', 275, '2026-11-19T08:00:00.000Z'));
    const r2 = await send(2, change('cola', 'favorite', false, '2026-11-19T10:00:00.000Z'));
    expect([r1.results[0]!.status, r2.results[0]!.status]).toEqual(['accepted', 'accepted']);
    const row = await item(businessId, 'cola');
    expect(row.price_cents).toBe(275);
    expect(row.favorite).toBe(true);
  });

  test('tags: ["spicy","vegan"] wird "spicy,vegan"', async () => {
    f.now.value = new Date('2026-11-19T12:00:00.000Z');
    const res = await send(1, change('huhn-bowl', 'tags', ['vegan', 'spicy'], '2026-11-19T11:00:00.000Z'));
    expect(res.results).toEqual([{ seq: 1, status: 'accepted' }]);
    expect((await item(businessId, 'huhn-bowl')).tags).toBe('spicy,vegan');
    const bad = await send(2, change('huhn-bowl', 'tags', ['glutenfrei'], '2026-11-19T11:00:00.000Z'));
    expect(status(bad)).toBe('rejected/invalid');
  });

  test('inSale und depositCents', async () => {
    f.now.value = new Date('2026-11-19T12:00:00.000Z');
    const a = await send(1, change('cola', 'inSale', false, '2026-11-19T11:30:00.000Z'));
    const b = await send(2, change('cola', 'depositCents', 50, '2026-11-19T11:30:00.000Z'));
    expect([status(a), status(b)]).toEqual(['accepted', 'accepted']);
    const row = await item(businessId, 'cola');
    expect(row).toMatchObject({ in_sale: false, deposit_cents: 50 });
  });

  test('unbekannter Artikel: rejected/unknown_item', async () => {
    const res = await send(1, change('gibt-es-nicht', 'priceCents', 100, '2026-11-19T08:00:00.000Z'));
    expect(status(res)).toBe('rejected/unknown_item');
  });

  test('priceCents -1 oder "abc": rejected/invalid', async () => {
    const before = await item(businessId, 'huhn-bowl');
    const a = await send(1, change('huhn-bowl', 'priceCents', -1, '2026-11-19T11:00:00.000Z'));
    const b = await send(2, change('huhn-bowl', 'priceCents', 'abc', '2026-11-19T11:00:00.000Z'));
    const c = await send(3, change('huhn-bowl', 'unbekannt', 1, '2026-11-19T11:00:00.000Z'));
    expect([status(a), status(b), status(c)]).toEqual(['rejected/invalid', 'rejected/invalid', 'rejected/invalid']);
    expect(await item(businessId, 'huhn-bowl')).toEqual(before);
  });

  test('Artikel eines anderen Betriebs mit gleicher Kennung bleibt unberührt', async () => {
    const other = (await createBusiness(f.app, provider.cookie, 'beispiel-imbiss')).id;
    await setPriceAt(other, 'cola', 250, '2026-11-19T07:00:00.000Z');
    const before = await item(other, 'cola');
    f.now.value = new Date('2026-11-19T12:00:00.000Z');
    const res = await send(1, change('cola', 'priceCents', 999, '2026-11-19T11:55:00.000Z'));
    expect(status(res)).toBe('accepted');
    expect(await item(other, 'cola')).toEqual(before);
    expect((await item(businessId, 'cola')).price_cents).toBe(999);
  });
});
