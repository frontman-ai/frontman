type authorization = Authorized | MissingAuthentication | InsufficientAuthorization

type policy = {
  allowedOrigins: array<string>,
  authorize: WebAPI.FetchTypes.headers => promise<authorization>,
  principal: (WebAPI.FetchTypes.headers, string) => string,
  limiter: FrontmanCore__MCP__RateLimiter.t,
}

type t = Allowed(string) | Rejected(WebAPI.Response.t)
type originValidation = ValidOrigin(string) | InvalidOrigin(WebAPI.Response.t)

let normalizeAuthority = (~protocol: string, authority: string): string => {
  let authority = authority->String.toLowerCase
  switch (protocol, authority->String.endsWith(":80"), authority->String.endsWith(":443")) {
  | ("http", true, _) => authority->String.slice(~start=0, ~end=authority->String.length - 3)
  | ("https", _, true) => authority->String.slice(~start=0, ~end=authority->String.length - 4)
  | _ => authority
  }
}

let serializedOriginParts = (value: string): option<(string, string)> => {
  switch value->String.split("://") {
  | [scheme, authority] =>
    let protocol = scheme->String.toLowerCase
    switch (
      protocol,
      authority,
      value == value->String.trim,
      authority->String.includes("/"),
      authority->String.includes("\\"),
      authority->String.includes("?"),
      authority->String.includes("#"),
      authority->String.includes(" "),
      authority->String.includes("\t"),
      authority->String.includes("\r"),
      authority->String.includes("\n"),
    ) {
    | ("http" | "https", "", _, _, _, _, _, _, _, _, _) => None
    | ("http" | "https", _, true, false, false, false, false, false, false, false, false) =>
      Some((protocol, authority))
    | _ => None
    }
  | _ => None
  }
}

let parseOrigin = (value: string): option<string> => {
  switch serializedOriginParts(value) {
  | None => None
  | Some((protocol, authority)) if WebAPI.URL.canParse(~url=value) =>
    let url = WebAPI.URL.make(~url=value)
    switch (
      url.protocol,
      url.username,
      url.password,
      url.pathname,
      url.search,
      url.hash,
      value->String.includes("%"),
      url.hostname->String.endsWith("."),
      normalizeAuthority(~protocol, authority) == url.host->String.toLowerCase,
    ) {
    | ("http:" | "https:", "", "", "/", "", "", false, false, true) => Some(url.origin)
    | _ => None
    }
  | Some(_) => None
  }
}

let make = (~allowedOrigins: array<string>, ~authorize, ~principal=?): policy => {
  let allowedOrigins = allowedOrigins->Array.map(origin => {
    switch parseOrigin(origin) {
    | Some(origin) => origin
    | None => failwith(`Invalid configured MCP origin: ${origin}`)
    }
  })
  let principal = principal->Option.getOr((_headers, origin) => "authorized-origin:" ++ origin)
  {allowedOrigins, authorize, principal, limiter: FrontmanCore__MCP__RateLimiter.make()}
}

let principal = (~headers, ~origin, ~policy): option<string> =>
  try {
    switch policy.principal(WebAPI.Headers.fromHeaders(headers), origin) {
    | "" => None
    | principal => Some(principal)
    }
  } catch {
  | _ => None
  }

let emptyResponse = (~status, ~origin=?) => {
  let headers = switch origin {
  | Some(origin) =>
    WebAPI.HeadersInit.fromKeyValueArray([
      ("Access-Control-Allow-Origin", origin),
      ("Vary", "Origin"),
    ])
  | None => WebAPI.HeadersInit.fromKeyValueArray([("Vary", "Origin")])
  }
  WebAPI.Response.fromNull(~init={status, headers})
}

let withOrigin = (~origin, response: WebAPI.Response.t): WebAPI.Response.t => {
  response.headers->WebAPI.Headers.set(~name="Access-Control-Allow-Origin", ~value=origin)
  response.headers->WebAPI.Headers.append(~name="Vary", ~value="Origin")
  response
}

let validateOriginHeaders = (
  ~headers: WebAPI.FetchTypes.headers,
  ~policy: policy,
): originValidation => {
  let origin = headers->WebAPI.Headers.get("Origin")->Null.toOption->Option.flatMap(parseOrigin)
  switch origin {
  | None => InvalidOrigin(emptyResponse(~status=403))
  | Some(origin) if !(policy.allowedOrigins->Array.includes(origin)) =>
    InvalidOrigin(emptyResponse(~status=403))
  | Some(origin) => ValidOrigin(origin)
  }
}

let validateHeaders = async (~headers: WebAPI.FetchTypes.headers, ~policy: policy): t => {
  switch validateOriginHeaders(~headers, ~policy) {
  | InvalidOrigin(response) => Rejected(response)
  | ValidOrigin(origin) =>
    switch await policy.authorize(WebAPI.Headers.fromHeaders(headers)) {
    | Authorized => Allowed(origin)
    | MissingAuthentication => Rejected(emptyResponse(~status=401, ~origin))
    | InsufficientAuthorization => Rejected(emptyResponse(~status=403, ~origin))
    }
  }
}

let validate = async (~request: WebAPI.Request.t, ~policy: policy): t =>
  await validateHeaders(~headers=request.headers, ~policy)
