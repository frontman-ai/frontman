open Vitest

module Types = FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP
module ContentBlock = FrontmanAiFrontmanProtocol.FrontmanProtocol__ContentBlock

let parsesWith = (json, schema) => {
  try {
    json->S.parseOrThrow(~to=schema)->ignore
    true
  } catch {
  | _ => false
  }
}

let object = fields => JSON.Encode.object(Dict.fromArray(fields))
let capabilityMetadata = frontmanDev => object([("frontman.dev", frontmanDev)])
let attributionMetadata = version =>
  capabilityMetadata(
    object([("agentAttribution", object([("version", JSON.Encode.int(version))]))]),
  )
let agent = (~id="executor", ~name="executor", ~displayName="Executor", ~color="#16A085") =>
  object([
    ("id", JSON.Encode.string(id)),
    ("name", JSON.Encode.string(name)),
    ("displayName", JSON.Encode.string(displayName)),
    ("description", JSON.Encode.string("Implements approved work")),
    ("color", JSON.Encode.string(color)),
  ])
let attributionConfiguration = (~agents, ~defaultAgentId="executor") =>
  object([
    ("agentAttribution", object([("version", JSON.Encode.int(1))])),
    ("agents", JSON.Encode.array(agents)),
    ("defaultAgentId", JSON.Encode.string(defaultAgentId)),
  ])
let messageMetadata = (~agentId="executor", ~timestamp) =>
  object([
    ("frontman.dev/agentId", JSON.Encode.string(agentId)),
    ("frontman.dev/timestamp", JSON.Encode.string(timestamp)),
  ])

describe("Frontman agent attribution metadata", () => {
  test("capability metadata rejects malformed advertisements", t => {
    [
      capabilityMetadata(JSON.Encode.string("invalid")),
      capabilityMetadata(object([("agentAttribution", JSON.Encode.string("invalid"))])),
      attributionMetadata(0),
      attributionMetadata(65536),
    ]->Array.forEach(
      json => t->expect(json->parsesWith(Types.capabilityMetadataSchema))->Expect.toBe(false),
    )
  })

  test("initialization configuration validates catalog and default", t => {
    [
      attributionConfiguration(~agents=[]),
      attributionConfiguration(~agents=[agent(~id="")]),
      attributionConfiguration(~agents=[agent(~name="")]),
      attributionConfiguration(~agents=[agent(~displayName="")]),
      attributionConfiguration(~agents=[agent(~color="blue")]),
      attributionConfiguration(~agents=[agent(), agent(~name="other")]),
      attributionConfiguration(~agents=[agent()], ~defaultAgentId=""),
      attributionConfiguration(~agents=[agent()], ~defaultAgentId="planner"),
    ]->Array.forEach(
      json =>
        t
        ->expect(json->parsesWith(Types.agentAttributionConfigurationMetadataSchema))
        ->Expect.toBe(false),
    )
    t
    ->expect(
      attributionConfiguration(
        ~agents=[agent(~id="constructor")],
        ~defaultAgentId="constructor",
      )->parsesWith(Types.agentAttributionConfigurationMetadataSchema),
    )
    ->Expect.toBe(true)
  })

  test("initialization configuration accepts unrelated metadata", t => {
    let configuration = attributionConfiguration(~agents=[agent()])
    configuration
    ->JSON.Decode.object
    ->Option.getOrThrow
    ->Dict.set("unrelated.dev/value", JSON.Encode.bool(true))

    t
    ->expect(configuration->parsesWith(Types.agentAttributionConfigurationMetadataSchema))
    ->Expect.toBe(true)
  })

  test("message metadata validates identity and RFC 3339 timestamp", t => {
    let valid = object([
      ("frontman.dev/agentId", JSON.Encode.string("executor")),
      ("frontman.dev/timestamp", JSON.Encode.string("2026-07-14T12:30:01.123456Z")),
      ("unrelated.dev/value", JSON.Encode.bool(true)),
    ])

    t->expect(valid->parsesWith(Types.messageMetadataSchema))->Expect.toBe(true)
    t
    ->expect(
      messageMetadata(~timestamp="2026-07-14T14:30:01+02:00")->parsesWith(
        Types.messageMetadataSchema,
      ),
    )
    ->Expect.toBe(true)
    [
      messageMetadata(~agentId="", ~timestamp="2026-07-14T12:30:01Z"),
      messageMetadata(~timestamp="July 14, 2026"),
      messageMetadata(~timestamp="2026-02-30T12:30:01Z"),
    ]->Array.forEach(
      json => t->expect(json->parsesWith(Types.messageMetadataSchema))->Expect.toBe(false),
    )
  })
})

