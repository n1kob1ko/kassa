import type { FastifyRequest } from 'fastify';
import { withSystem } from '../db/tenant.js';
import { ApiError } from '../errors.js';
import type { SessionUser } from './sessions.js';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Ob eine Kennung aus der Adresse wie eine uuid aussieht. Sonst gibt es sie nicht (404), bevor eine Abfrage scheitert. */
export function isUuid(s: string): boolean {
  return UUID.test(s);
}

function notFound(): ApiError {
  return new ApiError(404, 'not_found', 'Das gibt es nicht.');
}

/** Der angemeldete Benutzer, sonst 401 `unauthorized`. */
export function requireUser(req: FastifyRequest): SessionUser {
  if (!req.user) throw new ApiError(401, 'unauthorized', 'Bitte melde dich an.');
  return req.user;
}

/** Nur der Anbieter. Jeder andere Angemeldete bekommt 404, damit er nicht erfährt, dass es die Adresse gibt. */
export function requireProvider(req: FastifyRequest): SessionUser {
  const user = requireUser(req);
  if (user.role !== 'provider') throw notFound();
  return user;
}

/** Der Anbieter für jeden bestehenden Betrieb, ein Chef nur für seinen eigenen. Sonst 404. */
export async function requireBusinessAccess(req: FastifyRequest, businessId: string): Promise<SessionUser> {
  const user = requireUser(req);
  if (!isUuid(businessId)) throw notFound();
  const id = businessId.toLowerCase();
  if (user.role === 'chef') {
    if (user.businessId !== id) throw notFound();
    return user;
  }
  const r = await withSystem(req.server.deps.db, (c) => c.query('select 1 from businesses where id = $1', [id]));
  if (r.rowCount === 0) throw notFound();
  return user;
}
