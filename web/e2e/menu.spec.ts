import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import type { Locator, Page, Request, Route } from '@playwright/test';
import { expect, signInAsProvider, test } from './support/fixtures';
import { createSite } from './support/seed';

const HEADERS = { 'X-Kassa-Request': '1' };
const NBSP = ' ';
const MENU_FILE = fileURLToPath(new URL('../../shared/fixtures/menu/inputs/beispiel-imbiss.json', import.meta.url));
const MENU = JSON.parse(readFileSync(MENU_FILE, 'utf8')) as Record<string, any>;
const PHOTO = fileURLToPath(new URL('./support/photo.jpg', import.meta.url));
const PHOTO_2 = fileURLToPath(new URL('./support/photo-2.png', import.meta.url));
const LOGO = fileURLToPath(new URL('./support/logo.png', import.meta.url));

const PRICE_PROBLEM = 'Gib einen Preis wie 9,90 ein.';
const NOT_AN_IMAGE = 'Das ist kein Bild. Erlaubt sind JPEG, PNG und WebP.';
const TOO_LARGE = 'Das Bild ist größer als 10 MB.';
const SYNC_HINT = 'Kommt beim nächsten Abgleich an die Kassa.';
const PROVIDER_NOTE = 'Ändern kommt mit der nächsten Stufe. Bis dahin: Speisekarte neu einspielen.';

/** Ein eigener Betrieb aus der Beispiel-Speisekarte, auf Wunsch mit geänderter Datei. */
async function createBusiness(page: Page, change: (menu: Record<string, any>) => void = () => {}): Promise<string> {
  const menu = structuredClone(MENU);
  change(menu);
  const res = await page.request.post('/api/admin/businesses', { headers: HEADERS, data: { menuFile: JSON.stringify(menu) } });
  expect(res.status(), await res.text()).toBe(201);
  return ((await res.json()) as { business: { id: string } }).business.id;
}

type WireItem = { id: string; priceCents: number; inSale: boolean; favorite: boolean; archived: boolean; photo: { id: string; color: string } | null };

async function serverItem(page: Page, b: string, id: string): Promise<WireItem> {
  const res = await page.request.get(`/api/admin/businesses/${b}/items`);
  const { categories } = (await res.json()) as { categories: { items: WireItem[] }[] };
  return categories.flatMap((c) => c.items).find((i) => i.id === id)!;
}

const price = (page: Page, item: string) => page.getByRole('textbox', { name: `${item}: Preis` });
const inSale = (page: Page, item: string) => page.getByRole('switch', { name: `${item}: im Verkauf` });
const favorite = (page: Page, item: string) => page.getByRole('button', { name: `${item}: Favorit` });
const photoField = (page: Page, item: string) => page.getByRole('button', { name: new RegExp(`^${item}: Foto (hinzufügen|ändern)$`) });
const toast = (page: Page) => page.locator('[popover]');

/** Zählt die Anfragen einer Art, etwa alle PATCH an Artikel. */
function countRequests(page: Page, match: (r: Request) => boolean): { count: () => number } {
  let n = 0;
  page.on('request', (r) => {
    if (match(r)) n++;
  });
  return { count: () => n };
}
const isPatch = (r: Request) => r.method() === 'PATCH' && /\/items\/[^/]+$/.test(new URL(r.url()).pathname);

async function noHorizontalScroll(page: Page, what: string): Promise<void> {
  const { scrollWidth, clientWidth } = await page.evaluate(() => ({
    scrollWidth: document.documentElement.scrollWidth,
    clientWidth: document.documentElement.clientWidth,
  }));
  expect(scrollWidth, what).toBeLessThanOrEqual(clientWidth);
}

/** Das Bild im Foto-Feld ist geladen und kommt von der Datei `id`. */
async function expectPhoto(field: Locator, id: string): Promise<void> {
  const img = field.locator('img');
  await expect(img).toHaveAttribute('src', new RegExp(`/files/${id}$`));
  await expect.poll(() => img.evaluate((el: HTMLImageElement) => el.complete && el.naturalWidth > 0)).toBe(true);
}

test.beforeEach(async ({ page }) => {
  await signInAsProvider(page);
});

