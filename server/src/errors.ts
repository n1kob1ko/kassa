import type { FastifyError, FastifyInstance } from 'fastify';

/** Ein erwarteter Fehler mit Status, Code und einem deutschen Satz für Menschen. */
export class ApiError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
    readonly extra?: object,
  ) {
    super(message);
    this.name = 'ApiError';
  }
}

const INTERNAL_MESSAGE = 'Das hat nicht geklappt. Bitte nochmal versuchen.';

export function installErrorHandling(app: FastifyInstance): void {
  app.setNotFoundHandler((_req, reply) => {
    reply.code(404).send({ error: { code: 'not_found', message: 'Das gibt es nicht.' } });
  });

  app.setErrorHandler((err: FastifyError | ApiError, req, reply) => {
    if (err instanceof ApiError) {
      return reply.code(err.status).send({ error: { code: err.code, message: err.message }, ...err.extra });
    }
    const status = (err as FastifyError).statusCode;
    if (status === 413) {
      return reply
        .code(413)
        .send({ error: { code: 'payload_too_large', message: 'Die Anfrage ist zu groß.' } });
    }
    if (status !== undefined && status >= 400 && status < 500) {
      return reply
        .code(400)
        .send({ error: { code: 'bad_request', message: 'Die Anfrage ist nicht in Ordnung.' } });
    }
    req.log.error({ err }, 'unerwarteter Fehler');
    return reply.code(500).send({ error: { code: 'internal', message: INTERNAL_MESSAGE } });
  });
}
