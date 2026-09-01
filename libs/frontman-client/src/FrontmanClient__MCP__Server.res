module Types = FrontmanClient__MCP__Types
module Tool = FrontmanClient__MCP__Tool
module MCPClient = FrontmanClient__MCP__Client
module Log = FrontmanLogs.Logs.Make({
  let component = #MCPServer
})

type resolvedImage = {
  base64: string,
  mediaType: string,
}

type imageRefResolver = (string, ~taskId: string) => option<resolvedImage>

type authorizeTool = (
  ~name: string,
  ~arguments: option<Dict.t<JSON.t>>,
  ~readOnly: bool,
  ~readOnlyTools: array<string>,
) => promise<bool>

type invocationWindow = {startedAtMs: float, count: int}

@schema
type attachmentResolution = {
  version: int,
  referenceArgument: string,
  contentArgument: string,
  encodingArgument: string,
  encodingValue: string,
  removeReference: bool,
  mediaTypeArgument: option<string>,
}

let attachmentResolutionMetadata = "ai.frontman/attachment-resolution"

type t = {
  tools: array<module(Tool.Tool)>,
  frameworkClient: MCPClient.t,
  serverInfo: Types.Implementation.t,
  resolveImageRef: ref<option<imageRefResolver>>,
  authorizeTool: authorizeTool,
  invocationWindow: ref<option<invocationWindow>>,
}

let invocationLimit = 256
let invocationWindowMs = 60000.

@@live
let make = (
  ~frameworkClient: MCPClient.t,
  ~serverName="frontman-browser",
  ~serverVersion="1.0.0",
  ~resolveImageRef: option<imageRefResolver>=?,
  ~authorizeTool: authorizeTool=async (
    ~name as _,
    ~arguments as _,
    ~readOnly as _,
    ~readOnlyTools as _,
  ) => true,
): t => {
  tools: [],
  frameworkClient,
  serverInfo: {
    name: serverName,
    version: serverVersion,
    title: None,
    description: None,
    websiteUrl: None,
    icons: None,
  },
  resolveImageRef: ref(resolveImageRef),
  authorizeTool,
  invocationWindow: ref(None),
}

let setImageRefResolver = (server: t, resolver: imageRefResolver): unit => {
  server.resolveImageRef := Some(resolver)
}

let registerToolModule = (server: t, toolModule: module(Tool.Tool)): t => {
  {
    ...server,
    tools: Array.concat(server.tools, [toolModule]),
  }
}

external jsonSchemaAsJson: JSONSchema.t => JSON.t = "%identity"

@schema
type serializedToolAnnotations = {readOnlyHint: bool}

let serializeTool = (m: module(Tool.Tool)): JSON.t => {
  module T = unpack(m)
  let annotations = {
    readOnlyHint: switch T.access {
    | FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool.Read => true
    | Write | ReadWrite => false
    },
  }->S.decodeOrThrow(~from=serializedToolAnnotationsSchema, ~to=Types.ToolAnnotations.schema)
  let definition = dict{
    "name": JSON.Encode.string(T.name),
    "description": JSON.Encode.string(T.description),
    "inputSchema": T.inputSchema->S.toJSONSchema->jsonSchemaAsJson,
    "annotations": Types.ToolAnnotations.toJson(annotations),
  }
  T.outputJsonSchema->Option.forEach(schema =>
    definition->Dict.set("outputSchema", jsonSchemaAsJson(schema))
  )
  JSON.Encode.object(definition)
}

let getToolsJson = (server: t): array<JSON.t> => {
  let visibleLocalTools = server.tools->Array.filter(m => {
    module T = unpack(m)
    T.visibleToAgent
  })
  let localTools = visibleLocalTools->Array.map(serializeTool)
  let localNames = visibleLocalTools->Array.map(m => {
    module T = unpack(m)
    T.name
  })
  let frameworkTools =
    server.frameworkClient
    ->MCPClient.getToolsJson
    ->Array.filter(json =>
      try {
        let tool = json->S.parseOrThrow(~to=Types.Tool.schema)
        !(localNames->Array.includes(tool.name))
      } catch {
      | S.Exn(_) => false
      | exn => throw(exn)
      }
    )
  let tools = Array.concat(localTools, frameworkTools)
  tools->Array.sort((left, right) => {
    let leftTool = left->S.parseOrThrow(~to=Types.Tool.schema)
    let rightTool = right->S.parseOrThrow(~to=Types.Tool.schema)
    String.compare(leftTool.name, rightTool.name)
  })
  tools
}

let getToolByName = (server: t, name: string): option<module(Tool.Tool)> => {
  server.tools->Array.find(m => {
    module T = unpack(m)
    T.name == name
  })
}

let definitionIsReadOnly = (definition: Types.Tool.t): bool =>
  definition.annotations->Option.flatMap(annotations =>
    annotations
    ->Types.ToolAnnotations.toJson
    ->(json => S.parseOrThrow(json, ~to=Types.ToolAnnotations.knownFieldsSchema).readOnlyHint)
  ) == Some(true)