test('Preis ändern: Enter speichert, nach dem Neuladen steht der neue Preis, der Hinweis kommt einmal', async ({ page }) => {
  const b = await createBusiness(page);
  const patches = countRequests(page, isPatch);
  await page.goto(`/b/${b}/speisekarte`);
  const field = price(page, 'Huhn Bowl');
  await expect(field).toHaveValue('9,90');
  await expect(field).toHaveAttribute('inputmode', 'decimal');

  // Antippen markiert den ganzen Preis, Tippen ersetzt ihn.
  await field.click();
  expect(await field.evaluate((el: HTMLInputElement) => [el.selectionStart, el.selectionEnd])).toEqual([0, 4]);
  await page.keyboard.type('10.5');
  await page.keyboard.press('Enter');
  await expect(field).toHaveValue('10,50');
  await expect(field).toBeFocused();
  await expect(toast(page).getByText(SYNC_HINT)).toBeVisible();
  await expect.poll(async () => (await serverItem(page, b, 'huhn-bowl')).priceCents).toBe(1050);
  expect(patches.count()).toBe(1);

  // Verlassen ohne Änderung speichert nichts, Escape stellt den gespeicherten Preis wieder her.
  await field.blur();
  await field.fill('12');
  await page.keyboard.press('Escape');
  await expect(field).toHaveValue('10,50');
  await expect(field).toBeFocused();
  await field.blur();
  expect(patches.count()).toBe(1);

  // Verlassen mit Änderung speichert, der Hinweis kommt in diesem Besuch nicht noch einmal: ein neuer Hinweis
  // ersetzte den stehenden (der Hinweis wird mit jeder Meldung neu gebaut), der markierte bleibt also stehen.
  await toast(page).getByText(SYNC_HINT).evaluate((el) => el.setAttribute('data-first', ''));
  await price(page, 'Teigtaschen').fill('7');
  await price(page, 'Teigtaschen').blur();
  await expect.poll(async () => (await serverItem(page, b, 'teigtaschen')).priceCents).toBe(700);
  await page.waitForLoadState('networkidle');
  await expect(toast(page).locator('[data-first]')).toHaveCount(1);

  await page.reload();
  await expect(price(page, 'Huhn Bowl')).toHaveValue('10,50');
  await expect(price(page, 'Teigtaschen')).toHaveValue('7,00');
  // Ein neuer Besuch der Seite: der Hinweis kommt wieder.
  await price(page, 'Cola 0,33 l').fill('3,1');
  await page.keyboard.press('Enter');
  await expect(toast(page).getByText(SYNC_HINT)).toBeVisible();
});

test('unlesbarer Preis: der Satz steht am Feld, der Text bleibt, nichts wird gespeichert', async ({ page }) => {
  const b = await createBusiness(page);
  const patches = countRequests(page, isPatch);
  await page.goto(`/b/${b}/speisekarte`);
  const field = price(page, 'Huhn Bowl');
  for (const text of ['abc', '-2', '9,999', '']) {
    await field.fill(text);
    await field.blur();
    await expect(field).toHaveValue(text);
    await expect(field).toHaveAttribute('aria-invalid', 'true');
    const describedBy = await field.getAttribute('aria-describedby');
    expect(describedBy).toBeTruthy();
    await expect(page.locator(`[id="${describedBy}"]`)).toHaveText(PRICE_PROBLEM);
  }
  expect(patches.count()).toBe(0);

  // Escape stellt den gespeicherten Preis wieder her, die Meldung geht weg.
  await field.focus();
  await page.keyboard.press('Escape');
  await expect(field).toHaveValue('9,90');
  await expect(field).not.toHaveAttribute('aria-invalid', 'true');
  await expect(page.getByText(PRICE_PROBLEM)).toHaveCount(0);

  await page.reload();
  await expect(price(page, 'Huhn Bowl')).toHaveValue('9,90');
  expect((await serverItem(page, b, 'huhn-bowl')).priceCents).toBe(990);
});

test('zweite Änderung während des Speicherns geht nicht verloren: der letzte Preis gewinnt', async ({ page }) => {
  const b = await createBusiness(page);
  await page.goto(`/b/${b}/speisekarte`);
  let release: () => void = () => {};
  const held = new Promise<void>((r) => (release = r));
  let first = true;
  await page.route('**/api/admin/businesses/*/items/huhn-bowl', async (route) => {
    if (first) {
      first = false;
      await held;
    }
    await route.continue();
  });
  const field = price(page, 'Huhn Bowl');
  await field.fill('11');
  await page.keyboard.press('Enter');
  // Das Feld bleibt bedienbar, während gespeichert wird.
  await expect(field).toBeEditable();
  await field.fill('12,50');
  await page.keyboard.press('Enter');
  await expect(field).toHaveValue('12,50');
  release();
  await expect.poll(async () => (await serverItem(page, b, 'huhn-bowl')).priceCents).toBe(1250);
  await page.waitForLoadState('networkidle');
  await expect(field).toHaveValue('12,50');
  await page.reload();
  await expect(price(page, 'Huhn Bowl')).toHaveValue('12,50');
});

test('Schalter "Im Verkauf" aus und Favorit an bleiben nach dem Neuladen', async ({ page }) => {
  const b = await createBusiness(page);
  await page.goto(`/b/${b}/speisekarte`);
  await expect(inSale(page, 'Huhn Bowl')).toBeChecked();
  await expect(favorite(page, 'Huhn Bowl')).toHaveAttribute('aria-pressed', 'false');

  await inSale(page, 'Huhn Bowl').click();
  await expect(inSale(page, 'Huhn Bowl')).not.toBeChecked();
  await favorite(page, 'Huhn Bowl').click();
  await expect(favorite(page, 'Huhn Bowl')).toHaveAttribute('aria-pressed', 'true');
  // Mit der Tastatur: Leertaste am Schalter, Enter am Stern.
  await inSale(page, 'Cola 0,33 l').focus();
  await page.keyboard.press('Space');
  await expect(inSale(page, 'Cola 0,33 l')).not.toBeChecked();
  await page.keyboard.press('Tab');
  await expect(favorite(page, 'Cola 0,33 l')).toBeFocused();
  await page.keyboard.press('Enter');
  await expect(favorite(page, 'Cola 0,33 l')).toHaveAttribute('aria-pressed', 'true');

  await expect.poll(async () => (await serverItem(page, b, 'cola')).favorite).toBe(true);
  await page.reload();
  await expect(inSale(page, 'Huhn Bowl')).not.toBeChecked();
  await expect(favorite(page, 'Huhn Bowl')).toHaveAttribute('aria-pressed', 'true');
  await expect(inSale(page, 'Cola 0,33 l')).not.toBeChecked();
  await expect(favorite(page, 'Cola 0,33 l')).toHaveAttribute('aria-pressed', 'true');
  await expect(inSale(page, 'Teigtaschen')).toBeChecked();
  const huhn = await serverItem(page, b, 'huhn-bowl');
  expect([huhn.inSale, huhn.favorite]).toEqual([false, true]);
});

