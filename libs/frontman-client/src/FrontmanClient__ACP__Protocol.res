module Types = FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP
module ContentBlock = FrontmanAiFrontmanProtocol.FrontmanProtocol__ContentBlock
module Client = FrontmanClient__ACP__Client
module Channel = FrontmanClient__Phoenix__Channel
module JsonRpc = FrontmanAiFrontmanProtocol.FrontmanProtocol__JsonRpc
module Constants = FrontmanClient__Transport__Constants
module Decoders = FrontmanClient__Decoders
module Log = FrontmanLogs.Logs.Make({
  let component = #ACP
})

type requestMethod = [#initialize | #"session/new" | #"session/load" | #"session/prompt"]

let requestTimeoutMs = 120000
let connectionLost = "Connection lost. The agent may still be running. Reload to reconnect."

let maxMessageBytes = 8_000_000
let envelopeReserveBytes = 4096
let promptSizeError = "Prompt and attachments are too large. Remove images or shorten the text and try again (8 MB message limit)."
let unsupportedAttachmentError = "Documents, including PDFs, are not supported. Paste the document text or attach PNG, JPEG, GIF, or WebP images instead."

let validateMessageSize = (payload, ~reservedBytes=0) =>
  switch payload->JSON.stringify->FrontmanBindings.WebStreams.utf8ByteSize <=
    maxMessageBytes - reservedBytes {
  | true => Ok()
  | false => Error(promptSizeError)
  }

@@live
let validatePrompt = (~text, ~additionalBlocks, ~_meta) => {
  switch additionalBlocks->Array.some(block =>
    switch block {
    | ContentBlock.EmbeddedResource({resource: BlobResourceContents({mimeType}), _}) =>
      switch mimeType {
      | Some("image/png" | "image/jpeg" | "image/gif" | "image/webp") => false
      | _ => true
      }
    | ContentBlock.EmbeddedResource({resource: TextResourceContents(_), _meta, _}) =>
      _meta->Option.flatMap(meta =>
        meta->S.decodeOrThrow(
          ~from=S.json,
          ~to=S.object(s => s.field("user_image", S.option(S.bool))),
        )
      ) == Some(true)
    | _ => false
    }
  ) {
  | true => Error(unsupportedAttachmentError)
  | false =>
    let prompt =
      Array.concat(
        [ContentBlock.TextContent({text, _meta: None, annotations: None})],
        additionalBlocks,
      )->Array.map(block => block->S.decodeOrThrow(~from=ContentBlock.schema, ~to=S.json))
    let payload = JSON.Encode.object(
      Dict.fromArray([
        ("prompt", JSON.Encode.array(prompt)),
        ("_meta", _meta->Option.getOr(JSON.Encode.null)),
      ]),
    )
    validateMessageSize(payload, ~reservedBytes=envelopeReserveBytes)
  }
}

@get external channelTopic: Channel.t => string = "topic"

let validateRequest = (~channel, payload) => {
  let envelope = JSON.Encode.array([
    JSON.Encode.string("9007199254740991"),
    JSON.Encode.string("9007199254740991"),
    JSON.Encode.string(channel->channelTopic),
    JSON.Encode.string("acp:message"),
    payload,
  ])
  validateMessageSize(envelope)
}

let pushReplyMessageSchema = S.object(s => s.field("acp:message", JsonRpc.Response.schema))

let parsePushReply = (~id, ~parseResult, payload) => {
  payload
  ->Decoders.parseSchema(pushReplyMessageSchema)
  ->Result.mapError(error => Client.requestErrorFromMessage(`Invalid ACP push reply: ${error}`))
  ->Result.flatMap(response =>
    switch response->JsonRpc.Response.id->Option.flatMap(JsonRpc.Id.toInt) == Some(id) {
    | false => Error(Client.requestErrorFromMessage("Mismatched ACP response id"))
    | true =>
      switch response->JsonRpc.Response.error {
      | Some(error) =>
        Error(
          Client.requestErrorWithCode(
            ~code=error->JsonRpc.RpcError.code,
            ~message=error->JsonRpc.RpcError.message,
          ),
        )
      | None =>
        response
        ->JsonRpc.Response.result
        ->Option.getOrThrow
        ->parseResult
        ->Result.mapError(Client.requestErrorFromMessage)
      }
    }
  )
}

let sendRequest = (
  ~channel: Channel.t,
  ~state: ref<Client.state>,
  ~method: requestMethod,
  ~controlChannel: option<Channel.t>=?,
  ~params: option<JSON.t>,
  ~timeoutMs: int=requestTimeoutMs,
  ~parseResult: JSON.t => result<'a, string>,
): promise<result<'a, Client.requestError>> => {
  switch Channel.canPush(channel) &&
  (method == #initialize || Client.isInitialized(state.contents)) {
  | false => Promise.resolve(Error(Client.requestErrorFromMessage("ACP connection is not ready")))
  | true =>
    let method = (method :> string)
    let id = state.contents.currentId + 1
    let request = JsonRpc.Request.make(~id=JsonRpc.Id.fromInt(id), ~method, ~params)
    let payload = request->JsonRpc.Request.toJson
    switch validateRequest(~channel, payload) {
    | Error(error) => Promise.resolve(Error(Client.requestErrorFromMessage(error)))
    | Ok() =>
      Promise.make((resolve, _) => {
        let settled = ref(false)
        let pushRef = ref(None)
        let listeners = ref([])
        let finish = result => {
          switch settled.contents {
          | true => ()
          | false =>
            settled := true
            listeners.contents->Array.forEach(((owner, close, error)) => {
              owner->Channel.off(~event=#phx_close, ~ref=close)
              owner->Channel.off(~event=#phx_error, ~ref=error)
            })
            pushRef.contents->Option.forEach(Channel.cancelPush)
            resolve(result)
          }
        }
        let fail = message => finish(Error(Client.requestErrorFromMessage(message)))
        let closed = _ => fail(connectionLost)
        let owners = switch controlChannel {
        | Some(control) if control !== channel => [channel, control]
        | _ => [channel]
        }
        listeners :=
          owners->Array.map(owner => (
            owner,
            owner->Channel.onWithRef(~event=#phx_close, ~callback=closed),
            owner->Channel.onWithRef(~event=#phx_error, ~callback=closed),
          ))
        state := {...state.contents, currentId: id}
        let push =
          channel->Channel.push(~event=Constants.acpMessageEvent, ~payload, ~timeout=timeoutMs)
        pushRef := Some(push)
        switch settled.contents {
        | true => Channel.cancelPush(push)
        | false =>
          push.receive(~status="ok", ~callback=reply =>
            finish(parsePushReply(~id, ~parseResult, reply))
          ).receive(~status="error", ~callback=_ =>
            fail(`Request ${method} failed`)
          ).receive(~status="timeout", ~callback=_ =>
            fail(`Request ${method} timed out after ${Int.toString(timeoutMs)}ms`)
          )->ignore
        }
      })
    }
  }
}

let sendInitialize = (
  ~channel: Channel.t,
  ~state: ref<Client.state>,
  ~clientConfig: Client.config,
): promise<result<Types.initializeResult, Client.requestError>> => {
  let params = Client.buildInitializeParams(clientConfig)
  sendRequest(
    ~channel,
    ~state,
    ~method=#initialize,
    ~params=Some(params),
    ~parseResult=Client.parseInitializeResult,
  )
}

let sendSessionNew = (~channel: Channel.t, ~state: ref<Client.state>, ~sessionId: string): promise<
  result<Types.sessionNewResult, Client.requestError>,
> => {
  let capability = switch state.contents.acpState {
  | Initialized(result) =>
    switch result.agentCapabilities->Option.flatMap(capabilities => capabilities._meta) {
    | None => Ok(None)
    | Some(metadata) => metadata->Decoders.parseSchema(Types.sessionIdCapabilityMetadataSchema)
    }
  | _ => Ok(None)
  }
  switch capability {
  | Error(message) => Promise.resolve(Error(Client.requestErrorFromMessage(message)))
  | Ok(Some(true)) =>
    let params: Types.sessionNewParams = {
      cwd: "/",
      mcpServers: [],
      additionalDirectories: None,
      _meta: Some({sessionId: Some(sessionId)}),
    }
    let params = params->S.decodeOrThrow(~from=Types.sessionNewParamsSchema, ~to=S.json)
    sendRequest(
      ~channel,
      ~state,
      ~method=#"session/new",
      ~params=Some(params),
      ~parseResult=Client.parseSessionNewResult,
    )
  | Ok(_) =>
    Promise.resolve(
      Error(
        Client.requestErrorFromMessage("Agent does not support Frontman retry-safe session IDs"),
      ),
    )
  }
}

let sendPrompt = (
  ~channel: Channel.t,
  ~controlChannel: option<Channel.t>=?,
  ~state: ref<Client.state>,
  ~sessionId: string,
  ~prompt: array<JSON.t>,
  ~_meta: option<JSON.t>,
): promise<result<Types.promptResult, Client.requestError>> => {
  let entries = [
    ("sessionId", JSON.Encode.string(sessionId)),
    ("prompt", JSON.Encode.array(prompt)),
  ]
  let entries = switch _meta {
  | Some(meta) => Array.concat(entries, [("_meta", meta)])
  | None => entries
  }
  let promptParams = JSON.Encode.object(Dict.fromArray(entries))
  sendRequest(
    ~channel,
    ~state,
    ~method=#"session/prompt",
    ~controlChannel?,
    ~params=Some(promptParams),
    ~parseResult=Client.parsePromptResult,
  )
}

let sendCancel = (~channel: Channel.t, ~sessionId: string): unit => {
  switch Channel.canPush(channel) {
  | false => failwith("Cannot cancel: channel is disconnected")
  | true => ()
  }
  let params = JSON.Encode.object(Dict.fromArray([("sessionId", JSON.Encode.string(sessionId))]))
  let notification = JsonRpc.Notification.make(~method="session/cancel", ~params=Some(params))
  let payload = notification->JsonRpc.Notification.toJson
  channel->Channel.push(~event=Constants.acpMessageEvent, ~payload)->ignore
}

let sendSessionCommand = (
  ~channel: Channel.t,
  ~sessionId: string,
  ~command: string,
  ~argument: option<(string, JSON.t)>,
): unit => {
  switch Channel.canPush(channel) {
  | false => failwith("Cannot send session command: channel is disconnected")
  | true => ()
  }
  let params = [
    ("sessionId", JSON.Encode.string(sessionId)),
    ("command", JSON.Encode.string(command)),
  ]
  let params = switch argument {
  | Some(argument) => Array.concat(params, [argument])
  | None => params
  }
  let notification = JsonRpc.Notification.make(
    ~method="session/command",
    ~params=Some(JSON.Encode.object(Dict.fromArray(params))),
  )
  let payload = notification->JsonRpc.Notification.toJson
  channel->Channel.push(~event=Constants.acpMessageEvent, ~payload)->ignore
}

let getMethod = (payload: JSON.t): option<string> => {
  payload
  ->JSON.Decode.object
  ->Option.flatMap(obj => obj->Dict.get("method"))
  ->Option.flatMap(JSON.Decode.string)
}

let handleIncomingMessage = (
  ~state: ref<Client.state>,
  ~onUpdate: option<(string, Types.sessionUpdate) => unit>,
  ~onParseError: option<string => unit>,
  payload: JSON.t,
): unit => {
  switch getMethod(payload) {
  | Some("session/update") =>
    switch Client.parseSessionUpdateNotification(state.contents, payload) {
    | Ok(notification) =>
      onUpdate->Option.forEach(cb => {
        try {
          cb(notification.params.sessionId, notification.params.update)
        } catch {
        | Failure(error) => onParseError->Option.forEach(cb => cb(error))
        | exn =>
          let error =
            exn
            ->JsExn.fromException
            ->Option.flatMap(JsExn.message)
            ->Option.getOr("Session update handler failed")
          onParseError->Option.forEach(cb => cb(error))
        }
      })
    | Error(parseError) => onParseError->Option.forEach(cb => cb(parseError))
    }
  | Some(method) => Log.warning(`Received unhandled ACP notification: ${method}`)
  | None => Log.error("Received ACP notification without a method")
  }
}

let attachMessageHandler = (
  ~channel: Channel.t,
  ~state: ref<Client.state>,
  ~onUpdate: option<(string, Types.sessionUpdate) => unit>,
  ~onParseError: option<string => unit>,
): unit => {
  channel->Channel.on(~event=Constants.acpMessageEvent, ~callback=payload =>
    handleIncomingMessage(~state, ~onUpdate, ~onParseError, payload)
  )
}
