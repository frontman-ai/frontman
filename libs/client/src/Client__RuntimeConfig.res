// Runtime config injected by the framework middleware (e.g., Next.js)
// Reads from window.__frontmanRuntime

type t = {
  framework: string,
  openrouterKeyValue: option<string>,
}

let read = (): t => {
  let getRuntime: unit => Nullable.t<{..}> = %raw(`
    function() {
      if (typeof window === 'undefined') return null;
      return window.__frontmanRuntime || null;
    }
  `)
  let runtimeObj = getRuntime()->Nullable.toOption->Option.getOrThrow
  let framework: Js.Nullable.t<string> = runtimeObj["framework"]
  let openrouterKeyValue: Js.Nullable.t<string> = runtimeObj["openrouterKeyValue"]
  {
    framework: framework->Js.Nullable.toOption->Option.getOrThrow,
    openrouterKeyValue: openrouterKeyValue->Js.Nullable.toOption,
  }
}

// Check if an OpenRouter API key is available from the project environment
let hasOpenrouterKey = (config: t): bool => {
  config.openrouterKeyValue->Option.isSome
}

@schema
type clientMetadata = {
  framework: string,
  openrouterKeyValue: option<string>,
}

// Convert runtime config to metadata JSON for ACP prompt requests
// Includes framework and openrouterKeyValue so the server knows
// which framework the client is running in and can use the project's env key
let toMetadata = (config: t): JSON.t => {
  let metadata: clientMetadata = {
    framework: config.framework,
    openrouterKeyValue: config.openrouterKeyValue,
  }
  S.reverseConvertToJsonOrThrow(metadata, clientMetadataSchema)
}