test('Server antwortet 500: der Wert springt zurück, die Meldung nennt den Grund', async ({ page, pageProblems }) => {
  const b = await createBusiness(page);
  await page.goto(`/b/${b}/speisekarte`);
  const message = 'Das hat nicht geklappt. Bitte nochmal versuchen.';
  let release: () => void = () => {};
  const held = new Promise<void>((r) => (release = r));
  await page.route('**/api/admin/businesses/*/items/*', async (route) => {
    if (route.request().method() !== 'PATCH') return route.continue();
    await held;
    await route.fulfill({ status: 500, json: { error: { code: 'internal', message } } });
  });

  // Sofort umgelegt, dann zurück.
  await inSale(page, 'Huhn Bowl').click();
  await expect(inSale(page, 'Huhn Bowl')).not.toBeChecked();
  release();
  await expect(toast(page).getByText(message)).toBeVisible();
  await expect(inSale(page, 'Huhn Bowl')).toBeChecked();

  await favorite(page, 'Teigtaschen').click();
  await expect(favorite(page, 'Teigtaschen')).toHaveAttribute('aria-pressed', 'false');

  await price(page, 'Cola 0,33 l').fill('4');
  await page.keyboard.press('Enter');
  await expect(price(page, 'Cola 0,33 l')).toHaveValue('2,90');
  await expect(toast(page).getByText(SYNC_HINT)).toHaveCount(0);

  await page.unroute('**/api/admin/businesses/*/items/*');
  const cola = await serverItem(page, b, 'cola');
  expect(cola.priceCents).toBe(290);
  // Die 500 sind hier gewollt: der Browser meldet jede in der Konsole.
  const expected = /^Konsole \(error\): Failed to load resource: the server responded with a status of 500/;
  expect(pageProblems.filter((p) => expected.test(p))).toHaveLength(3);
  pageProblems.splice(0, pageProblems.length, ...pageProblems.filter((p) => !expected.test(p)));
});

const isList = (r: Request) => r.method() === 'GET' && /\/items$/.test(new URL(r.url()).pathname);

test('A scheitert, während B noch läuft: ist B durch, holt die Seite die Liste und zeigt, was der Server hat', async ({ page, pageProblems }) => {
  const b = await createBusiness(page);
  await page.goto(`/b/${b}/speisekarte`);
  await expect(price(page, 'Cola 0,33 l')).toHaveValue('2,90');
  const message = 'Das hat nicht geklappt. Bitte nochmal versuchen.';
  let release: () => void = () => {};
  const held = new Promise<void>((r) => (release = r));
  await page.route('**/api/admin/businesses/*/items/*', async (route) => {
    if (route.request().method() !== 'PATCH') return route.continue();
    if (route.request().url().endsWith('/teigtaschen')) return route.fulfill({ status: 500, json: { error: { code: 'internal', message } } });
    await held;
    await route.continue();
  });

  // B läuft (gehalten), A scheitert und springt zurück.
  await favorite(page, 'Huhn Bowl').click();
  await favorite(page, 'Teigtaschen').click();
  await expect(toast(page).getByText(message)).toBeVisible();
  await expect(favorite(page, 'Teigtaschen')).toHaveAttribute('aria-pressed', 'false');
  // Ein anderer ändert inzwischen am Server: nur ein Neuladen der Liste bringt das auf die Seite.
  const res = await page.request.patch(`/api/admin/businesses/${b}/items/cola`, { headers: HEADERS, data: { priceCents: 450 } });
  expect(res.ok(), await res.text()).toBe(true);
  const lists = countRequests(page, isList);
  expect(lists.count()).toBe(0);

  release();
  await expect(favorite(page, 'Huhn Bowl')).toHaveAttribute('aria-pressed', 'true');
  await expect(price(page, 'Cola 0,33 l')).toHaveValue('4,50');
  expect(lists.count()).toBe(1);
  // Die frühere Änderung glückte nach der gescheiterten späteren: der Hinweis kommt trotzdem.
  await expect(toast(page).getByText(SYNC_HINT)).toBeVisible();
  await page.unroute('**/api/admin/businesses/*/items/*');

  const expected = /^Konsole \(error\): Failed to load resource: the server responded with a status of 500/;
  expect(pageProblems.filter((p) => expected.test(p))).toHaveLength(1);
  pageProblems.splice(0, pageProblems.length, ...pageProblems.filter((p) => !expected.test(p)));
});

