module Core = FrontmanAiFrontmanCore
module CoreMiddleware = Core.FrontmanCore__Middleware
module CoreMiddlewareConfig = Core.FrontmanCore__MiddlewareConfig
module Config = FrontmanNextjs__Config
module LogCapture = FrontmanNextjs__LogCapture

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
  frameworkId: CoreMiddlewareConfig.Nextjs,
  traits: ["react", "typescript"],
  mcpBrowserToken: config.mcpBrowserToken,
  sourceLocationSecurity: config.sourceLocationSecurity,
}

let createMiddleware = (configInput: Config.jsConfigInput) => {
  let config = Config.makeFromObject(configInput)
  let middlewareConfig = toMiddlewareConfig(config)
  CoreMiddleware.createMiddleware(~config=middlewareConfig)
}
