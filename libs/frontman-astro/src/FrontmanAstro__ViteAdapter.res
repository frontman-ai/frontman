module NodeHttp = FrontmanBindings.NodeHttp
module CoreMiddleware = FrontmanAiFrontmanCore.FrontmanCore__Middleware
module Chassis = FrontmanAiFrontmanCore.FrontmanCore__NodeWebChassis
module RawHeaders = FrontmanAiFrontmanCore.FrontmanCore__MCP__RawHeaders
module McpEndpoint = FrontmanAiFrontmanCore.FrontmanCore__MCP__Endpoint

@module("./astro-route-rewrite.mjs")
external isExactMcpRequest: NodeHttp.incomingMessage => bool = "isExactMcpRequest"

type webMiddleware = (
  WebAPI.FetchAPI.request,
  ~rawHeaders: RawHeaders.t,
) => promise<option<WebAPI.FetchAPI.response>>

let adaptToConnect = (
  middleware: webMiddleware,
  ~basePath: string,
  ~mcp: option<McpEndpoint.config>=None,
): NodeHttp.connectMiddleware => {
  (req, res, next) => {
    let reqPath =
      req
      ->NodeHttp.url
      ->String.split("?")
      ->Array.get(0)
      ->Option.getOr(req->NodeHttp.url)
    let isFrontmanRoute = CoreMiddleware.isFrontmanRoute(
      ~pathname=reqPath,
      ~basePath,
      ~method=req->NodeHttp.method,
    )
    let isMcpRoute = (reqPath == "/mcp" || req->isExactMcpRequest) && mcp->Option.isSome
    switch (isMcpRoute, isFrontmanRoute) {
    | (false, false) => next()
    | (true, _) =>
      let config = mcp->Option.getOrThrow
      Chassis.handle(
        ~nodeRequest=req,
        ~nodeResponse=res,
        ~absoluteTimeoutMs=McpEndpoint.absoluteTimeoutMs,
        ~gate=(headers, _rawHeaders) =>
          McpEndpoint.gate(~config, ~method=req->NodeHttp.method, ~headers),
        ~dispatch=adapted => McpEndpoint.dispatch(~config, adapted),
      )
      ->Promise.then(outcome => {
        switch outcome {
        | Chassis.Passed => failwith("The active MCP endpoint passed through")
        | Chassis.Responded | Chassis.Cancelled | Chassis.TimedOut => ()
        }
        Promise.resolve()
      })
      ->Promise.catch(error => {
        Console.error2("[Frontman] MCP endpoint error:", error)
        switch res->NodeHttp.headersSent {
        | false =>
          res->NodeHttp.setStatusCode(500)
          res->NodeHttp.endWithData("Internal Server Error")
        | true => res->NodeHttp.end
        }
        Promise.resolve()
      })
      ->ignore
    | (false, true) =>
      Chassis.handle(
        ~nodeRequest=req,
        ~nodeResponse=res,
        ~gate=(_headers, _rawHeaders) => Promise.resolve(Chassis.Granted()),
        ~dispatch=adapted => middleware(adapted.request, ~rawHeaders=adapted.rawHeaders),
      )
      ->Promise.then(outcome => {
        switch outcome {
        | Chassis.Passed => next()
        | Chassis.Responded | Chassis.Cancelled | Chassis.TimedOut => ()
        }
        Promise.resolve()
      })
      ->Promise.catch(error => {
        Console.error2("[Frontman] Middleware error:", error)
        switch res->NodeHttp.headersSent {
        | false =>
          res->NodeHttp.setStatusCode(500)
          res->NodeHttp.endWithData("Internal Server Error")
        | true => res->NodeHttp.end
        }
        Promise.resolve()
      })
      ->ignore
    }
  }
}
