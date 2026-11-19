import type { FastifyBaseLogger, FastifyInstance } from 'fastify';
import type pg from 'pg';
import { withBusiness, withBusinessWrite } from '../db/tenant.js';
import { ApiError } from '../errors.js';
import { writeServerReport } from '../reports.js';
import { contentHash } from './content_hash.js';
import { handleItemChange } from './push_item_change.js';
import { handleReport } from './push_report.js';
import { requireRegister, type Register } from './guard.js';
import {
  certificateEntry,
  chainEntry,
  dayEntry,
  envelopeSchema,
  movementEntry,
  receiptEntry,
  type ParsedReceipt,
} from './push_schema.js';

export const PUSH_BODY_LIMIT = 2 * 1024 * 1024;

export type EntryContext = { register: Register; deviceId: string; at: Date; log?: Pick<FastifyBaseLogger, 'warn'> };
export type EntryResult =
  | { status: 'accepted' | 'duplicate' }
  | { status: 'rejected'; reason: 'conflict' | 'invalid' | 'unknown_item' };
/** Nimmt einen ganzen Eintrag (mit `seq` und `kind`) in einer Transaktion des Betriebs. Unlesbar: rejected/invalid. */
export type EntryHandler = (c: pg.PoolClient, ctx: EntryContext, body: unknown) => Promise<EntryResult>;

const ACCEPTED: EntryResult = { status: 'accepted' };
const DUPLICATE: EntryResult = { status: 'duplicate' };
const INVALID: EntryResult = { status: 'rejected', reason: 'invalid' };
const CONFLICT: EntryResult = { status: 'rejected', reason: 'conflict' };

type Existing = { content_hash: Buffer };

function report(c: pg.PoolClient, ctx: EntryContext, kind: string, content: object): Promise<void> {
  return writeServerReport(c, { businessId: ctx.register.businessId, registerId: ctx.register.id, kind, content }, ctx.at, ctx.log);
}

async function handleCertificate(c: pg.PoolClient, ctx: EntryContext, body: unknown): Promise<EntryResult> {
  const parsed = certificateEntry.safeParse(body);
  if (!parsed.success) return INVALID;
  const v = parsed.data.certificate;
  const hash = contentHash(v);
  const inserted = await c.query(
    `insert into rksv_certificates (business_id, device_id, serial_hex, certificate, issuers, register_id, content_hash, received_at)
     values ($1, $2, $3, $4, $5, $6, $7, $8) on conflict do nothing`,
    [ctx.register.businessId, ctx.deviceId, v.serialHex, Buffer.from(v.certificate, 'base64'), JSON.stringify(v.issuers), ctx.register.id, hash, ctx.at],
  );
  if (inserted.rowCount === 1) return ACCEPTED;
  const existing = await c.query<Existing>(
    'select content_hash from rksv_certificates where device_id = $1 and serial_hex = $2',
    [ctx.deviceId, v.serialHex],
  );
  if (existing.rows[0]!.content_hash.equals(hash)) return DUPLICATE;
  await report(c, ctx, 'certificate_conflict', { serialHex: v.serialHex });
  return CONFLICT;
}

async function handleChain(c: pg.PoolClient, ctx: EntryContext, body: unknown): Promise<EntryResult> {
  const parsed = chainEntry.safeParse(body);
  if (!parsed.success) return INVALID;
  const v = parsed.data.chain;
  const hash = contentHash(v);
  const existing = await c.query<Existing & { ended_at: Date | null }>(
    'select content_hash, ended_at from rksv_chains where device_id = $1 and chain = $2 for update',
    [ctx.deviceId, v.chain],
  );
  const row = existing.rows[0];
  if (!row) {
    await c.query(
      `insert into rksv_chains (business_id, device_id, chain, mode, cash_box_id, zda_id, cert_serial, started_at, ended_at, register_id, content_hash, received_at)
       values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)`,
      [ctx.register.businessId, ctx.deviceId, v.chain, v.mode, v.cashBoxId, v.zdaId, v.certSerial, v.startedAt, v.endedAt, ctx.register.id, hash, ctx.at],
    );
    return ACCEPTED;
  }
  if (row.ended_at === null) {
    await c.query(
      `update rksv_chains set mode = $3, cash_box_id = $4, zda_id = $5, cert_serial = $6, started_at = $7, ended_at = $8,
              content_hash = $9, received_at = $10, register_id = $11
        where device_id = $1 and chain = $2`,
      [ctx.deviceId, v.chain, v.mode, v.cashBoxId, v.zdaId, v.certSerial, v.startedAt, v.endedAt, hash, ctx.at, ctx.register.id],
    );
    return ACCEPTED;
  }
  if (row.content_hash.equals(hash)) return DUPLICATE;
  await report(c, ctx, 'chain_conflict', { chain: v.chain });
  return CONFLICT;
}

