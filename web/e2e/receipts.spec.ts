import type { Locator, Page, Route } from '@playwright/test';
import { expect, signInAsProvider, test } from './support/fixtures';
import {
  cashMovement,
  closeDay,
  createSite,
  earlierToday,
  line,
  MENU,
  openDay,
  pushEntries,
  saleReceipt,
  signature,
  signatureChain,
  specialReceipt,
  voidReceipt,
  type Site,
} from './support/seed';

const NBSP = ' ';
const eur = (text: string) => `${text}${NBSP}€`;
const DAY = 24 * 60 * 60_000;
const GROSS = { groupName: 'Größe', optionName: 'Groß', surchargeCents: 150 };

// Zeiten, Tage und "Heute" rechnet die Seite in der Zeit des Betriebs; der Browser steht in derselben Zeitzone.
test.use({ timezoneId: 'Europe/Vienna' });

test.beforeEach(async ({ page }) => {
  await signInAsProvider(page);
});

/** Die Zeilen der Bonliste in ihrer Reihenfolge. */
function receiptRows(page: Page): Locator {
  return page.getByRole('main').getByRole('link', { name: /^Bon \d+/ });
}

function receiptRow(page: Page, number: number): Locator {
  return page.getByRole('main').getByRole('link', { name: new RegExp(`^Bon ${number}\\b`) });
}

function payment(page: Page, label: string): Locator {
  return page.getByRole('radiogroup', { name: 'Zahlungsart' }).getByRole('radio', { name: label });
}

/** Die Leiste unten (am Handy); die Seitenleiste ist dann versteckt. */
function bottomBar(page: Page): Locator {
  return page.getByRole('navigation', { name: 'Bereiche' }).filter({ visible: true });
}

async function noHorizontalScroll(page: Page, what: string): Promise<void> {
  const { scrollWidth, clientWidth } = await page.evaluate(() => ({
    scrollWidth: document.documentElement.scrollWidth,
    clientWidth: document.documentElement.clientWidth,
  }));
  expect(scrollWidth, what).toBeLessThanOrEqual(clientWidth);
}

function viennaDate(at: Date): string {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Europe/Vienna',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(at);
}

/**
 * Bon 1 bar mit Option und Rückgeld, Bon 2 Karte, Bon 3 bar und von Bon 4 storniert, alle heute;
 * Bon 5 bar vor zwei Tagen. Neueste zuerst heißt also 4, 3, 2, 1, 5.
 */
async function seedReceipts(page: Page, site: Site) {
  const [t1, t2, t3, t4] = earlierToday(4);
  const withOption = saleReceipt({
    number: 1,
    createdAt: t1,
    givenCents: 2000,
    lines: [line(MENU.huhnBowl, 1, [GROSS]), line(MENU.cola, 2)],
  });
  const card = saleReceipt({ number: 2, createdAt: t2, payment: 'card', lines: [line(MENU.teigtaschen)] });
  const cancelled = saleReceipt({ number: 3, createdAt: t3, lines: [line(MENU.huhnBowl)] });
  const storno = voidReceipt(cancelled, { number: 4, createdAt: t4 });
  const old = saleReceipt({ number: 5, createdAt: new Date(Date.now() - 2 * DAY), lines: [line(MENU.cola)] });
  await pushEntries(
    page,
    site,
    [withOption, card, cancelled, storno, old].map((receipt) => ({ kind: 'receipt', receipt })),
  );
  return { withOption, card, cancelled, storno, old };
}

test('Bons: neueste zuerst, mit Uhrzeit, Kassa, Mitarbeiter, Betrag und Merkmalen', async ({ page }) => {
  const site = await createSite(page, { name: 'Imbiss mit Bons', registerName: 'Theke' });
  const seeded = await seedReceipts(page, site);
  await page.goto(`/b/${site.businessId}/bons`);

  await expect(page.getByRole('heading', { level: 1, name: 'Bons' })).toBeVisible();
  await expect(page.getByText('Imbiss mit Bons').first()).toBeVisible();
  await expect(receiptRows(page)).toHaveCount(5);
  const names = await receiptRows(page).evaluateAll((links) => links.map((l) => /^Bon (\d+)/.exec(l.textContent ?? '')?.[1]));
  expect(names).toEqual(['4', '3', '2', '1', '5']);

  const time = new Intl.DateTimeFormat('de-AT', {
    timeZone: 'Europe/Vienna',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  }).format(new Date(seeded.withOption.createdAt));
  await expect(receiptRow(page, 1)).toContainText(time);
  await expect(receiptRow(page, 1)).toContainText('Theke');
  await expect(receiptRow(page, 1)).toContainText('Chefin');
  await expect(receiptRow(page, 1)).toContainText(eur('17,70'));
  await expect(receiptRow(page, 1)).toContainText('Testbon');
  await expect(receiptRow(page, 4)).toContainText('Storno');
  await expect(receiptRow(page, 4)).toContainText(eur('−9,90'));
  await expect(receiptRow(page, 3)).toContainText('Storniert');
  await expect(receiptRow(page, 3)).toContainText(eur('9,90'));

  // Die Liste reicht über zwei Tage: ruhige Überschriften "Heute" und der Tag davor.
  await expect(page.getByRole('heading', { level: 2, name: 'Heute' })).toBeVisible();
  await expect(page.getByRole('heading', { level: 2 })).toHaveCount(2);
});

