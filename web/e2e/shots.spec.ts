import { readFileSync } from 'node:fs';
import { randomBytes } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import type { Page, Route } from '@playwright/test';
import { expect, signInAsProvider, test } from './support/fixtures';
import { E2E_RELEASE_TOKEN } from './support/server';
import {
  cashMovement,
  closeDay,
  createSite,
  deviceTestReport,
  errorReport,
  line,
  MENU as ITEMS,
  openDay,
  pushEntries,
  saleReceipt,
  signature,
  signatureCertificate,
  signatureChain,
  specialReceipt,
  startOfLocalDay,
  voidReceipt,
  type Entry,
} from './support/seed';

/**
 * Bildschirmfotos zum Ansehen, nur mit KASSA_SHOTS_DIR=<Ordner>, etwa:
 * KASSA_SHOTS_DIR=/var/tmp/kassa-shots npx playwright test --trace off
 * Läuft nach auth.spec.ts (das Anbieter-Konto gibt es dann schon).
 */
const dir = process.env.KASSA_SHOTS_DIR;
test.skip(!dir, 'nur mit KASSA_SHOTS_DIR');

const sizes = [
  { name: '1280', width: 1280, height: 800 },
  { name: '390', width: 390, height: 844 },
] as const;
const schemes = [
  { name: 'hell', colorScheme: 'light' },
  { name: 'dunkel', colorScheme: 'dark' },
] as const;

const INPUTS = fileURLToPath(new URL('../../shared/fixtures/menu/inputs/', import.meta.url));
const MENU_FILE = `${INPUTS}beispiel-imbiss.json`;
const INVALID_FILE = `${INPUTS}fehler-mehrere.json`;
const HEADERS = { 'X-Kassa-Request': '1' };
const APK = 'application/vnd.android.package-archive';

const MENU = readFileSync(MENU_FILE, 'utf8');

async function post(page: Page, url: string, data: unknown): Promise<Record<string, any>> {
  const res = await page.request.post(url, { headers: HEADERS, data });
  expect(res.ok(), `${url}: ${res.status()} ${await res.text()}`).toBe(true);
  return (await res.json()) as Record<string, any>;
}

async function pair(page: Page, b: string, name: string, version: string): Promise<string> {
  const { code } = await post(page, `/api/admin/businesses/${b}/pairing-codes`, { name });
  const paired = await post(page, '/api/device/pair', { code, previousBusinessId: null, appVersion: version, deviceModel: 'Redmi Pad Pro' });
  return paired.registerId as string;
}

/** Ein Betrieb ohne Mitarbeiter und Kassen, für die leeren Zustände und das Koppeln. */
async function freshBusiness(page: Page): Promise<string> {
  const created = await post(page, '/api/admin/businesses', { menuFile: MENU.replace(/Beispiel-Imbiss/g, 'Beispiel-Bäckerei') });
  return created.business.id as string;
}

/**
 * Der gut gefüllte Betrieb "Beispiel-Imbiss" mit Mitarbeitern, Kassen und Installationsdateien für die Bilder.
 * Gibt es ihn schon (ein früherer Test hat ihn angelegt), wird er wiederverwendet.
 */
async function theScene(page: Page): Promise<string> {
  const list = (await (await page.request.get('/api/admin/businesses')).json()) as { businesses: { id: string; name: string }[] };
  const known = list.businesses.find((b) => b.name === 'Beispiel-Imbiss');
  if (known) return known.id;

  const full = (await post(page, '/api/admin/businesses', { menuFile: MENU })).business.id as string;
  await post(page, `/api/admin/businesses/${full}/staff`, { name: 'Chefin', role: 'chef', pin: '1234' });
  await post(page, `/api/admin/businesses/${full}/staff`, { name: 'Anna', role: 'staff', pin: '4321' });
  const berta = (await post(page, `/api/admin/businesses/${full}/staff`, { name: 'Berta', role: 'staff', pin: '5678' })).staff;
  await page.request.patch(`/api/admin/businesses/${full}/staff/${berta.id}`, { headers: HEADERS, data: { archived: true } });

  await pair(page, full, 'Theke', '1.2.0');
  const garden = await pair(page, full, 'Gastgarten', '1.1.0');
  await page.request.post(`/api/admin/businesses/${full}/registers/${garden}/block`, { headers: HEADERS });

  const releases = (await (await page.request.get('/api/admin/releases')).json()) as { releases: { id: string; version: string }[] };
  if (releases.releases.length === 0) {
    for (const [version, build, size] of [['1.1.0', 11, 24_900_000], ['1.2.0', 12, 25_300_000]] as const) {
      const up = await page.request.put(`/api/releases/${version}?build=${build}`, {
        headers: { Authorization: `Bearer ${E2E_RELEASE_TOKEN}`, 'Content-Type': APK },
        data: Buffer.concat([Buffer.from([0x50, 0x4b, 0x03, 0x04]), randomBytes(size)]),
      });
      expect(up.ok(), `${up.status()} ${await up.text()}`).toBe(true);
      if (version === '1.1.0') {
        const id = ((await up.json()) as { id: string }).id;
        await page.request.delete(`/api/admin/releases/${id}`, { headers: HEADERS });
      }
    }
  }
  return full;
}

/**
 * Ein Betrieb mit Bons über 30 Tage (immer gleich verteilt) und mehreren Stunden heute, für die Umsätze.
 * Gibt es ihn schon, wird er wiederverwendet.
 */
