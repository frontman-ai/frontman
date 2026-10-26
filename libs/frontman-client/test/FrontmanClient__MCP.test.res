open Vitest

module MCP = FrontmanClient__MCP
module Types = FrontmanClient__MCP__Types
module MCPServer = FrontmanClient__MCP__Server
module Relay = FrontmanClient__Relay

module TestVitest = FrontmanBindings.Bindings__Test__Vitest
module TestPhoenix = FrontmanBindings.Bindings__Test__Phoenix

@val @scope("JSON")
external stringifyLogContext: 'a => string = "stringify"

let makeServer = async (~tools=[]) => {
  let config = Relay.makeConfig(~baseUrl="http://relay.invalid", ~fetch=async (_, _) =>
    WebAPI.Response.fromString(`{"tools":[],"serverInfo":{"name":"test","version":"1"},"protocolVersion":"2.0"}`)
  )
  let relay =
    (await Relay.connect(config, ~signal=WebAPI.AbortController.make().signal))->Result.getOrThrow
  MCPServer.make(MCPServer.makeConfig(~tools), ~relay)
}

type pushCall = {event: string, payload: JSON.t}
@obj
external pushResponse: (
  ~receive: (~status: string, ~callback: JSON.t => unit) => FrontmanBindings.Phoenix.pushResponse,
  ~cancelTimeout: unit => unit,
  ~cancelRefEvent: unit => unit,
) => FrontmanBindings.Phoenix.pushResponse = ""
let rec makePush = () =>
  pushResponse(
    ~receive=(~status as _, ~callback as _) => makePush(),
    ~cancelTimeout=() => (),
    ~cancelRefEvent=() => (),
  )

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

