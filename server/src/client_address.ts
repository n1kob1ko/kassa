import type { FastifyRequest } from 'fastify';
import type { Config } from './config.js';

/**
 * Die Internet-Adresse des Gegenübers, etwa für Grenzen bei Fehlversuchen.
 * Nennt CLIENT_IP_HEADER eine Kopfzeile und trägt die Anfrage genau einen nicht leeren Wert dafür, gilt dieser.
 * Sonst die Adresse der Verbindung. X-Forwarded-For und req.ip gelten nie, weil der Client sie selbst setzen kann.
 */
export function clientAddress(req: FastifyRequest, config: Pick<Config, 'clientIpHeader'>): string {
  if (config.clientIpHeader !== undefined) {
    const v = req.headers[config.clientIpHeader];
    // Node fasst mehrfach gesendete Kopfzeilen mit Komma zusammen: Das ist dann kein einzelner Wert.
    if (typeof v === 'string' && !v.includes(',')) {
      const value = v.trim();
      if (value !== '') return value;
    }
  }
  return req.socket.remoteAddress ?? '';
}
