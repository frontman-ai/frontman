type t = {
  baseUrl: string,
  requestCount: unit => int,
  originalPostCount: unit => int,
  oauthDiscoveryCount: unit => int,
  oauthTokenCount: unit => int,
  oauthRegistrationCount: unit => int,
  close: unit => promise<unit>,
}

@module("./FrontmanClient__MCP__OAuthAbsenceTestServer.mjs")
external start: unit => promise<t> = "start"
