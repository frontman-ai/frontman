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

@@live
type t = {
  @live
  isDev: bool,
  projectRoot: string,
  sourceRoot: string,
  basePath: string,
  serverName: string,
  serverVersion: string,
  @live
  host: string,
  clientUrl: string,
  clientCssUrl: option<string>,
  entrypointUrl: option<string>,
}

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
}

let makeFromObject = (config: jsConfigInput): t => {
  let host = config.host->Option.getOr(defaultHost)->normalizeHost

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
  let serverVersion = config.serverVersion->Option.getOr(packageVersion)

  let clientUrl = {
    let baseUrl = config.clientUrl->Option.getOr(
      Bindings.Process.env
      ->Dict.get("FRONTMAN_CLIENT_URL")
      ->Option.getOr(
        switch isDev {
        | true => Hosts.devClientJs
        | false => Hosts.clientJs
        },
      ),
    )
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
  }
}
