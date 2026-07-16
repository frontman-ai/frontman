// ACP (Agent Client Protocol) Types
// Based on ACP schema-v1.19.0 at commit a213df5240048f96d2b23f644984bb20c188a234.
// Source: libs/frontman-protocol/schemas/acp/upstream/README.md

// Protocol version is an integer (uint16 in spec)
type protocolVersion = int
let currentProtocolVersion = 1

// ---------------------------------------------------------------------------
// Frontman agent attribution extension metadata
// Contract: docs/acp-agent-attribution.md
// ---------------------------------------------------------------------------

let nonEmptyStringSchema = S.string->S.min(1, ~message="Must not be empty")

type agentAttributionCapability = {version: int}

let agentAttributionCapabilitySchema = S.object(s => {
  version: s.field(
    "version",
    S.int
    ->S.min(1, ~message="Version must be a positive integer")
    ->S.max(65535, ~message="Version must fit an unsigned 16-bit integer"),
  ),
})

type frontmanCapabilityNamespace = {
  agentAttribution: option<agentAttributionCapability>,
}

let frontmanCapabilityNamespaceSchema = S.object(s => {
  agentAttribution: s.field("agentAttribution", S.option(agentAttributionCapabilitySchema)),
})

type capabilityMetadata = {
  frontmanDev: option<frontmanCapabilityNamespace>,
}

let capabilityMetadataSchema = S.object(s => {
  frontmanDev: s.field("frontman.dev", S.option(frontmanCapabilityNamespaceSchema)),
})

type agentCatalogEntry = {
  id: string,
  name: string,
  displayName: string,
  description: string,
  color: string,
}

let agentCatalogEntrySchema = S.object(s => {
  id: s.field("id", nonEmptyStringSchema),
  name: s.field("name", nonEmptyStringSchema),
  displayName: s.field("displayName", nonEmptyStringSchema),
  description: s.field("description", nonEmptyStringSchema),
  color: s.field(
    "color",
    S.string->S.pattern(/^#[0-9A-Fa-f]{6}$/, ~message="Expected #RRGGBB color"),
  ),
})

let catalogIdsUnique = agents => {
  let ids = Set.make()
  agents->Array.every(agent => {
    switch ids->Set.has(agent.id) {
    | true => false
    | false => {
        ids->Set.add(agent.id)
        true
      }
    }
  })
}

let agentCatalogSchema =
  S.array(agentCatalogEntrySchema)
  ->S.refine(catalogIdsUnique, ~error="Agent catalog IDs must be unique")
  ->S.extendJSONSchema({
    uniqueItems: true,
    description: "Frontman runtime validation also requires unique id fields",
  })

type sessionMetadata = {
  agents: option<array<agentCatalogEntry>>,
}

let sessionMetadataSchema = S.object(s => {
  agents: s.field("frontman.dev/agents", S.option(agentCatalogSchema)),
})

let rfc3339TimestampSchema =
  S.string
  ->S.pattern(
    /^\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])[Tt]([01]\d|2[0-3]):[0-5]\d:([0-5]\d|60)(\.\d+)?([Zz]|[+-]([01]\d|2[0-3]):[0-5]\d)$/,
    ~message="Expected RFC 3339 timestamp",
  )
  ->S.refine(timestamp => {
    let year = timestamp->String.slice(~start=0, ~end=4)->Int.fromString
    let month = timestamp->String.slice(~start=5, ~end=7)->Int.fromString
    let day = timestamp->String.slice(~start=8, ~end=10)->Int.fromString

    switch (year, month, day) {
    | (Some(year), Some(month), Some(day)) => {
        let leapYear = mod(year, 4) == 0 && (mod(year, 100) != 0 || mod(year, 400) == 0)
        let daysInMonth = switch month {
        | 2 => leapYear ? 29 : 28
        | 4 | 6 | 9 | 11 => 30
        | _ => 31
        }
        day <= daysInMonth
      }
    | _ => false
    }
  }, ~error="Timestamp contains an invalid calendar date")
  ->S.extendJSONSchema({format: "date-time"})

