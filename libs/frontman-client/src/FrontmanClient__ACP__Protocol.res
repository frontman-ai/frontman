module Types = FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP
module Client = FrontmanClient__ACP__Client
module Channel = FrontmanClient__Phoenix__Channel
module JsonRpc = FrontmanAiFrontmanProtocol.FrontmanProtocol__JsonRpc
module Constants = FrontmanClient__Transport__Constants
module Log = FrontmanLogs.Logs.Make({
  let component = #ACP
})

let sendRequest = (
  ~channel: Channel.t,
  ~state: ref<Client.state>,
  ~method: string,
  ~params: option<JSON.t>,
  ~parseResult: JSON.t => result<'a, string>,
): promise<result<'a, string>> => {
  Promise.make((resolve, _) => {
    let id = state.contents.currentId + 1
    let request = JsonRpc.Request.make(~id=JsonRpc.Id.fromInt(id), ~method, ~params)

    let pending: Client.pendingRequest = {
      resolve: json => {
        switch parseResult(json) {
        | Ok(result) => resolve(Ok(result))
        | Error(e) => resolve(Error(e))
        }
      },
      reject: e => resolve(Error(e)),
    }

    state := state.contents->Client.reduce(Client.RequestSent(id, pending))

    let payload = request->JsonRpc.Request.toJson
    channel->Channel.push(~event=Constants.acpMessageEvent, ~payload)->ignore
  })
}

let sendInitialize = (
  ~channel: Channel.t,
  ~state: ref<Client.state>,
  ~clientConfig: Client.config,
): promise<result<Types.initializeResult, string>> => {
  let params = Client.buildInitializeParams(clientConfig)
  sendRequest(
    ~channel,
    ~state,
    ~method="initialize",
    ~params=Some(params),
    ~parseResult=Client.parseInitializeResult,
  )
}

let sendSessionNew = (~channel: Channel.t, ~state: ref<Client.state>, ~sessionId: string): promise<
  result<Types.sessionNewResult, string>,
> => {
  let params = Dict.make()
  params->Dict.set("sessionId", JSON.Encode.string(sessionId))
  sendRequest(
    ~channel,
    ~state,
    ~method="session/new",
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
): promise<result<Types.promptResult, string>> => {
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
    ~method="session/prompt",
    ~params=Some(promptParams),
    ~parseResult=Client.parsePromptResult,
  )
}

let sendCancel = (~channel: Channel.t, ~sessionId: string): unit => {
  let cancelParams = JSON.Encode.object(
    Dict.fromArray([("sessionId", JSON.Encode.string(sessionId))]),
  )
  let notification = JsonRpc.Notification.make(~method="session/cancel", ~params=Some(cancelParams))
  let payload = notification->JsonRpc.Notification.toJson
  channel->Channel.push(~event=Constants.acpMessageEvent, ~payload)->ignore
}

let sendRetryTurn = (~channel: Channel.t, ~sessionId: string, ~retriedErrorId: string): unit => {
  let params = JSON.Encode.object(
    Dict.fromArray([
      ("sessionId", JSON.Encode.string(sessionId)),
      ("retriedErrorId", JSON.Encode.string(retriedErrorId)),
    ]),
  )
  let notification = JsonRpc.Notification.make(~method="session/retry_turn", ~params=Some(params))
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
  | None => state := Client.handleResponse(state.contents, payload)
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
