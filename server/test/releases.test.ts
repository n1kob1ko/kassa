import { createHash, randomBytes } from 'node:crypto';
import { readdir, stat } from 'node:fs/promises';
import { join } from 'node:path';
import { Readable } from 'node:stream';
import { afterAll, expect, test } from 'vitest';
import { buildApp, loggerOptions } from '../src/app.js';
import { withSystem } from '../src/db/tenant.js';
import { LocalFileStore } from '../src/storage/local_file_store.js';
import { testApp, type TestApp } from './support/app.js';
import { createTestDb, TEST_APP_PASSWORD } from './support/db.js';
import { authed, createChef, createProvider, insertBusiness } from './support/users.js';

const TOKEN = 'release-schluessel-fuer-tests-0123456789';
const APK = 'application/vnd.android.package-archive';

const apps: TestApp[] = [];
async function fresh(
  overrides: Parameters<typeof testApp>[0] = {},
  opts: Parameters<typeof testApp>[1] = {},
): Promise<TestApp> {
  const a = await testApp({ ...overrides, config: { releaseToken: TOKEN, ...overrides.config } }, opts);
  apps.push(a);
  return a;
}
afterAll(async () => {
  for (const a of apps) await a.close();
});

const apk = (size = 2000) => Buffer.concat([Buffer.from([0x50, 0x4b, 0x03, 0x04]), randomBytes(size)]);

function upload(
  a: TestApp,
  body: Buffer | Readable,
  o: { version?: string; build?: string; token?: string | null; type?: string } = {},
) {
  const token = o.token === undefined ? TOKEN : o.token;
  return a.app.inject({
    method: 'PUT',
    url: `/api/releases/${o.version ?? '1.2.0'}?build=${o.build ?? '7'}`,
    headers: { 'content-type': o.type ?? APK, ...(token === null ? {} : { authorization: `Bearer ${token}` }) },
    payload: body,
  });
}

async function filesLeft(a: TestApp): Promise<string[]> {
  const names = await readdir(a.fileDir, { recursive: true, withFileTypes: true });
  return names.filter((e) => e.isFile()).map((e) => join(e.parentPath, e.name));
}

const count = (a: TestApp) =>
  withSystem(a.db, async (c) => (await c.query('select count(*)::int as n from releases')).rows[0].n as number);

test('hochladen und über den Link wieder laden: gleiche Bytes, sha256 und size stimmen', async () => {
  const a = await fresh();
  const bytes = apk(50_000);
  const res = await upload(a, bytes);
  expect(res.statusCode).toBe(201);
  const body = res.json();
  expect(body).toMatchObject({
    version: '1.2.0',
    build: 7,
    sha256: createHash('sha256').update(bytes).digest('hex'),
    size: bytes.length,
  });
  expect(body.id).toMatch(/^[0-9a-f-]{36}$/);
  expect(body.downloadPath).toMatch(/^\/laden\/[A-Za-z0-9_-]{43}\/kassa-1\.2\.0\.apk$/);

  const dl = await a.app.inject({ method: 'GET', url: body.downloadPath });
  expect(dl.statusCode).toBe(200);
  expect(Buffer.compare(dl.rawPayload, bytes)).toBe(0);
  expect(dl.headers['content-type']).toBe(APK);
  expect(dl.headers['content-disposition']).toBe('attachment; filename="kassa-1.2.0.apk"');
  expect(dl.headers['content-length']).toBe(String(bytes.length));
});

test('Antwort des Links trägt no-store und noindex', async () => {
  const a = await fresh();
  const { downloadPath } = (await upload(a, apk())).json();
  const dl = await a.app.inject({ method: 'GET', url: downloadPath });
  expect(dl.headers['cache-control']).toBe('private, no-store');
  expect(dl.headers['x-robots-tag']).toBe('noindex');
});

test('Link mit einem falschen Zeichen im geheimen Teil: 404, auch bei falschem Dateinamen, gleicher Text', async () => {
  const a = await fresh();
  const { downloadPath } = (await upload(a, apk())).json();
  const [, , secret, file] = downloadPath.split('/') as string[];
  const flipped = (secret!.at(0) === 'A' ? 'B' : 'A') + secret!.slice(1);
  const wrong = await a.app.inject({ method: 'GET', url: `/laden/${flipped}/${file}` });
  expect(wrong.statusCode).toBe(404);
  expect(wrong.payload).toBe('Diese Datei gibt es nicht.');
  expect(wrong.headers['content-type']).toMatch(/^text\/plain/);
  const otherName = await a.app.inject({ method: 'GET', url: `/laden/${secret}/kassa-9.9.9.apk` });
  expect(otherName.statusCode).toBe(404);
  expect(otherName.payload).toBe('Diese Datei gibt es nicht.');
  expect((await a.app.inject({ method: 'GET', url: `/laden/${secret}/${file}` })).statusCode).toBe(200);
});

