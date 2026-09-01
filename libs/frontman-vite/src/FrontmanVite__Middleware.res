module Core = FrontmanAiFrontmanCore
module CoreMiddleware = Core.FrontmanCore__Middleware
module CoreMiddlewareConfig = Core.FrontmanCore__MiddlewareConfig
module Config = FrontmanVite__Config
module ToolRegistry = FrontmanVite__ToolRegistry

type config = Config.t

type bundle = {
  middleware: (
    WebAPI.Request.t,
    ~rawHeaders: Core.FrontmanCore__MCP__RawHeaders.t=?,
  ) => promise<option<WebAPI.Response.t>>,
  registry: Core.FrontmanCore__ToolRegistry.t,
}

let toMiddlewareConfig = (config: Config.t): CoreMiddlewareConfig.t => {
  projectRoot: config.projectRoot,
  sourceRoot: config.sourceRoot,
  basePath: config.basePath,
  serverName: config.serverName,
  serverVersion: config.serverVersion,
  clientUrl: config.clientUrl,
  clientCssUrl: config.clientCssUrl,
  entrypointUrl: config.entrypointUrl,
  frameworkId: CoreMiddlewareConfig.Vite,
  traits: [],
  mcpBrowserToken: config.mcpBrowserToken,
  sourceLocationSecurity: config.sourceLocationSecurity,
}

let make = (config: Config.t): bundle => {
  let registry = ToolRegistry.make()
  let middlewareConfig = toMiddlewareConfig(config)
  {middleware: CoreMiddleware.createMiddleware(~config=middlewareConfig), registry}
}

@@live
let createMiddleware = (config: Config.t) => make(config).middleware
