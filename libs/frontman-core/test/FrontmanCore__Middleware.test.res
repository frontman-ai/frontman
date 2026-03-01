open Vitest

module Middleware = FrontmanCore__Middleware
module MiddlewareConfig = FrontmanCore__MiddlewareConfig
module ToolRegistry = FrontmanCore__ToolRegistry
module Relay = FrontmanAiFrontmanProtocol.FrontmanProtocol__Relay

module Helpers = {
  let config: MiddlewareConfig.t = {
    projectRoot: "/test/project",
    sourceRoot: "/test/project",
    basePath: "frontman",
    serverName: "test-server",
    serverVersion: "1.0.0",
    clientUrl: "http://localhost/client.js",
    clientCssUrl: None,
    entrypointUrl: None,
    isLightTheme: false,
    frameworkLabel: "Test",
  }

  let registry = ToolRegistry.coreTools()

  let middleware = Middleware.createMiddleware(~config, ~registry)

  let makeGetRequest = (url: string): WebAPI.FetchAPI.request => {
    WebAPI.Request.fromURL(url)
  }

  let makeOptionsRequest = (url: string): WebAPI.FetchAPI.request => {
    WebAPI.Request.fromURL(url, ~init={method: "OPTIONS"})
  }

  let makePostRequest = (url: string, body: JSON.t): WebAPI.FetchAPI.request => {
    let headers = WebAPI.HeadersInit.fromDict(
      Dict.fromArray([("Content-Type", "application/json")]),
    )
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
    testAsync("returns None for unrelated GET path", async t => {
      let req = Helpers.makeGetRequest("http://localhost/api/users")
      let result = await Helpers.middleware(req)

      t->expect(result->Option.isNone)->Expect.toBe(true)
    })

    testAsync("returns None for root path", async t => {
      let req = Helpers.makeGetRequest("http://localhost/")
      let result = await Helpers.middleware(req)

      t->expect(result->Option.isNone)->Expect.toBe(true)
    })

    testAsync("returns None for partial prefix match", async t => {
      let req = Helpers.makeGetRequest("http://localhost/frontmanager")
      let result = await Helpers.middleware(req)

      t->expect(result->Option.isNone)->Expect.toBe(true)
    })

    testAsync("returns None for POST to unknown sub-path", async t => {
      let body = JSON.Encode.object(Dict.make())
      let req = Helpers.makePostRequest("http://localhost/frontman/unknown", body)
      let result = await Helpers.middleware(req)

      t->expect(result->Option.isNone)->Expect.toBe(true)
    })
  })

  describe("CORS preflight (OPTIONS)", _t => {
    testAsync("handles OPTIONS for /frontman", async t => {
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
    })

    testAsync("handles OPTIONS for /frontman/tools", async t => {
      let req = Helpers.makeOptionsRequest("http://localhost/frontman/tools")
      let result = await Helpers.middleware(req)

      switch result {
      | Some(response) => t->expect(response.status)->Expect.toBe(204)
      | None => failwith("Expected Some(response) for OPTIONS /frontman/tools")
      }
    })

    testAsync("handles OPTIONS for /frontman/tools/call", async t => {
      let req = Helpers.makeOptionsRequest("http://localhost/frontman/tools/call")
      let result = await Helpers.middleware(req)

      switch result {
      | Some(response) => t->expect(response.status)->Expect.toBe(204)
      | None => failwith("Expected Some(response) for OPTIONS /frontman/tools/call")
      }
    })

    testAsync("handles OPTIONS for /frontman/resolve-source-location", async t => {
      let req = Helpers.makeOptionsRequest(
        "http://localhost/frontman/resolve-source-location",
      )
      let result = await Helpers.middleware(req)

      switch result {
      | Some(response) => t->expect(response.status)->Expect.toBe(204)
      | None =>
        failwith("Expected Some(response) for OPTIONS /frontman/resolve-source-location")
      }
    })

    testAsync("returns None for OPTIONS to non-frontman route", async t => {
      let req = Helpers.makeOptionsRequest("http://localhost/api/data")
      let result = await Helpers.middleware(req)

      t->expect(result->Option.isNone)->Expect.toBe(true)
    })
  })

  describe("GET /frontman (UI)", _t => {
    testAsync("returns HTML response", async t => {
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
    })

    testAsync("HTML includes CORS headers", async t => {
      let req = Helpers.makeGetRequest("http://localhost/frontman")
      let result = await Helpers.middleware(req)

      switch result {
      | Some(response) =>
        t
        ->expect(response.headers->WebAPI.Headers.get("Access-Control-Allow-Origin"))
        ->Expect.toEqual(Null.Value("*"))
      | None => failwith("Expected Some(response)")
      }
    })
  })

  describe("GET /frontman/tools", _t => {
    testAsync("returns JSON with tools list", async t => {
      let req = Helpers.makeGetRequest("http://localhost/frontman/tools")
      let result = await Helpers.middleware(req)

      switch result {
      | Some(response) =>
        t
        ->expect(response.headers->WebAPI.Headers.get("Content-Type"))
        ->Expect.toEqual(Null.Value("application/json"))
        let body = await response->WebAPI.Response.text
        let json = JSON.parseOrThrow(body)
        let obj = json->JSON.Decode.object->Option.getOrThrow
        t->expect(obj->Dict.get("tools")->Option.isSome)->Expect.toBe(true)
        t->expect(obj->Dict.get("serverInfo")->Option.isSome)->Expect.toBe(true)
      | None => failwith("Expected Some(response) for GET /frontman/tools")
      }
    })

    testAsync("tools response includes CORS headers", async t => {
      let req = Helpers.makeGetRequest("http://localhost/frontman/tools")
      let result = await Helpers.middleware(req)

      switch result {
      | Some(response) =>
        t
        ->expect(response.headers->WebAPI.Headers.get("Access-Control-Allow-Origin"))
        ->Expect.toEqual(Null.Value("*"))
      | None => failwith("Expected Some(response)")
      }
    })
  })

  describe("POST /frontman/tools/call", _t => {
    testAsync("returns SSE stream for valid tool call", async t => {
      let body = JSON.Encode.object(
        Dict.fromArray([
          ("name", JSON.Encode.string("file_exists")),
          (
            "arguments",
            JSON.Encode.object(
              Dict.fromArray([("path", JSON.Encode.string("/tmp/test.txt"))]),
            ),
          ),
        ]),
      )
      let req = Helpers.makePostRequest("http://localhost/frontman/tools/call", body)
      let result = await Helpers.middleware(req)

      switch result {
      | Some(response) =>
        t
        ->expect(response.headers->WebAPI.Headers.get("Content-Type"))
        ->Expect.toEqual(Null.Value("text/event-stream"))
        t
        ->expect(response.headers->WebAPI.Headers.get("Access-Control-Allow-Origin"))
        ->Expect.toEqual(Null.Value("*"))
      | None => failwith("Expected Some(response) for POST /frontman/tools/call")
      }
    })

    testAsync("returns 400 for malformed request", async t => {
      let body = JSON.Encode.string("not valid")
      let req = Helpers.makePostRequest("http://localhost/frontman/tools/call", body)
      let result = await Helpers.middleware(req)

      switch result {
      | Some(response) =>
        t->expect(response.status)->Expect.toBe(400)
        t
        ->expect(response.headers->WebAPI.Headers.get("Access-Control-Allow-Origin"))
        ->Expect.toEqual(Null.Value("*"))
      | None => failwith("Expected Some(response) for invalid POST")
      }
    })
  })

  describe("POST /frontman/resolve-source-location", _t => {
    testAsync("returns 400 for invalid body", async t => {
      let body = JSON.Encode.string("bad")
      let req = Helpers.makePostRequest(
        "http://localhost/frontman/resolve-source-location",
        body,
      )
      let result = await Helpers.middleware(req)

      switch result {
      | Some(response) =>
        t->expect(response.status)->Expect.toBe(400)
        t
        ->expect(response.headers->WebAPI.Headers.get("Access-Control-Allow-Origin"))
        ->Expect.toEqual(Null.Value("*"))
      | None => failwith("Expected Some(response) for invalid POST")
      }
    })
  })

  describe("case insensitivity", _t => {
    testAsync("handles uppercase path", async t => {
      let req = Helpers.makeGetRequest("http://localhost/FRONTMAN/TOOLS")
      let result = await Helpers.middleware(req)

      switch result {
      | Some(response) =>
        t
        ->expect(response.headers->WebAPI.Headers.get("Content-Type"))
        ->Expect.toEqual(Null.Value("application/json"))
      | None => failwith("Expected Some(response) for uppercase path")
      }
    })

    testAsync("handles mixed case path", async t => {
      let req = Helpers.makeGetRequest("http://localhost/Frontman/Tools")
      let result = await Helpers.middleware(req)

      switch result {
      | Some(response) =>
        t
        ->expect(response.headers->WebAPI.Headers.get("Content-Type"))
        ->Expect.toEqual(Null.Value("application/json"))
      | None => failwith("Expected Some(response) for mixed case path")
      }
    })
  })
})
