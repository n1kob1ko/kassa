import cookie from '@fastify/cookie';
import Fastify, { type FastifyInstance, type FastifyRequest, type FastifyServerOptions } from 'fastify';
import { installBackupRoutes } from './admin/backups.js';
import { installBusinessRoutes } from './admin/businesses.js';
import { installCustomerRoutes } from './admin/customers.js';
import { installDayRoutes } from './admin/days.js';
import { installDepRoutes } from './admin/dep.js';
import { installItemRoutes } from './admin/items.js';
import { installMonthRoutes } from './admin/months.js';
import { installOverviewRoutes } from './admin/overview.js';
import { installReportRoutes } from './admin/reports.js';
import { installReceiptRoutes } from './admin/receipts.js';
import { installReleaseRoutes } from './admin/releases.js';
import { installRegisterRoutes } from './admin/registers.js';
import { installStaffRoutes } from './admin/staff.js';
import { installTranslationRoutes } from './admin/translations.js';
import { installAuth } from './auth/routes.js';
import { installPairRoutes } from './device/pair.js';
import { installFileRoutes } from './files/routes.js';
import { installPullRoutes } from './device/pull.js';
import { installPushRoutes } from './device/push.js';
import { installReceiptPage } from './public/receipt_page.js';
import { clientAddress } from './client_address.js';
import type { Config } from './config.js';
import type { Db } from './db/db.js';
import { installErrorHandling } from './errors.js';
import type { FileStore } from './storage/file_store.js';
import { registerWeb } from './web.js';

export type AppDeps = {
  config: Config;
  db: Db;
  files: FileStore;
  now: () => Date;
  /** Zufallszahl von 0 bis 99 999 999 für Kopplungscodes. Vorgabe ist crypto.randomInt; Tests ersetzen sie. */
  randomCode?: () => number;
  /** Höchste Größe einer Installationsdatei. Vorgabe 200 MB; Tests setzen eine kleine Grenze. */
  maxReleaseBytes?: number;
};

export const BODY_LIMIT = 1024 * 1024;

/** Zeitgrenzen für Verbindungen in Millisekunden. */
export type Timeouts = {
  /** Die Kopfzeilen einer Anfrage müssen so schnell da sein (Node: server.headersTimeout). */
  headersMs: number;
  /** So lange darf eine Verbindung mitten in einer Anfrage nichts senden (Fastify connectionTimeout, Node: server.timeout). */
  idleMs: number;
  /** So lange darf die ganze Anfrage dauern, Kopfzeilen und Körper (Fastify requestTimeout, Node: server.requestTimeout). */
  requestMs: number;
};

export const DEFAULT_TIMEOUTS: Timeouts = { headersMs: 30_000, idleMs: 60_000, requestMs: 5 * 60_000 };

/**
 * Der Pfad ohne Abfrage. Der geheime Teil eines Installations-Links ist eine Fähigkeit und bleibt aus dem Protokoll:
 * `/laden/<geheim>/kassa-1.2.0.apk` wird zu `/laden/…/kassa-1.2.0.apk`. Ebenso der Schlüssel der Seite eines Bons:
 * alles ab `/beleg/` (in jeder Schreibweise) wird `/beleg/:token`.
 */
export function loggedPath(url: string): string {
  return url
    .split('?')[0]!
    .replace(/^\/laden\/[^/]*/, '/laden/…')
    .replace(/\/beleg\/.*$/is, '/beleg/:token');
}

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
        url: loggedPath(req.url),
        host: req.host,
        // Die Adresse, mit der die Grenzen zählen (CLIENT_IP_HEADER), nicht req.ip: Hinter dem Proxy wäre das der Proxy.
        remoteAddress: req.server?.deps ? clientAddress(req, req.server.deps.config) : req.socket?.remoteAddress,
      }),
    },
    ...(stream ? { stream } : {}),
  };
}

/** Alles, was Zustand hält (Zähler, Sperren), gehört hierher und nicht in Modul-Variablen: Tests bauen viele Apps. */
export async function buildApp(
  deps: AppDeps,
  opts: { logger?: FastifyServerOptions['logger']; timeouts?: Timeouts } = {},
): Promise<FastifyInstance> {
  // Kopfzeilen wie X-Forwarded-For kann jeder Client setzen. Die Adresse des Clients liest clientAddress().
  const timeouts = opts.timeouts ?? DEFAULT_TIMEOUTS;
  const app = Fastify({
    trustProxy: false,
    bodyLimit: BODY_LIMIT,
    logger: opts.logger ?? false,
    connectionTimeout: timeouts.idleMs,
    requestTimeout: timeouts.requestMs,
    // Node prüft die Zeitgrenzen nur in diesem Takt (Vorgabe 30 s): kurz genug für die kürzeste Grenze.
    http: { connectionsCheckingInterval: Math.min(timeouts.headersMs, timeouts.idleMs, 5000) },
  });
  // Fastify kennt keine eigene Einstellung dafür: Die Kopfzeilen müssen vor der ganzen Anfrage fertig sein.
  app.server.headersTimeout = Math.min(timeouts.headersMs, timeouts.requestMs);
  installErrorHandling(app);
  app.decorate('deps', deps);
  // Zuerst: der Hook für die Sicherheits-Kopfzeilen gilt nur für Adressen, die nach ihm dazukommen.
  await registerWeb(app, deps.config.webDir);
  await app.register(cookie);

  // Die öffentliche Seite eines Bons, vor allem anderen: /beleg/… bekommt nie die Seite der Verwaltung.
  installReceiptPage(app);
  app.get('/healthz', async () => ({ ok: true }));
  installAuth(app);
  await installReleaseRoutes(app);
  installBusinessRoutes(app);
  installStaffRoutes(app);
  installCustomerRoutes(app);
  installRegisterRoutes(app);
  installOverviewRoutes(app);
  installReceiptRoutes(app);
  installDayRoutes(app);
  installMonthRoutes(app);
  installItemRoutes(app);
  installTranslationRoutes(app);
  installDepRoutes(app);
  installReportRoutes(app);
  installBackupRoutes(app);
  await installFileRoutes(app);
  // Adressen für das Tablet: Geräte-Schlüssel statt Sitzung, ohne den Schutz für den Browser.
  installPairRoutes(app);
  installPullRoutes(app);
  installPushRoutes(app);

  return app;
}

declare module 'fastify' {
  interface FastifyInstance {
    deps: AppDeps;
  }
}