test('ein Neuladen während des Speicherns bringt den alten Wert nicht zurück', async ({ page }) => {
  const b = await createBusiness(page);
  await page.clock.install();
  await page.goto(`/b/${b}/speisekarte`);
  const field = price(page, 'Huhn Bowl');
  await expect(field).toHaveValue('9,90');

  let release: () => void = () => {};
  const held = new Promise<void>((r) => (release = r));
  await page.route('**/api/admin/businesses/*/items/huhn-bowl', async (route) => {
    await held;
    await route.continue();
  });
  // Die ersten zwei Listen holt der Test sofort vom Server (sie kennen den neuen Preis noch nicht) und gibt sie
  // erst zurück, wann er will; alle späteren gehen durch.
  const lists: { route: Route; old: Awaited<ReturnType<Route['fetch']>> }[] = [];
  await page.route('**/api/admin/businesses/*/items', async (route) => {
    if (route.request().method() !== 'GET' || lists.length >= 2) return route.continue();
    lists.push({ route, old: await route.fetch() });
  });
  // Die Seite holt die Liste neu, wenn das Fenster wieder sichtbar wird und die Daten alt sind.
  const refetch = async () => {
    await page.clock.fastForward(31_000);
    await page.evaluate(() => window.dispatchEvent(new Event('visibilitychange')));
  };

  await field.fill('11');
  await page.keyboard.press('Enter');
  await expect(field).toHaveValue('11,00');

  // Die alte Liste kommt, während noch gespeichert wird: der neue Preis bleibt stehen.
  await refetch();
  await expect.poll(() => lists.length).toBe(1);
  const first = page.waitForResponse((r) => r.request() === lists[0]!.route.request());
  await lists[0]!.route.fulfill({ response: lists[0]!.old });
  await first;
  await expect(field).toHaveValue('11,00');

  // Die alte Liste kommt erst nach der Antwort zum Speichern: sie zählt nicht, die Seite holt sie frisch.
  await refetch();
  await expect.poll(() => lists.length).toBe(2);
  const saved = page.waitForResponse((r) => isPatch(r.request()));
  const fresh = page.waitForResponse((r) => isList(r.request()) && r.request() !== lists[1]!.route.request());
  release();
  await saved;
  await fresh;
  await lists[1]!.route.fulfill({ response: lists[1]!.old }).catch(() => undefined);
  await page.waitForLoadState('networkidle');
  await expect(field).toHaveValue('11,00');
  expect((await serverItem(page, b, 'huhn-bowl')).priceCents).toBe(1100);
});

test('Foto entfernen als erste Änderung eines Besuchs: der Hinweis zum Abgleich kommt mit', async ({ page }) => {
  const b = await createBusiness(page);
  const put = await page.request.put(`/api/admin/businesses/${b}/items/huhn-bowl/photo`, {
    headers: { ...HEADERS, 'Content-Type': 'image/jpeg' },
    data: readFileSync(PHOTO),
  });
  expect(put.ok(), await put.text()).toBe(true);
  await page.goto(`/b/${b}/speisekarte`);
  await photoField(page, 'Huhn Bowl').click();
  const dialog = page.getByRole('dialog', { name: 'Foto für Huhn Bowl' });
  await dialog.getByRole('button', { name: 'Foto entfernen' }).click();
  await dialog.getByRole('button', { name: 'Ja, entfernen' }).click();
  await expect(dialog).toHaveCount(0);
  await expect(toast(page).getByText(`Foto entfernt. ${SYNC_HINT}`)).toBeVisible();

  // Die zweite Änderung des Besuchs meldet sich ohne den Hinweis.
  await favorite(page, 'Huhn Bowl').click();
  await expect.poll(async () => (await serverItem(page, b, 'huhn-bowl')).favorite).toBe(true);
  await expect(toast(page).getByText(`Foto entfernt. ${SYNC_HINT}`)).toBeVisible();
});

