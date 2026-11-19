import { afterAll, beforeAll, expect, test } from 'vitest';
import pg from 'pg';
import { withBusiness, withSystem } from '../src/db/tenant.js';
import { createTestDb } from './support/db.js';

let t: Awaited<ReturnType<typeof createTestDb>>;
let businessId: string;
const NOW = new Date('2026-11-18T10:00:00Z');
const IN_15_MIN = new Date('2026-11-18T10:15:00Z');

beforeAll(async () => {
  t = await createTestDb();
  businessId = await withSystem(t.db, async (c) => {
    const r = await c.query<{ id: string }>(
      `insert into businesses (name, change_seq) values ('Beispiel-Imbiss', nextval('change_seq')) returning id`,
    );
    return r.rows[0]!.id;
  });
});
afterAll(() => t.drop());

/** Wartet, bis eine Verbindung dieser Datenbank auf eine gesperrte Zeile wartet. */
async function waitForLockWaiter(): Promise<void> {
  const c = new pg.Client({ connectionString: t.ownerUrl });
  await c.connect();
  try {
    for (let i = 0; i < 200; i++) {
      const r = await c.query(
        `select 1 from pg_stat_activity where datname = current_database() and wait_event_type = 'Lock'`,
      );
      if (r.rowCount) return;
      await new Promise((resolve) => setTimeout(resolve, 25));
    }
    throw new Error('Niemand wartet auf die Zeile');
  } finally {
    await c.end();
  }
}

async function addPairingCode(hash: string, expiresAt: Date): Promise<Buffer> {
  const code = Buffer.from(hash);
  await withBusiness(t.db, businessId, (c) =>
    c.query(`insert into pairing_codes (code_hash, business_id, register_name, expires_at) values ($1, $2, 'Kassa 1', $3)`, [
      code,
      businessId,
      expiresAt,
    ]),
  );
  return code;
}

test('claim_pairing_code gibt einen Code genau einmal her', async () => {
  const code = await addPairingCode('code-einmal', IN_15_MIN);
  const first = await t.db.pool.connect();
  const second = await t.db.pool.connect();
  try {
    await first.query('begin');
    const won = await first.query('select * from claim_pairing_code($1, $2)', [code, NOW]);
    // Der zweite Aufruf läuft gleichzeitig und muss warten, bis der erste fertig ist.
    const racing = second.query('select * from claim_pairing_code($1, $2)', [code, NOW]);
    await waitForLockWaiter();
    await first.query('commit');
    const lost = await racing;
    expect(won.rows).toEqual([{ business_id: businessId, register_name: 'Kassa 1' }]);
    expect(lost.rowCount).toBe(0);
  } finally {
    first.release();
    second.release();
  }
  const again = await t.db.pool.query('select * from claim_pairing_code($1, $2)', [code, NOW]);
  expect(again.rowCount).toBe(0);
  const row = await withBusiness(t.db, businessId, (c) =>
    c.query<{ used_at: Date }>('select used_at from pairing_codes where code_hash = $1', [code]),
  );
  expect(row.rows[0]!.used_at.toISOString()).toBe(NOW.toISOString());
});

test('claim_pairing_code gibt abgelaufene Codes nicht her', async () => {
  const code = await addPairingCode('code-abgelaufen', NOW);
  const atExpiry = await t.db.pool.query('select * from claim_pairing_code($1, $2)', [code, NOW]);
  expect(atExpiry.rowCount).toBe(0);
  const justBefore = await t.db.pool.query('select * from claim_pairing_code($1, $2)', [
    code,
    new Date(NOW.getTime() - 1000),
  ]);
  expect(justBefore.rowCount).toBe(1);
  const unknown = await t.db.pool.query('select * from claim_pairing_code($1, $2)', [Buffer.from('gibt-es-nicht'), NOW]);
  expect(unknown.rowCount).toBe(0);
});

