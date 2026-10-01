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
  | SessionCreating({sessionId: string, requestId: sessionRequestId})
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

type createSessionRequest = {
  sessionId: string,
  onComplete: result<string, string> => unit,
}

type connectionResult = {
  signal: WebAPI.EventTypes.abortSignal,
  result: result<readyState, connectError>,
}

type sessionResult = {
  requestId: sessionRequestId,
  result: result<(ACP.session, configOptions), ACP.requestError>,
  onComplete: result<unit, string> => unit,
}

type connectionCallback = {signal: WebAPI.EventTypes.abortSignal, callback: unit => unit}
type sessionCallback = {requestId: sessionRequestId, callback: unit => unit}

type action =
  | Initialize
  | Dispose
  | RequireAuthentication
  | RetryAuthentication
  | BeginLogout
  | ConnectionResultReceived(connectionResult)
  | SessionResultReceived(sessionResult)
  | SessionFailed({requestId: sessionRequestId, sessionId: string, error: string})
  | ConnectionCallbackReceived(connectionCallback)
  | SessionCallbackReceived(sessionCallback)
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
  | ConnectRuntime({config: config, signal: WebAPI.EventTypes.abortSignal})
  | ScheduleAuthRetry({signal: WebAPI.EventTypes.abortSignal})
  | CleanupEffect(runtime)
  | CleanupConnectionEffect(ACP.connection)
  | LogoutEffect({apiBaseUrl: string, signal: WebAPI.EventTypes.abortSignal})
  | CreateSessionEffect({
      requestId: sessionRequestId,
      connection: ACP.connection,
      mcpServer: MCPServer.t,
      request: createSessionRequest,
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
  | LoadTaskEffect({
      requestId: sessionRequestId,
      connection: ACP.connection,
      mcpServer: MCPServer.t,
      request: loadTaskRequest,
    })
  | ConnectionCallbackEffect(connectionCallback)
  | SessionCallbackEffect(sessionCallback)
  | SessionCompletionEffect({
      sessionId: string,
      ready: readyState,
      result: result<configOptions, ACP.requestError>,
      onComplete: result<unit, string> => unit,
    })
  | DeleteSessionEffect({
      signal: WebAPI.EventTypes.abortSignal,
      connection: ACP.connection,
      taskId: string,
      onComplete: result<unit, string> => unit,
    })
  | NotifyDeleteSessionRejected({onComplete: result<unit, string> => unit, reason: string})
  | CleanupSessionEffect({session: ACP.session})

let initialState = (config: config): state => {config, connection: Ok(None)}

let ownedSession = session =>
  switch session {
  | SessionActive({session}) | SessionFailed({session}) => Some(session)
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
    | Ok(Some({phase: Connecting})) => Connecting
    | Ok(Some({phase: WaitingForAuthentication(_) | Authenticating(_)})) => Disconnected
    }

  let getAuthRedirectUrl = (state: state): option<string> =>
    switch state.connection {
    | Ok(Some({phase: WaitingForAuthentication({loginUrl}) | Authenticating({loginUrl})})) =>
      Some(loginUrl)
    | Ok(_) | Error(_) => None
    }
}

let cleanupRuntime = (runtime: runtime): unit => {
  WebAPI.AbortController.abort(runtime.lifetimeAbortController)
  switch runtime.phase {
  | Ready({connection, session}) => ACP.disconnect(connection, ~session=?ownedSession(session))
  | Connecting | WaitingForAuthentication(_) | Authenticating(_) | LoggingOut => ()
  }
}

let cleanup = (state: state): unit => {
  Client__TextDeltaBuffer.reset()
  switch state.connection {
  | Ok(Some(runtime)) => cleanupRuntime(runtime)
  | Ok(None) | Error(_) => ()
  }
}

let isCurrentConnection = (state: state, signal: WebAPI.EventTypes.abortSignal): bool =>
  switch state.connection {
  | Ok(Some({phase: Ready(_), lifetimeAbortController})) =>
    signal === lifetimeAbortController.signal && !signal.aborted
  | Ok(_) | Error(_) => false
  }

let isCurrentSessionRequest = (state: state, requestId: sessionRequestId): bool =>
  switch state.connection {
  | Ok(Some({
      phase: Ready({
        session: SessionCreating({requestId: expected}) | SessionActive({requestId: expected}),
      }),
      lifetimeAbortController,
    })) =>
    requestId === expected && !lifetimeAbortController.signal.aborted
  | Ok(_) | Error(_) => false
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
        {...state, connection: Ok(Some({...runtime, phase: Ready(ready)}))},
        [FetchSessionsEffect({connection: ready.connection, signal})],
      )
    | Error(AuthenticationRequired(payload)) =>
      let effects = switch runtime.phase {
      | Authenticating(_) => [ScheduleAuthRetry({signal: runtime.lifetimeAbortController.signal})]
      | Connecting | WaitingForAuthentication(_) | Ready(_) | LoggingOut => []
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
      | Connecting | WaitingForAuthentication(_) | Ready(_) | LoggingOut => (
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

  | (Ok(Some({phase: WaitingForAuthentication(payload)} as runtime)), RetryAuthentication) => (
      {...state, connection: Ok(Some({...runtime, phase: Authenticating(payload)}))},
      [ConnectRuntime({config: state.config, signal: runtime.lifetimeAbortController.signal})],
    )

  | (Ok(Some({phase: Ready(_)} as runtime)), RequireAuthentication) =>
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

  | (Ok(Some({phase: Ready(_)} as runtime)), BeginLogout) =>
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
      SessionResultReceived({requestId, result: Ok((session, configOptions)), onComplete}),
    ) if isCurrentSessionRequest(state, requestId) && expectedSessionId == session.sessionId =>
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
      Ok(Some({phase: Ready({session: SessionCreating({sessionId})} as ready)} as runtime)),
      SessionResultReceived({requestId, result: Error(error), onComplete}),
    ) if isCurrentSessionRequest(state, requestId) =>
    let session = switch ACP.requestErrorIsBillingInactive(error) {
    | true => NoSession
    | false => SessionCreationFailed(ACP.requestErrorMessage(error))
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
      Ok(Some(
        {
          phase: Ready(
            {session: SessionActive({session: {sessionId: expectedSessionId} as session})} as ready,
          ),
        } as runtime,
      )),
      SessionFailed({requestId, sessionId, error}),
    ) if isCurrentSessionRequest(state, requestId) && expectedSessionId == sessionId =>
    let ready = {...ready, session: SessionFailed({session, error})}
    (
      {...state, connection: Ok(Some({...runtime, phase: Ready(ready)}))},
      [
        SessionCompletionEffect({
          sessionId,
          ready,
          result: Error(ACP.requestErrorFromMessage(error)),
          onComplete: _ => (),
        }),
        LogError(`Session failed: ${error}`),
      ],
    )
  | (_, SessionFailed(_)) => (state, [LogInfo("Stale session failure ignored")])

  | (
      Ok(Some({phase: Ready({session: NoSession | SessionCreationFailed(_)} as ready)} as runtime)),
      CreateSession(request),
    ) =>
    let requestId = ref()
    (
      {
        ...state,
        connection: Ok(
          Some({
            ...runtime,
            phase: Ready({
              ...ready,
              session: SessionCreating({sessionId: request.sessionId, requestId}),
            }),
          }),
        ),
      },
      [
        CreateSessionEffect({
          requestId,
          connection: ready.connection,
          mcpServer: ready.mcpServer,
          request,
        }),
      ],
    )

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
  | (_, SendPrompt(_)) => (state, [LogError("Cannot send prompt: no active session")])

  | (
      Ok(Some({phase: Ready({session: SessionActive({session: {sessionId}, requestId})})})),
      LoadTask(request),
    ) if sessionId == request.taskId => (
      state,
      [SessionCallbackEffect({requestId, callback: () => request.onComplete(Ok())})],
    )
  | (Ok(Some({phase: Ready(ready)} as runtime)), LoadTask(request)) =>
    let requestId = ref()
    let cleanup = switch ownedSession(ready.session) {
    | Some(session) => [CleanupSessionEffect({session: session})]
    | None => []
    }
    (
      {
        ...state,
        connection: Ok(
          Some({
            ...runtime,
            phase: Ready({
              ...ready,
              session: SessionCreating({sessionId: request.taskId, requestId}),
            }),
          }),
        ),
      },
      Array.concat(
        cleanup,
        [
          LoadTaskEffect({
            requestId,
            connection: ready.connection,
            mcpServer: ready.mcpServer,
            request,
          }),
        ],
      ),
    )
  | (_, LoadTask(_)) => (state, [LogError("Cannot load task: not connected")])

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
        NotifyDeleteSessionRejected({onComplete, reason: "Not connected"}),
        LogError("Cannot delete session: not connected"),
      ],
    )

  | (Ok(Some({phase: Ready(ready)} as runtime)), ClearSession) =>
    let effects = switch ownedSession(ready.session) {
    | Some(session) => [CleanupSessionEffect({session: session})]
    | None => []
    }
    (
      {...state, connection: Ok(Some({...runtime, phase: Ready({...ready, session: NoSession})}))},
      effects,
    )
  | (_, ClearSession) => (state, [])
  | (_, CreateSession(_)) => (state, [LogError("Cannot create session: not ready")])
  | (_, Initialize) => (state, [LogInfo("Initialize ignored: dispose before restarting")])
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

