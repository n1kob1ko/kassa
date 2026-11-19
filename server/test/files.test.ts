import { readFileSync } from 'node:fs';
import { mkdtemp, readdir, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import type { FastifyInstance } from 'fastify';
import { afterAll, beforeAll, describe, expect, test } from 'vitest';
import { withBusiness, withSystem } from '../src/db/tenant.js';
import type { FileStore } from '../src/storage/file_store.js';
import { LocalFileStore } from '../src/storage/local_file_store.js';
import { testApp, type TestApp } from './support/app.js';
import { createBusiness } from './support/businesses.js';
import { createStaff, pairDevice, pull } from './support/device.js';
import { authed, createChef, createProvider, type TestUser } from './support/users.js';

const image = (name: string) => readFileSync(new URL(`./fixtures/images/${name}`, import.meta.url));
const JPEG = image('rotated_gps.jpg');

/** Eine Ablage, deren Löschen auf Wunsch scheitert. */
class FlakyStore implements FileStore {
  failDelete = false;
  constructor(private readonly inner: FileStore) {}
  put: FileStore['put'] = (k, b, t) => this.inner.put(k, b, t);
  get: FileStore['get'] = (k) => this.inner.get(k);
  delete: FileStore['delete'] = async (k) => {
    if (this.failDelete) throw new Error('Ablage nicht erreichbar');
    return this.inner.delete(k);
  };
}

let a: TestApp;
let store: FlakyStore;
let dir: string;
let provider: TestUser;
let businessId: string;
let chef: TestUser;
let token: string;
let registerId: string;
let otherBusinessId: string;
let otherChef: TestUser;
let otherToken: string;
const logs: string[] = [];

beforeAll(async () => {
  dir = await mkdtemp(join(tmpdir(), 'kassa-images-'));
  store = new FlakyStore(new LocalFileStore(dir));
  a = await testApp({ files: store }, { logger: { level: 'error', stream: { write: (m: string) => void logs.push(m) } } });
  provider = await createProvider(a.app, a.db);
  businessId = (await createBusiness(a.app, provider.cookie)).id;
  otherBusinessId = (await createBusiness(a.app, provider.cookie)).id;
  chef = await createChef(a.db, businessId);
  otherChef = await createChef(a.db, otherBusinessId);
  await createStaff(a.app, provider.cookie, businessId, { name: 'Chefin', role: 'chef', pin: '1234' });
  await createStaff(a.app, provider.cookie, otherBusinessId, { name: 'Chef', role: 'chef', pin: '4321' });
  ({ token, registerId } = await pairDevice(a.app, provider.cookie, businessId));
  ({ token: otherToken } = await pairDevice(a.app, provider.cookie, otherBusinessId));
});
afterAll(async () => {
  await a.close();
  await rm(dir, { recursive: true, force: true });
});

const itemUrl = (b = businessId, id = 'huhn-bowl') => `/api/admin/businesses/${b}/items/${id}/photo`;
const logoUrl = (b = businessId) => `/api/admin/businesses/${b}/logo`;

const put = (url: string, body: Buffer, o: { cookie?: string | null; type?: string } = {}) =>
  a.app.inject({
    method: 'PUT',
    url,
    headers: { ...(o.cookie === null ? { 'x-kassa-request': '1' } : authed(o.cookie ?? provider.cookie)), 'content-type': o.type ?? 'image/jpeg' },
    payload: body,
  });
const del = (url: string, cookie: string | null = provider.cookie) =>
  a.app.inject({ method: 'DELETE', url, headers: cookie === null ? { 'x-kassa-request': '1' } : authed(cookie) });
const getAdmin = (b: string, id: string, cookie: string | null = provider.cookie) =>
  a.app.inject({ method: 'GET', url: `/api/admin/businesses/${b}/files/${id}`, headers: cookie === null ? {} : { cookie } });
const getDevice = (id: string, t: string | null = token) =>
  a.app.inject({ method: 'GET', url: `/api/device/files/${id}`, headers: t === null ? {} : { authorization: `Bearer ${t}` } });

async function pulled(t = token) {
  const res = await pull(a.app, t, '?since=0');
  expect(res.statusCode).toBe(200);
  return res.json() as { next: number; business: { logo: { id: string; color: string } | null }; items: { id: string; photo: { id: string; color: string } | null }[] };
}
const photoOf = async (id = 'huhn-bowl', t = token) => (await pulled(t)).items.find((i) => i.id === id)!.photo;
const keysOnDisk = async () =>
  (await readdir(dir, { recursive: true, withFileTypes: true })).filter((e) => e.isFile()).map((e) => join(e.parentPath, e.name));
const auditActions = (b = businessId) =>
  withSystem(a.db, async (c) => (await c.query('select action, user_id, detail from audit_log where business_id = $1 order by id', [b])).rows).catch(() => []);

describe('Foto eines Artikels', () => {
  test('ohne Foto: pull nennt photo: null, auch beim Betrieb logo: null', async () => {
    const p = await pulled();
    expect(p.items.every((i) => i.photo === null)).toBe(true);
    expect(p.business.logo).toBeNull();
  });

  test('hochladen: Antwort, pull zeigt photo mit neuer Änderungs-Nummer, das Tablet lädt die Datei', async () => {
    const before = (await pulled()).next;
    const res = await put(itemUrl(), JPEG);
    expect(res.statusCode).toBe(200);
    const file = res.json().file;
    expect(Object.keys(file).sort()).toEqual(['color', 'height', 'id', 'width']);
    expect(file).toMatchObject({ width: 800, height: 1280 });
    expect(file.color).toMatch(/^#[0-9a-f]{6}$/);

    const after = await pull(a.app, token, `?since=${before}`);
    expect(after.json().next).toBeGreaterThan(before);
    const item = after.json().items.find((i: { id: string }) => i.id === 'huhn-bowl');
    expect(item.photo).toEqual({ id: file.id, color: file.color });

    const got = await getDevice(file.id);
    expect(got.statusCode).toBe(200);
    expect(got.headers['content-type']).toBe('image/webp');
    expect(got.headers['x-content-type-options']).toBe('nosniff');
    expect(got.headers['cache-control']).toBe('private, max-age=31536000, immutable');
    expect(got.rawPayload.subarray(0, 4).toString()).toBe('RIFF');
    expect(got.rawPayload.subarray(8, 12).toString()).toBe('WEBP');
    // Die Verwaltung sieht dieselbe Datei.
    const adm = await getAdmin(businessId, file.id);
    expect(adm.statusCode).toBe(200);
    expect(adm.headers['content-type']).toBe('image/webp');
    expect(adm.rawPayload.equals(got.rawPayload)).toBe(true);
    // Chef des Betriebs sieht sie auch.
    expect((await getAdmin(businessId, file.id, chef.cookie)).statusCode).toBe(200);
    // Ablage-Schlüssel businesses/<b>/files/<id>.webp
    expect(await keysOnDisk()).toContain(join(dir, 'businesses', businessId, 'files', `${file.id}.webp`));
    const row = await withBusiness(a.db, businessId, async (c) => (await c.query('select kind, storage_key, size, width, height, color from files where id = $1', [file.id])).rows[0]);
    expect(row).toMatchObject({ kind: 'item_photo', storage_key: `businesses/${businessId}/files/${file.id}.webp`, width: 800, height: 1280, color: file.color });
    expect(row.size).toBe(got.rawPayload.length);
  });

  test('ersetzen: neue Kennung, alte Kennung 404, altes Objekt weg, Änderungs-Nummer steigt', async () => {
    const first = await photoOf();
    const seq1 = (await pulled()).next;
    const res = await put(itemUrl(), image('photo.webp'), { type: 'image/webp' });
    expect(res.statusCode).toBe(200);
    const next = res.json().file;
    expect(next.id).not.toBe(first!.id);
    expect((await pulled()).next).toBeGreaterThan(seq1);
    expect(await photoOf()).toEqual({ id: next.id, color: next.color });
    expect((await getDevice(first!.id)).statusCode).toBe(404);
    expect((await getAdmin(businessId, first!.id)).statusCode).toBe(404);
    const keys = await keysOnDisk();
    expect(keys.some((k) => k.endsWith(`${first!.id}.webp`))).toBe(false);
    expect(keys.some((k) => k.endsWith(`${next.id}.webp`))).toBe(true);
    const rows = await withBusiness(a.db, businessId, async (c) => (await c.query("select id from files where kind = 'item_photo'")).rows);
    expect(rows.map((r) => r.id)).toEqual([next.id]);
  });

  test('ersetzen, obwohl die Ablage das Löschen verweigert: Anfrage gelingt, das Objekt bleibt, es steht im Protokoll', async () => {
    const old = await photoOf();
    logs.length = 0;
    store.failDelete = true;
    try {
      const res = await put(itemUrl(), image('plain_400.jpg'));
      expect(res.statusCode).toBe(200);
      expect(await photoOf()).toEqual({ id: res.json().file.id, color: res.json().file.color });
    } finally {
      store.failDelete = false;
    }
    expect((await getDevice(old!.id)).statusCode).toBe(404);
    expect((await keysOnDisk()).some((k) => k.endsWith(`${old!.id}.webp`))).toBe(true);
    expect(logs.join('')).toContain(old!.id);
  });

  test('entfernen: photo: null, Datei und Objekt weg', async () => {
    const cur = await photoOf();
    const seq = (await pulled()).next;
    const res = await del(itemUrl());
    expect(res.statusCode).toBe(204);
    expect(await photoOf()).toBeNull();
    expect((await pulled()).next).toBeGreaterThan(seq);
    expect((await getDevice(cur!.id)).statusCode).toBe(404);
    expect((await keysOnDisk()).some((k) => k.endsWith(`${cur!.id}.webp`))).toBe(false);
    // Ein zweites Entfernen schadet nicht.
    expect((await del(itemUrl())).statusCode).toBe(204);
  });

  test('jede Änderung steht im Verlauf', async () => {
    const actions = (await auditActions()).filter((r) => r.action.startsWith('item.photo_'));
    expect(actions.map((r) => r.action)).toEqual(['item.photo_set', 'item.photo_set', 'item.photo_set', 'item.photo_removed']);
    expect(actions[0].detail).toEqual({ itemId: 'huhn-bowl' });
    expect(actions[0].user_id).toBe(provider.user.id);
  });

  test('Artikel unbekannt: 404, und nichts bleibt in der Ablage', async () => {
    const before = await keysOnDisk();
    const res = await put(itemUrl(businessId, 'gibt-es-nicht'), JPEG);
    expect(res.statusCode).toBe(404);
    expect(res.json().error.code).toBe('not_found');
    expect(await keysOnDisk()).toEqual(before);
    expect((await del(itemUrl(businessId, 'gibt-es-nicht'))).statusCode).toBe(404);
  });
});

describe('Logo', () => {
  test('hochladen, ersetzen, entfernen wie beim Foto', async () => {
    const seq0 = (await pulled()).next;
    const r1 = await put(logoUrl(), image('transparent.png'), { type: 'image/png' });
    expect(r1.statusCode).toBe(200);
    const f1 = r1.json().file;
    const p1 = await pulled();
    expect(p1.next).toBeGreaterThan(seq0);
    expect(p1.business.logo).toEqual({ id: f1.id, color: f1.color });
    const got = await getDevice(f1.id);
    expect(got.statusCode).toBe(200);
    expect(got.headers['content-type']).toBe('image/webp');

    const r2 = await put(logoUrl(), JPEG);
    const f2 = r2.json().file;
    expect(f2.id).not.toBe(f1.id);
    expect((await pulled()).business.logo).toEqual({ id: f2.id, color: f2.color });
    expect((await getDevice(f1.id)).statusCode).toBe(404);
    expect((await keysOnDisk()).some((k) => k.endsWith(`${f1.id}.webp`))).toBe(false);

    const seq2 = (await pulled()).next;
    expect((await del(logoUrl())).statusCode).toBe(204);
    const p3 = await pulled();
    expect(p3.business.logo).toBeNull();
    expect(p3.next).toBeGreaterThan(seq2);
    expect((await getDevice(f2.id)).statusCode).toBe(404);
    expect((await keysOnDisk()).some((k) => k.endsWith(`${f2.id}.webp`))).toBe(false);

    const actions = (await auditActions()).filter((r) => r.action.startsWith('business.logo_'));
    expect(actions.map((r) => r.action)).toEqual(['business.logo_set', 'business.logo_set', 'business.logo_removed']);
  });

  test('der Chef des Betriebs darf', async () => {
    const res = await put(logoUrl(), JPEG, { cookie: chef.cookie });
    expect(res.statusCode).toBe(200);
    expect((await del(logoUrl(), chef.cookie)).statusCode).toBe(204);
  });
});

describe('Eingaben und Rechte', () => {
  test('11 MB ergibt 413', async () => {
    const before = await keysOnDisk();
    const res = await put(itemUrl(), Buffer.alloc(11 * 1024 * 1024, 1));
    expect(res.statusCode).toBe(413);
    expect(res.json().error.code).toBe('file_too_large');
    expect(await keysOnDisk()).toEqual(before);
  });

  test('image/gif ergibt 415 unsupported_media_type, ebenso fehlender Typ', async () => {
    const res = await put(itemUrl(), JPEG, { type: 'image/gif' });
    expect(res.statusCode).toBe(415);
    expect(res.json().error.code).toBe('unsupported_media_type');
    const json = await put(logoUrl(), Buffer.from('{}'), { type: 'application/json' });
    expect(json.statusCode).toBe(415);
  });

  test('der Typ der Anfrage entscheidet nicht: eine Textdatei als image/jpeg ergibt 422 image_invalid, nichts bleibt liegen', async () => {
    const before = await keysOnDisk();
    const res = await put(itemUrl(), image('not_an_image.jpg'));
    expect(res.statusCode).toBe(422);
    expect(res.json().error.code).toBe('image_invalid');
    expect(await keysOnDisk()).toEqual(before);
    expect(await photoOf()).toBeNull();
  });

  test('nicht angemeldet: 401', async () => {
    expect((await put(itemUrl(), JPEG, { cookie: null })).statusCode).toBe(401);
    expect((await del(itemUrl(), null)).statusCode).toBe(401);
    expect((await put(logoUrl(), JPEG, { cookie: null })).statusCode).toBe(401);
    expect((await getAdmin(businessId, '00000000-0000-4000-8000-000000000000', null)).statusCode).toBe(401);
  });

  test('der Chef eines anderen Betriebs bekommt 404 und ändert nichts', async () => {
    const seq = (await pulled()).next;
    const before = await keysOnDisk();
    expect((await put(itemUrl(), JPEG, { cookie: otherChef.cookie })).statusCode).toBe(404);
    expect((await del(itemUrl(), otherChef.cookie)).statusCode).toBe(404);
    expect((await put(logoUrl(), JPEG, { cookie: otherChef.cookie })).statusCode).toBe(404);
    expect((await del(logoUrl(), otherChef.cookie)).statusCode).toBe(404);
    expect(await keysOnDisk()).toEqual(before);
    expect((await pulled()).next).toBe(seq);
  });

  test('die Betriebe sind getrennt: ein zweiter Betrieb sieht und ändert nichts', async () => {
    const mine = await put(itemUrl(), JPEG);
    const id = mine.json().file.id;
    // Chef des anderen Betriebs liest die Datei weder über seinen Betrieb noch über meinen.
    expect((await getAdmin(otherBusinessId, id, otherChef.cookie)).statusCode).toBe(404);
    expect((await getAdmin(businessId, id, otherChef.cookie)).statusCode).toBe(404);
    // Der Anbieter findet sie nur im richtigen Betrieb.
    expect((await getAdmin(otherBusinessId, id)).statusCode).toBe(404);
    // Der Artikel im anderen Betrieb bleibt ohne Foto, auch wenn er gleich heißt.
    expect(await photoOf('huhn-bowl', otherToken)).toBeNull();
    // Das Tablet des zweiten Betriebs bekommt die Kennung nicht (Review Focus 4, Server-Seite).
    expect((await getDevice(id, otherToken)).statusCode).toBe(404);
    expect((await getDevice(id)).statusCode).toBe(200);
    // Und eine Kennung des zweiten Betriebs gibt es für mich nicht.
    const theirs = (await put(itemUrl(otherBusinessId), JPEG)).json().file.id;
    expect((await getDevice(theirs)).statusCode).toBe(404);
    expect((await getDevice(theirs, otherToken)).statusCode).toBe(200);
    // Ändern im anderen Betrieb ließ meines unberührt.
    expect((await photoOf())!.id).toBe(id);
  });

  test('Tablet: ohne Schlüssel 401, unbekannte oder ungültige Kennung 404', async () => {
    expect((await getDevice('00000000-0000-4000-8000-000000000000', null)).statusCode).toBe(401);
    expect((await getDevice('00000000-0000-4000-8000-000000000000')).statusCode).toBe(404);
    expect((await getDevice('kein-uuid')).statusCode).toBe(404);
  });

  test('das Objekt fehlt in der Ablage: 404 statt Absturz', async () => {
    const cur = await photoOf();
    const key = (await keysOnDisk()).find((k) => k.endsWith(`${cur!.id}.webp`))!;
    await rm(key);
    expect((await getDevice(cur!.id)).statusCode).toBe(404);
  });

  test('gesperrte Kassa: 403 register_blocked', async () => {
    const cur = await photoOf();
    await withBusiness(a.db, businessId, (c) => c.query('update registers set blocked_at = now() where id = $1', [registerId]));
    const res = await getDevice(cur!.id);
    expect(res.statusCode).toBe(403);
    expect(res.json().error.code).toBe('register_blocked');
  });
});
