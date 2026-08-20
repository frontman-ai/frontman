module Config = FrontmanAstro__Config
module ToolRegistry = FrontmanAstro__ToolRegistry
module Core = FrontmanAiFrontmanCore
module CoreMiddleware = Core.FrontmanCore__Middleware
module CoreMiddlewareConfig = Core.FrontmanCore__MiddlewareConfig

type routeDiscovery =
  | Filesystem
  | ResolvedRoutes({getRoutes: unit => array<FrontmanBindings.Astro.integrationResolvedRoute>})

type loadContentApi = unit => promise<FrontmanAstro__Tool__GetContentCollections.contentApi>

type bundle = {
  middleware: (
    WebAPI.FetchAPI.request,
    ~rawHeaders: Core.FrontmanCore__MCP__RawHeaders.t=?,
  ) => promise<option<WebAPI.FetchAPI.response>>,
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
  frameworkId: CoreMiddlewareConfig.Astro,
  traits: [],
  mcpBrowserToken: config.mcpBrowserToken,
  sourceLocationSecurity: config.sourceLocationSecurity,
}

let make = (
  config: Config.t,
  ~routeDiscovery: routeDiscovery,
  ~loadContentApi: loadContentApi,
): bundle => {
  let registry = switch routeDiscovery {
  | Filesystem => ToolRegistry.makeWithAstroRuntime(~loadContentApi)
  | ResolvedRoutes({getRoutes}) =>
    ToolRegistry.makeWithResolvedRoutesAndAstroRuntime(~getRoutes, ~loadContentApi)
  }
  let middlewareConfig = toMiddlewareConfig(config)
  {middleware: CoreMiddleware.createMiddleware(~config=middlewareConfig), registry}
}

let createMiddleware = (config, ~routeDiscovery, ~loadContentApi) =>
  make(config, ~routeDiscovery, ~loadContentApi).middleware
