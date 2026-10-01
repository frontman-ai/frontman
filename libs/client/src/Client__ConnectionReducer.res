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
  loginUrl: string,
  clientName: string,
  clientVersion: string,
  _meta: JSON.t,
}

type authRequiredPayload = {loginUrl: string}

type connectionAttempt = Opening | Initializing(ACP.connection)

type sessionState =
  | NoSession
  | SessionCreating(string)
  | SessionActive(ACP.session)
  | SessionCreationFailed(string)
  | SessionFailed({session: ACP.session, error: string})

type readyState = {connection: ACP.connection, session: sessionState}

type acpState =
  | Connecting(connectionAttempt)
  | WaitingForSignIn(authRequiredPayload)
  | WaitingForAuthRetry(authRequiredPayload)
  | Authenticating({loginUrl: string, attempt: connectionAttempt})
  | Ready(readyState)
  | Closing({connection: ACP.connection, session: option<ACP.session>})
  | Failed(string)

type relayState =
  | RelayConnecting(Relay.t)
  | RelayConnected(Relay.t)
  | RelayError(Relay.t, string)

type initializedState = {
  config: ACP.config,
  abortController: WebAPI.EventTypes.abortController,
  mcpServer: MCPServer.t,
  relay: relayState,
  acp: acpState,
}

type state = Uninitialized | Initialized(initializedState)

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

let apiBaseUrlFromLoginUrl = (loginUrl: string): string => {
  let url = WebAPI.URL.make(~url=loginUrl)
  url.origin
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
  onComplete: result<unit, string> => unit,
}

type createSessionRequest = {
  sessionId: string,
  onUpdate: (string, ACPTypes.sessionUpdate) => unit,
  onTitleUpdated: (string, string) => unit,
  onComplete: result<string, string> => unit,
}

type action =
  | Initialize(initPayload)
  | Dispose
  | BeginAuthenticationRetry
  | RequireAuthentication
  | RetryAuthentication
  | BeginLogout
  | ACPConnectionAllocated(ACP.connection)
  | ACPConnectSuccess(ACP.connection)
  | ACPAuthRequiredReceived(authRequiredPayload)
  | ACPConnectError(string)
  | RelayConnectSuccess
  | RelayConnectError(string)
  | SessionCreateSuccess(ACP.session)
  | SessionCreateError({sessionId: string, error: ACP.requestError})
  | SessionFailed({sessionId: string, error: string})
  | CreateSession(createSessionRequest)
  | SendPrompt({
      text: string,
      additionalBlocks: array<ContentBlock.t>,
      onComplete: result<ACPTypes.promptResult, string> => unit,
      _meta: option<JSON.t>,
    })
  | SessionCommand(ACP.sessionCommand)
  | LoadTask(loadTaskRequest)
  | DeleteSession({taskId: string, onComplete: result<unit, string> => unit})
  | ClearSession

type effect =
  | LogError(string)
  | LogInfo(string)
  | TrackAnalytics(Client__Analytics.event)
  | ConnectACP({config: ACP.config, signal: WebAPI.EventTypes.abortSignal})
  | ScheduleAuthRetry({signal: WebAPI.EventTypes.abortSignal})
  | CleanupEffect(state)
  | CleanupConnectionEffect({connection: ACP.connection, session: option<ACP.session>})
  | LogoutEffect({
      connection: ACP.connection,
      session: option<ACP.session>,
      apiBaseUrl: string,
      signal: WebAPI.EventTypes.abortSignal,
    })
  | ConnectRelay(Relay.t, WebAPI.EventTypes.abortSignal)
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
  | SessionCommandEffect({session: ACP.session, command: ACP.sessionCommand})
  | FetchSessionsEffect(ACP.connection)
  | LoadTaskEffect({connection: ACP.connection, mcpServer: MCPServer.t, request: loadTaskRequest})
  | DeleteSessionEffect({
      connection: ACP.connection,
      taskId: string,
      onComplete: result<unit, string> => unit,
    })
  | NotifyDeleteSessionRejected({onComplete: result<unit, string> => unit, reason: string})
  | CleanupSessionEffect({session: ACP.session})

let initialState: state = Uninitialized

let ownedSession = session =>
  switch session {
  | SessionActive(session) | SessionFailed({session}) => Some(session)
  | NoSession | SessionCreating(_) | SessionCreationFailed(_) => None
  }

let relayFailureReason = message =>
  switch message {
  | message if message->String.startsWith("HTTP ") => Client__Analytics.HttpError
  | message if message->String.startsWith("Invalid tools response: ") =>
    Client__Analytics.InvalidResponse
  | _ => Client__Analytics.NetworkError
  }

