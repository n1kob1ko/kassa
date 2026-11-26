import { afterAll, beforeAll, expect, test } from 'vitest';
import { importMenu, MAX_CENTS, checkCentsRange } from '../src/menu/import_menu.js';
import { parseMenuFile } from '../src/menu/parse_menu.js';
import { withBusiness, withBusinessWrite } from '../src/db/tenant.js';
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
const T1 = new Date('2026-11-19T12:00:00Z');

/** Die Beispieldatei als Objekt, nach `edit` wieder als geprüfte Speisekarte. */
function menu(edit: (file: any) => void = () => {}) {
  const file = JSON.parse(menuFixture('beispiel-imbiss'));
  edit(file);
  return parseMenuFile(JSON.stringify(file));
}

const run = (b: string, m: ReturnType<typeof menu>, now = T0) =>
  withBusinessWrite(t.db, b, (c) => importMenu(c, b, m, now));

async function fresh(): Promise<string> {
  return insertBusiness(t.db);
}

const items = (b: string) =>
  withBusiness(t.db, b, async (c) => (await c.query('select * from items order by position')).rows);
const categories = (b: string) =>
  withBusiness(t.db, b, async (c) => (await c.query('select * from categories order by position')).rows);
const templates = (b: string) =>
  withBusiness(t.db, b, async (c) => (await c.query('select * from modifier_templates order by id')).rows);
const business = (b: string) =>
  withBusiness(t.db, b, async (c) => (await c.query('select * from businesses where id = $1', [b])).rows[0]);
const seqs = async (b: string) =>
  [...(await categories(b)), ...(await items(b)), ...(await templates(b))].map((r) => Number(r.change_seq));

const ZERO = { added: 0, changed: 0, archived: 0 };

test('erstes Einspielen: alles added, Nummern steigen in Datei-Reihenfolge', async () => {
  const b = await fresh();
  const summary = await run(b, menu());
  expect(summary).toEqual({
    categories: { added: 2, changed: 0, archived: 0 },
    items: { added: 3, changed: 0, archived: 0 },
    templates: { added: 1, changed: 0, archived: 0 },
    translations: 0,
  });
  const cats = await categories(b);
  expect(cats.map((r) => r.id)).toEqual(['bowls', 'getraenke']);
  const its = await items(b);
  expect(its.map((r) => r.id)).toEqual(['huhn-bowl', 'teigtaschen', 'cola']);
  const nums = [...cats, ...its, ...(await templates(b))].map((r) => Number(r.change_seq));
  expect(new Set(nums).size).toBe(nums.length);
  expect(nums).toEqual([...nums].sort((x, y) => x - y));
  const first = its[0];
  expect(first).toMatchObject({
    name: 'Huhn Bowl',
    price_cents: 990,
    category_id: 'bowls',
    tax_percent: 10,
    deposit_cents: 0,
    tags: 'spicy',
    template_id: 'bowl',
    favorite: false,
    in_sale: true,
    photo_file_id: null,
    archived: false,
  });
  expect(its[1]!.info).toBe('5 Stück');
  expect(its[2]!.deposit_cents).toBe(25);
  // Die fünf Zeitstempel kommen aus der Uhr der App, nicht aus der echten Zeit.
  for (const col of ['price', 'in_sale', 'favorite', 'deposit', 'tags']) {
    expect(first![`${col}_changed_at`]).toEqual(T0);
  }
  const tpl = (await templates(b))[0]!;
  expect(tpl.groups[0].options[1]).toMatchObject({ name: 'XXL', surchargeCents: 200 });
  expect(await business(b)).toMatchObject({
    name: 'Beispiel-Imbiss',
    address_lines: ['Musterstraße 1', '1010 Wien'],
    vat_id: 'ATU12345678',
    receipt_footer: 'Danke und bis bald!',
  });
});

