import type { FastifyInstance, FastifyRequest } from 'fastify';
import { z } from 'zod';
import type pg from 'pg';
import { audit } from '../audit.js';
import { requireBusinessAccess, requireProvider } from '../auth/guards.js';
import { nextChangeSeq, withBusiness, withBusinessWrite } from '../db/tenant.js';
import { ApiError } from '../errors.js';
import { applyTranslations, menuNames, parseTranslations, same, TRANSLATION_LANGS, type TranslationLang } from '../menu/translations.js';

const MAX_FILE_BYTES = 1024 * 1024;
/** Die Anfrage darf größer sein als die Datei, weil JSON Zeichen aufbläht. Die Datei selbst prüft der Code unten. */
const BODY_LIMIT = 8 * MAX_FILE_BYTES;
const MAX_VALUE_LENGTH = 200;

type Values = Partial<Record<TranslationLang, string>>;
type Row = { source: string; values: Values };
type Section = { kind: 'categories' | 'category' | 'extras'; title: string; rows: Row[] };
type Json = Record<string, unknown>;

type MenuRows = {
  categories: { id: string; name: string; archived: boolean }[];
  items: { name: string; info: string | null; category_id: string; template_id: string | null; archived: boolean }[];
  templates: { id: string; groups: { name: string; options: { name: string }[] }[] }[];
};

async function readMenu(c: pg.PoolClient): Promise<MenuRows> {
  return {
    categories: (await c.query('select id, name, archived from categories order by position, id')).rows,
    // Nach Kategorie und Platz, wie die Karte am Tablet.
    items: (
      await c.query(
        `select i.name, i.info, i.category_id, i.template_id, i.archived
           from items i join categories k on k.id = i.category_id and k.business_id = i.business_id
          order by k.position, k.id, i.position, i.id`,
      )
    ).rows,
    templates: (await c.query('select id, groups from modifier_templates')).rows,
  };
}

/** Alle Namen der Speisekarte aus der Datenbank, auch stillgelegte: eine ältere Übersetzungsdatei soll weiter passen. */
async function allNames(c: pg.PoolClient): Promise<Set<string>> {
  const m = await readMenu(c);
  const groups: Json = {};
  for (const t of m.templates) {
    groups[t.id] = t.groups.map((g) => ({ name: g.name, optionen: g.options.map((o) => ({ name: o.name })) }));
  }
  return menuNames(m.categories, m.items.map((i) => ({ name: i.name, info: i.info })), groups);
}

async function storedValues(c: pg.PoolClient): Promise<Map<string, Values>> {
  const rows = (await c.query<{ source: string; values: Values }>('select source, values from translations')).rows;
  return new Map(rows.map((r) => [r.source, r.values]));
}

const putBody = z.strictObject({
  source: z.string(),
  lang: z.enum(TRANSLATION_LANGS),
  value: z.string(),
});

const invalid = (problems: string[]) =>
  new ApiError(422, 'translations_invalid', 'Die Übersetzungen sind nicht in Ordnung.', { problems });

