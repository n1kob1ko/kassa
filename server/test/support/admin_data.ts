import { randomUUID } from 'node:crypto';
import type { TestApp } from './app.js';
import { pairDevice } from './device.js';
import { entry, pushEntries } from './push.js';
import { insertBusiness, createProvider, type TestUser } from './users.js';
import { insertStaff } from './registers.js';
import { withSystem } from '../../src/db/tenant.js';

export type Site = { businessId: string; token: string; deviceId: string; registerId: string };

let seq = 0;

/** Ein Betrieb mit Chef-Mitarbeiter und einer gekoppelten Kassa. Der Anbieter wird einmal pro App angelegt. */
export async function siteFor(a: TestApp, provider: TestUser, name = 'Beispiel-Imbiss'): Promise<Site> {
  const businessId = await insertBusiness(a.db, name);
  await insertStaff(a.db, businessId);
  const { token, registerId } = await pairDevice(a.app, provider.cookie, businessId);
  return { businessId, token, deviceId: randomUUID(), registerId };
}

/** Sendet Einträge so, wie das Tablet es tut: `[['receipt', bon], ['day', tag]]`. */
export async function send(a: TestApp, s: Pick<Site, 'token' | 'deviceId'>, items: [string, object][]): Promise<void> {
  const res = await pushEntries(a.app, s.token, s.deviceId, items.map(([kind, v]) => entry(++seq, kind, v)));
  if (res.status !== 200 || res.results.some((r) => r.status !== 'accepted')) {
    throw new Error(`Senden: ${res.status} ${JSON.stringify(res.results)}`);
  }
}

export async function setTimeZone(a: TestApp, businessId: string, zone: string): Promise<void> {
  await withSystem(a.db, (c) => c.query('update businesses set time_zone = $2 where id = $1', [businessId, zone]));
}

export { createProvider };

/** Alle Schlüssel in einer JSON-Antwort, auch tief verschachtelt. */
export function allKeys(value: unknown, into = new Set<string>()): Set<string> {
  if (Array.isArray(value)) value.forEach((v) => allKeys(v, into));
  else if (typeof value === 'object' && value !== null) {
    for (const [k, v] of Object.entries(value)) {
      into.add(k);
      allKeys(v, into);
    }
  }
  return into;
}

export const FORBIDDEN_KEYS = ['staffId', 'staff_id', 'payload', 'content_hash', 'contentHash', 'jws'];
