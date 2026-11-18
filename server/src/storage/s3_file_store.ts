import { DeleteObjectCommand, GetObjectCommand, S3Client, type S3ClientConfig } from '@aws-sdk/client-s3';
import { Upload } from '@aws-sdk/lib-storage';
import type { Readable } from 'node:stream';
import type { S3Config } from '../config.js';
import { assertSafeKey, type FileStore } from './file_store.js';

/** Das, was die Ablage vom Client braucht. Tests setzen hier einen Stellvertreter ein. */
type S3Like = Pick<S3Client, 'send'>;

function isMissing(err: unknown): boolean {
  const e = err as { name?: string; $metadata?: { httpStatusCode?: number } };
  return e.name === 'NoSuchKey' || e.name === 'NotFound' || e.$metadata?.httpStatusCode === 404;
}

/** Die Einstellungen des Clients. Railway-Buckets erwarten den Bucket im Hostnamen (S3_URL_STYLE=virtual). */
export function s3ClientConfig(cfg: S3Config): S3ClientConfig & { forcePathStyle: boolean } {
  return {
    endpoint: cfg.endpoint,
    region: cfg.region,
    forcePathStyle: cfg.urlStyle === 'path',
    credentials: { accessKeyId: cfg.accessKeyId, secretAccessKey: cfg.secretAccessKey },
  };
}

/** Ablage in einem S3-kompatiblen Bucket (zum Beispiel bei Railway). */
export class S3FileStore implements FileStore {
  private readonly client: S3Like;
  private readonly bucket: string;

  constructor(cfg: S3Config, client?: S3Like) {
    this.bucket = cfg.bucket;
    this.client = client ?? new S3Client(s3ClientConfig(cfg));
  }

  async put(key: string, body: Readable, contentType: string): Promise<void> {
    assertSafeKey(key);
    // Die Länge ist beim Durchreichen nicht bekannt: Upload schickt den Strom in Teilen und bricht bei einem Fehler ab.
    const upload = new Upload({
      client: this.client as S3Client,
      params: { Bucket: this.bucket, Key: key, Body: body, ContentType: contentType },
    });
    await upload.done();
  }

  async get(key: string): Promise<{ body: Readable; size: number } | null> {
    assertSafeKey(key);
    try {
      const r = await this.client.send(new GetObjectCommand({ Bucket: this.bucket, Key: key }));
      if (!r.Body || r.ContentLength === undefined) return null;
      return { body: r.Body as Readable, size: r.ContentLength };
    } catch (err) {
      if (isMissing(err)) return null;
      throw err;
    }
  }

  async delete(key: string): Promise<void> {
    assertSafeKey(key);
    await this.client.send(new DeleteObjectCommand({ Bucket: this.bucket, Key: key }));
  }
}
