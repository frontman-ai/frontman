module Log = FrontmanLogs.Logs.Make({
  let component = #ConnectionReducer
})

module ACP = FrontmanAiFrontmanClient.FrontmanClient__ACP
module ACPTypes = FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP
module ContentBlock = FrontmanAiFrontmanProtocol.FrontmanProtocol__ContentBlock
module Relay = FrontmanAiFrontmanClient.FrontmanClient__Relay
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
  | ACPLoggingOut
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
  | SessionCreating(string)
  | SessionActive(ACP.session)
  | SessionError(string)

type state = {
  acp: acpState,
  acpConfig: option<ACP.config>,
  authRetryActive: bool,
  authRetryInFlight: bool,
  relay: relayState,
  session: sessionState,
  relayInstance: option<Relay.t>,
  mcpServer: option<MCPServer.t>,
  abortController: option<WebAPI.EventAPI.abortController>,
}

@schema
type clientInfoMeta = {framework: option<string>}

let frameworkFromClientInfoMeta = (meta: JSON.t): option<string> =>
  S.parseOrThrow(meta, ~to=clientInfoMetaSchema).framework

let enrichLoginUrl = (~loginUrl: string, ~framework: option<string>): string => {
  let url = WebAPI.URL.make(~url=loginUrl)
  url.searchParams->WebAPI.URLSearchParams.set(~name="return_to", ~value="/users/popup-complete")
  switch framework {
  | Some(framework) =>
    url.searchParams->WebAPI.URLSearchParams.set(~name="framework", ~value=framework)
  | None => ()
  }
  url.href
}