describe("ACP Types encoding/decoding", _t => {
  test("base result schemas preserve raw extension metadata", t => {
    let metadata = object([
      ("other.vendor", JSON.Encode.bool(true)),
      ("frontman.dev", JSON.Encode.string("future-shape")),
      ("frontman.dev/agents", JSON.Encode.string("future-catalog")),
    ])
    let initialize = JSON.parseOrThrow(`{"protocolVersion":1,"agentCapabilities":{}}`)
    initialize
    ->JSON.Decode.object
    ->Option.getOrThrow
    ->Dict.get("agentCapabilities")
    ->Option.flatMap(JSON.Decode.object)
    ->Option.getOrThrow
    ->Dict.set("_meta", metadata)
    let session = object([("sessionId", JSON.Encode.string("task-1")), ("_meta", metadata)])

    let initializeResult = initialize->S.parseOrThrow(~to=Types.initializeResultSchema)
    let sessionResult = session->S.parseOrThrow(~to=Types.sessionNewResultSchema)

    t
    ->expect(initializeResult.agentCapabilities->Option.flatMap(c => c._meta))
    ->Expect.toEqual(Some(metadata))
    t->expect(sessionResult._meta)->Expect.toEqual(Some(metadata))
  })

  test("initializeResult should decode without throwing", t => {
    let json = Dict.make()
    json->Dict.set("protocolVersion", JSON.Encode.int(1))

    let agentInfo = Dict.make()
    agentInfo->Dict.set("name", JSON.Encode.string("test-agent"))
    agentInfo->Dict.set("version", JSON.Encode.string("1.0.0"))
    json->Dict.set("agentInfo", JSON.Encode.object(agentInfo))

    let payload = JSON.Encode.object(json)
    let decoded = payload->S.parseOrThrow(~to=Types.initializeResultSchema)

    t->expect(decoded.protocolVersion)->Expect.toEqual(1)
    t->expect(decoded.agentInfo->Option.map(i => i.name))->Expect.toEqual(Some("test-agent"))
  })

  test("initializeResult with full agentCapabilities should decode", t => {
    let json = Dict.make()
    json->Dict.set("protocolVersion", JSON.Encode.int(1))

    let mcpCaps = Dict.make()
    mcpCaps->Dict.set("http", JSON.Encode.bool(false))
    mcpCaps->Dict.set("sse", JSON.Encode.bool(false))
    mcpCaps->Dict.set("websocket", JSON.Encode.bool(true))

    let agentCaps = Dict.make()
    agentCaps->Dict.set("loadSession", JSON.Encode.bool(false))
    agentCaps->Dict.set("mcpCapabilities", JSON.Encode.object(mcpCaps))
    json->Dict.set("agentCapabilities", JSON.Encode.object(agentCaps))

    let payload = JSON.Encode.object(json)
    let decoded = payload->S.parseOrThrow(~to=Types.initializeResultSchema)

    t
    ->expect(
      decoded.agentCapabilities
      ->Option.flatMap(c => c.mcpCapabilities)
      ->Option.flatMap(m => m.websocket),
    )
    ->Expect.toEqual(Some(true))
  })

  test("currentProtocolVersion is correct", t => {
    t->expect(Types.currentProtocolVersion)->Expect.toEqual(1)
  })

  test("shared content blocks round trip every variant and reject invalid payloads", t => {
    [
      `{"type":"text","text":"hello"}`,
      `{"type":"image","data":"aW1hZ2U=","mimeType":"image/png"}`,
      `{"type":"audio","data":"YXVkaW8=","mimeType":"audio/wav"}`,
      `{"type":"resource_link","name":"docs","uri":"https://example.com"}`,
      `{"type":"resource","_meta":{"current_page":true},"resource":{"uri":"page://localhost","mimeType":"text/plain","text":"Current page"}}`,
      `{"type":"resource","resource":{"uri":"annotation://a1/screenshot","mimeType":"image/png","blob":"ZGF0YQ=="}}`,
    ]->Array.forEach(
      source => {
        let json = JSON.parseOrThrow(source)
        let block = json->S.parseOrThrow(~to=ContentBlock.schema)
        t
        ->expect(
          block->S.decodeOrThrow(~from=ContentBlock.schema, ~to=S.json->S.noValidation(true)),
        )
        ->Expect.toEqual(json)
      },
    )
    [`{"type":"video","data":"base64"}`, `{"type":"image","mimeType":"image/png"}`]->Array.forEach(
      source =>
        t->expect(JSON.parseOrThrow(source)->parsesWith(ContentBlock.schema))->Expect.toBe(false),
    )
  })
})

