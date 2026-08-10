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
  onMessage: option<(messageDirection, JSON.t) => unit>,
}

type mcpMessage =
  | Request(JsonRpc.Wire.requestFields)
  | Notification(JsonRpc.Wire.notificationFields)
  | Response

type metaValidationError =
  | UnsupportedProtocolVersion(string)
  | MissingExecutionContextCapability(string)

let exceptionMessage = exn =>
  exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")

let parse = (json: JSON.t): result<mcpMessage, string> =>
  switch json->Decoders.parseSchema(JsonRpc.Wire.messageSchema) {
  | Error(error) => Error(error)
  | Ok(_) =>
    switch json->Decoders.parseSchema(JsonRpc.Wire.requestSchema) {
    | Ok(_) =>
      json
      ->Decoders.parseSchema(JsonRpc.Wire.requestFieldsSchema)
      ->Result.map(fields => Request(fields))
    | Error(_) =>
      switch json->Decoders.parseSchema(JsonRpc.Wire.notificationSchema) {
      | Ok(_) =>
        json
        ->Decoders.parseSchema(JsonRpc.Wire.notificationFieldsSchema)
        ->Result.map(fields => Notification(fields))
      | Error(_) => Ok(Response)
      }
    }
  }

let reportMessage = (handler: mcpHandler<'server>, direction, payload): unit => {
  switch handler.onMessage {
  | None => ()
  | Some(callback) =>
    try {
      callback(direction, payload)
    } catch {
    | exn => Log.error(~error=exn->JsExn.fromException, "MCP message callback failed")
    }
  }
}