type initPayload = {
  config: initConfig,
  relay: Relay.t,
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
  | BeginAuthenticationRetry
  | RetryAuthentication
  | BeginLogout
  | ACPConnectSuccess(ACP.connection)
  | ACPAuthRequiredReceived(authRequiredPayload)
  | ACPConnectError(string)
  | RelayConnectSuccess
  | RelayConnectError(string)
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
  | TrackRelay(Client__Heap.relayOutcome)
  | ConnectACP({config: ACP.config, signal: WebAPI.EventAPI.abortSignal})
  | ScheduleAuthRetry({signal: WebAPI.EventAPI.abortSignal})
  | Logout(ACP.connection, option<ACP.session>, string, WebAPI.EventAPI.abortSignal)
  | ConnectRelay(Relay.t, WebAPI.EventAPI.abortSignal)
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
  | NotifyDeleteSessionRejected({onComplete: result<unit, string> => unit, reason: string})
  | CleanupSessionEffect({session: ACP.session})

let initialState: state = {
  acp: ACPDisconnected,
  acpConfig: None,
  authRetryActive: false,
  authRetryInFlight: false,
  relay: RelayDisconnected,
  session: NoSession,
  relayInstance: None,
  mcpServer: None,
  abortController: None,
}

let relayFailureReason = message =>
  switch message {
  | message if message->String.startsWith("HTTP ") => Client__Heap.HttpError
  | message if message->String.startsWith("Invalid tools response: ") =>
    Client__Heap.InvalidResponse
  | _ => Client__Heap.NetworkError
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
    | LoggingOut
    | Connected
    | SessionActive(string)
    | Error(string)

  let getConnectionStatus = (state: state): connectionStatus => {
    switch (state.acp, state.relay, state.session) {
    | (_, _, SessionActive(sess)) => SessionActive(sess.sessionId)
    | (_, _, SessionError(msg)) => Error(msg)
    | (ACPError(msg), _, _) => Error(msg)
    | (_, RelayError(msg), _) => Error(msg)
    | (ACPConnected(_), RelayConnected, _) => Connected
    | (ACPConnecting, _, _) => Connecting
    | (ACPLoggingOut, _, _) => LoggingOut
    | (ACPConnected(_), RelayConnecting | RelayDisconnected, _) => Connecting
    | (ACPAuthRequired(_), _, _) => Disconnected
    | (ACPDisconnected, _, _) => Disconnected
    }
  }

  let getAuthRedirectUrl = (state: state): option<string> => {
    switch state.acp {
    | ACPAuthRequired({loginUrl}) => Some(loginUrl)
    | ACPDisconnected | ACPConnecting | ACPLoggingOut | ACPConnected(_) | ACPError(_) => None
    }
  }
}

let reduce = (state: state, action: action): (state, array<effect>) => {
  switch (state, action) {
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
    let abortController = WebAPI.AbortController.make()
    (
      {
        acp: ACPConnecting,
        acpConfig: Some(acpConfig),
        authRetryActive: false,
        authRetryInFlight: false,
        relay: RelayConnecting,
        session: NoSession,
        relayInstance: Some(relay),
        mcpServer: Some(mcpServer),
        abortController: Some(abortController),
      },
      [
        ConnectACP({
          config: acpConfig,
          signal: abortController.signal,
        }),
        ConnectRelay(relay, abortController.signal),
      ],
    )

  | ({acp: ACPConnecting}, ACPConnectSuccess(conn)) => (
      {
        ...state,
        acp: ACPConnected(conn),
        authRetryActive: false,
        authRetryInFlight: false,
      },
      [FetchSessionsEffect(conn)],
    )

  | (
      {acp: ACPAuthRequired(_), authRetryActive: true, authRetryInFlight: true},
      ACPConnectSuccess(conn),
    ) => (
      {
        ...state,
        acp: ACPConnected(conn),
        authRetryActive: false,
        authRetryInFlight: false,
      },
      [FetchSessionsEffect(conn)],
    )

  | (
      {acp: ACPConnecting | ACPAuthRequired(_), authRetryActive},
      ACPAuthRequiredReceived({loginUrl}),
    ) => {
      let effects = switch (authRetryActive, state.abortController) {
      | (true, Some(signalController)) => [ScheduleAuthRetry({signal: signalController.signal})]
      | _ => []
      }
      ({...state, acp: ACPAuthRequired({loginUrl: loginUrl}), authRetryInFlight: false}, effects)
    }

  | (
      {
        acp: ACPAuthRequired(_),
        acpConfig: Some(config),
        abortController: Some(signalController),
        authRetryInFlight: false,
      },
      BeginAuthenticationRetry | RetryAuthentication,
    ) => (
      {...state, authRetryActive: true, authRetryInFlight: true},
      [ConnectACP({config, signal: signalController.signal})],
    )

  | (_, BeginAuthenticationRetry | RetryAuthentication) => (state, [])

  | (
      {
        acp: ACPConnected(connection),
        acpConfig: Some(config),
        abortController: Some(signalController),
      },
      BeginLogout,
    ) => {
      let session = switch state.session {
      | SessionActive(session) => Some(session)
      | NoSession | SessionCreating(_) | SessionError(_) => None
      }
      (
        {
          ...state,
          acp: ACPLoggingOut,
          authRetryActive: false,
          authRetryInFlight: false,
          session: NoSession,
        },
        [Logout(connection, session, config.tokenUrl, signalController.signal)],
      )
    }

  | (_, BeginLogout) => (state, [])

  | ({acp: ACPConnecting}, ACPConnectError(msg)) => (
      {...state, acp: ACPError(msg), authRetryActive: false, authRetryInFlight: false},
      [LogError(`ACP connect failed: ${msg}`)],
    )

  | (
      {
        acp: ACPAuthRequired(_),
        authRetryActive: true,
        authRetryInFlight: true,
        abortController: Some(signalController),
      },
      ACPConnectError(msg),
    ) => (
      {...state, authRetryInFlight: false},
      [
        LogInfo(`ACP auth retry failed: ${msg}`),
        ScheduleAuthRetry({signal: signalController.signal}),
      ],
    )

  | ({relay: RelayConnecting}, RelayConnectSuccess) => (
      {...state, relay: RelayConnected},
      [TrackRelay(Success)],
    )

  | ({relay: RelayConnecting}, RelayConnectError(message)) => (
      {...state, relay: RelayError(message)},
      [TrackRelay(Failure(relayFailureReason(message)))],
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
        relay: RelayConnected,
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

  | ({session: NoSession | SessionCreating(_) | SessionError(_)}, SendPrompt(_)) => (
      state,
      [LogError("Cannot send prompt: no active session")],
    )

  | (
      {acp: ACPConnected(conn), mcpServer: Some(mcpServer), session: SessionActive({sessionId})},
      LoadTask(request),
    ) if sessionId == request.taskId => (
      state,
      [LoadTaskEffect({connection: conn, mcpServer, request})],
    )

  | (
      {acp: ACPConnected(conn), mcpServer: Some(mcpServer), session: SessionActive(oldSession)},
      LoadTask(request),
    ) => (
      {...state, session: SessionCreating(request.taskId)},
      [
        CleanupSessionEffect({session: oldSession}),
        LoadTaskEffect({connection: conn, mcpServer, request}),
      ],
    )

  | ({acp: ACPConnected(conn), mcpServer: Some(mcpServer)}, LoadTask(request)) => (
      {...state, session: SessionCreating(request.taskId)},
      [LoadTaskEffect({connection: conn, mcpServer, request})],
    )

  | (_, LoadTask(_)) => (state, [LogError("Cannot load task: not connected")])

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

  | (_, CreateSession(_)) => (state, [LogError("Cannot create session: not ready")])

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
  | TrackRelay(outcome) => Client__Heap.trackRelayConnection(outcome)
  | NotifyDeleteSessionRejected({onComplete, reason}) => onComplete(Error(reason))
  | ConnectACP({config, signal}) =>
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
          let framework = config.clientInfo._meta->Option.flatMap(frameworkFromClientInfoMeta)
          dispatch(
            ACPAuthRequiredReceived({
              loginUrl: enrichLoginUrl(~loginUrl, ~framework),
            }),
          )
        | ACP.ConnectionFailed(msg) => dispatch(ACPConnectError(msg))
        }
      }
    }
    connect()->ignore
  | ScheduleAuthRetry({signal}) =>
    let _ = WebAPI.Global.setTimeout(~timeout=2000, ~handler=() => {
      switch signal.aborted {
      | true => ()
      | false => dispatch(RetryAuthentication)
      }
    })
  | Logout(connection, session, tokenUrl, signal) =>
    ACP.disconnect(connection, ~session?)
    let rec check = attempt => {
      let _ = WebAPI.Global.setTimeout(~timeout=1000, ~handler=() => {
        let poll = async () => {
          try {
            let controller = WebAPI.AbortController.make()
            let timeout = WebAPI.Global.setTimeout(~timeout=1000, ~handler=() =>
              WebAPI.AbortController.abort(controller)
            )
            let response = await WebAPI.Global.fetch(
              tokenUrl,
              ~init={credentials: Include, signal: Null.make(controller.signal)},
            )
            WebAPI.Global.clearTimeout(timeout)
            switch (signal.aborted, response.status) {
            | (true, _) => ()
            | (false, 401) => WebAPI.Global.window->WebAPI.Window.location->WebAPI.Location.reload
            | (false, _) if attempt < 15 => check(attempt + 1)
            | (false, _) => WebAPI.Global.window->WebAPI.Window.location->WebAPI.Location.reload
            }
          } catch {
          | _ if signal.aborted => ()
          | _ if attempt < 15 => check(attempt + 1)
          | _ => WebAPI.Global.window->WebAPI.Window.location->WebAPI.Location.reload
          }
        }
        poll()->ignore
      })
    }
    check(1)
  | ConnectRelay(relay, signal) =>
    let connect = async () => {
      let result = await Relay.connect(relay, ~signal)
      switch (signal.aborted, result) {
      | (true, Ok()) =>
        Relay.disconnect(relay)
        Log.info("Relay connection aborted after connect (cleanup)")
      | (true, Error(_)) => Log.info("Relay connection aborted (cleanup)")
      | (false, Ok()) => dispatch(RelayConnectSuccess)
      | (false, Error(message)) => dispatch(RelayConnectError(message))
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
      let result = switch needsHistory {
      | true =>
        let loadResult = await ACP.loadSession(
          connection,
          taskId,
          ~onLoadResult=result => dispatchSessionResult(result.configOptions),
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
        await ACP.joinSession(
          connection,
          taskId,
          ~onUpdate=ACP.validatedUpdateHandler(connection, taskId, onUpdate),
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
