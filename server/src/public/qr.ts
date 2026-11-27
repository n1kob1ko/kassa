import QRCode from 'qrcode';

/**
 * Der Text im QR-Code eines Bons, wie `qrText` in app/lib/rksv/core/rksv_code.dart: die Nutzlast des JWS (UTF-8),
 * dann `_`, dann die Signatur als base64 mit `=` (nicht url-sicher). Kein JWS aus drei Teilen: wirft.
 * Geprüft gegen shared/fixtures/rksv/qr_text.json.
 */
export function rksvQrText(jws: string): string {
  const parts = jws.split('.');
  if (parts.length !== 3) throw new Error('Kein JWS');
  const payload = Buffer.from(parts[1]!, 'base64url').toString('utf8');
  const signature = Buffer.from(parts[2]!, 'base64url').toString('base64');
  return `${payload}_${signature}`;
}

/** Der QR-Code als `<svg …>`: schwarz auf weiß, Fehlerkorrektur M, Ruhezone 4 Module, ohne feste Größe. */
export async function qrSvg(text: string): Promise<string> {
  const svg = await QRCode.toString(text, {
    type: 'svg',
    errorCorrectionLevel: 'M',
    margin: 4,
    color: { dark: '#000000', light: '#ffffff' },
  });
  return svg.trim();
}

/** Die Elemente, aus denen der QR-Code besteht. */
const ALLOWED_TAGS = new Set(['svg', 'path']);
const SVG_NAMESPACE = ' xmlns="http://www.w3.org/2000/svg"';

/**
 * Ob [svg] ohne Bedenken in die Seite darf: genau ein `<svg>` nur aus `svg` und `path`, kein Skript, kein Attribut
 * `on…=`, kein Verweis (href, src, url(), @import, eine Adresse mit ://), keine Kommentare oder Anweisungen. Die Seite
 * verbietet Skripte auch über die Kopfzeile; sie soll aber ohne diese sicher sein.
 */
export function isSafeSvg(svg: string): boolean {
  const s = svg.trim();
  if (!s.startsWith('<svg') || !s.endsWith('</svg>')) return false;
  const tags = [...s.matchAll(/<\/?\s*([A-Za-z][\w:.-]*)/g)].map((m) => m[1]!.toLowerCase());
  if (tags.some((t) => !ALLOWED_TAGS.has(t))) return false;
  if (tags.filter((t) => t === 'svg').length !== 2) return false;
  if (/<\s*[!?]/.test(s)) return false;
  if (/[\s"'/]on[a-z]*\s*=/i.test(s)) return false;
  if (/href|src\s*=|url\s*\(|@import|javascript:|data:|xmlns:/i.test(s)) return false;
  if (s.replace(SVG_NAMESPACE, '').includes('://')) return false;
  return true;
}
