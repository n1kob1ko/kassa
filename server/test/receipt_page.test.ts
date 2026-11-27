import { randomUUID } from 'node:crypto';
import { copyFile, mkdtemp, rm, writeFile } from 'node:fs/promises';
import { readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { afterAll, beforeAll, describe, expect, test } from 'vitest';
import { loggerOptions } from '../src/app.js';
import { withSystem } from '../src/db/tenant.js';
import { MissLimiter } from '../src/public/miss_limiter.js';
import { isSafeSvg, qrSvg, rksvQrText } from '../src/public/qr.js';
import { testApp, type TestApp } from './support/app.js';
import { createProvider, send, setTimeZone, siteFor, type Site } from './support/admin_data.js';
import { pushEntries, sampleReceiptV2 } from './support/push.js';
import { freshToken, readStufe1b, voidOfV3 } from './support/stufe_1b.js';
import type { TestUser } from './support/users.js';

// Die öffentliche Seite eines Bons unter /beleg/<Schlüssel>: der einzige Teil ohne Anmeldung.

type Pair = { name: string; jws: string; qrText: string };
const QR_PAIRS = (
  JSON.parse(readFileSync(new URL('../../shared/fixtures/rksv/qr_text.json', import.meta.url), 'utf8')) as { pairs: Pair[] }
).pairs;

const CSP = "default-src 'none'; style-src 'unsafe-inline'; img-src data:; frame-ancestors 'none'; base-uri 'none'; form-action 'none'";
const NOT_FOUND_TEXT = 'Diesen Bon gibt es nicht. Ein neuer Bon ist vielleicht noch nicht da. Bitte in ein paar Minuten noch einmal versuchen.';

let a: TestApp;
let provider: TestUser;
let address = 0;
/** Jeder Test fragt von einer eigenen Adresse, damit die Bremse eines Tests keinen anderen trifft. */
const nextAddress = () => `198.51.100.${++address}`;

beforeAll(async () => {
  a = await testApp();
  provider = await createProvider(a.app, a.db);
});
afterAll(async () => {
  await a.close();
});

const page = (token: string, remoteAddress: string, method: 'GET' | 'HEAD' | 'POST' | 'DELETE' = 'GET') =>
  a.app.inject({ method, url: `/beleg/${token}`, remoteAddress });

/** Die Bons aus shared/fixtures/stats/stufe_1b.json: A bar 18,20, B Gutschein verkauft, C mit Gutschein bezahlt, D Pfand zurück. */
function fixtureReceipts(o: Record<string, unknown> = {}): Record<string, any>[] {
  return readStufe1b().receipts.map((r) => ({ ...r, id: randomUUID(), businessDayId: randomUUID(), publicToken: freshToken(), ...o }));
}

async function businessDetails(s: Site, o: { name?: string; footer?: string | null } = {}): Promise<void> {
  await withSystem(a.db, (c) =>
    c.query('update businesses set name = coalesce($2, name), address_lines = $3, vat_id = $4, receipt_footer = $5 where id = $1', [
      s.businessId,
      o.name ?? null,
      ['Musterweg 1', '1010 Wien'],
      'ATU00000000',
      o.footer === undefined ? 'Danke und bis bald!' : o.footer,
    ]),
  );
}

const chain = { chain: 1, mode: 'live', cashBoxId: 'BSPIMB01', zdaId: 'AT1', certSerial: '1a2b3c', startedAt: '2026-10-14T07:00:00.000Z', endedAt: null };

describe('Seite eines Bons', () => {
  let s: Site;
  let receipts: Record<string, any>[];
  beforeAll(async () => {
    s = await siteFor(a, provider);
    await businessDetails(s);
    await setTimeZone(a, s.businessId, 'Europe/Vienna');
    receipts = fixtureReceipts();
    // A bekommt einen Eintrag der Signatur aus qr_text.json und ist kein Testbon.
    receipts[0] = { ...receipts[0], test: false, rksv: { chain: 1, position: 1, jws: QR_PAIRS[0]!.jws, damaged: false, certSerial: '1a2b3c' } };
    await send(a, s, [['rksv_chain', chain], ...receipts.map((r): [string, object] => ['receipt', r])]);
  });

  test('richtiger Schlüssel: 200, die Seite trägt Betrieb, Zeilen, Summe 18,20, Steuer je Satz, Zahlung und ein <svg>', async () => {
    const [r] = receipts as [Record<string, any>];
    const res = await page(r.publicToken, nextAddress());
    expect(res.statusCode).toBe(200);
    expect(res.headers['content-type']).toBe('text/html; charset=utf-8');
    const html = res.body;
    // In dieser Reihenfolge, wie am Papier.
    const order = [
      'Beispiel-Imbiss', 'Musterweg 1', '1010 Wien', 'UID ATU00000000',
      'Bon Nr. 1', '14.10.2026 12:00', 'Kassen-ID: BSPIMB01',
      '2 x Cola 0,33 l', '5,80', 'je 2,90', '1 x Huhn Bowl', '11,90', 'XXL (+2,00)', 'Nudeln',
      'Pfand', '0,50', 'SUMME EUR', '18,20',
      '20 % MwSt 0,97', 'Netto 4,83', '10 % MwSt 1,08', 'Netto 10,82',
      'Bar', 'Gegeben', '20,00', 'Rückgeld', '1,80',
      '<svg', 'Danke und bis bald!',
    ];
    let at = 0;
    for (const text of order) {
      const i = html.indexOf(text, at);
      expect(i, `"${text}" nach Stelle ${at}`).toBeGreaterThanOrEqual(0);
      at = i + text.length;
    }
    // Der QR-Code trägt den QR-Text der Signatur, mit Rolle und Namen für Vorleseprogramme.
    const svg = (await qrSvg(QR_PAIRS[0]!.qrText)).replace(/^<svg /, '<svg role="img" aria-label="QR-Code der Signatur" ');
    expect(html).toContain(svg);
    expect(html).not.toContain('TESTBON');
    expect(html).not.toContain('STORNO');
    expect(html).not.toContain('RECHNUNG');
    // Die Seite ist ein ganzes deutsches Dokument ohne Schlüssel im Titel.
    expect(html).toMatch(/^<!doctype html>\n<html lang="de">/);
    expect(html).toContain('<meta name="viewport" content="width=device-width, initial-scale=1">');
    expect(html).toContain('<meta name="robots" content="noindex,nofollow">');
    expect(html).toContain('<meta name="referrer" content="no-referrer">');
    expect(html).toMatch(/<title>Bon 1 · Beispiel-Imbiss<\/title>/);
    expect(html.match(/<title>.*<\/title>/)![0]).not.toContain(r.publicToken);
    expect(html).not.toContain(r.publicToken);
    // Nie interne Kennungen, nie die Bedienung, nie ein Weg zur Verwaltung.
    for (const secret of [s.businessId, s.registerId, r.id, r.businessDayId, 'anna', 'Anna', '/api/', '/b/', 'href=']) {
      expect(html, secret).not.toContain(secret);
    }
  });

  test('unbekannt, leer, zu lang, mit Sonderzeichen, Schlüssel plus ein Zeichen: immer 404 mit demselben Text und denselben Kopfzeilen', async () => {
    const token = receipts[0]!.publicToken as string;
    const remoteAddress = nextAddress();
    const bodies = new Set<string>();
    const headers = new Set<string>();
    for (const t of ['A'.repeat(22), '', 'A'.repeat(23), 'A'.repeat(500), '../../etc/passwd', '%00', token + 'x', token.slice(0, 21)]) {
      const r = await a.app.inject({ method: 'GET', url: `/beleg/${encodeURIComponent(t)}`, remoteAddress });
      expect(r.statusCode, t).toBe(404);
      bodies.add(r.body);
      const { date: _date, ...rest } = r.headers;
      headers.add(JSON.stringify(rest));
    }
    expect(bodies.size).toBe(1);
    expect(headers.size).toBe(1);
    expect(visibleText([...bodies][0]!)).toBe(NOT_FOUND_TEXT);
    // Auch ohne Schlüssel, mit Schrägstrich am Ende, mit Unterpfad, mit kaputter Prozent-Kodierung, in anderer
    // Schreibweise und mit doppeltem Schrägstrich: Körper und Kopfzeilen Byte für Byte gleich.
    for (const url of ['/beleg', '/beleg/', `/beleg/${token}/`, `/beleg/${token}/x`, '/beleg/%zz', '//beleg/x', '/BELEG/x', `/Beleg/${token}`]) {
      const r = await a.app.inject({ method: 'GET', url, remoteAddress: nextAddress() });
      expect(r.statusCode, url).toBe(404);
      expect(r.body, url).toBe([...bodies][0]);
      const { date: _date, ...rest } = r.headers;
      expect(JSON.stringify(rest), url).toBe([...headers][0]);
    }
  });

  test('der Schlüssel eines anderen Betriebs und ein fast richtiger Schlüssel geben dieselbe Antwort wie ein unbekannter', async () => {
    const token = receipts[0]!.publicToken as string;
    const near = token.slice(0, 21) + (token[21] === 'A' ? 'B' : 'A');
    const unknown = await page(freshToken(), nextAddress());
    const almost = await page(near, nextAddress());
    const upper = await page(token.toUpperCase() === token ? token.toLowerCase() : token.toUpperCase(), nextAddress());
    for (const r of [almost, upper]) {
      expect(r.statusCode).toBe(404);
      expect(r.body).toBe(unknown.body);
    }
  });

  test('keine Cookies, no-store, noindex, CSP ohne Skript; robots.txt sperrt /beleg/', async () => {
    const token = receipts[0]!.publicToken as string;
    const remoteAddress = nextAddress();
    const ok = await page(token, remoteAddress);
    const missing = await page(freshToken(), remoteAddress);
    const head = await page(token, remoteAddress, 'HEAD');
    for (const res of [ok, missing, head]) {
      expect(res.headers['cache-control']).toBe('no-store');
      expect(res.headers['x-robots-tag']).toBe('noindex, nofollow');
      expect(res.headers['referrer-policy']).toBe('no-referrer');
      expect(res.headers['content-security-policy']).toBe(CSP);
      expect(res.headers['x-content-type-options']).toBe('nosniff');
      expect(res.headers['set-cookie']).toBeUndefined();
    }
    // Nichts wird nachgeladen: kein Skript, keine Schrift, kein Bild oder Stil von außen.
    for (const html of [ok.body, missing.body]) {
      expect(html).not.toMatch(/<script|<link|<img|<iframe|<object|<form|@import|@font-face|url\(|src=|href=/i);
    }

    // robots.txt kommt aus dem gebauten Ordner der Verwaltung (web/public/robots.txt).
    const webDir = await mkdtemp(join(tmpdir(), 'kassa-web-'));
    try {
      await writeFile(join(webDir, 'index.html'), '<!doctype html><title>Kassa</title>');
      await copyFile(fileURLToPath(new URL('../../web/public/robots.txt', import.meta.url)), join(webDir, 'robots.txt'));
      const w = await testApp({ config: { webDir } });
      try {
        const robots = await w.app.inject({ method: 'GET', url: '/robots.txt' });
        expect(robots.statusCode).toBe(200);
        expect(robots.body).toMatch(/^User-agent: \*$/m);
        expect(robots.body).toMatch(/^Disallow: \/beleg\/$/m);
        // Mit der Verwaltung im selben Server bekommt /beleg/… nie deren Seite.
        const p = await w.app.inject({ method: 'GET', url: `/beleg/${freshToken()}` });
        expect(p.statusCode).toBe(404);
        expect(visibleText(p.body)).toBe(NOT_FOUND_TEXT);
        expect(p.headers['content-security-policy']).toBe(CSP);
      } finally {
        await w.close();
      }
    } finally {
      await rm(webDir, { recursive: true, force: true });
    }
  });

  test('HEAD sagt nicht mehr als GET, andere Methoden bekommen die Seite "gibt es nicht"', async () => {
    const token = receipts[0]!.publicToken as string;
    const remoteAddress = nextAddress();
    const get = await page(token, remoteAddress);
    const head = await page(token, remoteAddress, 'HEAD');
    expect(head.statusCode).toBe(200);
    expect(head.body).toBe('');
    expect(head.headers['content-type']).toBe(get.headers['content-type']);
    const missingGet = await page(freshToken(), remoteAddress);
    const missingHead = await page(freshToken(), remoteAddress, 'HEAD');
    expect(missingHead.statusCode).toBe(404);
    for (const method of ['POST', 'DELETE'] as const) {
      const r = await page(token, remoteAddress, method);
      expect(r.statusCode, method).toBe(404);
      expect(r.body, method).toBe(missingGet.body);
      expect(r.headers['content-security-policy']).toBe(CSP);
    }
    const put = await a.app.inject({
      method: 'PUT',
      url: `/beleg/${token}`,
      remoteAddress,
      headers: { 'content-type': 'application/xml' },
      payload: '<x/>',
    });
    expect(put.statusCode).toBe(404);
    expect(put.body).toBe(missingGet.body);
  });

  test('Bon unter 0: Summe -0,75, "Pfand zurück", Bar -0,75', async () => {
    const res = await page(receipts[3]!.publicToken, nextAddress());
    expect(res.statusCode).toBe(200);
    const text = visibleText(res.body);
    expect(text).toContain('3 x Pfand zurück -0,75');
    expect(text).toContain('je -0,25');
    expect(text).toContain('Pfand zurück -0,75');
    expect(text).toContain('SUMME EUR -0,75');
    expect(text).toContain('Bar -0,75');
    // Verlangt wurde kein Pfand: die Reihe "Pfand" fehlt; ohne Steuer keine Steuerzeile.
    expect(text).not.toMatch(/(^|\s)Pfand -?\d/);
    expect(text).not.toContain('MwSt');
    expect(text).not.toContain('Gegeben');
  });

  test('Gutschein: der Code steht nur mit den letzten vier Ziffern da, bei Zahlung und bei Verkauf', async () => {
    const sold = await page(receipts[1]!.publicToken, nextAddress());
    const paid = await page(receipts[2]!.publicToken, nextAddress());
    expect(sold.statusCode).toBe(200);
    expect(paid.statusCode).toBe(200);
    const soldText = visibleText(sold.body);
    const paidText = visibleText(paid.body);
    expect(soldText).toContain('1 x Gutschein 25,00');
    expect(soldText).toContain('Code •••• 2768');
    expect(soldText).toContain('Gutschein (kein Umsatz) 25,00');
    expect(paidText).toContain('Gutschein •••• 2768 9,65');
    expect(paidText).toContain('Restguthaben 15,35');
    for (const html of [sold.body, paid.body]) {
      expect(html).not.toContain('71262768');
      expect(html).not.toContain('7126');
      expect(html).not.toContain('cccccccc');
    }
  });
});

describe('Seite eines Bons: Storno, Rechnung, Testbon, fremde Betriebe', () => {
  test('Storno: der stornierte Bon sagt "Storniert am", der Storno-Bon sagt STORNO', async () => {
    const s = await siteFor(a, provider);
    await setTimeZone(a, s.businessId, 'Europe/Vienna');
    const [sale] = fixtureReceipts({ createdAt: '2026-11-27T11:03:05.000Z' }) as [Record<string, any>];
    const storno = voidOfV3(sale, { id: randomUUID(), number: 2, createdAt: '2026-11-27T11:30:00.000Z' });
    await send(a, s, [['receipt', sale], ['receipt', storno]]);
    const saleText = visibleText((await page(sale.publicToken, nextAddress())).body);
    const stornoText = visibleText((await page(storno.publicToken, nextAddress())).body);
    expect(saleText).toContain('Storniert am 27.11.2026 12:30');
    expect(saleText).toContain('Bon Nr. 1 27.11.2026 12:03');
    expect(saleText).not.toContain('STORNO');
    expect(stornoText).toContain('STORNO');
    expect(stornoText).toContain('zu Bon Nr. 1');
    expect(stornoText).toContain('SUMME EUR -18,20');
    expect(stornoText).toContain('Bar -18,20');
    expect(stornoText).not.toContain('Storniert am');
  });

  test('Rechnung: Empfänger der letzten Fassung und Rechnungsnummer; Testbon trägt den Vermerk', async () => {
    const s = await siteFor(a, provider);
    await businessDetails(s);
    await send(a, s, [['rksv_chain', chain]]);
    const [r] = fixtureReceipts({ number: 42 }) as [Record<string, any>];
    await send(a, s, [['receipt', r]]);
    const recipient = (version: number, o: Record<string, unknown>) => ({
      receiptId: r.id, version, customerId: null, name: 'Muster GmbH', addressLine1: 'Musterweg 1', addressLine2: '1010 Wien',
      vatId: null, createdAt: '2026-10-14T10:05:00.000Z', staffId: 'chefin', staffName: 'Chefin', ...o,
    });
    const res = await pushEntries(a.app, s.token, s.deviceId, [
      { seq: 1, kind: 'recipient', ...recipient(0, { name: 'Alte Firma GmbH' }) },
      { seq: 2, kind: 'recipient', ...recipient(1, { addressLine1: 'Musterweg 2', vatId: 'ATU12345678' }) },
    ]);
    expect(res.results.map((x) => x.status)).toEqual(['accepted', 'accepted']);
    const text = visibleText((await page(r.publicToken, nextAddress())).body);
    const order = ['UID ATU00000000', 'RECHNUNG', 'Rechnung Nr. 42', 'An:', 'Muster GmbH', 'Musterweg 2', '1010 Wien', 'UID ATU12345678', 'Bon Nr. 42'];
    let at = 0;
    for (const t of order) {
      const i = text.indexOf(t, at);
      expect(i, t).toBeGreaterThanOrEqual(0);
      at = i + t.length;
    }
    expect(text).not.toContain('Alte Firma');
    expect(text).not.toContain('Chefin');
    // Der Bon ist ein Testbon (test: true, ohne Signatur): der Vermerk steht am Ende.
    expect(text.trimEnd().endsWith('TESTBON, keine gültige Rechnung')).toBe(true);
  });

  test('zwei Betriebe: der Schlüssel von Betrieb A zeigt nie eine Zeile von Betrieb B', async () => {
    const sa = await siteFor(a, provider, 'Betrieb Eins');
    const sb = await siteFor(a, provider, 'Betrieb Zwei');
    const [ra] = fixtureReceipts() as [Record<string, any>];
    const [rb0] = fixtureReceipts() as [Record<string, any>];
    // Dieselbe Kennung und Nummer in beiden Betrieben: nur der Betrieb des Schlüssels zählt.
    const rb: Record<string, any> = { ...rb0, id: ra.id, lines: rb0.lines.map((l: Record<string, any>) => ({ ...l, name: `${l.name} aus Zwei` })) };
    await send(a, sa, [['receipt', ra]]);
    await send(a, sb, [['receipt', rb]]);
    const pa = visibleText((await page(ra.publicToken, nextAddress())).body);
    const pb = visibleText((await page(rb.publicToken, nextAddress())).body);
    expect(pa).toContain('Betrieb Eins');
    expect(pa).toContain('Cola 0,33 l');
    expect(pa).not.toContain('aus Zwei');
    expect(pa).not.toContain('Betrieb Zwei');
    expect(pb).toContain('Betrieb Zwei');
    expect(pb).toContain('Cola 0,33 l aus Zwei');
    expect(pb).not.toContain('Betrieb Eins');
  });

  test('Artikelname "<script>alert(1)</script>" steht als Text auf der Seite, nicht als Element', async () => {
    const s = await siteFor(a, provider);
    await businessDetails(s, { name: 'Imbiss "<b>Fett</b>" & Co', footer: '<img src=x onerror=alert(1)>' });
    const [r0] = fixtureReceipts() as [Record<string, any>];
    const r: Record<string, any> = {
      ...r0,
      lines: r0.lines.map((l: Record<string, any>, i: number) =>
        i === 0 ? { ...l, name: '<script>alert(1)</script>', info: "'\"><svg onload=alert(2)>" } : l,
      ),
    };
    await send(a, s, [['receipt', r]]);
    const html = (await page(r.publicToken, nextAddress())).body;
    expect(html).toContain('&lt;script&gt;alert(1)&lt;/script&gt;');
    expect(html).toContain('Imbiss &quot;&lt;b&gt;Fett&lt;/b&gt;&quot; &amp; Co');
    expect(html).toContain('&lt;img src=x onerror=alert(1)&gt;');
    expect(html).toContain('&#39;&quot;&gt;&lt;svg onload=alert(2)&gt;');
    expect(html).not.toMatch(/<script|<img|<b>|<svg onload/i);
  });
});

describe('Bremse', () => {
  test('Bremse: 10 Fehlversuche, dann 429 auch für den richtigen Schlüssel; eine andere Adresse ist nicht betroffen; nach dem Fenster geht es wieder', async () => {
    const s = await siteFor(a, provider);
    const [r] = fixtureReceipts() as [Record<string, any>];
    await send(a, s, [['receipt', r]]);
    const start = a.now.value;
    try {
      const attacker = nextAddress();
      const other = nextAddress();
      // Richtige Schlüssel zählen nicht.
      for (let i = 0; i < 12; i++) expect((await page(r.publicToken, attacker)).statusCode).toBe(200);
      for (let i = 0; i < 10; i++) expect((await page(freshToken(), attacker)).statusCode, `Versuch ${i + 1}`).toBe(404);
      const blocked = await page(r.publicToken, attacker);
      expect(blocked.statusCode).toBe(429);
      expect(blocked.headers['content-type']).toBe('text/html; charset=utf-8');
      expect(blocked.headers['content-security-policy']).toBe(CSP);
      expect(blocked.headers['cache-control']).toBe('no-store');
      expect(blocked.body).toContain('Zu viele Versuche');
      expect(blocked.body).not.toContain('Cola');
      // Jede Anfrage der Adresse, auch eine falsche oder kaputte, bekommt dieselbe Seite.
      expect((await page(freshToken(), attacker)).body).toBe(blocked.body);
      expect((await page('kaputt', attacker)).body).toBe(blocked.body);
      expect((await page(r.publicToken, other)).statusCode).toBe(200);
      // Kurz vor dem Ende des Fensters noch gesperrt, danach wieder frei.
      a.now.value = new Date(start.getTime() + 10 * 60 * 1000 - 1);
      expect((await page(r.publicToken, attacker)).statusCode).toBe(429);
      a.now.value = new Date(start.getTime() + 10 * 60 * 1000 + 1);
      expect((await page(r.publicToken, attacker)).statusCode).toBe(200);
    } finally {
      a.now.value = start;
    }
  });

  test('IPv6: die Adressen eines Netzes /64 zählen zusammen', async () => {
    const s = await siteFor(a, provider);
    const [r] = fixtureReceipts() as [Record<string, any>];
    await send(a, s, [['receipt', r]]);
    for (let i = 1; i <= 10; i++) expect((await page(freshToken(), `2001:db8:5:6::${i}`)).statusCode).toBe(404);
    expect((await page(r.publicToken, '2001:db8:5:6::ff')).statusCode).toBe(429);
    expect((await page(r.publicToken, '2001:db8:5:7::1')).statusCode).toBe(200);
  });
});

describe('Der Schlüssel steht nie im Protokoll', () => {
  test('richtiger, falscher und gesperrter Schlüssel: im Protokoll steht /beleg/:token, nie der Schlüssel', async () => {
    const lines: string[] = [];
    const t = await testApp({}, { logger: loggerOptions({ write: (line: string) => void lines.push(line) }) });
    try {
      const p = await createProvider(t.app, t.db);
      const s = await siteFor(t, p);
      const [r] = fixtureReceipts() as [Record<string, any>];
      await send(t, s, [['receipt', r]]);
      const wrong = freshToken();
      const ip = '203.0.113.77';
      const get = (token: string, method: 'GET' | 'HEAD' | 'POST' = 'GET') =>
        t.app.inject({ method, url: `/beleg/${token}?x=${token}`, remoteAddress: ip });
      expect((await get(r.publicToken)).statusCode).toBe(200);
      expect((await get(r.publicToken, 'HEAD')).statusCode).toBe(200);
      expect((await get(r.publicToken, 'POST')).statusCode).toBe(404);
      // Derselbe falsche Schlüssel zählt einmal; neun weitere verschiedene, dann ist die Adresse gesperrt.
      for (let i = 0; i < 3; i++) expect((await get(wrong)).statusCode).toBe(404);
      for (let i = 0; i < 9; i++) expect((await get(freshToken())).statusCode).toBe(404);
      expect((await get(wrong)).statusCode).toBe(429);
      expect((await t.app.inject({ method: 'GET', url: `/beleg/${wrong}%zz`, remoteAddress: '203.0.113.78' })).statusCode).toBe(404);
      expect((await get(r.publicToken)).statusCode).toBe(429);
      // Groß geschrieben ist es nicht die Seite, aber der Schlüssel bleibt trotzdem draußen.
      await t.app.inject({ method: 'GET', url: `/BELEG/${r.publicToken}`, remoteAddress: ip });
      const text = lines.join('');
      expect(lines.length).toBeGreaterThan(10);
      expect(text).toContain('/beleg/:token');
      expect(text).not.toContain(r.publicToken);
      expect(text).not.toContain(wrong);
    } finally {
      await t.close();
    }
  });
});

describe('Nachbesserung 1: kaputte Adresse, Sperre je Adresse, gleiche falsche Schlüssel', () => {
  let s: Site;
  let r: Record<string, any>;
  beforeAll(async () => {
    s = await siteFor(a, provider);
    [r] = fixtureReceipts() as [Record<string, any>];
    await send(a, s, [['receipt', r]]);
  });

  test('derselbe falsche Schlüssel 30-mal ist nie 429; zehn verschiedene, dann ist der elfte 429, auch ein richtiger', async () => {
    const ip = nextAddress();
    const same = freshToken();
    for (let i = 0; i < 30; i++) expect((await page(same, ip)).statusCode, `Versuch ${i + 1}`).toBe(404);
    // Der eine Schlüssel zählt einmal: noch neun weitere verschiedene gehen.
    for (let i = 0; i < 9; i++) expect((await page(freshToken(), ip)).statusCode).toBe(404);
    expect((await page(freshToken(), ip)).statusCode).toBe(429);
    expect((await page(same, ip)).statusCode).toBe(429);
    // Wie im Brief: eine gesperrte Adresse bekommt auch für den richtigen Schlüssel 429.
    expect((await page(r.publicToken, ip)).statusCode).toBe(429);
    // Eine Adresse mit nur einem oft wiederholten Schlüssel bleibt frei.
    const reloader = nextAddress();
    for (let i = 0; i < 12; i++) await page(same, reloader);
    expect((await page(r.publicToken, reloader)).statusCode).toBe(200);
  });

  test('/beleg/%zz: dieselbe Seite mit allen Kopfzeilen, zählt als Fehlversuch; /api/%zz bleibt die Antwort von Fastify', async () => {
    const ip = nextAddress();
    const missing = await page(freshToken(), nextAddress());
    for (let i = 0; i < 10; i++) {
      const res = await a.app.inject({ method: 'GET', url: `/beleg/%zz${i}`, remoteAddress: ip });
      expect(res.statusCode).toBe(404);
      expect(res.body).toBe(missing.body);
      expect(res.headers['content-security-policy']).toBe(CSP);
      expect(res.headers['cache-control']).toBe('no-store');
      expect(res.headers['referrer-policy']).toBe('no-referrer');
      expect(res.body).not.toContain('%zz');
    }
    const blocked = await page(r.publicToken, ip);
    expect(blocked.statusCode).toBe(429);
    expect((await a.app.inject({ method: 'GET', url: '/BELEG/%zz', remoteAddress: ip })).statusCode).toBe(429);
    const api = await a.app.inject({ method: 'GET', url: '/api/%zz' });
    expect(api.statusCode).toBe(400);
    expect(api.headers['content-type']).toBe('application/json');
    expect(api.json()).toEqual({ error: 'Bad Request', code: 'FST_ERR_BAD_URL', message: "'/api/%zz' is not a valid url component", statusCode: 400 });
  });

  test('andere Methoden von einer gesperrten Adresse bekommen 429, nie die Verwaltung', async () => {
    const ip = nextAddress();
    for (let i = 0; i < 10; i++) await page(freshToken(), ip);
    for (const method of ['POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS', 'HEAD'] as const) {
      const res = await a.app.inject({ method, url: `/beleg/${r.publicToken}`, remoteAddress: ip, payload: method === 'HEAD' ? undefined : '{}' });
      expect(res.statusCode, method).toBe(429);
      expect(res.headers['content-security-policy'], method).toBe(CSP);
    }
  });

  test('/BELEG/<x>, //beleg/<x> und /Beleg fallen nie auf die Seite der Verwaltung', async () => {
    const webDir = await mkdtemp(join(tmpdir(), 'kassa-web-'));
    try {
      await writeFile(join(webDir, 'index.html'), '<!doctype html><title>Verwaltung</title>');
      const w = await testApp({ config: { webDir } });
      try {
        const reference = await w.app.inject({ method: 'GET', url: `/beleg/${freshToken()}`, remoteAddress: '192.0.2.10' });
        expect(reference.statusCode).toBe(404);
        let n = 10;
        for (const url of [`/BELEG/${r.publicToken}`, '//beleg/x', '///beleg/', '/Beleg', '/bElEg/x/y', '/beleg/%zz', '/%42ELEG/x', '/beleg%2Fx', '/BELEG#x', '/%62eleg']) {
          for (const method of ['GET', 'POST'] as const) {
            const res = await w.app.inject({ method, url, remoteAddress: `192.0.2.${++n}` });
            expect(res.statusCode, `${method} ${url}`).toBe(404);
            expect(res.body, `${method} ${url}`).toBe(reference.body);
            expect(res.body).not.toContain('Verwaltung');
            expect(res.headers['content-security-policy']).toBe(CSP);
            expect(res.headers['x-robots-tag']).toBe('noindex, nofollow');
          }
        }
        // Die Verwaltung selbst bleibt, wie sie war, auch für Adressen, die nur ähnlich aussehen.
        for (const url of ['/betriebe', '/belege', '/beleg-x', '/b/123/belege', '/b/123/bons/x', '/%62elege']) {
          const admin = await w.app.inject({ method: 'GET', url });
          expect(admin.statusCode, url).toBe(200);
          expect(admin.body, url).toContain('Verwaltung');
          expect(admin.headers['referrer-policy'], url).toBe('same-origin');
        }
      } finally {
        await w.close();
      }
    } finally {
      await rm(webDir, { recursive: true, force: true });
    }
  });

  test('volle Tabelle: eine neue Adresse bekommt ihre Seite, die älteste Adresse fällt heraus', async () => {
    const t = await testApp({ receiptPageAddresses: 3 });
    try {
      const p = await createProvider(t.app, t.db);
      const site = await siteFor(t, p);
      const [rr] = fixtureReceipts() as [Record<string, any>];
      await send(t, site, [['receipt', rr]]);
      const get = (token: string, ip: string) => t.app.inject({ method: 'GET', url: `/beleg/${token}`, remoteAddress: ip });
      // Die älteste Adresse ist gesperrt.
      for (let i = 0; i < 10; i++) await get(freshToken(), '192.0.2.1');
      expect((await get(rr.publicToken, '192.0.2.1')).statusCode).toBe(429);
      // Drei weitere Adressen mit je einem Fehlversuch: die Tabelle ist voll, die älteste fällt heraus.
      for (const ip of ['192.0.2.2', '192.0.2.3', '192.0.2.4']) expect((await get(freshToken(), ip)).statusCode).toBe(404);
      expect((await get(rr.publicToken, '192.0.2.1')).statusCode).toBe(200);
      // Eine ganz neue Adresse bei voller Tabelle bekommt ihre Seite, nicht 429.
      expect((await get(rr.publicToken, '192.0.2.99')).statusCode).toBe(200);
      expect((await get(freshToken(), '192.0.2.98')).statusCode).toBe(404);
    } finally {
      await t.close();
    }
  });

  test('Kartenzahlung mit Rabatten: die Seite zeigt Art und letzte vier Ziffern, nie eine ganze Kartennummer', async () => {
    const v2 = sampleReceiptV2({ createdAt: '2026-11-19T09:00:00.000Z', number: 5 });
    await send(a, s, [['receipt', v2]]);
    const token = freshToken();
    // Ein Bon in v: 2 hat keinen Schlüssel; für diesen Test bekommt er einen.
    await withSystem(a.db, (c) => c.query('insert into receipt_links (token, business_id, receipt_id) values ($1, $2, $3)', [token, s.businessId, v2.id]));
    const res = await page(token, nextAddress());
    expect(res.statusCode).toBe(200);
    const text = visibleText(res.body);
    expect(text).toContain('Karte');
    expect(text).toContain('VISA **** 4242');
    expect(text).toContain('davon Trinkgeld 0,64');
    expect(text).toContain('Zwischensumme');
    expect(text).toContain('Rabatt 10 % Aktion -1,65');
    expect(text).toContain('Rabatt 10 % Stammgast -1,19');
    expect(text).not.toContain('TX-BEISPIEL-1');
    expect(text).not.toMatch(/\d{5,}/);
    expect(text).not.toContain('Anna');
  });
});

test('MissLimiter: Speicher begrenzt, je Adresse höchstens max Prüfwerte, derselbe zählt einmal', () => {
  const m = new MissLimiter(10, 600_000, 100);
  const t0 = new Date('2026-11-27T10:00:00Z');
  for (let i = 0; i < 1000; i++) m.miss(`a${i}`, 'h', t0);
  expect(m.size).toBe(100);
  for (let i = 0; i < 50; i++) m.miss('x', `h${i}`, t0);
  expect(m.blockedMs('x', t0)).toBe(600_000);
  for (let i = 0; i < 50; i++) m.miss('y', 'same', t0);
  expect(m.blockedMs('y', t0)).toBe(0);
  expect(m.size).toBe(100);
  // Nach dem Fenster ist alles weg.
  expect(m.blockedMs('x', new Date(t0.getTime() + 600_001))).toBe(0);
  expect(m.size).toBe(0);
});

describe('Nachbesserung 2: gleichzeitige Anfragen zählen mit', () => {
  let t: TestApp;
  let rr: Record<string, any>;
  const lookups: string[] = [];
  let failNext = false;
  beforeAll(async () => {
    t = await testApp({
      wrapReceiptLoader: (load) => async (db, token, log) => {
        lookups.push(token);
        if (failNext) throw new Error('Datenbank weg');
        return load(db, token, log);
      },
    });
    const p = await createProvider(t.app, t.db);
    const site = await siteFor(t, p);
    [rr] = fixtureReceipts() as [Record<string, any>];
    await send(t, site, [['receipt', rr]]);
  });
  afterAll(async () => {
    await t.close();
  });
  const get = (token: string, ip: string) => t.app.inject({ method: 'GET', url: `/beleg/${token}`, remoteAddress: ip });
  const statuses = (list: { statusCode: number }[]) =>
    list.reduce<Record<number, number>>((m, r) => ({ ...m, [r.statusCode]: (m[r.statusCode] ?? 0) + 1 }), {});

  test('30 gleichzeitige Anfragen mit 30 verschiedenen falschen Schlüsseln: höchstens 10 Abfragen, der Rest 429', async () => {
    lookups.length = 0;
    const keys = Array.from({ length: 30 }, () => freshToken());
    const res = await Promise.all(keys.map((k) => get(k, '192.0.2.50')));
    expect(statuses(res)).toEqual({ 404: 10, 429: 20 });
    expect(lookups).toHaveLength(10);
    // Jede Abfrage gehört zu einer 404, keine 429 hat nachgesehen.
    expect(new Set(lookups)).toEqual(new Set(keys.filter((_, i) => res[i]!.statusCode === 404)));
    expect((await get(rr.publicToken, '192.0.2.50')).statusCode).toBe(429);
  });

  test('30 gleichzeitige Anfragen mit demselben richtigen Schlüssel: alle 200, nichts zählt', async () => {
    lookups.length = 0;
    const res = await Promise.all(Array.from({ length: 30 }, () => get(rr.publicToken, '192.0.2.51')));
    expect(statuses(res)).toEqual({ 200: 30 });
    expect(lookups).toHaveLength(30);
    // Keine Reservierung ist hängen geblieben: zehn verschiedene falsche gehen noch, erst der elfte ist 429.
    for (let i = 0; i < 10; i++) expect((await get(freshToken(), '192.0.2.51')).statusCode).toBe(404);
    expect((await get(freshToken(), '192.0.2.51')).statusCode).toBe(429);
  });

  test('derselbe falsche Schlüssel gleichzeitig: ein Platz, jede Anfrage darf nachsehen', async () => {
    lookups.length = 0;
    const same = freshToken();
    const res = await Promise.all(Array.from({ length: 30 }, () => get(same, '192.0.2.52')));
    expect(statuses(res)).toEqual({ 404: 30 });
    for (let i = 0; i < 9; i++) expect((await get(freshToken(), '192.0.2.52')).statusCode).toBe(404);
    expect((await get(freshToken(), '192.0.2.52')).statusCode).toBe(429);
  });

  test('Fehler beim Lesen geben den Platz zurück; nach dem Fenster ist die Adresse wieder frei', async () => {
    const start = t.now.value;
    try {
      failNext = true;
      const failed = await Promise.all(Array.from({ length: 30 }, () => get(freshToken(), '192.0.2.53')));
      failNext = false;
      // Höchstens zehn laufen gleichzeitig; ein Fehler des Servers zählt nicht als Fehlversuch.
      expect(statuses(failed)).toEqual({ 500: 10, 429: 20 });
      expect((await get(rr.publicToken, '192.0.2.53')).statusCode).toBe(200);
      // Nach dem Ansturm aus dem ersten Test und dem Ende des Fensters: alle Adressen frei, nichts hängt.
      t.now.value = new Date(start.getTime() + 10 * 60 * 1000 + 1);
      for (const ip of ['192.0.2.50', '192.0.2.51', '192.0.2.52', '192.0.2.53']) {
        expect((await get(rr.publicToken, ip)).statusCode, ip).toBe(200);
        const burst = await Promise.all(Array.from({ length: 10 }, () => get(freshToken(), ip)));
        expect(statuses(burst), ip).toEqual({ 404: 10 });
        expect((await get(freshToken(), ip)).statusCode, ip).toBe(429);
      }
    } finally {
      failNext = false;
      t.now.value = start;
    }
  });
});

test('MissLimiter: reserve zählt laufende Prüfwerte mit, release und record geben sie frei', () => {
  const m = new MissLimiter(3, 600_000, 2);
  const t0 = new Date('2026-11-27T10:00:00Z');
  expect([m.reserve('a', 'h1', t0), m.reserve('a', 'h2', t0), m.reserve('a', 'h3', t0)]).toEqual([true, true, true]);
  expect(m.reserve('a', 'h4', t0)).toBe(false);
  // Derselbe Prüfwert braucht keinen zweiten Platz.
  expect(m.reserve('a', 'h1', t0)).toBe(true);
  m.release('a', 'h1');
  m.release('a', 'h1');
  expect(m.reserve('a', 'h4', t0)).toBe(true);
  m.record('a', 'h2', t0);
  m.release('a', 'h3');
  m.release('a', 'h4');
  expect(m.pendingSize).toBe(0);
  expect(m.blockedMs('a', t0)).toBe(0);
  m.reserve('a', 'h5', t0);
  m.record('a', 'h5', t0);
  m.reserve('a', 'h6', t0);
  m.record('a', 'h6', t0);
  expect(m.blockedMs('a', t0)).toBe(600_000);
  // Grenze 2: laufende Anfragen zählen mit, die älteste gespeicherte Adresse fällt heraus.
  m.reserve('b', 'x', t0);
  m.reserve('c', 'x', t0);
  expect(m.size).toBe(0);
  expect(m.pendingSize).toBe(2);
  m.record('b', 'x', t0);
  m.record('c', 'x', t0);
  expect(m.size + m.pendingSize).toBeLessThanOrEqual(2);
});

describe('QR-Code', () => {
  test('rksvQrText: die Paare aus qr_text.json', () => {
    expect(QR_PAIRS).toHaveLength(3);
    for (const p of QR_PAIRS) expect(rksvQrText(p.jws), p.name).toBe(p.qrText);
    expect(() => rksvQrText('kein.jws')).toThrow();
    expect(() => rksvQrText('a.b.c.d')).toThrow();
  });

  test('qrSvg: schwarz auf weiß, Ruhezone 4 Module, ohne Skript und ohne Verweis', async () => {
    const svg = await qrSvg(QR_PAIRS[0]!.qrText);
    expect(svg.startsWith('<svg ')).toBe(true);
    const size = Number(svg.match(/viewBox="0 0 (\d+) \1"/)![1]);
    // Version 6 bis 10 bei Stufe M für rund 180 Zeichen, plus zweimal 4 Module Ruhezone.
    expect((size - 8 - 17) % 4).toBe(0);
    expect(svg).toContain(`<path fill="#ffffff" d="M0 0h${size}v${size}H0z"/>`);
    expect(svg).toMatch(/<path stroke="#000000" d="M4 4\.5h7/);
    expect(isSafeSvg(svg)).toBe(true);
    // Derselbe Text gibt dasselbe Bild.
    expect(await qrSvg(QR_PAIRS[0]!.qrText)).toBe(svg);
  });

  test('isSafeSvg lehnt Skript, on…=, Verweise und Fremdes ab', () => {
    const ok = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 29 29"><path fill="#ffffff" d="M0 0h29v29H0z"/></svg>';
    expect(isSafeSvg(ok)).toBe(true);
    for (const bad of [
      '<svg><script>alert(1)</script></svg>',
      '<svg><SCRIPT>alert(1)</SCRIPT></svg>',
      '<svg onload="alert(1)"></svg>',
      '<svg><path ONCLICK = "x"/></svg>',
      '<svg><image href="https://example.com/x.png"/></svg>',
      '<svg><use xlink:href="#a"/></svg>',
      '<svg><path style="fill:url(https://example.com/a)"/></svg>',
      '<svg><foreignObject><div>x</div></foreignObject></svg>',
      '<svg><style>@import "x"</style></svg>',
      '<svg><a>x</a></svg>',
      '<div>kein svg</div>',
      '<svg></svg><script>x</script>',
    ]) {
      expect(isSafeSvg(bad), bad).toBe(false);
    }
  });
});

/** Der Text der Seite ohne Auszeichnung: Elemente werden zu Leerzeichen, Leerraum zu einem. */
function visibleText(html: string): string {
  const body = html.slice(html.indexOf('<body'));
  return body
    .replace(/<svg[\s\S]*?<\/svg>/g, ' ')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/\s+/g, ' ')
    .trim();
}
