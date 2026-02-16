import { createMiddleware, makeConfig } from '@frontman/frontman-astro';
import { defineMiddleware } from 'astro:middleware';

const config = makeConfig({ host: 'old-server.company.com' });
const frontman = createMiddleware(config);

export const onRequest = defineMiddleware(async (context, next) => {
  return frontman(context, next);
});