let readOnlyToolNames = server =>
  getToolsJson(server)->Array.filterMap(json => {
    let definition = json->S.parseOrThrow(~to=Types.Tool.schema)
    definitionIsReadOnly(definition) ? Some(definition.name) : None
  })

let toolIsReadOnly = (server, ~name, ~localTool: option<module(Tool.Tool)>) =>
  switch localTool {
  | Some(toolModule) =>
    module T = unpack(toolModule)
    T.access == FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool.Read
  | None =>
    server.frameworkClient
    ->MCPClient.getToolsJson
    ->Array.findMap(json => {
      let definition = json->S.parseOrThrow(~to=Types.Tool.schema)
      definition.name == name ? Some(definitionIsReadOnly(definition)) : None
    })
    ->Option.getOr(false)
  }

let executeLocalTool = async (
  toolModule: module(Tool.Tool),
  ~arguments: option<Dict.t<JSON.t>>,
  ~taskId: string,
  ~toolCallId: string,
  ~signal: WebAPI.EventTypes.abortSignal,
): Types.CallToolResult.t => {
  module T = unpack(toolModule)
  Log.debug(~ctx={"tool": T.name}, "Executing local tool")
  let inputJson = arguments->Option.getOr(Dict.make())->JSON.Encode.object
  let inputResult: result<T.input, string> = try {
    Ok(inputJson->S.parseOrThrow(~to=T.inputSchema))
  } catch {
  | exn =>
    Error(exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Invalid input"))
  }

  switch inputResult {
  | Error(msg) =>
    Log.error(
      ~ctx={
        "tool": T.name,
        "taskId": taskId,
        "toolCallId": toolCallId,
      },
      "Tool input schema validation failed",
    )
    Types.CallToolResult.makeError(`Invalid input: ${msg}`)
  | Ok(input) =>
    Log.debug(~ctx={"tool": T.name}, "Calling execute")
    let result = await T.execute(input, ~taskId, ~toolCallId, ~signal)
    Log.debug(~ctx={"tool": T.name}, "Execute returned")
    result
  }
}

let resolveToolImageRef = (
  server: t,
  arguments: option<Dict.t<JSON.t>>,
  ~taskId: string,
  resolution: attachmentResolution,
): result<option<Dict.t<JSON.t>>, string> => {
  switch arguments {
  | None => Ok(None)
  | Some(args) =>
    switch (args->Dict.get(resolution.referenceArgument), server.resolveImageRef.contents) {
    | (None, _) => Ok(Some(args))
    | (Some(String("")), _) => Error("image_ref must be a non-empty string")
    | (Some(_), None) => Error("Cannot resolve image_ref: no resolver configured")
    | (Some(String(imageRef)), Some(resolve)) =>
      switch resolve(imageRef, ~taskId) {
      | None =>
        Error(
          `Image not found for URI: ${imageRef}. Available images may have expired or the URI is incorrect.`,
        )
      | Some({base64, mediaType}) =>
        let newArgs = args->Dict.copy
        switch resolution.removeReference {
        | true => newArgs->Dict.delete(resolution.referenceArgument)
        | false => ()
        }
        newArgs->Dict.set(resolution.contentArgument, JSON.Encode.string(base64))
        newArgs->Dict.set(resolution.encodingArgument, JSON.Encode.string(resolution.encodingValue))
        switch resolution.mediaTypeArgument {
        | Some(mediaTypeArgument) =>
          switch newArgs->Dict.get(mediaTypeArgument) {
          | None => newArgs->Dict.set(mediaTypeArgument, JSON.Encode.string(mediaType))
          | Some(_) => ()
          }
        | None => ()
        }
        Ok(Some(newArgs))
      }
    | (Some(_), _) => Error("image_ref must be a string")
    }
  }
}

let attachmentResolution = (server: t, name): result<option<attachmentResolution>, string> => {
  switch server.frameworkClient
  ->MCPClient.toolMetadata(name)
  ->Option.flatMap(metadata => metadata->Dict.get(attachmentResolutionMetadata)) {
  | None => Ok(None)
  | Some(value) =>
    try {
      let resolution = value->S.parseOrThrow(~to=attachmentResolutionSchema)
      switch resolution.version == 1 {
      | true => Ok(Some(resolution))
      | false => Error("Unsupported attachment-resolution metadata version")
      }
    } catch {
    | S.Exn(_) => Error("Invalid attachment-resolution metadata")
    | exn => throw(exn)
    }
  }
}

let toolError = (msg: string): Types.CallToolResult.t => Types.CallToolResult.makeError(msg)

let executeToolWithoutPolicy = async (
  server: t,
  ~name: string,
  ~arguments: option<Dict.t<JSON.t>>=?,
  ~taskId: string,
  ~toolCallId: string,
  ~onProgress: option<string => unit>=?,
  ~signal: WebAPI.EventTypes.abortSignal,
): Types.CallToolResult.t => {
  let localTool = getToolByName(server, name)
  let authorized = await server.authorizeTool(
    ~name,
    ~arguments,
    ~readOnly=toolIsReadOnly(server, ~name, ~localTool),
    ~readOnlyTools=readOnlyToolNames(server),
  )
  switch authorized {
  | false => toolError("Tool invocation denied by user")
  | true =>
    switch localTool {
    | Some(toolModule) =>
      await executeLocalTool(toolModule, ~arguments, ~taskId, ~toolCallId, ~signal)
    | None =>
      switch server.frameworkClient->MCPClient.hasTool(name) {
      | false => toolError(`Tool not found: ${name}`)
      | true =>
        let resolvedArgs = switch attachmentResolution(server, name) {
        | Error(message) => Error(message)
        | Ok(None) => Ok(arguments)
        | Ok(Some(resolution)) => resolveToolImageRef(server, arguments, ~taskId, resolution)
        }

        switch resolvedArgs {
        | Error(msg) => toolError(msg)
        | Ok(finalArgs) =>
          let result = await server.frameworkClient->MCPClient.executeTool(
            ~name,
            ~arguments=?finalArgs,
            ~onProgress?,
            ~signal,
          )
          switch result {
          | Ok(toolResult) => toolResult
          | Error(_) => JsError.throwWithMessage("Framework tool execution failed")
          }
        }
      }
    }
  }
}

let resultMeta = (server: t): Types.ResultMeta.t =>
  Dict.fromArray([
    (
      "io.modelcontextprotocol/serverInfo",
      server.serverInfo->S.decodeOrThrow(~from=Types.Implementation.schema, ~to=S.json),
    ),
  ])

let withServerInfo = (server: t, result: Types.CallToolResult.t): Types.CallToolResult.t => {
  let fields =
    result
    ->S.decodeOrThrow(~from=Types.CallToolResult.schema, ~to=S.json)
    ->S.parseOrThrow(~to=S.dict(S.json))
  let metadata =
    fields
    ->Dict.get("_meta")
    ->Option.mapOr(Dict.make(), metadata => metadata->S.parseOrThrow(~to=S.dict(S.json)))
  metadata->Dict.set(
    "io.modelcontextprotocol/serverInfo",
    server.serverInfo->S.decodeOrThrow(~from=Types.Implementation.schema, ~to=S.json),
  )
  fields->Dict.set("_meta", JSON.Encode.object(metadata))
  JSON.Encode.object(fields)->S.parseOrThrow(~to=Types.CallToolResult.schema)
}

let consumeInvocation = (server: t): bool => {
  let nowMs = Date.now()
  switch server.invocationWindow.contents {
  | Some(window) if nowMs < window.startedAtMs +. invocationWindowMs =>
    switch window.count >= invocationLimit {
    | true => false
    | false =>
      server.invocationWindow := Some({...window, count: window.count + 1})
      true
    }
  | Some(_) | None =>
    server.invocationWindow := Some({startedAtMs: nowMs, count: 1})
    true
  }
}

let executeTool = async (
  server: t,
  ~name: string,
  ~arguments: option<Dict.t<JSON.t>>=?,
  ~taskId: string,
  ~toolCallId: string,
  ~onProgress: option<string => unit>=?,
  ~signal: WebAPI.EventTypes.abortSignal,
): Types.CallToolResult.t => {
  let result = switch consumeInvocation(server) {
  | false => toolError("Tool invocation rate limit exceeded")
  | true =>
    await executeToolWithoutPolicy(
      server,
      ~name,
      ~arguments?,
      ~taskId,
      ~toolCallId,
      ~onProgress?,
      ~signal,
    )
  }
  withServerInfo(server, result)
}

let buildDiscoverResult = (server: t): Types.DiscoverResult.t => {
  {
    resultType: "complete",
    supportedVersions: [Types.protocolVersion],
    capabilities: Types.ExecutionContextExtension.serverCapabilities(),
    _meta: Some(resultMeta(server)),
    instructions: None,
    ttlMs: 0.,
    cacheScope: Types.CacheScope.Private,
  }
}

let buildToolsListResult = (server: t): Types.ListToolsResult.t => {
  {
    resultType: "complete",
    tools: getToolsJson(server)->Array.map(json => json->S.parseOrThrow(~to=Types.Tool.schema)),
    nextCursor: None,
    ttlMs: 0.,
    cacheScope: Types.CacheScope.Private,
    _meta: Some(resultMeta(server)),
  }
}

let toInterface = (server: t): Types.serverInterface<t> => {
  server,
  buildDiscoverResult,
  buildToolsListResult,
  executeTool: (server, ~name, ~arguments, ~taskId, ~toolCallId, ~onProgress, ~signal) =>
    executeTool(server, ~name, ~arguments?, ~taskId, ~toolCallId, ~onProgress?, ~signal),
}
