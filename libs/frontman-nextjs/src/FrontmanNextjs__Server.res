// Request handlers for Frontman Next.js endpoints
// Thin wrapper around shared core request handlers

// Injected at build time by tsup define — crash if missing so we catch broken builds immediately.
// Must use %raw with typeof guard: @val external won't work because __PACKAGE_VERSION__ is a
// build-time constant replaced by tsup, not a runtime global.
let packageVersion: string = %raw(`typeof __PACKAGE_VERSION__ !== "undefined" ? __PACKAGE_VERSION__ : undefined`)
let () = if Js.typeof(packageVersion) == "undefined" {
  JsError.throwWithMessage("__PACKAGE_VERSION__ is not defined — tsup build is misconfigured")
}

module Core = FrontmanAiFrontmanCore
module CoreRequestHandlers = Core.FrontmanCore__RequestHandlers
module ToolRegistry = FrontmanNextjs__ToolRegistry

type config = {
  projectRoot: string,
  // sourceRoot: root for file paths (monorepo root in monorepo setups, same as projectRoot otherwise)
  sourceRoot: string,
  serverName: string,
  serverVersion: string,
}

type t = {
  config: config,
  registry: ToolRegistry.t,
}

let make = (
  ~projectRoot: string,
  ~sourceRoot: option<string>=?,
  ~serverName="frontman-nextjs",
  ~serverVersion=packageVersion,
): t => {
  let resolvedSourceRoot = sourceRoot->Option.getOr(projectRoot)

  {
    config: {
      projectRoot,
      sourceRoot: resolvedSourceRoot,
      serverName,
      serverVersion,
    },
    registry: ToolRegistry.make(),
  }
}

// Convert to core handler config
let toHandlerConfig = (config: config): CoreRequestHandlers.handlerConfig => {
  projectRoot: config.projectRoot,
  sourceRoot: config.sourceRoot,
  serverName: config.serverName,
  serverVersion: config.serverVersion,
}

// GET /frontman/tools
let handleGetTools = (server: t): WebAPI.FetchAPI.response => {
  CoreRequestHandlers.handleGetTools(
    ~registry=server.registry,
    ~config=toHandlerConfig(server.config),
  )
}

// POST /frontman/tools/call - executes tool with SSE streaming
let handleToolCall = async (server: t, req: WebAPI.FetchAPI.request): WebAPI.FetchAPI.response => {
  await CoreRequestHandlers.handleToolCall(
    ~registry=server.registry,
    ~config=toHandlerConfig(server.config),
    req,
  )
}

// POST /frontman/resolve-source-location
let handleResolveSourceLocation = async (
  server: t,
  req: WebAPI.FetchAPI.request,
): WebAPI.FetchAPI.response => {
  await CoreRequestHandlers.handleResolveSourceLocation(~sourceRoot=server.config.sourceRoot, req)
}