test('Filter Karte und Nur Stornos stehen in der Adresse und bleiben nach dem Neuladen', async ({ page }) => {
  const site = await createSite(page, { name: 'Imbiss mit Filter' });
  await seedReceipts(page, site);
  await page.goto(`/b/${site.businessId}/bons`);
  await expect(receiptRows(page)).toHaveCount(5);
  await expect(payment(page, 'Alle')).toBeChecked();

  await payment(page, 'Karte').check();
  await expect(page).toHaveURL(/\?zahlung=karte$/);
  await expect(receiptRows(page)).toHaveCount(1);
  await expect(receiptRow(page, 2)).toBeVisible();

  await page.reload();
  await expect(payment(page, 'Karte')).toBeChecked();
  await expect(receiptRows(page)).toHaveCount(1);

  await payment(page, 'Alle').check();
  await page.getByRole('switch', { name: 'Nur Stornos' }).check();
  await expect(page).toHaveURL(/\?stornos=1$/);
  // Beide Hälften des Paars: der Storno-Bon und der Verkauf, den er storniert.
  await expect(receiptRows(page)).toHaveCount(2);
  await expect(receiptRow(page, 4)).toContainText('Storno');
  await expect(receiptRow(page, 3)).toContainText('Storniert');

  await page.reload();
  await expect(page.getByRole('switch', { name: 'Nur Stornos' })).toBeChecked();
  await expect(receiptRows(page)).toHaveCount(2);

  // Kein Bon passt: der eigene leere Zustand mit dem Weg zurück.
  await payment(page, 'Karte').check();
  await expect(page).toHaveURL(/zahlung=karte/);
  await expect(page.getByText('Kein Bon passt zu diesem Filter.')).toBeVisible();
  // Der Satz nennt auch den Schalter, der hier mitfiltert.
  await expect(page.getByText('Wähl einen anderen Tag oder eine andere Zahlungsart, oder schalte "Nur Stornos" aus.')).toBeVisible();
  await page.getByRole('button', { name: 'Filter zurücksetzen' }).click();
  await expect(page).toHaveURL(new RegExp(`/b/${site.businessId}/bons$`));
  await expect(receiptRows(page)).toHaveCount(5);
  await expect(page.getByRole('switch', { name: 'Nur Stornos' })).not.toBeChecked();
});

test('Tag: "Heute" setzt das Datum, leer heißt alle Tage', async ({ page }) => {
  const site = await createSite(page, { name: 'Imbiss mit Tagen' });
  await seedReceipts(page, site);
  await page.goto(`/b/${site.businessId}/bons`);
  await expect(page.getByLabel('Tag', { exact: true })).toHaveValue('');
  await expect(receiptRows(page)).toHaveCount(5);

  await page.getByRole('button', { name: 'Heute' }).click();
  const today = viennaDate(new Date());
  await expect(page).toHaveURL(new RegExp(`\\?tag=${today}$`));
  await expect(page.getByLabel('Tag', { exact: true })).toHaveValue(today);
  await expect(receiptRows(page)).toHaveCount(4);
  // Ein einziger Tag im Filter: keine Überschriften über den Zeilen.
  await expect(page.getByRole('heading', { level: 2 })).toHaveCount(0);

  const twoDaysAgo = viennaDate(new Date(Date.now() - 2 * DAY));
  await page.getByLabel('Tag', { exact: true }).fill(twoDaysAgo);
  await expect(page).toHaveURL(new RegExp(`\\?tag=${twoDaysAgo}$`));
  await expect(receiptRows(page)).toHaveCount(1);
  await expect(receiptRow(page, 5)).toBeVisible();

  await page.getByRole('button', { name: 'Tag löschen' }).click();
  await expect(page).toHaveURL(new RegExp(`/b/${site.businessId}/bons$`));
  await expect(page.getByLabel('Tag', { exact: true })).toHaveValue('');
  await expect(receiptRows(page)).toHaveCount(5);
});

