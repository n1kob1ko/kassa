import { createHash, randomUUID } from 'node:crypto';
import { Transform, type TransformCallback, type Readable } from 'node:stream';
import type { FastifyInstance, FastifyRequest } from 'fastify';
import { audit } from '../audit.js';
import { isUuid, requireProvider } from '../auth/guards.js';
import { randomToken, safeEqual } from '../auth/secrets.js';
import { withSystem } from '../db/tenant.js';
import { ApiError } from '../errors.js';

export const MAX_RELEASE_BYTES = 200 * 1024 * 1024;
const APK_TYPE = 'application/vnd.android.package-archive';
const ZIP_MAGIC = Buffer.from([0x50, 0x4b, 0x03, 0x04]);
const VERSION = /^\d+\.\d+\.\d+$/;
const MAX_VERSION_LENGTH = 32;
const MAX_BUILD = 2_147_483_647;
const UNIQUE_VIOLATION = '23505';
const GONE_TEXT = 'Diese Datei gibt es nicht.';

type ReleaseRow = {
  id: string;
  version: string;
  build: number;
  sha256: string;
  size: string;
  link_secret: string;
  uploaded_at: Date;
  withdrawn_at: Date | null;
};

const notFound = () => new ApiError(404, 'not_found', 'Das gibt es nicht.');
const versionInvalid = () =>
  new ApiError(422, 'version_invalid', 'Die Version muss wie 1.2.0 aussehen, der Build eine ganze Zahl ab 1.');
const releaseExists = () =>
  new ApiError(409, 'release_exists', 'Diese Version mit diesem Build gibt es schon.');

const downloadPath = (secret: string, version: string) => `/laden/${secret}/kassa-${version}.apk`;

/** Reicht den Inhalt durch und rechnet dabei Größe und Prüfsumme. Bricht ab, wenn es kein APK ist oder zu groß wird. */
class ApkGate extends Transform {
  private readonly hash = createHash('sha256');
  private seen = 0;
  size = 0;
  /** Der Grund des Abbruchs, damit er nicht in einem Folgefehler der Ablage untergeht. */
  failure: ApiError | undefined;

  constructor(private readonly limit: number) {
    super();
  }

  private fail(cb: TransformCallback, err: ApiError): void {
    this.failure = err;
    cb(err);
  }

  override _transform(chunk: Buffer, _enc: BufferEncoding, cb: TransformCallback): void {
    this.size += chunk.length;
    if (this.size > this.limit) return this.fail(cb, tooLarge());
    if (this.seen < ZIP_MAGIC.length) {
      const head = chunk.subarray(0, ZIP_MAGIC.length - this.seen);
      if (!head.equals(ZIP_MAGIC.subarray(this.seen, this.seen + head.length))) return this.fail(cb, notAnApk());
      this.seen += head.length;
    }
    this.hash.update(chunk);
    cb(null, chunk);
  }

  override _flush(cb: TransformCallback): void {
    if (this.seen < ZIP_MAGIC.length) return this.fail(cb, notAnApk());
    cb();
  }

  digest(): string {
    return this.hash.digest('hex');
  }
}

const tooLarge = () => new ApiError(413, 'file_too_large', 'Die Datei ist zu groß.');
const notAnApk = () => new ApiError(422, 'not_an_apk', 'Das ist keine Installationsdatei für Android.');

function toWire(r: ReleaseRow) {
  const withdrawn = r.withdrawn_at !== null;
  return {
    id: r.id,
    version: r.version,
    build: r.build,
    sha256: r.sha256,
    size: Number(r.size),
    uploadedAt: r.uploaded_at.toISOString(),
    withdrawn,
    downloadPath: withdrawn ? null : downloadPath(r.link_secret, r.version),
  };
}

/**
 * Installationsdateien: Hochladen mit Schlüssel, Laden über den geheimen Link, Liste und Zurückziehen für den Anbieter.
 * Nach installAuth aufrufen.
 */
