/**
 * Zugang zur Schnittstelle des Servers. Jede Anfrage trägt `X-Kassa-Request: 1` (Schutz gegen fremde Seiten)
 * und das Sitzungs-Cookie. Jeder Fehler wird ein `ApiError`; die Seiten entscheiden nach `code`, nie nach `message`.
 */

const INTERNAL_MESSAGE = 'Das hat nicht geklappt. Bitte nochmal versuchen.';
const NETWORK_MESSAGE = 'Keine Verbindung zum Server. Prüf dein Internet und versuch es nochmal.';

/** Seiten, auf denen eine 401 erwartet ist und nicht zur Anmeldung führt. */
const AUTH_PAGES = ['/anmelden', '/einrichten'];

export class ApiError extends Error {
  readonly status: number;
  readonly code: string;
  readonly problems?: string[];
  readonly retryAfterSeconds?: number;

  constructor(
    status: number,
    code: string,
    message: string,
    extra: { problems?: string[]; retryAfterSeconds?: number } = {},
  ) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
    this.code = code;
    if (extra.problems !== undefined) this.problems = extra.problems;
    if (extra.retryAfterSeconds !== undefined) this.retryAfterSeconds = extra.retryAfterSeconds;
  }
}

let onUnauthorized: () => void = () => {
  globalThis.location.assign('/anmelden');
};

/** Was bei 401 außerhalb der Anmeldeseiten passiert. main.tsx setzt hier die Weiterleitung im Router. */
export function setUnauthorizedHandler(handler: () => void): void {
  onUnauthorized = handler;
}

function onAuthPage(): boolean {
  const path = globalThis.location?.pathname ?? '';
  return AUTH_PAGES.some((p) => path === p || path.startsWith(`${p}/`));
}

type ErrorBody = {
  error?: { code?: unknown; message?: unknown };
  problems?: unknown;
  retryAfterSeconds?: unknown;
};

async function toApiError(res: Response): Promise<ApiError> {
  let body: ErrorBody | undefined;
  try {
    body = (await res.json()) as ErrorBody;
  } catch {
    body = undefined;
  }
  const code = body?.error?.code;
  const message = body?.error?.message;
  if (typeof code !== 'string' || typeof message !== 'string') {
    return new ApiError(res.status, 'internal', INTERNAL_MESSAGE);
  }
  const problems = Array.isArray(body?.problems)
    ? body.problems.filter((p): p is string => typeof p === 'string')
    : undefined;
  let retryAfterSeconds = typeof body?.retryAfterSeconds === 'number' ? body.retryAfterSeconds : undefined;
  if (retryAfterSeconds === undefined) {
    const header = Number(res.headers.get('retry-after'));
    if (Number.isFinite(header) && header > 0) retryAfterSeconds = header;
  }
  return new ApiError(res.status, code, message, { problems, retryAfterSeconds });
}

/**
 * Der Fehler einer Antwort, die nicht über `api` kam (etwa ein Hochladen mit Fortschritt): dieselbe Form wie bei
 * `api`, und bei 401 außerhalb der Anmeldeseiten dieselbe Weiterleitung.
 */
export async function errorOf(res: Response): Promise<ApiError> {
  const err = await toApiError(res);
  if (res.status === 401 && !onAuthPage()) onUnauthorized();
  return err;
}

/** Der Fehler, wenn der Server gar nicht antwortet. */
export function networkError(): ApiError {
  return new ApiError(0, 'network', NETWORK_MESSAGE);
}

async function request<T>(method: string, path: string, body?: unknown): Promise<T> {
  const headers: Record<string, string> = { 'X-Kassa-Request': '1' };
  const init: RequestInit = { method, headers, credentials: 'same-origin' };
  if (body !== undefined) {
    headers['Content-Type'] = 'application/json';
    init.body = JSON.stringify(body);
  }

  let res: Response;
  try {
    res = await fetch(path, init);
  } catch {
    throw networkError();
  }

  if (!res.ok) throw await errorOf(res);
  if (res.status === 204) return undefined as T;
  // Eine Antwort, die kein JSON ist (etwa eine Fehlerseite eines Proxys mit 200), ist für die Seite ein Fehler.
  try {
    const text = await res.text();
    return (text === '' ? undefined : JSON.parse(text)) as T;
  } catch {
    throw new ApiError(res.status, 'internal', INTERNAL_MESSAGE);
  }
}

export const api = {
  get: <T>(path: string) => request<T>('GET', path),
  post: <T>(path: string, body?: unknown) => request<T>('POST', path, body),
  put: <T>(path: string, body: unknown) => request<T>('PUT', path, body),
  patch: <T>(path: string, body: unknown) => request<T>('PATCH', path, body),
  del: (path: string) => request<void>('DELETE', path),
};
