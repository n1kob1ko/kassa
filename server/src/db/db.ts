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

/** Entfernt Zugangsdaten aus einer Meldung: `postgres://name:passwort@` wird zu `postgres://…@`, Passwörter zu `…`. */
function withoutSecrets(message: string, secrets: string[]): string {
  let out = message.replace(/([a-z][a-z0-9+.-]*:\/\/)[^\s/@]*@/gi, '$1…@');
  for (const secret of secrets) {
    if (secret !== '') out = out.split(secret).join('…');
  }
  return out;
}

export function openDb(
  config: Pick<Config, 'databaseUrl' | 'appDbPassword'>,
  opts: { onError?: (message: string) => void } = {},
): Db {
  const pool = new pg.Pool({ connectionString: appUrl(config), max: 10 });
  let ownerPassword = '';
  try {
    ownerPassword = decodeURIComponent(new URL(config.databaseUrl).password);
  } catch {
    ownerPassword = '';
  }
  pool.on('error', (err) => {
    // Eine abgebrochene Leerlauf-Verbindung darf den Dienst nicht beenden. Sie soll aber sichtbar sein.
    opts.onError?.(withoutSecrets(err.message, [config.appDbPassword, ownerPassword]));
  });
  return { pool };
}

export async function closeDb(db: Db): Promise<void> {
  await db.pool.end();
}
