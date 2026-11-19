import type { FastifyInstance } from 'fastify';
import { afterAll, beforeAll, describe, expect, test } from 'vitest';
import { withBusiness } from '../src/db/tenant.js';
import { testApp, type TestApp } from './support/app.js';
import { createBusiness, menuFixture } from './support/businesses.js';
import {
  changedMenu,
  createStaff,
  fixtureBusiness,
  normalize,
  pairDevice,
  PIN_FIXTURE,
  pull,
  reimport,
  syncFixture,
} from './support/device.js';
import { authed, createProvider, type TestUser } from './support/users.js';

const START = new Date('2026-11-18T10:00:00Z');
const KINDS = ['categories', 'items', 'templates', 'staff'] as const;

type Pulled = { next: number; more: boolean; business?: object } & Record<(typeof KINDS)[number], { id: string }[]>;

/** Alle Zeilen einer Antwort mit Art und Kennung, die Betriebsdaten als "business". */
function rowsOf(p: Pulled): { key: string; row: object }[] {
  const out: { key: string; row: object }[] = [];
  if (p.business) out.push({ key: 'business', row: p.business });
  for (const kind of KINDS) for (const r of p[kind]) out.push({ key: `${kind}/${r.id}`, row: r });
  return out;
}

/** Holt Seite für Seite bis more=false. */
async function pullAll(app: FastifyInstance, token: string, since: number, limit: number): Promise<Pulled[]> {
  const pages: Pulled[] = [];
  for (let cursor = since; ; ) {
    const res = await pull(app, token, `?since=${cursor}&limit=${limit}`);
    expect(res.statusCode).toBe(200);
    const page = res.json() as Pulled;
    pages.push(page);
    if (!page.more) return pages;
    cursor = page.next;
    expect(pages.length).toBeLessThan(100);
  }
}

describe('Beispieldateien', () => {
  let f: TestApp;
  let token: string;
  let businessId: string;
  let provider: TestUser;
  beforeAll(async () => {
    f = await testApp();
    ({ provider, businessId } = await fixtureBusiness(f));
    ({ token } = await pairDevice(f.app, provider.cookie, businessId));
  });
  afterAll(async () => {
    await f.close();
  });

  test('since=0 liefert die ganze Speisekarte wie pull_full.json', async () => {
    const res = await pull(f.app, token, '?since=0');
    expect(res.statusCode).toBe(200);
    expect(normalize(res.json())).toEqual(syncFixture('pull_full'));
    // Ohne limit gilt 500: alles passt auf eine Seite.
    expect(res.json().more).toBe(false);
  });

  test('jeder Artikel nennt photo und der Betrieb logo, ohne Bild null', async () => {
    const body = (await pull(f.app, token, '?since=0')).json();
    expect(body.items.length).toBeGreaterThan(0);
    for (const item of body.items) expect(item).toHaveProperty('photo', null);
    expect(body.business).toHaveProperty('logo', null);
  });

  test('since=next liefert nichts: leere Listen, next unverändert, kein business', async () => {
    const { next } = (await pull(f.app, token, '?since=0')).json();
    const res = await pull(f.app, token, `?since=${next}`);
    expect(res.statusCode).toBe(200);
    expect(res.json()).toEqual({ next, more: false, categories: [], items: [], templates: [], staff: [] });
    // Auch eine Nummer weit hinter allem gibt next unverändert zurück.
    expect((await pull(f.app, token, '?since=999999')).json().next).toBe(999999);
  });

  test('nach Preisänderung und Stilllegung wie pull_delta.json', async () => {
    const { next } = (await pull(f.app, token, '?since=0')).json();
    await reimport(f.app, provider.cookie, businessId, changedMenu());
    const res = await pull(f.app, token, `?since=${next}`);
    expect(res.statusCode).toBe(200);
    expect(normalize(res.json())).toEqual(syncFixture('pull_delta'));
    const items = res.json().items;
    expect(items.find((i: { id: string }) => i.id === 'huhn-bowl').priceCents).toBe(1090);
    expect(items.find((i: { id: string }) => i.id === 'teigtaschen').archived).toBe(true);
  });
});

