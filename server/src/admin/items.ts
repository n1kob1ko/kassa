import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { audit } from '../audit.js';
import { requireBusinessAccess } from '../auth/guards.js';
import { withBusiness, withBusinessWrite } from '../db/tenant.js';
import { applyItemField, type ItemField } from '../device/push_item_change.js';
import { ApiError } from '../errors.js';

const notFound = () => new ApiError(404, 'not_found', 'Das gibt es nicht.');

type ItemRow = {
  id: string;
  name: string;
  price_cents: number;
  in_sale: boolean;
  favorite: boolean;
  archived: boolean;
  photo_id: string | null;
  photo_color: string | null;
  category_id: string;
};

const ITEM_SELECT = `select i.id, i.name, i.price_cents, i.in_sale, i.favorite, i.archived, i.category_id,
    f.id as photo_id, f.color as photo_color
  from items i left join files f on f.id = i.photo_file_id`;

function toWire(r: ItemRow) {
  return {
    id: r.id,
    name: r.name,
    priceCents: r.price_cents,
    inSale: r.in_sale,
    favorite: r.favorite,
    archived: r.archived,
    photo: r.photo_id === null ? null : { id: r.photo_id, color: r.photo_color },
  };
}

/** Die Felder, die der Browser ändern darf, mit der Spalte ihres Änderungszeitpunkts. */
const TIME_COLUMN = { priceCents: 'price_changed_at', inSale: 'in_sale_changed_at', favorite: 'favorite_changed_at' } as const;
const FIELDS = Object.keys(TIME_COLUMN) as (keyof typeof TIME_COLUMN)[];

const patchBody = z.strictObject({
  priceCents: z.number().int().min(0).max(2_000_000_000).optional(),
  inSale: z.boolean().optional(),
  favorite: z.boolean().optional(),
});

/** Adressen für Artikel in der Verwaltung. Nach installAuth aufrufen. */
export function installItemRoutes(app: FastifyInstance): void {
  const { db, now } = app.deps;

  app.get<{ Params: { b: string } }>('/api/admin/businesses/:b/items', async (req) => {
    await requireBusinessAccess(req, req.params.b);
    return withBusiness(db, req.params.b.toLowerCase(), async (c) => {
      const categories = (
        await c.query<{ id: string; name: string; archived: boolean }>(
          'select id, name, archived from categories order by position, id',
        )
      ).rows;
      const items = (await c.query<ItemRow>(`${ITEM_SELECT} order by i.position, i.id`)).rows;
      return {
        categories: categories.map((cat) => ({
          id: cat.id,
          name: cat.name,
          archived: cat.archived,
          items: items.filter((i) => i.category_id === cat.id).map(toWire),
        })),
      };
    });
  });

  app.patch<{ Params: { b: string; id: string } }>('/api/admin/businesses/:b/items/:id', async (req) => {
    const user = await requireBusinessAccess(req, req.params.b);
    const businessId = req.params.b.toLowerCase();
    const parsed = patchBody.safeParse(req.body);
    if (!parsed.success) {
      throw new ApiError(422, 'item_invalid', 'Nur Preis, im Verkauf und Favorit lassen sich ändern, mit passenden Werten.');
    }
    const fields = FIELDS.filter((f) => parsed.data[f] !== undefined);
    if (fields.length === 0) throw new ApiError(422, 'nothing_to_change', 'Es gibt nichts zu ändern.');
    const itemId = req.params.id;
    const at = now();
    return withBusinessWrite(db, businessId, async (c) => {
      const stored = (
        await c.query<Record<string, Date>>(
          `select ${FIELDS.map((f) => `${TIME_COLUMN[f]} as "${f}"`).join(', ')} from items where business_id = $1 and id = $2 for update`,
          [businessId, itemId],
        )
      ).rows[0];
      if (!stored) throw notFound();
      const changed: Record<string, number | boolean> = {};
      for (const field of fields) {
        // Der Browser gewinnt immer: Steht das Feld schon auf "jetzt" oder später (Tablet im selben Moment), zählt eine Millisekunde danach.
        const changedAt = new Date(Math.max(at.getTime(), stored[field]!.getTime() + 1));
        const value = parsed.data[field]!;
        const outcome = await applyItemField(c, businessId, itemId, field as ItemField, value, changedAt);
        if (outcome === 'unknown_item') throw notFound();
        if (outcome === 'older') throw new Error(`Änderung von ${field} wurde als älter abgewiesen`);
        changed[field] = value;
      }
      await audit(c, { userId: user.id, businessId, action: 'item.update', detail: { itemId, fields: changed } }, at);
      const row = (await c.query<ItemRow>(`${ITEM_SELECT} where i.id = $1`, [itemId])).rows[0]!;
      return toWire(row);
    });
  });
}
