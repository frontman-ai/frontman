open Vitest

module SSE = FrontmanCore__SSE
module MCP = FrontmanAiFrontmanProtocol.FrontmanProtocol__MCP

describe("SSE", _t => {
  test("formats progress event correctly", t => {
    let event = SSE.progressEvent(~progress="50%")

    t->expect(event->String.includes("event: progress"))->Expect.toBe(true)
    t->expect(event->String.includes("data:"))->Expect.toBe(true)
    t->expect(event->String.includes("50%"))->Expect.toBe(true)
  })

  test("formats result event correctly", t => {
    let result = MCP.CallToolResult.makeText("hello")
    let event = SSE.resultEvent(result)

    t->expect(event->String.includes("event: result"))->Expect.toBe(true)
    t->expect(event->String.includes("hello"))->Expect.toBe(true)
  })

  test("sends changed beside structuredContent in the SSE result payload", t => {
    let result = MCP.CallToolResult.makeTextWithStructured("edited", Dict.make(), ~changed=true)
    let data = SSE.resultEvent(result)->String.split("\n")->Array.get(1)->Option.getOrThrow
    let payload = data->String.split("data: ")->Array.get(1)->Option.getOrThrow->JSON.parseOrThrow
    t->expect(payload)->Expect.toEqual(JSON.parseOrThrow(
      `{"resultType":"complete","content":[{"type":"text","text":"edited"}],"structuredContent":{},"changed":true}`,
    ))
  })
})
