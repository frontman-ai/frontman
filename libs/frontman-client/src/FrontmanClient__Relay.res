// Framework Tool Relay - connects to local dev server for tool discovery and execution

module Types = FrontmanClient__Relay__Types
module MCPTypes = FrontmanClient__MCP__Types
module SSE = FrontmanClient__SSE
module Decoders = FrontmanClient__Decoders
module Log = FrontmanLogs.Logs.Make({
  let component = #Relay
})

type relayState =
  | Disconnected
  | Connected({tools: array<Types.remoteTool>, serverInfo: MCPTypes.info})
  | Error(string)

type t = {
  baseUrl: string,
  requestHeaders: Dict.t<string>,
  state: ref<relayState>,
}

let make = (~baseUrl: string, ~requestHeaders: Dict.t<string>=Dict.make()): t => {
  baseUrl,
  requestHeaders,
  state: ref(Disconnected),
}

let isConnected = (relay: t): bool => {
  switch relay.state.contents {
  | Connected(_) => true
  | Disconnected | Error(_) => false
  }
}

let getState = (relay: t): relayState => relay.state.contents

// Connect to dev server and fetch tools
let connect = async (relay: t, ~signal: option<WebAPI.EventAPI.abortSignal>=?): result<
  unit,
  string,
> => {
  let url = `${relay.baseUrl}/frontman/tools`
  try {
    let response = await WebAPI.Global.fetch(
      url,
      ~init={
        headers: WebAPI.HeadersInit.fromDict(relay.requestHeaders),
        signal: ?(signal->Option.map(Null.make)),
      },
    )

    switch response.ok {
    | false =>
      let msg = `HTTP ${response.status->Int.toString}: ${response.statusText}`
      Log.error(~ctx={"url": url}, msg)
      relay.state := Error(msg)
      Error(msg)
    | true =>
      let json = await response->WebAPI.Response.json
      switch json->Decoders.parseSchema(Types.toolsResponseSchema) {
      | Ok(data) =>
        Log.info(
          ~ctx={"toolCount": data.tools->Array.length, "serverInfo": data.serverInfo},
          "Relay connected",
        )
        relay.state := Connected({tools: data.tools, serverInfo: data.serverInfo})
        Ok()
      | Error(parseError) =>
        let msg = `Invalid tools response: ${parseError}`
        Log.error(msg)
        relay.state := Error(msg)
        Error(msg)
      }
    }
  } catch {
  | exn =>
    let msg =
      exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Relay fetch failed")
    Log.error(~ctx={"url": url}, msg)
    relay.state := Error(msg)
    Error(msg)
  }
}

// Disconnect (reset state)
let disconnect = (relay: t): unit => {
  relay.state := Disconnected
}

// Get tools as JSON (for MCP tools/list)
let getToolsJson = (relay: t): array<JSON.t> => {
  switch relay.state.contents {
  | Connected({tools}) =>
    tools->Array.map(tool =>
      JSON.Encode.object(
        dict{
          "name": JSON.Encode.string(tool.name),
          "description": JSON.Encode.string(tool.description),
          "inputSchema": tool.inputSchema,
          "visibleToAgent": JSON.Encode.bool(tool.visibleToAgent),
        },
      )
    )
  | Disconnected | Error(_) => []
  }
}

// Check if relay has a specific tool
let hasTool = (relay: t, name: string): bool => {
  switch relay.state.contents {
  | Connected({tools}) => tools->Array.some(tool => tool.name == name)
  | Disconnected | Error(_) => false
  }
}

// Execute a tool via relay with SSE streaming
let executeTool = async (
  relay: t,
  ~name: string,
  ~arguments: option<Dict.t<JSON.t>>=?,
  ~onProgress: option<string => unit>=?,
): result<MCPTypes.callToolResult, string> => {
  switch relay->isConnected {
  | false =>
    Log.warning("Cannot execute tool: relay not connected")
    Error("Relay not connected")
  | true =>
    Log.debug(~ctx={"tool": name}, "Executing relay tool")
    let url = `${relay.baseUrl}/frontman/tools/call`
    let request: Types.toolCallRequest = {name, arguments}
    let body = request->S.reverseConvertToJsonOrThrow(Types.toolCallRequestSchema)
    let headers = Dict.fromArray([
      ("Content-Type", "application/json"),
      ("Accept", "text/event-stream"),
    ])
    relay.requestHeaders->Dict.forEachWithKey((value, key) => headers->Dict.set(key, value))

    try {
      let response = await WebAPI.Global.fetch(
        url,
        ~init={
          method: "POST",
          headers: WebAPI.HeadersInit.fromDict(headers),
          body: WebAPI.BodyInit.fromString(JSON.stringify(body)),
        },
      )

      switch response.ok {
      | false =>
        let msg = `HTTP ${response.status->Int.toString}: ${response.statusText}`
        Log.error(~ctx={"tool": name}, msg)
        Error(msg)
      | true =>
        switch await SSE.readStream(response, ~onProgress?) {
        | Ok(json) =>
          json
          ->Decoders.parseSchema(MCPTypes.callToolResultSchema)
          ->Result.mapError(msg => `Invalid result: ${msg}`)
        | Error(msg) => Error(msg)
        }
      }
    } catch {
    | exn =>
      let msg =
        exn
        ->JsExn.fromException
        ->Option.flatMap(JsExn.message)
        ->Option.getOr("Relay tool execution failed")
      Log.error(~ctx={"tool": name, "url": url}, msg)
      Error(msg)
    }
  }
}
