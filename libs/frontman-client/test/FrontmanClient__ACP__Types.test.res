open Vitest

module Types = FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP

let parsesWith = (json, schema) => {
  try {
    json->S.parseOrThrow(~to=schema)->ignore
    true
  } catch {
  | _ => false
  }
}

let schemaToJson = (value, schema) =>
  value->S.decodeOrThrow(~from=schema, ~to=S.json->S.noValidation(true))

describe("Frontman agent attribution metadata", () => {
  test("capability metadata preserves the Frontman key location", t => {
    let json = JSON.Encode.object(
      Dict.fromArray([
        ("unrelated.dev/value", JSON.Encode.bool(true)),
        (
          "frontman.dev",
          JSON.Encode.object(
            Dict.fromArray([
              (
                "agentAttribution",
                JSON.Encode.object(Dict.fromArray([("version", JSON.Encode.int(1))])),
              ),
            ]),
          ),
        ),
      ]),
    )

    let parsed = json->S.parseOrThrow(~to=Types.capabilityMetadataSchema)
    let serialized = parsed->schemaToJson(Types.capabilityMetadataSchema)
    let serializedObject = serialized->JSON.Decode.object->Option.getOrThrow

    t
    ->expect(
      parsed.frontmanDev
      ->Option.flatMap(value => value.agentAttribution)
      ->Option.map(a => a.version),
    )
    ->Expect.toEqual(Some(1))
    t->expect(serializedObject->Dict.has("frontman.dev"))->Expect.toBe(true)
    t->expect(serializedObject->Dict.has("agentAttribution"))->Expect.toBe(false)
  })

  test("capability metadata accepts unrelated keys", t => {
    let json = JSON.Encode.object(
      Dict.fromArray([("unrelated.dev/value", JSON.Encode.string("accepted"))]),
    )

    t->expect(json->parsesWith(Types.capabilityMetadataSchema))->Expect.toBe(true)
  })

  test("capability metadata rejects malformed advertisements", t => {
    let wrongShape = JSON.Encode.object(
      Dict.fromArray([("frontman.dev", JSON.Encode.string("invalid"))]),
    )
    let wrongAttributionShape = JSON.Encode.object(
      Dict.fromArray([
        (
          "frontman.dev",
          JSON.Encode.object(Dict.fromArray([("agentAttribution", JSON.Encode.string("invalid"))])),
        ),
      ]),
    )
    let invalidVersion = JSON.Encode.object(
      Dict.fromArray([
        (
          "frontman.dev",
          JSON.Encode.object(
            Dict.fromArray([
              (
                "agentAttribution",
                JSON.Encode.object(Dict.fromArray([("version", JSON.Encode.int(0))])),
              ),
            ]),
          ),
        ),
      ]),
    )
    let oversizedVersion = JSON.Encode.object(
      Dict.fromArray([
        (
          "frontman.dev",
          JSON.Encode.object(
            Dict.fromArray([
              (
                "agentAttribution",
                JSON.Encode.object(Dict.fromArray([("version", JSON.Encode.int(65536))])),
              ),
            ]),
          ),
        ),
      ]),
    )

    t->expect(wrongShape->parsesWith(Types.capabilityMetadataSchema))->Expect.toBe(false)
    t->expect(wrongAttributionShape->parsesWith(Types.capabilityMetadataSchema))->Expect.toBe(false)
    t->expect(invalidVersion->parsesWith(Types.capabilityMetadataSchema))->Expect.toBe(false)
    t->expect(oversizedVersion->parsesWith(Types.capabilityMetadataSchema))->Expect.toBe(false)
  })

  test("session metadata parses and serializes a catalog without relocating its key", t => {
    let json = JSON.Encode.object(
      Dict.fromArray([
        ("unrelated.dev/value", JSON.Encode.bool(true)),
        (
          "frontman.dev/agents",
          JSON.Encode.array([
            JSON.Encode.object(
              Dict.fromArray([
                ("id", JSON.Encode.string("executor")),
                ("name", JSON.Encode.string("executor")),
                ("displayName", JSON.Encode.string("Executor")),
                ("description", JSON.Encode.string("Implements approved work")),
                ("color", JSON.Encode.string("#16A085")),
              ]),
            ),
          ]),
        ),
      ]),
    )

    let parsed = json->S.parseOrThrow(~to=Types.sessionMetadataSchema)
    let serialized = parsed->schemaToJson(Types.sessionMetadataSchema)
    let serializedObject = serialized->JSON.Decode.object->Option.getOrThrow

    t
    ->expect(
      parsed.agents->Option.flatMap(agents => agents->Array.get(0))->Option.map(a => a.displayName),
    )
    ->Expect.toEqual(Some("Executor"))
    t->expect(serializedObject->Dict.has("frontman.dev/agents"))->Expect.toBe(true)
    t->expect(serializedObject->Dict.has("agents"))->Expect.toBe(false)
  })

  test("session metadata rejects empty identities, duplicate ids, and malformed colors", t => {
    let makeAgent = (~id="executor", ~name="executor", ~displayName="Executor", ~color="#16A085") =>
      JSON.Encode.object(
        Dict.fromArray([
          ("id", JSON.Encode.string(id)),
          ("name", JSON.Encode.string(name)),
          ("displayName", JSON.Encode.string(displayName)),
          ("description", JSON.Encode.string("Implements approved work")),
          ("color", JSON.Encode.string(color)),
        ]),
      )
    let metadata = agents =>
      JSON.Encode.object(Dict.fromArray([("frontman.dev/agents", JSON.Encode.array(agents))]))

    t
    ->expect(metadata([makeAgent(~id="")])->parsesWith(Types.sessionMetadataSchema))
    ->Expect.toBe(false)
    t
    ->expect(metadata([makeAgent(~name="")])->parsesWith(Types.sessionMetadataSchema))
    ->Expect.toBe(false)
    t
    ->expect(metadata([makeAgent(~displayName="")])->parsesWith(Types.sessionMetadataSchema))
    ->Expect.toBe(false)
    t
    ->expect(metadata([makeAgent(~color="blue")])->parsesWith(Types.sessionMetadataSchema))
    ->Expect.toBe(false)
    t
    ->expect(
      metadata([makeAgent(), makeAgent(~name="other")])->parsesWith(Types.sessionMetadataSchema),
    )
    ->Expect.toBe(false)
    t
    ->expect(metadata([makeAgent(~id="constructor")])->parsesWith(Types.sessionMetadataSchema))
    ->Expect.toBe(true)
  })

  test("message metadata validates identity and RFC 3339 timestamp", t => {
    let valid = JSON.Encode.object(
      Dict.fromArray([
        ("frontman.dev/agentId", JSON.Encode.string("executor")),
        ("frontman.dev/timestamp", JSON.Encode.string("2026-07-14T12:30:01.123456Z")),
        ("unrelated.dev/value", JSON.Encode.bool(true)),
      ]),
    )
    let offset = JSON.Encode.object(
      Dict.fromArray([
        ("frontman.dev/agentId", JSON.Encode.string("executor")),
        ("frontman.dev/timestamp", JSON.Encode.string("2026-07-14T14:30:01+02:00")),
      ]),
    )
    let emptyId = JSON.Encode.object(
      Dict.fromArray([
        ("frontman.dev/agentId", JSON.Encode.string("")),
        ("frontman.dev/timestamp", JSON.Encode.string("2026-07-14T12:30:01Z")),
      ]),
    )
    let invalidTimestamp = JSON.Encode.object(
      Dict.fromArray([
        ("frontman.dev/agentId", JSON.Encode.string("executor")),
        ("frontman.dev/timestamp", JSON.Encode.string("July 14, 2026")),
      ]),
    )
    let invalidCalendarDate = JSON.Encode.object(
      Dict.fromArray([
        ("frontman.dev/agentId", JSON.Encode.string("executor")),
        ("frontman.dev/timestamp", JSON.Encode.string("2026-02-30T12:30:01Z")),
      ]),
    )

    t->expect(valid->parsesWith(Types.messageMetadataSchema))->Expect.toBe(true)
    t->expect(offset->parsesWith(Types.messageMetadataSchema))->Expect.toBe(true)
    t->expect(emptyId->parsesWith(Types.messageMetadataSchema))->Expect.toBe(false)
    t->expect(invalidTimestamp->parsesWith(Types.messageMetadataSchema))->Expect.toBe(false)
    t->expect(invalidCalendarDate->parsesWith(Types.messageMetadataSchema))->Expect.toBe(false)
  })
})

