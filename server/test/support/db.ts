import { randomBytes } from 'node:crypto';
import pg from 'pg';
import { closeDb, openDb, type Db } from '../../src/db/db.js';
import { migrate } from '../../src/db/migrate.js';

export const TEST_DB_URL = process.env.KASSA_TEST_DB_URL ?? 'postgres://kassa@127.0.0.1:54329/postgres';
export const TEST_APP_PASSWORD = 'test-app-passwort';

export function withDatabase(url: string, name: string): string {
  const u = new URL(url);
  u.pathname = `/${name}`;
  return u.toString();
}

async function admin<T>(fn: (c: pg.Client) => Promise<T>): Promise<T> {
  const c = new pg.Client({ connectionString: TEST_DB_URL });
  await c.connect();
  try {
    return await fn(c);
  } finally {
    await c.end();
  }
}

/**
 * Legt für eine Testdatei eine eigene Datenbank an.
 * `migrated: true` kopiert die Vorlage (von global_setup.ts migriert), `false` gibt eine leere Datenbank.
 */
export async function createTestDb(
  opts: { migrated?: boolean } = {},
): Promise<{ db: Db; ownerUrl: string; drop(): Promise<void> }> {
  const name = `kassa_test_${randomBytes(6).toString('hex')}`;
  const migrated = opts.migrated ?? true;
  await admin((c) => c.query(migrated ? `create database ${name} template kassa_template` : `create database ${name}`));
  const ownerUrl = withDatabase(TEST_DB_URL, name);
  if (!migrated) {
    // Die Rolle kassa_app gibt es durch die Vorlage schon im Cluster. Ohne Migration gibt es nur eine leere Datenbank.
    const db = { pool: new pg.Pool({ connectionString: ownerUrl, max: 1 }) };
    return { db, ownerUrl, drop: dropper(name, db) };
  }
  const db = openDb({ databaseUrl: ownerUrl, appDbPassword: TEST_APP_PASSWORD });
  return { db, ownerUrl, drop: dropper(name, db) };
}

function dropper(name: string, db: Db): () => Promise<void> {
  return async () => {
    await closeDb(db);
    await admin((c) => c.query(`drop database if exists ${name} with (force)`));
  };
}

export { migrate };
