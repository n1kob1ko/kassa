import type pg from 'pg';
import { nextChangeSeq } from '../db/tenant.js';
import type { ParsedMenu } from './parse_menu.js';
import { applyTranslations } from './translations.js';

export type Counts = { added: number; changed: number; archived: number };
export type ImportSummary = { categories: Counts; items: Counts; templates: Counts; translations: number };

/** Größter Betrag in Cent, den der Server annimmt. Weit unter dem, was eine PostgreSQL-integer-Spalte fasst. */
export const MAX_CENTS = 99_999_999;

const tooBig = (v: number) => !Number.isSafeInteger(v) || v > MAX_CENTS;
const LIMIT_TEXT = `Erlaubt sind höchstens ${MAX_CENTS} Cent.`;

/**
 * Prüft nur für den Server, ob alle Beträge in die Datenbank passen.
 * Die Regeln der Datei selbst stehen in parse_menu.ts und gleichen denen der Tablet-App.
 * Gibt eine Zeile pro zu großem Wert zurück.
 */
export function checkCentsRange(menu: ParsedMenu): string[] {
  const problems: string[] = [];
  for (const item of menu.items) {
    if (tooBig(item.priceCents)) problems.push(`Artikel "${item.id}": Der Preis ist zu hoch. ${LIMIT_TEXT}`);
    if (tooBig(item.depositCents)) problems.push(`Artikel "${item.id}": Das Pfand ist zu hoch. ${LIMIT_TEXT}`);
  }
  for (const template of menu.templates) {
    for (const group of template.groups) {
      const where = `Auswahl "${template.id}", Gruppe "${group.name}", Option`;
      for (const o of group.options) {
        if (tooBig(o.surchargeCents) || o.surchargeCents < -MAX_CENTS) {
          problems.push(`${where} "${o.name}": Der Aufpreis ist zu hoch. ${LIMIT_TEXT}`);
        }
        if (o.depositCents !== null && tooBig(o.depositCents)) {
          problems.push(`${where} "${o.name}": Das Pfand ist zu hoch. ${LIMIT_TEXT}`);
        }
      }
    }
  }
  return problems;
}

/** Gleicher Inhalt gibt gleichen Text, egal in welcher Reihenfolge PostgreSQL die jsonb-Schlüssel liefert. */
function canonical(v: unknown): string {
  if (Array.isArray(v)) return `[${v.map(canonical).join(',')}]`;
  if (typeof v === 'object' && v !== null) {
    const o = v as Record<string, unknown>;
    return `{${Object.keys(o)
      .sort()
      .map((k) => `${JSON.stringify(k)}:${canonical(o[k])}`)
      .join(',')}}`;
  }
  return JSON.stringify(v ?? null);
}

const sameLines = (a: string[], b: string[]) => a.length === b.length && a.every((x, i) => x === b[i]);

type CategoryRow = { id: string; name: string; position: number; archived: boolean };
type ItemRow = {
  id: string;
  name: string;
  price_cents: number;
  category_id: string;
  tax_percent: number;
  deposit_cents: number;
  tags: string;
  info: string | null;
  template_id: string | null;
  position: number;
  archived: boolean;
};
type TemplateRow = { id: string; name: string; groups: unknown; archived: boolean };

/**
 * Spielt eine geprüfte Speisekarte in einen Betrieb ein. Nur innerhalb von withBusinessWrite aufrufen.
 * Die Datei gewinnt bei allem, was in ihr steht. `favorite`, `in_sale` und `photo_file_id` bleiben.
 * Was fehlt, wird stillgelegt, was wieder auftaucht, wieder in Betrieb genommen.
 * Nur Zeilen, die sich wirklich ändern, bekommen eine neue Änderungs-Nummer.
 * Übersetzungen werden nie gelöscht, nur je Name und Sprache ersetzt.
 * Mitarbeiter aus der Datei werden nie angelegt.
 */
