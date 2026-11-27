// Liest die Speisekarten-Datei (Anhang A des Entwurfs).
// Zeile für Zeile nach app/lib/domain/menu_import.dart: gleiche Reihenfolge
// der Prüfungen, gleiche Meldungen, gleiche Kennungen. Die gemeinsamen
// Beispiele in shared/fixtures/menu/ halten beide Leser gleich.

import { menuNames, parseTranslations, type Translations } from './translations.js';

export class MenuImportError extends Error {
  constructor(readonly problems: string[]) {
    super(problems.join(' '));
    this.name = 'MenuImportError';
  }
}

export type TaxPercent = 20 | 10 | 13 | 0 | 19;
export type ItemTag = 'vegan' | 'spicy';

export type ParsedMenu = {
  business: {
    name: string;
    addressLines: string[];
    vatId: string | null;
    receiptFooter: string | null;
  };
  categories: { id: string; name: string; position: number }[];
  items: {
    id: string;
    name: string;
    priceCents: number;
    categoryId: string;
    taxPercent: TaxPercent;
    depositCents: number;
    tags: ItemTag[];
    info: string | null;
    templateId: string | null;
    position: number;
  }[];
  templates: {
    id: string;
    name: string;
    groups: {
      id: string;
      name: string;
      min: number;
      max: number | null;
      options: {
        id: string;
        name: string;
        surchargeCents: number;
        isDefault: boolean;
        taxPercent: TaxPercent | null;
        depositCents: number | null;
      }[];
    }[];
  }[];
  staffSeeds: { name: string; pin: string; role: 'chef' | 'staff' }[];
  translations: Translations;
};

const INVALID_FILE = 'Die Datei ist keine gültige Speisekarten-Datei.';
const ALLOWED_RATES = 'Erlaubt sind 20, 10, 13, 0 und 19.';
const RATES: TaxPercent[] = [20, 10, 13, 0, 19];

type Json = Record<string, unknown>;

const isMap = (v: unknown): v is Json =>
  typeof v === 'object' && v !== null && !Array.isArray(v);
const isInt = (v: unknown): v is number => Number.isInteger(v);
const asMap = (v: unknown): Json => (isMap(v) ? v : {});

/** Wie Dart den Wert in einen Text einsetzt (nur für die Meldungen). */
function show(v: unknown): string {
  if (Array.isArray(v)) return `[${v.map(show).join(', ')}]`;
  if (isMap(v)) {
    return `{${Object.entries(v)
      .map(([k, x]) => `${k}: ${show(x)}`)
      .join(', ')}}`;
  }
  return String(v);
}

function text(v: unknown): string | null {
  if (typeof v !== 'string') return null;
  const t = v.trim();
  return t === '' ? null : t;
}

function rateOf(v: unknown): TaxPercent | null {
  if (!isInt(v)) return null;
  return RATES.find((r) => r === v) ?? null;
}

/** Freiwillige Zeilenliste: höchstens vier Zeilen, jede gekürzt, leere entfallen. */
function addressLinesOf(raw: unknown, problems: string[]): string[] {
  if (raw === undefined || raw === null) return [];
  if (!Array.isArray(raw) || raw.some((l) => typeof l !== 'string')) {
    problems.push('"adresse" muss eine Liste von Zeilen sein.');
    return [];
  }
  const lines = (raw as string[]).map((l) => l.trim()).filter((l) => l !== '');
  if (lines.length > 4) {
    problems.push('"adresse" darf höchstens 4 Zeilen haben.');
    return [];
  }
  return lines;
}

/** Freiwilliger Text: fehlt er oder ist er leer, bleibt er leer. */
function optionalText(raw: unknown, name: string, problems: string[]): string | null {
  if (raw === undefined || raw === null) return null;
  if (typeof raw !== 'string') {
    problems.push(`${name} muss ein Text sein.`);
    return null;
  }
  return text(raw);
}

type Template = ParsedMenu['templates'][number];