test('find_register_by_token findet die Kassa ohne gesetzten Betrieb', async () => {
  const token = Buffer.from('token-kassa');
  const registerId = await withBusiness(t.db, businessId, async (c) => {
    const r = await c.query<{ id: string }>(
      `insert into registers (business_id, name, token_hash) values ($1, 'Kassa 1', $2) returning id`,
      [businessId, token],
    );
    return r.rows[0]!.id;
  });
  const found = await t.db.pool.query('select * from find_register_by_token($1)', [token]);
  expect(found.rows).toEqual([{ id: registerId, business_id: businessId, name: 'Kassa 1', blocked_at: null }]);
  const missing = await t.db.pool.query('select * from find_register_by_token($1)', [Buffer.from('falsch')]);
  expect(missing.rowCount).toBe(0);
});

test('ein Chef ohne Betrieb und ein Anbieter mit Betrieb sind verboten', async () => {
  const insert = (email: string, role: string, business: string | null) =>
    withSystem(t.db, (c) =>
      c.query(`insert into users (email, password_hash, role, business_id) values ($1, 'x', $2, $3)`, [email, role, business]),
    );
  await expect(insert('chef-ohne@example.com', 'chef', null)).rejects.toThrow(/check constraint/);
  await expect(insert('anbieter-mit@example.com', 'provider', businessId)).rejects.toThrow(/check constraint/);
  await expect(insert('kellner@example.com', 'staff', businessId)).rejects.toThrow(/check constraint/);
  await insert('chef@example.com', 'chef', businessId);
  await insert('anbieter@example.com', 'provider', null);
});

test('E-Mail ist ohne Groß-/Kleinschreibung eindeutig', async () => {
  const insert = (email: string) =>
    withSystem(t.db, (c) => c.query(`insert into users (email, password_hash, role) values ($1, 'x', 'provider')`, [email]));
  await insert('beispiel@example.com');
  await expect(insert('Beispiel@Example.COM')).rejects.toThrow(/duplicate key/);
});

// Stufe 2: Tabellen für den Abgleich

const SYNC_ID = '11111111-1111-4111-8111-111111111111';
const SYNC_DEVICE = '22222222-2222-4222-8222-222222222222';

/** Je Tabelle mit Betrieb eine gültige Zeile; $1 ist der Betrieb. */
const SYNC_ROWS: Record<string, string> = {
  business_days: `insert into business_days (business_id, id, register_id, device_id, opened_at, opening_float_cents, content_hash)
    values ($1, '${SYNC_ID}', '${SYNC_ID}', '${SYNC_DEVICE}', now(), 10000, '\\x01')`,
  cash_movements: `insert into cash_movements (business_id, id, register_id, business_day_id, kind, amount_cents, reason, created_at, staff_id, staff_name, content_hash)
    values ($1, '${SYNC_ID}', '${SYNC_ID}', '${SYNC_ID}', 'deposit', 500, 'Wechselgeld', now(), 's1', 'Chefin', '\\x01')`,
  receipts: `insert into receipts (business_id, id, register_id, device_id, number, created_at, kind, staff_id, staff_name, goods_cents, deposit_cents, total_cents, is_test, content_hash, payload)
    values ($1, '${SYNC_ID}', '${SYNC_ID}', '${SYNC_DEVICE}', 1, now(), 'sale', 's1', 'Chefin', 990, 0, 990, true, '\\x01', '{}')`,
  receipt_lines: `insert into receipt_lines (business_id, receipt_id, position, item_id, name, unit_price_cents, quantity, unit_deposit_cents, gross20_cents, gross10_cents, gross13_cents, gross0_cents, gross19_cents)
    values ($1, '${SYNC_ID}', 0, 'huhn-bowl', 'Huhn Bowl', 990, 1, 0, 0, 990, 0, 0, 0)`,
  rksv_certificates: `insert into rksv_certificates (business_id, device_id, serial_hex, certificate, issuers, register_id, content_hash)
    values ($1, '${SYNC_DEVICE}', '1a2b', '\\x01', '[]', '${SYNC_ID}', '\\x01')`,
  rksv_chains: `insert into rksv_chains (business_id, device_id, chain, mode, cash_box_id, zda_id, cert_serial, started_at, register_id, content_hash)
    values ($1, '${SYNC_DEVICE}', 1, 'probe', 'KASSA1', 'AT0', '1a2b', now(), '${SYNC_ID}', '\\x01')`,
  rksv_entries: `insert into rksv_entries (business_id, device_id, chain, position, receipt_id, jws, damaged, cert_serial, register_id)
    values ($1, '${SYNC_DEVICE}', 1, 1, '${SYNC_ID}', 'a.b.c', false, '1a2b', '${SYNC_ID}')`,
  reports: `insert into reports (business_id, id, register_id, source, kind, at, content)
    values ($1, '${SYNC_ID}', '${SYNC_ID}', 'device', 'error', now(), '{}')`,
  files: `insert into files (business_id, id, kind, storage_key) values ($1, '${SYNC_ID}', 'item_photo', 'k/1')`,
};