test('ohne Schlüssel 401, falscher Schlüssel 401, ohne RELEASE_TOKEN in den Einstellungen 404', async () => {
  const a = await fresh();
  const none = await upload(a, apk(), { token: null });
  expect(none.statusCode).toBe(401);
  expect(none.json().error.code).toBe('unauthorized');
  expect((await upload(a, apk(), { token: 'falsch' })).statusCode).toBe(401);
  expect(await count(a)).toBe(0);
  expect(await filesLeft(a)).toEqual([]);

  const off = await fresh({ config: { releaseToken: undefined } });
  const res = await upload(off, apk());
  expect(res.statusCode).toBe(404);
  expect(res.json().error.code).toBe('not_found');
});

test('Version und Build werden vor dem Lesen des Inhalts geprüft: 422 version_invalid', async () => {
  const a = await fresh();
  for (const o of [
    { version: '1.2' },
    { version: 'v1.2.0' },
    { version: '1.2.0.1' },
    { build: '0' },
    { build: '-3' },
    { build: 'x' },
    { build: '1.5' },
    { build: '' },
  ]) {
    const res = await upload(a, apk(), o);
    expect(res.statusCode, JSON.stringify(o)).toBe(422);
    expect(res.json().error.code).toBe('version_invalid');
  }
  const noBuild = await a.app.inject({
    method: 'PUT',
    url: '/api/releases/1.2.0',
    headers: { 'content-type': APK, authorization: `Bearer ${TOKEN}` },
    payload: apk(),
  });
  expect(noBuild.statusCode).toBe(422);
  expect(await count(a)).toBe(0);
  expect(await filesLeft(a)).toEqual([]);
});

test('der Inhalt wird nicht gelesen, wenn der Schlüssel fehlt', async () => {
  const a = await fresh();
  let read = 0;
  const body = new Readable({
    read() {
      read += 1;
      this.push(Buffer.alloc(16 * 1024));
      if (read >= 50) this.push(null);
    },
  });
  const res = await upload(a, body, { token: 'falsch' });
  expect(res.statusCode).toBe(401);
  expect(read).toBeLessThan(50);
});

test('kein APK: 422 not_an_apk, die Ablage ist danach leer', async () => {
  const a = await fresh();
  for (const body of [Buffer.from('das ist kein apk, nur Text'), Buffer.from('PK'), Buffer.alloc(0)]) {
    const res = await upload(a, body);
    expect(res.statusCode).toBe(422);
    expect(res.json().error.code).toBe('not_an_apk');
  }
  expect(await filesLeft(a)).toEqual([]);
  expect(await count(a)).toBe(0);
});

test('zu groß: 413 file_too_large, bei bekannter und bei unbekannter Länge, die Ablage ist danach leer', async () => {
  const a = await fresh({ maxReleaseBytes: 1000 });
  const known = await upload(a, apk(2000));
  expect(known.statusCode).toBe(413);
  expect(known.json().error.code).toBe('file_too_large');

  // Ohne Content-Length greift erst die Zählung beim Durchreichen.
  const chunks = [apk(600), randomBytes(600), randomBytes(600)];
  const unknown = await upload(a, Readable.from(chunks));
  expect(unknown.statusCode).toBe(413);
  expect(unknown.json().error.code).toBe('file_too_large');

  expect(await filesLeft(a)).toEqual([]);
  expect(await count(a)).toBe(0);
  // Genau an der Grenze geht es noch.
  const edge = Buffer.concat([Buffer.from([0x50, 0x4b, 0x03, 0x04]), randomBytes(996)]);
  expect((await upload(a, edge)).statusCode).toBe(201);
});

