open Vitest

module BodyDecoder = FrontmanCore__MCP__BodyDecoder
module BodyReader = FrontmanCore__MCP__BodyReader
module RequestBody = FrontmanCore__MCP__RequestBody

module Helpers = {
  let request = (~body=?, ~headers=[]) => {
    let headers = WebAPI.HeadersInit.fromKeyValueArray(headers)
    switch body {
    | Some(body) =>
      WebAPI.Request.fromURL(
        "http://localhost/mcp",
        ~init={method: "POST", headers, body: WebAPI.BodyInit.fromString(body)},
      )
    | None => WebAPI.Request.fromURL("http://localhost/mcp", ~init={method: "POST", headers})
    }
  }
}

describe("MCP Web Request body boundary", _t => {
  testAsync("reads and decodes one arbitrary-root JSON value", async t => {
    let source = `[1,true,null,"世界"]`
    let request = Helpers.request(~body=source)

    let result = await RequestBody.decode(request)

    t->expect(result->Result.getOrThrow->JSON.stringify)->Expect.toBe(source)
    t->expect(request.bodyUsed)->Expect.toBe(true)
  })

  testAsync("preserves body-reader errors", async t => {
    let request = Helpers.request(
      ~body=`{}`,
      ~headers=[("Content-Length", Int.toString(BodyDecoder.maxBodyBytes + 1))],
    )

    let result = await RequestBody.decode(request)

    t
    ->expect(result)
    ->Expect.toEqual(Error(RequestBody.ReaderError(BodyReader.BodyTooLarge)))
    t->expect(request.bodyUsed)->Expect.toBe(false)
  })

  testAsync("preserves body-decoder errors", async t => {
    let request = Helpers.request(~body=`{"value":}`)

    let result = await RequestBody.decode(request)

    t
    ->expect(result)
    ->Expect.toEqual(Error(RequestBody.DecoderError(BodyDecoder.InvalidJson)))
    t->expect(request.bodyUsed)->Expect.toBe(true)
  })

  testAsync("rejects a missing body without inventing an empty stream", async t => {
    let request = Helpers.request()

    let result = await RequestBody.decode(request)

    t->expect(result)->Expect.toEqual(Error(RequestBody.MissingBody))
    t->expect(request.bodyUsed)->Expect.toBe(false)
  })

  testAsync("rejects an already-consumed body before reader acquisition", async t => {
    let request = Helpers.request(~body=`{}`)
    let _ = await request->WebAPI.Request.text

    let result = await RequestBody.decode(request)

    t->expect(result)->Expect.toEqual(Error(RequestBody.BodyAlreadyUsed))
  })
})
