module Bindings = FrontmanBindings

type t = {
  isDev: bool,
  basePath: string,
  serverName: string,
  serverVersion: string,
  clientUrl: string,
  clientCssUrl: option<string>,
  entrypointUrl: option<string>,
  isLightTheme: bool,
  projectRoot: string,
  // sourceRoot: root for file paths (monorepo root in monorepo setups)
  // Defaults to projectRoot if not specified
  sourceRoot: string,
}

// Internal make function with labeled parameters (for ReScript callers)
let make = (
  ~isDev=None,
  ~basePath=None,
  ~serverName=None,
  ~serverVersion=None,
  ~clientUrl=None,
  ~clientCssUrl=None,
  ~entrypointUrl=None,
  ~isLightTheme=None,
  ~projectRoot=None,
  ~sourceRoot=None,
) => {
  let isDev =
    isDev->Option.getOr(
      Bindings.Process.env->Dict.get("NODE_ENV")->Option.getOr("production") == "development",
    )
  let basePath = basePath->Option.getOr("__frontman")
  let serverName = serverName->Option.getOr("frontman-nextjs")
  let serverVersion = serverVersion->Option.getOr("1.0.0")
  let isLightTheme = isLightTheme->Option.getOr(false)

  let projectRoot =
    projectRoot
    ->Option.orElse(
      Bindings.Process.env
      ->Dict.get("PROJECT_ROOT")
      ->Option.orElse(Bindings.Process.env->Dict.get("PWD")),
    )
    ->Option.getOr(".")

  // sourceRoot defaults to projectRoot if not specified
  let sourceRoot = sourceRoot->Option.getOr(projectRoot)

  let clientUrl = clientUrl->Option.getOr(
    switch isDev {
    | true => "http://localhost:5173/src/Main.res.mjs?clientName=nextjs"
    | false => "https://frontman.dev/frontman.es.js?clientName=nextjs"
    },
  )

  {
    isDev,
    basePath,
    serverName,
    serverVersion,
    clientUrl,
    clientCssUrl,
    entrypointUrl,
    isLightTheme,
    projectRoot,
    sourceRoot,
  }
}

// JS-friendly type for config input (used by makeConfigFromObject)
type jsConfigInput = {
  isDev?: bool,
  basePath?: string,
  serverName?: string,
  serverVersion?: string,
  clientUrl?: string,
  clientCssUrl?: string,
  entrypointUrl?: string,
  isLightTheme?: bool,
  projectRoot?: string,
  sourceRoot?: string,
}

// JS-friendly function that accepts a config object
// Use this from JavaScript/TypeScript: makeConfig({ projectRoot: "..." })
let makeFromObject = (config: jsConfigInput): t => {
  // Extract values from optional record fields and compute defaults
  let isDev =
    config.isDev->Option.getOr(
      Bindings.Process.env->Dict.get("NODE_ENV")->Option.getOr("production") == "development",
    )
  let basePath = config.basePath->Option.getOr("__frontman")
  let serverName = config.serverName->Option.getOr("frontman-nextjs")
  let serverVersion = config.serverVersion->Option.getOr("1.0.0")
  let isLightTheme = config.isLightTheme->Option.getOr(false)

  let projectRoot =
    config.projectRoot
    ->Option.orElse(
      Bindings.Process.env
      ->Dict.get("PROJECT_ROOT")
      ->Option.orElse(Bindings.Process.env->Dict.get("PWD")),
    )
    ->Option.getOr(".")

  let sourceRoot = config.sourceRoot->Option.getOr(projectRoot)

  let clientUrl = config.clientUrl->Option.getOr(
    switch isDev {
    | true => "http://localhost:5173/src/Main.res.mjs?clientName=nextjs"
    | false => "https://frontman.dev/frontman.es.js?clientName=nextjs"
    },
  )

  {
    isDev,
    basePath,
    serverName,
    serverVersion,
    clientUrl,
    clientCssUrl: config.clientCssUrl,
    entrypointUrl: config.entrypointUrl,
    isLightTheme,
    projectRoot,
    sourceRoot,
  }
}
