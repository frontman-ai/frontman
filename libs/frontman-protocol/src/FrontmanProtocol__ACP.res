type protocolVersion = int
let currentProtocolVersion = 1

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
  ->S.refine(agents => agents->Array.length > 0, ~error="Agent catalog must not be empty")
  ->S.refine(catalogIdsUnique, ~error="Agent catalog IDs must be unique")
  ->S.extendJSONSchema({
    uniqueItems: true,
    minItems: 1,
    description: "Frontman runtime validation also requires unique id fields",
  })

type agentAttributionConfigurationMetadata = {
  agentAttribution: agentAttributionCapability,
  agents: array<agentCatalogEntry>,
  defaultAgentId: string,
}

let agentAttributionConfigurationMetadataSchema = S.object(s => {
  agentAttribution: s.field("agentAttribution", agentAttributionCapabilitySchema),
  agents: s.field("agents", agentCatalogSchema),
  defaultAgentId: s.field("defaultAgentId", nonEmptyStringSchema),
})->S.refine(
  configuration =>
    configuration.agents->Array.some(agent => agent.id == configuration.defaultAgentId),
  ~error="Default agent ID must exist in agent catalog",
)

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

@schema
type implementation = {
  name: string,
  version: string,
  title: option<string>,
  @as("_meta")
  _meta: option<JSON.t>,
}

@schema
type fileSystemCapability = {
  @as("readTextFile")
  readTextFile: option<bool>,
  @as("writeTextFile")
  writeTextFile: option<bool>,
}

@schema
type elicitationCapability = {
  form: option<JSON.t>,
  url: option<JSON.t>,
}

@schema
type clientCapabilities = {
  fs: option<fileSystemCapability>,
  terminal: option<bool>,
  elicitation: option<elicitationCapability>,
  @as("_meta")
  _meta: option<JSON.t>,
}

@schema
type promptCapabilities = {
  image: option<bool>,
  audio: option<bool>,
  @as("embeddedContext")
  embeddedContext: option<bool>,
}

@schema
type mcpCapabilities = {
  http: option<bool>,
  sse: option<bool>,
  websocket: option<bool>,
}

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

@schema
type authMethod = {
  id: string,
  name: string,
  description: option<string>,
}

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

type sessionModeId = string

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

type sessionConfigValueId = string

type sessionConfigGroupId = string

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

type sessionConfigSelectOptions =
  | Ungrouped(array<sessionConfigSelectOption>)
  | Grouped(array<sessionConfigSelectGroup>)

