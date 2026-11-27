import type { FastifyInstance, FastifyBaseLogger } from 'fastify';
import type pg from 'pg';
import { z } from 'zod';
import { requireBusinessAccess } from '../auth/guards.js';
import { withBusiness } from '../db/tenant.js';
import { DEPOSIT_RETURN_ITEM_PREFIX, VOUCHER_SALE_ITEM_ID } from '../device/push_schema.js';
import { ApiError } from '../errors.js';
import { revenueOf } from './receipt_sql.js';

// Rechnet die Zahlen der Übersicht genau wie app/lib/data/stats_repository.dart. Kalendertage gelten in der
// Zeitzone des Betriebs und werden in PostgreSQL gerechnet (Sommerzeit), Summen sind ganze Cent.

const FALLBACK_ZONE = 'Europe/Vienna';
const OTHER_CATEGORY = 'Sonstiges';
const DEPOSIT_NAME = 'Pfand';
const TOP_ITEMS = 5;

const DAYS = { today: 1, days7: 7, days30: 30 } as const;
const query = z.object({ range: z.enum(['today', 'days7', 'days30']).default('today') });

/** Die Zeitzone des Betriebs. Ein Name, den PostgreSQL nicht kennt, ersetzt Europe/Vienna (und steht im Protokoll). */
export async function loadTimeZone(c: pg.PoolClient, businessId: string, log: FastifyBaseLogger): Promise<string> {
  const r = await c.query<{ time_zone: string; known: boolean }>(
    `select b.time_zone, exists (select 1 from pg_timezone_names n where n.name = b.time_zone) as known
       from businesses b where b.id = $1`,
    [businessId],
  );
  const row = r.rows[0];
  if (!row) return FALLBACK_ZONE;
  if (!row.known) {
    log.warn({ businessId, timeZone: row.time_zone }, 'unbekannte Zeitzone, Europe/Vienna gilt');
    return FALLBACK_ZONE;
  }
  return row.time_zone;
}

type Bucket = { label: string; start: string; cents: number };

const byText = (a: string, b: string) => (a < b ? -1 : a > b ? 1 : 0);

