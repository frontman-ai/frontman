open Vitest

module Types = FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP

describe("ACP Types encoding/decoding", _t => {
  test("initializeParams should encode without throwing", _t => {
    let params: Types.initializeParams = {
      protocolVersion: Types.currentProtocolVersion,
      clientCapabilities: Some({
        fs: Some({readTextFile: Some(true), writeTextFile: Some(true)}),
        terminal: Some(false),
        elicitation: None,
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
  let makeAgentMessageChunk = (~text: string, ~timestamp: string): JSON.t => {
    JSON.Encode.object(
      Dict.fromArray([
        ("sessionUpdate", JSON.Encode.string("agent_message_chunk")),
        (
          "content",
          JSON.Encode.object(
            Dict.fromArray([
              ("type", JSON.Encode.string("text")),
              ("text", JSON.Encode.string(text)),
            ]),
          ),
        ),
        ("timestamp", JSON.Encode.string(timestamp)),
      ]),
    )
  }

  let makeUserMessage = (~messageId: string, ~text: string): JSON.t => {
    JSON.Encode.object(
      Dict.fromArray([
        ("sessionUpdate", JSON.Encode.string("user_message")),
        ("messageId", JSON.Encode.string(messageId)),
        (
          "content",
          JSON.Encode.array([
            JSON.Encode.object(
              Dict.fromArray([
                ("type", JSON.Encode.string("text")),
                ("text", JSON.Encode.string(text)),
              ]),
            ),
          ]),
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
  test("agent_message_chunk with text content and timestamp", t => {
    let json = Fixtures.makeAgentMessageChunk(
      ~text="Hello from the agent",
      ~timestamp="2024-01-15T10:00:30Z",
    )
    let parsed = json->S.parseOrThrow(~to=Types.sessionUpdateSchema)

    switch parsed {
    | Types.AgentMessageChunk({content: Types.TextContent({text}), timestamp}) =>
      t->expect(text)->Expect.toBe("Hello from the agent")
      t->expect(timestamp)->Expect.toBe("2024-01-15T10:00:30Z")
    | _ => t->expect("AgentMessageChunk")->Expect.toBe("not matched")
    }
  })

  test("user_message with canonical message id and content", t => {
    let json = Fixtures.makeUserMessage(~messageId="msg-123", ~text="Accepted user message")
    let parsed = json->S.parseOrThrow(~to=Types.sessionUpdateSchema)

    switch parsed {
    | Types.UserMessage({messageId, content: [Types.TextContent({text})]}) =>
      t->expect(messageId)->Expect.toBe("msg-123")
      t->expect(text)->Expect.toBe("Accepted user message")
    | _ => t->expect("UserMessage")->Expect.toBe("not matched")
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

  test("agent_message_chunk without timestamp falls through to Unknown", t => {
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

    let result = try {
      Ok(json->S.parseOrThrow(~to=Types.sessionUpdateSchema))
    } catch {
    | _ => Error("parse threw")
    }

    switch result {
    | Ok(Types.AgentMessageChunk(_)) =>
      t->expect("AgentMessageChunk without timestamp")->Expect.toBe("should not parse")
    | Ok(Types.Unknown({sessionUpdate})) =>
      // Falls to Unknown — message silently dropped by handleSessionUpdate
      t->expect(sessionUpdate)->Expect.toBe("agent_message_chunk")
    | Ok(_) => t->expect("unexpected variant")->Expect.toBe("should not happen")
    | Error(_) => // Sury fully rejected — also acceptable
      ()
    }
  })
})
