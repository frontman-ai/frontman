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
  // _meta to pass in ACP clientInfo (framework, env key detection, etc.)
  _meta: JSON.t,
  // Called when the server pushes a title update for a task
  onTitleUpdated: option<(string, string) => unit>,
}

// Connection states
type authRequiredPayload = {loginUrl: string}

type acpState =
  | ACPDisconnected
  | ACPConnecting
  | ACPConnected(ACP.connection)
  | ACPAuthRequired(authRequiredPayload)
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
  initialAuthBehavior: Client__FtueState.authBehavior,
  isSendingPrompt: bool,
  // Relay instance exists before connection completes - needed for MCPServer
  relayInstance: option<Relay.t>,
  // MCPServer created once relay instance exists
  mcpServer: option<MCPServer.t>,
  // AbortController for cancelling in-flight connections on cleanup
  abortController: option<WebAPI.EventAPI.abortController>,
}

@schema
type clientInfoMeta = {framework: option<string>}

@val external encodeURIComponent: string => string = "encodeURIComponent"

let frameworkFromClientInfoMeta = (meta: JSON.t): option<string> =>
  S.parseOrThrow(meta, clientInfoMetaSchema).framework

// Initialization payload - includes pre-created instances
type initPayload = {
  config: initConfig,
  relay: Relay.t,
  mcpServer: MCPServer.t,
}

