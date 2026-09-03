module Core = FrontmanAiFrontmanCore
module CoreMiddleware = Core.FrontmanCore__Middleware
module CoreMiddlewareConfig = Core.FrontmanCore__MiddlewareConfig
module Server = FrontmanNextjs__Server
module Config = FrontmanNextjs__Config
module LogCapture = FrontmanNextjs__LogCapture
module RuntimeEnv = FrontmanNextjs__RuntimeEnv

@module("./FrontmanNextjs__PreviewBridgeAsset.mjs")
external isPreviewBridgePath: (string, string) => bool = "isPreviewBridgePath"
@module("./FrontmanNextjs__PreviewBridgeAsset.mjs")
external makePreviewBridgeResponse: unit => promise<WebAPI.Response.t> = "makePreviewBridgeResponse"

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
}

let createMiddleware = (configInput: Config.jsConfigInput) => {
  let config = Config.makeFromObject(configInput)
  let middlewareConfig = toMiddlewareConfig(config)
  let server = Server.make(
    ~projectRoot=config.projectRoot,
    ~sourceRoot=config.sourceRoot,
    ~serverName=config.serverName,
    ~serverVersion=config.serverVersion,
  )

  let coreMiddleware = CoreMiddleware.createMiddleware(
    ~config=middlewareConfig,
    ~registry=server.registry,
  )
  let middleware = async (req: WebAPI.Request.t) =>
    switch isPreviewBridgePath(req.url, config.basePath) {
    | true => Some(await makePreviewBridgeResponse())
    | false => await coreMiddleware(req)
    }

  switch RuntimeEnv.isRuntimeEnabled() {
  | true =>
    LogCapture.initialize()
    middleware
  | false => async _req => None
  }
}
