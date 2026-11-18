import { afterAll, beforeAll, expect, test } from 'vitest';
import { recordLoginFailure } from '../src/auth/login_throttle.js';
import { pruneAuthRows } from '../src/auth/prune.js';
import { createSession } from '../src/auth/sessions.js';
import { withSystem } from '../src/db/tenant.js';
import { testApp, type TestApp } from './support/app.js';
import { createProvider } from './support/users.js';

const HOUR = 3600 * 1000;
const NOW = new Date('2026-11-18T10:00:00Z');
const ago = (ms: number) => new Date(NOW.getTime() - ms);

let a: TestApp;
beforeAll(async () => {
  a = await testApp();
});
afterAll(async () => {
  await a.close();
});

test('löscht Fehlversuche älter als 24 Stunden und abgelaufene Sitzungen, sonst nichts', async () => {
  const { user } = await createProvider(a.app, a.db);
  await withSystem(a.db, async (c) => {
    await recordLoginFailure(c, 'alt@example.com', ago(24 * HOUR + 1000));
    await recordLoginFailure(c, 'frisch@example.com', ago(23 * HOUR));
    // createSession setzt expires_at auf at + 30 Tage: vor 31 Tagen angelegt ist abgelaufen.
    await createSession(c, user.id, ago(31 * 24 * HOUR));
    await createSession(c, user.id, ago(29 * 24 * HOUR));
  });
  const before = await withSystem(a.db, async (c) => (await c.query('select count(*)::int as n from sessions')).rows[0].n);

  const removed = await withSystem(a.db, (c) => pruneAuthRows(c, NOW));
  expect(removed).toEqual({ loginFailures: 1, sessions: 1 });

  const left = await withSystem(a.db, async (c) => ({
    failures: (await c.query('select at from login_failures')).rows.map((r) => r.at.toISOString()),
    sessions: (await c.query('select count(*)::int as n from sessions')).rows[0].n,
    expired: (await c.query('select count(*)::int as n from sessions where expires_at <= $1', [NOW])).rows[0].n,
  }));
  expect(left.failures).toEqual([ago(23 * HOUR).toISOString()]);
  expect(left.sessions).toBe(before - 1);
  expect(left.expired).toBe(0);
  expect(await withSystem(a.db, (c) => pruneAuthRows(c, NOW))).toEqual({ loginFailures: 0, sessions: 0 });
});
