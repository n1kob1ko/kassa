/**
 * Server für die Browser-Tests (globalSetup von Playwright). Baut nichts selbst: `npm run e2e` baut vorher
 * Server und Seiten. Startet die Test-Datenbank, falls sie noch nicht läuft, legt eine frische Datenbank an
 * und startet den gebauten Server auf einem freien Port. Am Ende stoppt er den Server, löscht die Datenbank
 * und den Temp-Ordner und stoppt den Cluster nur dann, wenn er ihn selbst gestartet hat.
 */
import { execFileSync, spawn, type ChildProcess } from 'node:child_process';
import { randomBytes } from 'node:crypto';
import { existsSync } from 'node:fs';
import { mkdtemp, open, readFile, rm } from 'node:fs/promises';
import { createServer } from 'node:net';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import pg from 'pg';

export const E2E_SETUP_TOKEN = 'e2e-setup-token';
export const E2E_RELEASE_TOKEN = 'e2e-release-token';
/** Das Anbieter-Konto, das auth.spec.ts über "Einrichten" anlegt. */
export const E2E_PROVIDER = { email: 'beispiel@example.com', password: 'beispiel-passwort-123' };

const REPO = fileURLToPath(new URL('../../../', import.meta.url));
const TEST_DB = 'postgres://kassa@127.0.0.1:54329/postgres';
// Dasselbe Passwort wie in server/test/support/db.ts: migrate setzt es für die Rolle im ganzen Cluster,
// ein anderes Passwort würde einen gleichzeitig laufenden Server-Test stören.
const APP_DB_PASSWORD = 'test-app-passwort';

async function clusterRunning(): Promise<boolean> {
  const c = new pg.Client({ connectionString: TEST_DB, connectionTimeoutMillis: 2000 });
  try {
    await c.connect();
    return true;
  } catch {
    return false;
  } finally {
    await c.end().catch(() => undefined);
  }
}

async function admin(sql: string): Promise<void> {
  const c = new pg.Client({ connectionString: TEST_DB });
  await c.connect();
  try {
    await c.query(sql);
  } finally {
    await c.end();
  }
}

function withDatabase(url: string, name: string): string {
  const u = new URL(url);
  u.pathname = `/${name}`;
  return u.toString();
}

function freePort(): Promise<number> {
  return new Promise((resolvePort, reject) => {
    const s = createServer();
    s.once('error', reject);
    s.listen(0, '127.0.0.1', () => {
      const address = s.address();
      const port = typeof address === 'object' && address !== null ? address.port : 0;
      s.close(() => resolvePort(port));
    });
  });
}

async function waitForHealth(url: string, child: ChildProcess, logFile: string): Promise<void> {
  const deadline = Date.now() + 30_000;
  while (Date.now() < deadline) {
    if (child.exitCode !== null) break;
    try {
      const res = await fetch(`${url}/healthz`);
      if (res.ok) return;
    } catch {
      // Der Server lauscht noch nicht.
    }
    await new Promise((r) => setTimeout(r, 100));
  }
  const log = await readFile(logFile, 'utf8').catch(() => '');
  throw new Error(`Der Server für die Browser-Tests ist nicht gestartet.\n${log.slice(-4000)}`);
}

function stopChild(child: ChildProcess): Promise<void> {
  if (child.exitCode !== null) return Promise.resolve();
  return new Promise((resolveStop) => {
    const kill = setTimeout(() => child.kill('SIGKILL'), 5000);
    child.once('exit', () => {
      clearTimeout(kill);
      resolveStop();
    });
    child.kill('SIGTERM');
  });
}

export default async function startE2eServer(): Promise<() => Promise<void>> {
  const serverMain = join(REPO, 'server/dist/main.js');
  const webIndex = join(REPO, 'web/dist/index.html');
  if (!existsSync(serverMain) || !existsSync(webIndex)) {
    throw new Error('Server oder Seiten sind nicht gebaut. Starte die Browser-Tests mit "npm run e2e" in web/.');
  }

  const startedCluster = !(await clusterRunning());
  if (startedCluster) execFileSync(join(REPO, 'server/tool/test-db.sh'), ['start'], { stdio: 'inherit' });

  // Eigene Vorsilbe: die Server-Tests räumen beim Start alle Datenbanken kassa_test_* weg.
  const dbName = `kassa_e2e_${randomBytes(6).toString('hex')}`;
  await admin(`create database ${dbName}`);
  const tmp = await mkdtemp(join(tmpdir(), 'kassa-e2e-'));
  const logFile = join(tmp, 'server.log');
  const log = await open(logFile, 'w');

  const port = await freePort();
  const url = `http://127.0.0.1:${port}`;
  const databaseUrl = withDatabase(TEST_DB, dbName);
  const child = spawn(process.execPath, [serverMain], {
    cwd: REPO,
    env: {
      PATH: process.env.PATH,
      DATABASE_URL: databaseUrl,
      APP_DB_PASSWORD,
      PORT: String(port),
      PUBLIC_URL: url,
      SETUP_TOKEN: E2E_SETUP_TOKEN,
      RELEASE_TOKEN: E2E_RELEASE_TOKEN,
      FILE_DIR: join(tmp, 'files'),
      WEB_DIR: 'web/dist',
    },
    stdio: ['ignore', log.fd, log.fd],
  });

  const teardown = async () => {
    await stopChild(child);
    await log.close().catch(() => undefined);
    await admin(`drop database if exists ${dbName} with (force)`);
    await rm(tmp, { recursive: true, force: true });
    if (startedCluster) execFileSync(join(REPO, 'server/tool/test-db.sh'), ['stop'], { stdio: 'inherit' });
  };

  try {
    await waitForHealth(url, child, logFile);
  } catch (err) {
    await teardown();
    throw err;
  }

  process.env.KASSA_E2E_URL = url;
  process.env.KASSA_E2E_DATABASE_URL = databaseUrl;
  return teardown;
}
