import { describe, expect, test } from 'vitest';
import { loadConfig } from '../src/config.js';

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
    expect(loadConfig({ ...base, PORT: '8080', SETUP_TOKEN: 't', RELEASE_TOKEN: 'r', WEB_DIR: '/w' })).toMatchObject({
      port: 8080,
      setupToken: 't',
      releaseToken: 'r',
      webDir: '/w',
    });
  });

  test('S3-Einstellungen werden gelesen, unvollständige sind ein Fehler', () => {
    const { FILE_DIR: _ignored, ...rest } = base;
    expect(loadConfig({ ...rest, ...s3 }).s3).toEqual({
      endpoint: 'https://s3.example.com',
      bucket: 'dateien',
      accessKeyId: 'id',
      secretAccessKey: 'secret',
      region: 'auto',
    });
    expect(() => loadConfig({ ...rest, S3_ENDPOINT: 'https://s3.example.com' })).toThrow(/S3_BUCKET/);
  });

  test('ein ungültiger PORT ist ein Fehler', () => {
    expect(() => loadConfig({ ...base, PORT: 'abc' })).toThrow(/PORT/);
  });
});
