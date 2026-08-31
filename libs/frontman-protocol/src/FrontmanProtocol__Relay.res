module MCP = FrontmanProtocol__MCP

let protocolVersion = "1.0"

type remoteTool = JSON.t

let remoteToolSchema = MCP.toolJsonSchema

type toolsResponse = {
  tools: array<remoteTool>,
  serverInfo: MCP.info,
  protocolVersion: string,
}

let toolsResponseSchema = S.object(s => {
  tools: s.field("tools", S.array(MCP.toolJsonSchema)),
  serverInfo: s.field("serverInfo", MCP.infoSchema),
  protocolVersion: s.field("protocolVersion", S.literal("1.0")),
})

@schema
type toolCallRequest = {
  name: string,
  arguments: option<Dict.t<JSON.t>>,
}

type resultEvent = MCP.CallToolResult.t
