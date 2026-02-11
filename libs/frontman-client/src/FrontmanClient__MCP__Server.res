// MCP Server - browser-side tool registry and executor
// The browser acts as an MCP server, responding to tool calls from the agent

module Types = FrontmanClient__MCP__Types
module Tool = FrontmanClient__MCP__Tool
module Relay = FrontmanClient__Relay
module Log = FrontmanLogs.Logs.Make({
  let component = #MCPServer
})

type t = {
  tools: array<module(Tool.Tool)>,
  relay: Relay.t,
  serverInfo: Types.info,
}

let make = (~relay: Relay.t, ~serverName="frontman-browser", ~serverVersion="1.0.0"): t => {
  {
    tools: [],
    relay,
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
    "visibleToAgent": s.field("visibleToAgent", S.bool),
  }
})

// Serialize a tool module to JSON
let serializeTool = (m: module(Tool.Tool)): JSON.t => {
  module T = unpack(m)
  {
    "name": T.name,
    "description": T.description,
    "inputSchema": T.inputSchema->S.toJSONSchema->jsonSchemaAsJson,
    "visibleToAgent": T.visibleToAgent,
  }->S.reverseConvertToJsonOrThrow(toolWireSchema)
}

// Get tools as JSON array for MCP tools/list response
let getToolsJson = (server: t): array<JSON.t> => {
  let localTools = server.tools->Array.map(serializeTool)
  let relayTools = server.relay->Relay.getToolsJson
  Array.concat(localTools, relayTools)
}

let getToolByName = (server: t, name: string): option<module(Tool.Tool)> => {
  server.tools->Array.find(m => {
    module T = unpack(m)
    T.name == name
  })
}

// Execute a local tool module
let executeLocalTool = async (
  toolModule: module(Tool.Tool),
  ~arguments: option<Dict.t<JSON.t>>,
): Types.callToolResult => {
  module T = unpack(toolModule)
  Log.debug(~ctx={"tool": T.name}, "Executing local tool")
  let inputJson = arguments->Option.getOr(Dict.make())->JSON.Encode.object
  try {
    let input = inputJson->S.parseOrThrow(T.inputSchema)
    Log.debug(~ctx={"tool": T.name}, "Calling execute")
    let result = await T.execute(input)
    Log.debug(~ctx={"tool": T.name}, "Execute returned")
    switch result {
    | Ok(output) =>
      let outputJson = output->S.reverseConvertToJsonOrThrow(T.outputSchema)
      {
        content: [{type_: "text", text: JSON.stringify(outputJson)}],
        isError: None,
      }
    | Error(msg) => {
        content: [{type_: "text", text: msg}],
        isError: Some(true),
      }
    }
  } catch {
  | S.Error(e) =>
    Log.error(~ctx={"tool": T.name}, "Schema error")
    {
      content: [{type_: "text", text: `Invalid input: ${e.message}`}],
      isError: Some(true),
    }
  }
}

// Execute tool - tries local first, then relay
let executeTool = async (
  server: t,
  ~name: string,
  ~arguments: option<Dict.t<JSON.t>>=?,
  ~onProgress: option<string => unit>=?,
): Types.callToolResult => {
  // Try local tools first
  switch getToolByName(server, name) {
  | Some(toolModule) => await executeLocalTool(toolModule, ~arguments)
  | None =>
    // Try relay if it has this tool
    if server.relay->Relay.hasTool(name) {
      let result = await server.relay->Relay.executeTool(~name, ~arguments?, ~onProgress?)
      switch result {
      | Ok(toolResult) => toolResult
      | Error(msg) => {
          content: [{type_: "text", text: msg}],
          isError: Some(true),
        }
      }
    } else {
      {
        content: [{type_: "text", text: `Tool not found: ${name}`}],
        isError: Some(true),
      }
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

// Create a server interface for use with the generic MCP handler
let toInterface = (server: t): Types.serverInterface<t> => {
  server,
  buildInitializeResult,
  buildToolsListResult,
  executeTool: (server, ~name, ~arguments, ~onProgress) =>
    executeTool(server, ~name, ~arguments?, ~onProgress?),
}