test('Bon öffnen: Zeilen mit Option, Pfand, Summe, Rückgeld; Zurück führt zur gefilterten Liste', async ({ page }) => {
  const site = await createSite(page, { name: 'Imbiss mit Detail' });
  const { withOption, cancelled } = await seedReceipts(page, site);
  await page.goto(`/b/${site.businessId}/bons?zahlung=bar`);
  await expect(receiptRows(page)).toHaveCount(4);
  await page.evaluate(() => window.scrollTo(0, 0));

  await receiptRow(page, 1).click();
  await expect(page).toHaveURL(new RegExp(`/b/${site.businessId}/bons/${withOption.id}\\?zahlung=bar$`));
  const detail = page.getByRole('dialog', { name: 'Bon 1' });
  await expect(detail).toBeVisible();
  await expect(detail.getByRole('list', { name: 'Zeilen' }).getByRole('listitem')).toHaveCount(2);
  await expect(detail).toContainText('Huhn Bowl');
  await expect(detail).toContainText('Größe: Groß');
  await expect(detail).toContainText('Cola 0,33 l');
  await expect(detail.getByTestId('deposit')).toHaveText(eur('0,50'));
  await expect(detail.getByTestId('total')).toHaveText(eur('17,70'));
  await expect(detail.getByTestId('payment-kind')).toHaveText('Bar');
  await expect(detail.getByTestId('given')).toHaveText(eur('20,00'));
  await expect(detail.getByTestId('change')).toHaveText(eur('2,30'));
  // Nichts ist änderbar: kein Knopf außer Schließen.
  await expect(detail.getByRole('button')).toHaveCount(1);
  // Am Rechner liegt das Blatt über der Liste (die Liste ist dahinter gesperrt, aber zu sehen).
  await expect(page.locator(`[data-row-id="${cancelled.id}"]`)).toBeVisible();

  await page.goBack();
  await expect(page).toHaveURL(new RegExp(`/b/${site.businessId}/bons\\?zahlung=bar$`));
  await expect(page.getByRole('dialog')).toHaveCount(0);
  await expect(payment(page, 'Bar')).toBeChecked();
  await expect(receiptRows(page)).toHaveCount(4);

  // Neuladen der Adresse des Bons: das Blatt über der Liste.
  await page.goto(`/b/${site.businessId}/bons/${withOption.id}?zahlung=bar`);
  await expect(page.getByRole('dialog', { name: 'Bon 1' })).toBeVisible();
  await expect(receiptRows(page)).toHaveCount(4);
  await page.getByRole('dialog').getByRole('button', { name: 'Schließen' }).click();
  await expect(page).toHaveURL(new RegExp(`/b/${site.businessId}/bons\\?zahlung=bar$`));
  await expect(page.getByRole('dialog')).toHaveCount(0);
});

test('Storno und stornierter Bon verweisen aufeinander, Karte zeigt Kartenart und letzte vier Ziffern', async ({ page }) => {
  const site = await createSite(page, { name: 'Imbiss mit Storno' });
  const { storno, card } = await seedReceipts(page, site);
  await page.goto(`/b/${site.businessId}/bons/${storno.id}`);
  const stornoDetail = page.getByRole('dialog', { name: 'Bon 4' });
  await expect(stornoDetail).toContainText('Storno');
  await expect(stornoDetail.getByTestId('total')).toHaveText(eur('−9,90'));
  await stornoDetail.getByRole('link', { name: 'Zum stornierten Bon 3' }).click();
  const sale = page.getByRole('dialog', { name: 'Bon 3' });
  await expect(sale).toContainText('Storniert');
  await expect(sale.getByTestId('total')).toHaveText(eur('9,90'));
  await expect(sale.getByRole('link', { name: 'Zum Storno-Bon 4' })).toBeVisible();
  // Schließen führt zur Liste, nicht zurück zum Storno.
  await page.keyboard.press('Escape');
  await expect(page).toHaveURL(new RegExp(`/b/${site.businessId}/bons$`));

  await page.goto(`/b/${site.businessId}/bons/${card.id}`);
  const cardDetail = page.getByRole('dialog', { name: 'Bon 2' });
  await expect(cardDetail.getByTestId('payment-kind')).toHaveText('Karte');
  await expect(cardDetail.getByTestId('card')).toHaveText('VISA, endet auf 4242');
  await expect(cardDetail.getByTestId('given')).toHaveCount(0);
  // Damit findet der Chef die Zahlung bei SumUp.
  expect(card.payment.providerTxCode).toMatch(/^T\d+$/);
  await expect(cardDetail.getByText('Kennung bei SumUp')).toBeVisible();
  await expect(cardDetail.getByTestId('provider-tx')).toHaveText(card.payment.providerTxCode!);
  // Ein Barverkauf hat keine.
  await page.goto(`/b/${site.businessId}/bons/${storno.id}`);
  await expect(page.getByRole('dialog', { name: 'Bon 4' }).getByTestId('provider-tx')).toHaveCount(0);
});

test('ein Neuladen eines offenen Bons oder Tags scheitert: das Blatt bleibt stehen', async ({ page, pageProblems }) => {
  const site = await createSite(page, { name: 'Imbiss mit schwachem Netz' });
  const { card } = await seedReceipts(page, site);
  const day = openDay({ openedAt: earlierToday(1)[0]! });
  await pushEntries(page, site, [{ kind: 'day', day }]);
  await page.clock.install();
  const message = 'Das hat nicht geklappt. Bitte nochmal versuchen.';
  const fail = (route: Route) => route.fulfill({ status: 500, json: { error: { code: 'internal', message } } });
  // Die Seite holt neu, wenn das Fenster wieder sichtbar wird und die Daten alt sind.
  const refocus = async () => {
    await page.clock.fastForward(31_000);
    await page.evaluate(() => window.dispatchEvent(new Event('visibilitychange')));
  };

  await page.goto(`/b/${site.businessId}/bons/${card.id}`);
  const receipt = page.getByRole('dialog', { name: 'Bon 2' });
  await expect(receipt.getByTestId('payment-kind')).toHaveText('Karte');
  let failedReceipt = false;
  await page.route(`**/api/admin/businesses/*/receipts/${card.id}`, (route) => {
    failedReceipt = true;
    return fail(route);
  });
  await refocus();
  await expect.poll(() => failedReceipt).toBe(true);
  await page.waitForLoadState('networkidle');
  await expect(receipt.getByTestId('payment-kind')).toHaveText('Karte');
  await expect(receipt.getByText(message)).toHaveCount(0);

  await page.goto(`/b/${site.businessId}/tage/${day.id}`);
  const detail = page.getByRole('dialog');
  await expect(detail).toContainText('offen');
  let failedDay = false;
  await page.route(`**/api/admin/businesses/*/days/${day.id}`, (route) => {
    failedDay = true;
    return fail(route);
  });
  await refocus();
  await expect.poll(() => failedDay).toBe(true);
  await page.waitForLoadState('networkidle');
  await expect(detail).toContainText('offen');
  await expect(detail.getByText(message)).toHaveCount(0);

  // Die 500 sind hier gewollt: der Browser meldet jede in der Konsole.
  const expected = /^Konsole \(error\): Failed to load resource: the server responded with a status of 500/;
  expect(pageProblems.filter((p) => expected.test(p)).length).toBeGreaterThanOrEqual(2);
  pageProblems.splice(0, pageProblems.length, ...pageProblems.filter((p) => !expected.test(p)));
});

