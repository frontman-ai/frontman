module Core = FrontmanAiFrontmanCore
module CoreMiddleware = Core.FrontmanCore__Middleware
module CoreMiddlewareConfig = Core.FrontmanCore__MiddlewareConfig
module Config = FrontmanVite__Config
module ToolRegistry = FrontmanVite__ToolRegistry

type config = Config.t

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
}

let createMiddleware = (config: Config.t) => {
  let registry = ToolRegistry.make()
  let middlewareConfig = toMiddlewareConfig(config)
  CoreMiddleware.createMiddleware(~config=middlewareConfig, ~registry)
}
