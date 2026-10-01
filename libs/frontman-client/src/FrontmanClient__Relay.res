module Types = FrontmanClient__Relay__Types
module MCPTypes = FrontmanClient__MCP__Types
module SSE = FrontmanClient__SSE
module Decoders = FrontmanClient__Decoders
module Log = FrontmanLogs.Logs.Make({
  let component = #Relay
})

type config = {
  baseUrl: string,
  requestHeaders: Dict.t<string>,
  fetch: (string, WebAPI.FetchTypes.requestInit) => promise<WebAPI.Response.t>,
}

type connected = {
  config: config,
  tools: array<Types.remoteTool>,
  serverInfo: MCPTypes.info,
  signal: WebAPI.EventTypes.abortSignal,
}

let makeConfig = (
  ~baseUrl: string,
  ~requestHeaders: Dict.t<string>=Dict.make(),
  ~fetch=(url, init) => WebAPI.Fetch.fetch(url, ~init),
): config => {baseUrl, requestHeaders, fetch}

let getServerInfo = (relay: connected): MCPTypes.info => relay.serverInfo

let parseToolsResponse = (json: JSON.t): result<Types.toolsResponse, string> => {
  let normalizeLegacyTool = (tool: Types.legacyRemoteTool): Types.remoteTool => {
    let metadata = dict{
      "access": tool.access
      ->Option.getOr(FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool.ReadWrite)
      ->S.decodeOrThrow(
        ~from=FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool.accessSchema,
        ~to=S.json->S.noValidation(true),
      ),
      "visibleToAgent": JSON.Encode.bool(tool.visibleToAgent),
    }
    let definition = dict{
      "name": JSON.Encode.string(tool.name),
      "description": JSON.Encode.string(tool.description),
      "inputSchema": tool.inputSchema,
      "_meta": JSON.Encode.object(dict{"ai.frontman/tool-metadata": JSON.Encode.object(metadata)}),
    }
    tool.outputSchema->Option.forEach(outputSchema =>
      definition->Dict.set("outputSchema", outputSchema)
    )
    JSON.Encode.object(definition)
  }
  let protocolVersionSchema = S.object(s => s.field("protocolVersion", S.string))

  json
  ->Decoders.parseSchema(protocolVersionSchema)
  ->Result.mapError(error => `Invalid protocol version: ${error}`)
  ->Result.flatMap(protocolVersion =>
    switch protocolVersion {
    | "2.0" =>
      json
      ->Decoders.parseSchema(Types.toolsResponseSchema)
      ->Result.mapError(error => `Relay protocol 2.0: ${error}`)
    | "1.0" =>
      json
      ->Decoders.parseSchema(Types.legacyToolsResponseSchema)
      ->Result.map(data => {
        let normalized: Types.toolsResponse = {
          tools: data.tools->Array.map(normalizeLegacyTool),
          serverInfo: data.serverInfo,
          protocolVersion: Types.protocolVersion,
        }
        normalized
      })
      ->Result.mapError(error => `Relay protocol 1.0: ${error}`)
    | unsupported => Error(`Unsupported relay protocol version: ${unsupported}`)
    }
  )
}

@schema
type httpError = {code: option<string>, error: string}

let readHttpError = async response => {
  try {
    S.parseOrThrow(await response->WebAPI.Response.json, ~to=httpErrorSchema)
  } catch {
  | _ => {code: None, error: "Request rejected without JSON error details."}
  }
}

let request = async (relay: config, ~path, ~body=?, ~signal, ~decode): result<'a, string> => {
  let result: result<'a, string> = try {
    let (method, headers) = switch body {
    | Some(_) => ("POST", dict{"Content-Type": "application/json", "Accept": "text/event-stream"})
    | None => ("GET", Dict.make())
    }
    relay.requestHeaders->Dict.forEachWithKey((value, key) => headers->Dict.set(key, value))
    let response = await relay.fetch(
      `${relay.baseUrl}/frontman/${path}`,
      {
        method,
        headers: WebAPI.HeadersInit.fromDict(headers),
        body: ?(body->Option.map(WebAPI.BodyInit.fromString)),
        signal: Null.make(signal),
      },
    )
    switch response.ok {
    | true => await decode(response)
    | false =>
      let failure = await readHttpError(response)
      let code =
        failure.code
        ->Option.map(code => ` [${code->String.slice(~start=0, ~end=80)}]`)
        ->Option.getOr("")
      let message = failure.error->String.slice(~start=0, ~end=500)
      Error(`HTTP ${response.status->Int.toString}${code}: ${message}`)
    }
  } catch {
  | exn =>
    Error(
      exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Relay request failed"),
    )
  }
  result->Result.mapError(message => {
    Log.error(~ctx={"path": path}, message)
    message
  })
}

let connect = async (config: config, ~signal: WebAPI.EventTypes.abortSignal): result<
  connected,
  string,
> => {
  switch signal.aborted {
  | true => Error("Relay connection aborted")
  | false =>
    let result = await request(config, ~path="tools", ~signal, ~decode=async response => {
      (await response->WebAPI.Response.json)
      ->parseToolsResponse
      ->Result.mapError(message => `Invalid tools response: ${message}`)
    })
    switch signal.aborted {
    | true => Error("Relay connection aborted")
    | false =>
      result->Result.map(data => {config, tools: data.tools, serverInfo: data.serverInfo, signal})
    }
  }
}

let getToolsJson = (relay: connected): array<JSON.t> => relay.tools

let toolName = tool =>
  tool
  ->JSON.Decode.object
  ->Option.flatMap(tool => tool->Dict.get("name"))
  ->Option.flatMap(JSON.Decode.string)

let hasTool = (relay: connected, name: string): bool =>
  relay->getToolsJson->Array.some(tool => tool->toolName == Some(name))

let executeTool = async (
  relay: connected,
  ~name: string,
  ~arguments: option<Dict.t<JSON.t>>=?,
): result<MCPTypes.CallToolResult.t, string> => {
  switch relay.signal.aborted {
  | true => Error("Relay connection aborted")
  | false =>
    Log.debug(~ctx={"tool": name}, "Executing relay tool")
    let input: Types.toolCallRequest = {name, arguments}
    let body = input->S.decodeOrThrow(~from=Types.toolCallRequestSchema, ~to=S.jsonString)
    await request(
      relay.config,
      ~path="tools/call",
      ~body,
      ~signal=relay.signal,
      ~decode=async response => {
        (await SSE.readStream(response))->Result.flatMap(json =>
          json
          ->Decoders.parseSchema(MCPTypes.callToolResultSchema)
          ->Result.mapError(message => `Invalid result: ${message}`)
        )
      },
    )
  }
}
