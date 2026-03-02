// Middleware factory for Vite
// Thin wrapper around shared core middleware

module Core = FrontmanAiFrontmanCore
module CoreMiddleware = Core.FrontmanCore__Middleware
module CoreMiddlewareConfig = Core.FrontmanCore__MiddlewareConfig
module Config = FrontmanVite__Config
module ToolRegistry = FrontmanVite__ToolRegistry

type config = Config.t

// Convert Vite config to core middleware config
let toMiddlewareConfig = (config: Config.t): CoreMiddlewareConfig.t => {
  projectRoot: config.projectRoot,
  sourceRoot: config.sourceRoot,
  basePath: config.basePath,
  serverName: config.serverName,
  serverVersion: config.serverVersion,
  clientUrl: config.clientUrl,
  clientCssUrl: config.clientCssUrl,
  entrypointUrl: config.entrypointUrl,
  isLightTheme: config.isLightTheme,
  frameworkId: CoreMiddlewareConfig.Vite,
}

// Create middleware from a config
// Returns request => promise<option<response>>
// None means "not handled, pass through to next middleware"
let createMiddleware = (config: Config.t) => {
  let registry = ToolRegistry.make()
  let middlewareConfig = toMiddlewareConfig(config)
  CoreMiddleware.createMiddleware(~config=middlewareConfig, ~registry)
}
