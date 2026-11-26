import type { TranslationLang, TranslationSection } from '../api/translations';
import { groupThousands } from '../format';

/** `tag` steht als `lang` an Feldern und Texten: der Browser wählt danach Schrift und Silbentrennung. */
export type Language = { code: TranslationLang; name: string; tag: string; dir: 'ltr' | 'rtl' };

/** Die Sprachen der Übersetzungen, mit ihrem eigenen Namen, in dieser Reihenfolge. Arabisch schreibt von rechts. */
export const LANGUAGES: Language[] = [
  { code: 'en', name: 'English', tag: 'en', dir: 'ltr' },
  { code: 'zh', name: '中文', tag: 'zh-Hans', dir: 'ltr' },
  { code: 'tr', name: 'Türkçe', tag: 'tr', dir: 'ltr' },
  { code: 'ar', name: 'العربية', tag: 'ar', dir: 'rtl' },
];

export function languageOf(code: TranslationLang): Language {
  return LANGUAGES.find((l) => l.code === code)!;
}

/** Die gemerkte Sprache, wenn es eine der vier ist, sonst English. */
export function storedLanguage(value: string | null): TranslationLang {
  return LANGUAGES.find((l) => l.code === value)?.code ?? 'en';
}

const translated = (values: Partial<Record<TranslationLang, string>>, lang: TranslationLang) => (values[lang] ?? '') !== '';

/**
 * Die Abschnitte, wie die Seite sie zeigt: ohne leere. Mit "Nur fehlende" nur Namen ohne Übersetzung in `lang`;
 * Namen in `keep` (eben übersetzt) bleiben trotzdem stehen, damit die Zeile nicht unter dem Finger verschwindet.
 */
export function visibleSections(
  sections: TranslationSection[],
  lang: TranslationLang,
  onlyMissing: boolean,
  keep: ReadonlySet<string> = new Set(),
): TranslationSection[] {
  const shown = onlyMissing
    ? sections.map((s) => ({ ...s, rows: s.rows.filter((r) => !translated(r.values, lang) || keep.has(r.source)) }))
    : sections;
  return shown.filter((s) => s.rows.length > 0);
}

/**
 * Ein Schlüssel je Abschnitt für React: Art und Titel, ab dem zweiten Abschnitt mit gleichem Titel mit einer Nummer
 * (zwei Kategorien dürfen gleich heißen). So mischen sich die Entwürfe der Felder nicht, wenn der Filter wechselt.
 */
export function sectionKeys(sections: TranslationSection[]): string[] {
  const seen = new Map<string, number>();
  return sections.map((s) => {
    const base = `${s.kind}/${s.title}`;
    const n = (seen.get(base) ?? 0) + 1;
    seen.set(base, n);
    return n === 1 ? base : `${base}#${n}`;
  });
}

/** Wie viele Namen in `lang` übersetzt sind, von allen. */
export function progressOf(sections: TranslationSection[], lang: TranslationLang): { done: number; total: number } {
  const rows = sections.flatMap((s) => s.rows);
  return { done: rows.filter((r) => translated(r.values, lang)).length, total: rows.length };
}

/** "62 von 140 übersetzt", voll "Alles übersetzt.". */
export function progressText(done: number, total: number): string {
  if (total > 0 && done >= total) return 'Alles übersetzt.';
  return `${groupThousands(done)} von ${groupThousands(total)} übersetzt`;
}
