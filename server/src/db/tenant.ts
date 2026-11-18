import type pg from 'pg';
import type { Db } from './db.js';

export type TransactionOptions = {
  /** Liest die ganze Transaktion aus einem festen Stand (REPEATABLE READ). */
  repeatableRead?: boolean;
};

async function transaction<T>(
  db: Db,
  opts: TransactionOptions,
  fn: (c: pg.PoolClient) => Promise<T>,
): Promise<T> {
  const c = await db.pool.connect();
  let broken: Error | undefined;
  try {
    await c.query(opts.repeatableRead ? 'begin isolation level repeatable read' : 'begin');
    try {
      const result = await fn(c);
      await c.query('commit');
      return result;
    } catch (err) {
      try {
        await c.query('rollback');
      } catch (rollbackErr) {
        // Eine Verbindung, die nicht mehr zurückrollen kann, kommt nicht zurück in den Pool.
        broken = rollbackErr as Error;
      }
      throw err;
    }
  } finally {
    c.release(broken);
  }
}

/**
 * Setzt den Betrieb für die laufende Transaktion einer schon offenen Verbindung.
 * Nach commit oder rollback gilt er nicht mehr.
 */
export async function setBusiness(c: pg.PoolClient, businessId: string): Promise<void> {
  await c.query(`select set_config('app.business_id', $1, true)`, [businessId]);
}

/** Eine Transaktion ohne Betrieb: gesperrte Tabellen liefern darin keine Zeilen. */
export function withSystem<T>(db: Db, fn: (c: pg.PoolClient) => Promise<T>): Promise<T> {
  return transaction(db, {}, fn);
}

/** Eine Transaktion, in der nur die Zeilen dieses Betriebs sichtbar und änderbar sind. */
export function withBusiness<T>(
  db: Db,
  businessId: string,
  fn: (c: pg.PoolClient) => Promise<T>,
  opts: TransactionOptions = {},
): Promise<T> {
  return transaction(db, opts, async (c) => {
    await setBusiness(c, businessId);
    return fn(c);
  });
}

/**
 * Wie withBusiness, aber Schreib-Transaktionen desselben Betriebs laufen nacheinander.
 * So wird keine Änderungs-Nummer sichtbar, bevor alle kleineren sichtbar sind.
 */
export function withBusinessWrite<T>(db: Db, businessId: string, fn: (c: pg.PoolClient) => Promise<T>): Promise<T> {
  return transaction(db, {}, async (c) => {
    await c.query('select pg_advisory_xact_lock(hashtextextended($1, 0))', [businessId]);
    await setBusiness(c, businessId);
    return fn(c);
  });
}

/** Die nächste Änderungs-Nummer. Nur innerhalb von withBusinessWrite aufrufen. */
export async function nextChangeSeq(c: pg.PoolClient): Promise<number> {
  const r = await c.query<{ seq: string }>(`select nextval('change_seq') as seq`);
  return Number(r.rows[0]!.seq);
}
