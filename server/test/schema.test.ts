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
