import { isIP, isIPv4, isIPv6 } from 'node:net';
import type { FastifyRequest } from 'fastify';
import type { Config } from './config.js';

/**
 * Die Internet-Adresse des Gegenübers, etwa für Grenzen bei Fehlversuchen.
 * Nennt CLIENT_IP_HEADER eine Kopfzeile und trägt die Anfrage genau einen Wert dafür, der eine IP-Adresse ist, gilt dieser.
 * Sonst die Adresse der Verbindung. X-Forwarded-For und req.ip gelten nie, weil der Client sie selbst setzen kann.
 */
export function clientAddress(req: FastifyRequest, config: Pick<Config, 'clientIpHeader'>): string {
  return headerAddress(req, config) ?? req.socket.remoteAddress ?? '';
}

/**
 * Die Adresse aus der Kopfzeile CLIENT_IP_HEADER, wenn sie eingestellt ist und die Anfrage genau einen Wert trägt, der
 * eine IP-Adresse ist; sonst null (dann gilt in clientAddress die Adresse der Verbindung).
 */
export function headerAddress(req: FastifyRequest, config: Pick<Config, 'clientIpHeader'>): string | null {
  if (config.clientIpHeader === undefined) return null;
  const v = req.headers[config.clientIpHeader];
  // Node fasst mehrfach gesendete Kopfzeilen mit Komma zusammen: Das ist dann kein einzelner Wert.
  if (typeof v !== 'string' || v.includes(',')) return null;
  const value = v.trim();
  // Nur eine echte Adresse (IPv4 oder IPv6) gilt.
  return isIP(value) !== 0 ? value : null;
}

/** Die acht Gruppen (je 0 bis 65535) einer gültigen IPv6-Adresse ohne Zonenkennung. */
function ipv6Groups(address: string): number[] {
  let text = address.toLowerCase();
  const lastColon = text.lastIndexOf(':');
  const tail = text.slice(lastColon + 1);
  if (tail.includes('.')) {
    // Eingebettete IPv4-Adresse (::ffff:1.2.3.4) werden zwei Gruppen.
    const [a, b, c, d] = tail.split('.').map(Number) as [number, number, number, number];
    text = `${text.slice(0, lastColon + 1)}${((a << 8) | b).toString(16)}:${((c << 8) | d).toString(16)}`;
  }
  const [head = '', rest] = text.split('::');
  const first = head === '' ? [] : head.split(':');
  const second = rest === undefined || rest === '' ? [] : rest.split(':');
  const fill = rest === undefined ? [] : Array<string>(8 - first.length - second.length).fill('0');
  return [...first, ...fill, ...second].map((g) => parseInt(g, 16));
}

/**
 * Der Schlüssel, unter dem Grenzen eine Adresse zählen. Rein und wirft nie.
 * IPv4 bleibt, IPv4 in IPv6-Schreibweise wird IPv4, IPv6 wird auf das Netz /64 gekürzt (`2001:db8:1:2::/64`),
 * weil ein Anschluss meist ein ganzes /64 bekommt und sonst jede Adresse daraus eine eigene Grenze hätte.
 * Eine Zonenkennung (`%eth0`) fällt weg. Alles andere (auch leer) bleibt unverändert.
 */
export function rateKey(address: string): string {
  if (isIPv4(address)) return address;
  const percent = address.indexOf('%');
  const bare = percent >= 0 ? address.slice(0, percent) : address;
  if (!isIPv6(bare)) return address;
  const g = ipv6Groups(bare);
  if (g.slice(0, 5).every((x) => x === 0) && g[5] === 0xffff) {
    return `${g[6]! >> 8}.${g[6]! & 255}.${g[7]! >> 8}.${g[7]! & 255}`;
  }
  return `${g.slice(0, 4).map((x) => x.toString(16)).join(':')}::/64`;
}
