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
  serverInfo: Types.Implementation.t,
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
  serverInfo: {
    name: serverName,
    version: serverVersion,
    title: None,
    description: None,
    websiteUrl: None,
    icons: None,
  },
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

let serializeTool = (m: module(Tool.Tool)): JSON.t => {
  module T = unpack(m)
  let definition = dict{
    "name": JSON.Encode.string(T.name),
    "description": JSON.Encode.string(T.description),
    "inputSchema": T.inputSchema->S.toJSONSchema->jsonSchemaAsJson,
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

let argumentKeys = (arguments: option<Dict.t<JSON.t>>): string =>
  switch arguments {
  | None => "none"
  | Some(args) => args->Dict.keysToArray->Array.join(",")
  }

let executeLocalTool = async (
  toolModule: module(Tool.Tool),
  ~arguments: option<Dict.t<JSON.t>>,
  ~taskId: string,
  ~toolCallId: string,
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
        "schemaError": msg,
        "argumentKeys": argumentKeys(arguments),
      },
      "Tool input schema validation failed",
    )
    Types.CallToolResult.makeError(`Invalid input: ${msg}`)
  | Ok(input) =>
    Log.debug(~ctx={"tool": T.name}, "Calling execute")
    let result = await T.execute(input, ~taskId, ~toolCallId)
    Log.debug(~ctx={"tool": T.name}, "Execute returned")
    result
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
          switch newArgs->Dict.get("mime_type") {
          | None => newArgs->Dict.set("mime_type", JSON.Encode.string(mediaType))
          | Some(_) => ()
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
  ~toolCallId: string,
  ~onProgress: option<string => unit>=?,
): Types.CallToolResult.t => {
  switch getToolByName(server, name) {
  | Some(toolModule) => await executeLocalTool(toolModule, ~arguments, ~taskId, ~toolCallId)
  | None =>
    switch server.relay->Relay.hasTool(name) {
    | false => toolError(`Tool not found: ${name}`)
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
      | Error(msg) => toolError(msg)
      | Ok(finalArgs) =>
        let result = await server.relay->Relay.executeTool(
          ~name,
          ~arguments=?finalArgs,
          ~onProgress?,
        )
        switch result {
        | Ok(toolResult) => toolResult
        | Error(msg) => toolError(msg)
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
  executeTool: (server, ~name, ~arguments, ~taskId, ~toolCallId, ~onProgress) =>
    executeTool(server, ~name, ~arguments?, ~taskId, ~toolCallId, ~onProgress?),
}
