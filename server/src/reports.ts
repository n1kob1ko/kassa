import { randomUUID } from 'node:crypto';
import type { FastifyBaseLogger } from 'fastify';
import type pg from 'pg';

/** Eine Zeile `reports` mit `source = 'server'`, wenn der Server bei einer Sendung etwas Auffälliges bemerkt. */
export type ServerReport = {
  businessId: string;
  /** Ohne Kassa (null) steht die Nulluuid. */
  registerId: string | null;
  kind: string;
  content: object;
};

export const NO_REGISTER = '00000000-0000-0000-0000-000000000000';

/** Höchstens so viele Berichte des Servers pro Betrieb, Kassa, Art und Wiener Tag. Was darüber kommt, steht nur im Protokoll. */
export const MAX_SERVER_REPORTS_PER_DAY = 50;

/**
 * Schreibt den Bericht in die Datenbank und eine Zeile ins Protokoll des Servers. Berichte werden nie geändert,
 * jeder Aufruf legt eine neue Zeile an, bis zur Grenze pro Tag. In `content` gehört kein Geräte-Schlüssel und kein ganzer Bon.
 */
export async function writeServerReport(
  c: pg.PoolClient,
  r: ServerReport,
  at: Date,
  log?: Pick<FastifyBaseLogger, 'warn'>,
): Promise<void> {
  const registerId = r.registerId ?? NO_REGISTER;
  const used = await c.query<{ n: number }>(
    `select count(*)::int as n from reports
      where business_id = $1 and register_id = $2 and source = 'server' and kind = $3
        and (at at time zone 'Europe/Vienna')::date = ($4::timestamptz at time zone 'Europe/Vienna')::date`,
    [r.businessId, registerId, r.kind, at],
  );
  const line = { businessId: r.businessId, registerId: r.registerId, report: r.kind, content: r.content };
  if (used.rows[0]!.n >= MAX_SERVER_REPORTS_PER_DAY) {
    log?.warn(line, 'Bericht des Servers über der Grenze');
    return;
  }
  await c.query(
    `insert into reports (business_id, id, register_id, source, kind, at, count, content)
     values ($1, $2, $3, 'server', $4, $5, 1, $6)`,
    [r.businessId, randomUUID(), registerId, r.kind, at, JSON.stringify(r.content)],
  );
  log?.warn(line, 'Bericht des Servers');
}
