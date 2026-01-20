// Middleware factory for NextJS

module Server = FrontmanNextjs__Server
module Config = FrontmanNextjs__Config
module LogCapture = FrontmanNextjs__LogCapture

type config = Config.t

// CORS headers for cross-origin requests (e.g., browser test page on different port)
let corsHeaders = Dict.fromArray([
  ("Access-Control-Allow-Origin", "*"),
  ("Access-Control-Allow-Methods", "GET, POST, OPTIONS"),
  ("Access-Control-Allow-Headers", "Content-Type"),
])

// Add CORS headers to a response
let withCors = (response: WebAPI.FetchAPI.response): WebAPI.FetchAPI.response => {
  let headers = response.headers
  corsHeaders->Dict.forEachWithKey((value, key) => {
    headers->WebAPI.Headers.set(~name=key, ~value)
  })
  response
}

// Handle OPTIONS preflight request
let handlePreflight = (): WebAPI.FetchAPI.response => {
  let headers = WebAPI.HeadersInit.fromDict(corsHeaders)
  WebAPI.Response.fromNull(~init={status: 204, headers})
}

// Handle UI endpoint - serves the frontman client HTML
let handleUI = (config: config): WebAPI.FetchAPI.response => {
  let clientCssTag =
    config.clientCssUrl->Option.mapOr("", url => `<link rel="stylesheet" href="${url}">`)

  let entrypointTemplate =
    config.entrypointUrl->Option.mapOr("", url =>
      `<script type="template" id="frontman-entrypoint-url">${url}</script>`
    )

  let themeClass = config.isLightTheme ? "" : "dark"

  let runtimeConfigScript = {
    // Get the raw env var and filter out empty strings
    let openrouterKey =
      FrontmanBindings.Process.env
      ->Dict.get("OPENROUTER_API_KEY")
      ->Option.flatMap(key => key != "" ? Some(key) : None)
    let frameworkLabel = "Next.js"
    // Build JSON payload using proper JSON encoding to handle special characters
    let configObj = Dict.fromArray([("framework", JSON.Encode.string(frameworkLabel))])
    // Add key value if present and non-empty
    openrouterKey->Option.forEach(key => {
      configObj->Dict.set("openrouterKeyValue", JSON.Encode.string(key))
    })
    let payload = JSON.stringify(JSON.Encode.object(configObj))
    `<script>window.__frontmanRuntime=${payload}</script>`
  }

  let html = `<!DOCTYPE html>
<html lang="en" class="${themeClass}">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Frontman</title>
    ${entrypointTemplate}
    ${clientCssTag}
</head>
<body>
    <div id="root"></div>
    ${runtimeConfigScript}
    <script type="module" src="${config.clientUrl}"></script>
</body>
</html>`

  let headers = WebAPI.HeadersInit.fromDict(Dict.fromArray([("Content-Type", "text/html")]))
  WebAPI.Response.fromString(html, ~init={headers: headers})
}

// Create middleware from a config input object (applies defaults)
let createMiddleware = (configInput: Config.jsConfigInput) => {
  let config = Config.makeFromObject(configInput)
  let server = Server.make(
    ~projectRoot=config.projectRoot,
    ~sourceRoot=config.sourceRoot,
    ~serverName=config.serverName,
    ~serverVersion=config.serverVersion,
  )

  let middleware: WebAPI.FetchAPI.request => promise<
    option<WebAPI.FetchAPI.response>,
  > = async req => {
    let method = req.method->String.toLowerCase
    let pathname = WebAPI.URL.parse(~url=req.url).pathname

    // Normalize path: remove leading slash, lowercase
    let path =
      pathname
      ->String.split("/")
      ->Array.filter(p => !String.isEmpty(p))
      ->Array.join("/")
      ->String.toLowerCase

    let toolsPath = config.basePath->String.toLowerCase ++ "/tools"
    let toolsCallPath = config.basePath->String.toLowerCase ++ "/tools/call"
    let resolveSourceLocationPath =
      config.basePath->String.toLowerCase ++ "/resolve-source-location"

    let uiPath = config.basePath->String.toLowerCase

    // Check if this is a frontman route (for CORS preflight)
    let isFrontmanRoute =
      path == toolsPath ||
      path == toolsCallPath ||
      path == resolveSourceLocationPath ||
      path == uiPath

    switch (method, path) {
    | ("options", _) if isFrontmanRoute => Some(handlePreflight())
    | ("get", p) if p == uiPath => Some(handleUI(config)->withCors)
    | ("get", p) if p == toolsPath => Some(server->Server.handleGetTools->withCors)
    | ("post", p) if p == toolsCallPath =>
      Some((await server->Server.handleToolCall(req))->withCors)
    | ("post", p) if p == resolveSourceLocationPath =>
      Some((await server->Server.handleResolveSourceLocation(req))->withCors)
    | _ => None
    }
  }

  middleware
}
