// Browser URL sync for suffix-based routing.
//
// Keeps the browser URL in sync with the preview iframe URL by appending
// /<basePath> to the preview pathname via replaceState (avoids polluting
// browser history — the iframe manages its own back/forward).
//
// The basePath is read from window.__frontmanRuntime.basePath (injected by
// the server's HTML shell). Falls back to "frontman" if not present.
//
// NOTE: The URL construction logic in syncBrowserUrl (trailing-slash strip,
// suffix append) is intentionally duplicated in
// FrontmanAstro__ToolbarApp in libs/frontman-astro. The two files cannot
// share code because frontman-core is server-only. Keep the two
// implementations aligned — if you change one, update the other.

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

// Escape regex metacharacters in a string so it can be safely interpolated
// into a dynamically-built RegExp.
let _escapeRegex = s =>
  s->String.replaceRegExp(%re("/[.*+?^${}()|[\\]\\\\]/g"), "\\$&")

// Strip trailing /<basePath> segments (including trailing slash) from a pathname.
// Uses a regex to replace one or more repeated suffix segments in one pass.
let stripSuffix = pathname => {
  let sfx = _getBasePath()->_escapeRegex
  let re = RegExp.fromString(`(\\/${sfx})+\\/?$`)
  switch pathname->String.replaceRegExp(re, "") {
  | "" => "/"
  | p => p
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
  let pathname = WebAPI.URL.make(~url=previewUrl).pathname->String.replaceRegExp(%re("/\/$/"), "")
  let newPath = switch pathname {
  | "" => `/${basePath}`
  | p => `${p}/${basePath}`
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
