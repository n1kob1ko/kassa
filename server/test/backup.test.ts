import { execFile } from 'node:child_process';
import { existsSync } from 'node:fs';
import { chmod, mkdtemp, readdir, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { promisify } from 'node:util';
import pg from 'pg';
import { afterAll, beforeAll, describe, expect, test } from 'vitest';
import { checkPgDump, runBackupIfDue } from '../src/backup/backup.js';
import { withSystem } from '../src/db/tenant.js';
import { testApp, type TestApp } from './support/app.js';
import { createTestDb } from './support/db.js';
import { createProvider, send, siteFor } from './support/admin_data.js';
import { sampleReceipt } from './support/push.js';
import { authed, createChef, type TestUser } from './support/users.js';

const run = promisify(execFile);
const PG_DUMP = '/usr/lib/postgresql/16/bin/pg_dump';
const PG_RESTORE = '/usr/lib/postgresql/16/bin/pg_restore';
const haveDump = existsSync(PG_DUMP) && existsSync(PG_RESTORE);
if (!haveDump) console.warn('pg_dump 16 fehlt: die Tests mit echter Sicherung werden übersprungen.');

let a: TestApp;
let provider: TestUser;
beforeAll(async () => {
  a = await testApp();
  provider = await createProvider(a.app, a.db);
});
afterAll(async () => {
  await a.close();
});

const logs: { level: string; obj: unknown; msg: string }[] = [];
const log = {
  warn: (obj: unknown, msg?: string) => logs.push({ level: 'warn', obj, msg: msg ?? '' }),
  error: (obj: unknown, msg?: string) => logs.push({ level: 'error', obj, msg: msg ?? '' }),
};

const at = (iso: string) => {
  a.now.value = new Date(iso);
};
const backups = () =>
  withSystem(a.db, (c) =>
    c.query<{ day: string; ok: boolean; storage_key: string | null; size: string | null; error: string | null }>(
      `select day::text as day, ok, storage_key, size, error from backups order by id`,
    ),
  ).then((r) => r.rows);
const clearBackups = async () => {
  const owner = new pg.Client({ connectionString: a.app.deps.config.databaseUrl });
  await owner.connect();
  try {
    await owner.query('delete from backups');
  } finally {
    await owner.end();
  }
  await rm(join(a.fileDir, 'backups'), { recursive: true, force: true });
};
const backupFiles = async () => (await readdir(join(a.fileDir, 'backups')).catch(() => [])).sort();

describe('Fälligkeit', () => {
  test('vor 3 Uhr Wiener Zeit: not_due', async () => {
    await clearBackups();
    at('2026-11-19T01:59:00Z'); // 02:59 in Wien (Winterzeit)
    expect(await runBackupIfDue(a.app.deps, { pgDumpPath: '/gibt/es/nicht', log })).toBe('not_due');
    at('2026-07-01T00:59:00Z'); // 02:59 in Wien (Sommerzeit)
    expect(await runBackupIfDue(a.app.deps, { pgDumpPath: '/gibt/es/nicht', log })).toBe('not_due');
    expect(await backups()).toEqual([]);
  });

  test('ab 3 Uhr ist sie fällig (Winter und Sommer)', async () => {
    await clearBackups();
    for (const iso of ['2026-11-19T02:00:00Z', '2026-07-01T01:00:00Z']) {
      at(iso);
      expect(await runBackupIfDue(a.app.deps, { pgDumpPath: '/gibt/es/nicht', log })).toBe('failed');
    }
    await clearBackups();
  });
});

describe.skipIf(!haveDump)('mit echtem pg_dump', () => {
  test('nach 3 Uhr ohne Sicherung: done, Datei in der Ablage, Zeile ok', async () => {
    await clearBackups();
    at('2026-11-19T02:30:00Z');
    expect(await runBackupIfDue(a.app.deps, { pgDumpPath: PG_DUMP, log })).toBe('done');
    const rows = await backups();
    expect(rows).toHaveLength(1);
    expect(rows[0]).toMatchObject({ day: '2026-11-19', ok: true, storage_key: 'backups/kassa-2026-11-19.dump', error: null });
    const file = await readFile(join(a.fileDir, 'backups', 'kassa-2026-11-19.dump'));
    expect(Number(rows[0]!.size)).toBe(file.length);
    expect(file.subarray(0, 5).toString()).toBe('PGDMP');
    // Keine Reste im Ordner für Zwischendateien.
    expect((await readdir(tmpdir())).filter((n) => n.startsWith('kassa-backup-'))).toEqual([]);
  });

  test('zweiter Aufruf am selben Tag: not_due', async () => {
    at('2026-11-19T20:00:00Z');
    expect(await runBackupIfDue(a.app.deps, { pgDumpPath: PG_DUMP, log })).toBe('not_due');
    expect(await backups()).toHaveLength(1);
  });

  test('gleichzeitige Aufrufe: der zweite sagt not_due, es entsteht eine Sicherung', async () => {
    await clearBackups();
    at('2026-11-20T05:00:00Z');
    const [x, y] = await Promise.all([
      runBackupIfDue(a.app.deps, { pgDumpPath: PG_DUMP, log }),
      runBackupIfDue(a.app.deps, { pgDumpPath: PG_DUMP, log }),
    ]);
    expect([x, y].sort()).toEqual(['done', 'not_due']);
    expect(await backups()).toHaveLength(1);
  });

  test('16 Tage hintereinander: 14 Dateien bleiben', async () => {
    await clearBackups();
    for (let d = 1; d <= 16; d++) {
      at(`2026-12-${String(d).padStart(2, '0')}T08:00:00Z`);
      expect(await runBackupIfDue(a.app.deps, { pgDumpPath: PG_DUMP, log })).toBe('done');
    }
    const files = await backupFiles();
    expect(files).toHaveLength(14);
    expect(files[0]).toBe('kassa-2026-12-03.dump');
    expect(files[13]).toBe('kassa-2026-12-16.dump');
    const rows = await backups();
    expect(rows.filter((r) => r.ok)).toHaveLength(14);
    expect(rows.map((r) => r.day)).not.toContain('2026-12-02');
  });

  test('Fehlschläge zählen nicht mit und bleiben stehen; ein Fehler beim Löschen macht heute nicht failed', async () => {
    await clearBackups();
    const failing = {
      ...a.app.deps,
      files: {
        put: a.app.deps.files.put.bind(a.app.deps.files),
        get: a.app.deps.files.get.bind(a.app.deps.files),
        delete: async () => {
          throw new Error('Ablage kaputt');
        },
      },
    };
    for (let d = 1; d <= 15; d++) {
      at(`2027-01-${String(d).padStart(2, '0')}T08:00:00Z`);
      expect(await runBackupIfDue(failing, { pgDumpPath: PG_DUMP, log })).toBe('done');
    }
    // Das Objekt ließ sich nicht löschen: die Zeile bleibt, damit der nächste Lauf es wieder versucht.
    expect((await backups()).filter((r) => r.ok)).toHaveLength(15);
    at('2027-01-16T08:00:00Z');
    expect(await runBackupIfDue(a.app.deps, { pgDumpPath: PG_DUMP, log })).toBe('done');
    expect((await backups()).filter((r) => r.ok)).toHaveLength(14);
    expect(await backupFiles()).toHaveLength(14);
  });

  test('Zurückspielen: die Sicherung in eine leere Datenbank spielen ergibt dieselbe Zeilenzahl in jeder Tabelle', async () => {
    const t = await testApp();
    const target = await createTestDb({ migrated: false });
    try {
      const p = await createProvider(t.app, t.db);
      const s1 = await siteFor(t, p, 'Sicherung Eins');
      const s2 = await siteFor(t, p, 'Sicherung Zwei');
      await send(t, s1, [['receipt', sampleReceipt({ id: '11111111-1111-4111-8111-111111111111', number: 1 })]]);
      await send(t, s2, [
        ['receipt', sampleReceipt({ id: '22222222-2222-4222-8222-222222222221', number: 1 })],
        ['receipt', sampleReceipt({ id: '22222222-2222-4222-8222-222222222222', number: 2 })],
      ]);
      const count = async (url: string) => {
        const c = new pg.Client({ connectionString: url });
        await c.connect();
        try {
          const tables = await c.query<{ tablename: string }>(
            `select tablename from pg_tables where schemaname = 'public' order by tablename`,
          );
          const out: Record<string, number> = {};
          for (const { tablename } of tables.rows) {
            const r = await c.query<{ n: string }>(`select count(*) as n from public."${tablename}"`);
            out[tablename] = Number(r.rows[0]!.n);
          }
          return out;
        } finally {
          await c.end();
        }
      };
      // Gezählt wird vor der Sicherung: Ihre eigene Zeile in `backups` kommt erst danach.
      const before = await count(t.app.deps.config.databaseUrl);
      t.now.value = new Date('2026-11-19T08:00:00Z');
      expect(await runBackupIfDue(t.app.deps, { pgDumpPath: PG_DUMP, log })).toBe('done');
      const dump = join(t.fileDir, 'backups', 'kassa-2026-11-19.dump');

      await run(PG_RESTORE, ['--no-owner', '--exit-on-error', `--dbname=${target.ownerUrl}`, dump]);

      const after = await count(target.ownerUrl);
      // Ein leerer Dump darf nicht bestehen: Zeilen beider Betriebe müssen darin sein.
      expect(before.receipts).toBe(3);
      expect(before.receipt_lines).toBeGreaterThanOrEqual(3);
      expect(Object.keys(after).length).toBeGreaterThan(10);
      expect(after).toEqual(before);
    } finally {
      await target.drop();
      await t.close();
    }
  });

  test('checkPgDump: gleiche oder neuere Hauptversion ist null, eine ältere ein Satz', async () => {
    expect(await checkPgDump(a.app.deps, { pgDumpPath: PG_DUMP })).toBeNull();
    const dir = await mkdtemp(join(tmpdir(), 'kassa-fake-'));
    try {
      const old = join(dir, 'pg_dump');
      await writeFile(old, '#!/bin/sh\necho "pg_dump (PostgreSQL) 12.4"\n');
      await chmod(old, 0o755);
      const msg = await checkPgDump(a.app.deps, { pgDumpPath: old });
      expect(msg).toMatch(/pg_dump/);
      expect(msg).toMatch(/12/);
    } finally {
      await rm(dir, { recursive: true, force: true });
    }
  });
});

describe('Fehler', () => {
  test('pg_dump fehlt: failed, Zeile mit Fehler, kein Wurf, kein Passwort in der Meldung', async () => {
    await clearBackups();
    logs.length = 0;
    const secret = 'Geheim-Wort-4711';
    const url = `postgres://kassa:${secret}@db.example.invalid:5432/kassa?sslmode=require`;
    const deps = { ...a.app.deps, config: { ...a.app.deps.config, databaseUrl: url } };
    at('2026-11-19T08:00:00Z');
    expect(await runBackupIfDue(deps, { pgDumpPath: '/gibt/es/nicht/pg_dump', log })).toBe('failed');
    const rows = await backups();
    expect(rows).toHaveLength(1);
    expect(rows[0]).toMatchObject({ ok: false, storage_key: null });
    expect(rows[0]!.error).toBeTruthy();
    const everything = JSON.stringify([rows, logs]);
    expect(everything).not.toContain(secret);
    expect(everything).not.toContain(url);
    expect(logs.some((l) => l.level === 'error' && l.msg === 'sicherung gescheitert')).toBe(true);
    // Nach einem Fehlschlag ist die Sicherung weiter fällig.
    expect(await runBackupIfDue(deps, { pgDumpPath: '/gibt/es/nicht/pg_dump', log })).toBe('failed');
  });

  test('ein pg_dump, der Passwort und Adresse ausgibt: die Meldung bleibt sauber, die Daten kommen nur über PG-Variablen', async () => {
    await clearBackups();
    logs.length = 0;
    const secret = 'Geheim-Wort-4711';
    const url = `postgres://kassa:${secret}@db.example.invalid:5433/kassadb?sslmode=require`;
    const dir = await mkdtemp(join(tmpdir(), 'kassa-fake-'));
    try {
      const fake = join(dir, 'pg_dump');
      await writeFile(
        fake,
        `#!/bin/sh
{ echo "ARGS: $@"; env | grep '^PG' | sort; } > "${dir}/seen.txt"
echo "pg_dump: error: connection to server at db.example.invalid failed: password $PGPASSWORD for ${url}" >&2
exit 1
`,
      );
      await chmod(fake, 0o755);
      const deps = { ...a.app.deps, config: { ...a.app.deps.config, databaseUrl: url } };
      at('2026-11-19T08:00:00Z');
      expect(await runBackupIfDue(deps, { pgDumpPath: fake, log })).toBe('failed');
      const seen = await readFile(join(dir, 'seen.txt'), 'utf8');
      expect(seen).toContain('--format=custom');
      const argsLine = seen.split('\n')[0]!;
      expect(argsLine).not.toContain(secret);
      expect(argsLine).not.toContain('postgres://');
      expect(argsLine).not.toContain('db.example.invalid');
      expect(seen).toContain('PGHOST=db.example.invalid');
      expect(seen).toContain('PGPORT=5433');
      expect(seen).toContain('PGUSER=kassa');
      expect(seen).toContain(`PGPASSWORD=${secret}`);
      expect(seen).toContain('PGDATABASE=kassadb');
      expect(seen).toContain('PGSSLMODE=require');
      const rows = await backups();
      expect(rows[0]!.ok).toBe(false);
      const everything = JSON.stringify([rows, logs]);
      expect(everything).not.toContain(secret);
      expect(everything).not.toContain('db.example.invalid:5433');
    } finally {
      await rm(dir, { recursive: true, force: true });
    }
  });
});

describe('GET /api/admin/backups/latest', () => {
  const latest = (cookie = provider.cookie) =>
    a.app.inject({ method: 'GET', url: '/api/admin/backups/latest', headers: authed(cookie) });
  const add = (day: string, ok: boolean, o: { size?: number; error?: string; at?: string } = {}) =>
    withSystem(a.db, (c) =>
      c.query(
        `insert into backups (day, storage_key, size, ok, error, started_at, finished_at)
         values ($1, $2, $3, $4, $5, $6, $6)`,
        [day, ok ? `backups/kassa-${day}.dump` : null, o.size ?? null, ok, o.error ?? null, o.at ?? `${day}T03:00:00Z`],
      ),
    );

  test('ohne Sicherung: beides null; Chef bekommt 404', async () => {
    await clearBackups();
    const res = await latest();
    expect(res.statusCode).toBe(200);
    expect(res.json()).toEqual({ latest: null, lastError: null });
    const chef = await createChef(a.db, (await siteFor(a, provider, 'Nur ein Chef')).businessId);
    expect((await latest(chef.cookie)).statusCode).toBe(404);
  });

  test('neueste gelungene mit Größe; ein älterer Fehler zählt nicht, ein neuerer schon', async () => {
    await clearBackups();
    await add('2026-11-17', false, { error: 'alt', at: '2026-11-17T03:00:00Z' });
    await add('2026-11-17', true, { size: 1234, at: '2026-11-17T04:00:00Z' });
    let body = (await latest()).json();
    expect(body.latest).toEqual({ day: '2026-11-17', finishedAt: '2026-11-17T04:00:00.000Z', size: 1234 });
    expect(body.lastError).toBeNull();
    await add('2026-11-18', false, { error: 'pg_dump fehlt', at: '2026-11-18T03:00:00Z' });
    body = (await latest()).json();
    expect(body.latest.day).toBe('2026-11-17');
    expect(body.lastError).toEqual({ at: '2026-11-18T03:00:00.000Z', error: 'pg_dump fehlt' });
  });
});
