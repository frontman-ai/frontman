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

let pushReplyMessageSchema: S.t<JSON.t> = S.object(s => s.field("acp:message", S.json))

let parsePushReply = payload => {
  payload
  ->Decoders.parseSchema(pushReplyMessageSchema)
  ->Result.mapError(error => `Invalid ACP push reply envelope: ${error}`)
}

let sendRequest = (
  ~channel: Channel.t,
  ~state: ref<Client.state>,
  ~method: requestMethod,
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
        let idStr = Int.toString(id)
        let timer = ref(None)
        let pushRef = ref(None)
        let listeners = ref([])
        let finish = result => {
          timer.contents->Option.forEach(WebAPI.DomGlobal.clearTimeout)
          pushRef.contents->Option.forEach(Channel.cancelPush)
          listeners.contents->Array.forEach(((event, ref)) => channel->Channel.off(~event, ~ref))
          state := state.contents->Client.reduce(Client.ResponseReceived(id))
          resolve(result)
        }

        let pending: Client.pendingRequest = {
          resolve: json =>
            finish(parseResult(json)->Result.mapError(Client.requestErrorFromMessage)),
          reject: e => finish(Error(e)),
        }

        listeners :=
          [#phx_error, #phx_close]->Array.map(event => (
            event,
            channel->Channel.onWithRef(
              ~event,
              ~callback=_ => pending.reject(Client.requestErrorFromMessage(connectionLost)),
            ),
          ))
        state := state.contents->Client.reduce(Client.RequestSent(id, pending))
        timer :=
          Some(
            WebAPI.DomGlobal.setTimeout(~timeout=timeoutMs, ~handler=() => {
              pending.reject(
                Client.requestErrorFromMessage(
                  `Request ${method} timed out after ${Int.toString(timeoutMs)}ms`,
                ),
              )
            }),
          )

        let push =
          channel->Channel.push(~event=Constants.acpMessageEvent, ~payload, ~timeout=timeoutMs)
        pushRef := Some(push)
        switch state.contents.pendingRequests->Dict.get(idStr) {
        | None => Channel.cancelPush(push)
        | Some(_) => ()
        }
        push.receive(~status="ok", ~callback=reply => {
          switch state.contents.pendingRequests->Dict.get(idStr) {
          | None => ()
          | Some(_) =>
            switch parsePushReply(reply) {
            | Ok(message) => Client.handleResponse(state, message)
            | Error(error) => pending.reject(Client.requestErrorFromMessage(error))
            }
          }
        }).receive(~status="error", ~callback=_ =>
          pending.reject(Client.requestErrorFromMessage("ACP request failed"))
        )->ignore
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
  let params = Dict.make()
  params->Dict.set("sessionId", JSON.Encode.string(sessionId))
  sendRequest(
    ~channel,
    ~state,
    ~method=#"session/new",
    ~params=Some(JSON.Encode.object(params)),
    ~parseResult=Client.parseSessionNewResult,
  )
}

let sendPrompt = (
  ~channel: Channel.t,
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
  | None => Client.handleResponse(state, payload)
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
