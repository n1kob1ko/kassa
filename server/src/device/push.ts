import type { FastifyBaseLogger, FastifyInstance, FastifyRequest } from 'fastify';
import type pg from 'pg';
import { nextChangeSeq, withBusiness, withBusinessWrite } from '../db/tenant.js';
import { ApiError } from '../errors.js';
import { writeServerReport } from '../reports.js';
import { contentHash } from './content_hash.js';
import { handleCustomer } from './push_customer.js';
import { handleItemChange } from './push_item_change.js';
import { handleRecipient } from './push_recipient.js';
import { handleReport } from './push_report.js';
import { requireRegister, type Register } from './guard.js';
import {
  asV1,
  asV2,
  certificateEntry,
  chainEntry,
  dayEntry,
  envelopeSchema,
  invalid,
  movementEntry,
  paymentColumns,
  receiptEntry,
  ruleViolations,
  VOUCHER_SALE_ITEM_ID,
  type ParsedReceipt,
  type ParsedReceiptV2,
  type ParsedReceiptV3,
} from './push_schema.js';

export const PUSH_BODY_LIMIT = 2 * 1024 * 1024;

export type EntryContext = { register: Register; deviceId: string; at: Date; log?: Pick<FastifyBaseLogger, 'warn'> };
export type EntryResult =
  | { status: 'accepted' | 'duplicate' }
  | { status: 'rejected'; reason: 'conflict' | 'invalid' | 'unknown_item'; paths?: string[] };
/**
 * Nimmt einen ganzen Eintrag (mit `seq` und `kind`) in einer Transaktion des Betriebs. Unlesbar: rejected/invalid mit den
 * Pfaden der Fehler in `paths` (die gehen nur in den Bericht, nicht in die Antwort).
 */
export type EntryHandler = (c: pg.PoolClient, ctx: EntryContext, body: unknown) => Promise<EntryResult>;

const ACCEPTED: EntryResult = { status: 'accepted' };
const DUPLICATE: EntryResult = { status: 'duplicate' };
const CONFLICT: EntryResult = { status: 'rejected', reason: 'conflict' };

type Existing = { content_hash: Buffer };

function report(c: pg.PoolClient, ctx: EntryContext, kind: string, content: object): Promise<void> {
  return writeServerReport(c, { businessId: ctx.register.businessId, registerId: ctx.register.id, kind, content }, ctx.at, ctx.log);
}

