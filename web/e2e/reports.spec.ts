import { randomBytes } from 'node:crypto';
import type { Locator, Page, Route } from '@playwright/test';
import { expect, signInAsProvider, test } from './support/fixtures';
import { createSite, deviceTestReport, errorReport, line, MENU, pushEntries, saleReceipt, startOfLocalDay } from './support/seed';

// "heute, 03:12" rechnet die Seite in Wiener Zeit; der Browser steht in derselben Zeitzone.
test.use({ timezoneId: 'Europe/Vienna' });

test.beforeEach(async ({ page }) => {
  await signInAsProvider(page);
});

const HOUR = 60 * 60_000;
const CONFLICT = { error: { code: 'conflict', message: 'Das hat nicht geklappt. Bitte nochmal versuchen.' } };

/** Ein Wort, das die Betriebe eines Testlaufs von allen anderen in der gemeinsamen Liste unterscheidet. */
const tag = () => randomBytes(2).toString('hex');

/** Die Zeilen der Liste: jede ist ein Knopf, der ihren Inhalt aufklappt. */
function reportRows(page: Page, text?: string): Locator {
  const rows = page.getByRole('main').locator('button[aria-expanded]');
  return text ? rows.filter({ hasText: text }) : rows;
}

/** Der aufgeklappte Inhalt einer Zeile, über `aria-controls`. */
async function contentOf(page: Page, row: Locator): Promise<Locator> {
  const id = await row.getAttribute('aria-controls');
  expect(id).toBeTruthy();
  return page.locator(`[id="${id}"]`);
}

function backupCard(page: Page): Locator {
  return page.getByRole('region', { name: 'Sicherung' });
}

async function noHorizontalScroll(page: Page, what: string): Promise<void> {
  const { scrollWidth, clientWidth } = await page.evaluate(() => ({
    scrollWidth: document.documentElement.scrollWidth,
    clientWidth: document.documentElement.clientWidth,
  }));
  expect(scrollWidth, what).toBeLessThanOrEqual(clientWidth);
}

/** Eine lange Zeile ohne Leerzeichen und ein Stück HTML: beides muss als Text im Kasten bleiben. */
const LONG_STACK = [
  '#0      List.[] (dart:core-patch/growable_array.dart:264:36)',
  `#1      ${'SehrLangerName'.repeat(20)} (package:kassa/features/bons/bon_view.dart:88:21)`,
  '#2      <b>nicht fett</b> <img src=x onerror="window.__xss=1">',
  ...Array.from({ length: 40 }, (_, i) => `#${i + 3}      Frame.call (package:kassa/x.dart:${i + 1}:1)`),
].join('\n');

/** Zwei Betriebe: ein Fehler (dreimal) in Nord, ein Geräte-Test und ein Bericht des Servers in Süd. */
async function seedTwoBusinesses(page: Page) {
  const t = tag();
  const north = await createSite(page, { name: `Imbiss Nord ${t}`, registerName: 'Theke' });
  const south = await createSite(page, { name: `Imbiss Süd ${t}`, registerName: 'Gastgarten' });
  // Jede Sendung ihre eigene Zeit beim Server: so ist die Reihenfolge neueste zuerst fest.
  await pushEntries(page, north, [{ kind: 'report', report: errorReport({ count: 3, stack: LONG_STACK }) }]);
  await pushEntries(page, south, [
    {
      kind: 'report',
      report: deviceTestReport([
        { device: 'printer', ok: true, text: 'Testbon gedruckt.' },
        { device: 'drawer', ok: false, text: 'Die Lade hat sich nicht geöffnet.' },
      ]),
    },
  ]);
  // Ein Bon, dessen Summen nicht stimmen: der Server nimmt ihn an und schreibt einen eigenen Bericht.
  const broken = saleReceipt({ lines: [line(MENU.huhnBowl)] });
  await pushEntries(page, south, [{ kind: 'receipt', receipt: { ...broken, totalCents: broken.totalCents + 100 } }]);
  return { t, north, south, broken };
}

