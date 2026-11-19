import type { Locator, Page } from '@playwright/test';
import { expect, signInAsProvider, test } from './support/fixtures';
import { createSite, earlierToday, line, MENU, pushEntries, saleReceipt, type Site } from './support/seed';

const NBSP = ' ';
const eur = (text: string) => `${text}${NBSP}€`;
const DAY = 24 * 60 * 60_000;

/** "19.11." für einen Zeitpunkt, in Wiener Zeit, so wie der Server die Tage beschriftet. */
function dayLabel(at: Date): string {
  const parts = new Intl.DateTimeFormat('de-AT', { timeZone: 'Europe/Vienna', day: 'numeric', month: 'numeric' }).formatToParts(at);
  const get = (type: string) => Number(parts.find((p) => p.type === type)!.value);
  return `${get('day')}.${get('month')}.`;
}

/**
 * Drei Bons von heute (32,15 Euro, bar 22,50, Karte 9,65, Cola fünfmal) und einer von vor zwei Tagen (9,90 bar).
 * Der alte Bon liegt sicher in den letzten 7 Tagen und nie in "heute".
 */
async function seedFourReceipts(page: Page, site: Site): Promise<void> {
  const now = new Date();
  const [first, second, third] = earlierToday(3, now);
  await pushEntries(page, site, [
    { kind: 'receipt', receipt: saleReceipt({ createdAt: first, lines: [line(MENU.cola, 2), line(MENU.huhnBowl)] }) },
    { kind: 'receipt', receipt: saleReceipt({ createdAt: second, payment: 'card', lines: [line(MENU.teigtaschen), line(MENU.cola)] }) },
    { kind: 'receipt', receipt: saleReceipt({ createdAt: third, lines: [line(MENU.cola, 2)] }) },
    { kind: 'receipt', receipt: saleReceipt({ createdAt: new Date(now.getTime() - 2 * DAY), lines: [line(MENU.huhnBowl)] }) },
  ]);
}

function range(page: Page, label: string): Locator {
  return page.getByRole('radiogroup', { name: 'Zeitraum' }).getByRole('radio', { name: label });
}

function bars(page: Page): Locator {
  return page.getByRole('group', { name: /^Umsatz pro (Stunde|Tag)$/ }).getByRole('button');
}

async function noHorizontalScroll(page: Page, what: string): Promise<void> {
  const { scrollWidth, clientWidth } = await page.evaluate(() => ({
    scrollWidth: document.documentElement.scrollWidth,
    clientWidth: document.documentElement.clientWidth,
  }));
  expect(scrollWidth, what).toBeLessThanOrEqual(clientWidth);
}

test.beforeEach(async ({ page }) => {
  await signInAsProvider(page);
});

test('Betrieb ohne Bons: Umsätze sind die erste Seite und zeigen den leeren Zustand', async ({ page }) => {
  const site = await createSite(page, { name: 'Imbiss ohne Bons' });
  await page.goto(`/b/${site.businessId}`);
  await expect(page).toHaveURL(new RegExp(`/b/${site.businessId}/umsaetze$`));
  await expect(page.getByRole('heading', { level: 1, name: 'Umsätze' })).toBeVisible();
  await expect(page.getByText('Imbiss ohne Bons').first()).toBeVisible();
  await expect(page.getByText('Noch kein Bon.')).toBeVisible();
  await expect(page.getByText('Sobald an der Kassa boniert wird, erscheinen die Umsätze hier.')).toBeVisible();
  await expect(range(page, 'Heute')).toBeChecked();
  await expect(page.getByText('Testbetrieb: Alle Bons sind Testbons.')).toHaveCount(0);

  const nav = page.getByRole('navigation', { name: 'Bereiche' }).first();
  await expect(nav.getByRole('link').nth(1)).toHaveText('Umsätze');
  await expect(nav.getByRole('link', { name: 'Umsätze' })).toHaveAttribute('aria-current', 'page');
});

