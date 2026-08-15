module Core = FrontmanAiFrontmanCore
module CoreRequestHandlers = Core.FrontmanCore__RequestHandlers
module ToolRegistry = FrontmanVite__ToolRegistry
module Config = FrontmanVite__Config

let toHandlerConfig = (config: Config.t): CoreRequestHandlers.handlerConfig => {
  projectRoot: config.projectRoot,
  sourceRoot: config.sourceRoot,
  serverName: config.serverName,
  serverVersion: config.serverVersion,
}

@@live
let handleGetTools = (~registry: ToolRegistry.t, ~config: Config.t): WebAPI.FetchAPI.response => {
  CoreRequestHandlers.handleGetTools(~registry, ~config=toHandlerConfig(config))
}

@@live
let handleToolCall = async (
  ~registry: ToolRegistry.t,
  ~config: Config.t,
  req: WebAPI.FetchAPI.request,
): WebAPI.FetchAPI.response => {
  await CoreRequestHandlers.handleToolCall(~registry, ~config=toHandlerConfig(config), req)
}

@@live
let corsHeaders = Core.FrontmanCore__CORS.corsHeaders
@@live
let handleCORS = Core.FrontmanCore__CORS.handlePreflight

@@live
let handleResolveSourceLocation = async (
  ~config: Config.t,
  req: WebAPI.FetchAPI.request,
): WebAPI.FetchAPI.response => {
  await CoreRequestHandlers.handleResolveSourceLocation(
    ~projectRoot=config.projectRoot,
    ~sourceRoot=config.sourceRoot,
    req,
  )
}
