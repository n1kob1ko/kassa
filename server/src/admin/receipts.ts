import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { isUuid, requireBusinessAccess } from '../auth/guards.js';
import { withBusiness } from '../db/tenant.js';
import { ApiError } from '../errors.js';
import { hasCard, hasCash } from './months.js';
import { loadTimeZone } from './overview.js';

const PAGE_SIZE = 50;

const notFound = () => new ApiError(404, 'not_found', 'Das gibt es nicht.');
const invalid = (code: string, message: string) => new ApiError(422, code, message);

const isoMicros = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{6}Z$/;
const marker = z.object({ t: z.string().regex(isoMicros), i: z.string().refine(isUuid) });

/** Die Kennung der nächsten Seite: Zeitpunkt (auf die Mikrosekunde) und Kennung des letzten Bons, in base64url. */
function encodeMarker(t: string, i: string): string {
  return Buffer.from(JSON.stringify({ t, i }), 'utf8').toString('base64url');
}

function decodeMarker(raw: string): { t: string; i: string } {
  const bad = () => invalid('before_invalid', 'Die Kennung für die nächste Seite ist nicht in Ordnung.');
  if (!/^[A-Za-z0-9_-]+$/.test(raw)) throw bad();
  let json: unknown;
  try {
    json = JSON.parse(Buffer.from(raw, 'base64url').toString('utf8'));
  } catch {
    throw bad();
  }
  const r = marker.safeParse(json);
  if (!r.success) throw bad();
  // Die Form stimmt, der Zeitpunkt muss es auch: Monat 13 oder der 30. Februar gibt es nicht.
  const ms = new Date(r.data.t.replace(/\.\d{6}Z$/, '.000Z'));
  if (Number.isNaN(ms.getTime()) || !ms.toISOString().startsWith(r.data.t.slice(0, 19))) throw bad();
  return r.data;
}

const listQuery = z.object({
  day: z.string().optional(),
  payment: z.enum(['cash', 'card', 'voucher']).optional(),
  voided: z.literal('1').optional(),
  before: z.string().optional(),
});

function isCalendarDay(s: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(s)) return false;
  const d = new Date(`${s}T00:00:00Z`);
  const year = d.getUTCFullYear();
  return !Number.isNaN(d.getTime()) && d.toISOString().startsWith(s) && year >= 2000 && year <= 2100;
}

const VOIDED = `exists (select 1 from receipts v where v.business_id = r.business_id and v.voids_receipt_id = r.id and v.kind = 'voided')`;
const HEAD = `
  r.id, r.number, coalesce(g.name, '') as register_name, r.created_at, r.kind,
  r.payload->>'staffName' as staff_name, r.total_cents, r.payment_kind, r.is_test,
  ${VOIDED} as voided, r.voucher_cents,
  array_remove(array[case when r.voucher_cents <> 0 then 'voucher' end, case when ${hasCash('r.')} then 'cash' end,
                     case when ${hasCard('r.')} then 'card' end], null) as payment_kinds,
  to_char(r.created_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"') as created_micros`;
const FROM = `from receipts r left join registers g on g.business_id = r.business_id and g.id = r.register_id`;

type HeadRow = {
  id: string;
  number: number;
  register_name: string;
  created_at: Date;
  kind: string;
  staff_name: string | null;
  total_cents: number;
  payment_kind: string | null;
  is_test: boolean;
  voided: boolean;
  voucher_cents: number;
  payment_kinds: string[];
  created_micros: string;
};

function head(r: HeadRow) {
  return {
    id: r.id,
    number: r.number,
    registerName: r.register_name,
    createdAt: r.created_at.toISOString(),
    kind: r.kind,
    staffName: r.staff_name ?? '',
    totalCents: r.total_cents,
    paymentKind: r.payment_kind,
    /** Mit Gutschein bezahlt; 0 bei Bons vor v: 3. */
    voucherCents: r.voucher_cents,
    /** Alle Arten der Zahlungen des Bons, in der Reihenfolge Gutschein, bar, Karte. */
    paymentKinds: r.payment_kinds,
    test: r.is_test,
    voided: r.voided,
  };
}

