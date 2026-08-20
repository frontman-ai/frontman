module Types = FrontmanClient__MCP__Types
module Channel = FrontmanClient__Phoenix__Channel
module JsonRpc = FrontmanAiFrontmanProtocol.FrontmanProtocol__JsonRpc
module Decoders = FrontmanClient__Decoders
module Log = FrontmanLogs.Logs.Make({
  let component = #MCP
})

type messageDirection = Send | Receive

type activeRequest = {executionKey: string}

type durableExecution = {
  controller: WebAPI.EventAPI.abortController,
  fingerprint: string,
  waiters: ref<Dict.t<JsonRpc.Id.t>>,
}

type terminalResult =
  | Success(JSON.t)
  | Failure(string)

type completedExecution = {fingerprint: string, result: terminalResult}

type cachedExecution = {fingerprint: string, result: terminalResult, bytes: int}

type mcpHandler<'server> = {
  serverInterface: Types.serverInterface<'server>,
  channel: Channel.t,
  onMessage: option<(messageDirection, JSON.t) => unit>,
  activeRequests: ref<Dict.t<activeRequest>>,
  durableExecutions: ref<Dict.t<durableExecution>>,
  durableExecutionFingerprints: ref<Dict.t<string>>,
  durableExecutionFingerprintBytes: ref<int>,
  completedExecutions: ref<Dict.t<cachedExecution>>,
  completedExecutionOrder: ref<array<string>>,
  completedExecutionBytes: ref<int>,
  active: ref<bool>,
  listenerRef: ref<option<Channel.listenerRef>>,
}

let maxActiveRequests = 256
let maxCompletedExecutions = 256
let maxCompletedExecutionBytes = 1048576
let maxDurableExecutions = 4096
let maxDurableExecutionFingerprintBytes = 1048576

type textEncoder

@new external makeTextEncoder: unit => textEncoder = "TextEncoder"
@send external encodeText: (textEncoder, string) => Uint8Array.t = "encode"
@get external byteLength: Uint8Array.t => int = "byteLength"

let utf8Bytes = value => makeTextEncoder()->encodeText(value)->byteLength

type mcpMessage =
  | Request(JsonRpc.Wire.requestFields)
  | Notification(JsonRpc.Wire.notificationFields)
  | Response

type metaValidationError =
  | UnsupportedProtocolVersion(string)
  | MissingExecutionContextCapability(string)

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
  switch handler.active.contents {
  | false => ()
  | true =>
    reportMessage(handler, Send, payload)
    switch handler.active.contents {
    | false => ()
    | true => handler.channel->Channel.push(~event=#"mcp:message", ~payload)->ignore
    }
  }
}

let requestKey = id => id->JsonRpc.Id.toJson->JSON.stringify

let durableKey = (~taskId, ~toolCallId) =>
  JSON.stringify(JSON.Encode.array([JSON.Encode.string(taskId), JSON.Encode.string(toolCallId)]))

let rec canonicalJson = (value: JSON.t): string => {
  switch value->JSON.Decode.string {
  | Some(value) => "s" ++ JSON.stringify(JSON.Encode.string(value))
  | None =>
    switch value->JSON.Decode.bool {
    | Some(value) => value ? "b1" : "b0"
    | None =>
      switch value->JSON.Decode.float {
      | Some(value) => "n" ++ JSON.stringify(JSON.Encode.float(value))
      | None =>
        switch value->JSON.Decode.array {
        | Some(values) => "a[" ++ values->Array.map(canonicalJson)->Array.join(",") ++ "]"
        | None =>
          switch value->JSON.Decode.object {
          | Some(fields) =>
            let entries =
              fields
              ->Dict.keysToArray
              ->Array.toSorted(String.compare)
              ->Array.map(key =>
                JSON.stringify(JSON.Encode.string(key)) ++
                ":" ++
                canonicalJson(fields->Dict.get(key)->Option.getOrThrow)
              )
            "o{" ++ entries->Array.join(",") ++ "}"
          | None => "z"
          }
        }
      }
    }
  }
}

let executionFingerprint = (~name, ~arguments) =>
  canonicalJson(
    JSON.Encode.array([
      JSON.Encode.string("tools/call"),
      JSON.Encode.string(name),
      arguments->Option.mapOr(JSON.Encode.null, JSON.Encode.object),
    ]),
  )

