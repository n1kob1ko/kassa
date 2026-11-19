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

/**
 * Schreibt den Bericht in die Datenbank und eine Zeile ins Protokoll des Servers. Berichte werden nie geändert,
 * jeder Aufruf legt eine neue Zeile an. In `content` gehört kein Geräte-Schlüssel und kein ganzer Bon.
 */
export async function writeServerReport(
  c: pg.PoolClient,
  r: ServerReport,
  at: Date,
  log?: Pick<FastifyBaseLogger, 'warn'>,
): Promise<void> {
  await c.query(
    `insert into reports (business_id, id, register_id, source, kind, at, count, content)
     values ($1, $2, $3, 'server', $4, $5, 1, $6)`,
    [r.businessId, randomUUID(), r.registerId ?? NO_REGISTER, r.kind, at, JSON.stringify(r.content)],
  );
  log?.warn({ businessId: r.businessId, registerId: r.registerId, report: r.kind, content: r.content }, 'Bericht des Servers');
}
