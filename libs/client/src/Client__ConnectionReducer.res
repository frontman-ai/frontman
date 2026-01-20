// Connection state reducer for FrontmanProvider
// Manages ACP, Relay, and Session connection lifecycle
//
// Key insight: MCP handler attachment happens DURING session creation (before channel join),
// not as a separate post-hoc step. The reducer tracks whether prerequisites are met.

module ACP = FrontmanFrontmanClient.FrontmanClient__ACP
module Relay = FrontmanFrontmanClient.FrontmanClient__Relay
module MCPServer = FrontmanFrontmanClient.FrontmanClient__MCP__Server

// Configuration for initialization
type initConfig = {
  endpoint: string,
  tokenUrl: string,
  loginUrl: string,
  clientName: string,
  clientVersion: string,
  baseUrl: string,
  onACPMessage: (ACP.messageDirection, JSON.t) => unit,
  // Optional metadata to pass in ACP clientInfo (e.g., env key detection)
  metadata: option<JSON.t>,
}

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
  isSendingPrompt: bool,
  // Relay instance exists before connection completes - needed for MCPServer
  relayInstance: option<Relay.t>,
  // MCPServer created once relay instance exists
  mcpServer: option<MCPServer.t>,
  // AbortController for cancelling in-flight connections on cleanup
  abortController: option<WebAPI.EventAPI.abortController>,
}

// Initialization payload - includes pre-created instances
type initPayload = {
  config: initConfig,
  relay: Relay.t,
  mcpServer: MCPServer.t,
}

// Actions
type action =
  | Initialize(initPayload)
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
  | CreateSession({
      onUpdate: FrontmanFrontmanClient.FrontmanClient__ACP__Types.sessionUpdate => unit,
      onMcpMessage: (FrontmanFrontmanClient.FrontmanClient__MCP.messageDirection, JSON.t) => unit,
    })
  | SendPrompt({
      text: string,
      additionalBlocks: array<FrontmanFrontmanClient.FrontmanClient__ACP__Types.contentBlock>,
      onComplete: result<FrontmanFrontmanClient.FrontmanClient__ACP__Types.promptResult, string> => unit,
      metadata: option<JSON.t>,
    })
  | PromptSent
  | Cleanup

// Effects - side effects the reducer wants to trigger
type effect =
  | LogError(string)
  | LogInfo(string)
  | ConnectACP({config: ACP.config, signal: WebAPI.EventAPI.abortSignal})
  | ConnectRelay(Relay.t)
  | DisconnectRelay(Relay.t)
  | DisconnectACP(ACP.connection)
  | AbortConnections(WebAPI.EventAPI.abortController)
  | CreateSessionEffect({
      connection: ACP.connection,
      mcpServer: MCPServer.t,
      onUpdate: FrontmanFrontmanClient.FrontmanClient__ACP__Types.sessionUpdate => unit,
      onMcpMessage: (FrontmanFrontmanClient.FrontmanClient__MCP.messageDirection, JSON.t) => unit,
    })
  | SendPromptEffect({
      session: ACP.session,
      text: string,
      additionalBlocks: array<FrontmanFrontmanClient.FrontmanClient__ACP__Types.contentBlock>,
      onComplete: result<FrontmanFrontmanClient.FrontmanClient__ACP__Types.promptResult, string> => unit,
      metadata: option<JSON.t>,
    })