let connectRuntime = async (~config: config, ~signal: WebAPI.EventTypes.abortSignal): result<
  readyState,
  connectError,
> => {
  let attempt = WebAPI.AbortController.make()
  let rec onAbort = _ => {
    WebAPI.AbortController.abort(attempt)
    WebAPI.AbortSignal.removeEventListener(signal, Custom("abort"), onAbort)
  }
  WebAPI.AbortSignal.addEventListener(signal, Custom("abort"), onAbort)
  switch signal.aborted {
  | true => onAbort()
  | false => ()
  }
  let failure = ref(None)
  let connection = ref(None)
  let relay = ref(None)
  let fail = error => {
    switch failure.contents {
    | None => failure := Some(error)
    | Some(_) => ()
    }
    WebAPI.AbortController.abort(attempt)
  }
  let release = () => {
    connection.contents->Option.forEach(conn => ACP.disconnect(conn))
    connection := None
    WebAPI.AbortSignal.removeEventListener(signal, Custom("abort"), onAbort)
  }
  let connectACP = async () => {
    switch await ACP.connect(config.acp, ~signal=attempt.signal, ~onConnectionCreated=conn => {
      connection := Some(conn)
    }) {
    | Ok(conn) =>
      switch attempt.signal.aborted {
      | true =>
        ACP.disconnect(conn)
        connection := None
      | false =>
        switch ACP.getAgentAttributionConfiguration(conn) {
        | Some(_) => ()
        | None => fail(ConnectionFailed(ACPError("Frontman requires agent attribution v1")))
        }
      }
    | Error(ACP.AuthRequired({loginUrl})) =>
      connection := None
      let framework = config.acp.clientInfo._meta->Option.flatMap(frameworkFromClientInfoMeta)
      fail(AuthenticationRequired({loginUrl: enrichLoginUrl(~loginUrl, ~framework)}))
    | Error(ACP.ConnectionFailed(message)) =>
      connection := None
      fail(ConnectionFailed(ACPError(message)))
    }
  }
  let connectRelay = async () => {
    let result = await Relay.connect(config.relay, ~signal=attempt.signal)
    switch attempt.signal.aborted {
    | true => ()
    | false =>
      switch result {
      | Ok(connected) =>
        relay := Some(connected)
        Client__Analytics.track(RelayConnectionCompleted(Success))
      | Error(message) =>
        Client__Analytics.track(RelayConnectionCompleted(Failure(relayFailureReason(message))))
        fail(ConnectionFailed(RelayError(message)))
      }
    }
  }
  try {
    let _ = await Promise.all([connectACP(), connectRelay()])
    switch (signal.aborted, failure.contents) {
    | (true, _) =>
      release()
      Error(ConnectionFailed(ACPError("Connection aborted")))
    | (false, Some(error)) =>
      release()
      Error(error)
    | (false, None) =>
      let relay = relay.contents->Option.getOrThrow
      Ok({
        connection: connection.contents->Option.getOrThrow,
        relay,
        mcpServer: MCPServer.make(config.mcp, ~relay),
        session: NoSession,
      })
    }
  } catch {
  | exn =>
    WebAPI.AbortController.abort(attempt)
    release()
    throw(exn)
  }
}

