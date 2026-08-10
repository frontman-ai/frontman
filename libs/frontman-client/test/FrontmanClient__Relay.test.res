open Vitest

module Relay = FrontmanClient__Relay

describe("Relay.connect", _t => {
  testAsync("sets state to Error when server is unreachable", async t => {
    let relay = Relay.make(~baseUrl="http://localhost:19999")
    let result = await Relay.connectDetailed(relay)

    switch Relay.getState(relay) {
    | Error(_) => t->expect(true)->Expect.toBe(true)
    | _ => t->expect(false)->Expect.toBe(true)
    }
    switch result {
    | Error({reason: NetworkError}) => t->expect(true)->Expect.toBe(true)
    | _ => t->expect(false)->Expect.toBe(true)
    }
  })

  testAsync("classifies an aborted connection separately", async t => {
    let controller = WebAPI.AbortController.make()
    WebAPI.AbortController.abort(controller)
    let relay = Relay.make(~baseUrl="http://localhost:19999")

    switch await Relay.connectDetailed(relay, ~signal=controller.signal) {
    | Error({reason: Aborted}) => t->expect(true)->Expect.toBe(true)
    | _ => t->expect(false)->Expect.toBe(true)
    }
  })
})

test("preserves optional output schemas in MCP tool definitions", t => {
  let relay = Relay.make(~baseUrl="http://localhost")
  let tool = (~name, ~outputSchema): FrontmanClient__Relay__Types.remoteTool => {
    name,
    description: name,
    access: None,
    inputSchema: JSON.Encode.object(Dict.make()),
    outputSchema,
    visibleToAgent: true,
  }
  relay.state :=
    Relay.Connected({
      tools: [
        tool(~name="structured", ~outputSchema=Some(JSON.Encode.object(Dict.make()))),
        tool(~name="content_only", ~outputSchema=None),
      ],
      serverInfo: {name: "test", version: "1"},
    })

  let definitions = relay->Relay.getToolsJson->Array.map(json => JSON.stringify(json))
  t->expect(definitions[0]->Option.getOrThrow->String.includes("outputSchema"))->Expect.toBe(true)
  t->expect(definitions[1]->Option.getOrThrow->String.includes("outputSchema"))->Expect.toBe(false)
})
