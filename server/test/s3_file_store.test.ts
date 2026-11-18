import { S3Client } from '@aws-sdk/client-s3';
import { Readable } from 'node:stream';
import { expect, test } from 'vitest';
import { S3FileStore } from '../src/storage/s3_file_store.js';

// Gegen einen echten Bucket ist der Weg hier nicht geprüft (Task 17). Das Netz ersetzt ein Stellvertreter.
type Sent = { name: string; input: Record<string, unknown> };
function stubClient(answer: (s: Sent) => unknown) {
  const sent: Sent[] = [];
  return {
    sent,
    client: {
      send: async (cmd: { constructor: { name: string }; input: Record<string, unknown> }) => {
        const s = { name: cmd.constructor.name, input: cmd.input };
        sent.push(s);
        return answer(s);
      },
    },
  };
}
const cfg = { endpoint: 'https://s3.example.com', bucket: 'beispiel', accessKeyId: 'a', secretAccessKey: 'b', region: 'eu' };

test('Schlüssel mit .. wird abgelehnt, ohne dass eine Anfrage hinausgeht', async () => {
  const { client, sent } = stubClient(() => ({}));
  const store = new S3FileStore(cfg, client as never);
  await expect(store.get('../x')).rejects.toThrow(/Schlüssel/);
  await expect(store.delete('/x')).rejects.toThrow(/Schlüssel/);
  await expect(store.put('a/../b', Readable.from([Buffer.from('x')]), 'x/y')).rejects.toThrow(/Schlüssel/);
  expect(sent).toEqual([]);
});

test('get: fehlendes Objekt ist null, vorhandenes liefert Strom und Größe, andere Fehler bleiben Fehler', async () => {
  const missing = stubClient(() => {
    throw Object.assign(new Error('weg'), { name: 'NoSuchKey', $metadata: { httpStatusCode: 404 } });
  });
  expect(await new S3FileStore(cfg, missing.client as never).get('releases/a.apk')).toBeNull();

  const found = stubClient(() => ({ Body: Readable.from([Buffer.from('abc')]), ContentLength: 3 }));
  const got = await new S3FileStore(cfg, found.client as never).get('releases/a.apk');
  expect(got?.size).toBe(3);
  expect(found.sent[0]).toMatchObject({ name: 'GetObjectCommand', input: { Bucket: 'beispiel', Key: 'releases/a.apk' } });

  const broken = stubClient(() => {
    throw Object.assign(new Error('Zugriff'), { name: 'AccessDenied', $metadata: { httpStatusCode: 403 } });
  });
  await expect(new S3FileStore(cfg, broken.client as never).get('releases/a.apk')).rejects.toThrow('Zugriff');
});

test('delete und put schicken Bucket, Schlüssel und Inhaltstyp', async () => {
  const s = stubClient(() => ({}));
  // Upload liest die Einstellungen des Clients: ein echter Client, nur das Senden ist ersetzt.
  const client = new S3Client({
    endpoint: cfg.endpoint,
    region: cfg.region,
    forcePathStyle: true,
    credentials: { accessKeyId: 'a', secretAccessKey: 'b' },
  });
  client.send = s.client.send as never;
  const store = new S3FileStore(cfg, client);
  await store.put('releases/a.apk', Readable.from([Buffer.from('abc')]), 'application/x-test');
  await store.delete('releases/a.apk');
  expect(s.sent.map((x) => x.name)).toEqual(['PutObjectCommand', 'DeleteObjectCommand']);
  expect(s.sent[0]!.input).toMatchObject({ Bucket: 'beispiel', Key: 'releases/a.apk', ContentType: 'application/x-test' });
  expect(s.sent[1]!.input).toMatchObject({ Bucket: 'beispiel', Key: 'releases/a.apk' });
});
