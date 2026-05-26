// Request handlers for Frontman Astro endpoints
// Thin wrapper around shared core request handlers

module Core = FrontmanAiFrontmanCore
module CoreRequestHandlers = Core.FrontmanCore__RequestHandlers
module CoreCORS = Core.FrontmanCore__CORS
module ToolRegistry = FrontmanAstro__ToolRegistry
module Config = FrontmanAstro__Config

// Convert Astro config to core handler config
let toHandlerConfig = (config: Config.t): CoreRequestHandlers.handlerConfig => {
  projectRoot: config.projectRoot,
  sourceRoot: config.sourceRoot,
  serverName: config.serverName,
  serverVersion: config.serverVersion,
}

// GET /frontman/tools
@@live
let handleGetTools = (~registry: ToolRegistry.t, ~config: Config.t): WebAPI.FetchAPI.response => {
  CoreRequestHandlers.handleGetTools(~registry, ~config=toHandlerConfig(config))
}

// POST /frontman/tools/call - executes tool with SSE streaming
@@live
let handleToolCall = async (
  ~registry: ToolRegistry.t,
  ~config: Config.t,
  req: WebAPI.FetchAPI.request,
): WebAPI.FetchAPI.response => {
  await CoreRequestHandlers.handleToolCall(~registry, ~config=toHandlerConfig(config), req)
}

// CORS headers for preflight requests (delegated to core)
@@live
let corsHeaders = CoreCORS.corsHeaders
@@live
let handleCORS = CoreCORS.handlePreflight

// POST /frontman/resolve-source-location
@@live
let handleResolveSourceLocation = async (
  ~config: Config.t,
  req: WebAPI.FetchAPI.request,
): WebAPI.FetchAPI.response => {
  await CoreRequestHandlers.handleResolveSourceLocation(~sourceRoot=config.sourceRoot, req)
}