test('die Grenze von 1 MB gilt weiter für alle anderen Adressen', async () => {
  const a = await fresh();
  const res = await a.app.inject({
    method: 'POST',
    url: '/api/auth/login',
    headers: { 'x-kassa-request': '1', 'content-type': 'application/json' },
    payload: JSON.stringify({ email: 'x@example.com', password: 'y'.repeat(1_100_000) }),
  });
  expect(res.statusCode).toBe(413);
  expect(res.json().error.code).toBe('payload_too_large');
});

test('gleiche Version und Build nochmal: 409 release_exists, die zweite Datei bleibt nicht liegen', async () => {
  const a = await fresh();
  expect((await upload(a, apk())).statusCode).toBe(201);
  const again = await upload(a, apk());
  expect(again.statusCode).toBe(409);
  expect(again.json().error.code).toBe('release_exists');
  expect(await filesLeft(a)).toHaveLength(1);
  expect(await count(a)).toBe(1);
  // Anderer Build derselben Version ist erlaubt.
  expect((await upload(a, apk(), { build: '8' })).statusCode).toBe(201);
});

test('Datenbank-Konflikt nach dem Hochladen (gleichzeitig): 409 und keine Datei übrig', async () => {
  const a = await fresh();
  const results = await Promise.all([upload(a, apk()), upload(a, apk()), upload(a, apk())]);
  const codes = results.map((r) => r.statusCode).sort();
  expect(codes).toEqual([201, 409, 409]);
  expect(await filesLeft(a)).toHaveLength(1);
  expect(await count(a)).toBe(1);
});

test('zurückgezogen: Link 404, Datei aus der Ablage weg, in der Liste withdrawn', async () => {
  const a = await fresh();
  const p = await createProvider(a.app, a.db);
  const { id, downloadPath } = (await upload(a, apk())).json();
  expect(await filesLeft(a)).toHaveLength(1);

  const del = await a.app.inject({ method: 'DELETE', url: `/api/admin/releases/${id}`, headers: authed(p.cookie) });
  expect(del.statusCode).toBe(204);
  const dl = await a.app.inject({ method: 'GET', url: downloadPath });
  expect(dl.statusCode).toBe(404);
  expect(dl.payload).toBe('Diese Datei gibt es nicht.');
  expect(await filesLeft(a)).toEqual([]);

  const list = await a.app.inject({ method: 'GET', url: '/api/admin/releases', headers: { cookie: p.cookie } });
  expect(list.json().releases[0]).toMatchObject({ id, withdrawn: true, downloadPath: null });
  // Nochmal zurückziehen ändert nichts und bleibt 204.
  expect(
    (await a.app.inject({ method: 'DELETE', url: `/api/admin/releases/${id}`, headers: authed(p.cookie) })).statusCode,
  ).toBe(204);
});

test('ist die Datei in der Ablage schon weg, liefert der Link 404 statt eines Fehlers', async () => {
  const a = await fresh();
  const { downloadPath } = (await upload(a, apk())).json();
  for (const f of await filesLeft(a)) await (await import('node:fs/promises')).rm(f);
  const dl = await a.app.inject({ method: 'GET', url: downloadPath });
  expect(dl.statusCode).toBe(404);
  expect(dl.payload).toBe('Diese Datei gibt es nicht.');
});

test('Liste: neueste zuerst mit allen Feldern, nur für den Anbieter: Chef 404, ohne Anmeldung 401', async () => {
  const a = await fresh();
  const p = await createProvider(a.app, a.db);
  const first = (await upload(a, apk(), { version: '1.2.0', build: '7' })).json();
  a.now.value = new Date('2026-11-19T10:00:00Z');
  await withSystem(a.db, (c) => c.query(`update releases set uploaded_at = $1 where id = $2`, [new Date('2026-11-17T10:00:00Z'), first.id]));
  const second = (await upload(a, apk(), { version: '1.3.0', build: '9' })).json();

  const list = await a.app.inject({ method: 'GET', url: '/api/admin/releases', headers: { cookie: p.cookie } });
  expect(list.statusCode).toBe(200);
  const { releases } = list.json();
  expect(releases.map((r: { id: string }) => r.id)).toEqual([second.id, first.id]);
  expect(releases[0]).toEqual({
    id: second.id,
    version: '1.3.0',
    build: 9,
    sha256: second.sha256,
    size: second.size,
    uploadedAt: expect.any(String),
    withdrawn: false,
    downloadPath: second.downloadPath,
  });

  const chef = await createChef(a.db, await insertBusiness(a.db));
  expect((await a.app.inject({ method: 'GET', url: '/api/admin/releases', headers: { cookie: chef.cookie } })).statusCode).toBe(404);
  expect((await a.app.inject({ method: 'GET', url: '/api/admin/releases' })).statusCode).toBe(401);
  const chefDel = await a.app.inject({ method: 'DELETE', url: `/api/admin/releases/${first.id}`, headers: authed(chef.cookie) });
  expect(chefDel.statusCode).toBe(404);
  const anonDel = await a.app.inject({ method: 'DELETE', url: `/api/admin/releases/${first.id}`, headers: { 'x-kassa-request': '1' } });
  expect(anonDel.statusCode).toBe(401);
  expect((await a.app.inject({ method: 'GET', url: second.downloadPath })).statusCode).toBe(200);
});

