import { randomUUID } from 'node:crypto';
import type { FastifyInstance } from 'fastify';
import type { z } from 'zod';
import { audit } from '../audit.js';
import { isUuid, requireBusinessAccess } from '../auth/guards.js';
import { nextChangeSeq, withBusiness, withBusinessWrite } from '../db/tenant.js';
import { customerText, customerVatId, CUSTOMER_TEXT_MAX, CUSTOMER_VAT_ID_MAX } from '../device/push_customer.js';
import { ApiError } from '../errors.js';

type CustomerRow = {
  id: string;
  name: string;
  address_line1: string;
  address_line2: string;
  vat_id: string | null;
  archived: boolean;
  updated_at: Date;
};

const COLUMNS = 'id, name, address_line1, address_line2, vat_id, archived, updated_at';

const notFound = () => new ApiError(404, 'not_found', 'Das gibt es nicht.');
const badRequest = () => new ApiError(400, 'bad_request', 'Die Anfrage ist nicht in Ordnung.');

function toWire(r: CustomerRow) {
  return {
    id: r.id,
    name: r.name,
    addressLine1: r.address_line1,
    addressLine2: r.address_line2,
    vatId: r.vat_id,
    archived: r.archived,
    updatedAt: r.updated_at.toISOString(),
  };
}

/** Die Felder, ihr Fehlercode und der Satz dazu. Geprüft wie am Tablet (`checkRecipient`) und beim Abgleich. */
const FIELDS = {
  name: { column: 'name', code: 'name_invalid', message: `Der Name muss 1 bis ${CUSTOMER_TEXT_MAX} Zeichen lang sein.` },
  addressLine1: {
    column: 'address_line1',
    code: 'address_line1_invalid',
    message: `Die erste Adress-Zeile muss 1 bis ${CUSTOMER_TEXT_MAX} Zeichen lang sein.`,
  },
  addressLine2: {
    column: 'address_line2',
    code: 'address_line2_invalid',
    message: `Die zweite Adress-Zeile muss 1 bis ${CUSTOMER_TEXT_MAX} Zeichen lang sein.`,
  },
} as const;
type TextField = keyof typeof FIELDS;

function readText(field: TextField, v: unknown): string {
  const r = customerText.safeParse(v);
  if (!r.success) throw new ApiError(422, FIELDS[field].code, FIELDS[field].message);
  return r.data;
}

/** Fehlt die UID oder ist sie leer, hat der Kunde keine. */
function readVatId(v: unknown): z.infer<typeof customerVatId> {
  const r = customerVatId.safeParse(v === undefined ? null : v);
  if (!r.success) throw new ApiError(422, 'vat_id_invalid', `Die UID darf höchstens ${CUSTOMER_VAT_ID_MAX} Zeichen lang sein.`);
  return r.data;
}

function readObject(body: unknown): Record<string, unknown> {
  if (typeof body !== 'object' || body === null || Array.isArray(body)) throw badRequest();
  return body as Record<string, unknown>;
}

/**
 * Adressen unter /api/admin/businesses/:b/customers: Firmenkunden für die Rechnung (Spec 5.3). Rollen wie bei den
 * Mitarbeitern. Jede Änderung bekommt eine neue Änderungs-Nummer und kommt so auf alle Tablets des Betriebs. Der
 * Verlauf nennt nur Kennung und Felder, nie Name, Adresse oder UID. Nach installAuth aufrufen.
 */
export function installCustomerRoutes(app: FastifyInstance): void {
  const { db, now } = app.deps;

  app.get<{ Params: { b: string } }>('/api/admin/businesses/:b/customers', async (req) => {
    await requireBusinessAccess(req, req.params.b);
    const businessId = req.params.b.toLowerCase();
    const rows = await withBusiness(db, businessId, async (c) => (await c.query<CustomerRow>(`select ${COLUMNS} from customers`)).rows);
    rows.sort((x, y) => Number(x.archived) - Number(y.archived) || x.name.localeCompare(y.name, 'de') || x.id.localeCompare(y.id));
    return { customers: rows.map(toWire) };
  });

  app.post<{ Params: { b: string } }>('/api/admin/businesses/:b/customers', async (req, reply) => {
    const user = await requireBusinessAccess(req, req.params.b);
    const businessId = req.params.b.toLowerCase();
    const body = readObject(req.body);
    const name = readText('name', body.name);
    const addressLine1 = readText('addressLine1', body.addressLine1);
    const addressLine2 = readText('addressLine2', body.addressLine2);
    const vatId = readVatId(body.vatId);
    const at = now();
    const created = await withBusinessWrite(db, businessId, async (c) => {
      const row = (
        await c.query<CustomerRow>(
          `insert into customers (business_id, id, name, address_line1, address_line2, vat_id, archived, updated_at, change_seq)
           values ($1, $2, $3, $4, $5, $6, false, $7, $8) returning ${COLUMNS}`,
          [businessId, randomUUID(), name, addressLine1, addressLine2, vatId, at, await nextChangeSeq(c)],
        )
      ).rows[0]!;
      await audit(c, { userId: user.id, businessId, action: 'customer.create', detail: { customerId: row.id } }, at);
      return row;
    });
    return reply.code(201).send({ customer: toWire(created) });
  });

  app.patch<{ Params: { b: string; id: string } }>('/api/admin/businesses/:b/customers/:id', async (req) => {
    const user = await requireBusinessAccess(req, req.params.b);
    if (!isUuid(req.params.id)) throw notFound();
    const businessId = req.params.b.toLowerCase();
    const customerId = req.params.id.toLowerCase();
    const body = readObject(req.body);
    const fields: string[] = [];
    const set: Record<string, unknown> = {};
    for (const field of Object.keys(FIELDS) as TextField[]) {
      if (field in body) {
        fields.push(field);
        set[FIELDS[field].column] = readText(field, body[field]);
      }
    }
    if ('vatId' in body) {
      fields.push('vatId');
      set.vat_id = readVatId(body.vatId);
    }
    if ('archived' in body) {
      if (typeof body.archived !== 'boolean') throw badRequest();
      fields.push('archived');
      set.archived = body.archived;
    }
    if (fields.length === 0) throw badRequest();
    const at = now();
    const updated = await withBusinessWrite(db, businessId, async (c) => {
      const exists = await c.query('select 1 from customers where id = $1 for update', [customerId]);
      if (exists.rowCount === 0) throw notFound();
      const columns = Object.keys(set);
      const values = Object.values(set);
      const assignments = columns.map((col, i) => `${col} = $${i + 2}`);
      const row = (
        await c.query<CustomerRow>(
          `update customers set ${assignments.join(', ')}, updated_at = $${columns.length + 2}, change_seq = $${columns.length + 3}
            where id = $1 returning ${COLUMNS}`,
          [customerId, ...values, at, await nextChangeSeq(c)],
        )
      ).rows[0]!;
      await audit(c, { userId: user.id, businessId, action: 'customer.update', detail: { customerId, fields } }, at);
      return row;
    });
    return { customer: toWire(updated) };
  });
}
