// MCP Protocol Types

// Protocol version constant
let protocolVersion = "2025-11-25"

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
type textContent = {text: string}
type imageContent = {data: string, mimeType: string}

type toolResultContent =
  | TextContent(textContent)
  | ImageContent(imageContent)

let toolResultContentSchema = S.union([
  S.object(s => {
    s.tag("type", "text")
    TextContent({text: s.field("text", S.string)})
  }),
  S.object(s => {
    s.tag("type", "image")
    ImageContent({data: s.field("data", S.string), mimeType: s.field("mimeType", S.string)})
  }),
])

// Tool error
@schema
type toolError = {
  code: int,
  message: string,
}

// Tool call result (MCP CallToolResult spec)
module CallToolResult: {
  type t
  let schema: S.t<t>
  let makeText: string => t
  let makeImage: (~data: string, ~mimeType: string) => t
  let makeError: string => t
} = {
  type t = {
    content: array<toolResultContent>,
    structuredContent?: JSON.t,
    isError?: bool,
    _meta?: Dict.t<JSON.t>,
  }

  let schema = S.object(s => {
    content: s.field("content", S.array(toolResultContentSchema)),
    structuredContent: ?s.field("structuredContent", S.option(S.json)),
    isError: ?s.field("isError", S.option(S.bool)),
    _meta: ?s.field("_meta", S.option(S.dict(S.json))),
  })

  let makeText = text => {
    content: [TextContent({text: text})],
  }

  let makeImage = (~data, ~mimeType) => {
    content: [ImageContent({data, mimeType})],
  }

  let makeError = text => {
    content: [TextContent({text: text})],
    isError: true,
  }
}

let callToolResultSchema = CallToolResult.schema

// Tools list result
@schema
type toolsListResult = {tools: array<JSON.t>}

// Result of executing a tool — either completed immediately or suspended
// waiting for external input (e.g. interactive tool awaiting user response).
type executeToolResult =
  | Completed(CallToolResult.t)
  | Suspended

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
    ~callId: string,
    ~onProgress: option<string => unit>,
  ) => promise<executeToolResult>,
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
    ~callId: string,
    ~onProgress: option<string => unit>=?,
  ) => promise<executeToolResult>
}
