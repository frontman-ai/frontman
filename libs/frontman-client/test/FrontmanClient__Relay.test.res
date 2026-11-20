open Vitest

module Relay = FrontmanClient__Relay

let config = fetch => Relay.makeConfig(~baseUrl="http://localhost", ~fetch)
let toolsResponse = (~tools="[]", ~version="2.0", ()) =>
  WebAPI.Response.fromString(
    `{"tools":${tools},"serverInfo":{"name":"test","version":"1"},"protocolVersion":"${version}"}`,
  )

let connect = (fetch, controller: WebAPI.EventTypes.abortController) =>
  Relay.connect(config(fetch), ~signal=controller.signal)

let pendingUntilAbort = signal =>
  Promise.make((_, reject) => {
    FrontmanClient__ACP.onAbort(signal, () => reject(JsExn.anyToExnInternal(signal.reason)))
  })

testAsync("normalizes WordPress relay v1 tools on connect", async t => {
  let tools = `[{"name":"wp_list_posts","description":"List posts","access":"read","inputSchema":{"type":"object"},"visibleToAgent":true}]`
  let fetch = async (_, _) => toolsResponse(~tools, ~version="1.0", ())
  let relay = (await connect(fetch, WebAPI.AbortController.make()))->Result.getOrThrow
  t
  ->expect(Relay.getToolsJson(relay))
  ->Expect.toEqual([
    JSON.parseOrThrow(`{
      "name":"wp_list_posts","description":"List posts","inputSchema":{"type":"object"},
      "_meta":{"ai.frontman/tool-metadata":{"access":"read","visibleToAgent":true}}
    }`),
  ])
})

testAsync("preserves v2 MCP tool metadata on connect", async t => {
  let tool = JSON.parseOrThrow(`{
    "name":"tool","title":"Tool","description":"tool",
    "icons":[{"src":"data:image/png;base64,AA==","theme":"light"}],
    "inputSchema":{"type":"object"},"outputSchema":{"type":"object"},
    "annotations":{"title":"Tool annotation","readOnlyHint":true},
    "_meta":{"ai.frontman/tool-metadata":{"visibleToAgent":true,"access":"read"},"vendor/example":{"x":1}}
  }`)
  let fetch = async (_, _) => toolsResponse(~tools=`[${JSON.stringify(tool)}]`, ())
  let relay = (await connect(fetch, WebAPI.AbortController.make()))->Result.getOrThrow
  t->expect(Relay.getToolsJson(relay))->Expect.toEqual([tool])
})

let relayErrors = ref(None)

let captureRelayErrors = () => {
  let messages = []
  relayErrors := Some(messages)
  FrontmanLogs.Logs.addHandler({
    id: "relay-test-errors",
    run: (~component, ~stacktrace as _, ~level, message, _, _) =>
      switch (component, level, relayErrors.contents) {
      | ("Relay", Error, Some(messages)) => messages->Array.push(message)
      | _ => ()
      },
  })
  FrontmanBindings.Bindings__Test__Vitest.onTestFinished(() => relayErrors := None)
  messages
}

testAsync("does not report cancelled tools discovery as an error", async t => {
  let errors = captureRelayErrors()
  let controller = WebAPI.AbortController.make()
  let pending = connect((_, init) => {
    pendingUntilAbort(init.signal->Option.getOrThrow->Null.getOrThrow)
  }, controller)
  WebAPI.AbortController.abort(controller)
  t->expect(await pending)->Expect.toEqual(Error("Relay connection aborted"))
  t->expect(errors)->Expect.toEqual([])
})

[
  ("with a live signal", false, "Network request failed"),
  ("when disposal races it", true, "Relay connection aborted"),
]->Array.forEach(((scenario, dispose, expected)) =>
  testAsync(`logs a network rejection once ${scenario}`, async t => {
    let errors = captureRelayErrors()
    let controller = WebAPI.AbortController.make()
    let response = Promise.withResolvers()
    let pending = connect((_, _) => response.promise, controller)
    response.reject(JsExn.anyToExnInternal(JsError.make("Network request failed")))
    switch dispose {
    | true => WebAPI.AbortController.abort(controller)
    | false => ()
    }
    t->expect(await pending)->Expect.toEqual(Error(expected))
    t->expect(errors)->Expect.toEqual(["Network request failed"])
  })
)

testAsync("tool cancellation is isolated until the Relay disconnects", async t => {
  let connection = WebAPI.AbortController.make()
  let request = WebAPI.AbortController.make()
  let calls = []
  let fetch = (url, init: WebAPI.FetchTypes.requestInit) =>
    switch url->String.endsWith("/tools/call") {
    | false => Promise.resolve(toolsResponse())
    | true =>
      let signal = init.signal->Option.getOrThrow->Null.getOrThrow
      calls->Array.push(signal)
      pendingUntilAbort(signal)
    }
  let relay = (await connect(fetch, connection))->Result.getOrThrow
  let cancelled = Relay.executeTool(relay, ~name="write", ~signal=request.signal)
  let sibling = Relay.executeTool(relay, ~name="read", ~signal=WebAPI.AbortController.make().signal)
  WebAPI.AbortController.abort(request)
  t->expect(await cancelled)->Expect.toEqual(Error("Relay request cancelled"))
  t->expect(connection.signal.aborted)->Expect.toBe(false)
  t->expect((calls->Array.get(1)->Option.getOrThrow).aborted)->Expect.toBe(false)

  t
  ->expect(await Relay.executeTool(relay, ~name="write", ~signal=request.signal))
  ->Expect.toEqual(Error("Relay tool request cancelled before dispatch"))
  t->expect(calls->Array.length)->Expect.toBe(2)

  WebAPI.AbortController.abort(connection)
  t->expect(await sibling)->Expect.toEqual(Error("Relay request cancelled"))
})
