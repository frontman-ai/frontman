import { defineMiddleware } from 'astro:middleware';

export const onRequest = defineMiddleware(async (context, next) => {
  // Custom authentication middleware
  const token = context.cookies.get('token');
  if (!token) {
    return context.redirect('/login');
  }
  return next();
});
