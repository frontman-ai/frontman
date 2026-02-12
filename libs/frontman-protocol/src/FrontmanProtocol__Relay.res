// Relay Protocol Types for framework tool relay communication

module MCP = FrontmanProtocol__MCP

// Relay protocol version for runtime version negotiation
let protocolVersion = "1.0"

// Tool definition from dev server (JSON format, matches MCP)
@schema
type remoteTool = {
  name: string,
  description: string,
  inputSchema: JSON.t,
  visibleToAgent: bool,
}

// Tools list response from dev server
@schema
type toolsResponse = {
  tools: array<remoteTool>,
  serverInfo: MCP.info,
  protocolVersion: string,
}

// Tool call request to dev server
@schema
type toolCallRequest = {
  name: string,
  arguments: option<Dict.t<JSON.t>>,
}

// Result/Error events reuse MCP types
type resultEvent = MCP.callToolResult
type errorEvent = MCP.callToolResult
