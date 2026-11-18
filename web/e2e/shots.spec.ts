import type { Page } from '@playwright/test';
import { signInAsProvider, test } from './support/fixtures';

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

async function shoot(page: Page, name: string) {
  await page.evaluate(() => document.fonts.ready);
  await page.screenshot({ path: `${dir}/${name}.png`, fullPage: true });
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
        await page.goto('/betriebe');
        await page.getByRole('heading', { level: 1, name: 'Betriebe' }).waitFor();
        await shoot(page, `betriebe-${suffix}`);
      });
    });
  }
}
