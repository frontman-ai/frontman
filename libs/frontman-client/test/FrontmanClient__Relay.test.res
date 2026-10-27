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
    ->expect(
      response.tools
      ->Array.get(0)
      ->Option.map(tool => tool->S.decodeOrThrow(~from=Relay.Types.remoteToolSchema, ~to=S.json)),
    )
    ->Expect.toEqual(
      Some(
        JSON.parseOrThrow(`{
        "name":"wp_list_posts",
        "description":"List posts",
        "inputSchema":{"type":"object"},
        "_meta":{"ai.frontman/tool-metadata":{"access":"read","visibleToAgent":true}}
      }`),
      ),
    )
  })

  test("rejects missing, empty, and non-string v2 tool names", t => {
    ["", `"name":"",`, `"name":123,`]->Array.forEach(
      name => {
        let json = JSON.parseOrThrow(
          `{
        "tools":[{${name}"inputSchema":{"type":"object"},"_meta":{"ai.frontman/tool-metadata":{"access":"read","visibleToAgent":true}}}],
        "serverInfo":{"name":"test","version":"1"},"protocolVersion":"2.0"
      }`,
        )
        t->expect(json->Relay.parseToolsResponse->Result.isError)->Expect.toBe(true)
      },
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

testAsync("preserves relayed MCP tool metadata and parses legacy results", async t => {
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
  let config = Relay.makeConfig(~baseUrl="http://localhost", ~fetch=async (_, _) =>
    WebAPI.Response.fromString(
      `{"tools":[${JSON.stringify(
          tool,
        )}],"serverInfo":{"name":"test","version":"1"},"protocolVersion":"2.0"}`,
    )
  )
  let controller = WebAPI.AbortController.make()
  let relay = (await Relay.connect(config, ~signal=controller.signal))->Result.getOrThrow

  t
  ->expect(relay->Relay.getToolsJson->Array.get(0))
  ->Expect.toEqual(Some(tool))
  t->expect((relay.tools->Array.get(0)->Option.getOrThrow).name)->Expect.toBe("tool")
  t->expect(relay->Relay.hasTool("tool"))->Expect.toBe(true)
  t->expect(relay->Relay.hasTool("missing"))->Expect.toBe(false)
  JSON.parseOrThrow(`{"content":[]}`)
  ->S.parseOrThrow(~to=FrontmanClient__MCP__Types.callToolResultSchema)
  ->ignore
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

testAsync("isolates running tool cancellation from the relay and sibling calls", async t => {
  let connection = WebAPI.AbortController.make()
  let first = WebAPI.AbortController.make()
  let second = WebAPI.AbortController.make()
  let requests = ref([])
  let complete = ref([])
  let config = Relay.makeConfig(~baseUrl="http://localhost", ~fetch=(url, init) =>
    switch url->String.endsWith("/tools/call") {
    | false =>
      Promise.resolve(
        WebAPI.Response.fromString(`{"tools":[],"serverInfo":{"name":"test","version":"1"},"protocolVersion":"2.0"}`),
      )
    | true =>
      let signal = init.signal->Option.getOrThrow->Null.getOrThrow
      requests := requests.contents->Array.concat([signal])
      Promise.make((resolve, _) => complete := complete.contents->Array.concat([resolve]))
    }
  )
  let relay = (await Relay.connect(config, ~signal=connection.signal))->Result.getOrThrow
  let pendingFirst = Relay.executeTool(relay, ~name="write", ~signal=first.signal)
  let pendingSecond = Relay.executeTool(relay, ~name="read", ~signal=second.signal)
  t->expect(requests.contents->Array.length)->Expect.toBe(2)
  WebAPI.AbortController.abort(first)
  WebAPI.AbortController.abort(first)
  t->expect((requests.contents->Array.get(0)->Option.getOrThrow).aborted)->Expect.toBe(true)
  t->expect((requests.contents->Array.get(1)->Option.getOrThrow).aborted)->Expect.toBe(false)
  t->expect(connection.signal.aborted)->Expect.toBe(false)
  complete.contents->Array.forEach(resolve =>
    resolve(
      WebAPI.Response.fromString(`event: result\ndata: {"resultType":"complete","content":[{"type":"text","text":"done"}]}\n\n`),
    )
  )
  let results = await Promise.all([pendingFirst, pendingSecond])
  t->expect(results->Array.every(Result.isOk))->Expect.toBe(true)
})

testAsync("does not dispatch a pre-cancelled request and still cancels on disconnect", async t => {
  let connection = WebAPI.AbortController.make()
  let request = WebAPI.AbortController.make()
  let calls = ref(0)
  let active = ref(None)
  let complete = ref(_ => ())
  let config = Relay.makeConfig(~baseUrl="http://localhost", ~fetch=(url, init) =>
    switch url->String.endsWith("/tools/call") {
    | false =>
      Promise.resolve(
        WebAPI.Response.fromString(`{"tools":[],"serverInfo":{"name":"test","version":"1"},"protocolVersion":"2.0"}`),
      )
    | true =>
      calls := calls.contents + 1
      active := Some(init.signal->Option.getOrThrow->Null.getOrThrow)
      Promise.make((resolve, _) => complete := resolve)
    }
  )
  let relay = (await Relay.connect(config, ~signal=connection.signal))->Result.getOrThrow
  WebAPI.AbortController.abort(request)
  t
  ->expect(await Relay.executeTool(relay, ~name="write", ~signal=request.signal))
  ->Expect.toEqual(Error("Relay tool request cancelled before dispatch"))
  t->expect(calls.contents)->Expect.toBe(0)
  let running = Relay.executeTool(relay, ~name="read", ~signal=WebAPI.AbortController.make().signal)
  WebAPI.AbortController.abort(connection)
  t->expect((active.contents->Option.getOrThrow).aborted)->Expect.toBe(true)
  complete.contents(WebAPI.Response.fromString(`event: result\ndata: {"content":[]}\n\n`))
  (await running)->ignore
})