test('Signatur in Worten und Sonderbeleg mit Namen statt Betrag', async ({ page }) => {
  const site = await createSite(page, { name: 'Imbiss mit Signatur' });
  const [t1, t2, t3, t4, t5] = earlierToday(5);
  const live = saleReceipt({
    number: 1,
    createdAt: t1,
    test: false,
    lines: [line(MENU.cola)],
    rksv: signature({ chain: 2, position: 1 }),
  });
  const probe = saleReceipt({ number: 2, createdAt: t2, lines: [line(MENU.cola)], rksv: signature({ chain: 1, position: 1 }) });
  const damaged = saleReceipt({
    number: 3,
    createdAt: t3,
    lines: [line(MENU.cola)],
    rksv: signature({ chain: 1, position: 2, damaged: true }),
  });
  const unsigned = saleReceipt({ number: 4, createdAt: t4, lines: [line(MENU.cola)] });
  const start = specialReceipt('start', { number: 5, createdAt: t5 });
  await pushEntries(page, site, [
    { kind: 'rksv_chain', chain: signatureChain({ chain: 1, mode: 'probe' }) },
    { kind: 'rksv_chain', chain: signatureChain({ chain: 2, mode: 'live' }) },
    ...[live, probe, damaged, unsigned, start].map((receipt) => ({ kind: 'receipt', receipt })),
  ]);

  await page.goto(`/b/${site.businessId}/bons`);
  await expect(receiptRow(page, 5)).toContainText('Startbeleg');
  await expect(receiptRow(page, 5)).not.toContainText('€');
  await expect(receiptRow(page, 1)).not.toContainText('Testbon');

  for (const [receipt, text] of [
    [live, 'Signiert'],
    [probe, 'Probe'],
    [damaged, 'Signatur ausgefallen'],
  ] as const) {
    await page.goto(`/b/${site.businessId}/bons/${receipt.id}`);
    await expect(page.getByRole('dialog').getByTestId('signature')).toHaveText(text);
    await expect(page.getByRole('dialog')).not.toContainText('eyJ');
  }
  await page.goto(`/b/${site.businessId}/bons/${unsigned.id}`);
  await expect(page.getByRole('dialog', { name: 'Bon 4' })).toBeVisible();
  await expect(page.getByRole('dialog').getByTestId('signature')).toHaveCount(0);

  await page.goto(`/b/${site.businessId}/bons/${start.id}`);
  const special = page.getByRole('dialog', { name: 'Bon 5' });
  await expect(special.getByTestId('total')).toHaveText('Startbeleg');
  await expect(special.getByTestId('payment-kind')).toHaveCount(0);
});

test('Mehr laden hängt an, ein Fehler behält die Zeilen und bietet "Nochmal versuchen"', async ({ page }) => {
  const site = await createSite(page, { name: 'Imbiss mit vielen Bons' });
  const times = earlierToday(55);
  await pushEntries(
    page,
    site,
    times.map((createdAt, i) => ({
      kind: 'receipt',
      receipt: saleReceipt({ number: i + 1, createdAt, lines: [line(MENU.cola)] }),
    })),
  );
  await page.goto(`/b/${site.businessId}/bons`);
  await expect(receiptRows(page)).toHaveCount(50);
  await expect(receiptRows(page).first()).toHaveAccessibleName(/^Bon 55\b/);

  let fail = true;
  await page.route('**/receipts?*before=*', async (route) => {
    if (fail) {
      await route.fulfill({
        status: 409,
        json: { error: { code: 'conflict', message: 'Das hat nicht geklappt. Bitte nochmal versuchen.' } },
      });
    } else {
      await route.continue();
    }
  });
  await page.getByRole('button', { name: 'Mehr laden' }).click();
  await expect(page.getByText('Weitere Bons konnten nicht geladen werden.')).toBeVisible();
  await expect(receiptRows(page)).toHaveCount(50);

  fail = false;
  await page.getByRole('button', { name: 'Nochmal versuchen' }).click();
  await expect(receiptRows(page)).toHaveCount(55);
  await expect(receiptRows(page).last()).toHaveAccessibleName(/^Bon 1\b/);
  await expect(page.getByRole('button', { name: 'Mehr laden' })).toHaveCount(0);
});

