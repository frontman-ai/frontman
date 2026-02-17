import { defineConfig } from 'astro/config';
import node from '@astrojs/node';
import { frontmanIntegration } from '@frontman-ai/astro';

const isProd = process.env.NODE_ENV === 'production';

export default defineConfig({
  ...(isProd ? {} : { output: 'server', adapter: node({ mode: 'standalone' }) }),
  integrations: [frontmanIntegration()],
});
