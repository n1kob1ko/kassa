import { randomBytes } from 'node:crypto';
import { createReadStream, createWriteStream } from 'node:fs';
import { mkdir, rename, rm, stat } from 'node:fs/promises';
import { dirname, resolve, sep } from 'node:path';
import { pipeline } from 'node:stream/promises';
import type { Readable } from 'node:stream';
import { assertSafeKey, type FileStore } from './file_store.js';

/** Ablage in einem Ordner auf dem Server (für Entwicklung und Server mit Datenträger). */
export class LocalFileStore implements FileStore {
  private readonly root: string;

  constructor(dir: string) {
    this.root = resolve(dir);
  }

  private pathOf(key: string): string {
    assertSafeKey(key);
    const p = resolve(this.root, key);
    if (!p.startsWith(this.root + sep)) throw new Error('Ungültiger Schlüssel für die Ablage.');
    return p;
  }

  async put(key: string, body: Readable, _contentType: string): Promise<void> {
    const path = this.pathOf(key);
    await mkdir(dirname(path), { recursive: true });
    // Erst in eine eigene Datei schreiben: Ein abgebrochener Strom hinterlässt nie eine halbe Datei unter dem Schlüssel.
    const temp = `${path}.${randomBytes(6).toString('hex')}.tmp`;
    try {
      await pipeline(body, createWriteStream(temp, { flags: 'wx' }));
      await rename(temp, path);
    } catch (err) {
      await rm(temp, { force: true });
      throw err;
    }
  }

  async get(key: string): Promise<{ body: Readable; size: number } | null> {
    const path = this.pathOf(key);
    try {
      const s = await stat(path);
      if (!s.isFile()) return null;
      return { body: createReadStream(path), size: s.size };
    } catch (err) {
      if ((err as NodeJS.ErrnoException).code === 'ENOENT') return null;
      throw err;
    }
  }

  async delete(key: string): Promise<void> {
    await rm(this.pathOf(key), { force: true });
  }
}
