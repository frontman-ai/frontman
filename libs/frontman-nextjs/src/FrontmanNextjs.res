// Frontman NextJS Integration - exposes framework tools via HTTP
// Used by FrontmanClient__Relay to execute file system operations

module Config = FrontmanNextjs__Config
module Middleware = FrontmanNextjs__Middleware
module Server = FrontmanNextjs__Server
module ToolRegistry = FrontmanNextjs__ToolRegistry

module SSE = AskTheLlmFrontmanCore.FrontmanCore__SSE

module OpenTelemetry = FrontmanNextjs__OpenTelemetry

module Instrumentation = FrontmanNextjs__Instrumentation

// Re-export for convenience
let createMiddleware = Middleware.createMiddleware
let makeConfig = Config.make
type config = Config.t
