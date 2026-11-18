import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import type { FastifyInstance } from 'fastify';
import { expect } from 'vitest';
import { withBusiness } from '../../src/db/tenant.js';
import type { TestApp } from './app.js';
import { createBusiness, menuFixture } from './businesses.js';
import { authed, createProvider, type TestUser } from './users.js';

const PIN_FIXTURE = JSON.parse(
  readFileSync(new URL('../../../shared/fixtures/pin_hash.json', import.meta.url), 'utf8'),
) as { salt: string; pin: string; hash: string };

const SYNC_DIR = new URL('../../../shared/fixtures/sync/', import.meta.url);

/** Die Anfrage zum Koppeln mit festen Angaben, wie sie in pair_request.json steht (ohne Code). */
export const PAIR_DEVICE = { appVersion: '1.2.0', deviceModel: 'Redmi Pad Pro' } as const;

/** Legt über die Verwaltung einen Kopplungscode an. */
export async function createPairingCode(app: FastifyInstance, cookie: string, businessId: string, name = 'Kassa 1'): Promise<string> {
  const res = await app.inject({
    method: 'POST',
    url: `/api/admin/businesses/${businessId}/pairing-codes`,
    headers: authed(cookie),
    payload: { name },
  });
  if (res.statusCode !== 201) throw new Error(`Kopplungscode anlegen: ${res.statusCode} ${res.body}`);
  return res.json().code;
}

/** Koppelt ein Tablet mit dem Betrieb: Code in der Verwaltung anlegen und einlösen. Wirft, wenn es nicht 200 gibt. */
export async function pairDevice(
  app: FastifyInstance,
  cookie: string,
  businessId: string,
): Promise<{ token: string; registerId: string }> {
  const code = await createPairingCode(app, cookie, businessId);
  const res = await app.inject({
    method: 'POST',
    url: '/api/device/pair',
    payload: { code, previousBusinessId: null, ...PAIR_DEVICE },
  });
  if (res.statusCode !== 200) throw new Error(`Koppeln: ${res.statusCode} ${res.body}`);
  const body = res.json();
  return { token: body.token, registerId: body.registerId };
}

/** Holt mit dem Geräte-Schlüssel. */
export function pull(app: FastifyInstance, token: string, query: string, headers: Record<string, string> = {}) {
  return app.inject({
    method: 'GET',
    url: `/api/device/sync/pull${query}`,
    headers: { authorization: `Bearer ${token}`, ...headers },
  });
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

/** Ersetzt jede uuid durch "<uuid>" und den Geräte-Schlüssel durch "<token>", damit Antworten mit den Beispieldateien vergleichbar sind. */
export function normalize(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(normalize);
  if (typeof value === 'object' && value !== null) {
    return Object.fromEntries(
      Object.entries(value).map(([k, v]) => {
        if (k === 'token' && typeof v === 'string') {
          expect(v).toMatch(/^[A-Za-z0-9_-]{43}$/);
          return [k, '<token>'];
        }
        return [k, normalize(v)];
      }),
    );
  }
  if (typeof value === 'string' && UUID.test(value)) return '<uuid>';
  return value;
}

/** Eine Beispieldatei aus shared/fixtures/sync, ohne Endung. */
export function syncFixture(name: string): unknown {
  return JSON.parse(readFileSync(new URL(`${name}.json`, SYNC_DIR), 'utf8'));
}

/**
 * Vergleicht mit der Beispieldatei. Mit KASSA_WRITE_FIXTURES=1 wird die Datei stattdessen aus der echten Antwort geschrieben.
 */
export function expectSyncFixture(name: string, actual: unknown): void {
  if (process.env.KASSA_WRITE_FIXTURES === '1') {
    mkdirSync(SYNC_DIR, { recursive: true });
    writeFileSync(new URL(`${name}.json`, SYNC_DIR), `${JSON.stringify(actual, null, 2)}\n`);
    return;
  }
  expect(actual).toEqual(syncFixture(name));
}

/** Die Beispiel-Speisekarte mit neuem Preis für "huhn-bowl" und ohne "teigtaschen" (wird stillgelegt). */
export function changedMenu(): string {
  const menu = JSON.parse(menuFixture('beispiel-imbiss'));
  menu.artikel = menu.artikel
    .filter((a: { id: string }) => a.id !== 'teigtaschen')
    .map((a: { id: string }) => (a.id === 'huhn-bowl' ? { ...a, preis_cent: 1090 } : a));
  return JSON.stringify(menu);
}

/** Spielt eine Speisekarten-Datei über die Verwaltung neu ein. */
export async function reimport(app: FastifyInstance, cookie: string, businessId: string, menuFile: string): Promise<void> {
  const res = await app.inject({
    method: 'POST',
    url: `/api/admin/businesses/${businessId}/menu`,
    headers: authed(cookie),
    payload: { menuFile },
  });
  if (res.statusCode !== 200) throw new Error(`Neu einspielen: ${res.statusCode} ${res.body}`);
}

/** Legt einen Mitarbeiter über die Verwaltung an und gibt seine Kennung zurück. */
export async function createStaff(
  app: FastifyInstance,
  cookie: string,
  businessId: string,
  s: { name: string; role: 'chef' | 'staff'; pin: string },
): Promise<string> {
  const res = await app.inject({
    method: 'POST',
    url: `/api/admin/businesses/${businessId}/staff`,
    headers: authed(cookie),
    payload: s,
  });
  if (res.statusCode !== 201) throw new Error(`Mitarbeiter anlegen: ${res.statusCode} ${res.body}`);
  return res.json().staff.id;
}

/**
 * Der Betrieb der Beispieldateien in einer frischen Test-App: "beispiel-imbiss" mit einer Chefin,
 * deren Salz und Prüfwert per SQL auf die Werte aus shared/fixtures/pin_hash.json gesetzt werden.
 * Nur in einer frischen Datenbank aufrufen, sonst stimmen die Änderungs-Nummern nicht mit den Dateien.
 */
export async function fixtureBusiness(a: TestApp): Promise<{ provider: TestUser; businessId: string; staffId: string }> {
  const provider = await createProvider(a.app, a.db);
  const { id: businessId } = await createBusiness(a.app, provider.cookie, 'beispiel-imbiss');
  const staffId = await createStaff(a.app, provider.cookie, businessId, { name: 'Chefin', role: 'chef', pin: PIN_FIXTURE.pin });
  await withBusiness(a.db, businessId, (c) =>
    c.query('update staff set pin_salt = $2, pin_hash = $3 where id = $1', [staffId, PIN_FIXTURE.salt, PIN_FIXTURE.hash]),
  );
  return { provider, businessId, staffId };
}

export { PIN_FIXTURE };
