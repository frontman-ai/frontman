// Frontman Vite Integration - exposes framework tools via HTTP
// Used by FrontmanClient__Relay to execute file system operations

module Config = FrontmanVite__Config
module Middleware = FrontmanVite__Middleware
module Server = FrontmanVite__Server
module ToolRegistry = FrontmanVite__ToolRegistry
module Plugin = FrontmanVite__Plugin

// Re-export core SSE for convenience
module SSE = FrontmanFrontmanCore.FrontmanCore__SSE

// Re-export for convenience
let createMiddleware = Middleware.createMiddleware
// makeConfig accepts an object with optional fields - JS-friendly API
let makeConfig = Config.makeFromObject
type config = Config.t
type configInput = Config.jsConfigInput

// Plugin export - main entry point for Vite users
let frontmanPlugin = Plugin.frontmanPlugin
