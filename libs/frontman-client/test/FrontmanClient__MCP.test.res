open Vitest

module MCP = FrontmanClient__MCP
module Types = FrontmanClient__MCP__Types
module MCPServer = FrontmanClient__MCP__Server
module Relay = FrontmanClient__Relay

module TestVitest = FrontmanBindings.Bindings__Test__Vitest
module TestPhoenix = FrontmanBindings.Bindings__Test__Phoenix

@val @scope("JSON")
external stringifyLogContext: 'a => string = "stringify"

let cancellationLogs: ref<option<ref<string>>> = ref(None)

FrontmanLogs.Logs.addHandler({
  id: "mcp-cancellation-test",
  run: (~component as _, ~stacktrace, ~level as _, message, context, error) =>
    cancellationLogs.contents->Option.forEach(logs => {
      let entry = (message, context, stacktrace, error->Option.flatMap(JsExn.message))
      logs := logs.contents ++ stringifyLogContext(entry)
    }),
})

let makeServer = async (~tools=[]) => {
  let config = Relay.makeConfig(~baseUrl="http://relay.invalid", ~fetch=async (_, _) =>
    WebAPI.Response.fromString(`{"tools":[],"serverInfo":{"name":"test","version":"1"},"protocolVersion":"2.0"}`)
  )
  let relay =
    (await Relay.connect(config, ~signal=WebAPI.AbortController.make().signal))->Result.getOrThrow
  MCPServer.make(MCPServer.makeConfig(~tools), ~relay)
}

module MockChannel: {
  type pushCall = {event: string, payload: JSON.t}
  type t
  let make: unit => (t, ref<array<pushCall>>)
  let setOn: (t, (string, JSON.t => unit) => unit, ~allEvents: bool=?) => t
  let toPhoenix: t => FrontmanClient__Phoenix__Channel.t
} = {
  type pushCall = {event: string, payload: JSON.t}
  type t = TestPhoenix.mockChannel

  let toPhoenix = TestPhoenix.toChannel

  let setOn = (channel: t, on, ~allEvents=false) => {
    ...channel,
    on: (event, callback) =>
      switch (event, allEvents) {
      | ("mcp:message", _) | (_, true) => on(event, callback)
      | (_, false) => ()
      },
  }

  let rec pushResponse = () => {
    FrontmanBindings.Phoenix.receive: (~status as _, ~callback as _) => pushResponse(),
  }

  let make = () => {
    let calls: ref<array<pushCall>> = ref([])
    let channel: t = {
      push: (event, payload) => {
        calls := Array.concat(calls.contents, [{event, payload}])
        pushResponse()
      },
      on: (_, _) => (),
      off: () => (),
    }
    (channel, calls)
  }
}

let serverInfo: Types.info = {name: "test-browser", version: "1.0.0"}

module ThrowingTool = {
  let name = "throwing_tool"
  let description = "Throws during execution"
  let access = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool.Read
  type input = Dict.t<JSON.t>
  let inputSchema = S.dict(S.json)
  let outputJsonSchema = None
  let visibleToAgent = true
  let executionMode = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool.Synchronous
  let execute = async (_input, ~taskId as _, ~toolCallId as _) =>
    JsError.throwWithMessage("tool exploded")
}

type failure = Discover | List | Tool

let makeInterface = (
  ~context: ref<option<(string, string)>>,
  ~failure: option<failure>=?,
): Types.serverInterface<unit> => {
  server: (),
  buildDiscoverResult: _ =>
    switch failure {
    | Some(Discover) => JsError.throwWithMessage("discovery exploded")
    | Some(List) | Some(Tool) | None => {
        resultType: "complete",
        supportedVersions: [Types.protocolVersion],
        capabilities: {
          tools: {listChanged: false},
          extensions: {executionContext: {version: 1}, toolMetadata: {version: 1}},
        },
        ttlMs: 0,
        cacheScope: "private",
        _meta: {serverInfo: serverInfo},
      }
    },
  buildToolsListResult: _ => {
    resultType: "complete",
    tools: switch failure {
    | Some(List) => [JSON.Encode.null]
    | _ => [JSON.parseOrThrow(`{"name":"test","inputSchema":{"type":"object"}}`)]
    },
    ttlMs: 0,
    cacheScope: "private",
    _meta: {serverInfo: serverInfo},
  },
  executeTool: async (_, toolCall) => {
    switch failure == Some(Tool) {
    | true => JsError.throwWithMessage("tool exploded")
    | false => ()
    }
    context :=
      Some((Types.AuthorizedToolCall.taskId(toolCall), Types.AuthorizedToolCall.callId(toolCall)))
    Types.Completed(Types.CallToolResult.makeText("ok"))
  },
}

