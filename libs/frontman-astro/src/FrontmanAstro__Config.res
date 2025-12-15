// Astro configuration for Frontman

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

// For JS/TS interop, use positional args
// projectRoot: where the app lives (for finding pages)
// sourceRoot: root for file paths (monorepo root in monorepo setups, same as projectRoot otherwise)
let make = (
  projectRoot: string,
  sourceRoot: string,
  basePath: string,
  serverName: string,
  serverVersion: string,
): t => {
  projectRoot,
  sourceRoot,
  basePath,
  serverName,
  serverVersion,
  clientUrl: defaultClientUrl,
}