async function handleDay(c: pg.PoolClient, ctx: EntryContext, body: unknown): Promise<EntryResult> {
  const parsed = dayEntry.safeParse(body);
  if (!parsed.success) return INVALID;
  const v = parsed.data.day;
  const hash = contentHash(v);
  const existing = await c.query<Existing & { closed_at: Date | null }>(
    'select content_hash, closed_at from business_days where id = $1 for update',
    [v.id],
  );
  const row = existing.rows[0];
  if (!row) {
    await c.query(
      `insert into business_days (business_id, id, register_id, device_id, opened_at, closed_at, opening_float_cents, counted_cents,
                                  left_in_drawer_cents, expected_cents, difference_cents, closed_by_name, content_hash, received_at)
       values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)`,
      [ctx.register.businessId, v.id, ctx.register.id, ctx.deviceId, v.openedAt, v.closedAt, v.openingFloatCents, v.countedCents,
        v.leftInDrawerCents, v.expectedCents, v.differenceCents, v.closedByName, hash, ctx.at],
    );
    return ACCEPTED;
  }
  if (row.closed_at === null) {
    await c.query(
      `update business_days set opened_at = $2, closed_at = $3, opening_float_cents = $4, counted_cents = $5,
              left_in_drawer_cents = $6, expected_cents = $7, difference_cents = $8, closed_by_name = $9,
              content_hash = $10, received_at = $11, register_id = $12
        where id = $1`,
      [v.id, v.openedAt, v.closedAt, v.openingFloatCents, v.countedCents, v.leftInDrawerCents, v.expectedCents,
        v.differenceCents, v.closedByName, hash, ctx.at, ctx.register.id],
    );
    return ACCEPTED;
  }
  if (row.content_hash.equals(hash)) return DUPLICATE;
  await report(c, ctx, 'day_conflict', { dayId: v.id });
  return CONFLICT;
}

async function handleMovement(c: pg.PoolClient, ctx: EntryContext, body: unknown): Promise<EntryResult> {
  const parsed = movementEntry.safeParse(body);
  if (!parsed.success) return INVALID;
  const v = parsed.data.movement;
  const hash = contentHash(v);
  const inserted = await c.query(
    `insert into cash_movements (business_id, id, register_id, business_day_id, kind, amount_cents, reason, created_at,
                                 staff_id, staff_name, content_hash, received_at)
     values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12) on conflict do nothing`,
    [ctx.register.businessId, v.id, ctx.register.id, v.businessDayId, v.kind, v.amountCents, v.reason, v.createdAt,
      v.staffId, v.staffName, hash, ctx.at],
  );
  if (inserted.rowCount === 1) return ACCEPTED;
  const existing = await c.query<Existing>('select content_hash from cash_movements where id = $1', [v.id]);
  if (existing.rows[0]!.content_hash.equals(hash)) return DUPLICATE;
  await report(c, ctx, 'movement_conflict', { movementId: v.id });
  return CONFLICT;
}

type RksvEntry = NonNullable<ParsedReceipt['rksv']>;

/** Trägt den Eintrag der Signatur ein. Steht er schon anders da, bleibt der Bon-Status, es gibt einen Bericht. */
async function writeRksvEntry(c: pg.PoolClient, ctx: EntryContext, receiptId: string, e: RksvEntry): Promise<void> {
  const inserted = await c.query(
    `insert into rksv_entries (business_id, device_id, chain, position, receipt_id, jws, damaged, cert_serial, register_id, received_at)
     values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10) on conflict do nothing`,
    [ctx.register.businessId, ctx.deviceId, e.chain, e.position, receiptId, e.jws, e.damaged, e.certSerial, ctx.register.id, ctx.at],
  );
  if (inserted.rowCount === 1) return;
  const same = await c.query(
    `select 1 from rksv_entries
      where receipt_id = $1 and device_id = $2 and chain = $3 and position = $4 and jws = $5 and damaged = $6 and cert_serial = $7`,
    [receiptId, ctx.deviceId, e.chain, e.position, e.jws, e.damaged, e.certSerial],
  );
  if (same.rowCount === 1) return;
  await report(c, ctx, 'rksv_conflict', { receiptId, chain: e.chain, position: e.position });
}

