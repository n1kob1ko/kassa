import type { Page } from '@playwright/test';
import { expect, signInAsProvider, test } from './support/fixtures';
import { E2E_PROVIDER, E2E_SETUP_TOKEN } from './support/server';

// Der Einmal-Schlüssel gilt genau einmal: erst die Prüfung im Formular, dann das Anlegen, dann der verbrauchte Link.
test.describe.configure({ mode: 'serial' });

const SETUP_URL = `/einrichten?token=${E2E_SETUP_TOKEN}`;

function passwordField(page: Page) {
  return page.getByLabel('Passwort', { exact: true });
}

test('Passwort mit 9 Zeichen zeigt die Meldung am Feld, nichts wird gesendet', async ({ page }) => {
  const sent: string[] = [];
  page.on('request', (req) => {
    if (req.method() !== 'GET') sent.push(`${req.method()} ${req.url()}`);
  });
  await page.goto(SETUP_URL);
  await expect(page.getByRole('heading', { name: 'Konto einrichten' })).toBeVisible();

  await page.getByLabel('E-Mail').fill(E2E_PROVIDER.email);
  await passwordField(page).fill('123456789');
  await page.getByLabel('Passwort wiederholen').fill('123456789');
  await page.getByRole('button', { name: 'Konto anlegen' }).click();

  await expect(passwordField(page)).toHaveAttribute('aria-invalid', 'true');
  await expect(passwordField(page)).toHaveAccessibleDescription(/Das Passwort braucht mindestens 10 Zeichen\./);
  await expect(passwordField(page)).toBeFocused();
  expect(sent).toEqual([]);

  // Zwei verschiedene Passwörter: die Meldung steht am zweiten Feld.
  await passwordField(page).fill('1234567890');
  await page.getByLabel('Passwort wiederholen').fill('1234567899');
  await page.getByRole('button', { name: 'Konto anlegen' }).click();
  await expect(passwordField(page)).not.toHaveAttribute('aria-invalid', 'true');
  await expect(page.getByLabel('Passwort wiederholen')).toHaveAccessibleDescription(/stimmen nicht überein/);
  expect(sent).toEqual([]);
});

test('Einrichten: Konto anlegen und auf "Betriebe" landen', async ({ page }) => {
  await page.goto(SETUP_URL);
  await page.getByLabel('E-Mail').fill(` ${E2E_PROVIDER.email} `);
  await passwordField(page).fill(E2E_PROVIDER.password);
  await page.getByLabel('Passwort wiederholen').fill(E2E_PROVIDER.password);
  await page.getByRole('button', { name: 'Konto anlegen' }).click();

  await expect(page).toHaveURL(/\/betriebe$/);
  await expect(page.getByRole('heading', { level: 1, name: 'Betriebe' })).toBeVisible();
  await expect(page.getByText(E2E_PROVIDER.email).first()).toBeVisible();
});

test('Einrichten mit verbrauchtem Link zeigt "Dieser Link gilt nicht mehr."', async ({ page }) => {
  await page.goto(SETUP_URL);
  await expect(page.getByText('Dieser Link gilt nicht mehr. Bitte einen neuen anfordern.')).toBeVisible();
  await expect(page.getByLabel('E-Mail')).toHaveCount(0);
  await page.getByRole('link', { name: 'Zur Anmeldung' }).click();
  await expect(page).toHaveURL(/\/anmelden$/);

  // Ohne Schlüssel in der Adresse gilt dasselbe.
  await page.goto('/einrichten');
  await expect(page.getByText('Dieser Link gilt nicht mehr. Bitte einen neuen anfordern.')).toBeVisible();
});

test('Abmelden, falsches Passwort zeigt "E-Mail oder Passwort stimmt nicht.", richtiges meldet an', async ({ page }) => {
  await signInAsProvider(page);
  await page.goto('/betriebe');
  await expect(page.getByRole('heading', { level: 1, name: 'Betriebe' })).toBeVisible();

  await page.getByRole('button', { name: 'Abmelden' }).click();
  await expect(page).toHaveURL(/\/anmelden$/);
  await expect(page.getByRole('heading', { name: 'Anmelden' })).toBeVisible();

  await page.getByLabel('E-Mail').fill(E2E_PROVIDER.email);
  await passwordField(page).fill('falsches-passwort');
  await page.getByRole('button', { name: 'Anmelden' }).click();
  await expect(page.getByRole('alert')).toHaveText('E-Mail oder Passwort stimmt nicht.');
  await expect(page).toHaveURL(/\/anmelden$/);

  await passwordField(page).fill(E2E_PROVIDER.password);
  await page.getByRole('button', { name: 'Anmelden' }).click();
  await expect(page).toHaveURL(/\/betriebe$/);
  await expect(page.getByRole('heading', { level: 1, name: 'Betriebe' })).toBeVisible();

  // Die Sitzung hält auch nach dem Neuladen, und / führt angemeldet zu den Betrieben.
  await page.goto('/');
  await expect(page).toHaveURL(/\/betriebe$/);
});

