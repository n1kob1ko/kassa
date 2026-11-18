import { readFileSync } from 'node:fs';
import type { FastifyInstance } from 'fastify';
import { authed } from './users.js';

/** Der Text einer Beispieldatei aus shared/fixtures/menu/inputs, ohne Endung. */
export function menuFixture(name: string): string {
  return readFileSync(new URL(`../../../shared/fixtures/menu/inputs/${name}.json`, import.meta.url), 'utf8');
}

/** Legt über die Adresse einen Betrieb aus einer Beispieldatei an. Wirft, wenn es nicht 201 gibt. */
export async function createBusiness(
  app: FastifyInstance,
  cookie: string,
  fixtureName = 'beispiel-imbiss',
): Promise<{ id: string; name: string }> {
  const res = await app.inject({
    method: 'POST',
    url: '/api/admin/businesses',
    headers: authed(cookie),
    payload: { menuFile: menuFixture(fixtureName) },
  });
  if (res.statusCode !== 201) throw new Error(`Betrieb anlegen: ${res.statusCode} ${res.body}`);
  return res.json().business;
}