test('Bons und Tage laden alle 60 Sekunden von selbst nach, die geladenen Seiten bleiben', async ({ page }) => {
  const site = await createSite(page, { name: 'Imbiss mit Nachladen' });
  const times = earlierToday(55);
  const first = openDay({ openedAt: times[0]! });
  await pushEntries(page, site, [
    { kind: 'day', day: first },
    ...times.map((createdAt, i) => ({ kind: 'receipt', receipt: saleReceipt({ number: i + 1, createdAt, lines: [line(MENU.cola)] }) })),
  ]);
  await page.clock.install();
  await page.goto(`/b/${site.businessId}/bons`);
  await expect(receiptRows(page)).toHaveCount(50);
  await page.getByRole('button', { name: 'Mehr laden' }).click();
  await expect(receiptRows(page)).toHaveCount(55);

  // An der Kassa kommt ein Bon dazu: nach einer Minute steht er oben, die zweite Seite bleibt.
  await pushEntries(page, site, [{ kind: 'receipt', receipt: saleReceipt({ number: 56, createdAt: new Date(), lines: [line(MENU.cola)] }) }]);
  await page.clock.fastForward(30_000);
  await expect(receiptRows(page)).toHaveCount(55);
  await page.clock.fastForward(31_000);
  await expect(receiptRows(page).first()).toHaveAccessibleName(/^Bon 56\b/);
  await expect(receiptRows(page)).toHaveCount(56);
  await expect(receiptRows(page).last()).toHaveAccessibleName(/^Bon 1\b/);

  await page.goto(`/b/${site.businessId}/tage`);
  const rows = page.getByRole('main').getByRole('list', { name: 'Tage' }).getByRole('link');
  await expect(rows).toHaveCount(1);
  await pushEntries(page, site, [{ kind: 'day', day: openDay({ openedAt: new Date() }) }]);
  await page.clock.fastForward(61_000);
  await expect(rows).toHaveCount(2);
});

test('Betrieb ohne Bon: leerer Zustand ohne Filter', async ({ page }) => {
  const site = await createSite(page, { name: 'Imbiss ganz leer' });
  await page.goto(`/b/${site.businessId}/bons`);
  await expect(page.getByText('Noch kein Bon.', { exact: true })).toBeVisible();
  await expect(page.getByText('Sobald an der Kassa boniert wird, erscheinen die Bons hier.')).toBeVisible();
  await expect(page.getByRole('radiogroup', { name: 'Zahlungsart' })).toHaveCount(0);
});

test('Tastatur: Tab bis zum Bon, Eingabe öffnet, Escape schließt, der Fokus kehrt zur Zeile zurück', async ({ page }) => {
  const site = await createSite(page, { name: 'Imbiss mit Tastatur' });
  await seedReceipts(page, site);
  await page.goto(`/b/${site.businessId}/bons`);
  await expect(receiptRows(page)).toHaveCount(5);

  const first = receiptRows(page).first();
  for (let i = 0; i < 30; i++) {
    await page.keyboard.press('Tab');
    if (await first.evaluate((el) => el === document.activeElement)) break;
  }
  await expect(first).toBeFocused();
  await page.keyboard.press('Enter');
  const detail = page.getByRole('dialog', { name: 'Bon 4' });
  await expect(detail).toBeVisible();
  await expect(detail.getByRole('button', { name: 'Schließen' })).toBeFocused();
  await page.keyboard.press('Escape');
  await expect(page.getByRole('dialog')).toHaveCount(0);
  await expect(page).toHaveURL(new RegExp(`/b/${site.businessId}/bons$`));
  await expect(first).toBeFocused();

  // Nach dem Neuladen der Adresse des Bons geht der Fokus beim Schließen zu seiner Zeile.
  await page.goto(`/b/${site.businessId}/bons/${(await receiptRow(page, 2).getAttribute('href'))!.split('/').pop()}`);
  await expect(page.getByRole('dialog', { name: 'Bon 2' })).toBeVisible();
  await page.keyboard.press('Escape');
  await expect(receiptRow(page, 2)).toBeFocused();
});

test('Tab im Blatt des Bons: nach dem letzten zum ersten, vor dem ersten zum letzten', async ({ page }) => {
  const site = await createSite(page, { name: 'Imbiss mit Tab' });
  const { storno } = await seedReceipts(page, site);
  await page.goto(`/b/${site.businessId}/bons/${storno.id}`);
  const detail = page.getByRole('dialog', { name: 'Bon 4' });
  const close = detail.getByRole('button', { name: 'Schließen' });
  const pair = detail.getByRole('link', { name: 'Zum stornierten Bon 3' });
  await expect(pair).toBeVisible();
  await close.focus();

  await page.keyboard.press('Tab');
  await expect(pair).toBeFocused();
  await page.keyboard.press('Tab');
  await expect(close).toBeFocused();
  await page.keyboard.press('Shift+Tab');
  await expect(pair).toBeFocused();
  await page.keyboard.press('Shift+Tab');
  await expect(close).toBeFocused();
});

