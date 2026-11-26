import type { Page } from '@playwright/test';
import { expect, signInAsProvider, test } from './support/fixtures';
import { createSite } from './support/seed';

const HEADERS = { 'X-Kassa-Request': '1' };
const SYNC_HINT = 'Kommt beim nächsten Abgleich an die Kassa.';

/** Die Beispiel-Speisekarte hat 11 Namen: 2 Kategorien, 3 Artikel und "5 Stück", 2 Gruppen mit 3 Optionen. */
const TOTAL = 11;

type Values = Partial<Record<'en' | 'zh' | 'tr' | 'ar', string>>;
type Wire = { sections: { title: string; rows: { source: string; values: Values }[] }[]; total: number; done: Record<string, number> };

async function serverValues(page: Page, b: string, source: string): Promise<Values | undefined> {
  const res = await page.request.get(`/api/admin/businesses/${b}/translations`);
  const body = (await res.json()) as Wire;
  return body.sections.flatMap((s) => s.rows).find((r) => r.source === source)?.values;
}

async function newBusiness(page: Page, opts: { owner?: boolean } = {}) {
  return createSite(page, { name: 'Imbiss der Sprachen', ...opts });
}

const field = (page: Page, source: string, language: string) => page.getByRole('textbox', { name: `${source}: ${language}`, exact: true });
const progress = (page: Page) => page.getByTestId('translation-progress');
const toast = (page: Page) => page.locator('[popover]');
const language = (page: Page, name: string) => page.getByRole('radiogroup', { name: 'Sprache' }).getByRole('radio', { name });

async function noHorizontalScroll(page: Page): Promise<void> {
  const { scrollWidth, clientWidth } = await page.evaluate(() => ({
    scrollWidth: document.documentElement.scrollWidth,
    clientWidth: document.documentElement.clientWidth,
  }));
  expect(scrollWidth).toBeLessThanOrEqual(clientWidth);
}

test.beforeEach(async ({ page }) => {
  await signInAsProvider(page);
});

test('füllen, verlassen, neu laden: der Text steht da und der Stand zählt eins mehr; leeren löscht', async ({ page }) => {
  const { businessId: b } = await newBusiness(page);
  await page.goto(`/b/${b}/uebersetzungen`);
  await expect(page.getByRole('heading', { level: 1, name: 'Übersetzungen' })).toBeVisible();
  await expect(language(page, 'English')).toBeChecked();
  await expect(progress(page)).toHaveText(`0 von ${TOTAL} übersetzt`);

  // Gegliedert wie die Speisekarte, jeder Name einmal, der Name als Platzhalter.
  await expect(page.getByRole('heading', { level: 2 })).toHaveText(['Kategorien', 'Bowls', 'Getränke', 'Auswahl und Extras']);
  await expect(page.getByRole('list', { name: 'Bowls' }).getByRole('listitem')).toHaveCount(3);
  const huhn = field(page, 'Huhn Bowl', 'English');
  await expect(huhn).toHaveAttribute('placeholder', 'Huhn Bowl');
  await expect(huhn).toHaveAttribute('lang', 'en');
  await expect(huhn).toHaveAttribute('dir', 'ltr');
  await expect(page.getByRole('list', { name: 'Bowls' }).getByRole('listitem').first()).toContainText('fehlt');

  await huhn.fill('  Chicken bowl ');
  await huhn.blur();
  await expect(huhn).toHaveValue('Chicken bowl');
  await expect(progress(page)).toHaveText(`1 von ${TOTAL} übersetzt`);
  await expect(page.getByRole('list', { name: 'Bowls' }).getByRole('listitem').first()).not.toContainText('fehlt');
  await expect(toast(page).getByText(SYNC_HINT)).toBeVisible();
  await expect.poll(() => serverValues(page, b, 'Huhn Bowl')).toEqual({ en: 'Chicken bowl' });

  // Enter speichert ebenso und bleibt im Feld; Tab geht zum nächsten Feld darunter.
  const teig = field(page, 'Teigtaschen', 'English');
  await teig.fill('Dumplings');
  await page.keyboard.press('Enter');
  await expect(teig).toBeFocused();
  await expect(progress(page)).toHaveText(`2 von ${TOTAL} übersetzt`);
  await page.keyboard.press('Tab');
  await expect(field(page, '5 Stück', 'English')).toBeFocused();
  await expect.poll(() => serverValues(page, b, 'Teigtaschen')).toEqual({ en: 'Dumplings' });

  await page.reload();
  await expect(field(page, 'Huhn Bowl', 'English')).toHaveValue('Chicken bowl');
  await expect(field(page, 'Teigtaschen', 'English')).toHaveValue('Dumplings');
  await expect(progress(page)).toHaveText(`2 von ${TOTAL} übersetzt`);

  // Leeren löscht die Übersetzung; der Name gilt wieder.
  await field(page, 'Huhn Bowl', 'English').fill('');
  await field(page, 'Huhn Bowl', 'English').blur();
  await expect(progress(page)).toHaveText(`1 von ${TOTAL} übersetzt`);
  await expect.poll(() => serverValues(page, b, 'Huhn Bowl')).toEqual({});
  await page.reload();
  await expect(field(page, 'Huhn Bowl', 'English')).toHaveValue('');
  await expect(progress(page)).toHaveText(`1 von ${TOTAL} übersetzt`);
});

