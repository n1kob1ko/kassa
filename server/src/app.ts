import cookie from '@fastify/cookie';
import Fastify, { type FastifyInstance, type FastifyRequest, type FastifyServerOptions } from 'fastify';
import { installBusinessRoutes } from './admin/businesses.js';
import { installStaffRoutes } from './admin/staff.js';
import { installAuth } from './auth/routes.js';
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

/**
 * Einstellungen für das Protokoll. Die Adresse steht ohne Abfrage darin, weil dort
 * Geheimnisse stehen können (Einmal-Schlüssel beim Einrichten).
 */
export function loggerOptions(stream?: { write(msg: string): void }): FastifyServerOptions['logger'] {
  return {
    level: 'info',
    redact: ['req.headers.authorization', 'req.headers.cookie', 'res.headers["set-cookie"]'],
    serializers: {
      req: (req: FastifyRequest) => ({
        method: req.method,
        url: req.url.split('?')[0],
        host: req.host,
        remoteAddress: req.ip,
      }),
    },
    ...(stream ? { stream } : {}),
  };
}

/** Alles, was Zustand hält (Zähler, Sperren), gehört hierher und nicht in Modul-Variablen: Tests bauen viele Apps. */
export async function buildApp(
  deps: AppDeps,
  opts: { logger?: FastifyServerOptions['logger'] } = {},
): Promise<FastifyInstance> {
  const app = Fastify({ trustProxy: true, bodyLimit: BODY_LIMIT, logger: opts.logger ?? false });
  installErrorHandling(app);
  app.decorate('deps', deps);
  await app.register(cookie);

  app.get('/healthz', async () => ({ ok: true }));
  installAuth(app);
  installBusinessRoutes(app);
  installStaffRoutes(app);

  return app;
}

declare module 'fastify' {
  interface FastifyInstance {
    deps: AppDeps;
  }
}