let cancelRequest = (handler: mcpHandler<'server>, id): bool => {
  let key = requestKey(id)
  switch handler.activeRequests.contents->Dict.get(key) {
  | None => false
  | Some({executionKey}) =>
    handler.activeRequests.contents->Dict.delete(key)
    switch handler.durableExecutions.contents->Dict.get(executionKey) {
    | Some(execution) =>
      execution.waiters.contents->Dict.delete(key)
      switch execution.waiters.contents->Dict.size {
      | 0 => WebAPI.AbortController.abort(execution.controller)
      | _ => ()
      }
    | None => ()
    }
    true
  }
}

type beginExecutionError =
  | ChangedReplay
  | ActiveCapacityExceeded
  | DurableCapacityExceeded
  | ResultUnavailable
type beginExecutionResult = Start(durableExecution) | Join

let addWaiter = (
  handler: mcpHandler<'server>,
  executionKey: string,
  execution: durableExecution,
  id: JsonRpc.Id.t,
): unit => {
  let key = requestKey(id)
  execution.waiters.contents->Dict.set(key, id)
  handler.activeRequests.contents->Dict.set(key, {executionKey: executionKey})
}

let beginExecution = (handler: mcpHandler<'server>, ~executionKey, ~fingerprint, ~id): result<
  beginExecutionResult,
  beginExecutionError,
> => {
  switch handler.durableExecutions.contents->Dict.get(executionKey) {
  | Some(execution) if execution.fingerprint != fingerprint => Error(ChangedReplay)
  | Some(execution) =>
    addWaiter(handler, executionKey, execution, id)
    Ok(Join)
  | None =>
    switch handler.durableExecutionFingerprints.contents->Dict.get(executionKey) {
    | Some(originalFingerprint) if originalFingerprint != fingerprint => Error(ChangedReplay)
    | Some(_) => Error(ResultUnavailable)
    | None =>
      let identityBytes = executionKey->utf8Bytes + fingerprint->utf8Bytes
      switch (
        handler.durableExecutionFingerprints.contents->Dict.size >= maxDurableExecutions,
        identityBytes > maxDurableExecutionFingerprintBytes ||
          handler.durableExecutionFingerprintBytes.contents >
          maxDurableExecutionFingerprintBytes - identityBytes,
      ) {
      | (true, _) | (_, true) => Error(DurableCapacityExceeded)
      | (false, false) =>
        switch handler.durableExecutions.contents->Dict.size >= maxActiveRequests {
        | true => Error(ActiveCapacityExceeded)
        | false =>
          let execution = {
            controller: WebAPI.AbortController.make(),
            fingerprint,
            waiters: ref(Dict.make()),
          }
          handler.durableExecutionFingerprints.contents->Dict.set(executionKey, fingerprint)
          handler.durableExecutionFingerprintBytes :=
            handler.durableExecutionFingerprintBytes.contents + identityBytes
          handler.durableExecutions.contents->Dict.set(executionKey, execution)
          addWaiter(handler, executionKey, execution, id)
          Ok(Start(execution))
        }
      }
    }
  }
}

let terminalResultBytes = result => {
  let encoded = switch result {
  | Success(result) => JSON.stringify(result)
  | Failure(message) => JSON.stringify(JSON.Encode.string(message))
  }
  encoded->utf8Bytes
}

let rec evictCompletedExecutions = handler => {
  switch (
    handler.completedExecutionOrder.contents->Array.length > maxCompletedExecutions,
    handler.completedExecutionBytes.contents > maxCompletedExecutionBytes,
  ) {
  | (false, false) => ()
  | (true, _) | (_, true) =>
    let evictedKey = handler.completedExecutionOrder.contents[0]->Option.getOrThrow
    let evicted = handler.completedExecutions.contents->Dict.get(evictedKey)->Option.getOrThrow
    handler.completedExecutions.contents->Dict.delete(evictedKey)
    handler.completedExecutionOrder :=
      handler.completedExecutionOrder.contents->Array.slice(~start=1)
    handler.completedExecutionBytes := handler.completedExecutionBytes.contents - evicted.bytes
    evictCompletedExecutions(handler)
  }
}

let cacheCompletedExecution = (handler, executionKey, completed: completedExecution): unit => {
  let bytes = completed.result->terminalResultBytes
  switch bytes > maxCompletedExecutionBytes {
  | true => ()
  | false =>
    handler.completedExecutions.contents->Dict.set(
      executionKey,
      {
        fingerprint: completed.fingerprint,
        result: completed.result,
        bytes,
      },
    )
    handler.completedExecutionOrder :=
      handler.completedExecutionOrder.contents->Array.concat([executionKey])
    handler.completedExecutionBytes := handler.completedExecutionBytes.contents + bytes
    evictCompletedExecutions(handler)
  }
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

let sendTerminalResult = (handler, id, result): unit => {
  switch result {
  | Success(result) => sendResponse(handler, id, result)
  | Failure(_) => sendError(handler, id, Types.ErrorCode.internalError, "Tool execution failed")
  }
}

let completeExecution = (handler, executionKey, execution, result): unit => {
  switch handler.durableExecutions.contents->Dict.get(executionKey) {
  | Some(activeExecution) if activeExecution == execution =>
    handler.durableExecutions.contents->Dict.delete(executionKey)
    cacheCompletedExecution(handler, executionKey, {fingerprint: execution.fingerprint, result})
    execution.waiters.contents->Dict.forEach(id => {
      handler.activeRequests.contents->Dict.delete(requestKey(id))
      sendTerminalResult(handler, id, result)
    })
    execution.waiters := Dict.make()
  | Some(_) | None => ()
  }
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
    | _ => Error(MissingExecutionContextCapability("Invalid client capabilities"))
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
    detail->ignore
    Log.error("Missing required MCP client capability")
  }
}

let handleDiscover = (handler: mcpHandler<'server>, id, payload): unit => {
  switch payload->Decoders.parseSchema(Types.DiscoverRequest.schema) {
  | Error(_) => sendError(handler, id, Types.ErrorCode.invalidParams, "Invalid params")
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
      | _ =>
        Log.error("Server discovery failed")
        sendError(handler, id, Types.ErrorCode.internalError, "Server discovery failed")
      }
    }
  }
}

