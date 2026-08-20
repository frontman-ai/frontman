let packageVersion: string = %raw(`typeof __PACKAGE_VERSION__ !== "undefined" ? __PACKAGE_VERSION__ : undefined`)
let () = if typeof(packageVersion) == #undefined {
  JsError.throwWithMessage("__PACKAGE_VERSION__ is not defined — tsup build is misconfigured")
}

module Bindings = FrontmanBindings
module Hosts = FrontmanAiFrontmanCore.FrontmanCore__Hosts
module AdapterSecurity = FrontmanAiFrontmanCore.FrontmanCore__MCP__AdapterSecurity
module HttpSecurity = FrontmanAiFrontmanCore.FrontmanCore__MCP__HttpSecurity
module SourceLocationEndpoint = FrontmanAiFrontmanCore.FrontmanCore__SourceLocationEndpoint

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
  mcpBrowserToken: option<string>,
  mcpSecurity: option<HttpSecurity.policy>,
  sourceLocationSecurity: option<HttpSecurity.policy>,
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
  mcpBrowserToken?: string,
  mcp?: AdapterSecurity.input,
  sourceLocation?: SourceLocationEndpoint.input,
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
    | false => url.searchParams->WebAPI.URLSearchParams.set(~name="clientName", ~value="astro")
    }
    switch url.searchParams->WebAPI.URLSearchParams.has(~name="host") {
    | true => ()
    | false => url.searchParams->WebAPI.URLSearchParams.set(~name="host", ~value=host)
    }
    url.href
  }

  let mcpSecurity = config.mcp->Option.map(AdapterSecurity.make)

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
    mcpBrowserToken: config.mcpBrowserToken,
    mcpSecurity,
    sourceLocationSecurity: config.sourceLocation
    ->Option.map(SourceLocationEndpoint.makeSecurity)
    ->Option.orElse(mcpSecurity),
  }
}
