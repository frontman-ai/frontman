type frameworkId = Nextjs | Vite | Astro | Wordpress

type previewBridge = PageContextV1

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
  wordpressSettingsUrl: option<string>,
  wordpressLoginUrl: option<string>,
  projectRoot: option<string>,
  traits: option<array<string>>,
}

@@live
type t = {
  framework: frameworkId,
  previewBridge: option<previewBridge>,
  basePath: string,
  relayBaseUrl: option<string>,
  wpNonce: option<string>,
  wordpressPluginsUrl: option<string>,
  wordpressSettingsUrl: option<string>,
  wordpressLoginUrl: option<string>,
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
  let framework = frameworkIdFromString(config.framework)
  let (previewBridge, wordpressLoginUrl, wordpressSettingsUrl) = switch framework {
  | Wordpress =>
    let element =
      WebAPI.DomGlobal.document
      ->WebAPI.Document.querySelector("#frontman-runtime-config")
      ->Null.toOption
    let attribute = name =>
      element->Option.flatMap(element => element->WebAPI.Element.getAttribute(name)->Null.toOption)
    let url = (explicit, name) =>
      switch explicit {
      | Some(_) => explicit
      | None => attribute(name)->Option.filter(value => value->String.trim != "")
      }
    (
      switch attribute("data-preview-bridge") {
      | Some("page-context-v1") => Some(PageContextV1)
      | Some(_) | None => None
      },
      url(config.wordpressLoginUrl, "data-wordpress-login-url"),
      url(config.wordpressSettingsUrl, "data-wordpress-settings-url"),
    )
  | Nextjs | Vite | Astro => (None, config.wordpressLoginUrl, None)
  }
  {
    framework,
    previewBridge,
    basePath: switch config.basePath {
    | Some("") | None => "frontman"
    | Some(bp) => bp
    },
    relayBaseUrl: config.relayBaseUrl,
    wpNonce: config.wpNonce,
    wordpressPluginsUrl: config.wordpressPluginsUrl,
    wordpressSettingsUrl,
    wordpressLoginUrl,
    projectRoot: config.projectRoot,
    traits: config.traits,
  }
}

let frameworkUpdateTarget = (id: frameworkId): Client__State__Types.updateTarget =>
  switch id {
  | Nextjs => NpmPackage("@frontman-ai/nextjs")
  | Vite => NpmPackage("@frontman-ai/vite")
  | Astro => NpmPackage("@frontman-ai/astro")
  | Wordpress => WordPressPlugin
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
