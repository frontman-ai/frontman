// MCP Client entry point
// Handles MCP message routing for browser-as-server pattern

module Types = FrontmanClient__MCP__Types
module Server = FrontmanClient__MCP__Server
module Channel = FrontmanClient__Phoenix__Channel
module JsonRpc = FrontmanClient__JsonRpc

type messageDirection = Send | Receive

type mcpHandler = {
  server: Server.t,
  channel: Channel.t,
  onMessage: option<(messageDirection, JSON.t) => unit>,
}

// Incoming message variants
type mcpMessage =
  | Request({id: int, method: string, params: option<JSON.t>})
  | Notification({method: string, params: option<JSON.t>})

// Schema for requests (has id field)
let requestSchema = S.object(s => {
  s.field("jsonrpc", S.literal("2.0"))->ignore
  let id = s.field("id", S.int)
  let method = s.field("method", S.string)
  let params = s.field("params", S.option(S.json))
  Request({id, method, params})
})

// Schema for notifications (no id field)
let notificationSchema = S.object(s => {
  s.field("jsonrpc", S.literal("2.0"))->ignore
  let method = s.field("method", S.string)
  let params = s.field("params", S.option(S.json))
  Notification({method, params})
})

// Check if JSON object has an "id" field
let hasIdField = (json: JSON.t): bool => {
  switch json->JSON.Decode.object {
  | Some(obj) => obj->Dict.get("id")->Option.isSome
  | None => false
  }
}

// Parse incoming MCP message
// Discriminates by presence of 'id' field
let parse = (json: JSON.t): result<mcpMessage, string> => {
  let schema = if hasIdField(json) { requestSchema } else { notificationSchema }
  try {
    Ok(json->S.parseOrThrow(schema))
  } catch {
  | S.Error(e) => Error(e.message)
  }
}

// Send a JSON-RPC response
let sendResponse = (handler: mcpHandler, id: int, result: JSON.t): unit => {
  let response = JsonRpc.Response.makeSuccess(~id, ~result)
  let payload = response->S.reverseConvertToJsonOrThrow(JsonRpc.Response.schema)
  handler.onMessage->Option.forEach(cb => cb(Send, payload))
  handler.channel->Channel.push(~event=#"mcp:message", ~payload)->ignore
}

// Send a JSON-RPC error response
let sendError = (handler: mcpHandler, id: int, _code: int, message: string): unit => {
  let error = JsonRpc.RpcError.make(~code=MethodNotFound, ~message, ~data=None)
  let response = JsonRpc.Response.makeError(~id, ~error)
  let payload = response->S.reverseConvertToJsonOrThrow(JsonRpc.Response.schema)
  handler.onMessage->Option.forEach(cb => cb(Send, payload))
  handler.channel->Channel.push(~event=#"mcp:message", ~payload)->ignore
}

// Handle initialize request
let handleInitialize = (handler: mcpHandler, id: int, _params: option<JSON.t>): unit => {
  let result = Server.buildInitializeResult(handler.server)
  let resultJson = result->S.reverseConvertToJsonOrThrow(Types.initializeResultSchema)
  sendResponse(handler, id, resultJson)
}

// Handle tools/list request
let handleToolsList = (handler: mcpHandler, id: int): unit => {
  let result = Server.buildToolsListResult(handler.server)
  let resultJson = result->S.reverseConvertToJsonOrThrow(Types.toolsListResultSchema)
  sendResponse(handler, id, resultJson)
}

// Handle tools/call request
let handleToolsCall = async (handler: mcpHandler, id: int, params: option<JSON.t>): unit => {
  switch params {
  | Some(paramsJson) =>
    try {
      let {name, arguments}: Types.toolCallParams =
        paramsJson->S.parseOrThrow(Types.toolCallParamsSchema)
      let result = await Server.executeTool(handler.server, ~name, ~arguments?)
      let resultJson = result->S.reverseConvertToJsonOrThrow(Types.callToolResultSchema)
      sendResponse(handler, id, resultJson)
    } catch {
    | S.Error(e) =>
      sendError(handler, id, Types.ErrorCode.invalidParams, `Invalid params: ${e.message}`)
    }
  | None =>
    sendError(handler, id, Types.ErrorCode.invalidParams, "Missing params for tools/call")
  }
}

// Handle incoming MCP message
let handleMessage = async (handler: mcpHandler, payload: JSON.t): unit => {
  handler.onMessage->Option.forEach(cb => cb(Receive, payload))

  switch parse(payload) {
  | Ok(Request({id, method, params})) =>
    switch method {
    | "initialize" => handleInitialize(handler, id, params)
    | "tools/list" => handleToolsList(handler, id)
    | "tools/call" => await handleToolsCall(handler, id, params)
    | _ => sendError(handler, id, Types.ErrorCode.methodNotFound, `Method not found: ${method}`)
    }
  | Ok(Notification({method: "notifications/initialized"})) =>
    // Agent acknowledged initialization - nothing to do
    ()
  | Ok(Notification(_)) =>
    // Other notifications - ignore for now
    ()
  | Error(msg) => Console.error(`Failed to parse MCP message: ${msg}`)
  }
}

// Attach MCP handler to a session channel
let attach = (
  ~channel: Channel.t,
  ~server: Server.t,
  ~onMessage: option<(messageDirection, JSON.t) => unit>=?,
): mcpHandler => {
  let handler = {server, channel, onMessage}

  channel->Channel.on(~event=#"mcp:message", ~callback=payload => {
    handleMessage(handler, payload)->ignore
  })

  handler
}

// Detach MCP handler from channel
let detach = (handler: mcpHandler): unit => {
  handler.channel->Channel.off(~event=#"mcp:message")
}
