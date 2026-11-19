export type S3Config = {
  endpoint: string;
  bucket: string;
  accessKeyId: string;
  secretAccessKey: string;
  region: string;
  /** `virtual`: Bucket im Hostnamen (Vorgabe, so arbeitet Railway). `path`: Bucket im Pfad, etwa für eine lokale Nachbildung. */
  urlStyle: 'virtual' | 'path';
};

export type Config = {
  databaseUrl: string;
  appDbPassword: string;
  port: number;
  /** Die Herkunft (`new URL(...).origin`): Schema, Host klein geschrieben, Port nur wenn nicht Standard, kein Pfad. */
  publicUrl: string;
  setupToken?: string;
  releaseToken?: string;
  fileDir?: string;
  s3?: S3Config;
  webDir?: string;
  /** Kopfzeile mit der Adresse des Clients, klein geschrieben. Nur hinter einem Proxy setzen, der sie überschreibt. */
  clientIpHeader?: string;
  passwordCost: number;
  /** Das Programm `pg_dump` für die nächtliche Sicherung (Pfad oder Name). Vorgabe `pg_dump`. */
  pgDumpPath?: string;
  /** `BACKUP_DISABLED=1`: keine nächtliche Sicherung (zum Beispiel in der Entwicklung). */
  backupDisabled?: boolean;
};

/** Mindestlänge der Schlüssel aus den Einstellungen. Der Einrichtungs-Schlüssel setzt das Passwort des Anbieters neu. */
const MIN_TOKEN_LENGTH = 32;

const S3_VARS = ['S3_ENDPOINT', 'S3_BUCKET', 'S3_ACCESS_KEY_ID', 'S3_SECRET_ACCESS_KEY', 'S3_REGION'] as const;

function present(env: NodeJS.ProcessEnv, name: string): string | undefined {
  const v = env[name];
  return v === undefined || v === '' ? undefined : v;
}

export function loadConfig(env: NodeJS.ProcessEnv): Config {
  const problems: string[] = [];
  const missing: string[] = [];

  const need = (name: string): string => {
    const v = present(env, name);
    if (v === undefined) missing.push(name);
    return v ?? '';
  };

  // Fehlermeldungen nennen nur den Namen einer Variable, nie ihren Wert: Darin können Passwörter stehen.
  const databaseUrl = need('DATABASE_URL');
  if (databaseUrl !== '') {
    let ok = false;
    try {
      const u = new URL(databaseUrl);
      ok = (u.protocol === 'postgres:' || u.protocol === 'postgresql:') && u.hostname !== '';
    } catch {
      ok = false;
    }
    if (!ok) problems.push('DATABASE_URL ist keine gültige Adresse der Form postgres://…');
  }
  const appDbPassword = need('APP_DB_PASSWORD');
  const rawPublicUrl = need('PUBLIC_URL');

  // Der Browser schickt im Origin genau die Herkunft: Nur so stimmt der Vergleich beim Schutz für ändernde Anfragen.
  let publicUrl = '';
  if (rawPublicUrl !== '') {
    try {
      const u = new URL(rawPublicUrl);
      if (u.protocol !== 'https:' && u.protocol !== 'http:') throw new Error('kein http');
      publicUrl = u.origin;
    } catch {
      problems.push('PUBLIC_URL ist keine gültige Adresse der Form https://…');
    }
  }

  const token = (name: string): string | undefined => {
    const v = present(env, name);
    if (v !== undefined && v.length < MIN_TOKEN_LENGTH) {
      problems.push(`${name} muss mindestens ${MIN_TOKEN_LENGTH} Zeichen lang sein`);
    }
    return v;
  };
  const setupToken = token('SETUP_TOKEN');
  const releaseToken = token('RELEASE_TOKEN');

  let port = 3000;
  const rawPort = present(env, 'PORT');
  if (rawPort !== undefined) {
    port = Number(rawPort);
    if (!Number.isInteger(port) || port < 1 || port > 65535) {
      problems.push('PORT muss eine Zahl zwischen 1 und 65535 sein');
    }
  }

  const fileDir = present(env, 'FILE_DIR');
  const s3Present = S3_VARS.filter((n) => present(env, n) !== undefined);
  let s3: S3Config | undefined;
  if (fileDir !== undefined && s3Present.length > 0) {
    problems.push('FILE_DIR und die S3_-Variablen dürfen nicht zusammen gesetzt sein');
  } else if (fileDir === undefined && s3Present.length === 0) {
    missing.push('FILE_DIR (oder die S3_-Variablen)');
  } else if (s3Present.length > 0) {
    const absent = S3_VARS.filter((n) => present(env, n) === undefined);
    if (absent.length > 0) {
      missing.push(...absent);
    } else {
      const rawStyle = present(env, 'S3_URL_STYLE') ?? 'virtual';
      if (rawStyle !== 'virtual' && rawStyle !== 'path') {
        problems.push('S3_URL_STYLE muss virtual oder path sein');
      }
      s3 = {
        endpoint: env.S3_ENDPOINT!,
        bucket: env.S3_BUCKET!,
        accessKeyId: env.S3_ACCESS_KEY_ID!,
        secretAccessKey: env.S3_SECRET_ACCESS_KEY!,
        region: env.S3_REGION!,
        urlStyle: rawStyle === 'path' ? 'path' : 'virtual',
      };
    }
  }

  let clientIpHeader = present(env, 'CLIENT_IP_HEADER')?.trim().toLowerCase();
  if (clientIpHeader === '') clientIpHeader = undefined;
  if (clientIpHeader !== undefined && !/^[a-z0-9-]+$/.test(clientIpHeader)) {
    problems.push('CLIENT_IP_HEADER muss der Name einer Kopfzeile sein, zum Beispiel x-real-ip');
  }

  const parts: string[] = [];
  if (missing.length > 0) parts.push(`Es fehlen Einstellungen: ${missing.join(', ')}`);
  parts.push(...problems);
  if (parts.length > 0) throw new Error(`${parts.join('. ')}.`);

  return {
    databaseUrl,
    appDbPassword,
    port,
    publicUrl,
    setupToken,
    releaseToken,
    fileDir,
    s3,
    webDir: present(env, 'WEB_DIR'),
    clientIpHeader,
    passwordCost: 131072,
    pgDumpPath: present(env, 'PG_DUMP_PATH') ?? 'pg_dump',
    backupDisabled: present(env, 'BACKUP_DISABLED') === '1',
  };
}

/** Hinweise für das Start-Protokoll: Einstellungen, die gültig sind, aber vermutlich nicht so gemeint. */
export function configWarnings(config: Pick<Config, 'publicUrl' | 'clientIpHeader'>): string[] {
  const warnings: string[] = [];
  if (config.publicUrl.startsWith('https://') && config.clientIpHeader === undefined) {
    warnings.push(
      'CLIENT_IP_HEADER ist nicht gesetzt: Hinter einem Proxy teilen sich dann alle Geräte einen Zähler für Fehlversuche.',
    );
  }
  return warnings;
}
