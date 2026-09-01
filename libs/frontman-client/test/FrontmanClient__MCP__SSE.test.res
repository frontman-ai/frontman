open Vitest

module SSE = FrontmanClient__MCP__SSE

describe("MCP SSE framing", _t => {
  test("parses LF and CRLF data frames without trimming payload data", t => {
    t
    ->expect(SSE.parseFrame("data: {\"jsonrpc\":\"2.0\"}\n\n"))
    ->Expect.toEqual(Some("{\"jsonrpc\":\"2.0\"}"))
    t
    ->expect(SSE.parseFrame(": keepalive\r\ndata:  leading  \r\n"))
    ->Expect.toEqual(Some(" leading  "))
  })

  test("joins multiple data fields and ignores comments", t => {
    t
    ->expect(SSE.parseFrame(": comment\ndata: first\ndata: second"))
    ->Expect.toEqual(Some("first\nsecond"))
  })

  test("preserves a CRLF delimiter split across chunks", t => {
    let first = `data: {"jsonrpc":"2.0"}\r`
    let (firstBlocks, firstRemainder) = SSE.takeBlocks(first)
    t->expect(firstBlocks)->Expect.toEqual([])
    let (secondBlocks, secondRemainder) = SSE.takeBlocks(firstRemainder ++ "\n\r\n")
    t->expect(secondBlocks)->Expect.toEqual([`data: {"jsonrpc":"2.0"}`])
    t->expect(secondRemainder)->Expect.toBe("")
  })

  test("rejects requests and accepts notifications or responses", t => {
    let request = SSE.classify(`{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}`)
    let notification = SSE.classify(`{"jsonrpc":"2.0","method":"notifications/progress","params":{}}`)
    let response = SSE.classify(`{"jsonrpc":"2.0","id":1,"result":{"resultType":"complete"}}`)

    t->expect(request->Result.isError)->Expect.toBe(true)
    t->expect(notification->Result.isOk)->Expect.toBe(true)
    t->expect(response->Result.isOk)->Expect.toBe(true)
  })

  test("accepts a terminal event completed by EOF", t => {
    let data = `{"jsonrpc":"2.0","id":1,"result":{"resultType":"complete"}}`
    t->expect(SSE.parseFrame(`data: ${data}`))->Expect.toEqual(Some(data))
    switch SSE.classify(data) {
    | Ok(Terminal(_)) => t->expect(true)->Expect.toBe(true)
    | Ok(Notification(_)) | Error(_) => t->expect(false)->Expect.toBe(true)
    }
  })
})

describe("bounded response JSON", _t => {
  test("accepts depth 64 and rejects depth 65", t => {
    let atLimit = "["->String.repeat(64) ++ "0" ++ "]"->String.repeat(64)
    let overLimit = "["->String.repeat(65) ++ "0" ++ "]"->String.repeat(65)
    t->expect(FrontmanClient__MCP__ResponseBody.exceedsDepth(atLimit))->Expect.toBe(false)
    t->expect(FrontmanClient__MCP__ResponseBody.exceedsDepth(overLimit))->Expect.toBe(true)
  })
})
