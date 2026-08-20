module Protocol = FrontmanAiFrontmanProtocol
module MCP = Protocol.FrontmanProtocol__MCP
module Tool = Protocol.FrontmanProtocol__Tool
module JsonSchema = FrontmanCore__MCP__JsonSchema
module CustomHeaders = FrontmanCore__MCP__CustomHeaders
module WebStreams = FrontmanBindings.WebStreams

type tool = module(Tool.ServerTool)

type t = {tools: array<tool>}

let toolLimit = 256
let definitionByteLimit = 65536
let aggregateDefinitionByteLimit = 1048576
let toolNamePattern = /^[A-Za-z0-9_.-]{1,128}$/

let make = (): t => {
  tools: [],
}

external jsonSchemaAsJson: JSONSchema.t => JSON.t = "%identity"

@schema
type mcpToolAnnotations = {readOnlyHint: bool}

let mcpAnnotations = (access: Tool.access): MCP.ToolAnnotations.t =>
  {
    readOnlyHint: switch access {
    | Tool.Read => true
    | Tool.Write | Tool.ReadWrite => false
    },
  }->S.decodeOrThrow(~from=mcpToolAnnotationsSchema, ~to=MCP.ToolAnnotations.schema)

let mcpMetadata = (name: string): option<MCP.Metadata.t> =>
  switch name == Tool.ToolNames.writeFile {
  | false => None
  | true =>
    Some(
      Dict.fromArray([
        (
          "ai.frontman/attachment-resolution",
          JSON.parseOrThrow(`{"version":1,"referenceArgument":"image_ref","contentArgument":"content","encodingArgument":"encoding","encodingValue":"base64","removeReference":true,"mediaTypeArgument":null}`),
        ),
      ]),
    )
  }

let serializeMCPTool = (m: tool): MCP.Tool.t => {
  module T = unpack(m)
  {
    name: T.name,
    title: None,
    description: Some(T.description),
    inputSchema: T.inputSchema
    ->S.toJSONSchema
    ->jsonSchemaAsJson
    ->S.parseOrThrow(~to=MCP.ToolSchema.inputSchema),
    outputSchema: T.outputJsonSchema->Option.map(schema =>
      schema->jsonSchemaAsJson->S.parseOrThrow(~to=MCP.ToolSchema.outputSchema)
    ),
    icons: None,
    annotations: Some(mcpAnnotations(T.access)),
    _meta: mcpMetadata(T.name),
  }
}

@get
external byteLength: Uint8Array.t => int = "byteLength"

let utf8Bytes = value => WebStreams.makeTextEncoder()->WebStreams.encode(value)->byteLength

let definitionByteLength = tool =>
  tool
  ->serializeMCPTool
  ->S.decodeOrThrow(~from=MCP.Tool.schema, ~to=S.json->S.noValidation(true))
  ->JSON.stringify
  ->utf8Bytes

let validate = (tools: array<tool>): unit => {
  switch tools->Array.length > toolLimit {
  | true => failwith("MCP tool count limit exceeded")
  | false => ()
  }
  let names = Dict.make()
  let aggregateBytes = ref(0)
  tools->Array.forEach(tool => {
    module T = unpack(tool)
    switch toolNamePattern->RegExp.test(T.name) && !(names->Dict.has(T.name)) {
    | true => names->Dict.set(T.name, true)
    | false => failwith("Invalid or duplicate MCP tool name")
    }
    let definitionBytes = tool->definitionByteLength
    switch definitionBytes > definitionByteLimit {
    | true => failwith("MCP tool definition byte limit exceeded")
    | false => aggregateBytes := aggregateBytes.contents + definitionBytes
    }
    let inputJsonSchema = T.inputSchema->S.toJSONSchema
    switch CustomHeaders.discover(inputJsonSchema) {
    | Ok(_) => ()
    | Error(_) => failwith("Invalid MCP tool JSON Schema")
    }
    let inputSchema = inputJsonSchema->jsonSchemaAsJson
    let schemas = switch T.outputJsonSchema {
    | Some(outputSchema) => [inputSchema, outputSchema->jsonSchemaAsJson]
    | None => [inputSchema]
    }
    schemas->Array.forEach(schema =>
      switch JsonSchema.compile(schema) {
      | JsonSchema.Valid(_) => ()
      | JsonSchema.Invalid => failwith("Invalid MCP tool JSON Schema")
      }
    )
  })
  switch aggregateBytes.contents > aggregateDefinitionByteLimit {
  | true => failwith("MCP aggregate tool definition byte limit exceeded")
  | false => ()
  }
}

let addTools = (registry: t, newTools: array<tool>): t => {
  let tools = Array.concat(registry.tools, newTools)
  validate(tools)
  {tools: tools}
}

let coreTools = (): t =>
  make()->addTools([
    module(FrontmanCore__Tool__ReadFile),
    module(FrontmanCore__Tool__WriteFile),
    module(FrontmanCore__Tool__ListFiles),
    module(FrontmanCore__Tool__FileExists),
    module(FrontmanCore__Tool__LoadAgentInstructions),
    module(FrontmanCore__Tool__Grep),
    module(FrontmanCore__Tool__SearchFiles),
    module(FrontmanCore__Tool__Lighthouse),
    module(FrontmanCore__Tool__EditFile),
    module(FrontmanCore__Tool__ListTree),
  ])

let replaceByName = (registry: t, replacement: tool): t => {
  module R = unpack(replacement)
  let tools = registry.tools->Array.map(m => {
    module T = unpack(m)
    switch T.name == R.name {
    | true => replacement
    | false => m
    }
  })
  validate(tools)
  {tools: tools}
}

let merge = (a: t, b: t): t => {
  let tools = Array.concat(a.tools, b.tools)
  validate(tools)
  {tools: tools}
}

let getToolByName = (registry: t, name: string): option<tool> => {
  registry.tools->Array.find(m => {
    module T = unpack(m)
    T.name == name
  })
}

let getMCPToolDefinitions = (registry: t): array<MCP.Tool.t> => {
  let tools =
    registry.tools
    ->Array.filter(m => {
      module T = unpack(m)
      T.visibleToAgent
    })
    ->Array.map(serializeMCPTool)
  tools->Array.sort((a, b) => String.compare(a.name, b.name))
  tools
}

let count = (registry: t): int => {
  registry.tools->Array.length
}
