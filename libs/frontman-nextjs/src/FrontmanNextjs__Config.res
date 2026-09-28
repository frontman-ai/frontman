let packageVersion: string = %raw(`typeof __PACKAGE_VERSION__ !== "undefined" ? __PACKAGE_VERSION__ : undefined`)
let () = if typeof(packageVersion) == #undefined {
  JsError.throwWithMessage("__PACKAGE_VERSION__ is not defined — tsup build is misconfigured")
}

module Bindings = FrontmanBindings
module Hosts = FrontmanAiFrontmanCore.FrontmanCore__Hosts

let defaultHost = switch Bindings.Process.env->Dict.get("FRONTMAN_HOST") {
| Some(host) if host != "" => host
| _ => Hosts.apiHost
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
  isDev: bool,
  basePath: string,
  serverName: string,
  serverVersion: string,
  host: string,
  clientUrl: string,
  clientCssUrl: option<string>,
  entrypointUrl: option<string>,
  projectRoot: string,
  sourceRoot: string,
}

@@live
let make = (
  ~isDev=None,
  ~basePath=None,
  ~serverName=None,
  ~serverVersion=None,
  ~host=None,
  ~clientUrl=None,
  ~clientCssUrl=None,
  ~entrypointUrl=None,
  ~projectRoot=None,
  ~sourceRoot=None,
) => {
  let host = host->Option.getOr(defaultHost)->normalizeHost

  let isDev = isDev->Option.getOr(host != Hosts.apiHost->String.toLowerCase)

  let basePath = basePath->Option.getOr("frontman")
  let serverName = serverName->Option.getOr("frontman-nextjs")
  let serverVersion = serverVersion->Option.getOr(packageVersion)

  let projectRoot =
    projectRoot
    ->Option.orElse(
      Bindings.Process.env
      ->Dict.get("PROJECT_ROOT")
      ->Option.orElse(Bindings.Process.env->Dict.get("PWD")),
    )
    ->Option.getOr(".")

  let sourceRoot = sourceRoot->Option.getOr(projectRoot)

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
    let url = WebAPI.URL.make(~url=baseUrl)
    url.searchParams->WebAPI.URLSearchParams.set(~name="clientName", ~value="nextjs")
    url.searchParams->WebAPI.URLSearchParams.set(~name="host", ~value=host)
    url.href
  })

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
    projectRoot,
    sourceRoot,
  }
}

type jsConfigInput = {
  isDev?: bool,
  basePath?: string,
  serverName?: string,
  serverVersion?: string,
  host?: string,
  clientUrl?: string,
  clientCssUrl?: string,
  entrypointUrl?: string,
  projectRoot?: string,
  sourceRoot?: string,
}

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
    ~projectRoot=config.projectRoot,
    ~sourceRoot=config.sourceRoot,
  )
