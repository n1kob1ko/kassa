import type { Locator, Page } from '@playwright/test';
import { expect, signInAsProvider, test } from './support/fixtures';
import { closeDay, createSite, earlierToday, line, MENU, openDay, pushEntries, saleReceipt, voidReceipt, type Site } from './support/seed';

const NBSP = ' ';
const eur = (text: string) => `${text}${NBSP}€`;
const NOT_FOUND = 'Diese Abrechnung gibt es nicht.';

// Monate rechnet der Server in der Zeit des Betriebs (Wien); der Browser steht in derselben Zeitzone.
test.use({ timezoneId: 'Europe/Vienna' });

test.beforeEach(async ({ page }) => {
  await signInAsProvider(page);
});

/** Der laufende Monat in Wien und die zwei davor, als 'JJJJ-MM'. Die Bons liegen relativ zur echten Uhr. */
function months(now = new Date()) {
  const [y, m] = new Intl.DateTimeFormat('en-CA', { timeZone: 'Europe/Vienna', year: 'numeric', month: '2-digit' })
    .format(now)
    .split('-')
    .map(Number) as [number, number];
  const key = (offset: number) => {
    const d = new Date(Date.UTC(y, m - 1 - offset, 1));
    return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, '0')}`;
  };
  return { current: key(0), previous: key(1), before: key(2) };
}

/** Mittag (Wien) am Tag `day` des Monats 'JJJJ-MM'. */
function noon(month: string, day: number): Date {
  const [y, m] = month.split('-').map(Number) as [number, number];
  return new Date(Date.UTC(y, m - 1, day, 10, 0));
}

function monthLabel(month: string): string {
  const [y, m] = month.split('-').map(Number) as [number, number];
  return `${new Intl.DateTimeFormat('de-AT', { month: 'long', timeZone: 'UTC' }).format(new Date(Date.UTC(y, m - 1, 1)))} ${y}`;
}

/**
 * Vorvormonat: ein Bon bar, 2 Huhn Bowl, 19,80 (10 %).
 * Vormonat am 10.: bar 1 Huhn Bowl und 2 Cola (16,20 mit 0,50 Pfand), Karte 1 Teigtaschen (6,50);
 * am 12.: bar 1 Cola (3,15) und sein Storno. Also 2 Bons, 22,70: bar 16,20 (1), Karte 6,50 (1), storniert 1 Bon 3,15,
 * 10 %: 16,40 brutto, 1,49 MwSt; 20 %: 5,80 brutto, 0,97 MwSt; Pfand 0,50.
 * Laufender Monat: ein Bon, der in keiner Abrechnung stehen darf.
 */
async function seedMonths(page: Page, site: Site) {
  const { previous, before } = months();
  const cola = saleReceipt({ createdAt: noon(previous, 12), lines: [line(MENU.cola)] });
  await pushEntries(page, site, [
    { kind: 'receipt', receipt: saleReceipt({ createdAt: noon(before, 15), lines: [line(MENU.huhnBowl, 2)] }) },
    { kind: 'receipt', receipt: saleReceipt({ createdAt: noon(previous, 10), lines: [line(MENU.huhnBowl), line(MENU.cola, 2)] }) },
    { kind: 'receipt', receipt: saleReceipt({ createdAt: noon(previous, 10), payment: 'card', lines: [line(MENU.teigtaschen)] }) },
    { kind: 'receipt', receipt: cola },
    { kind: 'receipt', receipt: voidReceipt(cola) },
    { kind: 'receipt', receipt: saleReceipt({ createdAt: earlierToday(1)[0], lines: [line(MENU.huhnBowl, 5)] }) },
  ]);
}

function monthRows(page: Page): Locator {
  return page.getByRole('main').getByRole('list', { name: 'Monate' }).getByRole('link');
}

function closingTabs(page: Page): Locator {
  return page.getByRole('navigation', { name: 'Abschlüsse' });
}

async function noHorizontalScroll(page: Page, what: string): Promise<void> {
  const { scrollWidth, clientWidth } = await page.evaluate(() => ({
    scrollWidth: document.documentElement.scrollWidth,
    clientWidth: document.documentElement.clientWidth,
  }));
  expect(scrollWidth, what).toBeLessThanOrEqual(clientWidth);
}

test('Abschlüsse: Tage und Monate, ein Monat mit Zahlen wie berechnet', async ({ page }) => {
  const site = await createSite(page, { name: 'Imbiss Monat' });
  await seedMonths(page, site);
  const { previous, before } = months();

  await page.goto(`/b/${site.businessId}/tage`);
  const side = page.getByRole('navigation', { name: 'Bereiche' });
  await expect(side.getByRole('link', { name: 'Abschlüsse' })).toHaveAttribute('aria-current', 'page');
  await expect(page.getByRole('heading', { level: 1, name: 'Abschlüsse' })).toBeVisible();
  await expect(closingTabs(page).getByRole('link', { name: 'Tage' })).toHaveAttribute('aria-current', 'page');

  await closingTabs(page).getByRole('link', { name: 'Monate' }).click();
  await expect(page).toHaveURL(new RegExp(`/b/${site.businessId}/monate$`));
  await expect(closingTabs(page).getByRole('link', { name: 'Monate' })).toHaveAttribute('aria-current', 'page');
  await expect(closingTabs(page).getByRole('link', { name: 'Tage' })).not.toHaveAttribute('aria-current', 'page');
  await expect(page.getByRole('heading', { level: 1, name: 'Abschlüsse' })).toBeVisible();
  await expect(side.getByRole('link', { name: 'Abschlüsse' })).toHaveAttribute('aria-current', 'page');

  const rows = monthRows(page);
  await expect(rows).toHaveCount(2);
  await expect(rows.first()).toContainText(monthLabel(previous));
  await expect(rows.first()).toContainText('2 Bons');
  await expect(rows.first()).toContainText(eur('22,70'));
  await expect(rows.nth(1)).toContainText(monthLabel(before));
  await expect(rows.nth(1)).toContainText('1 Bon');
  await expect(rows.nth(1)).toContainText(eur('19,80'));

  await rows.first().click();
  await expect(page).toHaveURL(new RegExp(`/b/${site.businessId}/monate/${previous}$`));
  const sheet = page.getByRole('dialog', { name: monthLabel(previous) });
  await expect(sheet).toBeVisible();
  const [y, m] = previous.split('-');
  await expect(sheet).toContainText(`01.${m}.${y} bis `);
  await expect(sheet).toContainText('Testbetrieb');
  await expect(sheet.getByTestId('cash')).toHaveText(eur('16,20'));
  await expect(sheet.getByTestId('cash-count')).toHaveText('1 Bon');
  await expect(sheet.getByTestId('card')).toHaveText(eur('6,50'));
  await expect(sheet.getByTestId('total')).toHaveText(eur('22,70'));
  await expect(sheet.getByTestId('total-count')).toHaveText('2 Bons');
  await expect(sheet.getByTestId('voided')).toHaveText(eur('3,15'));
  const tax = sheet.getByRole('table', { name: 'Steuer' });
  await expect(tax.getByRole('row', { name: /MwSt 20 %/ })).toContainText(eur('5,80'));
  await expect(tax.getByRole('row', { name: /MwSt 20 %/ })).toContainText(eur('0,97'));
  await expect(tax.getByRole('row', { name: /MwSt 10 %/ })).toContainText(eur('16,40'));
  await expect(tax.getByRole('row', { name: /MwSt 10 %/ })).toContainText(eur('1,49'));
  await expect(tax.getByRole('row', { name: /Pfand, ohne MwSt/ })).toContainText(eur('0,50'));
  const days = sheet.getByRole('list', { name: 'Tage' }).getByRole('listitem');
  await expect(days).toHaveCount(2);
  await expect(days.first()).toContainText(`, 10.${Number(m)}.`);
  await expect(days.first()).toContainText('2 Bons');
  await expect(days.first()).toContainText(eur('22,70'));
  await expect(days.nth(1)).toContainText('0 Bons');

  await page.evaluate(() => {
    (window as unknown as { printed: number }).printed = 0;
    window.print = () => {
      (window as unknown as { printed: number }).printed += 1;
    };
  });
  await sheet.getByRole('button', { name: 'Drucken' }).click();
  await expect.poll(() => page.evaluate(() => (window as unknown as { printed: number }).printed)).toBe(1);

  await page.keyboard.press('Escape');
  await expect(page).toHaveURL(new RegExp(`/b/${site.businessId}/monate$`));
  await expect(rows.first()).toBeFocused();
});

test('laufender Monat steht nicht in der Liste', async ({ page }) => {
  const site = await createSite(page);
  await seedMonths(page, site);
  const { current } = months();

  await page.goto(`/b/${site.businessId}/monate`);
  await expect(monthRows(page)).toHaveCount(2);
  await expect(page.getByRole('main')).not.toContainText(monthLabel(current));
  await expect(page.getByLabel('Von').locator('option', { hasText: monthLabel(current) })).toHaveCount(0);

  await page.goto(`/b/${site.businessId}/monate/${current}`);
  await expect(page.getByRole('dialog')).toContainText(NOT_FOUND);
});

test('leer: noch keine Monatsabrechnung, ab wann es die erste gibt', async ({ page }) => {
  const site = await createSite(page);
  await pushEntries(page, site, [{ kind: 'receipt', receipt: saleReceipt({ createdAt: earlierToday(1)[0], lines: [line(MENU.cola)] }) }]);
  const { current } = months();
  const [y, m] = current.split('-').map(Number) as [number, number];
  const next = new Date(Date.UTC(y, m, 1));

  await page.goto(`/b/${site.businessId}/monate`);
  await expect(page.getByRole('heading', { name: 'Noch keine Monatsabrechnung.' })).toBeVisible();
  await expect(page.getByText(`Die erste gibt es ab 1. ${new Intl.DateTimeFormat('de-AT', { month: 'long', timeZone: 'UTC' }).format(next)}.`)).toBeVisible();
  await expect(page.getByLabel('Von')).toHaveCount(0);
});

test('Von und Bis: Anzeigen öffnet den Zeitraum mit einer Zeile je Monat; Bis bietet nichts vor Von', async ({ page }) => {
  const site = await createSite(page);
  await seedMonths(page, site);
  const { previous, before } = months();

  await page.goto(`/b/${site.businessId}/monate`);
  const from = page.getByLabel('Von');
  const to = page.getByLabel('Bis');
  await expect(from.locator('option')).toHaveText([monthLabel(previous), monthLabel(before)]);

  await from.selectOption({ label: monthLabel(previous) });
  await expect(to.locator('option')).toHaveText([monthLabel(previous)]);

  await from.selectOption({ label: monthLabel(before) });
  await expect(to.locator('option')).toHaveText([monthLabel(previous), monthLabel(before)]);
  await to.selectOption({ label: monthLabel(previous) });
  await page.getByRole('button', { name: 'Anzeigen' }).click();

  await expect(page).toHaveURL(new RegExp(`/b/${site.businessId}/monate/${before}\\.\\.${previous}$`));
  const sheet = page.getByRole('dialog');
  await expect(sheet.getByRole('heading', { level: 2 })).toContainText(' bis ');
  await expect(sheet.getByTestId('total')).toHaveText(eur('42,50'));
  await expect(sheet.getByTestId('total-count')).toHaveText('3 Bons');
  await expect(sheet.getByRole('list', { name: 'Tage' })).toHaveCount(0);
  const rows = sheet.getByRole('list', { name: 'Monate' }).getByRole('listitem');
  await expect(rows).toHaveCount(2);
  await expect(rows.first()).toContainText(monthLabel(before));
  await expect(rows.first()).toContainText(eur('19,80'));
  await expect(rows.nth(1)).toContainText(monthLabel(previous));
  await expect(rows.nth(1)).toContainText(eur('22,70'));
});

test('Adresse von Hand: /monate/2026-13 und /monate/abc zeigen "Diese Abrechnung gibt es nicht."', async ({ page }) => {
  const site = await createSite(page);
  await seedMonths(page, site);
  const asked: string[] = [];
  page.on('request', (r) => {
    if (r.url().includes('/months/summary')) asked.push(r.url());
  });

  for (const id of ['2026-13', 'abc', '2026-10..2026-01']) {
    await page.goto(`/b/${site.businessId}/monate/${id}`);
    const sheet = page.getByRole('dialog');
    await expect(sheet).toContainText(NOT_FOUND);
    await expect(sheet.getByRole('button', { name: 'Drucken' })).toHaveCount(0);
  }
  await expect(monthRows(page)).toHaveCount(2);
  expect(asked).toEqual([]);

  // Ein gültiger Monat vor dem ersten Bon: der Server sagt 404.
  await page.goto(`/b/${site.businessId}/monate/2001-01`);
  await expect(page.getByRole('dialog')).toContainText(NOT_FOUND);
});

test('Druckansicht: nur das Blatt, Betrieb und Zeitraum oben, schwarz auf weiß auch im dunklen Modus', async ({ page }) => {
  const site = await createSite(page, { name: 'Imbiss Druck' });
  await seedMonths(page, site);
  const { previous } = months();

  await page.emulateMedia({ colorScheme: 'dark' });
  await page.goto(`/b/${site.businessId}/monate/${previous}`);
  const sheet = page.getByRole('dialog');
  await expect(sheet.getByTestId('total')).toHaveText(eur('22,70'));
  // Am Bildschirm stehen Kopf und Fuß des Drucks nicht.
  await expect(sheet.getByText(/^Erstellt am /)).toBeHidden();

  await page.emulateMedia({ media: 'print', colorScheme: 'dark' });
  const background = (sel: string) => page.locator(sel).first().evaluate((el) => getComputedStyle(el).backgroundColor);
  expect(await background('body')).toBe('rgb(255, 255, 255)');
  expect(await background('dialog')).toBe('rgb(255, 255, 255)');
  const ink = await sheet.getByTestId('total').evaluate((el) => getComputedStyle(el).color);
  expect(ink).toBe('rgb(20, 23, 26)');

  await expect(page.getByRole('navigation', { name: 'Bereiche' })).toBeHidden();
  await expect(page.getByRole('heading', { level: 1 })).toBeHidden();
  // Versteckt fällt die Liste auch aus dem Baum der Rollen: darum über das Element selbst.
  await expect(page.locator('main ul[aria-label="Monate"]')).toBeHidden();
  await expect(page.locator('main ul[aria-label="Monate"] a').first()).toBeHidden();
  await expect(sheet.getByRole('button')).toHaveCount(0);
  await expect(sheet.getByText('Imbiss Druck')).toBeVisible();
  // Der Kopf des Blatts (mit "Schließen") fällt weg, der Kopf des Drucks trägt den Titel.
  await expect(sheet.getByRole('heading', { name: monthLabel(previous) })).toBeHidden();
  await expect(sheet.getByText(monthLabel(previous), { exact: true }).filter({ visible: true })).toHaveCount(1);
  await expect(sheet.getByText(/^Erstellt am \d{2}\.\d{2}\.\d{4} um \d{2}:\d{2}$/)).toBeVisible();
  await expect(sheet.getByTestId('total')).toBeVisible();

  // Das Blatt steht im Fluss über die ganze Breite, nicht als Blatt rechts mit eigener Höhe.
  const box = await sheet.evaluate((el) => {
    const r = el.getBoundingClientRect();
    return { left: r.left, width: r.width, page: document.documentElement.clientWidth, height: r.height, scroll: el.scrollHeight };
  });
  expect(box.left).toBe(0);
  expect(box.width).toBe(box.page);
  expect(Math.ceil(box.height)).toBeGreaterThanOrEqual(box.scroll);
});

test('Tag: Bar, Karte, Steuer und Drucken; offener Tag druckt mit "offen"', async ({ page }) => {
  const site = await createSite(page);
  const now = Date.now();
  const closed = openDay({ openedAt: new Date(now - 26 * 60 * 60_000), openingFloatCents: 10_000 });
  const open = openDay({ openedAt: earlierToday(3)[0] });
  const [t1, t2] = earlierToday(3).slice(1);
  const cash = saleReceipt({ createdAt: new Date(now - 25 * 60 * 60_000), businessDayId: closed.id, lines: [line(MENU.huhnBowl), line(MENU.cola, 2)] });
  const card = saleReceipt({ createdAt: new Date(now - 25 * 60 * 60_000 + 60_000), businessDayId: closed.id, payment: 'card', lines: [line(MENU.teigtaschen)] });
  const gone = saleReceipt({ createdAt: new Date(now - 25 * 60 * 60_000 + 120_000), businessDayId: closed.id, lines: [line(MENU.cola)] });
  await pushEntries(page, site, [
    { kind: 'day', day: closed },
    { kind: 'day', day: open },
    { kind: 'receipt', receipt: cash },
    { kind: 'receipt', receipt: card },
    { kind: 'receipt', receipt: gone },
    { kind: 'receipt', receipt: voidReceipt(gone) },
    { kind: 'receipt', receipt: saleReceipt({ createdAt: t1, businessDayId: open.id, lines: [line(MENU.cola)] }) },
    { kind: 'receipt', receipt: saleReceipt({ createdAt: t2, businessDayId: open.id, payment: 'card', lines: [line(MENU.huhnBowl)] }) },
  ]);
  await pushEntries(page, site, [
    { kind: 'day', day: closeDay(closed, { closedAt: new Date(now - 24 * 60 * 60_000), expectedCents: 11_620, countedCents: 11_620 }) },
  ]);

  await page.goto(`/b/${site.businessId}/tage/${closed.id}`);
  const sheet = page.getByRole('dialog');
  await expect(sheet.getByTestId('revenue')).toHaveText(eur('22,70'));
  await expect(sheet.getByTestId('cash')).toHaveText(eur('16,20'));
  await expect(sheet.getByTestId('card')).toHaveText(eur('6,50'));
  await expect(sheet.getByTestId('voided')).toHaveText(eur('3,15'));
  const tax = sheet.getByRole('table', { name: 'Steuer' });
  await expect(tax.getByRole('row', { name: /MwSt 10 %/ })).toContainText(eur('1,49'));
  await expect(tax.getByRole('row', { name: /MwSt 20 %/ })).toContainText(eur('0,97'));
  await expect(tax.getByRole('row', { name: /Pfand, ohne MwSt/ })).toContainText(eur('0,50'));
  await expect(sheet.getByRole('button', { name: 'Drucken' })).toBeVisible();
  await expect(sheet.getByTestId('counted')).toHaveText(eur('116,20'));

  await page.goto(`/b/${site.businessId}/tage/${open.id}`);
  await expect(sheet.getByTestId('revenue')).toHaveText(eur('13,05'));
  await expect(sheet.getByTestId('voided')).toHaveCount(0);
  await page.emulateMedia({ media: 'print' });
  await expect(sheet.getByText('offen', { exact: true })).toBeVisible();
  await expect(sheet.getByText(/^Erstellt am /)).toBeVisible();
  for (const id of ['expected', 'counted', 'difference', 'left-in-drawer']) await expect(sheet.getByTestId(id)).toHaveCount(0);
  await expect(page.getByRole('navigation', { name: 'Bereiche' })).toBeHidden();
});

test.describe('Handy', () => {
  test.use({ viewport: { width: 390, height: 844 } });

  test('Handy 390 px: kein Scrollen zur Seite auf Monate und im Blatt', async ({ page }) => {
    const site = await createSite(page, { name: 'Imbiss mit einem recht langen Namen am Handy' });
    await seedMonths(page, site);
    const { previous, before } = months();

    await page.goto(`/b/${site.businessId}/monate`);
    await expect(monthRows(page)).toHaveCount(2);
    await noHorizontalScroll(page, 'Monate');
    const bar = page.getByRole('navigation', { name: 'Bereiche' }).filter({ visible: true });
    await expect(bar.getByRole('link', { name: 'Abschlüsse' })).toHaveText('Abschluss');
    await expect(bar.getByRole('link', { name: 'Abschlüsse' })).toHaveAttribute('aria-current', 'page');

    await page.goto(`/b/${site.businessId}/monate/${previous}`);
    await expect(page.getByRole('dialog').getByTestId('total')).toHaveText(eur('22,70'));
    await noHorizontalScroll(page, 'Monat');
    const overflow = await page.getByRole('dialog').evaluate((el) => el.scrollWidth - el.clientWidth);
    expect(overflow, 'Blatt').toBeLessThanOrEqual(0);

    await page.goto(`/b/${site.businessId}/monate/${before}..${previous}`);
    await expect(page.getByRole('dialog').getByTestId('total')).toHaveText(eur('42,50'));
    await noHorizontalScroll(page, 'Zeitraum');
  });
});
