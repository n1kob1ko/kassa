export type S3Config = {
  endpoint: string;
  bucket: string;
  accessKeyId: string;
  secretAccessKey: string;
  region: string;
};

export type Config = {
  databaseUrl: string;
  appDbPassword: string;
  port: number;
  publicUrl: string;
  setupToken?: string;
  releaseToken?: string;
  fileDir?: string;
  s3?: S3Config;
  webDir?: string;
  passwordCost: number;
};

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

  const databaseUrl = need('DATABASE_URL');
  const appDbPassword = need('APP_DB_PASSWORD');
  const rawPublicUrl = need('PUBLIC_URL');

  let publicUrl = rawPublicUrl.replace(/\/+$/, '');
  if (rawPublicUrl !== '') {
    try {
      new URL(publicUrl);
    } catch {
      problems.push('PUBLIC_URL ist keine gültige Adresse');
    }
  }

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
      s3 = {
        endpoint: env.S3_ENDPOINT!,
        bucket: env.S3_BUCKET!,
        accessKeyId: env.S3_ACCESS_KEY_ID!,
        secretAccessKey: env.S3_SECRET_ACCESS_KEY!,
        region: env.S3_REGION!,
      };
    }
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
    setupToken: present(env, 'SETUP_TOKEN'),
    releaseToken: present(env, 'RELEASE_TOKEN'),
    fileDir,
    s3,
    webDir: present(env, 'WEB_DIR'),
    passwordCost: 131072,
  };
}