let handleEffect = (effect: effect, state: state, dispatch: action => unit) => {
  let activateSession = async (~requestId, ~sessionId, ~onComplete, activate) => {
    switch isCurrentSessionRequest(state, requestId) {
    | false => ()
    | true =>
      let pending = ref(true)
      let creationError = ref(None)
      let result = await activate(
        (sessionId, update) =>
          dispatch(
            SessionCallbackReceived({
              requestId,
              callback: () =>
                Client__State__Store.dispatch(
                  AcpSessionUpdateReceived({taskId: sessionId, update}),
                ),
            }),
          ),
        (sessionId, title) =>
          dispatch(
            SessionCallbackReceived({
              requestId,
              callback: () => Client__State.Actions.updateTaskTitle(~taskId=sessionId, ~title),
            }),
          ),
        error =>
          switch pending.contents {
          | true => creationError := Some(error)
          | false => dispatch(SessionFailed({requestId, sessionId, error}))
          },
      )
      let result = result->Result.flatMap(((session, configOptions)) =>
        switch creationError.contents {
        | Some(error) =>
          ACP.cleanupSessionChannel(session)
          Error(ACP.requestErrorFromMessage(error))
        | None => Ok((session, configOptions))
        }
      )
      pending := false
      dispatch(SessionResultReceived({requestId, result, onComplete}))
    }
  }

  switch effect {
  | LogError(msg) => Log.error(msg)
  | LogInfo(msg) => Log.info(msg)
  | NotifyDeleteSessionRejected({onComplete, reason}) => onComplete(Error(reason))
  | ConnectionCallbackEffect({signal, callback}) =>
    switch isCurrentConnection(state, signal) {
    | true => callback()
    | false => ()
    }
  | SessionCallbackEffect({requestId, callback}) =>
    switch isCurrentSessionRequest(state, requestId) {
    | true => callback()
    | false => ()
    }
  | SessionCompletionEffect({sessionId, ready, result, onComplete}) =>
    switch state.connection {
    | Ok(Some({phase: Ready(current), lifetimeAbortController}))
      if current === ready && !lifetimeAbortController.signal.aborted =>
      switch result {
      | Ok(configOptions) =>
        configOptions->Option.forEach(opts =>
          Client__State__Store.dispatch(ConfigOptionsReceived({configOptions: opts}))
        )
        onComplete(Ok())
      | Error(error) =>
        Client__TextDeltaBuffer.discardTask(sessionId)
        onComplete(Error(billingRequestErrorMessage(error)))
      }
    | Ok(_) | Error(_) => ()
    }
  | CleanupEffect(runtime) => cleanupRuntime(runtime)
  | CleanupConnectionEffect(connection) => ACP.disconnect(connection)
  | ConnectRuntime({config, signal}) =>
    let connect = async () => {
      let result = await connectRuntime(~config, ~signal)
      switch (signal.aborted, result) {
      | (true, Ok(ready)) => ACP.disconnect(ready.connection)
      | (true, Error(_)) => ()
      | (false, Ok(ready)) =>
        let {agents, defaultAgentId} =
          ACP.getAgentAttributionConfiguration(ready.connection)->Option.getOrThrow
        Client__State.Actions.agentAttributionConfigured(~agentCatalog=agents, ~defaultAgentId)
        dispatch(ConnectionResultReceived({signal, result}))
      | (false, Error(_)) => dispatch(ConnectionResultReceived({signal, result}))
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
  | LogoutEffect({apiBaseUrl, signal}) => revokeEmbeddedClientToken(~apiBaseUrl, ~signal)->ignore
  | CreateSessionEffect({requestId, connection, mcpServer, request: {sessionId, onComplete}}) =>
    activateSession(
      ~requestId,
      ~sessionId,
      ~onComplete=result => onComplete(result->Result.map(_ => sessionId)),
      async (onUpdate, onTitleUpdated, onParseError) => {
        let result = await ACP.createSession(
          connection,
          ~sessionId,
          ~onUpdate,
          ~onTitleUpdated,
          ~onParseError,
          ~mcpServerInterface=MCPServer.toInterface(mcpServer),
        )
        result->Result.map(((session, result)) => (session, result.configOptions))
      },
    )->ignore
  | SendPromptEffect({requestId, session, text, additionalBlocks, onComplete, _meta}) =>
    let send = async () => {
      try {
        let result = await ACP.sendPrompt(session, text, ~additionalBlocks, ~_meta)
        dispatch(
          SessionCallbackReceived({
            requestId,
            callback: () => onComplete(result->Result.mapError(billingRequestErrorMessage)),
          }),
        )
      } catch {
      | exn =>
        dispatch(
          SessionCallbackReceived({
            requestId,
            callback: () => onComplete(Error("sendPrompt exception")),
          }),
        )
        throw(exn)
      }
    }
    switch isCurrentSessionRequest(state, requestId) {
    | true => send()->ignore
    | false => ()
    }
  | SessionCommandEffect({session, command}) => ACP.sendSessionCommand(session, command)
  | FetchSessionsEffect({connection, signal}) =>
    let fetch = async () => {
      Client__State.Actions.sessionsLoadStarted()
      let result = await ACP.listSessions(connection)
      dispatch(
        ConnectionCallbackReceived({
          signal,
          callback: () =>
            switch result {
            | Ok(sessions) => Client__State.Actions.sessionsLoadSuccess(~sessions)
            | Error(err) =>
              Log.error(~ctx={"error": err}, "Failed to fetch sessions")
              Client__State.Actions.sessionsLoadError(~error=err)
            },
        }),
      )
    }
    switch isCurrentConnection(state, signal) {
    | true => fetch()->ignore
    | false => ()
    }
  | LoadTaskEffect({
      requestId,
      connection,
      mcpServer,
      request: {taskId, needsHistory, onComplete},
    }) =>
    activateSession(~requestId, ~sessionId=taskId, ~onComplete, async (
      onUpdate,
      onTitleUpdated,
      onParseError,
    ) => {
      let mcpServerInterface = MCPServer.toInterface(mcpServer)
      let result = switch needsHistory {
      | true =>
        let loadResult = await ACP.loadSession(
          connection,
          taskId,
          ~onLoadResult=_ => (),
          ~onUpdate,
          ~onTitleUpdated,
          ~onParseError,
          ~mcpServerInterface,
        )
        loadResult->Result.map(((session, loadResult)) => (session, loadResult.configOptions))
      | false =>
        let joinResult = await ACP.joinSession(
          connection,
          taskId,
          ~onUpdate=ACP.validatedUpdateHandler(connection, taskId, onUpdate),
          ~onTitleUpdated,
          ~onParseError,
          ~mcpServerInterface,
        )
        joinResult->Result.map(session => (session, None))
      }
      result->Result.mapError(ACP.requestErrorFromMessage)
    })->ignore
  | DeleteSessionEffect({signal, connection, taskId, onComplete}) =>
    let delete = async () => {
      let result = await ACP.deleteSession(connection, taskId)
      dispatch(
        ConnectionCallbackReceived({
          signal,
          callback: () => {
            switch result {
            | Ok() => Log.info(~ctx={"taskId": taskId}, "Session deleted")
            | Error(err) =>
              Log.error(~ctx={"taskId": taskId, "error": err}, "Failed to delete session")
            }
            onComplete(result)
          },
        }),
      )
    }
    switch isCurrentConnection(state, signal) {
    | true => delete()->ignore
    | false => ()
    }
  | CleanupSessionEffect({session}) => cleanupSession(session)
  }
}
