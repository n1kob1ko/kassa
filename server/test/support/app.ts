import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import type { FastifyInstance } from 'fastify';
import { buildApp, type AppDeps } from '../../src/app.js';
import type { Config } from '../../src/config.js';
import type { Db } from '../../src/db/db.js';
import { createTestDb, TEST_APP_PASSWORD } from './db.js';

export type TestApp = {
  app: FastifyInstance;
  db: Db;
  now: { value: Date };
  close(): Promise<void>;
};

export async function testApp(
  overrides: Omit<Partial<AppDeps>, 'config'> & { config?: Partial<Config> } = {},
): Promise<TestApp> {
  const testDb = await createTestDb();
  const fileDir = await mkdtemp(join(tmpdir(), 'kassa-files-'));
  const now = { value: new Date('2026-11-18T10:00:00Z') };
  const config: Config = {
    databaseUrl: testDb.ownerUrl,
    appDbPassword: TEST_APP_PASSWORD,
    port: 0,
    publicUrl: 'http://localhost',
    fileDir,
    passwordCost: 1024,
    ...overrides.config,
  };
  const app = await buildApp({
    config,
    db: overrides.db ?? testDb.db,
    files: overrides.files,
    now: overrides.now ?? (() => now.value),
    ...(overrides.randomCode ? { randomCode: overrides.randomCode } : {}),
  });
  return {
    app,
    db: overrides.db ?? testDb.db,
    now,
    async close() {
      await app.close();
      await testDb.drop();
      await rm(fileDir, { recursive: true, force: true });
    },
  };
}
