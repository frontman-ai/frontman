// Request handlers for Frontman Next.js endpoints
// Thin wrapper around shared core request handlers

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
  ~serverVersion="1.0.0",
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
  await CoreRequestHandlers.handleResolveSourceLocation(
    ~sourceRoot=server.config.sourceRoot,
    req,
  )
}