async function overviewScene(page: Page): Promise<string> {
  const list = (await (await page.request.get('/api/admin/businesses')).json()) as { businesses: { id: string; name: string }[] };
  const known = list.businesses.find((b) => b.name === 'Imbiss am Markt');
  if (known) return known.id;

  const site = await createSite(page, { name: 'Imbiss am Markt' });
  let state = 7;
  const random = () => (state = (state * 48271) % 2147483647) / 2147483647;
  const now = Date.now();
  const today = startOfLocalDay(new Date(now)).getTime();
  const receipts: Entry[] = [];
  for (let day = 29; day >= 0; day--) {
    const start = today - day * 24 * 60 * 60_000;
    const count = day === 0 ? 14 : 3 + Math.floor(random() * 9);
    for (let i = 0; i < count; i++) {
      const at = start + (10 + random() * 11) * 60 * 60_000;
      if (at >= now - 60_000) continue;
      const lines = [line(ITEMS.huhnBowl, 1 + Math.floor(random() * 2))];
      if (random() > 0.4) lines.push(line(ITEMS.cola, 1 + Math.floor(random() * 3)));
      if (random() > 0.6) lines.push(line(ITEMS.teigtaschen));
      receipts.push({ kind: 'receipt', receipt: saleReceipt({ createdAt: new Date(at), payment: random() > 0.65 ? 'card' : 'cash', lines }) });
    }
  }
  for (let i = 0; i < receipts.length; i += 100) await pushEntries(page, site, receipts.slice(i, i + 100));
  return site.businessId;
}

/**
 * Ein Betrieb mit fünf Tagen an zwei Kassen: abgeschlossene Tage (einer stimmt, einer mit Differenz in jede
 * Richtung), heute ein offener Tag, Bons mit Optionen, Karte, Storno, Startbeleg und Signatur. Wird wiederverwendet.
 */
async function receiptsScene(page: Page): Promise<{ businessId: string; sale: string; day: string }> {
  const list = (await (await page.request.get('/api/admin/businesses')).json()) as { businesses: { id: string; name: string }[] };
  const known = list.businesses.find((b) => b.name === 'Imbiss an der Ecke');
  const site = known ? null : await createSite(page, { name: 'Imbiss an der Ecke', registerName: 'Theke' });
  const businessId = known?.id ?? site!.businessId;
  if (site) {
    const today = startOfLocalDay(new Date()).getTime();
    const now = Date.now();
    const H = 60 * 60_000;
    const entries: Entry[] = [{ kind: 'rksv_chain', chain: signatureChain({ chain: 1, mode: 'live' }) }];
    const later: Entry[] = [];
    let position = 0;
    const big = (n: number) => line(ITEMS.huhnBowl, n, [{ groupName: 'Größe', optionName: 'Groß', surchargeCents: 150 }]);
    for (let back = 4; back >= 0; back--) {
      const start = today - back * 24 * H;
      const opened = Math.min(start + 9 * H, now - 3 * H);
      const day = openDay({ openedAt: new Date(opened), openingFloatCents: 15_000 });
      entries.push({ kind: 'day', day });
      let cash = 0;
      const plan = [
        { at: 0.5, lines: [big(1), line(ITEMS.cola, 2)], payment: 'cash' as const, given: 2000 },
        { at: 1.2, lines: [line(ITEMS.teigtaschen, 2)], payment: 'card' as const },
        { at: 1.9, lines: [line(ITEMS.huhnBowl)], payment: 'cash' as const, given: 1000 },
        { at: 2.4, lines: [line(ITEMS.cola, 3), line(ITEMS.teigtaschen)], payment: 'card' as const },
        { at: 2.8, lines: [big(2)], payment: 'cash' as const, given: 5000 },
      ];
      for (const [i, p] of plan.entries()) {
        const at = new Date(Math.min(opened + p.at * H, now - (plan.length - i) * 60_000));
        const receipt = saleReceipt({ createdAt: at, lines: p.lines, payment: p.payment, givenCents: p.given, businessDayId: day.id, test: false, rksv: signature({ position: ++position }) });
        entries.push({ kind: 'receipt', receipt });
        if (p.payment === 'cash') cash += receipt.totalCents;
        if (i === 2 && back === 0) {
          const storno = voidReceipt(receipt, { createdAt: new Date(at.getTime() + 90_000) });
          entries.push({ kind: 'receipt', receipt: storno });
          cash -= receipt.totalCents;
        }
      }
      entries.push({ kind: 'cash_movement', movement: cashMovement(day, { kind: 'withdrawal', amountCents: 2000, reason: 'purchase', createdAt: new Date(opened + 1.5 * H) }) });
      if (back === 4) entries.push({ kind: 'receipt', receipt: specialReceipt('start', { createdAt: new Date(opened - 60_000), test: false }) });
      if (back > 0) {
        const expected = 15_000 + cash - 2000;
        const counted = expected + [0, -150, 200, 0][back - 1]!;
        later.push({ kind: 'day', day: closeDay(day, { closedAt: new Date(opened + 9 * H), expectedCents: expected, countedCents: counted, leftInDrawerCents: 15_000 }) });
      }
    }
    await pushEntries(page, site, entries);
    await pushEntries(page, site, later);
  }
  const receipts = (await (await page.request.get(`/api/admin/businesses/${businessId}/receipts`)).json()) as { receipts: { id: string; kind: string; paymentKind: string; voided: boolean }[] };
  const sale = receipts.receipts.find((r) => r.kind === 'sale' && r.paymentKind === 'cash' && !r.voided)!.id;
  const days = (await (await page.request.get(`/api/admin/businesses/${businessId}/days`)).json()) as { days: { id: string; differenceCents: number | null }[] };
  const day = days.days.find((d) => d.differenceCents !== null && d.differenceCents !== 0)!.id;
  return { businessId, sale, day };
}

const PHOTO = fileURLToPath(new URL('./support/photo.jpg', import.meta.url));
const PHOTO_2 = fileURLToPath(new URL('./support/photo-2.png', import.meta.url));
const LOGO = fileURLToPath(new URL('./support/logo.png', import.meta.url));

async function putImage(page: Page, url: string, path: string, type: string) {
  const res = await page.request.put(url, { headers: { ...HEADERS, 'Content-Type': type }, data: readFileSync(path) });
  expect(res.ok(), `${url}: ${res.status()} ${await res.text()}`).toBe(true);
}

