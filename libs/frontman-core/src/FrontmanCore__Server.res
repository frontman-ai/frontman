// Core server execution logic - framework agnostic

module Protocol = FrontmanAiFrontmanProtocol
module MCP = Protocol.FrontmanProtocol__MCP
module Relay = Protocol.FrontmanProtocol__Relay
module Tool = Protocol.FrontmanProtocol__Tool
module ToolRegistry = FrontmanCore__ToolRegistry

type executionContext = {
  projectRoot: string,
  sourceRoot: string,
  onProgress: option<string => unit>,
}

type executeResult =
  | Ok(MCP.callToolResult)
  | ToolNotFound(string)
  | InvalidInput(string)
  | ExecutionError(string)

// Execute a tool by name
let executeTool = async (
  ~registry: ToolRegistry.t,
  ~ctx: executionContext,
  ~name: string,
  ~arguments: option<Dict.t<JSON.t>>,
): executeResult => {
  switch registry->ToolRegistry.getToolByName(name) {
  | None => ToolNotFound(name)
  | Some(toolModule) =>
    module T = unpack(toolModule)

    let toolCtx: Tool.serverExecutionContext = {
      projectRoot: ctx.projectRoot,
      sourceRoot: ctx.sourceRoot,
    }

    let inputJson = arguments->Option.getOr(Dict.make())->JSON.Encode.object

    try {
      let input = inputJson->S.parseOrThrow(T.inputSchema)
      let result = await T.execute(toolCtx, input)

      switch result {
      | Result.Ok(output) =>
        let outputJson = output->S.reverseConvertToJsonOrThrow(T.outputSchema)
        Ok({
          content: [{type_: "text", text: JSON.stringify(outputJson)}],
          isError: None,
        })
      | Result.Error(msg) =>
        Ok({
          content: [{type_: "text", text: msg}],
          isError: Some(true),
        })
      }
    } catch {
    | S.Error(e) => InvalidInput(e.message)
    | exn =>
      let msg =
        exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
      ExecutionError(msg)
    }
  }
}

// Convert executeResult to MCP.callToolResult for SSE streaming
let resultToMCP = (result: executeResult): MCP.callToolResult => {
  switch result {
  | Ok(r) => r
  | ToolNotFound(name) => {
      content: [{type_: "text", text: `Tool not found: ${name}`}],
      isError: Some(true),
    }
  | InvalidInput(msg) => {
      content: [{type_: "text", text: `Invalid input: ${msg}`}],
      isError: Some(true),
    }
  | ExecutionError(msg) => {
      content: [{type_: "text", text: `Execution error: ${msg}`}],
      isError: Some(true),
    }
  }
}

// Get tools response for the /tools endpoint
let getToolsResponse = (
  ~registry: ToolRegistry.t,
  ~serverName: string,
  ~serverVersion: string,
): Relay.toolsResponse => {
  tools: registry->ToolRegistry.getToolDefinitions,
  serverInfo: {
    name: serverName,
    version: serverVersion,
  },
  protocolVersion: Relay.protocolVersion,
}
