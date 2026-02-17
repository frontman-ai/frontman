// Thin wrapper to provide `export default` for `astro add` CLI compatibility.
// ReScript doesn't support default exports natively.
export { frontmanIntegration as default, frontmanIntegration } from './src/FrontmanAstro.res.mjs';