/**
 * Eine Speisekarte mit Fotos, Favoriten, einem Artikel außer Verkauf, einem langen Namen, einem stillgelegten
 * Artikel und einer stillgelegten Kategorie, dazu ein Logo. Wird wiederverwendet.
 */
async function menuScene(page: Page): Promise<string> {
  const list = (await (await page.request.get('/api/admin/businesses')).json()) as { businesses: { id: string; name: string }[] };
  const known = list.businesses.find((b) => b.name === 'Imbiss im Lindenhof');
  if (known) return known.id;
  const base = JSON.parse(MENU) as Record<string, any>;
  const menu = {
    ...base,
    betrieb: 'Imbiss im Lindenhof',
    kategorien: [
      { id: 'bowls', name: 'Bowls' },
      { id: 'getraenke', name: 'Getränke' },
      { id: 'desserts', name: 'Desserts' },
    ],
    artikel: [
      base.artikel[0],
      { id: 'tofu-bowl', name: 'Tofu Bowl', preis_cent: 890, kategorie: 'bowls', mwst: 10, kennzeichen: 'VEGAN' },
      base.artikel[1],
      { id: 'nudeln', name: 'Gebratene Nudeln mit knusprigem Hühnerfleisch und Gemüse der Saison', preis_cent: 1250, kategorie: 'bowls', mwst: 10 },
      { id: 'linsen', name: 'Linsen Curry', preis_cent: 790, kategorie: 'bowls', mwst: 10 },
      base.artikel[2],
      { id: 'almdudler', name: 'Almdudler 0,35 l', preis_cent: 320, kategorie: 'getraenke', mwst: 20, pfand_cent: 25 },
      { id: 'wasser', name: 'Mineralwasser', preis_cent: 250, kategorie: 'getraenke', mwst: 20 },
      { id: 'schmarrn', name: 'Kaiserschmarrn', preis_cent: 690, kategorie: 'desserts', mwst: 10 },
    ],
  };
  const b = (await post(page, '/api/admin/businesses', { menuFile: JSON.stringify(menu) })).business.id as string;
  // Linsen Curry und die Desserts fallen beim neuen Einspielen weg: sie sind dann stillgelegt.
  const later = { ...menu, kategorien: menu.kategorien.slice(0, 2), artikel: menu.artikel.filter((a) => a.id !== 'linsen' && a.id !== 'schmarrn') };
  await post(page, `/api/admin/businesses/${b}/menu`, { menuFile: JSON.stringify(later) });
  const items = `/api/admin/businesses/${b}/items`;
  await putImage(page, `${items}/huhn-bowl/photo`, PHOTO, 'image/jpeg');
  await putImage(page, `${items}/tofu-bowl/photo`, PHOTO_2, 'image/png');
  await putImage(page, `${items}/linsen/photo`, PHOTO, 'image/jpeg');
  await putImage(page, `/api/admin/businesses/${b}/logo`, LOGO, 'image/png');
  for (const [id, change] of [
    ['huhn-bowl', { favorite: true }],
    ['cola', { favorite: true }],
    ['almdudler', { inSale: false }],
  ] as const) {
    const res = await page.request.patch(`${items}/${id}`, { headers: HEADERS, data: change });
    expect(res.ok(), await res.text()).toBe(true);
  }
  return b;
}

/**
 * Ein Betrieb mit zwei Kassen und Ketten der Signatur: an der Theke eine beendete Probe und eine echte Kette, der
 * Gastgarten ohne Bon und ohne Kette. Wird wiederverwendet.
 */
async function chainsScene(page: Page): Promise<string> {
  const list = (await (await page.request.get('/api/admin/businesses')).json()) as { businesses: { id: string; name: string }[] };
  const known = list.businesses.find((b) => b.name === 'Imbiss mit Signatur');
  if (known) return known.id;
  const site = await createSite(page, { name: 'Imbiss mit Signatur', registerName: 'Theke' });
  const now = Date.now();
  const probe = { ...signatureChain({ chain: 1, mode: 'probe', startedAt: new Date(now - 3 * 24 * 60 * 60_000) }), endedAt: new Date(now - 2 * 24 * 60 * 60_000).toISOString() };
  const live = { ...signatureChain({ chain: 2, mode: 'live', startedAt: new Date(now - 2 * 24 * 60 * 60_000) }), cashBoxId: 'IMBISS-THEKE-1' };
  const receipts: Entry[] = [];
  for (let i = 1; i <= 12; i++) {
    receipts.push({ kind: 'receipt', receipt: saleReceipt({ lines: [line(ITEMS.cola)], rksv: signature({ chain: 1, position: i }), createdAt: new Date(now - 2 * 24 * 60 * 60_000 - (20 - i) * 60_000) }) });
  }
  for (let i = 1; i <= 248; i++) {
    receipts.push({ kind: 'receipt', receipt: saleReceipt({ lines: [line(ITEMS.huhnBowl)], rksv: signature({ chain: 2, position: i }), createdAt: new Date(now - (260 - i) * 5 * 60_000) }) });
  }
  await pushEntries(page, site, [
    { kind: 'rksv_certificate', certificate: signatureCertificate() },
    { kind: 'rksv_chain', chain: probe },
    { kind: 'rksv_chain', chain: live },
  ]);
  for (let i = 0; i < receipts.length; i += 100) await pushEntries(page, site, receipts.slice(i, i + 100));
  await pair(page, site.businessId, 'Gastgarten', '1.5.0');
  return site.businessId;
}

