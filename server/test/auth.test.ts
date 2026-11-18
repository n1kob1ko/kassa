import { afterAll, beforeAll, expect, test } from 'vitest';
import { buildApp, loggerOptions } from '../src/app.js';
import { requireBusinessAccess, requireProvider, requireUser, isUuid } from '../src/auth/guards.js';
import { sha256 } from '../src/auth/secrets.js';
import { withSystem } from '../src/db/tenant.js';
import { tmpdir } from 'node:os';
import { LocalFileStore } from '../src/storage/local_file_store.js';
import { testApp, type TestApp } from './support/app.js';
import { createTestDb, TEST_APP_PASSWORD } from './support/db.js';
import { authed, insertBusiness, createChef, createProvider, PROVIDER_EMAIL, TEST_PASSWORD } from './support/users.js';

const SETUP = 'einmal-schluessel-fuer-tests-0123456789';
const DAY = 24 * 3600 * 1000;

const apps: TestApp[] = [];
async function fresh(config: Parameters<typeof testApp>[0] = {}): Promise<TestApp> {
  const a = await testApp(config);
  apps.push(a);
  return a;
}
afterAll(async () => {
  for (const a of apps) await a.close();
});

function post(a: TestApp, url: string, payload: object, headers: Record<string, string> = {}) {
  return a.app.inject({ method: 'POST', url, payload, headers: { 'x-kassa-request': '1', ...headers } });
}
const setup = (a: TestApp, body: object) => post(a, '/api/auth/setup', body);
const login = (a: TestApp, email: string, password: string) => post(a, '/api/auth/login', { email, password });
const me = (a: TestApp, cookie?: string) =>
  a.app.inject({ method: 'GET', url: '/api/auth/me', headers: cookie ? { cookie } : {} });

/** "name=wert" aus der ersten Set-Cookie-Kopfzeile. */
function cookieOf(res: { headers: Record<string, unknown> }): string {
  const raw = res.headers['set-cookie'];
  const first = Array.isArray(raw) ? raw[0] : raw;
  expect(typeof first).toBe('string');
  return (first as string).split(';')[0]!;
}

function setCookieHeader(res: { headers: Record<string, unknown> }): string {
  const raw = res.headers['set-cookie'];
  return (Array.isArray(raw) ? raw[0] : raw) as string;
}

test('Einrichten mit richtigem Schlüssel legt den Anbieter an und meldet an', async () => {
  const a = await fresh({ config: { setupToken: SETUP } });

  expect((await a.app.inject({ method: 'GET', url: `/api/auth/setup?token=${SETUP}` })).json()).toEqual({ valid: true });
  expect((await a.app.inject({ method: 'GET', url: '/api/auth/setup?token=falsch' })).json()).toEqual({ valid: false });
  expect((await a.app.inject({ method: 'GET', url: '/api/auth/setup' })).json()).toEqual({ valid: false });

  const res = await setup(a, { token: SETUP, email: 'Beispiel@Example.com', password: TEST_PASSWORD });
  expect(res.statusCode).toBe(201);
  const user = res.json().user;
  expect(user).toEqual({ id: expect.any(String), email: PROVIDER_EMAIL, role: 'provider', businessId: null });

  const now = await me(a, cookieOf(res));
  expect(now.statusCode).toBe(200);
  expect(now.json().user).toEqual(user);

  // Mit dem gewählten Passwort kann er sich danach anmelden.
  expect((await login(a, PROVIDER_EMAIL, TEST_PASSWORD)).statusCode).toBe(200);
});

test('derselbe Schlüssel gilt kein zweites Mal', async () => {
  const a = await fresh({ config: { setupToken: SETUP } });
  expect((await setup(a, { token: SETUP, email: PROVIDER_EMAIL, password: TEST_PASSWORD })).statusCode).toBe(201);

  const again = await setup(a, { token: SETUP, email: 'zweiter@example.com', password: TEST_PASSWORD });
  expect(again.statusCode).toBe(403);
  expect(again.json().error.code).toBe('setup_invalid');
  expect(again.headers['set-cookie']).toBeUndefined();
  expect((await a.app.inject({ method: 'GET', url: `/api/auth/setup?token=${SETUP}` })).json()).toEqual({ valid: false });

  const wrong = await setup(a, { token: 'ein-anderer-schluessel', email: 'dritter@example.com', password: TEST_PASSWORD });
  expect(wrong.statusCode).toBe(403);
  expect(wrong.json().error.code).toBe('setup_invalid');

  const users = await withSystem(a.db, (c) => c.query('select email from users'));
  expect(users.rows).toEqual([{ email: PROVIDER_EMAIL }]);
});