test('gleiche Datei nochmal: summary überall 0, keine Änderungs-Nummer bewegt sich', async () => {
  const b = await fresh();
  await run(b, menu());
  const before = await seqs(b);
  const bizBefore = (await business(b)).change_seq;
  const summary = await run(b, menu(), T1);
  expect(summary).toEqual({ categories: ZERO, items: ZERO, templates: ZERO, translations: 0 });
  expect(await seqs(b)).toEqual(before);
  expect((await business(b)).change_seq).toBe(bizBefore);
  expect((await items(b))[0]!.price_changed_at).toEqual(T0);
});

test('Preis in der Datei geändert: genau dieser Artikel changed, neue Nummer, price_changed_at = now', async () => {
  const b = await fresh();
  await run(b, menu());
  const before = await items(b);
  const summary = await run(
    b,
    menu((f) => (f.artikel[2].preis_cent = 320)),
    T1,
  );
  expect(summary).toEqual({ categories: ZERO, items: { added: 0, changed: 1, archived: 0 }, templates: ZERO, translations: 0 });
  const after = await items(b);
  const cola = after.find((r) => r.id === 'cola')!;
  expect(cola.price_cents).toBe(320);
  expect(cola.price_changed_at).toEqual(T1);
  expect(cola.deposit_changed_at).toEqual(T0);
  expect(Number(cola.change_seq)).toBeGreaterThan(Math.max(...before.map((r) => Number(r.change_seq))));
  for (const id of ['huhn-bowl', 'teigtaschen']) {
    expect(after.find((r) => r.id === id)!.change_seq).toBe(before.find((r) => r.id === id)!.change_seq);
  }
});

test('Pfand und Kennzeichen setzen ihren eigenen Zeitstempel, Name nicht', async () => {
  const b = await fresh();
  await run(b, menu());
  await run(
    b,
    menu((f) => {
      f.artikel[2].pfand_cent = 50;
      f.artikel[0].kennzeichen = ['SCHARF', 'VEGAN'];
      f.artikel[1].name = 'Teigtaschen groß';
    }),
    T1,
  );
  const its = await items(b);
  const cola = its.find((r) => r.id === 'cola')!;
  const huhn = its.find((r) => r.id === 'huhn-bowl')!;
  const teig = its.find((r) => r.id === 'teigtaschen')!;
  expect([cola.deposit_cents, cola.deposit_changed_at, cola.price_changed_at]).toEqual([50, T1, T0]);
  expect([huhn.tags, huhn.tags_changed_at]).toEqual(['spicy,vegan', T1]);
  expect([teig.name, teig.price_changed_at, teig.tags_changed_at]).toEqual(['Teigtaschen groß', T0, T0]);
});

test('Artikel fehlt in der neuen Datei: archived, taucht er wieder auf: nicht mehr archived', async () => {
  const b = await fresh();
  await run(b, menu());
  const without = menu((f) => f.artikel.splice(2, 1));
  expect(await run(b, without, T1)).toEqual({
    categories: ZERO,
    items: { added: 0, changed: 0, archived: 1 },
    templates: ZERO,
    translations: 0,
  });
  const gone = (await items(b)).find((r) => r.id === 'cola')!;
  expect(gone.archived).toBe(true);
  const seqGone = Number(gone.change_seq);
  // Nochmal ohne ihn: nichts mehr zu tun.
  expect(await run(b, without, T1)).toEqual({ categories: ZERO, items: ZERO, templates: ZERO, translations: 0 });
  expect(Number((await items(b)).find((r) => r.id === 'cola')!.change_seq)).toBe(seqGone);

  expect(await run(b, menu(), T1)).toEqual({
    categories: ZERO,
    items: { added: 0, changed: 1, archived: 0 },
    templates: ZERO,
    translations: 0,
  });
  const back = (await items(b)).find((r) => r.id === 'cola')!;
  expect(back.archived).toBe(false);
  expect(Number(back.change_seq)).toBeGreaterThan(seqGone);
});

