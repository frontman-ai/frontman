module Log = FrontmanLogs.Logs.Make({
  let component = #ConnectionReducer
})

module ACP = FrontmanAiFrontmanClient.FrontmanClient__ACP
module ACPTypes = FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP
module Relay = FrontmanAiFrontmanClient.FrontmanClient__Relay
module MCPServer = FrontmanAiFrontmanClient.FrontmanClient__MCP__Server

type config = {
  acp: ACP.config,
  relay: Relay.config,
  mcp: MCPServer.config,
}

type authRequiredPayload = {loginUrl: string}
type connectionError = ACPError(string) | RelayError(string)
type connectError = AuthenticationRequired(authRequiredPayload) | ConnectionFailed(connectionError)

type sessionRequestId = ref<unit>
type configOptions = option<array<ACPTypes.sessionConfigOption>>

type activeSession = {
  session: ACP.session,
  requestId: sessionRequestId,
  configOptions: array<ACPTypes.sessionConfigOption>,
  configPending: bool,
  configError: option<string>,
}

type sessionState =
  | NoSession
  | SessionCreating({
      sessionId: option<string>,
      requestId: sessionRequestId,
      onComplete: option<result<string, string> => unit>,
    })
  | SessionActive(activeSession)
  | SessionCreationFailed(string)
  | SessionFailed({session: ACP.session, error: string})

type readyState = {
  connection: ACP.connection,
  relay: Relay.connected,
  mcpServer: MCPServer.t,
  session: sessionState,
}

type phase =
  | Connecting
  | WaitingForAuthentication(authRequiredPayload)
  | Authenticating(authRequiredPayload)
  | Ready(readyState)
  | Reconnecting(readyState)
  | LoggingOut

type runtime = {
  lifetimeAbortController: WebAPI.EventTypes.abortController,
  phase: phase,
}

