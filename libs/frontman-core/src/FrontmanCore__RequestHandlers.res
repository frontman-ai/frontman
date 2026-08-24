module Protocol = FrontmanAiFrontmanProtocol
module MCP = Protocol.FrontmanProtocol__MCP
module Relay = Protocol.FrontmanProtocol__Relay
module CoreServer = FrontmanCore__Server
module CoreSSE = FrontmanCore__SSE
module PathContext = FrontmanCore__PathContext
module SafePath = FrontmanCore__SafePath
module WebStreams = FrontmanBindings.WebStreams

@module("node:fs/promises")
external realpath: string => promise<string> = "realpath"

let maxSourceInvocations = 10
let maxSourceRequestBytes = 100_000

type handlerConfig = {
  projectRoot: string,
  sourceRoot: string,
  serverName: string,
  serverVersion: string,
}

@schema
type sourceLocation = {
  @live
  componentName: option<string>,
  @live
  tagName: option<string>,
  file: string,
  line: int,
  @live
  column: int,
  componentProps: option<Dict.t<JSON.t>>,
}

@schema
type sourceContext = {
  definition: option<sourceLocation>,
  invocations: array<sourceLocation>,
}

type sourceResolutionError = {
  code: string,
  message: string,
}

type sourceResolutionResult = {
  success: bool,
  data: option<sourceContext>,
  error: option<sourceResolutionError>,
}

type resolveSourceContextOptions = {projectRoot: string}

type resolveSourceContext = (
  sourceContext,
  resolveSourceContextOptions,
) => promise<sourceResolutionResult>

@module("dom-element-to-component-source/server")
external resolveElementSourceContext: resolveSourceContext = "resolveElementSourceContext"

@schema
type errorResponse = {
  @live
  error: string,
  @live @s.matches(S.option(S.string))
  details: option<string>,
}

let canonicalPath = async (path: string): option<string> => {
  try {
    Some(await realpath(path))
  } catch {
  | _ => None
  }
}

let normalizeResolvedLocation = async (
  ~canonicalSourceRoot: string,
  location: sourceLocation,
): result<sourceLocation, string> => {
  switch location.file->String.startsWith("about://") {
  | true => Error("Resolved source remained virtual")
  | false =>
    switch SafePath.resolve(~sourceRoot=canonicalSourceRoot, ~inputPath=location.file) {
    | Error(_) => Error("Resolved source is outside source root")
    | Ok(safePath) =>
      switch await canonicalPath(SafePath.toString(safePath)) {
      | None => Error("Resolved source does not exist")
      | Some(path)
        if SafePath.resolve(~sourceRoot=canonicalSourceRoot, ~inputPath=path)->Result.isOk =>
        Ok({
          ...location,
          file: PathContext.toRelativePath(~sourceRoot=canonicalSourceRoot, ~absolutePath=path),
        })
      | Some(_) => Error("Resolved source is outside source root")
      }
    }
  }
}

let rec normalizeResolvedInvocations = async (
  ~canonicalSourceRoot: string,
  invocations: array<sourceLocation>,
  index: int,
): result<array<sourceLocation>, string> => {
  switch invocations->Array.get(index) {
  | None => Ok([])
  | Some(invocation) =>
    switch await normalizeResolvedLocation(~canonicalSourceRoot, invocation) {
    | Error(details) => Error(details)
    | Ok(invocation) =>
      switch await normalizeResolvedInvocations(~canonicalSourceRoot, invocations, index + 1) {
      | Error(details) => Error(details)
      | Ok(rest) => Ok(Array.concat([invocation], rest))
      }
    }
  }
}

let normalizeResolvedContext = async (~canonicalSourceRoot: string, context: sourceContext): result<
  sourceContext,
  string,
> => {
  let definitionResult = switch context.definition {
  | None => Ok(None)
  | Some(definition) =>
    switch await normalizeResolvedLocation(~canonicalSourceRoot, definition) {
    | Error(details) => Error(details)
    | Ok(definition) => Ok(Some(definition))
    }
  }
  switch definitionResult {
  | Error(details) => Error(details)
  | Ok(definition) =>
    switch await normalizeResolvedInvocations(~canonicalSourceRoot, context.invocations, 0) {
    | Error(details) => Error(details)
    | Ok(invocations) => Ok({definition, invocations})
    }
  }
}