/** Adressen der Umsätze. Nach installAuth aufrufen. */
export function installOverviewRoutes(app: FastifyInstance): void {
  const { db, now } = app.deps;

  app.get<{ Params: { b: string } }>('/api/admin/businesses/:b/overview', async (req) => {
    await requireBusinessAccess(req, req.params.b);
    const businessId = req.params.b.toLowerCase();
    const parsed = query.safeParse(req.query);
    if (!parsed.success) throw new ApiError(422, 'range_invalid', 'Der Zeitraum ist unbekannt.');
    const range = parsed.data.range;
    const days = DAYS[range];
    const at = now();

    return withBusiness(
      db,
      businessId,
      async (c) => {
        const tz = await loadTimeZone(c, businessId, req.log);

        const win = (
          await c.query<{
            today: string;
            now_hour: number;
            from_at: Date;
            prev_from: Date;
            prev_to: Date;
          }>(
            `with w as (
               select ($1::timestamptz at time zone $2) as local_now,
                      date_trunc('day', $1::timestamptz at time zone $2) as today
             ), r as (
               select local_now, today,
                      today - make_interval(days => $3 - 1) as from_local,
                      case when $3 = 1 then today - interval '7 days'
                           else today - make_interval(days => 2 * $3 - 1) end as prev_from_local
                 from w
             )
             select to_char(today, 'YYYY-MM-DD') as today,
                    extract(hour from local_now)::int as now_hour,
                    from_local at time zone $2 as from_at,
                    prev_from_local at time zone $2 as prev_from,
                    (case when $3 = 1 then local_now - interval '7 days'
                          else from_local - interval '1 microsecond' end) at time zone $2 as prev_to
               from r`,
            [at, tz, days],
          )
        ).rows[0]!;

        // Irgendein Bon des Betriebs (jede Zeit, jede Art, auch Testbons): ohne ihn zeigt die Seite den leeren Zustand.
        const { has_receipts: hasReceipts, real } = (
          await c.query<{ has_receipts: boolean; real: boolean }>(
            `select exists (select 1 from receipts) as has_receipts, exists (select 1 from receipts where not is_test) as real`,
          )
        ).rows[0]!;

        const rows = (
          await c.query<{
            id: string;
            kind: string;
            revenue_cents: number;
            deposit_cents: number;
            cash_cents: number;
            card_cents: number;
            voucher_cents: number;
            local_day: string;
            local_hour: number;
            in_current: boolean;
            in_previous: boolean;
          }>(
            `select id, kind, ${revenueOf()} as revenue_cents, deposit_cents, cash_cents, card_cents, voucher_cents,
                    to_char(created_at at time zone $1, 'YYYY-MM-DD') as local_day,
                    extract(hour from created_at at time zone $1)::int as local_hour,
                    created_at >= $2 as in_current,
                    created_at <= $4 as in_previous
               from receipts
              where created_at >= $3 and created_at <= $5
                and kind in ('sale', 'voided')
                and (not $6 or not is_test)
              order by created_at, number, id`,
            [tz, win.from_at, win.prev_from, win.prev_to, at, real],
          )
        ).rows;

        const current = rows.filter((r) => r.in_current);
        // Umsatz ist überall ohne verkaufte Gutscheine: auch im Vergleich und in den Balken.
        const previousRevenue = rows.filter((r) => r.in_previous).reduce((s, r) => s + r.revenue_cents, 0);

        let revenue = 0;
        let receiptCount = 0;
        let voidCount = 0;
        let cash = 0;
        let card = 0;
        let voucher = 0;
        let deposit = 0;
        for (const r of current) {
          revenue += r.revenue_cents;
          deposit += r.deposit_cents;
          if (r.kind === 'voided') {
            receiptCount -= 1;
            voidCount += 1;
          } else {
            receiptCount += 1;
          }
          // Aus den Zahlungen: ein gemischter Bon zählt mit seinem Teil zu bar und mit dem Rest zur Karte.
          cash += r.cash_cents;
          card += r.card_cents;
          voucher += r.voucher_cents;
        }

        // Balken
        let buckets: Bucket[] = [];
        if (range === 'today') {
          if (current.length > 0) {
            const first = current[0]!.local_hour;
            const starts = await c.query<{ h: number; start: Date }>(
              `select h, (($1::date + h * interval '1 hour') at time zone $2) as start
                 from generate_series($3::int, $4::int) h order by h`,
              [win.today, tz, first, win.now_hour],
            );
            buckets = starts.rows.map((s) => ({
              label: String(s.h),
              start: s.start.toISOString(),
              cents: current.filter((r) => r.local_hour === s.h).reduce((sum, r) => sum + r.revenue_cents, 0),
            }));
          }
        } else {
          const starts = await c.query<{ day: string; start: Date }>(
            `select to_char(d, 'YYYY-MM-DD') as day, (d at time zone $2) as start
               from generate_series($1::timestamp - make_interval(days => $3 - 1), $1::timestamp, interval '1 day') d
              order by d`,
            [win.today, tz, days],
          );
          buckets = starts.rows.map((s) => {
            const [, m, d] = s.day.split('-').map(Number);
            return {
              label: `${d}.${m}.`,
              start: s.start.toISOString(),
              cents: current.filter((r) => r.local_day === s.day).reduce((sum, r) => sum + r.revenue_cents, 0),
            };
          });
        }

        // Artikel und Kategorien aus den Zeilen. Später gesendete Bons geben den Namen vor (wie am Tablet). Der Betrag
        // einer Zeile ist die Summe ihrer Beträge je Satz: der Wert nach Rabatt. Gutschein-Zeilen und "Pfand zurück" sind
        // keine Artikel: sie fehlen hier (das zurückgegebene Pfand steht in der Zeile Pfand).
        const order = new Map(current.map((r, i) => [r.id, i]));
        const lines = current.length
          ? (
              await c.query<{ receipt_id: string; item_id: string; name: string; cents: number; quantity: number }>(
                `select receipt_id, item_id, name, quantity,
                        (gross20_cents + gross10_cents + gross13_cents + gross0_cents + gross19_cents)::float8 as cents
                   from receipt_lines
                  where receipt_id = any($1::uuid[]) and item_id <> $2 and not starts_with(item_id, $3)
                  order by position`,
                [current.map((r) => r.id), VOUCHER_SALE_ITEM_ID, DEPOSIT_RETURN_ITEM_PREFIX],
              )
            ).rows
          : [];
        lines.sort((a, b) => order.get(a.receipt_id)! - order.get(b.receipt_id)!);

        const names = new Map<string, string>();
        const quantity = new Map<string, number>();
        const cents = new Map<string, number>();
        for (const l of lines) {
          names.set(l.item_id, l.name);
          quantity.set(l.item_id, (quantity.get(l.item_id) ?? 0) + l.quantity);
          cents.set(l.item_id, (cents.get(l.item_id) ?? 0) + l.cents);
        }
        const topItems = [...names.entries()]
          .filter(([id]) => quantity.get(id)! > 0)
          .map(([id, name]) => ({ name, quantity: quantity.get(id)!, cents: cents.get(id)! }))
          .sort((a, b) => b.quantity - a.quantity || b.cents - a.cents || byText(a.name, b.name))
          .slice(0, TOP_ITEMS);

        const categoryNames = new Map(
          (await c.query<{ id: string; name: string }>('select id, name from categories')).rows.map((r) => [r.id, r.name]),
        );
        const itemCategory = new Map(
          (await c.query<{ id: string; category_id: string }>('select id, category_id from items')).rows.map((r) => [r.id, r.category_id]),
        );
        const sums = new Map<string, number>();
        for (const l of lines) {
          const name = categoryNames.get(itemCategory.get(l.item_id) ?? '') ?? OTHER_CATEGORY;
          sums.set(name, (sums.get(name) ?? 0) + l.cents);
        }
        const byCategory = [...sums.entries()]
          .filter(([, v]) => v !== 0)
          .map(([name, v]) => ({ name, cents: v }))
          .sort((a, b) => b.cents - a.cents || byText(a.name, b.name));
        if (deposit !== 0) byCategory.push({ name: DEPOSIT_NAME, cents: deposit });

        return {
          range,
          testMode: !real,
          hasReceipts,
          revenueCents: revenue,
          previousRevenueCents: previousRevenue,
          receiptCount,
          voidCount,
          buckets,
          cashCents: cash,
          cardCents: card,
          voucherCents: voucher,
          topItems,
          byCategory,
        };
      },
      { repeatableRead: true },
    );
  });
}
