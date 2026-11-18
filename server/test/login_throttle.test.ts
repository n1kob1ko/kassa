import { afterAll, beforeAll, beforeEach, expect, test } from 'vitest';
import { clearLoginFailures, loginWait, recordLoginFailure } from '../src/auth/login_throttle.js';
import { withSystem } from '../src/db/tenant.js';
import { testApp } from './support/app.js';
import { createProvider, PROVIDER_EMAIL, TEST_PASSWORD } from './support/users.js';

let t: Awaited<ReturnType<typeof testApp>>;
const START = new Date('2026-11-18T10:00:00Z');
const at = (seconds: number) => new Date(START.getTime() + seconds * 1000);

beforeAll(async () => {
  t = await testApp();
  await createProvider(t.app, t.db);
});
afterAll(() => t.close());
beforeEach(async () => {
  t.now.value = START;
  await withSystem(t.db, (c) => c.query('delete from login_failures'));
});

function login(password: string) {
  return t.app.inject({
    method: 'POST',
    url: '/api/auth/login',
    headers: { 'x-kassa-request': '1' },
    payload: { email: PROVIDER_EMAIL, password },
  });
}

test('5 Fehlversuche: 60 s warten, 6: 120 s, 9 und mehr: 900 s', async () => {
  const email = 'jemand@example.com';
  const waits = await withSystem(t.db, async (c) => {
    const result: number[] = [];
    for (let n = 1; n <= 12; n++) {
      // Großschreibung zählt zur selben Adresse.
      await recordLoginFailure(c, n % 2 === 0 ? email.toUpperCase() : email, START);
      result.push(await loginWait(c, email, START));
    }
    return result;
  });
  expect(waits).toEqual([0, 0, 0, 0, 60, 120, 240, 480, 900, 900, 900, 900]);

  await withSystem(t.db, async (c) => {
    // Die Wartezeit läuft ab dem letzten Fehlversuch und wird kürzer.
    expect(await loginWait(c, email, at(600))).toBe(300);
    expect(await loginWait(c, email, at(900))).toBe(0);
    // Eine andere Adresse ist nicht betroffen.
    expect(await loginWait(c, 'andere@example.com', START)).toBe(0);
    // Fehlversuche, die älter als 24 Stunden sind, zählen nicht mehr.
    expect(await loginWait(c, email, at(24 * 3600 + 1))).toBe(0);
    await clearLoginFailures(c, email.toUpperCase());
    expect(await loginWait(c, email, START)).toBe(0);
  });

  await withSystem(t.db, async (c) => {
    for (let n = 0; n < 4; n++) await recordLoginFailure(c, email, at(-24 * 3600 - 10));
    await recordLoginFailure(c, email, START);
    // Nur einer der fünf liegt in den letzten 24 Stunden.
    expect(await loginWait(c, email, START)).toBe(0);
  });
});

test('nach der Wartezeit geht ein Versuch, ein Erfolg löscht die Zählung', async () => {
  for (let n = 0; n < 5; n++) expect((await login('falsches-passwort')).statusCode).toBe(401);

  const blocked = await login('falsches-passwort');
  expect(blocked.statusCode).toBe(429);
  expect(blocked.json().error.code).toBe('too_many_attempts');
  expect(blocked.json().retryAfterSeconds).toBe(60);
  expect(blocked.headers['retry-after']).toBe('60');

  t.now.value = at(30);
  expect((await login('falsches-passwort')).json().retryAfterSeconds).toBe(30);

  // Nach der Wartezeit geht ein Versuch, der falsche verlängert auf 2 Minuten.
  t.now.value = at(60);
  expect((await login('falsches-passwort')).statusCode).toBe(401);
  expect((await login('falsches-passwort')).json().retryAfterSeconds).toBe(120);

  t.now.value = at(180);
  const ok = await login(TEST_PASSWORD);
  expect(ok.statusCode).toBe(200);

  // Die Zählung beginnt von vorn: vier falsche gehen, der fünfte auch, erst danach wird gewartet.
  for (let n = 0; n < 5; n++) expect((await login('falsches-passwort')).statusCode).toBe(401);
  expect((await login('falsches-passwort')).statusCode).toBe(429);
});

test('während der Wartezeit zählt auch das richtige Passwort nicht', async () => {
  for (let n = 0; n < 5; n++) await login('falsches-passwort');

  t.now.value = at(59);
  const res = await login(TEST_PASSWORD);
  expect(res.statusCode).toBe(429);
  expect(res.json().retryAfterSeconds).toBe(1);
  expect(res.headers['set-cookie']).toBeUndefined();

  // Der abgelehnte Versuch hat die Wartezeit nicht verlängert.
  t.now.value = at(60);
  expect((await login(TEST_PASSWORD)).statusCode).toBe(200);
});
