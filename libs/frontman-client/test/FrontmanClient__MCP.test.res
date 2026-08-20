open Vitest

module MCP = FrontmanClient__MCP
module Types = FrontmanClient__MCP__Types
module JsonRpc = FrontmanAiFrontmanProtocol.FrontmanProtocol__JsonRpc
module MCPServer = FrontmanClient__MCP__Server

afterEach(() => Vi.useRealTimers()->ignore)

module LimitedLocalTool = {
  let name = "limited_local"
  let description = "Exercises browser MCP server invocation policy"
  let access = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool.Read
  let visibleToAgent = true
  let executionMode = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool.Synchronous
  let outputJsonSchema = None
  let executionCount = ref(0)

  @schema
  type input = {value: option<string>}

  let execute = async (_input, ~taskId as _, ~toolCallId as _, ~signal as _) => {
    executionCount := executionCount.contents + 1
    JSON.parseOrThrow(`{
      "resultType":"complete",
      "content":[{"type":"text","text":"local"}],
      "_meta":{
        "com.example/preserved":{"value":true},
        "io.modelcontextprotocol/serverInfo":{"name":"upstream-spoof","version":"9"}
      }
    }`)->S.parseOrThrow(~to=Types.CallToolResult.schema)
  }
}

module MockChannel = {
  type pushCall = {payload: JSON.t}
  let emit: (FrontmanClient__Phoenix__Channel.t, JSON.t) => unit = %raw(`
    (channel, payload) => channel.emit("mcp:message", payload)
  `)

  let make = () => {
    let calls: ref<array<pushCall>> = ref([])
    let channel: FrontmanClient__Phoenix__Channel.t = %raw(`{
      push: function(event, payload) {
        this._calls.push({event, payload});
        return { receive: function() { return this; } };
      },
      on: function(event, callback) {
        const ref = ++this._nextRef;
        this._handlers.set(ref, {event, callback});
        return ref;
      },
      off: function(event, ref) {
        this._offCalls.push({event, ref});
        this._handlers.delete(ref);
      },
      emit: function(event, payload) {
        for (const handler of this._handlers.values()) {
          if (handler.event === event) handler.callback(payload);
        }
      },
      _handlers: new Map(),
      _offCalls: [],
      _nextRef: 0,
      _calls: []
    }`)
    calls := %raw(`channel._calls`)
    (channel, calls)
  }
}

let discoverResult = (): Types.DiscoverResult.t => {
  resultType: "complete",
  supportedVersions: [Types.protocolVersion],
  capabilities: Types.ExecutionContextExtension.serverCapabilities(),
  _meta: None,
  instructions: None,
  ttlMs: 0.,
  cacheScope: Types.CacheScope.Private,
}

let toolsListResult = (): Types.ListToolsResult.t => {
  resultType: "complete",
  tools: [],
  nextCursor: None,
  ttlMs: 0.,
  cacheScope: Types.CacheScope.Private,
  _meta: None,
}

let makeServerInterface = (~executeTool): Types.serverInterface<unit> => {
  server: (),
  buildDiscoverResult: _ => discoverResult(),
  buildToolsListResult: _ => toolsListResult(),
  executeTool,
}

let completedServerInterface = () =>
  makeServerInterface(~executeTool=async (
    _,
    ~name as _,
    ~arguments as _,
    ~taskId as _,
    ~toolCallId as _,
    ~onProgress as _,
    ~signal as _,
  ) => Types.CallToolResult.makeText("tool output"))

let makeHandler = (channel, serverInterface): MCP.mcpHandler<unit> =>
  MCP.makeHandler(~channel, ~serverInterface)

let utf8Payload = bytes => {
  let pairs = "é"->String.repeat(bytes / 2)
  switch mod(bytes, 2) {
  | 0 => pairs
  | _ => pairs ++ "a"
  }
}

let requestMeta = (
  ~protocolVersion=Types.protocolVersion,
  ~context: option<(string, string)>=?,
) => {
  let metadata = Dict.fromArray([
    ("io.modelcontextprotocol/protocolVersion", JSON.Encode.string(protocolVersion)),
    (
      "io.modelcontextprotocol/clientCapabilities",
      Types.ExecutionContextExtension.clientCapabilities()->Types.ClientCapabilities.toJson,
    ),
  ])
  switch context {
  | Some((taskId, toolCallId)) =>
    metadata->Dict.set(
      Types.ExecutionContextExtension.identifier,
      JSON.Encode.object(
        Dict.fromArray([
          ("taskId", JSON.Encode.string(taskId)),
          ("toolCallId", JSON.Encode.string(toolCallId)),
        ]),
      ),
    )
  | None => ()
  }
  JSON.Encode.object(metadata)
}

let request = (~id=JSON.Encode.int(1), ~method, ~params) =>
  JSON.Encode.object(
    Dict.fromArray([
      ("jsonrpc", JSON.Encode.string("2.0")),
      ("id", id),
      ("method", JSON.Encode.string(method)),
      ("params", params),
    ]),
  )

let discoverRequest = (~protocolVersion=Types.protocolVersion) =>
  request(
    ~id=JSON.Encode.int(1),
    ~method="server/discover",
    ~params=JSON.Encode.object(Dict.fromArray([("_meta", requestMeta(~protocolVersion))])),
  )

let listRequest = () =>
  request(
    ~id=JSON.Encode.int(1),
    ~method="tools/list",
    ~params=JSON.Encode.object(Dict.fromArray([("_meta", requestMeta())])),
  )

let callRequest = (
  ~id=JSON.Encode.int(1),
  ~taskId="task-1",
  ~toolCallId="tool-call-1",
  ~name="take_screenshot",
  ~arguments: option<Dict.t<JSON.t>>=?,
  ~inputResponses: option<Dict.t<JSON.t>>=?,
  ~requestState: option<string>=?,
) => {
  let params = Dict.fromArray([
    ("_meta", requestMeta(~context=(taskId, toolCallId))),
    ("name", JSON.Encode.string(name)),
  ])
  switch arguments {
  | Some(arguments) => params->Dict.set("arguments", JSON.Encode.object(arguments))
  | None => ()
  }
  switch inputResponses {
  | Some(inputResponses) => params->Dict.set("inputResponses", JSON.Encode.object(inputResponses))
  | None => ()
  }
  switch requestState {
  | Some(requestState) => params->Dict.set("requestState", JSON.Encode.string(requestState))
  | None => ()
  }
  request(~id, ~method="tools/call", ~params=JSON.Encode.object(params))
}

let cancellation = requestId =>
  JSON.Encode.object(
    Dict.fromArray([
      ("jsonrpc", JSON.Encode.string("2.0")),
      ("method", JSON.Encode.string("notifications/cancelled")),
      (
        "params",
        JSON.Encode.object(
          Dict.fromArray([
            ("requestId", requestId),
            ("reason", JSON.Encode.string("user requested")),
          ]),
        ),
      ),
    ]),
  )

let responseById = (calls: ref<array<MockChannel.pushCall>>, id: JSON.t) =>
  calls.contents
  ->Array.find(call =>
    call.payload
    ->JSON.Decode.object
    ->Option.flatMap(fields => fields->Dict.get("id")) == Some(id)
  )
  ->Option.map(call => call.payload)

let responseErrorCode = response =>
  response
  ->JSON.Decode.object
  ->Option.flatMap(fields => fields->Dict.get("error"))
  ->Option.flatMap(JSON.Decode.object)
  ->Option.flatMap(error => error->Dict.get("code"))
  ->Option.flatMap(JSON.Decode.float)
  ->Option.map(Float.toInt)

let responseErrorMessage = response =>
  response
  ->JSON.Decode.object
  ->Option.flatMap(fields => fields->Dict.get("error"))
  ->Option.flatMap(JSON.Decode.object)
  ->Option.flatMap(error => error->Dict.get("message"))
  ->Option.flatMap(JSON.Decode.string)

