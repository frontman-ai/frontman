// Shared HTML shell generation for all framework adapters
//
// Generates the HTML page that hosts the Frontman client application.
// Each adapter passes its framework-specific config (framework label, client URL, etc.)

module MiddlewareConfig = FrontmanCore__MiddlewareConfig

// Generate the HTML shell for the Frontman UI
let generateHTML = (config: MiddlewareConfig.t): string => {
  let clientCssTag =
    config.clientCssUrl->Option.mapOr("", url => `<link rel="stylesheet" href="${url}">`)

  let entrypointTemplate =
    config.entrypointUrl->Option.mapOr("", url =>
      `<script type="template" id="frontman-entrypoint-url">${url}</script>`
    )

  let themeClass = switch config.isLightTheme {
  | true => ""
  | false => "dark"
  }

  let runtimeConfigScript = {
    // Get the raw env var and filter out empty strings
    let openrouterKey =
      FrontmanBindings.Process.env
      ->Dict.get("OPENROUTER_API_KEY")
      ->Option.flatMap(key =>
        switch key != "" {
        | true => Some(key)
        | false => None
        }
      )
    // Build JSON payload using proper JSON encoding to handle special characters
    let configObj = Dict.fromArray([("framework", JSON.Encode.string(config.frameworkLabel))])
    // Add key value if present and non-empty
    openrouterKey->Option.forEach(key => {
      configObj->Dict.set("openrouterKeyValue", JSON.Encode.string(key))
    })
    let payload = JSON.stringify(JSON.Encode.object(configObj))
    `<script>window.__frontmanRuntime=${payload}</script>`
  }

  `<!DOCTYPE html>
<html lang="en" class="${themeClass}">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Frontman</title>
    ${entrypointTemplate}
    ${clientCssTag}
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
    ${runtimeConfigScript}
    <script>if(typeof process==="undefined"){window.process={env:{NODE_ENV:"production"}}}</script>
    <script type="module" src="${config.clientUrl}"></script>
</body>
</html>`
}

// Serve the HTML shell as a Response
let serve = (config: MiddlewareConfig.t): WebAPI.FetchAPI.response => {
  let html = generateHTML(config)
  let headers = WebAPI.HeadersInit.fromDict(Dict.fromArray([("Content-Type", "text/html")]))
  WebAPI.Response.fromString(html, ~init={headers: headers})
}
