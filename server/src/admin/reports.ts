import type { FastifyInstance } from 'fastify';
import { isUuid, requireProvider } from '../auth/guards.js';
import { withSystem } from '../db/tenant.js';
import { ApiError } from '../errors.js';

const PAGE_SIZE = 50;

/** `received_at::text` aus PostgreSQL: `2026-11-19 08:00:00.123456+00`. Der Text geht unverändert hin und zurück, damit keine Mikrosekunde verloren geht. */
const TIME_TEXT = /^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}(\.\d{1,6})?[+-]\d{2}(:\d{2})?$/;

const invalid = () => new ApiError(422, 'before_invalid', 'Die Marke für die nächste Seite ist unlesbar.');

/** Die Marke ist `<received_at als Text>_<id>`. Sie ist nur dazu da, an `next` der letzten Antwort zurückgegeben zu werden. */
function parseMarker(raw: unknown): { at: string; id: string } | null {
  if (raw === undefined) return null;
  if (typeof raw !== 'string') throw invalid();
  const cut = raw.lastIndexOf('_');
  if (cut < 0) throw invalid();
  const at = raw.slice(0, cut);
  const id = raw.slice(cut + 1);
  if (!TIME_TEXT.test(at) || !isUuid(id)) throw invalid();
  return { at, id: id.toLowerCase() };
}

type Row = {
  id: string;
  business_name: string;
  register_name: string | null;
  source: string;
  kind: string;
  at: Date;
  app_version: string | null;
  device_model: string | null;
  count: number;
  content: unknown;
  received_text: string;
};

/** Die Liste aller Fehlerberichte für den Anbieter. Nach installAuth aufrufen. */
export function installReportRoutes(app: FastifyInstance): void {
  const { db } = app.deps;

  app.get('/api/admin/reports', async (req) => {
    requireProvider(req);
    const before = parseMarker((req.query as Record<string, unknown>).before);

    let rows: Row[];
    try {
      rows = await withSystem(db, async (c) => {
        const r = await c.query<Row>(
          `select id, business_name, register_name, source, kind, at, app_version, device_model, count, content,
                  received_at::text as received_text
             from list_reports($1, $2::timestamptz, $3::uuid)`,
          [PAGE_SIZE, before?.at ?? null, before?.id ?? null],
        );
        return r.rows;
      });
    } catch (err) {
      // 22xxx: ein Wert, den PostgreSQL nicht als Zeit liest (zum Beispiel der 31. Februar).
      if (before && /^22/.test((err as { code?: string }).code ?? '')) throw invalid();
      throw err;
    }

    const last = rows[rows.length - 1];
    return {
      reports: rows.map((r) => ({
        id: r.id,
        businessName: r.business_name,
        registerName: r.register_name,
        source: r.source,
        kind: r.kind,
        at: r.at.toISOString(),
        appVersion: r.app_version,
        deviceModel: r.device_model,
        count: r.count,
        content: r.content,
      })),
      next: rows.length === PAGE_SIZE && last ? `${last.received_text}_${last.id}` : null,
    };
  });
}
