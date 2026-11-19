import type { FastifyInstance } from 'fastify';
import { buildApp, loggerOptions } from './app.js';
import { checkPgDump, runBackupIfDue } from './backup/backup.js';
import { startPruning } from './auth/prune.js';
import { configWarnings, loadConfig } from './config.js';
import { closeDb, openDb } from './db/db.js';
import { migrate } from './db/migrate.js';
import { createFileStore } from './storage/file_store.js';

const config = loadConfig(process.env);
await migrate(config.databaseUrl, { appPassword: config.appDbPassword });

// Die App gibt es erst nach der Datenbank. Fehler davor gehen ohne Protokoll von Fastify auf stderr.
let app: FastifyInstance | undefined;
const db = openDb(config, {
  onError: (message) => {
    if (app) app.log.error({ message }, 'Datenbank-Verbindung abgebrochen');
    else console.error(`Datenbank-Verbindung abgebrochen: ${message}`);
  },
});

app = await buildApp(
  { config, db, files: createFileStore(config), now: () => new Date() },
  { logger: loggerOptions() },
);
for (const warning of configWarnings(config)) app.log.warn(warning);

// Alte Fehlversuche und abgelaufene Sitzungen: einmal pro Stunde weg.
const stopPruning = startPruning(db, () => new Date(), (err) =>
  app?.log.error({ message: (err as Error).message }, 'Aufräumen fehlgeschlagen'),
);

// Nächtliche Sicherung: nach dem Start prüfen, nach einer Minute zum ersten Mal, danach jede Stunde.
// Die Zeitgeber halten den Prozess beim Beenden nicht fest.
const timers: NodeJS.Timeout[] = [];
if (!config.backupDisabled) {
  const deps = app.deps;
  const log = app.log;
  const problem = await checkPgDump(deps);
  if (problem) log.warn(problem);
  const tick = () => void runBackupIfDue(deps, { log });
  const first = setTimeout(() => {
    tick();
    const hourly = setInterval(tick, 60 * 60 * 1000);
    hourly.unref();
    timers.push(hourly);
  }, 60 * 1000);
  first.unref();
  timers.push(first);
} else {
  app.log.warn('BACKUP_DISABLED=1: Es gibt keine nächtliche Sicherung.');
}

const stop = async () => {
  for (const t of timers) clearTimeout(t);
  stopPruning();
  await app?.close();
  await closeDb(db);
  process.exit(0);
};
process.on('SIGTERM', stop);
process.on('SIGINT', stop);

await app.listen({ host: '0.0.0.0', port: config.port });
