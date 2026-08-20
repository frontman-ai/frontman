module Log = FrontmanLogs.Logs.Make({
  let component = #ConnectionReducer
})

module ACP = FrontmanAiFrontmanClient.FrontmanClient__ACP
module ACPTypes = FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP
module ContentBlock = FrontmanAiFrontmanProtocol.FrontmanProtocol__ContentBlock
module MCPClient = FrontmanAiFrontmanClient.FrontmanClient__MCP__Client
module MCPServer = FrontmanAiFrontmanClient.FrontmanClient__MCP__Server

type initConfig = {
  endpoint: string,
  tokenUrl: string,
  loginUrl: string,
  clientName: string,
  clientVersion: string,
  onACPMessage: (ACP.messageDirection, JSON.t) => unit,
  _meta: JSON.t,
  onTitleUpdated: option<(string, string) => unit>,
}

type authRequiredPayload = {loginUrl: string}

type acpState =
  | ACPDisconnected
  | ACPConnecting
  | ACPConnected(ACP.connection)
  | ACPAuthRequired(authRequiredPayload)
  | ACPError(string)

type frameworkMCPState =
  | FrameworkMCPDisconnected
  | FrameworkMCPConnecting
  | FrameworkMCPConnected
  | FrameworkMCPError(string)

type frameworkServerInfo = FrontmanAiFrontmanProtocol.FrontmanProtocol__MCP.Implementation.t

type sessionState =
  | NoSession
  | SessionCreating(string)
  | SessionActive(ACP.session)
  | SessionError(string)

type state = {
  acp: acpState,
  frameworkMCP: frameworkMCPState,
  session: sessionState,
  initialAuthBehavior: Client__FtueState.authBehavior,
  frameworkMCPClient: option<MCPClient.t>,
  mcpServer: option<MCPServer.t>,
  abortController: option<WebAPI.EventAPI.abortController>,
}

@schema
type clientInfoMeta = {framework: option<string>}

@val external encodeURIComponent: string => string = "encodeURIComponent"

let frameworkFromClientInfoMeta = (meta: JSON.t): option<string> =>
  S.parseOrThrow(meta, ~to=clientInfoMetaSchema).framework

type initPayload = {
  config: initConfig,
  frameworkMCPClient: MCPClient.t,
  mcpServer: MCPServer.t,
}

type loadTaskRequest = {
  taskId: string,
  needsHistory: bool,
  onUpdate: (string, ACPTypes.sessionUpdate) => unit,
  onTitleUpdated: (string, string) => unit,
  onMcpMessage: (FrontmanAiFrontmanClient.FrontmanClient__MCP.messageDirection, JSON.t) => unit,
  onComplete: result<unit, string> => unit,
}

type createSessionRequest = {
  sessionId: string,
  onUpdate: (string, ACPTypes.sessionUpdate) => unit,
  onTitleUpdated: (string, string) => unit,
  onMcpMessage: (FrontmanAiFrontmanClient.FrontmanClient__MCP.messageDirection, JSON.t) => unit,
  onComplete: result<string, string> => unit,
}

type action =
  | Initialize(initPayload)
  | ACPConnectSuccess(ACP.connection)
  | ACPAuthRequiredReceived(authRequiredPayload)
  | ACPConnectError(string)
  | FrameworkMCPConnectSuccess
  | FrameworkMCPConnectError(string)
  | SessionCreateSuccess(ACP.session)
  | SessionCreateError({sessionId: string, error: string})
  | SessionFailed({sessionId: string, error: string})
  | CreateSession(createSessionRequest)
  | SendPrompt({
      text: string,
      additionalBlocks: array<ContentBlock.t>,
      onComplete: result<ACPTypes.promptResult, string> => unit,
      _meta: option<JSON.t>,
    })
  | CancelPrompt
  | RetryTurn({retriedErrorId: string})
  | LoadTask(loadTaskRequest)
  | DeleteSession({taskId: string, onComplete: result<unit, string> => unit})
  | ClearSession

