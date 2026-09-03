type devToolbarAppConfig = {
  id: string,
  name: string,
  icon: string,
  entrypoint: string,
}

type astroCommand = [#dev | #build | #preview | #sync]
type trailingSlash = [#always | #never | #ignore]

type devToolbarConfig = {enabled: bool}

type rehypePlugin
type markdownProcessor

type markdownConfig = {
  processor?: markdownProcessor,
  rehypePlugins: array<rehypePlugin>,
}

type unsafeConfigValue

type namedConfig = {name?: string}

type remotePattern = {
  protocol?: string,
  hostname?: string,
  port?: string,
  pathname?: string,
}

type imageConfig = {
  endpoint?: unsafeConfigValue,
  service?: unsafeConfigValue,
  domains?: array<string>,
  remotePatterns?: array<remotePattern>,
}

type securityConfig = {
  checkOrigin?: bool,
  allowedDomains?: array<remotePattern>,
  actionBodySizeLimit?: int,
  serverIslandBodySizeLimit?: int,
  csp?: unsafeConfigValue,
}

type sessionConfig = {
  driver?: string,
  ttl?: int,
  cookie?: unsafeConfigValue,
  options?: unsafeConfigValue,
}

type serverConfig = {allowedHosts?: array<string>}

type astroConfig = {
  root: string,
  devToolbar: devToolbarConfig,
  markdown: markdownConfig,
  trailingSlash: trailingSlash,
  output?: string,
  adapter?: namedConfig,
  integrations?: array<namedConfig>,
  site?: string,
  base: string,
  redirects?: unsafeConfigValue,
  i18n?: unsafeConfigValue,
  image?: imageConfig,
  security?: securityConfig,
  session?: sessionConfig,
  server?: serverConfig,
}

type vitePlugin

type connectMiddlewareStack

@send
external use: (connectMiddlewareStack, NodeHttp.connectMiddleware) => unit = "use"

type viteDevServer = {middlewares: connectMiddlewareStack}

@send
external ssrLoadModule: (viteDevServer, string) => promise<'a> = "ssrLoadModule"

type vitePluginConfig = {
  name: string,
  configureServer?: viteDevServer => unit,
}

external makeVitePlugin: vitePluginConfig => vitePlugin = "%identity"

type partialViteConfig = {plugins?: array<vitePlugin>}

type partialMarkdownConfig = {rehypePlugins?: array<rehypePlugin>}
type partialAstroConfig = {vite?: partialViteConfig, markdown?: partialMarkdownConfig}

type configSetupHookContext = {
  addDevToolbarApp: devToolbarAppConfig => unit,
  injectScript: (string, string) => unit,
  updateConfig: partialAstroConfig => unit,
  config: astroConfig,
  command: astroCommand,
}

type configDoneHookContext = {config: astroConfig, buildOutput: string}

type toolbarServerSide

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

type serverSetupHookContext = {
  server: viteDevServer,
  toolbar: toolbarServerSide,
}

type routeType = [#page | #endpoint | #redirect | #fallback]
type routeOrigin = [#internal | #"external" | #project]

type integrationResolvedRoute = {
  pattern: string,
  entrypoint: string,
  @as("type")
  type_: routeType,
  origin: routeOrigin,
  params: array<string>,
  pathname: option<string>,
  isPrerendered: bool,
}

type routesResolvedHookContext = {routes: array<integrationResolvedRoute>}

type astroHooks = {
  @as("astro:config:setup")
  configSetup?: configSetupHookContext => unit,
  @as("astro:config:done")
  configDone?: configDoneHookContext => unit,
  @as("astro:server:setup")
  serverSetup?: serverSetupHookContext => unit,
  @as("astro:routes:resolved")
  routesResolved?: routesResolvedHookContext => unit,
}

type astroIntegration = {
  name: string,
  hooks: astroHooks,
}

type toolbarCanvas = WebAPI.DomTypes.shadowRoot

type toolbarApp

type notificationOptions = {
  state?: bool,
  level?: [#error | #warning | #info],
}

type placementOptions = {placement: [#"bottom-left" | #"bottom-center" | #"bottom-right"]}

@send
external onToggled: (toolbarApp, toggleState => unit) => unit = "onToggled"

@send
external onToolbarPlacementUpdated: (toolbarApp, placementOptions => unit) => unit =
  "onToolbarPlacementUpdated"

@send
external toggleState: (toolbarApp, toggleState) => unit = "toggleState"

@send
external toggleNotification: (toolbarApp, notificationOptions) => unit = "toggleNotification"

type toolbarServer

@send
external serverSend: (toolbarServer, string, 'a) => unit = "send"

@send
external serverOn: (toolbarServer, string, 'a => unit) => unit = "on"

type toolbarAppDefinition

type toolbarAppConfig = {
  init: (toolbarCanvas, toolbarApp, toolbarServer) => unit,
  beforeTogglingOff?: toolbarCanvas => bool,
}

@module("astro/toolbar")
external defineToolbarApp: toolbarAppConfig => toolbarAppDefinition = "defineToolbarApp"
