import { createHash, randomBytes, timingSafeEqual } from 'node:crypto';

/** Ein zufälliges Geheimnis als base64url (32 Bytes ergeben 43 Zeichen). */
export function randomToken(bytes = 32): string {
  return randomBytes(bytes).toString('base64url');
}

export function sha256(s: string): Buffer {
  return createHash('sha256').update(s, 'utf8').digest();
}

/** Vergleicht zwei Texte in gleicher Zeit, auch bei verschiedener Länge. */
export function safeEqual(a: string, b: string): boolean {
  return timingSafeEqual(sha256(a), sha256(b));
}
