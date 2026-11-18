import type pg from 'pg';
import type { Db } from '../db/db.js';
import { withSystem } from '../db/tenant.js';

/** Fehlversuche zählen 24 Stunden (login_throttle.ts). Ältere Zeilen braucht niemand mehr. */
const LOGIN_FAILURE_KEEP_MS = 24 * 3600 * 1000;
export const PRUNE_INTERVAL_MS = 3600 * 1000;

/** Löscht Fehlversuche älter als 24 Stunden und abgelaufene Sitzungen. Gibt zurück, wie viele Zeilen es waren. */
export async function pruneAuthRows(c: pg.ClientBase, now: Date): Promise<{ loginFailures: number; sessions: number }> {
  const failures = await c.query('delete from login_failures where at <= $1', [
    new Date(now.getTime() - LOGIN_FAILURE_KEEP_MS),
  ]);
  const sessions = await c.query('delete from sessions where expires_at <= $1', [now]);
  return { loginFailures: failures.rowCount ?? 0, sessions: sessions.rowCount ?? 0 };
}

/**
 * Räumt einmal pro Stunde auf, das erste Mal gleich beim Start. Gibt eine Funktion zurück, die den Zeitgeber anhält.
 * Ein Fehler beim Aufräumen geht an `onError` und hält den Dienst nicht an.
 */
export function startPruning(db: Db, now: () => Date, onError: (err: unknown) => void): () => void {
  const run = () => {
    withSystem(db, (c) => pruneAuthRows(c, now())).catch(onError);
  };
  run();
  const timer = setInterval(run, PRUNE_INTERVAL_MS);
  timer.unref();
  return () => clearInterval(timer);
}
