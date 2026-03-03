// Runtime config injected by the framework middleware (e.g., Next.js)
// Reads from window.__frontmanRuntime

type frameworkId = Nextjs | Vite | Astro

let frameworkIdFromString = (s: string): frameworkId =>
  switch s {
  | "nextjs" => Nextjs
  | "vite" => Vite
  | "astro" => Astro
  | _ => JsError.throwWithMessage(`Unknown framework ID: "${s}"`)
  }

let frameworkIdToString = (id: frameworkId): string =>
  switch id {
  | Nextjs => "nextjs"
  | Vite => "vite"
  | Astro => "astro"
  }

// Map a framework ID to a human-readable display name.
// The wire format uses normalized IDs ("nextjs", "vite", "astro") but the
// UI should display user-friendly names ("Next.js", "Vite", "Astro").
let frameworkDisplayName = (id: frameworkId): string =>
  switch id {
  | Nextjs => "Next.js"
  | Vite => "Vite"
  | Astro => "Astro"
  }

@schema
type parsed = {
  framework: string,
  // UIShell always sets this, but tests and non-standard embeddings may omit it.
  basePath: option<string>,
  openrouterKeyValue: option<string>,
  projectRoot: option<string>,
  sourceRoot: option<string>,
}

type t = {
  framework: frameworkId,
  basePath: string,
  openrouterKeyValue: option<string>,
  projectRoot: option<string>,
  sourceRoot: option<string>,
}

let read = (): t => {
  let getRuntime: unit => Nullable.t<JSON.t> = %raw(`
    function() {
      if (typeof window === 'undefined') return null;
      return window.__frontmanRuntime || null;
    }
  `)
  let json = getRuntime()->Nullable.toOption->Option.getOrThrow
  let config = S.parseOrThrow(json, parsedSchema)
  {
    framework: frameworkIdFromString(config.framework),
    basePath: switch config.basePath {
    | Some("") | None => "frontman"
    | Some(bp) => bp
    },
    openrouterKeyValue: config.openrouterKeyValue,
    projectRoot: config.projectRoot,
    sourceRoot: config.sourceRoot,
  }
}

// Check if an OpenRouter API key is available from the project environment
let hasOpenrouterKey = (config: t): bool => {
  config.openrouterKeyValue->Option.isSome
}

// Map framework ID to the npm package name for update checks
let frameworkToNpmPackage = (id: frameworkId): string =>
  switch id {
  | Nextjs => "@frontman-ai/nextjs"
  | Vite => "@frontman-ai/vite"
  | Astro => "@frontman-ai/astro"
  }

// Convert runtime config to metadata JSON for ACP prompt requests
// Includes framework and openrouterKeyValue so the server knows
// which framework the client is running in and can use the project's env key
let toMetadata = (config: t): JSON.t => {
  let configObj = Dict.fromArray([
    ("framework", JSON.Encode.string(frameworkIdToString(config.framework))),
    ("basePath", JSON.Encode.string(config.basePath)),
  ])
  config.openrouterKeyValue->Option.forEach(key => {
    configObj->Dict.set("openrouterKeyValue", JSON.Encode.string(key))
  })
  JSON.Encode.object(configObj)
}
