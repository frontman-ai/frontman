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
    // Get raw env vars and filter out empty strings
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
    let payload = JSON.stringify(JSON.Encode.object(configObj))
    `<script>window.__frontmanRuntime=${payload}</script>`
  }

  let randomUuidPolyfillScript = `<script>(function(){var c=globalThis.crypto;if(!c||typeof c.randomUUID==="function"||typeof c.getRandomValues!=="function"){return;}var randomUUID=function(){var bytes=new Uint8Array(16);c.getRandomValues(bytes);bytes[6]=(bytes[6]&15)|64;bytes[8]=(bytes[8]&63)|128;var hex=Array.from(bytes,function(b){return b.toString(16).padStart(2,"0");}).join("");return hex.slice(0,8)+"-"+hex.slice(8,12)+"-"+hex.slice(12,16)+"-"+hex.slice(16,20)+"-"+hex.slice(20);};try{c.randomUUID=randomUUID;return;}catch(_){ }try{Object.defineProperty(c,"randomUUID",{value:randomUUID,configurable:true});}catch(_){ }}());</script>`

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
    ${randomUuidPolyfillScript}
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

// Serve with a dynamic entrypoint URL override for suffix-based routing.
let serveWithEntrypoint = (
  ~config: MiddlewareConfig.t,
  ~entrypointUrl: option<string>,
): WebAPI.FetchAPI.response => {
  let effectiveConfig = switch entrypointUrl {
  | Some(_) => {...config, entrypointUrl}
  | None => config
  }
  serve(effectiveConfig)
}
