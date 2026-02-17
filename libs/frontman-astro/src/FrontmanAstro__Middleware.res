// Middleware for Frontman Astro integration
//
// Handles /frontman/* routes: UI serving, tool endpoints, source location resolution.
// Returns option<Response>: Some(response) for handled routes, None for pass-through.
// This middleware is designed to be adapted to Vite's Connect middleware via ViteAdapter.

module Config = FrontmanAstro__Config
module Server = FrontmanAstro__Server
module ToolRegistry = FrontmanAstro__ToolRegistry

// HTML template for the Frontman UI
let uiHtml = (~clientUrl: string, ~isLightTheme: bool) => {
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
  let themeClass = isLightTheme ? "" : "dark"
  `<!DOCTYPE html>
<html lang="en" class="${themeClass}">
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
  let html = uiHtml(~clientUrl=config.clientUrl, ~isLightTheme=config.isLightTheme)
  let headers = WebAPI.HeadersInit.fromDict(Dict.fromArray([("Content-Type", "text/html")]))
  WebAPI.Response.fromString(html, ~init={headers: headers})
}

// Create middleware handler
// Returns a function: Request => promise<option<Response>>
//   Some(response) => this route was handled
//   None => not a frontman route, pass through
let createMiddleware = (config: Config.t) => {
  let registry = ToolRegistry.make()

  async (request: WebAPI.FetchAPI.request): option<WebAPI.FetchAPI.response> => {
    let url = WebAPI.URL.make(~url=request.url)
    let pathname = url.pathname
    let method = request.method

    let basePath = `/${config.basePath}`

    // Only handle frontman routes
    if !(pathname == basePath || pathname->String.startsWith(`${basePath}/`)) {
      None
    } else if method == "OPTIONS" {
      Some(Server.handleCORS())
    } else {
      switch pathname {
      | p if p == basePath || p == `${basePath}/` => Some(serveUI(config))

      | p if p == `${basePath}/tools` && method == "GET" =>
        Some(Server.handleGetTools(~registry, ~config))

      | p if p == `${basePath}/tools/call` && method == "POST" =>
        Some(await Server.handleToolCall(~registry, ~config, request))

      | p if p == `${basePath}/resolve-source-location` && method == "POST" =>
        Some(await Server.handleResolveSourceLocation(~config, request))

      | _ =>
        Some(
          WebAPI.Response.jsonR(
            ~data=JSON.Encode.object(Dict.fromArray([("error", JSON.Encode.string("Not found"))])),
            ~init={status: 404},
          ),
        )
      }
    }
  }
}
