import { describe, expect, test } from 'vitest';
import { configWarnings, loadConfig } from '../src/config.js';

const base = {
  DATABASE_URL: 'postgres://kassa@127.0.0.1:54329/postgres',
  APP_DB_PASSWORD: 'geheim',
  PUBLIC_URL: 'https://kassa.example.com',
  FILE_DIR: '/var/data',
};

const s3 = {
  S3_ENDPOINT: 'https://s3.example.com',
  S3_BUCKET: 'dateien',
  S3_ACCESS_KEY_ID: 'id',
  S3_SECRET_ACCESS_KEY: 'secret',
  S3_REGION: 'auto',
};

const SETUP = 's'.repeat(32);
const RELEASE = 'r'.repeat(40);

describe('loadConfig', () => {
  test('nennt alle fehlenden Variablen auf einmal', () => {
    expect(() => loadConfig({})).toThrow(/DATABASE_URL.*APP_DB_PASSWORD.*PUBLIC_URL/s);
  });

  test('FILE_DIR und S3 zusammen ist ein Fehler', () => {
    expect(() => loadConfig({ ...base, ...s3 })).toThrow(/FILE_DIR.*S3/s);
  });

  test('weder FILE_DIR noch S3 ist ein Fehler', () => {
    const { FILE_DIR: _ignored, ...rest } = base;
    expect(() => loadConfig(rest)).toThrow(/FILE_DIR.*S3/s);
  });

  test('PUBLIC_URL verliert den Schrägstrich am Ende', () => {
    expect(loadConfig({ ...base, PUBLIC_URL: 'https://kassa.example.com/' }).publicUrl).toBe(
      'https://kassa.example.com',
    );
  });

  test('Vorgaben und optionale Werte', () => {
    const c = loadConfig(base);
    expect(c.port).toBe(3000);
    expect(c.passwordCost).toBe(131072);
    expect(c.fileDir).toBe('/var/data');
    expect(c.s3).toBeUndefined();
    expect(c.setupToken).toBeUndefined();
    expect(loadConfig({ ...base, PORT: '8080', SETUP_TOKEN: SETUP, RELEASE_TOKEN: RELEASE, WEB_DIR: '/w' })).toMatchObject({
      port: 8080,
      setupToken: SETUP,
      releaseToken: RELEASE,
      webDir: '/w',
    });
  });

  test('CLIENT_IP_HEADER: ohne Angabe keiner, sonst klein geschrieben, kein gültiger Name ist ein Fehler', () => {
    expect(loadConfig(base).clientIpHeader).toBeUndefined();
    expect(loadConfig({ ...base, CLIENT_IP_HEADER: 'X-Real-IP' }).clientIpHeader).toBe('x-real-ip');
    expect(() => loadConfig({ ...base, CLIENT_IP_HEADER: 'x real ip' })).toThrow(/CLIENT_IP_HEADER/);
  });

  test('S3-Einstellungen werden gelesen, unvollständige sind ein Fehler', () => {
    const { FILE_DIR: _ignored, ...rest } = base;
    expect(loadConfig({ ...rest, ...s3 }).s3).toEqual({
      endpoint: 'https://s3.example.com',
      bucket: 'dateien',
      accessKeyId: 'id',
      secretAccessKey: 'secret',
      region: 'auto',
      urlStyle: 'virtual',
    });
    expect(() => loadConfig({ ...rest, S3_ENDPOINT: 'https://s3.example.com' })).toThrow(/S3_BUCKET/);
  });

  test('ein ungültiger PORT ist ein Fehler', () => {
    expect(() => loadConfig({ ...base, PORT: 'abc' })).toThrow(/PORT/);
  });

  test('PUBLIC_URL wird zur Herkunft: Pfad, Großbuchstaben und :443 stören nicht', () => {
    const origin = (v: string) => loadConfig({ ...base, PUBLIC_URL: v }).publicUrl;
    expect(origin('https://kassa.example.com/verwaltung/')).toBe('https://kassa.example.com');
    expect(origin('https://Kassa.Example.COM')).toBe('https://kassa.example.com');
    expect(origin('HTTPS://kassa.example.com:443/')).toBe('https://kassa.example.com');
    expect(origin('http://localhost:3000/x?y=1')).toBe('http://localhost:3000');
  });

  test('PUBLIC_URL nicht lesbar oder ohne http(s): Fehler ohne den Wert', () => {
    for (const v of ['kassa example com', 'ftp://kassa.example.com', 'https://geheim:passwort@']) {
      let message = '';
      try {
        loadConfig({ ...base, PUBLIC_URL: v });
      } catch (err) {
        message = (err as Error).message;
      }
      expect(message).toMatch(/PUBLIC_URL/);
      expect(message).not.toContain(v);
      expect(message).not.toContain('passwort');
    }
  });

  test('SETUP_TOKEN und RELEASE_TOKEN brauchen mindestens 32 Zeichen, der Fehler nennt den Namen, nicht den Wert', () => {
    const short = 'kurz-geheim-31-zeichen-xxxxxxxx';
    expect(short).toHaveLength(31);
    for (const name of ['SETUP_TOKEN', 'RELEASE_TOKEN']) {
      let message = '';
      try {
        loadConfig({ ...base, [name]: short });
      } catch (err) {
        message = (err as Error).message;
      }
      expect(message).toContain(name);
      expect(message).toMatch(/32 Zeichen/);
      expect(message).not.toContain(short);
    }
    const ok = loadConfig({ ...base, SETUP_TOKEN: 'x'.repeat(32), RELEASE_TOKEN: 'y'.repeat(32) });
    expect(ok.setupToken).toHaveLength(32);
    expect(ok.releaseToken).toHaveLength(32);
  });

  test('DATABASE_URL muss eine postgres-Adresse sein, der Fehler enthält den Wert nie', () => {
    for (const v of ['postgres://kassa:geheim@[kaputt/db', 'mysql://kassa:geheim@host/db', 'kassa:geheim@host/db']) {
      let message = '';
      try {
        loadConfig({ ...base, DATABASE_URL: v });
      } catch (err) {
        message = (err as Error).message;
      }
      expect(message).toContain('DATABASE_URL');
      expect(message).not.toContain('geheim');
    }
    expect(loadConfig({ ...base, DATABASE_URL: 'postgresql://kassa:geheim@db.example.com:5432/kassa' }).databaseUrl).toBe(
      'postgresql://kassa:geheim@db.example.com:5432/kassa',
    );
  });

  test('S3_URL_STYLE: Vorgabe virtual, path geht, alles andere ist ein Fehler', () => {
    const { FILE_DIR: _ignored, ...rest } = base;
    expect(loadConfig({ ...rest, ...s3 }).s3?.urlStyle).toBe('virtual');
    expect(loadConfig({ ...rest, ...s3, S3_URL_STYLE: 'virtual' }).s3?.urlStyle).toBe('virtual');
    expect(loadConfig({ ...rest, ...s3, S3_URL_STYLE: 'path' }).s3?.urlStyle).toBe('path');
    expect(() => loadConfig({ ...rest, ...s3, S3_URL_STYLE: 'Pfad' })).toThrow(/S3_URL_STYLE/);
  });
});

describe('configWarnings', () => {
  test('https ohne CLIENT_IP_HEADER gibt genau eine Warnung, sonst keine', () => {
    const warnings = configWarnings(loadConfig(base));
    expect(warnings).toHaveLength(1);
    expect(warnings[0]).toMatch(/CLIENT_IP_HEADER/);
    expect(configWarnings(loadConfig({ ...base, CLIENT_IP_HEADER: 'x-real-ip' }))).toEqual([]);
    expect(configWarnings(loadConfig({ ...base, PUBLIC_URL: 'http://localhost:3000' }))).toEqual([]);
  });
});
