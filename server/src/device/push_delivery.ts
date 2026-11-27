import type pg from 'pg';
import { z } from 'zod';
import type { EntryContext, EntryResult } from './push.js';
import { invalid } from './push_schema.js';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// Der Eintrag ist flach: `{seq, kind, receiptId, deliveryKind, at}`. Unbekannte Felder werden überlesen.
const deliveryEntry = z.object({
  receiptId: z.string().regex(UUID).transform((s) => s.toLowerCase()),
  deliveryKind: z.enum(['printed', 'digital']),
  at: z.iso.datetime().transform((s) => new Date(s)),
});

/**
 * Wie der Beleg zu einem Bon erteilt wurde: "printed" (Kundenbon zum ersten Mal ohne Fehler gedruckt) oder "digital"
 * (QR-Code zum ersten Mal gezeigt). Wird angefügt, der Bon selbst bleibt unverändert. Dieselbe Art zum selben Bon noch
 * einmal ist `duplicate`, die erste Zeit bleibt. Kennt der Server den Bon nicht (auch: Bon eines anderen Betriebs), ist
 * der Eintrag `invalid`. Zieht keine Änderungs-Nummer: läuft ohne die Schreib-Sperre des Betriebs, wie `recipient`.
 */
export async function handleDelivery(c: pg.PoolClient, ctx: EntryContext, body: unknown): Promise<EntryResult> {
  const parsed = deliveryEntry.safeParse(body);
  if (!parsed.success) return invalid(parsed.error);
  const v = parsed.data;
  const businessId = ctx.register.businessId;
  const known = await c.query('select 1 from receipts where business_id = $1 and id = $2', [businessId, v.receiptId]);
  if (known.rowCount === 0) return { status: 'rejected', reason: 'invalid', paths: ['receiptId'] };
  const inserted = await c.query(
    `insert into receipt_deliveries (business_id, receipt_id, kind, at) values ($1, $2, $3, $4) on conflict do nothing`,
    [businessId, v.receiptId, v.deliveryKind, v.at],
  );
  return inserted.rowCount === 1 ? { status: 'accepted' } : { status: 'duplicate' };
}
