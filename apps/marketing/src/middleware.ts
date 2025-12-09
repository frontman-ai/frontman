import { defineMiddleware } from "astro:middleware";

const FRONTMAN_ENABLED = import.meta.env.DEV;

// Only load frontman in dev mode - completely safe in production
const frontman = FRONTMAN_ENABLED
  ? await (async () => {
      const { createMiddleware, makeConfig } = await import(
        "@ask-the-llm/frontman-astro/src/FrontmanAstro.res.mjs"
      );
      const config = makeConfig(
        process.cwd(), // ~projectRoot
        "__frontman",  // ~basePath
        "marketing",   // ~serverName
        "1.0.0",       // ~serverVersion
      );
      return createMiddleware(config);
    })()
  : null;

export const onRequest = defineMiddleware(async (context, next) => {
  if (frontman) {
    return frontman(context, next);
  }
  return next();
});