let push = (handler: mcpHandler<'server>, payload: JSON.t): unit => {
  reportMessage(handler, Send, payload)
  handler.channel->Channel.push(~event=#"mcp:message", ~payload)->ignore
}

let sendResponse = (handler: mcpHandler<'server>, id: JsonRpc.Id.t, result: JSON.t): unit =>
  push(handler, JsonRpc.Response.makeSuccessPayloadWithId(~id, ~result))

let sendError = (
  handler: mcpHandler<'server>,
  id: JsonRpc.Id.t,
  code: int,
  message: string,
  ~data: option<JSON.t>=None,
): unit => {
  let error = JsonRpc.RpcError.make(~code, ~message, ~data)
  push(handler, JsonRpc.Response.makeErrorPayloadWithId(~id, ~error))
}

let encode = (value, schema) =>
  value->S.decodeOrThrow(~from=schema, ~to=S.json->S.noValidation(true))

let validateRequestMeta = (meta: Types.RequestMeta.t): result<unit, metaValidationError> => {
  let fields = meta->Types.ExecutionContextExtension.requestMetaFields
  switch fields.protocolVersion == Types.protocolVersion {
  | false => Error(UnsupportedProtocolVersion(fields.protocolVersion))
  | true =>
    try {
      meta->Types.ExecutionContextExtension.validateClientCapabilities
      Ok()
    } catch {
    | exn => Error(MissingExecutionContextCapability(exceptionMessage(exn)))
    }
  }
}

let sendMetaValidationError = (handler, id, error): unit => {
  switch error {
  | UnsupportedProtocolVersion(requested) =>
    let data = JSON.Encode.object(
      Dict.fromArray([
        ("requested", JSON.Encode.string(requested)),
        ("supported", JSON.Encode.array([JSON.Encode.string(Types.protocolVersion)])),
      ]),
    )
    sendError(
      handler,
      id,
      Types.ErrorCode.unsupportedProtocolVersion,
      `Unsupported MCP protocol version: ${requested}`,
      ~data=Some(data),
    )
  | MissingExecutionContextCapability(detail) =>
    let data = JSON.Encode.object(
      Dict.fromArray([
        (
          "requiredCapabilities",
          Types.ExecutionContextExtension.clientCapabilities()->Types.ClientCapabilities.toJson,
        ),
      ]),
    )
    sendError(
      handler,
      id,
      Types.ErrorCode.missingRequiredClientCapability,
      `Missing required client capability: ${Types.ExecutionContextExtension.identifier}`,
      ~data=Some(data),
    )
    Log.error(detail)
  }
}

let handleDiscover = (handler: mcpHandler<'server>, id, payload): unit => {
  switch payload->Decoders.parseSchema(Types.DiscoverRequest.schema) {
  | Error(error) =>
    sendError(handler, id, Types.ErrorCode.invalidParams, `Invalid params: ${error}`)
  | Ok(request) =>
    switch request.params._meta->validateRequestMeta {
    | Error(error) => sendMetaValidationError(handler, id, error)
    | Ok() =>
      try {
        let {serverInterface} = handler
        let result = serverInterface.buildDiscoverResult(serverInterface.server)
        result.capabilities
        ->Types.ServerCapabilities.toJson
        ->S.parseOrThrow(~to=Types.ExecutionContextExtension.serverCapabilitiesSchema)
        ->ignore
        sendResponse(handler, id, encode(result, Types.DiscoverResult.schema))
      } catch {
      | exn =>
        let message = exceptionMessage(exn)
        Log.error(~error=exn->JsExn.fromException, `Server discovery failed: ${message}`)
        sendError(handler, id, Types.ErrorCode.internalError, `Server discovery failed: ${message}`)
      }
    }
  }
}

let handleToolsList = (handler: mcpHandler<'server>, id, payload): unit => {
  switch payload->Decoders.parseSchema(Types.ListToolsRequest.schema) {
  | Error(error) =>
    sendError(handler, id, Types.ErrorCode.invalidParams, `Invalid params: ${error}`)
  | Ok(request) =>
    switch request.params._meta->validateRequestMeta {
    | Error(error) => sendMetaValidationError(handler, id, error)
    | Ok() =>
      try {
        let {serverInterface} = handler
        let result = serverInterface.buildToolsListResult(serverInterface.server)
        sendResponse(handler, id, encode(result, Types.ListToolsResult.schema))
      } catch {
      | exn =>
        let message = exceptionMessage(exn)
        Log.error(~error=exn->JsExn.fromException, `Tools list failed: ${message}`)
        sendError(handler, id, Types.ErrorCode.internalError, `Tools list failed: ${message}`)
      }
    }
  }
}

let handleToolsCall = async (handler: mcpHandler<'server>, id, payload): unit => {
  switch payload->Decoders.parseSchema(Types.CallToolRequest.schema) {
  | Error(error) =>
    sendError(handler, id, Types.ErrorCode.invalidParams, `Invalid params: ${error}`)
  | Ok(request) =>
    switch request.params._meta->validateRequestMeta {
    | Error(error) => sendMetaValidationError(handler, id, error)
    | Ok() =>
      let context = try {
        Ok(request.params._meta->Types.ExecutionContextExtension.executionContext)
      } catch {
      | exn => Error(exceptionMessage(exn))
      }
      switch context {
      | Error(error) =>
        sendError(handler, id, Types.ErrorCode.invalidParams, `Invalid execution context: ${error}`)
      | Ok({taskId, toolCallId}) =>
        try {
          let {serverInterface} = handler
          let result = await serverInterface.executeTool(
            serverInterface.server,
            ~name=request.params.name,
            ~arguments=request.params.arguments,
            ~taskId,
            ~toolCallId,
            ~onProgress=None,
          )
          sendResponse(handler, id, encode(result, Types.CallToolResult.schema))
        } catch {
        | exn =>
          let message = exceptionMessage(exn)
          Log.error(~error=exn->JsExn.fromException, `Tool execution failed: ${message}`)
          sendError(handler, id, Types.ErrorCode.internalError, `Tool execution failed: ${message}`)
        }
      }
    }
  }
}

let handleCancellation = payload => {
  switch payload->Decoders.parseSchema(Types.CancelledNotification.schema) {
  | Error(error) => Log.error(`Invalid MCP cancellation notification: ${error}`)
  | Ok(_) => ()
  }
}

let recoverRequestId = payload =>
  payload
  ->JSON.Decode.object
  ->Option.flatMap(fields =>
    switch (fields->Dict.has("result"), fields->Dict.has("error")) {
    | (false, false) => fields->Dict.get("id")
    | _ => None
    }
  )
  ->Option.flatMap(id =>
    switch id->Decoders.parseSchema(JsonRpc.Id.schema) {
    | Ok(id) => Some(id)
    | Error(_) => None
    }
  )

let handleMessage = async (handler: mcpHandler<'server>, payload: JSON.t): unit => {
  reportMessage(handler, Receive, payload)
  switch parse(payload) {
  | Ok(Request({id, method})) =>
    switch method {
    | "server/discover" => handleDiscover(handler, id, payload)
    | "tools/list" => handleToolsList(handler, id, payload)
    | "tools/call" => await handleToolsCall(handler, id, payload)
    | _ => sendError(handler, id, Types.ErrorCode.methodNotFound, `Method not found: ${method}`)
    }
  | Ok(Notification({method: "notifications/cancelled"})) => handleCancellation(payload)
  | Ok(Notification(_)) | Ok(Response) => ()
  | Error(error) =>
    switch payload->recoverRequestId {
    | Some(id) => sendError(handler, id, Types.ModernErrorCode.invalidRequest, "Invalid Request")
    | None => Log.error(`Failed to parse MCP message: ${error}`)
    }
  }
}

@@live
let attach = (
  ~channel: Channel.t,
  ~serverInterface: Types.serverInterface<'server>,
  ~onMessage: option<(messageDirection, JSON.t) => unit>=?,
): mcpHandler<'server> => {
  let handler = {serverInterface, channel, onMessage}
  channel->Channel.on(~event=#"mcp:message", ~callback=payload => {
    handleMessage(handler, payload)->ignore
  })
  handler
}

@@live
let detach = (handler: mcpHandler<'server>): unit => {
  handler.channel->Channel.off(~event=#"mcp:message")
}
