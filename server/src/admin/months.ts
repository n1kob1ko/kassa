import type { FastifyInstance } from 'fastify';
import type pg from 'pg';
import { requireBusinessAccess } from '../auth/guards.js';
import { withBusiness } from '../db/tenant.js';
import { DEPOSIT_RETURN_ITEM_PREFIX, VOUCHER_SALE_ITEM_ID } from '../device/push_schema.js';
import { ApiError } from '../errors.js';
import { loadTimeZone } from './overview.js';
import { GROSS_COLUMNS, RATES, sumTaxLines, taxLinesOf } from './tax.js';
import { tipsByStaff } from './tips.js';

// Monatsabrechnung wie app/lib/data/period_report_repository.dart. Monatsgrenzen und Tage gelten in der Zeitzone
// des Betriebs und werden in PostgreSQL gerechnet. Gezählt werden Verkäufe und Stornos; gibt es einen echten Bon
// (nicht is_test), zählen nur echte. Der laufende Monat und alles danach fehlt immer.

const MONTH = /^\d{4}-(0[1-9]|1[0-2])$/;
const NOT_FOUND = 'Diese Abrechnung gibt es nicht.';

/**
 * Ob ein Bon bar bzw. mit Karte bezahlt hat, aus den Spalten von receipts (mit Vorsatz `p`, etwa `r.`). `mixed` ohne
 * Gutschein ist bar und Karte (v: 2); mit Gutschein (v: 3) zählt die Art, die einen Betrag hat. Wie `paymentKind` am Tablet.
 */
export const hasCash = (p = '') =>
  `(${p}payment_kind = 'cash' or (${p}payment_kind = 'mixed' and (${p}voucher_cents = 0 or ${p}cash_cents <> 0)))`;
export const hasCard = (p = '') =>
  `(${p}payment_kind = 'card' or (${p}payment_kind = 'mixed' and (${p}voucher_cents = 0 or ${p}card_cents <> 0)))`;

/** Umsatz eines Bons: die Summe ohne verkaufte Gutscheine (Spalten von receipts mit Vorsatz `p`). */
export const revenueOf = (p = '') => `(${p}total_cents - ${p}voucher_sale_cents)`;

/**
 * Summe der Mengen der Zeilen eines Bons aus `receipts` (ohne Alias), deren Kennung `match` erfüllt. Nur für Bons, bei
 * denen `guard` gilt: alte Bons haben solche Zeilen nie, für sie wird nichts gelesen.
 */
const lineQuantity = (guard: string, match: string) =>
  `case when ${guard} then (select coalesce(sum(l.quantity), 0) from receipt_lines l
     where l.business_id = receipts.business_id and l.receipt_id = receipts.id and ${match}) else 0 end`;

/** Summen über Bons aus `receipts` (ohne Alias) in `group by`; Verkauf zählt eins hoch, Storno eins herunter. Auch für den Tag (days.ts). */
export const RECEIPT_SUMS = `
  coalesce(sum(case when kind = 'voided' then -1 else 1 end), 0)::float8 as count,
  coalesce(sum(case when kind = 'voided' then 1 else 0 end), 0)::float8 as void_count,
  coalesce(-sum(total_cents) filter (where kind = 'voided'), 0)::float8 as voided,
  coalesce(sum(${revenueOf()}), 0)::float8 as revenue,
  coalesce(sum(case when ${hasCash()} then case when kind = 'voided' then -1 else 1 end else 0 end), 0)::float8 as cash_count,
  coalesce(sum(case when payment_kind is null or ${hasCard()} then case when kind = 'voided' then -1 else 1 end else 0 end), 0)::float8 as card_count,
  coalesce(sum(cash_cents), 0)::float8 as cash,
  coalesce(sum(card_cents), 0)::float8 as card,
  coalesce(sum(deposit_cents), 0)::float8 as deposit,
  coalesce(sum(tip_cents), 0)::float8 as tip,
  coalesce(sum(discount_cents), 0)::float8 as discount,
  coalesce(sum(case when discount_cents <> 0 then case when kind = 'voided' then -1 else 1 end else 0 end), 0)::float8 as discount_count,
  coalesce(sum(voucher_cents), 0)::float8 as voucher_paid,
  coalesce(sum(voucher_sale_cents), 0)::float8 as voucher_sold,
  coalesce(sum(${lineQuantity('voucher_sale_cents <> 0', `l.item_id = '${VOUCHER_SALE_ITEM_ID}'`)}), 0)::float8 as voucher_sold_count,
  coalesce(-sum(deposit_return_cents), 0)::float8 as deposit_return,
  coalesce(sum(${lineQuantity('deposit_return_cents <> 0', `starts_with(l.item_id, '${DEPOSIT_RETURN_ITEM_PREFIX}')`)}), 0)::float8 as deposit_return_count`;