test('ein abgelehntes Einrichten verbraucht den Schlüssel nicht', async () => {
  const a = await fresh({ config: { setupToken: SETUP } });
  const short = await setup(a, { token: SETUP, email: PROVIDER_EMAIL, password: '123456789' });
  expect(short.statusCode).toBe(422);
  const bad = await setup(a, { token: SETUP, email: 'ohne-at.example.com', password: TEST_PASSWORD });
  expect(bad.statusCode).toBe(422);
  expect(bad.json().error.code).toBe('email_invalid');
  const long = await setup(a, { token: SETUP, email: `${'a'.repeat(243)}@example.com`, password: TEST_PASSWORD });
  expect(long.statusCode).toBe(422);
  expect(long.json().error.code).toBe('email_invalid');

  const chef = await createChef(a.db, await insertBusiness(a.db));
  const taken = await setup(a, { token: SETUP, email: chef.user.email.toUpperCase(), password: TEST_PASSWORD });
  expect(taken.statusCode).toBe(409);
  expect(taken.json().error.code).toBe('email_taken');

  expect((await setup(a, { token: SETUP, email: 'neu@example.com', password: TEST_PASSWORD })).statusCode).toBe(201);
});

const NEW_PASSWORD = 'neues-passwort-456';

test('neuer Schlüssel mit der E-Mail des Anbieters setzt sein Passwort neu', async () => {
  const a = await fresh({ config: { setupToken: SETUP } });
  const old = await createProvider(a.app, a.db);
  await withSystem(a.db, (c) =>
    c.query(`insert into login_failures (email_hash, at) values ($1, $2)`, [sha256(PROVIDER_EMAIL), a.now.value]),
  );

  const res = await setup(a, { token: SETUP, email: ' Beispiel@Example.com', password: NEW_PASSWORD });
  expect(res.statusCode).toBe(200);
  expect(res.json().user).toEqual(old.user);

  // Die neue Sitzung gilt, die alte nicht mehr.
  expect((await me(a, cookieOf(res))).json().user).toEqual(old.user);
  expect((await me(a, old.cookie)).statusCode).toBe(401);
  // Die Fehlversuche sind gelöscht.
  const failures = await withSystem(a.db, (c) => c.query('select count(*)::int as n from login_failures'));
  expect(failures.rows[0].n).toBe(0);

  expect((await login(a, PROVIDER_EMAIL, TEST_PASSWORD)).statusCode).toBe(401);
  expect((await login(a, PROVIDER_EMAIL, NEW_PASSWORD)).statusCode).toBe(200);

  // Der Schlüssel ist verbraucht, es gibt weiter genau einen Benutzer.
  expect((await setup(a, { token: SETUP, email: PROVIDER_EMAIL, password: 'noch-ein-passwort' })).statusCode).toBe(403);
  const users = await withSystem(a.db, (c) => c.query('select id, role from users'));
  expect(users.rows).toEqual([{ id: old.user.id, role: 'provider' }]);
});

test('Zurücksetzen prüft Passwort und E-Mail, bevor der Schlüssel verbraucht wird', async () => {
  const a = await fresh({ config: { setupToken: SETUP } });
  const old = await createProvider(a.app, a.db);
  const short = await setup(a, { token: SETUP, email: PROVIDER_EMAIL, password: '123456789' });
  expect(short.statusCode).toBe(422);
  expect(short.json().error.code).toBe('password_too_short');
  expect((await me(a, old.cookie)).statusCode).toBe(200);
  expect((await login(a, PROVIDER_EMAIL, TEST_PASSWORD)).statusCode).toBe(200);
  expect((await a.app.inject({ method: 'GET', url: `/api/auth/setup?token=${SETUP}` })).json()).toEqual({ valid: true });
});

