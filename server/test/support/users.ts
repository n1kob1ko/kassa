import { randomBytes } from 'node:crypto';
import type { FastifyInstance } from 'fastify';
import { hashPassword } from '../../src/auth/passwords.js';
import { createSession, sessionCookieName, type SessionUser } from '../../src/auth/sessions.js';
import type { Db } from '../../src/db/db.js';
import { withSystem } from '../../src/db/tenant.js';

export const TEST_PASSWORD = 'richtig-geheim-123';
export const PROVIDER_EMAIL = 'beispiel@example.com';

/** Fester Zeitpunkt für Hilfen ohne App, gleich der Uhr von testApp. */
const TEST_NOW = new Date('2026-11-18T10:00:00Z');
const TEST_COST = 1024;

export type TestUser = { user: SessionUser; cookie: string };

async function insertUser(
  db: Db,
  u: { email: string; role: 'provider' | 'chef'; businessId: string | null },
  cost: number,
  now: Date,
  cookieName: string,
): Promise<TestUser> {
  const hash = await hashPassword(TEST_PASSWORD, cost);
  return withSystem(db, async (c) => {
    const r = await c.query<{ id: string }>(
      `insert into users (email, password_hash, role, business_id, created_at) values ($1, $2, $3, $4, $5) returning id`,
      [u.email, hash, u.role, u.businessId, now],
    );
    const id = r.rows[0]!.id;
    const token = await createSession(c, id, now);
    return { user: { id, email: u.email, role: u.role, businessId: u.businessId }, cookie: `${cookieName}=${token}` };
  });
}

/** Der Anbieter `beispiel@example.com` mit Passwort TEST_PASSWORD und einer Sitzung, nach der Uhr der App. */
export function createProvider(app: FastifyInstance, db: Db): Promise<TestUser> {
  const { config, now } = app.deps;
  return insertUser(
    db,
    { email: PROVIDER_EMAIL, role: 'provider', businessId: null },
    config.passwordCost,
    now(),
    sessionCookieName(config.publicUrl),
  );
}

/** Ein Chef dieses Betriebs mit eigener E-Mail, Passwort TEST_PASSWORD und einer Sitzung (Cookie für http). */
export function createChef(db: Db, businessId: string): Promise<TestUser> {
  const email = `chef-${randomBytes(4).toString('hex')}@example.com`;
  return insertUser(
    db,
    { email, role: 'chef', businessId },
    TEST_COST,
    TEST_NOW,
    sessionCookieName('http://localhost'),
  );
}

/** Kopfzeilen für eine angemeldete Anfrage, die auch am Schutz für ändernde Anfragen vorbeikommt. */
export function authed(cookie: string): Record<string, string> {
  return { cookie, 'x-kassa-request': '1' };
}

/** Ein Betrieb für Tests, ohne Speisekarte. */
export function createBusiness(db: Db, name = 'Beispiel-Imbiss'): Promise<string> {
  return withSystem(db, async (c) => {
    const r = await c.query<{ id: string }>(
      `insert into businesses (name, change_seq) values ($1, nextval('change_seq')) returning id`,
      [name],
    );
    return r.rows[0]!.id;
  });
}
