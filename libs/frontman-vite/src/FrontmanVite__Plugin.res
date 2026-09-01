module Config = FrontmanVite__Config
module Middleware = FrontmanVite__Middleware
module Core = FrontmanAiFrontmanCore
module NodeHttp = FrontmanBindings.NodeHttp
module Chassis = Core.FrontmanCore__NodeWebChassis
module McpEndpoint = Core.FrontmanCore__MCP__Endpoint
open FrontmanVite__Bindings

let adaptMiddlewareToVite = (
  ~basePath: string,
  ~mcp: option<McpEndpoint.config>=None,
  middleware: (
    WebAPI.Request.t,
    ~rawHeaders: Core.FrontmanCore__MCP__RawHeaders.t,
  ) => promise<option<WebAPI.Response.t>>,
): ((incomingMessage, serverResponse, unit => unit) => promise<unit>) => {
  async (req, res, next) => {
    let reqUrl = req->NodeHttp.url
    let pathOnly = switch reqUrl->String.indexOf("?") {
    | -1 => reqUrl
    | idx => reqUrl->String.slice(~start=0, ~end=idx)
    }
    let isMcpRoute = pathOnly == "/mcp" && mcp->Option.isSome
    let isFrontmanRoute = Core.FrontmanCore__Middleware.isFrontmanRoute(
      ~pathname=pathOnly,
      ~basePath,
      ~method=req->NodeHttp.method,
    )
    switch (isMcpRoute, isFrontmanRoute) {
    | (true, _) =>
      let config = mcp->Option.getOrThrow
      let outcome = await Chassis.handle(
        ~nodeRequest=req,
        ~nodeResponse=res,
        ~absoluteTimeoutMs=McpEndpoint.absoluteTimeoutMs,
        ~gate=(headers, _rawHeaders) =>
          McpEndpoint.gate(~config, ~method=req->NodeHttp.method, ~headers),
        ~dispatch=adapted => McpEndpoint.dispatch(~config, adapted),
      )
      switch outcome {
      | Chassis.Passed => failwith("The active MCP endpoint passed through")
      | Chassis.Responded | Chassis.Cancelled | Chassis.TimedOut => ()
      }
    | (false, false) => next()
    | (false, true) =>
      let outcome = await Chassis.handle(
        ~nodeRequest=req,
        ~nodeResponse=res,
        ~gate=(_headers, _rawHeaders) => Promise.resolve(Chassis.Granted()),
        ~dispatch=adapted => middleware(adapted.request, ~rawHeaders=adapted.rawHeaders),
      )
      switch outcome {
      | Chassis.Passed => next()
      | Chassis.Responded | Chassis.Cancelled | Chassis.TimedOut => ()
      }
    }
  }
}

type pluginOptions = {
  isDev?: bool,
  basePath?: string,
  clientUrl?: string,
  clientCssUrl?: string,
  entrypointUrl?: string,
  projectRoot?: string,
  sourceRoot?: string,
  serverName?: string,
  serverVersion?: string,
  host?: string,
  mcpBrowserToken?: string,
  mcp?: Config.AdapterSecurity.input,
  sourceLocation?: Core.FrontmanCore__SourceLocationEndpoint.input,
}

@@live
let frontmanPlugin = (~options: option<pluginOptions>=?): array<plugin> => {
  let opts = options->Option.getOr({})

  let middlewarePlugin = {
    name: "frontman",
    enforce: "pre",
    config: () => {server: {cors: opts.mcp->Option.isNone}},
    configureServer: server => {
      FrontmanAiFrontmanCore.FrontmanCore__LogCapture.initialize()

      let isDev = opts.isDev
      let basePath = opts.basePath
      let clientUrl = opts.clientUrl
      let clientCssUrl = opts.clientCssUrl
      let entrypointUrl = opts.entrypointUrl
      let projectRoot = opts.projectRoot
      let sourceRoot = opts.sourceRoot
      let serverName = opts.serverName
      let serverVersion = opts.serverVersion
      let host = opts.host
      let mcpBrowserToken = opts.mcpBrowserToken
      let mcp = opts.mcp
      let sourceLocation = opts.sourceLocation
      let configInput: Config.jsConfigInput = {
        ?isDev,
        ?basePath,
        ?clientUrl,
        ?clientCssUrl,
        ?entrypointUrl,
        ?projectRoot,
        ?sourceRoot,
        ?serverName,
        ?serverVersion,
        ?host,
        ?mcpBrowserToken,
        ?mcp,
        ?sourceLocation,
      }
      let config = Config.makeFromObject(configInput)
      let middleware = Middleware.make(config)
      let mcp: option<McpEndpoint.config> = config.mcpSecurity->Option.map(security => {
        McpEndpoint.security,
        registry: middleware.registry,
        projectRoot: config.projectRoot,
        sourceRoot: config.sourceRoot,
        serverName: config.serverName,
        serverVersion: config.serverVersion,
        allowedPreflightHeaders: [],
      })
      let adaptedMiddleware = adaptMiddlewareToVite(~basePath=config.basePath, ~mcp, (
        request,
        ~rawHeaders,
      ) => middleware.middleware(request, ~rawHeaders))

      server.middlewares->useMiddleware((req, res, next) => {
        let _ = adaptedMiddleware(req, res, next)->Promise.catch(error => {
          let msg =
            error
            ->JsExn.fromException
            ->Option.flatMap(JsExn.message)
            ->Option.getOr("Unknown error")
          Console.error2("Frontman middleware error:", msg)
          switch res->NodeHttp.headersSent {
          | false =>
            res->NodeHttp.setStatusCode(500)
            res->NodeHttp.endWithData("Internal Server Error")
          | true => res->NodeHttp.end
          }
          Promise.resolve()
        })
      })
    },
  }

  [middlewarePlugin, frontmanVueSourcePlugin()]
}
