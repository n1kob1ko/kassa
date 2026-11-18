import { afterAll, beforeAll, expect, test } from 'vitest';
import pg from 'pg';
import { nextChangeSeq, setBusiness, withBusiness, withBusinessWrite, withSystem } from '../src/db/tenant.js';
import { createTestDb } from './support/db.js';

// A und B sind zwei Betriebe, beide mit Kategorie und Artikel "cola" und je einer Zeile in jeder gesperrten Tabelle.
const LOCKED_TABLES = ['registers', 'pairing_codes', 'categories', 'items', 'modifier_templates', 'staff'];

let t: Awaited<ReturnType<typeof createTestDb>>;
let a: string;
let b: string;

async function seedBusiness(name: string, tag: string): Promise<string> {
  const id = await withSystem(t.db, async (c) => {
    const r = await c.query<{ id: string }>(
      `insert into businesses (name, change_seq) values ($1, nextval('change_seq')) returning id`,
      [name],
    );
    return r.rows[0]!.id;
  });
  await withBusinessWrite(t.db, id, async (c) => {
    const seq = await nextChangeSeq(c);
    await c.query(
      `insert into categories (business_id, id, name, position, change_seq) values ($1, 'getraenke', 'Getränke', 0, $2)`,
      [id, seq],
    );
    await c.query(
      `insert into items (business_id, id, name, price_cents, category_id, tax_percent, position, change_seq)
       values ($1, 'cola', 'Cola', 350, 'getraenke', 20, 0, $2)`,
      [id, seq],
    );
    await c.query(
      `insert into modifier_templates (business_id, id, name, groups, change_seq) values ($1, 'bowl', 'bowl', '[]', $2)`,
      [id, seq],
    );
    await c.query(
      `insert into staff (business_id, name, role, pin_salt, pin_hash, change_seq) values ($1, 'Chefin', 'chef', 'aa', 'bb', $2)`,
      [id, seq],
    );
    await c.query(`insert into registers (business_id, name, token_hash) values ($1, 'Kassa 1', $2)`, [
      id,
      Buffer.from(`token-${tag}`),
    ]);
    await c.query(
      `insert into pairing_codes (code_hash, business_id, register_name, expires_at)
       values ($1, $2, 'Kassa 2', now() + interval '15 minutes')`,
      [Buffer.from(`code-${tag}`), id],
    );
  });
  return id;
}

async function owner<T>(fn: (c: pg.Client) => Promise<T>): Promise<T> {
  const c = new pg.Client({ connectionString: t.ownerUrl });
  await c.connect();
  try {
    return await fn(c);
  } finally {
    await c.end();
  }
}

/** Wartet, bis eine Verbindung dieser Datenbank auf eine Advisory-Sperre wartet. */
async function waitForAdvisoryWaiter(): Promise<void> {
  await owner(async (c) => {
    for (let i = 0; i < 200; i++) {
      const r = await c.query(
        `select 1 from pg_stat_activity
          where datname = current_database() and wait_event_type = 'Lock' and wait_event = 'advisory'`,
      );
      if (r.rowCount) return;
      await new Promise((resolve) => setTimeout(resolve, 25));
    }
    throw new Error('Niemand wartet auf die Sperre');
  });
}

function gate(): { promise: Promise<void>; open(): void } {
  let open!: () => void;
  const promise = new Promise<void>((resolve) => {
    open = resolve;
  });
  return { promise, open };
}

beforeAll(async () => {
  t = await createTestDb();
  a = await seedBusiness('Beispiel-Imbiss', 'a');
  b = await seedBusiness('Zweiter Imbiss', 'b');
});
afterAll(() => t.drop());

test('der Pool der Test-Datenbank arbeitet als kassa_app', async () => {
  const r = await t.db.pool.query<{ current_user: string }>('select current_user');
  expect(r.rows[0]!.current_user).toBe('kassa_app');
});

test('ohne Betrieb liefert jede gesperrte Tabelle 0 Zeilen', async () => {
  for (const table of LOCKED_TABLES) {
    const plain = await t.db.pool.query(`select * from ${table}`);
    expect(plain.rowCount, table).toBe(0);
    const system = await withSystem(t.db, (c) => c.query(`select * from ${table}`));
    expect(system.rowCount, table).toBe(0);
  }
  // Als Besitzer sind die Zeilen da: die Sperre filtert, die Tabellen sind nicht leer.
  const total = await owner((c) => c.query('select count(*)::int as n from items'));
  expect(total.rows[0].n).toBe(2);
});