module Selectors = {
  let getRelay = (state: state): option<Relay.t> =>
    switch state {
    | Uninitialized => None
    | Initialized({relay: RelayConnecting(relay) | RelayConnected(relay) | RelayError(relay, _)}) =>
      Some(relay)
    }

  let getSession = (state: state): option<ACP.session> =>
    switch state {
    | Initialized({acp: Ready({session: SessionActive(session)})}) => Some(session)
    | Uninitialized | Initialized(_) => None
    }

  type connectionStatus =
    | Disconnected
    | Connecting
    | LoggingOut
    | Connected
    | SessionActive(string)
    | Error(string)

  let getConnectionStatus = (state: state): connectionStatus =>
    switch state {
    | Uninitialized => Disconnected
    | Initialized({acp: Ready({session: SessionActive(session)})}) =>
      SessionActive(session.sessionId)
    | Initialized({acp: Ready({session: SessionCreationFailed(error) | SessionFailed({error})})}) =>
      Error(error)
    | Initialized({acp: Closing(_)}) => LoggingOut
    | Initialized({acp: Failed(error)}) => Error(error)
    | Initialized({relay: RelayError(_, error)}) => Error(error)
    | Initialized({acp: Ready(_), relay: RelayConnected(_)}) => Connected
    | Initialized({acp: Ready(_) | Connecting(_)}) => Connecting
    | Initialized({acp: WaitingForSignIn(_) | WaitingForAuthRetry(_) | Authenticating(_)}) =>
      Disconnected
    }

  let getAuthRedirectUrl = (state: state): option<string> =>
    switch state {
    | Initialized({
        acp:
          WaitingForSignIn({loginUrl})
          | WaitingForAuthRetry({loginUrl})
          | Authenticating({loginUrl}),
      }) =>
      Some(loginUrl)
    | Uninitialized | Initialized(_) => None
    }
}

let cleanup = (state: state): unit => {
  switch state {
  | Uninitialized => ()
  | Initialized(runtime) =>
    WebAPI.AbortController.abort(runtime.abortController)
    Selectors.getRelay(state)->Option.forEach(Relay.disconnect)
    switch runtime.acp {
    | Connecting(Initializing(connection)) | Authenticating({attempt: Initializing(connection)}) =>
      ACP.disconnect(connection)
    | Ready({connection, session}) => ACP.disconnect(connection, ~session=?ownedSession(session))
    | Closing({connection, session}) => ACP.disconnect(connection, ~session?)
    | Connecting(Opening)
    | Authenticating({attempt: Opening})
    | WaitingForSignIn(_)
    | WaitingForAuthRetry(_)
    | Failed(_) => ()
    }
  }
}