test('Kategorie und Vorlage fehlen: archived, sie kommen wieder: nicht mehr archived', async () => {
  const b = await fresh();
  await run(b, menu());
  const small = menu((f) => {
    f.artikel = [f.artikel[2]];
    f.kategorien = [f.kategorien[1]];
    delete f.auswahlgruppen;
  });
  expect(await run(b, small, T1)).toEqual({
    // Die übrig gebliebenen rücken in der Reihenfolge nach vorn, das ist eine echte Änderung.
    categories: { added: 0, changed: 1, archived: 1 },
    items: { added: 0, changed: 1, archived: 2 },
    templates: { added: 0, changed: 0, archived: 1 },
    translations: 0,
  });
  const cats = await categories(b);
  expect(cats.find((r) => r.id === 'bowls')!.archived).toBe(true);
  expect(cats.find((r) => r.id === 'getraenke')).toMatchObject({ archived: false, position: 0 });
  expect((await templates(b))[0]!.archived).toBe(true);
  const again = await run(b, menu(), T1);
  expect(again.templates).toEqual({ added: 0, changed: 1, archived: 0 });
  expect((await templates(b))[0]!.archived).toBe(false);
});

test('Vorlage geändert: nur dieses Stück changed, Schlüsselreihenfolge im jsonb zählt nicht', async () => {
  const b = await fresh();
  await run(b, menu());
  const changed = menu((f) => (f.auswahlgruppen.bowl[0].optionen[1].aufpreis_cent = 250));
  expect((await run(b, changed, T1)).templates).toEqual({ added: 0, changed: 1, archived: 0 });
  expect((await templates(b))[0]!.groups[0].options[1].surchargeCents).toBe(250);
});

test('favorite, in_sale und photo_file_id überleben das Einspielen', async () => {
  const b = await fresh();
  await run(b, menu());
  await withBusinessWrite(t.db, b, (c) =>
    c.query(`update items set favorite = true, in_sale = false, photo_file_id = '33333333-3333-4333-8333-333333333333' where id = 'cola'`),
  );
  await run(
    b,
    menu((f) => (f.artikel[2].preis_cent = 300)),
    T1,
  );
  const cola = (await items(b)).find((r) => r.id === 'cola')!;
  expect([cola.favorite, cola.in_sale, cola.photo_file_id, cola.price_cents]).toEqual([
    true,
    false,
    '33333333-3333-4333-8333-333333333333',
    300,
  ]);
  expect([cola.favorite_changed_at, cola.in_sale_changed_at]).toEqual([T0, T0]);
});

test('Betriebsdaten aus der Datei ersetzen die alten, auch wenn sie leer werden', async () => {
  const b = await fresh();
  await run(b, menu());
  const seq0 = (await business(b)).change_seq;
  await run(
    b,
    menu((f) => {
      f.betrieb = 'Neuer Name';
      delete f.adresse;
      delete f.uid;
      delete f.bon_ende;
    }),
    T1,
  );
  const row = await business(b);
  expect(row).toMatchObject({ name: 'Neuer Name', address_lines: [], vat_id: null, receipt_footer: null });
  expect(Number(row.change_seq)).toBeGreaterThan(Number(seq0));
});

test('Mitarbeiter in der Datei werden nicht angelegt', async () => {
  const b = await fresh();
  await run(b, parseMenuFile(menuFixture('mitarbeiter-in-datei')));
  const staff = await withBusiness(t.db, b, async (c) => (await c.query('select * from staff')).rows);
  expect(staff).toEqual([]);
});

test('Preise über der Grenze werden mit einer Zeile pro Wert gemeldet', () => {
  const m = menu((f) => {
    f.artikel[0].preis_cent = MAX_CENTS + 1;
    f.artikel[2].pfand_cent = 1e20;
    f.auswahlgruppen.bowl[0].optionen[1].aufpreis_cent = 3_000_000_000;
    f.auswahlgruppen.bowl[1].optionen[0].pfand_cent = 2 ** 31;
  });
  const problems = checkCentsRange(m);
  expect(problems).toHaveLength(4);
  expect(problems[0]).toMatch(/^Artikel "huhn-bowl": Der Preis/);
  expect(problems[1]).toMatch(/^Artikel "cola": Das Pfand/);
  expect(problems.join('\n')).toContain('Option "XXL"');
  expect(problems.join('\n')).toContain('Option "Teriyaki"');
  expect(checkCentsRange(menu((f) => (f.artikel[0].preis_cent = MAX_CENTS)))).toEqual([]);
});
