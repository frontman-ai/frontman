import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    environment: 'jsdom',
    include: ['test/**/*.test.res.mjs'],
    globals: true,
    passWithNoTests: true,
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json-summary', 'cobertura'],
      include: ['src/**/*.res.mjs'],
      exclude: [
        '**/*.test.*',
      ],
    },
  },
});