test('Schlüssel mit der E-Mail eines Chefs oder Gesperrten: 409, der Schlüssel bleibt gültig', async () => {
  const a = await fresh({ config: { setupToken: SETUP } });
  const chef = await createChef(a.db, await insertBusiness(a.db));
  const provider = await createProvider(a.app, a.db);
  await withSystem(a.db, (c) => c.query('update users set disabled_at = now() where id = $1', [provider.user.id]));

  for (const email of [chef.user.email, PROVIDER_EMAIL]) {
    const res = await setup(a, { token: SETUP, email, password: NEW_PASSWORD });
    expect(res.statusCode, email).toBe(409);
    expect(res.json().error.code).toBe('email_taken');
    expect(res.headers['set-cookie']).toBeUndefined();
  }
  // Nichts hat sich geändert: der Chef bleibt Chef mit altem Passwort und Sitzung, der Gesperrte gesperrt.
  expect((await me(a, chef.cookie)).json().user).toEqual(chef.user);
  expect((await login(a, chef.user.email, TEST_PASSWORD)).statusCode).toBe(200);
  expect((await login(a, chef.user.email, NEW_PASSWORD)).statusCode).toBe(401);
  const rows = await withSystem(a.db, (c) =>
    c.query('select role, disabled_at is not null as blocked from users order by role'),
  );
  expect(rows.rows).toEqual([
    { role: 'chef', blocked: false },
    { role: 'provider', blocked: true },
  ]);

  // Derselbe Schlüssel gilt danach für ein richtiges Einrichten.
  const ok = await setup(a, { token: SETUP, email: 'neu@example.com', password: NEW_PASSWORD });
  expect(ok.statusCode).toBe(201);
  expect(ok.json().user.role).toBe('provider');
});

test('Zurücksetzen steht im Verlauf, das Passwort nicht', async () => {
  const a = await fresh({ config: { setupToken: SETUP } });
  const old = await createProvider(a.app, a.db);
  const res = await setup(a, { token: SETUP, email: PROVIDER_EMAIL, password: NEW_PASSWORD });
  const rows = (await withSystem(a.db, (c) => c.query('select * from audit_log order by id'))).rows;
  expect(rows.map((r) => [r.action, r.user_id, r.business_id])).toEqual([['auth.setup_reset', old.user.id, null]]);
  const text = JSON.stringify(rows);
  for (const s of [NEW_PASSWORD, TEST_PASSWORD, SETUP, cookieOf(res).split('=')[1]!, old.cookie.split('=')[1]!]) {
    expect(text).not.toContain(s);
    expect(text).not.toContain(sha256(s).toString('hex'));
  }
  expect(text).not.toMatch(/scrypt/);
});

test('ohne SETUP_TOKEN ist Einrichten immer 403', async () => {
  const a = await fresh();
  for (const token of ['', 'irgendwas', 'undefined']) {
    const res = await setup(a, { token, email: PROVIDER_EMAIL, password: TEST_PASSWORD });
    expect(res.statusCode).toBe(403);
    expect(res.json().error.code).toBe('setup_invalid');
  }
  expect((await a.app.inject({ method: 'GET', url: '/api/auth/setup?token=' })).json()).toEqual({ valid: false });
  const users = await withSystem(a.db, (c) => c.query('select count(*)::int as n from users'));
  expect(users.rows[0].n).toBe(0);
});

test('Passwort mit 9 Zeichen: 422 password_too_short', async () => {
  const a = await fresh({ config: { setupToken: SETUP } });
  const res = await setup(a, { token: SETUP, email: PROVIDER_EMAIL, password: '123456789' });
  expect(res.statusCode).toBe(422);
  expect(res.json().error).toEqual({ code: 'password_too_short', message: expect.any(String) });
  expect((await setup(a, { token: SETUP, email: PROVIDER_EMAIL, password: '1234567890' })).statusCode).toBe(201);
});

