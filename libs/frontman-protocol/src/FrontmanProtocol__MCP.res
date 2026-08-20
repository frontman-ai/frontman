let protocolVersion = "2026-07-28"

@schema
type info = {
  name: string,
  version: string,
}

@schema
type extension = {version: @s.matches(S.literal(1)) int}

@schema
type extensions = {
  @as("ai.frontman/execution-context") executionContext: extension,
}

@schema
type clientCapabilities = {extensions: extensions}

@schema
type requestMeta = {
  @as("io.modelcontextprotocol/protocolVersion")
  protocolVersion: @s.matches(S.literal("2026-07-28")) string,
  @as("io.modelcontextprotocol/clientCapabilities") clientCapabilities: clientCapabilities,
  @as("io.modelcontextprotocol/clientInfo") clientInfo: info,
}

@schema
type discoverParams = {_meta: requestMeta}

@schema
type toolsCapability = {listChanged: bool}

@schema
type serverCapabilities = {
  tools: toolsCapability,
  extensions: extensions,
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
  ttlMs: @s.matches(S.int->S.min(0)) int,
  cacheScope: @s.matches(S.literal("private")) string,
  _meta: resultMeta,
}

@schema
type toolsListParams = {_meta: requestMeta}

@schema
type executionContext = {taskId: string, callId: string}

@schema
type toolCallMeta = {
  @as("io.modelcontextprotocol/protocolVersion")
  protocolVersion: @s.matches(S.literal("2026-07-28")) string,
  @as("io.modelcontextprotocol/clientCapabilities") clientCapabilities: clientCapabilities,
  @as("io.modelcontextprotocol/clientInfo") clientInfo: info,
  @as("ai.frontman/execution-context") executionContext: executionContext,
}

@schema
type toolCallParams = {
  _meta: toolCallMeta,
  name: string,
  arguments: option<Dict.t<JSON.t>>,
}

@schema
type toolError = {
  code: int,
  message: string,
}

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
    resultType: @s.matches(S.literal("complete")) string,
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

let toolJsonSchema = S.object(s => {
  s.field("name", S.string->S.min(1))->ignore
  s.field("description", S.string)->ignore
  s.field("inputSchema", S.dict(S.json))->ignore
  s.flatten(S.dict(S.json))->JSON.Encode.object
})

@schema
type toolsListResult = {
  resultType: @s.matches(S.literal("complete")) string,
  tools: array<JSON.t>,
  ttlMs: @s.matches(S.int->S.min(0)) int,
  cacheScope: @s.matches(S.literal("private")) string,
  _meta: resultMeta,
}

let toolsListResultWireSchema: S.t<toolsListResult> = S.object(s => {
  resultType: s.field("resultType", S.literal("complete")),
  tools: s.field("tools", S.array(toolJsonSchema)),
  ttlMs: s.field("ttlMs", S.int->S.min(0)),
  cacheScope: s.field("cacheScope", S.literal("private")),
  _meta: s.field("_meta", resultMetaSchema),
})

type executeToolResult =
  | Completed(CallToolResult.t)
  | Suspended

module ErrorCode = {
  let invalidParams = -32602
  let serverError = -32000
  let methodNotFound = -32601
}

type serverInterface<'server> = {
  server: 'server,
  buildDiscoverResult: 'server => discoverResult,
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

module type Server = {
  type t
  let buildDiscoverResult: t => discoverResult
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