async function handleCertificate(c: pg.PoolClient, ctx: EntryContext, body: unknown): Promise<EntryResult> {
  const parsed = certificateEntry.safeParse(body);
  if (!parsed.success) return invalid(parsed.error);
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
  if (!parsed.success) return invalid(parsed.error);
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
  if (!parsed.success) return invalid(parsed.error);
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
  if (!parsed.success) return invalid(parsed.error);
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

/** Prüfwert eines Bons: über alle gelesenen Felder außer dem Eintrag der Signatur. */
function receiptHash(r: ParsedReceipt): Buffer {
  const { rksv: _rksv, ...withoutRksv } = r;
  return contentHash(withoutRksv);
}

/** Was an den Summen eines Bons nicht passt. Der Bon wird trotzdem angenommen, das geht in den Bericht receipt_sums. */
function sumProblems(v: ParsedReceipt): string[] {
  const grossSum = v.lines.reduce((s, l) => s + l.gross['20'] + l.gross['10'] + l.gross['13'] + l.gross['0'] + l.gross['19'], 0);
  const problems: string[] = [];
  if (v.goodsCents + v.depositCents !== v.totalCents) problems.push('goods_plus_deposit');
  if (grossSum !== v.goodsCents) problems.push('lines_gross');
  if (v.v === 1) {
    if (v.kind === 'sale' && v.payment !== null && v.payment.amountCents !== v.totalCents) problems.push('payment');
    return problems;
  }
  return [...problems, ...sumProblemsV2(v), ...(v.v === 3 ? sumProblemsV3(v) : [])];
}

/**
 * Passen die verkauften Gutscheine zu den Gutschein-Zeilen? Jeder zeigt auf eine solche Zeile, die Werte ergeben zusammen
 * voucher_sale_cents, und jeder Wert hat das Vorzeichen des Bons (Verkauf über 0, Storno unter 0).
 */
function sumProblemsV3(v: ParsedReceiptV3): string[] {
  const saleLines = new Set(v.lines.filter((l) => l.itemId === VOUCHER_SALE_ITEM_ID).map((l) => l.position));
  const sign = v.kind === 'voided' ? -1 : 1;
  const fits =
    v.vouchers.every((x) => saleLines.has(x.linePosition) && x.valueCents * sign > 0) &&
    v.vouchers.reduce((s, x) => s + x.valueCents, 0) === paymentColumns(v).voucherSaleCents;
  return fits ? [] : ['vouchers'];
}

function sumProblemsV2(v: ParsedReceiptV2 | ParsedReceiptV3): string[] {
  const problems: string[] = [];
  const sum = (values: number[]) => values.reduce((s, n) => s + n, 0);
  const payments: { kind: string; position: number; amountCents: number; tipCents: number }[] = v.payments;
  const paid = sum(payments.map((p) => p.amountCents));
  if ((v.kind === 'sale' || v.kind === 'voided') && paid !== v.totalCents) problems.push('payments');
  if (sum(payments.map((p) => p.tipCents)) !== v.tipCents) problems.push('tip');
  if (sum(v.lines.map((l) => l.discountCents)) !== v.discountCents) problems.push('discount');
  // Höchstens eine Kartenzahlung, und die an letzter Stelle.
  const byPosition = [...payments].sort((a, b) => a.position - b.position);
  const cards = byPosition.filter((p) => p.kind === 'card');
  if (cards.length > 1 || (cards.length === 1 && byPosition.at(-1) !== cards[0])) problems.push('card_last');
  return problems;
}

/** Prüfwerte, unter denen derselbe Bon in einer älteren Form schon da sein kann (Muster asV1 aus 1a). */
function olderHashes(v: ParsedReceipt): Buffer[] {
  const v2 = v.v === 3 ? asV2(v) : v.v === 2 ? v : null;
  if (v2 === null) return [];
  const v1 = asV1(v2);
  return [...(v.v === 3 ? [receiptHash(v2)] : []), ...(v1 === null ? [] : [receiptHash(v1)])];
}

/** Ein Bon, der eine feste Regel bricht oder einen Schlüssel trägt, den schon ein anderer Bon hat: rejected/invalid. */
async function receiptInvalid(c: pg.PoolClient, ctx: EntryContext, v: ParsedReceipt): Promise<EntryResult | null> {
  if (v.v !== 3) return null;
  const rules = ruleViolations(v);
  if (rules.length > 0) return { status: 'rejected', reason: 'invalid', paths: rules.map((r) => `receipt.rules.${r}`) };
  if (v.publicToken === null) return null;
  // receipt_links hat keinen Zeilen-Schutz: der Schlüssel gilt über alle Betriebe.
  const link = await c.query<{ business_id: string; receipt_id: string }>(
    'select business_id, receipt_id from receipt_links where token = $1',
    [v.publicToken],
  );
  const row = link.rows[0];
  if (row && (row.business_id !== ctx.register.businessId || row.receipt_id !== v.id)) {
    return { status: 'rejected', reason: 'invalid', paths: ['receipt.publicToken'] };
  }
  return null;
}

/**
 * Schlüssel der Seite, Gutscheine und Bewegungen eines neuen Bons v: 3, in der Transaktion des Bons. Ein Gutschein entsteht
 * beim Verkauf (falls noch nicht da), das Storno legt keinen an. Das Guthaben prüft der Server nicht.
 */
async function writeReceiptV3(c: pg.PoolClient, ctx: EntryContext, v: ParsedReceiptV3): Promise<void> {
  const businessId = ctx.register.businessId;
  if (v.publicToken !== null) {
    await c.query('insert into receipt_links (token, business_id, receipt_id) values ($1, $2, $3)', [v.publicToken, businessId, v.id]);
  }
  const isVoid = v.kind === 'voided';
  const move = async (voucherId: string, kind: string, amountCents: number) =>
    c.query(
      `insert into voucher_movements (business_id, voucher_id, receipt_id, kind, amount_cents, created_at, change_seq)
       values ($1, $2, $3, $4, $5, $6, $7)`,
      [businessId, voucherId, v.id, kind, amountCents, v.createdAt, await nextChangeSeq(c)],
    );
  for (const sold of v.vouchers) {
    if (!isVoid) {
      const exists = await c.query('select 1 from vouchers where business_id = $1 and id = $2', [businessId, sold.id]);
      if (exists.rowCount === 0) {
        await c.query(
          `insert into vouchers (business_id, id, code, value_cents, created_at, is_test, sold_receipt_id, register_id, change_seq)
           values ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
          [businessId, sold.id, sold.code, sold.valueCents, v.createdAt, v.test, v.id, ctx.register.id, await nextChangeSeq(c)],
        );
      }
    }
    await move(sold.id, isVoid ? 'void_sale' : 'sale', sold.valueCents);
  }
  for (const p of v.payments) {
    if (p.kind !== 'voucher') continue;
    await move(p.voucherId!, isVoid ? 'void_redeem' : 'redeem', -p.amountCents);
  }
}

/** Hat der Server den Bon schon: duplicate (auch in älterer Form) oder conflict mit Bericht. Ein neuer Bon: null. */
async function knownReceipt(c: pg.PoolClient, ctx: EntryContext, v: ParsedReceipt, hash: Buffer): Promise<EntryResult | null> {
  const row = (await c.query<Existing>('select content_hash from receipts where id = $1', [v.id])).rows[0];
  if (!row) return null;
  const existing = row.content_hash;
  // Ein Tablet nach dem Update (1.10.0 auf 1.11.0, 1.11.0 auf 1.12.0) schickt einen schon gesendeten Bon in der neuen Form.
  const same = existing.equals(hash) || olderHashes(v).some((h) => existing.equals(h));
  if (!same) {
    await report(c, ctx, 'receipt_conflict', { receiptId: v.id, number: v.number });
    return CONFLICT;
  }
  if (v.rksv) await writeRksvEntry(c, ctx, v.id, v.rksv);
  return DUPLICATE;
}

async function handleReceipt(c: pg.PoolClient, ctx: EntryContext, body: unknown): Promise<EntryResult> {
  const parsed = receiptEntry.safeParse(body);
  if (!parsed.success) return invalid(parsed.error);
  const v = parsed.data.receipt;
  const rksv = v.rksv;
  const hash = receiptHash(v);
  // Ein Bon, den der Server schon hat (auch in älterer Form), ist duplicate oder conflict: Regeln und Schlüssel gelten nur
  // für einen neuen Bon.
  const known = await knownReceipt(c, ctx, v, hash);
  if (known) return known;
  const rejected = await receiptInvalid(c, ctx, v);
  if (rejected) return rejected;
  const sums = paymentColumns(v);
  // Das Original ist der Bon, wie er kam (auch Felder, die der Server noch nicht kennt), der Prüfwert hängt an den gelesenen.
  const payload = JSON.stringify((body as { receipt: unknown }).receipt);
  const inserted = await c.query(
    `insert into receipts (business_id, id, register_id, device_id, number, created_at, kind, staff_id, staff_name, business_day_id,
                           voids_receipt_id, goods_cents, deposit_cents, total_cents, payment_kind, is_test, content_hash, payload, received_at,
                           cash_cents, card_cents, tip_cents, discount_cents, voucher_cents, voucher_sale_cents, deposit_return_cents,
                           public_token)
     values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23,
             $24, $25, $26, $27)
     on conflict do nothing`,
    [ctx.register.businessId, v.id, ctx.register.id, ctx.deviceId, v.number, v.createdAt, v.kind, v.staffId, v.staffName,
      v.businessDayId, v.voidsReceiptId, v.goodsCents, v.depositCents, v.totalCents, sums.paymentKind, v.test,
      hash, payload, ctx.at, sums.cashCents, sums.cardCents, sums.tipCents, sums.discountCents,
      sums.voucherCents, sums.voucherSaleCents, sums.depositReturnCents, v.v === 3 ? v.publicToken : null],
  );
  // Zwischen der Frage oben und hier angekommen (zweite Sendung zur selben Zeit): wie ein schon bekannter Bon.
  if (inserted.rowCount !== 1) {
    const again = await knownReceipt(c, ctx, v, hash);
    if (!again) throw new Error('Bon weder eingefügt noch gefunden');
    return again;
  }

  // Zeilen von v: 1 haben keinen Rabatt.
  const lines: ParsedReceiptV2['lines'] = v.v === 1 ? v.lines.map((l) => ({ ...l, discountCents: 0, discount: null })) : v.lines;
  for (const l of lines) {
    await c.query(
      `insert into receipt_lines (business_id, receipt_id, position, item_id, name, info, unit_price_cents, quantity, unit_deposit_cents,
                                  gross20_cents, gross10_cents, gross13_cents, gross0_cents, gross19_cents, options, discount_cents, discount)
       values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17)`,
      [ctx.register.businessId, v.id, l.position, l.itemId, l.name, l.info, l.unitPriceCents, l.quantity, l.unitDepositCents,
        l.gross['20'], l.gross['10'], l.gross['13'], l.gross['0'], l.gross['19'], JSON.stringify(l.options),
        l.discountCents, l.discount === null ? null : JSON.stringify(l.discount)],
    );
  }
  if (rksv) await writeRksvEntry(c, ctx, v.id, rksv);
  if (v.v === 3) await writeReceiptV3(c, ctx, v);

  const problems = sumProblems(v);
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
  customer: handleCustomer,
  recipient: handleRecipient,
};

/**
 * Arten, die eine Änderungs-Nummer ziehen und darum in withBusinessWrite laufen (ein Bon v: 3 für Gutscheine und
 * Bewegungen, ein Firmenkunde für das Holen der anderen Tablets).
 */
const WRITE_KINDS = new Set(['item_change', 'receipt', 'customer']);

type Result = { seq: number } & (EntryResult | { status: 'error' });
type Entry = { seq: number; kind: string } & Record<string, unknown>;
type Outcome = EntryResult | { status: 'error' };

/** Fehler der Datenbank, die bei jedem neuen Versuch wieder kämen: Klasse 22 (Daten, etwa NUL im Text) und 23 (Bedingung). */
function deterministic(err: unknown): string | null {
  const code = (err as { code?: unknown } | null)?.code;
  return typeof code === 'string' && /^2[23][0-9A-Z]{3}$/.test(code) ? code : null;
}

/** POST /api/device/sync/push: Einträge des Tablets annehmen. Jeder Eintrag läuft in einer eigenen Transaktion. */
export function installPushRoutes(app: FastifyInstance): void {
  const { db, now } = app.deps;
  const registers = new WeakMap<FastifyRequest, Register>();

  /** Ein abgelehnter Eintrag (außer conflict, der hat seinen eigenen Bericht): Bericht push_rejected, nur feste Felder. */
  async function noteRejected(ctx: EntryContext, entry: Entry, reason: 'invalid' | 'unknown_item', extra: object): Promise<void> {
    const { businessId, id: registerId } = ctx.register;
    // Ein Bericht des Tablets, der nicht lesbar ist, erzeugt keinen Bericht (keine Schleife), nur die Zeile im Protokoll.
    if (entry.kind === 'report') {
      ctx.log?.warn({ businessId, registerId, seq: entry.seq, kind: entry.kind, reason }, 'Eintrag abgelehnt');
      return;
    }
    const content = { entryKind: entry.kind, seq: entry.seq, reason, ...extra };
    try {
      await withBusiness(db, businessId, (c) => report(c, ctx, 'push_rejected', content));
    } catch (err) {
      ctx.log?.warn({ err, businessId, registerId, ...content }, 'Eintrag abgelehnt, Bericht nicht geschrieben');
    }
  }

  async function take(ctx: EntryContext, entry: Entry, log: FastifyBaseLogger): Promise<Outcome> {
    const handler = Object.hasOwn(handlers, entry.kind) ? handlers[entry.kind]! : undefined;
    if (!handler) {
      await noteRejected(ctx, entry, 'invalid', { paths: [] });
      return { status: 'rejected', reason: 'invalid' };
    }
    try {
      const run = WRITE_KINDS.has(entry.kind) ? withBusinessWrite : withBusiness;
      const result = await run(db, ctx.register.businessId, (c) => handler(c, ctx, entry));
      if (result.status !== 'rejected' || result.reason === 'conflict') return result;
      await noteRejected(ctx, entry, result.reason, result.reason === 'invalid' ? { paths: result.paths ?? [] } : {});
      return { status: 'rejected', reason: result.reason };
    } catch (err) {
      // Nur die Art und der Fehler, nie der Inhalt des Eintrags.
      log.error({ err, seq: entry.seq, kind: entry.kind }, 'Eintrag konnte nicht angenommen werden');
      const sqlState = deterministic(err);
      if (sqlState === null) return { status: 'error' };
      await noteRejected(ctx, entry, 'invalid', { sqlState });
      return { status: 'rejected', reason: 'invalid' };
    }
  }

  // Erst der Geräte-Schlüssel, dann der Inhalt: ohne gültigen Schlüssel liest der Server keine 2 MB.
  const authenticate = async (req: FastifyRequest) => {
    registers.set(req, await requireRegister(req));
  };

  app.post('/api/device/sync/push', { bodyLimit: PUSH_BODY_LIMIT, onRequest: authenticate }, async (req) => {
    const register = registers.get(req)!;
    const parsed = envelopeSchema.safeParse(req.body);
    if (!parsed.success) {
      req.log.warn({ businessId: register.businessId, registerId: register.id }, 'Sendung abgelehnt');
      throw new ApiError(422, 'push_invalid', 'Die Sendung ist nicht lesbar: deviceId und höchstens 100 Einträge mit seq und kind.');
    }
    const { deviceId, entries } = parsed.data as { deviceId: string; entries: Entry[] };
    const at = now();
    const ctx: EntryContext = { register, deviceId, at, log: req.log };

    await withBusiness(db, register.businessId, (c) =>
      c.query('update registers set device_id = $2 where id = $1 and device_id is distinct from $2', [register.id, deviceId]),
    );

    const results: Result[] = [];
    for (const entry of entries) {
      results.push({ seq: entry.seq, ...(await take(ctx, entry, req.log)) });
    }
    return { results };
  });
}