describe('mit gemeinsamer App', () => {
  let a: TestApp;
  let provider: TestUser;
  beforeAll(async () => {
    a = await testApp();
    provider = await createProvider(a.app, a.db);
  });
  afterAll(async () => {
    await a.close();
  });

  /** Ein Betrieb aus der Beispieldatei mit Chefin und gekoppelter Kassa. */
  async function business(menuFile?: string) {
    const b = menuFile
      ? (
          await a.app.inject({
            method: 'POST',
            url: '/api/admin/businesses',
            headers: authed(provider.cookie),
            payload: { menuFile },
          })
        ).json().business.id
      : (await createBusiness(a.app, provider.cookie)).id;
    const staffId = await createStaff(a.app, provider.cookie, b, { name: 'Chefin', role: 'chef', pin: '1234' });
    const device = await pairDevice(a.app, provider.cookie, b);
    return { id: b as string, staffId, ...device };
  }

  test('limit=2: seitenweise bis more=false ergibt jede Zeile genau einmal', async () => {
    const b = await business();
    const whole = (await pull(a.app, b.token, '?since=0')).json() as Pulled;
    const all = rowsOf(whole);
    expect(all).toHaveLength(8);

    const pages = await pullAll(a.app, b.token, 0, 2);
    expect(pages).toHaveLength(4);
    expect(pages.map((p) => p.more)).toEqual([true, true, true, false]);
    for (const p of pages) expect(rowsOf(p)).toHaveLength(2);
    const walked = pages.flatMap(rowsOf);
    // Keine Zeile doppelt, keine fehlt, jede mit demselben Inhalt wie im großen Holen.
    expect(new Set(walked.map((r) => r.key)).size).toBe(walked.length);
    const byKey = (rows: { key: string; row: object }[]) => Object.fromEntries(rows.map((r) => [r.key, r.row]));
    expect(byKey(walked)).toEqual(byKey(all));
    expect(pages.at(-1)!.next).toBe(whole.next);
    // Die Seiten schließen lückenlos aneinander an: next wächst streng.
    for (let i = 1; i < pages.length; i++) expect(pages[i]!.next).toBeGreaterThan(pages[i - 1]!.next);

    // more ist genau dann true, wenn noch Zeilen offen sind.
    expect((await pull(a.app, b.token, '?since=0&limit=8')).json().more).toBe(false);
    expect((await pull(a.app, b.token, '?since=0&limit=7')).json().more).toBe(true);
    expect(rowsOf((await pull(a.app, b.token, '?since=0&limit=1')).json())).toEqual([{ key: 'business', row: whole.business }]);
  });

  test('limit: Vorgabe 500, höchstens 1000, keine ganze Zahl ab 1 gibt 422 limit_invalid', async () => {
    const b = await business();
    await withBusiness(a.db, b.id, async (c) => {
      // 1200 Kategorien, jede mit eigener Nummer.
      await c.query(
        `insert into categories (business_id, id, name, position, change_seq)
         select $1, 'k' || g, 'K' || g, g, nextval('change_seq') from generate_series(1, 1200) g`,
        [b.id],
      );
    });
    const count = (p: Pulled) => rowsOf(p).length;
    expect(count((await pull(a.app, b.token, '?since=0')).json())).toBe(500);
    expect(count((await pull(a.app, b.token, '?since=0&limit=5000')).json())).toBe(1000);
    expect(count((await pull(a.app, b.token, '?since=0&limit=1000')).json())).toBe(1000);
    for (const bad of ['0', '-1', '1.5', 'abc', '']) {
      const res = await pull(a.app, b.token, `?since=0&limit=${bad}`);
      expect(res.statusCode, bad).toBe(422);
      expect(res.json().error.code).toBe('limit_invalid');
    }
  });

  test('since fehlt oder ist keine ganze Zahl ab 0: 422 since_invalid', async () => {
    const b = await business();
    for (const q of ['', '?since=', '?since=-1', '?since=1.5', '?since=abc', '?since=1e3', '?since=0&since=1', '?since=99999999999999999999']) {
      const res = await pull(a.app, b.token, q);
      expect(res.statusCode, q).toBe(422);
      expect(res.json().error.code).toBe('since_invalid');
      expect(typeof res.json().error.message).toBe('string');
    }
  });

  test('Kassa von A sieht nichts von B, obwohl beide "cola" haben', async () => {
    const A = await business();
    const other = JSON.parse(menuFixture('beispiel-imbiss'));
    other.betrieb = 'Anderer Imbiss';
    other.artikel = other.artikel.map((x: { id: string }) => (x.id === 'cola' ? { ...x, preis_cent: 999 } : x));
    const B = await business(JSON.stringify(other));
    await createStaff(a.app, provider.cookie, B.id, { name: 'Bert', role: 'staff', pin: '5678' });

    const fromA = (await pull(a.app, A.token, '?since=0')).json() as Pulled;
    expect(fromA.business).toMatchObject({ name: 'Beispiel-Imbiss' });
    expect(fromA.items.find((i) => i.id === 'cola')).toMatchObject({ priceCents: 290 });
    expect(fromA.staff.map((s) => s.id)).toEqual([A.staffId]);
    expect(rowsOf(fromA)).toHaveLength(8);
    const text = JSON.stringify(fromA);
    for (const s of ['Anderer Imbiss', 'Bert', B.staffId, B.id]) expect(text).not.toContain(s);
    expect(text).not.toContain('"priceCents":999');

    const fromB = (await pull(a.app, B.token, '?since=0')).json() as Pulled;
    expect(fromB.business).toMatchObject({ name: 'Anderer Imbiss' });
    expect(fromB.items.find((i) => i.id === 'cola')).toMatchObject({ priceCents: 999 });
    expect(JSON.stringify(fromB)).not.toContain(A.staffId);

    // Seitenweise ebenfalls nichts von B, auch wenn die Nummern von B zwischen denen von A liegen.
    other.artikel = other.artikel.filter((x: { id: string }) => x.id !== 'teigtaschen');
    await reimport(a.app, provider.cookie, A.id, changedMenu());
    await reimport(a.app, provider.cookie, B.id, JSON.stringify(other));
    const pages = await pullAll(a.app, A.token, 0, 3);
    const paged = JSON.stringify(pages);
    for (const s of ['Anderer Imbiss', '"priceCents":999', 'Bert', B.staffId]) expect(paged).not.toContain(s);
    expect(pages.flatMap(rowsOf)).toHaveLength(8);
  });

  test('staff trägt pinSalt und pinHash', async () => {
    const b = await business();
    await withBusiness(a.db, b.id, (c) =>
      c.query('update staff set pin_salt = $2, pin_hash = $3 where id = $1', [b.staffId, PIN_FIXTURE.salt, PIN_FIXTURE.hash]),
    );
    // Die Änderung per SQL trägt keine neue Nummer, deshalb ab 0 holen.
    const { staff } = (await pull(a.app, b.token, '?since=0')).json();
    expect(staff).toEqual([
      { id: b.staffId, name: 'Chefin', role: 'chef', pinSalt: PIN_FIXTURE.salt, pinHash: PIN_FIXTURE.hash, archived: false },
    ]);
  });

  test('ohne Schlüssel 401, mit falschem 401, gesperrt 403, Sperre aufgehoben 200', async () => {
    const b = await business();
    const unauthorized = async (headers: Record<string, string>) => {
      const res = await a.app.inject({ method: 'GET', url: '/api/device/sync/pull?since=0', headers });
      expect(res.statusCode, JSON.stringify(headers)).toBe(401);
      expect(res.json().error.code).toBe('unauthorized');
    };
    await unauthorized({});
    // Eine Sitzung der Verwaltung gilt hier nicht.
    await unauthorized({ cookie: provider.cookie });
    await unauthorized({ authorization: 'Bearer falsch' });
    const lastChanged = `${b.token.slice(0, -1)}${b.token.endsWith('A') ? 'B' : 'A'}`;
    await unauthorized({ authorization: `Bearer ${lastChanged}` });
    await unauthorized({ authorization: b.token });
    await unauthorized({ authorization: `Basic ${b.token}` });
    await unauthorized({ authorization: `Bearer ${b.token} x` });

    expect((await pull(a.app, b.token, '?since=0')).statusCode).toBe(200);
    const admin = (what: string) =>
      a.app.inject({
        method: 'POST',
        url: `/api/admin/businesses/${b.id}/registers/${b.registerId}/${what}`,
        headers: authed(provider.cookie),
        payload: {},
      });
    expect((await admin('block')).statusCode).toBe(200);
    const blocked = await pull(a.app, b.token, '?since=0');
    expect(blocked.statusCode).toBe(403);
    expect(blocked.json()).toEqual({
      error: { code: 'register_blocked', message: 'Diese Kassa wurde in der Verwaltung gesperrt.' },
    });
    // Die Sperre kommt vor der Prüfung der Anfrage.
    expect((await pull(a.app, b.token, '?since=x')).statusCode).toBe(403);
    expect((await admin('unblock')).statusCode).toBe(200);
    expect((await pull(a.app, b.token, '?since=0')).statusCode).toBe(200);
  });

  test('neu einspielen während eines seitenweisen Holens: am Ende hat das Tablet den Stand des Servers', async () => {
    const b = await business();
    const tablet = new Map<string, object>();
    const apply = (p: Pulled) => {
      for (const { key, row } of rowsOf(p)) tablet.set(key, row);
    };

    // Seite 1: Betriebsdaten, zwei Kategorien und huhn-bowl.
    const first = (await pull(a.app, b.token, '?since=0&limit=4')).json() as Pulled;
    expect(first.more).toBe(true);
    apply(first);
    // huhn-bowl kam schon auf Seite 1 und ändert sich jetzt.
    expect(tablet.get('items/huhn-bowl')).toMatchObject({ priceCents: 990 });

    const changed = JSON.parse(changedMenu());
    changed.artikel.push({ id: 'ayran', name: 'Ayran', preis_cent: 350, kategorie: 'getraenke', mwst: 20 });
    await reimport(a.app, provider.cookie, b.id, JSON.stringify(changed));

    const rest = await pullAll(a.app, b.token, first.next, 3);
    rest.forEach(apply);
    const huhn = rest.flatMap((p) => p.items).filter((i) => i.id === 'huhn-bowl');
    expect(huhn).toEqual([expect.objectContaining({ priceCents: 1090 })]);
    const huhnPage = rest.find((p) => p.items.some((i) => i.id === 'huhn-bowl'))!;
    expect(huhnPage.next).toBeGreaterThan(first.next);

    const server = new Map(rowsOf((await pull(a.app, b.token, '?since=0')).json()).map((r) => [r.key, r.row]));
    expect(Object.fromEntries(tablet)).toEqual(Object.fromEntries(server));
    expect(tablet.get('items/teigtaschen')).toMatchObject({ archived: true });
    expect(tablet.get('items/ayran')).toMatchObject({ priceCents: 350, archived: false });
  });

  test('last_seen_at und app_version werden gesetzt', async () => {
    const b = await business();
    const reg = async () =>
      (
        await withBusiness(a.db, b.id, (c) =>
          c.query<{ last_seen_at: Date; app_version: string | null }>('select last_seen_at, app_version from registers where id = $1', [b.registerId]),
        )
      ).rows[0]!;
    try {
      expect(await reg()).toEqual({ last_seen_at: START, app_version: '1.2.0' });

      a.now.value = new Date(START.getTime() + 30_000);
      await pull(a.app, b.token, '?since=0', { 'x-kassa-app-version': '1.2.0' });
      expect((await reg()).last_seen_at).toEqual(START);

      a.now.value = new Date(START.getTime() + 61_000);
      await pull(a.app, b.token, '?since=0');
      expect(await reg()).toEqual({ last_seen_at: new Date(START.getTime() + 61_000), app_version: '1.2.0' });

      a.now.value = new Date(START.getTime() + 70_000);
      await pull(a.app, b.token, '?since=0', { 'x-kassa-app-version': '1.2.1' });
      expect(await reg()).toEqual({ last_seen_at: new Date(START.getTime() + 70_000), app_version: '1.2.1' });

      // Auch eine abgelehnte Anfrage zählt als gesehen, solange der Schlüssel gilt.
      a.now.value = new Date(START.getTime() + 200_000);
      expect((await pull(a.app, b.token, '?since=x')).statusCode).toBe(422);
      expect((await reg()).last_seen_at).toEqual(new Date(START.getTime() + 200_000));
    } finally {
      a.now.value = START;
    }
  });
});
