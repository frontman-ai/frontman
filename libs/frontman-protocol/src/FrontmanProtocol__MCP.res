// MCP Protocol Types

S.enableJson()

// Protocol version constant
let protocolVersion = "DRAFT-2025-v3"

// Capabilities
@schema
type capabilities = {
  tools: option<Dict.t<JSON.t>>,
  resources: option<Dict.t<JSON.t>>,
  prompts: option<Dict.t<JSON.t>>,
}

// Client/Server info
@schema
type info = {
  name: string,
  version: string,
}

// Initialize params (sent by client/agent)
@schema
type initializeParams = {
  protocolVersion: string,
  capabilities: capabilities,
  clientInfo: info,
}

// Initialize result (sent by server/browser)
@schema
type initializeResult = {
  protocolVersion: string,
  capabilities: capabilities,
  serverInfo: info,
}

// Tool call params
@schema
type toolCallParams = {
  callId: string,
  name: string,
  arguments: option<Dict.t<JSON.t>>,
}

// Tool result content
@schema
type toolResultContent = {
  @as("type") type_: string,
  text: string,
}

// Tool error
@schema
type toolError = {
  code: int,
  message: string,
}

// Tool call result (MCP CallToolResult spec)
@schema
type callToolResult = {
  content: array<toolResultContent>,
  isError: option<bool>,
}

// Tools list result
@schema
type toolsListResult = {tools: array<JSON.t>}

// MCP Error codes
module ErrorCode = {
  let invalidParams = -32602
  let serverError = -32000
  let methodNotFound = -32601
}

// Server interface - runtime-compatible record for generic MCP handlers
type serverInterface<'server> = {
  server: 'server,
  buildInitializeResult: 'server => initializeResult,
  buildToolsListResult: 'server => toolsListResult,
  executeTool: (
    'server,
    ~name: string,
    ~arguments: option<Dict.t<JSON.t>>,
    ~taskId: string,
    ~onProgress: option<string => unit>,
  ) => promise<callToolResult>,
}

// Server module type - implement this to create an MCP server
module type Server = {
  type t
  let buildInitializeResult: t => initializeResult
  let buildToolsListResult: t => toolsListResult
  let executeTool: (
    t,
    ~name: string,
    ~arguments: option<Dict.t<JSON.t>>=?,
    ~taskId: string,
    ~onProgress: option<string => unit>=?,
  ) => promise<callToolResult>
}
