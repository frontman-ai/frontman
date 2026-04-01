// ACP Protocol helpers
// Centralizes JSON-RPC request/response pattern and message handling

module Types = FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP
module Client = FrontmanClient__ACP__Client
module Channel = FrontmanClient__Phoenix__Channel
module JsonRpc = FrontmanAiFrontmanProtocol.FrontmanProtocol__JsonRpc
module Constants = FrontmanClient__Transport__Constants
module Log = FrontmanLogs.Logs.Make({
  let component = #ACP
})

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
  ~sessionId: string,
  ~onMessage: option<(messageDirection, JSON.t) => unit>,
): promise<result<Types.sessionNewResult, string>> => {
  let params = Dict.make()
  params->Dict.set("sessionId", JSON.Encode.string(sessionId))
  sendRequest(
    ~channel,
    ~state,
    ~method="session/new",
    ~params=Some(JSON.Encode.object(params)),
    ~parseResult=Client.parseSessionNewResult,
    ~onMessage,
  )
}

let sendPrompt = (
  ~channel: Channel.t,
  ~state: ref<Client.state>,
  ~sessionId: string,
  ~prompt: array<JSON.t>,
  ~_meta: option<JSON.t>,
  ~onMessage: option<(messageDirection, JSON.t) => unit>,
): promise<result<Types.promptResult, string>> => {
  let entries = [
    ("sessionId", JSON.Encode.string(sessionId)),
    ("prompt", JSON.Encode.array(prompt)),
  ]
  // Add _meta if provided
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
    ~onMessage,
  )
}

// ACP spec: session/cancel is a NOTIFICATION (no id, no response expected).
// The pending session/prompt request will be resolved by the agent with stopReason: "cancelled".
let sendCancel = (
  ~channel: Channel.t,
  ~sessionId: string,
  ~onMessage: option<(messageDirection, JSON.t) => unit>,
): unit => {
  let cancelParams = JSON.Encode.object(
    Dict.fromArray([("sessionId", JSON.Encode.string(sessionId))]),
  )
  let notification = JsonRpc.Notification.make(~method="session/cancel", ~params=Some(cancelParams))
  let payload = notification->JsonRpc.Notification.toJson
  onMessage->Option.forEach(cb => cb(Send, payload))
  channel->Channel.push(~event=Constants.acpMessageEvent, ~payload)->ignore
}

// ACP spec: session/retry_turn is a NOTIFICATION (no id, no response expected).
// Signals the server to retry the failed turn identified by retriedErrorId.
let sendRetryTurn = (
  ~channel: Channel.t,
  ~sessionId: string,
  ~retriedErrorId: string,
  ~onMessage: option<(messageDirection, JSON.t) => unit>,
): unit => {
  let params = JSON.Encode.object(
    Dict.fromArray([
      ("sessionId", JSON.Encode.string(sessionId)),
      ("retriedErrorId", JSON.Encode.string(retriedErrorId)),
    ]),
  )
  let notification = JsonRpc.Notification.make(~method="session/retry_turn", ~params=Some(params))
  let payload = notification->JsonRpc.Notification.toJson
  onMessage->Option.forEach(cb => cb(Send, payload))
  channel->Channel.push(~event=Constants.acpMessageEvent, ~payload)->ignore
}

// Extract method from JSON-RPC message (notifications have method, responses have id)
let getMethod = (payload: JSON.t): option<string> => {
  payload
  ->JSON.Decode.object
  ->Option.flatMap(obj => obj->Dict.get("method"))
  ->Option.flatMap(JSON.Decode.string)
}

// Message handler with proper error reporting (no silent swallowing)
// onUpdate receives (sessionId, update) per ACP session/update notification params
let handleIncomingMessage = (
  ~state: ref<Client.state>,
  ~onUpdate: option<(string, Types.sessionUpdate) => unit>,
  ~onMessage: option<(messageDirection, JSON.t) => unit>,
  ~onParseError: option<string => unit>,
  payload: JSON.t,
): unit => {
  onMessage->Option.forEach(cb => cb(Receive, payload))

  // Dispatch based on message type
  switch getMethod(payload) {
  | Some("session/update") =>
    // Session update notification - parse and dispatch with sessionId
    switch Client.parseSessionUpdateNotification(payload) {
    | Ok(notification) =>
      onUpdate->Option.forEach(cb => cb(notification.params.sessionId, notification.params.update))
    | Error(parseError) => onParseError->Option.forEach(cb => cb(parseError))
    }
  | Some("mcp_initialization_complete") => () // Known notification from MCP init handshake
  | Some(method) => Log.warning(`Received unhandled ACP notification: ${method}`)
  | None =>
    // No method field - must be a response
    state := Client.handleResponse(state.contents, payload)
  }
}

// Setup channel listener for ACP messages
let attachMessageHandler = (
  ~channel: Channel.t,
  ~state: ref<Client.state>,
  ~onUpdate: option<(string, Types.sessionUpdate) => unit>,
  ~onMessage: option<(messageDirection, JSON.t) => unit>,
  ~onParseError: option<string => unit>,
): unit => {
  channel->Channel.on(~event=Constants.acpMessageEvent, ~callback=payload =>
    handleIncomingMessage(~state, ~onUpdate, ~onMessage, ~onParseError, payload)
  )
}