let commonMeta = `"io.modelcontextprotocol/protocolVersion":"2026-07-28","io.modelcontextprotocol/clientCapabilities":{"extensions":{"ai.frontman/execution-context":{"version":1}}},"io.modelcontextprotocol/clientInfo":{"name":"frontman-server","version":"1.0.0"}`
let metadata = `"_meta":{${commonMeta}}`
let toolParams = `"_meta":{${commonMeta},"ai.frontman/execution-context":{"taskId":"task-1","callId":"call-1"}},"name":"question"`
let coreMetadata = `"_meta":{"io.modelcontextprotocol/protocolVersion":"2026-07-28","io.modelcontextprotocol/clientCapabilities":{}}`
let coreToolParams = `${coreMetadata},"name":"question"`

let requestWithId = (~id: string, ~method: string, ~params: string) =>
  JSON.parseOrThrow(`{"jsonrpc":"2.0","id":${id},"method":"${method}","params":{${params}}}`)

let request = (~id: int, ~method: string, ~params: string) =>
  requestWithId(~id=id->Int.toString, ~method, ~params)

let requestWithoutParams = (~id: int, ~method: string) =>
  JSON.parseOrThrow(`{"jsonrpc":"2.0","id":${id->Int.toString},"method":"${method}"}`)

let response = (calls: ref<array<MockChannel.pushCall>>) => {
  let {payload} = calls.contents->Array.get(0)->Option.getOrThrow
  payload->JSON.Decode.object->Option.getOrThrow
}
let resultJson = message => message->Dict.get("result")->Option.getOrThrow

let errorCode = calls =>
  response(calls)
  ->Dict.get("error")
  ->Option.flatMap(JSON.Decode.object)
  ->Option.flatMap(error => error->Dict.get("code"))
  ->Option.flatMap(JSON.Decode.float)
  ->Option.map(Float.toInt)

let errorData = calls =>
  response(calls)
  ->Dict.get("error")
  ->Option.flatMap(JSON.Decode.object)
  ->Option.flatMap(error => error->Dict.get("data"))

let makeHandler = (channel, serverInterface, ~sessionId="task-1") => {
  MCP.serverInterface,
  channel: MockChannel.toPhoenix(channel),
  sessionId,
  subscriptions: ref([]),
  transportListeners: ref([]),
}

let handler = (channel, context, ~sessionId="task-1", ~failure=?) =>
  makeHandler(channel, makeInterface(~context, ~failure?), ~sessionId)

