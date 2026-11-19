import type pg from 'pg';
import { z } from 'zod';
import { nextChangeSeq } from '../db/tenant.js';
import type { EntryContext, EntryResult } from './push.js';
import { invalid } from './push_schema.js';

export type ItemField = 'priceCents' | 'inSale' | 'favorite' | 'depositCents' | 'tags';

/** Spalte des Werts und Vorsilbe der Spalte des Zeitpunkts (`<Vorsilbe>_changed_at`) je Feld. */
const COLUMNS: Record<ItemField, { value: string; changedAt: string }> = {
  priceCents: { value: 'price_cents', changedAt: 'price_changed_at' },
  inSale: { value: 'in_sale', changedAt: 'in_sale_changed_at' },
  favorite: { value: 'favorite', changedAt: 'favorite_changed_at' },
  depositCents: { value: 'deposit_cents', changedAt: 'deposit_changed_at' },
  tags: { value: 'tags', changedAt: 'tags_changed_at' },
};

/**
 * Setzt ein Feld eines Artikels, wenn `changedAt` später ist als der Zeitpunkt, an dem das Feld zuletzt geändert wurde
 * (pro Feld gewinnt die spätere Änderung). Bei gleichem Zeitpunkt gewinnt ein anderer Wert (der spätere Eintrag derselben
 * Sekunde), derselbe Wert bleibt `older`, damit ein wiederholtes Paket nichts ändert. Gesetzt: der Artikel bekommt eine neue
 * Änderungs-Nummer. Älter mit anderem Wert: Wert und Zeitpunkt bleiben, aber die Änderungs-Nummer steigt, damit das Holen
 * den Wert des Servers zurück ans Tablet bringt. Nur innerhalb von withBusinessWrite aufrufen.
 * `value` muss zum Feld passen (Tags: Liste der Kennzeichen).
 */
export async function applyItemField(
  c: pg.PoolClient,
  businessId: string,
  itemId: string,
  field: ItemField,
  value: unknown,
  changedAt: Date,
): Promise<'applied' | 'older' | 'unknown_item'> {
  const col = COLUMNS[field];
  const current = await c.query<{ value: unknown; changed_at: Date }>(
    `select ${col.value} as value, ${col.changedAt} as changed_at from items where business_id = $1 and id = $2 for update`,
    [businessId, itemId],
  );
  const row = current.rows[0];
  if (!row) return 'unknown_item';
  const stored = field === 'tags' ? [...new Set(value as string[])].sort().join(',') : value;
  const same = row.value === stored;
  const diff = changedAt.getTime() - row.changed_at.getTime();
  if (diff < 0 || (diff === 0 && same)) {
    if (!same) {
      await c.query('update items set change_seq = $3 where business_id = $1 and id = $2', [businessId, itemId, await nextChangeSeq(c)]);
    }
    return 'older';
  }
  await c.query(
    `update items set ${col.value} = $3, ${col.changedAt} = $4, change_seq = $5 where business_id = $1 and id = $2`,
    [businessId, itemId, stored, changedAt, await nextChangeSeq(c)],
  );
  return 'applied';
}

const cents = z.number().int().min(0).max(2_000_000_000);
const change = z.object({ itemId: z.string().min(1).max(200), changedAt: z.iso.datetime().transform((s) => new Date(s)) });
const itemChangeEntry = z.object({
  change: z.discriminatedUnion('field', [
    change.extend({ field: z.literal('priceCents'), value: cents }),
    change.extend({ field: z.literal('depositCents'), value: cents }),
    change.extend({ field: z.literal('inSale'), value: z.boolean() }),
    change.extend({ field: z.literal('favorite'), value: z.boolean() }),
    change.extend({ field: z.literal('tags'), value: z.array(z.enum(['vegan', 'spicy'])).max(2) }),
  ]),
});

/** Eine Änderung vom Tablet. Eine Uhr in der Zukunft gilt als jetzt, damit sie nicht für immer gewinnt. */
export async function handleItemChange(c: pg.PoolClient, ctx: EntryContext, body: unknown): Promise<EntryResult> {
  const parsed = itemChangeEntry.safeParse(body);
  if (!parsed.success) return invalid(parsed.error);
  const v = parsed.data.change;
  const changedAt = v.changedAt.getTime() > ctx.at.getTime() ? ctx.at : v.changedAt;
  const outcome = await applyItemField(c, ctx.register.businessId, v.itemId, v.field, v.value, changedAt);
  return outcome === 'unknown_item' ? { status: 'rejected', reason: 'unknown_item' } : { status: 'accepted' };
}