let shared: TestApp;
let business: string;
let otherBusiness: string;
beforeAll(async () => {
  shared = await fresh();
  await createProvider(shared.app, shared.db);
  business = await insertBusiness(shared.db);
  otherBusiness = await insertBusiness(shared.db, 'Zweiter Imbiss');
  shared.app.get('/api/admin/test/user', async (req) => ({ user: requireUser(req) }));
  shared.app.get('/api/admin/test/provider', async (req) => ({ user: requireProvider(req) }));
  shared.app.get<{ Params: { b: string } }>('/api/admin/test/b/:b', async (req) => ({
    user: await requireBusinessAccess(req, req.params.b),
  }));
});

test('Anmelden setzt ein HttpOnly-Cookie mit SameSite=Lax', async () => {
  const res = await login(shared, PROVIDER_EMAIL, TEST_PASSWORD);
  expect(res.statusCode).toBe(200);
  expect(res.json().user).toMatchObject({ email: PROVIDER_EMAIL, role: 'provider', businessId: null });
  const header = setCookieHeader(res);
  expect(header).toMatch(/^kassa_session=[A-Za-z0-9_-]{43};/);
  expect(header).toContain('HttpOnly');
  expect(header).toContain('SameSite=Lax');
  expect(header).toContain('Path=/');
  expect(header).toContain('Max-Age=2592000');
  expect(header).not.toContain('Secure');

  const https = await fresh({ config: { publicUrl: 'https://kassa.example.com' } });
  await createProvider(https.app, https.db);
  const secure = setCookieHeader(await login(https, PROVIDER_EMAIL, TEST_PASSWORD));
  expect(secure).toMatch(/^__Host-kassa_session=[A-Za-z0-9_-]{43};/);
  expect(secure).toContain('Secure');
  expect(secure).toContain('HttpOnly');
  expect(secure).toContain('SameSite=Lax');
  expect(secure).toContain('Path=/');
  expect(secure).not.toContain('Domain');
});

test('falsches Passwort und unbekannte E-Mail geben dieselbe Antwort', async () => {
  const wrong = await login(shared, PROVIDER_EMAIL, 'falsches-passwort');
  const unknown = await login(shared, 'niemand@example.com', 'falsches-passwort');
  expect(wrong.statusCode).toBe(401);
  expect(unknown.statusCode).toBe(401);
  expect(wrong.json()).toEqual({ error: { code: 'login_failed', message: 'E-Mail oder Passwort stimmt nicht.' } });
  expect(unknown.json()).toEqual(wrong.json());
  expect(wrong.headers['set-cookie']).toBeUndefined();
  expect(unknown.headers['set-cookie']).toBeUndefined();

  // Ein Chef ohne Passwort und ein gesperrter Benutzer bekommen dieselbe Antwort.
  const chef = await createChef(shared.db, business);
  await withSystem(shared.db, (c) => c.query('update users set password_hash = null where id = $1', [chef.user.id]));
  expect((await login(shared, chef.user.email, TEST_PASSWORD)).json()).toEqual(wrong.json());
  const blocked = await createChef(shared.db, business);
  await withSystem(shared.db, (c) => c.query('update users set disabled_at = now() where id = $1', [blocked.user.id]));
  expect((await login(shared, blocked.user.email, TEST_PASSWORD)).json()).toEqual(wrong.json());
  await withSystem(shared.db, (c) => c.query('delete from login_failures'));
});

test('E-Mail in Großbuchstaben meldet denselben Benutzer an', async () => {
  const lower = await login(shared, PROVIDER_EMAIL, TEST_PASSWORD);
  const upper = await login(shared, '  BEISPIEL@EXAMPLE.COM ', TEST_PASSWORD);
  expect(upper.statusCode).toBe(200);
  expect(upper.json().user.id).toBe(lower.json().user.id);
});

test('me ohne Cookie: 401, mit Cookie: der Benutzer ohne password_hash', async () => {
  const none = await me(shared);
  expect(none.statusCode).toBe(401);
  expect(none.json().error.code).toBe('unauthorized');
  expect((await me(shared, 'kassa_session=gibt-es-nicht')).statusCode).toBe(401);

  const res = await me(shared, cookieOf(await login(shared, PROVIDER_EMAIL, TEST_PASSWORD)));
  expect(res.statusCode).toBe(200);
  expect(Object.keys(res.json().user).sort()).toEqual(['businessId', 'email', 'id', 'role']);
  expect(res.body).not.toMatch(/password|scrypt/i);
});

