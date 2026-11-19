import { randomUUID } from 'node:crypto';
import { Readable } from 'node:stream';
import type { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';
import type pg from 'pg';
import { audit } from '../audit.js';
import { isUuid, requireBusinessAccess } from '../auth/guards.js';
import { nextChangeSeq, withBusiness, withBusinessWrite } from '../db/tenant.js';
import { requireRegister } from '../device/guard.js';
import { ApiError } from '../errors.js';
import { processImage } from './images.js';

export const MAX_IMAGE_BYTES = 10 * 1024 * 1024;
const IMAGE_TYPES = ['image/jpeg', 'image/png', 'image/webp'];
const MAX_ITEM_ID = 200;

const notFound = () => new ApiError(404, 'not_found', 'Das gibt es nicht.');
const tooLarge = () => new ApiError(413, 'file_too_large', 'Das Bild ist zu groß. Es darf höchstens 10 MB haben.');
const unsupportedType = () =>
  new ApiError(415, 'unsupported_media_type', 'Bitte schicke das Bild als JPEG, PNG oder WebP.');

const storageKey = (businessId: string, fileId: string) => `businesses/${businessId}/files/${fileId}.webp`;

type Target = { kind: 'item_photo'; itemId: string } | { kind: 'logo' };

/** Der Zeiger auf die Datei: bei einem Artikel `photo_file_id`, beim Betrieb `logo_file_id`. */
async function currentFile(c: pg.PoolClient, businessId: string, t: Target): Promise<{ id: string; key: string } | null | 'missing'> {
  const r =
    t.kind === 'item_photo'
      ? await c.query<{ file_id: string | null }>('select photo_file_id as file_id from items where id = $1 for update', [t.itemId])
      : await c.query<{ file_id: string | null }>('select logo_file_id as file_id from businesses where id = $1 for update', [businessId]);
  const row = r.rows[0];
  if (!row) return 'missing';
  if (row.file_id === null) return null;
  const f = await c.query<{ storage_key: string }>('select storage_key from files where id = $1', [row.file_id]);
  return { id: row.file_id, key: f.rows[0]?.storage_key ?? storageKey(businessId, row.file_id) };
}

/** Zeigt der Artikel oder der Betrieb auf eine neue Datei (oder auf keine), und zieht eine Änderungs-Nummer. */
async function point(c: pg.PoolClient, businessId: string, t: Target, fileId: string | null): Promise<void> {
  const seq = await nextChangeSeq(c);
  if (t.kind === 'item_photo') {
    await c.query('update items set photo_file_id = $2, change_seq = $3 where id = $1', [t.itemId, fileId, seq]);
  } else {
    await c.query('update businesses set logo_file_id = $2, change_seq = $3 where id = $1', [businessId, fileId, seq]);
  }
}

const detailOf = (t: Target) => (t.kind === 'item_photo' ? { itemId: t.itemId } : {});
const actionOf = (t: Target, what: 'set' | 'removed') =>
  t.kind === 'item_photo' ? `item.photo_${what}` : `business.logo_${what}`;

/**
 * Bilder: Fotos der Artikel und das Logo hochladen und entfernen, Dateien an Verwaltung und Tablet ausliefern.
 * Nach installAuth aufrufen.
 */
export async function installFileRoutes(app: FastifyInstance): Promise<void> {
  const { db, files, now } = app.deps;

  /** Löscht nach dem Commit die alte Zeile und das alte Objekt. Scheitert etwas, bleibt es im Protokoll, die Anfrage gilt. */
  async function dropOld(req: FastifyRequest, businessId: string, old: { id: string; key: string }): Promise<void> {
    try {
      await withBusiness(db, businessId, (c) => c.query('delete from files where id = $1', [old.id]));
    } catch (err) {
      req.log.error({ err, fileId: old.id }, 'Alte Bilddatei: die Zeile ließ sich nicht löschen');
      return;
    }
    try {
      await files.delete(old.key);
    } catch (err) {
      req.log.error({ err, fileId: old.id, key: old.key }, 'Alte Bilddatei: das Objekt blieb in der Ablage liegen');
    }
  }

  async function replace(req: FastifyRequest, reply: FastifyReply, businessId: string, t: Target) {
    const user = req.user!;
    const body = req.body;
    if (!Buffer.isBuffer(body)) throw unsupportedType();
    const image = await processImage(body);
    const fileId = randomUUID();
    const key = storageKey(businessId, fileId);
    const at = now();
    let wrote = false;
    let old: { id: string; key: string } | null;
    try {
      old = await withBusinessWrite(db, businessId, async (c) => {
        const cur = await currentFile(c, businessId, t);
        if (cur === 'missing') throw notFound();
        await files.put(key, Readable.from([image.data]), 'image/webp');
        wrote = true;
        await c.query(
          `insert into files (business_id, id, kind, storage_key, size, width, height, color, created_at)
           values ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
          [businessId, fileId, t.kind, key, image.data.length, image.width, image.height, image.color, at],
        );
        await point(c, businessId, t, fileId);
        await audit(c, { userId: user.id, businessId, action: actionOf(t, 'set'), detail: detailOf(t) }, at);
        return cur;
      });
    } catch (err) {
      // Ohne Commit zeigt nichts auf das neue Objekt.
      if (wrote) await files.delete(key).catch((e) => req.log.error({ err: e, key }, 'Neue Bilddatei ließ sich nicht wieder löschen'));
      throw err;
    }
    if (old) await dropOld(req, businessId, old);
    return reply.send({ file: { id: fileId, color: image.color, width: image.width, height: image.height } });
  }

  async function remove(req: FastifyRequest, reply: FastifyReply, businessId: string, t: Target) {
    const user = req.user!;
    const at = now();
    const old = await withBusinessWrite(db, businessId, async (c) => {
      const cur = await currentFile(c, businessId, t);
      if (cur === 'missing') throw notFound();
      if (cur === null) return null;
      await point(c, businessId, t, null);
      await audit(c, { userId: user.id, businessId, action: actionOf(t, 'removed'), detail: detailOf(t) }, at);
      return cur;
    });
    if (old) await dropOld(req, businessId, old);
    return reply.code(204).send();
  }

  /** Liefert die Datei, solange ein Artikel oder der Betrieb auf sie zeigt. */
  async function serve(reply: FastifyReply, businessId: string, id: string) {
    if (!isUuid(id)) throw notFound();
    const key = await withBusiness(db, businessId, async (c) => {
      const r = await c.query<{ storage_key: string }>(
        `select f.storage_key from files f
          where f.id = $1
            and (exists (select 1 from items i where i.photo_file_id = f.id)
              or exists (select 1 from businesses b where b.logo_file_id = f.id))`,
        [id.toLowerCase()],
      );
      return r.rows[0]?.storage_key;
    });
    if (!key) throw notFound();
    const file = await files.get(key);
    if (!file) throw notFound();
    return reply
      .type('image/webp')
      .header('x-content-type-options', 'nosniff')
      .header('cache-control', 'private, max-age=31536000, immutable')
      .header('content-length', file.size)
      .send(file.body);
  }

  // Hochladen: eigener Bereich, damit der Leser für rohe Bilder und die Grenze nur hier gelten.
  await app.register(async (scope) => {
    for (const type of IMAGE_TYPES) {
      scope.addContentTypeParser(type, { parseAs: 'buffer', bodyLimit: MAX_IMAGE_BYTES }, (_req, body, done) => done(null, body));
    }
    /** Vor dem Lesen des Inhalts: Berechtigung, Typ und angekündigte Größe. */
    const check = async (req: FastifyRequest<{ Params: { b: string } }>) => {
      await requireBusinessAccess(req, req.params.b);
      const type = (req.headers['content-type'] ?? '').split(';')[0]!.trim().toLowerCase();
      if (!IMAGE_TYPES.includes(type)) throw unsupportedType();
      const declared = Number(req.headers['content-length']);
      if (Number.isFinite(declared) && declared > MAX_IMAGE_BYTES) throw tooLarge();
    };
    const opts = { bodyLimit: MAX_IMAGE_BYTES, onRequest: check };
    const itemTarget = (req: FastifyRequest<{ Params: { b: string; id: string } }>): Target => {
      if (req.params.id.length > MAX_ITEM_ID) throw notFound();
      return { kind: 'item_photo', itemId: req.params.id };
    };

    scope.put<{ Params: { b: string; id: string } }>('/api/admin/businesses/:b/items/:id/photo', opts, (req, reply) =>
      replace(req, reply, req.params.b.toLowerCase(), itemTarget(req)),
    );
    scope.put<{ Params: { b: string } }>('/api/admin/businesses/:b/logo', opts, (req, reply) =>
      replace(req, reply, req.params.b.toLowerCase(), { kind: 'logo' }),
    );
  });

  app.delete<{ Params: { b: string; id: string } }>('/api/admin/businesses/:b/items/:id/photo', async (req, reply) => {
    await requireBusinessAccess(req, req.params.b);
    if (req.params.id.length > MAX_ITEM_ID) throw notFound();
    return remove(req, reply, req.params.b.toLowerCase(), { kind: 'item_photo', itemId: req.params.id });
  });
  app.delete<{ Params: { b: string } }>('/api/admin/businesses/:b/logo', async (req, reply) => {
    await requireBusinessAccess(req, req.params.b);
    return remove(req, reply, req.params.b.toLowerCase(), { kind: 'logo' });
  });

  app.get<{ Params: { b: string; id: string } }>('/api/admin/businesses/:b/files/:id', async (req, reply) => {
    await requireBusinessAccess(req, req.params.b);
    return serve(reply, req.params.b.toLowerCase(), req.params.id);
  });
  app.get<{ Params: { id: string } }>('/api/device/files/:id', async (req, reply) => {
    const register = await requireRegister(req);
    return serve(reply, register.businessId, req.params.id);
  });
}
