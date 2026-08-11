module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool
module Bindings = FrontmanBindings.Astro

let name = "get_client_pages"
let access = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool.Read

let description = `Lists all routes resolved by Astro's router.

Parameters: None

Returns routes from Astro's astro:routes:resolved hook, including pages,
API endpoints, redirects, content collection routes, and integration-injected
routes. Each route includes its pattern, entrypoint, type, origin, params,
and prerender status.`

@schema
type input = {
  @live
  placeholder?: bool,
}

@schema
type routeEntry = {
  @live
  path: string,
  @live
  file: string,
  @live
  isDynamic: bool,
  @live
  params: array<string>,
  @as("type") @live
  type_: string,
  @live
  origin: string,
  @live
  isPrerendered: bool,
}

@schema
type output = array<routeEntry>

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
      let access = access
      let (visibleToAgent, outputJsonSchema) = (true, None)
      let description = description
      type input = input
      let inputSchema = inputSchema
      let execute = async (_ctx, _input) =>
        Tool.unstructuredResult(getRoutes()->Array.map(toRouteEntry), outputSchema)
    }
  )
}
