open Vitest

module MCP = FrontmanClient__MCP
module Types = FrontmanClient__MCP__Types
module JsonRpc = FrontmanAiFrontmanProtocol.FrontmanProtocol__JsonRpc

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
  ) => Types.CallToolResult.makeText("tool output"))

let makeHandler = (channel, serverInterface): MCP.mcpHandler<unit> => {
  serverInterface,
  channel,
  onMessage: None,
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

let discoverRequest = (~id=JSON.Encode.int(1), ~protocolVersion=Types.protocolVersion) =>
  request(
    ~id,
    ~method="server/discover",
    ~params=JSON.Encode.object(Dict.fromArray([("_meta", requestMeta(~protocolVersion))])),
  )

let listRequest = (~id=JSON.Encode.int(1)) =>
  request(
    ~id,
    ~method="tools/list",
    ~params=JSON.Encode.object(Dict.fromArray([("_meta", requestMeta())])),
  )

let callRequest = (~id=JSON.Encode.int(1), ~taskId="task-1", ~toolCallId="tool-call-1") =>
  request(
    ~id,
    ~method="tools/call",
    ~params=JSON.Encode.object(
      Dict.fromArray([
        ("_meta", requestMeta(~context=(taskId, toolCallId))),
        ("name", JSON.Encode.string("take_screenshot")),
      ]),
    ),
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
      ) => JsError.throwWithMessage("boom"),
    )
    let (channel, calls) = MockChannel.make()
    await MCP.handleMessage(makeHandler(channel, serverInterface), callRequest())

    let response = responseById(calls, JSON.Encode.int(1))->Option.getOrThrow
    t->expect(responseErrorCode(response))->Expect.toEqual(Some(Types.ErrorCode.internalError))
  })

  testAsync("accepts cancellation notifications without responding", async t => {
    let (channel, calls) = MockChannel.make()
    let handler = makeHandler(channel, completedServerInterface())
    let payload = JSON.parseOrThrow(`{"jsonrpc":"2.0","method":"notifications/cancelled","params":{"requestId":"request-7","reason":"user requested"}}`)
    await MCP.handleMessage(handler, payload)

    t->expect(calls.contents->Array.length)->Expect.toBe(0)
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
