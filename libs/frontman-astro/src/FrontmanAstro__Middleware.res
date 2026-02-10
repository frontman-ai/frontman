// Astro middleware for Frontman

module Config = FrontmanAstro__Config
module Server = FrontmanAstro__Server
module ToolRegistry = FrontmanAstro__ToolRegistry

// Annotation capture script - injected before </body>
// Stores paths exactly as Astro provides them (should be absolute paths)
let annotationCaptureScript = `
<script>
(function() {
  var annotations = new Map();
  document.querySelectorAll('[data-astro-source-file]').forEach(function(el) {
    annotations.set(el, {
      file: el.getAttribute('data-astro-source-file'),
      loc: el.getAttribute('data-astro-source-loc')
    });
  });
  window.__frontman_annotations__ = {
    _map: annotations,
    get: function(el) { return annotations.get(el); },
    has: function(el) { return annotations.has(el); },
    size: function() { return annotations.size; }
  };
  console.log('[Frontman] Captured ' + annotations.size + ' elements');
})();
</script>
`

// Helper to inject script into HTML response
let injectAnnotationScript = async (response: WebAPI.FetchAPI.response): WebAPI.FetchAPI.response => {
  let contentType = response.headers->WebAPI.Headers.get("content-type")->Null.toOption

  switch contentType {
  | Some(ct) if ct->String.includes("text/html") =>
    let html = await response->WebAPI.Response.text
    let injectedHtml = html->String.replace("</body>", `${annotationCaptureScript}</body>`)

    WebAPI.Response.fromString(
      injectedHtml,
      ~init={
        status: response.status,
        headers: WebAPI.HeadersInit.fromHeaders(response.headers),
      },
    )
  | _ => response
  }
}

// HTML template for the Frontman UI
let uiHtml = (~clientUrl: string) => {
  // Get the raw env var and filter out empty strings
  let openrouterKey =
    FrontmanBindings.Process.env
    ->Dict.get("OPENROUTER_API_KEY")
    ->Option.flatMap(key => key != "" ? Some(key) : None)
  // Build JSON payload using proper JSON encoding to handle special characters
  let configObj = Dict.fromArray([("framework", JSON.Encode.string("Astro"))])
  openrouterKey->Option.forEach(key => {
    configObj->Dict.set("openrouterKeyValue", JSON.Encode.string(key))
  })
  let runtimeConfig = JSON.stringify(JSON.Encode.object(configObj))
  `<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Frontman</title>
  <style>
    html, body, #root {
      margin: 0;
      padding: 0;
      height: 100%;
      width: 100%;
    }
  </style>
</head>
<body>
  <div id="root"></div>
  <script>window.__frontmanRuntime=${runtimeConfig}</script>
  <script type="module" src="${clientUrl}"></script>
</body>
</html>`
}

// Serve UI HTML
let serveUI = (config: Config.t): WebAPI.FetchAPI.response => {
  let html = uiHtml(~clientUrl=config.clientUrl)
  let headers = WebAPI.HeadersInit.fromDict(Dict.fromArray([("Content-Type", "text/html")]))
  WebAPI.Response.fromString(html, ~init={headers: headers})
}

// Type for Astro URL object (subset we need)
type astroUrl = {pathname: string}

// Type for Astro middleware context (subset of APIContext we actually use)
type astroContext = {
  request: WebAPI.FetchAPI.request,
  url: astroUrl,
}

// Type for Astro next function
type astroNext = unit => promise<WebAPI.FetchAPI.response>

// Create middleware handler
// Returns a function that can be used directly as Astro middleware
let createMiddleware = (config: Config.t) => {
  let registry = ToolRegistry.make()

  async (context: astroContext, next: astroNext): WebAPI.FetchAPI.response => {
    let pathname = context.url.pathname
    let method = context.request.method

    let basePath = `/${config.basePath}`

    // Check if this is a frontman route (exact match or subpath)
    if !(pathname == basePath || pathname->String.startsWith(`${basePath}/`)) {
      // Not a frontman route - pass through but inject script into HTML
      let response = await next()
      await injectAnnotationScript(response)
    } else if method == "OPTIONS" {
      // Handle CORS preflight
      Server.handleCORS()
    } else {
      // Route handling
      switch pathname {
      | p if p == basePath || p == `${basePath}/` =>
        serveUI(config)

      | p if p == `${basePath}/tools` && method == "GET" =>
        Server.handleGetTools(~registry, ~config)

      | p if p == `${basePath}/tools/call` && method == "POST" =>
        await Server.handleToolCall(~registry, ~config, context.request)

      | p if p == `${basePath}/resolve-source-location` && method == "POST" =>
        await Server.handleResolveSourceLocation(~config, context.request)

      | _ =>
        // Unknown frontman route
        WebAPI.Response.jsonR(
          ~data=JSON.Encode.object(Dict.fromArray([("error", JSON.Encode.string("Not found"))])),
          ~init={status: 404},
        )
      }
    }
  }
}
