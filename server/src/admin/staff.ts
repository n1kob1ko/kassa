import { createHash, randomBytes } from 'node:crypto';
import type { FastifyInstance } from 'fastify';
import type pg from 'pg';
import { audit } from '../audit.js';
import { requireBusinessAccess, isUuid } from '../auth/guards.js';
import { nextChangeSeq, withBusiness, withBusinessWrite } from '../db/tenant.js';
import { ApiError } from '../errors.js';

/** Prüfwert einer PIN: SHA-256 über Salz und PIN als UTF-8, klein geschriebenes Hex. Genauso rechnet die Tablet-App. */
export function pinHash(salt: string, pin: string): string {
  return createHash('sha256').update(`${salt}${pin}`, 'utf8').digest('hex');
}

const PIN = /^[0-9]{4}$/;
const MAX_NAME = 40;

type StaffRow = { id: string; name: string; role: 'chef' | 'staff'; archived: boolean; pin_salt: string; pin_hash: string };

const notFound = () => new ApiError(404, 'not_found', 'Das gibt es nicht.');
const badRequest = () => new ApiError(400, 'bad_request', 'Die Anfrage ist nicht in Ordnung.');

function toWire(r: StaffRow) {
  return { id: r.id, name: r.name, role: r.role, archived: r.archived };
}

function readName(v: unknown): string {
  const name = typeof v === 'string' ? v.trim() : '';
  if (name.length < 1 || name.length > MAX_NAME) {
    throw new ApiError(422, 'name_invalid', 'Der Name muss 1 bis 40 Zeichen lang sein.');
  }
  return name;
}

function readRole(v: unknown): 'chef' | 'staff' {
  if (v !== 'chef' && v !== 'staff') throw new ApiError(422, 'role_invalid', 'Die Rolle muss Chef oder Mitarbeiter sein.');
  return v;
}

function readPin(v: unknown): string {
  if (typeof v !== 'string' || !PIN.test(v)) {
    throw new ApiError(422, 'pin_invalid', 'Die PIN muss aus genau vier Ziffern bestehen.');
  }
  return v;
}

function readObject(body: unknown): Record<string, unknown> {
  if (typeof body !== 'object' || body === null || Array.isArray(body)) throw badRequest();
  return body as Record<string, unknown>;
}

const pinTaken = () => new ApiError(409, 'pin_taken', 'Diese PIN ist schon vergeben.');

/** Ob ein anderer aktiver Mitarbeiter dieses Betriebs diese PIN hat. Nur innerhalb von withBusinessWrite aufrufen. */
async function pinUsedByOther(c: pg.PoolClient, pin: string, exceptId: string | null): Promise<boolean> {
  const r = await c.query<{ pin_salt: string; pin_hash: string }>(
    'select pin_salt, pin_hash from staff where not archived and ($1::uuid is null or id <> $1)',
    [exceptId],
  );
  return r.rows.some((o) => pinHash(o.pin_salt, pin) === o.pin_hash);
}

/** Die PIN zu einem gespeicherten Prüfwert. Es gibt nur 10 000 PINs, das Durchprobieren dauert Millisekunden. */
function recoverPin(salt: string, hash: string): string | null {
  for (let i = 0; i < 10000; i++) {
    const pin = String(i).padStart(4, '0');
    if (pinHash(salt, pin) === hash) return pin;
  }
  return null;
}

