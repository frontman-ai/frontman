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

let idFieldSchema = S.object(s => s.field("id", S.json))
let idValue = json => json->Decoders.parseSchema(idFieldSchema)->Result.mapOr(None, id => Some(id))
let hasIdField = json => json->idValue->Option.isSome
let readableId = json =>
  json
  ->idValue
  ->Option.flatMap(id =>
    id->Decoders.parseSchema(JsonRpc.Id.schema)->Result.mapOr(None, id => Some(id))
  )

let parse = json =>
  json->Decoders.parseSchema(hasIdField(json) ? requestSchema : notificationSchema)

let parseParams = (params, schema, missingMessage) =>
  switch params {
  | Some(params) => params->Decoders.parseSchema(schema)
  | None => Error(missingMessage)
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

let sendErrorWithoutId = (handler: mcpHandler<'server>, code: int, message: string): unit => {
  let error = JsonRpc.RpcError.make(~code, ~message, ~data=None)
  let payload = JsonRpc.Response.makeErrorPayloadWithoutId(~error)
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

let sendBuiltResponse = (handler, id, operation, build) =>
  try {
    sendResponse(handler, id, build())
  } catch {
  | exn =>
    let msg = exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
    Log.error(~error=exn->JsExn.fromException, `${operation} failed: ${msg}`)
    sendError(handler, id, Types.ErrorCode.serverError, `${operation} failed: ${msg}`)
  }

let handleDiscover = (
  handler: mcpHandler<'server>,
  id: JsonRpc.Id.t,
  params: option<JSON.t>,
): unit => {
  let parsed = parseParams(params, Types.discoverParamsSchema, "Missing params for server/discover")

  switch parsed {
  | Error(msg) => sendError(handler, id, Types.ErrorCode.invalidParams, `Invalid params: ${msg}`)
  | Ok(_) =>
    sendBuiltResponse(handler, id, "Discovery", () => {
      let {serverInterface} = handler
      serverInterface.buildDiscoverResult(serverInterface.server)->S.decodeOrThrow(
        ~from=Types.discoverResultSchema,
        ~to=S.json->S.noValidation(true),
      )
    })
  }
}

let handleToolsList = (
  handler: mcpHandler<'server>,
  id: JsonRpc.Id.t,
  params: option<JSON.t>,
): unit => {
  switch parseParams(params, Types.toolsListParamsSchema, "Missing params for tools/list") {
  | Error(msg) => sendError(handler, id, Types.ErrorCode.invalidParams, `Invalid params: ${msg}`)
  | Ok({cursor: Some(_)}) =>
    sendError(handler, id, Types.ErrorCode.invalidParams, "Invalid or expired cursor")
  | Ok({cursor: None}) =>
    sendBuiltResponse(handler, id, "Tools list", () => {
      let {serverInterface} = handler
      let result = serverInterface.buildToolsListResult(serverInterface.server)
      let json =
        result->S.decodeOrThrow(~from=Types.toolsListResultSchema, ~to=S.json->S.noValidation(true))
      json->S.parseOrThrow(~to=Types.toolsListResultWireSchema)->ignore
      json
    })
  }
}

let handleToolsCall = async (
  handler: mcpHandler<'server>,
  id: JsonRpc.Id.t,
  params: option<JSON.t>,
): unit => {
  switch parseParams(params, Types.toolCallParamsSchema, "Missing params for tools/call") {
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
          let resultJson =
            callToolResult->S.decodeOrThrow(
              ~from=Types.callToolResultSchema,
              ~to=S.json->S.noValidation(true),
            )
          sendResponse(handler, id, resultJson)
        | Suspended => ()
        | ProtocolError({code, message}) => sendError(handler, id, code, message)
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
}

let handleMessage = async (handler: mcpHandler<'server>, payload: JSON.t): unit => {
  try {
    handler.onMessage->Option.forEach(cb => cb(Receive, payload))

    switch parse(payload) {
    | Ok(Request({id, method, params})) =>
      switch parseParams(params, Types.discoverParamsSchema, "Missing request params") {
      | Error(msg) =>
        sendError(handler, id, Types.ErrorCode.invalidParams, `Invalid params: ${msg}`)
      | Ok({_meta}) =>
        switch Types.validateRequestMeta(_meta) {
        | Error(error) => sendMetadataError(handler, id, error)
        | Ok(_) =>
          switch method {
          | "server/discover" => handleDiscover(handler, id, params)
          | "tools/list" => handleToolsList(handler, id, params)
          | "tools/call" => await handleToolsCall(handler, id, params)
          | _ =>
            sendError(handler, id, Types.ErrorCode.methodNotFound, `Method not found: ${method}`)
          }
        }
      }
    | Ok(Notification(_)) => ()
    | Error(msg) =>
      Log.error(`Failed to parse MCP message: ${msg}`)
      switch readableId(payload) {
      | Some(id) => sendError(handler, id, Types.ErrorCode.invalidRequest, "Invalid Request")
      | None => sendErrorWithoutId(handler, Types.ErrorCode.invalidRequest, "Invalid Request")
      }
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
