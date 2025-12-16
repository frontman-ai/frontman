// ACP Protocol helpers
// Centralizes JSON-RPC request/response pattern and message handling

module Types = FrontmanClient__ACP__Types
module Client = FrontmanClient__ACP__Client
module Channel = FrontmanClient__Phoenix__Channel
module JsonRpc = FrontmanClient__JsonRpc
module Constants = FrontmanClient__Transport__Constants

type messageDirection = Send | Receive

// Generic request sender - eliminates duplication across sendInitialize, createSession, sendPrompt
let sendRequest = (
  ~channel: Channel.t,
  ~state: ref<Client.state>,
  ~method: string,
  ~params: option<JSON.t>,
  ~parseResult: JSON.t => result<'a, string>,
  ~onMessage: option<(messageDirection, JSON.t) => unit>,
): promise<result<'a, string>> => {
  Promise.make((resolve, _) => {
    let id = state.contents.currentId + 1
    let request = JsonRpc.Request.make(~id, ~method, ~params)

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
    onMessage->Option.forEach(cb => cb(Send, payload))
    channel->Channel.push(~event=Constants.acpMessageEvent, ~payload)->ignore
  })
}

// Typed wrappers for specific ACP methods

let sendInitialize = (
  ~channel: Channel.t,
  ~state: ref<Client.state>,
  ~clientConfig: Client.config,
  ~onMessage: option<(messageDirection, JSON.t) => unit>,
): promise<result<Types.initializeResult, string>> => {
  let params = Client.buildInitializeParams(clientConfig)
  sendRequest(
    ~channel,
    ~state,
    ~method="initialize",
    ~params=Some(params),
    ~parseResult=Client.parseInitializeResult,
    ~onMessage,
  )
}

let sendSessionNew = (
  ~channel: Channel.t,
  ~state: ref<Client.state>,
  ~onMessage: option<(messageDirection, JSON.t) => unit>,
): promise<result<Types.sessionNewResult, string>> => {
  sendRequest(
    ~channel,
    ~state,
    ~method="session/new",
    ~params=Some(JSON.Encode.object(Dict.make())),
    ~parseResult=Client.parseSessionNewResult,
    ~onMessage,
  )
}

let sendPrompt = (
  ~channel: Channel.t,
  ~state: ref<Client.state>,
  ~sessionId: string,
  ~prompt: array<JSON.t>,
  ~onMessage: option<(messageDirection, JSON.t) => unit>,
): promise<result<Types.promptResult, string>> => {
  let promptParams = JSON.Encode.object(
    Dict.fromArray([
      ("sessionId", JSON.Encode.string(sessionId)),
      ("prompt", JSON.Encode.array(prompt)),
    ]),
  )
  sendRequest(
    ~channel,
    ~state,
    ~method="session/prompt",
    ~params=Some(promptParams),
    ~parseResult=Client.parsePromptResult,
    ~onMessage,
  )
}

// Message handler with proper error reporting (no silent swallowing)
let handleIncomingMessage = (
  ~state: ref<Client.state>,
  ~onUpdate: option<Types.sessionUpdate => unit>,
  ~onMessage: option<(messageDirection, JSON.t) => unit>,
  ~onParseError: option<string => unit>,
  payload: JSON.t,
): unit => {
  onMessage->Option.forEach(cb => cb(Receive, payload))

  // Try parsing as session update notification first
  switch Client.parseSessionUpdateNotification(payload) {
  | Ok(notification) => onUpdate->Option.forEach(cb => cb(notification.params.update))
  | Error(notificationError) =>
    // Not a notification - try handling as response
    let prevState = state.contents
    state := Client.handleResponse(prevState, payload)

    // If state unchanged and we have onUpdate, it might be a malformed message
    if state.contents === prevState && Option.isSome(onUpdate) {
      onParseError->Option.forEach(cb => cb(notificationError))
    }
  }
}

// Setup channel listener for ACP messages
let attachMessageHandler = (
  ~channel: Channel.t,
  ~state: ref<Client.state>,
  ~onUpdate: option<Types.sessionUpdate => unit>,
  ~onMessage: option<(messageDirection, JSON.t) => unit>,
  ~onParseError: option<string => unit>,
): unit => {
  channel->Channel.on(
    ~event=Constants.acpMessageEvent,
    ~callback=payload =>
      handleIncomingMessage(~state, ~onUpdate, ~onMessage, ~onParseError, payload),
  )
}