/** Adressen unter /api/admin/businesses/:b/staff. Nach installAuth aufrufen. */
export function installStaffRoutes(app: FastifyInstance): void {
  const { db, now } = app.deps;

  app.get<{ Params: { b: string } }>('/api/admin/businesses/:b/staff', async (req) => {
    await requireBusinessAccess(req, req.params.b);
    const id = req.params.b.toLowerCase();
    const rows = await withBusiness(
      db,
      id,
      async (c) => (await c.query<StaffRow>('select id, name, role, archived, pin_salt, pin_hash from staff')).rows,
    );
    rows.sort((x, y) => Number(x.archived) - Number(y.archived) || x.name.localeCompare(y.name, 'de') || x.id.localeCompare(y.id));
    return { staff: rows.map(toWire) };
  });

  app.post<{ Params: { b: string } }>('/api/admin/businesses/:b/staff', async (req, reply) => {
    const user = await requireBusinessAccess(req, req.params.b);
    const businessId = req.params.b.toLowerCase();
    const body = readObject(req.body);
    const name = readName(body.name);
    const role = readRole(body.role);
    const pin = readPin(body.pin);
    const at = now();
    const created = await withBusinessWrite(db, businessId, async (c) => {
      const count = (await c.query<{ n: number }>('select count(*)::int as n from staff')).rows[0]!.n;
      if (count === 0 && role !== 'chef') {
        throw new ApiError(422, 'first_must_be_chef', 'Der erste Mitarbeiter muss ein Chef sein.');
      }
      if (await pinUsedByOther(c, pin, null)) throw pinTaken();
      const salt = randomBytes(16).toString('hex');
      const row = (
        await c.query<StaffRow>(
          `insert into staff (business_id, name, role, pin_salt, pin_hash, change_seq)
           values ($1, $2, $3, $4, $5, $6) returning id, name, role, archived, pin_salt, pin_hash`,
          [businessId, name, role, salt, pinHash(salt, pin), await nextChangeSeq(c)],
        )
      ).rows[0]!;
      await audit(c, { userId: user.id, businessId, action: 'staff.create', detail: { staffId: row.id, name, role } }, at);
      return row;
    });
    return reply.code(201).send({ staff: toWire(created) });
  });

  app.patch<{ Params: { b: string; id: string } }>('/api/admin/businesses/:b/staff/:id', async (req) => {
    const user = await requireBusinessAccess(req, req.params.b);
    if (!isUuid(req.params.id)) throw notFound();
    const businessId = req.params.b.toLowerCase();
    const staffId = req.params.id.toLowerCase();
    const body = readObject(req.body);
    const fields: string[] = [];
    const name = 'name' in body ? (fields.push('name'), readName(body.name)) : undefined;
    const role = 'role' in body ? (fields.push('role'), readRole(body.role)) : undefined;
    const pin = 'pin' in body ? (fields.push('pin'), readPin(body.pin)) : undefined;
    let archived: boolean | undefined;
    if ('archived' in body) {
      if (typeof body.archived !== 'boolean') throw badRequest();
      fields.push('archived');
      archived = body.archived;
    }
    if (fields.length === 0) throw badRequest();
    const at = now();
    const updated = await withBusinessWrite(db, businessId, async (c) => {
      const cur = (
        await c.query<StaffRow>('select id, name, role, archived, pin_salt, pin_hash from staff where id = $1', [staffId])
      ).rows[0];
      if (!cur) throw notFound();
      const next = {
        name: name ?? cur.name,
        role: role ?? cur.role,
        archived: archived ?? cur.archived,
        salt: cur.pin_salt,
        hash: cur.pin_hash,
      };
      if (cur.role === 'chef' && !cur.archived && (next.role !== 'chef' || next.archived)) {
        const others = (
          await c.query<{ n: number }>(`select count(*)::int as n from staff where role = 'chef' and not archived and id <> $1`, [staffId])
        ).rows[0]!.n;
        if (others === 0) throw new ApiError(409, 'last_chef', 'Mindestens ein Chef muss bleiben.');
      }
      if (!next.archived && (pin !== undefined || cur.archived)) {
        const effective = pin ?? recoverPin(cur.pin_salt, cur.pin_hash);
        if (effective !== null && (await pinUsedByOther(c, effective, staffId))) throw pinTaken();
      }
      if (pin !== undefined) {
        next.salt = randomBytes(16).toString('hex');
        next.hash = pinHash(next.salt, pin);
      }
      const row = (
        await c.query<StaffRow>(
          `update staff set name = $2, role = $3, archived = $4, pin_salt = $5, pin_hash = $6, change_seq = $7
            where id = $1 returning id, name, role, archived, pin_salt, pin_hash`,
          [staffId, next.name, next.role, next.archived, next.salt, next.hash, await nextChangeSeq(c)],
        )
      ).rows[0]!;
      await audit(c, { userId: user.id, businessId, action: 'staff.update', detail: { staffId, fields } }, at);
      return row;
    });
    return { staff: toWire(updated) };
  });
}