describe("MCP 2026-07-28", () => {
  testAsync(
    "rejects active subscription ID reuse by other methods and bounds active streams",
    async t => {
      let (channel, calls) = MockChannel.make()
      let context = ref(None)
      let attached = MCP.attach(
        ~channel=MockChannel.toPhoenix(channel),
        ~sessionId="task-1",
        ~serverInterface=makeInterface(~context),
      )
      let _ = await Array.make(~length=128, ())
      ->Array.mapWithIndex(
        async (_, id) =>
          await MCP.handleMessage(
            attached,
            request(
              ~id,
              ~method="subscriptions/listen",
              ~params=`${coreMetadata},"notifications":{}`,
            ),
          ),
      )
      ->Promise.all
      t->expect(calls.contents->Array.length)->Expect.toBe(128)
      calls := []
      await MCP.handleMessage(attached, request(~id=0, ~method="tools/call", ~params=toolParams))
      t->expect(errorCode(calls))->Expect.toEqual(Some(Types.ErrorCode.invalidRequest))
      t->expect(context.contents)->Expect.toEqual(None)
      calls := []
      await MCP.handleMessage(
        attached,
        request(
          ~id=128,
          ~method="subscriptions/listen",
          ~params=`${coreMetadata},"notifications":{}`,
        ),
      )
      t->expect(errorCode(calls))->Expect.toEqual(Some(Types.ErrorCode.serverError))
      MCP.detach(attached)
    },
  )

  testAsync(
    "drops subscription streams on channel error or close without replaying them",
    async t => {
      let _ = await ["phx_error", "phx_close"]
      ->Array.map(
        async closeEvent => {
          let (channel, calls) = MockChannel.make()
          let listeners = Dict.make()
          let channel = MockChannel.setOn(
            channel,
            (event, callback) => listeners->Dict.set(event, callback),
            ~allEvents=true,
          )
          let attached = MCP.attach(
            ~channel=MockChannel.toPhoenix(channel),
            ~sessionId="task-1",
            ~serverInterface=makeInterface(~context=ref(None)),
          )
          let listen = request(
            ~id=1,
            ~method="subscriptions/listen",
            ~params=`${coreMetadata},"notifications":{}`,
          )
          await MCP.handleMessage(attached, listen)
          let close = listeners->Dict.get(closeEvent)->Option.getOrThrow
          close(JSON.Encode.null)
          MCP.detach(attached)
          t->expect(calls.contents->Array.length)->Expect.toBe(1)
        },
      )
      ->Promise.all
    },
  )

  testAsync("validates subscription filters before acknowledging", async t => {
    let _ = await [
      "null",
      "[]",
      `{"toolsListChanged":"yes"}`,
      `{"promptsListChanged":1}`,
      `{"resourcesListChanged":[]}`,
      `{"resourceSubscriptions":[1]}`,
      `{"toolsListChanged":null}`,
      `{"resourceSubscriptions":null}`,
    ]
    ->Array.map(
      async filter => {
        let (channel, calls) = MockChannel.make()
        await MCP.handleMessage(
          handler(channel, ref(None)),
          request(
            ~id=1,
            ~method="subscriptions/listen",
            ~params=`${coreMetadata},"notifications":${filter}`,
          ),
        )
        t->expect(errorCode(calls))->Expect.toEqual(Some(Types.ErrorCode.invalidParams))
        t->expect(calls.contents->Array.length)->Expect.toBe(1)
      },
    )
    ->Promise.all
  })

  testAsync("keeps distinct subscription IDs active until cancelled or detached", async t => {
    let (channel, calls) = MockChannel.make()
    let attached = MCP.attach(
      ~channel=MockChannel.toPhoenix(channel),
      ~sessionId="task-1",
      ~serverInterface=makeInterface(~context=ref(None)),
    )
    let listen = async id =>
      await MCP.handleMessage(
        attached,
        requestWithId(
          ~id,
          ~method="subscriptions/listen",
          ~params=`${coreMetadata},"notifications":{"toolsListChanged":true,"promptsListChanged":true,"resourcesListChanged":true,"resourceSubscriptions":["file:///x"]}`,
        ),
      )
    await listen("1")
    await listen(`"1"`)
    t->expect(calls.contents->Array.length)->Expect.toBe(2)
    [(0, "1"), (1, `"1"`)]->Array.forEach(
      ((index, id)) => {
        let payload = calls.contents->Array.get(index)->Option.getOrThrow
        t
        ->expect(payload.payload)
        ->Expect.toEqual(
          JSON.parseOrThrow(
            `{
        "jsonrpc":"2.0","method":"notifications/subscriptions/acknowledged",
        "params":{"notifications":{},"_meta":{"io.modelcontextprotocol/subscriptionId":${id}}}
      }`,
          ),
        )
      },
    )
    await listen("1")
    let duplicate = calls.contents->Array.get(2)->Option.getOrThrow
    t
    ->expect(duplicate.payload->JSON.stringify->String.includes("already active"))
    ->Expect.toBe(true)
    await MCP.handleMessage(
      attached,
      JSON.parseOrThrow(`{
      "jsonrpc":"2.0","method":"notifications/cancelled","params":{"requestId":1}
    }`),
    )
    t->expect(calls.contents->Array.length)->Expect.toBe(3)
    // Reusing the cancelled numeric ID is legal; its string counterpart remains active.
    await listen("1")
    t->expect(calls.contents->Array.length)->Expect.toBe(4)
    MCP.detach(attached)
    let endings = calls.contents->Array.slice(~start=4, ~end=8)->Array.map(call => call.payload)
    t
    ->expect(endings)
    ->Expect.toEqual(
      [`"1"`, "1"]->Array.flatMap(
        id => [
          JSON.parseOrThrow(
            `{"jsonrpc":"2.0","method":"notifications/cancelled","params":{"requestId":${id},"_meta":{"io.modelcontextprotocol/subscriptionId":${id}}}}`,
          ),
          JSON.parseOrThrow(
            `{"jsonrpc":"2.0","id":${id},"result":{"resultType":"complete","_meta":{"io.modelcontextprotocol/subscriptionId":${id}}}}`,
          ),
        ],
      ),
    )
    MCP.detach(attached)
    t->expect(calls.contents->Array.length)->Expect.toBe(8)
  })

  testAsync(
    "ignores malformed and unknown cancellation without ending active subscriptions",
    async t => {
      let logs = ref("")
      cancellationLogs := Some(logs)
      TestVitest.onTestFinished(() => cancellationLogs := None)
      let (channel, calls) = MockChannel.make()
      let attached = MCP.attach(
        ~channel=MockChannel.toPhoenix(channel),
        ~sessionId="task-1",
        ~serverInterface=makeInterface(~context=ref(None)),
      )
      await MCP.handleMessage(
        attached,
        request(
          ~id=2,
          ~method="subscriptions/listen",
          ~params=`${coreMetadata},"notifications":{}`,
        ),
      )
      let _ = await [
        `{"requestId":{"private":"REQUEST_ID_SENTINEL"},"reason":"REASON_SENTINEL"}`,
        `{"requestId":2,"reason":{"private":"REASON_SENTINEL"}}`,
        `{"requestId":3}`,
      ]
      ->Array.map(
        async params => {
          await MCP.handleMessage(
            attached,
            JSON.parseOrThrow(
              `{"jsonrpc":"2.0","method":"notifications/cancelled","params":${params}}`,
            ),
          )
        },
      )
      ->Promise.all
      t
      ->expect(logs.contents->String.includes("Invalid MCP cancellation params"))
      ->Expect.toBe(true)
      t->expect(logs.contents->String.includes("REQUEST_ID_SENTINEL"))->Expect.toBe(false)
      t->expect(logs.contents->String.includes("REASON_SENTINEL"))->Expect.toBe(false)
      t->expect(calls.contents->Array.length)->Expect.toBe(1)
      MCP.detach(attached)
      t->expect(calls.contents->Array.length)->Expect.toBe(3)
    },
  )

  testAsync("acknowledges an empty subscription through the attached browser server", async t => {
    let server = await makeServer()
    let (channel, calls) = MockChannel.make()
    let incoming = ref(None)
    let channel = MockChannel.setOn(
      channel,
      (event, callback) => {
        t->expect(event)->Expect.toBe("mcp:message")
        incoming := Some(callback)
      },
    )
    let attached = MCP.attach(
      ~channel=MockChannel.toPhoenix(channel),
      ~sessionId="task-1",
      ~serverInterface=MCPServer.toInterface(server),
    )
    TestVitest.onTestFinished(() => MCP.detach(attached))

    let receive = incoming.contents->Option.getOrThrow
    receive(
      requestWithId(
        ~id=`"empty-subscription"`,
        ~method="subscriptions/listen",
        ~params=`${coreMetadata},"notifications":{}`,
      ),
    )
    await TestVitest.waitFor(() => t->expect(calls.contents->Array.length > 0)->Expect.toBe(true))

    let first = calls.contents->Array.get(0)->Option.getOrThrow
    t->expect(first.event)->Expect.toBe("mcp:message")
    t
    ->expect(first.payload)
    ->Expect.toEqual(
      JSON.parseOrThrow(`{
        "jsonrpc": "2.0",
        "method": "notifications/subscriptions/acknowledged",
        "params": {
          "notifications": {},
          "_meta": {"io.modelcontextprotocol/subscriptionId": "empty-subscription"}
        }
      }`),
    )
  })

  testAsync("namespaces Frontman tool metadata under _meta", async t => {
    let server = await makeServer(~tools=[module(ThrowingTool)])
    let tool =
      MCPServer.buildToolsListResult(server).tools
      ->Array.get(0)
      ->Option.getOrThrow
      ->JSON.Decode.object
      ->Option.getOrThrow
    let metadata =
      tool
      ->Dict.get("_meta")
      ->Option.flatMap(JSON.Decode.object)
      ->Option.flatMap(metadata => metadata->Dict.get("ai.frontman/tool-metadata"))
      ->Option.flatMap(JSON.Decode.object)

    t->expect(metadata->Option.isSome)->Expect.toBe(true)
    t->expect(tool->Dict.get("access")->Option.isNone)->Expect.toBe(true)
    t->expect(tool->Dict.get("visibleToAgent")->Option.isNone)->Expect.toBe(true)
    t->expect(tool->Dict.get("executionMode")->Option.isNone)->Expect.toBe(true)
  })

  testAsync("handles discovery, listing, and tool execution", async t => {
    let context = ref(None)
    let call = async (id, method, params) => {
      let (channel, calls) = MockChannel.make()
      await MCP.handleMessage(handler(channel, context), request(~id, ~method, ~params))
      response(calls)
    }

    resultJson(await call(1, "server/discover", metadata))->ignore
    let listed = resultJson(await call(2, "tools/list", metadata))->JSON.stringify
    t->expect(listed->String.includes(`"name":"test"`))->Expect.toBe(true)
    resultJson(await call(3, "tools/call", toolParams))->ignore
    t->expect(context.contents)->Expect.toEqual(Some(("task-1", "call-1")))
  })

  testAsync("accepts core requests without optional identity or Frontman capabilities", async t => {
    let context = ref(None)
    let call = async (id, method) => {
      let (channel, calls) = MockChannel.make()
      await MCP.handleMessage(
        handler(channel, context),
        request(~id, ~method, ~params=coreMetadata),
      )
      response(calls)
    }

    t
    ->expect((await call(17, "server/discover"))->Dict.get("result")->Option.isSome)
    ->Expect.toBe(true)
    t->expect((await call(18, "tools/list"))->Dict.get("result")->Option.isSome)->Expect.toBe(true)
  })

  testAsync("rejects malformed and missing params", async t => {
    let check = async payload => {
      let (channel, calls) = MockChannel.make()
      await MCP.handleMessage(handler(channel, ref(None)), payload)
      errorCode(calls)
    }
    let errors = await [
      request(~id=5, ~method="server/discover", ~params=""),
      requestWithoutParams(~id=6, ~method="server/discover"),
      request(~id=7, ~method="tools/list", ~params=""),
      requestWithoutParams(~id=8, ~method="tools/list"),
      request(~id=9, ~method="tools/call", ~params=`"name":"question"`),
      request(
        ~id=10,
        ~method="tools/call",
        ~params=toolParams->String.replace(`"taskId":"task-1"`, `"taskId":""`),
      ),
    ]
    ->Array.map(check)
    ->Promise.all

    t->expect(errors)->Expect.toEqual(Array.make(~length=6, Some(Types.ErrorCode.invalidParams)))
  })

  testAsync("rejects tool calls for another joined session without executing", async t => {
    let (channel, calls) = MockChannel.make()
    let context = ref(None)
    await MCP.handleMessage(
      handler(channel, context, ~sessionId="different-task"),
      request(~id=11, ~method="tools/call", ~params=toolParams),
    )
    t->expect(errorCode(calls))->Expect.toEqual(Some(Types.ErrorCode.invalidParams))
    t->expect(context.contents)->Expect.toEqual(None)
  })

  testAsync("returns negotiation errors for unsupported versions and capabilities", async t => {
    let invoke = async (id, method, params) => {
      let (channel, calls) = MockChannel.make()
      await MCP.handleMessage(handler(channel, ref(None)), request(~id, ~method, ~params))
      calls
    }
    let wrongProtocol = metadata->String.replace("2026-07-28", "2025-11-25")

    let unsupported = await Promise.all([
      invoke(12, "server/discover", wrongProtocol),
      invoke(19, "tools/list", `${wrongProtocol},"cursor":"expired"`),
      invoke(20, "unknown/method", wrongProtocol),
    ])
    t
    ->expect(unsupported->Array.map(errorCode))
    ->Expect.toEqual(Array.make(~length=3, Some(-32022)))
    t
    ->expect(errorData(unsupported->Array.get(0)->Option.getOrThrow))
    ->Expect.toEqual(
      Some(JSON.parseOrThrow(`{"supported":["2026-07-28"],"requested":"2025-11-25"}`)),
    )

    let capabilities = await Promise.all([
      invoke(13, "tools/call", coreToolParams),
      invoke(21, "tools/call", toolParams->String.replace(`"version":1`, `"version":2`)),
    ])
    t
    ->expect(capabilities->Array.map(errorCode))
    ->Expect.toEqual(Array.make(~length=2, Some(-32021)))
    t
    ->expect(errorData(capabilities->Array.get(0)->Option.getOrThrow))
    ->Expect.toEqual(
      Some(
        JSON.parseOrThrow(`{"requiredCapabilities":{"extensions":{"ai.frontman/execution-context":{"version":1}}}}`),
      ),
    )
  })

  testAsync("returns serverError for handler failures", async t => {
    let invoke = async (failure, method, params) => {
      let (channel, calls) = MockChannel.make()
      await MCP.handleMessage(
        handler(channel, ref(None), ~failure),
        request(~id=14, ~method, ~params),
      )
      errorCode(calls)
    }

    let codes = await Promise.all([
      invoke(Discover, "server/discover", metadata),
      invoke(List, "tools/list", metadata),
      invoke(Tool, "tools/call", toolParams),
    ])
    t->expect(codes)->Expect.toEqual(Array.make(~length=3, Some(-32603)))
  })

  testAsync("echoes string JSON-RPC ids", async t => {
    let (channel, calls) = MockChannel.make()
    await MCP.handleMessage(
      handler(channel, ref(None)),
      requestWithId(~id=`"call-1"`, ~method="tools/call", ~params=toolParams),
    )
    t->expect(response(calls)->Dict.get("id"))->Expect.toEqual(Some(JSON.Encode.string("call-1")))
  })

  testAsync("echoes numeric JSON-RPC ids above signed 32-bit", async t => {
    let (channel, calls) = MockChannel.make()
    await MCP.handleMessage(
      handler(channel, ref(None)),
      requestWithId(~id="2147483648", ~method="tools/list", ~params=metadata),
    )

    t
    ->expect(response(calls)->Dict.get("id"))
    ->Expect.toEqual(Some(JSON.parseOrThrow("2147483648")))
  })

  testAsync("returns invalid params for an unknown tool", async t => {
    let server = await makeServer()
    let (channel, calls) = MockChannel.make()

    await MCP.handleMessage(
      makeHandler(channel, MCPServer.toInterface(server)),
      request(
        ~id=21,
        ~method="tools/call",
        ~params=toolParams->String.replace(`"name":"question"`, `"name":"missing_tool"`),
      ),
    )

    t->expect(errorCode(calls))->Expect.toEqual(Some(Types.ErrorCode.invalidParams))
    t->expect(response(calls)->Dict.get("result")->Option.isNone)->Expect.toBe(true)
  })

  testAsync("returns thrown tool failures as tool errors", async t => {
    let server = await makeServer(~tools=[module(ThrowingTool)])
    let (channel, calls) = MockChannel.make()

    await MCP.handleMessage(
      makeHandler(channel, MCPServer.toInterface(server)),
      request(
        ~id=22,
        ~method="tools/call",
        ~params=toolParams->String.replace(`"name":"question"`, `"name":"throwing_tool"`),
      ),
    )

    let result = response(calls)->Dict.get("result")->Option.flatMap(JSON.Decode.object)
    t
    ->expect(result->Option.flatMap(result => result->Dict.get("isError")))
    ->Expect.toEqual(Some(JSON.Encode.bool(true)))
    t->expect(response(calls)->Dict.get("error")->Option.isNone)->Expect.toBe(true)
  })

  testAsync("preserves readable ids on invalid requests", async t => {
    let invoke = async payload => {
      let (channel, calls) = MockChannel.make()
      await MCP.handleMessage(handler(channel, ref(None)), JSON.parseOrThrow(payload))
      response(calls)->S.parseOrThrow(~to=S.object(s => s.field("id", S.option(S.json))))
    }
    let ids = await Promise.all([
      invoke(`{"jsonrpc":"2.0","id":23,"method":{},"params":{${metadata}}}`),
      invoke(`{"jsonrpc":"2.0","id":{},"method":"server/discover","params":{${metadata}}}`),
    ])
    t->expect(ids)->Expect.toEqual([Some(JSON.Encode.int(23)), None])
  })

  test("accepts array structuredContent", _ => {
    let json = JSON.parseOrThrow(`{"resultType":"complete","content":[],"structuredContent":[1,"two",null]}`)
    json->S.parseOrThrow(~to=Types.callToolResultSchema)->ignore
  })
})
