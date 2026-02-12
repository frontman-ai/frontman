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
  // Frontman extension: optional metadata for passing extra info (e.g., env key detection)
  metadata: option<JSON.t>,
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

// session/load request params
@schema
type sessionLoadParams = {
  @as("sessionId")
  sessionId: string,
  cwd: string,
  @as("mcpServers")
  mcpServers: array<JSON.t>,
}

// delete_session request params (non-ACP channel event)
@schema
type deleteSessionParams = {
  @as("sessionId")
  sessionId: string,
}

// Title update notification from server
@schema
type titleUpdated = {
  @as("sessionId")
  sessionId: string,
  title: string,
}

// Annotations for embedded resources
@schema
type annotations = {
  @as("_meta")
  _meta: option<JSON.t>,
}

// Text resource contents (for EmbeddedResourceResource)
@schema
type textResourceContents = {
  uri: string,
  @as("mimeType")
  mimeType: option<string>,
  text: string,
}

// Blob resource contents (for EmbeddedResourceResource)
@schema
type blobResourceContents = {
  uri: string,
  @as("mimeType")
  mimeType: option<string>,
  blob: string,
}

// EmbeddedResourceResource union type
type embeddedResourceResource =
  | TextResourceContents(textResourceContents)
  | BlobResourceContents(blobResourceContents)

let embeddedResourceResourceSchema = S.union([
  S.object(s => {
    TextResourceContents({
      uri: s.field("uri", S.string),
      mimeType: s.field("mimeType", S.option(S.string)),
      text: s.field("text", S.string),
    })
  }),
  S.object(s => {
    BlobResourceContents({
      uri: s.field("uri", S.string),
      mimeType: s.field("mimeType", S.option(S.string)),
      blob: s.field("blob", S.string),
    })
  }),
])

// Embedded resource for ContentBlock::Resource (per ACP spec)
@schema
type embeddedResource = {
  @as("_meta")
  _meta: option<JSON.t>,
  annotations: option<annotations>,
  resource: embeddedResourceResource,
}

// Content block for prompts and responses
// Supports text, resource_link, resource types per ACP spec, and structured JSON content
type contentBlock = {
  @as("type")
  type_: string,
  // For type="text"
  text: option<string>,
  // For type="resource_link"
  uri: option<string>,
  // For type="resource" - contains EmbeddedResource wrapper
  resource: option<embeddedResource>,
  // For structured JSON content from backend tools
  content: option<JSON.t>,
}

let contentBlockSchema = S.object(s => {
  type_: s.field("type", S.string),
  text: s.field("text", S.option(S.string)),
  uri: s.field("uri", S.option(S.string)),
  resource: s.field("resource", S.option(embeddedResourceSchema)),
  content: s.field("content", S.option(S.json)),
})

let embeddedResourceSchema = S.object(s => {
  _meta: s.field("_meta", S.option(S.json)),
  annotations: s.field("annotations", S.option(annotationsSchema)),
  resource: s.field("resource", embeddedResourceResourceSchema),
})

let annotationsSchema = S.object(s => {
  _meta: s.field("_meta", S.option(S.json)),
})

// Tool call content item (for tool_call_update)
type toolCallContentItem = {
  @as("type")
  type_: string,
  content: option<contentBlock>,
}

let toolCallContentItemSchema = S.object(s => {
  type_: s.field("type", S.string),
  content: s.field("content", S.option(contentBlockSchema)),
})

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

// Plan entry priority (per ACP spec)
type planEntryPriority =
  | @as("high") High
  | @as("medium") Medium
  | @as("low") Low

let planEntryPrioritySchema = S.union([S.literal(High), S.literal(Medium), S.literal(Low)])

// Plan entry status (per ACP spec)
type planEntryStatus =
  | @as("pending") Pending
  | @as("in_progress") InProgress
  | @as("completed") Completed

let planEntryStatusSchema = S.union([
  S.literal(Pending),
  S.literal(InProgress),
  S.literal(Completed),
])

// Plan entry structure per ACP spec
type planEntry = {
  content: string,
  priority: planEntryPriority,
  status: planEntryStatus,
}