let reduce = (state: state, action: action): (state, array<effect>) => {
  switch (state, action) {
  | (Uninitialized, Dispose) => (initialState, [])
  | (Initialized(_), Dispose) => (initialState, [CleanupEffect(state)])

  | (Uninitialized, Initialize({config, relay, mcpServer})) =>
    let acpConfig = ACP.makeConfig(
      ~endpoint=config.endpoint,
      ~loginUrl=config.loginUrl,
      ~getAuthToken=Client__EmbeddedAuth.loadToken,
      ~name=config.clientName,
      ~version=config.clientVersion,
      ~_meta=config._meta,
      ~onConfigOptionsUpdated=configOptions => {
        Client__State__Store.dispatch(ConfigOptionsReceived({configOptions: configOptions}))
      },
      ~onBillingStatusUpdated=payload => {
        switch FrontmanAiFrontmanClient.FrontmanClient__Decoders.parseSchema(
          payload,
          Client__Billing.statusSchema,
        ) {
        | Ok(status) => Client__State__Store.dispatch(BillingStatusReceived(status))
        | Error(_) =>
          Client__State__Store.dispatch(
            BillingStatusError({error: "Failed to parse billing status"}),
          )
        }
      },
    )
    let abortController = WebAPI.AbortController.make()
    (
      Initialized({
        config: acpConfig,
        abortController,
        mcpServer,
        relay: RelayConnecting(relay),
        acp: Connecting(Opening),
      }),
      [
        ConnectACP({config: acpConfig, signal: abortController.signal}),
        ConnectRelay(relay, abortController.signal),
      ],
    )

  | (Initialized({acp: Connecting(Opening)} as runtime), ACPConnectionAllocated(connection)) => (
      Initialized({...runtime, acp: Connecting(Initializing(connection))}),
      [],
    )
  | (
      Initialized({acp: Authenticating({loginUrl, attempt: Opening})} as runtime),
      ACPConnectionAllocated(connection),
    ) => (
      Initialized({...runtime, acp: Authenticating({loginUrl, attempt: Initializing(connection)})}),
      [],
    )
  | (_, ACPConnectionAllocated(connection)) => (
      state,
      [CleanupConnectionEffect({connection, session: None})],
    )

  | (
      Initialized(
        {
          acp:
            Connecting(Initializing(expected)) | Authenticating({attempt: Initializing(expected)}),
        } as runtime,
      ),
      ACPConnectSuccess(connection),
    ) if expected === connection => (
      Initialized({...runtime, acp: Ready({connection, session: NoSession})}),
      [FetchSessionsEffect(connection)],
    )

  | (
      Initialized({acp: Connecting(_) | WaitingForSignIn(_)} as runtime),
      ACPAuthRequiredReceived({loginUrl}),
    ) => (Initialized({...runtime, acp: WaitingForSignIn({loginUrl: loginUrl})}), [])
  | (
      Initialized({acp: WaitingForAuthRetry(_) | Authenticating(_)} as runtime),
      ACPAuthRequiredReceived({loginUrl}),
    ) => (
      Initialized({...runtime, acp: WaitingForAuthRetry({loginUrl: loginUrl})}),
      [ScheduleAuthRetry({signal: runtime.abortController.signal})],
    )

  | (
      Initialized({acp: WaitingForSignIn({loginUrl}) | WaitingForAuthRetry({loginUrl})} as runtime),
      BeginAuthenticationRetry | RetryAuthentication,
    ) => (
      Initialized({...runtime, acp: Authenticating({loginUrl, attempt: Opening})}),
      [ConnectACP({config: runtime.config, signal: runtime.abortController.signal})],
    )

  | (Initialized({acp: Ready({connection, session})} as runtime), RequireAuthentication) =>
    let framework = runtime.config.clientInfo._meta->Option.flatMap(frameworkFromClientInfoMeta)
    (
      Initialized({
        ...runtime,
        acp: WaitingForSignIn({
          loginUrl: enrichLoginUrl(~loginUrl=runtime.config.loginUrl, ~framework),
        }),
      }),
      [CleanupConnectionEffect({connection, session: ownedSession(session)})],
    )
  | (_, BeginAuthenticationRetry | RequireAuthentication | RetryAuthentication) => (state, [])

  | (Initialized({acp: Ready({connection, session})} as runtime), BeginLogout) =>
    let session = ownedSession(session)
    (
      Initialized({...runtime, acp: Closing({connection, session})}),
      [
        LogoutEffect({
          connection,
          session,
          apiBaseUrl: apiBaseUrlFromLoginUrl(runtime.config.loginUrl),
          signal: runtime.abortController.signal,
        }),
      ],
    )
  | (_, BeginLogout) => (state, [])

  | (Initialized({acp: Connecting(_)} as runtime), ACPConnectError(error)) => (
      Initialized({...runtime, acp: Failed(error)}),
      [LogError(`ACP connect failed: ${error}`)],
    )
  | (Initialized({acp: Authenticating({loginUrl})} as runtime), ACPConnectError(error)) => (
      Initialized({...runtime, acp: WaitingForAuthRetry({loginUrl: loginUrl})}),
      [
        LogInfo(`ACP auth retry failed: ${error}`),
        ScheduleAuthRetry({signal: runtime.abortController.signal}),
      ],
    )

  | (Initialized({relay: RelayConnecting(relay)} as runtime), RelayConnectSuccess) => (
      Initialized({...runtime, relay: RelayConnected(relay)}),
      [TrackAnalytics(RelayConnectionCompleted(Success))],
    )
  | (Initialized({relay: RelayConnecting(relay)} as runtime), RelayConnectError(message)) => (
      Initialized({...runtime, relay: RelayError(relay, message)}),
      [
        LogError(`Project context connection failed: ${message}`),
        TrackAnalytics(RelayConnectionCompleted(Failure(relayFailureReason(message)))),
      ],
    )

  | (
      Initialized({acp: Ready({session: SessionCreating(expectedSessionId)} as ready)} as runtime),
      SessionCreateSuccess(session),
    ) if expectedSessionId == session.sessionId => (
      Initialized({...runtime, acp: Ready({...ready, session: SessionActive(session)})}),
      [LogInfo(`Session activated: ${session.sessionId}`)],
    )
  | (_, SessionCreateSuccess(session)) => (
      state,
      [
        CleanupSessionEffect({session: session}),
        LogInfo(`Stale session ignored: ${session.sessionId}`),
      ],
    )

  | (
      Initialized({acp: Ready({session: SessionCreating(expectedSessionId)} as ready)} as runtime),
      SessionCreateError({sessionId, error}),
    ) if expectedSessionId == sessionId => {
      let session = switch ACP.requestErrorIsBillingInactive(error) {
      | true => NoSession
      | false => SessionCreationFailed(ACP.requestErrorMessage(error))
      }
      (
        Initialized({...runtime, acp: Ready({...ready, session})}),
        [LogError(`Session failed: ${ACP.requestErrorMessage(error)}`)],
      )
    }

  | (
      Initialized(
        {
          acp: Ready({session: SessionActive({sessionId: expectedSessionId} as session)} as ready),
        } as runtime,
      ),
      SessionFailed({sessionId, error}),
    ) if expectedSessionId == sessionId => (
      Initialized({...runtime, acp: Ready({...ready, session: SessionFailed({session, error})})}),
      [LogError(`Session failed: ${error}`)],
    )
  | (
      Initialized({acp: Ready({session: SessionCreating(expectedSessionId)} as ready)} as runtime),
      SessionFailed({sessionId, error}),
    ) if expectedSessionId == sessionId => (
      Initialized({...runtime, acp: Ready({...ready, session: SessionCreationFailed(error)})}),
      [LogError(`Session failed: ${error}`)],
    )
  | (_, SessionFailed(_)) => (state, [LogInfo("Stale session failure ignored")])

  | (
      Initialized({acp: Ready({session: NoSession} as ready), relay: RelayConnected(_)} as runtime),
      CreateSession(request),
    ) => (
      Initialized({
        ...runtime,
        acp: Ready({...ready, session: SessionCreating(request.sessionId)}),
      }),
      [CreateSessionEffect({connection: ready.connection, mcpServer: runtime.mcpServer, request})],
    )

  | (
      Initialized({acp: Ready({session: SessionActive(session)})}),
      SendPrompt({text, additionalBlocks, onComplete, _meta}),
    ) => (state, [SendPromptEffect({session, text, additionalBlocks, onComplete, _meta})])
  | (Initialized({acp: Ready({session: SessionActive(session)})}), SessionCommand(command)) => (
      state,
      [SessionCommandEffect({session, command})],
    )
  | (_, SessionCommand(_)) => (state, [LogError("Cannot send session command: no active session")])
  | (_, SendPrompt(_)) => (state, [LogError("Cannot send prompt: no active session")])

  | (
      Initialized({acp: Ready({connection, session: SessionActive({sessionId})})} as runtime),
      LoadTask(request),
    ) if sessionId == request.taskId => (
      state,
      [LoadTaskEffect({connection, mcpServer: runtime.mcpServer, request})],
    )
  | (Initialized({acp: Ready(ready)} as runtime), LoadTask(request)) => {
      let cleanup = switch ownedSession(ready.session) {
      | Some(session) => [CleanupSessionEffect({session: session})]
      | None => []
      }
      (
        Initialized({...runtime, acp: Ready({...ready, session: SessionCreating(request.taskId)})}),
        Array.concat(
          cleanup,
          [LoadTaskEffect({connection: ready.connection, mcpServer: runtime.mcpServer, request})],
        ),
      )
    }
  | (_, LoadTask(_)) => (state, [LogError("Cannot load task: not connected")])

  | (Initialized({acp: Ready({connection})}), DeleteSession({taskId, onComplete})) => (
      state,
      [DeleteSessionEffect({connection, taskId, onComplete})],
    )
  | (_, DeleteSession({onComplete, _})) => (
      state,
      [
        NotifyDeleteSessionRejected({onComplete, reason: "Not connected"}),
        LogError("Cannot delete session: not connected"),
      ],
    )

  | (Initialized({acp: Ready(ready)} as runtime), ClearSession) => {
      let effects = switch ownedSession(ready.session) {
      | Some(session) => [CleanupSessionEffect({session: session})]
      | None => []
      }
      (Initialized({...runtime, acp: Ready({...ready, session: NoSession})}), effects)
    }
  | (_, ClearSession) => (state, [])
  | (_, CreateSession(_)) => (state, [LogError("Cannot create session: not ready")])
  | (_, Initialize(_)) => (state, [LogInfo("Initialize ignored: already initialized")])
  | (_, ACPConnectSuccess(connection)) => (
      state,
      [
        CleanupConnectionEffect({connection, session: None}),
        LogInfo("Stale ACP connection result ignored"),
      ],
    )
  | (_, ACPAuthRequiredReceived(_) | ACPConnectError(_)) => (
      state,
      [LogInfo("Stale ACP connection result ignored")],
    )
  | (_, RelayConnectSuccess | RelayConnectError(_)) => (
      state,
      [LogInfo("Stale relay connection result ignored")],
    )
  | (_, SessionCreateError(_)) => (state, [LogInfo("Stale session create result ignored")])
  }
}