test('Fremder Bon und fremder Tag unter dem eigenen Betrieb: gibt es nicht', async ({ page }) => {
  const own = await createSite(page, { name: 'Imbiss eigener' });
  const other = await createSite(page, { name: 'Imbiss fremder' });
  const foreign = saleReceipt({ number: 7, createdAt: earlierToday(1)[0]!, lines: [line(MENU.teigtaschen, 3)] });
  const day = openDay({ openedAt: earlierToday(1)[0]!, openingFloatCents: 98_765 });
  await pushEntries(page, other, [
    { kind: 'day', day },
    { kind: 'receipt', receipt: foreign },
  ]);

  await page.goto(`/b/${own.businessId}/bons/${foreign.id}`);
  const detail = page.getByRole('dialog', { name: 'Bon', exact: true });
  await expect(detail).toContainText('Diesen Bon gibt es nicht.');
  await expect(detail).not.toContainText('Teigtaschen');
  await expect(detail).not.toContainText('€');
  await expect(detail.getByTestId('total')).toHaveCount(0);

  await page.goto(`/b/${own.businessId}/tage/${day.id}`);
  const dayDetail = page.getByRole('dialog');
  await expect(dayDetail).toContainText('Diesen Tag gibt es nicht.');
  await expect(dayDetail).not.toContainText('987,65');
  await expect(dayDetail.getByTestId('opening-float')).toHaveCount(0);
});

test('Tage: offener Tag, abgeschlossener Tag mit Differenz und Bewegung', async ({ page }) => {
  const site = await createSite(page, { name: 'Imbiss mit Abschluss', registerName: 'Theke' });
  const now = Date.now();
  const yesterday = openDay({ openedAt: new Date(now - DAY - 2 * 60 * 60_000), openingFloatCents: 15_000 });
  const today = openDay({ openedAt: earlierToday(1)[0]! });
  const sale = saleReceipt({
    businessDayId: yesterday.id,
    createdAt: new Date(now - DAY - 60 * 60_000),
    lines: [line(MENU.huhnBowl, 2)],
  });
  const withdrawal = cashMovement(yesterday, {
    kind: 'withdrawal',
    amountCents: 2000,
    reason: 'bank',
    createdAt: new Date(now - DAY - 30 * 60_000),
  });
  const closed = closeDay(yesterday, {
    closedAt: new Date(now - DAY),
    expectedCents: 14_980,
    countedCents: 14_830,
    leftInDrawerCents: 10_000,
  });
  await pushEntries(page, site, [
    { kind: 'day', day: yesterday },
    { kind: 'day', day: today },
    { kind: 'receipt', receipt: sale },
    { kind: 'cash_movement', movement: withdrawal },
  ]);
  await pushEntries(page, site, [{ kind: 'day', day: closed }]);

  await page.goto(`/b/${site.businessId}/tage`);
  await expect(page.getByRole('heading', { level: 1, name: 'Abschlüsse' })).toBeVisible();
  const rows = page.getByRole('main').getByRole('list', { name: 'Tage' }).getByRole('link');
  await expect(rows).toHaveCount(2);
  await expect(rows.first()).toContainText('offen');
  await expect(rows.first()).toContainText('Theke');
  await expect(rows.nth(1)).toContainText(eur('19,80'));
  await expect(rows.nth(1)).toContainText(`Differenz ${eur('−1,50')}`);
  await expect(rows.nth(1)).not.toContainText('offen');

  await rows.nth(1).click();
  await expect(page).toHaveURL(new RegExp(`/b/${site.businessId}/tage/${yesterday.id}$`));
  const detail = page.getByRole('dialog');
  await expect(detail).toBeVisible();
  await expect(detail.getByTestId('opening-float')).toHaveText(eur('150,00'));
  await expect(detail.getByTestId('revenue')).toHaveText(eur('19,80'));
  await expect(detail.getByTestId('expected')).toHaveText(eur('149,80'));
  await expect(detail.getByTestId('counted')).toHaveText(eur('148,30'));
  await expect(detail.getByTestId('difference')).toHaveText(eur('−1,50'));
  await expect(detail.getByTestId('left-in-drawer')).toHaveText(eur('100,00'));
  const movements = detail.getByRole('list', { name: 'Bewegungen' }).getByRole('listitem');
  await expect(movements).toHaveCount(1);
  await expect(movements.first()).toContainText('Entnommen: Bank');
  await expect(movements.first()).toContainText(eur('−20,00'));
  await expect(detail.getByRole('button')).toHaveText(['Drucken', '']);

  await page.keyboard.press('Escape');
  await expect(page).toHaveURL(new RegExp(`/b/${site.businessId}/tage$`));
  await expect(rows.nth(1)).toBeFocused();

  await rows.first().click();
  await expect(page.getByRole('dialog')).toContainText('offen');
  await expect(page.getByRole('dialog').getByTestId('counted')).toHaveCount(0);
});

