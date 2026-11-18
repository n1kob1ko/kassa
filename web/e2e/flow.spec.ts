import { readFileSync } from 'node:fs';
import { randomBytes } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import type { Locator, Page } from '@playwright/test';
import { expect, signInAsProvider, test } from './support/fixtures';
import { E2E_RELEASE_TOKEN } from './support/server';

const INPUTS = fileURLToPath(new URL('../../shared/fixtures/menu/inputs/', import.meta.url));
const MENU_FILE = `${INPUTS}beispiel-imbiss.json`;
const INVALID_FILE = `${INPUTS}fehler-mehrere.json`;
const HEADERS = { 'X-Kassa-Request': '1' };

type Created = { id: string };

/** Legt einen Betrieb über die Schnittstelle an (schneller als über die Seite). */
async function createBusiness(page: Page): Promise<Created> {
  const res = await page.request.post('/api/admin/businesses', {
    headers: HEADERS,
    data: { menuFile: readFileSync(MENU_FILE, 'utf8') },
  });
  expect(res.status()).toBe(201);
  return ((await res.json()) as { business: Created }).business;
}

async function createStaff(page: Page, b: string, name: string, role: 'chef' | 'staff', pin: string): Promise<void> {
  const res = await page.request.post(`/api/admin/businesses/${b}/staff`, { headers: HEADERS, data: { name, role, pin } });
  expect(res.status()).toBe(201);
}

/** Legt eine gekoppelte Kassa an, so wie es ein Tablet täte. */
async function pairRegister(page: Page, b: string, name: string): Promise<void> {
  const created = await page.request.post(`/api/admin/businesses/${b}/pairing-codes`, { headers: HEADERS, data: { name } });
  const { code } = (await created.json()) as { code: string };
  const paired = await page.request.post('/api/device/pair', {
    headers: HEADERS,
    data: { code, previousBusinessId: null, appVersion: '1.2.0', deviceModel: 'Redmi Pad Pro' },
  });
  expect(paired.ok()).toBe(true);
}

/** Der sichtbare Hinweis (der Text steht zusätzlich unsichtbar für Screenreader im Dokument). */
function toastText(page: Page, text: string): Locator {
  return page.locator('[popover]').getByText(text);
}