let resultFields = result =>
  result
  ->S.decodeOrThrow(~from=Types.CallToolResult.schema, ~to=S.json)
  ->JSON.Decode.object
  ->Option.getOrThrow

let resultMetadata = result =>
  resultFields(result)
  ->Dict.get("_meta")
  ->Option.getOrThrow
  ->JSON.Decode.object
  ->Option.getOrThrow

let resultServerInfo = result =>
  resultMetadata(result)
  ->Dict.get("io.modelcontextprotocol/serverInfo")
  ->Option.getOrThrow
  ->S.parseOrThrow(~to=Types.Implementation.schema)

let resultIsError = result =>
  resultFields(result)
  ->Dict.get("isError")
  ->Option.flatMap(JSON.Decode.bool)
  ->Option.getOr(false)

let makeLocalServer = (
  ~authorizeTool=async (~name as _, ~arguments as _, ~readOnly as _, ~readOnlyTools as _) => true,
) => {
  let frameworkClient = FrontmanClient__MCP__Client.make(~baseUrl="http://127.0.0.1:1/mcp")
  MCPServer.make(
    ~frameworkClient,
    ~serverName="browser-test-server",
    ~serverVersion="4.5.6",
    ~authorizeTool,
  )->MCPServer.registerToolModule(module(LimitedLocalTool))
}

