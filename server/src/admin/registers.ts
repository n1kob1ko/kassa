import { randomInt } from 'node:crypto';
import type { FastifyInstance } from 'fastify';
import { audit } from '../audit.js';
import { isUuid, requireBusinessAccess } from '../auth/guards.js';
import { sha256 } from '../auth/secrets.js';
import { withBusiness, withBusinessWrite } from '../db/tenant.js';
import { ApiError } from '../errors.js';

const MAX_NAME = 30;
const CODE_LIFETIME_MS = 15 * 60 * 1000;
const MAX_DRAWS = 5;
const CODE_SPACE = 100_000_000;

type RegisterRow = {
  id: string;
  name: string;
  paired_at: Date;
  last_seen_at: Date | null;
  app_version: string | null;
  device_model: string | null;
  blocked_at: Date | null;
};

const COLUMNS = 'id, name, paired_at, last_seen_at, app_version, device_model, blocked_at';

const notFound = () => new ApiError(404, 'not_found', 'Das gibt es nicht.');
const noChef = () => new ApiError(409, 'no_chef', 'Lege zuerst einen Chef mit PIN an.');
const badRequest = () => new ApiError(400, 'bad_request', 'Die Anfrage ist nicht in Ordnung.');

function toWire(r: RegisterRow) {
  return {
    id: r.id,
    name: r.name,
    pairedAt: r.paired_at.toISOString(),
    lastSeenAt: r.last_seen_at ? r.last_seen_at.toISOString() : null,
    appVersion: r.app_version,
    deviceModel: r.device_model,
    blocked: r.blocked_at !== null,
  };
}

function readName(body: unknown): string {
  if (typeof body !== 'object' || body === null || Array.isArray(body)) throw badRequest();
  const v = (body as Record<string, unknown>).name;
  const name = typeof v === 'string' ? v.trim() : '';
  if (name.length < 1 || name.length > MAX_NAME) {
    throw new ApiError(422, 'name_invalid', 'Der Name muss 1 bis 30 Zeichen lang sein.');
  }
  return name;
}

/** Adressen für Kopplungscodes und Kassen eines Betriebs. Nach installAuth aufrufen. */
export function installRegisterRoutes(app: FastifyInstance): void {
  const { db, now } = app.deps;
  const draw = app.deps.randomCode ?? (() => randomInt(0, CODE_SPACE));

  app.post<{ Params: { b: string } }>('/api/admin/businesses/:b/pairing-codes', async (req, reply) => {
    const user = await requireBusinessAccess(req, req.params.b);
    const businessId = req.params.b.toLowerCase();
    const name = readName(req.body);
    const at = now();
    const expiresAt = new Date(at.getTime() + CODE_LIFETIME_MS);
    const code = await withBusinessWrite(db, businessId, async (c) => {
      // Ohne Chef hätte das Tablet nach dem Koppeln niemanden, der sich anmelden kann.
      const chef = await c.query(`select 1 from staff where role = 'chef' and not archived limit 1`);
      if (chef.rowCount === 0) throw noChef();
      // Benutzte und abgelaufene Codes werden sonst nie entfernt und blockieren ihren Prüfwert für immer.
      await c.query('delete from pairing_codes where used_at is not null or expires_at <= $1', [at]);
      for (let i = 0; i < MAX_DRAWS; i++) {
        const candidate = String(draw()).padStart(8, '0');
        const r = await c.query(
          `insert into pairing_codes (code_hash, business_id, register_name, expires_at, created_by)
           values ($1, $2, $3, $4, $5) on conflict (code_hash) do nothing`,
          [sha256(candidate), businessId, name, expiresAt, user.id],
        );
        if (r.rowCount === 1) {
          // Der Code selbst gehört nicht in den Verlauf.
          await audit(c, { userId: user.id, businessId, action: 'pairing_code.create', detail: { name } }, at);
          return candidate;
        }
      }
      throw new Error('Kein freier Kopplungscode gefunden');
    });
    return reply.code(201).send({ code, expiresAt: expiresAt.toISOString() });
  });

  app.get<{ Params: { b: string } }>('/api/admin/businesses/:b/registers', async (req) => {
    await requireBusinessAccess(req, req.params.b);
    const rows = await withBusiness(
      db,
      req.params.b.toLowerCase(),
      async (c) => (await c.query<RegisterRow>(`select ${COLUMNS} from registers order by paired_at desc, id`)).rows,
    );
    return { registers: rows.map(toWire) };
  });

  for (const what of ['block', 'unblock'] as const) {
    app.post<{ Params: { b: string; id: string } }>(`/api/admin/businesses/:b/registers/:id/${what}`, async (req) => {
      const user = await requireBusinessAccess(req, req.params.b);
      if (!isUuid(req.params.id)) throw notFound();
      const businessId = req.params.b.toLowerCase();
      const registerId = req.params.id.toLowerCase();
      const at = now();
      const row = await withBusiness(db, businessId, async (c) => {
        const r = await c.query<RegisterRow>(
          what === 'block'
            ? `update registers set blocked_at = coalesce(blocked_at, $2) where id = $1 returning ${COLUMNS}`
            : `update registers set blocked_at = null where id = $1 returning ${COLUMNS}`,
          what === 'block' ? [registerId, at] : [registerId],
        );
        const updated = r.rows[0];
        if (!updated) throw notFound();
        await audit(c, { userId: user.id, businessId, action: `register.${what}`, detail: { registerId } }, at);
        return updated;
      });
      return { register: toWire(row) };
    });
  }
}
