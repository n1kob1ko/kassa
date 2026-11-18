import { afterAll, beforeAll, expect, test } from 'vitest';
import { randomBytes } from 'node:crypto';
import pg from 'pg';
import { migrate, restrictAppRole } from '../src/db/migrate.js';
import { createTestDb, TEST_APP_PASSWORD, withDatabase } from './support/db.js';

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

test('ein Besitzer ohne Superuser und ohne BYPASSRLS wird abgelehnt und nichts angewendet', async () => {
  const suffix = randomBytes(6).toString('hex');
  const role = `kassa_owner_${suffix}`;
  const database = `kassa_test_owner_${suffix}`;
  await owner(`create role ${role} login nosuperuser nobypassrls`);
  await owner(`create database ${database} owner ${role}`);
  try {
    const url = new URL(withDatabase(t.ownerUrl, database));
    url.username = role;
    await expect(migrate(url.toString(), { appPassword: TEST_APP_PASSWORD })).rejects.toThrow(
      `Database role "${role}" must be a superuser or have BYPASSRLS`,
    );
    const c = new pg.Client({ connectionString: url.toString() });
    await c.connect();
    try {
      const tables = await c.query(`select 1 from pg_tables where schemaname = 'public'`);
      expect(tables.rowCount).toBe(0);
    } finally {
      await c.end();
    }
  } finally {
    await owner(`drop database if exists ${database} with (force)`);
    await owner(`drop role if exists ${role}`);
  }
});

test('restrictAppRole nimmt kassa_app Superuser und BYPASSRLS wieder weg', async () => {
  // Nur in einer Transaktion, die zurückgerollt wird: kassa_app gilt im ganzen Cluster,
  // und die anderen Testdateien laufen gleichzeitig.
  const c = new pg.Client({ connectionString: t.ownerUrl });
  await c.connect();
  try {
    await c.query('begin');
    await c.query('alter role kassa_app superuser bypassrls');
    await restrictAppRole(c);
    const r = await c.query('select rolsuper, rolbypassrls from pg_roles where rolname = $1', ['kassa_app']);
    expect(r.rows).toEqual([{ rolsuper: false, rolbypassrls: false }]);
  } finally {
    await c.query('rollback');
    await c.end();
  }
});

test('ein Passwort mit Anführungszeichen wird gesetzt, ohne dass SQL ausgeführt wird', async () => {
  const evil = `x'; create table eingeschleust(id int); --`;
  await migrate(t.ownerUrl, { appPassword: evil });
  const tables = await owner(`select 1 from pg_tables where tablename = 'eingeschleust'`);
  expect(tables.rowCount).toBe(0);
  await migrate(t.ownerUrl, { appPassword: TEST_APP_PASSWORD });
});