test('Anbieter sieht die Berichte zweier Betriebe und klappt sie auf', async ({ page, context }) => {
  await context.grantPermissions(['clipboard-read', 'clipboard-write']);
  const { t, broken } = await seedTwoBusinesses(page);

  // Dritter Bereich des Anbieters, nach Betriebe und Installationsdateien.
  await page.goto('/betriebe');
  const nav = page.getByRole('navigation', { name: 'Bereiche' }).first();
  await expect(nav.getByRole('link')).toHaveText(['Betriebe', 'Installationsdateien', 'Fehlerberichte']);
  await nav.getByRole('link', { name: 'Fehlerberichte' }).click();
  await expect(page).toHaveURL(/\/fehlerberichte$/);
  await expect(page.getByRole('heading', { level: 1, name: 'Fehlerberichte' })).toBeVisible();
  await expect(page.getByRole('heading', { level: 2, name: 'Heute' })).toBeVisible();

  const mine = reportRows(page, t);
  await expect(mine).toHaveCount(3);
  // Neueste zuerst: Server, Geräte-Test, Fehler.
  await expect(mine.nth(0)).toContainText(`Imbiss Süd ${t} · Gastgarten`);
  await expect(mine.nth(0)).toContainText('Server');
  await expect(mine.nth(1)).toContainText('Geräte-Test');
  await expect(mine.nth(1)).toContainText('1.5.0');
  const error = mine.nth(2);
  await expect(error).toContainText(`Imbiss Nord ${t} · Theke`);
  await expect(error).toContainText('Fehler');
  await expect(error).toContainText('1.5.0');
  await expect(error).toContainText('×3');
  await expect(error).toHaveAccessibleName(/3 Mal/);
  await expect(error).toContainText(/\b\d{2}:\d{2}\b/);
  // Ohne Wiederholung kein Zähler.
  await expect(mine.nth(1)).not.toContainText('×');
  for (let i = 0; i < 3; i++) await expect(mine.nth(i)).toHaveAttribute('aria-expanded', 'false');

  // Aufklappen springt nicht: die Seite bleibt, wo sie war.
  await error.scrollIntoViewIfNeeded();
  const before = await page.evaluate(() => window.scrollY);
  const top = (await error.boundingBox())!.y;
  await error.click();
  await expect(error).toHaveAttribute('aria-expanded', 'true');
  expect(await page.evaluate(() => window.scrollY)).toBe(before);
  expect((await error.boundingBox())!.y).toBe(top);

  const errorContent = await contentOf(page, error);
  await expect(errorContent).toHaveRole('region');
  await expect(errorContent).toHaveAccessibleName(/Imbiss Nord/);
  await expect(errorContent).toContainText('RangeError');
  await expect(errorContent).toContainText('Index außerhalb der Liste');
  await expect(errorContent).toContainText('Redmi Pad Pro');
  const stack = errorContent.locator('pre');
  await expect(stack).toHaveText(LONG_STACK);
  // Nur Text, nie HTML.
  await expect(stack.locator('b, img')).toHaveCount(0);
  expect(await page.evaluate(() => (window as { __xss?: number }).__xss)).toBeUndefined();
  // Die Aufrufliste scrollt in ihrem Kasten, höchstens etwa 320 px hoch, auch seitlich.
  const box = await stack.evaluate((el) => {
    const s = getComputedStyle(el);
    return { height: el.clientHeight, scrollHeight: el.scrollHeight, scrollWidth: el.scrollWidth, width: el.clientWidth, x: s.overflowX, y: s.overflowY, font: s.fontFamily };
  });
  expect(box.height).toBeLessThanOrEqual(330);
  expect(box.scrollHeight).toBeGreaterThan(box.height);
  expect(box.scrollWidth).toBeGreaterThan(box.width);
  expect(box.y).toBe('auto');
  expect(box.x).toBe('auto');
  expect(box.font).toMatch(/mono/);
  await noHorizontalScroll(page, 'Aufrufliste offen');

  await errorContent.getByRole('button', { name: 'Aufrufliste kopieren' }).click();
  await expect(page.locator('[popover]').getByText('Kopiert.')).toBeVisible();
  expect(await page.evaluate(() => navigator.clipboard.readText())).toBe(LONG_STACK);

  // Mehrere zugleich offen. Mit der Tastatur: Fokus auf die Zeile, Eingabe klappt auf.
  const deviceTest = mine.nth(1);
  await deviceTest.focus();
  await page.keyboard.press('Enter');
  await expect(deviceTest).toHaveAttribute('aria-expanded', 'true');
  await expect(error).toHaveAttribute('aria-expanded', 'true');
  const testContent = await contentOf(page, deviceTest);
  await expect(testContent.getByRole('listitem')).toHaveCount(2);
  await expect(testContent.getByRole('listitem').nth(0)).toContainText('Drucker');
  await expect(testContent.getByRole('listitem').nth(0)).toContainText('in Ordnung');
  await expect(testContent.getByRole('listitem').nth(0)).toContainText('Testbon gedruckt.');
  await expect(testContent.getByRole('listitem').nth(1)).toContainText('Geldlade');
  await expect(testContent.getByRole('listitem').nth(1)).toContainText('nicht in Ordnung');
  await expect(testContent.getByRole('listitem').nth(1)).toContainText('Die Lade hat sich nicht geöffnet.');

  const server = mine.nth(0);
  await server.press('Space');
  await expect(server).toHaveAttribute('aria-expanded', 'true');
  const serverContent = await contentOf(page, server);
  await expect(serverContent).toContainText('Summen eines Bons passen nicht');
  const json = await serverContent.locator('pre').textContent();
  expect(JSON.parse(json ?? '')).toEqual({ receiptId: broken.id, number: broken.number, problems: ['goods_plus_deposit', 'payment'] });
  expect(json).toContain('\n  "receiptId"');

  // Nochmal antippen klappt zu.
  await error.click();
  await expect(error).toHaveAttribute('aria-expanded', 'false');
  await expect(page.locator(`[id="${await error.getAttribute('aria-controls')}"]`)).toHaveCount(0);
});

