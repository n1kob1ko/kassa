import type { FastifyRequest } from 'fastify';
import { sha256 } from '../auth/secrets.js';
import { withBusiness, withSystem } from '../db/tenant.js';
import { ApiError } from '../errors.js';

export type Register = { id: string; businessId: string; name: string };

/** Ein Geräte-Schlüssel ist base64url aus 32 Bytes (randomToken). */
const BEARER = /^Bearer ([A-Za-z0-9_-]{43})$/;
const MAX_APP_VERSION = 40;
const SEEN_INTERVAL_MS = 60 * 1000;

const unauthorized = () =>
  new ApiError(401, 'unauthorized', 'Diese Kassa ist nicht gekoppelt. Bitte kopple sie in den Einstellungen neu.');

/** Die App-Version aus der Kopfzeile, sonst null. Zu lange oder mehrfache Angaben zählen nicht. */
function appVersion(req: FastifyRequest): string | null {
  const v = req.headers['x-kassa-app-version'];
  if (typeof v !== 'string') return null;
  const trimmed = v.trim();
  return trimmed.length > 0 && trimmed.length <= MAX_APP_VERSION ? trimmed : null;
}

/**
 * Die Kassa zum Geräte-Schlüssel aus `Authorization: Bearer <token>`. Die Sitzung der Verwaltung gilt hier nie.
 * Fehlt der Schlüssel oder ist er unbekannt: 401 `unauthorized`. Gesperrt: 403 `register_blocked`.
 * Der Schlüssel und sein Prüfwert kommen in keinen Fehler, kein Protokoll und keinen Verlauf.
 */
export async function requireRegister(req: FastifyRequest): Promise<Register> {
  const { db, now } = req.server.deps;
  const header = req.headers.authorization;
  const match = typeof header === 'string' ? BEARER.exec(header) : null;
  if (!match) throw unauthorized();

  const found = (
    await withSystem(db, (c) =>
      c.query<{ id: string; business_id: string; name: string; blocked_at: Date | null }>(
        'select id, business_id, name, blocked_at from find_register_by_token($1)',
        [sha256(match[1]!)],
      ),
    )
  ).rows[0];
  if (!found) throw unauthorized();
  if (found.blocked_at !== null) {
    throw new ApiError(403, 'register_blocked', 'Diese Kassa wurde in der Verwaltung gesperrt.');
  }

  // Höchstens einmal pro Minute schreiben, außer die App-Version hat sich geändert.
  const at = now();
  const version = appVersion(req);
  await withBusiness(db, found.business_id, (c) =>
    c.query(
      `update registers set last_seen_at = $2, app_version = coalesce($3, app_version)
        where id = $1
          and (last_seen_at is null or last_seen_at <= $4 or ($3::text is not null and app_version is distinct from $3))`,
      [found.id, at, version, new Date(at.getTime() - SEEN_INTERVAL_MS)],
    ),
  );
  return { id: found.id, businessId: found.business_id, name: found.name };
}