let handleToolsList = (handler: mcpHandler<'server>, id, payload): unit => {
  switch payload->Decoders.parseSchema(Types.ListToolsRequest.schema) {
  | Error(_) => sendError(handler, id, Types.ErrorCode.invalidParams, "Invalid params")
  | Ok(request) =>
    switch request.params.cursor {
    | Some(_) => sendError(handler, id, Types.ErrorCode.invalidParams, "Cursor is not supported")
    | None =>
      switch request.params._meta->validateRequestMeta {
      | Error(error) => sendMetaValidationError(handler, id, error)
      | Ok() =>
        try {
          let {serverInterface} = handler
          let result = serverInterface.buildToolsListResult(serverInterface.server)
          sendResponse(handler, id, encode(result, Types.ListToolsResult.schema))
        } catch {
        | _ =>
          Log.error("Tools list failed")
          sendError(handler, id, Types.ErrorCode.internalError, "Tools list failed")
        }
      }
    }
  }
}

let handleToolsCall = async (handler: mcpHandler<'server>, id, payload): unit => {
  switch payload->Decoders.parseSchema(Types.CallToolRequest.schema) {
  | Error(_) => sendError(handler, id, Types.ErrorCode.invalidParams, "Invalid params")
  | Ok(request) =>
    switch (request.params.inputResponses, request.params.requestState) {
    | (Some(_), _) =>
      sendError(handler, id, Types.ErrorCode.invalidParams, "inputResponses is not supported")
    | (_, Some(_)) =>
      sendError(handler, id, Types.ErrorCode.invalidParams, "requestState is not supported")
    | (None, None) =>
      switch request.params._meta->validateRequestMeta {
      | Error(error) => sendMetaValidationError(handler, id, error)
      | Ok() =>
        let context = try {
          Ok(request.params._meta->Types.ExecutionContextExtension.executionContext)
        } catch {
        | _ => Error("Invalid execution context")
        }
        switch context {
        | Error(_) =>
          sendError(handler, id, Types.ErrorCode.invalidParams, "Invalid execution context")
        | Ok({taskId, toolCallId}) =>
          let executionKey = durableKey(~taskId, ~toolCallId)
          let fingerprint = executionFingerprint(
            ~name=request.params.name,
            ~arguments=request.params.arguments,
          )
          switch handler.completedExecutions.contents->Dict.get(executionKey) {
          | Some(completed) if completed.fingerprint != fingerprint =>
            sendError(
              handler,
              id,
              Types.ModernErrorCode.invalidRequest,
              "Durable tool call replay payload does not match the original request",
            )
          | Some(completed) => sendTerminalResult(handler, id, completed.result)
          | None =>
            switch beginExecution(handler, ~executionKey, ~fingerprint, ~id) {
            | Error(ChangedReplay) =>
              sendError(
                handler,
                id,
                Types.ModernErrorCode.invalidRequest,
                "Durable tool call replay payload does not match the original request",
              )
            | Error(ActiveCapacityExceeded) =>
              sendError(handler, id, Types.ErrorCode.internalError, "Too many active MCP requests")
            | Error(DurableCapacityExceeded) =>
              sendError(
                handler,
                id,
                Types.ErrorCode.internalError,
                "Durable MCP execution capacity exceeded",
              )
            | Error(ResultUnavailable) =>
              sendError(
                handler,
                id,
                Types.ModernErrorCode.invalidRequest,
                "Durable tool call result is no longer available",
              )
            | Ok(Join) => ()
            | Ok(Start(execution)) =>
              try {
                let {serverInterface} = handler
                let result = await serverInterface.executeTool(
                  serverInterface.server,
                  ~name=request.params.name,
                  ~arguments=request.params.arguments,
                  ~taskId,
                  ~toolCallId,
                  ~onProgress=None,
                  ~signal=execution.controller.signal,
                )
                completeExecution(
                  handler,
                  executionKey,
                  execution,
                  Success(encode(result, Types.CallToolResult.schema)),
                )
              } catch {
              | _ =>
                Log.error("Tool execution failed")
                completeExecution(
                  handler,
                  executionKey,
                  execution,
                  Failure("Tool execution failed"),
                )
              }
            }
          }
        }
      }
    }
  }
}

