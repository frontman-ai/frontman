open Vitest

module Endpoint = FrontmanCore__SourceLocationEndpoint
module HttpSecurity = FrontmanCore__MCP__HttpSecurity

module Helpers = {
  let allowedOrigin = "https://client.example"

  let security = HttpSecurity.make(~allowedOrigins=[allowedOrigin], ~authorize=async _headers =>
    failwith("Source-location policy invoked MCP authorization")
  )

  let config: Endpoint.config = {security: Some(security), sourceRoot: "/test/project"}

  let request = (~method="POST", ~origin=?, ~contentType=?, ~body=?) => {
    let headers = []
    let headers = switch origin {
    | Some(origin) => [("Origin", origin), ...headers]
    | None => headers
    }
    let headers = switch contentType {
    | Some(contentType) => [("Content-Type", contentType), ...headers]
    | None => headers
    }
    switch body {
    | Some(body) =>
      WebAPI.Request.fromURL(
        "http://localhost/frontman/resolve-source-location",
        ~init={
          method,
          headers: WebAPI.HeadersInit.fromKeyValueArray(headers),
          body: WebAPI.BodyInit.fromString(body),
        },
      )
    | None =>
      WebAPI.Request.fromURL(
        "http://localhost/frontman/resolve-source-location",
        ~init={method, headers: WebAPI.HeadersInit.fromKeyValueArray(headers)},
      )
    }
  }

  let preflight = (~requestedHeaders) => {
    let headers = [
      ("Origin", allowedOrigin),
      ("Access-Control-Request-Method", "POST"),
      ("Access-Control-Request-Headers", requestedHeaders),
    ]
    WebAPI.Request.fromURL(
      "http://localhost/frontman/resolve-source-location",
      ~init={method: "OPTIONS", headers: WebAPI.HeadersInit.fromKeyValueArray(headers)},
    )
  }
}

describe("SourceLocationEndpoint", _t => {
  testAsync("rejects a missing Origin before reading the body", async t => {
    let request = Helpers.request(~contentType="application/json", ~body="not json")
    let response = await Endpoint.dispatch(~config=Helpers.config, request)

    t->expect(response.status)->Expect.toBe(403)
    t->expect(request.bodyUsed)->Expect.toBe(false)
    t
    ->expect(
      response.headers
      ->WebAPI.Headers.get("Access-Control-Allow-Origin")
      ->Null.toOption
      ->Option.isNone,
    )
    ->Expect.toBe(true)
  })

  testAsync("rejects an unlisted Origin before reading the body", async t => {
    let request = Helpers.request(
      ~origin="https://attacker.example",
      ~contentType="application/json",
      ~body="not json",
    )
    let response = await Endpoint.dispatch(~config=Helpers.config, request)

    t->expect(response.status)->Expect.toBe(403)
    t->expect(request.bodyUsed)->Expect.toBe(false)
  })

  testAsync("fails closed when source-location security is not configured", async t => {
    let request = Helpers.request(
      ~origin=Helpers.allowedOrigin,
      ~contentType="application/json",
      ~body="not json",
    )
    let response = await Endpoint.dispatch(
      ~config={security: None, sourceRoot: "/test/project"},
      request,
    )

    t->expect(response.status)->Expect.toBe(403)
    t->expect(request.bodyUsed)->Expect.toBe(false)
  })

  testAsync("returns an Origin-only preflight response", async t => {
    let response = await Endpoint.dispatch(
      ~config=Helpers.config,
      Helpers.preflight(~requestedHeaders="CONTENT-TYPE"),
    )

    t->expect(response.status)->Expect.toBe(204)
    t
    ->expect(response.headers->WebAPI.Headers.get("Access-Control-Allow-Origin"))
    ->Expect.toEqual(Null.Value(Helpers.allowedOrigin))
    t
    ->expect(
      response.headers
      ->WebAPI.Headers.get("Access-Control-Allow-Credentials")
      ->Null.toOption
      ->Option.isNone,
    )
    ->Expect.toBe(true)
    t
    ->expect(response.headers->WebAPI.Headers.get("Access-Control-Allow-Headers"))
    ->Expect.toEqual(Null.Value("Content-Type"))
  })

  testAsync("rejects unsupported preflight headers", async t => {
    let response = await Endpoint.dispatch(
      ~config=Helpers.config,
      Helpers.preflight(~requestedHeaders="Content-Type, Authorization"),
    )

    t->expect(response.status)->Expect.toBe(400)
    t
    ->expect(response.headers->WebAPI.Headers.get("Access-Control-Allow-Origin"))
    ->Expect.toEqual(Null.Value(Helpers.allowedOrigin))
  })

  testAsync("rejects unsupported media before reading the body", async t => {
    let request = Helpers.request(
      ~origin=Helpers.allowedOrigin,
      ~contentType="text/plain",
      ~body="not json",
    )
    let response = await Endpoint.dispatch(~config=Helpers.config, request)

    t->expect(response.status)->Expect.toBe(415)
    t->expect(request.bodyUsed)->Expect.toBe(false)
    t
    ->expect(response.headers->WebAPI.Headers.get("Access-Control-Allow-Origin"))
    ->Expect.toEqual(Null.Value(Helpers.allowedOrigin))
  })

  testAsync("maps malformed JSON through the shared bounded decoder", async t => {
    let request = Helpers.request(
      ~origin=Helpers.allowedOrigin,
      ~contentType="application/json; charset=utf-8",
      ~body="{",
    )
    let response = await Endpoint.dispatch(~config=Helpers.config, request)

    t->expect(response.status)->Expect.toBe(400)
    let body = await response->WebAPI.Response.text
    t->expect(body->String.includes("Invalid request"))->Expect.toBe(true)
  })

  testAsync("rejects a declared oversized body before reading it", async t => {
    let request = WebAPI.Request.fromURL(
      "http://localhost/frontman/resolve-source-location",
      ~init={
        method: "POST",
        headers: WebAPI.HeadersInit.fromKeyValueArray([
          ("Origin", Helpers.allowedOrigin),
          ("Content-Type", "application/json"),
          ("Content-Length", "2097153"),
        ]),
        body: WebAPI.BodyInit.fromString("{}"),
      },
    )
    let response = await Endpoint.dispatch(~config=Helpers.config, request)

    t->expect(response.status)->Expect.toBe(413)
    t
    ->expect(response.headers->WebAPI.Headers.get("Access-Control-Allow-Origin"))
    ->Expect.toEqual(Null.Value(Helpers.allowedOrigin))
  })

  testAsync("returns 405 for an allowed Origin using another method", async t => {
    let response = await Endpoint.dispatch(
      ~config=Helpers.config,
      Helpers.request(~method="GET", ~origin=Helpers.allowedOrigin),
    )

    t->expect(response.status)->Expect.toBe(405)
    t
    ->expect(response.headers->WebAPI.Headers.get("Allow"))
    ->Expect.toEqual(Null.Value("POST, OPTIONS"))
  })
})
