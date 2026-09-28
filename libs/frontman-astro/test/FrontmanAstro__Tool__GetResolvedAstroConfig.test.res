open Vitest

module Helpers = FrontmanAstro__TestHelpers
module Bindings = FrontmanBindings.Astro
module ToolRegistry = FrontmanAstro__ToolRegistry
module Tool = FrontmanAstro__Tool__GetResolvedAstroConfig

external unsafeConfigValue: JSON.t => Bindings.unsafeConfigValue = "%identity"

let config: Bindings.astroConfig = {
  root: "/tmp/project",
  devToolbar: {enabled: true},
  markdown: {
    processor: ?None,
    rehypePlugins: [],
  },
  trailingSlash: #always,
  output: ?Some("server"),
  adapter: ?Some({name: ?Some("@astrojs/node")}),
  integrations: ?Some([{name: ?Some("@astrojs/react")}, {name: ?Some("@astrojs/mdx")}]),
  site: ?Some("https://example.com"),
  base: "/docs/",
  redirects: ?Some(JSON.Encode.object(dict{"/old": JSON.Encode.string("/new")})->unsafeConfigValue),
  i18n: ?Some(
    JSON.Encode.object(
      dict{
        "defaultLocale": JSON.Encode.string("en"),
        "locales": JSON.Encode.array([JSON.Encode.string("en"), JSON.Encode.string("fr")]),
      },
    )->unsafeConfigValue,
  ),
  image: ?Some({
    endpoint: ?None,
    service: ?None,
    domains: ?Some(["images.example.com"]),
    remotePatterns: ?None,
  }),
  security: ?Some({
    checkOrigin: ?Some(true),
    allowedDomains: ?None,
    actionBodySizeLimit: ?None,
    serverIslandBodySizeLimit: ?None,
    csp: ?None,
  }),
  session: ?Some({
    driver: ?Some("redis"),
    ttl: ?Some(3600),
    cookie: ?None,
    options: ?Some(
      JSON.Encode.object(dict{"url": JSON.Encode.string("redis://secret")})->unsafeConfigValue,
    ),
  }),
  server: ?Some({allowedHosts: ?Some(["frontman.local"])}),
}

let captured: Tool.captured = {astroVersion: "5.18.0", buildOutput: "server", config}

let makeMiddleware = (~getAstroConfig=() => Some(captured), ()) =>
  Helpers.makeMiddleware(
    ~registry=ToolRegistry.makeWithAstroRuntime(
      ~loadContentApi=async () => failwith("unused"),
      ~getAstroConfig,
    ),
  )

describe("get_resolved_astro_config", _t => {
  testAsync("returns sanitized resolved Astro config", async t => {
    let middleware = makeMiddleware()

    let sseBody = await Helpers.callTool(
      middleware,
      ~name="get_resolved_astro_config",
      ~arguments=JSON.Encode.object(Dict.fromArray([])),
    )

    t->expect(sseBody->String.includes("5.18.0"))->Expect.toBe(true)
    t->expect(sseBody->String.includes("server"))->Expect.toBe(true)
    t->expect(sseBody->String.includes("@astrojs/node"))->Expect.toBe(true)
    t->expect(sseBody->String.includes("@astrojs/react"))->Expect.toBe(true)
    t->expect(sseBody->String.includes("https://example.com"))->Expect.toBe(true)
    t->expect(sseBody->String.includes("/docs/"))->Expect.toBe(true)
    t->expect(sseBody->String.includes("images.example.com"))->Expect.toBe(true)
    t->expect(sseBody->String.includes("frontman.local"))->Expect.toBe(true)
    t->expect(sseBody->String.includes("redis://secret"))->Expect.toBe(false)
  })

  testAsync("errors clearly before Astro config is captured", async t => {
    let middleware = makeMiddleware(~getAstroConfig=() => None, ())

    let sseBody = await Helpers.callTool(
      middleware,
      ~name="get_resolved_astro_config",
      ~arguments=JSON.Encode.object(Dict.fromArray([])),
    )

    t->expect(sseBody->String.includes("Astro config has not been captured yet"))->Expect.toBe(true)
  })

  test("is registered", t => {
    let registry = ToolRegistry.makeWithAstroRuntime(
      ~loadContentApi=async () => failwith("unused"),
      ~getAstroConfig=() => Some(captured),
    )

    t
    ->expect(ToolRegistry.getToolByName(registry, "get_resolved_astro_config") != None)
    ->Expect.toBe(true)
  })
})