describe("modern MCP consumer", () => {
  test("accepts absent and generic tool result metadata", t => {
    let parses = json => {
      try {
        json->JSON.parseOrThrow->S.parseOrThrow(~to=Types.CallToolResult.schema)->ignore
        true
      } catch {
      | _ => false
      }
    }

    t
    ->expect(
      parses(`{"content":[{"type":"text","text":"ok"}],"_meta":{"vendor.example/context":{"nested":[1,true,null]}},"resultType":"complete"}`),
    )
    ->Expect.toBe(true)
    t
    ->expect(parses(`{"content":[],"structuredContent":[],"resultType":"complete"}`))
    ->Expect.toBe(true)
    t->expect(parses(`{"content":[],"resultType":"input_required"}`))->Expect.toBe(false)
  })

  testAsync("discovers the server and advertises execution context support", async t => {
    let (channel, calls) = MockChannel.make()
    await MCP.handleMessage(makeHandler(channel, completedServerInterface()), discoverRequest())

    let response = responseById(calls, JSON.Encode.int(1))->Option.getOrThrow
    let capabilities =
      response
      ->JSON.Decode.object
      ->Option.flatMap(fields => fields->Dict.get("result"))
      ->Option.flatMap(JSON.Decode.object)
      ->Option.flatMap(result => result->Dict.get("capabilities"))
      ->Option.getOrThrow
    capabilities
    ->S.parseOrThrow(~to=Types.ExecutionContextExtension.serverCapabilitiesSchema)
    ->ignore
    t->expect(responseErrorCode(response))->Expect.toEqual(None)
  })

  testAsync("rejects legacy initialize requests", async t => {
    let (channel, calls) = MockChannel.make()
    let payload = request(
      ~method="initialize",
      ~params=JSON.Encode.object(Dict.fromArray([("_meta", requestMeta())])),
    )
    await MCP.handleMessage(makeHandler(channel, completedServerInterface()), payload)

    let response = responseById(calls, JSON.Encode.int(1))->Option.getOrThrow
    t->expect(responseErrorCode(response))->Expect.toEqual(Some(Types.ErrorCode.methodNotFound))
  })

  testAsync("lists tools with required request metadata", async t => {
    let (channel, calls) = MockChannel.make()
    await MCP.handleMessage(makeHandler(channel, completedServerInterface()), listRequest())

    let response = responseById(calls, JSON.Encode.int(1))->Option.getOrThrow
    t->expect(responseErrorCode(response))->Expect.toEqual(None)
  })

  testAsync("takes task and tool call identity only from execution context metadata", async t => {
    let receivedContext = ref(None)
    let serverInterface = makeServerInterface(
      ~executeTool=async (
        _,
        ~name as _,
        ~arguments as _,
        ~taskId,
        ~toolCallId,
        ~onProgress as _,
        ~signal as _,
      ) => {
        receivedContext := Some((taskId, toolCallId))
        Types.CallToolResult.makeText("ok")
      },
    )
    let (channel, calls) = MockChannel.make()
    let payload = callRequest(
      ~id=JSON.Encode.string("request-7"),
      ~taskId="task-9",
      ~toolCallId="call-3",
    )
    await MCP.handleMessage(makeHandler(channel, serverInterface), payload)

    t->expect(receivedContext.contents)->Expect.toEqual(Some(("task-9", "call-3")))
    t
    ->expect(responseById(calls, JSON.Encode.string("request-7"))->Option.isSome)
    ->Expect.toBe(true)
  })

  testAsync("returns invalid params when execution context is absent", async t => {
    let (channel, calls) = MockChannel.make()
    let payload = request(
      ~method="tools/call",
      ~params=JSON.Encode.object(
        Dict.fromArray([("_meta", requestMeta()), ("name", JSON.Encode.string("take_screenshot"))]),
      ),
    )
    await MCP.handleMessage(makeHandler(channel, completedServerInterface()), payload)

    let response = responseById(calls, JSON.Encode.int(1))->Option.getOrThrow
    t->expect(responseErrorCode(response))->Expect.toEqual(Some(Types.ErrorCode.invalidParams))
  })

  testAsync("returns unsupported version errors", async t => {
    let (channel, calls) = MockChannel.make()
    await MCP.handleMessage(
      makeHandler(channel, completedServerInterface()),
      discoverRequest(~protocolVersion="2024-11-05"),
    )

    let response = responseById(calls, JSON.Encode.int(1))->Option.getOrThrow
    t
    ->expect(responseErrorCode(response))
    ->Expect.toEqual(Some(Types.ErrorCode.unsupportedProtocolVersion))
  })

  testAsync(
    "returns required capability errors when the client does not advertise execution context",
    async t => {
      let metadata = JSON.Encode.object(
        Dict.fromArray([
          ("io.modelcontextprotocol/protocolVersion", JSON.Encode.string(Types.protocolVersion)),
          ("io.modelcontextprotocol/clientCapabilities", JSON.Encode.object(Dict.make())),
        ]),
      )
      let payload = request(
        ~method="server/discover",
        ~params=JSON.Encode.object(Dict.fromArray([("_meta", metadata)])),
      )
      let (channel, calls) = MockChannel.make()
      await MCP.handleMessage(makeHandler(channel, completedServerInterface()), payload)

      let response = responseById(calls, JSON.Encode.int(1))->Option.getOrThrow
      t
      ->expect(responseErrorCode(response))
      ->Expect.toEqual(Some(Types.ErrorCode.missingRequiredClientCapability))
    },
  )

  testAsync("guarantees an internal error response when execution throws", async t => {
    let serverInterface = makeServerInterface(
      ~executeTool=async (
        _,
        ~name as _,
        ~arguments as _,
        ~taskId as _,
        ~toolCallId as _,
        ~onProgress as _,
        ~signal as _,
      ) => JsError.throwWithMessage("secret-marker-boom"),
    )
    let (channel, calls) = MockChannel.make()
    await MCP.handleMessage(makeHandler(channel, serverInterface), callRequest())

    let response = responseById(calls, JSON.Encode.int(1))->Option.getOrThrow
    t->expect(responseErrorCode(response))->Expect.toEqual(Some(Types.ErrorCode.internalError))
    t
    ->expect(responseErrorMessage(response))
    ->Expect.toEqual(Some("Tool execution failed"))
    t->expect(JSON.stringify(response)->String.includes("secret-marker-boom"))->Expect.toBe(false)
  })

  testAsync("cancels only the matching request and suppresses its late result", async t => {
    let resolvers: Dict.t<unit => unit> = Dict.make()
    let signals: Dict.t<WebAPI.EventAPI.abortSignal> = Dict.make()
    let serverInterface = makeServerInterface(
      ~executeTool=async (
        _,
        ~name as _,
        ~arguments as _,
        ~taskId,
        ~toolCallId as _,
        ~onProgress as _,
        ~signal,
      ) => {
        signals->Dict.set(taskId, signal)
        await Promise.make((resolve, _) => resolvers->Dict.set(taskId, resolve))
        Types.CallToolResult.makeText(taskId)
      },
    )
    let (channel, calls) = MockChannel.make()
    let handler = makeHandler(channel, serverInterface)
    let first = MCP.handleMessage(
      handler,
      callRequest(~id=JSON.Encode.string("request-7"), ~taskId="task-7"),
    )
    let second = MCP.handleMessage(
      handler,
      callRequest(~id=JSON.Encode.string("request-8"), ~taskId="task-8"),
    )
    let payload = JSON.parseOrThrow(`{"jsonrpc":"2.0","method":"notifications/cancelled","params":{"requestId":"request-7","reason":"user requested"}}`)
    await MCP.handleMessage(handler, payload)

    let firstSignal: WebAPI.EventAPI.abortSignal = signals->Dict.get("task-7")->Option.getOrThrow
    let secondSignal: WebAPI.EventAPI.abortSignal = signals->Dict.get("task-8")->Option.getOrThrow
    t->expect(firstSignal.aborted)->Expect.toBe(true)
    t->expect(secondSignal.aborted)->Expect.toBe(false)
    let resolveFirst = resolvers->Dict.get("task-7")->Option.getOrThrow
    let resolveSecond = resolvers->Dict.get("task-8")->Option.getOrThrow
    resolveFirst()
    resolveSecond()
    await first
    await second
    t
    ->expect(responseById(calls, JSON.Encode.string("request-7"))->Option.isNone)
    ->Expect.toBe(true)
    t
    ->expect(responseById(calls, JSON.Encode.string("request-8"))->Option.isSome)
    ->Expect.toBe(true)
  })

  testAsync("rejects a duplicate active request id without executing twice", async t => {
    let invocationCount = ref(0)
    let resolveExecution = ref(None)
    let serverInterface = makeServerInterface(
      ~executeTool=async (
        _,
        ~name as _,
        ~arguments as _,
        ~taskId as _,
        ~toolCallId as _,
        ~onProgress as _,
        ~signal as _,
      ) => {
        invocationCount := invocationCount.contents + 1
        await Promise.make((resolve, _) => resolveExecution := Some(resolve))
        Types.CallToolResult.makeText("ok")
      },
    )
    let (channel, calls) = MockChannel.make()
    let handler = makeHandler(channel, serverInterface)
    let first = MCP.handleMessage(handler, callRequest(~id=JSON.Encode.string("same")))
    await MCP.handleMessage(handler, callRequest(~id=JSON.Encode.string("same")))

    t->expect(invocationCount.contents)->Expect.toBe(1)
    t->expect(calls.contents->Array.length)->Expect.toBe(0)
    let resolve = resolveExecution.contents->Option.getOrThrow
    resolve()
    await first
    t
    ->expect(responseById(calls, JSON.Encode.string("same"))->Option.getOrThrow->responseErrorCode)
    ->Expect.toEqual(None)
  })

  testAsync("joins an identical durable replay with a new request id", async t => {
    let invocationCount = ref(0)
    let resolveExecution = ref(None)
    let serverInterface = makeServerInterface(
      ~executeTool=async (
        _,
        ~name as _,
        ~arguments as _,
        ~taskId as _,
        ~toolCallId as _,
        ~onProgress as _,
        ~signal as _,
      ) => {
        invocationCount := invocationCount.contents + 1
        await Promise.make((resolve, _) => resolveExecution := Some(resolve))
        Types.CallToolResult.makeText("shared")
      },
    )
    let (channel, calls) = MockChannel.make()
    let handler = makeHandler(channel, serverInterface)
    let first = MCP.handleMessage(handler, callRequest(~id=JSON.Encode.string("first")))
    let second = MCP.handleMessage(handler, callRequest(~id=JSON.Encode.string("replay")))

    t->expect(invocationCount.contents)->Expect.toBe(1)
    let resolve = resolveExecution.contents->Option.getOrThrow
    resolve()
    await first
    await second
    t->expect(responseById(calls, JSON.Encode.string("first"))->Option.isSome)->Expect.toBe(true)
    t->expect(responseById(calls, JSON.Encode.string("replay"))->Option.isSome)->Expect.toBe(true)
  })

  testAsync("joins and replays structurally identical reordered arguments", async t => {
    let invocationCount = ref(0)
    let resolveExecution = ref(None)
    let serverInterface = makeServerInterface(
      ~executeTool=async (
        _,
        ~name as _,
        ~arguments as _,
        ~taskId as _,
        ~toolCallId as _,
        ~onProgress as _,
        ~signal as _,
      ) => {
        invocationCount := invocationCount.contents + 1
        await Promise.make((resolve, _) => resolveExecution := Some(resolve))
        Types.CallToolResult.makeText("shared")
      },
    )
    let firstArguments = Dict.fromArray([
      (
        "outer",
        JSON.Encode.object(
          Dict.fromArray([
            ("b", JSON.Encode.array([JSON.Encode.int(1), JSON.Encode.bool(true)])),
            ("a", JSON.Encode.null),
          ]),
        ),
      ),
      ("value", JSON.Encode.string("same")),
    ])
    let reorderedArguments = Dict.fromArray([
      ("value", JSON.Encode.string("same")),
      (
        "outer",
        JSON.Encode.object(
          Dict.fromArray([
            ("a", JSON.Encode.null),
            ("b", JSON.Encode.array([JSON.Encode.int(1), JSON.Encode.bool(true)])),
          ]),
        ),
      ),
    ])
    let (channel, calls) = MockChannel.make()
    let handler = makeHandler(channel, serverInterface)
    let first = MCP.handleMessage(
      handler,
      callRequest(~id=JSON.Encode.string("first"), ~arguments=firstArguments),
    )
    let joined = MCP.handleMessage(
      handler,
      callRequest(~id=JSON.Encode.string("joined"), ~arguments=reorderedArguments),
    )

    t->expect(invocationCount.contents)->Expect.toBe(1)
    let resolve = resolveExecution.contents->Option.getOrThrow
    resolve()
    await first
    await joined
    await MCP.handleMessage(
      handler,
      callRequest(~id=JSON.Encode.string("replay"), ~arguments=reorderedArguments),
    )
    t->expect(invocationCount.contents)->Expect.toBe(1)
    t->expect(responseById(calls, JSON.Encode.string("joined"))->Option.isSome)->Expect.toBe(true)
    t->expect(responseById(calls, JSON.Encode.string("replay"))->Option.isSome)->Expect.toBe(true)
  })

  testAsync("rejects a changed payload for an active durable execution", async t => {
    let invocationCount = ref(0)
    let resolveExecution = ref(None)
    let serverInterface = makeServerInterface(
      ~executeTool=async (
        _,
        ~name as _,
        ~arguments as _,
        ~taskId as _,
        ~toolCallId as _,
        ~onProgress as _,
        ~signal as _,
      ) => {
        invocationCount := invocationCount.contents + 1
        await Promise.make((resolve, _) => resolveExecution := Some(resolve))
        Types.CallToolResult.makeText("original")
      },
    )
    let (channel, calls) = MockChannel.make()
    let handler = makeHandler(channel, serverInterface)
    let first = MCP.handleMessage(handler, callRequest(~id=JSON.Encode.string("first")))
    await MCP.handleMessage(
      handler,
      callRequest(
        ~id=JSON.Encode.string("changed"),
        ~arguments=Dict.fromArray([("quality", JSON.Encode.string("high"))]),
      ),
    )

    t->expect(invocationCount.contents)->Expect.toBe(1)
    t
    ->expect(
      responseById(calls, JSON.Encode.string("changed"))->Option.getOrThrow->responseErrorCode,
    )
    ->Expect.toEqual(Some(Types.ModernErrorCode.invalidRequest))
    let resolve = resolveExecution.contents->Option.getOrThrow
    resolve()
    await first
  })

  testAsync("cancels one durable waiter without aborting the shared execution", async t => {
    let resolveExecution = ref(None)
    let signal = ref(None)
    let serverInterface = makeServerInterface(
      ~executeTool=async (
        _,
        ~name as _,
        ~arguments as _,
        ~taskId as _,
        ~toolCallId as _,
        ~onProgress as _,
        ~signal as executionSignal,
      ) => {
        signal := Some(executionSignal)
        await Promise.make((resolve, _) => resolveExecution := Some(resolve))
        Types.CallToolResult.makeText("shared")
      },
    )
    let (channel, calls) = MockChannel.make()
    let handler = makeHandler(channel, serverInterface)
    let first = MCP.handleMessage(handler, callRequest(~id=JSON.Encode.string("first")))
    let second = MCP.handleMessage(handler, callRequest(~id=JSON.Encode.string("second")))
    await MCP.handleMessage(handler, cancellation(JSON.Encode.string("first")))

    let executionSignal: WebAPI.EventAPI.abortSignal = signal.contents->Option.getOrThrow
    t->expect(executionSignal.aborted)->Expect.toBe(false)
    let resolve = resolveExecution.contents->Option.getOrThrow
    resolve()
    await first
    await second
    t->expect(responseById(calls, JSON.Encode.string("first"))->Option.isNone)->Expect.toBe(true)
    t->expect(responseById(calls, JSON.Encode.string("second"))->Option.isSome)->Expect.toBe(true)
  })

  testAsync(
    "retains capacity for cancelled abort-ignoring executions until settlement",
    async t => {
      let resolvers: Dict.t<unit => unit> = Dict.make()
      let cancelledSignal = ref(None)
      let serverInterface = makeServerInterface(
        ~executeTool=async (
          _,
          ~name as _,
          ~arguments as _,
          ~taskId,
          ~toolCallId as _,
          ~onProgress as _,
          ~signal,
        ) => {
          switch taskId {
          | "task-0" => cancelledSignal := Some(signal)
          | _ => ()
          }
          await Promise.make((resolve, _) => resolvers->Dict.set(taskId, resolve))
          Types.CallToolResult.makeText(taskId)
        },
      )
      let (channel, calls) = MockChannel.make()
      let handler = makeHandler(channel, serverInterface)
      let executions = Belt.Array.makeBy(
        256,
        index =>
          MCP.handleMessage(
            handler,
            callRequest(
              ~id=JSON.Encode.string(`request-${index->Int.toString}`),
              ~taskId=`task-${index->Int.toString}`,
            ),
          ),
      )
      await MCP.handleMessage(
        handler,
        callRequest(~id=JSON.Encode.string("request-0-replay"), ~taskId="task-0"),
      )
      await MCP.handleMessage(handler, cancellation(JSON.Encode.string("request-0")))
      let executionSignal: WebAPI.EventAPI.abortSignal = cancelledSignal.contents->Option.getOrThrow
      t->expect(executionSignal.aborted)->Expect.toBe(false)
      await MCP.handleMessage(handler, cancellation(JSON.Encode.string("request-0-replay")))
      await MCP.handleMessage(
        handler,
        callRequest(~id=JSON.Encode.string("overflow"), ~taskId="overflow-task"),
      )

      t->expect(executionSignal.aborted)->Expect.toBe(true)
      t
      ->expect(
        responseById(calls, JSON.Encode.string("overflow"))->Option.getOrThrow->responseErrorCode,
      )
      ->Expect.toEqual(Some(Types.ErrorCode.internalError))
      let resolveCancelled = resolvers->Dict.get("task-0")->Option.getOrThrow
      resolveCancelled()
      await executions[0]->Option.getOrThrow
      let replacement = MCP.handleMessage(
        handler,
        callRequest(~id=JSON.Encode.string("replacement"), ~taskId="replacement-task"),
      )
      t->expect(resolvers->Dict.has("replacement-task"))->Expect.toBe(true)
      resolvers->Dict.forEach(resolve => resolve())
      let _ = await Promise.all(executions)
      await replacement
    },
  )

  testAsync("replays a completed durable result without reinvoking the tool", async t => {
    let invocationCount = ref(0)
    let serverInterface = makeServerInterface(
      ~executeTool=async (
        _,
        ~name as _,
        ~arguments as _,
        ~taskId as _,
        ~toolCallId as _,
        ~onProgress as _,
        ~signal as _,
      ) => {
        invocationCount := invocationCount.contents + 1
        Types.CallToolResult.makeText("cached")
      },
    )
    let (channel, calls) = MockChannel.make()
    let handler = makeHandler(channel, serverInterface)
    await MCP.handleMessage(handler, callRequest(~id=JSON.Encode.string("first")))
    await MCP.handleMessage(handler, callRequest(~id=JSON.Encode.string("replay")))
    await MCP.handleMessage(
      handler,
      callRequest(
        ~id=JSON.Encode.string("changed-replay"),
        ~arguments=Dict.fromArray([("quality", JSON.Encode.string("high"))]),
      ),
    )

    t->expect(invocationCount.contents)->Expect.toBe(1)
    t->expect(responseById(calls, JSON.Encode.string("replay"))->Option.isSome)->Expect.toBe(true)
    t
    ->expect(
      responseById(calls, JSON.Encode.string("changed-replay"))
      ->Option.getOrThrow
      ->responseErrorCode,
    )
    ->Expect.toEqual(Some(Types.ModernErrorCode.invalidRequest))
  })

  testAsync("rejects unsupported continuation fields before execution", async t => {
    let invocationCount = ref(0)
    let serverInterface = makeServerInterface(
      ~executeTool=async (
        _,
        ~name as _,
        ~arguments as _,
        ~taskId as _,
        ~toolCallId as _,
        ~onProgress as _,
        ~signal as _,
      ) => {
        invocationCount := invocationCount.contents + 1
        Types.CallToolResult.makeText("unexpected")
      },
    )
    let (channel, calls) = MockChannel.make()
    let handler = makeHandler(channel, serverInterface)
    await MCP.handleMessage(
      handler,
      callRequest(~id=JSON.Encode.string("responses"), ~inputResponses=Dict.make()),
    )
    await MCP.handleMessage(
      handler,
      callRequest(~id=JSON.Encode.string("state"), ~requestState="opaque"),
    )

    t->expect(invocationCount.contents)->Expect.toBe(0)
    t
    ->expect(
      responseById(calls, JSON.Encode.string("responses"))->Option.getOrThrow->responseErrorCode,
    )
    ->Expect.toEqual(Some(Types.ErrorCode.invalidParams))
    t
    ->expect(responseById(calls, JSON.Encode.string("state"))->Option.getOrThrow->responseErrorCode)
    ->Expect.toEqual(Some(Types.ErrorCode.invalidParams))
    t->expect(handler.durableExecutionFingerprints.contents->Dict.size)->Expect.toBe(0)
  })

  testAsync("tombstones a result evicted by the 257th completion", async t => {
    let invocationCount = ref(0)
    let serverInterface = makeServerInterface(
      ~executeTool=async (
        _,
        ~name as _,
        ~arguments as _,
        ~taskId as _,
        ~toolCallId as _,
        ~onProgress as _,
        ~signal as _,
      ) => {
        invocationCount := invocationCount.contents + 1
        Types.CallToolResult.makeText("cached")
      },
    )
    let (channel, calls) = MockChannel.make()
    let handler = makeHandler(channel, serverInterface)
    for index in 0 to 256 {
      await MCP.handleMessage(
        handler,
        callRequest(
          ~id=JSON.Encode.string(`request-${index->Int.toString}`),
          ~taskId=`task-${index->Int.toString}`,
        ),
      )
    }
    t->expect(handler.completedExecutions.contents->Dict.size)->Expect.toBe(256)
    let retainedIdentityBytes = handler.durableExecutionFingerprintBytes.contents
    await MCP.handleMessage(
      handler,
      callRequest(~id=JSON.Encode.string("evicted-replay"), ~taskId="task-0"),
    )

    t->expect(invocationCount.contents)->Expect.toBe(257)
    t->expect(handler.durableExecutionFingerprintBytes.contents)->Expect.toBe(retainedIdentityBytes)
    t
    ->expect(
      responseById(calls, JSON.Encode.string("evicted-replay"))
      ->Option.getOrThrow
      ->responseErrorCode,
    )
    ->Expect.toEqual(Some(Types.ModernErrorCode.invalidRequest))
  })

  testAsync("bounds durable keys and fingerprints at exactly one aggregate MiB", async t => {
    let invocationCount = ref(0)
    let (channel, calls) = MockChannel.make()
    let handler = makeHandler(
      channel,
      makeServerInterface(
        ~executeTool=async (
          _,
          ~name as _,
          ~arguments as _,
          ~taskId as _,
          ~toolCallId as _,
          ~onProgress as _,
          ~signal as _,
        ) => {
          invocationCount := invocationCount.contents + 1
          Types.CallToolResult.makeText("cached")
        },
      ),
    )
    let executionKey = MCP.durableKey(~taskId="task-1", ~toolCallId="tool-call-1")
    let emptyArguments = Dict.fromArray([("payload", JSON.Encode.string(""))])
    let emptyFingerprint = MCP.executionFingerprint(
      ~name="take_screenshot",
      ~arguments=Some(emptyArguments),
    )
    let paddingBytes =
      MCP.maxDurableExecutionFingerprintBytes -
      MCP.utf8Bytes(executionKey) -
      MCP.utf8Bytes(emptyFingerprint)
    let exactArguments = Dict.fromArray([
      ("payload", JSON.Encode.string(utf8Payload(paddingBytes))),
    ])
    await MCP.handleMessage(
      handler,
      callRequest(~id=JSON.Encode.string("exact"), ~arguments=exactArguments),
    )
    await MCP.handleMessage(
      handler,
      callRequest(~id=JSON.Encode.string("exact-replay"), ~arguments=exactArguments),
    )
    await MCP.handleMessage(
      handler,
      callRequest(~id=JSON.Encode.string("aggregate-over"), ~taskId="task-2"),
    )

    t->expect(invocationCount.contents)->Expect.toBe(1)
    t
    ->expect(handler.durableExecutionFingerprintBytes.contents)
    ->Expect.toBe(MCP.maxDurableExecutionFingerprintBytes)
    t->expect(handler.durableExecutionFingerprints.contents->Dict.size)->Expect.toBe(1)
    t
    ->expect(
      responseById(calls, JSON.Encode.string("exact-replay"))
      ->Option.getOrThrow
      ->responseErrorCode,
    )
    ->Expect.toEqual(None)
    t
    ->expect(
      responseById(calls, JSON.Encode.string("aggregate-over"))
      ->Option.getOrThrow
      ->responseErrorCode,
    )
    ->Expect.toEqual(Some(Types.ErrorCode.internalError))
  })

  testAsync("rejects a one-byte-over durable identity before execution", async t => {
    let invocationCount = ref(0)
    let (channel, calls) = MockChannel.make()
    let handler = makeHandler(
      channel,
      makeServerInterface(
        ~executeTool=async (
          _,
          ~name as _,
          ~arguments as _,
          ~taskId as _,
          ~toolCallId as _,
          ~onProgress as _,
          ~signal as _,
        ) => {
          invocationCount := invocationCount.contents + 1
          Types.CallToolResult.makeText("unexpected")
        },
      ),
    )
    let executionKey = MCP.durableKey(~taskId="task-1", ~toolCallId="tool-call-1")
    let emptyArguments = Dict.fromArray([("payload", JSON.Encode.string(""))])
    let emptyFingerprint = MCP.executionFingerprint(
      ~name="take_screenshot",
      ~arguments=Some(emptyArguments),
    )
    let paddingBytes =
      MCP.maxDurableExecutionFingerprintBytes +
      1 -
      MCP.utf8Bytes(executionKey) -
      MCP.utf8Bytes(emptyFingerprint)
    await MCP.handleMessage(
      handler,
      callRequest(
        ~id=JSON.Encode.string("over"),
        ~arguments=Dict.fromArray([("payload", JSON.Encode.string(utf8Payload(paddingBytes)))]),
      ),
    )

    t->expect(invocationCount.contents)->Expect.toBe(0)
    t->expect(handler.durableExecutionFingerprintBytes.contents)->Expect.toBe(0)
    t->expect(handler.durableExecutionFingerprints.contents->Dict.size)->Expect.toBe(0)
    t
    ->expect(responseById(calls, JSON.Encode.string("over"))->Option.getOrThrow->responseErrorCode)
    ->Expect.toEqual(Some(Types.ErrorCode.internalError))
  })

  testAsync("rejects the 4097th distinct durable key without execution", async t => {
    let invocationCount = ref(0)
    let (channel, calls) = MockChannel.make()
    let handler = makeHandler(
      channel,
      makeServerInterface(
        ~executeTool=async (
          _,
          ~name as _,
          ~arguments as _,
          ~taskId as _,
          ~toolCallId as _,
          ~onProgress as _,
          ~signal as _,
        ) => {
          invocationCount := invocationCount.contents + 1
          Types.CallToolResult.makeText("unexpected")
        },
      ),
    )
    for index in 0 to 4095 {
      let executionKey = MCP.durableKey(
        ~taskId=`task-${index->Int.toString}`,
        ~toolCallId="tool-call-1",
      )
      let fingerprint = "fingerprint"
      handler.durableExecutionFingerprints.contents->Dict.set(executionKey, fingerprint)
      handler.durableExecutionFingerprintBytes :=
        handler.durableExecutionFingerprintBytes.contents +
        MCP.utf8Bytes(executionKey) +
        MCP.utf8Bytes(fingerprint)
    }
    await MCP.handleMessage(
      handler,
      callRequest(~id=JSON.Encode.string("overflow"), ~taskId="task-4096"),
    )

    t->expect(invocationCount.contents)->Expect.toBe(0)
    t->expect(handler.durableExecutionFingerprints.contents->Dict.size)->Expect.toBe(4096)
    t
    ->expect(
      handler.durableExecutionFingerprintBytes.contents < MCP.maxDurableExecutionFingerprintBytes,
    )
    ->Expect.toBe(true)
    t
    ->expect(
      responseById(calls, JSON.Encode.string("overflow"))->Option.getOrThrow->responseErrorCode,
    )
    ->Expect.toEqual(Some(Types.ErrorCode.internalError))
    MCP.detach(handler)
    t->expect(handler.durableExecutionFingerprints.contents->Dict.size)->Expect.toBe(0)
    t->expect(handler.durableExecutionFingerprintBytes.contents)->Expect.toBe(0)
  })

  test("bounds cached results at exactly one aggregate MiB", t => {
    let (channel, _) = MockChannel.make()
    let handler = makeHandler(channel, completedServerInterface())
    MCP.cacheCompletedExecution(
      handler,
      "exact",
      {
        fingerprint: "exact",
        result: MCP.Success(JSON.Encode.string("a"->String.repeat(1048574))),
      },
    )
    t->expect(handler.completedExecutionBytes.contents)->Expect.toBe(1048576)
    t->expect(handler.completedExecutions.contents->Dict.has("exact"))->Expect.toBe(true)

    MCP.cacheCompletedExecution(
      handler,
      "aggregate-over",
      {
        fingerprint: "aggregate-over",
        result: MCP.Success(JSON.Encode.null),
      },
    )
    t->expect(handler.completedExecutionBytes.contents)->Expect.toBe(4)
    t->expect(handler.completedExecutions.contents->Dict.has("exact"))->Expect.toBe(false)
    t->expect(handler.completedExecutions.contents->Dict.has("aggregate-over"))->Expect.toBe(true)

    MCP.cacheCompletedExecution(
      handler,
      "over",
      {
        fingerprint: "over",
        result: MCP.Success(JSON.Encode.string("a"->String.repeat(1048575))),
      },
    )
    t->expect(handler.completedExecutionBytes.contents)->Expect.toBe(4)
    t->expect(handler.completedExecutions.contents->Dict.has("over"))->Expect.toBe(false)
  })

  testAsync("tombstones a completed result omitted for cache size", async t => {
    let invocationCount = ref(0)
    let serverInterface = makeServerInterface(
      ~executeTool=async (
        _,
        ~name as _,
        ~arguments as _,
        ~taskId as _,
        ~toolCallId as _,
        ~onProgress as _,
        ~signal as _,
      ) => {
        invocationCount := invocationCount.contents + 1
        Types.CallToolResult.makeText("x"->String.repeat(1048576))
      },
    )
    let (channel, calls) = MockChannel.make()
    let handler = makeHandler(channel, serverInterface)
    await MCP.handleMessage(handler, callRequest(~id=JSON.Encode.string("initial")))
    t->expect(responseById(calls, JSON.Encode.string("initial"))->Option.isSome)->Expect.toBe(true)
    t->expect(handler.completedExecutions.contents->Dict.size)->Expect.toBe(0)
    await MCP.handleMessage(handler, callRequest(~id=JSON.Encode.string("replay")))

    t->expect(invocationCount.contents)->Expect.toBe(1)
    t
    ->expect(
      responseById(calls, JSON.Encode.string("replay"))->Option.getOrThrow->responseErrorCode,
    )
    ->Expect.toEqual(Some(Types.ModernErrorCode.invalidRequest))
  })

  testAsync("does not let another method answer an active call id", async t => {
    let resolveExecution = ref(None)
    let serverInterface = makeServerInterface(
      ~executeTool=async (
        _,
        ~name as _,
        ~arguments as _,
        ~taskId as _,
        ~toolCallId as _,
        ~onProgress as _,
        ~signal as _,
      ) => {
        await Promise.make((resolve, _) => resolveExecution := Some(resolve))
        Types.CallToolResult.makeText("ok")
      },
    )
    let (channel, calls) = MockChannel.make()
    let handler = makeHandler(channel, serverInterface)
    let execution = MCP.handleMessage(handler, callRequest(~id=JSON.Encode.string("same")))
    await MCP.handleMessage(
      handler,
      request(
        ~id=JSON.Encode.string("same"),
        ~method="server/discover",
        ~params=JSON.Encode.object(Dict.fromArray([("_meta", requestMeta())])),
      ),
    )

    t->expect(calls.contents->Array.length)->Expect.toBe(0)
    let resolve = resolveExecution.contents->Option.getOrThrow
    resolve()
    await execution
    t->expect(calls.contents->Array.length)->Expect.toBe(1)
  })

  testAsync("rejects a supplied list cursor", async t => {
    let (channel, calls) = MockChannel.make()
    let payload = request(
      ~method="tools/list",
      ~params=JSON.Encode.object(
        Dict.fromArray([("_meta", requestMeta()), ("cursor", JSON.Encode.string("page-2"))]),
      ),
    )
    await MCP.handleMessage(makeHandler(channel, completedServerInterface()), payload)

    t
    ->expect(responseById(calls, JSON.Encode.int(1))->Option.getOrThrow->responseErrorCode)
    ->Expect.toEqual(Some(Types.ErrorCode.invalidParams))
  })

  testAsync("rejects an explicitly empty list cursor", async t => {
    let (channel, calls) = MockChannel.make()
    let payload = request(
      ~method="tools/list",
      ~params=JSON.Encode.object(
        Dict.fromArray([("_meta", requestMeta()), ("cursor", JSON.Encode.string(""))]),
      ),
    )
    await MCP.handleMessage(makeHandler(channel, completedServerInterface()), payload)

    t
    ->expect(responseById(calls, JSON.Encode.int(1))->Option.getOrThrow->responseErrorCode)
    ->Expect.toEqual(Some(Types.ErrorCode.invalidParams))
  })

  testAsync("detaches only its listener and fences active calls", async t => {
    let resolvers: Dict.t<unit => unit> = Dict.make()
    let signals: Dict.t<WebAPI.EventAPI.abortSignal> = Dict.make()
    let serverInterface = makeServerInterface(
      ~executeTool=async (
        _,
        ~name as _,
        ~arguments as _,
        ~taskId,
        ~toolCallId as _,
        ~onProgress as _,
        ~signal as executionSignal,
      ) => {
        switch taskId {
        | "completed-task" => Types.CallToolResult.makeText("completed")
        | _ =>
          signals->Dict.set(taskId, executionSignal)
          await Promise.make((resolve, _) => resolvers->Dict.set(taskId, resolve))
          Types.CallToolResult.makeText("late")
        }
      },
    )
    let (channel, calls) = MockChannel.make()
    let unrelatedCalls = ref(0)
    channel
    ->FrontmanClient__Phoenix__Channel.on(
      ~event=#"mcp:message",
      ~callback=_ => unrelatedCalls := unrelatedCalls.contents + 1,
    )
    ->ignore
    let handler = MCP.attach(~channel, ~serverInterface)
    await MCP.handleMessage(
      handler,
      callRequest(~id=JSON.Encode.string("completed"), ~taskId="completed-task"),
    )
    t->expect(handler.completedExecutions.contents->Dict.size)->Expect.toBe(1)
    let first = MCP.handleMessage(handler, callRequest(~taskId="first-task"))
    let second = MCP.handleMessage(
      handler,
      callRequest(~id=JSON.Encode.string("second"), ~taskId="second-task"),
    )

    MCP.detach(handler)
    signals->Dict.forEach(signal => t->expect(signal.aborted)->Expect.toBe(true))
    t->expect(handler.activeRequests.contents->Dict.size)->Expect.toBe(0)
    t->expect(handler.durableExecutions.contents->Dict.size)->Expect.toBe(0)
    t->expect(handler.durableExecutionFingerprints.contents->Dict.size)->Expect.toBe(0)
    t->expect(handler.durableExecutionFingerprintBytes.contents)->Expect.toBe(0)
    t->expect(handler.completedExecutions.contents->Dict.size)->Expect.toBe(0)
    t->expect(handler.completedExecutionBytes.contents)->Expect.toBe(0)
    MockChannel.emit(channel, JSON.Encode.object(Dict.make()))
    t->expect(unrelatedCalls.contents)->Expect.toBe(1)
    resolvers->Dict.forEach(resolve => resolve())
    await first
    await second
    t->expect(calls.contents->Array.length)->Expect.toBe(1)
  })

  testAsync("returns invalid request when a malformed request has a recoverable id", async t => {
    let (channel, calls) = MockChannel.make()
    let payload = JSON.parseOrThrow(`{"jsonrpc":"2.0","id":"request-8","params":{}}`)
    await MCP.handleMessage(makeHandler(channel, completedServerInterface()), payload)

    let response = responseById(calls, JSON.Encode.string("request-8"))->Option.getOrThrow
    t
    ->expect(responseErrorCode(response))
    ->Expect.toEqual(Some(Types.ModernErrorCode.invalidRequest))
    t->expect(calls.contents->Array.length)->Expect.toBe(1)
  })

  testAsync("does not respond to a malformed response envelope", async t => {
    let (channel, calls) = MockChannel.make()
    let payload = JSON.parseOrThrow(`{"jsonrpc":"2.0","id":"response-1","result":{}}`)
    await MCP.handleMessage(makeHandler(channel, completedServerInterface()), payload)

    t->expect(calls.contents->Array.length)->Expect.toBe(0)
  })
})

