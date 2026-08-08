module Types = FrontmanClient__MCP__Types
module Channel = FrontmanClient__Phoenix__Channel
module JsonRpc = FrontmanAiFrontmanProtocol.FrontmanProtocol__JsonRpc
module Decoders = FrontmanClient__Decoders
module Log = FrontmanLogs.Logs.Make({
  let component = #MCP
})

type messageDirection = Send | Receive

type mcpHandler<'server> = {
  serverInterface: Types.serverInterface<'server>,
  channel: Channel.t,
  sessionId: string,
  onMessage: option<(messageDirection, JSON.t) => unit>,
}

@@live
type mcpMessage =
  | Request({id: JsonRpc.Id.t, method: string, params: option<JSON.t>})
  | Notification({method: string, params: option<JSON.t>})

let requestSchema = S.object(s => {
  s.field("jsonrpc", S.literal("2.0"))->ignore
  let id = s.field("id", JsonRpc.Id.schema)
  let method = s.field("method", S.string)
  let params = s.field("params", S.option(S.json))
  Request({id, method, params})
})

let notificationSchema = S.object(s => {
  s.field("jsonrpc", S.literal("2.0"))->ignore
  let method = s.field("method", S.string)
  let params = s.field("params", S.option(S.json))
  Notification({method, params})
})

let hasIdField = (json: JSON.t): bool => {
  switch json->JSON.Decode.object {
  | Some(obj) => obj->Dict.get("id")->Option.isSome
  | None => false
  }
}

let parse = (json: JSON.t): result<mcpMessage, string> => {
  let schema = if hasIdField(json) {
    requestSchema
  } else {
    notificationSchema
  }
  json->Decoders.parseSchema(schema)
}

let sendResponse = (handler: mcpHandler<'server>, id: JsonRpc.Id.t, result: JSON.t): unit => {
  let payload = JsonRpc.Response.makeSuccessPayloadWithId(~id, ~result)
  handler.onMessage->Option.forEach(cb => cb(Send, payload))
  handler.channel->Channel.push(~event=#"mcp:message", ~payload)->ignore
}

let sendError = (
  handler: mcpHandler<'server>,
  id: JsonRpc.Id.t,
  code: int,
  message: string,
): unit => {
  let error = JsonRpc.RpcError.make(~code, ~message, ~data=None)
  let payload = JsonRpc.Response.makeErrorPayloadWithId(~id, ~error)
  handler.onMessage->Option.forEach(cb => cb(Send, payload))
  handler.channel->Channel.push(~event=#"mcp:message", ~payload)->ignore
}

let handleInitialize = (
  handler: mcpHandler<'server>,
  id: JsonRpc.Id.t,
  _params: option<JSON.t>,
): unit => {
  try {
    let {serverInterface} = handler
    let result = serverInterface.buildInitializeResult(serverInterface.server)
    let resultJson =
      result->S.decodeOrThrow(~from=Types.initializeResultSchema, ~to=S.json->S.noValidation(true))
    sendResponse(handler, id, resultJson)
  } catch {
  | exn =>
    let msg = exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
    Log.error(~error=exn->JsExn.fromException, `Initialize failed: ${msg}`)
    sendError(handler, id, Types.ErrorCode.serverError, `Initialize failed: ${msg}`)
  }
}

let handleToolsList = (handler: mcpHandler<'server>, id: JsonRpc.Id.t): unit => {
  try {
    let {serverInterface} = handler
    let result = serverInterface.buildToolsListResult(serverInterface.server)
    let resultJson =
      result->S.decodeOrThrow(~from=Types.toolsListResultSchema, ~to=S.json->S.noValidation(true))
    sendResponse(handler, id, resultJson)
  } catch {
  | exn =>
    let msg = exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
    Log.error(~error=exn->JsExn.fromException, `Tools list failed: ${msg}`)
    sendError(handler, id, Types.ErrorCode.serverError, `Tools list failed: ${msg}`)
  }
}

let handleToolsCall = async (
  handler: mcpHandler<'server>,
  id: JsonRpc.Id.t,
  params: option<JSON.t>,
): unit => {
  switch params {
  | Some(paramsJson) =>
    let paramsResult = try {
      Ok(paramsJson->S.parseOrThrow(~to=Types.toolCallParamsSchema))
    } catch {
    | exn =>
      Error(exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Invalid params"))
    }

    switch paramsResult {
    | Error(msg) => sendError(handler, id, Types.ErrorCode.invalidParams, `Invalid params: ${msg}`)
    | Ok({callId, name, arguments}) =>
      try {
        let {serverInterface} = handler
        let result = await serverInterface.executeTool(
          serverInterface.server,
          ~name,
          ~arguments,
          ~taskId=handler.sessionId,
          ~callId,
          ~onProgress=None,
        )
        switch result {
        | Completed(callToolResult) =>
          let resultJson =
            callToolResult->S.decodeOrThrow(
              ~from=Types.callToolResultSchema,
              ~to=S.json->S.noValidation(true),
            )
          sendResponse(handler, id, resultJson)
        | Suspended => ()
        }
      } catch {
      | exn =>
        let msg =
          exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
        Log.error(~error=exn->JsExn.fromException, `Tool execution failed: ${msg}`)
        sendError(handler, id, Types.ErrorCode.serverError, `Tool execution failed: ${msg}`)
      }
    }
  | None => sendError(handler, id, Types.ErrorCode.invalidParams, "Missing params for tools/call")
  }
}

let handleMessage = async (handler: mcpHandler<'server>, payload: JSON.t): unit => {
  try {
    handler.onMessage->Option.forEach(cb => cb(Receive, payload))

    switch parse(payload) {
    | Ok(Request({id, method, params})) =>
      switch method {
      | "initialize" => handleInitialize(handler, id, params)
      | "tools/list" => handleToolsList(handler, id)
      | "tools/call" => await handleToolsCall(handler, id, params)
      | _ => sendError(handler, id, Types.ErrorCode.methodNotFound, `Method not found: ${method}`)
      }
    | Ok(Notification({method: "notifications/initialized"})) => ()
    | Ok(Notification(_)) => ()
    | Error(msg) => Log.error(`Failed to parse MCP message: ${msg}`)
    }
  } catch {
  | exn =>
    let msg = exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
    Log.error(~error=exn->JsExn.fromException, `Unhandled error in MCP message handler: ${msg}`)
  }
}

@@live
let attach = (
  ~channel: Channel.t,
  ~sessionId: string,
  ~serverInterface: Types.serverInterface<'server>,
  ~onMessage: option<(messageDirection, JSON.t) => unit>=?,
): mcpHandler<'server> => {
  let handler = {serverInterface, channel, sessionId, onMessage}

  channel->Channel.on(~event=#"mcp:message", ~callback=payload => {
    handleMessage(handler, payload)->ignore
  })

  handler
}

@@live
let detach = (handler: mcpHandler<'server>): unit => {
  handler.channel->Channel.off(~event=#"mcp:message")
}
