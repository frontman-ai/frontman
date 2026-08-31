open Vitest

module Relay = FrontmanClient__Relay

let jsonString = json => JSON.stringify(json)

describe("Relay.connect", _t => {
  test("rejects incompatible protocol versions", t => {
    let json = JSON.parseOrThrow(`{"tools":[],"serverInfo":{"name":"test","version":"1"},"protocolVersion":"2.0"}`)
    t
    ->expect(() => json->S.parseOrThrow(~to=FrontmanClient__Relay__Types.toolsResponseSchema))
    ->Expect.toThrow
  })
})

test("preserves relayed MCP tool metadata and parses legacy results", t => {
  let relay = Relay.make(~baseUrl="http://localhost")
  let tool = JSON.parseOrThrow(`{
    "name":"tool",
    "title":"Tool",
    "description":"tool",
    "icons":[{"src":"data:image/png;base64,AA==","theme":"light"}],
    "inputSchema":{"type":"object"},
    "outputSchema":{"type":"object"},
    "annotations":{"title":"Tool annotation","readOnlyHint":true},
    "_meta":{"ai.frontman/tool-metadata":{"visibleToAgent":true,"access":"read"},"vendor/example":{"x":1}}
  }`)
  relay.state :=
    Relay.Connected({
      tools: [tool],
      serverInfo: {name: "test", version: "1"},
    })

  t
  ->expect(relay->Relay.getToolsJson->Array.get(0)->Option.map(jsonString))
  ->Expect.toEqual(Some(JSON.stringify(tool)))
  t->expect(relay->Relay.hasTool("tool"))->Expect.toBe(true)
  JSON.parseOrThrow(`{"content":[]}`)
  ->S.parseOrThrow(~to=FrontmanClient__MCP__Types.callToolResultSchema)
  ->ignore
})