type state = {
  config: config,
  connection: result<option<runtime>, connectionError>,
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

let apiBaseUrlFromLoginUrl = (loginUrl: string): string => {
  let url = WebAPI.URL.make(~url=loginUrl)
  url.origin
}

type action =
  | Initialize
  | Dispose
  | RequireAuthentication
  | RetryAuthentication
  | BeginLogout
  | ACPReconnecting({signal: WebAPI.EventTypes.abortSignal})
  | ACPReconnected({
      signal: WebAPI.EventTypes.abortSignal,
      result: result<ACP.connection, connectError>,
    })
  | ConnectionResultReceived({
      signal: WebAPI.EventTypes.abortSignal,
      result: result<readyState, connectError>,
    })
  | SessionResultReceived({
      requestId: sessionRequestId,
      sessionId: string,
      result: result<(ACP.session, configOptions), ACP.requestError>,
    })
  | CreateSession({
      sessionId: string,
      modelPreference: string,
      onComplete: result<string, string> => unit,
    })
  | SetModel(string)
  | ConfigOptionResult({
      requestId: sessionRequestId,
      result: result<ACPTypes.configOptionsUpdated, ACP.requestError>,
    })
  | SessionConfigReceived(array<ACPTypes.sessionConfigOption>)
  | SessionCommand(ACP.sessionCommand)
  | LoadTask({taskId: string})
  | DeleteSession({taskId: string})
  | ClearSession

type effect =
  | LogError(string)
  | LogInfo(string)
  | ConnectRuntime({config: config, signal: WebAPI.EventTypes.abortSignal})
  | ScheduleAuthRetry({signal: WebAPI.EventTypes.abortSignal})
  | CleanupEffect(runtime)
  | CleanupConnectionEffect(ACP.connection)
  | LogoutEffect({apiBaseUrl: string, signal: WebAPI.EventTypes.abortSignal})
  | ActivateSessionEffect({
      requestId: sessionRequestId,
      connection: ACP.connection,
      mcpServer: MCPServer.t,
      operation: [#create(string, string) | #load(string)],
    })
  | SetModelEffect({session: ACP.session, requestId: sessionRequestId, value: string})
  | SessionCommandEffect({session: ACP.session, command: ACP.sessionCommand})
  | FetchSessionsEffect({connection: ACP.connection, signal: WebAPI.EventTypes.abortSignal})
  | SessionCompletionEffect({
      sessionId: string,
      ready: readyState,
      result: result<configOptions, ACP.requestError>,
      onComplete: option<result<string, string> => unit>,
    })
  | DeleteSessionEffect({
      signal: WebAPI.EventTypes.abortSignal,
      connection: ACP.connection,
      taskId: string,
    })
  | TaskLoadFailed({taskId: string, error: string})
  | NotifyRequestRejected(unit => unit)
  | CleanupSessionEffect({session: ACP.session})

let initialState = (config: config): state => {config, connection: Ok(None)}

module Selectors = {
  let getRelay = (state: state): option<Relay.connected> =>
    switch state.connection {
    | Ok(Some({phase: Ready({relay})})) => Some(relay)
    | Ok(_) | Error(_) => None
    }

  let getSession = (state: state): option<ACP.session> =>
    switch state.connection {
    | Ok(Some({phase: Ready({session: SessionActive({session})})})) => Some(session)
    | Ok(_) | Error(_) => None
    }

  let sessionTaskId = (state: state): option<string> =>
    switch state.connection {
    | Ok(Some({phase: Ready({session}) | Reconnecting({session})})) =>
      switch session {
      | SessionCreating({sessionId}) => sessionId
      | SessionActive({session}) | SessionFailed({session}) => Some(session.sessionId)
      | NoSession | SessionCreationFailed(_) => None
      }
    | Ok(_) | Error(_) => None
    }

  let getSessionError = (state: state): option<string> =>
    switch state.connection {
    | Ok(Some({
        phase: Ready({
          session:
            SessionActive({configError: Some(error)})
            | SessionCreationFailed(error)
            | SessionFailed({error}),
        }),
      })) =>
      Some(error)
    | Ok(_) | Error(_) => None
    }

  type connectionStatus =
    | Disconnected
    | Connecting
    | LoggingOut
    | Connected
    | SessionActive(string)
    | Error(string)

  let getConnectionStatus = (state: state): connectionStatus =>
    switch state.connection {
    | Ok(None) => Disconnected
    | Error(ACPError(error) | RelayError(error)) => Error(error)
    | Ok(Some({phase: Ready({session: SessionActive({session})})})) =>
      SessionActive(session.sessionId)
    | Ok(Some({phase: Ready(_)})) => Connected
    | Ok(Some({phase: LoggingOut})) => LoggingOut
    | Ok(Some({phase: Connecting | Reconnecting(_)})) => Connecting
    | Ok(Some({phase: WaitingForAuthentication(_) | Authenticating(_)})) => Disconnected
    }

  let getAuthRedirectUrl = (state: state): option<string> =>
    switch state.connection {
    | Ok(Some({phase: WaitingForAuthentication({loginUrl}) | Authenticating({loginUrl})})) =>
      Some(loginUrl)
    | Ok(_) | Error(_) => None
    }
}

let releaseSession = (session, ~error="Conversation changed. Your message was not sent.") =>
  switch session {
  | SessionCreating({onComplete: Some(onComplete)}) => [
      NotifyRequestRejected(() => onComplete(Error(error))),
    ]
  | SessionCreating({sessionId, onComplete: None}) => [
      TaskLoadFailed({taskId: sessionId->Option.getOrThrow, error}),
    ]
  | SessionActive({session}) | SessionFailed({session}) => [
      CleanupSessionEffect({session: session}),
    ]
  | NoSession | SessionCreationFailed(_) => []
  }

let isCurrentConnection = (state: state, signal: WebAPI.EventTypes.abortSignal): bool =>
  switch state.connection {
  | Ok(Some({phase: Ready({connection}), lifetimeAbortController})) =>
    signal === lifetimeAbortController.signal && !signal.aborted && ACP.isInitialized(connection)
  | Ok(_) | Error(_) => false
  }

let isCurrentSessionRequest = (state: state, requestId: sessionRequestId): bool =>
  switch state.connection {
  | Ok(Some({
      phase: Ready({
        connection,
        session: SessionCreating({requestId: expected}) | SessionActive({requestId: expected}),
      }),
      lifetimeAbortController,
    })) =>
    requestId === expected &&
    !lifetimeAbortController.signal.aborted &&
    ACP.isInitialized(connection)
  | Ok(_) | Error(_) => false
  }

let withPhase = (state: state, runtime: runtime, phase): state => {
  ...state,
  connection: Ok(Some({...runtime, phase})),
}

let withSession = (state, runtime, ready: readyState, session) => {
  let ready = {...ready, session}
  (withPhase(state, runtime, Ready(ready)), ready)
}

let startSession = (
  state: state,
  runtime: runtime,
  ready: readyState,
  ~operation,
  ~onComplete=None,
) => {
  let sessionId = switch operation {
  | #create(id, _) | #load(id) => Some(id)
  }
  let requestId = ref()
  let (state, _) = withSession(
    state,
    runtime,
    ready,
    SessionCreating({sessionId, requestId, onComplete}),
  )
  (
    state,
    [
      ...releaseSession(ready.session),
      ActivateSessionEffect({
        requestId,
        connection: ready.connection,
        mcpServer: ready.mcpServer,
        operation,
      }),
    ],
  )
}

let reduce = (state: state, action: action): (state, array<effect>) => {
  switch (state.connection, action) {
  | (Ok(Some(runtime)), Dispose) => (initialState(state.config), [CleanupEffect(runtime)])
  | (Ok(None) | Error(_), Dispose) => (initialState(state.config), [])

  | (Ok(None), Initialize) =>
    let lifetimeAbortController = WebAPI.AbortController.make()
    (
      {...state, connection: Ok(Some({lifetimeAbortController, phase: Connecting}))},
      [ConnectRuntime({config: state.config, signal: lifetimeAbortController.signal})],
    )

  | (
      Ok(Some({phase: Connecting | Authenticating(_)} as runtime)),
      ConnectionResultReceived({signal, result}),
    ) if signal === runtime.lifetimeAbortController.signal && !signal.aborted =>
    switch result {
    | Ok(ready) => (
        withPhase(
          state,
          runtime,
          switch ACP.isInitialized(ready.connection) {
          | true => Ready(ready)
          | false => Reconnecting(ready)
          },
        ),
        [FetchSessionsEffect({connection: ready.connection, signal})],
      )
    | Error(AuthenticationRequired(payload)) =>
      let effects = switch runtime.phase {
      | Authenticating(_) => [ScheduleAuthRetry({signal: runtime.lifetimeAbortController.signal})]
      | Connecting | WaitingForAuthentication(_) | Ready(_) | Reconnecting(_) | LoggingOut => []
      }
      (withPhase(state, runtime, WaitingForAuthentication(payload)), effects)
    | Error(ConnectionFailed(ACPError(error))) =>
      switch runtime.phase {
      | Authenticating(payload) => (
          withPhase(state, runtime, WaitingForAuthentication(payload)),
          [
            LogInfo(`ACP auth retry failed: ${error}`),
            ScheduleAuthRetry({signal: runtime.lifetimeAbortController.signal}),
          ],
        )
      | Connecting | WaitingForAuthentication(_) | Ready(_) | Reconnecting(_) | LoggingOut => (
          {...state, connection: Error(ACPError(error))},
          [CleanupEffect(runtime), LogError(`ACP connect failed: ${error}`)],
        )
      }
    | Error(ConnectionFailed(RelayError(error))) => (
        {...state, connection: Error(RelayError(error))},
        [CleanupEffect(runtime), LogError(`Project context connection failed: ${error}`)],
      )
    }
  | (_, ConnectionResultReceived({result: Ok(ready)})) => (
      state,
      [CleanupConnectionEffect(ready.connection), LogInfo("Stale connection result ignored")],
    )
  | (_, ConnectionResultReceived({result: Error(_)})) => (
      state,
      [LogInfo("Stale connection result ignored")],
    )

  | (Ok(Some({phase: Ready(ready)} as runtime)), ACPReconnecting({signal}))
    if signal === runtime.lifetimeAbortController.signal && !signal.aborted =>
    let (session, effects) = switch ready.session {
    | SessionCreating(_) => (
        NoSession,
        releaseSession(ready.session, ~error="Connection lost; send again when ready"),
      )
    | session => (session, [])
    }
    (withPhase(state, runtime, Reconnecting({...ready, session})), effects)
  | (Ok(Some({phase: Reconnecting(ready)} as runtime)), ACPReconnected({signal, result}))
    if signal === runtime.lifetimeAbortController.signal && !signal.aborted =>
    switch result {
    | Ok(connection) if connection === ready.connection && ACP.isInitialized(connection) =>
      let (state, effects) = switch ready.session {
      | SessionActive({session}) | SessionFailed({session}) =>
        startSession(state, runtime, ready, ~operation=#load(session.sessionId))
      | _ => (withPhase(state, runtime, Ready(ready)), [])
      }
      (state, Array.concat(effects, [FetchSessionsEffect({connection, signal})]))
    | Ok(_) => (state, [])
    | Error(AuthenticationRequired(payload)) => (
        {
          ...state,
          connection: Ok(
            Some({
              lifetimeAbortController: WebAPI.AbortController.make(),
              phase: WaitingForAuthentication(payload),
            }),
          ),
        },
        [CleanupEffect(runtime)],
      )
    | Error(ConnectionFailed(error)) => (
        {...state, connection: Error(error)},
        [CleanupEffect(runtime)],
      )
    }
  | (_, ACPReconnecting(_) | ACPReconnected(_)) => (state, [])

  | (Ok(Some({phase: WaitingForAuthentication(payload)} as runtime)), RetryAuthentication) => (
      withPhase(state, runtime, Authenticating(payload)),
      [ConnectRuntime({config: state.config, signal: runtime.lifetimeAbortController.signal})],
    )

  | (Ok(Some({phase: Ready(_) | Reconnecting(_)} as runtime)), RequireAuthentication) =>
    let framework = state.config.acp.clientInfo._meta->Option.flatMap(frameworkFromClientInfoMeta)
    let phase = WaitingForAuthentication({
      loginUrl: enrichLoginUrl(~loginUrl=state.config.acp.loginUrl, ~framework),
    })
    (
      {
        ...state,
        connection: Ok(Some({lifetimeAbortController: WebAPI.AbortController.make(), phase})),
      },
      [CleanupEffect(runtime)],
    )
  | (_, RequireAuthentication | RetryAuthentication) => (state, [])

  | (Ok(Some({phase: Ready(_) | Reconnecting(_)} as runtime)), BeginLogout) =>
    let lifetimeAbortController = WebAPI.AbortController.make()
    (
      {...state, connection: Ok(Some({lifetimeAbortController, phase: LoggingOut}))},
      [
        CleanupEffect(runtime),
        LogoutEffect({
          apiBaseUrl: apiBaseUrlFromLoginUrl(state.config.acp.loginUrl),
          signal: lifetimeAbortController.signal,
        }),
      ],
    )
  | (_, BeginLogout) => (state, [])

  | (
      Ok(Some(
        {
          phase: Ready(
            {session: SessionCreating({sessionId: expectedSessionId, onComplete})} as ready,
          ),
        } as runtime,
      )),
      SessionResultReceived({requestId, sessionId, result: Ok((session, configOptions))}),
    )
    if isCurrentSessionRequest(state, requestId) &&
    sessionId == session.sessionId &&
    expectedSessionId->Option.mapOr(true, expected => expected == sessionId) =>
    let (state, ready) = withSession(
      state,
      runtime,
      ready,
      SessionActive({
        session,
        requestId,
        configOptions: configOptions->Option.getOr([]),
        configPending: false,
        configError: None,
      }),
    )
    (
      state,
      [
        SessionCompletionEffect({
          sessionId: session.sessionId,
          ready,
          result: Ok(configOptions),
          onComplete,
        }),
        LogInfo(`Session activated: ${session.sessionId}`),
      ],
    )
  | (_, SessionResultReceived({result: Ok((session, _))})) => (
      state,
      [
        CleanupSessionEffect({session: session}),
        LogInfo(`Stale session ignored: ${session.sessionId}`),
      ],
    )

  | (
      Ok(Some(
        {phase: Ready({session: SessionCreating(_) | SessionActive(_)} as ready)} as runtime,
      )),
      SessionResultReceived({requestId, sessionId, result: Error(error)}),
    ) if isCurrentSessionRequest(state, requestId) =>
    let onComplete = switch ready.session {
    | SessionCreating({onComplete}) => onComplete
    | _ => None
    }
    let session = switch (ready.session, ACP.requestErrorIsBillingInactive(error)) {
    | (SessionActive({session}), _) =>
      SessionFailed({session, error: ACP.requestErrorMessage(error)})
    | (_, true) => NoSession
    | (_, false) => SessionCreationFailed(ACP.requestErrorMessage(error))
    }
    let (state, ready) = withSession(state, runtime, ready, session)
    (
      state,
      [
        SessionCompletionEffect({sessionId, ready, result: Error(error), onComplete}),
        LogError(`Session failed: ${ACP.requestErrorMessage(error)}`),
      ],
    )
  | (_, SessionResultReceived({result: Error(_)})) => (
      state,
      [LogInfo("Stale session result ignored")],
    )

  | (
      Ok(Some({phase: Ready({session: NoSession | SessionCreationFailed(_)} as ready)} as runtime)),
      CreateSession({sessionId, modelPreference, onComplete}),
    ) =>
    startSession(
      state,
      runtime,
      ready,
      ~operation=#create(sessionId, modelPreference),
      ~onComplete=Some(onComplete),
    )

  | (
      Ok(Some({phase: Ready({session: SessionActive(active)} as ready)} as runtime)),
      SetModel(value),
    ) if !active.configPending => (
      withSession(
        state,
        runtime,
        ready,
        SessionActive({...active, configPending: true, configError: None}),
      )->Pair.first,
      [
        SetModelEffect({
          session: active.session,
          requestId: active.requestId,
          value,
        }),
      ],
    )
  | (
      Ok(Some({phase: Ready({session: SessionActive(active)} as ready)} as runtime)),
      ConfigOptionResult({requestId, result}),
    ) if isCurrentSessionRequest(state, requestId) =>
    let active = switch result {
    | Ok({configOptions}) => {...active, configOptions, configPending: false, configError: None}
    | Error(error) => {
        ...active,
        configPending: false,
        configError: Some(ACP.requestErrorMessage(error)),
      }
    }
    (withSession(state, runtime, ready, SessionActive(active))->Pair.first, [])
  | (
      Ok(Some({phase: Ready({session: SessionActive(active)} as ready)} as runtime)),
      SessionConfigReceived(configOptions),
    ) => (
      withSession(state, runtime, ready, SessionActive({...active, configOptions}))->Pair.first,
      [],
    )
  | (_, SetModel(_) | ConfigOptionResult(_) | SessionConfigReceived(_)) => (state, [])

  | (Ok(Some({phase: Ready({session: SessionActive({session})})})), SessionCommand(command)) => (
      state,
      [SessionCommandEffect({session, command})],
    )
  | (_, SessionCommand(_)) => (state, [LogError("Cannot send session command: no active session")])

  | (
      Ok(Some({phase: Ready({session: SessionActive({session: {sessionId}})} as ready)})),
      LoadTask(request),
    ) if sessionId == request.taskId => (
      state,
      [SessionCompletionEffect({sessionId, ready, result: Ok(None), onComplete: None})],
    )
  | (Ok(Some({phase: Ready(ready)} as runtime)), LoadTask({taskId})) =>
    startSession(state, runtime, ready, ~operation=#load(taskId))
  | (_, LoadTask({taskId})) => (
      state,
      [TaskLoadFailed({taskId, error: "Cannot load task: not connected"})],
    )

  | (Ok(Some({phase: Ready({connection}), lifetimeAbortController})), DeleteSession({taskId})) => (
      state,
      [
        DeleteSessionEffect({
          signal: lifetimeAbortController.signal,
          connection,
          taskId,
        }),
      ],
    )
  | (_, DeleteSession(_)) => (state, [LogError("Cannot delete session: not connected")])

  | (Ok(Some({phase: Ready(ready) | Reconnecting(ready)} as runtime)), ClearSession) =>
    let effects = releaseSession(ready.session)
    let ready = {...ready, session: NoSession}
    let phase = switch runtime.phase {
    | Reconnecting(_) => Reconnecting(ready)
    | _ => Ready(ready)
    }
    (withPhase(state, runtime, phase), effects)
  | (_, ClearSession) => (state, [])
  | (_, CreateSession({onComplete})) => (
      state,
      [NotifyRequestRejected(() => onComplete(Error("Cannot create session: not ready")))],
    )
  | (_, Initialize) => (state, [LogInfo("Initialize ignored: dispose before restarting")])
  }
}

let next = reduce
