module CoreMiddlewareConfig = FrontmanAiFrontmanCore.FrontmanCore__MiddlewareConfig
module CoreMiddleware = FrontmanAiFrontmanCore.FrontmanCore__Middleware
module ToolRegistry = FrontmanAiFrontmanCore.FrontmanCore__ToolRegistry

let defaultConfig: CoreMiddlewareConfig.t = {
  projectRoot: "/tmp/project",
  sourceRoot: "/tmp/project",
  basePath: "frontman",
  serverName: "test-server",
  serverVersion: "1.0.0",
  clientUrl: "http://localhost/client.js",
  clientCssUrl: None,
  entrypointUrl: None,
  frameworkId: CoreMiddlewareConfig.Astro,
  traits: [],
}

let makeMiddleware = (~registry: ToolRegistry.t) =>
  CoreMiddleware.createMiddleware(~config=defaultConfig, ~registry)

let callTool = async (middleware, ~name: string, ~arguments: JSON.t): string => {
  let body = JSON.Encode.object(
    Dict.fromArray([("name", JSON.Encode.string(name)), ("arguments", arguments)]),
  )
  let headers = WebAPI.HeadersInit.fromDict(Dict.fromArray([("Content-Type", "application/json")]))
  let req = WebAPI.Request.fromURL(
    "http://localhost/frontman/tools/call",
    ~init={
      method: "POST",
      body: WebAPI.BodyInit.fromString(JSON.stringify(body)),
      headers,
    },
  )
  let result = await middleware(req)
  switch result {
  | None => failwith("Middleware did not handle /frontman/tools/call")
  | Some(response) => await response->WebAPI.Response.text
  }
}

let getEndpoint = async (middleware, ~path: string): string => {
  let req = WebAPI.Request.fromURL(`http://localhost/frontman/${path}`)
  let result = await middleware(req)
  switch result {
  | None => failwith(`Middleware did not handle /frontman/${path}`)
  | Some(response) => await response->WebAPI.Response.text
  }
}
