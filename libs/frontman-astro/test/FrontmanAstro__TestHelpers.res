module ToolRegistry = FrontmanAiFrontmanCore.FrontmanCore__ToolRegistry
module Server = FrontmanAiFrontmanCore.FrontmanCore__Server
module MCP = FrontmanAiFrontmanProtocol.FrontmanProtocol__MCP

let executionContext: Server.executionContext = {
  projectRoot: "/tmp/project",
  sourceRoot: "/tmp/project",
  signal: WebAPI.AbortController.make().signal,
  onProgress: None,
}

let callTool = async (registry: ToolRegistry.t, ~name: string, ~arguments: JSON.t): string => {
  let tool = registry->ToolRegistry.getToolByName(name)->Option.getOrThrow
  let arguments = arguments->JSON.Decode.object->Option.getOrThrow
  switch await Server.executeSelectedTool(
    ~tool,
    ~ctx=executionContext,
    ~arguments=Some(arguments),
  ) {
  | Server.Ok(result) =>
    result
    ->S.decodeOrThrow(~from=MCP.CallToolResult.schema, ~to=S.json->S.noValidation(true))
    ->JSON.stringify
  | Server.InvalidInput(message) => failwith(`Invalid tool input: ${message}`)
  | Server.ExecutionError(message) => failwith(`Tool execution failed: ${message}`)
  }
}

let serializeModernTools = (registry: ToolRegistry.t): string =>
  registry
  ->ToolRegistry.getMCPToolDefinitions
  ->Array.map(tool => tool->S.decodeOrThrow(~from=MCP.Tool.schema, ~to=S.json))
  ->JSON.Encode.array
  ->JSON.stringify
