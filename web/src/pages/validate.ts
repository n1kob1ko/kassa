/** Prüfungen im Formular, gleich wie am Server (server/src/auth/routes.ts). */

export const MIN_PASSWORD_LENGTH = 10;
const EMAIL = /^[^\s@]+@[^\s@]+$/;

export function emailProblem(email: string): string | undefined {
  const value = email.trim();
  if (value === '') return 'Bitte gib deine E-Mail-Adresse ein.';
  if (!EMAIL.test(value)) return 'Diese E-Mail-Adresse stimmt so nicht. Sie braucht ein @.';
  return undefined;
}

/** Zeichen wie der Server zählen: ein Emoji ist ein Zeichen. */
export function passwordLength(password: string): number {
  return [...password].length;
}

/** Höchster Preis, den die Verwaltung annimmt: 99.999,99 €. */
export const MAX_PRICE_CENTS = 9_999_999;
const PRICE = /^(\d{1,5})(?:[.,](\d{1,2}))?$/;

/**
 * Ein getippter Preis in Cent: `9,90`, `9.90`, `9` und `9,9` gehen, Leerzeichen und ein Eurozeichen am Ende
 * auch. Negativ, mehr als zwei Nachkommastellen, Buchstaben, Tausenderpunkte, leer oder über 99.999,99 €: `null`.
 */
export function parsePrice(text: string): number | null {
  const match = PRICE.exec(text.replace(/\s| /g, '').replace(/€$/, ''));
  if (!match) return null;
  const cents = Number(match[1]) * 100 + Number((match[2] ?? '').padEnd(2, '0'));
  return cents <= MAX_PRICE_CENTS ? cents : null;
}

/** Cent als Text im Preisfeld: `9,90`, ohne Eurozeichen (das steht neben dem Feld) und ohne Tausenderpunkt. */
export function priceText(cents: number): string {
  return `${Math.floor(cents / 100)},${String(cents % 100).padStart(2, '0')}`;
}

/** Bilder, die der Server annimmt (server/src/files/routes.ts), und ihre Grenze. */
export const IMAGE_TYPES = ['image/jpeg', 'image/png', 'image/webp'];
export const MAX_IMAGE_BYTES = 10 * 1024 * 1024;
export const NOT_AN_IMAGE = 'Das ist kein Bild. Erlaubt sind JPEG, PNG und WebP.';
export const IMAGE_TOO_LARGE = 'Das Bild ist größer als 10 MB.';

/** Prüft ein Bild vor dem Hochladen: ein Satz, wenn Art oder Größe nicht passen, sonst `null`. */
export function imageProblem(file: { type: string; size: number }): string | null {
  if (!IMAGE_TYPES.includes(file.type)) return NOT_AN_IMAGE;
  if (file.size > MAX_IMAGE_BYTES) return IMAGE_TOO_LARGE;
  return null;
}
