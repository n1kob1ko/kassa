import type pg from 'pg';

const byText = (a: string, b: string) => (a < b ? -1 : a > b ? 1 : 0);

/**
 * Karten-Trinkgeld je Person aus `payload.payments` der Bons, die `where` trifft (Alias `r`). Nach Name sortiert,
 * Zeilen mit 0 fehlen. Gruppiert wird nach `tipStaffId`, der Name ist der des spätesten Bons. Ein Bon in `v: 1` hat
 * keine Liste `payments` und damit kein Trinkgeld.
 */
export async function tipsByStaff(c: pg.PoolClient, where: string, params: unknown[]): Promise<{ staffName: string; cents: number }[]> {
  const rows = (
    await c.query<{ staff_name: string | null; cents: number }>(
      `select (array_agg(p->>'tipStaffName' order by r.created_at desc, r.id desc))[1] as staff_name,
              sum((p->>'tipCents')::int)::float8 as cents
         from receipts r
        cross join lateral jsonb_array_elements(
                case when jsonb_typeof(r.payload->'payments') = 'array' then r.payload->'payments' else '[]'::jsonb end) p
        where ${where} and coalesce((p->>'tipCents')::int, 0) <> 0
        group by p->>'tipStaffId'
       having sum((p->>'tipCents')::int) <> 0`,
      params,
    )
  ).rows;
  return rows
    .map((r) => ({ staffName: r.staff_name ?? '', cents: r.cents }))
    .sort((a, b) => byText(a.staffName, b.staffName) || a.cents - b.cents);
}
