open Vitest

module Middleware = FrontmanCore__Middleware
module MiddlewareConfig = FrontmanCore__MiddlewareConfig
module HttpSecurity = FrontmanCore__MCP__HttpSecurity

module Helpers = {
  let sourceLocationSecurity = HttpSecurity.make(
    ~allowedOrigins=["https://client.example"],
    ~authorize=async _headers => HttpSecurity.Authorized,
  )

  let config: MiddlewareConfig.t = {
    projectRoot: "/test/project",
    sourceRoot: "/test/project",
    basePath: "frontman",
    serverName: "test-server",
    serverVersion: "1.0.0",
    clientUrl: "http://localhost/client.js",
    clientCssUrl: None,
    entrypointUrl: None,
    frameworkId: MiddlewareConfig.Nextjs,
    traits: ["react", "typescript"],
    mcpBrowserToken: None,
    sourceLocationSecurity: Some(sourceLocationSecurity),
  }

  let middleware = req => Middleware.createMiddleware(~config)(req)

  let makeGetRequest = (url: string): WebAPI.Request.t => {
    WebAPI.Request.fromURL(url)
  }

  let makeOptionsRequest = (url: string, ~sourceLocation=false): WebAPI.Request.t => {
    let headers = switch sourceLocation {
    | false => WebAPI.HeadersInit.fromKeyValueArray([])
    | true =>
      WebAPI.HeadersInit.fromKeyValueArray([
        ("Origin", "https://client.example"),
        ("Access-Control-Request-Method", "POST"),
        ("Access-Control-Request-Headers", "Content-Type"),
      ])
    }
    WebAPI.Request.fromURL(url, ~init={method: "OPTIONS", headers})
  }

  let makePostRequest = (url: string, body: JSON.t, ~origin=?): WebAPI.Request.t => {
    let headerValues = switch origin {
    | Some(origin) => [("Content-Type", "application/json"), ("Origin", origin)]
    | None => [("Content-Type", "application/json")]
    }
    let headers = WebAPI.HeadersInit.fromKeyValueArray(headerValues)
    WebAPI.Request.fromURL(
      url,
      ~init={
        method: "POST",
        body: WebAPI.BodyInit.fromString(JSON.stringify(body)),
        headers,
      },
    )
  }
}