let handleCancellation = (handler, payload) => {
  switch payload->Decoders.parseSchema(Types.CancelledNotification.schema) {
  | Error(_) => Log.error("Invalid MCP cancellation notification")
  | Ok(notification) =>
    let params =
      notification
      ->JSON.Decode.object
      ->Option.flatMap(fields => fields->Dict.get("params"))
      ->Option.getOrThrow
      ->S.parseOrThrow(~to=Types.CancelledNotificationParams.knownFieldsSchema)
    cancelRequest(handler, params.requestId)->ignore
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
  switch handler.active.contents {
  | false => ()
  | true =>
    switch parse(payload) {
    | Ok(Request({id, method})) =>
      switch (handler.activeRequests.contents->Dict.has(requestKey(id)), method) {
      | (true, _) => ()
      | (false, "server/discover") => handleDiscover(handler, id, payload)
      | (false, "tools/list") => handleToolsList(handler, id, payload)
      | (false, "tools/call") => await handleToolsCall(handler, id, payload)
      | (false, _) =>
        sendError(handler, id, Types.ErrorCode.methodNotFound, `Method not found: ${method}`)
      }
    | Ok(Notification({method: "notifications/cancelled"})) => handleCancellation(handler, payload)
    | Ok(Notification(_)) | Ok(Response) => ()
    | Error(_) =>
      switch payload->recoverRequestId {
      | Some(id) if handler.activeRequests.contents->Dict.has(requestKey(id)) => ()
      | Some(id) => sendError(handler, id, Types.ModernErrorCode.invalidRequest, "Invalid Request")
      | None => Log.error("Failed to parse MCP message")
      }
    }
  }
}

@@live
let makeHandler = (
  ~channel: Channel.t,
  ~serverInterface: Types.serverInterface<'server>,
  ~onMessage: option<(messageDirection, JSON.t) => unit>=?,
): mcpHandler<'server> => {
  serverInterface,
  channel,
  onMessage,
  activeRequests: ref(Dict.make()),
  durableExecutions: ref(Dict.make()),
  durableExecutionFingerprints: ref(Dict.make()),
  durableExecutionFingerprintBytes: ref(0),
  completedExecutions: ref(Dict.make()),
  completedExecutionOrder: ref([]),
  completedExecutionBytes: ref(0),
  active: ref(true),
  listenerRef: ref(None),
}

@@live
let attach = (
  ~channel: Channel.t,
  ~serverInterface: Types.serverInterface<'server>,
  ~onMessage: option<(messageDirection, JSON.t) => unit>=?,
): mcpHandler<'server> => {
  let handler = makeHandler(~channel, ~serverInterface, ~onMessage?)
  let listenerRef = channel->Channel.on(~event=#"mcp:message", ~callback=payload => {
    handleMessage(handler, payload)->ignore
  })
  handler.listenerRef := Some(listenerRef)
  handler
}

@@live
let detach = (handler: mcpHandler<'server>): unit => {
  switch handler.active.contents {
  | false => ()
  | true =>
    handler.active := false
    handler.listenerRef.contents->Option.forEach(listenerRef =>
      handler.channel->Channel.off(~event=#"mcp:message", ~ref=listenerRef)
    )
    handler.listenerRef := None
    handler.durableExecutions.contents
    ->Dict.valuesToArray
    ->Array.forEach(({controller}) => WebAPI.AbortController.abort(controller))
    handler.activeRequests := Dict.make()
    handler.durableExecutions := Dict.make()
    handler.durableExecutionFingerprints := Dict.make()
    handler.durableExecutionFingerprintBytes := 0
    handler.completedExecutions := Dict.make()
    handler.completedExecutionOrder := []
    handler.completedExecutionBytes := 0
  }
}