type effect =
  | LogError(string)
  | LogInfo(string)
  | ConnectACP({
      config: ACP.config,
      signal: WebAPI.EventAPI.abortSignal,
      initialAuthBehavior: Client__FtueState.authBehavior,
    })
  | ConnectFrameworkMCP(MCPClient.t, WebAPI.EventAPI.abortSignal)
  | CreateSessionEffect({
      connection: ACP.connection,
      mcpServer: MCPServer.t,
      request: createSessionRequest,
    })
  | SendPromptEffect({
      session: ACP.session,
      text: string,
      additionalBlocks: array<ContentBlock.t>,
      onComplete: result<ACPTypes.promptResult, string> => unit,
      _meta: option<JSON.t>,
    })
  | CancelPromptEffect({session: ACP.session})
  | RetryTurnEffect({session: ACP.session, retriedErrorId: string})
  | FetchSessionsEffect(ACP.connection)
  | LoadTaskEffect({connection: ACP.connection, mcpServer: MCPServer.t, request: loadTaskRequest})
  | DeleteSessionEffect({
      connection: ACP.connection,
      taskId: string,
      onComplete: result<unit, string> => unit,
    })
  | NotifyCreateSessionRejected({onComplete: result<string, string> => unit, reason: string})
  | NotifyLoadTaskRejected({onComplete: result<unit, string> => unit, reason: string})
  | NotifySendPromptRejected({
      onComplete: result<ACPTypes.promptResult, string> => unit,
      reason: string,
    })
  | NotifyDeleteSessionRejected({onComplete: result<unit, string> => unit, reason: string})
  | CleanupSessionEffect({session: ACP.session})

let initialState: state = {
  acp: ACPDisconnected,
  frameworkMCP: FrameworkMCPDisconnected,
  session: NoSession,
  initialAuthBehavior: Client__FtueState.RedirectToLogin,
  frameworkMCPClient: None,
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

  type connectionStatus =
    | Disconnected
    | Connecting
    | Connected
    | SessionActive(string)
    | Error(string)

  let getConnectionStatus = (state: state): connectionStatus => {
    switch (state.acp, state.frameworkMCP, state.session) {
    | (_, _, SessionActive(sess)) => SessionActive(sess.sessionId)
    | (_, _, SessionError(msg)) => Error(msg)
    | (ACPError(msg), _, _) => Error(msg)
    | (ACPConnected(_), FrameworkMCPConnected | FrameworkMCPError(_), _) => Connected
    | (ACPConnected(_), FrameworkMCPDisconnected | FrameworkMCPConnecting, _) => Connecting
    | (ACPConnecting, _, _) => Connecting
    | (ACPAuthRequired(_), _, _) => Disconnected
    | (ACPDisconnected, _, _) => Disconnected
    }
  }

  let getFrameworkServerInfo = (state: state): option<frameworkServerInfo> =>
    state.frameworkMCPClient->Option.flatMap(client =>
      switch MCPClient.getState(client) {
      | Connected({serverInfo}) => Some(serverInfo)
      | Disconnected | Error(_) => None
      }
    )

  let getAuthRedirectUrl = (state: state): option<string> => {
    switch state.acp {
    | ACPAuthRequired({loginUrl}) => Some(loginUrl)
    | ACPDisconnected | ACPConnecting | ACPConnected(_) | ACPError(_) => None
    }
  }
}

