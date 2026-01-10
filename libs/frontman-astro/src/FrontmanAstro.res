// Frontman Astro Integration - exposes framework tools via HTTP
// Used by FrontmanClient__Relay to execute file system operations

module Config = FrontmanAstro__Config
module Middleware = FrontmanAstro__Middleware
module Server = FrontmanAstro__Server
module ToolRegistry = FrontmanAstro__ToolRegistry
module Integration = FrontmanAstro__Integration

// Re-export core SSE for convenience
module SSE = FrontmanFrontmanCore.FrontmanCore__SSE

// Re-export for convenience
let createMiddleware = Middleware.createMiddleware
// makeConfig accepts an object with optional fields - JS-friendly API
let makeConfig = Config.makeFromObject
type config = Config.t

// Integration export
let frontmanIntegration = Integration.make
