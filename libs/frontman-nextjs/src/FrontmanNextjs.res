// Frontman NextJS Integration - exposes framework tools via HTTP
// Used by FrontmanClient__Relay to execute file system operations

module Config = FrontmanNextjs__Config
module Middleware = FrontmanNextjs__Middleware
module Server = FrontmanNextjs__Server
module ToolRegistry = FrontmanNextjs__ToolRegistry

module SSE = FrontmanFrontmanCore.FrontmanCore__SSE

module OpenTelemetry = FrontmanNextjs__OpenTelemetry

module Instrumentation = FrontmanNextjs__Instrumentation

// Re-export for convenience
// createMiddleware takes a config object (use makeConfig to create one)
let createMiddleware = Middleware.createMiddleware
// makeConfig accepts an object with optional fields - JS-friendly API
let makeConfig = Config.makeFromObject
type config = Config.t