test('Abmelden macht das Cookie wertlos', async () => {
  const cookie = cookieOf(await login(shared, PROVIDER_EMAIL, TEST_PASSWORD));
  const res = await shared.app.inject({ method: 'POST', url: '/api/auth/logout', headers: authed(cookie) });
  expect(res.statusCode).toBe(204);
  expect(setCookieHeader(res)).toMatch(/^kassa_session=;/);
  expect((await me(shared, cookie)).statusCode).toBe(401);
  const token = cookie.split('=')[1]!;
  const left = await withSystem(shared.db, (c) => c.query('select 1 from sessions where id_hash = $1', [sha256(token)]));
  expect(left.rowCount).toBe(0);
});

test('Sitzung läuft nach 30 Tagen ohne Benutzung ab, Benutzung am Tag 29 verlängert', async () => {
  const a = await fresh();
  const start = a.now.value.getTime();
  const { cookie } = await createProvider(a.app, a.db);
  const seen = async () =>
    (
      await withSystem(a.db, (c) =>
        c.query<{ last_seen_at: Date; expires_at: Date }>('select last_seen_at, expires_at from sessions'),
      )
    ).rows[0]!;

  a.now.value = new Date(start + 29 * DAY);
  expect((await me(a, cookie)).statusCode).toBe(200);
  expect((await seen()).last_seen_at.getTime()).toBe(start + 29 * DAY);
  expect((await seen()).expires_at.getTime()).toBe(start + 59 * DAY);

  // Innerhalb einer Stunde bleibt last_seen_at, verlängert wird trotzdem.
  a.now.value = new Date(start + 29 * DAY + 30 * 60 * 1000);
  expect((await me(a, cookie)).statusCode).toBe(200);
  expect((await seen()).last_seen_at.getTime()).toBe(start + 29 * DAY);
  expect((await seen()).expires_at.getTime()).toBe(start + 59 * DAY + 30 * 60 * 1000);

  a.now.value = new Date(start + 58 * DAY);
  expect((await me(a, cookie)).statusCode).toBe(200);

  a.now.value = new Date(start + 88 * DAY + 1000);
  expect((await me(a, cookie)).statusCode).toBe(401);
  // Auch später gilt sie nicht wieder.
  expect((await me(a, cookie)).statusCode).toBe(401);
});

test('ein gesperrter Benutzer ist sofort abgemeldet', async () => {
  const chef = await createChef(shared.db, business);
  expect((await me(shared, chef.cookie)).statusCode).toBe(200);
  await withSystem(shared.db, (c) => c.query('update users set disabled_at = now() where id = $1', [chef.user.id]));
  expect((await me(shared, chef.cookie)).statusCode).toBe(401);
});

test('POST ohne X-Kassa-Request: 403 csrf', async () => {
  for (const url of ['/api/auth/login', '/api/auth/logout', '/api/auth/setup', '/api/admin/irgendwas']) {
    const res = await shared.app.inject({
      method: 'POST',
      url,
      payload: { email: PROVIDER_EMAIL, password: TEST_PASSWORD },
    });
    expect(res.statusCode, url).toBe(403);
    expect(res.json().error.code).toBe('csrf');
    expect(res.headers['set-cookie']).toBeUndefined();
  }
  const wrongValue = await shared.app.inject({
    method: 'POST',
    url: '/api/auth/login',
    headers: { 'x-kassa-request': '0' },
    payload: { email: PROVIDER_EMAIL, password: TEST_PASSWORD },
  });
  expect(wrongValue.statusCode).toBe(403);
  // GET braucht die Kopfzeile nicht.
  expect((await me(shared)).statusCode).toBe(401);
});

test('POST mit fremdem Origin: 403 csrf', async () => {
  for (const origin of ['https://boese.example', 'http://localhost:8080', 'null']) {
    const res = await post(shared, '/api/auth/login', { email: PROVIDER_EMAIL, password: TEST_PASSWORD }, { origin });
    expect(res.statusCode, origin).toBe(403);
    expect(res.json().error.code).toBe('csrf');
  }
  const own = await post(
    shared,
    '/api/auth/login',
    { email: PROVIDER_EMAIL, password: TEST_PASSWORD },
    { origin: 'http://localhost' },
  );
  expect(own.statusCode).toBe(200);
});

