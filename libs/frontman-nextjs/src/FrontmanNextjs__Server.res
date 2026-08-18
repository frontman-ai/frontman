let packageVersion: string = %raw(`typeof __PACKAGE_VERSION__ !== "undefined" ? __PACKAGE_VERSION__ : undefined`)
let () = if typeof(packageVersion) == #undefined {
  JsError.throwWithMessage("__PACKAGE_VERSION__ is not defined — tsup build is misconfigured")
}

module Core = FrontmanAiFrontmanCore
module CoreRequestHandlers = Core.FrontmanCore__RequestHandlers
module ToolRegistry = FrontmanNextjs__ToolRegistry

type config = {
  projectRoot: string,
  sourceRoot: string,
  serverName: string,
  serverVersion: string,
}

type t = {
  config: config,
  registry: ToolRegistry.t,
}

@@live
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

let toHandlerConfig = (config: config): CoreRequestHandlers.handlerConfig => {
  projectRoot: config.projectRoot,
  sourceRoot: config.sourceRoot,
  serverName: config.serverName,
  serverVersion: config.serverVersion,
}

@@live
let handleGetTools = (server: t): WebAPI.FetchAPI.response => {
  CoreRequestHandlers.handleGetTools(
    ~registry=server.registry,
    ~config=toHandlerConfig(server.config),
  )
}

@@live
let handleToolCall = async (server: t, req: WebAPI.FetchAPI.request): WebAPI.FetchAPI.response => {
  await CoreRequestHandlers.handleToolCall(
    ~registry=server.registry,
    ~config=toHandlerConfig(server.config),
    req,
  )
}
