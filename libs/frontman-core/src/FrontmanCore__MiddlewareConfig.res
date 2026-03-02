// Shared middleware configuration type used by all framework adapters
//
// Each adapter has its own Config type with framework-specific fields (isDev, etc.),
// but the middleware layer only needs this subset.

type frameworkId = Nextjs | Vite | Astro

let frameworkIdToString = (id: frameworkId): string =>
  switch id {
  | Nextjs => "nextjs"
  | Vite => "vite"
  | Astro => "astro"
  }

// Map a framework ID to a human-readable display name.
// Used by the client UI to show "Framework detected: Next.js" etc.
let frameworkDisplayName = (id: frameworkId): string =>
  switch id {
  | Nextjs => "Next.js"
  | Vite => "Vite"
  | Astro => "Astro"
  }

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
  frameworkId: frameworkId,
}
