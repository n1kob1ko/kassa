import type pg from 'pg';
import { randomToken, sha256 } from './secrets.js';

export type SessionUser = { id: string; email: string; role: 'provider' | 'chef'; businessId: string | null };

/** Eine Sitzung gilt 30 Tage ab der letzten Benutzung. */
export const SESSION_MAX_AGE_SECONDS = 30 * 24 * 3600;
const SESSION_MS = SESSION_MAX_AGE_SECONDS * 1000;
const LAST_SEEN_STEP_MS = 3600 * 1000;

/** Über https mit `__Host-`, damit keine Unteradresse das Cookie setzen kann. */
export function sessionCookieName(publicUrl: string): string {
  return publicUrl.startsWith('https://') ? '__Host-kassa_session' : 'kassa_session';
}

/** Legt eine Sitzung an und gibt den Wert für das Cookie zurück. In der Datenbank steht nur sein SHA-256. */
export async function createSession(c: pg.ClientBase, userId: string, now: Date): Promise<string> {
  const token = randomToken();
  await c.query(
    `insert into sessions (id_hash, user_id, created_at, last_seen_at, expires_at) values ($1, $2, $3, $3, $4)`,
    [sha256(token), userId, now, new Date(now.getTime() + SESSION_MS)],
  );
  return token;
}

/**
 * Der Benutzer zur Sitzung, oder null bei unbekannter oder abgelaufener Sitzung und bei gesperrtem Benutzer.
 * Verlängert die Sitzung auf jetzt plus 30 Tage, last_seen_at wird höchstens einmal pro Stunde geschrieben.
 */
export async function findSessionUser(c: pg.ClientBase, cookieValue: string, now: Date): Promise<SessionUser | null> {
  const r = await c.query<{ id: string; email: string; role: 'provider' | 'chef'; business_id: string | null }>(
    `update sessions s
        set expires_at = $3,
            last_seen_at = case when s.last_seen_at <= $4 then $2 else s.last_seen_at end
       from users u
      where s.id_hash = $1
        and s.expires_at > $2
        and u.id = s.user_id
        and u.disabled_at is null
     returning u.id, u.email, u.role, u.business_id`,
    [sha256(cookieValue), now, new Date(now.getTime() + SESSION_MS), new Date(now.getTime() - LAST_SEEN_STEP_MS)],
  );
  const row = r.rows[0];
  return row ? { id: row.id, email: row.email, role: row.role, businessId: row.business_id } : null;
}

export async function deleteSession(c: pg.ClientBase, cookieValue: string): Promise<void> {
  await c.query('delete from sessions where id_hash = $1', [sha256(cookieValue)]);
}
