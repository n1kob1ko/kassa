import type pg from 'pg';
import { z } from 'zod';
import { nextChangeSeq } from '../db/tenant.js';
import type { EntryContext, EntryResult } from './push.js';
import { invalid } from './push_schema.js';

/** Höchstlänge von Name und jeder Adress-Zeile, in Zeichen (wie `customerTextMax` am Tablet). */
export const CUSTOMER_TEXT_MAX = 80;
/** Höchstlänge der UID (wie `customerVatIdMax` am Tablet). */
export const CUSTOMER_VAT_ID_MAX = 20;
/** Über 10.000,00 € braucht die Rechnung die UID des Kunden (wie `invoiceVatIdRequiredAboveCents`). */
export const VAT_ID_REQUIRED_ABOVE_CENTS = 1_000_000;

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Pflichttext ohne Leerzeichen vorn und hinten, 1 bis 80 Zeichen (wie `checkRecipient` am Tablet). */
export const customerText = z
  .string()
  .transform((s) => s.trim())
  .pipe(z.string().min(1).max(CUSTOMER_TEXT_MAX));

/** Die UID: ohne Leerzeichen vorn und hinten höchstens 20 Zeichen, leer ist keine (`null`). */
export const customerVatId = z
  .string()
  .transform((s) => s.trim())
  .pipe(z.string().max(CUSTOMER_VAT_ID_MAX))
  .nullable()
  .transform((s) => (s === null || s === '' ? null : s));

const uuid = z.string().regex(UUID).transform((s) => s.toLowerCase());
const time = z.iso.datetime().transform((s) => new Date(s));

// Der Eintrag ist flach: `{seq, kind, id, name, …}`. Unbekannte Felder werden überlesen.
const customerEntry = z.object({
  id: uuid,
  name: customerText,
  addressLine1: customerText,
  addressLine2: customerText,
  vatId: customerVatId,
  archived: z.boolean(),
  updatedAt: time,
});

type CustomerRow = {
  name: string;
  address_line1: string;
  address_line2: string;
  vat_id: string | null;
  archived: boolean;
  updated_at: Date;
};

/**
 * Ein Firmenkunde vom Tablet: anlegen oder ändern. Die Fassung mit dem neueren `updatedAt` gewinnt, eine Uhr in der
 * Zukunft zählt als jetzt. Eine ältere oder gleich alte Fassung ist `duplicate`; weicht sie im Inhalt ab, bekommt der
 * Kunde eine neue Änderungs-Nummer, damit das Holen den Stand des Servers zurück ans Tablet bringt. Nur innerhalb von
 * withBusinessWrite aufrufen.
 */
export async function handleCustomer(c: pg.PoolClient, ctx: EntryContext, body: unknown): Promise<EntryResult> {
  const parsed = customerEntry.safeParse(body);
  if (!parsed.success) return invalid(parsed.error);
  const v = parsed.data;
  const businessId = ctx.register.businessId;
  const updatedAt = v.updatedAt.getTime() > ctx.at.getTime() ? ctx.at : v.updatedAt;
  const current = (
    await c.query<CustomerRow>(
      'select name, address_line1, address_line2, vat_id, archived, updated_at from customers where business_id = $1 and id = $2 for update',
      [businessId, v.id],
    )
  ).rows[0];
  if (!current) {
    await c.query(
      `insert into customers (business_id, id, name, address_line1, address_line2, vat_id, archived, updated_at, change_seq)
       values ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
      [businessId, v.id, v.name, v.addressLine1, v.addressLine2, v.vatId, v.archived, updatedAt, await nextChangeSeq(c)],
    );
    return { status: 'accepted' };
  }
  if (updatedAt.getTime() > current.updated_at.getTime()) {
    await c.query(
      `update customers set name = $3, address_line1 = $4, address_line2 = $5, vat_id = $6, archived = $7, updated_at = $8,
              change_seq = $9
        where business_id = $1 and id = $2`,
      [businessId, v.id, v.name, v.addressLine1, v.addressLine2, v.vatId, v.archived, updatedAt, await nextChangeSeq(c)],
    );
    return { status: 'accepted' };
  }
  const same =
    current.name === v.name &&
    current.address_line1 === v.addressLine1 &&
    current.address_line2 === v.addressLine2 &&
    current.vat_id === v.vatId &&
    current.archived === v.archived;
  if (!same) {
    await c.query('update customers set change_seq = $3 where business_id = $1 and id = $2', [businessId, v.id, await nextChangeSeq(c)]);
  }
  return { status: 'duplicate' };
}
