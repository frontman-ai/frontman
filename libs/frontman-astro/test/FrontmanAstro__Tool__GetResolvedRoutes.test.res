open Vitest

module Helpers = FrontmanAstro__TestHelpers
module Bindings = FrontmanBindings.Astro
module ToolRegistry = FrontmanAstro__ToolRegistry

module Fixtures = {
  let homePage: Bindings.integrationResolvedRoute = {
    pattern: "/",
    entrypoint: "src/pages/index.astro",
    type_: #page,
    origin: #project,
    params: [],
    pathname: Some("/"),
    isPrerendered: false,
  }

  let aboutPage: Bindings.integrationResolvedRoute = {
    pattern: "/about",
    entrypoint: "src/pages/about.astro",
    type_: #page,
    origin: #project,
    params: [],
    pathname: Some("/about"),
    isPrerendered: true,
  }

  let blogPost: Bindings.integrationResolvedRoute = {
    pattern: "/blog/[slug]",
    entrypoint: "src/pages/blog/[slug].astro",
    type_: #page,
    origin: #project,
    params: ["slug"],
    pathname: None,
    isPrerendered: true,
  }

  let docsSection: Bindings.integrationResolvedRoute = {
    pattern: "/docs/[...path]",
    entrypoint: "src/pages/docs/[...path].astro",
    type_: #page,
    origin: #project,
    params: ["path"],
    pathname: None,
    isPrerendered: true,
  }

  let apiHealth: Bindings.integrationResolvedRoute = {
    pattern: "/api/health",
    entrypoint: "src/pages/api/health.ts",
    type_: #endpoint,
    origin: #project,
    params: [],
    pathname: Some("/api/health"),
    isPrerendered: false,
  }

  let apiUserById: Bindings.integrationResolvedRoute = {
    pattern: "/api/users/[id]",
    entrypoint: "src/pages/api/users/[id].ts",
    type_: #endpoint,
    origin: #project,
    params: ["id"],
    pathname: None,
    isPrerendered: false,
  }

  let redirectOldBlog: Bindings.integrationResolvedRoute = {
    pattern: "/old-blog",
    entrypoint: "",
    type_: #redirect,
    origin: #project,
    params: [],
    pathname: Some("/old-blog"),
    isPrerendered: false,
  }

  let redirectDynamic: Bindings.integrationResolvedRoute = {
    pattern: "/posts/[slug]",
    entrypoint: "",
    type_: #redirect,
    origin: #project,
    params: ["slug"],
    pathname: None,
    isPrerendered: false,
  }

  let sitemapXml: Bindings.integrationResolvedRoute = {
    pattern: "/sitemap.xml",
    entrypoint: "node_modules/@astrojs/sitemap/dist/endpoint.js",
    type_: #endpoint,
    origin: #"external",
    params: [],
    pathname: Some("/sitemap.xml"),
    isPrerendered: true,
  }

  let imageEndpoint: Bindings.integrationResolvedRoute = {
    pattern: "/_image",
    entrypoint: "node_modules/astro/dist/assets/endpoint.js",
    type_: #endpoint,
    origin: #internal,
    params: [],
    pathname: Some("/_image"),
    isPrerendered: false,
  }

  let fallback404: Bindings.integrationResolvedRoute = {
    pattern: "/404",
    entrypoint: "src/pages/404.astro",
    type_: #fallback,
    origin: #project,
    params: [],
    pathname: Some("/404"),
    isPrerendered: true,
  }

  let i18nBlogPost: Bindings.integrationResolvedRoute = {
    pattern: "/[lang]/blog/[slug]",
    entrypoint: "src/pages/[lang]/blog/[slug].astro",
    type_: #page,
    origin: #project,
    params: ["lang", "slug"],
    pathname: None,
    isPrerendered: false,
  }
}

let makeMiddleware = (~routes) =>
  Helpers.makeMiddleware(~registry=ToolRegistry.makeWithResolvedRoutes(~getRoutes=() => routes))

