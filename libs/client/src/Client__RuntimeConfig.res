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
  openrouterKeyValue: option<string>,
  anthropicKeyValue: option<string>,
  fireworksKeyValue: option<string>,
  projectRoot: option<string>,
  sourceRoot: option<string>,
}

type t = {
  framework: frameworkId,
  basePath: string,
  wpNonce: option<string>,
  openrouterKeyValue: option<string>,
  anthropicKeyValue: option<string>,
  fireworksKeyValue: option<string>,
  projectRoot: option<string>,
  sourceRoot: option<string>,
}

let normalizeOptionalString = value =>
  switch value {
  | Some("") | None => None
  | Some(text) => Some(text)
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
    wpNonce: config.wpNonce,
    openrouterKeyValue: normalizeOptionalString(config.openrouterKeyValue),
    anthropicKeyValue: normalizeOptionalString(config.anthropicKeyValue),
    fireworksKeyValue: normalizeOptionalString(config.fireworksKeyValue),
    projectRoot: config.projectRoot,
    sourceRoot: config.sourceRoot,
  }
}

let toEnvApiKeyDict = (config: t): Dict.t<string> => {
  let envApiKey = Dict.make()
  config.openrouterKeyValue->Option.forEach(key => {
    envApiKey->Dict.set("openrouterKeyValue", key)
  })
  config.anthropicKeyValue->Option.forEach(key => {
    envApiKey->Dict.set("anthropicKeyValue", key)
  })
  config.fireworksKeyValue->Option.forEach(key => {
    envApiKey->Dict.set("fireworksKeyValue", key)
  })
  envApiKey
}

// Check if an OpenRouter API key is available from the project environment
let hasOpenrouterKey = (config: t): bool => {
  config.openrouterKeyValue->Option.isSome
}

// Check if an Anthropic API key is available from the project environment
let hasAnthropicKey = (config: t): bool => {
  config.anthropicKeyValue->Option.isSome
}

// Check if a Fireworks API key is available from the project environment
let hasFireworksKey = (config: t): bool => {
  config.fireworksKeyValue->Option.isSome
}

let hasAnyProviderKey = (config: t): bool => {
  toEnvApiKeyDict(config)->Dict.valuesToArray->Array.length > 0
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
// Includes framework and forwarded provider keys so the server knows
// which framework the client is running in and can use the project's env keys
let toMeta = (config: t): JSON.t => {
  let configObj = Dict.fromArray([
    ("framework", JSON.Encode.string(frameworkIdToString(config.framework))),
    ("basePath", JSON.Encode.string(config.basePath)),
  ])
  toEnvApiKeyDict(config)->Dict.forEachWithKey((keyValue, keyName) => {
    configObj->Dict.set(keyName, JSON.Encode.string(keyValue))
  })
  JSON.Encode.object(configObj)
}
