// Connection state reducer for FrontmanProvider
// Manages ACP, Relay, and Session connection lifecycle
//
// Key insight: MCP handler attachment happens DURING session creation (before channel join),
// not as a separate post-hoc step. The reducer tracks whether prerequisites are met.

module ACP = FrontmanFrontmanClient.FrontmanClient__ACP
module Relay = FrontmanFrontmanClient.FrontmanClient__Relay
module MCPServer = FrontmanFrontmanClient.FrontmanClient__MCP__Server

// Connection states
type acpState =
  | ACPDisconnected
  | ACPConnecting
  | ACPConnected(ACP.connection)
  | ACPError(string)

type relayState =
  | RelayDisconnected
  | RelayConnecting
  | RelayConnected
  | RelayError(string)

type sessionState =
  | NoSession
  | SessionCreating
  | SessionActive(ACP.session)
  | SessionError(string)

type state = {
  acp: acpState,
  relay: relayState,
  session: sessionState,
  // Relay instance exists before connection completes - needed for MCPServer
  relayInstance: option<Relay.t>,
  // MCPServer created once relay instance exists
  mcpServer: option<MCPServer.t>,
}

// Actions
type action =
  | ACPConnectStart
  | ACPConnectSuccess(ACP.connection)
  | ACPConnectError(string)
  | RelayInstanceCreated(Relay.t)
  | RelayConnectStart
  | RelayConnectSuccess
  | RelayConnectError(string)
  | MCPServerCreated(MCPServer.t)
  | SessionCreateStart
  | SessionCreateSuccess(ACP.session)
  | SessionCreateError(string)
  | Cleanup

// Effects - side effects the reducer wants to trigger
type effect =
  | LogError(string)
  | LogInfo(string)
  | ConnectRelay(Relay.t)
  | CreateMCPServer(Relay.t)
  | DisconnectRelay(Relay.t)

let initialState: state = {
  acp: ACPDisconnected,
  relay: RelayDisconnected,
  session: NoSession,
  relayInstance: None,
  mcpServer: None,
}

module Selectors = {
  let isACPConnected = (state: state): bool => {
    switch state.acp {
    | ACPConnected(_) => true
    | _ => false
    }
  }

  let getACPConnection = (state: state): option<ACP.connection> => {
    switch state.acp {
    | ACPConnected(conn) => Some(conn)
    | _ => None
    }
  }

  let isRelayConnected = (state: state): bool => {
    switch state.relay {
    | RelayConnected => true
    | _ => false
    }
  }

  let hasActiveSession = (state: state): bool => {
    switch state.session {
    | SessionActive(_) => true
    | _ => false
    }
  }

  let getSession = (state: state): option<ACP.session> => {
    switch state.session {
    | SessionActive(s) => Some(s)
    | _ => None
    }
  }

  let canCreateSession = (state: state): bool => {
    switch (state.acp, state.relay, state.mcpServer, state.session) {
    | (ACPConnected(_), RelayConnected, Some(_), NoSession) => true
    | _ => false
    }
  }

  let getMCPServer = (state: state): option<MCPServer.t> => state.mcpServer

  // Derive user-facing connection state
  type connectionStatus =
    | Disconnected
    | Connecting
    | Connected
    | SessionActive(string)
    | Error(string)

  let getConnectionStatus = (state: state): connectionStatus => {
    switch (state.acp, state.relay, state.session) {
    // Session states take priority
    | (_, _, SessionActive(sess)) => SessionActive(sess.sessionId)
    | (_, _, SessionError(msg)) => Error(msg)
    // Errors
    | (ACPError(msg), _, _) => Error(msg)
    | (_, RelayError(msg), _) => Error(msg)
    // Connected only when both ACP and relay are connected
    | (ACPConnected(_), RelayConnected, _) => Connected
    // Still connecting if either is in progress
    | (ACPConnecting, _, _) => Connecting
    | (ACPConnected(_), RelayConnecting | RelayDisconnected, _) => Connecting
    // Disconnected
    | (ACPDisconnected, _, _) => Disconnected
    }
  }

  type mcpStatus =
    | MCPDisconnected
    | MCPConnecting
    | MCPReady
    | MCPError(string)