test('nach zu vielen Fehlversuchen nennt die Anmeldung die Wartezeit', async ({ page }) => {
  await page.goto('/anmelden');
  await page.getByLabel('E-Mail').fill('niemand@example.com');
  await passwordField(page).fill('falsches-passwort');
  for (let i = 0; i < 5; i += 1) {
    await page.getByRole('button', { name: 'Anmelden' }).click();
    await expect(page.getByRole('alert')).toHaveText('E-Mail oder Passwort stimmt nicht.');
    await expect(page.getByRole('button', { name: 'Anmelden' })).not.toHaveAttribute('aria-busy', 'true');
  }
  await page.getByRole('button', { name: 'Anmelden' }).click();
  await expect(page.getByRole('alert')).toHaveText('Zu viele Versuche. Bitte in 1 Minute nochmal.');
});

test('Grenze pro Adresse: die Anmeldung zeigt den Satz des Servers', async ({ page }) => {
  await page.route('**/api/auth/login', (route) =>
    route.fulfill({
      status: 429,
      headers: { 'retry-after': '840' },
      json: {
        error: { code: 'too_many_attempts', message: 'Zu viele Versuche. Bitte in 14 Minuten nochmal.' },
        retryAfterSeconds: 60,
      },
    }),
  );
  await page.goto('/anmelden');
  await page.getByLabel('E-Mail').fill('niemand@example.com');
  await passwordField(page).fill('falsches-passwort');
  await page.getByRole('button', { name: 'Anmelden' }).click();
  await expect(page.getByRole('alert')).toHaveText('Zu viele Versuche. Bitte in 14 Minuten nochmal.');
});

test('ohne Anmeldung führt /betriebe nach /anmelden', async ({ page }) => {
  await page.goto('/betriebe');
  await expect(page).toHaveURL(/\/anmelden$/);
  await expect(page.getByRole('heading', { name: 'Anmelden' })).toBeVisible();

  await page.goto('/');
  await expect(page).toHaveURL(/\/anmelden$/);

  // Nach der Anmeldung geht es dorthin zurück, wo man hin wollte.
  await page.goto('/betriebe');
  await page.getByLabel('E-Mail').fill(E2E_PROVIDER.email);
  await passwordField(page).fill(E2E_PROVIDER.password);
  await page.getByRole('button', { name: 'Anmelden' }).click();
  await expect(page).toHaveURL(/\/betriebe$/);
});

test('bei 390 px Breite gibt es kein waagrechtes Scrollen', async ({ page }) => {
  const noHorizontalScroll = async (what: string) => {
    const { scrollWidth, clientWidth } = await page.evaluate(() => ({
      scrollWidth: document.documentElement.scrollWidth,
      clientWidth: document.documentElement.clientWidth,
    }));
    expect(scrollWidth, what).toBeLessThanOrEqual(clientWidth);
  };

  for (const width of [390, 360]) {
    await page.setViewportSize({ width, height: 844 });

    await page.goto('/anmelden');
    await expect(page.getByRole('heading', { name: 'Anmelden' })).toBeVisible();
    await noHorizontalScroll(`/anmelden bei ${width}`);

    await page.goto(SETUP_URL);
    await expect(page.getByText('Dieser Link gilt nicht mehr.', { exact: false })).toBeVisible();
    await noHorizontalScroll(`/einrichten (verbraucht) bei ${width}`);

    // Das Formular gibt es nur mit gültigem Schlüssel; der ist verbraucht, die Prüfung wird hier vorgespielt.
    await page.route('**/api/auth/setup?*', (route) => route.fulfill({ json: { valid: true } }));
    await page.goto(SETUP_URL);
    await page.getByRole('button', { name: 'Konto anlegen' }).click();
    await expect(page.getByLabel('E-Mail')).toHaveAttribute('aria-invalid', 'true');
    await noHorizontalScroll(`/einrichten (Formular mit Meldungen) bei ${width}`);
    await page.unroute('**/api/auth/setup?*');

    await signInAsProvider(page);
    await page.goto('/betriebe');
    await expect(page.getByRole('heading', { level: 1, name: 'Betriebe' })).toBeVisible();
    await noHorizontalScroll(`/betriebe bei ${width}`);
    await page.context().clearCookies();
  }
});

test('die Seite läuft unter der Content-Security-Policy, eingeschleuste Skripte und Stile werden blockiert', async ({
  page,
  pageProblems,
}) => {
  const response = await page.goto('/anmelden');
  expect(response?.headers()['content-security-policy']).toContain("default-src 'self'");
  await expect(page.getByRole('heading', { name: 'Anmelden' })).toBeVisible();

  const result = await page.evaluate(async () => {
    const blocked: string[] = [];
    document.addEventListener('securitypolicyviolation', (e) => blocked.push(e.effectiveDirective));
    const script = document.createElement('script');
    script.textContent = 'window.__eingeschleust = true;';
    document.head.append(script);
    const style = document.createElement('style');
    style.textContent = 'body { display: none; }';
    document.head.append(style);
    await new Promise((r) => setTimeout(r, 100));
    return {
      blocked,
      ran: (window as unknown as { __eingeschleust?: boolean }).__eingeschleust === true,
      bodyVisible: getComputedStyle(document.body).display !== 'none',
    };
  });
  expect(result.ran).toBe(false);
  expect(result.bodyVisible).toBe(true);
  expect(result.blocked).toEqual(expect.arrayContaining(['script-src-elem', 'style-src-elem']));

  // Die Prüfung nach dem Test meldet genau diese zwei Verletzungen; sie sind hier gewollt.
  expect(pageProblems.filter((p) => /Content Security Policy/.test(p))).toHaveLength(2);
  pageProblems.length = 0;
});