export async function installReleaseRoutes(app: FastifyInstance): Promise<void> {
  const { config, db, files, now } = app.deps;
  const maxBytes = app.deps.maxReleaseBytes ?? MAX_RELEASE_BYTES;

  // Hochladen: eigener Bereich, damit der Strom-Leser und die große Grenze nur für diese eine Adresse gelten.
  await app.register(async (scope) => {
    scope.addContentTypeParser(APK_TYPE, (_req, payload, done) => done(null, payload));

    /** Läuft vor dem Lesen des Inhalts: Wer den Schlüssel nicht hat, kann keine 200 MB schicken. */
    const check = async (req: FastifyRequest<{ Params: { version: string }; Querystring: { build?: unknown } }>) => {
      if (config.releaseToken === undefined) throw notFound();
      const m = /^Bearer (.+)$/.exec(req.headers.authorization ?? '');
      if (!m || !safeEqual(m[1]!, config.releaseToken)) {
        throw new ApiError(401, 'unauthorized', 'Der Schlüssel stimmt nicht.');
      }
      const { version } = req.params;
      if (!VERSION.test(version) || version.length > MAX_VERSION_LENGTH) throw versionInvalid();
      const build = req.query.build;
      if (typeof build !== 'string' || !/^[1-9]\d{0,9}$/.test(build) || Number(build) > MAX_BUILD) {
        throw versionInvalid();
      }
      const declared = Number(req.headers['content-length']);
      if (Number.isFinite(declared) && declared > maxBytes) throw tooLarge();
    };

    scope.put<{ Params: { version: string }; Querystring: { build?: string } }>(
      '/api/releases/:version',
      { bodyLimit: maxBytes, onRequest: check },
      async (req, reply) => {
        const version = req.params.version;
        const build = Number(req.query.build);
        const at = now();

        const taken = await withSystem(db, (c) =>
          c.query('select 1 from releases where version = $1 and build = $2', [version, build]),
        );
        if (taken.rowCount !== 0) throw releaseExists();

        const id = randomUUID();
        const key = `releases/${id}.apk`;
        const secret = randomToken();
        const gate = new ApkGate(maxBytes);
        try {
          // Von Hand durchreichen: Bei einem Abbruch muss der Strom der Ablage enden, ohne auf die Anfrage zu warten.
          // Der Fehler steht in gate.failure und wird unten geworfen; hier soll er nur nicht unbehandelt bleiben.
          gate.on('error', () => undefined);
          const source = req.body as Readable;
          source.on('error', (err) => gate.destroy(err));
          source.on('close', () => {
            if (!source.readableEnded) gate.destroy(new Error('Die Anfrage wurde abgebrochen.'));
          });
          source.pipe(gate);
          try {
            await files.put(key, gate, APK_TYPE);
          } catch (err) {
            throw gate.failure ?? err;
          }

          const sha256 = gate.digest();
          try {
            await withSystem(db, async (c) => {
              await c.query(
                `insert into releases (id, version, build, file_key, sha256, size, link_secret, uploaded_at)
                 values ($1, $2, $3, $4, $5, $6, $7, $8)`,
                [id, version, build, key, sha256, gate.size, secret, at],
              );
              // Nie der geheime Teil des Links und nie der Schlüssel.
              await audit(c, { userId: undefined, action: 'release.upload', detail: { version, build } }, at);
            });
          } catch (err) {
            if ((err as { code?: string }).code === UNIQUE_VIOLATION) throw releaseExists();
            throw err;
          }
          return reply.code(201).send({
            id,
            version,
            build,
            sha256,
            size: gate.size,
            downloadPath: downloadPath(secret, version),
          });
        } catch (err) {
          // Was auch schiefging: in der Ablage bleibt nichts liegen.
          await files.delete(key).catch(() => undefined);
          reply.header('connection', 'close');
          throw err;
        }
      },
    );
  });

  // Laden über den geheimen Link. Unbekannt, zurückgezogen und falscher Dateiname sehen gleich aus.
  app.get<{ Params: { secret: string; filename: string } }>('/laden/:secret/:filename', async (req, reply) => {
    reply.header('cache-control', 'private, no-store').header('x-robots-tag', 'noindex');
    const gone = () => reply.code(404).type('text/plain; charset=utf-8').send(GONE_TEXT);
    const row = (
      await withSystem(db, (c) =>
        c.query<{ version: string; file_key: string }>(
          'select version, file_key from releases where link_secret = $1 and withdrawn_at is null',
          [req.params.secret],
        ),
      )
    ).rows[0];
    if (!row || req.params.filename !== `kassa-${row.version}.apk`) return gone();
    const file = await files.get(row.file_key);
    if (!file) return gone();
    return reply
      .type(APK_TYPE)
      .header('content-disposition', `attachment; filename="kassa-${row.version}.apk"`)
      .header('content-length', file.size)
      .send(file.body);
  });

  app.get('/api/admin/releases', async (req) => {
    requireProvider(req);
    const rows = await withSystem(
      db,
      async (c) =>
        (
          await c.query<ReleaseRow>(
            `select id, version, build, sha256, size, link_secret, uploaded_at, withdrawn_at
             from releases order by uploaded_at desc, id`,
          )
        ).rows,
    );
    return { releases: rows.map(toWire) };
  });

  app.delete<{ Params: { id: string } }>('/api/admin/releases/:id', async (req, reply) => {
    const user = requireProvider(req);
    if (!isUuid(req.params.id)) throw notFound();
    const at = now();
    const row = await withSystem(db, async (c) => {
      const r = await c.query<{ version: string; build: number; file_key: string }>(
        `update releases set withdrawn_at = coalesce(withdrawn_at, $2) where id = $1 returning version, build, file_key`,
        [req.params.id.toLowerCase(), at],
      );
      const found = r.rows[0];
      if (!found) throw notFound();
      await audit(c, { userId: user.id, action: 'release.withdraw', detail: { version: found.version, build: found.build } }, at);
      return found;
    });
    // Erst nach dem Vermerk: Ist die Datei nicht zu löschen, gilt der Link trotzdem nicht mehr, und Wiederholen räumt auf.
    await files.delete(row.file_key);
    return reply.code(204).send();
  });
}
