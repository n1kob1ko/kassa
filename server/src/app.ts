import Fastify, { type FastifyInstance, type FastifyServerOptions } from 'fastify';
import type { Config } from './config.js';
import type { Db } from './db/db.js';
import { installErrorHandling } from './errors.js';

export type AppDeps = {
  config: Config;
  db: Db;
  /** Wird in Task 9 zum FileStore. */
  files: unknown;
  now: () => Date;
};

export const BODY_LIMIT = 1024 * 1024;

/** Alles, was Zustand hält (Zähler, Sperren), gehört hierher und nicht in Modul-Variablen: Tests bauen viele Apps. */
export async function buildApp(
  deps: AppDeps,
  opts: { logger?: FastifyServerOptions['logger'] } = {},
): Promise<FastifyInstance> {
  const app = Fastify({ trustProxy: true, bodyLimit: BODY_LIMIT, logger: opts.logger ?? false });
  installErrorHandling(app);

  app.get('/healthz', async () => ({ ok: true }));

  app.decorate('deps', deps);
  return app;
}

declare module 'fastify' {
  interface FastifyInstance {
    deps: AppDeps;
  }
}
