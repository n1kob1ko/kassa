import { buildApp, loggerOptions } from './app.js';
import { loadConfig } from './config.js';
import { closeDb, openDb } from './db/db.js';
import { migrate } from './db/migrate.js';
import { createFileStore } from './storage/file_store.js';

const config = loadConfig(process.env);
await migrate(config.databaseUrl, { appPassword: config.appDbPassword });
const db = openDb(config);

const app = await buildApp(
  { config, db, files: createFileStore(config), now: () => new Date() },
  { logger: loggerOptions() },
);

const stop = async () => {
  await app.close();
  await closeDb(db);
  process.exit(0);
};
process.on('SIGTERM', stop);
process.on('SIGINT', stop);

await app.listen({ host: '0.0.0.0', port: config.port });