test('Sprachen: jede mit eigenem Feld, Arabisch von rechts nach links, die Wahl bleibt nach dem Neuladen', async ({ page }) => {
  const { businessId: b } = await newBusiness(page);
  await page.goto(`/b/${b}/uebersetzungen`);
  await expect(page.getByRole('radiogroup', { name: 'Sprache' }).getByRole('radio')).toHaveCount(4);
  for (const name of ['English', '中文', 'Türkçe', 'العربية']) await expect(language(page, name)).toBeVisible();

  await language(page, 'العربية').check();
  const cola = field(page, 'Cola 0,33 l', 'العربية');
  await expect(cola).toHaveAttribute('dir', 'rtl');
  await expect(cola).toHaveAttribute('lang', 'ar');
  await cola.fill('كولا');
  await cola.blur();
  await expect(progress(page)).toHaveText(`1 von ${TOTAL} übersetzt`);

  await language(page, '中文').check();
  await expect(field(page, 'Cola 0,33 l', '中文')).toHaveAttribute('lang', 'zh-Hans');
  await expect(field(page, 'Cola 0,33 l', '中文')).toHaveValue('');
  await expect(progress(page)).toHaveText(`0 von ${TOTAL} übersetzt`);
  await expect.poll(() => serverValues(page, b, 'Cola 0,33 l')).toEqual({ ar: 'كولا' });

  await language(page, 'العربية').check();
  await page.reload();
  await expect(language(page, 'العربية')).toBeChecked();
  await expect(field(page, 'Cola 0,33 l', 'العربية')).toHaveValue('كولا');
});

test('"Nur fehlende" blendet übersetzte Namen aus; eben übersetzte bleiben stehen, bis der Filter neu angeht', async ({ page }) => {
  const { businessId: b } = await newBusiness(page);
  const put = await page.request.put(`/api/admin/businesses/${b}/translations`, {
    headers: HEADERS,
    data: { source: 'Getränke', lang: 'en', value: 'Drinks' },
  });
  expect(put.ok(), await put.text()).toBe(true);
  await page.goto(`/b/${b}/uebersetzungen`);
  await expect(field(page, 'Getränke', 'English')).toHaveValue('Drinks');

  await page.getByRole('switch', { name: 'Nur fehlende' }).check();
  await expect(field(page, 'Getränke', 'English')).toHaveCount(0);
  await expect(field(page, 'Bowls', 'English')).toBeVisible();

  await field(page, 'Bowls', 'English').fill('Bowls');
  await field(page, 'Bowls', 'English').blur();
  await expect(field(page, 'Cola 0,33 l', 'English')).toBeVisible();
  await field(page, 'Cola 0,33 l', 'English').fill('Coke 0.33 l');
  await page.keyboard.press('Tab');
  // Gerade übersetzt: die Zeile bleibt, der Fokus geht weiter, nichts springt weg.
  await expect(field(page, 'Cola 0,33 l', 'English')).toHaveValue('Coke 0.33 l');
  await expect(progress(page)).toHaveText(`3 von ${TOTAL} übersetzt`);

  await page.getByRole('switch', { name: 'Nur fehlende' }).uncheck();
  await page.getByRole('switch', { name: 'Nur fehlende' }).check();
  await expect(field(page, 'Cola 0,33 l', 'English')).toHaveCount(0);
  // "Bowls" gleich dem Namen ist eine Übersetzung: die Zeile fehlt nicht mehr.
  await expect(field(page, 'Bowls', 'English')).toHaveCount(0);
  await expect(page.getByRole('heading', { level: 2, name: 'Getränke' })).toHaveCount(0);
});

test('Speichern scheitert: der alte Text kommt zurück, der Hinweis nennt den Grund', async ({ page }) => {
  const { businessId: b } = await newBusiness(page);
  await page.goto(`/b/${b}/uebersetzungen`);
  await field(page, 'Teriyaki', 'English').fill('Teriyaki sauce');
  await field(page, 'Teriyaki', 'English').blur();
  await expect(progress(page)).toHaveText(`1 von ${TOTAL} übersetzt`);
  await expect.poll(() => serverValues(page, b, 'Teriyaki')).toEqual({ en: 'Teriyaki sauce' });

  await page.route('**/translations', (route) =>
    route.request().method() === 'PUT'
      ? route.fulfill({ status: 422, contentType: 'application/json', body: JSON.stringify({ error: { code: 'internal', message: 'Gerade nicht gespeichert.' } }) })
      : route.fallback(),
  );
  await field(page, 'Teriyaki', 'English').fill('');
  await field(page, 'Teriyaki', 'English').blur();
  await expect(toast(page).getByText('Gerade nicht gespeichert.')).toBeVisible();
  await expect(field(page, 'Teriyaki', 'English')).toHaveValue('Teriyaki sauce');
  await expect(progress(page)).toHaveText(`1 von ${TOTAL} übersetzt`);
});

