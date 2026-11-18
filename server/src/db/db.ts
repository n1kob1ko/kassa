import pg from 'pg';
import type { Config } from '../config.js';

/** Verbindungen der Rolle kassa_app. Nur diese Rolle unterliegt der Sperre pro Betrieb. */
export type Db = { pool: pg.Pool };

export function appUrl(config: Pick<Config, 'databaseUrl' | 'appDbPassword'>): string {
  const url = new URL(config.databaseUrl);
  url.username = 'kassa_app';
  url.password = config.appDbPassword;
  return url.toString();
}

export function openDb(config: Pick<Config, 'databaseUrl' | 'appDbPassword'>): Db {
  const pool = new pg.Pool({ connectionString: appUrl(config), max: 10 });
  pool.on('error', () => {
    // Eine abgebrochene Leerlauf-Verbindung darf den Dienst nicht beenden.
  });
  return { pool };
}

export async function closeDb(db: Db): Promise<void> {
  await db.pool.end();
}