test('Chef kommt über die Adresse nicht auf die Seite, der Server antwortet 404', async ({ page }) => {
  const site = await createSite(page, { name: `Imbiss mit Chef ${tag()}`, owner: true });
  await page.context().clearCookies();
  const login = await page.request.post('/api/auth/login', { headers: { 'X-Kassa-Request': '1' }, data: site.owner });
  expect(login.ok()).toBe(true);
  expect((await page.request.get('/api/admin/reports')).status()).toBe(404);
  expect((await page.request.get('/api/admin/backups/latest')).status()).toBe(404);

  const asked: string[] = [];
  page.on('request', (req) => {
    if (/\/api\/admin\/(reports|backups)/.test(req.url())) asked.push(req.url());
  });
  // Kein kurzes Aufblitzen: ein Beobachter merkt sich, ob der Titel der Seite je im Dokument stand.
  await page.addInitScript(() => {
    new MutationObserver(() => {
      if ([...document.querySelectorAll('h1')].some((h) => h.textContent === 'Fehlerberichte')) {
        (window as { __flash?: boolean }).__flash = true;
      }
    }).observe(document, { childList: true, subtree: true, characterData: true });
  });
  await page.goto('/fehlerberichte');
  await expect(page).toHaveURL(new RegExp(`/b/${site.businessId}/umsaetze$`));
  await expect(page.getByRole('heading', { level: 1, name: 'Umsätze' })).toBeVisible();
  expect(await page.evaluate(() => (window as { __flash?: boolean }).__flash)).toBeUndefined();
  expect(asked).toEqual([]);
  await expect(page.getByRole('link', { name: 'Fehlerberichte' })).toHaveCount(0);
});

/** Beantwortet die Frage nach dem Stand der Sicherung mit `body`. */
async function backupAnswer(page: Page, body: object | null, status = 200) {
  await page.route('**/api/admin/backups/latest', (route) => route.fulfill({ status, json: body }));
}

