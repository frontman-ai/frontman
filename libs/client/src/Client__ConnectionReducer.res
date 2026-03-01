// Connection state reducer for FrontmanProvider
// Manages ACP, Relay, and Session connection lifecycle
//
// Key insight: MCP handler attachment happens DURING session creation (before channel join),
// not as a separate post-hoc step. The reducer tracks whether prerequisites are met.

module Log = FrontmanLogs.Logs.Make({
  let component = #ConnectionReducer
})

module ACP = FrontmanAiFrontmanClient.FrontmanClient__ACP
module Relay = FrontmanAiFrontmanClient.FrontmanClient__Relay
module MCPServer = FrontmanAiFrontmanClient.FrontmanClient__MCP__Server
module Channel = FrontmanAiFrontmanClient.FrontmanClient__Phoenix__Channel

// Configuration for initialization
type initConfig = {
  endpoint: string,
  tokenUrl: string,
  loginUrl: string,
  clientName: string,
  clientVersion: string,
  baseUrl: string,
  onACPMessage: (ACP.messageDirection, JSON.t) => unit,
  // Metadata to pass in ACP clientInfo (framework, env key detection, etc.)
  metadata: JSON.t,
  // Called when the server pushes a title update for a task
  onTitleUpdated: option<(string, string) => unit>,
}