let reduce = (state: state, action: action): (state, array<effect>) => {
  switch (state, action) {
  | (
      {acp: ACPDisconnected, frameworkMCP: FrameworkMCPDisconnected},
      Initialize({config, frameworkMCPClient, mcpServer}),
    ) =>
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
    let abortController = WebAPI.AbortController.make()
    (
      {
        acp: ACPConnecting,
        frameworkMCP: FrameworkMCPConnecting,
        session: NoSession,
        initialAuthBehavior: state.initialAuthBehavior,
        frameworkMCPClient: Some(frameworkMCPClient),
        mcpServer: Some(mcpServer),
        abortController: Some(abortController),
      },
      [
        ConnectACP({
          config: acpConfig,
          signal: abortController.signal,
          initialAuthBehavior: state.initialAuthBehavior,
        }),
        ConnectFrameworkMCP(frameworkMCPClient, abortController.signal),
        LogInfo("Initializing connections..."),
      ],
    )

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

  | ({frameworkMCP: FrameworkMCPConnecting}, FrameworkMCPConnectSuccess) => (
      {...state, frameworkMCP: FrameworkMCPConnected},
      [LogInfo("Framework MCP connected")],
    )

  | ({frameworkMCP: FrameworkMCPConnecting}, FrameworkMCPConnectError(msg)) => (
      {...state, frameworkMCP: FrameworkMCPError(msg)},
      [LogInfo(`Framework MCP failed (non-fatal): ${msg}`)],
    )

  | ({session: SessionCreating(expectedSessionId)}, SessionCreateSuccess(sess))
    if expectedSessionId == sess.sessionId => (
      {...state, session: SessionActive(sess)},
      [LogInfo(`Session activated: ${sess.sessionId}`)],
    )

  | (_, SessionCreateSuccess(sess)) => (
      state,
      [CleanupSessionEffect({session: sess}), LogInfo(`Stale session ignored: ${sess.sessionId}`)],
    )

  | ({session: SessionCreating(expectedSessionId)}, SessionCreateError({sessionId, error}))
    if expectedSessionId == sessionId => (
      {...state, session: SessionError(error)},
      [LogError(`Session failed: ${error}`)],
    )

  | (
      {session: SessionActive({sessionId: expectedSessionId}) | SessionCreating(expectedSessionId)},
      SessionFailed({sessionId, error}),
    ) if expectedSessionId == sessionId => (
      {...state, session: SessionError(error)},
      [LogError(`Session failed: ${error}`)],
    )

  | (_, SessionFailed(_)) => (state, [LogInfo("Stale session failure ignored")])

  | (
      {
        acp: ACPConnected(conn),
        frameworkMCP: FrameworkMCPConnected | FrameworkMCPError(_),
        mcpServer: Some(mcpServer),
        session: NoSession,
      },
      CreateSession(request),
    ) => (
      {...state, session: SessionCreating(request.sessionId)},
      [CreateSessionEffect({connection: conn, mcpServer, request})],
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

  | ({session: NoSession | SessionCreating(_) | SessionError(_)}, SendPrompt({onComplete})) => (
      state,
      [
        NotifySendPromptRejected({onComplete, reason: "No active session"}),
        LogError("Cannot send prompt: no active session"),
      ],
    )

  | (
      {
        acp: ACPConnected(conn),
        frameworkMCP: FrameworkMCPConnected | FrameworkMCPError(_),
        mcpServer: Some(mcpServer),
        session: SessionActive({sessionId}),
      },
      LoadTask(request),
    ) if sessionId == request.taskId => (
      state,
      [LoadTaskEffect({connection: conn, mcpServer, request})],
    )

  | (
      {
        acp: ACPConnected(conn),
        frameworkMCP: FrameworkMCPConnected | FrameworkMCPError(_),
        mcpServer: Some(mcpServer),
        session: SessionActive(oldSession),
      },
      LoadTask(request),
    ) => (
      {...state, session: SessionCreating(request.taskId)},
      [
        CleanupSessionEffect({session: oldSession}),
        LoadTaskEffect({connection: conn, mcpServer, request}),
      ],
    )

  | (
      {
        acp: ACPConnected(conn),
        frameworkMCP: FrameworkMCPConnected | FrameworkMCPError(_),
        mcpServer: Some(mcpServer),
      },
      LoadTask(request),
    ) => (
      {...state, session: SessionCreating(request.taskId)},
      [LoadTaskEffect({connection: conn, mcpServer, request})],
    )

  | (_, LoadTask(request)) => (
      state,
      [
        NotifyLoadTaskRejected({onComplete: request.onComplete, reason: "Not connected"}),
        LogError("Cannot load task: not connected"),
      ],
    )

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

  | ({session: SessionActive(oldSession)}, ClearSession) => (
      {...state, session: NoSession},
      [CleanupSessionEffect({session: oldSession})],
    )
  | (_, ClearSession) => ({...state, session: NoSession}, [])

  | (_, CreateSession(request)) => (
      state,
      [
        NotifyCreateSessionRejected({onComplete: request.onComplete, reason: "Not ready"}),
        LogError("Cannot create session: not ready"),
      ],
    )

  | (_, Initialize(_)) => (state, [LogInfo("Initialize ignored: already initialized")])

  | (_, ACPConnectSuccess(_) | ACPAuthRequiredReceived(_) | ACPConnectError(_)) => (
      state,
      [LogInfo("Stale ACP connection result ignored")],
    )

  | (_, FrameworkMCPConnectSuccess | FrameworkMCPConnectError(_)) => (
      state,
      [LogInfo("Stale framework MCP connection result ignored")],
    )

  | (_, SessionCreateError(_)) => (state, [LogInfo("Stale session create result ignored")])

  | ({session: NoSession | SessionCreating(_) | SessionError(_)}, CancelPrompt) => (
      state,
      [LogError("CancelPrompt rejected: no active session")],
    )
  }
}

let name = "ConnectionReducer"

let next = reduce

let cleanupSession = (session: ACP.session): unit => {
  ACP.cleanupSessionChannel(session)
  Log.debug(~ctx={"sessionId": session.sessionId}, "Cleaned up session channel")
}

let handleEffect = (effect: effect, state: state, dispatch: action => unit) => {
  let dispatchConfigOptions = (configOptions: option<array<_>>) =>
    configOptions->Option.forEach(opts =>
      Client__State__Store.dispatch(ConfigOptionsReceived({configOptions: opts}))
    )

  let dispatchSessionResult = configOptions => dispatchConfigOptions(configOptions)

  switch effect {
  | LogError(msg) => Log.error(msg)
  | LogInfo(msg) => Log.info(msg)
  | NotifyCreateSessionRejected({onComplete, reason}) => onComplete(Error(reason))
  | NotifyLoadTaskRejected({onComplete, reason}) => onComplete(Error(reason))
  | NotifySendPromptRejected({onComplete, reason}) => onComplete(Error(reason))
  | NotifyDeleteSessionRejected({onComplete, reason}) => onComplete(Error(reason))
  | ConnectACP({config, signal, initialAuthBehavior}) =>
    let connect = async () => {
      let result = await ACP.connect(config, ~signal)
      switch (signal.aborted, result) {
      | (true, Ok(conn)) =>
        ACP.disconnect(conn)
        Log.info("ACP connection aborted after connect (cleanup)")
      | (true, Error(_)) => Log.info("ACP connection aborted (cleanup)")
      | (false, Ok(conn)) =>
        switch ACP.getAgentAttributionConfiguration(conn) {
        | Some({agents, defaultAgentId}) =>
          Client__State.Actions.agentAttributionConfigured(~agentCatalog=agents, ~defaultAgentId)
          dispatch(ACPConnectSuccess(conn))
        | None =>
          ACP.disconnect(conn)
          dispatch(ACPConnectError("Frontman requires agent attribution v1"))
        }
      | (false, Error(err)) =>
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
    connect()->ignore
  | ConnectFrameworkMCP(client, signal) =>
    let connect = async () => {
      let result = await MCPClient.connect(client, ~signal)
      switch result {
      | Ok() =>
        dispatch(FrameworkMCPConnectSuccess)
        switch MCPClient.getState(client) {
        | Connected({tools, serverInfo}) =>
          Log.info(
            ~ctx={"tools": tools->Array.map(t => t.name)},
            `${serverInfo.name} v${serverInfo.version} - ${tools
              ->Array.length
              ->Int.toString} framework MCP tools available`,
          )
        | Disconnected | Error(_) => ()
        }
      | Error(err) =>
        switch signal.aborted {
        | true => Log.info("Framework MCP connection aborted (cleanup)")
        | false => dispatch(FrameworkMCPConnectError(err))
        }
      }
    }
    connect()->ignore
  | CreateSessionEffect({
      connection,
      mcpServer,
      request: {sessionId, onUpdate, onTitleUpdated, onMcpMessage, onComplete},
    }) =>
    let create = async () => {
      let mcpServerInterface = MCPServer.toInterface(mcpServer)
      let creationError = ref(None)
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
      | Ok((sess, sessionNewResult)) =>
        switch creationError.contents {
        | Some(error) =>
          ACP.cleanupSessionChannel(sess)
          onComplete(Error(error))
        | None =>
          dispatch(SessionCreateSuccess(sess))
          onComplete(Ok(sess.sessionId))
          dispatchSessionResult(sessionNewResult.configOptions)
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
  | CancelPromptEffect({session}) => ACP.cancelPrompt(session)

  | RetryTurnEffect({session, retriedErrorId}) => ACP.retryTurn(session, ~retriedErrorId)

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
      request: {taskId, needsHistory, onUpdate, onTitleUpdated, onMcpMessage, onComplete},
    }) =>
    let activateSession = async () => {
      let mcpServerInterface = MCPServer.toInterface(mcpServer)
      let activationError = ref(None)
      let result = switch needsHistory {
      | true =>
        let loadResult = await ACP.loadSession(
          connection,
          taskId,
          ~onLoadResult=result => dispatchSessionResult(result.configOptions),
          ~onUpdate,
          ~onTitleUpdated,
          ~onParseError=err => {
            activationError := Some(err)
            Client__TextDeltaBuffer.discardTask(taskId)
            dispatch(SessionFailed({sessionId: taskId, error: err}))
          },
          ~mcpServerInterface,
          ~onMcpMessage,
        )
        loadResult->Result.map(((session, _)) => session)
      | false =>
        await ACP.joinSession(
          connection,
          taskId,
          ~onUpdate=ACP.validatedUpdateHandler(connection, taskId, onUpdate),
          ~onTitleUpdated,
          ~onParseError=err => {
            activationError := Some(err)
            Client__TextDeltaBuffer.discardTask(taskId)
            dispatch(SessionFailed({sessionId: taskId, error: err}))
          },
          ~mcpServerInterface,
          ~onMcpMessage,
        )
      }
      switch result {
      | Ok(session) =>
        switch activationError.contents {
        | Some(error) =>
          ACP.cleanupSessionChannel(session)
          onComplete(Error(error))
        | None =>
          dispatch(SessionCreateSuccess(session))
          Log.info(~ctx={"taskId": taskId}, "Session activated")
          onComplete(Ok())
        }
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
