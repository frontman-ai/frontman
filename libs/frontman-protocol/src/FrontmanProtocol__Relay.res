module MCP = FrontmanProtocol__MCP

let protocolVersion = "2.0"
let legacyProtocolVersion = "1.0"

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

@schema
type remoteTool = {
  name: @s.matches(S.string->S.min(1)) string,
  title?: string,
  description?: string,
  icons?: array<@s.matches(MCP.preservingJson(MCP.iconSchema)) JSON.t>,
  inputSchema: @s.matches(MCP.preservingJson(MCP.toolInputSchema)) JSON.t,
  outputSchema?: @s.matches(MCP.preservingJson(S.dict(S.json))) JSON.t,
  annotations?: @s.matches(MCP.preservingJson(MCP.toolAnnotationsSchema)) JSON.t,
  _meta: @s.matches(MCP.preservingJson(remoteToolMetaSchema)) JSON.t,
}

@schema
type toolsResponse = {
  tools: array<remoteTool>,
  serverInfo: MCP.info,
  protocolVersion: @s.matches(S.literal(protocolVersion)) string,
}

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