// Connection states
type acpState =
  | ACPDisconnected
  | ACPConnecting
  | ACPConnected(ACP.connection)
  | ACPAuthRequired({loginUrl: string})
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
      onUpdate: (string, FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP.sessionUpdate) => unit,
      onMcpMessage: (FrontmanAiFrontmanClient.FrontmanClient__MCP.messageDirection, JSON.t) => unit,
      onComplete: result<string, string> => unit,
    })
  | SendPrompt({
      text: string,
      additionalBlocks: array<FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP.contentBlock>,
      onComplete: result<FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP.promptResult, string> => unit,
      metadata: option<JSON.t>,
    })
  | PromptSent
  | CancelPrompt
  | LoadTask({
      taskId: string,
      needsHistory: bool,
      onUpdate: (string, FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP.sessionUpdate) => unit,
      onMcpMessage: (FrontmanAiFrontmanClient.FrontmanClient__MCP.messageDirection, JSON.t) => unit,
      onComplete: result<unit, string> => unit,
    })
  | DeleteSession({taskId: string, onComplete: result<unit, string> => unit})
  | ClearSession
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
      onUpdate: (string, FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP.sessionUpdate) => unit,
      onMcpMessage: (FrontmanAiFrontmanClient.FrontmanClient__MCP.messageDirection, JSON.t) => unit,
      onComplete: result<string, string> => unit,
    })
  | SendPromptEffect({
      session: ACP.session,
      text: string,
      additionalBlocks: array<FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP.contentBlock>,
      onComplete: result<FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP.promptResult, string> => unit,
      metadata: option<JSON.t>,
    })
  | CancelPromptEffect({session: ACP.session})
  | FetchSessionsEffect(ACP.connection)
  | LoadTaskEffect({
      connection: ACP.connection,
      mcpServer: MCPServer.t,
      taskId: string,
      needsHistory: bool,
      onUpdate: (string, FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP.sessionUpdate) => unit,
      onMcpMessage: (FrontmanAiFrontmanClient.FrontmanClient__MCP.messageDirection, JSON.t) => unit,
      onComplete: result<unit, string> => unit,
    })
  | DeleteSessionEffect({connection: ACP.connection, taskId: string, onComplete: result<unit, string> => unit})
  | CleanupSessionEffect({session: ACP.session})

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
    // Auth required — surface as Disconnected so UI can check authRedirectUrl
    | (ACPAuthRequired(_), _, _) => Disconnected
    // Disconnected
    | (ACPDisconnected, _, _) => Disconnected
    }
  }

  // Returns the auth redirect URL when ACP connection requires authentication
  let getAuthRedirectUrl = (state: state): option<string> => {
    switch state.acp {
    | ACPAuthRequired({loginUrl}) => Some(loginUrl)
    | _ => None
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
      ~metadata=config.metadata,
      ~onMessage=config.onACPMessage,
      ~onTitleUpdated=?config.onTitleUpdated,
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
      [LogInfo("ACP connected"), FetchSessionsEffect(conn)],
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
      {...state, session: SessionActive(sess), isSendingPrompt: false},
      [LogInfo(`Session created: ${sess.sessionId}`)],
    )

  // Handle SessionCreateSuccess from NoSession - happens when LoadTaskEffect completes
  | ({session: NoSession}, SessionCreateSuccess(sess)) => (
      {...state, session: SessionActive(sess), isSendingPrompt: false},
      [LogInfo(`Session loaded: ${sess.sessionId}`)],
    )

  // Handle SessionCreateSuccess when switching tasks - old session already cleaned up in effect handler
  | ({session: SessionActive(_)}, SessionCreateSuccess(sess)) => (
      {...state, session: SessionActive(sess), isSendingPrompt: false},
      [LogInfo(`Session switched: ${sess.sessionId}`)],
    )

  // Handle SessionCreateSuccess after previous failure - recovery
  | ({session: SessionError(_)}, SessionCreateSuccess(sess)) => (
      {...state, session: SessionActive(sess), isSendingPrompt: false},
      [LogInfo(`Session recovered: ${sess.sessionId}`)],
    )

  | ({session: SessionCreating}, SessionCreateError(msg)) => (
      {...state, session: SessionError(msg)},
      [LogError(`Session failed: ${msg}`)],
    )

  | (
      {acp: ACPConnected(conn), relay: RelayConnected, mcpServer: Some(mcpServer), session: NoSession},
      CreateSession({onUpdate, onMcpMessage, onComplete}),
    ) => (
      {...state, session: SessionCreating},
      [CreateSessionEffect({connection: conn, mcpServer, onUpdate, onMcpMessage, onComplete})],
    )

  | ({session: SessionActive(session), isSendingPrompt: false}, SendPrompt({text, additionalBlocks, onComplete, metadata})) =>
    (
      {...state, isSendingPrompt: true},
      [SendPromptEffect({session, text, additionalBlocks, onComplete, metadata})],
    )

   | (_, PromptSent) =>
    (
      {...state, isSendingPrompt: false},
      [],
    )

  // Cancel an in-flight prompt turn
  // Reset isSendingPrompt immediately so a new prompt can be sent
  // while the cancelled prompt's server response is still in-flight.
  | ({isSendingPrompt: true, session: SessionActive(session)}, CancelPrompt) =>
    (
      {...state, isSendingPrompt: false},
      [CancelPromptEffect({session: session})],
    )

  | ({isSendingPrompt: false}, CancelPrompt) =>
    (
      state,
      [LogInfo("CancelPrompt ignored: not sending a prompt")],
    )

  | ({isSendingPrompt: true}, SendPrompt(_)) =>
    (
      state,
      [LogError("Cannot send prompt: already sending")],
    )

  | ({session: NoSession | SessionCreating | SessionError(_)}, SendPrompt(_)) =>
    (
      state,
      [LogError("Cannot send prompt: no active session")],
    )

  // Load a persisted task (calls ACP.loadSession or joinSession based on needsHistory)
  | ({acp: ACPConnected(conn), mcpServer: Some(mcpServer)}, LoadTask({taskId, needsHistory, onUpdate, onMcpMessage, onComplete})) => (
      state,
      [LoadTaskEffect({connection: conn, mcpServer, taskId, needsHistory, onUpdate, onMcpMessage, onComplete})],
    )

  | (_, LoadTask(_)) => (
      state,
      [LogError("Cannot load task: not connected")],
    )

  // Delete a persisted session (calls ACP.deleteSession)
  | ({acp: ACPConnected(conn)}, DeleteSession({taskId, onComplete})) => (
      state,
      [DeleteSessionEffect({connection: conn, taskId, onComplete})],
    )

  | (_, DeleteSession({onComplete, _})) => {
      onComplete(Error("Not connected"))
      (state, [])
    }

  // === Clear Session (for starting new task) ===
  | ({session: SessionActive(oldSession)}, ClearSession) => (
      {...state, session: NoSession},
      [CleanupSessionEffect({session: oldSession})],
    )
  | (_, ClearSession) => ({...state, session: NoSession}, [])

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

  | ({acp: ACPConnecting | ACPConnected(_) | ACPAuthRequired(_) | ACPError(_)}, ACPConnectStart) => (
      state,
      [LogError("Invalid: ACP connect already in progress or completed")],
    )

  | ({acp: ACPDisconnected | ACPConnected(_) | ACPAuthRequired(_) | ACPError(_)}, ACPConnectSuccess(_)) => (
      state,
      [LogError("Invalid: unexpected ACP connect success")],
    )

  | ({relay: RelayConnecting | RelayConnected | RelayError(_)}, RelayConnectStart) => (
      state,
      [LogError("Invalid: Relay connect already in progress or completed")],
    )

  | ({acp: ACPDisconnected | ACPConnecting | ACPAuthRequired(_) | ACPError(_)}, SessionCreateStart) => (
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

// Helper to clean up a session's channel handlers
let cleanupSession = (session: ACP.session): unit => {
  session.channel->Channel.off(~event=#"acp:message")
  session.channel->Channel.off(~event=#"mcp:message")
  Channel.leave(session.channel)->ignore
  Log.debug(~ctx={"sessionId": session.sessionId}, "Cleaned up session channel")
}

// Effect handler - executed in useEffect, not during dispatch
// This receives current state and dispatch, so async callbacks can safely dispatch
let handleEffect = (effect: effect, state: state, dispatch: action => unit) => {
  switch effect {
  | LogError(msg) => Log.error(msg)
  | LogInfo(msg) => Log.info(msg)
  | DisconnectRelay(relay) => Relay.disconnect(relay)
  | DisconnectACP(_) => ()
  | AbortConnections(controller) =>
    Log.info("Aborting in-flight connections")
    WebAPI.AbortController.abort(controller)
  | ConnectACP({config, signal}) =>
    let connect = async () => {
      let result = await ACP.connect(config, ~signal)
      switch result {
      | Ok(conn) => dispatch(ACPConnectSuccess(conn))
      | Error(err) =>
        // Don't dispatch error for aborted connections - component is unmounting
        if signal.aborted {
          Log.info("ACP connection aborted (cleanup)")
        } else {
          switch err {
          | ACP.AuthRequired({loginUrl}) =>
            let encodeURIComponent: string => string = %raw(`encodeURIComponent`)
            let currentUrl =
              WebAPI.Global.window->WebAPI.Window.location->WebAPI.Location.href
            let returnTo = encodeURIComponent(currentUrl)
            let fullUrl = `${loginUrl}?return_to=${returnTo}`
            // For first-time users, surface the auth URL so the UI can show a welcome modal.
            // Returning users get redirected immediately.
            switch Client__FtueState.get() {
            | Client__FtueState.New =>
              dispatch(ACPConnectError(`auth_required:${fullUrl}`))
            | Client__FtueState.WelcomeShown | Client__FtueState.Completed =>
              WebAPI.Global.window->WebAPI.Window.location->WebAPI.Location.assign(fullUrl)
            }
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
          Log.info(
            ~ctx={"tools": tools->Array.map(t => t.name)},
            `${serverInfo.name} v${serverInfo.version} - ${tools
              ->Array.length
              ->Int.toString} relay tools available`,
          )
        | _ => ()
        }
      | Error(err) => dispatch(RelayConnectError(err))
      }
    }
    connect()->ignore
  | CreateSessionEffect({connection, mcpServer, onUpdate, onMcpMessage, onComplete}) =>
    let create = async () => {
      let mcpServerInterface = MCPServer.toInterface(mcpServer)
      let sessionId = WebAPI.Global.crypto->WebAPI.Crypto.randomUUID
      let result = await ACP.createSession(
        connection,
        ~sessionId,
        ~onUpdate,
        ~mcpServerInterface,
        ~onMcpMessage,
      )
      switch result {
      | Ok(sess) =>
        dispatch(SessionCreateSuccess(sess))
        onComplete(Ok(sess.sessionId))
      | Error(err) =>
        dispatch(SessionCreateError(err))
        onComplete(Error(err))
      }
    }
    create()->ignore
  | SendPromptEffect({session, text, additionalBlocks, onComplete, metadata}) =>
    let send = async () => {
      try {
        let result = await ACP.sendPrompt(session, text, ~additionalBlocks, ~metadata)
        dispatch(PromptSent)
        onComplete(result)
      } catch {
      | exn =>
        dispatch(PromptSent)
        onComplete(Error("sendPrompt exception"))
        throw(exn)
      }
    }
    send()->ignore
  | CancelPromptEffect({session}) =>
    // ACP spec: session/cancel is a notification (fire-and-forget).
    // The pending session/prompt request will resolve with stopReason: "cancelled",
    // which triggers PromptSent via the existing SendPromptEffect onComplete callback.
    ACP.cancelPrompt(session)

  | FetchSessionsEffect(conn) =>
    Client__State.Actions.sessionsLoadStarted()
    let fetch = async () => {
      switch await ACP.listSessions(conn) {
      | Ok(sessions) => Client__State.Actions.sessionsLoadSuccess(~sessions)
      | Error(err) =>
        Log.error(~ctx={"error": err}, "Failed to fetch sessions")
        Client__State.Actions.sessionsLoadError(~error=err)
      }
    }
    fetch()->ignore

  | LoadTaskEffect({connection, mcpServer, taskId, needsHistory, onUpdate, onMcpMessage, onComplete}) =>
    let activateSession = async () => {
      let mcpServerInterface = MCPServer.toInterface(mcpServer)
      let result = if needsHistory {
        await ACP.loadSession(connection, taskId, ~onUpdate, ~mcpServerInterface, ~onMcpMessage)
      } else {
        await ACP.joinSession(connection, taskId, ~onUpdate, ~mcpServerInterface, ~onMcpMessage)
      }
      switch result {
      | Ok(session) =>
        dispatch(SessionCreateSuccess(session))
        Log.info(~ctx={"taskId": taskId}, "Session activated")
        onComplete(Ok())
      | Error(err) =>
        dispatch(SessionCreateError(err))
        Log.error(~ctx={"error": err}, "Failed to activate session")
        onComplete(Error(err))
      }
    }

    switch state.session {
    | SessionActive({sessionId}) when sessionId == taskId => onComplete(Ok())
    | SessionActive(oldSession) =>
      cleanupSession(oldSession)
      activateSession()->ignore
    | NoSession | SessionCreating | SessionError(_) => activateSession()->ignore
    }

  | DeleteSessionEffect({connection, taskId, onComplete}) =>
    let delete = async () => {
      let result = await ACP.deleteSession(connection, taskId)
      switch result {
      | Ok() => Log.info(~ctx={"taskId": taskId}, "Session deleted")
      | Error(err) => Log.error(~ctx={"taskId": taskId, "error": err}, "Failed to delete session")
      }
      onComplete(result)
    }
    delete()->ignore

  | CleanupSessionEffect({session}) => cleanupSession(session)
  }
}