test('Übersetzungen einspielen: Fehler als Liste, dann eine gute Datei mit "N Namen übersetzt."', async ({ page }) => {
  const { businessId: b } = await newBusiness(page);
  await page.goto(`/b/${b}/uebersetzungen`);
  await page.getByRole('button', { name: 'Übersetzungen einspielen' }).click();
  const dialog = page.getByRole('dialog', { name: 'Übersetzungen einspielen' });
  const input = dialog.locator('input[type=file]');

  await input.setInputFiles({
    name: 'falsch.json',
    mimeType: 'application/json',
    buffer: Buffer.from(JSON.stringify({ uebersetzungen: { 'Gibt es nicht': { tr: 'Yok' }, Bowls: { tr: 'Kâseler' } } })),
  });
  await dialog.getByRole('button', { name: 'Einspielen' }).click();
  const alert = dialog.getByRole('alert');
  await expect(alert).toContainText('Die Datei hat 1 Problem');
  await expect(alert.getByRole('listitem')).toHaveText(['Übersetzung "Gibt es nicht": Diesen Namen gibt es in der Speisekarte nicht.']);
  expect(await serverValues(page, b, 'Bowls')).toEqual({});

  await input.setInputFiles({
    name: 'tuerkisch.json',
    mimeType: 'application/json',
    buffer: Buffer.from(JSON.stringify({ uebersetzungen: { Bowls: { tr: 'Kâseler' }, Größe: { tr: 'Boy', en: 'Size' } } })),
  });
  await expect(alert).toHaveCount(0);
  await dialog.getByRole('button', { name: 'Einspielen' }).click();
  await expect(dialog).toHaveCount(0);
  await expect(toast(page).getByText('2 Namen übersetzt.')).toBeVisible();
  // Die Seite zeigt den neuen Stand gleich.
  await expect(field(page, 'Größe', 'English')).toHaveValue('Size');
  await expect(progress(page)).toHaveText(`1 von ${TOTAL} übersetzt`);
  await language(page, 'Türkçe').check();
  await expect(field(page, 'Bowls', 'Türkçe')).toHaveValue('Kâseler');
  await expect(progress(page)).toHaveText(`2 von ${TOTAL} übersetzt`);
});

test('Chef: übersetzen ja, einspielen nein; die Seite steht in der Navigation nach "Speisekarte"', async ({ page }) => {
  const site = await newBusiness(page, { owner: true });
  await page.context().clearCookies();
  const login = await page.request.post('/api/auth/login', { headers: HEADERS, data: site.owner });
  expect(login.ok(), await login.text()).toBe(true);

  await page.goto(`/b/${site.businessId}/speisekarte`);
  const nav = page.getByRole('navigation', { name: 'Bereiche' }).first();
  await expect(nav.getByRole('link', { name: 'Übersetzungen' })).toBeVisible();
  const labels = await nav.getByRole('link').allTextContents();
  expect(labels.indexOf('Übersetzungen')).toBe(labels.indexOf('Speisekarte') + 1);
  await nav.getByRole('link', { name: 'Übersetzungen' }).click();
  await expect(page).toHaveURL(new RegExp(`/b/${site.businessId}/uebersetzungen$`));
  await expect(page.getByRole('heading', { level: 1, name: 'Übersetzungen' })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Übersetzungen einspielen' })).toHaveCount(0);

  await field(page, 'Normal', 'English').fill('Regular');
  await page.keyboard.press('Enter');
  await expect.poll(() => serverValues(page, site.businessId, 'Normal')).toEqual({ en: 'Regular' });
});

test.describe('Handy', () => {
  test.use({ viewport: { width: 390, height: 844 } });

  test('Name über dem Feld, ohne seitliches Scrollen', async ({ page }) => {
    const { businessId: b } = await newBusiness(page);
    await page.goto(`/b/${b}/uebersetzungen`);
    const huhn = field(page, 'Huhn Bowl', 'English');
    await expect(huhn).toBeVisible();
    const row = page.getByRole('list', { name: 'Bowls' }).getByRole('listitem').first();
    const name = await row.getByText('Huhn Bowl', { exact: true }).boundingBox();
    const box = await huhn.boundingBox();
    expect(box!.y).toBeGreaterThanOrEqual(name!.y + name!.height);
    expect(box!.height).toBeGreaterThanOrEqual(44);
    await noHorizontalScroll(page);
  });
});