type messageMetadata = {
  agentId: string,
  timestamp: string,
}

let messageMetadataSchema = S.object(s => {
  agentId: s.field("frontman.dev/agentId", nonEmptyStringSchema),
  timestamp: s.field("frontman.dev/timestamp", rfc3339TimestampSchema),
})

// Implementation info (used for clientInfo and agentInfo)
@schema
type implementation = {
  name: string,
  version: string,
  title: option<string>,
  // ACP spec extensibility: optional metadata for passing extra info (e.g., env key detection)
  @as("_meta")
  _meta: option<JSON.t>,
}

// File system capabilities
@schema
type fileSystemCapability = {
  @as("readTextFile")
  readTextFile: option<bool>,
  @as("writeTextFile")
  writeTextFile: option<bool>,
}

// Elicitation capability (what form types the client supports)
@schema
type elicitationCapability = {
  form: option<JSON.t>,
  url: option<JSON.t>,
}

// Client capabilities
@schema
type clientCapabilities = {
  fs: option<fileSystemCapability>,
  terminal: option<bool>,
  elicitation: option<elicitationCapability>,
  @as("_meta")
  _meta: option<JSON.t>,
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
  @as("_meta")
  _meta: option<JSON.t>,
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

let initializeParamsToJson = (params: initializeParams): JSON.t => {
  let json = params->JSON.stringifyAny->Option.getOrThrow->JSON.parseOrThrow
  json->S.parseOrThrow(~to=initializeParamsSchema)->ignore
  json
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

// session/load request params
@schema
type sessionLoadParams = {
  @as("sessionId")
  sessionId: string,
  cwd: string,
  @as("mcpServers")
  mcpServers: array<JSON.t>,
  @as("_meta")
  _meta: option<JSON.t>,
}

// ---------------------------------------------------------------------------
// Session Modes (ACP spec)
// ---------------------------------------------------------------------------

// Unique identifier for a session mode
type sessionModeId = string

// A mode the agent can operate in
type sessionMode = {
  id: sessionModeId,
  name: string,
  description: option<string>,
  _meta: option<JSON.t>,
}

let sessionModeSchema = S.object(s => {
  id: s.field("id", S.string),
  name: s.field("name", S.string),
  description: s.field("description", S.option(S.string)),
  _meta: s.field("_meta", S.option(S.json)),
})

// The set of modes and the one currently active
type sessionModeState = {
  currentModeId: sessionModeId,
  availableModes: array<sessionMode>,
  _meta: option<JSON.t>,
}

let sessionModeStateSchema = S.object(s => {
  currentModeId: s.field("currentModeId", S.string),
  availableModes: s.field("availableModes", S.array(sessionModeSchema)),
  _meta: s.field("_meta", S.option(S.json)),
})

// ---------------------------------------------------------------------------
// Session Config Options (ACP spec)
// ---------------------------------------------------------------------------

// Unique identifier for a config option value
type sessionConfigValueId = string

// Unique identifier for a config option group
type sessionConfigGroupId = string

// A possible value for a session config option
type sessionConfigSelectOption = {
  value: sessionConfigValueId,
  name: string,
  description: option<string>,
  _meta: option<JSON.t>,
}

let sessionConfigSelectOptionSchema = S.object(s => {
  value: s.field("value", S.string),
  name: s.field("name", S.string),
  description: s.field("description", S.option(S.string)),
  _meta: s.field("_meta", S.option(S.json)),
})

// A group of option values
type sessionConfigSelectGroup = {
  group: sessionConfigGroupId,
  name: string,
  options: array<sessionConfigSelectOption>,
  _meta: option<JSON.t>,
}

let sessionConfigSelectGroupSchema = S.object(s => {
  group: s.field("group", S.string),
  name: s.field("name", S.string),
  options: s.field("options", S.array(sessionConfigSelectOptionSchema)),
  _meta: s.field("_meta", S.option(S.json)),
})

// Options for a select config: either a flat list or a grouped list
type sessionConfigSelectOptions =
  | Ungrouped(array<sessionConfigSelectOption>)
  | Grouped(array<sessionConfigSelectGroup>)

let sessionConfigSelectOptionsSchema = S.union([
  // Try grouped first (items have a "group" field that distinguishes them)
  S.array(sessionConfigSelectGroupSchema)->S.transform(s => {
    parser: v => Grouped(v),
    serializer: v =>
      switch v {
      | Grouped(groups) => groups
      | Ungrouped(_) => s.fail("Expected Grouped")
      },
  }),
  S.array(sessionConfigSelectOptionSchema)->S.transform(s => {
    parser: v => Ungrouped(v),
    serializer: v =>
      switch v {
      | Ungrouped(opts) => opts
      | Grouped(_) => s.fail("Expected Ungrouped")
      },
  }),
])

// Semantic category for a config option (UX hint).
// Per ACP spec: "Clients MUST handle missing or unknown categories gracefully."
// Category names beginning with `_` are free for custom use.
type sessionConfigOptionCategory =
  | @as("mode") Mode
  | @as("model") Model
  | @as("thought_level") ThoughtLevel
  | Other(string)

let sessionConfigOptionCategorySchema = S.union([
  S.literal(Mode),
  S.literal(Model),
  S.literal(ThoughtLevel),
  S.string->S.transform(_ => {
    parser: v => Other(v),
    serializer: v =>
      switch v {
      | Other(s) => s
      | Mode => "mode"
      | Model => "model"
      | ThoughtLevel => "thought_level"
      },
  }),
])

// A session config option — discriminated union on "type".
// Currently only the "select" variant exists in the ACP spec.
type sessionConfigOption =
  | SelectConfigOption({
      id: string,
      name: string,
      description: option<string>,
      category: option<sessionConfigOptionCategory>,
      options: sessionConfigSelectOptions,
      _meta: option<JSON.t>,
    })

let sessionConfigOptionSchema = S.union([
  S.object(s => {
    s.tag("type", "select")
    SelectConfigOption({
      id: s.field("id", S.string),
      name: s.field("name", S.string),
      description: s.field("description", S.option(S.string)),
      category: s.field("category", S.option(sessionConfigOptionCategorySchema)),
      options: s.field("options", sessionConfigSelectOptionsSchema),
      _meta: s.field("_meta", S.option(S.json)),
    })
  }),
])

// ---------------------------------------------------------------------------
// session/load response result (ACP LoadSessionResponse)
// ---------------------------------------------------------------------------

type sessionLoadResult = {
  modes: option<sessionModeState>,
  configOptions: option<array<sessionConfigOption>>,
  _meta: option<JSON.t>,
}

let sessionLoadResultSchema = S.object(s => {
  modes: s.field("modes", S.option(sessionModeStateSchema)),
  configOptions: s.field("configOptions", S.option(S.array(sessionConfigOptionSchema))),
  _meta: s.field("_meta", S.option(S.json)),
})

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

// Find a config option by its semantic category (e.g. Model, Mode, ThoughtLevel).
let findConfigOptionByCategory = (
  configOptions: array<sessionConfigOption>,
  category: sessionConfigOptionCategory,
): option<sessionConfigOption> =>
  configOptions->Array.find(opt =>
    switch opt {
    | SelectConfigOption({category: Some(c)}) => c == category
    | _ => false
    }
  )

// ---------------------------------------------------------------------------
// session/new response result (ACP NewSessionResponse)
// ---------------------------------------------------------------------------

type sessionNewResult = {
  sessionId: string,
  modes: option<sessionModeState>,
  configOptions: option<array<sessionConfigOption>>,
  _meta: option<JSON.t>,
}

let sessionNewResultSchema = S.object(s => {
  sessionId: s.field("sessionId", S.string),
  modes: s.field("modes", S.option(sessionModeStateSchema)),
  configOptions: s.field("configOptions", S.option(S.array(sessionConfigOptionSchema))),
  _meta: s.field("_meta", S.option(S.json)),
})

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

// Payload for the config_options_updated channel event (non-ACP, tasks channel)
type configOptionsUpdated = {configOptions: array<sessionConfigOption>}

let configOptionsUpdatedSchema = S.object(s => {
  configOptions: s.field("configOptions", S.array(sessionConfigOptionSchema)),
})

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
// Discriminated union on "type" field per ACP spec:
// - TextContent (type="text"): text string
// - ImageContent (type="image"): base64 data + mimeType
// - AudioContent (type="audio"): base64 data + mimeType
// - ResourceLink (type="resource_link"): name + uri
// - EmbeddedResource (type="resource"): embedded resource wrapper
type contentBlock =
  | TextContent({text: string, _meta: option<JSON.t>, annotations: option<annotations>})
  | ImageContent({
      data: string,
      mimeType: string,
      _meta: option<JSON.t>,
      annotations: option<annotations>,
    })
  | AudioContent({
      data: string,
      mimeType: string,
      _meta: option<JSON.t>,
      annotations: option<annotations>,
    })
  | ResourceLink({
      name: string,
      uri: string,
      _meta: option<JSON.t>,
      annotations: option<annotations>,
    })
  | EmbeddedResource({
      resource: embeddedResource,
      _meta: option<JSON.t>,
      annotations: option<annotations>,
    })

let contentBlockSchema = S.union([
  S.object(s => {
    s.tag("type", "text")
    TextContent({
      text: s.field("text", S.string),
      _meta: s.field("_meta", S.option(S.json)),
      annotations: s.field("annotations", S.option(annotationsSchema)),
    })
  }),
  S.object(s => {
    s.tag("type", "image")
    ImageContent({
      data: s.field("data", S.string),
      mimeType: s.field("mimeType", S.string),
      _meta: s.field("_meta", S.option(S.json)),
      annotations: s.field("annotations", S.option(annotationsSchema)),
    })
  }),
  S.object(s => {
    s.tag("type", "audio")
    AudioContent({
      data: s.field("data", S.string),
      mimeType: s.field("mimeType", S.string),
      _meta: s.field("_meta", S.option(S.json)),
      annotations: s.field("annotations", S.option(annotationsSchema)),
    })
  }),
  S.object(s => {
    s.tag("type", "resource_link")
    ResourceLink({
      name: s.field("name", S.string),
      uri: s.field("uri", S.string),
      _meta: s.field("_meta", S.option(S.json)),
      annotations: s.field("annotations", S.option(annotationsSchema)),
    })
  }),
  S.object(s => {
    s.tag("type", "resource")
    EmbeddedResource({
      resource: s.field("resource", embeddedResourceSchema),
      _meta: s.field("_meta", S.option(S.json)),
      annotations: s.field("annotations", S.option(annotationsSchema)),
    })
  }),
])

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

let toolCallStatusSchema = S.union([
  S.literal(Pending),
  S.literal(InProgress),
  S.literal(Completed),
  S.literal(Failed),
])

// Stop reason (per ACP spec)
type stopReason =
  | @as("end_turn") EndTurn
  | @as("max_tokens") MaxTokens
  | @as("max_turn_requests") MaxTurnRequests
  | @as("refusal") Refusal
  | @as("cancelled") Cancelled

let stopReasonSchema = S.union([
  S.literal(EndTurn),
  S.literal(MaxTokens),
  S.literal(MaxTurnRequests),
  S.literal(Refusal),
  S.literal(Cancelled),
])

type sessionState =
  | @as("running") Running
  | @as("idle") Idle
  | @as("requires_action") RequiresAction

let sessionStateSchema = S.union([S.literal(Running), S.literal(Idle), S.literal(RequiresAction)])

// session/prompt acceptance result
type promptResult = unit

let promptResultSchema = S.object(_s => ())

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
type sessionUpdate =
  | AgentMessageChunk({messageId: string, content: contentBlock, _meta: messageMetadata})
  | UserMessageChunk({messageId: string, content: contentBlock, _meta: messageMetadata})
  | GenericAgentMessageChunk({
      messageId: option<string>,
      content: contentBlock,
      _meta: option<JSON.t>,
    })
  | GenericUserMessageChunk({
      messageId: option<string>,
      content: contentBlock,
      _meta: option<JSON.t>,
    })
  | Unknown({sessionUpdate: string})
  | ToolCall({
      toolCallId: string,
      title: string,
      kind: option<string>,
      status: option<toolCallStatus>,
      timestamp: string,
      parentAgentId: option<string>, // If present, this is a sub-agent tool call
      spawningToolName: option<string>,
    }) // Tool name that spawned the sub-agent
  | ToolCallUpdate({
      toolCallId: string,
      status: option<toolCallStatus>,
      content: option<array<toolCallContentItem>>,
    })
  | Plan({entries: array<planEntry>})
  | ConfigOptionUpdate({configOptions: array<sessionConfigOption>})
  | CurrentModeUpdate({currentModeId: sessionModeId})
  | StateUpdate({state: sessionState, stopReason: option<stopReason>})
  | Error({
      _meta: option<JSON.t>,
      message: string,
      timestamp: string,
      retryAt: option<string>,
      attempt: option<int>,
      maxAttempts: option<int>,
      category: option<string>,
    })

let commonSessionUpdateSchema = S.union([
  S.object(s => {
    s.tag("sessionUpdate", "tool_call")
    ToolCall({
      toolCallId: s.field("toolCallId", S.string),
      title: s.field("title", S.string),
      kind: s.field("kind", S.option(S.string)),
      status: s.field("status", S.option(toolCallStatusSchema)),
      timestamp: s.field("timestamp", S.string),
      parentAgentId: s.field("parentAgentId", S.option(S.string)),
      spawningToolName: s.field("spawningToolName", S.option(S.string)),
    })
  }),
  S.object(s => {
    s.tag("sessionUpdate", "tool_call_update")
    ToolCallUpdate({
      toolCallId: s.field("toolCallId", S.string),
      status: s.field("status", S.option(toolCallStatusSchema)),
      content: s.field("content", S.option(S.array(toolCallContentItemSchema))),
    })
  }),
  S.object(s => {
    s.tag("sessionUpdate", "plan")
    Plan({
      entries: s.field("entries", S.array(planEntrySchema)),
    })
  }),
  S.object(s => {
    s.tag("sessionUpdate", "config_option_update")
    ConfigOptionUpdate({
      configOptions: s.field("configOptions", S.array(sessionConfigOptionSchema)),
    })
  }),
  S.object(s => {
    s.tag("sessionUpdate", "current_mode_update")
    CurrentModeUpdate({
      currentModeId: s.field("currentModeId", S.string),
    })
  }),
  S.object(s => {
    s.tag("sessionUpdate", "state_update")
    StateUpdate({
      state: s.field("state", sessionStateSchema),
      stopReason: s.field("stopReason", S.option(stopReasonSchema)),
    })
  }),
  S.object(s => {
    s.tag("sessionUpdate", "error")
    Error({
      _meta: s.field("_meta", S.option(S.json)),
      message: s.field("message", S.string),
      timestamp: s.field("timestamp", S.string),
      retryAt: s.field("retryAt", S.option(S.string)),
      attempt: s.field("attempt", S.option(S.int)),
      maxAttempts: s.field("maxAttempts", S.option(S.int)),
      category: s.field("category", S.option(S.string)),
    })
  }),
])

let sessionUpdateSchema = S.union([
  S.object(s => {
    s.tag("sessionUpdate", "agent_message_chunk")
    AgentMessageChunk({
      messageId: s.field("messageId", nonEmptyStringSchema),
      content: s.field("content", contentBlockSchema),
      _meta: s.field("_meta", messageMetadataSchema),
    })
  }),
  S.object(s => {
    s.tag("sessionUpdate", "user_message_chunk")
    UserMessageChunk({
      messageId: s.field("messageId", nonEmptyStringSchema),
      content: s.field("content", contentBlockSchema),
      _meta: s.field("_meta", messageMetadataSchema),
    })
  }),
  commonSessionUpdateSchema,
])

let genericSessionUpdateSchema = S.union([
  S.object(s => {
    s.tag("sessionUpdate", "agent_message_chunk")
    GenericAgentMessageChunk({
      messageId: s.field("messageId", S.option(nonEmptyStringSchema)),
      content: s.field("content", contentBlockSchema),
      _meta: s.field("_meta", S.option(S.json)),
    })
  }),
  S.object(s => {
    s.tag("sessionUpdate", "user_message_chunk")
    GenericUserMessageChunk({
      messageId: s.field("messageId", S.option(nonEmptyStringSchema)),
      content: s.field("content", contentBlockSchema),
      _meta: s.field("_meta", S.option(S.json)),
    })
  }),
  commonSessionUpdateSchema,
])

let unknownSessionUpdateSchema = S.object(s => Unknown({
  sessionUpdate: s.field("sessionUpdate", S.string),
}))

type sessionUpdateParams = {
  sessionId: string,
  update: sessionUpdate,
}

// Full session/update notification envelope
type sessionUpdateNotification = {
  jsonrpc: string,
  method: string,
  params: sessionUpdateParams,
}

let makeSessionUpdateNotificationSchema = updateSchema =>
  S.object(s => {
    jsonrpc: s.field("jsonrpc", S.literal("2.0")),
    method: s.field("method", S.literal("session/update")),
    params: s.field(
      "params",
      S.object(s => {
        sessionId: s.field("sessionId", S.string),
        update: s.field("update", updateSchema),
      }),
    ),
  })

let sessionUpdateNotificationSchema = makeSessionUpdateNotificationSchema(sessionUpdateSchema)
let genericSessionUpdateNotificationSchema = makeSessionUpdateNotificationSchema(
  genericSessionUpdateSchema,
)
let unknownSessionUpdateNotificationSchema = makeSessionUpdateNotificationSchema(
  unknownSessionUpdateSchema,
)

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

// ---------------------------------------------------------------------------
// Elicitation (session/elicitation)
// ---------------------------------------------------------------------------

// Elicitation mode — "form" for inline forms, "url" for out-of-band browser flows
type elicitationMode =
  | @as("form") Form
  | @as("url") Url

let elicitationModeSchema = S.union([S.literal(Form), S.literal(Url)])

// session/elicitation request params (server -> client)
@schema
type elicitationRequestParams = {
  @as("sessionId")
  sessionId: string,
  mode: elicitationMode,
  message: string,
  // For form mode: JSON Schema describing the fields to render
  @as("requestedSchema")
  requestedSchema: option<JSON.t>,
  // For URL mode: the URL the client should open
  url: option<string>,
  // For URL mode: correlates with notifications/elicitation/complete
  @as("elicitationId")
  elicitationId: option<string>,
}

// User's action on the elicitation form
type elicitationAction =
  | @as("accept") Accept
  | @as("decline") Decline
  | @as("cancel") Cancel

let elicitationActionSchema = S.union([S.literal(Accept), S.literal(Decline), S.literal(Cancel)])

// session/elicitation response result (client -> server)
@schema
type elicitationResponseResult = {
  action: elicitationAction,
  content: option<JSON.t>,
}

// notifications/elicitation/complete params
@schema
type elicitationCompleteParams = {
  @as("elicitationId")
  elicitationId: string,
}
