// MCP Server - browser-side tool registry and executor
// The browser acts as an MCP server, responding to tool calls from the agent

module Types = FrontmanClient__MCP__Types
module Tool = FrontmanClient__MCP__Tool
module ToolNames = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool.ToolNames
module Relay = FrontmanClient__Relay
module Log = FrontmanLogs.Logs.Make({
  let component = #MCPServer
})

// Resolved image data for write_file image_ref interception
type resolvedImage = {
  base64: string,
  mediaType: string,
}

type imageRefResolver = (string, ~taskId: string) => option<resolvedImage>

type t = {
  tools: array<module(Tool.Tool)>,
  relay: Relay.t,
  serverInfo: Types.info,
  // Resolver for image_ref URIs — set by the client layer which has access to the state store.
  // Receives (uri, ~taskId) so it resolves from the correct task, not the currently viewed one.
  resolveImageRef: ref<option<imageRefResolver>>,
  // Provider for tool result metadata (model, env API keys).
  // Set by the client layer which has access to the runtime config.
  // The server uses this to resume agent execution after a restart.
  getToolResultMeta: ref<option<unit => Types.callToolResultMeta>>,
}

let make = (
  ~relay: Relay.t,
  ~serverName="frontman-browser",
  ~serverVersion="1.0.0",
  ~resolveImageRef: option<imageRefResolver>=?,
): t => {
  tools: [],
  relay,
  serverInfo: {name: serverName, version: serverVersion},
  resolveImageRef: ref(resolveImageRef),
  getToolResultMeta: ref(None),
}

let setImageRefResolver = (server: t, resolver: imageRefResolver): unit => {
  server.resolveImageRef := Some(resolver)
}

let setToolResultMetaProvider = (server: t, provider: unit => Types.callToolResultMeta): unit => {
  server.getToolResultMeta := Some(provider)
}

let currentMeta = (server: t): Types.callToolResultMeta => {
  switch server.getToolResultMeta.contents {
  | Some(getMeta) => getMeta()
  | None => {model: None, envApiKey: Dict.make()}
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

module ToolTypes = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool

// Schema for executionMode serialization
let executionModeSchema = S.union([
  S.literal(ToolTypes.Synchronous),
  S.literal(ToolTypes.Interactive),
])

// Tool wire format schema - serialized directly to JSON
let toolWireSchema = S.object(s => {
  {
    "name": s.field("name", S.string),
    "description": s.field("description", S.string),
    "inputSchema": s.field("inputSchema", S.json),
    "visibleToAgent": s.field("visibleToAgent", S.bool),
    "executionMode": s.field("executionMode", executionModeSchema),
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
    "executionMode": T.executionMode,
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
  server: t,
  toolModule: module(Tool.Tool),
  ~arguments: option<Dict.t<JSON.t>>,
  ~taskId: string,
  ~toolCallId: string,
): Types.executeToolResult => {
  module T = unpack(toolModule)
  let meta = currentMeta(server)
  Log.debug(~ctx={"tool": T.name}, "Executing local tool")
  let inputJson = arguments->Option.getOr(Dict.make())->JSON.Encode.object
  try {
    let input = inputJson->S.parseOrThrow(T.inputSchema)
    Log.debug(~ctx={"tool": T.name}, "Calling execute")
    let result = await T.execute(input, ~taskId, ~toolCallId)
    Log.debug(~ctx={"tool": T.name}, "Execute returned")
    let callToolResult: Types.callToolResult = switch result {
    | Ok(output) =>
      let outputJson = output->S.reverseConvertToJsonOrThrow(T.outputSchema)
      {
        content: [{type_: Text, text: JSON.stringify(outputJson)}],
        isError: None,
        _meta: meta,
      }
    | Error(msg) => {
        content: [{type_: Text, text: msg}],
        isError: Some(true),
        _meta: meta,
      }
    }
    Completed(callToolResult)
  } catch {
  | S.Error(e) =>
    Log.error(~ctx={"tool": T.name}, "Schema error")
    Completed({
      content: [{type_: Text, text: `Invalid input: ${e.message}`}],
      isError: Some(true),
      _meta: meta,
    })
  }
}

// Resolve image_ref in write_file arguments before forwarding to relay.
// Replaces image_ref with content (base64) and encoding ("base64").
let resolveWriteFileImageRef = (
  server: t,
  arguments: option<Dict.t<JSON.t>>,
  ~taskId: string,
): result<option<Dict.t<JSON.t>>, string> => {
  switch arguments {
  | None => Ok(None)
  | Some(args) =>
    switch (args->Dict.get("image_ref"), server.resolveImageRef.contents) {
    | (None, _) => Ok(Some(args))
    | (Some(String("")), _) => Error("image_ref must be a non-empty string")
    | (Some(_), None) => Error("Cannot resolve image_ref: no resolver configured")
    | (Some(String(imageRef)), Some(resolve)) =>
      switch resolve(imageRef, ~taskId) {
      | None =>
        Error(
          `Image not found for URI: ${imageRef}. Available images may have expired or the URI is incorrect.`,
        )
      | Some({base64}) =>
        let newArgs = args->Dict.copy
        newArgs->Dict.delete("image_ref")
        newArgs->Dict.set("content", JSON.Encode.string(base64))
        newArgs->Dict.set("encoding", JSON.Encode.string("base64"))
        Ok(Some(newArgs))
      }
    | (Some(_), _) => Error("image_ref must be a string")
    }
  }
}

let toolError = (server: t, msg: string): Types.callToolResult => {
  content: [{type_: Text, text: msg}],
  isError: Some(true),
  _meta: server->currentMeta,
}

// Execute tool - tries local first, then relay
let executeTool = async (
  server: t,
  ~name: string,
  ~arguments: option<Dict.t<JSON.t>>=?,
  ~taskId: string,
  ~callId: string,
  ~onProgress: option<string => unit>=?,
): Types.executeToolResult => {
  // Try local tools first
  switch getToolByName(server, name) {
  | Some(toolModule) =>
    await executeLocalTool(server, toolModule, ~arguments, ~taskId, ~toolCallId=callId)
  | None =>
    switch server.relay->Relay.hasTool(name) {
    | false => Completed(toolError(server, `Tool not found: ${name}`))
    | true =>
      // Intercept write_file with image_ref to resolve from the correct task
      let resolvedArgs = switch name == ToolNames.writeFile {
      | true => resolveWriteFileImageRef(server, arguments, ~taskId)
      | false => Ok(arguments)
      }

      switch resolvedArgs {
      | Error(msg) => Completed(toolError(server, msg))
      | Ok(finalArgs) =>
        let result = await server.relay->Relay.executeTool(
          ~name,
          ~arguments=?finalArgs,
          ~onProgress?,
        )
        switch result {
        | Ok(toolResult) => Completed({...toolResult, _meta: server->currentMeta})
        | Error(msg) => Completed(toolError(server, msg))
        }
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
  executeTool: (server, ~name, ~arguments, ~taskId, ~callId, ~onProgress) =>
    executeTool(server, ~name, ~arguments?, ~taskId, ~callId, ~onProgress?),
}
