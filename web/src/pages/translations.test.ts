import { describe, expect, test } from 'vitest';
import type { TranslationSection } from '../api/translations';
import { LANGUAGES, languageOf, progressOf, progressText, storedLanguage, visibleSections } from './translations';

const SECTIONS: TranslationSection[] = [
  { kind: 'categories', title: 'Kategorien', rows: [{ source: 'Bowls', values: { en: 'Bowls', tr: 'Kâseler' } }] },
  {
    kind: 'category',
    title: 'Bowls',
    rows: [
      { source: 'Huhn Bowl', values: { en: 'Chicken bowl' } },
      { source: 'Teigtaschen', values: {} },
      { source: '5 Stück', values: { en: '' } },
    ],
  },
  { kind: 'extras', title: 'Auswahl und Extras', rows: [{ source: 'Größe', values: { en: 'Size' } }] },
];

describe('visibleSections', () => {
  test('alle Zeilen, wenn nicht gefiltert wird', () => {
    expect(visibleSections(SECTIONS, 'en', false)).toEqual(SECTIONS);
  });

  test('"Nur fehlende" zeigt nur Namen ohne Übersetzung in der Sprache und lässt leere Abschnitte weg', () => {
    const shown = visibleSections(SECTIONS, 'en', true);
    expect(shown.map((s) => s.title)).toEqual(['Bowls']);
    expect(shown[0]!.rows.map((r) => r.source)).toEqual(['Teigtaschen', '5 Stück']);
  });

  test('je Sprache anders', () => {
    const shown = visibleSections(SECTIONS, 'tr', true);
    expect(shown.map((s) => s.title)).toEqual(['Bowls', 'Auswahl und Extras']);
  });

  test('ein leerer Abschnitt fällt immer weg, auch ohne Filter', () => {
    const withEmpty: TranslationSection[] = [{ kind: 'categories', title: 'Kategorien', rows: [] }, ...SECTIONS.slice(1)];
    expect(visibleSections(withEmpty, 'en', false).map((s) => s.title)).toEqual(['Bowls', 'Auswahl und Extras']);
  });

  test('gerade übersetzte Namen bleiben unter "Nur fehlende" stehen, bis der Filter neu angeht', () => {
    const shown = visibleSections(SECTIONS, 'en', true, new Set(['Huhn Bowl']));
    expect(shown[0]!.rows.map((r) => r.source)).toEqual(['Huhn Bowl', 'Teigtaschen', '5 Stück']);
  });
});

describe('progressText', () => {
  test('Stand als "N von M übersetzt"', () => {
    expect(progressText(62, 140)).toBe('62 von 140 übersetzt');
    expect(progressText(0, 3)).toBe('0 von 3 übersetzt');
    expect(progressText(1067, 2000)).toBe('1.067 von 2.000 übersetzt');
  });

  test('voll: "Alles übersetzt."', () => {
    expect(progressText(140, 140)).toBe('Alles übersetzt.');
  });
});

test('progressOf zählt nicht leere Übersetzungen der Sprache', () => {
  expect(progressOf(SECTIONS, 'en')).toEqual({ done: 3, total: 5 });
  expect(progressOf(SECTIONS, 'tr')).toEqual({ done: 1, total: 5 });
  expect(progressOf(SECTIONS, 'ar')).toEqual({ done: 0, total: 5 });
});

test('Sprachen: Namen, Reihenfolge und Schreibrichtung', () => {
  expect(LANGUAGES.map((l) => [l.code, l.name, l.dir])).toEqual([
    ['en', 'English', 'ltr'],
    ['zh', '中文', 'ltr'],
    ['tr', 'Türkçe', 'ltr'],
    ['ar', 'العربية', 'rtl'],
  ]);
  expect(languageOf('ar').name).toBe('العربية');
});

test('storedLanguage: gemerkte Sprache, sonst English', () => {
  expect(storedLanguage('tr')).toBe('tr');
  expect(storedLanguage(null)).toBe('en');
  expect(storedLanguage('de')).toBe('en');
  expect(storedLanguage('xx')).toBe('en');
});