let name = "ConnectionReducer"
let next = reduce

let cleanupSession = (session: ACP.session): unit => {
  ACP.cleanupSessionChannel(session)
  Log.debug(~ctx={"sessionId": session.sessionId}, "Cleaned up session channel")
}

let revokeEmbeddedClientToken = async (
  ~apiBaseUrl: string,
  ~signal: WebAPI.EventTypes.abortSignal,
) => {
  switch Client__EmbeddedAuth.headers() {
  | Some(headers) =>
    try {
      let response = await WebAPI.Fetch.fetch(
        `${apiBaseUrl}/api/client-token`,
        ~init={method: "DELETE", headers, signal: Null.make(signal)},
      )
      switch response.status {
      | 204 | 401 => ()
      | status => Log.error(`Embedded token revocation failed: HTTP ${status->Int.toString}`)
      }
    } catch {
    | exn =>
      switch exn->JsExn.fromException->Option.map(FrontmanBindings.JsException.name) {
      | Some("AbortError") | Some("TypeError") => ()
      | _ => throw(exn)
      }
    }
  | None => ()
  }
  Client__EmbeddedAuth.clearToken()
  WebAPI.Window.current->WebAPI.Window.location->WebAPI.Location.reload
}

let billingRequestErrorMessage = error => {
  switch ACP.requestErrorIsBillingInactive(error) {
  | true => Client__State.Actions.openSettingsModalOnBilling()
  | false => ()
  }
  ACP.requestErrorMessage(error)
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
  | TrackAnalytics(event) => Client__Analytics.track(event)
  | NotifyDeleteSessionRejected({onComplete, reason}) => onComplete(Error(reason))
  | CleanupEffect(state) => cleanup(state)
  | CleanupConnectionEffect({connection, session}) => ACP.disconnect(connection, ~session?)
  | ConnectACP({config, signal}) =>
    let connect = async () => {
      let result = await ACP.connect(config, ~signal, ~onConnectionCreated=connection =>
        dispatch(ACPConnectionAllocated(connection))
      )
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
          dispatch(ACPAuthRequiredReceived({loginUrl: enrichLoginUrl(~loginUrl, ~framework)}))
        | ACP.ConnectionFailed(msg) => dispatch(ACPConnectError(msg))
        }
      }
    }
    connect()->ignore
  | ScheduleAuthRetry({signal}) =>
    let _ = WebAPI.Window.setTimeout(WebAPI.Window.current, ~timeout=2000, ~handler=() => {
      switch signal.aborted {
      | true => ()
      | false => dispatch(RetryAuthentication)
      }
    })
  | LogoutEffect({connection, session, apiBaseUrl, signal}) =>
    ACP.disconnect(connection, ~session?)
    revokeEmbeddedClientToken(~apiBaseUrl, ~signal)->ignore
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
      request: {sessionId, onUpdate, onTitleUpdated, onComplete},
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
        onComplete(Error(billingRequestErrorMessage(err)))
      }
    }
    create()->ignore
  | SendPromptEffect({session, text, additionalBlocks, onComplete, _meta}) =>
    let send = async () => {
      try {
        let result = await ACP.sendPrompt(session, text, ~additionalBlocks, ~_meta)
        onComplete(result->Result.mapError(billingRequestErrorMessage))
      } catch {
      | exn =>
        onComplete(Error("sendPrompt exception"))
        throw(exn)
      }
    }
    send()->ignore
  | SessionCommandEffect({session, command}) => ACP.sendSessionCommand(session, command)
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
      request: {taskId, needsHistory, onUpdate, onTitleUpdated, onComplete},
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
        )
      }
      switch result {
      | Ok(session) =>
        dispatch(SessionCreateSuccess(session))
        Log.info(~ctx={"taskId": taskId}, "Session activated")
        onComplete(Ok())
      | Error(err) =>
        dispatch(SessionCreateError({sessionId: taskId, error: ACP.requestErrorFromMessage(err)}))
        Log.error(~ctx={"error": err}, "Failed to activate session")
        onComplete(Error(err))
      }
    }
    switch state {
    | Initialized({acp: Ready({session: SessionActive({sessionId})})}) if sessionId == taskId =>
      onComplete(Ok())
    | Uninitialized | Initialized(_) => activateSession()->ignore
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
