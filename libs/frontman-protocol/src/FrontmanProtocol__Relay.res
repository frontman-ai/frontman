module MCP = FrontmanProtocol__MCP

let protocolVersion = "2.0"
let legacyProtocolVersion = "1.0"

type remoteTool = JSON.t

@schema
type legacyRemoteTool = {
  name: string,
  description: string,
  access: option<FrontmanProtocol__Tool.access>,
  inputSchema: JSON.t,
  outputSchema: option<JSON.t>,
  visibleToAgent: bool,
}

let relayToolMetadataSchema = S.object(s => {
  s.field("visibleToAgent", S.bool)->ignore
  s.field(
    "access",
    S.union([S.literal("read"), S.literal("write"), S.literal("read-write")]),
  )->ignore
  s.field(
    "executionMode",
    S.option(S.union([S.literal("Synchronous"), S.literal("Interactive")])),
  )->ignore
  s.flatten(S.dict(S.json))->JSON.Encode.object
})

let remoteToolMetaSchema = S.object(s => {
  s.field("ai.frontman/tool-metadata", relayToolMetadataSchema)->ignore
  s.flatten(S.dict(S.json))->JSON.Encode.object
})

let remoteToolShapeSchema = S.object(s => {
  s.field("name", S.string->S.min(1))->ignore
  s.field("title", S.option(S.string))->ignore
  s.field("description", S.option(S.string))->ignore
  s.field("icons", S.option(S.array(MCP.iconSchema)))->ignore
  s.field("inputSchema", MCP.toolInputSchema)->ignore
  s.field("outputSchema", S.option(S.dict(S.json)))->ignore
  s.field("annotations", S.option(MCP.toolAnnotationsSchema))->ignore
  s.field("_meta", remoteToolMetaSchema)->ignore
  s.flatten(S.dict(S.json))->JSON.Encode.object
})

let remoteToolSchema = MCP.preservingJson(remoteToolShapeSchema)

type toolsResponse = {
  tools: array<remoteTool>,
  serverInfo: MCP.info,
  protocolVersion: string,
}

let toolsResponseSchema = S.object(s => {
  tools: s.field("tools", S.array(remoteToolSchema)),
  serverInfo: s.field("serverInfo", MCP.infoSchema),
  protocolVersion: s.field("protocolVersion", S.literal(protocolVersion)),
})

@schema
type legacyToolsResponse = {
  tools: array<legacyRemoteTool>,
  serverInfo: MCP.info,
  protocolVersion: @s.matches(S.literal(legacyProtocolVersion)) string,
}

@schema
type toolCallRequest = {
  name: string,
  arguments: option<Dict.t<JSON.t>>,
}

type resultEvent = MCP.CallToolResult.t
