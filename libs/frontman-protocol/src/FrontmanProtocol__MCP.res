let protocolVersion = "2026-07-28"

let ttlMsSchema = S.int->S.min(0)

@scope("Number") @val
external numberIsInteger: float => bool = "isInteger"

let ttlMsWireSchema =
  S.float
  ->S.refine(
    value => value >= 0. && numberIsInteger(value),
    ~error="Expected a nonnegative integer",
  )
  ->S.extendJSONSchema({minimum: 0., multipleOf: 1.})

let jsonObjectShapeSchema = S.object(s => s.flatten(S.dict(S.json))->JSON.Encode.object)
let extensionsSchema =
  S.dict(S.json)
  ->S.refine(extensions =>
    extensions
    ->Dict.valuesToArray
    ->Array.every(value => value->JSON.Decode.object->Option.isSome)
  , ~error="Expected extension settings to be objects")
  ->S.extendJSONSchema(S.dict(jsonObjectShapeSchema)->S.toJSONSchema)

@schema
type info = {
  name: string,
  version: string,
}

@schema
type extension = {version: @s.matches(S.literal(1)) int}

@schema
type frontmanExtensions = {
  @as("ai.frontman/execution-context") executionContext: extension,
  @as("ai.frontman/tool-metadata") toolMetadata: extension,
}

@schema
type requiredFrontmanExtensions = {
  @as("ai.frontman/execution-context") executionContext: extension,
}

@schema
type clientCapabilities = {
  extensions: option<@s.matches(extensionsSchema) Dict.t<JSON.t>>,
}

@schema
type executionContext = {
  taskId: @s.matches(S.string->S.min(1)) string,
  callId: @s.matches(S.string->S.min(1)) string,
}

@schema
type requestMeta = {
  @as("io.modelcontextprotocol/protocolVersion")
  protocolVersion: string,
  @as("io.modelcontextprotocol/clientCapabilities")
  clientCapabilities: clientCapabilities,
  @as("io.modelcontextprotocol/clientInfo")
  clientInfo: option<info>,
  @as("ai.frontman/execution-context")
  executionContext: option<executionContext>,
}

@schema
type discoverParams = {_meta: requestMeta}

@schema
type toolsCapability = {listChanged: bool}

@schema
type serverCapabilities = {
  tools: toolsCapability,
  extensions: frontmanExtensions,
}

@schema
type resultMeta = {
  @as("io.modelcontextprotocol/serverInfo") serverInfo: info,
}

@schema
type discoverResult = {
  resultType: @s.matches(S.literal("complete")) string,
  supportedVersions: array<@s.matches(S.literal("2026-07-28")) string>,
  capabilities: serverCapabilities,
  ttlMs: @s.matches(ttlMsSchema) int,
  cacheScope: @s.matches(S.literal("private")) string,
  _meta: resultMeta,
}

let toolsCapabilityWireSchema = S.object(s => {
  s.field("listChanged", S.option(S.bool))->ignore
  s.flatten(S.dict(S.json))->JSON.Encode.object
})

let serverCapabilitiesWireSchema = S.object(s => {
  s.field("tools", S.option(toolsCapabilityWireSchema))->ignore
  s.field("extensions", S.option(extensionsSchema))->ignore
  s.flatten(S.dict(S.json))->JSON.Encode.object
})

let resultMetaWireSchema = S.object(s => {
  s.field("io.modelcontextprotocol/serverInfo", S.option(infoSchema))->ignore
  s.flatten(S.dict(S.json))->JSON.Encode.object
})

let cacheScopeWireSchema = S.union([S.literal("public"), S.literal("private")])

let discoverResultWireSchema = S.object(s => {
  s.field("resultType", S.literal("complete"))->ignore
  s.field("supportedVersions", S.array(S.string))->ignore
  s.field("capabilities", serverCapabilitiesWireSchema)->ignore
  s.field("instructions", S.option(S.string))->ignore
  s.field("ttlMs", ttlMsWireSchema)->ignore
  s.field("cacheScope", cacheScopeWireSchema)->ignore
  s.field("_meta", S.option(resultMetaWireSchema))->ignore
  s.flatten(S.dict(S.json))->JSON.Encode.object
})