export type ReceiptSums = {
  count: number;
  void_count: number;
  voided: number;
  revenue: number;
  cash_count: number;
  card_count: number;
  cash: number;
  card: number;
  deposit: number;
  tip: number;
  discount: number;
  discount_count: number;
  voucher_paid: number;
  voucher_sold: number;
  voucher_sold_count: number;
  deposit_return: number;
  deposit_return_count: number;
};

/**
 * Die Felder aus Stufe 1b, wie am Tablet (`ReceiptTally`): mit Gutschein bezahlt, verkaufte Gutscheine (Anzahl, Summe)
 * und Pfand zurück (Stück, Summe positiv). Ein Storno zieht ab. Bons in v: 1 und v: 2 haben hier überall 0.
 */
export function voucherFigures(s: ReceiptSums) {
  return {
    voucherPaidCents: s.voucher_paid,
    voucherSoldCount: s.voucher_sold_count,
    voucherSoldCents: s.voucher_sold,
    depositReturnCount: s.deposit_return_count,
    depositReturnCents: s.deposit_return,
  };
}

/** Die neuen Felder von Tag und Abrechnung: Rabatte, Karten-Trinkgeld und was am Kartenkonto ankommt. */
export function paymentFigures(s: ReceiptSums, tips: { staffName: string; cents: number }[]) {
  return {
    discountCount: s.discount_count,
    discountCents: s.discount,
    cardTipCents: s.tip,
    cardAccountCents: s.card + s.tip,
    tipsByStaff: tips,
  };
}

/** Brutto je Satz aus der Zeile einer Abfrage mit `sum(gross..._cents) as g20` usw. */
export const GROSS_SUMS = Object.entries(GROSS_COLUMNS)
  .map(([p, col]) => `coalesce(sum(l.${col}), 0)::float8 as g${p}`)
  .join(', ');
export function grossOf(row: Record<string, number>): Record<number, number> {
  return Object.fromEntries(RATES.map((p) => [p, row[`g${p}`] ?? 0]));
}

function previous(month: string): string {
  const [y, m] = month.split('-').map(Number) as [number, number];
  return m === 1 ? `${y - 1}-12` : `${y}-${String(m - 1).padStart(2, '0')}`;
}

function next(month: string): string {
  const [y, m] = month.split('-').map(Number) as [number, number];
  return m === 12 ? `${y + 1}-01` : `${y}-${String(m + 1).padStart(2, '0')}`;
}

/** Alle Monate von `from` bis `to`, aufsteigend. */
function monthsBetween(from: string, to: string): string[] {
  const out: string[] = [];
  for (let m = from; m <= to; m = next(m)) out.push(m);
  return out;
}

type Scope = { tz: string; real: boolean; current: string; first: string | null; last: string };

/** Zeitzone, ob es echte Bons gibt, der laufende Monat und der Bereich, den es zu rechnen gibt. */
async function loadScope(c: pg.PoolClient, businessId: string, log: Parameters<typeof loadTimeZone>[2], at: Date): Promise<Scope> {
  const tz = await loadTimeZone(c, businessId, log);
  const real = (
    await c.query<{ real: boolean; current: string }>(
      `select exists (select 1 from receipts where not is_test) as real,
              to_char(date_trunc('month', $1::timestamptz at time zone $2), 'YYYY-MM') as current`,
      [at, tz],
    )
  ).rows[0]!;
  const first = (
    await c.query<{ first: string | null }>(
      `select to_char(date_trunc('month', min(created_at) at time zone $1), 'YYYY-MM') as first
         from receipts where kind in ('sale', 'voided') and (not $2 or not is_test)`,
      [tz, real.real],
    )
  ).rows[0]!.first;
  const last = previous(real.current);
  return { tz, real: real.real, current: real.current, first: first !== null && first <= last ? first : null, last };
}

const COUNTED = `kind in ('sale', 'voided') and (not $2 or not is_test)`;

