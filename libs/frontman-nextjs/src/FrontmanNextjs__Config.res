module Bindings = FrontmanBindings

// Default host can be overridden via FRONTMAN_HOST env var for remote development
let defaultHost = switch Bindings.Process.env->Dict.get("FRONTMAN_HOST") {
| Some(host) => host
| None => "frontman.local:4000"
}

type t = {
  isDev: bool,
  basePath: string,
  serverName: string,
  serverVersion: string,
  host: string,
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
  ~host=None,
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
  let host = host->Option.getOr(defaultHost)

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

  // Client URL can be overridden via FRONTMAN_CLIENT_URL env var for remote development
  let clientUrl = clientUrl->Option.getOr(
    switch Bindings.Process.env->Dict.get("FRONTMAN_CLIENT_URL") {
    | Some(baseUrl) => `${baseUrl}?clientName=nextjs&host=${host}`
    | None =>
      switch isDev {
      | true => `http://localhost:5173/src/Main.res.mjs?clientName=nextjs&host=${host}`
      | false => `https://frontman.dev/frontman.es.js?clientName=nextjs&host=${host}`
      }
    },
  )

  {
    isDev,
    basePath,
    serverName,
    serverVersion,
    host,
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
  host?: string,
  clientUrl?: string,
  clientCssUrl?: string,
  entrypointUrl?: string,
  isLightTheme?: bool,
  projectRoot?: string,
  sourceRoot?: string,
}

// JS-friendly function that accepts a config object - delegates to make
let makeFromObject = (config: jsConfigInput): t =>
  make(
    ~isDev=config.isDev,
    ~basePath=config.basePath,
    ~serverName=config.serverName,
    ~serverVersion=config.serverVersion,
    ~host=config.host,
    ~clientUrl=config.clientUrl,
    ~clientCssUrl=config.clientCssUrl,
    ~entrypointUrl=config.entrypointUrl,
    ~isLightTheme=config.isLightTheme,
    ~projectRoot=config.projectRoot,
    ~sourceRoot=config.sourceRoot,
  )