test('Anmeldung und Einrichten stehen im Verlauf, das Passwort nicht', async () => {
  const a = await fresh({ config: { setupToken: SETUP } });
  const created = await setup(a, { token: SETUP, email: PROVIDER_EMAIL, password: TEST_PASSWORD });
  const id = created.json().user.id;
  const loggedIn = await login(a, PROVIDER_EMAIL, TEST_PASSWORD);
  await a.app.inject({ method: 'POST', url: '/api/auth/logout', headers: authed(cookieOf(loggedIn)) });

  const rows = (await withSystem(a.db, (c) => c.query('select * from audit_log order by id'))).rows;
  expect(rows.map((r) => [r.action, r.user_id, r.business_id])).toEqual([
    ['auth.setup', id, null],
    ['auth.login', id, null],
    ['auth.logout', id, null],
  ]);
  expect(rows[0].at.getTime()).toBe(a.now.value.getTime());

  const text = JSON.stringify(rows);
  const secrets = [TEST_PASSWORD, SETUP, cookieOf(created).split('=')[1]!, cookieOf(loggedIn).split('=')[1]!];
  for (const s of secrets) {
    expect(text).not.toContain(s);
    expect(text).not.toContain(sha256(s).toString('hex'));
    expect(text).not.toContain(sha256(s).toString('base64'));
  }
  expect(text).not.toMatch(/scrypt/);

  // Ein Chef steht mit seinem Betrieb im Verlauf.
  const b = await insertBusiness(a.db);
  const chef = await createChef(a.db, b);
  await login(a, chef.user.email, TEST_PASSWORD);
  const last = (await withSystem(a.db, (c) => c.query('select * from audit_log order by id desc limit 1'))).rows[0];
  expect([last.action, last.user_id, last.business_id]).toEqual(['auth.login', chef.user.id, b]);
});

test('im Protokoll steht kein Geheimnis', async () => {
  const testDb = await createTestDb();
  const lines: string[] = [];
  const app = await buildApp(
    {
      config: {
        databaseUrl: testDb.ownerUrl,
        appDbPassword: TEST_APP_PASSWORD,
        port: 0,
        publicUrl: 'http://localhost',
        setupToken: SETUP,
        passwordCost: 1024,
      },
      db: testDb.db,
      files: new LocalFileStore(tmpdir()),
      now: () => new Date('2026-11-18T10:00:00Z'),
    },
    { logger: loggerOptions({ write: (s: string) => void lines.push(s) }) },
  );
  try {
    await app.inject({ method: 'GET', url: `/api/auth/setup?token=${SETUP}` });
    const created = await app.inject({
      method: 'POST',
      url: '/api/auth/setup',
      headers: { 'x-kassa-request': '1' },
      payload: { token: SETUP, email: PROVIDER_EMAIL, password: TEST_PASSWORD },
    });
    const cookie = cookieOf(created);
    await app.inject({ method: 'GET', url: '/api/auth/me', headers: { cookie } });
    await app.inject({
      method: 'POST',
      url: '/api/auth/login',
      headers: { 'x-kassa-request': '1' },
      payload: { email: PROVIDER_EMAIL, password: 'falsches-passwort' },
    });
    expect(lines.length).toBeGreaterThan(0);
    const text = lines.join('\n');
    expect(text).toContain('/api/auth/setup');
    for (const s of [SETUP, TEST_PASSWORD, 'falsches-passwort', cookie.split('=')[1]!]) expect(text).not.toContain(s);
  } finally {
    await app.close();
    await testDb.drop();
  }
});

