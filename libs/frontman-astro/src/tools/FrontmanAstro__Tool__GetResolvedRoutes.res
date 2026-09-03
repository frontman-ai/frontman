module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool
module Bindings = FrontmanBindings.Astro

let name = "get_client_pages"
let access = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool.Read

let description = `Lists all routes resolved by Astro's router.

Parameters: None

Returns routes from Astro's astro:routes:resolved hook, including pages,
API endpoints, redirects, content collection routes, and integration-injected
routes. Each route includes its pattern, entrypoint, type, origin, params,
pathname, segments, redirects, i18n fallback routes, serialized route regex, captured order, and prerender status.
Endpoint HTTP methods are not returned because Astro does not expose them via
astro:routes:resolved.`

@schema
type input = {
  @live
  placeholder?: bool,
}

@schema
type segmentPart = {
  @live
  content: string,
  @live
  dynamic: bool,
  @live
  spread: bool,
}

@schema
type regexInfo = {
  @live
  source: string,
  @live
  flags: string,
}

@schema
type routeRef = {
  @live
  path: string,
  @live
  file: string,
  @as("type") @live
  type_: string,
  @live
  origin: string,
}

@schema
type routeEntry = {
  @live
  order: int,
  @live
  path: string,
  @live
  file: string,
  @live
  isDynamic: bool,
  @live
  params: array<string>,
  @live
  pathname?: string,
  @live
  segments?: array<array<segmentPart>>,
  @live
  redirect?: JSON.t,
  @live
  redirectRoute?: routeRef,
  @live
  fallbackRoutes: array<routeRef>,
  @live
  patternRegex?: regexInfo,
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
@get external regexSource: Bindings.patternRegex => string = "source"
@get external regexFlags: Bindings.patternRegex => string = "flags"

let toRouteRef = (route: Bindings.integrationResolvedRoute): routeRef => {
  path: route.pattern,
  file: route.entrypoint,
  type_: route.type_->routeTypeToString,
  origin: route.origin->routeOriginToString,
}

let toRegexInfo = regex => {source: regex->regexSource, flags: regex->regexFlags}

let toSegmentPart = (part: Bindings.routePart): segmentPart => {
  content: part.content,
  dynamic: part.dynamic,
  spread: part.spread,
}

let toSegments = segments => segments->Array.map(segment => segment->Array.map(toSegmentPart))

let toRouteEntry = (route: Bindings.integrationResolvedRoute, order): routeEntry => {
  order,
  path: route.pattern,
  file: route.entrypoint,
  isDynamic: route.params->Array.length > 0,
  params: route.params,
  pathname: ?route.pathname,
  segments: ?(route.segments->Option.map(toSegments)),
  redirect: ?route.redirect,
  redirectRoute: ?(route.redirectRoute->Option.map(toRouteRef)),
  fallbackRoutes: route.fallbackRoutes->Array.map(toRouteRef),
  patternRegex: ?(route.patternRegex->Option.map(toRegexInfo)),
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
        Tool.unstructuredResult(
          getRoutes()->Array.mapWithIndex((route, order) => toRouteEntry(route, order)),
          outputSchema,
        )
    }
  )
}