/** Adressen für Übersetzungen in der Verwaltung. Nach installAuth aufrufen. */
export function installTranslationRoutes(app: FastifyInstance): void {
  const { db, now } = app.deps;

  app.get<{ Params: { b: string } }>('/api/admin/businesses/:b/translations', async (req) => {
    await requireBusinessAccess(req, req.params.b);
    return withBusiness(db, req.params.b.toLowerCase(), async (c) => {
      const m = await readMenu(c);
      const stored = await storedValues(c);
      const seen = new Set<string>();
      const rows: Row[] = [];
      /** Ein Name steht nur beim ersten Vorkommen. */
      const take = (raw: string | null): Row[] => {
        const source = raw?.trim() ?? '';
        if (source === '' || seen.has(source)) return [];
        seen.add(source);
        const row = { source, values: stored.get(source) ?? {} };
        rows.push(row);
        return [row];
      };
      const sections: Section[] = [];
      const activeCategories = m.categories.filter((k) => !k.archived);
      sections.push({ kind: 'categories', title: 'Kategorien', rows: activeCategories.flatMap((k) => take(k.name)) });
      for (const k of activeCategories) {
        const own = m.items.filter((i) => i.category_id === k.id && !i.archived);
        sections.push({
          kind: 'category',
          title: k.name,
          rows: own.flatMap((i) => [...take(i.name), ...take(i.info)]),
        });
      }
      const templates = new Map(m.templates.map((t) => [t.id, t]));
      const used: string[] = [];
      for (const i of m.items) {
        if (!i.archived && i.template_id !== null && templates.has(i.template_id) && !used.includes(i.template_id)) {
          used.push(i.template_id);
        }
      }
      sections.push({
        kind: 'extras',
        title: 'Auswahl und Extras',
        rows: used.flatMap((id) => templates.get(id)!.groups.flatMap((g) => [...take(g.name), ...g.options.flatMap((o) => take(o.name))])),
      });
      const done = Object.fromEntries(
        TRANSLATION_LANGS.map((l) => [l, rows.filter((r) => (r.values[l] ?? '') !== '').length]),
      );
      return { sections: sections.filter((s) => s.rows.length > 0 || s.kind === 'categories'), total: rows.length, done };
    });
  });

  app.put<{ Params: { b: string } }>('/api/admin/businesses/:b/translations', async (req) => {
    const user = await requireBusinessAccess(req, req.params.b);
    const businessId = req.params.b.toLowerCase();
    const parsed = putBody.safeParse(req.body);
    if (!parsed.success) {
      throw new ApiError(422, 'translation_invalid', 'Es fehlen Name, Sprache (en, zh, tr oder ar) oder Text.');
    }
    const source = parsed.data.source.trim();
    const lang = parsed.data.lang;
    const text = parsed.data.value.trim();
    // Länge in Zeichen wie in Dart (UTF-16-Einheiten).
    if (text.length > MAX_VALUE_LENGTH) {
      throw new ApiError(422, 'translation_invalid', `Der Text darf höchstens ${MAX_VALUE_LENGTH} Zeichen haben.`);
    }
    const at = now();
    return withBusinessWrite(db, businessId, async (c) => {
      if (!(await allNames(c)).has(source)) throw new ApiError(404, 'not_found', 'Das gibt es nicht.');
      const before = (await storedValues(c)).get(source);
      const values: Values = { ...before };
      // Leer oder gleich dem Namen heißt: keine Übersetzung, der Name der Speisekarte gilt.
      if (text === '' || text === source) delete values[lang];
      else values[lang] = text;
      if (before === undefined ? Object.keys(values).length > 0 : !same(before, values)) {
        await c.query(
          `insert into translations (business_id, source, values, change_seq) values ($1, $2, $3, $4)
           on conflict (business_id, source) do update set values = excluded.values, change_seq = excluded.change_seq`,
          [businessId, source, JSON.stringify(values), await nextChangeSeq(c)],
        );
        await audit(c, { userId: user.id, businessId, action: 'translation.update', detail: { source, lang } }, at);
      }
      return { source, values };
    });
  });

  // Mit 8 MB Grenze: Anmeldung und Rolle prüft onRequest, bevor ein Byte des Körpers gelesen wird.
  const providerFirst = async (req: FastifyRequest<{ Params: { b: string } }>) => {
    requireProvider(req);
    await requireBusinessAccess(req, req.params.b);
  };

  app.post<{ Params: { b: string } }>(
    '/api/admin/businesses/:b/translations/import',
    { bodyLimit: BODY_LIMIT, onRequest: providerFirst },
    async (req) => {
      const user = requireProvider(req);
      await requireBusinessAccess(req, req.params.b);
      const businessId = req.params.b.toLowerCase();
      const body = z.object({ translationsFile: z.string() }).safeParse(req.body);
      if (!body.success) throw new ApiError(400, 'bad_request', 'Die Anfrage ist nicht in Ordnung.');
      if (Buffer.byteLength(body.data.translationsFile, 'utf8') > MAX_FILE_BYTES) {
        throw new ApiError(413, 'file_too_large', 'Die Datei ist größer als 1 MB.');
      }
      let file: unknown;
      try {
        file = JSON.parse(body.data.translationsFile);
      } catch {
        throw invalid(['Die Datei ist keine gültige Übersetzungs-Datei.']);
      }
      if (typeof file !== 'object' || file === null || Array.isArray(file) || !('uebersetzungen' in file)) {
        throw invalid(['Die Datei ist keine gültige Übersetzungs-Datei: "uebersetzungen" fehlt.']);
      }
      const at = now();
      return withBusinessWrite(db, businessId, async (c) => {
        const problems: string[] = [];
        const t = parseTranslations((file as Json)['uebersetzungen'], await allNames(c), problems);
        if (problems.length > 0) throw invalid(problems);
        const changed = await applyTranslations(c, businessId, t);
        await audit(c, { userId: user.id, businessId, action: 'translation.import', detail: { changed } }, at);
        return { changed };
      });
    },
  );
}
