open Vitest

module MCP = FrontmanClient__MCP
module Types = FrontmanClient__MCP__Types
module MCPServer = FrontmanClient__MCP__Server
module Relay = FrontmanClient__Relay

let makeServer = async (~tools=[]) => {
  let config = Relay.makeConfig(~baseUrl="http://relay.invalid", ~fetch=async (_, _) =>
    WebAPI.Response.fromString(`{"tools":[],"serverInfo":{"name":"test","version":"1"},"protocolVersion":"2.0"}`)
  )
  let relay =
    (await Relay.connect(config, ~signal=WebAPI.AbortController.make().signal))->Result.getOrThrow
  MCPServer.make(MCPServer.makeConfig(~tools), ~relay)
}

module MockChannel = {
  type pushCall = {payload: JSON.t}

  let make = () => {
    let calls: ref<array<pushCall>> = ref([])
    let channel: FrontmanClient__Phoenix__Channel.t = %raw(`{
      push: function(event, payload) {
        this._calls.push({event, payload});
        return { receive: function() { return this; } };
      },
      on: function() {},
      off: function() {},
      _calls: []
    }`)
    calls := %raw(`channel._calls`)
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

let handler = (channel, context, ~sessionId="task-1", ~failure=?) => {
  MCP.serverInterface: makeInterface(~context, ~failure?),
  channel,
  sessionId,
}

describe("MCP 2026-07-28", () => {
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

  testAsync(
    "canonicalizes mixed catalogs without changing definitions or registration arrays",
    async t => {
      module UpperTool = {
        include ThrowingTool
        let name = "A"
      }
      let relayTool = name =>
        JSON.parseOrThrow(
          `{"name":"${name}","description":"relay tool","inputSchema":{"type":"object","x-input":true},"outputSchema":{"type":"array"},"annotations":{"readOnlyHint":true},"_meta":{"custom":{"keep":true}},"x-tool":[1,null]}`,
        )
      let lower = relayTool("a")
      let last = relayTool("z")
      let server = await makeServer(~tools=[module(ThrowingTool), module(UpperTool)])
      let first = {...server, relay: {...server.relay, tools: [last, lower]}}
      let second = {
        ...server,
        tools: [module(UpperTool), module(ThrowingTool)],
        relay: {...server.relay, tools: [lower, last]},
      }
      let expected = [
        MCPServer.serializeTool(module(UpperTool)),
        lower,
        MCPServer.serializeTool(module(ThrowingTool)),
        last,
      ]
      let snapshot = server => (
        server.MCPServer.tools
        ->Array.map(MCPServer.serializeTool)
        ->JSON.Encode.array
        ->JSON.stringify,
        server.relay.tools->JSON.Encode.array->JSON.stringify,
      )
      let before = [snapshot(first), snapshot(second)]
      [first, second]->Array.forEach(
        server => {
          [1, 2]->Array.forEach(
            _ => {
              let tools = MCPServer.buildToolsListResult(server).tools
              t->expect(tools)->Expect.toEqual(expected)
            },
          )
        },
      )
      t->expect([snapshot(first), snapshot(second)])->Expect.toEqual(before)
    },
  )

  testAsync("accepts prototype-property tool names but rejects their duplicates", async t => {
    let names = ["toString", "constructor", "__proto__", "hasOwnProperty"]
    for index in 0 to names->Array.length - 1 {
      let toolName = names->Array.get(index)->Option.getOrThrow
      let executions = ref(0)
      module NamedTool = {
        include ThrowingTool
        let name = toolName
        let execute = async (_input, ~taskId as _, ~toolCallId as _) => {
          executions := executions.contents + 1
          Types.CallToolResult.makeText("ok")
        }
      }
      let server = await makeServer(~tools=[module(NamedTool)])
      let tool = MCPServer.serializeTool(module(NamedTool))
      t->expect(MCPServer.buildToolsListResult(server).tools)->Expect.toEqual([tool])
      let result = await MCPServer.executeTool(
        server,
        ~name=toolName,
        ~taskId="task-1",
        ~callId="call-1",
      )
      t->expect(result)->Expect.toEqual(Types.Completed(Types.CallToolResult.makeText("ok")))
      t->expect(executions.contents)->Expect.toBe(1)
      let relayOnly = {...server, tools: [], relay: {...server.relay, tools: [tool]}}
      t->expect(MCPServer.buildToolsListResult(relayOnly).tools)->Expect.toEqual([tool])
      let duplicate = {...server, relay: {...server.relay, tools: [tool]}}
      t->expect(() => MCPServer.buildToolsListResult(duplicate)->ignore)->Expect.toThrow
    }
  })

  testAsync("rejects every catalog collision before listing or execution", async t => {
    let executions = ref(0)
    let requests = ref(0)
    module CountingTool = {
      include ThrowingTool
      let name = "question"
      let execute = async (_input, ~taskId as _, ~toolCallId as _) => {
        executions := executions.contents + 1
        Types.CallToolResult.makeText("ok")
      }
    }
    let server = await makeServer(~tools=[module(ThrowingTool)])
    let last = JSON.parseOrThrow(`{"name":"z","inputSchema":{"type":"object"}}`)
    let local: module(MCPServer.Tool.Tool) = module(CountingTool)
    let tool = MCPServer.serializeTool(local)
    let relay = {
      ...server.relay,
      config: {
        ...server.relay.config,
        fetch: async (_, _) => {
          requests := requests.contents + 1
          JsError.throwWithMessage("unexpected relay request")
        },
      },
    }
    for category in 0 to 2 {
      let (tools, remote) = switch category {
      | 0 => ([local, local], [])
      | 1 => ([local], [tool])
      | _ => ([], [tool, tool])
      }
      let server = {
        ...server,
        tools: Array.concat(server.tools, tools),
        relay: {...relay, tools: Array.concat([last], remote)},
      }
      let snapshot = () => (
        server.tools->Array.map(MCPServer.serializeTool)->JSON.Encode.array->JSON.stringify,
        server.relay.tools->JSON.Encode.array->JSON.stringify,
      )
      let before = snapshot()
      let call = async (method, params) => {
        let (channel, calls) = MockChannel.make()
        let handler = {
          MCP.serverInterface: MCPServer.toInterface(server),
          channel,
          sessionId: "task-1",
        }
        await MCP.handleMessage(handler, request(~id=1, ~method, ~params))
        calls
      }
      let discovery = await call("server/discover", metadata)
      t->expect(response(discovery)->Dict.get("result")->Option.isSome)->Expect.toBe(true)
      for attempt in 0 to 2 {
        let (method, params) = switch attempt {
        | 1 => ("tools/list", metadata)
        | _ => ("tools/call", toolParams)
        }
        let calls = await call(method, params)
        t->expect(calls.contents->Array.length)->Expect.toBe(1)
        t->expect(errorCode(calls))->Expect.toEqual(Some(Types.ErrorCode.serverError))
        t
        ->expect(
          response(calls)
          ->JSON.Encode.object
          ->JSON.stringify
          ->String.includes("Duplicate tool name: question"),
        )
        ->Expect.toBe(true)
        t->expect((executions.contents, requests.contents))->Expect.toEqual((0, 0))
        t->expect(snapshot())->Expect.toEqual(before)
      }
    }
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
      {
        MCP.serverInterface: MCPServer.toInterface(server),
        channel,
        sessionId: "task-1",
      },
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
      {
        MCP.serverInterface: MCPServer.toInterface(server),
        channel,
        sessionId: "task-1",
      },
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