test('Foto hochladen, ersetzen, entfernen mit Rückgängig, nach dem Neuladen mit Rückfrage', async ({ page }) => {
  const b = await createBusiness(page);
  await page.goto(`/b/${b}/speisekarte`);
  const field = photoField(page, 'Huhn Bowl');
  await expect(field).toHaveAccessibleName('Huhn Bowl: Foto hinzufügen');
  const box = await field.boundingBox();
  expect([box?.width, box?.height]).toEqual([56, 56]);

  await field.click();
  const dialog = page.getByRole('dialog', { name: 'Foto für Huhn Bowl' });
  await expect(dialog).toBeVisible();
  await expect(dialog.getByRole('button', { name: 'Speichern' })).toHaveAttribute('aria-disabled', 'true');
  await expect(dialog.getByRole('button', { name: 'Foto entfernen' })).toHaveCount(0);
  await dialog.locator('input[type=file]').setInputFiles(PHOTO);
  const preview = dialog.getByRole('img', { name: 'Vorschau' });
  await expect(preview).toHaveAttribute('src', /^blob:/);
  await dialog.getByRole('button', { name: 'Speichern' }).click();
  await expect(dialog).toHaveCount(0);
  // Der Fokus ist zurück am Foto-Feld.
  await expect(photoField(page, 'Huhn Bowl')).toBeFocused();
  await expect(photoField(page, 'Huhn Bowl')).toHaveAccessibleName('Huhn Bowl: Foto ändern');
  const first = (await serverItem(page, b, 'huhn-bowl')).photo!;
  await expectPhoto(field, first.id);
  await expect(toast(page).getByText(SYNC_HINT)).toBeVisible();

  // Ersetzen: neue Datei, neue Adresse.
  await field.click();
  await expect(dialog.getByRole('img', { name: 'Vorschau' })).toHaveAttribute('src', new RegExp(`/files/${first.id}$`));
  await dialog.locator('input[type=file]').setInputFiles(PHOTO_2);
  await dialog.getByRole('button', { name: 'Speichern' }).click();
  await expect(dialog).toHaveCount(0);
  const second = (await serverItem(page, b, 'huhn-bowl')).photo!;
  expect(second.id).not.toBe(first.id);
  await expectPhoto(field, second.id);

  // Entfernen wirkt sofort, das Bild aus diesem Besuch kommt mit "Rückgängig" zurück.
  await field.click();
  await dialog.getByRole('button', { name: 'Foto entfernen' }).click();
  await expect(dialog).toHaveCount(0);
  await expect(field).toHaveAccessibleName('Huhn Bowl: Foto hinzufügen');
  await expect(field.locator('img')).toHaveCount(0);
  await expect(toast(page).getByText('Foto entfernt.')).toBeVisible();
  await expect.poll(async () => (await serverItem(page, b, 'huhn-bowl')).photo).toBeNull();
  await toast(page).getByRole('button', { name: 'Rückgängig' }).click();
  await expect(field).toHaveAccessibleName('Huhn Bowl: Foto ändern');
  await expect.poll(async () => (await serverItem(page, b, 'huhn-bowl')).photo).not.toBeNull();
  const back = (await serverItem(page, b, 'huhn-bowl')).photo!;
  await expectPhoto(field, back.id);

  // Nach dem Neuladen kennt die Seite die Datei nicht mehr: erst eine Rückfrage, kein Rückgängig.
  await page.reload();
  await photoField(page, 'Huhn Bowl').click();
  await dialog.getByRole('button', { name: 'Foto entfernen' }).click();
  await expect(dialog.getByText('Foto wirklich entfernen?')).toBeVisible();
  await dialog.getByRole('button', { name: 'Ja, entfernen' }).click();
  await expect(dialog).toHaveCount(0);
  await expect(toast(page).getByText('Foto entfernt.')).toBeVisible();
  await expect(toast(page).getByRole('button', { name: 'Rückgängig' })).toHaveCount(0);
  await expect(photoField(page, 'Huhn Bowl')).toHaveAccessibleName('Huhn Bowl: Foto hinzufügen');
  await page.reload();
  await expect(photoField(page, 'Huhn Bowl')).toHaveAccessibleName('Huhn Bowl: Foto hinzufügen');
  expect((await serverItem(page, b, 'huhn-bowl')).photo).toBeNull();
});

test('falsche Dateien: Textdatei mit Endung .jpg nennt der Server, andere Art und zu groß prüft schon die Seite', async ({ page }) => {
  const b = await createBusiness(page);
  const puts = countRequests(page, (r) => r.method() === 'PUT');
  await page.goto(`/b/${b}/speisekarte`);
  await photoField(page, 'Teigtaschen').click();
  const dialog = page.getByRole('dialog', { name: 'Foto für Teigtaschen' });
  const input = dialog.locator('input[type=file]');

  await input.setInputFiles({ name: 'notiz.txt', mimeType: 'text/plain', buffer: Buffer.from('Einkaufsliste') });
  await expect(dialog.getByText(NOT_AN_IMAGE)).toBeVisible();
  await expect(dialog.getByRole('button', { name: 'Speichern' })).toHaveAttribute('aria-disabled', 'true');

  await input.setInputFiles({ name: 'riesig.jpg', mimeType: 'image/jpeg', buffer: Buffer.alloc(10 * 1024 * 1024 + 1, 1) });
  await expect(dialog.getByText(TOO_LARGE)).toBeVisible();
  await expect(dialog.getByText(NOT_AN_IMAGE)).toHaveCount(0);
  expect(puts.count()).toBe(0);

  await input.setInputFiles({ name: 'kein-bild.jpg', mimeType: 'image/jpeg', buffer: Buffer.from('Das ist nur Text, kein Foto.') });
  await expect(dialog.getByText(TOO_LARGE)).toHaveCount(0);
  await dialog.getByRole('button', { name: 'Speichern' }).click();
  await expect(dialog.getByText(NOT_AN_IMAGE)).toBeVisible();
  expect(puts.count()).toBe(1);
  await expect(dialog).toBeVisible();
  expect((await serverItem(page, b, 'teigtaschen')).photo).toBeNull();
});

