// Runtime config injected by the framework middleware (e.g., Next.js)
// Reads from window.__frontmanRuntime

type frameworkId = Nextjs | Vite | Astro | Wordpress

type updateTarget =
  | NpmPackage(string)
  | WordPressPlugin

let frameworkIdFromString = (s: string): frameworkId =>
  switch s {
  | "nextjs" => Nextjs
  | "vite" => Vite
  | "astro" => Astro
  | "wordpress" => Wordpress
  | _ => JsError.throwWithMessage(`Unknown framework ID: "${s}"`)
  }

let frameworkIdToString = (id: frameworkId): string =>
  switch id {
  | Nextjs => "nextjs"
  | Vite => "vite"
  | Astro => "astro"
  | Wordpress => "wordpress"
  }

// Map a framework ID to a human-readable display name.
// The wire format uses normalized IDs ("nextjs", "vite", "astro") but the
// UI should display user-friendly names ("Next.js", "Vite", "Astro").
let frameworkDisplayName = (id: frameworkId): string =>
  switch id {
  | Nextjs => "Next.js"
  | Vite => "Vite"
  | Astro => "Astro"
  | Wordpress => "WordPress"
  }

@schema
type parsed = {
  framework: string,
  // UIShell always sets this, but tests and non-standard embeddings may omit it.
  basePath: option<string>,
  // WordPress injects a nonce for authenticated same-origin POSTs to /frontman/*.
  wpNonce: option<string>,
  projectRoot: option<string>,
  traits: option<array<string>>,
}

@@live
type t = {
  framework: frameworkId,
  basePath: string,
  wpNonce: option<string>,
  projectRoot: option<string>,
  traits: option<array<string>>,
}

let read = (): t => {
  let getRuntime: unit => Nullable.t<JSON.t> = %raw(`
    function() {
      if (typeof window === 'undefined') return null;
      return window.__frontmanRuntime || null;
    }
  `)
  let json = getRuntime()->Nullable.toOption->Option.getOrThrow
  let config = S.parseOrThrow(json, ~to=parsedSchema)
  {
    framework: frameworkIdFromString(config.framework),
    basePath: switch config.basePath {
    | Some("") | None => "frontman"
    | Some(bp) => bp
    },
    wpNonce: config.wpNonce,
    projectRoot: config.projectRoot,
    traits: config.traits,
  }
}

// Model update checks explicitly so WordPress doesn't silently pretend to have
// an npm package.
let frameworkUpdateTarget = (id: frameworkId): updateTarget =>
  switch id {
  | Nextjs => NpmPackage("@frontman-ai/nextjs")
  | Vite => NpmPackage("@frontman-ai/vite")
  | Astro => NpmPackage("@frontman-ai/astro")
  | Wordpress => WordPressPlugin
  }

// Convert runtime config to _meta JSON for ACP requests
// Includes framework metadata used by the server.
let toMeta = (config: t): JSON.t => {
  let configObj = Dict.fromArray([
    ("framework", JSON.Encode.string(frameworkIdToString(config.framework))),
  ])
  config.traits->Option.forEach(traits => {
    configObj->Dict.set("traits", traits->Array.map(JSON.Encode.string)->JSON.Encode.array)
  })
  JSON.Encode.object(configObj)
}
