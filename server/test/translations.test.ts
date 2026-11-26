import { randomUUID } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, test } from 'vitest';
import { withBusiness, withSystem } from '../src/db/tenant.js';
import { testApp, type TestApp } from './support/app.js';
import { createBusiness } from './support/businesses.js';
import { fixtureBusiness } from './support/device.js';
import { authed, createChef, type TestUser } from './support/users.js';

let a: TestApp;
let provider: TestUser;
let businessId: string;
let otherId: string;

beforeAll(async () => {
  a = await testApp();
  ({ provider, businessId } = await fixtureBusiness(a));
  otherId = (await createBusiness(a.app, provider.cookie)).id;
});
afterAll(async () => {
  await a.close();
});

const url = (b = businessId) => `/api/admin/businesses/${b}/translations`;
const get = (b = businessId, cookie = provider.cookie) => a.app.inject({ method: 'GET', url: url(b), headers: authed(cookie) });
const put = (payload: unknown, b = businessId, cookie = provider.cookie) =>
  a.app.inject({ method: 'PUT', url: url(b), headers: authed(cookie), payload: payload as object });
const importFile = (file: unknown, b = businessId, cookie = provider.cookie) =>
  a.app.inject({
    method: 'POST',
    url: `${url(b)}/import`,
    headers: authed(cookie),
    payload: { translationsFile: typeof file === 'string' ? file : JSON.stringify(file) },
  });
const row = async (b: string, source: string) =>
  (await withBusiness(a.db, b, (c) => c.query('select * from translations where source = $1', [source]))).rows[0];
const clear = (b = businessId) => withBusiness(a.db, b, (c) => c.query('delete from translations'));
const auditRows = (action: string) =>
  withSystem(a.db, async (c) => (await c.query('select * from audit_log where action = $1 order by id', [action])).rows);

describe('Liste der Übersetzungen', () => {
  test('Abschnitte in der Reihenfolge der Speisekarte, ohne Zahlen bei leerem Wörterbuch', async () => {
    const res = await get();
    expect(res.statusCode).toBe(200);
    expect(res.json()).toEqual({
      sections: [
        { kind: 'categories', title: 'Kategorien', rows: [{ source: 'Bowls', values: {} }, { source: 'Getränke', values: {} }] },
        {
          kind: 'category',
          title: 'Bowls',
          rows: [
            { source: 'Huhn Bowl', values: {} },
            { source: 'Teigtaschen', values: {} },
            { source: '5 Stück', values: {} },
          ],
        },
        { kind: 'category', title: 'Getränke', rows: [{ source: 'Cola 0,33 l', values: {} }] },
        {
          kind: 'extras',
          title: 'Auswahl und Extras',
          rows: ['Größe', 'Normal', 'XXL', 'Extra-Sauce', 'Teriyaki'].map((source) => ({ source, values: {} })),
        },
      ],
      total: 11,
      done: { en: 0, zh: 0, tr: 0, ar: 0 },
    });
  });

  test('doppelter Name nur einmal, stillgelegte fehlen, done zählt jeden nicht leeren Text', async () => {
    await withBusiness(a.db, businessId, async (c) => {
      await c.query(`update items set name = 'Normal' where id = 'cola'`);
      await c.query(`update items set archived = true where id = 'teigtaschen'`);
      await c.query(`update categories set archived = true where id = 'getraenke'`);
    });
    await put({ source: 'Normal', lang: 'en', value: 'Regular' });
    await put({ source: 'Bowls', lang: 'en', value: 'Bowls' });
    const body = (await get()).json();
    const titles = body.sections.map((s: { title: string }) => s.title);
    expect(titles).toEqual(['Kategorien', 'Bowls', 'Auswahl und Extras']);
    const all = body.sections.flatMap((s: { rows: { source: string }[] }) => s.rows.map((r) => r.source));
    expect(all).toEqual(['Bowls', 'Huhn Bowl', 'Größe', 'Normal', 'XXL', 'Extra-Sauce', 'Teriyaki']);
    expect(new Set(all).size).toBe(all.length);
    expect(body.total).toBe(7);
    // "Bowls" gleich dem Namen zählt mit.
    expect(body.done).toEqual({ en: 2, zh: 0, tr: 0, ar: 0 });
    await withBusiness(a.db, businessId, async (c) => {
      await c.query(`update items set name = 'Cola 0,33 l' where id = 'cola'`);
      await c.query(`update items set archived = false where id = 'teigtaschen'`);
      await c.query(`update categories set archived = false where id = 'getraenke'`);
    });
    await clear();
  });
});