test('Schließen während des Hochladens bricht ab und ändert nichts', async ({ page }) => {
  const b = await createBusiness(page);
  await page.goto(`/b/${b}/speisekarte`);
  let aborted = false;
  page.on('requestfailed', (r) => {
    if (r.method() === 'PUT') aborted = true;
  });
  // Die Anfrage bleibt hängen, bis die Seite sie abbricht.
  let held: Route | undefined;
  await page.route('**/api/admin/businesses/*/items/*/photo', (route) => {
    held = route;
  });
  await photoField(page, 'Huhn Bowl').click();
  const dialog = page.getByRole('dialog', { name: 'Foto für Huhn Bowl' });
  await dialog.locator('input[type=file]').setInputFiles(PHOTO);
  await dialog.getByRole('button', { name: 'Speichern' }).click();
  await expect(dialog.getByRole('progressbar')).toBeVisible();
  // Das Fenster bleibt bedienbar.
  await expect(dialog.getByRole('button', { name: 'Abbrechen' })).toBeEnabled();
  await page.keyboard.press('Escape');
  await expect(dialog).toHaveCount(0);
  await expect.poll(() => aborted).toBe(true);
  await expect(photoField(page, 'Huhn Bowl')).toHaveAccessibleName('Huhn Bowl: Foto hinzufügen');
  // Erst nachdem die Seite abgebrochen hat: die gehaltene Anfrage geht nie zum Server.
  await held?.abort().catch(() => undefined);
  await page.unroute('**/api/admin/businesses/*/items/*/photo');
  expect((await serverItem(page, b, 'huhn-bowl')).photo).toBeNull();
});

test('Tastatur: durch eine Zeile und durch das Foto-Fenster, der Fokus kommt zum Foto-Feld zurück', async ({ page }) => {
  const b = await createBusiness(page);
  await page.goto(`/b/${b}/speisekarte`);
  await photoField(page, 'Huhn Bowl').focus();
  await page.keyboard.press('Tab');
  await expect(price(page, 'Huhn Bowl')).toBeFocused();
  await page.keyboard.press('Tab');
  await expect(inSale(page, 'Huhn Bowl')).toBeFocused();
  await page.keyboard.press('Tab');
  await expect(favorite(page, 'Huhn Bowl')).toBeFocused();
  await page.keyboard.press('Tab');
  await expect(photoField(page, 'Teigtaschen')).toBeFocused();

  await page.keyboard.press('Shift+Tab');
  await page.keyboard.press('Shift+Tab');
  await page.keyboard.press('Shift+Tab');
  await page.keyboard.press('Shift+Tab');
  await expect(photoField(page, 'Huhn Bowl')).toBeFocused();
  await page.keyboard.press('Enter');
  const dialog = page.getByRole('dialog', { name: 'Foto für Huhn Bowl' });
  await expect(dialog).toBeVisible();
  // Die Fläche zum Wählen ist mit der Tastatur erreichbar, der Fokus bleibt im Fenster.
  const input = dialog.locator('input[type=file]');
  for (let i = 0; i < 4 && !(await input.evaluate((el) => el === document.activeElement)); i++) await page.keyboard.press('Tab');
  await expect(input).toBeFocused();
  await input.setInputFiles(PHOTO);
  await dialog.getByRole('button', { name: 'Speichern' }).focus();
  await page.keyboard.press('Enter');
  await expect(dialog).toHaveCount(0);
  await expect(photoField(page, 'Huhn Bowl')).toBeFocused();

  // Entfernen mit Rückgängig, mit der Tastatur; Escape schließt, der Fokus ist wieder am Foto-Feld.
  await page.keyboard.press('Enter');
  await expect(dialog.getByRole('button', { name: 'Foto entfernen' })).toBeVisible();
  await page.keyboard.press('Escape');
  await expect(dialog).toHaveCount(0);
  await expect(photoField(page, 'Huhn Bowl')).toBeFocused();
});

test('stillgelegte Artikel und Kategorien stehen am Ende, gedämpft und ohne Bedienelemente', async ({ page }) => {
  const b = await createBusiness(page);
  // Neu einspielen ohne Teigtaschen und ohne Getränke: beide werden stillgelegt.
  const menu = structuredClone(MENU);
  menu.artikel = menu.artikel.filter((a: { id: string }) => a.id === 'huhn-bowl');
  menu.kategorien = menu.kategorien.filter((k: { id: string }) => k.id === 'bowls');
  menu.artikel.push({ id: 'tofu-bowl', name: 'Tofu Bowl', preis_cent: 890, kategorie: 'bowls', mwst: 10 });
  const res = await page.request.post(`/api/admin/businesses/${b}/menu`, { headers: HEADERS, data: { menuFile: JSON.stringify(menu) } });
  expect(res.ok(), await res.text()).toBe(true);

  await page.goto(`/b/${b}/speisekarte`);
  const bowls = page.getByRole('list', { name: 'Bowls' });
  await expect(bowls.getByRole('listitem')).toHaveText([/Huhn Bowl/, /Tofu Bowl/, /Teigtaschen.*Stillgelegt/]);
  const archived = bowls.getByRole('listitem').filter({ hasText: 'Teigtaschen' });
  await expect(archived.getByRole('textbox')).toHaveCount(0);
  await expect(archived.getByRole('switch')).toHaveCount(0);
  await expect(archived.getByRole('button')).toHaveCount(0);
  await expect(archived).toContainText(`6,50${NBSP}€`);

  // Die stillgelegte Kategorie kommt nach den aktiven.
  const headings = page.getByRole('heading', { level: 2 });
  await expect(headings).toHaveText([/Bowls/, /Getränke.*Stillgelegt/]);
  const drinks = page.getByRole('list', { name: 'Getränke' });
  await expect(drinks.getByRole('listitem')).toHaveCount(1);
  await expect(drinks.getByRole('textbox')).toHaveCount(0);
  await expect(drinks.getByRole('switch')).toHaveCount(0);
  await expect(drinks.getByRole('button')).toHaveCount(0);

  // Am Handy steht der Preis, wo er in den aktiven Zeilen steht: links unter dem Foto, gleich breit wie das Feld.
  await page.setViewportSize({ width: 390, height: 844 });
  const field = (await price(page, 'Huhn Bowl').locator('xpath=..').boundingBox())!;
  const text = (await archived.getByText(`6,50${NBSP}€`).boundingBox())!;
  expect(Math.abs(text.x - field.x)).toBeLessThanOrEqual(1);
  expect(Math.abs(text.x + text.width - (field.x + field.width))).toBeLessThanOrEqual(1);
});

