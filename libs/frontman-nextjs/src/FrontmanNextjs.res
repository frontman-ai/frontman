module Config = FrontmanNextjs__Config
module Middleware = FrontmanNextjs__Middleware
module ToolRegistry = FrontmanNextjs__ToolRegistry
module McpHandler = FrontmanNextjs__McpHandler

module OpenTelemetry = FrontmanNextjs__OpenTelemetry

module Instrumentation = FrontmanNextjs__Instrumentation

@@live
let createMiddleware = Middleware.createMiddleware
let createMcpHandler = McpHandler.make
let makeConfig = Config.makeFromObject
type config = Config.t
type configInput = Config.jsConfigInput