export async function importMenu(
  c: pg.PoolClient,
  businessId: string,
  menu: ParsedMenu,
  now: Date,
): Promise<ImportSummary> {
  const summary: ImportSummary = {
    categories: { added: 0, changed: 0, archived: 0 },
    items: { added: 0, changed: 0, archived: 0 },
    templates: { added: 0, changed: 0, archived: 0 },
    translations: 0,
  };

  // Betriebsdaten
  const b = menu.business;
  const biz = (
    await c.query<{ name: string; address_lines: string[]; vat_id: string | null; receipt_footer: string | null }>(
      'select name, address_lines, vat_id, receipt_footer from businesses where id = $1',
      [businessId],
    )
  ).rows[0]!;
  if (
    biz.name !== b.name ||
    !sameLines(biz.address_lines, b.addressLines) ||
    biz.vat_id !== b.vatId ||
    biz.receipt_footer !== b.receiptFooter
  ) {
    await c.query(
      `update businesses set name = $2, address_lines = $3, vat_id = $4, receipt_footer = $5, change_seq = $6 where id = $1`,
      [businessId, b.name, b.addressLines, b.vatId, b.receiptFooter, await nextChangeSeq(c)],
    );
  }

  // Kategorien
  const oldCategories = new Map(
    (await c.query<CategoryRow>('select id, name, position, archived from categories')).rows.map((r) => [r.id, r]),
  );
  for (const k of menu.categories) {
    const old = oldCategories.get(k.id);
    if (!old) {
      await c.query(
        'insert into categories (business_id, id, name, position, change_seq) values ($1, $2, $3, $4, $5)',
        [businessId, k.id, k.name, k.position, await nextChangeSeq(c)],
      );
      summary.categories.added++;
    } else if (old.name !== k.name || old.position !== k.position || old.archived) {
      await c.query('update categories set name = $3, position = $4, archived = false, change_seq = $5 where business_id = $1 and id = $2', [
        businessId,
        k.id,
        k.name,
        k.position,
        await nextChangeSeq(c),
      ]);
      summary.categories.changed++;
    }
    oldCategories.delete(k.id);
  }
  for (const old of oldCategories.values()) {
    if (old.archived) continue;
    await c.query('update categories set archived = true, change_seq = $3 where business_id = $1 and id = $2', [
      businessId,
      old.id,
      await nextChangeSeq(c),
    ]);
    summary.categories.archived++;
  }

  // Artikel
  const oldItems = new Map(
    (
      await c.query<ItemRow>(
        `select id, name, price_cents, category_id, tax_percent, deposit_cents, tags, info, template_id, position, archived from items`,
      )
    ).rows.map((r) => [r.id, r]),
  );
  for (const i of menu.items) {
    const tags = [...i.tags].sort().join(',');
    const old = oldItems.get(i.id);
    if (!old) {
      await c.query(
        `insert into items (business_id, id, name, price_cents, category_id, tax_percent, deposit_cents, tags, info,
                            template_id, position, change_seq, price_changed_at, in_sale_changed_at,
                            favorite_changed_at, deposit_changed_at, tags_changed_at)
         values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $13, $13, $13, $13)`,
        [
          businessId,
          i.id,
          i.name,
          i.priceCents,
          i.categoryId,
          i.taxPercent,
          i.depositCents,
          tags,
          i.info,
          i.templateId,
          i.position,
          await nextChangeSeq(c),
          now,
        ],
      );
      summary.items.added++;
    } else if (
      old.name !== i.name ||
      old.price_cents !== i.priceCents ||
      old.category_id !== i.categoryId ||
      old.tax_percent !== i.taxPercent ||
      old.deposit_cents !== i.depositCents ||
      old.tags !== tags ||
      old.info !== i.info ||
      old.template_id !== i.templateId ||
      old.position !== i.position ||
      old.archived
    ) {
      await c.query(
        `update items set name = $3, price_cents = $4, category_id = $5, tax_percent = $6, deposit_cents = $7,
                tags = $8, info = $9, template_id = $10, position = $11, archived = false, change_seq = $12,
                price_changed_at = case when price_cents <> $4 then $13 else price_changed_at end,
                deposit_changed_at = case when deposit_cents <> $7 then $13 else deposit_changed_at end,
                tags_changed_at = case when tags <> $8 then $13 else tags_changed_at end
          where business_id = $1 and id = $2`,
        [
          businessId,
          i.id,
          i.name,
          i.priceCents,
          i.categoryId,
          i.taxPercent,
          i.depositCents,
          tags,
          i.info,
          i.templateId,
          i.position,
          await nextChangeSeq(c),
          now,
        ],
      );
      summary.items.changed++;
    }
    oldItems.delete(i.id);
  }
  for (const old of oldItems.values()) {
    if (old.archived) continue;
    await c.query('update items set archived = true, change_seq = $3 where business_id = $1 and id = $2', [
      businessId,
      old.id,
      await nextChangeSeq(c),
    ]);
    summary.items.archived++;
  }

  // Auswahl-Vorlagen: die Gruppen werden als ganzes Stück verglichen.
  const oldTemplates = new Map(
    (await c.query<TemplateRow>('select id, name, groups, archived from modifier_templates')).rows.map((r) => [r.id, r]),
  );
  for (const t of menu.templates) {
    const old = oldTemplates.get(t.id);
    if (!old) {
      await c.query(
        'insert into modifier_templates (business_id, id, name, groups, change_seq) values ($1, $2, $3, $4, $5)',
        [businessId, t.id, t.name, JSON.stringify(t.groups), await nextChangeSeq(c)],
      );
      summary.templates.added++;
    } else if (old.name !== t.name || old.archived || canonical(old.groups) !== canonical(t.groups)) {
      await c.query(
        'update modifier_templates set name = $3, groups = $4, archived = false, change_seq = $5 where business_id = $1 and id = $2',
        [businessId, t.id, t.name, JSON.stringify(t.groups), await nextChangeSeq(c)],
      );
      summary.templates.changed++;
    }
    oldTemplates.delete(t.id);
  }
  for (const old of oldTemplates.values()) {
    if (old.archived) continue;
    await c.query('update modifier_templates set archived = true, change_seq = $3 where business_id = $1 and id = $2', [
      businessId,
      old.id,
      await nextChangeSeq(c),
    ]);
    summary.templates.archived++;
  }

  // Wörterbuch: je Name und Sprache ersetzen, der Rest bleibt.
  summary.translations = await applyTranslations(c, businessId, menu.translations);

  return summary;
}