@schema
type toolsListParams = {_meta: requestMeta, cursor: option<string>}

@schema
type toolCallParams = {
  _meta: requestMeta,
  name: string,
  arguments: option<Dict.t<JSON.t>>,
}

type metadataError = UnsupportedProtocolVersion(string)

let validateRequestMeta = meta =>
  switch meta.protocolVersion == protocolVersion {
  | true => Ok()
  | false => Error(UnsupportedProtocolVersion(meta.protocolVersion))
  }

type toolCallValidationError =
  | ToolCallMetadata(metadataError)
  | MissingExecutionContextCapability
  | MissingExecutionContext
  | WrongTask

module AuthorizedToolCall: {
  type t
  let authorize: (toolCallParams, ~sessionId: string) => result<t, toolCallValidationError>
  let name: t => string
  let arguments: t => option<Dict.t<JSON.t>>
  let taskId: t => string
  let callId: t => string
} = {
  type t = {
    name: string,
    arguments: option<Dict.t<JSON.t>>,
    taskId: string,
    callId: string,
  }

  let hasExecutionContextCapability = (capabilities: clientCapabilities) =>
    switch capabilities.extensions->Option.flatMap(extensions =>
      extensions->Dict.get("ai.frontman/execution-context")
    ) {
    | Some(settings) =>
      try {
        settings->S.parseOrThrow(~to=extensionSchema)->ignore
        true
      } catch {
      | _ => false
      }
    | None => false
    }

  let authorize = ({_meta, name, arguments}, ~sessionId) =>
    switch validateRequestMeta(_meta) {
    | Error(error) => Error(ToolCallMetadata(error))
    | Ok() if !hasExecutionContextCapability(_meta.clientCapabilities) =>
      Error(MissingExecutionContextCapability)
    | Ok() =>
      switch _meta.executionContext {
      | None => Error(MissingExecutionContext)
      | Some({taskId}) if taskId != sessionId => Error(WrongTask)
      | Some({callId}) => Ok({name, arguments, taskId: sessionId, callId})
      }
    }

  let name = toolCall => toolCall.name
  let arguments = toolCall => toolCall.arguments
  let taskId = toolCall => toolCall.taskId
  let callId = toolCall => toolCall.callId
}

@schema
type unsupportedProtocolVersionData = {supported: array<string>, requested: string}

@schema
type requiredClientCapabilities = {extensions: requiredFrontmanExtensions}

@schema
type missingRequiredClientCapabilityData = {requiredCapabilities: requiredClientCapabilities}

let unsupportedProtocolVersionDataToJson = requested =>
  {requested, supported: [protocolVersion]}->S.decodeOrThrow(
    ~from=unsupportedProtocolVersionDataSchema,
    ~to=S.json->S.noValidation(true),
  )

let missingExecutionContextCapabilityDataToJson = () =>
  {
    requiredCapabilities: {extensions: {executionContext: {version: 1}}},
  }->S.decodeOrThrow(
    ~from=missingRequiredClientCapabilityDataSchema,
    ~to=S.json->S.noValidation(true),
  )

