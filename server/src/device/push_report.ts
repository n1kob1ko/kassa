import type pg from 'pg';
import { z } from 'zod';
import type { EntryContext, EntryResult } from './push.js';
import { invalid } from './push_schema.js';

/** Höchstens so viele Berichte pro Kassa und Kalendertag (UTC) werden gespeichert. */
export const MAX_REPORTS_PER_DAY = 50;

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const short = z.string().max(200);

// Feste Felder, unbekannte werden verworfen (zod liest streng nur, was hier steht).
const reportEntry = z.object({
  report: z.object({
    id: z.string().regex(UUID),
    kind: z.enum(['error', 'device_test']),
    at: z.iso.datetime().transform((s) => new Date(s)),
    appVersion: short,
    androidVersion: short,
    deviceModel: short,
    count: z.number().int().min(1).max(1_000_000),
    error: z
      .object({ type: short, message: z.string().max(500).nullable(), stack: z.string().max(8000) })
      .nullable(),
    devices: z.array(z.object({ device: short, ok: z.boolean(), text: z.string().max(500) })).max(20).nullable(),
  }),
}).refine(
  ({ report: r }) => (r.kind === 'error' ? r.error !== null && r.devices === null : r.devices !== null && r.error === null),
);

/** Ein Bericht des Tablets. Der Inhalt ist nur das, was die festen Felder erlauben; ins Protokoll geht kein Text daraus. */
export async function handleReport(c: pg.PoolClient, ctx: EntryContext, body: unknown): Promise<EntryResult> {
  const parsed = reportEntry.safeParse(body);
  if (!parsed.success) return invalid(parsed.error);
  const r = parsed.data.report;
  const { businessId, id: registerId } = ctx.register;

  const known = await c.query('select 1 from reports where business_id = $1 and id = $2', [businessId, r.id]);
  if (known.rowCount === 1) return { status: 'duplicate' };

  // Berichte sind unveränderlich: die Grenze wird vor dem Eintragen gezählt, nie durch eine Änderung erzwungen.
  const today = new Date(Date.UTC(ctx.at.getUTCFullYear(), ctx.at.getUTCMonth(), ctx.at.getUTCDate()));
  const tomorrow = new Date(today.getTime() + 24 * 60 * 60 * 1000);
  const used = await c.query<{ n: number }>(
    `select count(*)::int as n from reports
      where business_id = $1 and register_id = $2 and source = 'device' and received_at >= $3 and received_at < $4`,
    [businessId, registerId, today, tomorrow],
  );
  if (used.rows[0]!.n >= MAX_REPORTS_PER_DAY) return { status: 'accepted' };

  await c.query(
    `insert into reports (business_id, id, register_id, source, kind, at, app_version, android_version, device_model, count, content, received_at)
     values ($1, $2, $3, 'device', $4, $5, $6, $7, $8, $9, $10, $11)`,
    [businessId, r.id, registerId, r.kind, r.at, r.appVersion, r.androidVersion, r.deviceModel, r.count,
      JSON.stringify({ error: r.error, devices: r.devices }), ctx.at],
  );
  ctx.log?.warn(
    { businessId, registerId, report: r.kind, appVersion: r.appVersion, ...(r.error ? { errorType: r.error.type } : {}) },
    'bericht',
  );
  return { status: 'accepted' };
}
