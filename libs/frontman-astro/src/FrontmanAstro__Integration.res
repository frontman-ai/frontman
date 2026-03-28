// Frontman Astro Integration
//
// A proper Astro integration that handles everything automatically:
// - Dev toolbar app registration (astro:config:setup)
// - Annotation capture script injection via injectScript "head-inline" (astro:config:setup)
// - Frontman API routes via Vite server middleware (astro:server:setup)
//
// Users only need one line in astro.config.mjs:
//   integrations: [frontman({ projectRoot: import.meta.dirname })]

module Bindings = FrontmanBindings.Astro
module Config = FrontmanAstro__Config
module Middleware = FrontmanAstro__Middleware
module ViteAdapter = FrontmanAstro__ViteAdapter

@module("node:module") external createRequire: string => {"resolve": string => string} = "createRequire"
@val @scope(("import", "meta")) external importMetaUrl2: string = "url"

@schema
type packageJson = {version: string}

let getAstroVersion = () => {
  let require = createRequire(importMetaUrl2)
  let pkgPath = require["resolve"]("astro/package.json")
  let raw = FrontmanBindings.Fs.readFileSync(pkgPath)
  S.parseJsonStringOrThrow(raw, packageJsonSchema).version
}

let parseMajorVersion = (version: string) =>
  version
  ->String.split(".")
  ->Array.get(0)
  ->Option.flatMap(s => Int.fromString(s))
  ->Option.getOrThrow(
    ~message=`[Frontman] Failed to parse Astro major version from "${version}"`,
  )

let getAstroMajorVersion = () => getAstroVersion()->parseMajorVersion

// Vite plugin that wraps Astro's renderComponent to inject component props
// as HTML comments. Imported as raw JS since it transforms Vite module internals.
@module("./vite-plugin-props-injection.mjs")
external frontmanPropsInjectionPlugin: unit => Bindings.vitePlugin = "frontmanPropsInjectionPlugin"

// Browser-side annotation capture script (exported as a string for injectScript)
@module("./annotation-capture.mjs")
external annotationCaptureScript: string = "annotationCaptureScript"

// Rehype plugin that injects __frontman_content_file__ comments into markdown output.
// This lets the annotation capture script resolve the source .md file for
// elements rendered from markdown (which lack data-astro-source-file attributes).
//
// Registered as [attacher, options] tuple — unified calls attacher(options) to get the transformer.
// A ReScript tuple (fn, opts) compiles to a JS array [fn, opts], which matches
// the format Astro's markdown processor expects for rehype plugin entries.
@module("./rehype-content-file.mjs")
external rehypeContentFile: {..} => Bindings.rehypePlugin = "rehypeContentFile"
external asRehypePlugin: (({..} => Bindings.rehypePlugin, {..})) => Bindings.rehypePlugin = "%identity"

// SVG icon for the toolbar — Frontman "F" glyph from favicon.svg (no background)
// Uses currentColor so it adapts to Astro's toolbar theming.
let icon = `<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="90 70 230 270" fill="none"><path d="M145.925 316.925C136.175 316.925 129.242 315.517 125.125 312.7C121.008 309.667 118.517 305.875 117.65 301.325C116.783 296.558 116.35 291.792 116.35 287.025V119C116.35 107.733 118.517 100.042 122.85 95.925C127.4 91.5917 135.417 89.425 146.9 89.425H265.85C270.833 89.425 275.492 89.8583 279.825 90.725C284.375 91.5917 288.058 94.0833 290.875 98.2C293.692 102.317 295.1 109.358 295.1 119.325C295.1 129.075 293.583 136.008 290.55 140.125C287.733 144.242 284.05 146.733 279.5 147.6C274.95 148.467 270.183 148.9 265.2 148.9H175.825V177.825H235.625C240.608 177.825 245.05 178.258 248.95 179.125C253.067 179.775 256.208 181.942 258.375 185.625C260.758 189.092 261.95 195.158 261.95 203.825C261.95 212.058 260.758 217.908 258.375 221.375C255.992 224.842 252.742 226.9 248.625 227.55C244.725 228.2 240.283 228.525 235.3 228.525H175.825V287.35C175.825 292.117 175.392 296.775 174.525 301.325C173.658 305.875 171.167 309.667 167.05 312.7C162.933 315.517 155.892 316.925 145.925 316.925Z" fill="currentColor"/></svg>`

// Get the path to the toolbar app entrypoint
// Uses import.meta.url to resolve relative to this file
@val @scope(("import", "meta"))
external importMetaUrl: string = "url"

let getToolbarAppPath = () => {
  let url = WebAPI.URL.make(~url="./toolbar.js", ~base=importMetaUrl)
  url.pathname
}

