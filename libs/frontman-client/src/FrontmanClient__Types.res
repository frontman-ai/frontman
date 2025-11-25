// Core type definitions for FrontmanClient

type userMessage = {
  id: string,
  content: string,
  timestamp: Js.Date.t,
  metadata: Js.Dict.t<JSON.t>,
}

type agentResponse = {
  id: string,
  agentId: string,
  content: string,
  timestamp: Js.Date.t,
  metadata: Js.Dict.t<JSON.t>,
}

type agentSpawned = {
  id: string,
  agentId: string,
  config: Js.Dict.t<JSON.t>,
  timestamp: Js.Date.t,
}

type agentCompleted = {
  id: string,
  agentId: string,
  timestamp: Js.Date.t,
  result: option<JSON.t>,
}

type interaction =
  | UserMessage(userMessage)
  | AgentResponse(agentResponse)
  | AgentSpawned(agentSpawned)
  | AgentCompleted(agentCompleted)

type connectionState =
  | Connecting
  | Connected
  | Disconnected
  | Reconnecting

type streamToken = {
  agentId: string,
  token: string,
}

type onStreamToken = streamToken => unit

type onInteraction = interaction => unit

type onFinish = (~usage: option<Js.Dict.t<JSON.t>>) => unit

type onError = string => unit

type result<'ok, 'error> =
  | Ok('ok)
  | Error('error)
