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

// Hook context for astro:config:setup
type configSetupHookContext = {
  addDevToolbarApp: devToolbarAppConfig => unit,
  config: {root: string},
  command: astroCommand,
}

// Astro integration hooks
type astroHooks = {
  @as("astro:config:setup")
  configSetup?: configSetupHookContext => unit,
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
