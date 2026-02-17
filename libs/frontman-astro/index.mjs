// Thin wrapper to provide `export default` for `astro add` CLI compatibility.
// ReScript doesn't support default exports natively.
//
// Also re-exports createMiddleware + makeConfig for backward compat with
// the CLI installer templates (which generate `import { createMiddleware, makeConfig } from '@frontman-ai/astro'`).
export { frontmanIntegration as default, frontmanIntegration, makeConfig } from './src/FrontmanAstro.res.mjs';
export { createMiddleware } from './src/FrontmanAstro__Middleware.res.mjs';
