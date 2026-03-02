// Middleware factory for Next.js
// Thin wrapper around shared core middleware

module Core = FrontmanAiFrontmanCore
module CoreMiddleware = Core.FrontmanCore__Middleware
module CoreMiddlewareConfig = Core.FrontmanCore__MiddlewareConfig
module Server = FrontmanNextjs__Server
module Config = FrontmanNextjs__Config
module LogCapture = FrontmanNextjs__LogCapture

type config = Config.t

// Convert Next.js config to core middleware config
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
  frameworkId: CoreMiddlewareConfig.Nextjs,
}

// Create middleware from a config input object (applies defaults)
let createMiddleware = (configInput: Config.jsConfigInput) => {
  let config = Config.makeFromObject(configInput)
  let middlewareConfig = toMiddlewareConfig(config)
  let server = Server.make(
    ~projectRoot=config.projectRoot,
    ~sourceRoot=config.sourceRoot,
    ~serverName=config.serverName,
    ~serverVersion=config.serverVersion,
  )

  CoreMiddleware.createMiddleware(~config=middlewareConfig, ~registry=server.registry)
}
