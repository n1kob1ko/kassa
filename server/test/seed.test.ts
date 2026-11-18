import { execFile } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { promisify } from 'node:util';
import { afterEach, beforeEach, describe, expect, test } from 'vitest';
import { assertLocalUrl, seed } from '../src/dev/seed.js';
import { withBusiness } from '../src/db/tenant.js';
import { testApp, type TestApp } from './support/app.js';
import { TEST_APP_PASSWORD } from './support/db.js';

const run = promisify(execFile);

let a: TestApp;
beforeEach(async () => {
  a = await testApp();
});
afterEach(async () => {
  await a.close();
});

function envFor(a: TestApp, publicUrl = 'http://127.0.0.1:3999'): NodeJS.ProcessEnv {
  return {
    PATH: process.env.PATH,
    DATABASE_URL: a.app.deps.config.databaseUrl,
    APP_DB_PASSWORD: TEST_APP_PASSWORD,
    PUBLIC_URL: publicUrl,
    FILE_DIR: a.fileDir,
  };
}

describe('seed', () => {
  test('legt Betrieb, Chefin und Kopplungscode an, der Cookie gilt in der Verwaltung', async () => {
    const r = await seed(envFor(a, 'http://localhost'));
    expect(r.code).toMatch(/^\d{8}$/);
    expect(r.cookie).toMatch(/^kassa_session=[A-Za-z0-9_-]{43}$/);

    const list = await a.app.inject({ method: 'GET', url: '/api/admin/businesses', headers: { cookie: r.cookie } });
    expect(list.statusCode).toBe(200);
    expect(list.json().businesses.map((b: { name: string }) => b.name)).toEqual(['Beispiel-Imbiss']);

    const staff = await withBusiness(a.db, r.businessId, async (c) => (await c.query('select name, role from staff')).rows);
    expect(staff).toEqual([{ name: 'Chefin', role: 'chef' }]);

    a.now.value = new Date();
    const pair = await a.app.inject({
      method: 'POST',
      url: '/api/device/pair',
      payload: { code: r.code, previousBusinessId: null, appVersion: '1.2.0', deviceModel: null },
    });
    expect(pair.statusCode).toBe(200);
    expect(pair.json().businessId).toBe(r.businessId);
  });

  test('weigert sich bei einer Adresse, die nicht der eigene Rechner ist', async () => {
    for (const url of [
      'https://kassa.example.com',
      'http://kassa.example.com',
      'http://127.0.0.1.example.com',
      'http://localhost.example.com',
      undefined,
    ]) {
      expect(() => assertLocalUrl(url)).toThrow(/PUBLIC_URL/);
    }
    for (const url of ['http://127.0.0.1', 'http://127.0.0.1:3000', 'http://localhost', 'http://localhost:8080']) {
      expect(() => assertLocalUrl(url)).not.toThrow();
    }
    await expect(seed(envFor(a, 'https://kassa.example.com'))).rejects.toThrow(/PUBLIC_URL/);
    // Nichts wurde angelegt.
    const n = await a.db.pool.query('select count(*)::int as n from users');
    expect(n.rows[0].n).toBe(0);
  });

  test('als Programm: genau eine Zeile JSON auf stdout, Fehler mit Ende 1 und ohne stdout', async () => {
    const ok = await run('npx', ['tsx', 'src/dev/seed.ts'], { env: envFor(a), cwd: new URL('..', import.meta.url).pathname });
    expect(ok.stdout.endsWith('\n')).toBe(true);
    expect(ok.stdout.trim().split('\n')).toHaveLength(1);
    expect(Object.keys(JSON.parse(ok.stdout)).sort()).toEqual(['businessId', 'code', 'cookie']);

    const refused = await run('npx', ['tsx', 'src/dev/seed.ts'], {
      env: envFor(a, 'https://kassa.example.com'),
      cwd: new URL('..', import.meta.url).pathname,
    }).then(
      () => undefined,
      (e: { code: number; stdout: string; stderr: string }) => e,
    );
    expect(refused?.code).toBe(1);
    expect(refused?.stdout).toBe('');
    expect(refused?.stderr).toMatch(/PUBLIC_URL/);
  });

  test('der Dienst kennt seed nicht: weder main.ts noch der Bau', () => {
    expect(readFileSync(new URL('../src/main.ts', import.meta.url), 'utf8')).not.toMatch(/seed|dev\//);
    expect(readFileSync(new URL('../tsconfig.build.json', import.meta.url), 'utf8')).toMatch(/"exclude":\s*\["src\/dev"\]/);
  });
});