type Discount = { percent: number | null; amountCents: number; reason: string };

/** Ein Rabatt, wie er im Bon steht, nur mit seinen drei Feldern. */
function discountOf(d: Discount | null | undefined): Discount | null {
  return d ? { percent: d.percent ?? null, amountCents: d.amountCents, reason: d.reason } : null;
}

/** Adressen der Bons (nur lesen). Nach installAuth aufrufen. */
export function installReceiptRoutes(app: FastifyInstance): void {
  const { db } = app.deps;

  app.get<{ Params: { b: string } }>('/api/admin/businesses/:b/receipts', async (req) => {
    await requireBusinessAccess(req, req.params.b);
    const businessId = req.params.b.toLowerCase();
    const parsed = listQuery.safeParse(req.query);
    if (!parsed.success) throw invalid('query_invalid', 'Die Filter sind nicht in Ordnung.');
    const q = parsed.data;
    if (q.day !== undefined && !isCalendarDay(q.day)) throw invalid('day_invalid', 'Der Tag ist nicht in Ordnung.');
    const before = q.before === undefined ? null : decodeMarker(q.before);

    return withBusiness(db, businessId, async (c) => {
      const tz = q.day === undefined ? null : await loadTimeZone(c, businessId, req.log);
      const where: string[] = [];
      const params: unknown[] = [];
      const add = (v: unknown) => `$${params.push(v)}`;
      if (q.day !== undefined) {
        const d = add(q.day);
        const z = add(tz);
        where.push(`r.created_at >= (${d}::date::timestamp at time zone ${z})`);
        where.push(`r.created_at < ((${d}::date + 1)::timestamp at time zone ${z})`);
      }
      // Ein Bon steht unter jeder Art, mit der er bezahlt ist: ein gemischter (bar und Karte) unter beiden.
      if (q.payment === 'cash') where.push(hasCash('r.'));
      if (q.payment === 'card') where.push(hasCard('r.'));
      if (q.payment === 'voucher') where.push('r.voucher_cents <> 0');
      // Beide Hälften eines Paars: der Storno-Bon und der Verkauf, auf den er sich bezieht.
      if (q.voided) where.push(`(r.kind = 'voided' or ${VOIDED})`);
      if (before) {
        where.push(`(r.created_at, r.id) < (${add(before.t)}::timestamptz, ${add(before.i)}::uuid)`);
      }
      const limit = add(PAGE_SIZE + 1);
      const rows = (
        await c.query<HeadRow>(
          `select ${HEAD} ${FROM} ${where.length ? `where ${where.join(' and ')}` : ''}
            order by r.created_at desc, r.id desc limit ${limit}`,
          params,
        )
      ).rows;
      const page = rows.slice(0, PAGE_SIZE);
      const last = page[page.length - 1];
      return {
        receipts: page.map(head),
        next: rows.length > PAGE_SIZE && last ? encodeMarker(last.created_micros, last.id) : null,
      };
    });
  });

  app.get<{ Params: { b: string; id: string } }>('/api/admin/businesses/:b/receipts/:id', async (req) => {
    await requireBusinessAccess(req, req.params.b);
    const businessId = req.params.b.toLowerCase();
    if (!isUuid(req.params.id)) throw notFound();
    const id = req.params.id.toLowerCase();

    return withBusiness(db, businessId, async (c) => {
      const r = (
        await c.query<
          HeadRow & {
            goods_cents: number;
            deposit_cents: number;
            voids_receipt_id: string | null;
            voided_by: string | null;
            payments: Record<string, unknown>[] | null;
            payment: Record<string, unknown> | null;
            vouchers: { code: string; valueCents: number; linePosition: number }[] | null;
            discount: Discount | null;
            tip_cents: number;
            discount_cents: number;
          }
        >(
          `select ${HEAD}, r.goods_cents, r.deposit_cents, r.voids_receipt_id, r.tip_cents, r.discount_cents,
                  r.payload->'payments' as payments, r.payload->'payment' as payment, r.payload->'vouchers' as vouchers,
                  r.payload->'discount' as discount,
                  (select v.id from receipts v where v.business_id = r.business_id and v.voids_receipt_id = r.id and v.kind = 'voided'
                    order by v.created_at, v.id limit 1) as voided_by
             ${FROM} where r.id = $1`,
          [id],
        )
      ).rows[0];
      if (!r) throw notFound();

      const lines = (
        await c.query<{
          position: number;
          item_id: string;
          name: string;
          info: string | null;
          unit_price_cents: number;
          quantity: number;
          unit_deposit_cents: number;
          options: { groupName: string; optionName: string; surchargeCents: number }[];
          discount_cents: number;
          discount: Discount | null;
        }>(
          `select position, item_id, name, info, unit_price_cents, quantity, unit_deposit_cents, options, discount_cents, discount
             from receipt_lines where receipt_id = $1 order by position`,
          [id],
        )
      ).rows;

      // Nie die Signatur selbst, das Zertifikat oder das JWS.
      const rksv = (
        await c.query<{ damaged: boolean; cash_box_id: string | null; mode: string | null }>(
          `select e.damaged, h.cash_box_id, h.mode
             from rksv_entries e
             left join rksv_chains h on h.business_id = e.business_id and h.device_id = e.device_id and h.chain = e.chain
            where e.receipt_id = $1`,
          [id],
        )
      ).rows[0];

      // v: 2 bringt die Liste `payments`, v: 1 eine Zahlung `payment` (oder keine): die wird Stelle 0 ohne Trinkgeld.
      const payments = Array.isArray(r.payments)
        ? [...r.payments].sort((x, y) => Number(x.position) - Number(y.position))
        : r.payment
          ? [{ ...r.payment, position: 0, tipCents: 0, tipStaffName: null }]
          : [];
      return {
        ...head(r),
        goodsCents: r.goods_cents,
        depositCents: r.deposit_cents,
        lines: lines.map((l) => ({
          position: l.position,
          itemId: l.item_id,
          name: l.name,
          info: l.info,
          unitPriceCents: l.unit_price_cents,
          quantity: l.quantity,
          unitDepositCents: l.unit_deposit_cents,
          options: l.options.map((o) => ({ groupName: o.groupName, optionName: o.optionName, surchargeCents: o.surchargeCents })),
          discountCents: l.discount_cents,
          discount: discountOf(l.discount),
        })),
        payments: payments.map((p) => ({
          position: p.position,
          kind: p.kind,
          amountCents: p.amountCents,
          givenCents: p.givenCents,
          changeCents: p.changeCents,
          tipCents: p.tipCents ?? 0,
          tipStaffName: p.tipStaffName ?? null,
          provider: p.provider,
          providerTxCode: p.providerTxCode ?? null,
          cardScheme: p.cardScheme,
          cardLast4: p.cardLast4,
          // Ab v: 3 bei einer Gutschein-Zahlung: Code und was danach am Gutschein blieb. Die Kennung bleibt am Server.
          voucherCode: p.voucherCode ?? null,
          voucherBalanceAfterCents: p.voucherBalanceAfterCents ?? null,
        })),
        // Die auf diesem Bon verkauften Gutscheine (ab v: 3), beim Storno mit negativem Wert.
        vouchers: (r.vouchers ?? []).map((v) => ({ code: v.code, valueCents: v.valueCents, linePosition: v.linePosition })),
        tipCents: r.tip_cents,
        discountCents: r.discount_cents,
        discount: discountOf(r.discount),
        voidsReceiptId: r.voids_receipt_id,
        voidedByReceiptId: r.voided_by,
        rksv: rksv ? { cashBoxId: rksv.cash_box_id, damaged: rksv.damaged, probe: rksv.mode !== 'live' } : null,
      };
    });
  });
}
