import { afterAll, beforeAll, expect, test } from 'vitest';
import pg from 'pg';
import { migrate } from '../src/db/migrate.js';
import { createTestDb, TEST_APP_PASSWORD } from './support/db.js';

let t: Awaited<ReturnType<typeof createTestDb>>;
beforeAll(async () => {
  t = await createTestDb({ migrated: false });
});
afterAll(() => t.drop());

async function owner(sql: string, params: unknown[] = []): Promise<pg.QueryResult> {
  const c = new pg.Client({ connectionString: t.ownerUrl });
  await c.connect();
  try {
    return await c.query(sql, params);
  } finally {
    await c.end();
  }
}

test('der erste Lauf wendet 0000_roles.sql an, der zweite nichts mehr', async () => {
  const first = await migrate(t.ownerUrl, { appPassword: TEST_APP_PASSWORD });
  expect(first).toContain('0000_roles.sql');
  const second = await migrate(t.ownerUrl, { appPassword: TEST_APP_PASSWORD });
  expect(second).toEqual([]);
  const rows = await owner('select name from schema_migrations order by name');
  expect(rows.rows.map((r) => r.name)).toEqual(first);
});

test('kassa_app ist weder Superuser noch BYPASSRLS, kann sich aber anmelden', async () => {
  await migrate(t.ownerUrl, { appPassword: TEST_APP_PASSWORD });
  const r = await owner('select rolsuper, rolbypassrls, rolcanlogin from pg_roles where rolname = $1', ['kassa_app']);
  expect(r.rows).toEqual([{ rolsuper: false, rolbypassrls: false, rolcanlogin: true }]);
});

test('ein Passwort mit Anführungszeichen wird gesetzt, ohne dass SQL ausgeführt wird', async () => {
  const evil = `x'; create table eingeschleust(id int); --`;
  await migrate(t.ownerUrl, { appPassword: evil });
  const tables = await owner(`select 1 from pg_tables where tablename = 'eingeschleust'`);
  expect(tables.rowCount).toBe(0);
  await migrate(t.ownerUrl, { appPassword: TEST_APP_PASSWORD });
});
