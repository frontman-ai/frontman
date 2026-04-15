// Get client pages tool (v5) — backed by Astro's astro:routes:resolved hook.
//
// Unlike the v4 GetPages tool which scans the filesystem, this tool reads
// routes directly from Astro's router. This catches routes that don't exist
// as files in src/pages/: content collections, config redirects, API endpoints,
// integration-injected routes, and internal fallbacks.
//
// Uses a factory pattern: make(~getRoutes) => module(ServerTool).
// The ServerTool interface only passes (serverExecutionContext, input) to
// execute, so there's no way to thread the routes ref through the standard
// interface. The factory closes over getRoutes at construction time, allowing
// execute to read it without global state or protocol changes.

module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool
module Bindings = FrontmanBindings.Astro

let name = "get_client_pages"
let visibleToAgent = true

let description = `Lists all routes resolved by Astro's router.

Parameters: None

Returns routes from Astro's astro:routes:resolved hook, including pages,
API endpoints, redirects, content collection routes, and integration-injected
routes. Each route includes its pattern, entrypoint, type, origin, params,
and prerender status.`

@schema
type input = {placeholder?: bool}

@schema
type routeEntry = {
  path: string,
  file: string,
  isDynamic: bool,
  params: array<string>,
  @as("type")
  type_: string,
  origin: string,
  isPrerendered: bool,
}

@schema
type output = array<routeEntry>

// Poly variants are strings at runtime
external routeTypeToString: Bindings.routeType => string = "%identity"
external routeOriginToString: Bindings.routeOrigin => string = "%identity"

let toRouteEntry = (route: Bindings.integrationResolvedRoute): routeEntry => {
  path: route.pattern,
  file: route.entrypoint,
  isDynamic: route.params->Array.length > 0,
  params: route.params,
  type_: route.type_->routeTypeToString,
  origin: route.origin->routeOriginToString,
  isPrerendered: route.isPrerendered,
}

let make = (
  ~getRoutes: unit => array<Bindings.integrationResolvedRoute>,
): module(Tool.ServerTool) => {
  module(
    {
      let name = name
      let visibleToAgent = visibleToAgent
      let description = description
      type input = input
      type output = output
      let inputSchema = inputSchema
      let outputSchema = outputSchema
      let execute = async (_ctx, _input) => {
        Ok(getRoutes()->Array.map(toRouteEntry))
      }
    }
  )
}