describe("ACP Types encoding/decoding", _t => {
  test("initializeParams should encode without throwing", _t => {
    let params: Types.initializeParams = {
      protocolVersion: Types.currentProtocolVersion,
      clientCapabilities: Some({
        fs: Some({readTextFile: Some(true), writeTextFile: Some(true)}),
        terminal: Some(false),
        elicitation: None,
        _meta: None,
      }),
      clientInfo: Some({name: "test-client", version: "1.0.0", title: None, _meta: None}),
    }

    params->Types.initializeParamsToJson->ignore
  })

  test("initializeParams should encode correct JSON structure", t => {
    let params: Types.initializeParams = {
      protocolVersion: 1,
      clientCapabilities: None,
      clientInfo: Some({name: "test", version: "1.0", title: Some("Test Client"), _meta: None}),
    }

    let json = params->Types.initializeParamsToJson
    let obj = json->JSON.Decode.object->Option.getOrThrow

    t->expect(obj->Dict.get("protocolVersion"))->Expect.toEqual(Some(JSON.Encode.int(1)))
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

  test("contentBlock encodes embedded text resource", t => {
    let block: Types.contentBlock = Types.EmbeddedResource({
      resource: {
        _meta: Some(JSON.Encode.object(Dict.fromArray([("current_page", JSON.Encode.bool(true))]))),
        annotations: None,
        resource: Types.TextResourceContents({
          uri: "page://http://localhost:4321/",
          mimeType: Some("text/plain"),
          text: "Current page",
        }),
      },
      _meta: None,
      annotations: None,
    })

    let json =
      block->S.decodeOrThrow(~from=Types.contentBlockSchema, ~to=S.json->S.noValidation(true))
    let obj = json->JSON.Decode.object->Option.getOrThrow
    let resource = obj->Dict.get("resource")->Option.flatMap(JSON.Decode.object)->Option.getOrThrow
    let contents =
      resource->Dict.get("resource")->Option.flatMap(JSON.Decode.object)->Option.getOrThrow

    t
    ->expect(obj->Dict.get("type")->Option.flatMap(JSON.Decode.string))
    ->Expect.toEqual(Some("resource"))
    t
    ->expect(contents->Dict.get("uri")->Option.flatMap(JSON.Decode.string))
    ->Expect.toEqual(Some("page://http://localhost:4321/"))
    t
    ->expect(contents->Dict.get("text")->Option.flatMap(JSON.Decode.string))
    ->Expect.toEqual(Some("Current page"))
    t->expect(contents->Dict.get("blob")->Option.isNone)->Expect.toEqual(true)
  })

  test("contentBlock decodes embedded text resource", t => {
    let json = JSON.Encode.object(
      Dict.fromArray([
        ("type", JSON.Encode.string("resource")),
        (
          "resource",
          JSON.Encode.object(
            Dict.fromArray([
              (
                "resource",
                JSON.Encode.object(
                  Dict.fromArray([
                    ("uri", JSON.Encode.string("page://http://localhost:4321/")),
                    ("mimeType", JSON.Encode.string("text/plain")),
                    ("text", JSON.Encode.string("Current page")),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ]),
    )

    switch json->S.parseOrThrow(~to=Types.contentBlockSchema) {
    | Types.EmbeddedResource({resource: {resource: Types.TextResourceContents({uri, text})}}) =>
      t->expect(uri)->Expect.toEqual("page://http://localhost:4321/")
      t->expect(text)->Expect.toEqual("Current page")
    | _ => t->expect("EmbeddedResource")->Expect.toEqual("not matched")
    }
  })

  test("contentBlock encodes embedded blob resource", t => {
    let block: Types.contentBlock = Types.EmbeddedResource({
      resource: {
        _meta: None,
        annotations: None,
        resource: Types.BlobResourceContents({
          uri: "annotation://a1/screenshot",
          mimeType: Some("image/png"),
          blob: "base64-data",
        }),
      },
      _meta: None,
      annotations: None,
    })

    let json =
      block->S.decodeOrThrow(~from=Types.contentBlockSchema, ~to=S.json->S.noValidation(true))
    let obj = json->JSON.Decode.object->Option.getOrThrow
    let resource = obj->Dict.get("resource")->Option.flatMap(JSON.Decode.object)->Option.getOrThrow
    let contents =
      resource->Dict.get("resource")->Option.flatMap(JSON.Decode.object)->Option.getOrThrow

    t
    ->expect(contents->Dict.get("uri")->Option.flatMap(JSON.Decode.string))
    ->Expect.toEqual(Some("annotation://a1/screenshot"))
    t
    ->expect(contents->Dict.get("blob")->Option.flatMap(JSON.Decode.string))
    ->Expect.toEqual(Some("base64-data"))
    t->expect(contents->Dict.get("text")->Option.isNone)->Expect.toEqual(true)
  })

  test("contentBlock decodes embedded blob resource", t => {
    let json = JSON.Encode.object(
      Dict.fromArray([
        ("type", JSON.Encode.string("resource")),
        (
          "resource",
          JSON.Encode.object(
            Dict.fromArray([
              (
                "resource",
                JSON.Encode.object(
                  Dict.fromArray([
                    ("uri", JSON.Encode.string("annotation://a1/screenshot")),
                    ("mimeType", JSON.Encode.string("image/png")),
                    ("blob", JSON.Encode.string("base64-data")),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ]),
    )

    switch json->S.parseOrThrow(~to=Types.contentBlockSchema) {
    | Types.EmbeddedResource({resource: {resource: Types.BlobResourceContents({uri, blob})}}) =>
      t->expect(uri)->Expect.toEqual("annotation://a1/screenshot")
      t->expect(blob)->Expect.toEqual("base64-data")
    | _ => t->expect("EmbeddedResource blob")->Expect.toEqual("not matched")
    }
  })
})

// ============================================================================
// Session Update Parsing Tests
// ============================================================================

module Fixtures = {
  let messageMetadata = (~agentId: string, ~timestamp: string): JSON.t =>
    JSON.Encode.object(
      Dict.fromArray([
        ("frontman.dev/agentId", JSON.Encode.string(agentId)),
        ("frontman.dev/timestamp", JSON.Encode.string(timestamp)),
      ]),
    )

  let makeAgentMessageChunk = (
    ~messageId: string,
    ~agentId: string,
    ~text: string,
    ~timestamp: string,
  ): JSON.t => {
    JSON.Encode.object(
      Dict.fromArray([
        ("sessionUpdate", JSON.Encode.string("agent_message_chunk")),
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

  let makeUserMessageChunk = (
    ~messageId: string,
    ~agentId: string,
    ~text: string,
    ~timestamp: string,
  ): JSON.t => {
    JSON.Encode.object(
      Dict.fromArray([
        ("sessionUpdate", JSON.Encode.string("user_message_chunk")),
        ("messageId", JSON.Encode.string(messageId)),
        ("_meta", messageMetadata(~agentId, ~timestamp)),
        (
          "content",
          JSON.Encode.object(
            Dict.fromArray([
              ("type", JSON.Encode.string("text")),
              ("text", JSON.Encode.string(text)),
            ]),
          ),
        ),
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
    let json = Fixtures.makeAgentMessageChunk(
      ~messageId="turn-123:0",
      ~agentId="executor-id",
      ~text="Hello from the agent",
      ~timestamp="2024-01-15T10:00:30Z",
    )
    let parsed = json->S.parseOrThrow(~to=Types.sessionUpdateSchema)

    switch parsed {
    | Types.AgentMessageChunk({
        messageId,
        content: Types.TextContent({text}),
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
    let json = Fixtures.makeUserMessageChunk(
      ~messageId="msg-123",
      ~agentId="executor-id",
      ~text="Accepted user message",
      ~timestamp="2024-01-15T10:00:00Z",
    )
    let parsed = json->S.parseOrThrow(~to=Types.sessionUpdateSchema)

    switch parsed {
    | Types.UserMessageChunk({
        messageId,
        content: Types.TextContent({text}),
        _meta: {agentId, timestamp},
      }) =>
      t->expect(messageId)->Expect.toBe("msg-123")
      t->expect(text)->Expect.toBe("Accepted user message")
      t->expect(agentId)->Expect.toBe("executor-id")
      t->expect(timestamp)->Expect.toBe("2024-01-15T10:00:00Z")
    | _ => t->expect("UserMessageChunk")->Expect.toBe("not matched")
    }
  })

  test("state_update running", t => {
    let json = Fixtures.makeStateUpdate(~state="running")
    let parsed = json->S.parseOrThrow(~to=Types.sessionUpdateSchema)

    switch parsed {
    | Types.StateUpdate({state: Types.Running, stopReason: None}) =>
      t->expect("running")->Expect.toBe("running")
    | _ => t->expect("StateUpdate running")->Expect.toBe("not matched")
    }
  })

  test("state_update idle with stop reason", t => {
    let json = Fixtures.makeStateUpdate(~state="idle", ~stopReason="end_turn")
    let parsed = json->S.parseOrThrow(~to=Types.sessionUpdateSchema)

    switch parsed {
    | Types.StateUpdate({state: Types.Idle, stopReason: Some(Types.EndTurn)}) =>
      t->expect("idle")->Expect.toBe("idle")
    | _ => t->expect("StateUpdate idle")->Expect.toBe("not matched")
    }
  })

  test("state_update requires_action", t => {
    let json = Fixtures.makeStateUpdate(~state="requires_action")
    let parsed = json->S.parseOrThrow(~to=Types.sessionUpdateSchema)

    switch parsed {
    | Types.StateUpdate({state: Types.RequiresAction, stopReason: None}) =>
      t->expect("requires_action")->Expect.toBe("requires_action")
    | _ => t->expect("StateUpdate requires_action")->Expect.toBe("not matched")
    }
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

    let rejected = try {
      json->S.parseOrThrow(~to=Types.sessionUpdateSchema)->ignore
      false
    } catch {
    | _ => true
    }

    t->expect(rejected)->Expect.toBe(true)
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

    let rejected = try {
      json->S.parseOrThrow(~to=Types.sessionUpdateSchema)->ignore
      false
    } catch {
    | _ => true
    }

    t->expect(rejected)->Expect.toBe(true)

    switch json->S.parseOrThrow(~to=Types.unknownSessionUpdateSchema) {
    | Types.Unknown({sessionUpdate: "future_update"}) => ()
    | _ => t->expect("Unknown future_update")->Expect.toBe("not matched")
    }
  })
})