describe("browser MCP server policy", () => {
  testAsync(
    "accepts underlying execution 256, rejects 257, and resets at exactly 60000ms",
    async t => {
      Vi.useFakeTimers()->ignore
      LimitedLocalTool.executionCount := 0
      let authorizationCount = ref(0)
      let server = makeLocalServer(
        ~authorizeTool=async (~name as _, ~arguments as _, ~readOnly as _, ~readOnlyTools as _) => {
          authorizationCount := authorizationCount.contents + 1
          true
        },
      )
      let execute = async index =>
        await MCPServer.executeTool(
          server,
          ~name=LimitedLocalTool.name,
          ~taskId=`task-${index->Int.toString}`,
          ~toolCallId=`call-${index->Int.toString}`,
          ~signal=WebAPI.AbortController.make().signal,
        )

      for index in 1 to 256 {
        t->expect((await execute(index))->resultIsError)->Expect.toBe(false)
      }
      t->expect((await execute(257))->resultIsError)->Expect.toBe(true)
      t->expect(authorizationCount.contents)->Expect.toBe(256)
      t->expect(LimitedLocalTool.executionCount.contents)->Expect.toBe(256)

      let _ = await Vi.advanceTimersByTimeAsync(59999)
      t->expect((await execute(258))->resultIsError)->Expect.toBe(true)
      t->expect(authorizationCount.contents)->Expect.toBe(256)

      let _ = await Vi.advanceTimersByTimeAsync(1)
      t->expect((await execute(259))->resultIsError)->Expect.toBe(false)
      t->expect(authorizationCount.contents)->Expect.toBe(257)
      t->expect(LimitedLocalTool.executionCount.contents)->Expect.toBe(257)
    },
  )

  testAsync("does not charge completed replays as new invocations", async t => {
    LimitedLocalTool.executionCount := 0
    let authorizationCount = ref(0)
    let server = makeLocalServer(
      ~authorizeTool=async (~name as _, ~arguments as _, ~readOnly as _, ~readOnlyTools as _) => {
        authorizationCount := authorizationCount.contents + 1
        true
      },
    )
    let (channel, calls) = MockChannel.make()
    let handler = MCP.makeHandler(~channel, ~serverInterface=server->MCPServer.toInterface)
    let first = callRequest(
      ~id=JSON.Encode.string("first"),
      ~name=LimitedLocalTool.name,
      ~taskId="task-first",
      ~toolCallId="call-first",
    )
    await MCP.handleMessage(handler, first)
    await MCP.handleMessage(
      handler,
      callRequest(
        ~id=JSON.Encode.string("replay"),
        ~name=LimitedLocalTool.name,
        ~taskId="task-first",
        ~toolCallId="call-first",
      ),
    )
    for index in 2 to 256 {
      await MCP.handleMessage(
        handler,
        callRequest(
          ~id=JSON.Encode.string(`request-${index->Int.toString}`),
          ~name=LimitedLocalTool.name,
          ~taskId=`task-${index->Int.toString}`,
          ~toolCallId=`call-${index->Int.toString}`,
        ),
      )
    }
    await MCP.handleMessage(
      handler,
      callRequest(
        ~id=JSON.Encode.string("overflow"),
        ~name=LimitedLocalTool.name,
        ~taskId="task-overflow",
        ~toolCallId="call-overflow",
      ),
    )

    t->expect(responseById(calls, JSON.Encode.string("replay"))->Option.isSome)->Expect.toBe(true)
    t->expect(authorizationCount.contents)->Expect.toBe(256)
    t->expect(LimitedLocalTool.executionCount.contents)->Expect.toBe(256)
    let overflow = responseById(calls, JSON.Encode.string("overflow"))->Option.getOrThrow
    t->expect(responseErrorCode(overflow))->Expect.toBeNone
    let overflowResult =
      overflow
      ->JSON.Decode.object
      ->Option.flatMap(fields => fields->Dict.get("result"))
      ->Option.getOrThrow
      ->S.parseOrThrow(~to=Types.CallToolResult.schema)
    t->expect(overflowResult->resultIsError)->Expect.toBe(true)
  })

  testAsync("retains the invocation window when the transport handler is reattached", async t => {
    LimitedLocalTool.executionCount := 0
    let server = makeLocalServer()
    let (firstChannel, _) = MockChannel.make()
    let firstHandler = MCP.makeHandler(
      ~channel=firstChannel,
      ~serverInterface=server->MCPServer.toInterface,
    )
    for index in 1 to 128 {
      await MCP.handleMessage(
        firstHandler,
        callRequest(
          ~id=JSON.Encode.string(`first-${index->Int.toString}`),
          ~name=LimitedLocalTool.name,
          ~taskId=`first-task-${index->Int.toString}`,
          ~toolCallId=`first-call-${index->Int.toString}`,
        ),
      )
    }
    MCP.detach(firstHandler)

    let (secondChannel, secondCalls) = MockChannel.make()
    let secondHandler = MCP.makeHandler(
      ~channel=secondChannel,
      ~serverInterface=server->MCPServer.toInterface,
    )
    for index in 129 to 256 {
      await MCP.handleMessage(
        secondHandler,
        callRequest(
          ~id=JSON.Encode.string(`second-${index->Int.toString}`),
          ~name=LimitedLocalTool.name,
          ~taskId=`second-task-${index->Int.toString}`,
          ~toolCallId=`second-call-${index->Int.toString}`,
        ),
      )
    }
    await MCP.handleMessage(
      secondHandler,
      callRequest(
        ~id=JSON.Encode.string("reattach-overflow"),
        ~name=LimitedLocalTool.name,
        ~taskId="reattach-overflow-task",
        ~toolCallId="reattach-overflow-call",
      ),
    )

    t->expect(LimitedLocalTool.executionCount.contents)->Expect.toBe(256)
    let overflow =
      responseById(secondCalls, JSON.Encode.string("reattach-overflow"))->Option.getOrThrow
    let overflowResult =
      overflow
      ->JSON.Decode.object
      ->Option.flatMap(fields => fields->Dict.get("result"))
      ->Option.getOrThrow
      ->S.parseOrThrow(~to=Types.CallToolResult.schema)
    t->expect(overflowResult->resultIsError)->Expect.toBe(true)
  })

  testAsync("merges browser server identity into local and denied results", async t => {
    LimitedLocalTool.executionCount := 0
    let localResult = await MCPServer.executeTool(
      makeLocalServer(),
      ~name=LimitedLocalTool.name,
      ~taskId="identity-task",
      ~toolCallId="identity-call",
      ~signal=WebAPI.AbortController.make().signal,
    )
    let localInfo = localResult->resultServerInfo
    t->expect(localInfo.name)->Expect.toBe("browser-test-server")
    t->expect(localInfo.version)->Expect.toBe("4.5.6")
    t
    ->expect(localResult->resultMetadata->Dict.get("com.example/preserved"))
    ->Expect.toEqual(Some(JSON.parseOrThrow(`{"value":true}`)))

    let deniedResult = await MCPServer.executeTool(
      makeLocalServer(
        ~authorizeTool=async (~name as _, ~arguments as _, ~readOnly as _, ~readOnlyTools as _) =>
          false,
      ),
      ~name=LimitedLocalTool.name,
      ~taskId="denied-task",
      ~toolCallId="denied-call",
      ~signal=WebAPI.AbortController.make().signal,
    )
    let deniedInfo = deniedResult->resultServerInfo
    t->expect(deniedResult->resultIsError)->Expect.toBe(true)
    t->expect(deniedInfo.name)->Expect.toBe("browser-test-server")
    t->expect(deniedInfo.version)->Expect.toBe("4.5.6")
  })

  testAsync(
    "returns and replays a generic internal error when forwarded output validation fails",
    async t => {
      let testServer = await FrontmanClient__MCP__TestServer.start()
      let frameworkClient = FrontmanClient__MCP__Client.make(~baseUrl=testServer.baseUrl)
      try {
        (await frameworkClient->FrontmanClient__MCP__Client.connect)->Result.getOrThrow
        let server = FrontmanClient__MCP__Server.make(~frameworkClient)
        let (channel, calls) = MockChannel.make()
        let handler = MCP.makeHandler(
          ~channel,
          ~serverInterface=server->FrontmanClient__MCP__Server.toInterface,
        )
        let callCountBefore = testServer.counts().callCount
        let requestId = JSON.Encode.string("schema-invalid-forwarded-output")
        await MCP.handleMessage(
          handler,
          callRequest(
            ~id=requestId,
            ~name="slow_output",
            ~taskId="schema-invalid-task",
            ~toolCallId="schema-invalid-call",
          ),
        )

        let response = responseById(calls, requestId)->Option.getOrThrow
        let responseFields = response->JSON.Decode.object->Option.getOrThrow
        t
        ->expect(responseErrorCode(response))
        ->Expect.toEqual(Some(Types.ErrorCode.internalError))
        t->expect(responseErrorMessage(response))->Expect.toEqual(Some("Tool execution failed"))
        t
        ->expect(JSON.stringify(response)->String.includes("Tool output validation timed out"))
        ->Expect.toBe(false)
        t->expect(responseFields->Dict.has("result"))->Expect.toBe(false)
        t->expect(testServer.counts().callCount)->Expect.toBe(callCountBefore + 1)
        let completed =
          handler.completedExecutions.contents
          ->Dict.get(
            MCP.durableKey(~taskId="schema-invalid-task", ~toolCallId="schema-invalid-call"),
          )
          ->Option.getOrThrow
        switch completed.result {
        | MCP.Failure(_) => ()
        | MCP.Success(_) => t->expect("success result")->Expect.toBe("internal error")
        }

        let replayId = JSON.Encode.string("schema-invalid-forwarded-output-replay")
        await MCP.handleMessage(
          handler,
          callRequest(
            ~id=replayId,
            ~name="slow_output",
            ~taskId="schema-invalid-task",
            ~toolCallId="schema-invalid-call",
          ),
        )
        let replay = responseById(calls, replayId)->Option.getOrThrow
        let replayFields = replay->JSON.Decode.object->Option.getOrThrow
        t->expect(responseErrorCode(replay))->Expect.toEqual(Some(Types.ErrorCode.internalError))
        t->expect(responseErrorMessage(replay))->Expect.toEqual(Some("Tool execution failed"))
        t
        ->expect(JSON.stringify(replay)->String.includes("Tool output validation timed out"))
        ->Expect.toBe(false)
        t->expect(replayFields->Dict.has("result"))->Expect.toBe(false)
        t->expect(testServer.counts().callCount)->Expect.toBe(callCountBefore + 1)
      } catch {
      | exn =>
        await testServer.close()
        throw(exn)
      }
      await testServer.close()
    },
  )
})

