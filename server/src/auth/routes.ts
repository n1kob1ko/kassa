import type { CookieSerializeOptions } from '@fastify/cookie';
import type { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';
import type pg from 'pg';
import { z } from 'zod';
import { audit } from '../audit.js';
import { clientAddress } from '../client_address.js';
import { withSystem } from '../db/tenant.js';
import { ApiError } from '../errors.js';
import { SlidingWindow } from '../rate_limit.js';
import { requireUser } from './guards.js';
import { clearLoginFailures, loginWait, recordLoginFailure } from './login_throttle.js';
import { hashPassword, verifyPassword } from './passwords.js';
import { safeEqual, sha256 } from './secrets.js';
import {
  createSession,
  deleteSession,
  findSessionUser,
  SESSION_MAX_AGE_SECONDS,
  sessionCookieName,
  type SessionUser,
} from './sessions.js';

const MIN_PASSWORD_LENGTH = 10;
const LOGIN_ATTEMPTS_PER_ADDRESS = 30;
const LOGIN_WINDOW_MS = 15 * 60 * 1000;
const MAX_EMAIL_LENGTH = 254;
const EMAIL = /^[^\s@]+@[^\s@]+$/;
const UNIQUE_VIOLATION = '23505';

type UserRow = {
  id: string;
  email: string;
  role: 'provider' | 'chef';
  business_id: string | null;
  password_hash: string | null;
  disabled_at: Date | null;
};

const setupBody = z.object({ token: z.string(), email: z.string(), password: z.string() });
const loginBody = z.object({ email: z.string(), password: z.string() });

const loginFailed = () => new ApiError(401, 'login_failed', 'E-Mail oder Passwort stimmt nicht.');
const setupInvalid = () => new ApiError(403, 'setup_invalid', 'Dieser Link gilt nicht mehr. Bitte einen neuen anfordern.');
const csrf = () => new ApiError(403, 'csrf', 'Diese Anfrage wurde abgelehnt. Bitte lade die Seite neu.');

function parse<T>(schema: z.ZodType<T>, body: unknown): T {
  const r = schema.safeParse(body);
  if (!r.success) throw new ApiError(400, 'bad_request', 'Die Anfrage ist nicht in Ordnung.');
  return r.data;
}

function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
}

/** Die Adresse der Route, bei unbekannten Adressen der Pfad ohne Abfrage. */
function routePath(req: FastifyRequest): string {
  return req.routeOptions.url ?? req.url.split('?')[0]!;
}

function underApi(path: string, area: string): boolean {
  return path === area || path.startsWith(`${area}/`);
}

/**
 * Anmeldung im Browser: Cookie lesen, Schutz für ändernde Anfragen und die Adressen unter /api/auth.
 * Wird direkt auf der Wurzel der App aufgerufen, damit die Hooks für alle Adressen gelten.
 */
