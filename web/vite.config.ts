import react from '@vitejs/plugin-react';
import { defineConfig } from 'vitest/config';

// Der Server läuft beim Entwickeln auf Port 3000 (siehe server/README.md).
const SERVER = 'http://localhost:3000';

export default defineConfig({
  plugins: [react()],
  server: {
    proxy: {
      '/api': SERVER,
      '/laden': SERVER,
    },
  },
  build: {
    // Nichts als data:-Adresse einbetten: die Content-Security-Policy lässt Schriften nur von der eigenen Adresse zu.
    assetsInlineLimit: 0,
  },
  test: {
    include: ['src/**/*.test.ts'],
    environment: 'node',
  },
});
