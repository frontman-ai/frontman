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

// Vite plugin that wraps Astro's renderComponent to inject component props
// as HTML comments. Imported as raw JS since it transforms Vite module internals.
@module("./vite-plugin-props-injection.mjs")
external frontmanPropsInjectionPlugin: unit => Bindings.vitePlugin = "frontmanPropsInjectionPlugin"

// Browser-side annotation capture script (exported as a string for injectScript)
@module("./annotation-capture.mjs")
external annotationCaptureScript: string = "annotationCaptureScript"

// SVG icon for the toolbar
let icon = `<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><circle cx="12" cy="12" r="3"/></svg>`

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

  {
    name: "frontman",
    hooks: {
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
                "[Frontman] Astro devToolbar is disabled — element source detection will be limited. " ++
                "Set `devToolbar: { enabled: true }` in your astro.config to enable full component source resolution.",
              )
            }

            // Register Vite plugin that monkey-patches renderComponent to inject
            // component props as HTML comments into the SSR output.
            // This lets the client-side annotation capture script associate
            // props with each component instance for AI agent context.
            ctx.updateConfig({
              vite: ?Some({
                plugins: ?Some([frontmanPropsInjectionPlugin()]),
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
          FrontmanFrontmanCore.FrontmanCore__LogCapture.initialize()

          // Create our Web API middleware and adapt it to Vite's Connect middleware
          let webMiddleware = Middleware.createMiddleware(config)
          let connectMiddleware = ViteAdapter.adaptToConnect(webMiddleware, ~basePath=config.basePath)

          // Register with Vite's dev server
          server.middlewares->Bindings.use(connectMiddleware)

          // Log when the toolbar app is initialized
          toolbar->Bindings.toolbarOnAppInitialized("frontman:toolbar", () => {
            Console.log("[Frontman] Dev toolbar app initialized")
          })
        },
      ),
    },
  }
}
