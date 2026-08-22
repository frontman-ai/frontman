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

let serializeResult = (result, schema, ~validateWith=schema) => {
  let json = result->S.decodeOrThrow(~from=schema, ~to=S.json->S.noValidation(true))
  json->S.parseOrThrow(~to=validateWith)->ignore
  json
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
  ~data: option<JSON.t>=?,
): unit => {
  let error = JsonRpc.RpcError.make(~code, ~message, ~data)
  let payload = JsonRpc.Response.makeErrorPayloadWithId(~id, ~error)
  handler.onMessage->Option.forEach(cb => cb(Send, payload))
  handler.channel->Channel.push(~event=#"mcp:message", ~payload)->ignore
}

let sendMetadataError = (handler, id, error: Types.metadataError) =>
  switch error {
  | UnsupportedProtocolVersion(requested) =>
    sendError(
      handler,
      id,
      Types.ErrorCode.unsupportedProtocolVersion,
      "Unsupported protocol version",
      ~data=Types.unsupportedProtocolVersionDataToJson(requested),
    )
  }

let handleDiscover = (
  handler: mcpHandler<'server>,
  id: JsonRpc.Id.t,
  params: option<JSON.t>,
): unit => {
  let parsed = switch params {
  | Some(params) =>
    try {
      Ok(params->S.parseOrThrow(~to=Types.discoverParamsSchema))
    } catch {
    | exn =>
      Error(exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Invalid params"))
    }
  | None => Error("Missing params for server/discover")
  }

  switch parsed {
  | Error(msg) => sendError(handler, id, Types.ErrorCode.invalidParams, `Invalid params: ${msg}`)
  | Ok({_meta}) =>
    switch Types.validateRequestMeta(_meta) {
    | Error(error) => sendMetadataError(handler, id, error)
    | Ok(_) =>
      try {
        let {serverInterface} = handler
        let result = serverInterface.buildDiscoverResult(serverInterface.server)
        let resultJson = serializeResult(result, Types.discoverResultSchema)
        sendResponse(handler, id, resultJson)
      } catch {
      | exn =>
        let msg =
          exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
        Log.error(~error=exn->JsExn.fromException, `Discovery failed: ${msg}`)
        sendError(handler, id, Types.ErrorCode.serverError, `Discovery failed: ${msg}`)
      }
    }
  }
}

let handleToolsList = (
  handler: mcpHandler<'server>,
  id: JsonRpc.Id.t,
  params: option<JSON.t>,
): unit => {
  let parsed = switch params {
  | Some(params) =>
    try {
      Ok(params->S.parseOrThrow(~to=Types.toolsListParamsSchema))
    } catch {
    | exn =>
      Error(exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Invalid params"))
    }
  | None => Error("Missing params for tools/list")
  }

  switch parsed {
  | Error(msg) => sendError(handler, id, Types.ErrorCode.invalidParams, `Invalid params: ${msg}`)
  | Ok({_meta}) =>
    switch Types.validateRequestMeta(_meta) {
    | Error(error) => sendMetadataError(handler, id, error)
    | Ok(_) =>
      try {
        let {serverInterface} = handler
        let result = serverInterface.buildToolsListResult(serverInterface.server)
        let resultJson = serializeResult(
          result,
          Types.toolsListResultSchema,
          ~validateWith=Types.toolsListResultWireSchema,
        )
        sendResponse(handler, id, resultJson)
      } catch {
      | exn =>
        let msg =
          exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
        Log.error(~error=exn->JsExn.fromException, `Tools list failed: ${msg}`)
        sendError(handler, id, Types.ErrorCode.serverError, `Tools list failed: ${msg}`)
      }
    }
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
    | Ok(params) =>
      switch Types.AuthorizedToolCall.authorize(params, ~sessionId=handler.sessionId) {
      | Error(ToolCallMetadata(error)) => sendMetadataError(handler, id, error)
      | Error(MissingExecutionContextCapability) =>
        sendError(
          handler,
          id,
          Types.ErrorCode.missingRequiredClientCapability,
          "Missing required client capability",
          ~data=Types.missingExecutionContextCapabilityDataToJson(),
        )
      | Error(MissingExecutionContext) =>
        sendError(handler, id, Types.ErrorCode.invalidParams, "Missing execution context")
      | Error(WrongTask) =>
        sendError(handler, id, Types.ErrorCode.invalidParams, "Tool taskId does not match session")
      | Ok(authorizedToolCall) =>
        try {
          let {serverInterface} = handler
          let result = await serverInterface.executeTool(
            serverInterface.server,
            authorizedToolCall,
            ~onProgress=None,
          )
          switch result {
          | Completed(callToolResult) =>
            let resultJson = serializeResult(callToolResult, Types.callToolResultSchema)
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
      | "server/discover" => handleDiscover(handler, id, params)
      | "tools/list" => handleToolsList(handler, id, params)
      | "tools/call" => await handleToolsCall(handler, id, params)
      | _ => sendError(handler, id, Types.ErrorCode.methodNotFound, `Method not found: ${method}`)
      }
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