let unresolvedReactSourceResponse = (~details: string): WebAPI.Response.t => {
  let json = {
    error: "Could not resolve React source context",
    details: Some(details),
  }->S.decodeOrThrow(~from=errorResponseSchema, ~to=S.json)
  WebAPI.Response.jsonR(~data=json, ~init={status: 422})
}

let safeSourceResolutionError = (error: sourceResolutionError): string =>
  switch error.code {
  | "INVALID_REACT_URL" => "INVALID_REACT_URL: React source URL is invalid"
  | "GENERATED_FILE_NOT_FOUND" => "GENERATED_FILE_NOT_FOUND: Generated source file was not found"
  | "SOURCE_MAP_NOT_FOUND" => "SOURCE_MAP_NOT_FOUND: Source map was not found"
  | "POSITION_NOT_FOUND" => "POSITION_NOT_FOUND: Source map position was not found"
  | _ => "RESOLUTION_FAILED: Source resolution failed"
  }

let handleGetTools = (
  ~registry: FrontmanCore__ToolRegistry.t,
  ~config: handlerConfig,
): WebAPI.Response.t => {
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
  req: WebAPI.Request.t,
): WebAPI.Response.t => {
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
  ~projectRoot: option<string>=?,
  ~sourceRoot: string,
  ~resolveSourceContext: resolveSourceContext=resolveElementSourceContext,
  req: WebAPI.Request.t,
): WebAPI.Response.t => {
  let projectRoot = projectRoot->Option.getOr(sourceRoot)
  let canonicalProjectRoot = (await canonicalPath(projectRoot))->Option.getOr(projectRoot)
  let canonicalSourceRoot = (await canonicalPath(sourceRoot))->Option.getOr(sourceRoot)

  let request = try {
    let body = await req->WebAPI.Request.text
    switch WebStreams.utf8ByteSize(body) > maxSourceRequestBytes {
    | true => Error(#tooLarge)
    | false => Ok(body->JSON.parseOrThrow->S.parseOrThrow(~to=sourceContextSchema))
    }
  } catch {
  | exn =>
    Error(
      #invalid(
        exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Invalid request"),
      ),
    )
  }

  switch request {
  | Error(#tooLarge) =>
    let json = {
      error: "Source context exceeds 100000 bytes",
      details: None,
    }->S.decodeOrThrow(~from=errorResponseSchema, ~to=S.json)
    WebAPI.Response.jsonR(~data=json, ~init={status: 413})
  | Error(#invalid(msg)) =>
    let json =
      {error: `Invalid request: ${msg}`, details: None}->S.decodeOrThrow(
        ~from=errorResponseSchema,
        ~to=S.json,
      )
    WebAPI.Response.jsonR(~data=json, ~init={status: 400})

  | Ok(request) =>
    switch request.invocations->Array.length > maxSourceInvocations {
    | true =>
      unresolvedReactSourceResponse(~details="Source context must contain at most 10 invocations")
    | false =>
      try {
        let packageResult = await resolveSourceContext(request, {projectRoot: canonicalProjectRoot})
        switch (packageResult.success, packageResult.data, packageResult.error) {
        | (false, _, Some(error)) =>
          Console.warn({
            "event": "source_resolution_failed",
            "code": error.code,
            "details": error.message,
          })
          unresolvedReactSourceResponse(~details=safeSourceResolutionError(error))
        | (false, _, None) => JsError.throwWithMessage("Source resolver failed without an error")
        | (true, None, _) => JsError.throwWithMessage("Source resolver succeeded without data")
        | (true, Some(resolved), _) =>
          switch await normalizeResolvedContext(~canonicalSourceRoot, resolved) {
          | Error(details) => unresolvedReactSourceResponse(~details)
          | Ok(responseContext) =>
            let json =
              responseContext->S.decodeOrThrow(
                ~from=sourceContextSchema,
                ~to=S.json->S.noValidation(true),
              )
            let headers = WebAPI.HeadersInit.fromDict(
              Dict.fromArray([("Content-Type", "application/json")]),
            )
            WebAPI.Response.jsonR(~data=json, ~init={headers: headers})
          }
        }
      } catch {
      | exn =>
        let msg =
          exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
        Console.error({"event": "source_resolution_exception", "details": msg})
        let json = {
          error: "Failed to resolve source context",
          details: Some("RESOLUTION_FAILED: Source resolution failed"),
        }->S.decodeOrThrow(~from=errorResponseSchema, ~to=S.json->S.noValidation(true))
        WebAPI.Response.jsonR(~data=json, ~init={status: 500})
      }
    }
  }
}
