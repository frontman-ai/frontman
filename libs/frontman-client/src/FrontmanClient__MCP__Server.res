// MCP Server - browser-side tool registry and executor
// The browser acts as an MCP server, responding to tool calls from the agent

module Types = FrontmanClient__MCP__Types
module Tool = FrontmanClient__MCP__Tool

type t = {
  tools: array<module(Tool.Tool)>,
  serverInfo: Types.info,
}

let make = (~serverName="frontman-browser", ~serverVersion="1.0.0"): t => {
  {
    tools: [],
    serverInfo: {name: serverName, version: serverVersion},
  }
}

let registerToolModule = (server: t, toolModule: module(Tool.Tool)): t => {
  {
    ...server,
    tools: Array.concat(server.tools, [toolModule]),
  }
}

// JSONSchema.t is JSON.t at runtime
external jsonSchemaAsJson: JSONSchema.t => JSON.t = "%identity"

// Tool wire format schema - serialized directly to JSON
let toolWireSchema = S.object(s => {
  {
    "name": s.field("name", S.string),
    "description": s.field("description", S.string),
    "inputSchema": s.field("inputSchema", S.json),
  }
})

// Serialize a tool module to JSON
let serializeTool = (m: module(Tool.Tool)): JSON.t => {
  module T = unpack(m)
  {
    "name": T.name,
    "description": T.description,
    "inputSchema": T.inputSchema->S.toJSONSchema->jsonSchemaAsJson,
  }->S.reverseConvertToJsonOrThrow(toolWireSchema)
}

// Get tools as JSON array for MCP tools/list response
let getToolsJson = (server: t): array<JSON.t> => {
  server.tools->Array.map(serializeTool)
}

let getToolByName = (server: t, name: string): option<module(Tool.Tool)> => {
  server.tools->Array.find(m => {
    module T = unpack(m)
    T.name == name
  })
}

// Execute tool with type erasure at JSON boundary
let executeTool = async (
  server: t,
  ~callId: string,
  ~name: string,
  ~arguments: option<Dict.t<JSON.t>>=?,
): Types.toolCallResult => {
  switch getToolByName(server, name) {
  | Some(toolModule) =>
    module T = unpack(toolModule)
    let inputJson = arguments->Option.getOr(Dict.make())->JSON.Encode.object
    try {
      let input = inputJson->S.parseOrThrow(T.inputSchema)
      let result = await T.execute(input)
      switch result {
      | Ok(output) =>
        let outputJson = output->S.reverseConvertToJsonOrThrow(T.outputSchema)
        {
          callId,
          result: Some({
            content: [{type_: "text", text: JSON.stringify(outputJson)}],
          }),
          error: None,
        }
      | Error(msg) => {
          callId,
          result: None,
          error: Some({
            code: Types.ErrorCode.serverError,
            message: msg,
          }),
        }
      }
    } catch {
    | S.Error(e) => {
        callId,
        result: None,
        error: Some({
          code: Types.ErrorCode.invalidParams,
          message: `Invalid input: ${e.message}`,
        }),
      }
    }
  | None => {
      callId,
      result: None,
      error: Some({
        code: Types.ErrorCode.invalidParams,
        message: `Tool not found: ${name}`,
      }),
    }
  }
}

// Build initialize result response
let buildInitializeResult = (server: t): Types.initializeResult => {
  {
    protocolVersion: Types.protocolVersion,
    capabilities: {
      tools: Some(Dict.make()),
      resources: None,
      prompts: None,
    },
    serverInfo: server.serverInfo,
  }
}

// Build tools/list result
let buildToolsListResult = (server: t): Types.toolsListResult => {
  {tools: getToolsJson(server)}
}
