type frameworkId = Nextjs | Vite | Astro | Wordpress

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

let frameworkDisplayName = (id: frameworkId): string =>
  switch id {
  | Nextjs => "Next.js"
  | Vite => "Vite"
  | Astro => "Astro"
  | Wordpress => "WordPress"
  }

let supportsFileChanges = (id: frameworkId): bool =>
  switch id {
  | Nextjs | Astro | Vite => true
  | Wordpress => false
  }

@schema
type parsed = {
  framework: string,
  basePath: option<string>,
  relayBaseUrl: option<string>,
  wpNonce: option<string>,
  wordpressPluginsUrl: option<string>,
  projectRoot: option<string>,
  traits: option<array<string>>,
}

@@live
type t = {
  framework: frameworkId,
  basePath: string,
  relayBaseUrl: option<string>,
  wpNonce: option<string>,
  wordpressPluginsUrl: option<string>,
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
    relayBaseUrl: config.relayBaseUrl,
    wpNonce: config.wpNonce,
    wordpressPluginsUrl: config.wordpressPluginsUrl,
    projectRoot: config.projectRoot,
    traits: config.traits,
  }
}

let frameworkUpdateTarget = (id: frameworkId): Client__State__Types.updateTarget =>
  switch id {
  | Nextjs => NpmPackage("@frontman-ai/nextjs")
  | Vite => NpmPackage("@frontman-ai/vite")
  | Astro => NpmPackage("@frontman-ai/astro")
  | Wordpress => WordPressPlugin("frontman-agentic-ai-editor")
  }

let toMeta = (config: t): JSON.t => {
  let configObj = Dict.fromArray([
    ("framework", JSON.Encode.string(frameworkIdToString(config.framework))),
  ])
  config.traits->Option.forEach(traits => {
    configObj->Dict.set("traits", traits->Array.map(JSON.Encode.string)->JSON.Encode.array)
  })
  JSON.Encode.object(configObj)
}