test.describe('Handy', () => {
  test.use({ viewport: { width: 390, height: 844 } });

  test('Leiste: fünf Ziele, "Mehr" öffnet das Blatt, eine Zeile führt hin und schließt es', async ({ page }) => {
    const site = await createSite(page, { name: 'Imbiss am Handy' });
    await page.goto(`/b/${site.businessId}/umsaetze`);
    const bar = bottomBar(page);
    await expect(bar.getByRole('link')).toHaveText(['Umsätze', 'Bons', 'Abschluss', 'Speisekarte']);
    const more = bar.getByRole('button', { name: 'Mehr' });
    await expect(more).toBeVisible();
    await expect(more).not.toHaveAttribute('aria-current');

    await more.click();
    const sheet = page.getByRole('dialog', { name: 'Mehr' });
    await expect(sheet.getByRole('link')).toHaveText(['Übersetzungen', 'Kassen', 'Mitarbeiter', 'Betrieb', 'Alle Betriebe']);
    await sheet.getByRole('link', { name: 'Kassen' }).click();
    await expect(page).toHaveURL(new RegExp(`/b/${site.businessId}/kassen$`));
    await expect(page.getByRole('dialog')).toHaveCount(0);
    await expect(page.getByRole('heading', { level: 1, name: 'Kassen' })).toBeVisible();
    await expect(more).toHaveAttribute('aria-current', 'true');

    // Zurück schließt das Blatt und bleibt auf der Seite.
    await more.click();
    await expect(page.getByRole('dialog', { name: 'Mehr' })).toBeVisible();
    await page.goBack();
    await expect(page.getByRole('dialog')).toHaveCount(0);
    await expect(page).toHaveURL(new RegExp(`/b/${site.businessId}/kassen$`));

    // Mit der Tastatur: Eingabe öffnet, Escape schließt, der Fokus steht wieder auf "Mehr".
    await more.focus();
    await page.keyboard.press('Enter');
    await expect(page.getByRole('dialog', { name: 'Mehr' })).toBeVisible();
    await page.keyboard.press('Escape');
    await expect(page.getByRole('dialog')).toHaveCount(0);
    await expect(more).toBeFocused();
    await expect(page).toHaveURL(new RegExp(`/b/${site.businessId}/kassen$`));

    await page.keyboard.press('Enter');
    const sheet2 = page.getByRole('dialog', { name: 'Mehr' });
    await expect(sheet2).toBeVisible();
    await page.keyboard.press('Tab');
    await expect(sheet2.getByRole('link', { name: 'Übersetzungen' })).toBeFocused();
    await page.keyboard.press('Tab');
    await expect(sheet2.getByRole('link', { name: 'Kassen' })).toBeFocused();
    await page.keyboard.press('Tab');
    await page.keyboard.press('Enter');
    await expect(page).toHaveURL(new RegExp(`/b/${site.businessId}/mitarbeiter$`));
    await expect(page.getByRole('dialog')).toHaveCount(0);
    await expect(more).toBeFocused();
  });

  test('Bon am Handy als eigene Seite mit Zurück', async ({ page }) => {
    const site = await createSite(page, { name: 'Imbiss Handy-Bon' });
    await seedReceipts(page, site);
    await page.goto(`/b/${site.businessId}/bons?zahlung=bar`);
    await receiptRow(page, 1).click();
    const detail = page.getByRole('dialog', { name: 'Bon 1' });
    await expect(detail).toBeVisible();
    // Am Handy füllt das Blatt die ganze Breite: eine eigene Seite.
    await expect.poll(async () => (await detail.boundingBox())?.width).toBe(390);
    await detail.getByRole('button', { name: 'Zurück' }).click();
    await expect(page).toHaveURL(new RegExp(`/b/${site.businessId}/bons\\?zahlung=bar$`));
    await expect(page.getByRole('dialog')).toHaveCount(0);
  });

  test('Tab bleibt am Handy im Bon und im Blatt "Mehr", in beide Richtungen', async ({ page }) => {
    const site = await createSite(page, { name: 'Imbiss Handy-Tab' });
    const { storno, withOption } = await seedReceipts(page, site);

    // Bon mit Verweis: "Zurück" ist das erste, der Verweis das letzte Ziel.
    await page.goto(`/b/${site.businessId}/bons/${storno.id}`);
    const detail = page.getByRole('dialog', { name: 'Bon 4' });
    const back = detail.getByRole('button', { name: 'Zurück' });
    const pair = detail.getByRole('link', { name: 'Zum stornierten Bon 3' });
    await expect(pair).toBeVisible();
    await back.focus();
    await page.keyboard.press('Tab');
    await expect(pair).toBeFocused();
    await page.keyboard.press('Tab');
    await expect(back).toBeFocused();
    await page.keyboard.press('Shift+Tab');
    await expect(pair).toBeFocused();
    await page.keyboard.press('Shift+Tab');
    await expect(back).toBeFocused();

    // Bon ohne Verweis: "Zurück" ist das einzige Ziel, Tab und Shift+Tab bleiben darauf.
    await page.goto(`/b/${site.businessId}/bons/${withOption.id}`);
    const plain = page.getByRole('dialog', { name: 'Bon 1' });
    const plainBack = plain.getByRole('button', { name: 'Zurück' });
    await expect(plainBack).toBeVisible();
    await plainBack.focus();
    await page.keyboard.press('Tab');
    await expect(plainBack).toBeFocused();
    await page.keyboard.press('Shift+Tab');
    await expect(plainBack).toBeFocused();

    // Das Blatt "Mehr": Schließen zuerst, "Alle Betriebe" zuletzt.
    await page.goto(`/b/${site.businessId}/umsaetze`);
    await bottomBar(page).getByRole('button', { name: 'Mehr' }).click();
    const sheet = page.getByRole('dialog', { name: 'Mehr' });
    const close = sheet.getByRole('button', { name: 'Schließen' });
    const lastLink = sheet.getByRole('link', { name: 'Alle Betriebe' });
    await close.focus();
    await page.keyboard.press('Shift+Tab');
    await expect(lastLink).toBeFocused();
    await page.keyboard.press('Tab');
    await expect(close).toBeFocused();
  });

  test('Nach dem Neuladen ist das Blatt "Mehr" zu und die Leiste geht', async ({ page }) => {
    const site = await createSite(page, { name: 'Imbiss Handy-Neuladen' });
    await page.goto(`/b/${site.businessId}/umsaetze`);
    const more = bottomBar(page).getByRole('button', { name: 'Mehr' });
    await more.click();
    await expect(page.getByRole('dialog', { name: 'Mehr' })).toBeVisible();

    await page.reload();
    await expect(page.getByRole('heading', { level: 1, name: 'Umsätze' })).toBeVisible();
    await expect(page.getByRole('dialog')).toHaveCount(0);
    await expect(more).toHaveAttribute('aria-expanded', 'false');

    await bottomBar(page).getByRole('link', { name: 'Bons' }).click();
    await expect(page).toHaveURL(new RegExp(`/b/${site.businessId}/bons$`));
    await expect(page.getByRole('heading', { level: 1, name: 'Bons' })).toBeVisible();

    // "Mehr" geht wieder auf, Zurück schließt es.
    await more.click();
    await expect(page.getByRole('dialog', { name: 'Mehr' })).toBeVisible();
    await page.goBack();
    await expect(page.getByRole('dialog')).toHaveCount(0);
    await expect(page).toHaveURL(new RegExp(`/b/${site.businessId}/bons$`));
  });
});