test('Sicherung: noch keine, heute, älter als 36 Stunden mit letztem Fehler', async ({ page }) => {
  const today = startOfLocalDay(new Date()).getTime();
  const at = (ms: number) => new Date(today + ms).toISOString();

  await backupAnswer(page, { latest: null, lastError: null });
  await page.goto('/fehlerberichte');
  await expect(backupCard(page)).toContainText('Noch keine Sicherung.');
  await expect(backupCard(page)).not.toContainText('Letzter Fehler');

  await page.unroute('**/api/admin/backups/latest');
  await backupAnswer(page, { latest: { day: 'x', finishedAt: at(3 * HOUR + 12 * 60_000), size: 25_270_000 }, lastError: null });
  await page.reload();
  await expect(backupCard(page).getByText('Letzte Sicherung: heute, 03:12')).toBeVisible();
  await expect(backupCard(page)).toContainText('24,1 MB');
  await expect(backupCard(page)).not.toContainText('36 Stunden');

  await page.unroute('**/api/admin/backups/latest');
  await backupAnswer(page, {
    latest: { day: 'x', finishedAt: at(-2 * 24 * HOUR + 3 * HOUR + 12 * 60_000), size: 25_270_000 },
    lastError: { at: at(4 * HOUR), error: 'pg_dump: Verbindung abgelehnt <b>fett</b>' },
  });
  await page.reload();
  await expect(backupCard(page).getByText(/^Letzte Sicherung: \w{2}\., \d{2}\.\d{2}\., 03:12$/)).toBeVisible();
  await expect(backupCard(page).getByText('Die letzte Sicherung ist älter als 36 Stunden.')).toBeVisible();
  await expect(backupCard(page).getByText('Letzter Fehler: heute, 04:00')).toBeVisible();
  await expect(backupCard(page).getByText('pg_dump: Verbindung abgelehnt <b>fett</b>')).toBeVisible();
  await expect(backupCard(page).locator('b')).toHaveCount(0);
});

test('Sicherung und Liste laden und scheitern jede für sich', async ({ page }) => {
  // Beide Antworten gehalten: zwei eigene Platzhalter.
  const held: Route[] = [];
  await page.route('**/api/admin/backups/latest', (route) => void held.push(route));
  await page.route('**/api/admin/reports', (route) => void held.push(route));
  await page.goto('/fehlerberichte');
  await expect(page.getByRole('status').filter({ hasText: 'Sicherung wird geladen' })).toBeVisible();
  await expect(page.getByRole('status').filter({ hasText: 'Berichte werden geladen' })).toBeVisible();
  await expect.poll(() => held.length).toBe(2);
  for (const r of held) await r.fallback();
  await page.unroute('**/api/admin/backups/latest');
  await page.unroute('**/api/admin/reports');

  // Die Sicherung scheitert, die Liste steht.
  await page.route('**/api/admin/backups/latest', (route) => route.fulfill({ status: 409, json: CONFLICT }));
  await page.reload();
  await expect(backupCard(page).getByText('Der Stand der Sicherung konnte nicht geladen werden.')).toBeVisible();
  await expect(reportRows(page).first()).toBeVisible();
  await page.unroute('**/api/admin/backups/latest');
  await backupCard(page).getByRole('button', { name: 'Nochmal versuchen' }).click();
  await expect(backupCard(page).getByText('Der Stand der Sicherung konnte nicht geladen werden.')).toHaveCount(0);

  // Die Liste scheitert, die Sicherung steht.
  await backupAnswer(page, { latest: null, lastError: null });
  await page.route('**/api/admin/reports', (route) => route.fulfill({ status: 409, json: CONFLICT }));
  await page.reload();
  await expect(page.getByText('Das konnte nicht geladen werden')).toBeVisible();
  await expect(backupCard(page)).toContainText('Noch keine Sicherung.');
});

test('keine Berichte: "Keine Berichte. Das ist gut."', async ({ page }) => {
  await page.route('**/api/admin/reports', (route) => route.fulfill({ json: { reports: [], next: null } }));
  await page.goto('/fehlerberichte');
  await expect(page.getByText('Keine Berichte. Das ist gut.')).toBeVisible();
  await expect(reportRows(page)).toHaveCount(0);
  await expect(backupCard(page)).toBeVisible();
});

