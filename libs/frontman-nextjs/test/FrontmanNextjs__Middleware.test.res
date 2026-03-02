open Vitest

module Middleware = FrontmanNextjs__Middleware
module Config = FrontmanNextjs__Config

module Helpers = {
  // Create middleware with test config (bypass default host/URL resolution)
  let createTestMiddleware = () => {
    let configInput: Config.jsConfigInput = {
      projectRoot: "/test/project",
      sourceRoot: "/test/project",
      basePath: "frontman",
      serverName: "test-nextjs",
      serverVersion: "1.0.0",
      host: "localhost:3000",
      clientUrl: "http://localhost:3000/client.js?clientName=nextjs&host=localhost:3000",
      isLightTheme: false,
    }
    Middleware.createMiddleware(configInput)
  }

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

describe("FrontmanNextjs Middleware (adapter)", _t => {
  describe("createMiddleware", _t => {
    test("returns a function", t => {
      let mw = Helpers.createTestMiddleware()
      // Middleware is a function: request => promise<option<response>>
      t->expect(typeof(mw) == #function)->Expect.toBe(true)
    })
  })

  describe("pass-through", _t => {
    testAsync("returns None for non-frontman routes", async t => {
      let mw = Helpers.createTestMiddleware()
      let req = Helpers.makeGetRequest("http://localhost:3000/api/users")
      let result = await mw(req)

      t->expect(result->Option.isNone)->Expect.toBe(true)
    })

    testAsync("returns None for root path", async t => {
      let mw = Helpers.createTestMiddleware()
      let req = Helpers.makeGetRequest("http://localhost:3000/")
      let result = await mw(req)

      t->expect(result->Option.isNone)->Expect.toBe(true)
    })
  })

  describe("UI route (GET /frontman)", _t => {
    testAsync("returns HTML response", async t => {
      let mw = Helpers.createTestMiddleware()
      let req = Helpers.makeGetRequest("http://localhost:3000/frontman")
      let result = await mw(req)

      switch result {
      | Some(response) =>
        t
        ->expect(response.headers->WebAPI.Headers.get("Content-Type"))
        ->Expect.toEqual(Null.Value("text/html"))
        let body = await response->WebAPI.Response.text
        t->expect(body->String.includes("<!DOCTYPE html>"))->Expect.toBe(true)
        t->expect(body->String.includes("\"nextjs\""))->Expect.toBe(true)
      | None => failwith("Expected Some(response) for GET /frontman")
      }
    })

    testAsync("HTML includes CORS headers", async t => {
      let mw = Helpers.createTestMiddleware()
      let req = Helpers.makeGetRequest("http://localhost:3000/frontman")
      let result = await mw(req)

      switch result {
      | Some(response) =>
        t
        ->expect(response.headers->WebAPI.Headers.get("Access-Control-Allow-Origin"))
        ->Expect.toEqual(Null.Value("*"))
      | None => failwith("Expected Some(response)")
      }
    })
  })

  describe("tools route (GET /frontman/tools)", _t => {
    testAsync("returns JSON with tools", async t => {
      let mw = Helpers.createTestMiddleware()
      let req = Helpers.makeGetRequest("http://localhost:3000/frontman/tools")
      let result = await mw(req)

      switch result {
      | Some(response) =>
        t
        ->expect(response.headers->WebAPI.Headers.get("Content-Type"))
        ->Expect.toEqual(Null.Value("application/json"))
        let body = await response->WebAPI.Response.text
        let json = JSON.parseOrThrow(body)
        let obj = json->JSON.Decode.object->Option.getOrThrow
        t->expect(obj->Dict.get("tools")->Option.isSome)->Expect.toBe(true)
        // Verify server name comes from adapter config
        let serverInfo =
          obj->Dict.get("serverInfo")->Option.flatMap(JSON.Decode.object)->Option.getOrThrow
        t
        ->expect(serverInfo->Dict.get("name")->Option.flatMap(JSON.Decode.string))
        ->Expect.toEqual(Some("test-nextjs"))
      | None => failwith("Expected Some(response) for GET /frontman/tools")
      }
    })
  })

  describe("CORS preflight", _t => {
    testAsync("OPTIONS /frontman returns 204", async t => {
      let mw = Helpers.createTestMiddleware()
      let req = Helpers.makeOptionsRequest("http://localhost:3000/frontman")
      let result = await mw(req)

      switch result {
      | Some(response) =>
        t->expect(response.status)->Expect.toBe(204)
        t
        ->expect(response.headers->WebAPI.Headers.get("Access-Control-Allow-Origin"))
        ->Expect.toEqual(Null.Value("*"))
      | None => failwith("Expected Some(response) for OPTIONS /frontman")
      }
    })

    testAsync("OPTIONS returns None for non-frontman route", async t => {
      let mw = Helpers.createTestMiddleware()
      let req = Helpers.makeOptionsRequest("http://localhost:3000/api/data")
      let result = await mw(req)

      t->expect(result->Option.isNone)->Expect.toBe(true)
    })
  })

  describe("tool call route", _t => {
    testAsync("POST /frontman/tools/call returns SSE stream", async t => {
      let mw = Helpers.createTestMiddleware()
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
      let req = Helpers.makePostRequest("http://localhost:3000/frontman/tools/call", body)
      let result = await mw(req)

      switch result {
      | Some(response) =>
        t
        ->expect(response.headers->WebAPI.Headers.get("Content-Type"))
        ->Expect.toEqual(Null.Value("text/event-stream"))
      | None => failwith("Expected Some(response) for POST /frontman/tools/call")
      }
    })

    testAsync("POST /frontman/tools/call returns 400 for bad request", async t => {
      let mw = Helpers.createTestMiddleware()
      let body = JSON.Encode.string("invalid")
      let req = Helpers.makePostRequest("http://localhost:3000/frontman/tools/call", body)
      let result = await mw(req)

      switch result {
      | Some(response) => t->expect(response.status)->Expect.toBe(400)
      | None => failwith("Expected Some(response) for invalid POST")
      }
    })
  })
})