let initialState: state = {
  acp: ACPDisconnected,
  relay: RelayDisconnected,
  session: NoSession,
  isSendingPrompt: false,
  relayInstance: None,
  mcpServer: None,
  abortController: None,
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
  // === Initialize - single entry point for connection setup ===
  | ({acp: ACPDisconnected, relay: RelayDisconnected}, Initialize({config, relay, mcpServer})) =>
    let acpConfig = ACP.makeConfig(
      ~endpoint=config.endpoint,
      ~tokenUrl=config.tokenUrl,
      ~loginUrl=config.loginUrl,
      ~name=config.clientName,
      ~version=config.clientVersion,
      ~metadata=?config.metadata,
      ~onMessage=config.onACPMessage,
    )
    // Create AbortController to cancel connections on cleanup
    let abortController = WebAPI.AbortController.make()
    (
      {
        acp: ACPConnecting,
        relay: RelayConnecting,
        session: NoSession,
        isSendingPrompt: false,
        relayInstance: Some(relay),
        mcpServer: Some(mcpServer),
        abortController: Some(abortController),
      },
      [
        ConnectACP({config: acpConfig, signal: abortController.signal}),
        ConnectRelay(relay),
        LogInfo("Initializing connections..."),
      ],
    )

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
  // Legacy: Relay instance created (now handled by Initialize)
  | ({relayInstance: None}, RelayInstanceCreated(relay)) => (
      {...state, relayInstance: Some(relay)},
      [],
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

  | (
      {acp: ACPConnected(conn), relay: RelayConnected, mcpServer: Some(mcpServer), session: NoSession},
      CreateSession({onUpdate, onMcpMessage}),
    ) => (
      {...state, session: SessionCreating},
      [CreateSessionEffect({connection: conn, mcpServer, onUpdate, onMcpMessage})],
    )

  | ({session: SessionActive(session), isSendingPrompt: false}, SendPrompt({text, additionalBlocks, onComplete, metadata})) => (
      {...state, isSendingPrompt: true},
      [SendPromptEffect({session, text, additionalBlocks, onComplete, metadata})],
    )

  | ({isSendingPrompt: true}, PromptSent) => (
      {...state, isSendingPrompt: false},
      [],
    )

  | ({isSendingPrompt: true}, SendPrompt(_)) => (
      state,
      [LogError("Cannot send prompt: already sending")],
    )

  | ({session: NoSession | SessionCreating | SessionError(_)}, SendPrompt(_)) => (
      state,
      [LogError("Cannot send prompt: no active session")],
    )

  | (_, CreateSession(_)) => (
      state,
      [LogError("Cannot create session: not ready")],
    )

  // === Cleanup ===
  | (_, Cleanup) =>
    let abortEffects = switch state.abortController {
    | Some(controller) => [AbortConnections(controller)]
    | None => []
    }
    let relayEffects = switch state.relayInstance {
    | Some(relay) => [DisconnectRelay(relay)]
    | None => []
    }
    let acpEffects = switch state.acp {
    | ACPConnected(conn) => [DisconnectACP(conn)]
    | _ => []
    }
    (initialState, Array.flat([abortEffects, relayEffects, acpEffects]))

  // === Invalid transitions ===
  | (_, Initialize(_)) => (
      state,
      [LogError("Invalid: already initialized")],
    )

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

// StateReducer.Interface implementation
let name = "ConnectionReducer"

// Alias for StateReducer compatibility
let next = reduce

// Effect handler - executed in useEffect, not during dispatch
// This receives current state and dispatch, so async callbacks can safely dispatch
let handleEffect = (effect: effect, _state: state, dispatch: action => unit) => {
  switch effect {
  | LogError(msg) => Console.error(`[FrontmanProvider] ${msg}`)
  | LogInfo(msg) => Console.log(`[FrontmanProvider] ${msg}`)
  | DisconnectRelay(relay) => Relay.disconnect(relay)
  | DisconnectACP(_) => ()
  | AbortConnections(controller) =>
    Console.log("[FrontmanProvider] Aborting in-flight connections")
    WebAPI.AbortController.abort(controller)
  | ConnectACP({config, signal}) =>
    let connect = async () => {
      let result = await ACP.connect(config, ~signal)
      switch result {
      | Ok(conn) => dispatch(ACPConnectSuccess(conn))
      | Error(err) =>
        // Don't dispatch error for aborted connections - component is unmounting
        if signal.aborted {
          Console.log("[FrontmanProvider] ACP connection aborted (cleanup)")
        } else {
          switch err {
          | ACP.AuthRequired({loginUrl}) =>
            // Redirect to login with return_to param
            let currentUrl =
              WebAPI.Global.window->WebAPI.Window.location->WebAPI.Location.href
            let encodeURIComponent: string => string = %raw(`encodeURIComponent`)
            let returnTo = encodeURIComponent(currentUrl)
            let fullUrl = `${loginUrl}?return_to=${returnTo}`
            WebAPI.Global.window->WebAPI.Window.location->WebAPI.Location.assign(fullUrl)
          | ACP.ConnectionFailed(msg) => dispatch(ACPConnectError(msg))
          }
        }
      }
    }
    connect()->ignore
  | ConnectRelay(relay) =>
    let connect = async () => {
      let result = await Relay.connect(relay)
      switch result {
      | Ok() =>
        dispatch(RelayConnectSuccess)
        switch Relay.getState(relay) {
        | Connected({tools, serverInfo}) =>
          Console.log3(
            `[FrontmanProvider] ${serverInfo.name} v${serverInfo.version} - ${tools
              ->Array.length
              ->Int.toString} relay tools available`,
            tools->Array.map(t => t.name),
            (),
          )
        | _ => ()
        }
      | Error(err) => dispatch(RelayConnectError(err))
      }
    }
    connect()->ignore
  | CreateSessionEffect({connection, mcpServer, onUpdate, onMcpMessage}) =>
    let create = async () => {
      let mcpServerInterface = MCPServer.toInterface(mcpServer)
      let result = await ACP.createSession(
        connection,
        ~onUpdate,
        ~mcpServerInterface,
        ~onMcpMessage,
      )
      switch result {
      | Ok(sess) =>
        dispatch(SessionCreateSuccess(sess))
        Console.log2("[ConnectionReducer] Session created:", sess.sessionId)
      | Error(err) =>
        dispatch(SessionCreateError(err))
        Console.error2("[ConnectionReducer] Session creation failed:", err)
      }
    }
    create()->ignore
  | SendPromptEffect({session, text, additionalBlocks, onComplete, metadata}) =>
    let send = async () => {
      let result = await ACP.sendPrompt(session, text, ~additionalBlocks, ~metadata)
      dispatch(PromptSent)
      onComplete(result)
    }
    send()->ignore
  }
}