describe("get_client_pages (resolved routes) via HTTP middleware", _t => {
  describe("routes the v4 filesystem scanner misses", _t => {
    testAsync(
      "includes API endpoints (v4 excludes api/ directory)",
      async t => {
        let middleware = makeMiddleware(~routes=[Fixtures.apiHealth, Fixtures.apiUserById])

        let sseBody = await Helpers.callTool(
          middleware,
          ~name="get_client_pages",
          ~arguments=JSON.Encode.object(Dict.fromArray([])),
        )

        t->expect(sseBody->String.includes("/api/health"))->Expect.toBe(true)
        t->expect(sseBody->String.includes("/api/users/[id]"))->Expect.toBe(true)
        t->expect(sseBody->String.includes("endpoint"))->Expect.toBe(true)
      },
    )

    testAsync(
      "includes config-defined redirects (no file on disk)",
      async t => {
        let middleware = makeMiddleware(
          ~routes=[Fixtures.redirectOldBlog, Fixtures.redirectDynamic],
        )

        let sseBody = await Helpers.callTool(
          middleware,
          ~name="get_client_pages",
          ~arguments=JSON.Encode.object(Dict.fromArray([])),
        )

        t->expect(sseBody->String.includes("/old-blog"))->Expect.toBe(true)
        t->expect(sseBody->String.includes("redirect"))->Expect.toBe(true)
        t->expect(sseBody->String.includes("/posts/[slug]"))->Expect.toBe(true)
      },
    )

    testAsync(
      "includes integration-injected routes (external origin, e.g. @astrojs/sitemap)",
      async t => {
        let middleware = makeMiddleware(~routes=[Fixtures.sitemapXml])

        let sseBody = await Helpers.callTool(
          middleware,
          ~name="get_client_pages",
          ~arguments=JSON.Encode.object(Dict.fromArray([])),
        )

        t->expect(sseBody->String.includes("/sitemap.xml"))->Expect.toBe(true)
        t->expect(sseBody->String.includes("external"))->Expect.toBe(true)
      },
    )

    testAsync(
      "includes internal/fallback routes (Astro built-ins)",
      async t => {
        let middleware = makeMiddleware(~routes=[Fixtures.imageEndpoint, Fixtures.fallback404])

        let sseBody = await Helpers.callTool(
          middleware,
          ~name="get_client_pages",
          ~arguments=JSON.Encode.object(Dict.fromArray([])),
        )

        t->expect(sseBody->String.includes("/_image"))->Expect.toBe(true)
        t->expect(sseBody->String.includes("internal"))->Expect.toBe(true)
        t->expect(sseBody->String.includes("fallback"))->Expect.toBe(true)
      },
    )
  })

  describe("route metadata from hook data", _t => {
    testAsync(
      "populates params from hook data",
      async t => {
        let middleware = makeMiddleware(~routes=[Fixtures.blogPost, Fixtures.docsSection])

        let sseBody = await Helpers.callTool(
          middleware,
          ~name="get_client_pages",
          ~arguments=JSON.Encode.object(Dict.fromArray([])),
        )

        t->expect(sseBody->String.includes(`\\\"slug\\\"`))->Expect.toBe(true)
        t->expect(sseBody->String.includes(`\\\"path\\\"`))->Expect.toBe(true)
      },
    )

    testAsync(
      "reports multiple params for multi-param routes",
      async t => {
        let middleware = makeMiddleware(~routes=[Fixtures.i18nBlogPost])

        let sseBody = await Helpers.callTool(
          middleware,
          ~name="get_client_pages",
          ~arguments=JSON.Encode.object(Dict.fromArray([])),
        )

        t->expect(sseBody->String.includes(`\\\"lang\\\"`))->Expect.toBe(true)
        t->expect(sseBody->String.includes(`\\\"slug\\\"`))->Expect.toBe(true)
      },
    )

    testAsync(
      "marks routes with params as dynamic",
      async t => {
        let middleware = makeMiddleware(~routes=[Fixtures.homePage, Fixtures.blogPost])

        let sseBody = await Helpers.callTool(
          middleware,
          ~name="get_client_pages",
          ~arguments=JSON.Encode.object(Dict.fromArray([])),
        )

        t->expect(sseBody->String.includes(`\\\"isDynamic\\\":true`))->Expect.toBe(true)
        t->expect(sseBody->String.includes(`\\\"isDynamic\\\":false`))->Expect.toBe(true)
      },
    )

    testAsync(
      "includes prerender status",
      async t => {
        let middleware = makeMiddleware(~routes=[Fixtures.homePage, Fixtures.aboutPage])

        let sseBody = await Helpers.callTool(
          middleware,
          ~name="get_client_pages",
          ~arguments=JSON.Encode.object(Dict.fromArray([])),
        )

        t->expect(sseBody->String.includes(`\\\"isPrerendered\\\":true`))->Expect.toBe(true)
        t->expect(sseBody->String.includes(`\\\"isPrerendered\\\":false`))->Expect.toBe(true)
      },
    )

    testAsync(
      "includes route type and origin",
      async t => {
        let middleware = makeMiddleware(
          ~routes=[Fixtures.homePage, Fixtures.apiHealth, Fixtures.sitemapXml],
        )

        let sseBody = await Helpers.callTool(
          middleware,
          ~name="get_client_pages",
          ~arguments=JSON.Encode.object(Dict.fromArray([])),
        )

        t->expect(sseBody->String.includes("page"))->Expect.toBe(true)
        t->expect(sseBody->String.includes("endpoint"))->Expect.toBe(true)
        t->expect(sseBody->String.includes("project"))->Expect.toBe(true)
        t->expect(sseBody->String.includes("external"))->Expect.toBe(true)
      },
    )
  })

  describe("edge cases", _t => {
    testAsync(
      "returns empty array when no routes resolved",
      async t => {
        let middleware = makeMiddleware(~routes=[])

        let sseBody = await Helpers.callTool(
          middleware,
          ~name="get_client_pages",
          ~arguments=JSON.Encode.object(Dict.fromArray([])),
        )

        t->expect(sseBody->String.includes("[]"))->Expect.toBe(true)
      },
    )

    testAsync(
      "handles full route mix without errors",
      async t => {
        let middleware = makeMiddleware(
          ~routes=[
            Fixtures.homePage,
            Fixtures.aboutPage,
            Fixtures.blogPost,
            Fixtures.docsSection,
            Fixtures.apiHealth,
            Fixtures.apiUserById,
            Fixtures.redirectOldBlog,
            Fixtures.redirectDynamic,
            Fixtures.sitemapXml,
            Fixtures.imageEndpoint,
            Fixtures.fallback404,
            Fixtures.i18nBlogPost,
          ],
        )

        let sseBody = await Helpers.callTool(
          middleware,
          ~name="get_client_pages",
          ~arguments=JSON.Encode.object(Dict.fromArray([])),
        )

        t->expect(sseBody->String.includes("/blog/[slug]"))->Expect.toBe(true)
        t->expect(sseBody->String.includes("/docs/[...path]"))->Expect.toBe(true)
        t->expect(sseBody->String.includes("/api/health"))->Expect.toBe(true)
        t->expect(sseBody->String.includes("/old-blog"))->Expect.toBe(true)
        t->expect(sseBody->String.includes("/sitemap.xml"))->Expect.toBe(true)
        t->expect(sseBody->String.includes("/_image"))->Expect.toBe(true)
        t->expect(sseBody->String.includes("/404"))->Expect.toBe(true)
        t->expect(sseBody->String.includes("/[lang]/blog/[slug]"))->Expect.toBe(true)
      },
    )
  })

  describe("tool listing", _t => {
    testAsync(
      "get_client_pages is listed in the tools endpoint",
      async t => {
        let middleware = makeMiddleware(~routes=[])
        let body = await Helpers.getEndpoint(middleware, ~path="tools")
        t->expect(body->String.includes("get_client_pages"))->Expect.toBe(true)
      },
    )

    testAsync(
      "tool description mentions resolved routes",
      async t => {
        let middleware = makeMiddleware(~routes=[])
        let body = await Helpers.getEndpoint(middleware, ~path="tools")
        t->expect(body->String.includes("resolved"))->Expect.toBe(true)
      },
    )
  })
})