const SHOT_STACK = [
  'RangeError (index): Invalid value: Not in inclusive range 0..3: 4',
  '#0      List.[] (dart:core-patch/growable_array.dart:264:36)',
  '#1      BonView._lineAt (package:kassa/features/bons/bon_view.dart:88:21)',
  '#2      BonView.build.<anonymous closure> (package:kassa/features/bons/bon_view.dart:61:18)',
  '#3      SliverChildBuilderDelegate.build (package:flutter/src/widgets/scroll_delegate.dart:479:22)',
  '#4      SliverMultiBoxAdaptorElement._build (package:flutter/src/widgets/sliver.dart:944:28)',
  '#5      SliverMultiBoxAdaptorElement.createChild.<anonymous closure> (package:flutter/src/widgets/sliver.dart:958:55)',
  '#6      BuildOwner.buildScope (package:flutter/src/widgets/framework.dart:2869:19)',
  '#7      SliverMultiBoxAdaptorElement.createChild (package:flutter/src/widgets/sliver.dart:950:12)',
  '#8      RenderSliverMultiBoxAdaptor._createOrObtainChild (package:flutter/src/rendering/sliver_multi_box_adaptor.dart:349:5)',
  '#9      RenderSliverList.performLayout (package:flutter/src/rendering/sliver_list.dart:90:31)',
  '#10     RenderObject.layout (package:flutter/src/rendering/object.dart:2615:7)',
  '#11     RenderViewportBase.layoutChildSequence (package:flutter/src/rendering/viewport.dart:601:13)',
  '#12     RenderViewport._attemptLayout (package:flutter/src/rendering/viewport.dart:1554:12)',
  '#13     RenderViewport.performLayout (package:flutter/src/rendering/viewport.dart:1463:20)',
  '#14     PipelineOwner.flushLayout (package:flutter/src/rendering/object.dart:1065:18)',
  '#15     RendererBinding.drawFrame (package:flutter/src/rendering/binding.dart:582:23)',
].join('\n');

/** Berichte aus zwei Betrieben (ein Fehler dreimal, ein Geräte-Test, ein Bericht des Servers). Wird wiederverwendet. */
async function reportsScene(page: Page): Promise<void> {
  const list = (await (await page.request.get('/api/admin/businesses')).json()) as { businesses: { id: string; name: string }[] };
  if (list.businesses.some((b) => b.name === 'Imbiss Lindengasse')) return;
  const linden = await createSite(page, { name: 'Imbiss Lindengasse', registerName: 'Theke' });
  const cafe = await createSite(page, { name: 'Café am Platz', registerName: 'Gastgarten' });
  const minutes = (n: number) => new Date(Date.now() - n * 60_000);
  // Ältere zuerst senden: die Liste steht nach Eingang beim Server.
  await pushEntries(page, cafe, [{ kind: 'report', report: errorReport({ type: 'SocketException', message: 'Connection timed out', stack: '#0      _NativeSocket.connect (dart:io-patch/socket_patch.dart:723:35)', at: minutes(52), appVersion: '1.4.0' }) }]);
  await pushEntries(page, linden, [{ kind: 'report', report: errorReport({ count: 3, stack: SHOT_STACK, message: 'Invalid value: Not in inclusive range 0..3: 4', at: minutes(31) }) }]);
  await pushEntries(page, cafe, [
    {
      kind: 'report',
      report: deviceTestReport(
        [
          { device: 'printer', ok: true, text: 'Testbon gedruckt.' },
          { device: 'drawer', ok: false, text: 'Die Lade hat sich nicht geöffnet. Prüf das Kabel am Drucker.' },
          { device: 'card', ok: true, text: 'SumUp Air verbunden.' },
        ],
        { at: minutes(18) },
      ),
    },
  ]);
  const broken = saleReceipt({ lines: [line(ITEMS.huhnBowl), line(ITEMS.cola)], createdAt: minutes(9) });
  await pushEntries(page, linden, [{ kind: 'receipt', receipt: { ...broken, totalCents: broken.totalCents + 100 } }]);
}

/** Wartet, bis jedes Bild in der Seite geladen und eingeblendet ist. */
async function imagesLoaded(page: Page) {
  await expect.poll(() => page.evaluate(() => [...document.images].every((i) => i.complete && i.naturalWidth > 0))).toBe(true);
}

async function shoot(page: Page, name: string, fullPage = true) {
  await page.evaluate(() => document.fonts.ready);
  // Dialog und Hinweis laufen 220 ms ein: erst danach fotografieren.
  await page.waitForTimeout(400);
  await page.screenshot({ path: `${dir}/${name}.png`, fullPage });
}

