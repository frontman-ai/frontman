open Vitest

module CORS = FrontmanCore__CORS

describe("CORS", _t => {
  describe("corsHeaders", _t => {
    test("includes Access-Control-Allow-Origin wildcard", t => {
      t
      ->expect(CORS.corsHeaders->Dict.get("Access-Control-Allow-Origin"))
      ->Expect.toEqual(Some("*"))
    })

    test("includes Access-Control-Allow-Methods", t => {
      t
      ->expect(CORS.corsHeaders->Dict.get("Access-Control-Allow-Methods"))
      ->Expect.toEqual(Some("GET, POST, OPTIONS"))
    })

    test("includes Access-Control-Allow-Headers", t => {
      t
      ->expect(CORS.corsHeaders->Dict.get("Access-Control-Allow-Headers"))
      ->Expect.toEqual(Some("Content-Type"))
    })
  })

  describe("handlePreflight", _t => {
    test("returns 204 No Content status", t => {
      let response = CORS.handlePreflight()
      t->expect(response.status)->Expect.toBe(204)
    })

    test("response includes CORS headers", t => {
      let response = CORS.handlePreflight()
      t
      ->expect(response.headers->WebAPI.Headers.get("Access-Control-Allow-Origin"))
      ->Expect.toEqual(Null.Value("*"))
    })

    test("response includes allowed methods header", t => {
      let response = CORS.handlePreflight()
      t
      ->expect(response.headers->WebAPI.Headers.get("Access-Control-Allow-Methods"))
      ->Expect.toEqual(Null.Value("GET, POST, OPTIONS"))
    })
  })

  describe("withCors", _t => {
    test("adds CORS headers to an existing response", t => {
      let original = WebAPI.Response.fromString("hello", ~init={status: 200})
      let corsed = CORS.withCors(original)

      t
      ->expect(corsed.headers->WebAPI.Headers.get("Access-Control-Allow-Origin"))
      ->Expect.toEqual(Null.Value("*"))
    })

    test("preserves original response status", t => {
      let original = WebAPI.Response.fromString("not found", ~init={status: 404})
      let corsed = CORS.withCors(original)

      t->expect(corsed.status)->Expect.toBe(404)
    })

    test("preserves existing headers on the response", t => {
      let headers = WebAPI.HeadersInit.fromDict(
        Dict.fromArray([("X-Custom", "value")]),
      )
      let original = WebAPI.Response.fromString("ok", ~init={status: 200, headers})
      let corsed = CORS.withCors(original)

      t
      ->expect(corsed.headers->WebAPI.Headers.get("X-Custom"))
      ->Expect.toEqual(Null.Value("value"))
      t
      ->expect(corsed.headers->WebAPI.Headers.get("Access-Control-Allow-Origin"))
      ->Expect.toEqual(Null.Value("*"))
    })
  })
})
