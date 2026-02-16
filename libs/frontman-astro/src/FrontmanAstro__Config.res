// Astro configuration for Frontman

module Bindings = FrontmanBindings

// Default host can be overridden via FRONTMAN_HOST env var for remote development
let defaultHost = switch Bindings.Process.env->Dict.get("FRONTMAN_HOST") {
| Some(host) => host
| None => "frontman.local:4000"
}

type t = {
  projectRoot: string,
  // sourceRoot: root for resolving file paths from Astro's data-astro-source-file attributes
  // In a monorepo, this is typically the monorepo root. Defaults to projectRoot.
  sourceRoot: string,
  basePath: string,
  serverName: string,
  serverVersion: string,
  host: string,
  clientUrl: string,
  isLightTheme: bool,
}

// JS-friendly type for config input
type jsConfigInput = {
  projectRoot?: string,
  sourceRoot?: string,
  basePath?: string,
  serverName?: string,
  serverVersion?: string,
  host?: string,
  clientUrl?: string,
  isLightTheme?: bool,
}

// JS-friendly function that accepts a config object
// Use this from JavaScript/TypeScript: makeConfig({ projectRoot: "..." })
let makeFromObject = (config: jsConfigInput): t => {
  let projectRoot =
    config.projectRoot
    ->Option.orElse(
      Bindings.Process.env
      ->Dict.get("PROJECT_ROOT")
      ->Option.orElse(Bindings.Process.env->Dict.get("PWD")),
    )
    ->Option.getOr(".")

  let sourceRoot = config.sourceRoot->Option.getOr(projectRoot)
  let basePath = config.basePath->Option.getOr("frontman")
  let serverName = config.serverName->Option.getOr("frontman-astro")
  let serverVersion = config.serverVersion->Option.getOr("1.0.0")
  let isLightTheme = config.isLightTheme->Option.getOr(false)
  let host = config.host->Option.getOr(defaultHost)

  let clientUrl = config.clientUrl->Option.getOr({
    let baseUrl =
      Bindings.Process.env
      ->Dict.get("FRONTMAN_CLIENT_URL")
      ->Option.getOr("http://localhost:5173/src/Main.res.mjs")
    // Use URL API to properly append params (handles base URLs that already have query strings)
    let url = WebAPI.URL.make(~url=baseUrl)
    url.searchParams->WebAPI.URLSearchParams.set(~name="clientName", ~value="astro")
    url.searchParams->WebAPI.URLSearchParams.set(~name="host", ~value=host)
    url.href
  })

  // Assert clientUrl contains the required "host" query param that the client reads from import.meta.url
  let parsedUrl = WebAPI.URL.make(~url=clientUrl)
  if !(parsedUrl.searchParams->WebAPI.URLSearchParams.has(~name="host")) {
    JsError.throwWithMessage(
      `[frontman-astro] clientUrl must include a "host" query parameter. Got: ${clientUrl}`,
    )
  }

  {
    projectRoot,
    sourceRoot,
    basePath,
    serverName,
    serverVersion,
    host,
    clientUrl,
    isLightTheme,
  }
}
