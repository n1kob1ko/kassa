import type { Readable } from 'node:stream';
import type { Config } from '../config.js';
import { LocalFileStore } from './local_file_store.js';
import { S3FileStore } from './s3_file_store.js';

/** Die Ablage für Installationsdateien. Schlüssel sind Pfade wie `releases/<id>.apk`. */
export interface FileStore {
  put(key: string, body: Readable, contentType: string): Promise<void>;
  /** `null`, wenn es den Schlüssel nicht gibt. */
  get(key: string): Promise<{ body: Readable; size: number } | null>;
  /** Löschen eines fehlenden Schlüssels ist kein Fehler. */
  delete(key: string): Promise<void>;
}

/** Lehnt Schlüssel ab, die aus der Ablage hinausführen könnten. */
export function assertSafeKey(key: string): void {
  const bad =
    key === '' ||
    key.startsWith('/') ||
    key.includes('\\') ||
    key.includes('\0') ||
    key.split('/').some((part) => part === '..' || part === '.' || part === '');
  if (bad) throw new Error('Ungültiger Schlüssel für die Ablage.');
}

export function createFileStore(config: Config): FileStore {
  if (config.s3) return new S3FileStore(config.s3);
  if (config.fileDir) return new LocalFileStore(config.fileDir);
  throw new Error('Weder FILE_DIR noch S3 ist eingestellt.');
}
