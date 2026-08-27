let packageVersion: string = %raw(`typeof __PACKAGE_VERSION__ !== "undefined" ? __PACKAGE_VERSION__ : undefined`)
let () = if typeof(packageVersion) == #undefined {
  JsError.throwWithMessage("__PACKAGE_VERSION__ is not defined — tsup build is misconfigured")
}

module Bindings = FrontmanBindings
module Hosts = FrontmanAiFrontmanCore.FrontmanCore__Hosts

let defaultHost = switch Bindings.Process.env->Dict.get("FRONTMAN_HOST") {
| Some(host) => host
| None => Hosts.apiHost
}

@@live
type t = {
  isDev: bool,
  projectRoot: string,
  sourceRoot: string,
  basePath: string,
  serverName: string,
  serverVersion: string,
  host: string,
  clientUrl: string,
  clientCssUrl: option<string>,
  entrypointUrl: option<string>,
}

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

let ensureConfig: jsConfigInput => jsConfigInput = %raw(`function(c) { return c || {}; }`)

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