describe('Eine Übersetzung setzen', () => {
  test('setzt, ändert, löscht; Änderungs-Nummer nur bei Änderung; done zählt neu', async () => {
    let res = await put({ source: 'Cola 0,33 l', lang: 'en', value: ' Cola 0.33 l ' });
    expect(res.statusCode).toBe(200);
    expect(res.json()).toEqual({ source: 'Cola 0,33 l', values: { en: 'Cola 0.33 l' } });
    const first = await row(businessId, 'Cola 0,33 l');

    res = await put({ source: 'Cola 0,33 l', lang: 'en', value: 'Cola 0.33 l' });
    expect(res.statusCode).toBe(200);
    expect((await row(businessId, 'Cola 0,33 l')).change_seq).toBe(first.change_seq);

    res = await put({ source: 'Cola 0,33 l', lang: 'tr', value: 'Kola' });
    expect(res.json().values).toEqual({ en: 'Cola 0.33 l', tr: 'Kola' });
    const second = await row(businessId, 'Cola 0,33 l');
    expect(Number(second.change_seq)).toBeGreaterThan(Number(first.change_seq));
    expect((await get()).json().done).toEqual({ en: 1, zh: 0, tr: 1, ar: 0 });

    res = await put({ source: 'Cola 0,33 l', lang: 'en', value: 'Cola' });
    expect(res.json().values).toEqual({ en: 'Cola', tr: 'Kola' });

    res = await put({ source: 'Cola 0,33 l', lang: 'en', value: '' });
    expect(res.json().values).toEqual({ tr: 'Kola' });
    expect((await get()).json().done).toEqual({ en: 0, zh: 0, tr: 1, ar: 0 });
    expect((await auditRows('translation.update')).length).toBeGreaterThanOrEqual(4);
  });

  test('letzte Sprache gelöscht: values = {} mit neuer Nummer, Zeile bleibt für den Abgleich', async () => {
    const before = await row(businessId, 'Cola 0,33 l');
    const res = await put({ source: 'Cola 0,33 l', lang: 'tr', value: '   ' });
    expect(res.json()).toEqual({ source: 'Cola 0,33 l', values: {} });
    const after = await row(businessId, 'Cola 0,33 l');
    expect(after.values).toEqual({});
    expect(Number(after.change_seq)).toBeGreaterThan(Number(before.change_seq));
    // Nochmal löschen ändert nichts.
    await put({ source: 'Cola 0,33 l', lang: 'tr', value: '' });
    expect((await row(businessId, 'Cola 0,33 l')).change_seq).toBe(after.change_seq);
  });

  test('Text gleich dem Namen wird gespeichert und zählt; nochmal ändert die Nummer nicht; Leerzeichen löschen', async () => {
    const doneBefore = (await get()).json().done.zh;
    const res = await put({ source: 'Huhn Bowl', lang: 'zh', value: ' Huhn Bowl ' });
    expect(res.json()).toEqual({ source: 'Huhn Bowl', values: { zh: 'Huhn Bowl' } });
    const stored = await row(businessId, 'Huhn Bowl');
    expect(stored.values).toEqual({ zh: 'Huhn Bowl' });
    expect((await get()).json().done.zh).toBe(doneBefore + 1);

    await put({ source: 'Huhn Bowl', lang: 'zh', value: 'Huhn Bowl' });
    expect((await row(businessId, 'Huhn Bowl')).change_seq).toBe(stored.change_seq);

    const other = await put({ source: 'Cola 0,33 l', lang: 'zh', value: 'x' });
    expect(Number((await row(businessId, 'Cola 0,33 l')).change_seq)).toBeGreaterThan(Number(stored.change_seq));
    expect(other.statusCode).toBe(200);

    const cleared = await put({ source: 'Huhn Bowl', lang: 'zh', value: '   ' });
    expect(cleared.json()).toEqual({ source: 'Huhn Bowl', values: {} });
    expect(Number((await row(businessId, 'Huhn Bowl')).change_seq)).toBeGreaterThan(Number(stored.change_seq));
    expect((await get()).json().done.zh).toBe(doneBefore + 1);
    await clear();
  });

  test('Fehler: unbekannter Name 404, falsche Sprache und zu langer Text 422', async () => {
    expect((await put({ source: 'Gibt es nicht', lang: 'en', value: 'x' })).statusCode).toBe(404);
    expect((await put({ source: 'Cola 0,33 l', lang: 'de', value: 'x' })).statusCode).toBe(422);
    expect((await put({ source: 'Cola 0,33 l', lang: 'en' })).statusCode).toBe(422);
    const long = await put({ source: 'Cola 0,33 l', lang: 'en', value: 'x'.repeat(201) });
    expect(long.statusCode).toBe(422);
    expect((await put({ source: 'Cola 0,33 l', lang: 'en', value: 'x'.repeat(200) })).statusCode).toBe(200);
    await clear();
  });

  test('stillgelegter Name darf gesetzt werden', async () => {
    await withBusiness(a.db, businessId, (c) => c.query(`update items set archived = true where id = 'teigtaschen'`));
    expect((await put({ source: 'Teigtaschen', lang: 'en', value: 'Dumplings' })).statusCode).toBe(200);
    await withBusiness(a.db, businessId, (c) => c.query(`update items set archived = false where id = 'teigtaschen'`));
    await clear();
  });
});