for (const size of sizes) {
  for (const scheme of schemes) {
    test.describe(`${size.name} ${scheme.name}`, () => {
      test.use({ viewport: { width: size.width, height: size.height }, deviceScaleFactor: 1 });
      test.beforeEach(async ({ page }) => {
        await page.emulateMedia({ colorScheme: scheme.colorScheme });
      });
      const suffix = `${size.name}-${scheme.name}`;

      test('anmelden', async ({ page }) => {
        await page.goto('/anmelden');
        await page.getByRole('heading', { name: 'Anmelden' }).waitFor();
        await shoot(page, `anmelden-${suffix}`);

        // Nie die E-Mail des Anbieters: Fehlversuche dort würden seine Anmeldung sperren.
        await page.getByLabel('E-Mail').fill('kein-konto@example.com');
        await page.getByLabel('Passwort', { exact: true }).fill('falsches-passwort');
        await page.getByRole('button', { name: 'Anmelden' }).click();
        await page.getByRole('alert').waitFor();
        await page.getByLabel('Passwort', { exact: true }).blur();
        await shoot(page, `anmelden-fehler-${suffix}`);
      });

      test('einrichten', async ({ page }) => {
        await page.route('**/api/auth/setup?*', (route) => route.fulfill({ json: { valid: true } }));
        await page.goto('/einrichten?token=vorschau');
        await page.getByRole('button', { name: 'Konto anlegen' }).waitFor();
        await shoot(page, `einrichten-${suffix}`);

        await page.getByLabel('E-Mail').fill('beispiel@example');
        await page.getByLabel('Passwort', { exact: true }).fill('123456789');
        await page.getByRole('button', { name: 'Konto anlegen' }).click();
        await page.getByLabel('E-Mail').blur();
        await shoot(page, `einrichten-fehler-${suffix}`);

        await page.unroute('**/api/auth/setup?*');
        await page.goto('/einrichten?token=verbraucht');
        await page.getByText('Dieser Link gilt nicht mehr.', { exact: false }).waitFor();
        await shoot(page, `einrichten-ungueltig-${suffix}`);
      });

      test('betriebe', async ({ page }) => {
        await signInAsProvider(page);
        const full = await theScene(page);
        await page.goto('/betriebe');
        await expect(page.getByRole('list', { name: 'Betriebe' })).toBeVisible();
        await shoot(page, `betriebe-${suffix}`);

        await page.getByRole('button', { name: 'Betrieb anlegen' }).click();
        await shoot(page, `betriebe-dialog-${suffix}`);
        await page.getByRole('dialog').locator('input[type=file]').setInputFiles(INVALID_FILE);
        await expect(page.getByRole('alert')).toBeVisible();
        await shoot(page, `betriebe-dialog-fehler-${suffix}`);
        await page.keyboard.press('Escape');

        await page.route('**/api/admin/businesses', (route) => route.fulfill({ json: { businesses: [] } }));
        await page.goto('/betriebe');
        await expect(page.getByText('Noch kein Betrieb')).toBeVisible();
        await shoot(page, `betriebe-leer-${suffix}`);
        await page.unroute('**/api/admin/businesses');

        // Laden und Fehler.
        await page.route(`**/api/admin/businesses/${full}/registers`, async (route) => {
          await new Promise((r) => setTimeout(r, 1500));
          await route.fulfill({ status: 409, json: { error: { code: 'conflict', message: 'Das hat nicht geklappt. Bitte nochmal versuchen.' } } });
        });
        await page.goto(`/b/${full}/kassen`);
        await expect(page.getByRole('status').filter({ hasText: 'Kassen werden geladen' })).toBeVisible();
        await shoot(page, `laden-${suffix}`);
        await expect(page.getByRole('button', { name: 'Nochmal versuchen' })).toBeVisible();
        await shoot(page, `fehler-${suffix}`);
      });

      test('speisekarte', async ({ page }) => {
        await signInAsProvider(page);
        const full = await theScene(page);
        await page.goto(`/b/${full}/speisekarte`);
        await expect(page.getByRole('list', { name: 'Bowls' })).toBeVisible();
        await shoot(page, `speisekarte-einfach-${suffix}`);
        await page.getByRole('button', { name: 'Speisekarte neu einspielen' }).click();
        await shoot(page, `speisekarte-dialog-${suffix}`);
        await page.getByRole('dialog').locator('input[type=file]').setInputFiles(INVALID_FILE);
        await page.getByRole('dialog').getByRole('button', { name: 'Neu einspielen' }).click();
        await expect(page.getByRole('alert')).toBeVisible();
        await shoot(page, `speisekarte-dialog-fehler-${suffix}`);
      });

      test('speisekarte mit preisen und fotos', async ({ page }) => {
        await signInAsProvider(page);
        const b = await menuScene(page);
        await page.goto(`/b/${b}/speisekarte`);
        await expect(page.getByRole('list', { name: 'Bowls' })).toBeVisible();
        await imagesLoaded(page);
        await shoot(page, `speisekarte-${suffix}`);

        const field = page.getByRole('textbox', { name: 'Tofu Bowl: Preis' });
        await field.fill('8,9,0');
        await field.blur();
        await expect(page.getByText('Gib einen Preis wie 9,90 ein.')).toBeVisible();
        await field.scrollIntoViewIfNeeded();
        await shoot(page, `speisekarte-fehler-${suffix}`, false);
        await field.focus();
        await page.keyboard.press('Escape');

        // Das Fenster mit dem vorhandenen Foto.
        await page.getByRole('button', { name: 'Huhn Bowl: Foto ändern' }).click();
        const dialog = page.getByRole('dialog', { name: 'Foto für Huhn Bowl' });
        await expect(dialog.getByRole('img', { name: 'Vorschau' })).toBeVisible();
        await imagesLoaded(page);
        await shoot(page, `foto-fenster-${suffix}`, false);

        // Neue Datei, die Antwort bleibt aus: Vorschau und Fortschritt. Schließen bricht ab, am Server ändert sich nichts.
        let held: Route | undefined;
        await page.route('**/api/admin/businesses/*/items/*/photo', (route) => {
          held = route;
        });
        await dialog.locator('input[type=file]').setInputFiles(PHOTO_2);
        await dialog.getByRole('button', { name: 'Speichern' }).click();
        await expect(dialog.getByRole('progressbar')).toBeVisible();
        await shoot(page, `foto-fenster-hochladen-${suffix}`, false);
        await page.keyboard.press('Escape');
        // Die gehaltene Anfrage kommt so nie beim Server an, die Speisekarte für die Bilder bleibt gleich.
        await held?.abort().catch(() => undefined);
        await page.unroute('**/api/admin/businesses/*/items/*/photo');

        // Ohne Foto, mit einer abgewiesenen Datei.
        await page.getByRole('button', { name: 'Teigtaschen: Foto hinzufügen' }).click();
        await page.getByRole('dialog').locator('input[type=file]').setInputFiles({ name: 'notiz.txt', mimeType: 'text/plain', buffer: Buffer.from('Notiz') });
        await expect(page.getByRole('dialog').getByRole('alert')).toBeVisible();
        await shoot(page, `foto-fenster-fehler-${suffix}`, false);
        await page.keyboard.press('Escape');

        await page.route(`**/api/admin/businesses/${b}/items`, async (route) => {
          await new Promise((r) => setTimeout(r, 1500));
          await route.continue().catch(() => undefined);
        });
        await page.goto(`/b/${b}/speisekarte`);
        await expect(page.getByRole('status').filter({ hasText: 'Speisekarte wird geladen' })).toBeVisible();
        await shoot(page, `speisekarte-laden-${suffix}`);
        await page.unroute(`**/api/admin/businesses/${b}/items`);
      });

      test('betrieb', async ({ page }) => {
        await signInAsProvider(page);
        const b = await menuScene(page);
        await page.goto(`/b/${b}/betrieb`);
        await expect(page.getByRole('heading', { level: 1, name: 'Betrieb' })).toBeVisible();
        await imagesLoaded(page);
        await shoot(page, `betrieb-${suffix}`);
        await page.getByRole('button', { name: 'Logo ändern' }).click();
        await expect(page.getByRole('dialog', { name: 'Logo' }).getByRole('img', { name: 'Vorschau' })).toBeVisible();
        await imagesLoaded(page);
        await shoot(page, `betrieb-logo-fenster-${suffix}`, false);
        await page.keyboard.press('Escape');

        const empty = await freshBusiness(page);
        await page.goto(`/b/${empty}/betrieb`);
        await expect(page.getByRole('button', { name: 'Logo hinzufügen' })).toBeVisible();
        await shoot(page, `betrieb-ohne-logo-${suffix}`);
      });

      test('mitarbeiter', async ({ page }) => {
        await signInAsProvider(page);
        const full = await theScene(page);
        const empty = await freshBusiness(page);
        await page.goto(`/b/${full}/mitarbeiter`);
        await expect(page.getByRole('list', { name: 'Mitarbeiter' })).toBeVisible();
        await shoot(page, `mitarbeiter-${suffix}`);

        await page.getByRole('button', { name: 'Mitarbeiter anlegen' }).click();
        await shoot(page, `mitarbeiter-dialog-${suffix}`);
        await page.getByRole('dialog').getByLabel('Name').fill('Clara');
        await page.getByRole('dialog').getByLabel('PIN').fill('1234');
        await page.getByRole('dialog').getByRole('button', { name: 'Anlegen' }).click();
        await expect(page.getByRole('dialog').getByText('Diese PIN ist schon vergeben.')).toBeVisible();
        await shoot(page, `mitarbeiter-dialog-fehler-${suffix}`);
        await page.keyboard.press('Escape');

        await page.getByRole('listitem').filter({ hasText: 'Anna' }).getByRole('button', { name: 'Stilllegen' }).click();
        await expect(page.locator('[popover]').getByRole('button', { name: 'Rückgängig' })).toBeVisible();
        await shoot(page, `mitarbeiter-hinweis-${suffix}`);
        await page.locator('[popover]').getByRole('button', { name: 'Rückgängig' }).click();
        await expect(page.getByRole('listitem').filter({ hasText: 'Anna' })).not.toContainText('Stillgelegt');
        await page.waitForLoadState('networkidle');

        await page.goto(`/b/${empty}/mitarbeiter`);
        await expect(page.getByText('Noch kein Mitarbeiter. Lege zuerst einen Chef an.')).toBeVisible();
        await shoot(page, `mitarbeiter-leer-${suffix}`);
      });

      test('kassen', async ({ page }) => {
        await signInAsProvider(page);
        const full = await theScene(page);
        const empty = await freshBusiness(page);
        await page.goto(`/b/${full}/kassen`);
        await expect(page.getByRole('list', { name: 'Kassen' })).toBeVisible();
        await shoot(page, `kassen-${suffix}`);

        await page.getByRole('listitem').filter({ hasText: 'Theke' }).getByRole('button', { name: 'Sperren' }).click();
        await shoot(page, `kassen-sperren-${suffix}`);
        await page.keyboard.press('Escape');

        await page.route(`**/api/admin/businesses/${full}/staff`, (route) => route.fulfill({ json: { staff: [] } }));
        await page.reload();
        await expect(page.getByRole('link', { name: 'Zu den Mitarbeitern' })).toBeVisible();
        await shoot(page, `kassen-ohne-chef-liste-${suffix}`);
        await page.unroute(`**/api/admin/businesses/${full}/staff`);

        await page.goto(`/b/${empty}/kassen`);
        await expect(page.getByRole('link', { name: 'Zu den Mitarbeitern' })).toBeVisible();
        await shoot(page, `kassen-ohne-chef-${suffix}`);

        await post(page, `/api/admin/businesses/${empty}/staff`, { name: 'Chefin', role: 'chef', pin: '1234' });
        await page.reload();
        await expect(page.getByRole('button', { name: 'Kassa koppeln' })).toBeVisible();
        await shoot(page, `kassen-leer-${suffix}`);

        await page.getByRole('button', { name: 'Kassa koppeln' }).click();
        await shoot(page, `kassen-koppeln-name-${suffix}`);
        await page.getByRole('dialog').getByRole('button', { name: 'Code erzeugen' }).click();
        await expect(page.getByTestId('pairing-code')).toBeVisible();
        await shoot(page, `kassen-koppeln-code-${suffix}`);

        const code = ((await page.getByTestId('pairing-code').textContent()) ?? '').replace(' ', '');
        await post(page, '/api/device/pair', { code, previousBusinessId: null, appVersion: '1.2.0', deviceModel: 'Redmi Pad Pro' });
        await expect(page.getByRole('dialog').getByText('Verbunden', { exact: true })).toBeVisible({ timeout: 8000 });
        await shoot(page, `kassen-koppeln-verbunden-${suffix}`);
      });

      test('kopplungscode abgelaufen', async ({ page }) => {
        await signInAsProvider(page);
        await theScene(page);
        const empty = await freshBusiness(page);
        await post(page, `/api/admin/businesses/${empty}/staff`, { name: 'Chefin', role: 'chef', pin: '1234' });
        await page.goto(`/b/${empty}/kassen`);
        await page.clock.install();
        await page.getByRole('button', { name: /Kassa koppeln|Koppeln/ }).first().click();
        await page.getByRole('dialog').getByRole('button', { name: 'Code erzeugen' }).click();
        await expect(page.getByTestId('pairing-code')).toBeVisible();
        await page.clock.fastForward('15:05');
        await expect(page.getByText('Der Code ist abgelaufen.')).toBeVisible();
        await shoot(page, `kassen-koppeln-abgelaufen-${suffix}`);
      });

      test('umsaetze', async ({ page }) => {
        await signInAsProvider(page);
        const full = await overviewScene(page);
        await page.goto(`/b/${full}/umsaetze`);
        await expect(page.getByTestId('revenue')).toBeVisible();
        await shoot(page, `umsaetze-${suffix}`);
        await page.goto(`/b/${full}/umsaetze?zeit=7`);
        await expect(page.getByRole('group', { name: 'Umsatz pro Tag' }).getByRole('button')).toHaveCount(7);
        await shoot(page, `umsaetze-7-${suffix}`);
        await page.goto(`/b/${full}/umsaetze?zeit=30`);
        await expect(page.getByRole('group', { name: 'Umsatz pro Tag' }).getByRole('button')).toHaveCount(30);
        await shoot(page, `umsaetze-30-${suffix}`);

        // Ein Balken mit der Tastatur gewählt.
        await page.getByRole('group', { name: 'Umsatz pro Tag' }).getByRole('button').first().focus();
        await page.keyboard.press('End');
        await page.keyboard.press('ArrowLeft');
        await shoot(page, `umsaetze-30-balken-${suffix}`);

        // Heute noch kein Bon, aber Bons in den Tagen davor: die normale Seite mit 0,00 €.
        const quiet = await createSite(page, { name: 'Imbiss am Morgen' });
        await pushEntries(page, quiet, [
          { kind: 'receipt', receipt: saleReceipt({ createdAt: new Date(Date.now() - 2 * 24 * 60 * 60_000), lines: [line(ITEMS.huhnBowl), line(ITEMS.cola)] }) },
        ]);
        await page.goto(`/b/${quiet.businessId}/umsaetze`);
        await expect(page.getByText('Heute noch kein Bon.')).toBeVisible();
        await shoot(page, `umsaetze-heute-leer-${suffix}`);

        const empty = await freshBusiness(page);
        await page.goto(`/b/${empty}/umsaetze`);
        await expect(page.getByText('Noch kein Bon.')).toBeVisible();
        await shoot(page, `umsaetze-leer-${suffix}`);

        await page.route(`**/api/admin/businesses/${full}/overview?*`, async (route) => {
          await new Promise((r) => setTimeout(r, 1500));
          await route.fulfill({ status: 409, json: { error: { code: 'conflict', message: 'Das hat nicht geklappt. Bitte nochmal versuchen.' } } });
        });
        await page.goto(`/b/${full}/umsaetze`);
        await expect(page.getByRole('status').filter({ hasText: 'Umsätze werden geladen' })).toBeVisible();
        await shoot(page, `umsaetze-laden-${suffix}`);
        await expect(page.getByRole('button', { name: 'Nochmal versuchen' })).toBeVisible();
        await shoot(page, `umsaetze-fehler-${suffix}`);
      });

      test('bons und tage', async ({ page }) => {
        await signInAsProvider(page);
        const { businessId, sale, day } = await receiptsScene(page);
        await page.goto(`/b/${businessId}/bons`);
        await expect(page.getByRole('main').getByRole('link', { name: /^Bon \d+/ }).first()).toBeVisible();
        await shoot(page, `bons-${suffix}`);
        await page.goto(`/b/${businessId}/bons?zahlung=bar&stornos=1`);
        await expect(page.getByRole('main').getByRole('link', { name: /^Bon \d+/ })).toHaveCount(2);
        await shoot(page, `bons-filter-${suffix}`);
        await page.goto(`/b/${businessId}/bons?zahlung=karte&stornos=1`);
        await expect(page.getByText('Kein Bon passt zu diesem Filter.')).toBeVisible();
        await shoot(page, `bons-leer-${suffix}`);
        const empty = await freshBusiness(page);
        await page.goto(`/b/${empty}/bons`);
        await expect(page.getByText('Sobald an der Kassa boniert wird, erscheinen die Bons hier.')).toBeVisible();
        await shoot(page, `bons-leer-ohne-bon-${suffix}`);

        await page.goto(`/b/${businessId}/bons/${sale}`);
        await expect(page.getByRole('dialog').getByTestId('total')).toBeVisible();
        await shoot(page, `bon-detail-${suffix}`, false);
        const storno = page.getByRole('main').locator('a', { hasText: 'Storno' });
        await page.keyboard.press('Escape');
        await storno.first().click();
        await expect(page.getByRole('dialog').getByRole('link', { name: /Zum stornierten Bon/ })).toBeVisible();
        await shoot(page, `bon-detail-storno-${suffix}`, false);

        await page.route(`**/api/admin/businesses/${businessId}/receipts?*`, async (route) => {
          await new Promise((r) => setTimeout(r, 1500));
          // Nach dem Foto ist die Seite schon weiter: dann gibt es nichts mehr zu beantworten.
          await route.continue().catch(() => undefined);
        });
        await page.goto(`/b/${businessId}/bons?zahlung=bar`);
        await expect(page.getByRole('status').filter({ hasText: 'Bons werden geladen' })).toBeVisible();
        await shoot(page, `bons-laden-${suffix}`);
        await page.unroute(`**/api/admin/businesses/${businessId}/receipts?*`);

        await page.goto(`/b/${businessId}/tage`);
        await expect(page.getByRole('main').getByRole('link').first()).toBeVisible();
        await shoot(page, `tage-${suffix}`);
        await page.goto(`/b/${businessId}/tage/${day}`);
        await expect(page.getByRole('dialog').getByTestId('difference')).toBeVisible();
        await shoot(page, `tag-detail-${suffix}`, false);
        await page.keyboard.press('Escape');
        await page.getByRole('main').getByRole('link').first().click();
        await expect(page.getByRole('dialog').getByText('offen')).toBeVisible();
        await shoot(page, `tag-detail-offen-${suffix}`, false);
      });

      test('leiste mehr', async ({ page }) => {
        await signInAsProvider(page);
        const { businessId } = await receiptsScene(page);
        await page.goto(`/b/${businessId}/kassen`);
        await expect(page.getByRole('heading', { level: 1, name: 'Kassen' })).toBeVisible();
        if (size.width < 1024) {
          await page.getByRole('navigation', { name: 'Bereiche' }).filter({ visible: true }).getByRole('button', { name: 'Mehr' }).click();
          await expect(page.getByRole('dialog', { name: 'Mehr' })).toBeVisible();
        }
        await shoot(page, `leiste-mehr-${suffix}`, false);
      });

      test('kassen ketten', async ({ page }) => {
        await signInAsProvider(page);
        const b = await chainsScene(page);
        await page.goto(`/b/${b}/kassen`);
        await expect(page.getByRole('list', { name: 'Ketten der Signatur: Theke' })).toBeVisible();
        await shoot(page, `kassen-ketten-${suffix}`);
      });

      test('fehlerberichte', async ({ page }) => {
        await signInAsProvider(page);
        await reportsScene(page);
        const today = startOfLocalDay(new Date()).getTime();
        const fresh = { latest: { day: 'x', finishedAt: new Date(today + 3 * 60 * 60_000 + 12 * 60_000).toISOString(), size: 25_270_000 }, lastError: null };
        await page.route('**/api/admin/backups/latest', (route) => route.fulfill({ json: fresh }));
        await page.goto('/fehlerberichte');
        const rows = page.getByRole('main').locator('button[aria-expanded]');
        await expect(rows.filter({ hasText: 'Imbiss Lindengasse' }).first()).toBeVisible();
        await shoot(page, `fehlerberichte-${suffix}`, false);

        // Ein Fehler offen, mit der Aufrufliste im eigenen Kasten.
        const error = rows.filter({ hasText: 'Imbiss Lindengasse' }).filter({ hasText: 'Fehler' });
        await error.click();
        await expect(page.getByRole('region', { name: 'Aufrufliste' })).toBeVisible();
        await shoot(page, `fehlerberichte-offen-${suffix}`);
        await error.click();

        const deviceTest = rows.filter({ hasText: 'Geräte-Test' }).first();
        await deviceTest.click();
        await expect(page.getByRole('list', { name: 'Geräte' })).toBeVisible();
        await shoot(page, `fehlerberichte-geraete-test-${suffix}`);
        await rows.filter({ hasText: 'Server' }).first().click();
        await shoot(page, `fehlerberichte-server-${suffix}`);

        await page.route('**/api/admin/reports', (route) => route.fulfill({ json: { reports: [], next: null } }));
        await page.goto('/fehlerberichte');
        await expect(page.getByText('Keine Berichte. Das ist gut.')).toBeVisible();
        await shoot(page, `fehlerberichte-leer-${suffix}`);

        // Laden: beide Antworten gehalten, bis das Bild gemacht ist.
        let release: () => void = () => undefined;
        const held = new Promise<void>((r) => (release = r));
        await page.unroute('**/api/admin/reports');
        await page.unroute('**/api/admin/backups/latest');
        await page.route('**/api/admin/reports', async (route) => {
          await held;
          await route.fallback().catch(() => undefined);
        });
        await page.route('**/api/admin/backups/latest', async (route) => {
          await held;
          await route.fulfill({ json: fresh }).catch(() => undefined);
        });
        await page.goto('/fehlerberichte');
        await expect(page.getByRole('status').filter({ hasText: 'Berichte werden geladen' })).toBeVisible();
        await shoot(page, `fehlerberichte-laden-${suffix}`, false);
        release();
      });

      test('sicherung', async ({ page }) => {
        await signInAsProvider(page);
        await reportsScene(page);
        const today = startOfLocalDay(new Date()).getTime();
        const at = (ms: number) => new Date(today + ms).toISOString();
        const states: [string, object][] = [
          ['keine', { latest: null, lastError: null }],
          ['keine-fehler', { latest: null, lastError: { at: at(4 * 60 * 60_000), error: 'pg_dump: error: connection to server failed: Connection refused.' } }],
          ['heute', { latest: { day: 'x', finishedAt: at(3 * 60 * 60_000 + 12 * 60_000), size: 25_270_000 }, lastError: null }],
          [
            'alt',
            {
              latest: { day: 'x', finishedAt: at(-2 * 24 * 60 * 60_000 + 3 * 60 * 60_000 + 12 * 60_000), size: 24_870_000 },
              lastError: { at: at(4 * 60 * 60_000), error: 'pg_dump: error: connection to server failed: Connection refused. Is the server running and accepting TCP/IP connections?' },
            },
          ],
        ];
        for (const [name, body] of states) {
          await page.route('**/api/admin/backups/latest', (route) => route.fulfill({ json: body }));
          await page.goto('/fehlerberichte');
          await expect(page.getByRole('region', { name: 'Sicherung' }).getByRole('status')).toHaveCount(0);
          await expect(page.getByRole('main').locator('button[aria-expanded]').first()).toBeVisible();
          await shoot(page, `sicherung-${name}-${suffix}`, false);
          await page.unroute('**/api/admin/backups/latest');
        }
      });

      test('installationsdateien', async ({ page }) => {
        await signInAsProvider(page);
        await theScene(page);
        await page.goto('/installationsdateien');
        await expect(page.getByRole('list', { name: 'Installationsdateien' })).toBeVisible();
        await shoot(page, `installationsdateien-${suffix}`);

        await page.getByRole('button', { name: /Zurückziehen/ }).first().click();
        await shoot(page, `installationsdateien-zurueckziehen-${suffix}`);
        await page.keyboard.press('Escape');

        await page.route('**/api/admin/releases', (route) => route.fulfill({ json: { releases: [] } }));
        await page.goto('/installationsdateien');
        await expect(page.getByText('Noch keine Installationsdatei.')).toBeVisible();
        await shoot(page, `installationsdateien-leer-${suffix}`);
      });
    });
  }
}
