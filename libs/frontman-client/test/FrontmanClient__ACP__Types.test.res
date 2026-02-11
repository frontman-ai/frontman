open Vitest

module Types = FrontmanFrontmanProtocol.FrontmanProtocol__ACP

describe("ACP Types encoding/decoding", _t => {
  test("initializeParams should encode without throwing", _t => {
    let params: Types.initializeParams = {
      protocolVersion: Types.currentProtocolVersion,
      clientCapabilities: Some({
        fs: Some({readTextFile: Some(true), writeTextFile: Some(true)}),
        terminal: Some(false),
      }),
      clientInfo: Some({name: "test-client", version: "1.0.0", title: None, metadata: None}),
    }

    let _encoded = params->S.reverseConvertToJsonOrThrow(Types.initializeParamsSchema)
  })

  test("initializeParams should encode correct JSON structure", t => {
    let params: Types.initializeParams = {
      protocolVersion: 1,
      clientCapabilities: None,
      clientInfo: Some({name: "test", version: "1.0", title: Some("Test Client"), metadata: None}),
    }

    let json = params->S.reverseConvertToJsonOrThrow(Types.initializeParamsSchema)
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
    let decoded = payload->S.parseOrThrow(Types.initializeResultSchema)

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
    let decoded = payload->S.parseOrThrow(Types.initializeResultSchema)

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
})