test('Mehr laden hängt an, ein Fehler behält die Zeilen und bietet "Nochmal versuchen"', async ({ page }) => {
  const t = tag();
  // Höchstens 50 Berichte pro Kassa und Tag: zwei Betriebe.
  for (const [name, n] of [[`Imbiss Viel ${t}`, 30], [`Imbiss Mehr ${t}`, 25]] as const) {
    const site = await createSite(page, { name });
    await pushEntries(page, site, Array.from({ length: n }, () => ({ kind: 'report', report: errorReport() })));
  }
  await page.goto('/fehlerberichte');
  await expect(reportRows(page)).toHaveCount(50);
  await expect(reportRows(page, t)).toHaveCount(50);

  let fail = true;
  await page.route('**/api/admin/reports?before=*', async (route) => {
    if (fail) await route.fulfill({ status: 409, json: CONFLICT });
    else await route.fallback();
  });
  await page.getByRole('button', { name: 'Mehr laden' }).click();
  await expect(page.getByText('Weitere Berichte konnten nicht geladen werden.')).toBeVisible();
  await expect(reportRows(page)).toHaveCount(50);

  fail = false;
  await page.getByRole('button', { name: 'Nochmal versuchen' }).click();
  await expect(reportRows(page, t)).toHaveCount(55);
});

test('360 px: kein waagrechtes Scrollen, Ziele mindestens 44 px', async ({ page }) => {
  const { t } = await seedTwoBusinesses(page);
  await page.setViewportSize({ width: 360, height: 780 });
  await page.goto('/fehlerberichte');
  const mine = reportRows(page, t);
  await expect(mine).toHaveCount(3);
  await noHorizontalScroll(page, 'Liste');
  for (let i = 0; i < 3; i++) await mine.nth(i).click();
  await noHorizontalScroll(page, 'alle offen');
  const targets = [mine.nth(0), mine.nth(1), mine.nth(2), page.getByRole('button', { name: 'Aufrufliste kopieren' }), page.getByRole('button', { name: 'Inhalt kopieren' })];
  for (const target of targets) {
    const b = (await target.boundingBox())!;
    expect(b.height).toBeGreaterThanOrEqual(44);
    expect(b.width).toBeGreaterThanOrEqual(44);
  }
  // Zeit, Betrieb, Kassa, Art und Version bleiben in der Zeile, nichts läuft hinaus.
  const row = await mine.nth(2).evaluate((el) => {
    const r = el.getBoundingClientRect();
    return [...el.querySelectorAll('*')].every((c) => {
      const b = c.getBoundingClientRect();
      return b.width === 0 || (b.left >= r.left - 0.5 && b.right <= r.right + 0.5);
    });
  });
  expect(row).toBe(true);
});

test('ein spät gesendeter Bericht von gestern steht nach Eingang, mit eigener Überschrift', async ({ page }) => {
  const report = (id: string, at: Date) => ({
    id,
    businessName: 'Imbiss Spät',
    registerName: null,
    source: 'device',
    kind: 'error',
    at: at.toISOString(),
    appVersion: '1.5.0',
    deviceModel: 'Redmi Pad Pro',
    count: 1,
    content: { error: { type: 'StateError', message: null, stack: '#0 main' }, devices: null },
  });
  const today = startOfLocalDay(new Date()).getTime();
  await page.route('**/api/admin/reports', (route) =>
    route.fulfill({
      json: {
        reports: [
          report('00000000-0000-4000-8000-000000000001', new Date(today + 60_000)),
          report('00000000-0000-4000-8000-000000000002', new Date(today - 2 * HOUR)),
          report('00000000-0000-4000-8000-000000000003', new Date(today + 30_000)),
        ],
        next: null,
      },
    }),
  );
  await page.goto('/fehlerberichte');
  await expect(page.getByRole('heading', { level: 2 }).filter({ hasNotText: 'Sicherung' })).toHaveText(['Heute', 'Gestern', 'Heute']);
  await expect(reportRows(page).first()).toContainText('Imbiss Spät · ohne Kassa');
  // Ohne Meldung keine Zeile "Meldung".
  await reportRows(page).first().click();
  await expect(await contentOf(page, reportRows(page).first())).not.toContainText('Meldung');
});
