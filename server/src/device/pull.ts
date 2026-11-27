import type { FastifyInstance } from 'fastify';
import { withBusiness } from '../db/tenant.js';
import { ApiError } from '../errors.js';
import { requireRegister } from './guard.js';

const DEFAULT_LIMIT = 500;
const MAX_LIMIT = 1000;
const DIGITS = /^[0-9]+$/;

type GroupJson = {
  id: string;
  name: string;
  min: number;
  max: number | null;
  options: {
    id: string;
    name: string;
    surchargeCents: number;
    isDefault: boolean;
    taxPercent: number | null;
    depositCents: number | null;
  }[];
};

/** Eine Zeile mit ihrer Änderungs-Nummer, damit alle Arten gemeinsam nach Nummer sortiert und abgeschnitten werden. */
type Change = {
  seq: number;
  kind: 'business' | 'categories' | 'items' | 'templates' | 'staff' | 'translations' | 'customers';
  row: object;
};

/** Eine ganze Zahl ab `min` aus der Abfrage, sonst null. Mehrfach angegeben zählt als falsch. */
function readInt(v: unknown, min: number): number | null {
  if (typeof v !== 'string' || !DIGITS.test(v)) return null;
  const n = Number(v);
  return Number.isSafeInteger(n) && n >= min ? n : null;
}

// bigint kommt als Text. Angenommen wird, dass Änderungs-Nummern unter 2^53 bleiben, sonst wäre Number ungenau.
const seqOf = (r: { change_seq: string }) => Number(r.change_seq);

/** Vorlagen gehen in fester Reihenfolge der Schlüssel hinaus, egal wie jsonb sie speichert. */
function groupsToWire(groups: GroupJson[]) {
  return groups.map((g) => ({
    id: g.id,
    name: g.name,
    min: g.min,
    max: g.max,
    options: g.options.map((o) => ({
      id: o.id,
      name: o.name,
      surchargeCents: o.surchargeCents,
      isDefault: o.isDefault,
      taxPercent: o.taxPercent,
      depositCents: o.depositCents,
    })),
  }));
}

