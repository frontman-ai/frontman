open Vitest

module Middleware = FrontmanNextjs__Middleware
module Config = FrontmanNextjs__Config

module Helpers = {
  let createTestMiddleware = () => {
    let configInput: Config.jsConfigInput = {
      projectRoot: "/test/project",
      sourceRoot: "/test/project",
      basePath: "frontman",
      serverName: "test-nextjs",
      serverVersion: "1.0.0",
      host: "localhost:3000",
      clientUrl: "http://localhost:3000/client.js?clientName=nextjs&host=localhost:3000",
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
    test(
      "returns a function",
      t => {
        let mw = Helpers.createTestMiddleware()
        t->expect(typeof(mw) == #function)->Expect.toBe(true)
      },
    )
  })

  describe("pass-through", _t => {
    testAsync(
      "returns None for non-frontman routes",
      async t => {
        let mw = Helpers.createTestMiddleware()
        let req = Helpers.makeGetRequest("http://localhost:3000/api/users")
        let result = await mw(req)

        t->expect(result->Option.isNone)->Expect.toBe(true)
      },
    )

    testAsync(
      "returns None for root path",
      async t => {
        let mw = Helpers.createTestMiddleware()
        let req = Helpers.makeGetRequest("http://localhost:3000/")
        let result = await mw(req)

        t->expect(result->Option.isNone)->Expect.toBe(true)
      },
    )

    testAsync(
      "keeps MCP POST and preflight unregistered",
      async t => {
        let mw = Helpers.createTestMiddleware()
        let post = Helpers.makePostRequest(
          "http://localhost:3000/mcp",
          JSON.Encode.object(Dict.make()),
        )
        let nested = Helpers.makePostRequest(
          "http://localhost:3000/frontman/mcp",
          JSON.Encode.object(Dict.make()),
        )
        let options = Helpers.makeOptionsRequest("http://localhost:3000/mcp")
        let customBaseMiddleware = Middleware.createMiddleware({
          projectRoot: "/test/project",
          sourceRoot: "/test/project",
          basePath: "fm",
          host: "localhost:3000",
          clientUrl: "http://localhost:3000/client.js?clientName=nextjs&host=localhost:3000",
        })
        let customBase = Helpers.makePostRequest(
          "http://localhost:3000/fm/mcp",
          JSON.Encode.object(Dict.make()),
        )

        t->expect((await mw(post))->Option.isNone)->Expect.toBe(true)
        t->expect((await mw(nested))->Option.isNone)->Expect.toBe(true)
        t->expect((await mw(options))->Option.isNone)->Expect.toBe(true)
        t->expect((await customBaseMiddleware(customBase))->Option.isNone)->Expect.toBe(true)
        t->expect(post.bodyUsed)->Expect.toBe(false)
        t->expect(nested.bodyUsed)->Expect.toBe(false)
        t->expect(customBase.bodyUsed)->Expect.toBe(false)
      },
    )

    testAsync(
      "does not own the removed legacy tool routes",
      async t => {
        let mw = Helpers.createTestMiddleware()
        let get = Helpers.makeGetRequest("http://localhost:3000/frontman/tools")
        let post = Helpers.makePostRequest(
          "http://localhost:3000/frontman/tools/call",
          JSON.Encode.object(Dict.make()),
        )
        let options = Helpers.makeOptionsRequest("http://localhost:3000/frontman/tools")

        t->expect((await mw(get))->Option.isNone)->Expect.toBe(true)
        t->expect((await mw(post))->Option.isNone)->Expect.toBe(true)
        t->expect((await mw(options))->Option.isNone)->Expect.toBe(true)
        t->expect(post.bodyUsed)->Expect.toBe(false)
      },
    )
  })

  describe("UI route (GET /frontman)", _t => {
    testAsync(
      "returns HTML response",
      async t => {
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
      },
    )

    testAsync(
      "HTML includes CORS headers",
      async t => {
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
      },
    )
  })

  describe("CORS preflight", _t => {
    testAsync(
      "OPTIONS /frontman returns 204",
      async t => {
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
      },
    )

    testAsync(
      "OPTIONS returns None for non-frontman route",
      async t => {
        let mw = Helpers.createTestMiddleware()
        let req = Helpers.makeOptionsRequest("http://localhost:3000/api/data")
        let result = await mw(req)

        t->expect(result->Option.isNone)->Expect.toBe(true)
      },
    )
  })
})