test('withBusiness(A) sieht nur Zeilen von A', async () => {
  for (const table of LOCKED_TABLES) {
    const r = await withBusiness(t.db, a, (c) => c.query<{ business_id: string }>(`select business_id from ${table}`));
    expect(r.rows, table).toEqual([{ business_id: a }]);
  }
  const cola = await withBusiness(t.db, b, (c) => c.query(`select business_id from items where id = 'cola'`));
  expect(cola.rows).toEqual([{ business_id: b }]);
});

test('in withBusiness(A) scheitert ein INSERT mit business_id von B', async () => {
  await expect(
    withBusiness(t.db, a, (c) =>
      c.query(`insert into categories (business_id, id, name, position, change_seq) values ($1, 'fremd', 'Fremd', 1, 1)`, [b]),
    ),
  ).rejects.toThrow(/row-level security/);
  const r = await withBusiness(t.db, b, (c) => c.query(`select id from categories where id = 'fremd'`));
  expect(r.rowCount).toBe(0);
});

test('ohne Betrieb scheitert ein INSERT in eine gesperrte Tabelle', async () => {
  await expect(
    withSystem(t.db, (c) =>
      c.query(`insert into categories (business_id, id, name, position, change_seq) values ($1, 'ohne', 'Ohne', 1, 1)`, [a]),
    ),
  ).rejects.toThrow(/row-level security/);
});

test('kassa_app kann den Verlauf schreiben und lesen, aber nicht ändern oder löschen', async () => {
  await withSystem(t.db, (c) => c.query(`insert into audit_log (action, business_id) values ('test', $1)`, [a]));
  const read = await t.db.pool.query(`select action from audit_log where action = 'test'`);
  expect(read.rowCount).toBe(1);
  await expect(withSystem(t.db, (c) => c.query(`update audit_log set action = 'geändert'`))).rejects.toThrow(
    /permission denied/,
  );
  await expect(withSystem(t.db, (c) => c.query('delete from audit_log'))).rejects.toThrow(/permission denied/);
});

test('in withBusiness(A) ändert ein UPDATE ohne WHERE nur Zeilen von A', async () => {
  const updated = await withBusiness(t.db, a, (c) => c.query('update items set price_cents = 1'));
  expect(updated.rowCount).toBe(1);
  const prices = await owner((c) =>
    c.query<{ business_id: string; price_cents: number }>('select business_id, price_cents from items order by price_cents'),
  );
  expect(prices.rows).toEqual([
    { business_id: a, price_cents: 1 },
    { business_id: b, price_cents: 350 },
  ]);
  await withBusiness(t.db, a, (c) => c.query('update items set price_cents = 350'));
});

test('ein UPDATE kann eine Zeile nicht zu einem anderen Betrieb schieben', async () => {
  await expect(withBusiness(t.db, a, (c) => c.query('update staff set business_id = $1', [b]))).rejects.toThrow(
    /row-level security/,
  );
});

test('kassa_app kann die Sperre nicht abschalten', async () => {
  for (const table of LOCKED_TABLES) {
    await expect(withSystem(t.db, (c) => c.query(`alter table ${table} disable row level security`)), table).rejects.toThrow(
      /must be owner/,
    );
    await expect(withSystem(t.db, (c) => c.query(`alter table ${table} no force row level security`)), table).rejects.toThrow(
      /must be owner/,
    );
  }
  const r = await owner((c) =>
    c.query<{ relname: string; relrowsecurity: boolean; relforcerowsecurity: boolean }>(
      `select relname, relrowsecurity, relforcerowsecurity from pg_class where relname = any($1) order by relname`,
      [LOCKED_TABLES],
    ),
  );
  expect(r.rows).toHaveLength(LOCKED_TABLES.length);
  for (const row of r.rows) {
    expect(row, row.relname).toMatchObject({ relrowsecurity: true, relforcerowsecurity: true });
  }
});

test('ein Fehler in fn rollt die Transaktion zurück', async () => {
  await expect(
    withBusiness(t.db, a, async (c) => {
      await c.query(`insert into categories (business_id, id, name, position, change_seq) values ($1, 'weg', 'Weg', 1, 1)`, [a]);
      throw new Error('abbrechen');
    }),
  ).rejects.toThrow('abbrechen');
  const r = await withBusiness(t.db, a, (c) => c.query(`select id from categories where id = 'weg'`));
  expect(r.rowCount).toBe(0);
});

