module Bindings = FrontmanBindings.Astro
module Config = FrontmanAstro__Config
module Middleware = FrontmanAstro__Middleware
module ViteAdapter = FrontmanAstro__ViteAdapter

@module("node:module")
external createRequire: string => {"resolve": string => string} = "createRequire"
@val @scope(("import", "meta")) external importMetaUrl2: string = "url"

@schema
type packageJson = {version: string}

let getAstroVersion = () => {
  let require = createRequire(importMetaUrl2)
  let pkgPath = require["resolve"]("astro/package.json")
  let raw = FrontmanBindings.Fs.readFileSync(pkgPath)
  let pkg = raw->S.decodeOrThrow(~from=S.jsonString, ~to=packageJsonSchema)
  pkg.version
}

let parseMajorVersion = (version: string) =>
  version
  ->String.split(".")
  ->Array.get(0)
  ->Option.flatMap(s => Int.fromString(s))
  ->Option.getOrThrow(~message=`[Frontman] Failed to parse Astro major version from "${version}"`)

let getAstroMajorVersion = () => getAstroVersion()->parseMajorVersion

@module("./vite-plugin-props-injection.mjs")
external frontmanPropsInjectionPlugin: unit => Bindings.vitePlugin = "frontmanPropsInjectionPlugin"

@module("./vite-plugin-source-annotations.mjs")
external frontmanSourceAnnotationsPlugin: unit => Bindings.vitePlugin =
  "frontmanSourceAnnotationsPlugin"

@module("./annotation-capture.mjs")
external annotationCaptureScript: string = "annotationCaptureScript"

@module("./astro-route-rewrite.mjs")
external prependFrontmanRouteRewrite: (
  Bindings.viteDevServer,
  string,
  Bindings.trailingSlash,
  bool,
) => unit = "prependFrontmanRouteRewrite"

