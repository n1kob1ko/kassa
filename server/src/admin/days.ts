import type { FastifyInstance } from 'fastify';
import { isUuid, requireBusinessAccess } from '../auth/guards.js';
import { withBusiness } from '../db/tenant.js';
import { ApiError } from '../errors.js';

const MAX_DAYS = 100;

type DayRow = {
  id: string;
  register_name: string;
  opened_at: Date;
  closed_at: Date | null;
  expected_cents: number | null;
  counted_cents: number | null;
  difference_cents: number | null;
  closed_by_name: string | null;
  opening_float_cents: number;
  left_in_drawer_cents: number | null;
};

const COLUMNS = `d.id, coalesce(g.name, '') as register_name, d.opened_at, d.closed_at, d.expected_cents, d.counted_cents,
  d.difference_cents, d.closed_by_name, d.opening_float_cents, d.left_in_drawer_cents`;
/** Was zum Umsatz eines Tages zählt: Verkäufe und Stornos (mit negativem Betrag), keine Sonderbelege. */
const REVENUE_KINDS = `kind in ('sale', 'voided')`;
const FROM = `from business_days d left join registers g on g.business_id = d.business_id and g.id = d.register_id`;

function head(r: DayRow) {
  return {
    id: r.id,
    registerName: r.register_name,
    openedAt: r.opened_at.toISOString(),
    closedAt: r.closed_at ? r.closed_at.toISOString() : null,
    expectedCents: r.expected_cents,
    countedCents: r.counted_cents,
    differenceCents: r.difference_cents,
    closedByName: r.closed_by_name,
  };
}

/** Adressen der Tage (nur lesen). Nach installAuth aufrufen. */
export function installDayRoutes(app: FastifyInstance): void {
  const { db } = app.deps;

  app.get<{ Params: { b: string } }>('/api/admin/businesses/:b/days', async (req) => {
    await requireBusinessAccess(req, req.params.b);
    const businessId = req.params.b.toLowerCase();
    return withBusiness(db, businessId, async (c) => {
      // Umsatz je Tag in einer Abfrage, gerechnet wie im Detail (REVENUE_KINDS).
      const rows = (
        await c.query<DayRow & { revenue_cents: number }>(
          `select ${COLUMNS}, coalesce(t.revenue, 0)::int as revenue_cents ${FROM}
             left join (select business_id, business_day_id, sum(total_cents) as revenue
                          from receipts where ${REVENUE_KINDS} group by business_id, business_day_id) t
               on t.business_id = d.business_id and t.business_day_id = d.id
            order by d.opened_at desc, d.id desc limit $1`,
          [MAX_DAYS],
        )
      ).rows;
      return { days: rows.map((r) => ({ ...head(r), revenueCents: r.revenue_cents })) };
    });
  });

  app.get<{ Params: { b: string; id: string } }>('/api/admin/businesses/:b/days/:id', async (req) => {
    await requireBusinessAccess(req, req.params.b);
    const businessId = req.params.b.toLowerCase();
    if (!isUuid(req.params.id)) throw new ApiError(404, 'not_found', 'Das gibt es nicht.');
    const id = req.params.id.toLowerCase();
    return withBusiness(db, businessId, async (c) => {
      const day = (await c.query<DayRow>(`select ${COLUMNS} ${FROM} where d.id = $1`, [id])).rows[0];
      if (!day) throw new ApiError(404, 'not_found', 'Das gibt es nicht.');
      const movements = (
        await c.query<{ kind: string; amount_cents: number; reason: string | null; created_at: Date; staff_name: string }>(
          `select kind, amount_cents, reason, created_at, staff_name from cash_movements
            where business_day_id = $1 order by created_at, id`,
          [id],
        )
      ).rows;
      // Wie in der Übersicht: Verkäufe zählen eins hoch, Stornos eins herunter, Sonderbelege zählen nicht.
      const totals = (
        await c.query<{ count: number; revenue: number }>(
          `select coalesce(sum(case when kind = 'voided' then -1 else 1 end), 0)::int as count,
                  coalesce(sum(total_cents), 0)::int as revenue
             from receipts where business_day_id = $1 and ${REVENUE_KINDS}`,
          [id],
        )
      ).rows[0]!;
      return {
        ...head(day),
        openingFloatCents: day.opening_float_cents,
        leftInDrawerCents: day.left_in_drawer_cents,
        movements: movements.map((m) => ({
          kind: m.kind,
          amountCents: m.amount_cents,
          reason: m.reason,
          createdAt: m.created_at.toISOString(),
          staffName: m.staff_name,
        })),
        receiptCount: totals.count,
        revenueCents: totals.revenue,
      };
    });
  });
}