/** Der Besitzer umgeht die Sperre, nicht aber die Trigger. */
async function asOwner<T>(fn: (c: pg.Client) => Promise<T>): Promise<T> {
  const c = new pg.Client({ connectionString: t.ownerUrl });
  await c.connect();
  try {
    return await fn(c);
  } finally {
    await c.end();
  }
}

async function newBusiness(name: string): Promise<string> {
  return withSystem(t.db, async (c) => {
    const r = await c.query<{ id: string }>(
      `insert into businesses (name, change_seq) values ($1, nextval('change_seq')) returning id`,
      [name],
    );
    return r.rows[0]!.id;
  });
}

/** Eine Zeile einfügen; Bon-Zeilen brauchen zuerst ihren Bon. */
async function insertSample(c: pg.PoolClient, table: string, biz: string): Promise<void> {
  if (table === 'receipt_lines') await c.query(SYNC_ROWS.receipts!, [biz]);
  await c.query(SYNC_ROWS[table]!, [biz]);
}

for (const table of Object.keys(SYNC_ROWS)) {
  test(`${table}: nur der eigene Betrieb sieht und schreibt Zeilen`, async () => {
    const a = await newBusiness(`A ${table}`);
    const b = await newBusiness(`B ${table}`);
    await withBusiness(t.db, a, (c) => insertSample(c, table, a));
    const own = await withBusiness(t.db, a, (c) => c.query(`select 1 from ${table}`));
    expect(own.rowCount).toBe(1);
    const noBusiness = await withSystem(t.db, (c) => c.query(`select 1 from ${table}`));
    expect(noBusiness.rowCount).toBe(0);
    const foreign = await withBusiness(t.db, b, (c) => c.query(`select 1 from ${table}`));
    expect(foreign.rowCount).toBe(0);
    await expect(withBusiness(t.db, b, (c) => insertSample(c, table, a))).rejects.toThrow(/row-level security/);
  });
}

const IMMUTABLE: Record<string, string> = {
  receipts: 'total_cents = 1',
  receipt_lines: `name = 'x'`,
  cash_movements: 'amount_cents = 1',
  reports: 'count = 2',
  rksv_entries: `jws = 'x'`,
  rksv_certificates: `serial_hex = 'ff'`,
};

for (const [table, set] of Object.entries(IMMUTABLE)) {
  test(`${table}: update und delete scheitern, auch als Besitzer`, async () => {
    const biz = await newBusiness(`Fest ${table}`);
    await withBusiness(t.db, biz, (c) => insertSample(c, table, biz));
    for (const sql of [`update ${table} set ${set}`, `delete from ${table}`]) {
      // Der Dienst hat dafür gar kein Recht, der Besitzer scheitert am Trigger.
      await expect(withBusiness(t.db, biz, (c) => c.query(sql))).rejects.toThrow(/permission denied/);
      await expect(asOwner((c) => c.query(sql))).rejects.toThrow(/unveränderlich/);
    }
    const left = await withBusiness(t.db, biz, (c) => c.query(`select 1 from ${table}`));
    expect(left.rowCount).toBe(1);
  });
}

const CLOSABLE: Array<{ table: string; closed: string; open: string }> = [
  { table: 'business_days', closed: `closed_at = now(), counted_cents = 10500`, open: 'left_in_drawer_cents = 9000' },
  { table: 'rksv_chains', closed: `ended_at = now()`, open: `cash_box_id = 'KASSA2'` },
];

