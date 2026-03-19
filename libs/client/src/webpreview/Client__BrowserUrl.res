// Browser URL sync for suffix-based routing.
//
// Keeps the browser URL in sync with the preview iframe URL by appending
// /<basePath> to the preview pathname via replaceState (avoids polluting
// browser history — the iframe manages its own back/forward).
//
// The basePath is read from window.__frontmanRuntime.basePath (injected by
// the server's HTML shell). Falls back to "frontman" if not present.
//
// NOTE: The URL construction logic in syncBrowserUrl (suffix append with
// trailing slash) is intentionally duplicated in FrontmanAstro__ToolbarApp
// in libs/frontman-astro. The two files cannot share code because
// frontman-core is server-only. Keep the two implementations aligned —
// if you change one, update the other.

// Read basePath from runtime config. Lazy — reads once on first access.
// Falls back to "frontman" if runtime config is unavailable (e.g. in tests).
let _getBasePath: unit => string = {
  let cached = ref(None)
  () =>
    switch cached.contents {
    | Some(bp) => bp
    | None =>
      let bp = try {
        Client__RuntimeConfig.read().basePath
      } catch {
      | _ =>
        // Console.warn used intentionally — this runs before ACP.connect() registers
        // the log handler, so Logs.* calls would be silently dropped.
        Console.warn("RuntimeConfig.basePath unavailable, falling back to \"frontman\"")
        "frontman"
      }
      cached := Some(bp)
      bp
    }
}

// Returns the URL suffix including the leading slash (e.g. "/frontman").
let suffix = () => `/${_getBasePath()}`

// Strip a single trailing slash from a URL or pathname, unless it's just "/".
// Used to normalize trailing-slash variants (e.g. /en and /en/) so they are
// treated as the same destination for comparison and URL building purposes.
let removeTrailingSlash = s =>
  switch s->String.endsWith("/") && String.length(s) > 1 {
  | true => s->String.slice(~start=0, ~end=String.length(s) - 1)
  | false => s
  }

// Escape regex metacharacters in a string so it can be safely interpolated
// into a dynamically-built RegExp.
let _escapeRegex = s =>
  s->String.replaceRegExp(%re("/[.*+?^${}()|[\\]\\\\]/g"), "\\$&")

// Returns true if pathname contains one or more trailing /<basePath> segments.
// Pure predicate — does not mutate the path.
let hasSuffix = pathname => {
  let sfx = _getBasePath()->_escapeRegex
  let re = RegExp.fromString(`(\\/${sfx})+\\/?$`)
  re->RegExp.test(pathname)
}

// Strip trailing /<basePath> segments from a pathname. When a suffix is
// present, the result is normalized with a trailing slash to match Astro's
// trailingSlash: "always" default. When no suffix is present the original
// pathname is returned unchanged — no trailing slash is added — to avoid
// false positives in callers that use string equality to detect mutations
// (e.g. the useIFrameLocation navigate intercept).
let stripSuffix = pathname => {
  switch hasSuffix(pathname) {
  | false => pathname
  | true =>
    let sfx = _getBasePath()->_escapeRegex
    let re = RegExp.fromString(`(\\/${sfx})+\\/?$`)
    switch pathname->String.replaceRegExp(re, "") {
    | "" => "/"
    | p =>
      switch p->String.endsWith("/") {
      | true => p
      | false => p ++ "/"
      }
    }
  }
}

// Derive the initial preview URL from the browser location.
// Reads the entrypoint URL from the DOM if present (#frontman-entrypoint-url),
// otherwise builds it from the current browser URL with the suffix stripped.
let getInitialUrl = () => {
  let currentUrl =
    WebAPI.Global.window->WebAPI.Window.location->WebAPI.Location.href->WebAPI.URL.make(~url=_)
  let previewPath = WebAPI.Global.location.pathname->stripSuffix
  let default = `${currentUrl.protocol}//${currentUrl.host}${previewPath}`

  WebAPI.Global.document
  ->WebAPI.Document.querySelector("#frontman-entrypoint-url")
  ->Null.flatMap(element => {
    element->WebAPI.Element.asNode->WebAPI.Node.textContent
  })
  ->Null.toOption
  ->Option.map(entrypointUrl => {
    // Normalize the scheme to match the browser's protocol.
    // When behind a TLS-terminating reverse proxy (e.g. Caddy), the server
    // sees http:// internally but the browser loaded the page over https://.
    // Without this, the iframe would load http:// → Mixed Content error.
    let browserProtocol = currentUrl.protocol
    try {
      let parsed = WebAPI.URL.make(~url=entrypointUrl)
      switch parsed.protocol == browserProtocol {
      | true => entrypointUrl
      | false =>
        `${browserProtocol}//${parsed.host}${parsed.pathname}${parsed.search}${parsed.hash}`
      }
    } catch {
    | _ => entrypointUrl
    }
  })
  ->Option.getOr(default)
}

// Resolve a (potentially relative) URL against a base, returning None on failure.
let resolveUrlWithBase = (~url: string, ~base: string): option<string> => {
  try {
    Some(WebAPI.URL.make(~url, ~base).href)
  } catch {
  | _ => None
  }
}

// Check whether two URLs share the same origin (protocol + host).
let isSameOriginWithBase = (~baseUrl: string, ~targetUrl: string): bool => {
  try {
    let base = WebAPI.URL.make(~url=baseUrl)
    let target = WebAPI.URL.make(~url=targetUrl, ~base=baseUrl)
    base.protocol == target.protocol && base.host == target.host
  } catch {
  | _ => false
  }
}

// Sync browser URL to reflect the current preview URL.
// The preview URL is guaranteed clean (no /<basePath> suffix) by useIFrameLocation.
let syncBrowserUrl = (~previewUrl) => {
  let basePath = _getBasePath()
  let pathname = WebAPI.URL.make(~url=previewUrl).pathname->removeTrailingSlash
  let newPath = switch pathname {
  | "" | "/" => `/${basePath}/`
  | p => `${p}/${basePath}/`
  }
  switch WebAPI.Global.location.pathname == newPath {
  | true => ()
  | false =>
    WebAPI.Global.history->WebAPI.History.replaceState(
      ~data=JSON.Encode.null,
      ~unused="",
      ~url=newPath,
    )
  }
}
