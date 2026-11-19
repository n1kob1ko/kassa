import { afterAll, beforeAll, describe, expect, test } from 'vitest';
import { rateKey } from '../src/client_address.js';
import { testApp, type TestApp } from './support/app.js';
import { createBusiness } from './support/businesses.js';
import { createPairingCode, PAIR_DEVICE } from './support/device.js';
import { insertStaff } from './support/registers.js';
import { createProvider, type TestUser } from './support/users.js';

describe('rateKey', () => {
  test('IPv4 bleibt unverändert', () => {
    expect(rateKey('203.0.113.7')).toBe('203.0.113.7');
  });

  test('IPv4 in IPv6-Schreibweise gilt als IPv4', () => {
    expect(rateKey('::ffff:1.2.3.4')).toBe('1.2.3.4');
    expect(rateKey('::FFFF:1.2.3.4')).toBe('1.2.3.4');
    expect(rateKey('::ffff:102:304')).toBe('1.2.3.4');
  });

  test('IPv6 wird auf das Netz /64 gekürzt, auch bei anderer Schreibweise', () => {
    expect(rateKey('2001:db8:1:2::1')).toBe('2001:db8:1:2::/64');
    expect(rateKey('2001:DB8:1:2::1')).toBe('2001:db8:1:2::/64');
    expect(rateKey('2001:db8:1:2:ffff::9')).toBe('2001:db8:1:2::/64');
    expect(rateKey('2001:0db8:0001:0002:0000:0000:0000:0001')).toBe('2001:db8:1:2::/64');
    expect(rateKey('2001:db8:1:3::1')).not.toBe(rateKey('2001:db8:1:2::1'));
    expect(rateKey('::1')).toBe('0:0:0:0::/64');
    expect(rateKey('2001:db8::1')).toBe('2001:db8:0:0::/64');
  });

  test('eine Zonenkennung fällt vor dem Kürzen weg', () => {
    expect(rateKey('fe80::1%eth0')).toBe('fe80:0:0:0::/64');
    expect(rateKey('fe80::1%eth0')).toBe(rateKey('fe80::2'));
  });

  test('Unsinn bleibt, wie er ist, und wirft nie', () => {
    for (const s of ['', 'unbekannt', '1.2.3', '1.2.3.4.5', '999.1.1.1', '1.2.3.4%eth0', ':::', '2001:db8:::1', 'g::1', ' 1.2.3.4']) {
      expect(rateKey(s)).toBe(s);
    }
  });
});

describe('Grenzen über alle Adressen', () => {
  const START = new Date('2026-11-18T10:00:00Z');
  const MINUTE = 60 * 1000;
  let a: TestApp;
  let provider: TestUser;
  let businessId: string;
  beforeAll(async () => {
    a = await testApp();
    provider = await createProvider(a.app, a.db);
    businessId = (await createBusiness(a.app, provider.cookie)).id;
    await insertStaff(a.db, businessId);
  });
  afterAll(async () => {
    await a.close();
  });

  const pair = (code: string, ip: string) =>
    a.app.inject({
      method: 'POST',
      url: '/api/device/pair',
      payload: { code, previousBusinessId: null, ...PAIR_DEVICE },
      remoteAddress: ip,
    });
  const login = (email: string, ip: string) =>
    a.app.inject({
      method: 'POST',
      url: '/api/auth/login',
      headers: { 'x-kassa-request': '1' },
      payload: { email, password: 'falsch-falsch-falsch' },
      remoteAddress: ip,
    });
  const ipv4 = (n: number) => `10.${Math.floor(n / 250) + 1}.0.${(n % 250) + 1}`;

  test('zehn falsche Codes von zehn Adressen im selben /64 sperren die elfte Adresse', async () => {
    a.now.value = START;
    for (let i = 1; i <= 10; i++) expect((await pair('00000000', `2001:db8:aaaa:1::${i}`)).statusCode).toBe(404);
    const eleventh = await pair('00000000', '2001:db8:aaaa:1:ffff::1');
    expect(eleventh.statusCode).toBe(429);
    expect(eleventh.json().error.code).toBe('too_many_attempts');
    // Ein anderes Netz ist nicht betroffen.
    expect((await pair('00000000', '2001:db8:aaaa:2::1')).statusCode).toBe(404);
  });

  test('30 Anmeldungen von 30 Adressen im selben /64 sperren die 31. Adresse', async () => {
    a.now.value = new Date(START.getTime() + 20 * MINUTE);
    for (let i = 1; i <= 30; i++) expect((await login(`n${i}@example.com`, `2001:db8:bbbb:1::${i}`)).statusCode).toBe(401);
    const res = await login('n31@example.com', '2001:db8:bbbb:1:abcd::1');
    expect(res.statusCode).toBe(429);
    expect(res.json().error.code).toBe('too_many_attempts');
  });

  test('200 falsche Codes von 200 Adressen sperren alle, auch mit richtigem Code; Sperren zählen nicht mit', async () => {
    const t0 = new Date(START.getTime() + 60 * MINUTE);
    a.now.value = t0;
    const early = await createPairingCode(a.app, provider.cookie, businessId, 'Kassa 2');

    // Ein richtiger Code vorher geht durch und zählt nicht.
    expect((await pair(early, ipv4(999))).statusCode).toBe(200);

    for (let i = 0; i < 200; i++) expect((await pair('00000000', ipv4(i))).statusCode).toBe(404);

    const blockedNew = await pair('00000000', ipv4(300));
    expect(blockedNew.statusCode).toBe(429);
    expect(blockedNew.json().error.code).toBe('too_many_attempts');
    expect(blockedNew.json().error.message).toMatch(/Zu viele Versuche/);
    expect(Number(blockedNew.headers['retry-after'])).toBeGreaterThan(0);
    // Auch der richtige Code wird abgewiesen (ein Code, der den ganzen Test über gilt).
    a.now.value = new Date(t0.getTime() + 5 * MINUTE);
    const good = await createPairingCode(a.app, provider.cookie, businessId);
    expect((await pair(good, ipv4(301))).statusCode).toBe(429);

    // 50 weitere gesperrte Versuche (neue und alte Adressen) zählen nicht als falsche Codes.
    a.now.value = new Date(t0.getTime() + 10 * MINUTE);
    for (let i = 0; i < 50; i++) expect((await pair('00000000', ipv4(400 + i))).statusCode).toBe(429);

    // Knapp vor dem Ende des Fensters der ersten 200 noch gesperrt, knapp danach geht der richtige Code durch.
    a.now.value = new Date(t0.getTime() + 15 * MINUTE - 1);
    expect((await pair(good, ipv4(500))).statusCode).toBe(429);
    a.now.value = new Date(t0.getTime() + 15 * MINUTE);
    expect((await pair(good, ipv4(501))).statusCode).toBe(200);
  });
});
