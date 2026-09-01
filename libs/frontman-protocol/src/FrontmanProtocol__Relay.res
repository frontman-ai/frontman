module MCP = FrontmanProtocol__MCP

let protocolVersion = "2.0"

type remoteTool = JSON.t

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
  s.field("icons", S.option(S.array(FrontmanProtocol__ContentBlock.iconSchema)))->ignore
  s.field("inputSchema", MCP.ToolSchema.inputSchema)->ignore
  s.field("outputSchema", S.option(MCP.ToolSchema.outputSchema))->ignore
  s.field("annotations", S.option(MCP.ToolAnnotations.schema))->ignore
  s.field("_meta", remoteToolMetaSchema)->ignore
  s.flatten(S.dict(S.json))->JSON.Encode.object
})

let remoteToolSchema = MCP.preserveJsonWithSchema(remoteToolShapeSchema)

type toolsResponse = {
  tools: array<remoteTool>,
  serverInfo: MCP.Implementation.t,
  protocolVersion: string,
}

let toolsResponseSchema = S.object(s => {
  tools: s.field("tools", S.array(remoteToolSchema)),
  serverInfo: s.field("serverInfo", MCP.Implementation.schema),
  protocolVersion: s.field("protocolVersion", S.literal(protocolVersion)),
})

@schema
type toolCallRequest = {
  name: string,
  arguments: option<Dict.t<JSON.t>>,
}

type resultEvent = MCP.CallToolResult.t
