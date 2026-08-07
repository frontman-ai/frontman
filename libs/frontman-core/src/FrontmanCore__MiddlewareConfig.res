type frameworkId = Nextjs | Vite | Astro

let frameworkIdToString = (id: frameworkId): string =>
  switch id {
  | Nextjs => "nextjs"
  | Vite => "vite"
  | Astro => "astro"
  }

@@live
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
  frameworkId: frameworkId,
  traits: array<string>,
}
