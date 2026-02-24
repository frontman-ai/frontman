// Runtime config injected by the framework middleware (e.g., Next.js)
// Reads from window.__frontmanRuntime

@schema
type parsed = {
  framework: string,
  // UIShell always sets this, but tests and non-standard embeddings may omit it.
  basePath: option<string>,
  openrouterKeyValue: option<string>,
}

@schema
type t = {
  framework: string,
  basePath: string,
  openrouterKeyValue: option<string>,
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
    framework: config.framework,
    basePath: switch config.basePath {
    | Some("") | None => "frontman"
    | Some(bp) => bp
    },
    openrouterKeyValue: config.openrouterKeyValue,
  }
}

// Check if an OpenRouter API key is available from the project environment
let hasOpenrouterKey = (config: t): bool => {
  config.openrouterKeyValue->Option.isSome
}

// Convert runtime config to metadata JSON for ACP prompt requests
// Includes framework and openrouterKeyValue so the server knows
// which framework the client is running in and can use the project's env key
let toMetadata = (config: t): JSON.t => {
  S.reverseConvertToJsonOrThrow(config, schema)
}
