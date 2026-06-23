// Core server execution logic - framework agnostic

module Protocol = FrontmanAiFrontmanProtocol
module MCP = Protocol.FrontmanProtocol__MCP
module Relay = Protocol.FrontmanProtocol__Relay
module Tool = Protocol.FrontmanProtocol__Tool
module ToolRegistry = FrontmanCore__ToolRegistry

type executionContext = {
  projectRoot: string,
  sourceRoot: string,
  @live
  onProgress: option<string => unit>,
}

type executeResult =
  | Ok(MCP.CallToolResult.t)
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

    let inputResult: result<T.input, string> = try {
      Ok(inputJson->S.parseOrThrow(~to=T.inputSchema))
    } catch {
    | exn =>
      Error(exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Invalid input"))
    }

    switch inputResult {
    | Error(msg) => InvalidInput(msg)
    | Ok(input) =>
      try {
        let result = await T.execute(toolCtx, input)
        Ok(result)
      } catch {
      | exn =>
        let msg =
          exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
        ExecutionError(msg)
      }
    }
  }
}

// Convert executeResult to MCP CallToolResult for SSE streaming
let resultToMCP = (result: executeResult): MCP.CallToolResult.t => {
  switch result {
  | Ok(r) => r
  | ToolNotFound(name) => MCP.CallToolResult.makeError(`Tool not found: ${name}`)
  | InvalidInput(msg) => MCP.CallToolResult.makeError(`Invalid input: ${msg}`)
  | ExecutionError(msg) => MCP.CallToolResult.makeError(`Execution error: ${msg}`)
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
