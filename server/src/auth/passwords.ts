import { randomBytes, scrypt, timingSafeEqual, type ScryptOptions } from 'node:crypto';

const R = 8;
const P = 1;
const KEY_LENGTH = 32;
const SALT_LENGTH = 16;
/** Grenzen für N aus einem gespeicherten Prüfwert, damit ein kaputter Wert nicht den Speicher sprengt. */
const MIN_COST = 1024;
const MAX_COST = 1 << 20;

function derive(pw: string, salt: Buffer, n: number, keyLength: number): Promise<Buffer> {
  // scrypt braucht etwa 128 * N * r Bytes, die Vorgabe von Node (32 MB) reicht ab N=32768 nicht mehr.
  const options: ScryptOptions = { N: n, r: R, p: P, maxmem: 256 * n * R * P };
  return new Promise((resolve, reject) => {
    scrypt(pw, salt, keyLength, options, (err, key) => (err ? reject(err) : resolve(key)));
  });
}

/** Prüfwert im Format `scrypt$<N>$8$1$<salt base64>$<hash base64>`. */
export async function hashPassword(pw: string, cost: number): Promise<string> {
  const salt = randomBytes(SALT_LENGTH);
  const key = await derive(pw, salt, cost, KEY_LENGTH);
  return `scrypt$${cost}$${R}$${P}$${salt.toString('base64')}$${key.toString('base64')}`;
}

/** Prüft mit den Kosten, die im Prüfwert stehen. Ein unlesbarer Prüfwert gilt nie. */
export async function verifyPassword(pw: string, stored: string): Promise<boolean> {
  const parts = stored.split('$');
  if (parts.length !== 6 || parts[0] !== 'scrypt') return false;
  const n = Number(parts[1]);
  const validCost = Number.isInteger(n) && n >= MIN_COST && n <= MAX_COST && (n & (n - 1)) === 0;
  if (!validCost || parts[2] !== String(R) || parts[3] !== String(P)) return false;
  const salt = Buffer.from(parts[4]!, 'base64');
  const expected = Buffer.from(parts[5]!, 'base64');
  if (salt.length === 0 || expected.length !== KEY_LENGTH) return false;
  const key = await derive(pw, salt, n, KEY_LENGTH);
  return timingSafeEqual(key, expected);
}