  let getMCPStatus = (state: state): mcpStatus => {
    switch state.relay {
    | RelayError(msg) => MCPError(msg)
    | RelayConnected => MCPReady
    | RelayConnecting => MCPConnecting
    | RelayDisconnected => MCPDisconnected
    }
  }
}

let reduce = (state: state, action: action): (state, array<effect>) => {
  switch (state, action) {
  // === ACP connection flow ===
  | ({acp: ACPDisconnected}, ACPConnectStart) => ({...state, acp: ACPConnecting}, [])

  | ({acp: ACPConnecting}, ACPConnectSuccess(conn)) => (
      {...state, acp: ACPConnected(conn)},
      [LogInfo("ACP connected")],
    )

  | ({acp: ACPConnecting}, ACPConnectError(msg)) => (
      {...state, acp: ACPError(msg)},
      [LogError(`ACP connect failed: ${msg}`)],
    )

  // === Relay lifecycle ===
  // Relay instance created - triggers MCPServer creation
  | ({relayInstance: None}, RelayInstanceCreated(relay)) => (
      {...state, relayInstance: Some(relay)},
      [CreateMCPServer(relay)],
    )

  | ({relay: RelayDisconnected, relayInstance: Some(relay)}, RelayConnectStart) => (
      {...state, relay: RelayConnecting},
      [ConnectRelay(relay)],
    )

  | ({relay: RelayConnecting}, RelayConnectSuccess) => (
      {...state, relay: RelayConnected},
      [LogInfo("Relay connected")],
    )

  // Relay error is non-fatal - MCP still works with client-only tools
  | ({relay: RelayConnecting}, RelayConnectError(msg)) => (
      {...state, relay: RelayError(msg)},
      [LogInfo(`Relay failed (non-fatal): ${msg}`)],
    )

  // === MCPServer lifecycle ===
  | ({mcpServer: None}, MCPServerCreated(server)) => (
      {...state, mcpServer: Some(server)},
      [LogInfo("MCPServer ready")],
    )

  // === Session lifecycle ===
  // Can only start session when ACP connected, relay connected, and MCPServer ready
  | (
      {acp: ACPConnected(_), relay: RelayConnected, mcpServer: Some(_), session: NoSession},
      SessionCreateStart,
    ) => (
      {...state, session: SessionCreating},
      [],
    )

  // Reject session creation if relay is not connected
  | ({relay: RelayDisconnected | RelayConnecting | RelayError(_)}, SessionCreateStart) => (
      state,
      [LogError("Cannot create session: Relay not connected")],
    )

  | ({session: SessionCreating}, SessionCreateSuccess(sess)) => (
      {...state, session: SessionActive(sess)},
      [LogInfo(`Session created: ${sess.sessionId}`)],
    )

  | ({session: SessionCreating}, SessionCreateError(msg)) => (
      {...state, session: SessionError(msg)},
      [LogError(`Session failed: ${msg}`)],
    )

  // === Cleanup ===
  | (_, Cleanup) =>
    let effects = switch state.relayInstance {
    | Some(relay) => [DisconnectRelay(relay)]
    | None => []
    }
    (
      {
        ...initialState,
        relayInstance: state.relayInstance,
        mcpServer: state.mcpServer,
      },
      effects,
    )

  // === Invalid transitions ===
  | ({acp: ACPConnecting | ACPConnected(_) | ACPError(_)}, ACPConnectStart) => (
      state,
      [LogError("Invalid: ACP connect already in progress or completed")],
    )

  | ({acp: ACPDisconnected | ACPConnected(_) | ACPError(_)}, ACPConnectSuccess(_)) => (
      state,
      [LogError("Invalid: unexpected ACP connect success")],
    )

  | ({relay: RelayConnecting | RelayConnected | RelayError(_)}, RelayConnectStart) => (
      state,
      [LogError("Invalid: Relay connect already in progress or completed")],
    )

  | ({acp: ACPDisconnected | ACPConnecting | ACPError(_)}, SessionCreateStart) => (
      state,
      [LogError("Cannot create session: ACP not connected")],
    )

  | ({mcpServer: None}, SessionCreateStart) => (
      state,
      [LogError("Cannot create session: MCPServer not ready")],
    )

  | ({session: SessionCreating | SessionActive(_) | SessionError(_)}, SessionCreateStart) => (
      state,
      [LogError("Cannot create session: session already exists")],
    )

  // Ignore other invalid transitions silently
  | _ => (state, [])
  }
}
