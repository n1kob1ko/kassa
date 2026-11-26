import { expect, test } from 'vitest';
import { summaryText, type ImportSummary } from './businesses';

const counts = (added: number, changed: number, archived: number) => ({ added, changed, archived });

test('summaryText: Summe über Kategorien, Artikel und Vorlagen, Übersetzungen nur wenn welche kamen', () => {
  const summary: ImportSummary = { categories: counts(1, 0, 0), items: counts(2, 3, 1), templates: counts(0, 1, 0), translations: 0 };
  expect(summaryText(summary)).toBe('3 neu, 4 geändert, 1 stillgelegt');
  expect(summaryText({ ...summary, translations: 1 })).toBe('3 neu, 4 geändert, 1 stillgelegt, 1 Name übersetzt');
  expect(summaryText({ ...summary, translations: 12 })).toBe('3 neu, 4 geändert, 1 stillgelegt, 12 Namen übersetzt');
});
