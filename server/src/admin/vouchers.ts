import type { FastifyInstance } from 'fastify';
import type pg from 'pg';
import { isUuid, requireBusinessAccess } from '../auth/guards.js';
import { withBusiness } from '../db/tenant.js';
import { ApiError } from '../errors.js';

// Gutscheine in der Verwaltung (Spec 5.5). Nur lesen: Gutscheine und Bewegungen entstehen allein mit den Bons der
// Tablets. Guthaben und Zustand folgen aus den Bewegungen, nach derselben Regel wie am Tablet (app/lib/domain/voucher.dart);
// beide prüfen gegen shared/fixtures/vouchers/states.json.

export type VoucherState = 'active' | 'empty' | 'voided' | 'overdrawn';

/**
 * Guthaben und Zustand aus den Bewegungen: überzogen unter 0; bei 0 storniert, wenn der Verkauf storniert ist, sonst
 * aufgebraucht; über 0 gültig. Gültig heißt also genau: Guthaben über 0.
 */
export function voucherStatus(movements: { kind: string; amountCents: number }[]): { balanceCents: number; state: VoucherState } {
  const balanceCents = movements.reduce((s, m) => s + m.amountCents, 0);
  let state: VoucherState = 'active';
  if (balanceCents < 0) state = 'overdrawn';
  else if (balanceCents === 0) state = movements.some((m) => m.kind === 'void_sale') ? 'voided' : 'empty';
  return { balanceCents, state };
}

/**
 * Summe der offenen Guthaben (über 0, wie "gültig" in [voucherStatus]) aller echten Gutscheine (`is_test` falsch), mit
 * den Bewegungen bis zum Ende des Monats [until] ('JJJJ-MM') in der Zeitzone [tz], ohne [until] mit allen. Eine Bewegung
 * ohne bekannten Gutschein zählt nicht: sein Übungs-Kennzeichen ist unbekannt.
 */
export async function openVoucherCents(c: pg.PoolClient, until?: { tz: string; month: string }): Promise<number> {
  const cut = until ? `and to_char(m.created_at at time zone $1, 'YYYY-MM') <= $2` : '';
  const r = await c.query<{ open: number }>(
    `select coalesce(sum(greatest(x.balance, 0)), 0)::float8 as open from (
       select sum(m.amount_cents) as balance
         from vouchers v join voucher_movements m on m.business_id = v.business_id and m.voucher_id = v.id
        where not v.is_test ${cut}
        group by v.id) x`,
    until ? [until.tz, until.month] : [],
  );
  return r.rows[0]!.open;
}

type VoucherRow = { id: string; code: string; created_at: Date; value_cents: number; is_test: boolean };
type MovementRow = { voucher_id: string; kind: string; amount_cents: number };

const notFound = () => new ApiError(404, 'not_found', 'Das gibt es nicht.');

/** Ein Gutschein mit vollem Code, Guthaben und Zustand. */
function toWire(v: VoucherRow, movements: { kind: string; amountCents: number }[]) {
  return { id: v.id, code: v.code, createdAt: v.created_at.toISOString(), valueCents: v.value_cents, ...voucherStatus(movements), isTest: v.is_test };
}

/**
 * GET /api/admin/businesses/:b/vouchers und …/vouchers/:id. Rollen wie bei den Bons; ein anderer Betrieb sieht nichts
 * (404, Zeilen-Schutz). Nach installAuth aufrufen.
 */
export function installVoucherRoutes(app: FastifyInstance): void {
  const { db } = app.deps;

  app.get<{ Params: { b: string } }>('/api/admin/businesses/:b/vouchers', async (req) => {
    await requireBusinessAccess(req, req.params.b);
    const businessId = req.params.b.toLowerCase();
    return withBusiness(
      db,
      businessId,
      async (c) => {
        const vouchers = (
          await c.query<VoucherRow>('select id, code, created_at, value_cents, is_test from vouchers order by created_at desc, id')
        ).rows;
        const byVoucher = new Map<string, { kind: string; amountCents: number }[]>();
        for (const m of (await c.query<MovementRow>('select voucher_id, kind, amount_cents from voucher_movements')).rows) {
          const list = byVoucher.get(m.voucher_id) ?? [];
          list.push({ kind: m.kind, amountCents: m.amount_cents });
          byVoucher.set(m.voucher_id, list);
        }
        const out = vouchers.map((v) => toWire(v, byVoucher.get(v.id) ?? []));
        // Übungs-Gutscheine stehen in keiner Summe; überzogene, aufgebrauchte und stornierte haben kein offenes Guthaben.
        const openCents = out.filter((v) => !v.isTest && v.state === 'active').reduce((s, v) => s + v.balanceCents, 0);
        return { openCents, vouchers: out };
      },
      { repeatableRead: true },
    );
  });

  app.get<{ Params: { b: string; id: string } }>('/api/admin/businesses/:b/vouchers/:id', async (req) => {
    await requireBusinessAccess(req, req.params.b);
    if (!isUuid(req.params.id)) throw notFound();
    const businessId = req.params.b.toLowerCase();
    const voucherId = req.params.id.toLowerCase();
    return withBusiness(
      db,
      businessId,
      async (c) => {
        const v = (
          await c.query<VoucherRow>('select id, code, created_at, value_cents, is_test from vouchers where id = $1', [voucherId])
        ).rows[0];
        if (!v) throw notFound();
        const rows = (
          await c.query<{ kind: string; amount_cents: number; created_at: Date; receipt_id: string; number: number; register_name: string }>(
            `select m.kind, m.amount_cents, m.created_at, m.receipt_id, r.number, coalesce(g.name, '') as register_name
               from voucher_movements m
               join receipts r on r.business_id = m.business_id and r.id = m.receipt_id
               left join registers g on g.business_id = r.business_id and g.id = r.register_id
              where m.voucher_id = $1
              order by m.created_at, m.change_seq`,
            [voucherId],
          )
        ).rows;
        const movements = rows.map((m) => ({
          kind: m.kind,
          amountCents: m.amount_cents,
          createdAt: m.created_at.toISOString(),
          receiptId: m.receipt_id,
          receiptNumber: m.number,
          registerName: m.register_name,
        }));
        return { ...toWire(v, movements), movements };
      },
      { repeatableRead: true },
    );
  });
}
