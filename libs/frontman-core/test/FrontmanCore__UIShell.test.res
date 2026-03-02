open Vitest

module UIShell = FrontmanCore__UIShell
module MiddlewareConfig = FrontmanCore__MiddlewareConfig

module Helpers = {
  let makeConfig = (
    ~clientUrl="http://localhost/client.js",
    ~clientCssUrl=None,
    ~entrypointUrl=None,
    ~isLightTheme=false,
    ~frameworkId=MiddlewareConfig.Nextjs,
  ): MiddlewareConfig.t => {
    projectRoot: "/test/project",
    sourceRoot: "/test/project",
    basePath: "frontman",
    serverName: "test-server",
    serverVersion: "1.0.0",
    clientUrl,
    clientCssUrl,
    entrypointUrl,
    isLightTheme,
    frameworkId,
  }
}

describe("UIShell", _t => {
  describe("generateHTML", _t => {
    test("includes DOCTYPE and html structure", t => {
      let html = UIShell.generateHTML(Helpers.makeConfig())

      t->expect(html->String.includes("<!DOCTYPE html>"))->Expect.toBe(true)
      t->expect(html->String.includes("<html lang=\"en\""))->Expect.toBe(true)
      t->expect(html->String.includes("</html>"))->Expect.toBe(true)
    })

    test("includes client JS script tag with correct URL", t => {
      let html = UIShell.generateHTML(
        Helpers.makeConfig(~clientUrl="http://cdn.example.com/app.js"),
      )

      t
      ->expect(html->String.includes("http://cdn.example.com/app.js"))
      ->Expect.toBe(true)
      t
      ->expect(html->String.includes("<script type=\"module\" src=\"http://cdn.example.com/app.js\">"))
      ->Expect.toBe(true)
    })

    test("includes CSS link when clientCssUrl is provided", t => {
      let html = UIShell.generateHTML(
        Helpers.makeConfig(~clientCssUrl=Some("http://cdn.example.com/style.css")),
      )

      t
        ->expect(
          html->String.includes(
            "<link rel=\"stylesheet\" href=\"http://cdn.example.com/style.css\">",
          ),
        )
        ->Expect.toBe(true)
    })

    test("omits CSS link when clientCssUrl is None", t => {
      let html = UIShell.generateHTML(Helpers.makeConfig(~clientCssUrl=None))

      t->expect(html->String.includes("<link rel=\"stylesheet\""))->Expect.toBe(false)
    })

    test("includes entrypoint URL template when provided", t => {
      let html = UIShell.generateHTML(
        Helpers.makeConfig(~entrypointUrl=Some("http://localhost:3000")),
      )

      t
        ->expect(
          html->String.includes("id=\"frontman-entrypoint-url\""),
        )
        ->Expect.toBe(true)
      t
        ->expect(html->String.includes("http://localhost:3000"))
        ->Expect.toBe(true)
    })

    test("omits entrypoint template when entrypointUrl is None", t => {
      let html = UIShell.generateHTML(Helpers.makeConfig(~entrypointUrl=None))

      t
        ->expect(html->String.includes("frontman-entrypoint-url"))
        ->Expect.toBe(false)
    })

    test("applies dark class when isLightTheme is false", t => {
      let html = UIShell.generateHTML(Helpers.makeConfig(~isLightTheme=false))

      t->expect(html->String.includes("class=\"dark\""))->Expect.toBe(true)
    })

    test("omits dark class when isLightTheme is true", t => {
      let html = UIShell.generateHTML(Helpers.makeConfig(~isLightTheme=true))

      t->expect(html->String.includes("class=\"dark\""))->Expect.toBe(false)
      t->expect(html->String.includes("class=\"\""))->Expect.toBe(true)
    })

    test("includes framework id in runtime config", t => {
      let html = UIShell.generateHTML(
        Helpers.makeConfig(~frameworkId=MiddlewareConfig.Vite),
      )

      t->expect(html->String.includes("__frontmanRuntime"))->Expect.toBe(true)
      t->expect(html->String.includes("\"vite\""))->Expect.toBe(true)
    })

    test("includes root div for React mounting", t => {
      let html = UIShell.generateHTML(Helpers.makeConfig())

      t->expect(html->String.includes("<div id=\"root\"></div>"))->Expect.toBe(true)
    })

    test("includes process polyfill for browser", t => {
      let html = UIShell.generateHTML(Helpers.makeConfig())

      t
        ->expect(html->String.includes("typeof process===\"undefined\""))
        ->Expect.toBe(true)
    })
  })

  describe("serve", _t => {
    testAsync("returns response with text/html content type", async t => {
      let response = UIShell.serve(Helpers.makeConfig())

      t
      ->expect(response.headers->WebAPI.Headers.get("Content-Type"))
      ->Expect.toEqual(Null.Value("text/html"))
    })

    testAsync("returns 200 status", async t => {
      let response = UIShell.serve(Helpers.makeConfig())

      t->expect(response.status)->Expect.toBe(200)
    })

    testAsync("response body contains the generated HTML", async t => {
      let config = Helpers.makeConfig(~frameworkId=MiddlewareConfig.Astro)
      let response = UIShell.serve(config)
      let body = await response->WebAPI.Response.text

      t->expect(body->String.includes("<!DOCTYPE html>"))->Expect.toBe(true)
      t->expect(body->String.includes("\"astro\""))->Expect.toBe(true)
    })
  })
})
