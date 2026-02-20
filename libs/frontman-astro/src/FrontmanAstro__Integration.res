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
  var PROPS_PREFIX = '__frontman_props__:';

  // Parse a __frontman_props__ comment value (base64-encoded JSON).
  // Returns { displayName, props, moduleId? } or null.
  function parsePropsPayload(text) {
    text = text.trim();
    if (text.indexOf(PROPS_PREFIX) !== 0) return null;
    try {
      var encoded = text.slice(PROPS_PREFIX.length).trim();
      return JSON.parse(atob(encoded));
    } catch(e) {
      return null;
    }
  }

  function captureAnnotations() {
    var annotations = new Map();

    // Phase 1: Build a map from each annotated element to its component
    // props by walking the DOM in document order with a TreeWalker.
    //
    // When we encounter a __frontman_props__ comment, we push it onto a
    // stack. When we encounter an element with data-astro-source-file,
    // we pop all pending comments and build a props chain for that element.
    // This works because renderComponent writes the comment immediately
    // before the component renders, so the comment is always followed by
    // the component's first rendered element.
    //
    // For nested components (BlogCard -> Card -> <div>):
    //   <!-- BlogCard props -->
    //   <!-- Card props -->
    //   <div data-astro-source-file="Card.astro">
    //
    // The <div> gets both BlogCard and Card props in its chain.

    var propsMap = new Map(); // element -> array of props entries
    var pendingProps = [];    // stack of pending comment payloads

    var walker = document.createTreeWalker(
      document.documentElement,
      NodeFilter.SHOW_COMMENT | NodeFilter.SHOW_ELEMENT,
      null
    );

    var node;
    while (node = walker.nextNode()) {
      if (node.nodeType === 8) { // Comment
        var parsed = parsePropsPayload(node.textContent);
        if (parsed) {
          pendingProps.push(parsed);
        }
      } else if (node.nodeType === 1) { // Element
        // If there are pending props comments and this element has
        // data-astro-source-file, associate the props with it.
        if (pendingProps.length > 0 && node.hasAttribute('data-astro-source-file')) {
          propsMap.set(node, pendingProps.slice()); // copy the array
          pendingProps = [];
        }
        // Non-annotated elements (excluding STYLE/SCRIPT) are ignored;
        // pendingProps carry forward until an annotated element consumes them.
        // This handles components that render wrapper elements without
        // data-astro-source-file before their annotated children.
      }
    }

    // Phase 2: Build annotations map with props lookup.
    document.querySelectorAll('[data-astro-source-file]').forEach(function(el) {
      var sourceFile = el.getAttribute('data-astro-source-file');
      var annotation = {
        file: sourceFile,
        loc: el.getAttribute('data-astro-source-loc')
      };

      // Direct match: this element has props comments
      var propsChain = propsMap.get(el);

      // If no direct match, walk up ancestors to find one
      if (!propsChain) {
        var parent = el.parentElement;
        var maxSteps = 30;
        while (parent && maxSteps-- > 0) {
          propsChain = propsMap.get(parent);
          if (propsChain) break;
          parent = parent.parentElement;
        }
      }

      if (propsChain && propsChain.length > 0) {
        // Find the best matching entry by moduleId
        var match = null;
        for (var i = 0; i < propsChain.length; i++) {
          var entry = propsChain[i];
          if (entry.moduleId) {
            var entryFile = entry.moduleId.split('/').pop() || '';
            var srcFile = sourceFile.split('/').pop() || '';
            if (entryFile === srcFile && entryFile !== '') {
              match = entry;
              break;
            }
          }
        }
        // Fall back to outermost entry
        if (!match) match = propsChain[0];

        if (match) {
          annotation.componentProps = match.props || null;
          if (match.displayName) {
            annotation.displayName = match.displayName;
          }
        }
      }

      annotations.set(el, annotation);
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
