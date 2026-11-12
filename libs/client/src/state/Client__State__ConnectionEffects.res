module Log = FrontmanLogs.Logs.Make({
  let component = #StateReducer
})

open Client__State__Protocol

type appAction = action
open! Client__ConnectionReducer
let relayFailureReason = message =>
  switch message {
  | message if message->String.startsWith("HTTP ") => Client__Analytics.HttpError
  | message if message->String.startsWith("Invalid tools response: ") =>
    Client__Analytics.InvalidResponse
  | _ => Client__Analytics.NetworkError
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

let connectRuntime = async (
  ~config: config,
  ~signal: WebAPI.EventTypes.abortSignal,
  ~onConnectionLost,
): result<readyState, connectError> => {
  let attempt = WebAPI.AbortController.make()
  let attemptSignal = WebAPI.AbortSignal.any([signal, attempt.signal])
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
  }
  let acpError = error =>
    switch error {
    | ACP.AuthRequired({loginUrl}) =>
      let framework = config.acp.clientInfo._meta->Option.flatMap(frameworkFromClientInfoMeta)
      AuthenticationRequired({loginUrl: enrichLoginUrl(~loginUrl, ~framework)})
    | ACP.ConnectionFailed(message) => ConnectionFailed(ACPError(message))
    }
  let validateConnection = result =>
    result
    ->Result.mapError(acpError)
    ->Result.flatMap(conn =>
      switch (ACP.isInitialized(conn), ACP.getAgentAttributionConfiguration(conn)) {
      | (true, Some(_)) => Ok(conn)
      | (false, _) => Error(ConnectionFailed(ACPError("Connection lost")))
      | (true, None) =>
        Error(ConnectionFailed(ACPError("Frontman requires agent attribution v1")))
      }
    )
  let connectACP = async () => {
    let result = await ACP.connect(
      config.acp,
      ~signal=attemptSignal,
      ~onConnectionCreated=conn => connection := Some(conn),
      ~onConnectionLost=message => {
        let error = ConnectionFailed(ACPError(message))
        fail(error)
        onConnectionLost(error)
      },
    )
    switch validateConnection(result) {
    | Ok(conn) =>
      switch attemptSignal.aborted {
      | true =>
        ACP.disconnect(conn)
        connection := None
      | false => ()
      }
    | Error(error) => fail(error)
    }
  }
  let connectRelay = async () => {
    let result = await Relay.connect(config.relay, ~signal=attemptSignal)
    switch attemptSignal.aborted {
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

let billingRequestErrorMessage = (error, dispatchApp: appAction => unit) => {
  switch ACP.requestErrorIsBillingInactive(error) {
  | true => dispatchApp(SetSettingsModalTab({tab: Some(Billing)}))
  | false => ()
  }
  ACP.requestErrorMessage(error)
}

let rec handleEffect = (
  effect: effect,
  state: state,
  dispatch: action => unit,
  ~dispatchApp: appAction => unit,
) => {
  let activateSession = async (~requestId, ~sessionId, activate) => {
    switch isCurrentSessionRequest(state, requestId) {
    | false => ()
    | true =>
      Client__TextDeltaBuffer.reset()
      let pending = ref(true)
      let creationError = ref(None)
      let result = await activate(
        (sessionId, update) => {
          let errorDisplayId = switch update {
          | FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP.Error({_meta, retryAt: None}) =>
            switch Client__ACP__MessageCodec.agentErrorId(_meta) {
            | Some(id) => Some(id)
            | None => Some(WebAPI.Window.current->WebAPI.Window.crypto->WebAPI.Crypto.randomUUID)
            }
          | _ => None
          }
          dispatchApp(
            SessionEvent({
              requestId,
              action: AcpSessionUpdateReceived({taskId: sessionId, update, errorDisplayId}),
            }),
          )
        },
        (sessionId, title) =>
          dispatchApp(
            SessionEvent({requestId, action: UpdateTaskTitle({taskId: sessionId, title})}),
          ),
        error => {
          Client__TextDeltaBuffer.flush()
          switch pending.contents {
          | true => creationError := Some(error)
          | false =>
            dispatch(
              SessionResultReceived({
                requestId,
                sessionId,
                result: Error(ACP.requestErrorFromMessage(error)),
              }),
            )
          }
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
      dispatch(SessionResultReceived({requestId, sessionId, result}))
    }
  }

  switch effect {
  | LogError(msg) => Log.error(msg)
  | LogInfo(msg) => Log.info(msg)
  | NotifyRequestRejected(notify) => notify()
  | SessionCompletionEffect({sessionId, ready, result, onComplete}) =>
    let complete = result =>
      switch (onComplete, result) {
      | (Some(onComplete), _) => onComplete(result)
      | (None, Ok(_)) =>
        Client__TextDeltaBuffer.flush()
        switch ready.session {
        | SessionActive({requestId}) =>
          dispatchApp(TaskLoadFinished({taskId: sessionId, result: Ok(requestId)}))
        | _ => failwith("Loaded session must be active")
        }
      | (None, Error(error)) =>
        dispatchApp(TaskLoadFinished({taskId: sessionId, result: Error(error)}))
      }
    switch state.connection {
    | Ok(Some({phase: Ready(current), lifetimeAbortController}))
      if current === ready &&
      !lifetimeAbortController.signal.aborted &&
      ACP.isInitialized(current.connection) =>
      switch result {
      | Ok(_) => complete(Ok(sessionId))
      | Error(error) =>
        Client__TextDeltaBuffer.flush()
        complete(Error(billingRequestErrorMessage(error, dispatchApp)))
      }
    | Ok(Some({phase: Ready(current)})) if current.session === ready.session =>
      complete(Error("Connection changed before submission completed; send again when ready"))
    | Ok(_) | Error(_) => complete(Error("Conversation changed. Your message was not sent."))
    }
  | TaskLoadFailed({taskId, error}) =>
    dispatchApp(TaskLoadFinished({taskId, result: Error(error)}))
  | CleanupEffect(runtime) =>
    WebAPI.AbortController.abort(runtime.lifetimeAbortController)
    switch runtime.phase {
    | Ready({connection, session}) =>
      ACP.disconnect(connection)
      releaseSession(session)->Array.forEach(effect =>
        handleEffect(effect, state, dispatch, ~dispatchApp)
      )
    | _ => ()
    }
  | CleanupConnectionEffect(connection) => ACP.disconnect(connection)
  | ConnectRuntime({config, signal}) =>
    let connect = async () => {
      let result = await connectRuntime(~config, ~signal, ~onConnectionLost=error => {
        Client__TextDeltaBuffer.flush()
        dispatch(ConnectionResultReceived({signal, result: Error(error)}))
      })
      switch (signal.aborted, result) {
      | (true, Ok(ready)) => ACP.disconnect(ready.connection)
      | (true, Error(_)) => ()
      | (false, _) => dispatch(ConnectionResultReceived({signal, result}))
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
  | SessionCommandEffect({session, command}) => ACP.sendSessionCommand(session, command)
  | FetchSessionsEffect({connection, signal}) =>
    let fetch = async () => {
      let {agents, defaultAgentId} =
        ACP.getAgentAttributionConfiguration(connection)->Option.getOrThrow
      dispatchApp(AgentAttributionConfigured({agentCatalog: agents, defaultAgentId}))
      dispatchApp(SessionsLoadStarted)
      let result = await ACP.listSessions(connection)
      dispatchApp(
        ConnectionEvent({
          signal,
          action: switch result {
          | Ok(sessions) => SessionsLoadSuccess({sessions: sessions})
          | Error(error) => SessionsLoadError({error: error})
          },
        }),
      )
    }
    switch isCurrentConnection(state, signal) {
    | true => fetch()->ignore
    | false => ()
    }
  | ActivateSessionEffect({requestId, connection, mcpServer, operation}) =>
    let sessionId = switch operation {
    | #load(sessionId) | #create(sessionId) => sessionId
    }
    activateSession(~requestId, ~sessionId, async (onUpdate, onTitleUpdated, onParseError) => {
      let mcpServerInterface = MCPServer.toInterface(mcpServer)
      switch operation {
      | #create(_) =>
        let result = await ACP.createSession(
          connection,
          ~sessionId,
          ~onUpdate,
          ~onTitleUpdated,
          ~onParseError,
          ~mcpServerInterface,
        )
        result->Result.map(((session, result)) => (session, result.configOptions))
      | #load(_) =>
        let result = await ACP.loadSession(
          connection,
          sessionId,
          ~onLoadResult=_ => (),
          ~onUpdate,
          ~onTitleUpdated,
          ~onParseError,
          ~mcpServerInterface,
        )
        result
        ->Result.map(((session, result)) => (session, result.configOptions))
        ->Result.mapError(ACP.requestErrorFromMessage)
      }
    })->ignore
  | DeleteSessionEffect({signal, connection, taskId}) =>
    let delete = async () => {
      switch await ACP.deleteSession(connection, taskId) {
      | Ok() => Log.info(~ctx={"taskId": taskId}, "Session deleted")
      | Error(error) =>
        Log.error(~ctx={"taskId": taskId, "error": error}, "Failed to delete session")
      }
    }
    switch isCurrentConnection(state, signal) {
    | true => delete()->ignore
    | false => ()
    }
  | CleanupSessionEffect({session}) =>
    ACP.cleanupSessionChannel(session)
    Log.debug(~ctx={"sessionId": session.sessionId}, "Cleaned up session channel")
  }
}
