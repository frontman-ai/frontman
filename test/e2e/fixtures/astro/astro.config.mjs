import { defineConfig } from 'astro/config';
import frontman from '@frontman-ai/astro';

export default defineConfig({
  integrations: [
    frontman({
      host: 'localhost:4002',
      projectRoot: import.meta.dirname,
    }),
  ],
});