// Actions
type action =
  | Initialize(initPayload)
  | ACPConnectSuccess(ACP.connection)
  | ACPAuthRequiredReceived(authRequiredPayload)
  | ACPConnectError(string)
  | RelayConnectSuccess
  | RelayConnectError(string)
  | SessionCreateSuccess(ACP.session)
  | SessionCreateError(string)
  | CreateSession({
      onUpdate: (string, FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP.sessionUpdate) => unit,
      onTitleUpdated: (string, string) => unit,
      onMcpMessage: (FrontmanAiFrontmanClient.FrontmanClient__MCP.messageDirection, JSON.t) => unit,
      onComplete: result<string, string> => unit,
    })
  | SendPrompt({
      text: string,
      additionalBlocks: array<FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP.contentBlock>,
      onComplete: result<
        FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP.promptResult,
        string,
      > => unit,
      _meta: option<JSON.t>,
    })
  | PromptSent
  | CancelPrompt
  | RetryTurn({retriedErrorId: string})
  | LoadTask({
      taskId: string,
      needsHistory: bool,
      onUpdate: (string, FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP.sessionUpdate) => unit,
      onTitleUpdated: (string, string) => unit,
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
  | ConnectACP({
      config: ACP.config,
      signal: WebAPI.EventAPI.abortSignal,
      initialAuthBehavior: Client__FtueState.authBehavior,
    })
  | ConnectRelay(Relay.t, WebAPI.EventAPI.abortSignal)
  | DisconnectRelay(Relay.t)
  | DisconnectACP(ACP.connection)
  | AbortConnections(WebAPI.EventAPI.abortController)
  | CreateSessionEffect({
      connection: ACP.connection,
      mcpServer: MCPServer.t,
      onUpdate: (string, FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP.sessionUpdate) => unit,
      onTitleUpdated: (string, string) => unit,
      onMcpMessage: (FrontmanAiFrontmanClient.FrontmanClient__MCP.messageDirection, JSON.t) => unit,
      onComplete: result<string, string> => unit,
    })
  | SendPromptEffect({
      session: ACP.session,
      text: string,
      additionalBlocks: array<FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP.contentBlock>,
      onComplete: result<
        FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP.promptResult,
        string,
      > => unit,
      _meta: option<JSON.t>,
    })
  | CancelPromptEffect({session: ACP.session})
  | RetryTurnEffect({session: ACP.session, retriedErrorId: string})
  | FetchSessionsEffect(ACP.connection)
  | LoadTaskEffect({
      connection: ACP.connection,
      mcpServer: MCPServer.t,
      taskId: string,
      needsHistory: bool,
      onUpdate: (string, FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP.sessionUpdate) => unit,
      onTitleUpdated: (string, string) => unit,
      onMcpMessage: (FrontmanAiFrontmanClient.FrontmanClient__MCP.messageDirection, JSON.t) => unit,
      onComplete: result<unit, string> => unit,
    })
  | DeleteSessionEffect({
      connection: ACP.connection,
      taskId: string,
      onComplete: result<unit, string> => unit,
    })
  | NotifyDeleteSessionRejected({onComplete: result<unit, string> => unit, reason: string})
  | CleanupSessionEffect({session: ACP.session})

let initialState: state = {
  acp: ACPDisconnected,
  relay: RelayDisconnected,
  session: NoSession,
  initialAuthBehavior: Client__FtueState.RedirectToLogin,
  isSendingPrompt: false,
  relayInstance: None,
  mcpServer: None,
  abortController: None,
}

module Selectors = {
  let getSession = (state: state): option<ACP.session> => {
    switch state.session {
    | SessionActive(s) => Some(s)
    | NoSession | SessionCreating | SessionError(_) => None
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
    | ACPDisconnected | ACPConnecting | ACPConnected(_) | ACPError(_) => None
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
      ~_meta=config._meta,
      ~onMessage=config.onACPMessage,
      ~onTitleUpdated=?config.onTitleUpdated,
      ~onConfigOptionsUpdated=configOptions => {
        Client__State__Store.dispatch(ConfigOptionsReceived({configOptions: configOptions}))
      },
    )
    // Create AbortController to cancel connections on cleanup
    let abortController = WebAPI.AbortController.make()
    (
      {
        acp: ACPConnecting,
        relay: RelayConnecting,
        session: NoSession,
        initialAuthBehavior: state.initialAuthBehavior,
        isSendingPrompt: false,
        relayInstance: Some(relay),
        mcpServer: Some(mcpServer),
        abortController: Some(abortController),
      },
      [
        ConnectACP({
          config: acpConfig,
          signal: abortController.signal,
          initialAuthBehavior: state.initialAuthBehavior,
        }),
        ConnectRelay(relay, abortController.signal),
        LogInfo("Initializing connections..."),
      ],
    )

  // === ACP connection flow ===
  | ({acp: ACPConnecting}, ACPConnectSuccess(conn)) => (
      {...state, acp: ACPConnected(conn)},
      [LogInfo("ACP connected"), FetchSessionsEffect(conn)],
    )

  | ({acp: ACPConnecting}, ACPAuthRequiredReceived({loginUrl})) => (
      {...state, acp: ACPAuthRequired({loginUrl: loginUrl})},
      [LogInfo("ACP auth required")],
    )

  | ({acp: ACPConnecting}, ACPConnectError(msg)) => (
      {...state, acp: ACPError(msg)},
      [LogError(`ACP connect failed: ${msg}`)],
    )

  // === Relay lifecycle ===
  | ({relay: RelayConnecting}, RelayConnectSuccess) => (
      {...state, relay: RelayConnected},
      [LogInfo("Relay connected")],
    )

  // Relay error is non-fatal - MCP still works with client-only tools
  | ({relay: RelayConnecting}, RelayConnectError(msg)) => (
      {...state, relay: RelayError(msg)},
      [LogInfo(`Relay failed (non-fatal): ${msg}`)],
    )

  // === Session lifecycle ===
  | (_, SessionCreateSuccess(sess)) => (
      {...state, session: SessionActive(sess), isSendingPrompt: false},
      [LogInfo(`Session activated: ${sess.sessionId}`)],
    )

  | ({session: SessionCreating}, SessionCreateError(msg)) => (
      {...state, session: SessionError(msg)},
      [LogError(`Session failed: ${msg}`)],
    )

  | (
      {
        acp: ACPConnected(conn),
        relay: RelayConnected,
        mcpServer: Some(mcpServer),
        session: NoSession,
      },
      CreateSession({onUpdate, onTitleUpdated, onMcpMessage, onComplete}),
    ) => (
      {...state, session: SessionCreating},
      [
        CreateSessionEffect({
          connection: conn,
          mcpServer,
          onUpdate,
          onTitleUpdated,
          onMcpMessage,
          onComplete,
        }),
      ],
    )

  | (
      {session: SessionActive(session), isSendingPrompt: false},
      SendPrompt({text, additionalBlocks, onComplete, _meta}),
    ) => (
      {...state, isSendingPrompt: true},
      [SendPromptEffect({session, text, additionalBlocks, onComplete, _meta})],
    )

  | (_, PromptSent) => ({...state, isSendingPrompt: false}, [])

  // Cancel an in-flight prompt turn
  // Reset isSendingPrompt immediately so a new prompt can be sent
  // while the cancelled prompt's server response is still in-flight.
  | ({isSendingPrompt: true, session: SessionActive(session)}, CancelPrompt) => (
      {...state, isSendingPrompt: false},
      [CancelPromptEffect({session: session})],
    )

  | ({isSendingPrompt: false}, CancelPrompt) => (
      state,
      [LogInfo("CancelPrompt ignored: not sending a prompt")],
    )

  | ({session: SessionActive(session)}, RetryTurn({retriedErrorId})) => (
      state,
      [RetryTurnEffect({session, retriedErrorId})],
    )

  | (_, RetryTurn(_)) => (state, [LogError("Cannot retry turn: no active session")])

  | ({isSendingPrompt: true}, SendPrompt(_)) => (
      state,
      [LogError("Cannot send prompt: already sending")],
    )

  | ({session: NoSession | SessionCreating | SessionError(_)}, SendPrompt(_)) => (
      state,
      [LogError("Cannot send prompt: no active session")],
    )

  // Load a persisted task (calls ACP.loadSession or joinSession based on needsHistory)
  | (
      {acp: ACPConnected(conn), mcpServer: Some(mcpServer)},
      LoadTask({taskId, needsHistory, onUpdate, onTitleUpdated, onMcpMessage, onComplete}),
    ) => (
      state,
      [
        LoadTaskEffect({
          connection: conn,
          mcpServer,
          taskId,
          needsHistory,
          onUpdate,
          onTitleUpdated,
          onMcpMessage,
          onComplete,
        }),
      ],
    )

  | (_, LoadTask(_)) => (state, [LogError("Cannot load task: not connected")])

  // Delete a persisted session (calls ACP.deleteSession)
  | ({acp: ACPConnected(conn)}, DeleteSession({taskId, onComplete})) => (
      state,
      [DeleteSessionEffect({connection: conn, taskId, onComplete})],
    )

  | (_, DeleteSession({onComplete, _})) => (
      state,
      [
        NotifyDeleteSessionRejected({onComplete, reason: "Not connected"}),
        LogError("Cannot delete session: not connected"),
      ],
    )

  // === Clear Session (for starting new task) ===
  | ({session: SessionActive(oldSession)}, ClearSession) => (
      {...state, session: NoSession},
      [CleanupSessionEffect({session: oldSession})],
    )
  | (_, ClearSession) => ({...state, session: NoSession}, [])

  | (_, CreateSession(_)) => (state, [LogError("Cannot create session: not ready")])

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
    | ACPDisconnected | ACPConnecting | ACPAuthRequired(_) | ACPError(_) => []
    }
    (
      {...initialState, initialAuthBehavior: state.initialAuthBehavior},
      Array.flat([abortEffects, relayEffects, acpEffects]),
    )

  // === Invalid transitions ===
  | (_, Initialize(_)) => (state, [LogInfo("Initialize ignored: already initialized")])

  | (_, ACPConnectSuccess(_) | ACPAuthRequiredReceived(_) | ACPConnectError(_)) => (
      state,
      [LogInfo("Stale ACP connection result ignored")],
    )

  | (_, RelayConnectSuccess | RelayConnectError(_)) => (
      state,
      [LogInfo("Stale relay connection result ignored")],
    )

  | (_, SessionCreateError(_)) => (state, [LogInfo("Stale session create result ignored")])

  | (
      {isSendingPrompt: true, session: NoSession | SessionCreating | SessionError(_)},
      CancelPrompt,
    ) => (state, [LogError("CancelPrompt rejected: no active session")])
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
  session.channel->Channel.off(~event=#title_updated)
  Channel.leave(session.channel)->ignore
  Log.debug(~ctx={"sessionId": session.sessionId}, "Cleaned up session channel")
}

// Effect handler - executed in useEffect, not during dispatch
// This receives current state and dispatch, so async callbacks can safely dispatch
let handleEffect = (effect: effect, state: state, dispatch: action => unit) => {
  let dispatchConfigOptions = (configOptions: option<array<_>>) =>
    switch configOptions {
    | Some(opts) => Client__State__Store.dispatch(ConfigOptionsReceived({configOptions: opts}))
    | None => ()
    }

  switch effect {
  | LogError(msg) => Log.error(msg)
  | LogInfo(msg) => Log.info(msg)
  | DisconnectRelay(relay) => Relay.disconnect(relay)
  | DisconnectACP(_) => ()
  | NotifyDeleteSessionRejected({onComplete, reason}) => onComplete(Error(reason))
  | AbortConnections(controller) =>
    Log.info("Aborting in-flight connections")
    WebAPI.AbortController.abort(controller)
  | ConnectACP({config, signal, initialAuthBehavior}) =>
    let connect = async () => {
      let result = await ACP.connect(config, ~signal)
      switch result {
      | Ok(conn) => dispatch(ACPConnectSuccess(conn))
      | Error(err) =>
        // Don't dispatch error for aborted connections - component is unmounting
        switch signal.aborted {
        | true => Log.info("ACP connection aborted (cleanup)")
        | false =>
          switch err {
          | ACP.AuthRequired({loginUrl}) =>
            let currentUrl = Client__HostNavigation.currentUrl()
            let returnTo = encodeURIComponent(currentUrl)
            let framework = config.clientInfo._meta->Option.flatMap(frameworkFromClientInfoMeta)

            let frameworkParam = switch framework {
            | Some(framework) => `&framework=${encodeURIComponent(framework)}`
            | None => ""
            }

            let separator = switch String.includes(loginUrl, "?") {
            | true => "&"
            | false => "?"
            }
            let fullUrl = `${loginUrl}${separator}return_to=${returnTo}${frameworkParam}`
            switch initialAuthBehavior {
            | Client__FtueState.ShowWelcomeModal =>
              dispatch(ACPAuthRequiredReceived({loginUrl: fullUrl}))
            | Client__FtueState.RedirectToLogin => Client__HostNavigation.assign(~url=fullUrl)
            }
          | ACP.ConnectionFailed(msg) => dispatch(ACPConnectError(msg))
          }
        }
      }
    }
    connect()->ignore
  | ConnectRelay(relay, signal) =>
    let connect = async () => {
      let result = await Relay.connect(relay, ~signal)
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
        | Disconnected | Error(_) => ()
        }
      | Error(err) =>
        switch signal.aborted {
        | true => Log.info("Relay connection aborted (cleanup)")
        | false => dispatch(RelayConnectError(err))
        }
      }
    }
    connect()->ignore
  | CreateSessionEffect({
      connection,
      mcpServer,
      onUpdate,
      onTitleUpdated,
      onMcpMessage,
      onComplete,
    }) =>
    let create = async () => {
      let mcpServerInterface = MCPServer.toInterface(mcpServer)
      let sessionId = WebAPI.Global.crypto->WebAPI.Crypto.randomUUID
      let result = await ACP.createSession(
        connection,
        ~sessionId,
        ~onUpdate,
        ~onTitleUpdated,
        ~mcpServerInterface,
        ~onMcpMessage,
      )
      switch result {
      | Ok((sess, configOptions)) =>
        dispatchConfigOptions(configOptions)
        dispatch(SessionCreateSuccess(sess))
        onComplete(Ok(sess.sessionId))
      | Error(err) =>
        dispatch(SessionCreateError(err))
        onComplete(Error(err))
      }
    }
    create()->ignore
  | SendPromptEffect({session, text, additionalBlocks, onComplete, _meta}) =>
    let send = async () => {
      try {
        let result = await ACP.sendPrompt(session, text, ~additionalBlocks, ~_meta)
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

  | RetryTurnEffect({session, retriedErrorId}) =>
    // ACP spec: session/retry_turn is a notification (fire-and-forget).
    // Signals the server to retry the failed agent turn.
    ACP.retryTurn(session, ~retriedErrorId)

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

  | LoadTaskEffect({
      connection,
      mcpServer,
      taskId,
      needsHistory,
      onUpdate,
      onTitleUpdated,
      onMcpMessage,
      onComplete,
    }) =>
    let activateSession = async () => {
      let mcpServerInterface = MCPServer.toInterface(mcpServer)
      let result = switch needsHistory {
      | true =>
        let loadResult = await ACP.loadSession(
          connection,
          taskId,
          ~onUpdate,
          ~onTitleUpdated,
          ~mcpServerInterface,
          ~onMcpMessage,
        )
        switch loadResult {
        | Ok((session, sessionLoadResult)) =>
          dispatchConfigOptions(sessionLoadResult.configOptions)
          Ok(session)
        | Error(e) => Error(e)
        }
      | false =>
        await ACP.joinSession(
          connection,
          taskId,
          ~onUpdate,
          ~onTitleUpdated,
          ~mcpServerInterface,
          ~onMcpMessage,
        )
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
    | SessionActive(oldSession) =>
      switch oldSession.sessionId == taskId {
      | true => onComplete(Ok())
      | false =>
        cleanupSession(oldSession)
        activateSession()->ignore
      }
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
