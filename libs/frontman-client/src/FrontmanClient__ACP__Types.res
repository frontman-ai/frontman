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

// Content block for prompts and responses
@schema
type contentBlock = {
  @as("type")
  type_: string,
  text: option<string>,
}

// session/prompt result
@schema
type promptResult = {
  @as("stopReason")
  stopReason: string,
}

// Session update - the update object from session/update notification
@schema
type sessionUpdate = {
  @as("sessionUpdate")
  sessionUpdate: string,
  content: contentBlock,
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
