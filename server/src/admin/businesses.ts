import { randomUUID } from 'node:crypto';
import type { FastifyInstance, FastifyRequest } from 'fastify';
import { z } from 'zod';
import { audit } from '../audit.js';
import { requireBusinessAccess, requireProvider } from '../auth/guards.js';
import { nextChangeSeq, withBusiness, withBusinessWrite, withSystem } from '../db/tenant.js';
import { ApiError } from '../errors.js';
import { checkCentsRange, importMenu } from '../menu/import_menu.js';
import { MenuImportError, parseMenuFile, type ParsedMenu } from '../menu/parse_menu.js';

const MAX_MENU_FILE_BYTES = 1024 * 1024;
/** Die Anfrage darf größer sein als die Datei, weil JSON Zeichen aufbläht. Die Datei selbst prüft der Code unten. */
const MENU_BODY_LIMIT = 8 * MAX_MENU_FILE_BYTES;

const menuBody = z.object({ menuFile: z.string() });

/** Liest und prüft die Speisekarten-Datei aus dem Anfragekörper. */
function readMenu(body: unknown): ParsedMenu {
  const r = menuBody.safeParse(body);
  if (!r.success) throw new ApiError(400, 'bad_request', 'Die Anfrage ist nicht in Ordnung.');
  if (Buffer.byteLength(r.data.menuFile, 'utf8') > MAX_MENU_FILE_BYTES) {
    throw new ApiError(413, 'file_too_large', 'Die Datei ist größer als 1 MB.');
  }
  const invalid = (problems: string[]) =>
    new ApiError(422, 'menu_invalid', 'Die Speisekarten-Datei ist nicht in Ordnung.', { problems });
  let menu: ParsedMenu;
  try {
    menu = parseMenuFile(r.data.menuFile);
  } catch (err) {
    if (err instanceof MenuImportError) throw invalid(err.problems);
    throw err;
  }
  const problems = checkCentsRange(menu);
  if (problems.length > 0) throw invalid(problems);
  return menu;
}

type Row = Record<string, unknown>;

/** Adressen unter /api/admin/businesses. Nach installAuth aufrufen, weil die Hooks dort auf der Wurzel hängen. */
export function installBusinessRoutes(app: FastifyInstance): void {
  const { db, now } = app.deps;

  app.get('/api/admin/businesses', async (req) => {
    requireProvider(req);
    const list = await withSystem(db, async (c) => (await c.query<{ id: string; name: string }>('select id, name from businesses')).rows);
    list.sort((x, y) => x.name.localeCompare(y.name, 'de') || x.id.localeCompare(y.id));
    const businesses = [];
    for (const b of list) {
      const counts = await withBusiness(db, b.id, async (c) => {
        const r = await c.query<{ items: number; staff: number; registers: number }>(
          `select (select count(*) from items where not archived)::int as items,
                  (select count(*) from staff where not archived)::int as staff,
                  (select count(*) from registers where blocked_at is null)::int as registers`,
        );
        return r.rows[0]!;
      });
      businesses.push({ id: b.id, name: b.name, counts });
    }
    return { businesses };
  });

  // Mit 8 MB Grenze: Anmeldung und Rolle prüft onRequest, bevor ein Byte des Körpers gelesen wird.
  const providerFirst = async (req: FastifyRequest) => {
    requireProvider(req);
  };

  app.post('/api/admin/businesses', { bodyLimit: MENU_BODY_LIMIT, onRequest: providerFirst }, async (req, reply) => {
    const user = requireProvider(req);
    const menu = readMenu(req.body);
    const at = now();
    const id = randomUUID();
    const summary = await withBusinessWrite(db, id, async (c) => {
      await c.query(
        `insert into businesses (id, name, address_lines, vat_id, receipt_footer, change_seq, created_at)
         values ($1, $2, $3, $4, $5, $6, $7)`,
        [id, menu.business.name, menu.business.addressLines, menu.business.vatId, menu.business.receiptFooter, await nextChangeSeq(c), at],
      );
      const result = await importMenu(c, id, menu, at);
      await audit(c, { userId: user.id, businessId: id, action: 'business.create', detail: { summary: result } }, at);
      return result;
    });
    return reply.code(201).send({ business: { id, name: menu.business.name }, summary });
  });

  app.get<{ Params: { b: string } }>('/api/admin/businesses/:b', async (req) => {
    await requireBusinessAccess(req, req.params.b);
    const id = req.params.b.toLowerCase();
    return withBusiness(db, id, async (c) => {
      const biz = (
        await c.query<Row>(
          `select b.id, b.name, b.address_lines, b.vat_id, b.receipt_footer, f.id as logo_id, f.color as logo_color
             from businesses b left join files f on f.id = b.logo_file_id
            where b.id = $1`,
          [id],
        )
      ).rows[0];
      if (!biz) throw new ApiError(404, 'not_found', 'Das gibt es nicht.');
      const counts = (
        await c.query<Row>(
          `select (select count(*) from categories where not archived)::int as categories,
                  (select count(*) from items where not archived)::int as items,
                  (select count(*) from modifier_templates where not archived)::int as templates,
                  (select count(*) from staff where not archived)::int as staff,
                  (select count(*) from registers where blocked_at is null)::int as registers`,
        )
      ).rows[0];
      const categories = (
        await c.query<Row>(
          `select k.id, k.name, k.archived,
                  (select count(*) from items i where i.category_id = k.id and not i.archived)::int as "itemCount"
             from categories k order by k.position`,
        )
      ).rows.map((r) => ({ id: r.id, name: r.name, itemCount: r.itemCount, archived: r.archived }));
      return {
        business: {
          id: biz.id,
          name: biz.name,
          addressLines: biz.address_lines,
          vatId: biz.vat_id,
          receiptFooter: biz.receipt_footer,
          logo: biz.logo_id === null ? null : { id: biz.logo_id, color: biz.logo_color },
          counts,
        },
        categories,
      };
    });
  });

  app.post<{ Params: { b: string } }>(
    '/api/admin/businesses/:b/menu',
    {
      bodyLimit: MENU_BODY_LIMIT,
      onRequest: async (req: FastifyRequest<{ Params: { b: string } }>) => {
        requireProvider(req);
        await requireBusinessAccess(req, req.params.b);
      },
    },
    async (req) => {
      const user = requireProvider(req);
      await requireBusinessAccess(req, req.params.b);
      const id = req.params.b.toLowerCase();
      const menu = readMenu(req.body);
      const at = now();
      return withBusinessWrite(db, id, async (c) => {
        const summary = await importMenu(c, id, menu, at);
        const ignoredStaff = menu.staffSeeds.length;
        await audit(c, { userId: user.id, businessId: id, action: 'business.menu_import', detail: { summary, ignoredStaff } }, at);
        return { summary, ignoredStaff };
      });
    },
  );
}
