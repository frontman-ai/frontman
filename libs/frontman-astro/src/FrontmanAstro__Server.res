// Request handlers for Frontman Astro endpoints

module Protocol = FrontmanFrontmanProtocol
module MCP = Protocol.FrontmanProtocol__MCP
module Relay = Protocol.FrontmanProtocol__Relay
module Core = FrontmanFrontmanCore
module CoreServer = Core.FrontmanCore__Server
module CoreSSE = Core.FrontmanCore__SSE
module ToolRegistry = FrontmanAstro__ToolRegistry
module Config = FrontmanAstro__Config
module WebStreams = FrontmanBindings.WebStreams
module DOMElementToComponentSource = FrontmanBindings.DOMElementToComponentSource

// GET /frontman/tools
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

// POST /frontman/tools/call - executes tool with SSE streaming
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

// Helper to convert absolute path to relative path (relative to sourceRoot)
// If the path starts with sourceRoot, strip it; otherwise return as-is
let toRelativePath = (absolutePath: string, sourceRoot: string): string => {
  // Ensure sourceRoot ends with / for proper stripping
  let normalizedRoot = if sourceRoot->String.endsWith("/") {
    sourceRoot
  } else {
    sourceRoot ++ "/"
  }

  if absolutePath->String.startsWith(normalizedRoot) {
    absolutePath->String.slice(~start=normalizedRoot->String.length, ~end=absolutePath->String.length)
  } else if absolutePath->String.startsWith(sourceRoot) {
    // Handle case where sourceRoot doesn't end with / but path matches exactly
    absolutePath->String.slice(~start=sourceRoot->String.length, ~end=absolutePath->String.length)
  } else {
    absolutePath
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

// POST /frontman/resolve-source-location - resolves source location via source maps
let handleResolveSourceLocation = async (
  ~config: Config.t,
  req: WebAPI.FetchAPI.request,
): WebAPI.FetchAPI.response => {
  let body = await req->WebAPI.Request.json

  let requestObj = body->JSON.Decode.object

  switch requestObj {
  | None =>
    WebAPI.Response.jsonR(
      ~data=JSON.Encode.object(Dict.fromArray([("error", JSON.Encode.string("Invalid request body"))])),
      ~init={status: 400},
    )
  | Some(obj) =>
    let componentName = obj->Dict.get("componentName")->Option.flatMap(JSON.Decode.string)
    let file = obj->Dict.get("file")->Option.flatMap(JSON.Decode.string)
    let line = obj->Dict.get("line")->Option.flatMap(JSON.Decode.float)
    let column = obj->Dict.get("column")->Option.flatMap(JSON.Decode.float)

    switch (componentName, file, line, column) {
    | (Some(componentName), Some(file), Some(line), Some(column)) =>
      try {
        let sourceLocation: DOMElementToComponentSource.sourceLocation = {
          componentName,
          file,
          line: line->Float.toInt,
          column: column->Float.toInt,
          componentProps: None,
          parent: None,
        }

        let resolved = await DOMElementToComponentSource.resolveSourceLocationInServer(sourceLocation)

        // Convert absolute path to relative path (relative to sourceRoot)
        // This ensures the agent can use the path directly with MCP tools
        let relativeFile = toRelativePath(resolved.file, config.sourceRoot)

        let responseJson = JSON.Encode.object(
          Dict.fromArray([
            ("componentName", JSON.Encode.string(resolved.componentName)),
            ("file", JSON.Encode.string(relativeFile)),
            ("line", JSON.Encode.float(resolved.line->Int.toFloat)),
            ("column", JSON.Encode.float(resolved.column->Int.toFloat)),
          ]),
        )

        let headers = WebAPI.HeadersInit.fromDict(Dict.fromArray([("Content-Type", "application/json")]))
        WebAPI.Response.jsonR(~data=responseJson, ~init={headers: headers})
      } catch {
      | exn =>
        let msg =
          exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
        WebAPI.Response.jsonR(
          ~data=JSON.Encode.object(
            Dict.fromArray([
              ("error", JSON.Encode.string("Failed to resolve source location")),
              ("details", JSON.Encode.string(msg)),
            ]),
          ),
          ~init={status: 500},
        )
      }
    | _ =>
      WebAPI.Response.jsonR(
        ~data=JSON.Encode.object(
          Dict.fromArray([
            ("error", JSON.Encode.string("Missing required fields: componentName, file, line, column")),
          ]),
        ),
        ~init={status: 400},
      )
    }
  }
}
