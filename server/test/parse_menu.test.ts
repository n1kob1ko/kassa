import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, test } from 'vitest';
import { MenuImportError, parseMenuFile } from '../src/menu/parse_menu.js';

const root = join(import.meta.dirname, '../../shared/fixtures/menu');
const inputs = readdirSync(join(root, 'inputs'))
  .filter((f) => f.endsWith('.json'))
  .sort();

type Expected = { problems: string[] } | { menu: unknown };
const expectedOf = (file: string): Expected =>
  JSON.parse(readFileSync(join(root, 'expected', file), 'utf8'));

/** Die Meldung als Liste fester Textteile; `$name` und `${...}` sind Platzhalter. */
function messageParts(literal: string): string[] {
  return literal
    .replace(/\\(.)/g, '$1')
    .split(/\$\{[^}]*\}|\$\w+/)
    .filter((p) => p.length > 0);
}

describe('gemeinsame Beispiele mit der App', () => {
  test('es gibt mindestens 30 Eingaben und zu jeder eine expected-Datei', () => {
    expect(inputs.length).toBeGreaterThanOrEqual(30);
    expect(readdirSync(join(root, 'expected')).sort()).toEqual(inputs);
  });

  for (const name of inputs) {
    test(`Beispiel ${name}`, () => {
      const text = readFileSync(join(root, 'inputs', name), 'utf8');
      const expected = expectedOf(name);
      if ('problems' in expected) {
        let thrown: unknown;
        try {
          parseMenuFile(text);
        } catch (e) {
          thrown = e;
        }
        expect(thrown).toBeInstanceOf(MenuImportError);
        expect((thrown as MenuImportError).problems).toEqual(expected.problems);
      } else {
        // Ältere Beispiele kennen kein Wörterbuch: fehlt `translations`, gilt es als leer.
        expect(parseMenuFile(text)).toEqual({ translations: {}, ...(expected.menu as object) });
      }
    });
  }

  test('eine Kennung mit "open-amount-" vorn ist für den freien Betrag vergeben', () => {
    const text = JSON.stringify({
      betrieb: 'X',
      kategorien: [{ id: 'a', name: 'A' }],
      artikel: [{ id: 'open-amount-20', name: 'X', preis_cent: 100, kategorie: 'a', mwst: 20 }],
    });
    let thrown: unknown;
    try {
      parseMenuFile(text);
    } catch (e) {
      thrown = e;
    }
    expect(thrown).toBeInstanceOf(MenuImportError);
    expect((thrown as MenuImportError).problems).toEqual([
      'Artikel "open-amount-20": Die Kennung darf nicht mit "open-amount-" beginnen.',
    ]);
  });

  test('jede Meldung aus menu_import.dart kommt in einem Beispiel vor', () => {
    const dart = readFileSync(
      join(import.meta.dirname, '../../app/lib/domain/menu_import.dart'),
      'utf8',
    );
    const literal = String.raw`'((?:\$\{[^}]*\}|[^'\\]|\\.)*)'`;
    const found = [
      ...dart.matchAll(new RegExp(String.raw`(?:problems\.add\(|fail\(|_invalidFile =|_allowedRates =)\s*` + literal, 'g')),
    ].map((m) => m[1] as string);
    expect(found.length).toBeGreaterThanOrEqual(35);

    const problems: string[] = [];
    for (const name of inputs) {
      const e = expectedOf(name);
      if ('problems' in e) problems.push(...e.problems);
    }
    const missing = found.filter((lit) => {
      const parts = messageParts(lit);
      return !problems.some((p) => {
        let from = 0;
        for (const part of parts) {
          const at = p.indexOf(part, from);
          if (at < 0) return false;
          from = at + part.length;
        }
        return true;
      });
    });
    expect(missing).toEqual([]);
  });
});
