import { mkdtemp, readdir, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { Readable } from 'node:stream';
import { afterAll, beforeAll, expect, test } from 'vitest';
import { LocalFileStore } from '../src/storage/local_file_store.js';

let dir: string;
let store: LocalFileStore;
beforeAll(async () => {
  dir = await mkdtemp(join(tmpdir(), 'kassa-store-'));
  store = new LocalFileStore(dir);
});
afterAll(async () => {
  await rm(dir, { recursive: true, force: true });
});

async function bytes(s: Readable): Promise<Buffer> {
  const parts: Buffer[] = [];
  for await (const p of s) parts.push(p as Buffer);
  return Buffer.concat(parts);
}

test('Schlüssel mit .. wird abgelehnt', async () => {
  for (const key of ['../aus.apk', 'a/../../aus.apk', '/etc/passwd', '', 'a\\b', 'a\0b']) {
    await expect(store.put(key, Readable.from([Buffer.from('x')]), 'text/plain')).rejects.toThrow(/Schlüssel/);
    await expect(store.get(key)).rejects.toThrow(/Schlüssel/);
    await expect(store.delete(key)).rejects.toThrow(/Schlüssel/);
  }
  expect(await readdir(join(dir, '..')).then((n) => n.includes('aus.apk'))).toBe(false);
});

test('get für unbekannten Schlüssel ist null', async () => {
  expect(await store.get('releases/gibt-es-nicht.apk')).toBeNull();
});

test('put, get und delete: Bytes und Größe stimmen, danach ist die Datei weg und Löschen ist wiederholbar', async () => {
  await store.put('releases/a.apk', Readable.from([Buffer.from('hallo '), Buffer.from('welt')]), 'x/y');
  const got = await store.get('releases/a.apk');
  expect(got?.size).toBe(10);
  expect((await bytes(got!.body)).toString()).toBe('hallo welt');
  await store.delete('releases/a.apk');
  await store.delete('releases/a.apk');
  expect(await store.get('releases/a.apk')).toBeNull();
});

test('ein abgebrochener Strom hinterlässt nichts', async () => {
  const broken = new Readable({
    read() {
      this.push(Buffer.from('anfang'));
      this.destroy(new Error('abgebrochen'));
    },
  });
  await expect(store.put('releases/kaputt.apk', broken, 'x/y')).rejects.toThrow();
  expect(await store.get('releases/kaputt.apk')).toBeNull();
  expect(await readdir(join(dir, 'releases'))).toEqual([]);
});
