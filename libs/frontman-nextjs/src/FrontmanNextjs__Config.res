module Bindings = AskTheLlmBindings

type t = {
  isDev: bool,
  basePath: string,
  serverName: string,
  serverVersion: string,
  clientUrl: string,
  clientCssUrl: option<string>,
  entrypointUrl: option<string>,
  isLightTheme: bool,
  projectRoot: string,
}

let make = (
  ~isDev=None,
  ~basePath=None,
  ~serverName=None,
  ~serverVersion=None,
  ~clientUrl=None,
  ~clientCssUrl=None,
  ~entrypointUrl=None,
  ~isLightTheme=None,
  ~projectRoot=None,
) => {
  let isDev =
    isDev->Option.getOr(
      Bindings.Process.env->Dict.get("NODE_ENV")->Option.getOr("production") == "development",
    )
  let basePath = basePath->Option.getOr("__frontman")
  let serverName = serverName->Option.getOr("frontman-nextjs")
  let serverVersion = serverVersion->Option.getOr("1.0.0")
  let isLightTheme = isLightTheme->Option.getOr(false)

  let projectRoot =
    projectRoot
    ->Option.orElse(
      Bindings.Process.env
      ->Dict.get("PROJECT_ROOT")
      ->Option.orElse(Bindings.Process.env->Dict.get("PWD")),
    )
    ->Option.getOr(".")

  let clientUrl = clientUrl->Option.getOr(
    switch isDev {
    | true => "http://localhost:5173/src/Main.res.mjs?clientName=nextjs"
    | false => "https://ask-the-llm.vercel.app/frontman.es.js?clientName=nextjs"
    },
  )

  {
    isDev,
    basePath,
    serverName,
    serverVersion,
    clientUrl,
    clientCssUrl,
    entrypointUrl,
    isLightTheme,
    projectRoot,
  }
}
