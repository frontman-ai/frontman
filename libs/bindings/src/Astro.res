// Astro Integration API bindings

// Dev toolbar app configuration
// entrypoint: file path to the toolbar app module (string | URL supported, using string for simplicity)
type devToolbarAppConfig = {
  id: string,
  name: string,
  icon: string,
  entrypoint: string,
}

// Astro command type
type astroCommand = [#dev | #build | #preview | #sync]

// Astro devToolbar config
type devToolbarConfig = {enabled: bool}

// Astro config (subset we care about)
type astroConfig = {
  root: string,
  devToolbar: devToolbarConfig,
}

// Hook context for astro:config:setup
// injectScript stage is passed as a plain string: "head-inline", "before-hydration", "page", "page-ssr"
type configSetupHookContext = {
  addDevToolbarApp: devToolbarAppConfig => unit,
  injectScript: (string, string) => unit,
  config: astroConfig,
  command: astroCommand,
}

// Vite dev server connect middleware stack
type connectMiddlewareStack

@send
external use: (connectMiddlewareStack, NodeHttp.connectMiddleware) => unit = "use"

// Vite dev server (minimal bindings for astro:server:setup)
type viteDevServer = {middlewares: connectMiddlewareStack}

// Hook context for astro:server:setup
type serverSetupHookContext = {server: viteDevServer}

// Astro integration hooks
type astroHooks = {
  @as("astro:config:setup")
  configSetup?: configSetupHookContext => unit,
  @as("astro:server:setup")
  serverSetup?: serverSetupHookContext => unit,
}

// Astro integration type
type astroIntegration = {
  name: string,
  hooks: astroHooks,
}

// Toolbar app types
type toolbarCanvas // opaque
type toolbarApp // opaque
type toolbarServer // opaque
type toolbarAppDefinition // opaque - returned by defineToolbarApp

type toolbarAppConfig = {
  init: (toolbarCanvas, toolbarApp, toolbarServer) => unit,
}

// defineToolbarApp binding - returns an object that should be export default'd
@module("astro/toolbar")
external defineToolbarApp: toolbarAppConfig => toolbarAppDefinition = "defineToolbarApp"