// Create the Astro integration
// Accepts the same config options as makeConfig (all optional)
let make = (configInput: Config.jsConfigInput): Bindings.astroIntegration => {
  // Build config once, reuse across hooks
  let config = Config.makeFromObject(configInput)

  // Detect Astro version to choose route discovery strategy.
  // v5+ provides astro:routes:resolved hook with authoritative route data.
  // v4 falls back to filesystem scanning of src/pages/.
  let useResolvedRoutes = getAstroMajorVersion() >= 5
  let resolvedRoutes = ref([])

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
          // Only activate in dev mode
          if ctx.command == #dev {
            // Warn if devToolbar is disabled — Astro only emits source annotations
            // (data-astro-source-file/loc) when devToolbar.enabled is true.
            // Without annotations, Frontman falls back to CSS selector detection
            // and cannot resolve the source component file/line for selected elements.
            if !ctx.config.devToolbar.enabled {
              Console.warn(
                "[Frontman] Astro devToolbar is disabled — element source detection will be limited. " ++ "Set `devToolbar: { enabled: true }` in your astro.config to enable full component source resolution.",
              )
            }

            // Create our Web API middleware and adapt it to Vite's Connect middleware.
            // Registered as a Vite plugin via configureServer so it runs BEFORE Astro's
            // own page routing. If registered via astro:server:setup instead, Astro's
            // catch-all dynamic routes (e.g. blog/[...id]) would match suffix URLs
            // like /blog/frontman and return 404 before our middleware gets the request.
            let webMiddleware = Middleware.createMiddleware(config, ~routeDiscovery)
            let connectMiddleware = ViteAdapter.adaptToConnect(
              webMiddleware,
              ~basePath=config.basePath,
            )
            let middlewarePlugin = Bindings.makeVitePlugin({
              name: "frontman-middleware",
              configureServer: ?Some(
                server => {
                  server.middlewares->Bindings.use(connectMiddleware)
                },
              ),
            })

            // Register Vite plugin that monkey-patches renderComponent to inject
            // component props as HTML comments into the SSR output.
            // This lets the client-side annotation capture script associate
            // props with each component instance for AI agent context.
            ctx.updateConfig({
              vite: ?Some({
                plugins: ?Some([middlewarePlugin, frontmanPropsInjectionPlugin()]),
              }),
            })

            // Register rehype plugin as [attacher, options] tuple. Astro's markdown
            // processor calls unified.use(attacher, options) — passing the pre-invoked
            // transformer directly won't work because unified treats it as an attacher
            // and calls it with no args.
            ctx.updateConfig({
              markdown: ?Some({
                rehypePlugins: ?Some([
                  asRehypePlugin((rehypeContentFile, {"projectRoot": config.sourceRoot})),
                ]),
              }),
            })

            // Register the dev toolbar app
            ctx.addDevToolbarApp({
              id: "frontman:toolbar",
              name: "Frontman",
              icon,
              entrypoint: getToolbarAppPath(),
            })

            // Inject a meta tag so the toolbar app can discover the basePath
            // and annotation capture script into every page's <head>.
            // Uses "head-inline" + DOMContentLoaded to run after DOM is parsed
            // but before Astro's toolbar strips data-astro-source-* attributes
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
      serverSetup: ?Some(
        ({server, toolbar}) => {
          // Initialize core LogCapture to intercept console/stdout for the
          // get_logs tool and post-edit error checking in edit_file
          FrontmanAiFrontmanCore.FrontmanCore__LogCapture.initialize()

          // Rewrite Frontman routes so Astro's trailingSlash: "always" doesn't
          // 404 them. Astro's trailing-slash check runs inside its Connect
          // handler, before any middleware registered via configureServer.
          // The only way to intercept first is to prepend a raw HTTP "request"
          // listener that appends a trailing slash before Connect sees it.
          //
          // We rewrite:
          //   /{basePath}         → /{basePath}/         (UI entry)
          //   /{basePath}/tools   → /{basePath}/tools/   (API route)
          //   /foo/{basePath}     → /foo/{basePath}/     (suffix UI route)
          // Basically any path ending with /{basePath} or starting with
          // /{basePath}/ that lacks a trailing slash.
          let prependTrailingSlashRewrite: (Bindings.viteDevServer, string) => unit = %raw(`
            function(server, basePath) {
              var hs = server.httpServer;
              if (!hs) return;
              var prefix = "/" + basePath.toLowerCase();
              var prefixSlash = prefix + "/";
              var listeners = hs.listeners("request").slice();
              hs.removeAllListeners("request");
              hs.on("request", function(req) {
                var raw = req.url || "";
                var qIdx = raw.indexOf("?");
                var path = (qIdx !== -1 ? raw.slice(0, qIdx) : raw).toLowerCase();
                var needsSlash = false;
                // Exact match: /frontman
                if (path === prefix) needsSlash = true;
                // Prefix API/UI routes: /frontman/tools, /frontman/tools/call, etc.
                // Only when the path doesn't already end with /
                else if (path.lastIndexOf("/") < path.length - 1 && (path.startsWith(prefixSlash) || path.endsWith(prefix))) needsSlash = true;
                if (needsSlash) {
                  var qs = qIdx !== -1 ? raw.slice(qIdx) : "";
                  // Preserve original case: insert / before query string
                  var pathPart = qIdx !== -1 ? raw.slice(0, qIdx) : raw;
                  req.url = pathPart + "/" + qs;
                }
              });
              for (var i = 0; i < listeners.length; i++) hs.on("request", listeners[i]);
            }
          `)
          prependTrailingSlashRewrite(server, config.basePath)

          // Log when the toolbar app is initialized
          toolbar->Bindings.toolbarOnAppInitialized("frontman:toolbar", () => {
            Console.log("[Frontman] Dev toolbar app initialized")
          })
        },
      ),
    },
  }
}
