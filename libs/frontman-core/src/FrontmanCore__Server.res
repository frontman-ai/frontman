module Protocol = FrontmanAiFrontmanProtocol
module MCP = Protocol.FrontmanProtocol__MCP
module Tool = Protocol.FrontmanProtocol__Tool
module ToolRegistry = FrontmanCore__ToolRegistry

type executionContext = {
  projectRoot: string,
  sourceRoot: string,
  signal: WebAPI.EventAPI.abortSignal,
  @live
  onProgress: option<string => unit>,
}

type executeResult =
  | Ok(MCP.CallToolResult.t)
  | InvalidInput(string)
  | ExecutionError(string)

@schema
type resultMetaFields = {
  @live @as("io.modelcontextprotocol/serverInfo") serverInfo: MCP.Implementation.t,
}

@schema
type toolCapability = {@live listChanged: bool}

@schema
type serverCapabilitiesFields = {@live tools: toolCapability}

let serverInfo = (~serverName, ~serverVersion): MCP.Implementation.t => {
  name: serverName,
  version: serverVersion,
  title: None,
  description: None,
  websiteUrl: None,
  icons: None,
}

let resultMeta = (~serverName, ~serverVersion): MCP.ResultMeta.t =>
  {serverInfo: serverInfo(~serverName, ~serverVersion)}->S.decodeOrThrow(
    ~from=resultMetaFieldsSchema,
    ~to=MCP.ResultMeta.schema,
  )

let discoverResult = (~serverName, ~serverVersion): MCP.DiscoverResult.t => {
  let capabilities =
    {tools: {listChanged: false}}->S.decodeOrThrow(
      ~from=serverCapabilitiesFieldsSchema,
      ~to=MCP.ServerCapabilities.schema,
    )
  {
    resultType: "complete",
    supportedVersions: [MCP.protocolVersion],
    capabilities,
    _meta: Some(resultMeta(~serverName, ~serverVersion)),
    instructions: None,
    ttlMs: 0.,
    cacheScope: MCP.CacheScope.Private,
  }
}

let listToolsResult = (~registry, ~serverName, ~serverVersion): MCP.ListToolsResult.t => {
  resultType: "complete",
  tools: registry->ToolRegistry.getMCPToolDefinitions,
  nextCursor: None,
  ttlMs: 0.,
  cacheScope: MCP.CacheScope.Private,
  _meta: Some(resultMeta(~serverName, ~serverVersion)),
}

let executeSelectedTool = async (
  ~tool: ToolRegistry.tool,
  ~ctx: executionContext,
  ~arguments: option<Dict.t<JSON.t>>,
): executeResult => {
  module T = unpack(tool)

  let toolCtx: Tool.serverExecutionContext = {
    projectRoot: ctx.projectRoot,
    sourceRoot: ctx.sourceRoot,
    signal: ctx.signal,
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
    ctx.signal->WebAPI.AbortSignal.throwIfAborted
    try {
      let result = await T.execute(toolCtx, input)
      ctx.signal->WebAPI.AbortSignal.throwIfAborted
      Ok(result)
    } catch {
    | exn if ctx.signal.aborted => throw(exn)
    | exn =>
      let msg =
        exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
      ExecutionError(msg)
    }
  }
}
