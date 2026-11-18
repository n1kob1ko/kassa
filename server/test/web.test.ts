import { mkdir, mkdtemp, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { afterAll, beforeAll, describe, expect, test } from 'vitest';
import type { Config } from '../src/config.js';
import { testApp, type TestApp } from './support/app.js';

const INDEX = '<!doctype html><html lang="de"><head><title>Kassa</title></head><body><div id="root"></div></body></html>';
const SCRIPT = 'console.log("kassa");';
const CSP = "default-src 'self'; img-src 'self' data: blob:; object-src 'none'; base-uri 'self'; frame-ancestors 'none'";

let webDir: string;
const apps: TestApp[] = [];
async function fresh(config: Partial<Config> = {}): Promise<TestApp> {
  const a = await testApp({ config: { webDir, ...config } });
  apps.push(a);
  return a;
}

beforeAll(async () => {
  webDir = await mkdtemp(join(tmpdir(), 'kassa-web-'));
  await mkdir(join(webDir, 'assets'));
  await mkdir(join(webDir, 'fonts'));
  await writeFile(join(webDir, 'index.html'), INDEX);
  await writeFile(join(webDir, 'assets', 'index-a1b2c3.js'), SCRIPT);
  await writeFile(join(webDir, 'fonts', 'Figtree-Bold.ttf'), 'schrift');
});
afterAll(async () => {
  for (const a of apps) await a.close();
  await rm(webDir, { recursive: true, force: true });
});

function expectSecurityHeaders(headers: Record<string, unknown>): void {
  expect(headers['x-content-type-options']).toBe('nosniff');
  expect(headers['referrer-policy']).toBe('same-origin');
  expect(headers['x-frame-options']).toBe('DENY');
  expect(headers['content-security-policy']).toBe(CSP);
}

describe('Seiten aus dem gebauten Ordner', () => {
  let t: TestApp;
  beforeAll(async () => {
    t = await fresh();
  });

  test('GET /betriebe liefert index.html, GET /api/x bleibt 404 JSON, GET /laden/x/y bleibt 404 Text', async () => {
    const page = await t.app.inject({ method: 'GET', url: '/betriebe' });
    expect(page.statusCode).toBe(200);
    expect(page.headers['content-type']).toMatch(/^text\/html/);
    expect(page.body).toBe(INDEX);
    expect(page.headers['cache-control']).toBe('no-cache');

    const deep = await t.app.inject({ method: 'GET', url: '/b/123/mitarbeiter?x=1' });
    expect(deep.statusCode).toBe(200);
    expect(deep.body).toBe(INDEX);

    const api = await t.app.inject({ method: 'GET', url: '/api/x' });
    expect(api.statusCode).toBe(404);
    expect(api.headers['content-type']).toMatch(/^application\/json/);
    expect(api.json().error.code).toBe('not_found');

    const apiDeep = await t.app.inject({ method: 'GET', url: '/api/admin/gibt/es/nicht' });
    expect(apiDeep.statusCode).toBe(404);
    expect(apiDeep.json().error.code).toBe('not_found');

    const download = await t.app.inject({ method: 'GET', url: '/laden/x/y' });
    expect(download.statusCode).toBe(404);
    expect(download.headers['content-type']).toMatch(/^text\/plain/);

    const health = await t.app.inject({ method: 'GET', url: '/healthz' });
    expect(health.statusCode).toBe(200);
    expect(health.json()).toEqual({ ok: true });
  });

  test('die Startseite und index.html kommen ohne Zwischenspeicher', async () => {
    for (const url of ['/', '/index.html']) {
      const res = await t.app.inject({ method: 'GET', url });
      expect(res.statusCode, url).toBe(200);
      expect(res.body, url).toBe(INDEX);
      expect(res.headers['cache-control'], url).toBe('no-cache');
    }
  });

  test('Dateien unter /assets/ dürfen ein Jahr im Zwischenspeicher bleiben', async () => {
    const res = await t.app.inject({ method: 'GET', url: '/assets/index-a1b2c3.js' });
    expect(res.statusCode).toBe(200);
    expect(res.body).toBe(SCRIPT);
    expect(res.headers['content-type']).toMatch(/javascript/);
    expect(res.headers['cache-control']).toBe('public, max-age=31536000, immutable');
  });

  test('eine fehlende Datei unter /assets/ oder mit Endung ist 404, nicht die Seite', async () => {
    for (const url of ['/assets/gibt-es-nicht.js', '/favicon.ico']) {
      const res = await t.app.inject({ method: 'GET', url });
      expect(res.statusCode, url).toBe(404);
      expect(res.body, url).not.toBe(INDEX);
    }
  });

  test('ändernde Anfragen auf Seitenadressen bekommen nicht die Seite', async () => {
    const res = await t.app.inject({ method: 'POST', url: '/betriebe', payload: {} });
    expect(res.statusCode).toBe(404);
    expect(res.json().error.code).toBe('not_found');
  });

  test('jede Antwort trägt die Sicherheits-Kopfzeilen', async () => {
    const responses = await Promise.all([
      t.app.inject({ method: 'GET', url: '/betriebe' }),
      t.app.inject({ method: 'GET', url: '/assets/index-a1b2c3.js' }),
      t.app.inject({ method: 'GET', url: '/fonts/Figtree-Bold.ttf' }),
      t.app.inject({ method: 'GET', url: '/healthz' }),
      t.app.inject({ method: 'GET', url: '/api/x' }),
      t.app.inject({ method: 'GET', url: '/api/auth/me' }),
      t.app.inject({ method: 'GET', url: '/laden/x/y' }),
      // Ohne X-Kassa-Request lehnt schon der erste Hook ab: auch diese Antwort trägt die Kopfzeilen.
      t.app.inject({ method: 'POST', url: '/api/auth/login', payload: {} }),
      t.app.inject({
        method: 'POST',
        url: '/api/auth/login',
        headers: { 'x-kassa-request': '1', 'content-type': 'application/json' },
        payload: '{kaputt',
      }),
    ]);
    expect(responses.map((r) => r.statusCode)).toEqual([200, 200, 200, 200, 404, 401, 404, 403, 400]);
    for (const res of responses) {
      expectSecurityHeaders(res.headers);
      // Ohne https gibt es kein HSTS: die Kopfzeile würde lokale Entwicklung auf https zwingen.
      expect(res.headers['strict-transport-security']).toBeUndefined();
    }
  });
});

test('bei https kommt Strict-Transport-Security dazu', async () => {
  const t = await fresh({ publicUrl: 'https://kassa.example.com' });
  for (const url of ['/betriebe', '/api/x']) {
    const res = await t.app.inject({ method: 'GET', url });
    expectSecurityHeaders(res.headers);
    expect(res.headers['strict-transport-security'], url).toBe('max-age=31536000');
  }
});

test('ohne gebauten Ordner startet der Server ohne Seiten, die Kopfzeilen bleiben', async () => {
  for (const dir of [undefined, join(webDir, 'gibt-es-nicht')]) {
    const t = await fresh({ webDir: dir });
    const page = await t.app.inject({ method: 'GET', url: '/betriebe' });
    expect(page.statusCode).toBe(404);
    expect(page.json().error.code).toBe('not_found');
    expectSecurityHeaders(page.headers);

    const health = await t.app.inject({ method: 'GET', url: '/healthz' });
    expect(health.statusCode).toBe(200);
    expectSecurityHeaders(health.headers);
  }
});
