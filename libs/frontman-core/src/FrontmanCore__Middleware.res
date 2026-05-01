// Shared middleware factory: Request => Promise<Option<Response>>
//
// Supports suffix-based URL routing: /products/123/frontman serves the UI
// with the preview pointing at /products/123. API routes stay at fixed paths.
// Used by Vite, Next.js, and Astro adapters.

module CORS = FrontmanCore__CORS
module RequestHandlers = FrontmanCore__RequestHandlers
module UIShell = FrontmanCore__UIShell
module MiddlewareConfig = FrontmanCore__MiddlewareConfig
module ToolRegistry = FrontmanCore__ToolRegistry

// Check if a normalized path (no leading slash) is a suffix-based UI route.
// Returns the prefix (everything before /basePath) if it matches, None otherwise.
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

// Check whether a raw pathname (with leading slash) is a frontman route.
// Suffix routes (path ending with /basePath) only match GET — for other
// methods the core middleware won't handle them, so returning true would
// cause adapters to drain the request body for nothing.
let isFrontmanRoute = (~pathname: string, ~basePath: string, ~method: string): bool => {
  let prefix = "/" ++ basePath->String.toLowerCase
  let path = pathname->String.toLowerCase
  let isPrefixRoute = path == prefix || path->String.startsWith(prefix ++ "/")
  let isSuffixRoute = path->String.endsWith(prefix) || path->String.endsWith(prefix ++ "/")
  isPrefixRoute || (method->String.toUpperCase == "GET" && isSuffixRoute)
}

// Build the canonical path for a suffix route prefix.
// Returns None if already canonical, Some(path) if a redirect is needed.
// Only detects actual frontman-in-frontman nesting — does NOT strip legitimate
// user URL segments that happen to match basePath.
// All returned paths include a trailing slash to avoid an extra redirect from
// frameworks with trailingSlash: "always" (e.g. Astro's default).
//
// Cases detected:
//   prefixPath == basePath (e.g. "frontman" from /frontman/frontman)
//   prefixPath ends with /basePath (e.g. "blog/frontman" from /blog/frontman/frontman)
//   prefixPath starts with basePath/ (e.g. "frontman/page" from /frontman/page/frontman)
let getCanonicalRedirect = (~prefixPath: string, ~basePath: string): option<string> => {
  let suffix = "/" ++ basePath
  // Exact match: prefix IS the basePath (e.g. /frontman/frontman -> prefix "frontman")
  switch prefixPath == basePath {
  | true => Some("/" ++ basePath ++ "/")
  | false =>
    // Trailing nested suffix: strip one trailing /basePath from prefix
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
      // Leading basePath/ prefix: strip leading basePath/ from prefix
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

// Build entrypoint URL from request origin + prefix. Config override takes precedence.
// Always includes a trailing slash so frameworks with trailingSlash: "always"
// (e.g. Astro's default) don't redirect the iframe on load.
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

// Create middleware from config and registry
// Returns request => promise<option<response>>
// None means "not handled, pass through to next middleware"
let createMiddleware = (~config: MiddlewareConfig.t, ~registry: ToolRegistry.t): (
  WebAPI.FetchAPI.request => promise<option<WebAPI.FetchAPI.response>>
) => {
  let handlerConfig: RequestHandlers.handlerConfig = {
    projectRoot: config.projectRoot,
    sourceRoot: config.sourceRoot,
    serverName: config.serverName,
    serverVersion: config.serverVersion,
  }

  let middleware: WebAPI.FetchAPI.request => promise<
    option<WebAPI.FetchAPI.response>,
  > = async req => {
    let method = req.method->String.toLowerCase
    let url = WebAPI.URL.make(~url=req.url)
    let pathname = url.pathname

    // Normalize path segments — keep original case for URL construction,
    // lowercase copy for case-insensitive route matching.
    let pathSegments =
      pathname
      ->String.split("/")
      ->Array.filter(p => !String.isEmpty(p))
    let originalPath = pathSegments->Array.join("/")
    let path = originalPath->String.toLowerCase

    let basePath = config.basePath->String.toLowerCase
    let toolsPath = basePath ++ "/tools"
    let toolsCallPath = basePath ++ "/tools/call"
    let resolveSourceLocationPath = basePath ++ "/resolve-source-location"

    let isApiRoute = path == toolsPath || path == toolsCallPath || path == resolveSourceLocationPath

    let suffixPrefix = switch isApiRoute {
    | true => None
    | false => getSuffixRoutePrefix(~path, ~basePath)
    }

    // Original-case prefix for entrypoint URL construction (avoids lowercasing user paths).
    let originalSuffixPrefix = suffixPrefix->Option.map(loweredPrefix =>
      switch loweredPrefix {
      | "" => ""
      | _ =>
        // Slice originalPath to the same length as the lowered prefix
        originalPath->String.slice(~start=0, ~end=loweredPrefix->String.length)
      }
    )

    let isFrontmanRoute = isApiRoute || suffixPrefix->Option.isSome

    switch (method, path) {
    | ("options", _) if isFrontmanRoute => Some(CORS.handlePreflight())

    // API routes
    | ("get", p) if p == toolsPath =>
      Some(RequestHandlers.handleGetTools(~registry, ~config=handlerConfig)->CORS.withCors)
    | ("post", p) if p == toolsCallPath =>
      Some(
        (
          await RequestHandlers.handleToolCall(~registry, ~config=handlerConfig, req)
        )->CORS.withCors,
      )
    | ("post", p) if p == resolveSourceLocationPath =>
      Some(
        (
          await RequestHandlers.handleResolveSourceLocation(~sourceRoot=config.sourceRoot, req)
        )->CORS.withCors,
      )

    // UI route (suffix match) — redirect nested basePath segments to canonical URL
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
        // Use original-case prefix to preserve URL casing for case-sensitive frameworks
        let originalPrefix = originalSuffixPrefix->Option.getOrThrow
        let enableReactScan =
          url.searchParams->WebAPI.URLSearchParams.has(~name="debug") &&
            url.searchParams->WebAPI.URLSearchParams.get("debug") == "1"
        let entrypointUrl = buildEntrypointUrl(
          ~config,
          ~requestUrl=req.url,
          ~prefixPath=originalPrefix,
        )
        Some(UIShell.serveWithEntrypoint(~config, ~entrypointUrl, ~enableReactScan)->CORS.withCors)
      }

    | _ => None
    }
  }

  middleware
}