@module("./markdown-content-file.mjs")
external registerContentFilePlugin: (
  option<Bindings.markdownProcessor>,
  {..},
) => [#legacy | #satteri | #unified | #unsupported] = "registerContentFilePlugin"

@module("./rehype-content-file.mjs")
external rehypeContentFile: {..} => Bindings.rehypePlugin = "rehypeContentFile"
external asRehypePlugin: (({..} => Bindings.rehypePlugin, {..})) => Bindings.rehypePlugin =
  "%identity"

let icon = `<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="90 70 230 270" fill="none"><path d="M145.925 316.925C136.175 316.925 129.242 315.517 125.125 312.7C121.008 309.667 118.517 305.875 117.65 301.325C116.783 296.558 116.35 291.792 116.35 287.025V119C116.35 107.733 118.517 100.042 122.85 95.925C127.4 91.5917 135.417 89.425 146.9 89.425H265.85C270.833 89.425 275.492 89.8583 279.825 90.725C284.375 91.5917 288.058 94.0833 290.875 98.2C293.692 102.317 295.1 109.358 295.1 119.325C295.1 129.075 293.583 136.008 290.55 140.125C287.733 144.242 284.05 146.733 279.5 147.6C274.95 148.467 270.183 148.9 265.2 148.9H175.825V177.825H235.625C240.608 177.825 245.05 178.258 248.95 179.125C253.067 179.775 256.208 181.942 258.375 185.625C260.758 189.092 261.95 195.158 261.95 203.825C261.95 212.058 260.758 217.908 258.375 221.375C255.992 224.842 252.742 226.9 248.625 227.55C244.725 228.2 240.283 228.525 235.3 228.525H175.825V287.35C175.825 292.117 175.392 296.775 174.525 301.325C173.658 305.875 171.167 309.667 167.05 312.7C162.933 315.517 155.892 316.925 145.925 316.925Z" fill="currentColor"/></svg>`

@val @scope(("import", "meta"))
external importMetaUrl: string = "url"

let getToolbarAppPath = () => {
  let url = WebAPI.URL.make(~url="./toolbar.js", ~base=importMetaUrl)
  url.pathname
}

let make = (configInput: Config.jsConfigInput): Bindings.astroIntegration => {
  let config = Config.makeFromObject(configInput)

  let astroMajorVersion = getAstroMajorVersion()
  let useResolvedRoutes = astroMajorVersion >= 5
  let resolvedRoutes = ref([])
  let trailingSlash = ref(#ignore)

  let routeDiscovery: Middleware.routeDiscovery = switch useResolvedRoutes {
  | true => ResolvedRoutes({getRoutes: () => resolvedRoutes.contents})
  | false => Filesystem
  }

  {
    name: "frontman",
    hooks: {
      routesResolved: ?switch useResolvedRoutes {
      | true => Some(({routes}) => resolvedRoutes := routes)
      | false => None
      },
      configSetup: ?Some(
        ctx => {
          if ctx.command == #dev {
            if astroMajorVersion < 7 && !ctx.config.devToolbar.enabled {
              Console.warn(
                "[Frontman] Astro devToolbar is disabled — element source detection will be limited. " ++ "Set `devToolbar: { enabled: true }` in your astro.config to enable full component source resolution.",
              )
            }

            let middlewarePlugin = Bindings.makeVitePlugin({
              name: "frontman-middleware",
              enforce: "pre",
              configureServer: ?Some(
                server => {
                  let loadContentApi = async () =>
                    await server->Bindings.ssrLoadModule("astro:content")
                  let middleware = Middleware.make(config, ~routeDiscovery, ~loadContentApi)
                  let mcp: option<
                    FrontmanAiFrontmanCore.FrontmanCore__MCP__Endpoint.config,
                  > = config.mcpSecurity->Option.map(security => {
                    FrontmanAiFrontmanCore.FrontmanCore__MCP__Endpoint.security,
                    registry: middleware.registry,
                    projectRoot: config.projectRoot,
                    sourceRoot: config.sourceRoot,
                    serverName: config.serverName,
                    serverVersion: config.serverVersion,
                    allowedPreflightHeaders: [],
                  })
                  let connectMiddleware = ViteAdapter.adaptToConnect(
                    middleware.middleware,
                    ~basePath=config.basePath,
                    ~mcp,
                  )

                  server.middlewares->Bindings.use(connectMiddleware)
                },
              ),
            })

            let vitePlugins = switch astroMajorVersion >= 7 {
            | true => [
                middlewarePlugin,
                frontmanSourceAnnotationsPlugin(),
                frontmanPropsInjectionPlugin(),
              ]
            | false => [middlewarePlugin, frontmanPropsInjectionPlugin()]
            }
            ctx.updateConfig({
              vite: ?Some({
                plugins: ?Some(vitePlugins),
                server: ?switch config.mcpSecurity {
                | Some(_) => Some({cors: ?Some(false)})
                | None => None
                },
              }),
            })

            switch registerContentFilePlugin(
              ctx.config.markdown.processor,
              {"projectRoot": config.sourceRoot},
            ) {
            | #satteri | #unified => ()
            | #legacy =>
              ctx.updateConfig({
                markdown: ?Some({
                  rehypePlugins: ?Some([
                    asRehypePlugin((rehypeContentFile, {"projectRoot": config.sourceRoot})),
                  ]),
                }),
              })
            | #unsupported => Console.warn("[Frontman] Unsupported Markdown processor")
            }

            ctx.addDevToolbarApp({
              id: "frontman:toolbar",
              name: "Frontman",
              icon,
              entrypoint: getToolbarAppPath(),
            })

            let safeBasePath = JSON.stringifyAny(config.basePath)->Option.getOr(`"frontman"`)
            let basePathMeta = `{
              const meta = document.createElement('meta');
              meta.name = 'frontman-base-path';
              meta.content = ${safeBasePath};
              document.head.appendChild(meta);
            }`
            ctx.injectScript("head-inline", basePathMeta ++ "\n" ++ annotationCaptureScript)
          }
        },
      ),
      configDone: ?Some(({config}) => trailingSlash := config.trailingSlash),
      serverSetup: ?Some(
        ({server, toolbar}) => {
          FrontmanAiFrontmanCore.FrontmanCore__LogCapture.initialize()

          prependFrontmanRouteRewrite(
            server,
            config.basePath,
            trailingSlash.contents,
            config.mcpSecurity->Option.isSome,
          )

          toolbar->Bindings.toolbarOnAppInitialized("frontman:toolbar", () => {
            Console.log("[Frontman] Dev toolbar app initialized")
          })
        },
      ),
    },
  }
}
