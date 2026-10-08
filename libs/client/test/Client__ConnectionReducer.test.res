open Vitest

module Reducer = Client__ConnectionReducer
module App = Client__State__StateReducer

let handleEffect = (effect, state, dispatch) =>
  App.ConnectionEffects.handleEffect(
    effect,
    state,
    dispatch,
    ~dispatchApp=Client__State__Store.dispatch,
  )

let effectKinds = effects =>
  effects->Array.map(effect =>
    switch effect {
    | Reducer.LogError(_) => #logError
    | Reducer.LogInfo(_) => #logInfo
    | Reducer.ConnectRuntime(_) => #connectRuntime
    | Reducer.ScheduleAuthRetry(_) => #scheduleAuthRetry
    | Reducer.CleanupEffect(_) => #cleanup
    | Reducer.CleanupConnectionEffect(_) => #cleanupConnection
    | Reducer.LogoutEffect(_) => #logout
    | Reducer.ActivateSessionEffect({operation: #create(_)}) => #createSession
    | Reducer.ActivateSessionEffect({operation: #load(_) | #join(_)}) => #loadTask
    | Reducer.SessionCommandEffect(_) => #sessionCommand
    | Reducer.FetchSessionsEffect(_) => #fetchSessions
    | Reducer.DeleteSessionEffect(_) => #deleteSession
    | Reducer.NotifyRequestRejected(_) => #requestRejected
    | Reducer.CleanupSessionEffect(_) => #cleanupSession
    | Reducer.TaskLoadFailed(_) => #taskLoadFailed
    | Reducer.SessionCompletionEffect(_) => #sessionCompletion
    }
  )

type reconnectWire = {lose: bool => unit, requests: array<JSON.t>}
@send
external triggerChannelError: (Reducer.ACP.Channel.t, @as("phx_error") _, JSON.t) => unit =
  "trigger"
@module("../../frontman-client/test/acpReconnectTransport.mjs")
external reconnectWire: unit => reconnectWire = "makeTransport"
@module("vitest") @scope("vi") external stubGlobal: (string, 'a) => unit = "stubGlobal"
@module("vitest") @scope("vi") external unstubAllGlobals: unit => unit = "unstubAllGlobals"
@module("vitest") external onTestFinished: (unit => unit) => unit = "onTestFinished"

let mock = value => Obj.magic(value)
let mockRelay: Reducer.Relay.connected = mock({"id": "relay"})
let mockConnection = Client__ConnectionTestHelpers.connection
let loginUrl = "https://app.frontman.sh/users/log-in"
let config = Client__ConnectionTestHelpers.config(~apiBaseUrl="https://app.frontman.sh")
let initialState = Reducer.initialState(config)
let initialize = state => Reducer.reduce(state, Initialize)
let runtime = (state: Reducer.state) => state.connection->Result.getOrThrow->Option.getOrThrow
let connectionLost = state => Reducer.ConnectionResultReceived({
  signal: runtime(state).lifetimeAbortController.signal,
  result: Error(ConnectionFailed(ACPError(Reducer.ACP.Protocol.connectionLost))),
})
let initialized = () => {
  let (state, _) = initialize(initialState)
  state
}
let withPhase = phase => {
  let state = initialized()
  {...state, connection: Ok(Some({...runtime(state), phase}))}
}
let ready = (session): Reducer.readyState => {
  connection: mockConnection,
  relay: mockRelay,
  mcpServer: mock({"tools": []}),
  session,
}
let withSession = session => withPhase(Reducer.Ready(ready(session)))
let sessionState = state =>
  switch runtime(state).phase {
  | Reducer.Ready({session}) => session
  | _ => failwith("Expected ready connection")
  }
let creating = sessionId => Reducer.SessionCreating({
  sessionId: Some(sessionId),
  requestId: ref(),
  onComplete: Some(_ => ()),
})
let active = session => Reducer.SessionActive({session, requestId: ref()})
let requestId = state =>
  switch sessionState(state) {
  | SessionCreating({requestId}) | SessionActive({requestId}) => requestId
  | _ => failwith("Expected session request")
  }
let pendingSessionId = state =>
  switch sessionState(state) {
  | SessionCreating({sessionId}) => sessionId->Option.getOrThrow
  | _ => failwith("Expected pending session")
  }
let completeSession = (state, result) =>
  Reducer.reduce(
    state,
    SessionResultReceived({
      requestId: requestId(state),
      sessionId: switch result {
      | Ok((session, _)) => session.Reducer.ACP.sessionId
      | Error(_) => pendingSessionId(state)
      },
      result,
    }),
  )

let complete = (state, result) =>
  Reducer.reduce(
    state,
    ConnectionResultReceived({
      signal: runtime(state).lifetimeAbortController.signal,
      result,
    }),
  )
let loadTask = taskId => Reducer.LoadTask({taskId, needsHistory: true})

describe("Connection Reducer", () => {
  describe("login URL", () => {
    test(
      "sets completion and framework parameters without losing URL structure",
      t => {
        let url = Reducer.enrichLoginUrl(
          ~loginUrl="https://app.frontman.sh/users/log-in?source=acp&framework=old#password",
          ~framework=Some("wordpress"),
        )
        t
        ->expect(url)
        ->Expect.toBe(
          "https://app.frontman.sh/users/log-in?source=acp&framework=wordpress&return_to=%2Fusers%2Fpopup-complete#password",
        )
      },
    )
    test(
      "omits framework when client metadata has none",
      t => {
        let url = Reducer.enrichLoginUrl(
          ~loginUrl="https://app.frontman.sh/users/log-in?return_to=/old",
          ~framework=None,
        )
        t
        ->expect(url)
        ->Expect.toBe("https://app.frontman.sh/users/log-in?return_to=%2Fusers%2Fpopup-complete")
      },
    )
  })

  describe("runtime ownership", () => {
    test(
      "starts with configuration and no runtime",
      t => {
        t->expect(initialState.config)->Expect.toBe(config)
        t->expect(initialState.connection)->Expect.toEqual(Ok(None))
        t->expect(Reducer.Selectors.getRelay(initialState))->Expect.toBe(None)
        t->expect(Reducer.Selectors.getSession(initialState))->Expect.toBe(None)
        t->expect(Reducer.Selectors.getConnectionStatus(initialState))->Expect.toBe(Disconnected)
      },
    )
    test(
      "initialization starts joint connection without exposing partial resources",
      t => {
        let (state, effects) = initialize(initialState)
        t->expect(runtime(state).phase)->Expect.toBe(Reducer.Connecting)
        t->expect(state.config)->Expect.toBe(config)
        t->expect(Reducer.Selectors.getRelay(state))->Expect.toBe(None)
        t->expect(Reducer.Selectors.getConnectionStatus(state))->Expect.toBe(Connecting)
        t->expect(effectKinds(effects))->Expect.toEqual([#connectRuntime])
        let (unchanged, duplicateEffects) = initialize(state)
        t->expect(unchanged)->Expect.toBe(state)
        t->expect(effectKinds(duplicateEffects))->Expect.toEqual([#logInfo])
      },
    )
    test(
      "joint success exposes both connections and fetches sessions",
      t => {
        let (state, effects) = complete(initialized(), Ok(ready(NoSession)))
        t->expect(Reducer.Selectors.getConnectionStatus(state))->Expect.toBe(Connected)
        t->expect(Reducer.Selectors.getRelay(state))->Expect.toBe(Some(mockRelay))
        t->expect(effectKinds(effects))->Expect.toEqual([#fetchSessions])
      },
    )
    test(
      "either transport failure drops runtime but retains configuration",
      t => {
        [Reducer.ACPError("ACP failed"), Reducer.RelayError("Relay failed")]->Array.forEach(
          error => {
            let starting = initialized()
            let previous = runtime(starting)
            let (failed, effects) = complete(starting, Error(ConnectionFailed(error)))
            t->expect(failed.connection)->Expect.toEqual(Error(error))
            t->expect(failed.config)->Expect.toBe(config)
            t->expect(Reducer.Selectors.getRelay(failed))->Expect.toBe(None)
            t->expect(effectKinds(effects))->Expect.toEqual([#cleanup, #logError])
            handleEffect(effects->Array.get(0)->Option.getOrThrow, failed, _ => ())
            t->expect(previous.lifetimeAbortController.signal.aborted)->Expect.toBe(true)
          },
        )
      },
    )
    test(
      "disposal retains config and allows a fresh lifetime",
      t => {
        let starting = initialized()
        let (disposed, effects) = Reducer.reduce(starting, Dispose)
        t->expect(disposed)->Expect.toEqual(initialState)
        t->expect(effectKinds(effects))->Expect.toEqual([#cleanup])
        let (restarted, restartEffects) = initialize(disposed)
        t
        ->expect(
          runtime(restarted).lifetimeAbortController === runtime(starting).lifetimeAbortController,
        )
        ->Expect.toBe(false)
        t->expect(effectKinds(restartEffects))->Expect.toEqual([#connectRuntime])
      },
    )
    test(
      "late startup success cannot replace a new lifetime",
      t => {
        let oldState = initialized()
        let (disposed, _) = Reducer.reduce(oldState, Dispose)
        let (current, _) = initialize(disposed)
        let (unchanged, effects) = Reducer.reduce(
          current,
          ConnectionResultReceived({
            signal: runtime(oldState).lifetimeAbortController.signal,
            result: Ok(ready(NoSession)),
          }),
        )
        t->expect(unchanged)->Expect.toBe(current)
        t->expect(effectKinds(effects))->Expect.toEqual([#cleanupConnection, #logInfo])
      },
    )
    test(
      "relay errors retain analytics classification",
      t => {
        [
          ("HTTP 500: Error", Client__Analytics.HttpError),
          ("Invalid tools response: bad data", Client__Analytics.InvalidResponse),
          ("Connection refused", Client__Analytics.NetworkError),
        ]->Array.forEach(
          ((message, reason)) =>
            t
            ->expect(Client__State__StateReducer.ConnectionEffects.relayFailureReason(message))
            ->Expect.toBe(reason),
        )
      },
    )
  })

  test("connection loss rejects operations and fences stale events", t => {
    let session = mock({"sessionId": "existing"})
    let original = withSession(active(session))
    let signal = runtime(original).lifetimeAbortController.signal
    let (lost, effects) = Reducer.reduce(original, connectionLost(original))
    t->expect(effectKinds(effects))->Expect.toEqual([#cleanup, #logError])
    t
    ->expect(Reducer.Selectors.getConnectionStatus(lost))
    ->Expect.toEqual(Error(Reducer.ACP.Protocol.connectionLost))
    t->expect(Reducer.Selectors.getSession(lost))->Expect.toBe(None)
    let current = {...App.defaultState, connection: Some(original)}
    let newer = {...current, connection: Some(withSession(active(session)))}
    let action = App.SessionsLoadSuccess({sessions: []})
    [
      App.ConnectionEvent({signal, action}),
      App.SessionEvent({requestId: requestId(original), action}),
    ]->Array.forEach(
      event => {
        [newer, {...current, connection: Some(lost)}]->Array.forEach(
          state => {
            t->expect(App.next(state, event)->Pair.first)->Expect.toBe(state)
          },
        )
        let (updated, effects) = App.next(current, event)
        t->expect(updated.sessionsLoadState)->Expect.toEqual(SessionsLoaded)
        t->expect(effects)->Expect.toEqual([])
      },
    )
    let rejected = ref(0)
    let onComplete = result => {
      t->expect(result->Result.isError)->Expect.toBe(true)
      rejected := rejected.contents + 1
    }
    let (_, effects) = Reducer.reduce(lost, CreateSession({sessionId: "new-session", onComplete}))
    effects->Array.forEach(effect => handleEffect(effect, lost, _ => ()))
    t->expect(rejected.contents)->Expect.toBe(1)
    t
    ->expect(Reducer.reduce(lost, loadTask("existing"))->Pair.second->effectKinds)
    ->Expect.toEqual([#taskLoadFailed])
    let (unchanged, effects) = Reducer.reduce(
      lost,
      ConnectionResultReceived({signal, result: Ok(ready(active(session)))}),
    )
    t->expect(unchanged)->Expect.toBe(lost)
    t->expect(effectKinds(effects))->Expect.toEqual([#cleanupConnection, #logInfo])
  })

  test("connection loss rejects pending drafts and late session completion", t => {
    let completed = ref(None)
    let create = () =>
      Reducer.reduce(
        withSession(NoSession),
        CreateSession({sessionId: "new-session", onComplete: result => completed := Some(result)}),
      )
    let (creating, _) = create()
    let (lost, effects) = Reducer.reduce(creating, connectionLost(creating))
    effects->Array.forEach(effect => handleEffect(effect, lost, _ => ()))
    t->expect(completed.contents->Option.getOrThrow->Result.isError)->Expect.toBe(true)
    let (unchanged, effects) = Reducer.reduce(
      lost,
      SessionResultReceived({
        requestId: requestId(creating),
        sessionId: "late",
        result: Ok((mock({"sessionId": "late"}), None)),
      }),
    )
    t->expect(unchanged)->Expect.toBe(lost)
    t->expect(effectKinds(effects))->Expect.toEqual([#cleanupSession, #logInfo])
    completed := None
    let (creating, _) = create()
    let (activated, queued) = completeSession(
      creating,
      Ok((mock({"sessionId": "new-session"}), None)),
    )
    let (lost, _) = Reducer.reduce(activated, connectionLost(activated))
    queued->Array.forEach(effect => handleEffect(effect, lost, _ => ()))
    t->expect(completed.contents->Option.getOrThrow->Result.isError)->Expect.toBe(true)
  })

  describe("Authentication Retry", () => {
    test(
      "auth required exposes login URL without starting automatic retry",
      t => {
        let (state, effects) = complete(
          initialized(),
          Error(AuthenticationRequired({loginUrl: loginUrl})),
        )
        t->expect(Reducer.Selectors.getAuthRedirectUrl(state))->Expect.toBe(Some(loginUrl))
        t->expect(effectKinds(effects))->Expect.toEqual([])
      },
    )
    test(
      "opening sign-in starts a joint connection attempt",
      t => {
        let waiting = withPhase(WaitingForAuthentication({loginUrl: loginUrl}))
        let (state, effects) = Reducer.reduce(waiting, RetryAuthentication)
        t->expect(runtime(state).phase)->Expect.toEqual(Authenticating({loginUrl: loginUrl}))
        t->expect(Reducer.Selectors.getAuthRedirectUrl(state))->Expect.toBe(Some(loginUrl))
        t->expect(effectKinds(effects))->Expect.toEqual([#connectRuntime])
        let (unchanged, duplicateEffects) = Reducer.reduce(state, RetryAuthentication)
        t->expect(unchanged)->Expect.toBe(state)
        t->expect(effectKinds(duplicateEffects))->Expect.toEqual([])
      },
    )
    test(
      "authentication and transient ACP failures schedule another retry",
      t => {
        [
          Reducer.AuthenticationRequired({loginUrl: loginUrl}),
          Reducer.ConnectionFailed(ACPError("Network unavailable")),
        ]->Array.forEach(
          error => {
            let (state, effects) = complete(
              withPhase(Authenticating({loginUrl: loginUrl})),
              Error(error),
            )
            t
            ->expect(runtime(state).phase)
            ->Expect.toEqual(WaitingForAuthentication({loginUrl: loginUrl}))
            t->expect(effectKinds(effects))->Expect.toContain(#scheduleAuthRetry)
          },
        )
      },
    )
    test(
      "stale automatic retry is ignored after authentication succeeds",
      t => {
        let state = withSession(NoSession)
        let (unchanged, effects) = Reducer.reduce(state, RetryAuthentication)
        t->expect(unchanged)->Expect.toBe(state)
        t->expect(effects)->Expect.toEqual([])
      },
    )
    test(
      "requiring authentication releases the ready lifetime",
      t => {
        let state = withSession(NoSession)
        let (waiting, effects) = Reducer.reduce(state, RequireAuthentication)
        t->expect(Reducer.Selectors.getRelay(waiting))->Expect.toBe(None)
        t->expect(Reducer.Selectors.getAuthRedirectUrl(waiting)->Option.isSome)->Expect.toBe(true)
        t
        ->expect(
          runtime(waiting).lifetimeAbortController === runtime(state).lifetimeAbortController,
        )
        ->Expect.toBe(false)
        t->expect(effectKinds(effects))->Expect.toEqual([#cleanup])
      },
    )
  })

  test("logout releases connections but retains a lifetime for token revocation", t => {
    let state = withSession(NoSession)
    let (nextState, effects) = Reducer.reduce(state, BeginLogout)
    t->expect(runtime(nextState).phase)->Expect.toBe(LoggingOut)
    t->expect(Reducer.Selectors.getSession(nextState))->Expect.toBe(None)
    t->expect(Reducer.Selectors.getRelay(nextState))->Expect.toBe(None)
    t->expect(Reducer.Selectors.getConnectionStatus(nextState))->Expect.toBe(LoggingOut)
    t
    ->expect(runtime(nextState).lifetimeAbortController === runtime(state).lifetimeAbortController)
    ->Expect.toBe(false)
    t->expect(effectKinds(effects))->Expect.toEqual([#cleanup, #logout])
  })

  describe("Session Creation", () => {
    test(
      "accepted session result transitions to SessionActive",
      t => {
        let completed = ref(None)
        let mockSession = mock({"sessionId": "sess-1", "channel": null})
        let (state, effects) = completeSession(
          Reducer.reduce(
            withSession(NoSession),
            CreateSession({
              sessionId: "sess-1",
              onComplete: result => completed := Some(result),
            }),
          )->Pair.first,
          Ok((mockSession, None)),
        )
        effects->Array.forEach(effect => handleEffect(effect, state, _ => ()))
        t->expect(completed.contents)->Expect.toEqual(Some(Ok("sess-1")))
        t->expect(Reducer.Selectors.getSession(state))->Expect.toEqual(Some(mockSession))
        t
        ->expect(Reducer.Selectors.getConnectionStatus(state))
        ->Expect.toEqual(Reducer.Selectors.SessionActive("sess-1"))
        t->expect(effectKinds(effects))->Expect.toEqual([#sessionCompletion, #logInfo])
      },
    )
    test(
      "matching parse failures preserve failed session resources",
      t => {
        let mockSession = mock({"sessionId": "sess-1", "channel": null})
        let state = withSession(active(mockSession))
        let (failed, effects) = Reducer.reduce(
          state,
          SessionResultReceived({
            requestId: requestId(state),
            sessionId: "sess-1",
            result: Error(Reducer.ACP.requestErrorFromMessage("invalid attribution")),
          }),
        )
        t
        ->expect(sessionState(failed))
        ->Expect.toEqual(SessionFailed({session: mockSession, error: "invalid attribution"}))
        t->expect(Reducer.Selectors.getConnectionStatus(failed))->Expect.toBe(Connected)
        t
        ->expect(Reducer.Selectors.getSessionError(failed))
        ->Expect.toEqual(Some("invalid attribution"))
        t->expect(effectKinds(effects))->Expect.toEqual([#sessionCompletion, #logError])
      },
    )
    test(
      "stale parse and late activation failures do not fail current session",
      t => {
        let mockSession = mock({"sessionId": "sess-2", "channel": null})
        let state = withSession(active(mockSession))
        [
          Reducer.SessionResultReceived({
            requestId: ref(),
            sessionId: "sess-2",
            result: Error(Reducer.ACP.requestErrorFromMessage("stale update")),
          }),
          Reducer.SessionResultReceived({
            requestId: ref(),
            sessionId: "sess-2",
            result: Error(Reducer.ACP.requestErrorFromMessage("late activation")),
          }),
        ]->Array.forEach(
          action => {
            let (nextState, effects) = Reducer.reduce(state, action)
            t->expect(Reducer.Selectors.getSession(nextState))->Expect.toEqual(Some(mockSession))
            t->expect(effectKinds(effects))->Expect.toEqual([#logInfo])
          },
        )
      },
    )
    test(
      "stale load completion cannot replace the latest requested task",
      t => {
        ["sess-1", "sess-2"]->Array.forEach(
          nextId => {
            let (loadingFirst, _) = Reducer.reduce(withSession(NoSession), loadTask("sess-1"))
            let (loadingSecond, _) = Reducer.reduce(loadingFirst, loadTask(nextId))
            let staleSession = mock({"sessionId": "sess-1", "channel": null})
            let (afterStaleSuccess, effects) = Reducer.reduce(
              loadingSecond,
              SessionResultReceived({
                requestId: requestId(loadingFirst),
                sessionId: "sess-1",
                result: Ok((staleSession, None)),
              }),
            )
            t->expect(afterStaleSuccess)->Expect.toBe(loadingSecond)
            t->expect(pendingSessionId(afterStaleSuccess))->Expect.toBe(nextId)
            t->expect(effectKinds(effects))->Expect.toEqual([#cleanupSession, #logInfo])
          },
        )
      },
    )
    test(
      "switching tasks enters SessionCreating before cleanup and load",
      t => {
        let oldSession = mock({"sessionId": "sess-1", "channel": null})
        let (nextState, effects) = Reducer.reduce(
          withSession(active(oldSession)),
          loadTask("sess-2"),
        )
        t->expect(pendingSessionId(nextState))->Expect.toBe("sess-2")
        switch effects {
        | [
            Reducer.CleanupSessionEffect({session: cleaned}),
            Reducer.ActivateSessionEffect({operation: #load(sessionId)}),
          ] =>
          t->expect(cleaned)->Expect.toBe(oldSession)
          t->expect(sessionId)->Expect.toBe("sess-2")
        | _ => t->expect(effectKinds(effects))->Expect.toEqual([#cleanupSession, #loadTask])
        }
      },
    )
    test(
      "billing session failures return to NoSession",
      t => {
        let error = Reducer.ACP.requestErrorWithCode(
          ~code=FrontmanAiFrontmanProtocol.FrontmanProtocol__JsonRpc.ErrorCode.billingInactive,
          ~message="Alternate billing copy",
        )
        let (state, effects) = completeSession(
          withSession(creating("billing-session")),
          Error(error),
        )
        t->expect(sessionState(state))->Expect.toBe(Reducer.NoSession)
        t->expect(effectKinds(effects))->Expect.toEqual([#sessionCompletion, #logError])
      },
    )
    test(
      "CreateSession requires a ready connection",
      t => {
        let request = Reducer.CreateSession({sessionId: "new-session", onComplete: _ => ()})
        let (_, rejected) = Reducer.reduce(initialized(), request)
        t->expect(effectKinds(rejected))->Expect.toEqual([#requestRejected])
        let state = withSession(NoSession)
        let (nextState, effects) = Reducer.reduce(state, request)
        switch sessionState(nextState) {
        | SessionCreating({sessionId: Some("new-session")}) => ()
        | _ => failwith("Expected a new session request")
        }
        switch effects {
        | [Reducer.ActivateSessionEffect({connection, operation: #create(_)})] =>
          t->expect(connection)->Expect.toBe(mockConnection)
        | _ => t->expect(effectKinds(effects))->Expect.toEqual([#createSession])
        }
      },
    )
  })

  [
    ("socket loss", #socketLoss),
    ("control-channel error", #controlError),
    ("task-channel error", #taskError),
    ("intentional disposal", #dispose),
  ]->Array.forEach(((name, scenario)) =>
    testAsync(
      `active runtime settlement after ${name}`,
      async t => {
        Vi.useFakeTimers()->ignore
        let wire = reconnectWire()
        onTestFinished(
          () => {
            Vi.useRealTimers()->ignore
            unstubAllGlobals()
          },
        )
        stubGlobal(
          "window",
          {
            "location": {"origin": "https://wordpress.test"},
            "__frontmanRuntime": {"framework": "nextjs", "basePath": "frontman"},
            "heap": {"track": (_: string, _: JSON.t) => ()},
          },
        )
        stubGlobal(
          "fetch",
          async (_: string, _: WebAPI.FetchTypes.requestInit) =>
            WebAPI.Response.fromString(`{"tools":[],"serverInfo":{"name":"test","version":"1"},"protocolVersion":"2.0"}`),
        )
        let state = ref(initialized())
        let losses = ref(0)
        let signal = runtime(state.contents).lifetimeAbortController.signal
        let result = await App.ConnectionEffects.connectRuntime(
          ~config={...config, acp: {...config.acp, getAuthToken: () => Some("test")}},
          ~signal,
          ~onConnectionLost=error => {
            losses := losses.contents + 1
            let (lost, effects) = Reducer.reduce(
              state.contents,
              ConnectionResultReceived({signal, result: Error(error)}),
            )
            state := lost
            effects->Array.forEach(effect => handleEffect(effect, lost, _ => ()))
          },
        )
        let ready = result->Result.getOrThrow
        onTestFinished(() => Reducer.ACP.disconnect(ready.connection))
        state := complete(state.contents, result)->Pair.first
        let (session, _) =
          (
            await Reducer.ACP.createSession(
              ready.connection,
              ~sessionId="existing",
              ~onUpdate=(_, _) => (),
              ~onTitleUpdated=(_, _) => (),
            )
          )->Result.getOrThrow
        state := {
            ...state.contents,
            connection: Ok(
              Some({
                ...runtime(state.contents),
                phase: Ready({...ready, session: active(session)}),
              }),
            ),
          }
        let pending = Reducer.ACP.sendPrompt(session, "hello")
        let sent = wire.requests->Array.length
        switch scenario {
        | #socketLoss => wire.lose(true)
        | #controlError => wire.lose(false)
        | #taskError => triggerChannelError(session.channel, JSON.Encode.null)
        | #dispose =>
          let (disposed, effects) = Reducer.reduce(state.contents, Dispose)
          state := disposed
          effects->Array.forEach(effect => handleEffect(effect, disposed, _ => ()))
        }
        t
        ->expect(await pending)
        ->Expect.toEqual(
          Error(Reducer.ACP.requestErrorFromMessage(Reducer.ACP.Protocol.connectionLost)),
        )
        let (status, lossCount) = switch scenario {
        | #dispose => (Reducer.Selectors.Disconnected, 0)
        | #socketLoss | #controlError | #taskError => (
            Error(Reducer.ACP.Protocol.connectionLost),
            1,
          )
        }
        t->expect(Reducer.Selectors.getConnectionStatus(state.contents))->Expect.toEqual(status)
        t->expect(losses.contents)->Expect.toBe(lossCount)
        t->expect(Reducer.Selectors.getSession(state.contents))->Expect.toBe(None)
        t->expect(signal.aborted)->Expect.toBe(true)
        let _ = await Vi.advanceTimersByTimeAsync(1000)
        t->expect(wire.requests->Array.length)->Expect.toBe(sent)
        t->expect(Vi.getTimerCount())->Expect.toBe(0)
      },
    )
  )
})
