// Frontman Astro Integration - official Astro integration for Frontman
//
// Usage in astro.config.mjs:
//   import frontman from '@frontman-ai/astro';
//   export default defineConfig({
//     integrations: [frontman({ projectRoot: import.meta.dirname })],
//   });

module Config = FrontmanAstro__Config
module Middleware = FrontmanAstro__Middleware
module Server = FrontmanAstro__Server
module ToolRegistry = FrontmanAstro__ToolRegistry
module Integration = FrontmanAstro__Integration
module ViteAdapter = FrontmanAstro__ViteAdapter

// Re-export core SSE for convenience
module SSE = FrontmanAiFrontmanCore.FrontmanCore__SSE

// The main integration factory - accepts optional config
// This is also exported as default for `astro add` compatibility
let frontmanIntegration = Integration.make

// Re-export config types for advanced usage
type config = Config.t
type configInput = Config.jsConfigInput
let makeConfig = Config.makeFromObject