let sessionConfigSelectOptionsSchema = S.union([
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

type sessionConfigOption =
  | SelectConfigOption({
      id: string,
      name: string,
      description: option<string>,
      category: option<sessionConfigOptionCategory>,
      options: sessionConfigSelectOptions,
      _meta: option<JSON.t>,
    })

let sessionConfigOptionFirstOption = (configOption: sessionConfigOption) => {
  switch configOption {
  | SelectConfigOption({options: Grouped(groups)}) =>
    groups->Array.findMap(group => group.options->Array.get(0))
  | SelectConfigOption({options: Ungrouped(options)}) => options->Array.get(0)
  }
}

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

@schema
type deleteSessionParams = {
  @as("sessionId")
  sessionId: string,
}

@schema
type titleUpdated = {
  @as("sessionId")
  sessionId: string,
  title: string,
}

type configOptionsUpdated = {configOptions: array<sessionConfigOption>}

let configOptionsUpdatedSchema = S.object(s => {
  configOptions: s.field("configOptions", S.array(sessionConfigOptionSchema)),
})

type toolCallContentItem =
  | Content({content: FrontmanProtocol__ContentBlock.t, _meta: option<JSON.t>})
  | Diff({path: string, oldText: option<string>, newText: string, _meta: option<JSON.t>})
  | Terminal({terminalId: string, _meta: option<JSON.t>})

let toolCallContentItemSchema = S.union([
  S.object(s => {
    s.tag("type", "content")
    Content({
      content: s.field("content", FrontmanProtocol__ContentBlock.schema),
      _meta: s.field("_meta", S.option(S.json)),
    })
  }),
  S.object(s => {
    s.tag("type", "diff")
    Diff({
      path: s.field("path", S.string),
      oldText: s.field("oldText", S.nullableAsOption(S.string)),
      newText: s.field("newText", S.string),
      _meta: s.field("_meta", S.option(S.json)),
    })
  }),
  S.object(s => {
    s.tag("type", "terminal")
    Terminal({
      terminalId: s.field("terminalId", S.string),
      _meta: s.field("_meta", S.option(S.json)),
    })
  }),
])

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

type promptResult = unit

let promptResultSchema = S.object(_s => ())

type planEntryPriority =
  | @as("high") High
  | @as("medium") Medium
  | @as("low") Low

let planEntryPrioritySchema = S.union([S.literal(High), S.literal(Medium), S.literal(Low)])

type planEntryStatus =
  | @as("pending") Pending
  | @as("in_progress") InProgress
  | @as("completed") Completed

let planEntryStatusSchema = S.union([
  S.literal(Pending),
  S.literal(InProgress),
  S.literal(Completed),
])

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

type sessionUpdate =
  | AgentMessageChunk({
      messageId: string,
      content: FrontmanProtocol__ContentBlock.t,
      _meta: messageMetadata,
    })
  | UserMessageChunk({
      messageId: string,
      content: FrontmanProtocol__ContentBlock.t,
      _meta: messageMetadata,
    })
  | GenericAgentMessageChunk({
      messageId: option<string>,
      content: FrontmanProtocol__ContentBlock.t,
      _meta: option<JSON.t>,
    })
  | GenericUserMessageChunk({
      messageId: option<string>,
      content: FrontmanProtocol__ContentBlock.t,
      _meta: option<JSON.t>,
    })
  | Unknown({sessionUpdate: string})
  | FrontmanTaskRewound({messageId: string})
  | ToolCall({
      toolCallId: string,
      title: string,
      kind: option<string>,
      status: option<toolCallStatus>,
      content: option<array<toolCallContentItem>>,
      rawInput: option<JSON.t>,
      rawOutput: option<JSON.t>,
      timestamp: string,
      parentAgentId: option<string>,
      spawningToolName: option<string>,
    })
  | ToolCallUpdate({
      toolCallId: string,
      status: option<toolCallStatus>,
      content: option<array<toolCallContentItem>>,
      rawInput: option<JSON.t>,
      rawOutput: option<JSON.t>,
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
    s.tag("sessionUpdate", "frontman_task_rewound")
    FrontmanTaskRewound({messageId: s.field("messageId", nonEmptyStringSchema)})
  }),
  S.object(s => {
    s.tag("sessionUpdate", "tool_call")
    ToolCall({
      toolCallId: s.field("toolCallId", S.string),
      title: s.field("title", S.string),
      kind: s.field("kind", S.option(S.string)),
      status: s.field("status", S.option(toolCallStatusSchema)),
      content: s.field("content", S.option(S.array(toolCallContentItemSchema))),
      rawInput: s.field("rawInput", S.option(S.json)),
      rawOutput: s.field("rawOutput", S.option(S.json)),
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
      rawInput: s.field("rawInput", S.option(S.json)),
      rawOutput: s.field("rawOutput", S.option(S.json)),
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
      content: s.field("content", FrontmanProtocol__ContentBlock.schema),
      _meta: s.field("_meta", messageMetadataSchema),
    })
  }),
  S.object(s => {
    s.tag("sessionUpdate", "user_message_chunk")
    UserMessageChunk({
      messageId: s.field("messageId", nonEmptyStringSchema),
      content: s.field("content", FrontmanProtocol__ContentBlock.schema),
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
      content: s.field("content", FrontmanProtocol__ContentBlock.schema),
      _meta: s.field("_meta", S.option(S.json)),
    })
  }),
  S.object(s => {
    s.tag("sessionUpdate", "user_message_chunk")
    GenericUserMessageChunk({
      messageId: s.field("messageId", S.option(nonEmptyStringSchema)),
      content: s.field("content", FrontmanProtocol__ContentBlock.schema),
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

type elicitationMode =
  | @as("form") Form
  | @as("url") Url

let elicitationModeSchema = S.union([S.literal(Form), S.literal(Url)])

@schema
type elicitationRequestParams = {
  @as("sessionId")
  sessionId: string,
  mode: elicitationMode,
  message: string,
  @as("requestedSchema")
  requestedSchema: option<JSON.t>,
  url: option<string>,
  @as("elicitationId")
  elicitationId: option<string>,
}

type elicitationAction =
  | @as("accept") Accept
  | @as("decline") Decline
  | @as("cancel") Cancel

let elicitationActionSchema = S.union([S.literal(Accept), S.literal(Decline), S.literal(Cancel)])

@schema
type elicitationResponseResult = {
  action: elicitationAction,
  content: option<JSON.t>,
}

@schema
type elicitationCompleteParams = {
  @as("elicitationId")
  elicitationId: string,
}
