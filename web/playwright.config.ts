import { defineConfig, devices } from '@playwright/test';

// e2e/support/server.ts startet vor allen Tests den gebauten Server und trägt seine Adresse hier ein.
// Die Worker lesen diese Datei nach dem Start neu und finden die Adresse dann in der Umgebung.
const baseURL = process.env.KASSA_E2E_URL;

export default defineConfig({
  testDir: './e2e',
  globalSetup: './e2e/support/server.ts',
  // Alle Tests teilen einen Server und eine Datenbank; der Einmal-Schlüssel gilt nur einmal.
  workers: 1,
  fullyParallel: false,
  forbidOnly: true,
  reporter: [['list']],
  timeout: 30_000,
  use: {
    ...devices['Desktop Chrome'],
    baseURL,
    locale: 'de-AT',
    trace: 'off',
    screenshot: 'off',
    video: 'off',
  },
});
