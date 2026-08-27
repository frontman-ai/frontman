open Vitest

module Relay = FrontmanClient__Relay

describe("Relay.connect", _t => {
  test("rejects incompatible protocol versions", t => {
    let json = JSON.parseOrThrow(`{"tools":[],"serverInfo":{"name":"test","version":"1"},"protocolVersion":"2.0"}`)
    t
    ->expect(() => json->S.parseOrThrow(~to=FrontmanClient__Relay__Types.toolsResponseSchema))
    ->Expect.toThrow
  })
})

test("preserves optional output schemas and parses legacy results", t => {
  let relay = Relay.make(~baseUrl="http://localhost")
  let tool = (outputSchema): FrontmanClient__Relay__Types.remoteTool => {
    name: "tool",
    description: "tool",
    access: None,
    inputSchema: JSON.Encode.object(Dict.make()),
    outputSchema,
    visibleToAgent: true,
  }
  relay.state :=
    Relay.Connected({
      tools: [tool(Some(JSON.Encode.object(Dict.make()))), tool(None)],
      serverInfo: {name: "test", version: "1"},
    })

  let definitions = relay->Relay.getToolsJson->Array.map(json => JSON.stringify(json))
  t->expect(definitions[0]->Option.getOrThrow->String.includes("outputSchema"))->Expect.toBe(true)
  t->expect(definitions[1]->Option.getOrThrow->String.includes("outputSchema"))->Expect.toBe(false)
  JSON.parseOrThrow(`{"content":[]}`)
  ->S.parseOrThrow(~to=FrontmanClient__MCP__Types.callToolResultSchema)
  ->ignore
})
