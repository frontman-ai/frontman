// Injected at build time by tsup define — crash if missing so we catch broken builds immediately.
// Must use %raw with typeof guard: @val external won't work because __PACKAGE_VERSION__ is a
// build-time constant replaced by tsup, not a runtime global.
let packageVersion: string = %raw(`typeof __PACKAGE_VERSION__ !== "undefined" ? __PACKAGE_VERSION__ : undefined`)
let () = if Js.typeof(packageVersion) == "undefined" {
  JsError.throwWithMessage("__PACKAGE_VERSION__ is not defined — tsup build is misconfigured")
}

module Bindings = FrontmanBindings
module Hosts = FrontmanAiFrontmanCore.FrontmanCore__Hosts

// Default host can be overridden via env vars for development.
// Priority:
// 1) FRONTMAN_HOST (explicit Frontman server host)
// 2) api.frontman.sh (production default)
let defaultHost =
  switch Bindings.Process.env->Dict.get("FRONTMAN_HOST") {
  | Some(host) if host != "" => host
  | _ => Hosts.apiHost
  }

// Normalize host values so users can pass either bare hosts or full URLs.
// Examples:
// - api.frontman.sh -> api.frontman.sh
// - https://api.frontman.sh -> api.frontman.sh
// - https://api.frontman.sh:443 -> api.frontman.sh
// - http://frontman.local:4000 -> frontman.local:4000
let normalizeHost = (host: string): string => {
  let trimmed = host->String.trim
  let candidate = switch trimmed->String.includes("://") {
  | true => trimmed
  | false => "https://" ++ trimmed
  }

  try {
    let parsed = WebAPI.URL.make(~url=candidate)
    let normalized = switch parsed.port {
    | "" | "443" => parsed.hostname
    | port => `${parsed.hostname}:${port}`
    }
    normalized->String.toLowerCase
  } catch {
  | _ => trimmed->String.toLowerCase
  }
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
  let host = host->Option.getOr(defaultHost)->normalizeHost

  // isDev is inferred from the host: api.frontman.sh is the only production server,
  // everything else (e.g. frontman.local:4000) is dev. Can be overridden explicitly.
  let isDev = isDev->Option.getOr(host != Hosts.apiHost->String.toLowerCase)

  let basePath = basePath->Option.getOr("frontman")
  let serverName = serverName->Option.getOr("frontman-nextjs")
  let serverVersion = serverVersion->Option.getOr(packageVersion)
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

  // Client URL can be overridden via FRONTMAN_CLIENT_URL env var for remote development
  let clientUrl = clientUrl->Option.getOr({
    let baseUrl =
      Bindings.Process.env
      ->Dict.get("FRONTMAN_CLIENT_URL")
      ->Option.getOr(
        switch isDev {
        | true => Hosts.devClientJs
        | false => Hosts.clientJs
        },
      )
    // Use URL API to properly append params (handles base URLs that already have query strings)
    let url = WebAPI.URL.make(~url=baseUrl)
    url.searchParams->WebAPI.URLSearchParams.set(~name="clientName", ~value="nextjs")
    url.searchParams->WebAPI.URLSearchParams.set(~name="host", ~value=host)
    url.href
  })

  // Assert clientUrl contains the required "host" query param that the client reads from import.meta.url
  let parsedUrl = WebAPI.URL.make(~url=clientUrl)
  switch parsedUrl.searchParams->WebAPI.URLSearchParams.has(~name="host") {
  | true => ()
  | false =>
    JsError.throwWithMessage(
      `[frontman-nextjs] clientUrl must include a "host" query parameter. Got: ${clientUrl}`,
    )
  }

  {
    isDev,
    basePath,
    serverName,
    serverVersion,
    host,
    clientUrl,
    clientCssUrl: clientCssUrl->Option.orElse(
      switch isDev {
      | true => None
      | false => Some(Hosts.clientCss)
      },
    ),
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