describe("attachment resolution metadata", () => {
  testAsync("does not invoke a framework tool when host consent is denied", async t => {
    let testServer = await FrontmanClient__MCP__TestServer.start()
    let frameworkClient = FrontmanClient__MCP__Client.make(~baseUrl=testServer.baseUrl)
    let connectResult = await frameworkClient->FrontmanClient__MCP__Client.connect
    connectResult->Result.getOrThrow
    let server = FrontmanClient__MCP__Server.make(
      ~frameworkClient,
      ~authorizeTool=async (~name as _, ~arguments as _, ~readOnly as _, ~readOnlyTools as _) =>
        false,
    )

    let result = await FrontmanClient__MCP__Server.executeTool(
      server,
      ~name="attachment_tool",
      ~taskId="task-denied",
      ~toolCallId="call-denied",
      ~signal=WebAPI.AbortController.make().signal,
    )
    let toolCalls = testServer.requests->Array.filter(
      request =>
        request.body
        ->JSON.Decode.object
        ->Option.flatMap(fields => fields->Dict.get("method")) ==
          Some(JSON.Encode.string("tools/call")),
    )

    t->expect(toolCalls->Array.length)->Expect.toBe(0)
    let resultJson = result->S.decodeOrThrow(~from=Types.CallToolResult.schema, ~to=S.json)
    t
    ->expect(resultJson->JSON.stringify->String.includes("Tool invocation denied by user"))
    ->Expect.toBe(true)
    await testServer.close()
  })

  testAsync(
    "resolves documented remote argument metadata without tool-name conventions",
    async t => {
      let testServer = await FrontmanClient__MCP__TestServer.start()
      let frameworkClient = FrontmanClient__MCP__Client.make(~baseUrl=testServer.baseUrl)
      let connectResult = await frameworkClient->FrontmanClient__MCP__Client.connect
      connectResult->Result.getOrThrow
      let authorizationCalls = ref([])
      let server = FrontmanClient__MCP__Server.make(
        ~frameworkClient,
        ~authorizeTool=async (~name, ~arguments, ~readOnly, ~readOnlyTools as _) => {
          authorizationCalls :=
            authorizationCalls.contents->Array.concat([(name, arguments, readOnly)])
          true
        },
        ~resolveImageRef=(reference, ~taskId) =>
          switch (reference, taskId) {
          | ("attachment://asset-1/photo.png", "task-1") =>
            Some({base64: "cG5n", mediaType: "image/png"})
          | _ => None
          },
      )
      let result = await FrontmanClient__MCP__Server.executeTool(
        server,
        ~name="attachment_tool",
        ~arguments=Dict.fromArray([
          ("asset", JSON.Encode.string("attachment://asset-1/photo.png")),
        ]),
        ~taskId="task-1",
        ~toolCallId="call-1",
        ~signal=WebAPI.AbortController.make().signal,
      )
      let call =
        testServer.requests
        ->Array.find(
          request =>
            request.body
            ->JSON.Decode.object
            ->Option.flatMap(fields => fields->Dict.get("method")) ==
              Some(JSON.Encode.string("tools/call")),
        )
        ->Option.getOrThrow
      let arguments =
        call.body
        ->JSON.Decode.object
        ->Option.flatMap(fields => fields->Dict.get("params"))
        ->Option.flatMap(JSON.Decode.object)
        ->Option.flatMap(fields => fields->Dict.get("arguments"))
        ->Option.getOrThrow
      t->expect(authorizationCalls.contents->Array.length)->Expect.toBe(1)
      let (authorizedName, authorizedArguments, readOnly) =
        authorizationCalls.contents[0]->Option.getOrThrow
      t->expect(authorizedName)->Expect.toBe("attachment_tool")
      t->expect(authorizedArguments->Option.isSome)->Expect.toBe(true)
      t->expect(readOnly)->Expect.toBe(true)

      t
      ->expect(arguments)
      ->Expect.toEqual(
        JSON.parseOrThrow(`{"bytes":"cG5n","format":"base64","mediaType":"image/png"}`),
      )
      let serverInfo = result->resultServerInfo
      t->expect(serverInfo.name)->Expect.toBe("frontman-browser")
      t->expect(serverInfo.version)->Expect.toBe("1.0.0")
      await testServer.close()
    },
  )
})
