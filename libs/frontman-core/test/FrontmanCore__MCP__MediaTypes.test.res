open Vitest

module MediaTypes = FrontmanCore__MCP__MediaTypes

module Helpers = {
  let headers = entries => WebAPI.Headers.fromKeyValueArray(entries)

  let valid = (~contentType="application/json", ~accept="application/json, text/event-stream") =>
    headers([("Content-Type", contentType), ("Accept", accept)])
}

describe("MCP Streamable HTTP media types", _t => {
  test("accepts JSON requests with both response media types", t => {
    [
      Helpers.valid(),
      Helpers.valid(
        ~contentType="Application/Json; charset=utf-8",
        ~accept="TEXT/EVENT-STREAM; q=0.5, APPLICATION/JSON; q=1.0",
      ),
      Helpers.valid(
        ~accept="application/problem+json; profile=\"a,b\", application/json, text/event-stream; q=0.001",
      ),
    ]->Array.forEach(headers => t->expect(MediaTypes.validate(headers))->Expect.toEqual(Ok()))
  })

  test("rejects missing and unsupported request content types", t => {
    [
      Helpers.headers([("Accept", "application/json, text/event-stream")]),
      Helpers.valid(~contentType="text/plain"),
      Helpers.valid(~contentType="application/problem+json"),
      Helpers.valid(~contentType="application/json, text/plain"),
      Helpers.valid(~contentType="application/json;"),
      Helpers.valid(~contentType="application/json; foo=x, text/plain"),
      Helpers.valid(~contentType="application/json; charset=iso-8859-1"),
    ]->Array.forEach(
      headers =>
        t
        ->expect(MediaTypes.validate(headers))
        ->Expect.toEqual(Error(MediaTypes.UnsupportedMediaType)),
    )
  })

  test("rejects missing or incomplete response media offers", t => {
    [
      Helpers.headers([("Content-Type", "application/json")]),
      Helpers.valid(~accept="application/json"),
      Helpers.valid(~accept="text/event-stream"),
      Helpers.valid(~accept="*/*"),
      Helpers.valid(~accept="application/*, text/*"),
      Helpers.valid(~accept="application/json; profile=modern, text/event-stream"),
      Helpers.valid(~accept="application/json; profile=\"a;q=0\", text/event-stream"),
      Helpers.valid(~accept="text/plain; note=\",text/event-stream,\", application/json"),
      Helpers.valid(~accept="application/json, text/plain; note=\"text/event-stream"),
    ]->Array.forEach(
      headers =>
        t->expect(MediaTypes.validate(headers))->Expect.toEqual(Error(MediaTypes.NotAcceptable)),
    )
  })

  test("rejects unavailable or malformed quality weights", t => {
    [
      "application/json; q=0, text/event-stream",
      "application/json, text/event-stream; q=0.000",
      "application/json; q=1.1, text/event-stream",
      "application/json, text/event-stream; q=wat",
      "application/json, text/event-stream; q=0.0001",
      "application/json; q, text/event-stream",
      "application/json; q=0=1, text/event-stream",
      "application/json; q=1; q=0, text/event-stream",
    ]->Array.forEach(
      accept =>
        t
        ->expect(MediaTypes.validate(Helpers.valid(~accept)))
        ->Expect.toEqual(Error(MediaTypes.NotAcceptable)),
    )
  })

  test("validates content type before accept", t => {
    let headers = Helpers.headers([("Content-Type", "text/plain"), ("Accept", "text/plain")])

    t
    ->expect(MediaTypes.validate(headers))
    ->Expect.toEqual(Error(MediaTypes.UnsupportedMediaType))
  })
})
