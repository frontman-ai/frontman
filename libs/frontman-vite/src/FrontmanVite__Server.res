// Request handlers for Frontman Vite endpoints
// Thin wrapper around shared core request handlers

module Core = FrontmanAiFrontmanCore
module CoreRequestHandlers = Core.FrontmanCore__RequestHandlers
module ToolRegistry = FrontmanVite__ToolRegistry
module Config = FrontmanVite__Config

// Convert Vite config to core handler config
let toHandlerConfig = (config: Config.t): CoreRequestHandlers.handlerConfig => {
  projectRoot: config.projectRoot,
  sourceRoot: config.sourceRoot,
  serverName: config.serverName,
  serverVersion: config.serverVersion,
}

// GET /frontman/tools
let handleGetTools = (~registry: ToolRegistry.t, ~config: Config.t): WebAPI.FetchAPI.response => {
  CoreRequestHandlers.handleGetTools(~registry, ~config=toHandlerConfig(config))
}

// POST /frontman/tools/call - executes tool with SSE streaming
let handleToolCall = async (
  ~registry: ToolRegistry.t,
  ~config: Config.t,
  req: WebAPI.FetchAPI.request,
): WebAPI.FetchAPI.response => {
  await CoreRequestHandlers.handleToolCall(~registry, ~config=toHandlerConfig(config), req)
}

// CORS headers for preflight requests (delegated to core)
let corsHeaders = Core.FrontmanCore__CORS.corsHeaders
let handleCORS = Core.FrontmanCore__CORS.handlePreflight

// POST /frontman/resolve-source-location
let handleResolveSourceLocation = async (
  ~config: Config.t,
  req: WebAPI.FetchAPI.request,
): WebAPI.FetchAPI.response => {
  await CoreRequestHandlers.handleResolveSourceLocation(~sourceRoot=config.sourceRoot, req)
}