export function installAuth(app: FastifyInstance): void {
  const { config, db, now } = app.deps;
  const cookieName = sessionCookieName(config.publicUrl);
  const cookieOptions: CookieSerializeOptions = {
    httpOnly: true,
    sameSite: 'lax',
    path: '/',
    secure: config.publicUrl.startsWith('https://'),
  };

  // Für unbekannte E-Mails wird gegen diesen Wert gerechnet, damit die Antwort gleich lange dauert.
  let dummyHash: Promise<string> | undefined;
  const dummy = () => (dummyHash ??= hashPassword('kein-echtes-passwort', config.passwordCost));

  // Pro App eine eigene Zählung. Ein Erfolg gibt keinen Platz frei: Sonst hält ein Konto die Tür für fremde Versuche auf.
  const attemptsPerAddress = new SlidingWindow(LOGIN_ATTEMPTS_PER_ADDRESS, LOGIN_WINDOW_MS);

  app.decorateRequest('user', null);

  // Eine fremde Seite kann weder eigene Kopfzeilen setzen noch ihr Origin verbergen.
  app.addHook('onRequest', async (req) => {
    if (req.method === 'GET' || req.method === 'HEAD') return;
    const path = routePath(req);
    if (!underApi(path, '/api/auth') && !underApi(path, '/api/admin')) return;
    if (req.headers['x-kassa-request'] !== '1') throw csrf();
    const origin = req.headers.origin;
    if (origin !== undefined && origin !== config.publicUrl) throw csrf();
  });

  app.addHook('onRequest', async (req) => {
    const value = req.cookies[cookieName];
    if (!value || !underApi(routePath(req), '/api')) return;
    req.user = await withSystem(db, (c) => findSessionUser(c, value, now()));
  });

  /** Legt die Sitzung in der laufenden Transaktion an und schreibt den Verlauf. Gibt den Cookie-Wert zurück. */
  async function openSession(c: pg.ClientBase, user: SessionUser, at: Date, action: string): Promise<string> {
    const token = await createSession(c, user.id, at);
    await audit(c, { userId: user.id, businessId: user.businessId ?? undefined, action }, at);
    return token;
  }

  function setSessionCookie(reply: FastifyReply, token: string): void {
    reply.setCookie(cookieName, token, { ...cookieOptions, maxAge: SESSION_MAX_AGE_SECONDS });
  }

  async function setupTokenUsable(token: string): Promise<boolean> {
    if (config.setupToken === undefined || !safeEqual(token, config.setupToken)) return false;
    const r = await withSystem(db, (c) => c.query('select 1 from used_secrets where secret_hash = $1', [sha256(token)]));
    return r.rowCount === 0;
  }

  app.get<{ Querystring: { token?: string } }>('/api/auth/setup', async (req) => {
    const token = typeof req.query.token === 'string' ? req.query.token : '';
    return { valid: await setupTokenUsable(token) };
  });

  app.post('/api/auth/setup', async (req, reply) => {
    const body = parse(setupBody, req.body);
    if (!(await setupTokenUsable(body.token))) throw setupInvalid();
    const email = normalizeEmail(body.email);
    if (!EMAIL.test(email) || email.length > MAX_EMAIL_LENGTH) {
      throw new ApiError(422, 'email_invalid', 'Diese E-Mail-Adresse stimmt so nicht.');
    }
    if ([...body.password].length < MIN_PASSWORD_LENGTH) {
      throw new ApiError(422, 'password_too_short', 'Das Passwort braucht mindestens 10 Zeichen.');
    }
    const hash = await hashPassword(body.password, config.passwordCost);
    const at = now();

    const emailTaken = () => new ApiError(409, 'email_taken', 'Diese E-Mail-Adresse ist schon vergeben.');
    const { user, token, reset } = await withSystem(db, async (c) => {
      // Der Schlüssel gilt als verbraucht, sobald diese Transaktion gelingt. Von zwei gleichzeitigen gewinnt eine.
      // Jeder Fehler danach rollt alles zurück: Schlüssel, Passwort und Sitzungen bleiben dann, wie sie waren.
      const used = await c.query(
        'insert into used_secrets (secret_hash, used_at) values ($1, $2) on conflict do nothing',
        [sha256(body.token), at],
      );
      if (used.rowCount === 0) throw setupInvalid();

      const existing = (
        await c.query<UserRow>(
          `select id, email, role, business_id, password_hash, disabled_at from users where lower(email) = $1 for update`,
          [email],
        )
      ).rows[0];
      if (existing) {
        // Ein neuer Schlüssel setzt nur das Passwort eines Anbieters neu. Er macht nie einen Chef zum Anbieter
        // und hebt keine Sperre auf.
        if (existing.role !== 'provider' || existing.disabled_at !== null) throw emailTaken();
        await c.query('update users set password_hash = $2 where id = $1', [existing.id, hash]);
        await c.query('delete from sessions where user_id = $1', [existing.id]);
        await clearLoginFailures(c, email);
        const found: SessionUser = { id: existing.id, email: existing.email, role: 'provider', businessId: null };
        return { user: found, token: await openSession(c, found, at, 'auth.setup_reset'), reset: true };
      }

      let id: string;
      try {
        const r = await c.query<{ id: string }>(
          `insert into users (email, password_hash, role, created_at) values ($1, $2, 'provider', $3) returning id`,
          [email, hash, at],
        );
        id = r.rows[0]!.id;
      } catch (err) {
        if ((err as { code?: string }).code === UNIQUE_VIOLATION) throw emailTaken();
        throw err;
      }
      const created: SessionUser = { id, email, role: 'provider', businessId: null };
      return { user: created, token: await openSession(c, created, at, 'auth.setup'), reset: false };
    });
    setSessionCookie(reply, token);
    return reply.code(reset ? 200 : 201).send({ user });
  });

  /** 429 mit Retry-After und dem Satz, wie lange es noch dauert. */
  function tooManyAttempts(reply: FastifyReply, seconds: number): ApiError {
    const minutes = Math.ceil(seconds / 60);
    reply.header('retry-after', String(seconds));
    return new ApiError(
      429,
      'too_many_attempts',
      `Zu viele Versuche. Bitte in ${minutes} ${minutes === 1 ? 'Minute' : 'Minuten'} nochmal.`,
      { retryAfterSeconds: seconds },
    );
  }

  app.post('/api/auth/login', async (req, reply) => {
    const body = parse(loginBody, req.body);
    const email = normalizeEmail(body.email);
    const at = now();

    // Vor dem Rechnen des Passworts: Jeder Versuch kostet Rechenzeit und Speicher, auch mit immer neuer E-Mail.
    const address = clientAddress(req, config);
    if (!attemptsPerAddress.hit(address, at)) {
      throw tooManyAttempts(reply, Math.ceil(attemptsPerAddress.retryAfterMs(address, at) / 1000));
    }

    const wait = await withSystem(db, (c) => loginWait(c, email, at));
    if (wait > 0) throw tooManyAttempts(reply, wait);

    const row = (
      await withSystem(db, (c) =>
        c.query<UserRow>(
          'select id, email, role, business_id, password_hash, disabled_at from users where lower(email) = $1',
          [email],
        ),
      )
    ).rows[0];
    // Auch ohne Benutzer wird ein Passwort gerechnet, damit die Antwortzeit nichts verrät.
    const matches = await verifyPassword(body.password, row?.password_hash ?? (await dummy()));
    if (!row || row.password_hash === null || row.disabled_at !== null || !matches) {
      await withSystem(db, (c) => recordLoginFailure(c, email, at));
      throw loginFailed();
    }

    const user: SessionUser = { id: row.id, email: row.email, role: row.role, businessId: row.business_id };
    const token = await withSystem(db, async (c) => {
      await clearLoginFailures(c, email);
      return openSession(c, user, at, 'auth.login');
    });
    setSessionCookie(reply, token);
    return { user };
  });

  app.post('/api/auth/logout', async (req, reply) => {
    const value = req.cookies[cookieName];
    if (value) {
      await withSystem(db, async (c) => {
        await deleteSession(c, value);
        if (req.user) {
          const { id, businessId } = req.user;
          await audit(c, { userId: id, businessId: businessId ?? undefined, action: 'auth.logout' }, now());
        }
      });
    }
    reply.clearCookie(cookieName, cookieOptions);
    return reply.code(204).send();
  });

  app.get('/api/auth/me', async (req) => ({ user: requireUser(req) }));
}

declare module 'fastify' {
  interface FastifyRequest {
    /** Der angemeldete Benutzer aus dem Sitzungs-Cookie, sonst null. Über requireUser lesen. */
    user: SessionUser | null;
  }
}
