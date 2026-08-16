module Protocol = FrontmanAiFrontmanProtocol
module MCP = Protocol.FrontmanProtocol__MCP
module Relay = Protocol.FrontmanProtocol__Relay
module CoreServer = FrontmanCore__Server
module CoreSSE = FrontmanCore__SSE
module PathContext = FrontmanCore__PathContext
module SafePath = FrontmanCore__SafePath
module WebStreams = FrontmanBindings.WebStreams
module DOMElementToComponentSource = FrontmanBindings.DOMElementToComponentSource

@module("node:url")
external fileURLToPath: string => string = "fileURLToPath"
@module("node:fs/promises")
external realpath: string => promise<string> = "realpath"

let reactSourcePrefix = "about://React/"
let reactServerSourcePrefix = "about://React/Server/"

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

let canonicalPath = async (path: string): option<string> => {
  try {
    Some(await realpath(path))
  } catch {
  | _ => None
  }
}

let pathInside = (~sourceRoot: string, path: string): bool => {
  SafePath.resolve(~sourceRoot, ~inputPath=path)->Result.isOk
}

let validateRequestSourceFile = async (~sourceRoot: string, file: string): result<bool, string> => {
  switch file->String.startsWith(reactSourcePrefix) {
  | false => Ok(false)
  | true =>
    switch file->String.startsWith(reactServerSourcePrefix) {
    | false => Error("Unsupported React source URL")
    | true =>
      try {
        let fileUrl =
          file->String.slice(
            ~start=reactServerSourcePrefix->String.length,
            ~end=file->String.length,
          )
        let generatedFile = fileURLToPath(fileUrl)
        switch generatedFile->String.endsWith(".js") {
        | false => Error("Generated React source must be a JavaScript file")
        | true =>
          let generatedPath = await canonicalPath(generatedFile)
          let adjacentMapPath = await canonicalPath(generatedFile ++ ".map")
          let alternateMapPath = switch adjacentMapPath {
          | Some(_) => None
          | None =>
            await canonicalPath(
              generatedFile->String.slice(
                ~start=0,
                ~end=generatedFile->String.length - 3,
              ) ++ ".map",
            )
          }
          switch (generatedPath, adjacentMapPath->Option.orElse(alternateMapPath)) {
          | (Some(generatedPath), Some(mapPath))
            if pathInside(~sourceRoot, generatedPath) && pathInside(~sourceRoot, mapPath) =>
            Ok(true)
          | (None, _) => Error("Generated React source file does not exist")
          | (_, None) => Error("Generated React source map does not exist")
          | _ => Error("Generated React source or source map is outside project root")
          }
        }
      } catch {
      | exn =>
        Error(
          exn
          ->JsExn.fromException
          ->Option.flatMap(JsExn.message)
          ->Option.getOr("Malformed React source URL"),
        )
      }
    }
  }
}

let resolvedReactSource = async (~sourceRoot: string, file: string): option<string> => {
  switch file->String.startsWith(reactSourcePrefix) {
  | true => None
  | false =>
    switch await canonicalPath(file) {
    | Some(path) if pathInside(~sourceRoot, path) => Some(path)
    | _ => None
    }
  }
}

let unresolvedReactSourceResponse = (~details: string): WebAPI.FetchAPI.response => {
  let json = {
    error: "Could not resolve React source location",
    details: Some(details),
  }->S.decodeOrThrow(~from=errorResponseSchema, ~to=S.json)
  WebAPI.Response.jsonR(~data=json, ~init={status: 422})
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
  ~projectRoot: option<string>=?,
  ~sourceRoot: string,
  req: WebAPI.FetchAPI.request,
): WebAPI.FetchAPI.response => {
  let projectRoot = projectRoot->Option.getOr(sourceRoot)
  let canonicalProjectRoot = (await canonicalPath(projectRoot))->Option.getOr(projectRoot)
  let canonicalSourceRoot = (await canonicalPath(sourceRoot))->Option.getOr(sourceRoot)
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
    switch await validateRequestSourceFile(~sourceRoot=canonicalProjectRoot, request.file) {
    | Error(details) => unresolvedReactSourceResponse(~details)
    | Ok(reactServerSource) =>
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
          ~projectRoot=canonicalProjectRoot,
        )
        let responseFile = switch reactServerSource {
        | true => await resolvedReactSource(~sourceRoot=canonicalSourceRoot, resolved.file)
        | false => Some(resolved.file)
        }
        switch responseFile {
        | None =>
          unresolvedReactSourceResponse(
            ~details="Resolved source is virtual, missing, or outside source root",
          )
        | Some(responseFile) =>
          let relativeRoot = switch reactServerSource {
          | true => canonicalSourceRoot
          | false => sourceRoot
          }
          let relativeFile = PathContext.toRelativePath(
            ~sourceRoot=relativeRoot,
            ~absolutePath=responseFile,
          )
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
        }
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
}