let planEntrySchema = S.object(s => {
  content: s.field("content", S.string),
  priority: s.field("priority", planEntryPrioritySchema),
  status: s.field("status", planEntryStatusSchema),
})

// Session update variants - discriminated by sessionUpdate field
// Per ACP spec: only agent_message_chunk exists (first chunk implicitly starts message,
// session/prompt response with stopReason signals message end)
type sessionUpdate =
  | AgentMessageChunk({content: option<contentBlock>})
  | UserMessageChunk({content: contentBlock, timestamp: string})
  | ToolCall({
      toolCallId: string,
      title: option<string>,
      kind: option<string>,
      status: option<string>,
      parentAgentId: option<string>, // If present, this is a sub-agent tool call
      spawningToolName: option<string>,
    }) // Tool name that spawned the sub-agent
  | ToolCallUpdate({
      toolCallId: string,
      status: option<string>,
      content: option<array<toolCallContentItem>>,
    })
  | Plan({entries: option<array<planEntry>>})
  | Error({message: string})
  | Unknown({sessionUpdate: string})

// Session update schema using S.union with s.tag for proper discrimination
let sessionUpdateSchema = S.union([
  S.object(s => {
    s.tag("sessionUpdate", "agent_message_chunk")
    AgentMessageChunk({
      content: s.field("content", S.option(contentBlockSchema)),
    })
  }),
  S.object(s => {
    s.tag("sessionUpdate", "user_message_chunk")
    UserMessageChunk({
      content: s.field("content", contentBlockSchema),
      timestamp: s.field("timestamp", S.string),
    })
  }),
  S.object(s => {
    s.tag("sessionUpdate", "tool_call")
    ToolCall({
      toolCallId: s.field("toolCallId", S.string),
      title: s.field("title", S.option(S.string)),
      kind: s.field("kind", S.option(S.string)),
      status: s.field("status", S.option(S.string)),
      parentAgentId: s.field("parentAgentId", S.option(S.string)),
      spawningToolName: s.field("spawningToolName", S.option(S.string)),
    })
  }),
  S.object(s => {
    s.tag("sessionUpdate", "tool_call_update")
    ToolCallUpdate({
      toolCallId: s.field("toolCallId", S.string),
      status: s.field("status", S.option(S.string)),
      content: s.field("content", S.option(S.array(toolCallContentItemSchema))),
    })
  }),
  S.object(s => {
    s.tag("sessionUpdate", "plan")
    Plan({
      entries: s.field("entries", S.option(S.array(planEntrySchema))),
    })
  }),
  S.object(s => {
    s.tag("sessionUpdate", "error")
    Error({
      message: s.field("message", S.string),
    })
  }),
  // Fallback for unknown session update types
  S.object(s => {
    Unknown({
      sessionUpdate: s.field("sessionUpdate", S.string),
    })
  }),
])

// session/update params
type sessionUpdateParams = {
  sessionId: string,
  update: sessionUpdate,
}

let sessionUpdateParamsSchema = S.object(s => {
  sessionId: s.field("sessionId", S.string),
  update: s.field("update", sessionUpdateSchema),
})

// Full session/update notification envelope
type sessionUpdateNotification = {
  jsonrpc: string,
  method: string,
  params: sessionUpdateParams,
}

let sessionUpdateNotificationSchema = S.object(s => {
  jsonrpc: s.field("jsonrpc", S.string),
  method: s.field("method", S.string),
  params: s.field("params", sessionUpdateParamsSchema),
})

// Session summary for list_sessions response
type sessionSummary = {
  sessionId: string,
  title: string,
  createdAt: string,
  updatedAt: string,
}

let sessionSummarySchema = S.object(s => {
  sessionId: s.field("sessionId", S.string),
  title: s.field("title", S.string),
  createdAt: s.field("createdAt", S.string),
  updatedAt: s.field("updatedAt", S.string),
})

type listSessionsResult = {sessions: array<sessionSummary>}

let listSessionsResultSchema = S.object(s => {
  sessions: s.field("sessions", S.array(sessionSummarySchema)),
})
