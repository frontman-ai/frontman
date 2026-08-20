module HttpSecurity = FrontmanCore__MCP__HttpSecurity
module HttpRequest = FrontmanCore__MCP__HttpRequest
module DecodedRequest = FrontmanCore__MCP__DecodedRequest
module ToolRegistry = FrontmanCore__ToolRegistry
module Chassis = FrontmanCore__NodeWebChassis
module RateLimiter = FrontmanCore__MCP__RateLimiter

let absoluteTimeoutMs = 600000

type config = {
  security: HttpSecurity.policy,
  registry: ToolRegistry.t,
  projectRoot: string,
  sourceRoot: string,
  serverName: string,
  serverVersion: string,
  allowedPreflightHeaders: array<string>,
}

type context = Preflight(string) | Post({origin: string, principal: string}) | Unsupported(string)

let standardPreflightHeaders = [
  "content-type",
  "authorization",
  "mcp-protocol-version",
  "mcp-method",
  "mcp-name",
]

let emptyResponse = (~status, ~headers) =>
  WebAPI.Response.fromNull(~init={status, headers: WebAPI.HeadersInit.fromKeyValueArray(headers)})

let allowedPreflightHeader = (~config, header) => {
  let header = header->String.toLowerCase
  standardPreflightHeaders->Array.includes(header) ||
  header->String.startsWith("mcp-param-") ||
  config.allowedPreflightHeaders->Array.some(allowed => allowed->String.toLowerCase == header)
}

let requestedPreflightHeaders = (headers: WebAPI.FetchAPI.headers): result<array<string>, unit> => {
  switch headers->WebAPI.Headers.get("Access-Control-Request-Headers")->Null.toOption {
  | None => Ok([])
  | Some(value) =>
    let requested = value->String.split(",")->Array.map(String.trim)
    switch requested->Array.some(String.isEmpty) {
    | true => Error()
    | false => Ok(requested)
    }
  }
}

let gate = async (~config, ~method, ~headers): Chassis.gateResult<context> => {
  switch method {
  | "OPTIONS" =>
    switch HttpSecurity.validateOriginHeaders(~headers, ~policy=config.security) {
    | HttpSecurity.ValidOrigin(origin) => Chassis.Granted(Preflight(origin))
    | HttpSecurity.InvalidOrigin(response) => Chassis.Denied(response)
    }
  | "POST" =>
    switch await HttpSecurity.validateHeaders(~headers, ~policy=config.security) {
    | HttpSecurity.Allowed(origin) =>
      switch HttpSecurity.principal(~headers, ~origin, ~policy=config.security) {
      | Some(principal) => Chassis.Granted(Post({origin, principal}))
      | None => Chassis.Denied(HttpSecurity.emptyResponse(~status=503, ~origin))
      }
    | HttpSecurity.Rejected(response) => Chassis.Denied(response)
    }
  | _ =>
    switch await HttpSecurity.validateHeaders(~headers, ~policy=config.security) {
    | HttpSecurity.Allowed(origin) => Chassis.Granted(Unsupported(origin))
    | HttpSecurity.Rejected(response) => Chassis.Denied(response)
    }
  }
}

let preflight = (~config, ~origin, ~headers): WebAPI.FetchAPI.response => {
  let requestedMethod = headers->WebAPI.Headers.get("Access-Control-Request-Method")->Null.toOption
  switch (requestedMethod, requestedPreflightHeaders(headers)) {
  | (Some("POST"), Ok(requested))
    if requested->Array.every(header => allowedPreflightHeader(~config, header)) =>
    let responseHeaders = [
      ("Access-Control-Allow-Origin", origin),
      ("Access-Control-Allow-Methods", "POST, OPTIONS"),
      ("Vary", "Origin, Access-Control-Request-Method, Access-Control-Request-Headers"),
    ]
    let responseHeaders = switch requested {
    | [] => responseHeaders
    | requested =>
      responseHeaders->Array.concat([("Access-Control-Allow-Headers", requested->Array.join(", "))])
    }
    emptyResponse(~status=204, ~headers=responseHeaders)
  | _ =>
    emptyResponse(
      ~status=400,
      ~headers=[
        ("Access-Control-Allow-Origin", origin),
        ("Vary", "Origin, Access-Control-Request-Method, Access-Control-Request-Headers"),
      ],
    )
  }
}

let methodNotAllowed = (~origin) =>
  emptyResponse(
    ~status=405,
    ~headers=[
      ("Allow", "POST, OPTIONS"),
      ("Access-Control-Allow-Origin", origin),
      ("Vary", "Origin"),
    ],
  )

let rateLimited = (~origin, ~retryAfter) =>
  emptyResponse(
    ~status=429,
    ~headers=[
      ("Retry-After", retryAfter->Int.toString),
      ("Access-Control-Allow-Origin", origin),
      ("Vary", "Origin"),
    ],
  )

let limiterFailed = (~origin) =>
  emptyResponse(~status=503, ~headers=[("Access-Control-Allow-Origin", origin), ("Vary", "Origin")])

let dispatch = async (~config, adapted: Chassis.adaptedRequest<context>) => {
  switch adapted.context {
  | Preflight(origin) => Some(preflight(~config, ~origin, ~headers=adapted.request.headers))
  | Post({origin, principal}) =>
    switch config.security.limiter->RateLimiter.check(~principal) {
    | RateLimiter.Rejected(retryAfter) => Some(rateLimited(~origin, ~retryAfter))
    | RateLimiter.Failed => Some(limiterFailed(~origin))
    | RateLimiter.Allowed =>
      switch await HttpRequest.validateAfterSecurity(
        ~request=adapted.request,
        ~origin,
        ~rawHeaders=Some(adapted.rawHeaders),
        ~registry=config.registry,
        ~serverIdentity=Some({
          serverName: config.serverName,
          serverVersion: config.serverVersion,
        }),
      ) {
      | HttpRequest.Completed(response) | HttpRequest.Rejected(response) => Some(response)
      | HttpRequest.Accepted({origin, request}) =>
        let ctx: FrontmanCore__Server.executionContext = {
          projectRoot: config.projectRoot,
          sourceRoot: config.sourceRoot,
          signal: adapted.signal,
          onProgress: None,
        }
        switch await DecodedRequest.execute(
          ~ctx,
          ~serverName=config.serverName,
          ~serverVersion=config.serverVersion,
          request,
        ) {
        | DecodedRequest.Completed(response) => Some(response->HttpSecurity.withOrigin(~origin))
        | DecodedRequest.Accepted(_) | DecodedRequest.Rejected(_) =>
          failwith("Validated MCP execution did not complete")
        }
      }
    }
  | Unsupported(origin) => Some(methodNotAllowed(~origin))
  }
}