describe("Middleware (integration)", _t => {
  describe("pass-through (non-frontman routes)", _t => {
    testAsync(
      "returns None for unrelated GET path",
      async t => {
        let req = Helpers.makeGetRequest("http://localhost/api/users")
        let result = await Helpers.middleware(req)

        t->expect(result->Option.isNone)->Expect.toBe(true)
      },
    )

    testAsync(
      "returns None for root path",
      async t => {
        let req = Helpers.makeGetRequest("http://localhost/")
        let result = await Helpers.middleware(req)

        t->expect(result->Option.isNone)->Expect.toBe(true)
      },
    )

    testAsync(
      "returns None for partial prefix match",
      async t => {
        let req = Helpers.makeGetRequest("http://localhost/frontmanager")
        let result = await Helpers.middleware(req)

        t->expect(result->Option.isNone)->Expect.toBe(true)
      },
    )

    testAsync(
      "returns None for POST to unknown sub-path",
      async t => {
        let body = JSON.Encode.object(Dict.make())
        let req = Helpers.makePostRequest("http://localhost/frontman/unknown", body)
        let result = await Helpers.middleware(req)

        t->expect(result->Option.isNone)->Expect.toBe(true)
      },
    )
  })

  describe("CORS preflight (OPTIONS)", _t => {
    testAsync(
      "handles OPTIONS for /frontman",
      async t => {
        let req = Helpers.makeOptionsRequest("http://localhost/frontman")
        let result = await Helpers.middleware(req)

        switch result {
        | Some(response) =>
          t->expect(response.status)->Expect.toBe(204)
          t
          ->expect(response.headers->WebAPI.Headers.get("Access-Control-Allow-Origin"))
          ->Expect.toEqual(Null.Value("*"))
        | None => failwith("Expected Some(response) for OPTIONS /frontman")
        }
      },
    )

    testAsync(
      "handles OPTIONS for /frontman/resolve-source-location",
      async t => {
        let req = Helpers.makeOptionsRequest(
          "http://localhost/frontman/resolve-source-location",
          ~sourceLocation=true,
        )
        let result = await Helpers.middleware(req)

        switch result {
        | Some(response) =>
          t->expect(response.status)->Expect.toBe(204)
          t
          ->expect(response.headers->WebAPI.Headers.get("Access-Control-Allow-Origin"))
          ->Expect.toEqual(Null.Value("https://client.example"))
        | None => failwith("Expected Some(response) for OPTIONS /frontman/resolve-source-location")
        }
      },
    )

    testAsync(
      "returns None for OPTIONS to non-frontman route",
      async t => {
        let req = Helpers.makeOptionsRequest("http://localhost/api/data")
        let result = await Helpers.middleware(req)

        t->expect(result->Option.isNone)->Expect.toBe(true)
      },
    )
  })

  describe("GET /frontman (UI)", _t => {
    testAsync(
      "sets a path-scoped HttpOnly MCP cookie without exposing it in HTML",
      async t => {
        let config = {...Helpers.config, mcpBrowserToken: Some("secret token;value")}
        let result = await Middleware.createMiddleware(~config)(
          Helpers.makeGetRequest("https://localhost/frontman"),
        )

        switch result {
        | Some(response) =>
          t
          ->expect(response.headers->WebAPI.Headers.get("Set-Cookie"))
          ->Expect.toEqual(
            Null.Value(
              "frontman_mcp_session=secret%20token%3Bvalue; Path=/mcp; HttpOnly; SameSite=Strict; Secure",
            ),
          )
          let body = await response->WebAPI.Response.text
          t->expect(body->String.includes("secret token;value"))->Expect.toBe(false)
          t->expect(body->String.includes("secret%20token%3Bvalue"))->Expect.toBe(false)
        | None => failwith("Expected Some(response) for GET /frontman")
        }
      },
    )

    testAsync(
      "omits Secure from the MCP cookie on local HTTP",
      async t => {
        let config = {...Helpers.config, mcpBrowserToken: Some("local-token")}
        let result = await Middleware.createMiddleware(~config)(
          Helpers.makeGetRequest("http://localhost/frontman"),
        )

        switch result {
        | Some(response) =>
          t
          ->expect(response.headers->WebAPI.Headers.get("Set-Cookie"))
          ->Expect.toEqual(
            Null.Value("frontman_mcp_session=local-token; Path=/mcp; HttpOnly; SameSite=Strict"),
          )
        | None => failwith("Expected Some(response) for GET /frontman")
        }
      },
    )

    testAsync(
      "returns HTML response",
      async t => {
        let req = Helpers.makeGetRequest("http://localhost/frontman")
        let result = await Helpers.middleware(req)

        switch result {
        | Some(response) =>
          t
          ->expect(response.headers->WebAPI.Headers.get("Content-Type"))
          ->Expect.toEqual(Null.Value("text/html"))
          let body = await response->WebAPI.Response.text
          t->expect(body->String.includes("<!DOCTYPE html>"))->Expect.toBe(true)
        | None => failwith("Expected Some(response) for GET /frontman")
        }
      },
    )

    testAsync(
      "HTML includes CORS headers",
      async t => {
        let req = Helpers.makeGetRequest("http://localhost/frontman")
        let result = await Helpers.middleware(req)

        switch result {
        | Some(response) =>
          t
          ->expect(response.headers->WebAPI.Headers.get("Access-Control-Allow-Origin"))
          ->Expect.toEqual(Null.Value("*"))
        | None => failwith("Expected Some(response)")
        }
      },
    )

    testAsync(
      "injects React Scan for debug requests",
      async t => {
        let req = Helpers.makeGetRequest("http://localhost/frontman?debug=1")
        let result = await Helpers.middleware(req)

        switch result {
        | Some(response) =>
          let body = await response->WebAPI.Response.text
          t
          ->expect(body->String.includes("react-scan@0.5.3/dist/auto.global.js"))
          ->Expect.toBe(true)
        | None => failwith("Expected Some(response) for GET /frontman?debug=1")
        }
      },
    )

    testAsync(
      "omits React Scan without debug param",
      async t => {
        let req = Helpers.makeGetRequest("http://localhost/frontman")
        let result = await Helpers.middleware(req)

        switch result {
        | Some(response) =>
          let body = await response->WebAPI.Response.text
          t
          ->expect(body->String.includes("react-scan@0.5.3/dist/auto.global.js"))
          ->Expect.toBe(false)
        | None => failwith("Expected Some(response) for GET /frontman")
        }
      },
    )

    testAsync(
      "injects React Scan for suffix debug requests",
      async t => {
        let req = Helpers.makeGetRequest("http://localhost/products/123/frontman?debug=1")
        let result = await Helpers.middleware(req)

        switch result {
        | Some(response) =>
          let body = await response->WebAPI.Response.text
          t
          ->expect(body->String.includes("react-scan@0.5.3/dist/auto.global.js"))
          ->Expect.toBe(true)
        | None => failwith("Expected Some(response) for GET /products/123/frontman?debug=1")
        }
      },
    )
  })

  describe("removed legacy tool routes", _t => {
    testAsync(
      "does not own GET /frontman/tools",
      async t => {
        let req = Helpers.makeGetRequest("http://localhost/frontman/tools")
        let result = await Helpers.middleware(req)

        t->expect(result->Option.isNone)->Expect.toBe(true)
      },
    )

    testAsync(
      "does not own OPTIONS /frontman/tools",
      async t => {
        let req = Helpers.makeOptionsRequest("http://localhost/frontman/tools")
        let result = await Helpers.middleware(req)

        t->expect(result->Option.isNone)->Expect.toBe(true)
      },
    )

    testAsync(
      "does not own POST /frontman/tools/call or consume its body",
      async t => {
        let body = JSON.Encode.object(
          Dict.fromArray([
            ("name", JSON.Encode.string("file_exists")),
            (
              "arguments",
              JSON.Encode.object(Dict.fromArray([("path", JSON.Encode.string("/tmp/test.txt"))])),
            ),
          ]),
        )
        let req = Helpers.makePostRequest("http://localhost/frontman/tools/call", body)
        let result = await Helpers.middleware(req)

        t->expect(result->Option.isNone)->Expect.toBe(true)
        t->expect(req.bodyUsed)->Expect.toBe(false)
      },
    )

    testAsync(
      "does not own OPTIONS /frontman/tools/call",
      async t => {
        let req = Helpers.makeOptionsRequest("http://localhost/frontman/tools/call")
        let result = await Helpers.middleware(req)

        t->expect(result->Option.isNone)->Expect.toBe(true)
      },
    )
  })

  describe("POST /frontman/resolve-source-location", _t => {
    testAsync(
      "returns 400 for invalid body",
      async t => {
        let body = JSON.Encode.string("bad")
        let req = Helpers.makePostRequest(
          "http://localhost/frontman/resolve-source-location",
          body,
          ~origin="https://client.example",
        )
        let result = await Helpers.middleware(req)

        switch result {
        | Some(response) =>
          t->expect(response.status)->Expect.toBe(400)
          t
          ->expect(response.headers->WebAPI.Headers.get("Access-Control-Allow-Origin"))
          ->Expect.toEqual(Null.Value("https://client.example"))
        | None => failwith("Expected Some(response) for invalid POST")
        }
      },
    )
  })

  describe("UI route case insensitivity", _t => {
    testAsync(
      "handles uppercase path",
      async t => {
        let req = Helpers.makeGetRequest("http://localhost/FRONTMAN")
        let result = await Helpers.middleware(req)

        switch result {
        | Some(response) =>
          t
          ->expect(response.headers->WebAPI.Headers.get("Content-Type"))
          ->Expect.toEqual(Null.Value("text/html"))
        | None => failwith("Expected Some(response) for uppercase path")
        }
      },
    )

    testAsync(
      "handles mixed case path",
      async t => {
        let req = Helpers.makeGetRequest("http://localhost/Frontman")
        let result = await Helpers.middleware(req)

        switch result {
        | Some(response) =>
          t
          ->expect(response.headers->WebAPI.Headers.get("Content-Type"))
          ->Expect.toEqual(Null.Value("text/html"))
        | None => failwith("Expected Some(response) for mixed case path")
        }
      },
    )
  })
})
