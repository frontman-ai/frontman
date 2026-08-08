module Protocol = FrontmanAiFrontmanProtocol
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

@schema
type resolveSourceLocationRequest = {
  componentName: string,
  file: string,
  line: int,
  column: int,
}

@schema
type resolveSourceLocationResponse = {
  @live
  componentName: string,
  @live
  file: string,
  @live
  line: int,
  @live
  column: int,
}

@schema
type errorResponse = {
  @live
  error: string,
  @live @s.matches(S.option(S.string))
  details: option<string>,
}

let handleGetTools = (
  ~registry: FrontmanCore__ToolRegistry.t,
  ~config: handlerConfig,
): WebAPI.FetchAPI.response => {
  let response = CoreServer.getToolsResponse(
    ~registry,
    ~serverName=config.serverName,
    ~serverVersion=config.serverVersion,
  )

  let json =
    response->S.decodeOrThrow(~from=Relay.toolsResponseSchema, ~to=S.json->S.noValidation(true))
  let headers = WebAPI.HeadersInit.fromDict(Dict.fromArray([("Content-Type", "application/json")]))
  WebAPI.Response.jsonR(~data=json, ~init={headers: headers})
}

let handleToolCall = async (
  ~registry: FrontmanCore__ToolRegistry.t,
  ~config: handlerConfig,
  req: WebAPI.FetchAPI.request,
): WebAPI.FetchAPI.response => {
  let body = await req->WebAPI.Request.json

  let request = try {
    Ok(body->S.parseOrThrow(~to=Relay.toolCallRequestSchema))
  } catch {
  | exn =>
    Error(exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Invalid request"))
  }

  switch request {
  | Error(msg) =>
    let errorResult = MCP.CallToolResult.makeError(`Invalid request: ${msg}`)
    let json =
      errorResult->S.decodeOrThrow(~from=MCP.callToolResultSchema, ~to=S.json->S.noValidation(true))
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
            let eventData = switch result {
            | CoreServer.Ok(mcpResult) => CoreSSE.resultEvent(mcpResult)
            | CoreServer.ToolNotFound(_)
            | CoreServer.InvalidInput(_)
            | CoreServer.ExecutionError(_) =>
              CoreSSE.errorEvent(CoreServer.resultToMCP(result))
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
            let errorResult = MCP.CallToolResult.makeError(`Tool execution failed: ${msg}`)
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

let handleResolveSourceLocation = async (
  ~sourceRoot: string,
  req: WebAPI.FetchAPI.request,
): WebAPI.FetchAPI.response => {
  let body = await req->WebAPI.Request.json

  let request = try {
    Ok(body->S.parseOrThrow(~to=resolveSourceLocationRequestSchema))
  } catch {
  | exn =>
    Error(exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Invalid request"))
  }

  switch request {
  | Error(msg) =>
    let json =
      {error: `Invalid request: ${msg}`, details: None}->S.decodeOrThrow(
        ~from=errorResponseSchema,
        ~to=S.json,
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

      let resolved = await DOMElementToComponentSource.resolveSourceLocationInServer(sourceLocation)

      let relativeFile = PathContext.toRelativePath(~sourceRoot, ~absolutePath=resolved.file)

      let responseJson: resolveSourceLocationResponse = {
        componentName: resolved.componentName,
        file: relativeFile,
        line: resolved.line,
        column: resolved.column,
      }

      let json =
        responseJson->S.decodeOrThrow(~from=resolveSourceLocationResponseSchema, ~to=S.json)
      let headers = WebAPI.HeadersInit.fromDict(
        Dict.fromArray([("Content-Type", "application/json")]),
      )
      WebAPI.Response.jsonR(~data=json, ~init={headers: headers})
    } catch {
    | exn =>
      let msg =
        exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
      let json = {
        error: "Failed to resolve source location",
        details: Some(msg),
      }->S.decodeOrThrow(~from=errorResponseSchema, ~to=S.json->S.noValidation(true))
      WebAPI.Response.jsonR(~data=json, ~init={status: 500})
    }
  }
}
