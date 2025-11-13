module Bindings = AskTheLlmBindings
type t = {
  isDev: bool,
  basePath: string,
  clientJs: string,
  theme: string,
  projectRoot: string,
}

let make = (~isDev=None, ~basePath=None) => {
  let isDev =
    isDev->Option.getOr(
      Bindings.Process.env->Dict.get("NODE_ENV")->Option.getOr("production") == "development",
    )
  let basePath = basePath->Option.getOr("ask-the-llm")

  let projectRoot =
    Bindings.Process.env
    ->Dict.get("PROJECT_ROOT")
    ->Option.orElse(Bindings.Process.env->Dict.get("PWD"))
    ->Option.getOr(".")
  let clientJs = switch isDev {
  | true => "http://localhost:5173/src/Main.res.mjs"
  | false => "https://ask-the-llm.vercel.app/ask-the-llm.es.js"
  }
  {
    isDev,
    clientJs,
    theme: "dark",
    basePath,
    projectRoot,
  }
}