test('360 px: Bons, Bon, Tage und Tag ohne waagrechtes Scrollen', async ({ page }) => {
  await page.setViewportSize({ width: 360, height: 780 });
  const site = await createSite(page, {
    name: 'Imbiss mit einem ziemlich langen Namen am Eck',
    registerName: 'Kassa mit langem Namen am Eck',
  });
  const { withOption } = await seedReceipts(page, site);
  const day = openDay();
  await pushEntries(page, site, [
    { kind: 'day', day },
    { kind: 'cash_movement', movement: cashMovement(day, { kind: 'deposit', amountCents: 123_456, reason: 'change' }) },
  ]);
  await pushEntries(page, site, [{ kind: 'day', day: closeDay(day, { expectedCents: 1_234_567, countedCents: 1_234_767 }) }]);

  await page.goto(`/b/${site.businessId}/bons?tag=${viennaDate(new Date())}&zahlung=bar&stornos=1`);
  await expect(receiptRows(page)).toHaveCount(2);
  await noHorizontalScroll(page, 'Bons mit Filter');
  await page.goto(`/b/${site.businessId}/bons`);
  await expect(receiptRows(page)).toHaveCount(5);
  await noHorizontalScroll(page, 'Bons');
  await page.goto(`/b/${site.businessId}/bons/${withOption.id}`);
  await expect(page.getByRole('dialog', { name: 'Bon 1' })).toBeVisible();
  await noHorizontalScroll(page, 'Bon');
  await page.goto(`/b/${site.businessId}/tage`);
  await expect(page.getByRole('main').getByRole('list', { name: 'Tage' }).getByRole('link')).toHaveCount(1);
  await expect(page.getByRole('main').getByRole('list', { name: 'Tage' }).getByRole('link')).toContainText(`Differenz ${eur('+2,00')}`);
  await noHorizontalScroll(page, 'Tage');
  // Die Leiste unten: fünf Ziele, keine Beschriftung abgeschnitten ("Abschluss" statt "Abschlüsse").
  const labels = await bottomBar(page)
    .locator('a, button')
    .evaluateAll((els) =>
      els.map((el) => {
        const label = el.lastElementChild as HTMLElement;
        return {
          text: label.textContent,
          clipped: label.scrollWidth > label.clientWidth,
          height: el.getBoundingClientRect().height,
          width: el.getBoundingClientRect().width,
        };
      }),
    );
  expect(labels.map((l) => l.text)).toEqual(['Umsätze', 'Bons', 'Abschluss', 'Speisekarte', 'Mehr']);
  for (const l of labels) {
    expect(l.clipped, l.text ?? '').toBe(false);
    expect(l.height).toBeGreaterThanOrEqual(44);
    expect(l.width).toBeGreaterThanOrEqual(44);
  }
  await page.goto(`/b/${site.businessId}/tage/${day.id}`);
  await expect(page.getByRole('dialog').getByTestId('difference')).toHaveText(eur('+2,00'));
  await noHorizontalScroll(page, 'Tag');
});
