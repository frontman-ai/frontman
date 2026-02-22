// Middleware for Frontman Astro integration
//
// Handles /frontman/* routes: UI serving, tool endpoints, source location resolution.
// Returns option<Response>: Some(response) for handled routes, None for pass-through.
// This middleware is designed to be adapted to Vite's Connect middleware via ViteAdapter.
//
// Delegates shared logic (CORS, UI shell, request handling) to frontman-core modules.

module Config = FrontmanAstro__Config
module Server = FrontmanAstro__Server
module ToolRegistry = FrontmanAstro__ToolRegistry
module Core = FrontmanFrontmanCore
module CoreMiddlewareConfig = Core.FrontmanCore__MiddlewareConfig
module CoreUIShell = Core.FrontmanCore__UIShell
module CoreCORS = Core.FrontmanCore__CORS

// Convert Astro config to core middleware config
let toMiddlewareConfig = (config: Config.t): CoreMiddlewareConfig.t => {
  projectRoot: config.projectRoot,
  sourceRoot: config.sourceRoot,
  basePath: config.basePath,
  serverName: config.serverName,
  serverVersion: config.serverVersion,
  clientUrl: config.clientUrl,
  clientCssUrl: config.clientCssUrl,
  entrypointUrl: None,
  isLightTheme: config.isLightTheme,
  frameworkLabel: "Astro",
}

// Create middleware handler
// Returns a function: Request => promise<option<Response>>
//   Some(response) => this route was handled
//   None => not a frontman route, pass through
let createMiddleware = (config: Config.t) => {
  let registry = ToolRegistry.make()
  let middlewareConfig = toMiddlewareConfig(config)

  async (request: WebAPI.FetchAPI.request): option<WebAPI.FetchAPI.response> => {
    let url = WebAPI.URL.make(~url=request.url)
    let pathname = url.pathname
    let method = request.method

    let basePath = `/${config.basePath}`

    // Only handle frontman routes
    if !(pathname == basePath || pathname->String.startsWith(`${basePath}/`)) {
      None
    } else if method == "OPTIONS" {
      Some(CoreCORS.handlePreflight())
    } else {
      switch pathname {
      | p if p == basePath || p == `${basePath}/` =>
        Some(CoreUIShell.serve(middlewareConfig)->CoreCORS.withCors)

      | p if p == `${basePath}/tools` && method == "GET" =>
        Some(Server.handleGetTools(~registry, ~config)->CoreCORS.withCors)

      | p if p == `${basePath}/tools/call` && method == "POST" =>
        Some((await Server.handleToolCall(~registry, ~config, request))->CoreCORS.withCors)

      | p if p == `${basePath}/resolve-source-location` && method == "POST" =>
        Some((await Server.handleResolveSourceLocation(~config, request))->CoreCORS.withCors)

      | _ =>
        Some(
          WebAPI.Response.jsonR(
            ~data=JSON.Encode.object(Dict.fromArray([("error", JSON.Encode.string("Not found"))])),
            ~init={status: 404},
          ),
        )
      }
    }
  }
}
