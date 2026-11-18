import { execFileSync } from 'node:child_process';
import pg from 'pg';
import { migrate } from '../../src/db/migrate.js';
import { TEST_APP_PASSWORD, TEST_DB_URL, withDatabase } from './db.js';

export default async function setup(): Promise<void> {
  execFileSync(new URL('../../tool/test-db.sh', import.meta.url).pathname, ['start'], { stdio: 'inherit' });

  const admin = new pg.Client({ connectionString: TEST_DB_URL });
  await admin.connect();
  try {
    // Reste abgebrochener Läufe wegräumen, dann die Vorlage neu bauen.
    const old = await admin.query<{ datname: string }>(
      `select datname from pg_database where datname = 'kassa_template' or datname like 'kassa_test_%'`,
    );
    for (const { datname } of old.rows) {
      await admin.query(`drop database "${datname}" with (force)`);
    }
    await admin.query('create database kassa_template');
  } finally {
    await admin.end();
  }
  await migrate(withDatabase(TEST_DB_URL, 'kassa_template'), { appPassword: TEST_APP_PASSWORD });
}
