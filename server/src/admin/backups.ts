import type { FastifyInstance } from 'fastify';
import { requireProvider } from '../auth/guards.js';
import { withSystem } from '../db/tenant.js';

type Row = { id: string; day: string; at: Date; size: string | null; error: string | null };

/** Der Stand der Sicherung für den Anbieter. Nach installAuth aufrufen. */
export function installBackupRoutes(app: FastifyInstance): void {
  const { db } = app.deps;

  app.get('/api/admin/backups/latest', async (req) => {
    requireProvider(req);
    const { good, bad } = await withSystem(db, async (c) => {
      const pick = (ok: boolean) =>
        c.query<Row>(
          `select day::text as day, coalesce(finished_at, started_at) as at, size, error, id
             from backups where ok = $1 order by id desc limit 1`,
          [ok],
        );
      const [g, b] = [await pick(true), await pick(false)];
      return { good: g.rows[0], bad: b.rows[0] };
    });
    // Ein Fehler zählt nur, solange danach keine Sicherung gelungen ist.
    const showError = bad !== undefined && (good === undefined || Number(bad.id) > Number(good.id));
    return {
      latest: good ? { day: good.day, finishedAt: good.at.toISOString(), size: Number(good.size ?? 0) } : null,
      lastError: showError ? { at: bad.at.toISOString(), error: bad.error ?? '' } : null,
    };
  });
}