function parseTemplate(id: string, raw: unknown, problems: string[]): Template | null {
  const before = problems.length;
  if (!Array.isArray(raw)) {
    problems.push(`Auswahl "${id}": Die Gruppen fehlen.`);
    return null;
  }
  const groups: Template['groups'] = [];
  for (let g = 0; g < raw.length; g++) {
    const gj = asMap(raw[g]);
    const gName = text(gj['name']);
    if (gName === null) {
      problems.push(`Auswahl "${id}": Eine Gruppe hat keinen Namen.`);
      continue;
    }
    const where = `Auswahl "${id}", Gruppe "${gName}"`;
    const min = gj['min'] ?? 0;
    const maxRaw = gj['max'] ?? null;
    const optionsJson = gj['optionen'];
    if (
      !isInt(min) ||
      min < 0 ||
      (maxRaw !== null && (!isInt(maxRaw) || maxRaw < 0))
    ) {
      problems.push(`${where}: min und max müssen ganze Zahlen ab 0 sein.`);
      continue;
    }
    if (!Array.isArray(optionsJson)) {
      problems.push(`${where}: Die Optionen fehlen.`);
      continue;
    }
    const max = maxRaw as number | null;
    let groupOk = true;
    if (max !== null && min > max) {
      problems.push(`${where}: mindestens ${min} und höchstens ${max} passt nicht zusammen.`);
      groupOk = false;
    }
    const options: Template['groups'][number]['options'] = [];
    for (let o = 0; o < optionsJson.length; o++) {
      const oj = asMap(optionsJson[o]);
      const oName = text(oj['name']);
      if (oName === null) {
        problems.push(`${where}: Eine Option hat keinen Namen.`);
        groupOk = false;
        continue;
      }
      const surcharge = oj['aufpreis_cent'] ?? 0;
      if (!isInt(surcharge)) {
        problems.push(`${where}, Option "${oName}": Aufpreis muss eine ganze Zahl in Cent sein.`);
        groupOk = false;
        continue;
      }
      let rate: TaxPercent | null = null;
      if (oj['mwst'] !== undefined && oj['mwst'] !== null) {
        rate = rateOf(oj['mwst']);
        if (rate === null) {
          problems.push(
            `${where}, Option "${oName}": Steuersatz ${show(oj['mwst'])} ist nicht erlaubt. ${ALLOWED_RATES}`,
          );
          groupOk = false;
          continue;
        }
      }
      const deposit = oj['pfand_cent'] ?? null;
      if (deposit !== null && (!isInt(deposit) || deposit < 0)) {
        problems.push(`${where}, Option "${oName}": Pfand muss eine ganze Zahl ab 0 sein.`);
        groupOk = false;
        continue;
      }
      options.push({
        id: `${id}/${g}/${o}`,
        name: oName,
        surchargeCents: surcharge,
        isDefault: oj['vorgabe'] === true,
        taxPercent: rate,
        depositCents: deposit as number | null,
      });
    }
    const defaults = options.filter((x) => x.isDefault).length;
    if (max !== null && defaults > max) {
      problems.push(`${where}: ${defaults} Vorgaben, aber höchstens ${max} wählbar.`);
      groupOk = false;
    }
    if (groupOk) groups.push({ id: `${id}/${g}`, name: gName, min, max, options });
  }
  if (problems.length > before) return null;
  return { id, name: id, groups };
}

