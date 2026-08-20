module CORS = FrontmanCore__CORS
module RequestHandlers = FrontmanCore__RequestHandlers
module UIShell = FrontmanCore__UIShell
module MiddlewareConfig = FrontmanCore__MiddlewareConfig
module RawHeaders = FrontmanCore__MCP__RawHeaders
module SourceLocationEndpoint = FrontmanCore__SourceLocationEndpoint

@val external encodeURIComponent: string => string = "encodeURIComponent"

let mcpCookieName = "frontman_mcp_session"

let withMcpBrowserCookie = (
  response: WebAPI.FetchAPI.response,
  ~token: option<string>,
  ~secure: bool,
): WebAPI.FetchAPI.response => {
  token->Option.forEach(token => {
    let secureAttribute = switch secure {
    | true => "; Secure"
    | false => ""
    }
    response.headers->WebAPI.Headers.set(
      ~name="Set-Cookie",
      ~value=`${mcpCookieName}=${encodeURIComponent(
          token,
        )}; Path=/mcp; HttpOnly; SameSite=Strict${secureAttribute}`,
    )
  })
  response
}

let getSuffixRoutePrefix = (~path: string, ~basePath: string): option<string> => {
  switch path == basePath {
  | true => Some("")
  | false =>
    let suffix = "/" ++ basePath
    switch path->String.endsWith(suffix) {
    | true => Some(path->String.slice(~start=0, ~end=path->String.length - suffix->String.length))
    | false => None
    }
  }
}

let isFrontmanRoute = (~pathname: string, ~basePath: string, ~method: string): bool => {
  let prefix = "/" ++ basePath->String.toLowerCase
  let path = pathname->String.toLowerCase
  let isPrefixRoute = path == prefix || path->String.startsWith(prefix ++ "/")
  let isSuffixRoute = path->String.endsWith(prefix) || path->String.endsWith(prefix ++ "/")
  isPrefixRoute || (method->String.toUpperCase == "GET" && isSuffixRoute)
}

let getCanonicalRedirect = (~prefixPath: string, ~basePath: string): option<string> => {
  let suffix = "/" ++ basePath
  switch prefixPath == basePath {
  | true => Some("/" ++ basePath ++ "/")
  | false =>
    switch prefixPath->String.endsWith(suffix) {
    | true =>
      let stripped =
        prefixPath->String.slice(~start=0, ~end=prefixPath->String.length - suffix->String.length)
      let cleanPrefix = switch stripped {
      | "" => ""
      | p => p
      }
      let canonical = switch cleanPrefix {
      | "" => "/" ++ basePath ++ "/"
      | p => "/" ++ p ++ "/" ++ basePath ++ "/"
      }
      Some(canonical)
    | false =>
      switch prefixPath->String.startsWith(basePath ++ "/") {
      | true =>
        let rest =
          prefixPath->String.slice(
            ~start=basePath->String.length + 1,
            ~end=prefixPath->String.length,
          )
        let canonical = switch rest {
        | "" => "/" ++ basePath ++ "/"
        | p => "/" ++ p ++ "/" ++ basePath ++ "/"
        }
        Some(canonical)
      | false => None
      }
    }
  }
}

let buildEntrypointUrl = (
  ~config: MiddlewareConfig.t,
  ~requestUrl: string,
  ~prefixPath: string,
): option<string> => {
  switch config.entrypointUrl {
  | Some(_) as override => override
  | None =>
    let url = WebAPI.URL.make(~url=requestUrl)
    let origin = url.origin
    let pagePath = switch prefixPath {
    | "" => "/"
    | p => "/" ++ p ++ "/"
    }
    Some(origin ++ pagePath)
  }
}

@@live
let createMiddleware = (~config: MiddlewareConfig.t): (
  (
    WebAPI.FetchAPI.request,
    ~rawHeaders: RawHeaders.t=?,
  ) => promise<option<WebAPI.FetchAPI.response>>
) => {
  let middleware = async (
    req: WebAPI.FetchAPI.request,
    ~rawHeaders as _: option<RawHeaders.t>=?,
  ) => {
    let method = req.method->String.toLowerCase
    let url = WebAPI.URL.make(~url=req.url)
    let pathname = url.pathname

    let pathSegments =
      pathname
      ->String.split("/")
      ->Array.filter(p => !String.isEmpty(p))
    let originalPath = pathSegments->Array.join("/")
    let path = originalPath->String.toLowerCase

    let basePath = config.basePath->String.toLowerCase
    let resolveSourceLocationPath = basePath ++ "/resolve-source-location"

    let isApiRoute = path == resolveSourceLocationPath

    let suffixPrefix = switch isApiRoute {
    | true => None
    | false => getSuffixRoutePrefix(~path, ~basePath)
    }

    let originalSuffixPrefix = suffixPrefix->Option.map(loweredPrefix =>
      switch loweredPrefix {
      | "" => ""
      | _ => originalPath->String.slice(~start=0, ~end=loweredPrefix->String.length)
      }
    )

    let isFrontmanRoute = isApiRoute || suffixPrefix->Option.isSome

    switch (method, path) {
    | ("options", p) if p == resolveSourceLocationPath =>
      Some(
        await SourceLocationEndpoint.dispatch(
          ~config={security: config.sourceLocationSecurity, sourceRoot: config.sourceRoot},
          req,
        ),
      )
    | ("options", _) if isFrontmanRoute => Some(CORS.handlePreflight())

    | ("post", p) if p == resolveSourceLocationPath =>
      Some(
        await SourceLocationEndpoint.dispatch(
          ~config={security: config.sourceLocationSecurity, sourceRoot: config.sourceRoot},
          req,
        ),
      )

    | ("get", _) if suffixPrefix->Option.isSome =>
      let prefixPath = suffixPrefix->Option.getOrThrow
      switch getCanonicalRedirect(~prefixPath, ~basePath) {
      | Some(canonicalPath) =>
        Some(
          WebAPI.Response.fromString(
            "",
            ~init={
              status: 302,
              headers: WebAPI.HeadersInit.fromDict(Dict.fromArray([("Location", canonicalPath)])),
            },
          ),
        )
      | None =>
        let originalPrefix = originalSuffixPrefix->Option.getOrThrow
        let enableReactScan =
          url.searchParams->WebAPI.URLSearchParams.has(~name="debug") &&
            url.searchParams->WebAPI.URLSearchParams.get("debug")->Null.toOption == Some("1")
        let entrypointUrl = buildEntrypointUrl(
          ~config,
          ~requestUrl=req.url,
          ~prefixPath=originalPrefix,
        )
        Some(
          UIShell.serveWithEntrypoint(~config, ~entrypointUrl, ~enableReactScan)
          ->CORS.withCors
          ->withMcpBrowserCookie(~token=config.mcpBrowserToken, ~secure=url.protocol == "https:"),
        )
      }

    | _ => None
    }
  }

  middleware
}
