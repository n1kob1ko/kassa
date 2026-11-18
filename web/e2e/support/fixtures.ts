import { test as base, expect, type Page } from '@playwright/test';
import { E2E_PROVIDER, E2E_SETUP_TOKEN } from './server';

/**
 * `test` mit einer Prüfung nach jedem Test: kein Fehler im Skript der Seite und keine Meldung in der Konsole,
 * vor allem keine Verletzung der Content-Security-Policy. Erwartete Fehlerantworten (401 bei der Anmeldung)
 * meldet Chromium als "Failed to load resource"; die zählen nicht.
 */
export const test = base.extend<{ pageProblems: string[] }>({
  pageProblems: [
    async ({ page }, use) => {
      const problems: string[] = [];
      page.on('pageerror', (err) => problems.push(`Skriptfehler: ${err.message}`));
      page.on('console', (msg) => {
        if (msg.type() !== 'error' && msg.type() !== 'warning') return;
        const text = msg.text();
        if (/^Failed to load resource: the server responded with a status of 4\d\d/.test(text)) return;
        problems.push(`Konsole (${msg.type()}): ${text}`);
      });
      await use(problems);
      expect(problems, 'Meldungen der Seite').toEqual([]);
    },
    { auto: true },
  ],
});

export { expect };

/**
 * Meldet die Seite als Anbieter an (Cookie im Kontext der Seite). Gibt es das Konto noch nicht (Anmeldung 401
 * `login_failed` und der Einmal-Schlüssel gilt noch), legt der Schlüssel es an. auth.spec.ts läuft zuerst und legt
 * es dabei über die Seite "Einrichten" an. Jede andere Antwort bricht mit ihrem echten Grund ab.
 */
export async function signInAsProvider(page: Page): Promise<void> {
  const headers = { 'X-Kassa-Request': '1' };
  const login = await page.request.post('/api/auth/login', { headers, data: E2E_PROVIDER });
  if (login.ok()) return;
  const loginBody = await login.text();
  const loginCode = login.status() === 401 ? (JSON.parse(loginBody) as { error?: { code?: string } }).error?.code : undefined;
  if (loginCode !== 'login_failed') {
    throw new Error(`Anmeldung als Anbieter gescheitert: ${login.status()} ${loginBody}`);
  }

  const check = await page.request.get(`/api/auth/setup?token=${encodeURIComponent(E2E_SETUP_TOKEN)}`);
  const { valid } = (await check.json()) as { valid?: boolean };
  if (!valid) {
    throw new Error(
      'Anmeldung als Anbieter gescheitert (login_failed), und der Einmal-Schlüssel ist schon verbraucht: ' +
        'das Konto gibt es mit einem anderen Passwort, oder eine Testdatei hat es geändert.',
    );
  }
  const setup = await page.request.post('/api/auth/setup', {
    headers,
    data: { token: E2E_SETUP_TOKEN, ...E2E_PROVIDER },
  });
  if (!setup.ok()) {
    throw new Error(`Anbieter-Konto anlegen gescheitert: ${setup.status()} ${await setup.text()}`);
  }
}
