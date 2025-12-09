// Request handlers for Frontman Astro endpoints

module Protocol = AskTheLlmFrontmanProtocol
module MCP = Protocol.FrontmanProtocol__MCP
module Relay = Protocol.FrontmanProtocol__Relay
module Core = AskTheLlmFrontmanCore
module CoreServer = Core.FrontmanCore__Server
module CoreSSE = Core.FrontmanCore__SSE
module ToolRegistry = FrontmanAstro__ToolRegistry
module Config = FrontmanAstro__Config
module WebStreams = AskTheLlmBindings.WebStreams

// GET /__frontman/tools
let handleGetTools = (~registry: ToolRegistry.t, ~config: Config.t): WebAPI.FetchAPI.response => {
  let response = CoreServer.getToolsResponse(
    ~registry,
    ~serverName=config.serverName,
    ~serverVersion=config.serverVersion,
  )

  let json = response->S.reverseConvertToJsonOrThrow(Relay.toolsResponseSchema)
  let headers = WebAPI.HeadersInit.fromDict(Dict.fromArray([("Content-Type", "application/json")]))
  WebAPI.Response.jsonR(~data=json, ~init={headers: headers})
}

// POST /__frontman/tools/call - executes tool with SSE streaming
let handleToolCall = async (
  ~registry: ToolRegistry.t,
  ~config: Config.t,
  req: WebAPI.FetchAPI.request,
): WebAPI.FetchAPI.response => {
  let body = await req->WebAPI.Request.json

  let request = try {
    Ok(body->S.parseOrThrow(Relay.toolCallRequestSchema))
  } catch {
  | S.Error(e) => Error(e.message)
  }

  switch request {
  | Error(msg) =>
    let errorResult: MCP.callToolResult = {
      content: [{type_: "text", text: `Invalid request: ${msg}`}],
      isError: Some(true),
    }
    let json = errorResult->S.reverseConvertToJsonOrThrow(MCP.callToolResultSchema)
    WebAPI.Response.jsonR(~data=json, ~init={status: 400})

  | Ok(request) =>
    // Execute tool using core
    let ctx: CoreServer.executionContext = {
      projectRoot: config.projectRoot,
      onProgress: None,
    }

    let resultPromise = CoreServer.executeTool(
      ~registry,
      ~ctx,
      ~name=request.name,
      ~arguments=request.arguments,
    )

    let encoder = WebStreams.makeTextEncoder()
    let stream = WebStreams.makeReadableStream({
      start: controller => {
        let _ = resultPromise->Promise.then(result => {
          let mcpResult = CoreServer.resultToMCP(result)
          let eventData = switch mcpResult.isError {
          | Some(true) => CoreSSE.errorEvent(mcpResult)
          | _ => CoreSSE.resultEvent(mcpResult)
          }
          controller->WebStreams.enqueue(encoder->WebStreams.encode(eventData))
          controller->WebStreams.close
          Promise.resolve()
        })
      },
    })

    WebAPI.Response.fromReadableStream(stream, ~init={headers: CoreSSE.headers()})
  }
}

// CORS headers for preflight requests
let corsHeaders = () => {
  WebAPI.HeadersInit.fromDict(
    Dict.fromArray([
      ("Access-Control-Allow-Origin", "*"),
      ("Access-Control-Allow-Methods", "GET, POST, OPTIONS"),
      ("Access-Control-Allow-Headers", "Content-Type"),
    ]),
  )
}

// Handle CORS preflight
let handleCORS = (): WebAPI.FetchAPI.response => {
  WebAPI.Response.fromNull(~init={status: 204, headers: corsHeaders()})
}
