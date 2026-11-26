import { afterAll, beforeAll, expect, test } from 'vitest';
import { randomBytes } from 'node:crypto';
import pg from 'pg';
import { migrate, restrictAppRole } from '../src/db/migrate.js';
import { readdir, readFile } from 'node:fs/promises';
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

const MIGRATIONS = new URL('../migrations/', import.meta.url);

/** Wendet die noch fehlenden Migrationen bis einschließlich [last] an, wie migrate es tut. Gibt ihre Namen zurück. */
async function migrateTo(c: pg.Client, last: string): Promise<string[]> {
  await c.query('create table if not exists schema_migrations (name text primary key, applied_at timestamptz not null default now())');
  const done = new Set((await c.query<{ name: string }>('select name from schema_migrations')).rows.map((r) => r.name));
  const names = (await readdir(MIGRATIONS)).filter((n) => n.endsWith('.sql') && n <= last && !done.has(n)).sort();
  for (const name of names) {
    await c.query('begin');
    await c.query(await readFile(new URL(name, MIGRATIONS), 'utf8'));
    await c.query('insert into schema_migrations (name) values ($1)', [name]);
    await c.query('commit');
  }
  return names;
}

/** Eine leere Datenbank nur für einen Test, mit einer Verbindung als Besitzer. */
async function withFreshDb(run: (c: pg.Client) => Promise<void>): Promise<void> {
  const database = `kassa_test_mig_${randomBytes(6).toString('hex')}`;
  await owner(`create database ${database}`);
  try {
    const c = new pg.Client({ connectionString: withDatabase(t.ownerUrl, database) });
    await c.connect();
    try {
      await run(c);
    } finally {
      await c.end();
    }
  } finally {
    await owner(`drop database if exists ${database} with (force)`);
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
      expect(applied).toEqual(['0002_sync.sql', '0003_translations.sql', '0004_payments.sql']);
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

test('0004 füllt alte Bons aus payment_kind und total_cents, danach ist receipts wieder unveränderlich', async () => {
  await withFreshDb(async (c) => {
    // Stand 0003 herstellen, drei Bons direkt einfügen: bar 990, Karte 1250, Sonderbeleg 0 ohne Zahlung.
    await migrateTo(c, '0003_translations.sql');
    const b = await c.query<{ id: string }>(`insert into businesses (name, change_seq) values ('Alt', nextval('change_seq')) returning id`);
    const biz = b.rows[0]!.id;
    const receipt = (number: number, kind: string, total: number, paymentKind: string | null) =>
      c.query(
        `insert into receipts (business_id, id, register_id, device_id, number, created_at, kind, staff_id, staff_name,
                               goods_cents, deposit_cents, total_cents, payment_kind, is_test, content_hash, payload)
         values ($1, gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), $2, now(), $3, 's', 'S', $4, 0, $4, $5, true, '\\x00', '{}')`,
        [biz, number, kind, total, paymentKind],
      );
    await receipt(1, 'sale', 990, 'cash');
    await receipt(2, 'sale', 1250, 'card');
    await receipt(3, 'zero', 0, null);

    expect(await migrateTo(c, '0004_payments.sql')).toEqual(['0004_payments.sql']);
    expect((await c.query('select number, cash_cents, card_cents, tip_cents, discount_cents from receipts order by number')).rows).toEqual([
      { number: 1, cash_cents: 990, card_cents: 0, tip_cents: 0, discount_cents: 0 },
      { number: 2, cash_cents: 0, card_cents: 1250, tip_cents: 0, discount_cents: 0 },
      { number: 3, cash_cents: 0, card_cents: 0, tip_cents: 0, discount_cents: 0 },
    ]);
    await expect(c.query('update receipts set cash_cents = 1')).rejects.toThrow(/unveränderlich/);
    await expect(c.query('delete from receipts')).rejects.toThrow(/unveränderlich/);
  });
});

test('0004 läuft auf einer leeren Datenbank mit Stand 0003, die neuen Spalten haben ihre Vorgaben', async () => {
  await withFreshDb(async (c) => {
    await migrateTo(c, '0003_translations.sql');
    expect(await migrateTo(c, '0004_payments.sql')).toEqual(['0004_payments.sql']);
    const cols = await c.query(
      `select table_name, column_name, data_type, is_nullable, column_default from information_schema.columns
        where table_name in ('receipts', 'receipt_lines')
          and column_name in ('cash_cents', 'card_cents', 'tip_cents', 'discount_cents', 'discount')
        order by table_name, column_name`,
    );
    expect(cols.rows).toEqual([
      { table_name: 'receipt_lines', column_name: 'discount', data_type: 'jsonb', is_nullable: 'YES', column_default: null },
      { table_name: 'receipt_lines', column_name: 'discount_cents', data_type: 'integer', is_nullable: 'NO', column_default: '0' },
      { table_name: 'receipts', column_name: 'card_cents', data_type: 'integer', is_nullable: 'NO', column_default: '0' },
      { table_name: 'receipts', column_name: 'cash_cents', data_type: 'integer', is_nullable: 'NO', column_default: '0' },
      { table_name: 'receipts', column_name: 'discount_cents', data_type: 'integer', is_nullable: 'NO', column_default: '0' },
      { table_name: 'receipts', column_name: 'tip_cents', data_type: 'integer', is_nullable: 'NO', column_default: '0' },
    ]);
  });
});
