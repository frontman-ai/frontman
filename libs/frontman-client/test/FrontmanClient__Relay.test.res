open Vitest

module Relay = FrontmanClient__Relay

describe("Relay.connect", _t => {
  test("accepts only the current relay protocol version", t => {
    let json = JSON.parseOrThrow(`{"tools":[],"serverInfo":{"name":"test","version":"1"},"protocolVersion":"1.0"}`)
    t
    ->expect(() => json->S.parseOrThrow(~to=FrontmanClient__Relay__Types.toolsResponseSchema))
    ->Expect.toThrow
  })

  test("normalizes WordPress relay v1 responses", t => {
    let json = JSON.parseOrThrow(`{
      "tools":[{
        "name":"wp_list_posts",
        "description":"List posts",
        "access":"read",
        "inputSchema":{"type":"object"},
        "visibleToAgent":true
      }],
      "serverInfo":{"name":"frontman-wordpress","version":"4.0.0"},
      "protocolVersion":"1.0"
    }`)
    let response = json->Relay.parseToolsResponse->Result.getOrThrow

    t->expect(response.protocolVersion)->Expect.toBe("2.0")
    t
    ->expect(response.tools->Array.get(0)->Option.map(json => JSON.stringify(json)))
    ->Expect.toEqual(
      Some(
        JSON.stringify(
          JSON.parseOrThrow(`{
            "name":"wp_list_posts",
            "description":"List posts",
            "inputSchema":{"type":"object"},
            "_meta":{"ai.frontman/tool-metadata":{"access":"read","visibleToAgent":true}}
          }`),
        ),
      ),
    )
  })

  test("requires relay v2 tool metadata shape", t => {
    let legacy = JSON.parseOrThrow(`{
      "tools":[{"name":"hidden","inputSchema":{"type":"object"},"access":"read","visibleToAgent":false}],
      "serverInfo":{"name":"test","version":"1"},
      "protocolVersion":"2.0"
    }`)
    let current = JSON.parseOrThrow(`{
      "tools":[{"name":"hidden","inputSchema":{"type":"object"},"_meta":{"ai.frontman/tool-metadata":{"access":"read","visibleToAgent":false}}}],
      "serverInfo":{"name":"test","version":"1"},
      "protocolVersion":"2.0"
    }`)

    t
    ->expect(() => legacy->S.parseOrThrow(~to=FrontmanClient__Relay__Types.toolsResponseSchema))
    ->Expect.toThrow
    current->S.parseOrThrow(~to=FrontmanClient__Relay__Types.toolsResponseSchema)->ignore
  })
})

testAsync("preserves tool metadata and round-trips legacy SSE results", async t => {
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
  let resultBody = ref("")
  let requests = []
  let config = Relay.makeConfig(~baseUrl="http://localhost", ~fetch=async (url, _) => {
    requests->Array.push(url)
    switch url {
    | "http://localhost/frontman/tools" =>
      WebAPI.Response.fromString(
        `{"tools":[${JSON.stringify(
            tool,
          )}],"serverInfo":{"name":"test","version":"1"},"protocolVersion":"2.0"}`,
      )
    | "http://localhost/frontman/tools/call" =>
      WebAPI.Response.fromString(`event: result\ndata: ${resultBody.contents}\n\n`)
    | _ => JsError.throwWithMessage(`Unexpected relay URL: ${url}`)
    }
  })
  let controller = WebAPI.AbortController.make()
  let relay = (await Relay.connect(config, ~signal=controller.signal))->Result.getOrThrow

  t
  ->expect(relay->Relay.getToolsJson->Array.get(0)->Option.map(json => JSON.stringify(json)))
  ->Expect.toEqual(Some(JSON.stringify(tool)))
  t->expect(relay->Relay.hasTool("tool"))->Expect.toBe(true)
  let values = ["null", "0", "false"]
  for index in 0 to values->Array.length - 1 {
    let value = values->Array.getUnsafe(index)
    let fields = `"content":[{"type":"text","text":"relay result"}],"structuredContent":${value},"_meta":{"vendor/result":{"tag":"kept"},"progressToken":0}`
    resultBody := `{${fields}}`
    let result = (await Relay.executeTool(relay, ~name="tool"))->Result.getOrThrow
    let encoded =
      result->S.decodeOrThrow(~from=FrontmanClient__MCP__Types.callToolResultSchema, ~to=S.json)
    t->expect(encoded)->Expect.toEqual(JSON.parseOrThrow(`{"resultType":"complete",${fields}}`))
  }
  t
  ->expect(requests)
  ->Expect.toEqual([
    "http://localhost/frontman/tools",
    "http://localhost/frontman/tools/call",
    "http://localhost/frontman/tools/call",
    "http://localhost/frontman/tools/call",
  ])
  WebAPI.AbortController.abort(controller)
  t
  ->expect(await Relay.executeTool(relay, ~name="tool"))
  ->Expect.toEqual(Error("Relay connection aborted"))
})

testAsync("does not expose a connected relay after cancellation", async t => {
  let controller = WebAPI.AbortController.make()
  let config = Relay.makeConfig(~baseUrl="http://localhost", ~fetch=async (_, _) => {
    WebAPI.AbortController.abort(controller)
    WebAPI.Response.fromString(`{"tools":[],"serverInfo":{"name":"test","version":"1"},"protocolVersion":"2.0"}`)
  })
  t
  ->expect(await Relay.connect(config, ~signal=controller.signal))
  ->Expect.toEqual(Error("Relay connection aborted"))
})
