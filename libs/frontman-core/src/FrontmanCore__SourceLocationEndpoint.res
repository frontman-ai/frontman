module HttpSecurity = FrontmanCore__MCP__HttpSecurity
module MediaTypes = FrontmanCore__MCP__MediaTypes
module RequestHandlers = FrontmanCore__RequestHandlers

type config = {
  security: option<HttpSecurity.policy>,
  sourceRoot: string,
}

type input = {allowedOrigins: array<string>}

let makeSecurity = (input: input) =>
  HttpSecurity.make(~allowedOrigins=input.allowedOrigins, ~authorize=async _headers =>
    failwith("Source-location Origin policy does not authorize MCP requests")
  )

let emptyResponse = (~status, ~headers=[]) =>
  WebAPI.Response.fromNull(~init={status, headers: WebAPI.HeadersInit.fromKeyValueArray(headers)})

let validateOrigin = (~config, ~headers) =>
  switch config.security {
  | None => HttpSecurity.InvalidOrigin(HttpSecurity.emptyResponse(~status=403))
  | Some(policy) => HttpSecurity.validateOriginHeaders(~headers, ~policy)
  }

let preflight = (~origin, ~headers) => {
  let requestedMethod = headers->WebAPI.Headers.get("Access-Control-Request-Method")->Null.toOption
  let requestedHeaders =
    headers
    ->WebAPI.Headers.get("Access-Control-Request-Headers")
    ->Null.toOption
    ->Option.map(value =>
      value->String.split(",")->Array.map(value => value->String.trim->String.toLowerCase)
    )
  switch (requestedMethod, requestedHeaders) {
  | (Some("POST"), None)
  | (Some("POST"), Some(["content-type"])) =>
    emptyResponse(
      ~status=204,
      ~headers=[
        ("Access-Control-Allow-Origin", origin),
        ("Access-Control-Allow-Methods", "POST, OPTIONS"),
        ("Access-Control-Allow-Headers", "Content-Type"),
        ("Vary", "Origin, Access-Control-Request-Method, Access-Control-Request-Headers"),
      ],
    )
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

let dispatch = async (~config, request: WebAPI.FetchAPI.request) => {
  switch validateOrigin(~config, ~headers=request.headers) {
  | HttpSecurity.InvalidOrigin(response) => response
  | HttpSecurity.ValidOrigin(origin) =>
    switch request.method {
    | "OPTIONS" => preflight(~origin, ~headers=request.headers)
    | "POST" =>
      switch request.headers->WebAPI.Headers.get("Content-Type")->Null.toOption {
      | Some(value) if MediaTypes.isJsonContentType(value) =>
        (
          await RequestHandlers.handleResolveSourceLocation(~sourceRoot=config.sourceRoot, request)
        )->HttpSecurity.withOrigin(~origin)
      | Some(_) | None => emptyResponse(~status=415)->HttpSecurity.withOrigin(~origin)
      }
    | _ =>
      emptyResponse(~status=405, ~headers=[("Allow", "POST, OPTIONS")])->HttpSecurity.withOrigin(
        ~origin,
      )
    }
  }
}
