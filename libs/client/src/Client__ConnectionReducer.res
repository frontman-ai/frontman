module Log = FrontmanLogs.Logs.Make({
  let component = #ConnectionReducer
})

module ACP = FrontmanAiFrontmanClient.FrontmanClient__ACP
module ACPTypes = FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP
module ContentBlock = FrontmanAiFrontmanProtocol.FrontmanProtocol__ContentBlock
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

type sessionState =
  | NoSession
  | SessionCreating({
      sessionId: option<string>,
      requestId: sessionRequestId,
      onComplete: result<string, string> => unit,
    })
  | SessionActive({session: ACP.session, requestId: sessionRequestId})
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

type loadTaskRequest = {
  taskId: string,
  needsHistory: bool,
  onComplete: result<unit, string> => unit,
}

type connectionCallback = {signal: WebAPI.EventTypes.abortSignal, callback: unit => unit}
type sessionCallback = {
  requestId: sessionRequestId,
  callback: unit => unit,
  onConnectionLost: option<unit => unit>,
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
      onComplete: result<string, string> => unit,
    })
  | ConnectionCallbackReceived(connectionCallback)
  | SessionCallbackReceived(sessionCallback)
  | CreateSession({sessionId: string, onComplete: result<string, string> => unit})
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
  | ConnectRuntime({config: config, signal: WebAPI.EventTypes.abortSignal})
  | ScheduleAuthRetry({signal: WebAPI.EventTypes.abortSignal})
  | CleanupEffect(runtime)
  | CleanupConnectionEffect(ACP.connection)
  | LogoutEffect({apiBaseUrl: string, signal: WebAPI.EventTypes.abortSignal})
  | ActivateSessionEffect({
      requestId: sessionRequestId,
      connection: ACP.connection,
      mcpServer: MCPServer.t,
      operation: [#create(string) | #load(string) | #join(string)],
      onComplete: result<string, string> => unit,
    })
  | SendPromptEffect({
      requestId: sessionRequestId,
      session: ACP.session,
      text: string,
      additionalBlocks: array<ContentBlock.t>,
      onComplete: result<ACPTypes.promptResult, string> => unit,
      _meta: option<JSON.t>,
    })
  | SessionCommandEffect({session: ACP.session, command: ACP.sessionCommand})
  | FetchSessionsEffect({connection: ACP.connection, signal: WebAPI.EventTypes.abortSignal})
  | ConnectionCallbackEffect(connectionCallback)
  | SessionCallbackEffect(sessionCallback)
  | SessionCompletionEffect({
      sessionId: string,
      ready: readyState,
      result: result<configOptions, ACP.requestError>,
      onComplete: result<string, string> => unit,
    })
  | DeleteSessionEffect({
      signal: WebAPI.EventTypes.abortSignal,
      connection: ACP.connection,
      taskId: string,
      onComplete: result<unit, string> => unit,
    })
  | NotifyRequestRejected(unit => unit)
  | CleanupSessionEffect({session: ACP.session})

let initialState = (config: config): state => {config, connection: Ok(None)}

let ownedSession = session =>
  switch session {
  | SessionActive({session}) | SessionFailed({session}) => Some(session)
  | NoSession | SessionCreating(_) | SessionCreationFailed(_) => None
  }

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

  let getSessionError = (state: state): option<string> =>
    switch state.connection {
    | Ok(Some({phase: Ready({session: SessionCreationFailed(error) | SessionFailed({error})})})) =>
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

let cancelCreation = session =>
  switch session {
  | SessionCreating({onComplete}) =>
    onComplete(Error("Conversation changed. Your message was not sent."))
  | _ => ()
  }

let cleanupRuntime = (runtime: runtime): unit => {
  WebAPI.AbortController.abort(runtime.lifetimeAbortController)
  switch runtime.phase {
  | Ready({connection, session}) | Reconnecting({connection, session}) =>
    cancelCreation(session)
    ACP.disconnect(connection, ~session=?ownedSession(session))
  | Connecting | WaitingForAuthentication(_) | Authenticating(_) | LoggingOut => ()
  }
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

let startSession = (state: state, runtime: runtime, ready: readyState, ~operation, ~onComplete) => {
  let sessionId = switch operation {
  | #create(_) => None
  | #load(id) | #join(id) => Some(id)
  }
  let requestId = ref()
  let completed = ref(false)
  let onComplete = result =>
    switch completed.contents {
    | true => ()
    | false =>
      completed := true
      onComplete(result)
    }
  let cleanup = switch ready.session {
  | SessionCreating(_) => [NotifyRequestRejected(() => cancelCreation(ready.session))]
  | session =>
    switch ownedSession(session) {
    | Some(session) => [CleanupSessionEffect({session: session})]
    | None => []
    }
  }
  (
    {
      ...state,
      connection: Ok(
        Some({
          ...runtime,
          phase: Ready({...ready, session: SessionCreating({sessionId, requestId, onComplete})}),
        }),
      ),
    },
    [
      ...cleanup,
      ActivateSessionEffect({
        requestId,
        connection: ready.connection,
        mcpServer: ready.mcpServer,
        operation,
        onComplete,
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
        {
          ...state,
          connection: Ok(
            Some({
              ...runtime,
              phase: switch ACP.isInitialized(ready.connection) {
              | true => Ready(ready)
              | false => Reconnecting(ready)
              },
            }),
          ),
        },
        [FetchSessionsEffect({connection: ready.connection, signal})],
      )
    | Error(AuthenticationRequired(payload)) =>
      let effects = switch runtime.phase {
      | Authenticating(_) => [ScheduleAuthRetry({signal: runtime.lifetimeAbortController.signal})]
      | Connecting | WaitingForAuthentication(_) | Ready(_) | Reconnecting(_) | LoggingOut => []
      }
      (
        {...state, connection: Ok(Some({...runtime, phase: WaitingForAuthentication(payload)}))},
        effects,
      )
    | Error(ConnectionFailed(ACPError(error))) =>
      switch runtime.phase {
      | Authenticating(payload) => (
          {...state, connection: Ok(Some({...runtime, phase: WaitingForAuthentication(payload)}))},
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
    | SessionCreating({onComplete}) => (
        NoSession,
        [NotifyRequestRejected(() => onComplete(Error("Connection lost; send again when ready")))],
      )
    | session => (session, [])
    }
    (
      {...state, connection: Ok(Some({...runtime, phase: Reconnecting({...ready, session})}))},
      effects,
    )
  | (Ok(Some({phase: Reconnecting(ready)} as runtime)), ACPReconnected({signal, result}))
    if signal === runtime.lifetimeAbortController.signal && !signal.aborted =>
    switch result {
    | Ok(connection) if connection === ready.connection && ACP.isInitialized(connection) => (
        {...state, connection: Ok(Some({...runtime, phase: Ready(ready)}))},
        [FetchSessionsEffect({connection, signal})],
      )
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
      {...state, connection: Ok(Some({...runtime, phase: Authenticating(payload)}))},
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

  | (_, ConnectionCallbackReceived(callback)) => (state, [ConnectionCallbackEffect(callback)])
  | (_, SessionCallbackReceived(callback)) => (state, [SessionCallbackEffect(callback)])

  | (
      Ok(Some(
        {
          phase: Ready({session: SessionCreating({sessionId: expectedSessionId})} as ready),
        } as runtime,
      )),
      SessionResultReceived({
        requestId,
        sessionId,
        result: Ok((session, configOptions)),
        onComplete,
      }),
    )
    if isCurrentSessionRequest(state, requestId) &&
    sessionId == session.sessionId &&
    expectedSessionId->Option.mapOr(true, expected => expected == sessionId) =>
    let ready = {...ready, session: SessionActive({session, requestId})}
    (
      {...state, connection: Ok(Some({...runtime, phase: Ready(ready)}))},
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
      SessionResultReceived({requestId, sessionId, result: Error(error), onComplete}),
    ) if isCurrentSessionRequest(state, requestId) =>
    let session = switch (ownedSession(ready.session), ACP.requestErrorIsBillingInactive(error)) {
    | (Some(session), _) => SessionFailed({session, error: ACP.requestErrorMessage(error)})
    | (None, true) => NoSession
    | (None, false) => SessionCreationFailed(ACP.requestErrorMessage(error))
    }
    let ready = {...ready, session}
    (
      {...state, connection: Ok(Some({...runtime, phase: Ready(ready)}))},
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
      CreateSession({sessionId, onComplete}),
    ) =>
    startSession(state, runtime, ready, ~operation=#create(sessionId), ~onComplete)

  | (
      Ok(Some({phase: Ready({session: SessionActive({session, requestId})})})),
      SendPrompt({text, additionalBlocks, onComplete, _meta}),
    ) => (
      state,
      [SendPromptEffect({requestId, session, text, additionalBlocks, onComplete, _meta})],
    )
  | (Ok(Some({phase: Ready({session: SessionActive({session})})})), SessionCommand(command)) => (
      state,
      [SessionCommandEffect({session, command})],
    )
  | (_, SessionCommand(_)) => (state, [LogError("Cannot send session command: no active session")])
  | (_, SendPrompt({onComplete})) => (
      state,
      [NotifyRequestRejected(() => onComplete(Error("Cannot send prompt: no active session")))],
    )

  | (
      Ok(Some({phase: Ready({session: SessionActive({session: {sessionId}, requestId})})})),
      LoadTask(request),
    ) if sessionId == request.taskId => (
      state,
      [
        SessionCallbackEffect({
          requestId,
          callback: () => request.onComplete(Ok()),
          onConnectionLost: None,
        }),
      ],
    )
  | (Ok(Some({phase: Ready(ready)} as runtime)), LoadTask(request)) =>
    let operation = switch request.needsHistory {
    | true => #load(request.taskId)
    | false => #join(request.taskId)
    }
    startSession(state, runtime, ready, ~operation, ~onComplete=result =>
      request.onComplete(result->Result.map(_ => ()))
    )
  | (_, LoadTask({onComplete})) => (
      state,
      [NotifyRequestRejected(() => onComplete(Error("Cannot load task: not connected")))],
    )

  | (
      Ok(Some({phase: Ready({connection}), lifetimeAbortController})),
      DeleteSession({taskId, onComplete}),
    ) => (
      state,
      [
        DeleteSessionEffect({
          signal: lifetimeAbortController.signal,
          connection,
          taskId,
          onComplete,
        }),
      ],
    )
  | (_, DeleteSession({onComplete, _})) => (
      state,
      [
        NotifyRequestRejected(() => onComplete(Error("Not connected"))),
        LogError("Cannot delete session: not connected"),
      ],
    )

  | (Ok(Some({phase: Ready(ready) | Reconnecting(ready)} as runtime)), ClearSession) =>
    let effects = switch ready.session {
    | SessionCreating(_) => [NotifyRequestRejected(() => cancelCreation(ready.session))]
    | session =>
      switch ownedSession(session) {
      | Some(session) => [CleanupSessionEffect({session: session})]
      | None => []
      }
    }
    let ready = {...ready, session: NoSession}
    let phase = switch runtime.phase {
    | Reconnecting(_) => Reconnecting(ready)
    | _ => Ready(ready)
    }
    ({...state, connection: Ok(Some({...runtime, phase}))}, effects)
  | (_, ClearSession) => (state, [])
  | (_, CreateSession({onComplete})) => (
      state,
      [NotifyRequestRejected(() => onComplete(Error("Cannot create session: not ready")))],
    )
  | (_, Initialize) => (state, [LogInfo("Initialize ignored: dispose before restarting")])
  }
}

let next = reduce