function row(page: Page, text: string): Locator {
  return page.getByRole('listitem').filter({ hasText: text });
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

// Muss der erste Test sein: er braucht eine Datenbank ohne Betriebe.
test('Betrieb anlegen, Chef anlegen, Kassa koppeln', async ({ page }) => {
  await page.goto('/betriebe');
  await expect(page.getByText('Noch kein Betrieb')).toBeVisible();

  await page.getByRole('button', { name: 'Betrieb anlegen' }).click();
  const dialog = page.getByRole('dialog');
  await expect(dialog.getByText('Speisekarten-Datei hierher ziehen oder auswählen')).toBeVisible();
  await dialog.locator('input[type=file]').setInputFiles(MENU_FILE);

  // Ohne Chef kann sich am Tablet niemand anmelden: nach dem Anlegen geht es zuerst zu den Mitarbeitern.
  await expect(page).toHaveURL(/\/b\/[0-9a-f-]{36}\/mitarbeiter$/);
  await expect(page.getByRole('heading', { level: 1, name: 'Mitarbeiter' })).toBeVisible();
  await expect(page.getByText('Beispiel-Imbiss').first()).toBeVisible();
  await expect(page.getByText('Noch kein Mitarbeiter. Lege zuerst einen Chef an.')).toBeVisible();

  // Die Leiste: Alle Betriebe, Kassen, Mitarbeiter, Speisekarte.
  const nav = page.getByRole('navigation', { name: 'Bereiche' }).first();
  for (const label of ['Alle Betriebe', 'Kassen', 'Mitarbeiter', 'Speisekarte']) {
    await expect(nav.getByRole('link', { name: label })).toBeVisible();
  }

  // Kassen ohne Chef: statt "Kassa koppeln" der Hinweis mit dem Weg zu den Mitarbeitern.
  await nav.getByRole('link', { name: 'Kassen' }).click();
  await expect(page.getByRole('heading', { level: 1, name: 'Kassen' })).toBeVisible();
  await expect(page.getByText('Noch keine Kassa gekoppelt.')).toBeVisible();
  await expect(page.getByText('Lege zuerst einen Chef mit PIN an.')).toBeVisible();
  await expect(page.getByRole('button', { name: 'Kassa koppeln' })).toHaveCount(0);
  await page.getByRole('link', { name: 'Zu den Mitarbeitern' }).click();
  await expect(page).toHaveURL(/\/b\/[0-9a-f-]{36}\/mitarbeiter$/);

  await page.getByRole('button', { name: 'Mitarbeiter anlegen' }).click();
  await page.getByRole('dialog').getByLabel('Name').fill('Chefin');
  await page.getByRole('dialog').getByLabel('PIN').fill('1234');
  await page.getByRole('dialog').getByRole('button', { name: 'Anlegen' }).click();
  await expect(page.getByRole('dialog')).toHaveCount(0);
  await expect(row(page, 'Chefin')).toContainText('Chef');

  await nav.getByRole('link', { name: 'Kassen' }).click();
  await expect(page.getByText('Lege zuerst einen Chef mit PIN an.')).toHaveCount(0);
  await page.getByRole('button', { name: 'Kassa koppeln' }).click();
  await expect(page.getByRole('dialog').getByLabel('Name')).toHaveValue('Kassa 1');
  await page.getByRole('dialog').getByRole('button', { name: 'Code erzeugen' }).click();

  const code = page.getByTestId('pairing-code');
  await expect(code).toHaveText(/^\d{4} \d{4}$/);
  await expect(page.getByRole('dialog').getByText(/^gilt noch (14:[3-5]\d|15:00)$/)).toBeVisible();
  await expect(page.getByRole('dialog').getByText('Neues Tablet: Mit Code koppeln')).toBeVisible();
  await expect(
    page.getByRole('dialog').getByText('Tablet mit Speisekarte: Einstellungen, Server, Mit Server verbinden'),
  ).toBeVisible();
  await expect(page.getByRole('dialog').getByText('Am Tablet: Mit Code koppeln')).toHaveCount(0);

  const digits = ((await code.textContent()) ?? '').replace(' ', '');
  const paired = await page.request.post('/api/device/pair', {
    headers: HEADERS,
    data: { code: digits, previousBusinessId: null, appVersion: '1.2.0', deviceModel: 'Redmi Pad Pro' },
  });
  expect(paired.ok()).toBe(true);

  // Die Liste lädt bei offenem Dialog alle 3 Sekunden neu.
  await expect(page.getByRole('dialog').getByText('Verbunden', { exact: true })).toBeVisible({ timeout: 8000 });
  await page.getByRole('dialog').getByRole('button', { name: 'Fertig' }).click();
  await expect(page.getByRole('dialog')).toHaveCount(0);
  await expect(row(page, 'Kassa 1')).toContainText('Verbunden');
  await expect(row(page, 'Kassa 1')).toContainText('1.2.0');
  await expect(row(page, 'Kassa 1')).toContainText('zuletzt gesehen');

  await page.goto('/betriebe');
  await expect(page.getByRole('link', { name: /Beispiel-Imbiss/ })).toContainText(/\d+ Artikel/);
  await expect(page.getByRole('link', { name: /Beispiel-Imbiss/ })).toContainText('1 Kassa');
});

test('ungültige Datei zeigt die Zahl und den Wortlaut der Probleme', async ({ page }) => {
  const res = await page.request.post('/api/admin/businesses', {
    headers: HEADERS,
    data: { menuFile: readFileSync(INVALID_FILE, 'utf8') },
  });
  expect(res.status()).toBe(422);
  const { problems } = (await res.json()) as { problems: string[] };
  expect(problems.length).toBeGreaterThan(3);

  await page.goto('/betriebe');
  await page.getByRole('button', { name: 'Betrieb anlegen' }).click();
  const dialog = page.getByRole('dialog');
  await dialog.locator('input[type=file]').setInputFiles(INVALID_FILE);
  await expect(dialog.getByText(`Die Datei hat ${problems.length} Probleme`)).toBeVisible();
  for (const p of problems) await expect(dialog.getByText(p, { exact: true })).toBeVisible();
  await expect(page).toHaveURL(/\/betriebe$/);

  // Keine .json-Datei: gar nicht erst senden.
  await dialog.locator('input[type=file]').setInputFiles({ name: 'karte.pdf', mimeType: 'application/pdf', buffer: Buffer.from('x') });
  await expect(dialog.getByText('Das ist keine .json-Datei. Wähle die Speisekarten-Datei aus.')).toBeVisible();
});

test('zweite Person mit PIN 1234 zeigt "Diese PIN ist schon vergeben."', async ({ page }) => {
  const b = await createBusiness(page);
  await createStaff(page, b.id, 'Chefin', 'chef', '1234');
  await page.goto(`/b/${b.id}/mitarbeiter`);

  await page.getByRole('button', { name: 'Mitarbeiter anlegen' }).click();
  const dialog = page.getByRole('dialog');
  await dialog.getByLabel('Name').fill('Aushilfe');
  await dialog.getByLabel('PIN').fill('1234');
  await dialog.getByRole('button', { name: 'Anlegen' }).click();

  await expect(dialog.getByLabel('PIN')).toHaveAccessibleDescription(/Diese PIN ist schon vergeben\./);
  await expect(dialog.getByLabel('PIN')).toHaveAttribute('aria-invalid', 'true');
  await expect(dialog).toBeVisible();

  // Mit einer anderen PIN klappt es, und die Person steht in der Liste.
  await dialog.getByLabel('PIN').fill('4321');
  await dialog.getByRole('button', { name: 'Anlegen' }).click();
  await expect(dialog).toHaveCount(0);
  await expect(row(page, 'Aushilfe')).toContainText('Mitarbeiter');
});

test('PIN mit Buchstaben oder falscher Länge wird am Feld abgewiesen, ohne zu senden', async ({ page }) => {
  const b = await createBusiness(page);
  await page.goto(`/b/${b.id}/mitarbeiter`);
  const sent: string[] = [];
  page.on('request', (req) => {
    if (req.method() !== 'GET') sent.push(req.url());
  });
  await page.getByRole('button', { name: 'Mitarbeiter anlegen' }).click();
  const dialog = page.getByRole('dialog');
  await expect(dialog.getByLabel('PIN')).toHaveAttribute('inputmode', 'numeric');
  await expect(dialog.getByLabel('PIN')).toHaveAttribute('maxlength', '4');
  await expect(dialog.getByLabel('PIN')).toHaveAttribute('autocomplete', 'off');
  await dialog.getByLabel('Name').fill('Chefin');
  await dialog.getByLabel('PIN').fill('12');
  await dialog.getByRole('button', { name: 'Anlegen' }).click();
  await expect(dialog.getByLabel('PIN')).toHaveAccessibleDescription(/genau vier Ziffern/);
  expect(sent).toEqual([]);
});

test('einzigen Chef stilllegen zeigt "Mindestens ein Chef muss bleiben."', async ({ page }) => {
  const b = await createBusiness(page);
  await createStaff(page, b.id, 'Chefin', 'chef', '1234');
  await page.goto(`/b/${b.id}/mitarbeiter`);

  await row(page, 'Chefin').getByRole('button', { name: 'Stilllegen' }).click();
  await expect(toastText(page, 'Mindestens ein Chef muss bleiben.')).toBeVisible();
  // Zurückgerollt: die Person ist weiter aktiv.
  await expect(row(page, 'Chefin').getByRole('button', { name: 'Stilllegen' })).toBeVisible();
  await expect(row(page, 'Chefin')).not.toContainText('Stillgelegt');
});

test('stilllegen und "Rückgängig" stellt die Person wieder her', async ({ page }) => {
  const b = await createBusiness(page);
  await createStaff(page, b.id, 'Chefin', 'chef', '1234');
  await createStaff(page, b.id, 'Aushilfe', 'staff', '4321');
  await page.goto(`/b/${b.id}/mitarbeiter`);

  await row(page, 'Aushilfe').getByRole('button', { name: 'Stilllegen' }).click();
  await expect(row(page, 'Aushilfe')).toContainText('Stillgelegt');
  const toast = toastText(page, 'Aushilfe ist stillgelegt.');
  await expect(toast).toBeVisible();

  await page.getByRole('button', { name: 'Rückgängig' }).click();
  await expect(row(page, 'Aushilfe')).not.toContainText('Stillgelegt');
  await expect(page.getByRole('button', { name: 'Rückgängig' })).toHaveCount(0);

  const list = await page.request.get(`/api/admin/businesses/${b.id}/staff`);
  const { staff } = (await list.json()) as { staff: { name: string; archived: boolean }[] };
  expect(staff.find((s) => s.name === 'Aushilfe')?.archived).toBe(false);

  // Stillgelegte stehen am Ende und lassen sich wieder einsetzen.
  await row(page, 'Aushilfe').getByRole('button', { name: 'Stilllegen' }).click();
  await expect(row(page, 'Aushilfe')).toContainText('Stillgelegt');
  await page.getByRole('button', { name: 'Wieder einsetzen' }).click();
  await expect(row(page, 'Aushilfe')).not.toContainText('Stillgelegt');
});

test('Person bearbeiten: Name, Rolle und PIN neu setzen', async ({ page }) => {
  const b = await createBusiness(page);
  await createStaff(page, b.id, 'Chefin', 'chef', '1234');
  await createStaff(page, b.id, 'Aushilfe', 'staff', '4321');
  await page.goto(`/b/${b.id}/mitarbeiter`);

  await row(page, 'Aushilfe').getByRole('button', { name: 'Bearbeiten' }).click();
  const dialog = page.getByRole('dialog');
  await expect(dialog.getByLabel('Name')).toHaveValue('Aushilfe');
  await dialog.getByLabel('Name').fill('Lehrling');
  await dialog.getByLabel('PIN neu setzen').fill('1234');
  await dialog.getByRole('button', { name: 'Speichern' }).click();
  await expect(dialog.getByLabel('PIN neu setzen')).toHaveAccessibleDescription(/Diese PIN ist schon vergeben\./);
  await dialog.getByLabel('PIN neu setzen').fill('5555');
  await dialog.getByRole('button', { name: 'Speichern' }).click();
  await expect(dialog).toHaveCount(0);
  await expect(row(page, 'Lehrling')).toBeVisible();

  // Die einzige Chefin lässt sich nicht zur Mitarbeiterin machen: die Meldung steht im Dialog.
  await row(page, 'Chefin').getByRole('button', { name: 'Bearbeiten' }).click();
  await dialog.getByLabel('Mitarbeiter', { exact: true }).check();
  await dialog.getByRole('button', { name: 'Speichern' }).click();
  await expect(dialog.getByText('Mindestens ein Chef muss bleiben.')).toBeVisible();
});

test('sperren zeigt "Gesperrt", aufheben zeigt wieder "Verbunden"', async ({ page }) => {
  const b = await createBusiness(page);
  await createStaff(page, b.id, 'Chefin', 'chef', '1234');
  await pairRegister(page, b.id, 'Theke');
  await page.goto(`/b/${b.id}/kassen`);
  await expect(row(page, 'Theke')).toContainText('Verbunden');

  await row(page, 'Theke').getByRole('button', { name: 'Sperren' }).click();
  const dialog = page.getByRole('dialog');
  await expect(dialog.getByText('Diese Kassa gleicht dann nicht mehr ab. Bonieren geht am Tablet weiter.')).toBeVisible();
  await dialog.getByRole('button', { name: 'Sperren' }).click();
  await expect(dialog).toHaveCount(0);
  await expect(row(page, 'Theke')).toContainText('Gesperrt');

  // Ohne Rückfrage.
  await row(page, 'Theke').getByRole('button', { name: 'Sperre aufheben' }).click();
  await expect(row(page, 'Theke')).toContainText('Verbunden');
  await expect(row(page, 'Theke')).not.toContainText('Gesperrt');
  const list = await page.request.get(`/api/admin/businesses/${b.id}/registers`);
  const { registers } = (await list.json()) as { registers: { blocked: boolean }[] };
  expect(registers[0]?.blocked).toBe(false);
});

test('Speisekarte: Zahlen, Kategorien und neu einspielen', async ({ page }) => {
  const b = await createBusiness(page);
  await page.goto(`/b/${b.id}/speisekarte`);
  await expect(page.getByRole('heading', { level: 1, name: 'Speisekarte' })).toBeVisible();
  await expect(page.getByText(/^\d+ Artikel$/).first()).toBeVisible();
  await expect(row(page, 'Bowls')).toContainText(/\d+ Artikel/);
  await expect(row(page, 'Getränke')).toContainText(/\d+ Artikel/);

  await page.getByRole('button', { name: 'Speisekarte neu einspielen' }).click();
  const dialog = page.getByRole('dialog');
  await expect(
    dialog.getByText('Die Datei gewinnt bei allem, was in ihr steht, auch bei Preisen. Favoriten, "Im Verkauf" und Fotos bleiben.'),
  ).toBeVisible();

  // Eine ungültige Datei bleibt im Dialog.
  await dialog.locator('input[type=file]').setInputFiles(INVALID_FILE);
  await dialog.getByRole('button', { name: 'Neu einspielen' }).click();
  await expect(dialog.getByText(/Die Datei hat \d+ Probleme/)).toBeVisible();

  await dialog.locator('input[type=file]').setInputFiles(MENU_FILE);
  await dialog.getByRole('button', { name: 'Neu einspielen' }).click();
  await expect(dialog).toHaveCount(0);
  // Der Hinweis erscheint erst nach dem Schließen des Dialogs.
  await expect(toastText(page, '0 neu, 0 geändert, 0 stillgelegt')).toBeVisible();
});

test('Installationsdatei: nach dem Hochladen über die Schnittstelle steht sie in der Liste, zurückziehen entfernt den Link', async ({
  page,
  context,
}) => {
  await context.grantPermissions(['clipboard-read', 'clipboard-write']);
  await page.goto('/installationsdateien');
  await expect(page.getByRole('heading', { level: 1, name: 'Installationsdateien' })).toBeVisible();
  await expect(page.getByText('Noch keine Installationsdatei.')).toBeVisible();

  const body = Buffer.concat([Buffer.from([0x50, 0x4b, 0x03, 0x04]), randomBytes(5000)]);
  const up = await page.request.put('/api/releases/9.8.7?build=3', {
    headers: { Authorization: `Bearer ${E2E_RELEASE_TOKEN}`, 'Content-Type': 'application/vnd.android.package-archive' },
    data: body,
  });
  expect(up.status()).toBe(201);
  const uploaded = (await up.json()) as { sha256: string; downloadPath: string };

  await page.reload();
  const item = row(page, '9.8.7');
  await expect(item).toContainText('Build 3');
  await expect(item).toContainText('0,0 MB');
  await expect(item).toContainText(uploaded.sha256.slice(0, 12));
  await expect(item).not.toContainText(uploaded.sha256.slice(0, 13));

  await item.getByRole('button', { name: 'Link kopieren' }).click();
  await expect(toastText(page, 'Link kopiert.')).toBeVisible();
  const link = await page.evaluate(() => navigator.clipboard.readText());
  expect(link).toBe(`${new URL(page.url()).origin}${uploaded.downloadPath}`);
  expect((await page.request.get(link)).status()).toBe(200);

  await item.getByRole('button', { name: 'Zurückziehen' }).click();
  const dialog = page.getByRole('dialog');
  await dialog.getByRole('button', { name: 'Zurückziehen' }).click();
  await expect(dialog).toHaveCount(0);
  await expect(item).toContainText('Zurückgezogen');
  await expect(item.getByRole('button', { name: 'Link kopieren' })).toHaveCount(0);
  expect((await page.request.get(link)).status()).toBe(404);
});

test('Dialog: Escape und Klick auf den Rand schließen, der Fokus geht zurück', async ({ page }) => {
  const b = await createBusiness(page);
  await page.goto(`/b/${b.id}/mitarbeiter`);
  const opener = page.getByRole('button', { name: 'Mitarbeiter anlegen' });

  await opener.click();
  const dialog = page.getByRole('dialog');
  await expect(dialog).toBeVisible();
  await expect(dialog.getByLabel('Name')).toBeFocused();
  await page.keyboard.press('Escape');
  await expect(dialog).toHaveCount(0);
  await expect(opener).toBeFocused();

  await opener.click();
  await expect(dialog).toBeVisible();
  await page.mouse.click(8, 8);
  await expect(dialog).toHaveCount(0);

  // Der Fokus bleibt im Dialog.
  await opener.click();
  for (let i = 0; i < 12; i += 1) {
    await page.keyboard.press('Tab');
    expect(await page.evaluate(() => document.activeElement?.closest('dialog') !== null)).toBe(true);
  }
});

test('Hinweis: bleibt stehen, solange die Maus darauf ruht, auch wenn ein neuer Hinweis den alten ersetzt', async ({ page }) => {
  const b = await createBusiness(page);
  await createStaff(page, b.id, 'Chefin', 'chef', '1234');
  await createStaff(page, b.id, 'Anna', 'staff', '4321');
  await createStaff(page, b.id, 'Berta', 'staff', '5678');
  await page.goto(`/b/${b.id}/mitarbeiter`);
  await page.clock.install();

  // Ohne Maus verschwindet der Hinweis nach 7 Sekunden.
  await row(page, 'Anna').getByRole('button', { name: 'Stilllegen' }).click();
  const undo = page.getByRole('button', { name: 'Rückgängig' });
  await expect(undo).toBeVisible();
  await page.clock.runFor(8000);
  await expect(undo).toHaveCount(0);

  // Die Maus ruht auf dem Hinweis, ein zweiter ersetzt den ersten: die Zeit läuft nicht weiter.
  await row(page, 'Berta').getByRole('button', { name: 'Stilllegen' }).click();
  await expect(toastText(page, 'Berta ist stillgelegt.')).toBeVisible();
  await undo.hover();
  await row(page, 'Anna').getByRole('button', { name: 'Wieder einsetzen' }).focus();
  await page.keyboard.press('Enter');
  await row(page, 'Anna').getByRole('button', { name: 'Stilllegen' }).focus();
  await page.keyboard.press('Enter');
  await expect(toastText(page, 'Anna ist stillgelegt.')).toBeVisible();
  await page.clock.runFor(8000);
  await expect(toastText(page, 'Anna ist stillgelegt.')).toBeVisible();

  // Maus weg: nach der Restzeit verschwindet er.
  await page.mouse.move(5, 5);
  await page.clock.runFor(8000);
  await expect(undo).toHaveCount(0);
});

test('Kopplungscode läuft ab: "Der Code ist abgelaufen." mit neuem Code', async ({ page }) => {
  const b = await createBusiness(page);
  await createStaff(page, b.id, 'Chefin', 'chef', '1234');
  await page.goto(`/b/${b.id}/kassen`);
  await page.clock.install();
  await page.getByRole('button', { name: 'Kassa koppeln' }).click();
  await page.getByRole('dialog').getByRole('button', { name: 'Code erzeugen' }).click();
  const code = page.getByTestId('pairing-code');
  await expect(code).toBeVisible();
  const first = await code.textContent();

  await page.clock.fastForward('15:05');
  await expect(page.getByText('Der Code ist abgelaufen.')).toBeVisible();
  await expect(code).toHaveCount(0);
  // Der Server rechnet mit der echten Uhr, die Seite mit der vorgestellten: der neue Code gilt ab der Uhr der Seite.
  const browserNow = await page.evaluate(() => Date.now());
  await page.route('**/pairing-codes', async (route) => {
    const res = await route.fetch();
    const body = (await res.json()) as { code: string };
    await route.fulfill({ response: res, json: { ...body, expiresAt: new Date(browserNow + 15 * 60_000).toISOString() } });
  });
  await page.getByRole('button', { name: 'Neuen Code erzeugen' }).click();
  await expect(code).toHaveText(/^\d{4} \d{4}$/);
  expect(await code.textContent()).not.toBe(first);
});

test('Server antwortet no_chef: der Satz steht im Dialog', async ({ page }) => {
  const b = await createBusiness(page);
  // Die Seite glaubt an eine Chefin (etwa eben in einem anderen Fenster stillgelegt), der Server kennt keine.
  await page.route(`**/api/admin/businesses/${b.id}/staff`, (route) =>
    route.fulfill({ json: { staff: [{ id: '22222222-2222-4222-8222-222222222222', name: 'Chefin', role: 'chef', archived: false }] } }),
  );
  await page.goto(`/b/${b.id}/kassen`);
  await page.getByRole('button', { name: 'Kassa koppeln' }).click();
  await page.getByRole('dialog').getByRole('button', { name: 'Code erzeugen' }).click();
  await expect(page.getByRole('dialog').getByRole('alert')).toHaveText('Lege zuerst einen Chef mit PIN an.');
  await expect(page.getByTestId('pairing-code')).toHaveCount(0);
});

test('Kassen in der Liste, aber kein Chef mehr: Hinweis statt "Kassa koppeln" im Kopf', async ({ page }) => {
  const b = await createBusiness(page);
  await createStaff(page, b.id, 'Chefin', 'chef', '1234');
  await pairRegister(page, b.id, 'Theke');
  await page.route(`**/api/admin/businesses/${b.id}/staff`, (route) => route.fulfill({ json: { staff: [] } }));
  await page.goto(`/b/${b.id}/kassen`);
  await expect(row(page, 'Theke')).toContainText('Verbunden');
  await expect(page.getByText('Lege zuerst einen Chef mit PIN an.')).toBeVisible();
  await expect(page.getByRole('button', { name: 'Kassa koppeln' })).toHaveCount(0);
  await page.getByRole('link', { name: 'Zu den Mitarbeitern' }).click();
  await expect(page).toHaveURL(new RegExp(`/b/${b.id}/mitarbeiter$`));
});

test('ein Chef sieht nur seinen Betrieb, keine Betriebe und keine Installationsdateien', async ({ page }) => {
  const b = await createBusiness(page);
  // Die Sitzung des Anbieters, die Antwort auf "wer bin ich" wird zum Chef umgeschrieben.
  await page.route('**/api/auth/me', (route) =>
    route.fulfill({ json: { user: { id: '11111111-1111-4111-8111-111111111111', email: 'chef@example.com', role: 'chef', businessId: b.id } } }),
  );
  await page.goto('/betriebe');
  await expect(page).toHaveURL(new RegExp(`/b/${b.id}/kassen$`));
  const nav = page.getByRole('navigation', { name: 'Bereiche' }).first();
  await expect(nav.getByRole('link', { name: 'Kassen' })).toBeVisible();
  await expect(nav.getByRole('link', { name: 'Speisekarte' })).toBeVisible();
  await expect(page.getByRole('link', { name: 'Alle Betriebe' })).toHaveCount(0);
  await expect(page.getByRole('link', { name: 'Installationsdateien' })).toHaveCount(0);
  await expect(page.getByRole('button', { name: 'Speisekarte neu einspielen' })).toHaveCount(0);

  await page.goto('/installationsdateien');
  await expect(page).toHaveURL(new RegExp(`/b/${b.id}/kassen$`));
});

test('abgelaufene Sitzung führt zur Anmeldung, unbekannter Betrieb zeigt "Diesen Betrieb gibt es nicht."', async ({ page }) => {
  await page.goto('/b/6f1c5b9e-3d1a-4a52-9a53-2d0b6c2f7d11/kassen');
  await expect(page.getByText('Diesen Betrieb gibt es nicht.')).toBeVisible();
  await expect(page.getByRole('navigation', { name: 'Bereiche' }).first()).toBeVisible();
  await page.goto('/b/kein-betrieb/mitarbeiter');
  await expect(page.getByText('Diesen Betrieb gibt es nicht.')).toBeVisible();

  await page.goto('/betriebe');
  await expect(page.getByRole('list', { name: 'Betriebe' })).toBeVisible();
  await page.context().clearCookies();
  await page.getByRole('link', { name: 'Installationsdateien' }).first().click();
  await expect(page).toHaveURL(/\/anmelden$/);
});

test('alle fünf Seiten bei 390 px ohne waagrechtes Scrollen', async ({ page }) => {
  const b = await createBusiness(page);
  await createStaff(page, b.id, 'Chefin mit einem ziemlich langen Namen', 'chef', '1234');
  await pairRegister(page, b.id, 'Kassa mit langem Namen am Eck');
  await page.request.put('/api/releases/9.8.8?build=4', {
    headers: { Authorization: `Bearer ${E2E_RELEASE_TOKEN}`, 'Content-Type': 'application/vnd.android.package-archive' },
    data: Buffer.concat([Buffer.from([0x50, 0x4b, 0x03, 0x04]), randomBytes(100)]),
  });

  for (const width of [390, 360]) {
    await page.setViewportSize({ width, height: 844 });
    const pages: [string, string, string][] = [
      ['/betriebe', 'Betriebe', 'Beispiel-Imbiss'],
      [`/b/${b.id}/speisekarte`, 'Speisekarte', 'Bowls'],
      [`/b/${b.id}/mitarbeiter`, 'Mitarbeiter', 'Chefin mit einem ziemlich langen Namen'],
      [`/b/${b.id}/kassen`, 'Kassen', 'Kassa mit langem Namen am Eck'],
      ['/installationsdateien', 'Installationsdateien', 'Version 9.8.8'],
    ];
    for (const [path, title, content] of pages) {
      await page.goto(path);
      await expect(page.getByRole('heading', { level: 1, name: title })).toBeVisible();
      await expect(page.getByText(content).first()).toBeVisible();
      await noHorizontalScroll(page, `${path} bei ${width}`);
    }
    // Auch die Dialoge.
    await page.goto(`/b/${b.id}/kassen`);
    await page.getByRole('button', { name: 'Kassa koppeln' }).click();
    await expect(page.getByRole('dialog')).toBeVisible();
    await noHorizontalScroll(page, `Kopplungsdialog bei ${width}`);
    await page.keyboard.press('Escape');
  }
});
