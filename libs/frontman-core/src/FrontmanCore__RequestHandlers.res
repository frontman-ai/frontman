// Shared HTTP request handlers for all framework adapters
//
// These handle the three core API endpoints:
// - GET /tools - list available tools
// - POST /tools/call - execute a tool with SSE streaming
// - POST /resolve-source-location - resolve source maps

module Protocol = FrontmanFrontmanProtocol
module MCP = Protocol.FrontmanProtocol__MCP
module Relay = Protocol.FrontmanProtocol__Relay
module CoreServer = FrontmanCore__Server
module CoreSSE = FrontmanCore__SSE
module PathContext = FrontmanCore__PathContext
module WebStreams = FrontmanBindings.WebStreams
module DOMElementToComponentSource = FrontmanBindings.DOMElementToComponentSource

type handlerConfig = {
  projectRoot: string,
  sourceRoot: string,
  serverName: string,
  serverVersion: string,
}

// Sury schemas for resolve-source-location endpoint
@schema
type resolveSourceLocationRequest = {
  componentName: string,
  file: string,
  line: int,
  column: int,
}

@schema
type resolveSourceLocationResponse = {
  componentName: string,
  file: string,
  line: int,
  column: int,
}

@schema
type errorResponse = {
  error: string,
  @s.matches(S.option(S.string))
  details: option<string>,
}

// GET /tools - returns JSON list of available tools
let handleGetTools = (
  ~registry: FrontmanCore__ToolRegistry.t,
  ~config: handlerConfig,
): WebAPI.FetchAPI.response => {
  let response = CoreServer.getToolsResponse(
    ~registry,
    ~serverName=config.serverName,
    ~serverVersion=config.serverVersion,
  )

  let json = response->S.reverseConvertToJsonOrThrow(Relay.toolsResponseSchema)
  let headers = WebAPI.HeadersInit.fromDict(Dict.fromArray([("Content-Type", "application/json")]))
  WebAPI.Response.jsonR(~data=json, ~init={headers: headers})
}

// POST /tools/call - executes tool with SSE streaming
let handleToolCall = async (
  ~registry: FrontmanCore__ToolRegistry.t,
  ~config: handlerConfig,
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
    let ctx: CoreServer.executionContext = {
      projectRoot: config.projectRoot,
      sourceRoot: config.sourceRoot,
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
        let _ =
          resultPromise
          ->Promise.then(result => {
            let mcpResult = CoreServer.resultToMCP(result)
            let eventData = switch mcpResult.isError {
            | Some(true) => CoreSSE.errorEvent(mcpResult)
            | _ => CoreSSE.resultEvent(mcpResult)
            }
            controller->WebStreams.enqueue(encoder->WebStreams.encode(eventData))
            controller->WebStreams.close
            Promise.resolve()
          })
          ->Promise.catch(error => {
            let msg =
              error
              ->JsExn.fromException
              ->Option.flatMap(JsExn.message)
              ->Option.getOr("Unknown error")
            let errorResult: MCP.callToolResult = {
              content: [{type_: "text", text: `Tool execution failed: ${msg}`}],
              isError: Some(true),
            }
            controller->WebStreams.enqueue(
              encoder->WebStreams.encode(CoreSSE.errorEvent(errorResult)),
            )
            controller->WebStreams.close
            Promise.resolve()
          })
      },
    })

    WebAPI.Response.fromReadableStream(stream, ~init={headers: CoreSSE.headers()})
  }
}

// POST /resolve-source-location - resolves source location via source maps
let handleResolveSourceLocation = async (
  ~sourceRoot: string,
  req: WebAPI.FetchAPI.request,
): WebAPI.FetchAPI.response => {
  let body = await req->WebAPI.Request.json

  let request = try {
    Ok(body->S.parseOrThrow(resolveSourceLocationRequestSchema))
  } catch {
  | S.Error(e) => Error(e.message)
  }

  switch request {
  | Error(msg) =>
    let json =
      {error: `Invalid request: ${msg}`, details: None}->S.reverseConvertToJsonOrThrow(
        errorResponseSchema,
      )
    WebAPI.Response.jsonR(~data=json, ~init={status: 400})

  | Ok(request) =>
    try {
      let sourceLocation: DOMElementToComponentSource.sourceLocation = {
        componentName: request.componentName,
        file: request.file,
        line: request.line,
        column: request.column,
        componentProps: None,
        parent: None,
      }

      let resolved = await DOMElementToComponentSource.resolveSourceLocationInServer(
        sourceLocation,
      )

      // Convert absolute path to relative path (relative to sourceRoot)
      // This ensures the agent can use the path directly with MCP tools
      let relativeFile = PathContext.toRelativePath(
        ~sourceRoot,
        ~absolutePath=resolved.file,
      )

      let responseJson: resolveSourceLocationResponse = {
        componentName: resolved.componentName,
        file: relativeFile,
        line: resolved.line,
        column: resolved.column,
      }

      let json = responseJson->S.reverseConvertToJsonOrThrow(resolveSourceLocationResponseSchema)
      let headers = WebAPI.HeadersInit.fromDict(
        Dict.fromArray([("Content-Type", "application/json")]),
      )
      WebAPI.Response.jsonR(~data=json, ~init={headers: headers})
    } catch {
    | exn =>
      let msg =
        exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
      let json =
        {error: "Failed to resolve source location", details: Some(msg)}->S.reverseConvertToJsonOrThrow(
          errorResponseSchema,
        )
      WebAPI.Response.jsonR(~data=json, ~init={status: 500})
    }
  }
}