let makeInterface = async (
  ~context: ref<option<(string, string)>>,
  ~failure: option<failure>=?,
): Types.serverInterface<MCPServer.t> => {
  let server = await makeServer(~tools=[module(ThrowingTool)])
  let serverInterface = MCPServer.toInterface(server)
  {
    ...serverInterface,
    buildDiscoverResult: server =>
      switch failure {
      | Some(Discover) => JsError.throwWithMessage("discovery exploded")
      | _ => serverInterface.buildDiscoverResult(server)
      },
    buildToolsListResult: server => {
      let result = serverInterface.buildToolsListResult(server)
      {...result, tools: failure == Some(List) ? [JSON.Encode.null] : result.tools}
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

let response = (calls: ref<array<pushCall>>) => {
  let {payload} = calls.contents->Array.get(0)->Option.getOrThrow
  payload->JSON.Decode.object->Option.getOrThrow
}
let resultJson = message => message->Dict.get("result")->Option.getOrThrow

module JsonRpc = FrontmanAiFrontmanProtocol.FrontmanProtocol__JsonRpc
let rpcResponse = (calls: ref<array<pushCall>>) =>
  (calls.contents->Array.get(0)->Option.getOrThrow).payload->S.parseOrThrow(
    ~to=JsonRpc.Response.schema,
  )
let rpcError = (calls: ref<array<pushCall>>) =>
  (calls.contents->Array.get(0)->Option.getOrThrow).payload->S.parseOrThrow(
    ~to=S.object(s => s.field("error", S.option(JsonRpc.RpcError.schema))),
  )
let errorCode = calls => rpcError(calls)->Option.map(JsonRpc.RpcError.code)
let errorData = calls => rpcError(calls)->Option.flatMap(JsonRpc.RpcError.data)

let fixture = serverInterface => {
  let calls = ref([])
  let listeners = Dict.make()
  let channel: TestPhoenix.mockChannel = {
    push: (event, payload) => {
      calls := Array.concat(calls.contents, [{event, payload}])
      makePush()
    },
    on: (event, callback) => listeners->Dict.set(event, callback),
    off: () => (),
  }
  let handler = MCP.attach(
    ~channel=TestPhoenix.toChannel(channel),
    ~sessionId="task-1",
    ~serverInterface,
  )
  TestVitest.onTestFinished(() => MCP.detach(handler))
  (handler, calls, listeners)
}

let invoke = async (~context=ref(None), ~failure=?, payload) => {
  let (handler, calls, _) = fixture(await makeInterface(~context, ~failure?))
  await MCP.handleMessage(handler, payload)
  calls
}

let listen = (handler, id, ~notifications="{}") =>
  MCP.handleMessage(
    handler,
    requestWithId(
      ~id,
      ~method="subscriptions/listen",
      ~params=`${coreMetadata},"notifications":${notifications}`,
    ),
  )

let cancel = (handler, params) =>
  MCP.handleMessage(
    handler,
    JsonRpc.Notification.make(
      ~method="notifications/cancelled",
      ~params=Some(JSON.parseOrThrow(params)),
    )->JsonRpc.Notification.toJson,
  )

describe("MCP 2026-07-28", () => {
  testAsync(
    "acknowledges attached streams and reserves tool IDs until completion or teardown",
    async t => {
      let server = await makeServer()
      let complete = Types.Completed(Types.CallToolResult.makeText("ok"))
      let _ = await [
        (complete, None),
        (Types.Suspended, None),
        (Types.ProtocolError({code: Types.ErrorCode.invalidParams, message: "Invalid tool"}), None),
        (complete, Some("detach")),
        (complete, Some("phx_error")),
        (complete, Some("phx_close")),
      ]
      ->Array.map(
        async ((outcome, event)) => {
          let resolve = ref(_ => ())
          let deferred = Promise.make((complete, _) => resolve := complete)
          let (handler, calls, listeners) = fixture({
            ...MCPServer.toInterface(server),
            executeTool: (_, _) => deferred,
          })
          let pending = MCP.handleMessage(
            handler,
            request(~id=1, ~method="tools/call", ~params=toolParams),
          )
          let receive = listeners->Dict.get("mcp:message")->Option.getOrThrow
          receive(
            requestWithId(
              ~id=`"1"`,
              ~method="subscriptions/listen",
              ~params=`${coreMetadata},"notifications":{}`,
            ),
          )
          await TestVitest.waitFor(() => t->expect(calls.contents->Array.length)->Expect.toBe(1))
          t
          ->expect((calls.contents->Array.get(0)->Option.getOrThrow).payload)
          ->Expect.toEqual(
            JSON.parseOrThrow(`{"jsonrpc":"2.0","method":"notifications/subscriptions/acknowledged","params":{"notifications":{},"_meta":{"io.modelcontextprotocol/subscriptionId":"1"}}}`),
          )
          calls := []
          await cancel(handler, `{"requestId":1}`)
          await listen(handler, "1")
          t->expect(errorCode(calls))->Expect.toEqual(Some(Types.ErrorCode.invalidRequest))
          calls := []
          switch event {
          | None =>
            resolve.contents(outcome)
            await pending
            t->expect(calls.contents->Array.length)->Expect.toBe(outcome == Types.Suspended ? 0 : 1)
            calls := []
            await listen(handler, "1")
            t
            ->expect(errorCode(calls))
            ->Expect.toEqual(
              outcome == Types.Suspended ? Some(Types.ErrorCode.invalidRequest) : None,
            )
          | Some(event) =>
            switch event {
            | "detach" => MCP.detach(handler)
            | _ => (listeners->Dict.get(event)->Option.getOrThrow)(JSON.Encode.null)
            }
            let sent = calls.contents
            resolve.contents(outcome)
            await pending
            MCP.detach(handler)
            t->expect(calls.contents)->Expect.toEqual(sent)
            t->expect(sent->Array.length)->Expect.toBe(event == "detach" ? 2 : 0)
          }
        },
      )
      ->Promise.all
    },
  )

  testAsync(
    "filters subscriptions, preserves typed IDs, and closes only active streams",
    async t => {
      let server = await makeServer()
      let (handler, calls, _) = fixture(MCPServer.toInterface(server))
      let requests =
        [`"1"`, "1", "2147483648"]->Array.map(
          id =>
            listen(
              handler,
              id,
              ~notifications=`{"toolsListChanged":true,"promptsListChanged":true,"resourcesListChanged":true,"resourceSubscriptions":["file:///test"]}`,
            ),
        )
      let _ = await Promise.all(requests)
      t->expect(calls.contents->Array.length)->Expect.toBe(3)
      calls.contents->Array.forEachWithIndex(
        (call, index) => {
          let expectedId = [`"1"`, "1", "2147483648"]->Array.get(index)->Option.getOrThrow
          t->expect(call.event)->Expect.toBe("mcp:message")
          t
          ->expect(call.payload)
          ->Expect.toEqual(
            JSON.parseOrThrow(
              `{"jsonrpc":"2.0","method":"notifications/subscriptions/acknowledged","params":{"notifications":{},"_meta":{"io.modelcontextprotocol/subscriptionId":${expectedId}}}}`,
            ),
          )
        },
      )
      calls := []
      await MCP.handleMessage(handler, request(~id=1, ~method="tools/call", ~params=toolParams))
      t->expect(errorCode(calls))->Expect.toEqual(Some(Types.ErrorCode.invalidRequest))
      let logs = ref("")
      FrontmanLogs.Logs.addHandler({
        id: "mcp-cancellation-test",
        run: (~component as _, ~stacktrace, ~level as _, message, context, error) => {
          let entry = (message, context, stacktrace, error->Option.flatMap(JsExn.message))
          logs := logs.contents ++ stringifyLogContext(entry)
        },
      })
      calls := []
      let malformed = [
        `{"requestId":{"private":"ID_SENTINEL"},"reason":"REASON_SENTINEL"}`,
        `{"requestId":1,"reason":{"private":"REASON_SENTINEL"}}`,
        `{"requestId":3}`,
      ]
      for index in 0 to 2 {
        await cancel(handler, malformed->Array.get(index)->Option.getOrThrow)
      }
      t
      ->expect(logs.contents->String.includes("Invalid MCP cancellation params"))
      ->Expect.toBe(true)
      t->expect(logs.contents->String.includes("SENTINEL"))->Expect.toBe(false)
      t->expect(handler.subscriptions.contents->Array.length)->Expect.toBe(3)
      for id in 0 to 1 {
        let id = id == 0 ? "1" : "2147483648"
        await cancel(handler, `{"requestId":${id}}`)
      }
      t->expect(calls.contents)->Expect.toEqual([])
      MCP.detach(handler)
      t
      ->expect(calls.contents->Array.map(call => call.payload))
      ->Expect.toEqual([
        JSON.parseOrThrow(`{"jsonrpc":"2.0","method":"notifications/cancelled","params":{"requestId":"1","_meta":{"io.modelcontextprotocol/subscriptionId":"1"}}}`),
        JSON.parseOrThrow(`{"jsonrpc":"2.0","id":"1","result":{"resultType":"complete","_meta":{"io.modelcontextprotocol/subscriptionId":"1"}}}`),
      ])
      MCP.detach(handler)
      t->expect(calls.contents->Array.length)->Expect.toBe(2)
      for id in 0 to 127 {
        await listen(handler, Int.toString(id))
      }
      calls := []
      await listen(handler, "128")
      t->expect(errorCode(calls))->Expect.toEqual(Some(Types.ErrorCode.serverError))
      MCP.detach(handler)
    },
  )

  testAsync("namespaces Frontman tool metadata under _meta", async t => {
    let server = await makeServer(~tools=[module(ThrowingTool)])
    let tool =
      MCPServer.buildToolsListResult(server).tools
      ->Array.get(0)
      ->Option.getOrThrow
    let metadata = S.object(
      s => s.field("_meta", S.object(s => s.field("ai.frontman/tool-metadata", S.dict(S.json)))),
    )
    tool->S.parseOrThrow(~to=metadata)->ignore
    let fields = tool->S.parseOrThrow(~to=S.dict(S.json))
    ["access", "visibleToAgent", "executionMode"]->Array.forEach(
      key => t->expect(fields->Dict.get(key))->Expect.toEqual(None),
    )
  })

  testAsync("handles discovery, listing, and tool execution with optional identity", async t => {
    let context = ref(None)
    let call = async (id, method, params) => {
      let calls = await invoke(~context, requestWithId(~id, ~method, ~params))
      t
      ->expect(rpcResponse(calls)->JsonRpc.Response.id)
      ->Expect.toEqual(Some(JSON.parseOrThrow(id)->S.parseOrThrow(~to=JsonRpc.Id.schema)))
      resultJson(response(calls))
    }
    for index in 0 to 1 {
      let params = index == 0 ? metadata : coreMetadata
      (await call("2147483648", "server/discover", params))->ignore
      let listed = (await call(`"list"`, "tools/list", params))->JSON.stringify
      t->expect(listed->String.includes(`"name":"throwing_tool"`))->Expect.toBe(true)
    }
    (await call(`"call-1"`, "tools/call", toolParams))->ignore
    t->expect(context.contents)->Expect.toEqual(Some(("task-1", "call-1")))
  })

  testAsync("rejects malformed and missing params", async t => {
    let context = ref(None)
    let requests = [
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
      request(
        ~id=11,
        ~method="tools/call",
        ~params=toolParams->String.replace("task-1", "other-task"),
      ),
      requestWithoutParams(~id=24, ~method="subscriptions/listen"),
      ...[
        "",
        `,"notifications":null`,
        `,"notifications":[]`,
        `,"notifications":{"toolsListChanged":"true"}`,
        `,"notifications":{"promptsListChanged":1}`,
        `,"notifications":{"resourcesListChanged":null}`,
        `,"notifications":{"resourcesListChanged":[]}`,
        `,"notifications":{"toolsListChanged":null}`,
        `,"notifications":{"resourceSubscriptions":null}`,
        `,"notifications":{"resourceSubscriptions":[1]}`,
      ]->Array.map(
        filter => request(~id=24, ~method="subscriptions/listen", ~params=coreMetadata ++ filter),
      ),
    ]
    let errors = await requests
    ->Array.map(
      async payload => {
        let calls = await invoke(~context, payload)
        t->expect(calls.contents->Array.length)->Expect.toBe(1)
        errorCode(calls)
      },
    )
    ->Promise.all

    t
    ->expect(errors)
    ->Expect.toEqual(
      Array.make(~length=Array.length(requests), Some(Types.ErrorCode.invalidParams)),
    )
    t->expect(context.contents)->Expect.toEqual(None)
  })

  testAsync("returns negotiation errors for unsupported versions and capabilities", async t => {
    let call = (id, method, params) => invoke(request(~id, ~method, ~params))
    let wrongProtocol = metadata->String.replace("2026-07-28", "2025-11-25")

    let unsupported = await Promise.all([
      call(12, "server/discover", wrongProtocol),
      call(19, "tools/list", `${wrongProtocol},"cursor":"expired"`),
      call(20, "unknown/method", wrongProtocol),
      call(24, "subscriptions/listen", `${wrongProtocol},"notifications":{}`),
    ])
    t
    ->expect(unsupported->Array.map(errorCode))
    ->Expect.toEqual(Array.make(~length=4, Some(-32022)))
    t
    ->expect(errorData(unsupported->Array.get(0)->Option.getOrThrow))
    ->Expect.toEqual(
      Some(JSON.parseOrThrow(`{"supported":["2026-07-28"],"requested":"2025-11-25"}`)),
    )

    let capabilities = await Promise.all([
      call(13, "tools/call", coreToolParams),
      call(21, "tools/call", toolParams->String.replace(`"version":1`, `"version":2`)),
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
    let call = async (failure, method, params) =>
      errorCode(await invoke(~failure, request(~id=14, ~method, ~params)))

    let codes = await Promise.all([
      call(Discover, "server/discover", metadata),
      call(List, "tools/list", metadata),
      call(Tool, "tools/call", toolParams),
    ])
    t->expect(codes)->Expect.toEqual(Array.make(~length=3, Some(-32603)))
  })

  testAsync("returns invalid params for an unknown tool", async t => {
    let server = await makeServer()
    let (handler, calls, _) = fixture(MCPServer.toInterface(server))
    await MCP.handleMessage(
      handler,
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
    let (handler, calls, _) = fixture(MCPServer.toInterface(server))
    await MCP.handleMessage(
      handler,
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
    let call = async payload =>
      rpcResponse(await invoke(JSON.parseOrThrow(payload)))->JsonRpc.Response.id
    let ids = await Promise.all([
      call(`{"jsonrpc":"2.0","id":23,"method":{},"params":{${metadata}}}`),
      call(`{"jsonrpc":"2.0","id":{},"method":"server/discover","params":{${metadata}}}`),
    ])
    t->expect(ids)->Expect.toEqual([Some(JsonRpc.Id.fromInt(23)), None])
  })

  test("accepts array structuredContent", _ => {
    let json = JSON.parseOrThrow(`{"resultType":"complete","content":[],"structuredContent":[1,"two",null]}`)
    json->S.parseOrThrow(~to=Types.callToolResultSchema)->ignore
  })
})
