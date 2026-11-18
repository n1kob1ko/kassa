import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    include: ['test/**/*.test.ts'],
    globalSetup: ['test/support/global_setup.ts'],
    testTimeout: 20000,
    hookTimeout: 60000,
  },
});
