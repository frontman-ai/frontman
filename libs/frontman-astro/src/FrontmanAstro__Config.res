// Astro configuration for Frontman

// Injected at build time by tsup define — crash if missing so we catch broken builds immediately.
// Must use %raw with typeof guard: @val external won't work because __PACKAGE_VERSION__ is a
// build-time constant replaced by tsup, not a runtime global.
let packageVersion: string = %raw(`typeof __PACKAGE_VERSION__ !== "undefined" ? __PACKAGE_VERSION__ : undefined`)
let () = if typeof(packageVersion) == #undefined {
  JsError.throwWithMessage("__PACKAGE_VERSION__ is not defined — tsup build is misconfigured")
}

module Bindings = FrontmanBindings
module Hosts = FrontmanAiFrontmanCore.FrontmanCore__Hosts

// Default host can be overridden via FRONTMAN_HOST env var for remote development
let defaultHost = switch Bindings.Process.env->Dict.get("FRONTMAN_HOST") {
| Some(host) => host
| None => Hosts.apiHost
}

@@live
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
  entrypointUrl: option<string>,
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
  entrypointUrl?: string,
}

// Ensure config is an object even when called with no args (frontman())
let ensureConfig: jsConfigInput => jsConfigInput = %raw(`function(c) { return c || {}; }`)

// JS-friendly function that accepts a config object
// Use this from JavaScript/TypeScript: makeConfig({ projectRoot: "..." })
let makeFromObject = (rawConfig: jsConfigInput): t => {
  let config = ensureConfig(rawConfig)
  let host = config.host->Option.getOr(defaultHost)

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
      ->String.replaceRegExp(/^\/+|\/+$/g, "")
    switch raw {
    | "" => "frontman"
    | normalized => normalized
    }
  }
  let serverName = config.serverName->Option.getOr("frontman-astro")
  let serverVersion = config.serverVersion->Option.getOr(packageVersion)

  let clientUrl = Hosts.clientUrl(
    ~baseUrl=config.clientUrl,
    ~clientName="astro",
    ~host,
    ~isDev,
    ~sentryDsn=Bindings.Process.envString("SENTRY_DSN"),
    ~preserveExisting=true,
  )

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
  }
}
