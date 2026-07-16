// Connection state reducer for FrontmanProvider
// Manages ACP, Relay, and Session connection lifecycle
//
// Key insight: MCP handler attachment happens DURING session creation (before channel join),
// not as a separate post-hoc step. The reducer tracks whether prerequisites are met.

module Log = FrontmanLogs.Logs.Make({
  let component = #ConnectionReducer
})

module ACP = FrontmanAiFrontmanClient.FrontmanClient__ACP
module ACPTypes = FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP
module Relay = FrontmanAiFrontmanClient.FrontmanClient__Relay
module MCPServer = FrontmanAiFrontmanClient.FrontmanClient__MCP__Server

// Configuration for initialization
type initConfig = {
  endpoint: string,
  tokenUrl: string,
  loginUrl: string,
  clientName: string,
  clientVersion: string,
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
  | SessionCreating(option<string>)
  | SessionActive(ACP.session)
  | SessionError(string)

type state = {
  acp: acpState,
  relay: relayState,
  session: sessionState,
  initialAuthBehavior: Client__FtueState.authBehavior,
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
  S.parseOrThrow(meta, ~to=clientInfoMetaSchema).framework

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
  | SessionCreationIdentified(string)
  | SessionCreateSuccess(ACP.session)
  | SessionCreateError({sessionId: string, error: string})
  | SessionFailed({sessionId: string, error: string})
  | CreateSession({
      onUpdate: (string, ACPTypes.sessionUpdate) => unit,
      onTitleUpdated: (string, string) => unit,
      onMcpMessage: (FrontmanAiFrontmanClient.FrontmanClient__MCP.messageDirection, JSON.t) => unit,
      onComplete: result<string, string> => unit,
    })
  | SendPrompt({
      text: string,
      additionalBlocks: array<ACPTypes.contentBlock>,
      onComplete: result<ACPTypes.promptResult, string> => unit,
      _meta: option<JSON.t>,
    })
  | CancelPrompt
  | RetryTurn({retriedErrorId: string})
  | LoadTask({
      taskId: string,
      needsHistory: bool,
      onUpdate: (string, ACPTypes.sessionUpdate) => unit,
      onTitleUpdated: (string, string) => unit,
      onMcpMessage: (FrontmanAiFrontmanClient.FrontmanClient__MCP.messageDirection, JSON.t) => unit,
      onComplete: result<unit, string> => unit,
    })
  | DeleteSession({taskId: string, onComplete: result<unit, string> => unit})
  | ClearSession

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
  | CreateSessionEffect({
      connection: ACP.connection,
      mcpServer: MCPServer.t,
      onUpdate: (string, ACPTypes.sessionUpdate) => unit,
      onTitleUpdated: (string, string) => unit,
      onMcpMessage: (FrontmanAiFrontmanClient.FrontmanClient__MCP.messageDirection, JSON.t) => unit,
      onComplete: result<string, string> => unit,
    })
  | SendPromptEffect({
      session: ACP.session,
      text: string,
      additionalBlocks: array<ACPTypes.contentBlock>,
      onComplete: result<ACPTypes.promptResult, string> => unit,
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
      onUpdate: (string, ACPTypes.sessionUpdate) => unit,
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
  relayInstance: None,
  mcpServer: None,
  abortController: None,
}

module Selectors = {
  let getSession = (state: state): option<ACP.session> => {
    switch state.session {
    | SessionActive(s) => Some(s)
    | NoSession | SessionCreating(_) | SessionError(_) => None
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
  | ({session: SessionCreating(None)}, SessionCreationIdentified(sessionId)) => (
      {...state, session: SessionCreating(Some(sessionId))},
      [],
    )

  | ({session: SessionCreating(expectedSessionId)}, SessionCreateSuccess(sess))
    if expectedSessionId->Option.mapOr(true, id => id == sess.sessionId) => (
      {...state, session: SessionActive(sess)},
      [LogInfo(`Session activated: ${sess.sessionId}`)],
    )

  | (_, SessionCreateSuccess(sess)) => (
      state,
      [CleanupSessionEffect({session: sess}), LogInfo(`Stale session ignored: ${sess.sessionId}`)],
    )

  | ({session: SessionCreating(expectedSessionId)}, SessionCreateError({sessionId, error}))
    if expectedSessionId->Option.mapOr(true, id => id == sessionId) => (
      {...state, session: SessionError(error)},
      [LogError(`Session failed: ${error}`)],
    )

  | ({session: SessionActive({sessionId: activeSessionId})}, SessionFailed({sessionId, error}))
    if sessionId == activeSessionId => (
      {...state, session: SessionError(error)},
      [LogError(`Session failed: ${error}`)],
    )

  | ({session: SessionCreating(Some(expectedSessionId))}, SessionFailed({sessionId, error}))
    if expectedSessionId == sessionId => (
      {...state, session: SessionError(error)},
      [LogError(`Session failed: ${error}`)],
    )

  | (_, SessionFailed(_)) => (state, [LogInfo("Stale session failure ignored")])

  | (
      {
        acp: ACPConnected(conn),
        relay: RelayConnected,
        mcpServer: Some(mcpServer),
        session: NoSession,
      },
      CreateSession({onUpdate, onTitleUpdated, onMcpMessage, onComplete}),
    ) => (
      {...state, session: SessionCreating(None)},
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
      {session: SessionActive(session)},
      SendPrompt({text, additionalBlocks, onComplete, _meta}),
    ) => (state, [SendPromptEffect({session, text, additionalBlocks, onComplete, _meta})])

  | ({session: SessionActive(session)}, CancelPrompt) => (
      state,
      [CancelPromptEffect({session: session})],
    )

  | ({session: SessionActive(session)}, RetryTurn({retriedErrorId})) => (
      state,
      [RetryTurnEffect({session, retriedErrorId})],
    )

  | (_, RetryTurn(_)) => (state, [LogError("Cannot retry turn: no active session")])

  | ({session: NoSession | SessionCreating(_) | SessionError(_)}, SendPrompt(_)) => (
      state,
      [LogError("Cannot send prompt: no active session")],
    )

  // Load a persisted task (calls ACP.loadSession or joinSession based on needsHistory)
  | (
      {acp: ACPConnected(conn), mcpServer: Some(mcpServer), session: SessionActive({sessionId})},
      LoadTask({taskId, needsHistory, onUpdate, onTitleUpdated, onMcpMessage, onComplete}),
    ) if sessionId == taskId => (
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

  | (
      {acp: ACPConnected(conn), mcpServer: Some(mcpServer), session: SessionActive(oldSession)},
      LoadTask({taskId, needsHistory, onUpdate, onTitleUpdated, onMcpMessage, onComplete}),
    ) => (
      {...state, session: SessionCreating(Some(taskId))},
      [
        CleanupSessionEffect({session: oldSession}),
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

  | (
      {acp: ACPConnected(conn), mcpServer: Some(mcpServer)},
      LoadTask({taskId, needsHistory, onUpdate, onTitleUpdated, onMcpMessage, onComplete}),
    ) => (
      {...state, session: SessionCreating(Some(taskId))},
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

  | (_, SessionCreationIdentified(_) | SessionCreateError(_)) => (
      state,
      [LogInfo("Stale session create result ignored")],
    )
  | ({session: NoSession | SessionCreating(_) | SessionError(_)}, CancelPrompt) => (
      state,
      [LogError("CancelPrompt rejected: no active session")],
    )
  }
}

// StateReducer.Interface implementation
let name = "ConnectionReducer"

// Alias for StateReducer compatibility
let next = reduce

// Helper to clean up a session's channel handlers
let cleanupSession = (session: ACP.session): unit => {
  ACP.cleanupSessionChannel(session)
  Log.debug(~ctx={"sessionId": session.sessionId}, "Cleaned up session channel")
}

// Effect handler - executed in useEffect, not during dispatch
// This receives current state and dispatch, so async callbacks can safely dispatch
let handleEffect = (effect: effect, state: state, dispatch: action => unit) => {
  let dispatchConfigOptions = (configOptions: option<array<_>>) =>
    configOptions->Option.forEach(opts =>
      Client__State__Store.dispatch(ConfigOptionsReceived({configOptions: opts}))
    )

  let dispatchSessionResult = (
    taskId,
    catalog: option<array<ACPTypes.agentCatalogEntry>>,
    configOptions,
  ) => {
    let taskAction: Client__Task__Reducer.action = AgentCatalogInstalled(
      catalog->Option.getOrThrow(~message="Validated attribution catalog is required"),
    )
    Client__State__Store.dispatch(TaskAction({target: ForTask(taskId), action: taskAction}))
    dispatchConfigOptions(configOptions)
  }

  switch effect {
  | LogError(msg) => Log.error(msg)
  | LogInfo(msg) => Log.info(msg)
  | NotifyDeleteSessionRejected({onComplete, reason}) => onComplete(Error(reason))
  | ConnectACP({config, signal, initialAuthBehavior}) =>
    let connect = async () => {
      let result = await ACP.connect(config, ~signal)
      switch result {
      | Ok(conn) =>
        switch ACP.getAgentAttributionVersion(conn) {
        | Some(_) => dispatch(ACPConnectSuccess(conn))
        | None =>
          ACP.disconnect(conn)
          dispatch(ACPConnectError("Frontman requires agent attribution v1"))
        }
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
      let creationError = ref(None)
      dispatch(SessionCreationIdentified(sessionId))
      let result = await ACP.createSession(
        connection,
        ~sessionId,
        ~onUpdate,
        ~onTitleUpdated,
        ~onParseError=error => {
          creationError := Some(error)
          Client__TextDeltaBuffer.discardTask(sessionId)
          dispatch(SessionFailed({sessionId, error}))
        },
        ~mcpServerInterface,
        ~onMcpMessage,
      )
      switch result {
      | Ok((sess, sessionNewResult, catalog)) =>
        switch creationError.contents {
        | Some(error) =>
          ACP.cleanupSessionChannel(sess)
          onComplete(Error(error))
        | None =>
          dispatchSessionResult(sess.sessionId, catalog, sessionNewResult.configOptions)
          dispatch(SessionCreateSuccess(sess))
          onComplete(Ok(sess.sessionId))
        }
      | Error(err) =>
        dispatch(SessionCreateError({sessionId, error: err}))
        onComplete(Error(err))
      }
    }
    create()->ignore
  | SendPromptEffect({session, text, additionalBlocks, onComplete, _meta}) =>
    let send = async () => {
      try {
        let result = await ACP.sendPrompt(session, text, ~additionalBlocks, ~_meta)
        onComplete(result)
      } catch {
      | exn =>
        onComplete(Error("sendPrompt exception"))
        throw(exn)
      }
    }
    send()->ignore
  | CancelPromptEffect({session}) =>
    // ACP spec: session/cancel is a notification (fire-and-forget).
    ACP.cancelPrompt(session)

  | RetryTurnEffect({session, retriedErrorId}) =>
    // Frontman extension: session/retry_turn is a notification (fire-and-forget).
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
          ~onLoadResult=(result, catalog) =>
            dispatchSessionResult(taskId, catalog, result.configOptions),
          ~onUpdate,
          ~onTitleUpdated,
          ~onParseError=err => {
            Client__TextDeltaBuffer.discardTask(taskId)
            dispatch(SessionFailed({sessionId: taskId, error: err}))
          },
          ~mcpServerInterface,
          ~onMcpMessage,
        )
        loadResult->Result.map(((session, _)) => session)
      | false =>
        let task =
          StateStore.getState(Client__State__Store.store).tasks
          ->Dict.get(taskId)
          ->Option.getOrThrow(~message=`Unknown task: ${taskId}`)
        let catalog = Client__Task__Types.Task.getAgentCatalog(task)
        await ACP.joinSession(
          connection,
          taskId,
          ~onUpdate,
          ~catalog,
          ~onTitleUpdated,
          ~onParseError=err => {
            Client__TextDeltaBuffer.discardTask(taskId)
            dispatch(SessionFailed({sessionId: taskId, error: err}))
          },
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
        dispatch(SessionCreateError({sessionId: taskId, error: err}))
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
    | NoSession | SessionCreating(_) | SessionError(_) => activateSession()->ignore
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
