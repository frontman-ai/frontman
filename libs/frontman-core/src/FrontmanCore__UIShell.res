// Shared HTML shell generation for all framework adapters
//
// Generates the HTML page that hosts the Frontman client application.
// Each adapter passes its framework-specific config (framework label, client URL, etc.)

module MiddlewareConfig = FrontmanCore__MiddlewareConfig

let escapeHtmlAttribute = (value: string): string =>
  value
  ->String.replaceAll("&", "&amp;")
  ->String.replaceAll("\"", "&quot;")
  ->String.replaceAll("'", "&#39;")
  ->String.replaceAll("<", "&lt;")
  ->String.replaceAll(">", "&gt;")

// Pin the dev-only debugger so React Scan releases do not change Frontman debug behavior under us.
let reactScanScript = `<script src="https://unpkg.com/react-scan@0.5.3/dist/auto.global.js" crossorigin="anonymous"></script>`

let reactScanTag = (~enableReactScan: bool): string => {
  switch enableReactScan {
  | true => reactScanScript
  | false => ""
  }
}
// Generate the HTML shell for the Frontman UI
let generateHTML = (config: MiddlewareConfig.t, ~enableReactScan=false): string => {
  let clientCssTag =
    config.clientCssUrl->Option.mapOr("", url =>
      `<link rel="stylesheet" href="${url->escapeHtmlAttribute}">`
    )

  let entrypointTemplate =
    config.entrypointUrl->Option.mapOr("", url =>
      `<span id="frontman-entrypoint-url" hidden>${url->escapeHtmlAttribute}</span>`
    )

  let runtimeConfigScript = {
    let getEnvKey = varName =>
      FrontmanBindings.Process.env
      ->Dict.get(varName)
      ->Option.flatMap(key =>
        switch key != "" {
        | true => Some(key)
        | false => None
        }
      )
    let openrouterKey = getEnvKey("OPENROUTER_API_KEY")
    let anthropicKey = getEnvKey("ANTHROPIC_API_KEY")
    let fireworksKey = getEnvKey("FIREWORKS_API_KEY")
    // Build JSON payload using proper JSON encoding to handle special characters
    let configObj = Dict.fromArray([
      ("framework", JSON.Encode.string(MiddlewareConfig.frameworkIdToString(config.frameworkId))),
      ("basePath", JSON.Encode.string(config.basePath)),
      ("projectRoot", JSON.Encode.string(config.projectRoot)),
      ("sourceRoot", JSON.Encode.string(config.sourceRoot)),
    ])
    // Add key values if present and non-empty
    openrouterKey->Option.forEach(key => {
      configObj->Dict.set("openrouterKeyValue", JSON.Encode.string(key))
    })
    anthropicKey->Option.forEach(key => {
      configObj->Dict.set("anthropicKeyValue", JSON.Encode.string(key))
    })
    fireworksKey->Option.forEach(key => {
      configObj->Dict.set("fireworksKeyValue", JSON.Encode.string(key))
    })
    let payload = JSON.stringify(JSON.Encode.object(configObj))
    `<script>window.__frontmanRuntime=${payload}</script>`
  }

  `<!DOCTYPE html>
<html lang="en" class="dark">
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
    ${reactScanTag(~enableReactScan)}
    <script type="module" src="${config.clientUrl->escapeHtmlAttribute}"></script>
</body>
</html>`
}

// Serve the HTML shell as a Response
let serve = (config: MiddlewareConfig.t, ~enableReactScan=false): WebAPI.FetchAPI.response => {
  let html = generateHTML(config, ~enableReactScan)
  let headers = WebAPI.HeadersInit.fromDict(Dict.fromArray([("Content-Type", "text/html")]))
  WebAPI.Response.fromString(html, ~init={headers: headers})
}

// Serve with a dynamic entrypoint URL override for suffix-based routing.
let serveWithEntrypoint = (
  ~config: MiddlewareConfig.t,
  ~entrypointUrl: option<string>,
  ~enableReactScan=false,
): WebAPI.FetchAPI.response => {
  let effectiveConfig = switch entrypointUrl {
  | Some(_) => {...config, entrypointUrl}
  | None => config
  }
  serve(effectiveConfig, ~enableReactScan)
}
