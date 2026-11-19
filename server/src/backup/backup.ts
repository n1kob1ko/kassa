import { execFile } from 'node:child_process';
import { createReadStream } from 'node:fs';
import { mkdtemp, rm, stat } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { promisify } from 'node:util';
import type { FastifyBaseLogger } from 'fastify';
import pg from 'pg';
import type { AppDeps } from '../app.js';
import type { Db } from '../db/db.js';
import { withSystem } from '../db/tenant.js';

const execFileAsync = promisify(execFile);

const ZONE = 'Europe/Vienna';
const FROM_HOUR = 3;
const KEEP = 14;
const PREFIX = 'backups/';
const DUMP_TIMEOUT_MS = 30 * 60 * 1000;
const MAX_ERROR_CHARS = 500;

export type BackupResult = 'done' | 'not_due' | 'failed';
export type BackupLog = Pick<FastifyBaseLogger, 'warn' | 'error'>;
export type BackupOptions = { pgDumpPath?: string; log?: BackupLog };

/** Pro Datenbank läuft höchstens eine Sicherung zugleich: Der Stundentakt kann eine lange Sicherung überholen. */
const running = new WeakSet<Db>();

/** Tag (`YYYY-MM-DD`) und Stunde der Uhr in Wien. */
function viennaClock(at: Date): { day: string; hour: number } {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: ZONE,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(at);
  const get = (t: string) => parts.find((p) => p.type === t)!.value;
  return { day: `${get('year')}-${get('month')}-${get('day')}`, hour: Number(get('hour')) };
}

