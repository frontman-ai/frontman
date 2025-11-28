// Framework Tool Relay - connects to local dev server for tool discovery and execution

module Types = FrontmanClient__Relay__Types
module MCPTypes = FrontmanClient__MCP__Types
module SSE = FrontmanClient__SSE

type connectionState =
  | Disconnected
  | Connected({tools: array<Types.remoteTool>, serverInfo: MCPTypes.info})
  | Error(string)

type t = {
  baseUrl: string,
  mutable state: connectionState,
}

let make = (~baseUrl: string): t => {
  baseUrl,
  state: Disconnected,
}

let isConnected = (relay: t): bool => {
  switch relay.state {
  | Connected(_) => true
  | _ => false
  }
}

let getState = (relay: t): connectionState => relay.state

// Connect to dev server and fetch tools
let connect = async (relay: t): result<unit, string> => {
  let url = `${relay.baseUrl}/__frontman/tools`
  let response = await WebAPI.Global.fetch(url)

  if !response.ok {
    let msg = `HTTP ${response.status->Int.toString}: ${response.statusText}`
    relay.state = Error(msg)
    Error(msg)
  } else {
    let json = await response->WebAPI.Response.json
    try {
      let data = json->S.parseOrThrow(Types.toolsResponseSchema)
      relay.state = Connected({tools: data.tools, serverInfo: data.serverInfo})
      Ok()
    } catch {
    | S.Error(e) =>
      let msg = `Invalid tools response: ${e.message}`
      relay.state = Error(msg)
      Error(msg)
    }
  }
}

// Disconnect (reset state)
let disconnect = (relay: t): unit => {
  relay.state = Disconnected
}

// Get tools as JSON (for MCP tools/list)
let getToolsJson = (relay: t): array<JSON.t> => {
  switch relay.state {
  | Connected({tools}) =>
    tools->Array.map(tool =>
      JSON.Encode.object(
        dict{
          "name": JSON.Encode.string(tool.name),
          "description": JSON.Encode.string(tool.description),
          "inputSchema": tool.inputSchema,
        },
      )
    )
  | _ => []
  }
}

// Check if relay has a specific tool
let hasTool = (relay: t, name: string): bool => {
  switch relay.state {
  | Connected({tools}) => tools->Array.some(tool => tool.name == name)
  | _ => false
  }
}

// Execute a tool via relay with SSE streaming
let executeTool = async (
  relay: t,
  ~name: string,
  ~arguments: option<Dict.t<JSON.t>>=?,
  ~onProgress: option<string => unit>=?,
): result<MCPTypes.callToolResult, string> => {
  if !(relay->isConnected) {
    Error("Relay not connected")
  } else {
    let url = `${relay.baseUrl}/__frontman/tools/call`
    let request: Types.toolCallRequest = {name, arguments}
    let body = request->S.reverseConvertToJsonOrThrow(Types.toolCallRequestSchema)

    let response = await WebAPI.Global.fetch(
      url,
      ~init={
        method: "POST",
        headers: WebAPI.HeadersInit.fromDict(
          dict{
            "Content-Type": "application/json",
            "Accept": "text/event-stream",
          },
        ),
        body: WebAPI.BodyInit.fromString(JSON.stringify(body)),
      },
    )

    if !response.ok {
      Error(`HTTP ${response.status->Int.toString}: ${response.statusText}`)
    } else {
      // Read SSE stream and return result
      switch await SSE.readStream(response, ~onProgress?) {
      | Ok(json) =>
        try {
          let result = json->S.parseOrThrow(MCPTypes.callToolResultSchema)
          Ok(result)
        } catch {
        | S.Error(e) => Error(`Invalid result: ${e.message}`)
        }
      | Error(msg) => Error(msg)
      }
    }
  }
}