export function parseMenuFile(jsonText: string): ParsedMenu {
  let root: unknown;
  try {
    root = JSON.parse(jsonText.startsWith('﻿') ? jsonText.substring(1) : jsonText);
  } catch {
    throw new MenuImportError([INVALID_FILE]);
  }
  if (!isMap(root)) throw new MenuImportError([INVALID_FILE]);
  const categoriesJson = root['kategorien'];
  const itemsJson = root['artikel'];
  const groupsJson = root['auswahlgruppen'] ?? {};
  const staffJson = root['mitarbeiter'] ?? [];
  if (
    !Array.isArray(categoriesJson) ||
    !Array.isArray(itemsJson) ||
    !isMap(groupsJson) ||
    !Array.isArray(staffJson)
  ) {
    throw new MenuImportError([INVALID_FILE]);
  }

  const problems: string[] = [];
  const businessName = text(root['betrieb']);
  if (businessName === null) problems.push('Betrieb fehlt.');

  const addressLines = addressLinesOf(root['adresse'], problems);
  const vatId = optionalText(root['uid'], '"uid"', problems);
  const receiptFooter = optionalText(root['bon_ende'], '"bon_ende"', problems);
  if (receiptFooter !== null && receiptFooter.length > 200) {
    problems.push('"bon_ende" darf höchstens 200 Zeichen haben.');
  }

  const categories: ParsedMenu['categories'] = [];
  const categoryIds = new Set<string>();
  for (const raw of categoriesJson) {
    const k = asMap(raw);
    const id = text(k['id']);
    const name = text(k['name']);
    if (id === null) {
      problems.push('Eine Kategorie hat keine Kennung.');
      continue;
    }
    if (categoryIds.has(id)) {
      problems.push(`Kategorie "${id}" kommt doppelt vor.`);
      continue;
    }
    categoryIds.add(id);
    if (name === null) {
      problems.push(`Kategorie "${id}": Name fehlt.`);
      continue;
    }
    categories.push({ id, name, position: categories.length });
  }

  const items: ParsedMenu['items'] = [];
  const itemIds = new Set<string>();
  for (const raw of itemsJson) {
    const a = asMap(raw);
    const id = text(a['id']);
    if (id === null) {
      problems.push('Ein Artikel hat keine Kennung.');
      continue;
    }
    let ok = true;
    const fail = (message: string) => {
      problems.push(`Artikel "${id}": ${message}`);
      ok = false;
    };

    if (itemIds.has(id)) {
      problems.push(`Artikel "${id}" kommt doppelt vor.`);
      ok = false;
    }
    itemIds.add(id);
    // An der Kassa vergeben: freier Betrag (open-amount-20 usw.), Pfand
    // zurück (deposit-return-25 usw.) und Gutschein (voucher-sale); wie
    // isReservedItemId in app/lib/domain/cart.dart.
    if (id.startsWith('open-amount-')) {
      fail('Die Kennung darf nicht mit "open-amount-" beginnen.');
    } else if (id.startsWith('deposit-return-')) {
      fail('Die Kennung darf nicht mit "deposit-return-" beginnen.');
    } else if (id === 'voucher-sale') {
      fail('Die Kennung darf nicht "voucher-sale" sein.');
    }
    const name = text(a['name']);
    if (name === null) fail('Name fehlt.');

    const price = a['preis_cent'];
    if (price === undefined || price === null) {
      fail('Preis fehlt.');
    } else if (!isInt(price)) {
      fail('Preis muss eine ganze Zahl in Cent sein.');
    } else if (price < 0) {
      fail('Preis darf nicht negativ sein.');
    }

    const categoryId = text(a['kategorie']);
    if (categoryId === null) {
      fail('Kategorie fehlt.');
    } else if (!categoryIds.has(categoryId)) {
      fail(`Kategorie "${categoryId}" gibt es nicht.`);
    }

    const rate = rateOf(a['mwst']);
    if (a['mwst'] === undefined || a['mwst'] === null) {
      fail('Steuersatz fehlt.');
    } else if (rate === null) {
      fail(`Steuersatz ${show(a['mwst'])} ist nicht erlaubt. ${ALLOWED_RATES}`);
    }

    const depositRaw = a['pfand_cent'];
    let deposit = 0;
    if (depositRaw !== undefined && depositRaw !== null) {
      if (!isInt(depositRaw)) {
        fail('Pfand muss eine ganze Zahl in Cent sein.');
      } else if (depositRaw < 0) {
        fail('Pfand darf nicht negativ sein.');
      } else {
        deposit = depositRaw;
      }
    }

    const templateId = text(a['auswahl']);
    if (templateId !== null && !Object.hasOwn(groupsJson, templateId)) {
      fail(`Auswahl "${templateId}" gibt es nicht.`);
    }

    const tags: ItemTag[] = [];
    const tagRaw = a['kennzeichen'];
    const tagWords: unknown[] =
      tagRaw === undefined || tagRaw === null ? [] : Array.isArray(tagRaw) ? tagRaw : [tagRaw];
    for (const word of tagWords) {
      const key = typeof word === 'string' ? word.trim().toUpperCase() : null;
      const tag: ItemTag | null = key === 'VEGAN' ? 'vegan' : key === 'SCHARF' ? 'spicy' : null;
      if (tag === null) {
        fail(`Kennzeichen "${show(word)}" kennt die Kassa nicht.`);
      } else if (!tags.includes(tag)) {
        tags.push(tag);
      }
    }

    if (ok) {
      items.push({
        id,
        name: name as string,
        priceCents: price as number,
        categoryId: categoryId as string,
        taxPercent: rate as TaxPercent,
        depositCents: deposit,
        tags,
        info: text(a['info']),
        templateId,
        position: items.length,
      });
    }
  }

  const templates: ParsedMenu['templates'] = [];
  for (const [key, value] of Object.entries(groupsJson)) {
    const template = parseTemplate(key, value, problems);
    if (template !== null) templates.push(template);
  }

  const staffSeeds: ParsedMenu['staffSeeds'] = [];
  for (const raw of staffJson) {
    const m = asMap(raw);
    const name = text(m['name']);
    if (name === null) {
      problems.push('Ein Mitarbeiter hat keinen Namen.');
      continue;
    }
    let ok = true;
    const pin = m['pin'];
    if (typeof pin !== 'string' || !/^[0-9]{4}$/.test(pin)) {
      problems.push(`Mitarbeiter "${name}": Die PIN muss aus genau vier Ziffern bestehen.`);
      ok = false;
    }
    const role: 'chef' | 'staff' | null =
      m['rolle'] === 'chef' ? 'chef' : m['rolle'] === 'mitarbeiter' ? 'staff' : null;
    if (role === null) {
      problems.push(`Mitarbeiter "${name}": Die Rolle muss "chef" oder "mitarbeiter" sein.`);
      ok = false;
    }
    if (ok && staffSeeds.some((s) => s.pin === pin)) {
      problems.push(`Mitarbeiter "${name}": Die PIN ist in der Datei schon vergeben.`);
      ok = false;
    }
    if (ok) staffSeeds.push({ name, pin: pin as string, role: role as 'chef' | 'staff' });
  }

  // Übersetzungsprobleme kommen nach allen anderen.
  const translations = parseTranslations(
    root['uebersetzungen'],
    menuNames(categoriesJson, itemsJson, groupsJson),
    problems,
  );

  if (problems.length > 0) throw new MenuImportError(problems);
  return {
    business: { name: businessName as string, addressLines, vatId, receiptFooter },
    categories,
    items,
    templates,
    staffSeeds,
    translations,
  };
}