test('Logo hochladen und entfernen: die Kopfzeile zeigt es neben dem Namen', async ({ page }) => {
  const b = await createBusiness(page);
  await page.goto(`/b/${b}/betrieb`);
  await expect(page.getByRole('heading', { level: 1, name: 'Betrieb' })).toBeVisible();
  await expect(page.getByTestId('business-logo')).toHaveCount(0);
  // Die Angaben nur zum Lesen, für den Anbieter mit dem Satz.
  await expect(page.getByText('Musterstraße 1')).toBeVisible();
  await expect(page.getByText('1010 Wien')).toBeVisible();
  await expect(page.getByText('ATU12345678')).toBeVisible();
  await expect(page.getByText('Danke und bis bald!')).toBeVisible();
  await expect(page.getByText(PROVIDER_NOTE)).toBeVisible();
  await expect(page.getByRole('main').getByRole('textbox')).toHaveCount(0);

  await page.getByRole('button', { name: 'Logo hinzufügen' }).click();
  const dialog = page.getByRole('dialog', { name: 'Logo' });
  await dialog.locator('input[type=file]').setInputFiles(LOGO);
  await expect(dialog.getByRole('img', { name: 'Vorschau' })).toBeVisible();
  await dialog.getByRole('button', { name: 'Speichern' }).click();
  await expect(dialog).toHaveCount(0);
  const logo = page.getByTestId('business-logo');
  await expect(logo).toHaveAttribute('alt', '');
  await expect.poll(() => logo.evaluate((el: HTMLImageElement) => el.complete && el.naturalWidth > 0)).toBe(true);
  const size = await logo.boundingBox();
  expect([size?.width, size?.height]).toEqual([32, 32]);

  // Entfernen wirkt sofort; das Logo aus diesem Besuch kommt mit "Rückgängig" zurück.
  const firstId = (await logo.getAttribute('src'))!;
  await page.getByRole('button', { name: 'Logo ändern' }).click();
  await dialog.getByRole('button', { name: 'Logo entfernen' }).click();
  await expect(dialog).toHaveCount(0);
  await expect(page.getByTestId('business-logo')).toHaveCount(0);
  await expect(toast(page).getByText('Logo entfernt.')).toBeVisible();
  await toast(page).getByRole('button', { name: 'Rückgängig' }).click();
  await expect(page.getByTestId('business-logo')).toBeVisible();
  await expect(page.getByTestId('business-logo')).not.toHaveAttribute('src', firstId);

  // Auf jeder Seite des Betriebs, auch nach dem Neuladen. Danach kennt die Seite die Datei nicht mehr: erst die Rückfrage.
  await page.goto(`/b/${b}/speisekarte`);
  await expect(page.getByTestId('business-logo')).toBeVisible();
  await page.goto(`/b/${b}/betrieb`);
  await page.getByRole('button', { name: 'Logo ändern' }).click();
  await dialog.getByRole('button', { name: 'Logo entfernen' }).click();
  await expect(dialog.getByText('Logo wirklich entfernen?')).toBeVisible();
  await dialog.getByRole('button', { name: 'Ja, entfernen' }).click();
  await expect(dialog).toHaveCount(0);
  await expect(toast(page).getByText('Logo entfernt.')).toBeVisible();
  await expect(page.getByTestId('business-logo')).toHaveCount(0);
  await page.reload();
  await expect(page.getByRole('heading', { level: 1, name: 'Betrieb' })).toBeVisible();
  await expect(page.getByTestId('business-logo')).toHaveCount(0);
});

