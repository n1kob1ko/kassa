import { afterAll, beforeAll, expect, test } from 'vitest';
import { withBusiness, withBusinessWrite, withSystem } from '../src/db/tenant.js';
import { importMenu } from '../src/menu/import_menu.js';
import { parseMenuFile } from '../src/menu/parse_menu.js';
import { applyTranslations } from '../src/menu/translations.js';
import { createTestDb } from './support/db.js';
import { menuFixture } from './support/businesses.js';
import { insertBusiness } from './support/users.js';

let t: Awaited<ReturnType<typeof createTestDb>>;
beforeAll(async () => {
  t = await createTestDb();
});
afterAll(async () => {
  await t.drop();
});

const T0 = new Date('2026-11-18T10:00:00Z');

/** Die Beispieldatei mit einem Wörterbuch. */
function menu(dict?: object) {
  const file = JSON.parse(menuFixture('beispiel-imbiss'));
  if (dict) file.uebersetzungen = dict;
  return parseMenuFile(JSON.stringify(file));
}

const run = (b: string, m: ReturnType<typeof menu>) => withBusinessWrite(t.db, b, (c) => importMenu(c, b, m, T0));
const rows = (b: string) =>
  withBusiness(
    t.db,
    b,
    async (c) =>
      (await c.query('select source, values, change_seq from translations order by source')).rows as {
        source: string;
        values: Record<string, string>;
        change_seq: string;
      }[],
  );

test('Tabelle translations: ein Betrieb sieht und schreibt die Zeilen des anderen nicht', async () => {
  const a = await insertBusiness(t.db, 'A');
  const b = await insertBusiness(t.db, 'B');
  const insert = `insert into translations (business_id, source, values, change_seq) values ($1, 'Cola', '{"en":"Cola"}', 1)`;
  await withBusiness(t.db, a, (c) => c.query(insert, [a]));
  expect((await rows(a)).length).toBe(1);
  expect((await rows(b)).length).toBe(0);
  expect((await withSystem(t.db, (c) => c.query('select 1 from translations'))).rowCount).toBe(0);
  await expect(withBusiness(t.db, b, (c) => c.query(insert, [a]))).rejects.toThrow(/row-level security/);
});

test('Einspielen schreibt das Wörterbuch und zählt die Namen', async () => {
  const b = await insertBusiness(t.db);
  const summary = await run(b, menu({ 'Huhn Bowl': { en: 'Chicken bowl', ar: 'طبق دجاج' }, 'Cola 0,33 l': { tr: 'Kola' } }));
  expect(summary.translations).toBe(2);
  expect((await rows(b)).map((r) => [r.source, r.values])).toEqual([
    ['Cola 0,33 l', { tr: 'Kola' }],
    ['Huhn Bowl', { en: 'Chicken bowl', ar: 'طبق دجاج' }],
  ]);
});

test('Text gleich dem Namen wird geschrieben, nur Leerzeichen nicht', async () => {
  const b = await insertBusiness(t.db);
  const summary = await run(b, menu({ 'Cola 0,33 l': { en: ' Cola 0,33 l ', tr: '   ' } }));
  expect(summary.translations).toBe(1);
  expect((await rows(b)).map((r) => [r.source, r.values])).toEqual([['Cola 0,33 l', { en: 'Cola 0,33 l' }]]);
});

test('je Name und Sprache ersetzen, der Rest bleibt', async () => {
  const b = await insertBusiness(t.db);
  await run(b, menu({ 'Cola 0,33 l': { en: 'Cola drink', tr: 'Kola' }, 'Huhn Bowl': { en: 'Chicken bowl' } }));
  const summary = await run(b, menu({ 'Cola 0,33 l': { en: 'Soda' } }));
  expect(summary.translations).toBe(1);
  const after = await rows(b);
  expect(after.find((r) => r.source === 'Cola 0,33 l')!.values).toEqual({ en: 'Soda', tr: 'Kola' });
  expect(after.find((r) => r.source === 'Huhn Bowl')!.values).toEqual({ en: 'Chicken bowl' });
});

test('eine Datei ohne uebersetzungen löscht nichts', async () => {
  const b = await insertBusiness(t.db);
  await run(b, menu({ 'Cola 0,33 l': { en: 'Soda' } }));
  const before = await rows(b);
  expect((await run(b, menu())).translations).toBe(0);
  expect(await rows(b)).toEqual(before);
});

test('zweimal dieselbe Datei ändert keine Änderungs-Nummer', async () => {
  const b = await insertBusiness(t.db);
  const dict = { 'Cola 0,33 l': { en: 'Soda', tr: 'Kola' }, 'Huhn Bowl': { en: 'Chicken bowl' } };
  await run(b, menu(dict));
  const before = await rows(b);
  const summary = await run(b, menu(dict));
  expect(summary.translations).toBe(0);
  expect(await rows(b)).toEqual(before);
  // Auch ein Teil des Gespeicherten ist keine Änderung.
  expect(await withBusinessWrite(t.db, b, (c) => applyTranslations(c, b, { 'Cola 0,33 l': { tr: 'Kola' } }))).toBe(0);
  expect(await rows(b)).toEqual(before);
});

test('eine gelöschte Zeile (values {}) wird durch neue Texte wieder belebt und bekommt eine neue Nummer', async () => {
  const b = await insertBusiness(t.db);
  await run(b, menu({ 'Cola 0,33 l': { en: 'Soda' } }));
  const old = Number((await rows(b))[0]!.change_seq);
  await withBusinessWrite(t.db, b, (c) => c.query(`update translations set values = '{}'`));
  expect(await withBusinessWrite(t.db, b, (c) => applyTranslations(c, b, { 'Cola 0,33 l': { en: 'Soda' } }))).toBe(1);
  const [row] = await rows(b);
  expect(row!.values).toEqual({ en: 'Soda' });
  expect(Number(row!.change_seq)).toBeGreaterThan(old);
});
