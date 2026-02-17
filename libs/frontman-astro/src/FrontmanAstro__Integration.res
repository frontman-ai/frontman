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

// Annotation capture script - injected via injectScript("head-inline")
// Reads Astro's data-astro-source-file/loc attributes and stores them on window.
//
// Timing: Astro's dev toolbar strips data-astro-source-* attributes inside a
// DOMContentLoaded handler registered by a <script type="module">. Our script is
// an inline <script> in <head>, so it parses and registers its DOMContentLoaded
// listener before the module script even starts loading. Since DOMContentLoaded
// listeners fire in registration order, we capture annotations before the toolbar
// strips them.
//
// Also re-captures on Astro View Transitions (SPA navigations) via astro:page-load.
let annotationCaptureScript = `(function() {
  function captureAnnotations() {
    var annotations = new Map();
    document.querySelectorAll('[data-astro-source-file]').forEach(function(el) {
      annotations.set(el, {
        file: el.getAttribute('data-astro-source-file'),
        loc: el.getAttribute('data-astro-source-loc')
      });
    });
    window.__frontman_annotations__ = {
      _map: annotations,
      get: function(el) { return annotations.get(el); },
      has: function(el) { return annotations.has(el); },
      size: function() { return annotations.size; }
    };
  }
  // Capture once on initial DOM parse
  document.addEventListener('DOMContentLoaded', captureAnnotations);
  // Re-capture on View Transitions (SPA navigations) — skips the initial
  // page-load event since DOMContentLoaded already captured
  var initialLoad = true;
  document.addEventListener('astro:page-load', function() {
    if (initialLoad) { initialLoad = false; return; }
    captureAnnotations();
  });
})();`

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

            // Register the dev toolbar app
            ctx.addDevToolbarApp({
              id: "frontman:toolbar",
              name: "Frontman",
              icon,
              entrypoint: getToolbarAppPath(),
            })

            // Inject annotation capture script into every page's <head>
            // Uses "head-inline" + DOMContentLoaded to run after DOM is parsed
            // but before Astro's toolbar strips data-astro-source-* attributes
            ctx.injectScript("head-inline", annotationCaptureScript)
          }
        },
      ),
      serverSetup: ?Some(
        ({server}) => {
          // Create our Web API middleware and adapt it to Vite's Connect middleware
          let webMiddleware = Middleware.createMiddleware(config)
          let connectMiddleware = ViteAdapter.adaptToConnect(webMiddleware, ~basePath=config.basePath)

          // Register with Vite's dev server
          server.middlewares->Bindings.use(connectMiddleware)
        },
      ),
    },
  }
}