/** Verbindungsdaten für pg_dump als PG-Variablen: Nichts davon steht in der Befehlszeile (sichtbar in der Prozessliste). */
function pgEnv(databaseUrl: string): NodeJS.ProcessEnv {
  const env: NodeJS.ProcessEnv = {};
  for (const [k, v] of Object.entries(process.env)) if (!k.startsWith('PG')) env[k] = v;
  const u = new URL(databaseUrl);
  env.PGHOST = u.hostname.replace(/^\[|\]$/g, '');
  if (u.port) env.PGPORT = u.port;
  if (u.username) env.PGUSER = decodeURIComponent(u.username);
  if (u.password) env.PGPASSWORD = decodeURIComponent(u.password);
  const database = decodeURIComponent(u.pathname.replace(/^\//, ''));
  if (database) env.PGDATABASE = database;
  const ssl = u.searchParams.get('sslmode');
  if (ssl) env.PGSSLMODE = ssl;
  return env;
}

/** Streicht Adresse und Passwort aus einer Meldung und kürzt sie. */
function scrub(message: string, databaseUrl: string): string {
  let out = message;
  const secrets = [databaseUrl];
  try {
    const u = new URL(databaseUrl);
    secrets.push(u.password, decodeURIComponent(u.password));
  } catch {
    // keine Adresse, nichts weiter zu streichen
  }
  for (const s of secrets.sort((x, y) => y.length - x.length)) {
    if (s !== '') out = out.split(s).join('…');
  }
  out = out.replace(/([a-z][a-z0-9+.-]*:\/\/)[^\s/@]*@/gi, '$1…@');
  return out.trim().slice(0, MAX_ERROR_CHARS);
}

function failureText(err: unknown): string {
  const e = err as { stderr?: unknown; message?: unknown };
  const stderr = typeof e.stderr === 'string' ? e.stderr.trim() : '';
  if (stderr !== '') return stderr;
  return typeof e.message === 'string' && e.message !== '' ? e.message : 'unbekannter Fehler';
}

/** Löscht alle gelungenen Sicherungen bis auf die jüngsten 14, erst das Objekt, dann die Zeile. Ein Fehler steht im Protokoll und bricht nichts ab. */
async function prune(deps: AppDeps, log: BackupLog | undefined): Promise<void> {
  let old: { id: string; storage_key: string | null }[];
  try {
    old = await withSystem(deps.db, async (c) => {
      const r = await c.query<{ id: string; storage_key: string | null }>(
        `select id, storage_key from backups where ok order by day desc, id desc offset $1`,
        [KEEP],
      );
      return r.rows;
    });
  } catch (err) {
    log?.error({ message: (err as Error).message }, 'alte Sicherungen: Liste nicht lesbar');
    return;
  }
  if (old.length === 0) return;
  // Löschen darf nur der Besitzer der Datenbank: kassa_app hat auf `backups` kein delete.
  const owner = new pg.Client({ connectionString: deps.config.databaseUrl });
  try {
    await owner.connect();
  } catch (err) {
    log?.error({ message: scrub((err as Error).message, deps.config.databaseUrl) }, 'alte Sicherungen: keine Verbindung zum Löschen');
    return;
  }
  try {
    for (const row of old) {
      try {
        if (row.storage_key !== null) {
          if (!row.storage_key.startsWith(PREFIX)) continue;
          await deps.files.delete(row.storage_key);
        }
        await owner.query('delete from backups where id = $1 and ok', [row.id]);
      } catch (err) {
        log?.error({ id: row.id, key: row.storage_key, message: scrub((err as Error).message, deps.config.databaseUrl) }, 'alte Sicherung ließ sich nicht löschen');
      }
    }
  } finally {
    await owner.end().catch(() => undefined);
  }
}

/**
 * Sichert die Datenbank, wenn es in Wien 3 Uhr oder später ist und für den heutigen Wiener Tag noch keine Sicherung gelang.
 * Wirft nie: ein Fehler wird zu einer Zeile mit `ok = false` und einer Meldung im Protokoll.
 */
export async function runBackupIfDue(deps: AppDeps, opts: BackupOptions = {}): Promise<BackupResult> {
  const log = opts.log;
  if (running.has(deps.db)) return 'not_due';
  running.add(deps.db);
  const startedAt = deps.now();
  const { day, hour } = viennaClock(startedAt);
  let dir: string | undefined;
  try {
    if (hour < FROM_HOUR) return 'not_due';
    const done = await withSystem(deps.db, (c) => c.query('select 1 from backups where day = $1 and ok', [day]));
    if (done.rowCount! > 0) return 'not_due';

    try {
      dir = await mkdtemp(join(tmpdir(), 'kassa-backup-'));
      const file = join(dir, 'kassa.dump');
      await execFileAsync(opts.pgDumpPath ?? deps.config.pgDumpPath ?? 'pg_dump', ['--format=custom', '--no-password', '--file', file], {
        env: pgEnv(deps.config.databaseUrl),
        timeout: DUMP_TIMEOUT_MS,
        maxBuffer: 1024 * 1024,
        encoding: 'utf8',
      });
      const size = (await stat(file)).size;
      const key = `${PREFIX}kassa-${day}.dump`;
      await deps.files.put(key, createReadStream(file), 'application/octet-stream');
      await withSystem(deps.db, (c) =>
        c.query(
          `insert into backups (day, storage_key, size, ok, started_at, finished_at) values ($1, $2, $3, true, $4, $5)`,
          [day, key, size, startedAt, deps.now()],
        ),
      );
    } catch (err) {
      const message = scrub(failureText(err), deps.config.databaseUrl);
      log?.error({ day, message }, 'sicherung gescheitert');
      try {
        await withSystem(deps.db, (c) =>
          c.query(`insert into backups (day, ok, error, started_at, finished_at) values ($1, false, $2, $3, $4)`, [day, message, startedAt, deps.now()]),
        );
      } catch (rowErr) {
        log?.error({ message: scrub((rowErr as Error).message, deps.config.databaseUrl) }, 'sicherung gescheitert: die Zeile ließ sich nicht schreiben');
      }
      return 'failed';
    }
    await prune(deps, log);
    return 'done';
  } catch (err) {
    // Etwa die Datenbank beim Prüfen der Fälligkeit nicht erreichbar: nie werfen.
    log?.error({ message: scrub((err as Error).message, deps.config.databaseUrl) }, 'sicherung gescheitert');
    return 'failed';
  } finally {
    if (dir !== undefined) await rm(dir, { recursive: true, force: true }).catch(() => undefined);
    running.delete(deps.db);
  }
}

/**
 * `null`, wenn pg_dump mindestens so neu ist wie die Datenbank, sonst ein Satz für das Protokoll
 * (ein älteres pg_dump weigert sich, einen neueren Server zu sichern).
 */
export async function checkPgDump(deps: AppDeps, opts: { pgDumpPath?: string } = {}): Promise<string | null> {
  const path = opts.pgDumpPath ?? deps.config.pgDumpPath ?? 'pg_dump';
  let tool: number;
  try {
    const out = await execFileAsync(path, ['--version'], { timeout: 30_000, encoding: 'utf8' });
    const m = /(\d+)(?:\.\d+)*/.exec(out.stdout.replace(/^[^\d]*/, ''));
    if (!m) return `pg_dump (${path}) nennt keine Version. Die nächtliche Sicherung wird vermutlich scheitern.`;
    tool = Number(m[1]);
  } catch {
    return `pg_dump (${path}) ließ sich nicht starten. Ohne das gibt es keine nächtliche Sicherung.`;
  }
  let server: number;
  try {
    const r = await withSystem(deps.db, (c) => c.query<{ n: number }>(`select current_setting('server_version_num')::int / 10000 as n`));
    server = r.rows[0]!.n;
  } catch {
    return null;
  }
  if (tool < server) {
    return `pg_dump ist Version ${tool}, die Datenbank Version ${server}: die nächtliche Sicherung wird scheitern. Nimm ein pg_dump ab Version ${server} (Einstellung PG_DUMP_PATH).`;
  }
  return null;
}
