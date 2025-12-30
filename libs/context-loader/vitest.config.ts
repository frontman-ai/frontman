import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    environment: 'node',
    include: ['tests/**/*.test.res.mjs'],

    // Coverage configuration
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json-summary', 'cobertura'],
      include: ['src/**/*.res.mjs'],
      exclude: [
        '**/*.test.*',
        '**/*.story.*',
        'src/**/*.res.d.ts',
        'src/Bindings__*.res.mjs',
      ],
    },
  },
})
