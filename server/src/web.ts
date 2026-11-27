import { stat } from 'node:fs/promises';
import { relative, resolve, sep } from 'node:path';
import fastifyStatic from '@fastify/static';
import type { FastifyInstance } from 'fastify';

const CONTENT_SECURITY_POLICY =
  "default-src 'self'; img-src 'self' data: blob:; object-src 'none'; base-uri 'self'; frame-ancestors 'none'";
const IMMUTABLE = 'public, max-age=31536000, immutable';

/** Adressen, die der Server selbst beantwortet. Dort gibt es nie die Seite, sondern die eigene 404. */
const SERVER_AREAS = ['/api', '/laden', '/healthz', '/assets', '/beleg'];

/** Eine Datei hat eine Endung aus Buchstaben und Ziffern ("favicon.ico"); ein Zeitraum "2026-01..2026-10" nicht. */
const FILE_ENDING = /\.[A-Za-z0-9]+$/;

function inArea(path: string, area: string): boolean {
  return path === area || path.startsWith(`${area}/`);
}

async function isDirectory(dir: string): Promise<boolean> {
  try {
    return (await stat(dir)).isDirectory();
  } catch {
    return false;
  }
}

/** Vite schreibt einen Prüfwert in jeden Dateinamen unter assets/, eine neue Fassung hat einen neuen Namen. */
function cacheControl(root: string, filePath: string): string {
  return relative(root, filePath).startsWith(`assets${sep}`) ? IMMUTABLE : 'no-cache';
}

/**
 * Sicherheits-Kopfzeilen für jede Antwort, dazu die gebauten Seiten der Verwaltung aus `webDir`.
 * Muss vor allen anderen Adressen registriert werden, damit der Hook auch für sie gilt.
 * Ohne `webDir` oder ohne diesen Ordner (Tests, Entwicklung ohne Bau) gibt es nur die Kopfzeilen.
 */
export async function registerWeb(app: FastifyInstance, webDir: string | undefined): Promise<void> {
  const https = app.deps.config.publicUrl.startsWith('https://');
  app.addHook('onSend', async (_req, reply, payload) => {
    reply.header('x-content-type-options', 'nosniff');
    reply.header('referrer-policy', 'same-origin');
    reply.header('x-frame-options', 'DENY');
    reply.header('content-security-policy', CONTENT_SECURITY_POLICY);
    if (https) reply.header('strict-transport-security', 'max-age=31536000');
    return payload;
  });

  if (webDir === undefined) return;
  const root = resolve(webDir);
  if (!(await isDirectory(root))) {
    app.log.warn({ webDir: root }, 'Ordner für die Seiten fehlt, der Server läuft ohne Seiten');
    return;
  }

  // wildcard: false legt beim Start eine Adresse pro Datei an. Der gebaute Ordner ändert sich im Betrieb nicht.
  await app.register(fastifyStatic, {
    root,
    wildcard: false,
    cacheControl: false,
    dotfiles: 'ignore',
    setHeaders: (reply, filePath) => reply.header('cache-control', cacheControl(root, filePath)),
  });

  // Jede andere Seitenadresse (etwa /betriebe oder /b/<Betrieb>/kassen) bekommt index.html, den Rest macht der Browser.
  app.get('/*', async (req, reply) => {
    const path = req.url.split('?')[0]!;
    const lastSegment = path.slice(path.lastIndexOf('/') + 1);
    if (SERVER_AREAS.some((area) => inArea(path, area)) || FILE_ENDING.test(lastSegment)) {
      return reply.callNotFound();
    }
    reply.header('cache-control', 'no-cache');
    return reply.sendFile('index.html');
  });
}
