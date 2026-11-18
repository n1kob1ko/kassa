import type pg from 'pg';
import { sha256 } from './secrets.js';

const WINDOW_MS = 24 * 3600 * 1000;
const FREE_ATTEMPTS = 4;
const MAX_WAIT_MINUTES = 15;

/** Fehlversuche zählen pro E-Mail ohne Rücksicht auf Groß- und Kleinschreibung. Gespeichert wird nur ihr SHA-256. */
function emailHash(email: string): Buffer {
  return sha256(email.trim().toLowerCase());
}

/**
 * Sekunden bis zum nächsten erlaubten Versuch, 0 heißt erlaubt.
 * Gezählt werden die Fehlversuche der letzten 24 Stunden. Ab dem 5. gilt ab dem letzten
 * eine Wartezeit von 1, 2, 4, 8, dann immer 15 Minuten.
 */
export async function loginWait(c: pg.ClientBase, email: string, now: Date): Promise<number> {
  const r = await c.query<{ n: number; last: Date | null }>(
    `select count(*)::int as n, max(at) as last from login_failures where email_hash = $1 and at > $2 and at <= $3`,
    [emailHash(email), new Date(now.getTime() - WINDOW_MS), now],
  );
  const { n, last } = r.rows[0]!;
  if (n <= FREE_ATTEMPTS || last === null) return 0;
  const minutes = Math.min(2 ** (n - FREE_ATTEMPTS - 1), MAX_WAIT_MINUTES);
  const remainingMs = last.getTime() + minutes * 60 * 1000 - now.getTime();
  return remainingMs > 0 ? Math.ceil(remainingMs / 1000) : 0;
}

export async function recordLoginFailure(c: pg.ClientBase, email: string, now: Date): Promise<void> {
  await c.query('insert into login_failures (email_hash, at) values ($1, $2)', [emailHash(email), now]);
}

export async function clearLoginFailures(c: pg.ClientBase, email: string): Promise<void> {
  await c.query('delete from login_failures where email_hash = $1', [emailHash(email)]);
}
