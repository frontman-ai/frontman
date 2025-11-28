open Vitest

module SSE = FrontmanNextjs__SSE
module MCP = AskTheLlmFrontmanProtocol.FrontmanProtocol__MCP

describe("SSE", _t => {
  test("formats progress event correctly", t => {
    let event = SSE.progressEvent(~progress="50%")

    t->expect(event->String.includes("event: progress"))->Expect.toBe(true)
    t->expect(event->String.includes("data:"))->Expect.toBe(true)
    t->expect(event->String.includes("50%"))->Expect.toBe(true)
  })

  test("formats result event correctly", t => {
    let result: MCP.callToolResult = {
      content: [{type_: "text", text: "hello"}],
      isError: None,
    }
    let event = SSE.resultEvent(result)

    t->expect(event->String.includes("event: result"))->Expect.toBe(true)
    t->expect(event->String.includes("hello"))->Expect.toBe(true)
  })
})