test('Wächter: ohne Anmeldung 401, falsche Rolle oder fremder Betrieb 404', async () => {
  const get = (url: string, cookie?: string) =>
    shared.app.inject({ method: 'GET', url, headers: cookie ? { cookie } : {} });
  const provider = cookieOf(await login(shared, PROVIDER_EMAIL, TEST_PASSWORD));
  const chef = await createChef(shared.db, business);
  const unknown = '00000000-0000-4000-8000-000000000000';

  for (const url of [
    '/api/admin/test/user',
    '/api/admin/test/provider',
    `/api/admin/test/b/${business}`,
    '/api/admin/test/b/kein-uuid',
  ]) {
    const res = await get(url);
    expect(res.statusCode, url).toBe(401);
    expect(res.json().error.code).toBe('unauthorized');
  }

  expect((await get('/api/admin/test/user', chef.cookie)).json().user.id).toBe(chef.user.id);
  expect((await get('/api/admin/test/provider', provider)).statusCode).toBe(200);
  const chefOnProvider = await get('/api/admin/test/provider', chef.cookie);
  expect(chefOnProvider.statusCode).toBe(404);
  expect(chefOnProvider.json().error.code).toBe('not_found');

  expect((await get(`/api/admin/test/b/${business}`, provider)).statusCode).toBe(200);
  expect((await get(`/api/admin/test/b/${otherBusiness}`, provider)).statusCode).toBe(200);
  expect((await get(`/api/admin/test/b/${business}`, chef.cookie)).json().user.id).toBe(chef.user.id);
  expect((await get(`/api/admin/test/b/${business.toUpperCase()}`, chef.cookie)).statusCode).toBe(200);
  for (const [b, cookie] of [
    [unknown, provider],
    [otherBusiness, chef.cookie],
    [unknown, chef.cookie],
    ['kein-uuid', provider],
    ['kein-uuid', chef.cookie],
  ] as const) {
    const res = await get(`/api/admin/test/b/${b}`, cookie);
    expect(res.statusCode, b).toBe(404);
    expect(res.json().error.code).toBe('not_found');
  }
});

test('isUuid erkennt nur die übliche Schreibweise', () => {
  expect(isUuid('00000000-0000-4000-8000-000000000000')).toBe(true);
  expect(isUuid('6F9619FF-8B86-D011-B42D-00C04FC964FF')).toBe(true);
  for (const s of [
    '',
    'kein-uuid',
    '00000000000040008000000000000000',
    '{00000000-0000-4000-8000-000000000000}',
    '00000000-0000-4000-8000-00000000000g',
    ' 00000000-0000-4000-8000-000000000000',
  ]) {
    expect(isUuid(s), s).toBe(false);
  }
});

test('Anmelden: 30 Versuche pro Adresse in 15 Minuten, dann 429 vor dem Passwort, andere Adressen nicht betroffen', async () => {
  const a = await fresh();
  await createProvider(a.app, a.db);
  const from = (ip: string, email: string, password: string) =>
    a.app.inject({
      method: 'POST',
      url: '/api/auth/login',
      payload: { email, password },
      headers: { 'x-kassa-request': '1' },
      remoteAddress: ip,
    });
  const failures = async () =>
    withSystem(a.db, async (c) => (await c.query('select count(*)::int as n from login_failures')).rows[0].n as number);

  // Ein Erfolg gibt keinen Platz frei.
  expect((await from('10.1.0.1', PROVIDER_EMAIL, TEST_PASSWORD)).statusCode).toBe(200);
  for (let i = 1; i < 30; i++) {
    expect((await from('10.1.0.1', `niemand-${i}@example.com`, 'falsch-falsch')).statusCode).toBe(401);
  }
  const before = await failures();
  const over = await from('10.1.0.1', 'noch-einer@example.com', 'falsch-falsch');
  expect(over.statusCode).toBe(429);
  expect(over.json().error).toEqual({ code: 'too_many_attempts', message: 'Zu viele Versuche. Bitte in 15 Minuten nochmal.' });
  expect(over.json().retryAfterSeconds).toBe(900);
  expect(over.headers['retry-after']).toBe('900');
  // Auch das richtige Passwort wartet, und der abgelehnte Versuch schreibt keine Zeile.
  expect((await from('10.1.0.1', PROVIDER_EMAIL, TEST_PASSWORD)).statusCode).toBe(429);
  expect(await failures()).toBe(before);

  expect((await from('10.1.0.2', PROVIDER_EMAIL, TEST_PASSWORD)).statusCode).toBe(200);

  a.now.value = new Date(a.now.value.getTime() + 15 * 60 * 1000 + 1000);
  expect((await from('10.1.0.1', PROVIDER_EMAIL, TEST_PASSWORD)).statusCode).toBe(200);
});
