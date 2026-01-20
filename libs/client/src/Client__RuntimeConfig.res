// Runtime config injected by the framework middleware (e.g., Next.js)
// Reads from window.__frontmanRuntime

type t = {
  framework: option<string>,
  openrouterKeyValue: option<string>,
}

let read = (): t => {
  let getRuntime: unit => option<{..}> = %raw(`
    function() {
      if (typeof window === 'undefined') return null;
      return window.__frontmanRuntime || null;
    }
  `)
  let runtime = getRuntime()
  runtime->Option.mapOr(
    {framework: None, openrouterKeyValue: None},
    runtimeObj => {
      let framework: Js.Nullable.t<string> = runtimeObj["framework"]
      let openrouterKeyValue: Js.Nullable.t<string> = runtimeObj["openrouterKeyValue"]
      {
        framework: framework->Js.Nullable.toOption,
        openrouterKeyValue: openrouterKeyValue->Js.Nullable.toOption,
      }
    },
  )
}

// Check if an OpenRouter API key is available from the project environment
let hasOpenrouterKey = (config: t): bool => {
  config.openrouterKeyValue->Option.isSome
}

// Convert runtime config to metadata JSON for ACP prompt requests
// Only includes openrouterKeyValue so the server can use the project's env key
let toMetadata = (config: t): option<JSON.t> => {
  switch config.openrouterKeyValue {
  | Some(key) =>
    Some(
      JSON.Encode.object(
        Dict.fromArray([("openrouterKeyValue", JSON.Encode.string(key))]),
      ),
    )
  | None => None
  }
}
