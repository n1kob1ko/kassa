// Das Wörterbuch der Speisekarte (Schlüssel `uebersetzungen` der Datei).
// Zeile für Zeile nach _translations in app/lib/domain/menu_import.dart.
import type pg from 'pg';
import { nextChangeSeq } from '../db/tenant.js';

export const TRANSLATION_LANGS = ['en', 'zh', 'tr', 'ar'] as const;
export type TranslationLang = (typeof TRANSLATION_LANGS)[number];
/** Name der Speisekarte -> Sprache -> Text. */
export type Translations = Record<string, Partial<Record<TranslationLang, string>>>;

type Json = Record<string, unknown>;
const isMap = (v: unknown): v is Json => typeof v === 'object' && v !== null && !Array.isArray(v);

function trimmed(v: unknown): string | null {
  if (typeof v !== 'string') return null;
  const t = v.trim();
  return t === '' ? null : t;
}

/**
 * Alle Namen der Speisekarte, die übersetzt werden dürfen: Kategorien, Artikel,
 * Infotexte, Gruppen und Optionen. Liest die rohe Datei wie die App, damit auch
 * Namen aus Einträgen zählen, die an anderer Stelle schon als Fehler gemeldet sind.
 */
export function menuNames(categories: unknown[], items: unknown[], groups: Json): Set<string> {
  const names = new Set<string>();
  const add = (raw: unknown) => {
    const t = trimmed(raw);
    if (t !== null) names.add(t);
  };
  for (const k of categories) if (isMap(k)) add(k['name']);
  for (const a of items) {
    if (isMap(a)) {
      add(a['name']);
      add(a['info']);
    }
  }
  for (const list of Object.values(groups)) {
    if (!Array.isArray(list)) continue;
    for (const g of list) {
      if (!isMap(g)) continue;
      add(g['name']);
      if (!Array.isArray(g['optionen'])) continue;
      for (const o of g['optionen']) if (isMap(o)) add(o['name']);
    }
  }
  return names;
}

/**
 * Prüft `uebersetzungen` gegen die Namen der Speisekarte. Name und Text werden gekürzt;
 * nur ein leerer Text zählt als keiner und wird nicht gespeichert. Ein Text gleich dem Namen
 * ist eine gültige Übersetzung.
 */
export function parseTranslations(raw: unknown, names: Set<string>, problems: string[]): Translations {
  if (raw === undefined || raw === null) return {};
  if (!isMap(raw) || Object.values(raw).some((v) => !isMap(v))) {
    problems.push('"uebersetzungen" muss eine Liste von Namen mit ihren Übersetzungen sein.');
    return {};
  }
  const result: Translations = {};
  for (const [key, value] of Object.entries(raw)) {
    const name = key.trim();
    if (!names.has(name)) {
      problems.push(`Übersetzung "${name}": Diesen Namen gibt es in der Speisekarte nicht.`);
      continue;
    }
    const texts: Translations[string] = {};
    for (const [code, v] of Object.entries(value as Json)) {
      if (!(TRANSLATION_LANGS as readonly string[]).includes(code)) {
        problems.push(
          `Übersetzung "${name}": Die Sprache "${code}" kennt die Kassa nicht. Erlaubt sind en, zh, tr und ar.`,
        );
        continue;
      }
      if (typeof v !== 'string') {
        problems.push(`Übersetzung "${name}", Sprache "${code}": Der Text fehlt.`);
        continue;
      }
      const text = v.trim();
      // Länge in Zeichen wie in Dart (UTF-16-Einheiten).
      if (text.length > 200) {
        problems.push(`Übersetzung "${name}", Sprache "${code}": Höchstens 200 Zeichen.`);
        continue;
      }
      if (text !== '') texts[code as TranslationLang] = text;
    }
    if (Object.keys(texts).length > 0) result[name] = { ...result[name], ...texts };
  }
  return result;
}

/** Gleicher Inhalt gleich, egal in welcher Reihenfolge jsonb die Schlüssel liefert. */
export const same = (a: Json, b: Json) => {
  const ka = Object.keys(a).sort();
  const kb = Object.keys(b).sort();
  return ka.length === kb.length && ka.every((k, i) => k === kb[i] && a[k] === b[k]);
};

/**
 * Schreibt Einträge: je Name und Sprache ersetzen, der Rest bleibt. Nur eine Zeile, deren Werte sich
 * wirklich ändern, bekommt eine neue Änderungs-Nummer. Nur in withBusinessWrite aufrufen.
 * Gibt die Zahl geänderter Namen zurück.
 */
export async function applyTranslations(c: pg.PoolClient, businessId: string, t: Translations): Promise<number> {
  const old = new Map(
    (await c.query<{ source: string; values: Json }>('select source, values from translations')).rows.map((r) => [
      r.source,
      r.values,
    ]),
  );
  let changed = 0;
  for (const [source, texts] of Object.entries(t)) {
    const before = old.get(source);
    const merged: Json = { ...before, ...texts };
    if (before !== undefined && same(before, merged)) continue;
    await c.query(
      `insert into translations (business_id, source, values, change_seq) values ($1, $2, $3, $4)
       on conflict (business_id, source) do update set values = excluded.values, change_seq = excluded.change_seq`,
      [businessId, source, JSON.stringify(merged), await nextChangeSeq(c)],
    );
    changed++;
  }
  return changed;
}
