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

// Vite plugin type — opaque, we just pass plugin objects through
type vitePlugin

// Partial Astro config for updateConfig — only the fields we need
type partialViteConfig = {plugins?: array<vitePlugin>}
type partialAstroConfig = {vite?: partialViteConfig}

// Hook context for astro:config:setup
// injectScript stage is passed as a plain string: "head-inline", "before-hydration", "page", "page-ssr"
type configSetupHookContext = {
  addDevToolbarApp: devToolbarAppConfig => unit,
  injectScript: (string, string) => unit,
  updateConfig: partialAstroConfig => unit,
  config: astroConfig,
  command: astroCommand,
}

// Vite dev server connect middleware stack
type connectMiddlewareStack

@send
external use: (connectMiddlewareStack, NodeHttp.connectMiddleware) => unit = "use"

// Vite dev server (minimal bindings for astro:server:setup)
type viteDevServer = {middlewares: connectMiddlewareStack}

// --- Server-side toolbar object (available in astro:server:setup hook) ---
// Must be defined before serverSetupHookContext which references it.

type toolbarServerSide

// Toggle state — shared between client-side and server-side toolbar APIs
type toggleState = {state: bool}

@send
external toolbarSend: (toolbarServerSide, string, 'a) => unit = "send"

@send
external toolbarOn: (toolbarServerSide, string, 'a => unit) => unit = "on"

@send
external toolbarOnAppInitialized: (toolbarServerSide, string, unit => unit) => unit =
  "onAppInitialized"

@send
external toolbarOnAppToggled: (toolbarServerSide, string, toggleState => unit) => unit =
  "onAppToggled"

// Hook context for astro:server:setup
type serverSetupHookContext = {
  server: viteDevServer,
  toolbar: toolbarServerSide,
}

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

// --- Client-side toolbar app types ---

// canvas is a ShadowRoot — apps render their UI into it
type toolbarCanvas = WebAPI.DOMAPI.shadowRoot

// app is an EventTarget with helper methods for toggle/notification events
type toolbarApp

// Notification options for toggleNotification
type notificationOptions = {
  state?: bool,
  level?: [#error | #warning | #info],
}

// Toolbar placement options
type placementOptions = {
  placement: [#"bottom-left" | #"bottom-center" | #"bottom-right"],
}

// Client-side app event helpers
@send
external onToggled: (toolbarApp, toggleState => unit) => unit = "onToggled"

@send
external onToolbarPlacementUpdated: (toolbarApp, placementOptions => unit) => unit =
  "onToolbarPlacementUpdated"

@send
external toggleState: (toolbarApp, toggleState) => unit = "toggleState"

@send
external toggleNotification: (toolbarApp, notificationOptions) => unit = "toggleNotification"

// Toolbar server helpers for client-server communication (client-side)
type toolbarServer

@send
external serverSend: (toolbarServer, string, 'a) => unit = "send"

@send
external serverOn: (toolbarServer, string, 'a => unit) => unit = "on"

type toolbarAppDefinition // opaque - returned by defineToolbarApp

type toolbarAppConfig = {
  init: (toolbarCanvas, toolbarApp, toolbarServer) => unit,
  beforeTogglingOff?: toolbarCanvas => bool,
}

// defineToolbarApp binding - returns an object that should be export default'd
@module("astro/toolbar")
external defineToolbarApp: toolbarAppConfig => toolbarAppDefinition = "defineToolbarApp"
