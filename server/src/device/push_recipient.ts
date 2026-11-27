import type pg from 'pg';
import { z } from 'zod';
import type { EntryContext, EntryResult } from './push.js';
import { customerText, customerVatId, noNul, VAT_ID_REQUIRED_ABOVE_CENTS } from './push_customer.js';
import { invalid } from './push_schema.js';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const uuid = z.string().regex(UUID).transform((s) => s.toLowerCase());
const text = noNul.pipe(z.string().max(2000));

// Der Eintrag ist flach: `{seq, kind, receiptId, version, …}`. Unbekannte Felder werden überlesen.
const recipientEntry = z.object({
  receiptId: uuid,
  version: z.number().int().min(0).max(1_000_000),
  customerId: uuid.nullable(),
  name: customerText,
  addressLine1: customerText,
  addressLine2: customerText,
  vatId: customerVatId,
  createdAt: z.iso.datetime().transform((s) => new Date(s)),
  staffId: noNul.pipe(z.string().min(1).max(2000)),
  staffName: text,
});

const rejectedAt = (path: string): EntryResult => ({ status: 'rejected', reason: 'invalid', paths: [path] });

/**
 * Eine Fassung des Empfängers der Rechnung zu einem Bon: wird angefügt, der Bon selbst bleibt unverändert. Dieselbe
 * Fassung noch einmal ist `duplicate`. Kennt der Server den Bon nicht (auch: Bon eines anderen Betriebs), ist sie
 * `invalid`; ebenso, wenn die UID fehlt, obwohl der Bon über 10.000,00 € liegt.
 */
export async function handleRecipient(c: pg.PoolClient, ctx: EntryContext, body: unknown): Promise<EntryResult> {
  const parsed = recipientEntry.safeParse(body);
  if (!parsed.success) return invalid(parsed.error);
  const v = parsed.data;
  const businessId = ctx.register.businessId;
  const receipt = (
    await c.query<{ total_cents: number }>('select total_cents from receipts where business_id = $1 and id = $2', [businessId, v.receiptId])
  ).rows[0];
  if (!receipt) return rejectedAt('receiptId');
  if (v.vatId === null && receipt.total_cents > VAT_ID_REQUIRED_ABOVE_CENTS) return rejectedAt('vatId');
  const inserted = await c.query(
    `insert into receipt_recipients (business_id, receipt_id, version, customer_id, name, address_line1, address_line2, vat_id,
                                     created_at, staff_id, staff_name)
     values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11) on conflict do nothing`,
    [businessId, v.receiptId, v.version, v.customerId, v.name, v.addressLine1, v.addressLine2, v.vatId, v.createdAt, v.staffId, v.staffName],
  );
  return inserted.rowCount === 1 ? { status: 'accepted' } : { status: 'duplicate' };
}
