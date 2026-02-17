import { createMiddleware, makeConfig } from '@frontman-ai/astro';
import { defineMiddleware } from 'astro:middleware';

const config = makeConfig({ host: 'old-js-server.company.com' });
const frontman = createMiddleware(config);

export const onRequest = defineMiddleware(async (context, next) => {
  return frontman(context, next);
});
