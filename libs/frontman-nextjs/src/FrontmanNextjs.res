// Frontman NextJS Integration - exposes framework tools via HTTP
// Used by FrontmanClient__Relay to execute file system operations

module Middleware = FrontmanNextjs__Middleware
module Server = FrontmanNextjs__Server
module ToolRegistry = FrontmanNextjs__ToolRegistry
module SSE = FrontmanNextjs__SSE

// Re-export for convenience
let createMiddleware = Middleware.createMiddleware
type config = Middleware.config
let defaultConfig = Middleware.defaultConfig