describe('Zugriff', () => {
  test('fremder Betrieb und unbekannte Nummer 404, Chef eines anderen Betriebs 404, ohne Anmeldung 401/403', async () => {
    expect((await get(randomUUID())).statusCode).toBe(404);
    expect((await get('kein-betrieb')).statusCode).toBe(404);
    const chef1 = await createChef(a.db, businessId);
    const chef2 = await createChef(a.db, otherId);
    expect((await get(businessId, chef1.cookie)).statusCode).toBe(200);
    expect((await get(businessId, chef2.cookie)).statusCode).toBe(404);
    expect((await put({ source: 'Bowls', lang: 'en', value: 'Bowls!' }, businessId, chef2.cookie)).statusCode).toBe(404);
    expect((await put({ source: 'Bowls', lang: 'en', value: 'Bowls!' }, businessId, chef1.cookie)).statusCode).toBe(200);
    expect((await a.app.inject({ method: 'GET', url: url() })).statusCode).toBe(401);
    await clear();
  });

  test('der andere Betrieb sieht die Übersetzung nicht', async () => {
    await put({ source: 'Bowls', lang: 'en', value: 'Bowls!' });
    const other = (await get(otherId)).json();
    expect(other.done.en).toBe(0);
    await clear();
  });
});

describe('Datei einspielen', () => {
  test('setzt Übersetzungen, meldet die Zahl geänderter Namen, zweites Mal ändert nichts', async () => {
    const file = { uebersetzungen: { Bowls: { en: 'Bowls', zh: '碗' }, 'Huhn Bowl': { en: 'Chicken bowl' }, Normal: { tr: 'Normal ', en: 'Regular' } } };
    const res = await importFile(file);
    expect(res.statusCode).toBe(200);
    // "Bowls" auf Englisch ist gleich dem Namen und zählt wie Chinesisch.
    expect(res.json()).toEqual({ changed: 3 });
    expect((await row(businessId, 'Bowls')).values).toEqual({ en: 'Bowls', zh: '碗' });
    expect((await importFile(file)).json()).toEqual({ changed: 0 });
    expect((await auditRows('translation.import')).length).toBeGreaterThanOrEqual(2);
  });

  test('nur Anbieter', async () => {
    const chef = await createChef(a.db, businessId);
    const res = await importFile({ uebersetzungen: { Bowls: { zh: 'x' } } }, businessId, chef.cookie);
    expect(res.statusCode).toBe(404);
  });

  test('Fehler wörtlich als 422, bei Fehlern wird nichts geändert', async () => {
    await clear();
    const res = await importFile({
      uebersetzungen: { Bowls: { en: 'Bowls!' }, 'Gibt es nicht': { en: 'x' }, Cola: { xx: 'y' } },
    });
    expect(res.statusCode).toBe(422);
    expect(res.json().error.code).toBe('translations_invalid');
    expect(res.json().problems).toEqual([
      'Übersetzung "Gibt es nicht": Diesen Namen gibt es in der Speisekarte nicht.',
      'Übersetzung "Cola": Diesen Namen gibt es in der Speisekarte nicht.',
    ]);
    expect(await row(businessId, 'Bowls')).toBeUndefined();
  });

  test('keine Datei, kein JSON, ohne "uebersetzungen"', async () => {
    expect((await importFile('kein json')).statusCode).toBe(422);
    const noKey = await importFile({ kategorien: [] });
    expect(noKey.statusCode).toBe(422);
    expect(noKey.json().error.code).toBe('translations_invalid');
    const noBody = await a.app.inject({ method: 'POST', url: `${url()}/import`, headers: authed(provider.cookie), payload: {} });
    expect(noBody.statusCode).toBe(400);
  });

  test('stillgelegte Namen sind in der Datei erlaubt', async () => {
    await withBusiness(a.db, businessId, (c) => c.query(`update items set archived = true where id = 'teigtaschen'`));
    const res = await importFile({ uebersetzungen: { Teigtaschen: { en: 'Dumplings' } } });
    expect(res.json()).toEqual({ changed: 1 });
    await withBusiness(a.db, businessId, (c) => c.query(`update items set archived = false where id = 'teigtaschen'`));
    await clear();
  });
});