async function handleReceipt(c: pg.PoolClient, ctx: EntryContext, body: unknown): Promise<EntryResult> {
  const parsed = receiptEntry.safeParse(body);
  if (!parsed.success) return INVALID;
  const v = parsed.data.receipt;
  const { rksv, ...withoutRksv } = v;
  const hash = contentHash(withoutRksv);
  const payload = JSON.stringify(v);
  const inserted = await c.query(
    `insert into receipts (business_id, id, register_id, device_id, number, created_at, kind, staff_id, staff_name, business_day_id,
                           voids_receipt_id, goods_cents, deposit_cents, total_cents, payment_kind, is_test, content_hash, payload, received_at)
     values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19) on conflict do nothing`,
    [ctx.register.businessId, v.id, ctx.register.id, ctx.deviceId, v.number, v.createdAt, v.kind, v.staffId, v.staffName,
      v.businessDayId, v.voidsReceiptId, v.goodsCents, v.depositCents, v.totalCents, v.payment?.kind ?? null, v.test,
      hash, payload, ctx.at],
  );
  if (inserted.rowCount !== 1) {
    const existing = await c.query<Existing>('select content_hash from receipts where id = $1', [v.id]);
    if (!existing.rows[0]!.content_hash.equals(hash)) {
      await report(c, ctx, 'receipt_conflict', { receiptId: v.id, number: v.number });
      return CONFLICT;
    }
    if (rksv) await writeRksvEntry(c, ctx, v.id, rksv);
    return DUPLICATE;
  }

  for (const l of v.lines) {
    await c.query(
      `insert into receipt_lines (business_id, receipt_id, position, item_id, name, info, unit_price_cents, quantity, unit_deposit_cents,
                                  gross20_cents, gross10_cents, gross13_cents, gross0_cents, gross19_cents, options)
       values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)`,
      [ctx.register.businessId, v.id, l.position, l.itemId, l.name, l.info, l.unitPriceCents, l.quantity, l.unitDepositCents,
        l.gross['20'], l.gross['10'], l.gross['13'], l.gross['0'], l.gross['19'], JSON.stringify(l.options)],
    );
  }
  if (rksv) await writeRksvEntry(c, ctx, v.id, rksv);

  const grossSum = v.lines.reduce((s, l) => s + l.gross['20'] + l.gross['10'] + l.gross['13'] + l.gross['0'] + l.gross['19'], 0);
  const problems: string[] = [];
  if (v.goodsCents + v.depositCents !== v.totalCents) problems.push('goods_plus_deposit');
  if (grossSum !== v.goodsCents) problems.push('lines_gross');
  if (v.kind === 'sale' && v.payment !== null && v.payment.amountCents !== v.totalCents) problems.push('payment');
  if (problems.length > 0) await report(c, ctx, 'receipt_sums', { receiptId: v.id, number: v.number, problems });
  return ACCEPTED;
}

/** Eine Art von Eintrag, ein Handler. Weitere Arten werden hier eingetragen. */
export const handlers: Record<string, EntryHandler> = {
  rksv_certificate: handleCertificate,
  rksv_chain: handleChain,
  day: handleDay,
  cash_movement: handleMovement,
  receipt: handleReceipt,
  item_change: handleItemChange,
  report: handleReport,
};

/** Arten, die eine Änderungs-Nummer ziehen und darum in withBusinessWrite laufen. */
const WRITE_KINDS = new Set(['item_change']);

type Result = { seq: number } & (EntryResult | { status: 'error' });

/** POST /api/device/sync/push: Einträge des Tablets annehmen. Jeder Eintrag läuft in einer eigenen Transaktion. */
export function installPushRoutes(app: FastifyInstance): void {
  const { db, now } = app.deps;

  app.post('/api/device/sync/push', { bodyLimit: PUSH_BODY_LIMIT }, async (req) => {
    const register = await requireRegister(req);
    const parsed = envelopeSchema.safeParse(req.body);
    if (!parsed.success) {
      throw new ApiError(422, 'push_invalid', 'Die Sendung ist nicht lesbar: deviceId und höchstens 100 Einträge mit seq und kind.');
    }
    const { deviceId, entries } = parsed.data as { deviceId: string; entries: ({ seq: number; kind: string } & Record<string, unknown>)[] };
    const at = now();
    const ctx: EntryContext = { register, deviceId, at, log: req.log };

    await withBusiness(db, register.businessId, (c) =>
      c.query('update registers set device_id = $2 where id = $1 and device_id is distinct from $2', [register.id, deviceId]),
    );

    const results: Result[] = [];
    for (const entry of entries) {
      const handler = Object.hasOwn(handlers, entry.kind) ? handlers[entry.kind]! : undefined;
      if (!handler) {
        results.push({ seq: entry.seq, ...INVALID });
        continue;
      }
      try {
        const run = WRITE_KINDS.has(entry.kind) ? withBusinessWrite : withBusiness;
        results.push({ seq: entry.seq, ...(await run(db, register.businessId, (c) => handler(c, ctx, entry))) });
      } catch (err) {
        // Nur die Art und der Fehler, nie der Inhalt des Eintrags.
        req.log.error({ err, seq: entry.seq, kind: entry.kind }, 'Eintrag konnte nicht angenommen werden');
        results.push({ seq: entry.seq, status: 'error' });
      }
    }
    return { results };
  });
}
