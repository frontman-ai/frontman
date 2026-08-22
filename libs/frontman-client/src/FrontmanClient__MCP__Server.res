module Types = FrontmanClient__MCP__Types
module Tool = FrontmanClient__MCP__Tool
module ToolNames = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool.ToolNames
module Relay = FrontmanClient__Relay
module Log = FrontmanLogs.Logs.Make({
  let component = #MCPServer
})

type resolvedImage = {
  base64: string,
  mediaType: string,
}

type imageRefResolver = (string, ~taskId: string) => option<resolvedImage>

type t = {
  tools: array<module(Tool.Tool)>,
  relay: Relay.t,
  serverInfo: Types.info,
  resolveImageRef: ref<option<imageRefResolver>>,
}

@@live
let make = (
  ~relay: Relay.t,
  ~serverName="frontman-browser",
  ~serverVersion="1.0.0",
  ~resolveImageRef: option<imageRefResolver>=?,
): t => {
  tools: [],
  relay,
  serverInfo: {name: serverName, version: serverVersion},
  resolveImageRef: ref(resolveImageRef),
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

module ToolTypes = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool

let executionModeSchema = S.union([
  S.literal(ToolTypes.Synchronous),
  S.literal(ToolTypes.Interactive),
])

let serializeTool = (m: module(Tool.Tool)): JSON.t => {
  module T = unpack(m)
  let definition = dict{
    "name": JSON.Encode.string(T.name),
    "description": JSON.Encode.string(T.description),
    "access": T.access->S.decodeOrThrow(~from=ToolTypes.accessSchema, ~to=S.json),
    "inputSchema": T.inputSchema->S.toJSONSchema->jsonSchemaAsJson,
    "visibleToAgent": JSON.Encode.bool(T.visibleToAgent),
    "executionMode": T.executionMode->S.decodeOrThrow(~from=executionModeSchema, ~to=S.json),
  }
  T.outputJsonSchema->Option.forEach(schema =>
    definition->Dict.set("outputSchema", jsonSchemaAsJson(schema))
  )
  JSON.Encode.object(definition)
}

let getToolsJson = (server: t): array<JSON.t> => {
  let localTools = server.tools->Array.map(serializeTool)
  let relayTools = server.relay->Relay.getToolsJson
  Array.concat(localTools, relayTools)
}

let getToolByName = (server: t, name: string): option<module(Tool.Tool)> => {
  server.tools->Array.find(m => {
    module T = unpack(m)
    T.name == name
  })
}

let executeLocalTool = async (
  toolModule: module(Tool.Tool),
  ~arguments: option<Dict.t<JSON.t>>,
  ~taskId: string,
  ~toolCallId: string,
): Types.executeToolResult => {
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
    Completed(Types.CallToolResult.makeError(`Invalid input: ${msg}`))
  | Ok(input) =>
    Log.debug(~ctx={"tool": T.name}, "Calling execute")
    let result = await T.execute(input, ~taskId, ~toolCallId)
    Log.debug(~ctx={"tool": T.name}, "Execute returned")
    Completed(result)
  }
}

let resolveToolImageRef = (
  server: t,
  arguments: option<Dict.t<JSON.t>>,
  ~taskId: string,
  ~removeImageRef: bool,
  ~includeMimeType: bool,
): result<option<Dict.t<JSON.t>>, string> => {
  switch arguments {
  | None => Ok(None)
  | Some(args) =>
    switch (args->Dict.get("image_ref"), server.resolveImageRef.contents) {
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
        switch removeImageRef {
        | true => newArgs->Dict.delete("image_ref")
        | false => ()
        }
        newArgs->Dict.set("content", JSON.Encode.string(base64))
        newArgs->Dict.set("encoding", JSON.Encode.string("base64"))
        switch includeMimeType {
        | true =>
          if newArgs->Dict.get("mime_type")->Option.isNone {
            newArgs->Dict.set("mime_type", JSON.Encode.string(mediaType))
          }
        | false => ()
        }
        Ok(Some(newArgs))
      }
    | (Some(_), _) => Error("image_ref must be a string")
    }
  }
}

let toolError = (msg: string): Types.CallToolResult.t => Types.CallToolResult.makeError(msg)

let executeTool = async (
  server: t,
  ~name: string,
  ~arguments: option<Dict.t<JSON.t>>=?,
  ~taskId: string,
  ~callId: string,
  ~onProgress: option<string => unit>=?,
): Types.executeToolResult => {
  switch getToolByName(server, name) {
  | Some(toolModule) => await executeLocalTool(toolModule, ~arguments, ~taskId, ~toolCallId=callId)
  | None =>
    switch server.relay->Relay.hasTool(name) {
    | false => Completed(toolError(`Tool not found: ${name}`))
    | true =>
      let resolvedArgs = switch name {
      | name if name == ToolNames.writeFile =>
        resolveToolImageRef(
          server,
          arguments,
          ~taskId,
          ~removeImageRef=true,
          ~includeMimeType=false,
        )
      | "wp_upload_media" =>
        resolveToolImageRef(
          server,
          arguments,
          ~taskId,
          ~removeImageRef=false,
          ~includeMimeType=true,
        )
      | _ => Ok(arguments)
      }

      switch resolvedArgs {
      | Error(msg) => Completed(toolError(msg))
      | Ok(finalArgs) =>
        let result = await server.relay->Relay.executeTool(
          ~name,
          ~arguments=?finalArgs,
          ~onProgress?,
        )
        switch result {
        | Ok(toolResult) => Completed(toolResult)
        | Error(msg) => Completed(toolError(msg))
        }
      }
    }
  }
}

let buildDiscoverResult = (server: t): Types.discoverResult => {
  {
    resultType: "complete",
    supportedVersions: [Types.protocolVersion],
    capabilities: {
      tools: {listChanged: false},
      extensions: {executionContext: {version: 1}},
    },
    ttlMs: 0,
    cacheScope: "private",
    _meta: {serverInfo: server.serverInfo},
  }
}

let buildToolsListResult = (server: t): Types.toolsListResult => {
  {
    resultType: "complete",
    tools: getToolsJson(server),
    ttlMs: 0,
    cacheScope: "private",
    _meta: {serverInfo: server.serverInfo},
  }
}

let toInterface = (server: t): Types.serverInterface<t> => {
  server,
  buildDiscoverResult,
  buildToolsListResult,
  executeTool: (server, toolCall, ~onProgress) =>
    executeTool(
      server,
      ~name=Types.AuthorizedToolCall.name(toolCall),
      ~arguments=?Types.AuthorizedToolCall.arguments(toolCall),
      ~taskId=Types.AuthorizedToolCall.taskId(toolCall),
      ~callId=Types.AuthorizedToolCall.callId(toolCall),
      ~onProgress?,
    ),
}
