/**
 * Nur zum Entwickeln, nie Teil des Dienstes: legt in einer leeren, schon migrierten Datenbank einen Anbieter,
 * den Beispiel-Imbiss, eine Chefin mit PIN 1234 und einen Kopplungscode an. Gibt eine Zeile JSON aus:
 * {"businessId":…, "code":…, "cookie":…}. Der Aufruf ist `npx tsx src/dev/seed.ts` mit denselben Umgebungsvariablen
 * wie der Server. `tsconfig.build.json` lässt diesen Ordner aus, `main.ts` kennt ihn nicht.
 */
import { randomBytes } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
import { buildApp } from '../app.js';
import { hashPassword } from '../auth/passwords.js';
import { randomToken } from '../auth/secrets.js';
import { createSession, sessionCookieName } from '../auth/sessions.js';
import { loadConfig } from '../config.js';
import { closeDb, openDb } from '../db/db.js';
import { withSystem } from '../db/tenant.js';
import { createFileStore } from '../storage/file_store.js';

const MENU_FILE = new URL('../../../shared/fixtures/menu/inputs/beispiel-imbiss.json', import.meta.url);

export type SeedResult = { businessId: string; code: string; cookie: string };

/** Weigert sich für jede Adresse außer dem eigenen Rechner, damit nichts in einem echten Dienst landet. */
export function assertLocalUrl(publicUrl: string | undefined): void {
  const local = publicUrl !== undefined && /^http:\/\/(127\.0\.0\.1|localhost)([:/]|$)/.test(publicUrl);
  if (!local) {
    throw new Error('seed legt nur Testdaten an und läuft nur gegen PUBLIC_URL http://127.0.0.1 oder http://localhost.');
  }
}

export async function seed(env: NodeJS.ProcessEnv): Promise<SeedResult> {
  assertLocalUrl(env.PUBLIC_URL);
  const config = loadConfig(env);
  const db = openDb(config);
  const now = () => new Date();
  const app = await buildApp({ config, db, files: createFileStore(config), now });
  try {
    const at = now();
    const cookieName = sessionCookieName(config.publicUrl);
    const hash = await hashPassword(randomBytes(24).toString('hex'), config.passwordCost);
    const session = await withSystem(db, async (c) => {
      const r = await c.query<{ id: string }>(
        `insert into users (email, password_hash, role, business_id, created_at)
         values ('beispiel@example.com', $1, 'provider', null, $2) returning id`,
        [hash, at],
      );
      return createSession(c, r.rows[0]!.id, at);
    });
    const cookie = `${cookieName}=${session}`;
    const headers = { cookie, 'x-kassa-request': '1' };

    const menuFile = await readFile(MENU_FILE, 'utf8');
    const created = await app.inject({ method: 'POST', url: '/api/admin/businesses', headers, payload: { menuFile } });
    if (created.statusCode !== 201) throw new Error(`Betrieb anlegen: ${created.statusCode}`);
    const businessId: string = created.json().business.id;

    const staff = await app.inject({
      method: 'POST',
      url: `/api/admin/businesses/${businessId}/staff`,
      headers,
      payload: { name: 'Chefin', role: 'chef', pin: '1234' },
    });
    if (staff.statusCode !== 201) throw new Error(`Chefin anlegen: ${staff.statusCode}`);

    const code = await app.inject({
      method: 'POST',
      url: `/api/admin/businesses/${businessId}/pairing-codes`,
      headers,
      payload: { name: 'Kassa 1' },
    });
    if (code.statusCode !== 201) throw new Error(`Kopplungscode anlegen: ${code.statusCode}`);
    return { businessId, code: code.json().code, cookie };
  } finally {
    await app.close();
    await closeDb(db);
  }
}

// Nur wenn die Datei selbst gestartet wird, nicht beim Einlesen aus einem Test.
if (process.argv[1] !== undefined && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    process.stdout.write(`${JSON.stringify(await seed(process.env))}\n`);
  } catch (err) {
    process.stderr.write(`${err instanceof Error ? err.message : String(err)}\n`);
    process.exit(1);
  }
}
