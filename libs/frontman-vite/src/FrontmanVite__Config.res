// Vite configuration for Frontman

module Bindings = FrontmanBindings
module Hosts = FrontmanFrontmanCore.FrontmanCore__Hosts

// Default host can be overridden via FRONTMAN_HOST env var for development
let defaultHost = switch Bindings.Process.env->Dict.get("FRONTMAN_HOST") {
| Some(host) => host
| None => Hosts.apiHost
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
  projectRoot: string,
  // sourceRoot: root for resolving file paths
  // In a monorepo, this is typically the monorepo root. Defaults to projectRoot.
  sourceRoot: string,
  basePath: string,
  serverName: string,
  serverVersion: string,
  host: string,
  clientUrl: string,
  clientCssUrl: option<string>,
  entrypointUrl: option<string>,
  isLightTheme: bool,
}

// JS-friendly type for config input (all optional)
type jsConfigInput = {
  isDev?: bool,
  projectRoot?: string,
  sourceRoot?: string,
  basePath?: string,
  serverName?: string,
  serverVersion?: string,
  host?: string,
  clientUrl?: string,
  clientCssUrl?: string,
  entrypointUrl?: string,
  isLightTheme?: bool,
}

// JS-friendly function that accepts a config object
// Use this from JavaScript/TypeScript: makeConfig({ isDev: true, ... })
let makeFromObject = (config: jsConfigInput): t => {
  let host = config.host->Option.getOr(defaultHost)->normalizeHost

  // isDev is inferred from the host: api.frontman.sh is the only production server,
  // everything else (e.g. frontman.local:4000) is dev. Can be overridden explicitly.
  let isDev = config.isDev->Option.getOr(host != Hosts.apiHost->String.toLowerCase)

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
  let serverName = config.serverName->Option.getOr("frontman-vite")
  let serverVersion = config.serverVersion->Option.getOr("1.0.0")
  let isLightTheme = config.isLightTheme->Option.getOr(false)

  let clientUrl = {
    let baseUrl =
      config.clientUrl->Option.getOr(
        Bindings.Process.env
        ->Dict.get("FRONTMAN_CLIENT_URL")
        ->Option.getOr(
          switch isDev {
          | true => Hosts.devClientJs
          | false => Hosts.clientJs
          },
        ),
      )
    // Ensure clientUrl always has the required query params the client reads from import.meta.url
    let url = WebAPI.URL.make(~url=baseUrl)
    switch url.searchParams->WebAPI.URLSearchParams.has(~name="clientName") {
    | true => ()
    | false => url.searchParams->WebAPI.URLSearchParams.set(~name="clientName", ~value="vite")
    }
    switch url.searchParams->WebAPI.URLSearchParams.has(~name="host") {
    | true => ()
    | false => url.searchParams->WebAPI.URLSearchParams.set(~name="host", ~value=host)
    }
    url.href
  }

  {
    isDev,
    projectRoot,
    sourceRoot,
    basePath,
    serverName,
    serverVersion,
    host,
    clientUrl,
    clientCssUrl: config.clientCssUrl->Option.orElse(
      switch isDev {
      | true => None
      | false => Some(Hosts.clientCss)
      },
    ),
    entrypointUrl: config.entrypointUrl,
    isLightTheme,
  }
}
