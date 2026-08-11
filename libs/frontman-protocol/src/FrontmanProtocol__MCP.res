let protocolVersion = "2025-11-25"

@schema
type capabilities = {
  tools: option<Dict.t<JSON.t>>,
  resources: option<Dict.t<JSON.t>>,
  prompts: option<Dict.t<JSON.t>>,
}

@schema
type info = {
  name: string,
  version: string,
}

@schema
type initializeParams = {
  protocolVersion: string,
  capabilities: capabilities,
  clientInfo: info,
}

@schema
type initializeResult = {
  protocolVersion: string,
  capabilities: capabilities,
  serverInfo: info,
}

@schema
type toolCallParams = {
  callId: string,
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
  let makeStructured: Dict.t<JSON.t> => t
  let makeImage: (~data: string, ~mimeType: string) => t
  let makeError: string => t
} = {
  @schema
  type t = {
    content: @s.matches(FrontmanProtocol__ContentBlock.arraySchema)
    array<FrontmanProtocol__ContentBlock.t>,
    structuredContent?: Dict.t<JSON.t>,
    isError?: bool,
    _meta?: Dict.t<JSON.t>,
  }

  let jsonSchema = S.object(s => {
    content: s.field("content", S.array(FrontmanProtocol__ContentBlock.schema)),
    structuredContent: ?s.field("structuredContent", S.option(S.dict(S.json))),
    isError: ?s.field("isError", S.option(S.bool)),
    _meta: ?s.field("_meta", S.option(S.dict(S.json))),
  })

  let makeText = text => {
    content: [TextContent({text, _meta: None, annotations: None})],
  }

  let makeStructured = json => {
    content: [
      TextContent({text: JSON.stringify(JSON.Encode.object(json)), _meta: None, annotations: None}),
    ],
    structuredContent: json,
  }

  let makeImage = (~data, ~mimeType) => {
    content: [ImageContent({data, mimeType, _meta: None, annotations: None})],
  }

  let makeError = text => {
    content: [TextContent({text, _meta: None, annotations: None})],
    isError: true,
  }
}

let callToolResultSchema = CallToolResult.schema

@schema
type toolsListResult = {tools: array<JSON.t>}

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
