type request = {
  headers: Dict.t<string>,
  body: JSON.t,
}

type counts = {
  discoveryCount: int,
  listCount: int,
  callCount: int,
  headerMismatchCount: int,
  authorizationAlphaCount: int,
  authorizationBetaCount: int,
  authorizationMutatedCount: int,
}

type t = {
  baseUrl: string,
  requests: array<request>,
  counts: unit => counts,
  controlledReceived: promise<unit>,
  controlledClientClosed: promise<unit>,
  respondControlled: unit => unit,
  waitForControlled: int => promise<unit>,
  respondControlledAt: int => unit,
  close: unit => promise<unit>,
}

@module("./FrontmanClient__MCP__TestServer.mjs")
external start: unit => promise<t> = "start"

@module("./FrontmanClient__MCP__TestServer.mjs")
external startScenario: string => promise<t> = "startScenario"