test('Chef: Preis, Schalter, Foto und Logo ja, "Neu einspielen" nein, die Angaben ohne den Satz', async ({ page }) => {
  const site = await createSite(page, { name: 'Imbiss mit Chef', owner: true });
  await page.context().clearCookies();
  const login = await page.request.post('/api/auth/login', { headers: HEADERS, data: site.owner });
  expect(login.ok(), await login.text()).toBe(true);

  await page.goto(`/b/${site.businessId}/speisekarte`);
  await expect(page.getByRole('heading', { level: 1, name: 'Speisekarte' })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Speisekarte neu einspielen' })).toHaveCount(0);
  await price(page, 'Huhn Bowl').fill('10,90');
  await page.keyboard.press('Enter');
  await inSale(page, 'Cola 0,33 l').click();
  await favorite(page, 'Teigtaschen').click();
  await photoField(page, 'Teigtaschen').click();
  const dialog = page.getByRole('dialog', { name: 'Foto für Teigtaschen' });
  await dialog.locator('input[type=file]').setInputFiles(PHOTO);
  await dialog.getByRole('button', { name: 'Speichern' }).click();
  await expect(dialog).toHaveCount(0);
  await expect(photoField(page, 'Teigtaschen')).toHaveAccessibleName('Teigtaschen: Foto ändern');

  await page.reload();
  await expect(price(page, 'Huhn Bowl')).toHaveValue('10,90');
  await expect(inSale(page, 'Cola 0,33 l')).not.toBeChecked();
  await expect(favorite(page, 'Teigtaschen')).toHaveAttribute('aria-pressed', 'true');

  await page.getByRole('navigation', { name: 'Bereiche' }).first().getByRole('link', { name: 'Betrieb' }).click();
  await expect(page).toHaveURL(new RegExp(`/b/${site.businessId}/betrieb$`));
  await expect(page.getByText('Musterstraße 1')).toBeVisible();
  await expect(page.getByText(PROVIDER_NOTE)).toHaveCount(0);
  await page.getByRole('button', { name: 'Logo hinzufügen' }).click();
  await page.getByRole('dialog', { name: 'Logo' }).locator('input[type=file]').setInputFiles(LOGO);
  await page.getByRole('dialog', { name: 'Logo' }).getByRole('button', { name: 'Speichern' }).click();
  await expect(page.getByTestId('business-logo')).toBeVisible();
});

test('360 px: kein waagrechtes Scrollen, Ziele mindestens 44 px, Beschriftungen für Vorleseprogramme', async ({ page }) => {
  const long = 'Gebratene Nudeln mit knusprigem Hühnerfleisch und Gemüse der Saison';
  const b = await createBusiness(page, (menu) => {
    menu.artikel.push({ id: 'nudeln', name: long, preis_cent: 1_234_550, kategorie: 'bowls', mwst: 10 });
    menu.artikel.push({ id: 'almdudler', name: 'Almdudler 0,35 l', preis_cent: 320, kategorie: 'getraenke', mwst: 20 });
    menu.artikel.push({ id: 'nudeln-kurz', name: 'Gebratene Nudeln mit knusprigem Huhn', preis_cent: 1150, kategorie: 'bowls', mwst: 10 });
  });
  await page.setViewportSize({ width: 360, height: 780 });
  await page.goto(`/b/${b}/speisekarte`);
  await expect(price(page, long)).toHaveValue('12345,50');
  await noHorizontalScroll(page, 'Speisekarte bei 360');

  // Der Name reicht bis zum Stern: kurze Namen in einer Zeile, die Einheit bricht nicht allein um.
  const lines = (item: string) =>
    page
      .getByRole('listitem')
      .filter({ has: price(page, item) })
      .locator('p')
      .evaluate((el) => Math.round(el.getBoundingClientRect().height / parseFloat(getComputedStyle(el).lineHeight)));
  expect(await lines('Almdudler 0,35 l')).toBe(1);
  expect(await lines('Cola 0,33 l')).toBe(1);
  expect(await lines('Gebratene Nudeln mit knusprigem Huhn')).toBeLessThanOrEqual(2);
  // Ein Name von fast 70 Zeichen braucht bei 360 px mehr Zeilen, bleibt aber ganz lesbar.
  expect(await lines(long)).toBeLessThanOrEqual(4);

  for (const item of ['Huhn Bowl', long]) {
    // Beim Preis ist die Tippfläche das ganze Feld um den Text (mit Eurozeichen und Rand).
    for (const target of [photoField(page, item), price(page, item).locator('xpath=..'), favorite(page, item)]) {
      const box = (await target.boundingBox())!;
      expect(box.width, `${item}`).toBeGreaterThanOrEqual(44);
      expect(box.height, `${item}`).toBeGreaterThanOrEqual(44);
    }
    // Die Tippfläche des Schalters ist die beschriftete Zeile um das Kästchen.
    const sw = (await inSale(page, item).boundingBox())!;
    expect(sw.width).toBeGreaterThanOrEqual(44);
    expect(sw.height).toBeGreaterThanOrEqual(44);
  }

  // Unlesbarer Preis bei 360 px: die Meldung passt in die Zeile.
  await price(page, long).fill('zu viel');
  await price(page, long).blur();
  await expect(page.getByText(PRICE_PROBLEM)).toBeVisible();
  await noHorizontalScroll(page, 'Meldung bei 360');

  await photoField(page, 'Huhn Bowl').click();
  await page.getByRole('dialog').locator('input[type=file]').setInputFiles(PHOTO);
  await expect(page.getByRole('dialog').getByRole('img', { name: 'Vorschau' })).toBeVisible();
  await noHorizontalScroll(page, 'Foto-Fenster bei 360');
  await page.keyboard.press('Escape');

  await page.goto(`/b/${b}/betrieb`);
  await expect(page.getByText('ATU12345678')).toBeVisible();
  await noHorizontalScroll(page, 'Betrieb bei 360');
});