test('Zurückziehen: Kennung keine uuid oder unbekannt: 404; ohne Schutz-Kopfzeile 403', async () => {
  const a = await fresh();
  const p = await createProvider(a.app, a.db);
  for (const id of ['abc', '00000000-0000-4000-8000-000000000000']) {
    const res = await a.app.inject({ method: 'DELETE', url: `/api/admin/releases/${id}`, headers: authed(p.cookie) });
    expect(res.statusCode).toBe(404);
  }
  const noCsrf = await a.app.inject({ method: 'DELETE', url: '/api/admin/releases/abc', headers: { cookie: p.cookie } });
  expect(noCsrf.statusCode).toBe(403);
});

test('Verlauf: Hochladen und Zurückziehen mit Version und Build, nie Geheimnis oder Schlüssel', async () => {
  const a = await fresh();
  const p = await createProvider(a.app, a.db);
  const { id, downloadPath } = (await upload(a, apk())).json();
  await a.app.inject({ method: 'DELETE', url: `/api/admin/releases/${id}`, headers: authed(p.cookie) });
  const rows = (
    await withSystem(a.db, (c) => c.query(`select action, user_id, detail from audit_log where action like 'release.%' order by id`))
  ).rows;
  expect(rows.map((r) => r.action)).toEqual(['release.upload', 'release.withdraw']);
  expect(rows[0].detail).toEqual({ version: '1.2.0', build: 7 });
  expect(rows[1].detail).toEqual({ version: '1.2.0', build: 7 });
  expect(rows[1].user_id).toBe(p.user.id);
  const text = JSON.stringify(rows);
  expect(text).not.toContain(TOKEN);
  expect(text).not.toContain(downloadPath.split('/')[2]);
});

test('im Protokoll steht der geheime Teil des Links nicht, auch nicht der Schlüssel', async () => {
  const testDb = await createTestDb();
  const lines: string[] = [];
  const dirApp = await testApp();
  apps.push(dirApp);
  const app = await buildApp(
    {
      config: { ...dirApp.app.deps.config, databaseUrl: testDb.ownerUrl, appDbPassword: TEST_APP_PASSWORD, releaseToken: TOKEN },
      db: testDb.db,
      files: new LocalFileStore(dirApp.fileDir),
      now: () => new Date('2026-11-18T10:00:00Z'),
    },
    { logger: loggerOptions({ write: (s: string) => void lines.push(s) }) },
  );
  try {
    const up = await app.inject({
      method: 'PUT',
      url: '/api/releases/1.2.0?build=7',
      headers: { 'content-type': APK, authorization: `Bearer ${TOKEN}` },
      payload: apk(),
    });
    const { downloadPath } = up.json();
    const secret = downloadPath.split('/')[2] as string;
    await app.inject({ method: 'GET', url: downloadPath });
    await app.inject({ method: 'GET', url: `/laden/${secret}/kassa-0.0.1.apk` });
    await app.inject({ method: 'GET', url: `/laden/${secret}` });
    const text = lines.join('\n');
    expect(text).toContain('/laden/…/kassa-1.2.0.apk');
    expect(text).not.toContain(secret);
    expect(text).not.toContain(TOKEN);
  } finally {
    await app.close();
    await testDb.drop();
  }
});

test('Dateien liegen unter einem eigenen Schlüssel in der Ablage, nicht unter dem Link', async () => {
  const a = await fresh();
  const { downloadPath } = (await upload(a, apk())).json();
  const files = await filesLeft(a);
  expect(files).toHaveLength(1);
  expect(files[0]).not.toContain(downloadPath.split('/')[2]);
  expect((await stat(files[0]!)).size).toBeGreaterThan(0);
});