module Fixtures = {
  let makeMessageChunk = (
    ~sessionUpdate: string,
    ~messageId: string,
    ~agentId: string,
    ~text: string,
    ~timestamp: string,
  ): JSON.t => {
    JSON.Encode.object(
      Dict.fromArray([
        ("sessionUpdate", JSON.Encode.string(sessionUpdate)),
        ("messageId", JSON.Encode.string(messageId)),
        (
          "content",
          JSON.Encode.object(
            Dict.fromArray([
              ("type", JSON.Encode.string("text")),
              ("text", JSON.Encode.string(text)),
            ]),
          ),
        ),
        ("_meta", messageMetadata(~agentId, ~timestamp)),
      ]),
    )
  }

  let makeStateUpdate = (~state: string, ~stopReason: option<string>=?): JSON.t => {
    let fields = Dict.fromArray([
      ("sessionUpdate", JSON.Encode.string("state_update")),
      ("state", JSON.Encode.string(state)),
    ])

    switch stopReason {
    | Some(reason) => fields->Dict.set("stopReason", JSON.Encode.string(reason))
    | None => ()
    }

    JSON.Encode.object(fields)
  }
}

describe("sessionUpdate schema parsing", () => {
  test("agent_message_chunk with identity metadata", t => {
    let json = Fixtures.makeMessageChunk(
      ~sessionUpdate="agent_message_chunk",
      ~messageId="turn-123:0",
      ~agentId="executor-id",
      ~text="Hello from the agent",
      ~timestamp="2024-01-15T10:00:30Z",
    )
    let parsed = json->S.parseOrThrow(~to=Types.sessionUpdateSchema)

    switch parsed {
    | Types.AgentMessageChunk({
        messageId,
        content: ContentBlock.TextContent({text}),
        _meta: {agentId, timestamp},
      }) =>
      t->expect(messageId)->Expect.toBe("turn-123:0")
      t->expect(text)->Expect.toBe("Hello from the agent")
      t->expect(agentId)->Expect.toBe("executor-id")
      t->expect(timestamp)->Expect.toBe("2024-01-15T10:00:30Z")
    | _ => t->expect("AgentMessageChunk")->Expect.toBe("not matched")
    }
  })

  test("user_message_chunk with canonical identity metadata", t => {
    let json = Fixtures.makeMessageChunk(
      ~sessionUpdate="user_message_chunk",
      ~messageId="msg-123",
      ~agentId="executor-id",
      ~text="Accepted user message",
      ~timestamp="2024-01-15T10:00:00Z",
    )
    let parsed = json->S.parseOrThrow(~to=Types.sessionUpdateSchema)

    switch parsed {
    | Types.UserMessageChunk({
        messageId,
        content: ContentBlock.TextContent({text}),
        _meta: {agentId, timestamp},
      }) =>
      t->expect(messageId)->Expect.toBe("msg-123")
      t->expect(text)->Expect.toBe("Accepted user message")
      t->expect(agentId)->Expect.toBe("executor-id")
      t->expect(timestamp)->Expect.toBe("2024-01-15T10:00:00Z")
    | _ => t->expect("UserMessageChunk")->Expect.toBe("not matched")
    }
  })

  test("state_update variants", t => {
    [
      (
        Fixtures.makeStateUpdate(~state="running"),
        Types.StateUpdate({state: Types.Running, stopReason: None}),
      ),
      (
        Fixtures.makeStateUpdate(~state="idle", ~stopReason="end_turn"),
        Types.StateUpdate({state: Types.Idle, stopReason: Some(Types.EndTurn)}),
      ),
      (
        Fixtures.makeStateUpdate(~state="requires_action"),
        Types.StateUpdate({state: Types.RequiresAction, stopReason: None}),
      ),
    ]->Array.forEach(
      ((json, expected)) =>
        t->expect(json->S.parseOrThrow(~to=Types.sessionUpdateSchema))->Expect.toEqual(expected),
    )
  })

  test("malformed known agent_message_chunk is rejected", t => {
    let json = JSON.Encode.object(
      Dict.fromArray([
        ("sessionUpdate", JSON.Encode.string("agent_message_chunk")),
        (
          "content",
          JSON.Encode.object(
            Dict.fromArray([
              ("type", JSON.Encode.string("text")),
              ("text", JSON.Encode.string("hello")),
            ]),
          ),
        ),
      ]),
    )

    t->expect(json->parsesWith(Types.sessionUpdateSchema))->Expect.toBe(false)
  })

  test("generic chunk accepts Frontman metadata that negotiated v1 rejects", t => {
    let json = JSON.parseOrThrow(`{
      "sessionUpdate":"agent_message_chunk",
      "messageId":"message-1",
      "content":{"type":"text","text":"hello"},
      "_meta":{"frontman.dev/agentId":42,"frontman.dev/timestamp":"invalid"}
    }`)

    t->expect(json->parsesWith(Types.sessionUpdateSchema))->Expect.toBe(false)
    t->expect(json->parsesWith(Types.genericSessionUpdateSchema))->Expect.toBe(true)
  })

  test("generic known chunk still requires standard ACP content", t => {
    let json = JSON.parseOrThrow(`{
      "sessionUpdate":"agent_message_chunk",
      "messageId":"message-1",
      "_meta":{"frontman.dev/agentId":42}
    }`)

    t->expect(json->parsesWith(Types.genericSessionUpdateSchema))->Expect.toBe(false)
  })

  test("unknown session update is rejected", t => {
    let json = JSON.Encode.object(
      Dict.fromArray([("sessionUpdate", JSON.Encode.string("future_update"))]),
    )

    t->expect(json->parsesWith(Types.sessionUpdateSchema))->Expect.toBe(false)

    switch json->S.parseOrThrow(~to=Types.unknownSessionUpdateSchema) {
    | Types.Unknown({sessionUpdate: "future_update"}) => ()
    | _ => t->expect("Unknown future_update")->Expect.toBe("not matched")
    }
  })

  test("notification requires literal JSON-RPC version and method", t => {
    [
      `{"jsonrpc":"1.0","method":"session/update","params":{"sessionId":"task-1","update":{"sessionUpdate":"state_update","state":"running"}}}`,
      `{"jsonrpc":"2.0","method":"session/prompt","params":{"sessionId":"task-1","update":{"sessionUpdate":"state_update","state":"running"}}}`,
    ]->Array.forEach(
      json =>
        t
        ->expect(JSON.parseOrThrow(json)->parsesWith(Types.sessionUpdateNotificationSchema))
        ->Expect.toBe(false),
    )
  })
})