test('drei Bons: Umsatz, Bons, bar und Karte, meistverkauft; Wechsel auf 7 Tage bleibt in der Adresse', async ({ page }) => {
  const site = await createSite(page, { name: 'Imbiss am Markt' });
  await seedFourReceipts(page, site);
  await page.goto(`/b/${site.businessId}/umsaetze`);

  await expect(page.getByTestId('revenue')).toHaveText(eur('32,15'));
  await expect(page.getByTestId('receipt-count')).toHaveText('3');
  await expect(page.getByTestId('void-count')).toHaveText('0');
  await expect(page.getByText('Testbetrieb: Alle Bons sind Testbons.')).toBeVisible();
  await expect(page.getByTestId('cash')).toHaveText(eur('22,50'));
  await expect(page.getByTestId('cash-share')).toHaveText('70 %');
  await expect(page.getByTestId('card')).toHaveText(eur('9,65'));
  await expect(page.getByTestId('card-share')).toHaveText('30 %');

  const top = page.getByRole('list', { name: 'Meistverkauft' }).getByRole('listitem');
  await expect(top.first()).toContainText('Cola 0,33 l');
  await expect(top.first()).toContainText('5 Stück');
  await expect(top.first()).toContainText(eur('14,50'));
  const categories = page.getByRole('list', { name: 'Umsatz nach Kategorie' }).getByRole('listitem');
  await expect(categories).toHaveText([/Bowls.*16,40/, /Getränke.*14,50/, /Pfand.*1,25/]);

  // Heute: ein Balken pro Stunde seit dem ersten Bon, jeder mit Zeit und Betrag als Name.
  await expect(bars(page).first()).toHaveAccessibleName(/^\d{1,2} Uhr: [\d.]+,\d\d €$/);

  await range(page, '7 Tage').check();
  await expect(page).toHaveURL(/\?zeit=7$/);
  await expect(page.getByTestId('revenue')).toHaveText(eur('42,05'));
  await expect(page.getByTestId('receipt-count')).toHaveText('4');
  await expect(bars(page)).toHaveCount(7);
  await expect(bars(page).last()).toHaveAccessibleName(`${dayLabel(new Date())}: ${eur('32,15')}`);

  // Mit der Tastatur: ein Tab-Halt im Diagramm, Pfeile und Ende wandern über die Balken.
  await bars(page).first().focus();
  await page.keyboard.press('End');
  await expect(bars(page).last()).toBeFocused();
  await expect(page.getByTestId('bar-readout')).toHaveText(`${dayLabel(new Date())} ${eur('32,15')}`);
  await page.keyboard.press('ArrowLeft');
  await expect(bars(page).nth(5)).toBeFocused();

  await page.reload();
  await expect(range(page, '7 Tage')).toBeChecked();
  await expect(page.getByTestId('revenue')).toHaveText(eur('42,05'));

  await range(page, 'Heute').check();
  await expect(page).toHaveURL(new RegExp(`/umsaetze$`));
  await expect(page.getByTestId('revenue')).toHaveText(eur('32,15'));
});

test('beim Wechsel bleiben die alten Zahlen stehen, ein Fehler beim stillen Nachladen auch', async ({ page }) => {
  const site = await createSite(page, { name: 'Imbiss am Bahnhof' });
  await seedFourReceipts(page, site);
  await page.clock.install();
  await page.goto(`/b/${site.businessId}/umsaetze`);
  await expect(page.getByTestId('revenue')).toHaveText(eur('32,15'));

  let release: () => void = () => undefined;
  const held = new Promise<void>((r) => (release = r));
  await page.route('**/overview?range=days30', async (route) => {
    await held;
    await route.continue();
  });
  await range(page, '30 Tage').check();
  await expect(range(page, '30 Tage')).toBeChecked();
  await expect(page.getByTestId('revenue')).toHaveText(eur('32,15'));
  await expect(page.getByRole('status').filter({ hasText: 'Umsätze werden geladen' })).toHaveCount(0);
  release();
  await expect(page.getByTestId('revenue')).toHaveText(eur('42,05'));
  await page.unroute('**/overview?range=days30');

  // Nach 60 Sekunden lädt die Seite still nach. Scheitert das, bleiben die Zahlen stehen.
  await page.route('**/overview?range=days30', (route) =>
    // Eine Antwort mit Fehler (4xx meldet Chromium, die Prüfung nach dem Test lässt sie durch).
    route.fulfill({ status: 409, json: { error: { code: 'conflict', message: 'Das hat nicht geklappt. Bitte nochmal versuchen.' } } }),
  );
  const refresh = page.waitForRequest('**/overview?range=days30');
  await page.clock.runFor(61_000);
  await refresh;
  await expect(page.getByTestId('revenue')).toHaveText(eur('42,05'));
  await expect(page.getByRole('button', { name: 'Nochmal versuchen' })).toHaveCount(0);
});

test('bei 360 px kein waagrechtes Scrollen, auch mit 30 Balken', async ({ page }) => {
  const site = await createSite(page, { name: 'Imbiss mit einem ziemlich langen Namen am Hauptplatz' });
  await seedFourReceipts(page, site);
  await page.setViewportSize({ width: 360, height: 800 });
  for (const [query, revenue] of [['', '32,15'], ['?zeit=7', '42,05'], ['?zeit=30', '42,05']] as const) {
    await page.goto(`/b/${site.businessId}/umsaetze${query}`);
    await expect(page.getByTestId('revenue')).toHaveText(eur(revenue));
    await noHorizontalScroll(page, `Umsätze${query} bei 360 px`);
  }
  await expect(bars(page)).toHaveCount(30);
});

test('ein Chef sieht die Umsätze seines Betriebs und keinen fremden', async ({ page }) => {
  const other = await createSite(page, { name: 'Fremder Imbiss' });
  const site = await createSite(page, { name: 'Imbiss der Chefin', owner: true });
  await seedFourReceipts(page, site);

  await page.context().clearCookies();
  const login = await page.request.post('/api/auth/login', { headers: { 'X-Kassa-Request': '1' }, data: site.owner });
  expect(login.ok(), await login.text()).toBe(true);

  await page.goto('/');
  await expect(page).toHaveURL(new RegExp(`/b/${site.businessId}/umsaetze$`));
  await expect(page.getByText('Imbiss der Chefin').first()).toBeVisible();
  await expect(page.getByTestId('revenue')).toHaveText(eur('32,15'));
  const nav = page.getByRole('navigation', { name: 'Bereiche' }).first();
  await expect(nav.getByRole('link').first()).toHaveText('Umsätze');
  await expect(nav.getByRole('link', { name: 'Alle Betriebe' })).toHaveCount(0);

  await page.goto(`/b/${other.businessId}/umsaetze`);
  await expect(page.getByText('Diesen Betrieb gibt es nicht.')).toBeVisible();
  await expect(page.getByTestId('revenue')).toHaveCount(0);
});
