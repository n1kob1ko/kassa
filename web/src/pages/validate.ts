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
