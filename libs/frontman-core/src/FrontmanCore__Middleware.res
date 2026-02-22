// Shared middleware factory for all framework adapters
//
// Creates a standard Web API middleware: Request => Promise<Option<Response>>
// Returns None for non-frontman routes (pass-through to next middleware)
// Returns Some(response) for frontman routes
//
// This is used directly by Vite and Next.js adapters.
// Astro wraps this with its own (context, next) adapter signature.

module CORS = FrontmanCore__CORS
module RequestHandlers = FrontmanCore__RequestHandlers
module UIShell = FrontmanCore__UIShell
module MiddlewareConfig = FrontmanCore__MiddlewareConfig
module ToolRegistry = FrontmanCore__ToolRegistry

// Create middleware from config and registry
// Returns request => promise<option<response>>
// None means "not handled, pass through to next middleware"
let createMiddleware = (
  ~config: MiddlewareConfig.t,
  ~registry: ToolRegistry.t,
): (WebAPI.FetchAPI.request => promise<option<WebAPI.FetchAPI.response>>) => {
  let handlerConfig: RequestHandlers.handlerConfig = {
    projectRoot: config.projectRoot,
    sourceRoot: config.sourceRoot,
    serverName: config.serverName,
    serverVersion: config.serverVersion,
  }

  let middleware: WebAPI.FetchAPI.request => promise<
    option<WebAPI.FetchAPI.response>,
  > = async req => {
    let method = req.method->String.toLowerCase
    let pathname = WebAPI.URL.make(~url=req.url).pathname

    // Normalize path: remove leading slash, lowercase
    let path =
      pathname
      ->String.split("/")
      ->Array.filter(p => !String.isEmpty(p))
      ->Array.join("/")
      ->String.toLowerCase

    let basePath = config.basePath->String.toLowerCase
    let toolsPath = basePath ++ "/tools"
    let toolsCallPath = basePath ++ "/tools/call"
    let resolveSourceLocationPath = basePath ++ "/resolve-source-location"
    let uiPath = basePath

    // Check if this is a frontman route (for CORS preflight)
    let isFrontmanRoute =
      path == toolsPath ||
      path == toolsCallPath ||
      path == resolveSourceLocationPath ||
      path == uiPath

    switch (method, path) {
    | ("options", _) if isFrontmanRoute => Some(CORS.handlePreflight())
    | ("get", p) if p == uiPath => Some(UIShell.serve(config)->CORS.withCors)
    | ("get", p) if p == toolsPath =>
      Some(RequestHandlers.handleGetTools(~registry, ~config=handlerConfig)->CORS.withCors)
    | ("post", p) if p == toolsCallPath =>
      Some(
        (await RequestHandlers.handleToolCall(~registry, ~config=handlerConfig, req))->CORS.withCors,
      )
    | ("post", p) if p == resolveSourceLocationPath =>
      Some(
        (await RequestHandlers.handleResolveSourceLocation(
          ~sourceRoot=config.sourceRoot,
          req,
        ))->CORS.withCors,
      )
    | _ => None
    }
  }

  middleware
}
