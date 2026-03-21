// Middleware for Frontman Astro integration
//
// Handles /frontman/* routes: UI serving, tool endpoints, source location resolution.
// Returns option<Response>: Some(response) for handled routes, None for pass-through.
//
// Delegates all routing and request handling to the shared core middleware.

module Config = FrontmanAstro__Config
module ToolRegistry = FrontmanAstro__ToolRegistry
module Core = FrontmanAiFrontmanCore
module CoreMiddleware = Core.FrontmanCore__Middleware
module CoreMiddlewareConfig = Core.FrontmanCore__MiddlewareConfig

// How the get_client_pages tool discovers routes.
// Filesystem: scans src/pages/ (v4 behavior, works on all Astro versions).
// ResolvedRoutes: reads from astro:routes:resolved hook (v5+, catches content
// collections, config redirects, API endpoints, and integration-injected routes).
type routeDiscovery =
  | Filesystem
  | ResolvedRoutes({getRoutes: unit => array<FrontmanBindings.Astro.integrationResolvedRoute>})

// Convert Astro config to core middleware config
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
  frameworkId: CoreMiddlewareConfig.Astro,
}

// Create middleware handler
// Returns a function: Request => promise<option<Response>>
//   Some(response) => this route was handled
//   None => not a frontman route, pass through
let createMiddleware = (config: Config.t, ~routeDiscovery: routeDiscovery) => {
  let registry = switch routeDiscovery {
  | Filesystem => ToolRegistry.make()
  | ResolvedRoutes({getRoutes}) => ToolRegistry.makeWithResolvedRoutes(~getRoutes)
  }
  let middlewareConfig = toMiddlewareConfig(config)
  CoreMiddleware.createMiddleware(~config=middlewareConfig, ~registry)
}