module CallToolResult: {
  type t
  let schema: S.t<t>
  let jsonSchema: S.t<t>
  let makeText: string => t
  let makeTextWithStructured: (string, Dict.t<JSON.t>) => t
  let makeStructured: Dict.t<JSON.t> => t
  let makeImage: (~data: string, ~mimeType: string) => t
  let makeError: string => t
} = {
  @schema
  type t = {
    resultType: @s.default("complete") @s.matches(S.literal("complete")) string,
    content: @s.matches(FrontmanProtocol__ContentBlock.arraySchema)
    array<FrontmanProtocol__ContentBlock.t>,
    structuredContent?: JSON.t,
    isError?: bool,
    _meta?: Dict.t<JSON.t>,
  }

  let jsonSchema = S.object(s => {
    resultType: s.field("resultType", S.literal("complete")),
    content: s.field("content", S.array(FrontmanProtocol__ContentBlock.schema)),
    structuredContent: ?s.field("structuredContent", S.option(S.json)),
    isError: ?s.field("isError", S.option(S.bool)),
    _meta: ?s.field("_meta", S.option(S.dict(S.json))),
  })

  let makeText = text => {
    resultType: "complete",
    content: [TextContent({text, _meta: None, annotations: None})],
  }

  let makeStructured = json => {
    resultType: "complete",
    content: [
      TextContent({text: JSON.stringify(JSON.Encode.object(json)), _meta: None, annotations: None}),
    ],
    structuredContent: JSON.Encode.object(json),
  }

  let makeTextWithStructured = (text, structuredContent) => {
    resultType: "complete",
    content: [TextContent({text, _meta: None, annotations: None})],
    structuredContent: JSON.Encode.object(structuredContent),
  }

  let makeImage = (~data, ~mimeType) => {
    resultType: "complete",
    content: [ImageContent({data, mimeType, _meta: None, annotations: None})],
  }

  let makeError = text => {
    resultType: "complete",
    content: [TextContent({text, _meta: None, annotations: None})],
    isError: true,
  }
}

let callToolResultSchema = CallToolResult.schema

let toolMetadataSchema = S.object(s => {
  s.field("visibleToAgent", S.option(S.bool))->ignore
  s.field(
    "executionMode",
    S.option(S.union([S.literal("Synchronous"), S.literal("Interactive")])),
  )->ignore
  s.field(
    "access",
    S.option(S.union([S.literal("read"), S.literal("write"), S.literal("read-write")])),
  )->ignore
  s.flatten(S.dict(S.json))->JSON.Encode.object
})

let toolMetaSchema = S.object(s => {
  s.field("ai.frontman/tool-metadata", S.option(toolMetadataSchema))->ignore
  s.flatten(S.dict(S.json))->JSON.Encode.object
})

let toolInputSchema = S.object(s => {
  s.field("type", S.literal("object"))->ignore
  s.flatten(S.dict(S.json))->JSON.Encode.object
})

let toolJsonSchema = S.object(s => {
  s.field("name", S.string->S.min(1))->ignore
  s.field("description", S.option(S.string))->ignore
  s.field("inputSchema", toolInputSchema)->ignore
  s.field("outputSchema", S.option(S.dict(S.json)))->ignore
  s.field("_meta", S.option(toolMetaSchema))->ignore
  s.flatten(S.dict(S.json))->JSON.Encode.object
})

@schema
type toolsListResult = {
  resultType: @s.matches(S.literal("complete")) string,
  tools: array<JSON.t>,
  ttlMs: @s.matches(ttlMsSchema) int,
  cacheScope: @s.matches(S.literal("private")) string,
  _meta: resultMeta,
}

let toolsListResultWireSchema = S.object(s => {
  s.field("resultType", S.literal("complete"))->ignore
  s.field("tools", S.array(toolJsonSchema))->ignore
  s.field("nextCursor", S.option(S.string))->ignore
  s.field("ttlMs", ttlMsWireSchema)->ignore
  s.field("cacheScope", cacheScopeWireSchema)->ignore
  s.field("_meta", S.option(resultMetaWireSchema))->ignore
  s.flatten(S.dict(S.json))->JSON.Encode.object
})

type executeToolResult =
  | Completed(CallToolResult.t)
  | Suspended
  | ProtocolError({code: int, message: string})

module ErrorCode = {
  let invalidRequest = -32600
  let invalidParams = -32602
  let serverError = -32603
  let methodNotFound = -32601
  let missingRequiredClientCapability = -32021
  let unsupportedProtocolVersion = -32022
}

type serverInterface<'server> = {
  server: 'server,
  buildDiscoverResult: 'server => discoverResult,
  buildToolsListResult: 'server => toolsListResult,
  executeTool: (
    'server,
    AuthorizedToolCall.t,
    ~onProgress: option<string => unit>,
  ) => promise<executeToolResult>,
}