/** GET /api/device/sync/pull: alles, was sich seit einer Änderungs-Nummer geändert hat, nach Nummer aufsteigend. */
export function installPullRoutes(app: FastifyInstance): void {
  const { db } = app.deps;

  app.get<{ Querystring: Record<string, unknown> }>('/api/device/sync/pull', async (req) => {
    const register = await requireRegister(req);
    const since = readInt(req.query.since, 0);
    if (since === null) throw new ApiError(422, 'since_invalid', 'Die Angabe since muss eine ganze Zahl ab 0 sein.');
    let limit = DEFAULT_LIMIT;
    if (req.query.limit !== undefined) {
      const n = readInt(req.query.limit, 1);
      if (n === null) throw new ApiError(422, 'limit_invalid', 'Die Angabe limit muss eine ganze Zahl ab 1 sein.');
      limit = Math.min(n, MAX_LIMIT);
    }

    // Ein fester Stand für alle sieben Abfragen. Jede Art liefert höchstens limit + 1 Zeilen: Daraus ergeben sich
    // die ersten limit Zeilen über alle Arten und ob danach noch etwas kommt.
    const changes = await withBusiness(
      db,
      register.businessId,
      async (c) => {
        const take = limit + 1;
        const out: Change[] = [];
        const business = await c.query(
          `select b.name, b.address_lines, b.vat_id, b.receipt_footer, b.change_seq, f.id as logo_id, f.color as logo_color
             from businesses b left join files f on f.id = b.logo_file_id
            where b.id = $1 and b.change_seq > $2`,
          [register.businessId, since],
        );
        for (const r of business.rows) {
          out.push({
            seq: seqOf(r),
            kind: 'business',
            row: {
              name: r.name,
              addressLines: r.address_lines,
              vatId: r.vat_id,
              receiptFooter: r.receipt_footer,
              logo: r.logo_id === null ? null : { id: r.logo_id, color: r.logo_color },
            },
          });
        }
        const categories = await c.query(
          `select id, name, position, archived, change_seq from categories
            where change_seq > $1 order by change_seq limit $2`,
          [since, take],
        );
        for (const r of categories.rows) {
          out.push({ seq: seqOf(r), kind: 'categories', row: { id: r.id, name: r.name, position: r.position, archived: r.archived } });
        }
        const items = await c.query(
          `select i.id, i.name, i.price_cents, i.category_id, i.tax_percent, i.deposit_cents, i.tags, i.info,
                  i.template_id, i.favorite, i.in_sale, i.position, i.archived, i.change_seq,
                  f.id as photo_id, f.color as photo_color
             from items i left join files f on f.id = i.photo_file_id
            where i.change_seq > $1 order by i.change_seq limit $2`,
          [since, take],
        );
        for (const r of items.rows) {
          out.push({
            seq: seqOf(r),
            kind: 'items',
            row: {
              id: r.id,
              name: r.name,
              priceCents: r.price_cents,
              categoryId: r.category_id,
              taxPercent: r.tax_percent,
              depositCents: r.deposit_cents,
              tags: (r.tags as string).split(',').filter((t) => t !== ''),
              info: r.info,
              templateId: r.template_id,
              favorite: r.favorite,
              inSale: r.in_sale,
              position: r.position,
              archived: r.archived,
              photo: r.photo_id === null ? null : { id: r.photo_id, color: r.photo_color },
            },
          });
        }
        const templates = await c.query(
          `select id, name, groups, archived, change_seq from modifier_templates
            where change_seq > $1 order by change_seq limit $2`,
          [since, take],
        );
        for (const r of templates.rows) {
          out.push({
            seq: seqOf(r),
            kind: 'templates',
            row: { id: r.id, name: r.name, archived: r.archived, groups: groupsToWire(r.groups as GroupJson[]) },
          });
        }
        const staff = await c.query(
          `select id, name, role, pin_salt, pin_hash, archived, change_seq from staff
            where change_seq > $1 order by change_seq limit $2`,
          [since, take],
        );
        for (const r of staff.rows) {
          out.push({
            seq: seqOf(r),
            kind: 'staff',
            row: { id: r.id, name: r.name, role: r.role, pinSalt: r.pin_salt, pinHash: r.pin_hash, archived: r.archived },
          });
        }
        const translations = await c.query(
          `select source, values, change_seq from translations
            where change_seq > $1 order by change_seq limit $2`,
          [since, take],
        );
        for (const r of translations.rows) {
          out.push({ seq: seqOf(r), kind: 'translations', row: { source: r.source, values: r.values } });
        }
        // Firmenkunden für die Rechnung (Stufe 1b), auch die archivierten: das Tablet nimmt sie dann aus der Auswahl.
        const customers = await c.query(
          `select id, name, address_line1, address_line2, vat_id, archived, change_seq from customers
            where change_seq > $1 order by change_seq limit $2`,
          [since, take],
        );
        for (const r of customers.rows) {
          out.push({
            seq: seqOf(r),
            kind: 'customers',
            row: {
              id: r.id,
              name: r.name,
              addressLine1: r.address_line1,
              addressLine2: r.address_line2,
              vatId: r.vat_id,
              archived: r.archived,
            },
          });
        }
        return out;
      },
      { repeatableRead: true },
    );

    changes.sort((x, y) => x.seq - y.seq);
    const page = changes.slice(0, limit);
    let business: object | undefined;
    const lists = { categories: [] as object[], items: [] as object[], templates: [] as object[], staff: [] as object[], translations: [] as object[] };
    // Listen ab Stufe 1b: nur in der Antwort, wenn sie nicht leer sind. So bleibt jede Antwort ohne sie genau, wie sie
    // in 1.11.0 war; ältere Tablets überlesen sie. Weitere Listen kommen hierher.
    const extra = { customers: [] as object[] };
    for (const ch of page) {
      if (ch.kind === 'business') business = ch.row;
      else if (ch.kind === 'customers') extra[ch.kind].push(ch.row);
      else lists[ch.kind].push(ch.row);
    }
    return {
      next: page.length > 0 ? page[page.length - 1]!.seq : since,
      more: changes.length > limit,
      // Fehlt, wenn sich die Betriebsdaten seit `since` nicht geändert haben.
      ...(business ? { business } : {}),
      ...lists,
      ...Object.fromEntries(Object.entries(extra).filter(([, rows]) => rows.length > 0)),
    };
  });
}
