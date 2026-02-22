// Shared middleware configuration type used by all framework adapters
//
// Each adapter has its own Config type with framework-specific fields (isDev, etc.),
// but the middleware layer only needs this subset.

type t = {
  projectRoot: string,
  sourceRoot: string,
  basePath: string,
  serverName: string,
  serverVersion: string,
  clientUrl: string,
  clientCssUrl: option<string>,
  entrypointUrl: option<string>,
  isLightTheme: bool,
  frameworkLabel: string,
}