for (const { table, closed, open } of CLOSABLE) {
  test(`${table}: ändern nur, solange er offen ist, löschen nie`, async () => {
    const biz = await newBusiness(`Offen ${table}`);
    await withBusiness(t.db, biz, (c) => insertSample(c, table, biz));
    await withBusiness(t.db, biz, (c) => c.query(`update ${table} set ${open}`));
    await withBusiness(t.db, biz, (c) => c.query(`update ${table} set ${closed}`));
    for (const sql of [`update ${table} set ${open}`, `update ${table} set ${closed}`]) {
      await expect(withBusiness(t.db, biz, (c) => c.query(sql))).rejects.toThrow(/unveränderlich/);
      await expect(asOwner((c) => c.query(sql))).rejects.toThrow(/unveränderlich/);
    }
  });

  test(`${table}: löschen scheitert auch solange er offen ist (als Besitzer)`, async () => {
    const biz = await newBusiness(`Offen2 ${table}`);
    await withBusiness(t.db, biz, (c) => insertSample(c, table, biz));
    await expect(asOwner((c) => c.query(`delete from ${table}`))).rejects.toThrow(/unveränderlich/);
  });
}

test('files: eine Datei darf gelöscht werden', async () => {
  const biz = await newBusiness('Dateien');
  await withBusiness(t.db, biz, (c) => c.query(SYNC_ROWS.files!, [biz]));
  const r = await withBusiness(t.db, biz, (c) => c.query('delete from files'));
  expect(r.rowCount).toBe(1);
});

test('list_reports liefert Berichte aller Betriebe, ein direktes select keinen', async () => {
  const a = await newBusiness('Imbiss Eins');
  const b = await newBusiness('Imbiss Zwei');
  const regA = await withBusiness(t.db, a, async (c) => {
    const r = await c.query<{ id: string }>(
      `insert into registers (business_id, name, token_hash) values ($1, 'Kassa A', 'tok-a') returning id`,
      [a],
    );
    return r.rows[0]!.id;
  });
  const regB = await withBusiness(t.db, b, async (c) => {
    const r = await c.query<{ id: string }>(
      `insert into registers (business_id, name, token_hash) values ($1, 'Kassa B', 'tok-b') returning id`,
      [b],
    );
    return r.rows[0]!.id;
  });
  const add = (biz: string, reg: string, id: string, receivedAt: string) =>
    withBusiness(t.db, biz, (c) =>
      c.query(
        `insert into reports (business_id, id, register_id, source, kind, at, content, received_at)
         values ($1, $2, $3, 'device', 'error', $4, '{}', $4)`,
        [biz, id, reg, receivedAt],
      ),
    );
  await add(a, regA, '00000000-0000-4000-8000-0000000000a1', '2026-11-19T08:00:00Z');
  await add(b, regB, '00000000-0000-4000-8000-0000000000b1', '2026-11-19T09:00:00Z');
  await add(a, regA, '00000000-0000-4000-8000-0000000000a2', '2026-11-19T10:00:00Z');

  const direct = await t.db.pool.query('select 1 from reports');
  expect(direct.rowCount).toBe(0);

  const all = await t.db.pool.query(`select * from list_reports(10, null)`);
  const mine = all.rows.filter((r) => [a, b].includes(r.business_id));
  expect(mine.map((r) => [r.business_name, r.register_name])).toEqual([
    ['Imbiss Eins', 'Kassa A'],
    ['Imbiss Zwei', 'Kassa B'],
    ['Imbiss Eins', 'Kassa A'],
  ]);

  const older = await t.db.pool.query(`select * from list_reports(10, $1)`, ['2026-11-19T10:00:00Z']);
  expect(older.rows.filter((r) => [a, b].includes(r.business_id))).toHaveLength(2);
  const limited = await t.db.pool.query(`select * from list_reports(1, null)`);
  expect(limited.rowCount).toBe(1);
});

test('backups ist ohne Betrieb schreib- und lesbar, aber nicht löschbar', async () => {
  await withSystem(t.db, (c) =>
    c.query(`insert into backups (day, ok, started_at) values ('2026-11-19', true, now())`),
  );
  const r = await withSystem(t.db, (c) => c.query(`update backups set ok = false where day = '2026-11-19'`));
  expect(r.rowCount).toBeGreaterThan(0);
  await expect(withSystem(t.db, (c) => c.query('delete from backups'))).rejects.toThrow(/permission denied/);
});