test('setBusiness gilt auf einer offenen Verbindung bis zum Ende der Transaktion', async () => {
  const c = await t.db.pool.connect();
  try {
    await c.query('begin');
    await setBusiness(c, a);
    const inside = await c.query<{ business_id: string }>('select business_id from categories');
    expect(inside.rows).toEqual([{ business_id: a }]);
    await c.query('commit');
    const after = await c.query('select business_id from categories');
    expect(after.rowCount).toBe(0);
  } finally {
    c.release();
  }
});

test('withBusiness mit repeatableRead liest einen festen Stand', async () => {
  const insertOther = (id: string) =>
    withBusiness(t.db, a, (c) =>
      c.query(`insert into categories (business_id, id, name, position, change_seq) values ($1, $2, $2, 5, 1)`, [a, id]),
    );
  const count = (c: pg.PoolClient) =>
    c.query<{ n: number }>('select count(*)::int as n from categories').then((r) => r.rows[0]!.n);

  const snapshot = await withBusiness(
    t.db,
    a,
    async (c) => {
      const level = await c.query<{ transaction_isolation: string }>('show transaction_isolation');
      const before = await count(c);
      await insertOther('rr-1');
      return { level: level.rows[0]!.transaction_isolation, before, after: await count(c) };
    },
    { repeatableRead: true },
  );
  expect(snapshot.level).toBe('repeatable read');
  expect(snapshot.after).toBe(snapshot.before);

  const plain = await withBusiness(t.db, a, async (c) => {
    const before = await count(c);
    await insertOther('rr-2');
    return { before, after: await count(c) };
  });
  expect(plain.after).toBe(plain.before + 1);

  await withBusiness(t.db, a, (c) => c.query(`delete from categories where id in ('rr-1', 'rr-2')`));
});

test('nextChangeSeq liefert eine Zahl, die bei jedem Aufruf wächst', async () => {
  const [first, second] = await withBusinessWrite(t.db, a, async (c) => [await nextChangeSeq(c), await nextChangeSeq(c)]);
  expect(typeof first).toBe('number');
  expect(second).toBeGreaterThan(first!);
});

test('zwei withBusinessWrite auf denselben Betrieb laufen nacheinander', async () => {
  const events: string[] = [];
  const tx1Holds = gate();
  const tx1Release = gate();

  const tx1 = withBusinessWrite(t.db, a, async (c) => {
    const seq = await nextChangeSeq(c);
    await c.query(
      `insert into categories (business_id, id, name, position, change_seq) values ($1, 'tx1', 'tx1', 9, $2)`,
      [a, seq],
    );
    events.push('tx1 hat Nummer');
    tx1Holds.open();
    await tx1Release.promise;
    events.push('tx1 fertig');
    return seq;
  });
  await tx1Holds.promise;

  const tx2 = withBusinessWrite(t.db, a, async (c) => {
    events.push('tx2 beginnt');
    const seq = await nextChangeSeq(c);
    await c.query(
      `insert into categories (business_id, id, name, position, change_seq) values ($1, 'tx2', 'tx2', 9, $2)`,
      [a, seq],
    );
    return seq;
  });
  await waitForAdvisoryWaiter();

  const seen = await withBusiness(t.db, a, (c) => c.query(`select id from categories where id in ('tx1', 'tx2')`));
  expect(seen.rowCount).toBe(0);
  expect(events).toEqual(['tx1 hat Nummer']);

  tx1Release.open();
  const [seq1, seq2] = await Promise.all([tx1, tx2]);
  expect(events).toEqual(['tx1 hat Nummer', 'tx1 fertig', 'tx2 beginnt']);
  expect(seq2).toBeGreaterThan(seq1);

  const rows = await withBusiness(t.db, a, (c) =>
    c.query<{ id: string }>(`select id from categories where id in ('tx1', 'tx2') order by change_seq`),
  );
  expect(rows.rows.map((r) => r.id)).toEqual(['tx1', 'tx2']);
  await withBusiness(t.db, a, (c) => c.query(`delete from categories where id in ('tx1', 'tx2')`));
});

test('withBusinessWrite auf zwei verschiedene Betriebe blockiert sich nicht', async () => {
  const tx1Holds = gate();
  const tx1Release = gate();
  const tx1 = withBusinessWrite(t.db, a, async (c) => {
    await nextChangeSeq(c);
    tx1Holds.open();
    await tx1Release.promise;
  });
  await tx1Holds.promise;
  try {
    const seq = await withBusinessWrite(t.db, b, (c) => nextChangeSeq(c));
    expect(seq).toBeGreaterThan(0);
  } finally {
    tx1Release.open();
    await tx1;
  }
});
