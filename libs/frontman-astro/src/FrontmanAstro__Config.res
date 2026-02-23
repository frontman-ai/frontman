// Astro configuration for Frontman

module Bindings = FrontmanBindings
module Hosts = FrontmanFrontmanCore.FrontmanCore__Hosts

// Default host can be overridden via FRONTMAN_HOST env var for remote development
let defaultHost = switch Bindings.Process.env->Dict.get("FRONTMAN_HOST") {
| Some(host) => host
| None => Hosts.apiHost
}

type t = {
  isDev: bool,
  projectRoot: string,
  // sourceRoot: root for resolving file paths from Astro's data-astro-source-file attributes
  // In a monorepo, this is typically the monorepo root. Defaults to projectRoot.
  sourceRoot: string,
  basePath: string,
  serverName: string,
  serverVersion: string,
  host: string,
  clientUrl: string,
  clientCssUrl: option<string>,
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
  clientCssUrl?: string,
  isLightTheme?: bool,
}

// Ensure config is an object even when called with no args (frontman())
let ensureConfig: jsConfigInput => jsConfigInput = %raw(`function(c) { return c || {}; }`)

// JS-friendly function that accepts a config object
// Use this from JavaScript/TypeScript: makeConfig({ projectRoot: "..." })
let makeFromObject = (rawConfig: jsConfigInput): t => {
  let config = ensureConfig(rawConfig)
  let host = config.host->Option.getOr(defaultHost)

  // isDev is inferred from the host: the production API host is the only production server,
  // everything else (e.g. frontman.local:4000) is dev.
  let isDev = host != Hosts.apiHost

  let projectRoot =
    config.projectRoot
    ->Option.orElse(
      Bindings.Process.env
      ->Dict.get("PROJECT_ROOT")
      ->Option.orElse(Bindings.Process.env->Dict.get("PWD")),
    )
    ->Option.getOr(".")

  let sourceRoot = config.sourceRoot->Option.getOr(projectRoot)
  // Normalize basePath: strip leading/trailing slashes so URL construction
  // (e.g. `/${basePath}/`) never produces protocol-relative URLs like //frontman/
  let basePath = {
    let raw =
      config.basePath
      ->Option.getOr("frontman")
      ->String.replaceRegExp(%re("/^\/+|\/+$/g"), "")
    switch raw {
    | "" => "frontman"
    | normalized => normalized
    }
  }
  let serverName = config.serverName->Option.getOr("frontman-astro")
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
    | false => url.searchParams->WebAPI.URLSearchParams.set(~name="clientName", ~value="astro")
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
    isLightTheme,
  }
}
