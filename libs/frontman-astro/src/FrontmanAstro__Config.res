// Astro configuration for Frontman

module Bindings = FrontmanBindings

type t = {
  projectRoot: string,
  // sourceRoot: root for resolving file paths from Astro's data-astro-source-file attributes
  // In a monorepo, this is typically the monorepo root. Defaults to projectRoot.
  sourceRoot: string,
  basePath: string,
  serverName: string,
  serverVersion: string,
  clientUrl: string,
}

// Default client URL - can be overridden
let defaultClientUrl = "http://localhost:5173/src/Main.res.mjs"

// JS-friendly type for config input
type jsConfigInput = {
  projectRoot?: string,
  sourceRoot?: string,
  basePath?: string,
  serverName?: string,
  serverVersion?: string,
  clientUrl?: string,
}

// JS-friendly function that accepts a config object
// Use this from JavaScript/TypeScript: makeConfig({ projectRoot: "..." })
let makeFromObject = (config: jsConfigInput): t => {
  let projectRoot =
    config.projectRoot
    ->Option.orElse(
      Bindings.Process.env
      ->Dict.get("PROJECT_ROOT")
      ->Option.orElse(Bindings.Process.env->Dict.get("PWD")),
    )
    ->Option.getOr(".")

  let sourceRoot = config.sourceRoot->Option.getOr(projectRoot)
  let basePath = config.basePath->Option.getOr("__frontman")
  let serverName = config.serverName->Option.getOr("frontman-astro")
  let serverVersion = config.serverVersion->Option.getOr("1.0.0")
  let clientUrl = config.clientUrl->Option.getOr(defaultClientUrl)

  {
    projectRoot,
    sourceRoot,
    basePath,
    serverName,
    serverVersion,
    clientUrl,
  }
}