/** Adressen der Monatsabrechnung. Nach installAuth aufrufen. */
export function installMonthRoutes(app: FastifyInstance): void {
  const { db, now } = app.deps;

  app.get<{ Params: { b: string } }>('/api/admin/businesses/:b/months', async (req) => {
    await requireBusinessAccess(req, req.params.b);
    const businessId = req.params.b.toLowerCase();
    return withBusiness(
      db,
      businessId,
      async (c) => {
        const scope = await loadScope(c, businessId, req.log, now());
        const nextAvailable = `${next(scope.current)}-01`;
        if (scope.first === null) return { testMode: !scope.real, nextAvailable, months: [] };
        const sums = await monthSums(c, scope, scope.first, scope.last);
        const months = monthsBetween(scope.first, scope.last)
          .reverse()
          .map((month) => ({ month, receiptCount: sums.get(month)?.count ?? 0, revenueCents: sums.get(month)?.revenue ?? 0 }));
        return { testMode: !scope.real, nextAvailable, months };
      },
      { repeatableRead: true },
    );
  });

  app.get<{ Params: { b: string } }>('/api/admin/businesses/:b/months/summary', async (req) => {
    await requireBusinessAccess(req, req.params.b);
    const businessId = req.params.b.toLowerCase();
    const { from, to } = req.query as { from?: unknown; to?: unknown };
    if (typeof from !== 'string' || typeof to !== 'string' || !MONTH.test(from) || !MONTH.test(to) || to < from) {
      throw new ApiError(422, 'period_invalid', 'Der Zeitraum ist unbekannt.');
    }
    return withBusiness(
      db,
      businessId,
      async (c) => {
        const scope = await loadScope(c, businessId, req.log, now());
        if (scope.first === null || from < scope.first || to > scope.last) throw new ApiError(404, 'not_found', NOT_FOUND);
        const months = monthsBetween(from, to);
        const sums = await monthSums(c, scope, from, to);
        const grossByMonth = await monthGross(c, scope, from, to);

        const total: ReceiptSums = {
          count: 0, void_count: 0, voided: 0, revenue: 0, cash_count: 0, card_count: 0, cash: 0, card: 0, deposit: 0,
          tip: 0, discount: 0, discount_count: 0, voucher_paid: 0, voucher_sold: 0, voucher_sold_count: 0, deposit_return: 0,
          deposit_return_count: 0,
        };
        for (const s of sums.values()) for (const k of Object.keys(total) as (keyof ReceiptSums)[]) total[k] += s[k];
        // Steuer je Monat gerechnet, dann über die Monate addiert.
        const taxLines = sumTaxLines(months.map((m) => taxLinesOf(grossByMonth.get(m) ?? {})));
        const tips = await tipsByStaff(
          c,
          `r.kind in ('sale', 'voided') and (not $2 or not r.is_test) and to_char(r.created_at at time zone $1, 'YYYY-MM') between $3 and $4`,
          [scope.tz, scope.real, from, to],
        );

        let rows: { key: string; receiptCount: number; revenueCents: number }[];
        if (from === to) {
          rows = (
            await c.query<{ day: string; count: number; revenue: number }>(
              `select to_char(created_at at time zone $1, 'YYYY-MM-DD') as day,
                      sum(case when kind = 'voided' then -1 else 1 end)::float8 as count, sum(${revenueOf()})::float8 as revenue
                 from receipts
                where ${COUNTED} and to_char(created_at at time zone $1, 'YYYY-MM') = $3
                group by 1 order by 1`,
              [scope.tz, scope.real, from],
            )
          ).rows.map((r) => ({ key: r.day, receiptCount: r.count, revenueCents: r.revenue }));
        } else {
          rows = months.map((m) => ({ key: m, receiptCount: sums.get(m)?.count ?? 0, revenueCents: sums.get(m)?.revenue ?? 0 }));
        }

        return {
          from,
          to,
          testMode: !scope.real,
          receiptCount: total.count,
          cashReceiptCount: total.cash_count,
          cardReceiptCount: total.card_count,
          voidCount: total.void_count,
          voidedCents: total.voided,
          revenueCents: total.revenue,
          cashRevenueCents: total.cash,
          cardRevenueCents: total.card,
          depositCents: total.deposit,
          ...paymentFigures(total, tips),
          ...voucherFigures(total),
          taxLines,
          rows,
        };
      },
      { repeatableRead: true },
    );
  });
}

/** Summen je Monat ('JJJJ-MM') von `from` bis `to`; Monate ohne Bon fehlen. */
async function monthSums(c: pg.PoolClient, scope: Scope, from: string, to: string): Promise<Map<string, ReceiptSums>> {
  const rows = (
    await c.query<ReceiptSums & { month: string }>(
      `select to_char(created_at at time zone $1, 'YYYY-MM') as month, ${RECEIPT_SUMS}
         from receipts
        where ${COUNTED} and to_char(created_at at time zone $1, 'YYYY-MM') between $3 and $4
        group by 1`,
      [scope.tz, scope.real, from, to],
    )
  ).rows;
  return new Map(rows.map((r) => [r.month, r]));
}

/** Brutto je Satz und Monat aus den Zeilen der gezählten Bons. */
async function monthGross(c: pg.PoolClient, scope: Scope, from: string, to: string): Promise<Map<string, Record<number, number>>> {
  const rows = (
    await c.query<Record<string, number> & { month: string }>(
      `select to_char(r.created_at at time zone $1, 'YYYY-MM') as month, ${GROSS_SUMS}
         from receipts r join receipt_lines l on l.business_id = r.business_id and l.receipt_id = r.id
        where r.kind in ('sale', 'voided') and (not $2 or not r.is_test)
          and to_char(r.created_at at time zone $1, 'YYYY-MM') between $3 and $4
        group by 1`,
      [scope.tz, scope.real, from, to],
    )
  ).rows;
  return new Map(rows.map((r) => [r.month as unknown as string, grossOf(r)]));
}
