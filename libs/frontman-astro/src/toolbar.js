// Thin re-export so the Integration module can reference ./toolbar.js
// and Astro/Vite can resolve it at dev time.
// In production builds, tsup bundles FrontmanAstro__ToolbarApp.res.mjs
// directly into dist/toolbar.js.
export { default } from './FrontmanAstro__ToolbarApp.res.mjs';
