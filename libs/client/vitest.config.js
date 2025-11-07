import { defineConfig } from 'vite'

export default defineConfig({
  test: {
    environment: 'jsdom',
    globals: true,
    include: ['test/**/*.test.res.mjs', 'test/**/*.test.mjs'],
  },
})
