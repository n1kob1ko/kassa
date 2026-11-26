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

test('0002 läuft auf einer Datenbank mit Stand 0001 und lässt vorhandene Artikel stehen', async () => {
  const suffix = randomBytes(6).toString('hex');
  const database = `kassa_test_alt_${suffix}`;
  await owner(`create database ${database}`);
  try {
    const url = withDatabase(t.ownerUrl, database);
    const c = new pg.Client({ connectionString: url });
    await c.connect();
    try {
      await c.query('create table schema_migrations (name text primary key, applied_at timestamptz not null default now())');
      // Stand 0001: nur 0000 und 0001 anwenden, dann einen Artikel anlegen.
      const { readFile } = await import('node:fs/promises');
      for (const name of ['0000_roles.sql', '0001_init.sql']) {
        const sql = await readFile(new URL(`../migrations/${name}`, import.meta.url), 'utf8');
        await c.query(sql);
        await c.query('insert into schema_migrations (name) values ($1)', [name]);
      }
      const b = await c.query<{ id: string }>(
        `insert into businesses (name, change_seq) values ('Alt', nextval('change_seq')) returning id`,
      );
      const biz = b.rows[0]!.id;
      await c.query(`insert into categories (business_id, id, name, position, change_seq) values ($1, 'k', 'K', 0, 1)`, [biz]);
      await c.query(
        `insert into items (business_id, id, name, price_cents, category_id, tax_percent, position, change_seq)
         values ($1, 'huhn-bowl', 'Huhn Bowl', 990, 'k', 10, 0, 1)`,
        [biz],
      );
      const applied = await migrate(url, { appPassword: TEST_APP_PASSWORD });
      expect(applied).toEqual(['0002_sync.sql', '0003_translations.sql']);
      const item = await c.query('select name, price_cents, photo_file_id from items where id = $1', ['huhn-bowl']);
      expect(item.rows).toEqual([{ name: 'Huhn Bowl', price_cents: 990, photo_file_id: null }]);
      const biz2 = await c.query('select time_zone from businesses where id = $1', [biz]);
      expect(biz2.rows[0]!.time_zone).toBe('Europe/Vienna');
    } finally {
      await c.end();
    }
  } finally {
    await owner(`drop database if exists ${database} with (force)`);
  }
});
