import { expect, test } from 'vitest';
import { hashPassword, verifyPassword } from '../src/auth/passwords.js';
import { randomToken, safeEqual, sha256 } from '../src/auth/secrets.js';

const FORMAT = /^scrypt\$(\d+)\$8\$1\$[A-Za-z0-9+/]+=*\$[A-Za-z0-9+/]+=*$/;

test('gleiches Passwort ergibt zwei verschiedene Prüfwerte, beide gelten', async () => {
  const a = await hashPassword('mein-langes-passwort', 1024);
  const b = await hashPassword('mein-langes-passwort', 1024);
  expect(a).toMatch(FORMAT);
  expect(b).toMatch(FORMAT);
  expect(a).not.toBe(b);
  expect(await verifyPassword('mein-langes-passwort', a)).toBe(true);
  expect(await verifyPassword('mein-langes-passwort', b)).toBe(true);
  expect(await verifyPassword('mein-langes-passwort!', a)).toBe(false);
  expect(a).not.toContain('mein-langes-passwort');
});

test('Prüfwert trägt seine Kosten, ein alter mit N=1024 gilt weiter', async () => {
  const fresh = await hashPassword('mein-langes-passwort', 2048);
  expect(fresh.match(FORMAT)?.[1]).toBe('2048');
  expect(await verifyPassword('mein-langes-passwort', fresh)).toBe(true);

  // Mit N=1024 erzeugt, bevor die Kosten erhöht wurden.
  const old = 'scrypt$1024$8$1$YmVpc3BpZWwtc2Fsei0xNg==$ghS7dG1yMMS9D0FFknFQcKLO/HdyQHPCTeIfzyVIxvI=';
  expect(await verifyPassword('altes-passwort-1', old)).toBe(true);
  expect(await verifyPassword('altes-passwort-2', old)).toBe(false);
});

test('ein kaputter Prüfwert gilt nie und wirft nicht', async () => {
  for (const stored of [
    '',
    'kaputt',
    'scrypt$1024$8$1$abc',
    'scrypt$1000$8$1$YmVpc3BpZWwtc2Fsei0xNg==$ghS7dG1yMMS9D0FFknFQcKLO/HdyQHPCTeIfzyVIxvI=',
    'scrypt$1073741824$8$1$YmVpc3BpZWwtc2Fsei0xNg==$ghS7dG1yMMS9D0FFknFQcKLO/HdyQHPCTeIfzyVIxvI=',
    'bcrypt$1024$8$1$YmVpc3BpZWwtc2Fsei0xNg==$ghS7dG1yMMS9D0FFknFQcKLO/HdyQHPCTeIfzyVIxvI=',
  ]) {
    expect(await verifyPassword('altes-passwort-1', stored)).toBe(false);
  }
});

test('randomToken ist base64url mit 43 Zeichen für 32 Bytes, sha256 und safeEqual', () => {
  const a = randomToken();
  expect(a).toMatch(/^[A-Za-z0-9_-]{43}$/);
  expect(randomToken()).not.toBe(a);
  expect(randomToken(16)).toMatch(/^[A-Za-z0-9_-]{22}$/);
  expect(sha256('abc').toString('hex')).toBe('ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
  expect(safeEqual('gleich', 'gleich')).toBe(true);
  expect(safeEqual('gleich', 'anders')).toBe(false);
  expect(safeEqual('kurz', 'viel länger')).toBe(false);
});
