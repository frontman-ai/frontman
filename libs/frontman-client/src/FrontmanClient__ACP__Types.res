// ACP (Agent Client Protocol) Types
// Based on: https://github.com/agentclientprotocol/agent-client-protocol/schema/schema.json

S.enableJson()

// Protocol version is an integer (uint16 in spec)
type protocolVersion = int
let currentProtocolVersion = 1

// Implementation info (used for clientInfo and agentInfo)
@schema
type implementation = {
  name: string,
  version: string,
  title: option<string>,
}

// File system capabilities
@schema
type fileSystemCapability = {
  @as("readTextFile")
  readTextFile: option<bool>,
  @as("writeTextFile")
  writeTextFile: option<bool>,
}

// Client capabilities
@schema
type clientCapabilities = {
  fs: option<fileSystemCapability>,
  terminal: option<bool>,
}

// Prompt capabilities (what content types agent supports)
@schema
type promptCapabilities = {
  image: option<bool>,
  audio: option<bool>,
  @as("embeddedContext")
  embeddedContext: option<bool>,
}

// MCP transport capabilities (extended with websocket for our architecture)
@schema
type mcpCapabilities = {
  http: option<bool>,
  sse: option<bool>,
  websocket: option<bool>,
}

// Agent capabilities
@schema
type agentCapabilities = {
  @as("loadSession")
  loadSession: option<bool>,
  @as("mcpCapabilities")
  mcpCapabilities: option<mcpCapabilities>,
  @as("promptCapabilities")
  promptCapabilities: option<promptCapabilities>,
}

// Auth method
@schema
type authMethod = {
  id: string,
  name: string,
  description: option<string>,
}

// Initialize request params
@schema
type initializeParams = {
  @as("protocolVersion")
  protocolVersion: int,
  @as("clientCapabilities")
  clientCapabilities: option<clientCapabilities>,
  @as("clientInfo")
  clientInfo: option<implementation>,
}

// Initialize response result
@schema
type initializeResult = {
  @as("protocolVersion")
  protocolVersion: int,
  @as("agentCapabilities")
  agentCapabilities: option<agentCapabilities>,
  @as("agentInfo")
  agentInfo: option<implementation>,
  @as("authMethods")
  authMethods: option<array<authMethod>>,
}

// session/new response result
@schema
type sessionNewResult = {
  @as("sessionId")
  sessionId: string,
}

// Embedded resource for ContentBlock::Resource
@schema
type embeddedResource = {
  uri: string,
  @as("mimeType")
  mimeType: string,
  text: option<string>,
}

// Content block for prompts and responses
// Supports text, resource_link, resource types per ACP spec, and structured JSON content
@schema
type contentBlock = {
  @as("type")
  type_: string,
  // For type="text"
  text: option<string>,
  // For type="resource_link"
  uri: option<string>,
  // For type="resource"
  resource: option<embeddedResource>,
  // For type="resource" - mimeType is required per ACP spec
  @as("mimeType")
  mimeType: option<string>,
  // For structured JSON content from backend tools
  content: option<JSON.t>,
}

// Tool call content item (for tool_call_update)
@schema
type toolCallContentItem = {
  @as("type")
  type_: string,
  content: option<contentBlock>,
}

// Tool call status
type toolCallStatus =
  | @as("pending") Pending
  | @as("in_progress") InProgress
  | @as("completed") Completed
  | @as("failed") Failed

// session/prompt result
@schema
type promptResult = {
  @as("stopReason")
  stopReason: string,
}

// Session update - the update object from session/update notification
// Supports agent_message_chunk, tool_call, and tool_call_update
@schema
type sessionUpdate = {
  @as("sessionUpdate")
  sessionUpdate: string,
  // For agent_message_chunk - single content block
  content: option<contentBlock>,
  // For tool_call and tool_call_update
  @as("toolCallId")
  toolCallId: option<string>,
  @as("toolName")
  toolName: option<string>,
  title: option<string>,
  kind: option<string>,
  status: option<string>,
  // For tool_call_update with results (array of content items)
  @as("contents")
  contents: option<array<toolCallContentItem>>,
}

// session/update params
@schema
type sessionUpdateParams = {
  @as("sessionId")
  sessionId: string,
  update: sessionUpdate,
}

// Full session/update notification envelope
@schema
type sessionUpdateNotification = {
  jsonrpc: string,
  method: string,
  params: sessionUpdateParams,
}
