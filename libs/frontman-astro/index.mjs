// Thin wrapper to provide `export default` for `astro add` CLI compatibility.
// ReScript doesn't support default exports natively.
//
// The integration now handles everything automatically via frontman() —
// createMiddleware and makeConfig are no longer needed by end users.
export { frontmanIntegration as default, frontmanIntegration, makeConfig } from './src/FrontmanAstro.res.mjs';
