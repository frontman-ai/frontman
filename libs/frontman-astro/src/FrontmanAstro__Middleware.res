// Astro middleware for Frontman

module Config = FrontmanAstro__Config
module Server = FrontmanAstro__Server
module ToolRegistry = FrontmanAstro__ToolRegistry

// HTML template for the Frontman UI
let uiHtml = (~clientUrl: string) => {
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

// Type for Astro middleware context (minimal interface)
type astroContext = {request: WebAPI.FetchAPI.request}

// Type for Astro next function
type astroNext = unit => promise<WebAPI.FetchAPI.response>

// Create middleware handler
// Returns a function that can be used with Astro's sequence() or directly
let createMiddleware = (config: Config.t) => {
  let registry = ToolRegistry.make()

  async (context: astroContext, next: astroNext): WebAPI.FetchAPI.response => {
    let url = WebAPI.URL.parse(~url=context.request.url)
    let pathname = url.pathname
    let method = context.request.method

    let basePath = `/${config.basePath}`

    // Check if this is a frontman route
    if !(pathname->String.startsWith(basePath)) {
      await next()
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
