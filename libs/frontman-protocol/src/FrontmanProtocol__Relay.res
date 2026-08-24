module MCP = FrontmanProtocol__MCP

let protocolVersion = "1.0"

@schema
type remoteTool = {
  name: string,
  description: string,
  access: option<FrontmanProtocol__Tool.access>,
  inputSchema: JSON.t,
  outputSchema: option<JSON.t>,
  visibleToAgent: bool,
}

@schema
type toolsResponse = {
  tools: array<remoteTool>,
  serverInfo: MCP.info,
  protocolVersion: string,
}

@schema
type toolCallRequest = {
  name: string,
  arguments: option<Dict.t<JSON.t>>,
}

type resultEvent = MCP.CallToolResult.t
type errorEvent = MCP.CallToolResult.t
