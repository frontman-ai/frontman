open Vitest

module Reducer = Client__ConnectionReducer
module ContentBlock = FrontmanAiFrontmanProtocol.FrontmanProtocol__ContentBlock

let effectKinds = effects =>
  effects->Array.map(effect =>
    switch effect {
    | Reducer.LogError(_) => #logError
    | Reducer.LogInfo(_) => #logInfo
    | Reducer.TrackAnalytics(_) => #trackAnalytics
    | Reducer.ConnectACP(_) => #connectACP
    | Reducer.ScheduleAuthRetry(_) => #scheduleAuthRetry
    | Reducer.CleanupEffect(_) => #cleanup
    | Reducer.CleanupConnectionEffect(_) => #cleanupConnection
    | Reducer.LogoutEffect(_) => #logout
    | Reducer.ConnectRelay(_) => #connectRelay
    | Reducer.CreateSessionEffect(_) => #createSession
    | Reducer.SendPromptEffect(_) => #sendPrompt
    | Reducer.SessionCommandEffect(_) => #sessionCommand
    | Reducer.FetchSessionsEffect(_) => #fetchSessions
    | Reducer.LoadTaskEffect(_) => #loadTask
    | Reducer.DeleteSessionEffect(_) => #deleteSession
    | Reducer.NotifyDeleteSessionRejected(_) => #deleteRejected
    | Reducer.CleanupSessionEffect(_) => #cleanupSession
    }
  )
let trackedRelayOutcomes = effects =>
  effects->Array.filterMap(e =>
    switch e {
    | Reducer.TrackAnalytics(RelayConnectionCompleted(outcome)) => Some(outcome)
    | _ => None
    }
  )

let mock = value => Obj.magic(value)
let mockRelay: Reducer.Relay.t = mock({"id": "relay"})
let mockConnection: Reducer.ACP.connection = mock({"id": "connection"})
let loginUrl = "https://app.frontman.sh/users/log-in"
let initConfig: Reducer.initConfig = {
  endpoint: "ws://test",
  loginUrl: "http://test/users/log-in",
  clientName: "test",
  clientVersion: "1.0.0",
  _meta: JSON.Encode.object(Dict.fromArray([("framework", JSON.Encode.string("test"))])),
}
let initPayload = (): Reducer.initPayload => {
  config: initConfig,
  relay: mockRelay,
  mcpServer: mock({"tools": []}),
}
let initialize = state => Reducer.reduce(state, Initialize(initPayload()))
let runtime = state =>
  switch state {
  | Reducer.Initialized(runtime) => runtime
  | Reducer.Uninitialized => failwith("Expected initialized connection")
  }
let initialized = () => {
  let (state, _) = initialize(Reducer.initialState)
  runtime(state)
}
let withACP = acp => Reducer.Initialized({...initialized(), acp})
let withSession = session => withACP(Reducer.Ready({connection: mockConnection, session}))
let sessionState = state =>
  switch runtime(state).acp {
  | Reducer.Ready({session}) => session
  | _ => failwith("Expected ready connection")
  }
let loadTask = taskId => Reducer.LoadTask({
  taskId,
  needsHistory: true,
  onUpdate: (_, _) => (),
  onTitleUpdated: (_, _) => (),
  onComplete: _ => (),
})

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

  describe("Initial State", () => {
    test(
      "starts with all components disconnected",
      t => {
        let state = Reducer.initialState
        t->expect(state)->Expect.toBe(Reducer.Uninitialized)
        t->expect(Reducer.Selectors.getRelay(state))->Expect.toBe(None)
        t->expect(Reducer.Selectors.getSession(state))->Expect.toBe(None)
        t->expect(Reducer.Selectors.getConnectionStatus(state))->Expect.toBe(Disconnected)
      },
    )
  })

  describe("Initialize", () => {
    test(
      "Initialize sets up relay, mcpServer and emits connection effects",
      t => {
        let (nextState, effects) = initialize(Reducer.initialState)
        let runtime = runtime(nextState)
        t->expect(runtime.acp)->Expect.toEqual(Reducer.Connecting(Opening))
        t->expect(runtime.relay)->Expect.toEqual(Reducer.RelayConnecting(mockRelay))
        t->expect(Reducer.Selectors.getConnectionStatus(nextState))->Expect.toBe(Connecting)
        t->expect(Reducer.Selectors.getRelay(nextState)->Option.getOrThrow)->Expect.toBe(mockRelay)
        t->expect(runtime.mcpServer)->Expect.toEqual(initPayload().mcpServer)
        t->expect(effectKinds(effects))->Expect.toEqual([#connectACP, #connectRelay])
      },
    )
    test(
      "ignores initialization after initialization has started",
      t => {
        let (state, _) = initialize(Reducer.initialState)
        let (nextState, effects) = initialize(state)
        t->expect(nextState)->Expect.toBe(state)
        t->expect(effectKinds(effects))->Expect.toEqual([#logInfo])
      },
    )
    test(
      "allows initialization after provider disposal",
      t => {
        let (initializedState, _) = initialize(Reducer.initialState)
        let (disposedState, disposeEffects) = Reducer.reduce(initializedState, Dispose)
        let (reinitializedState, reinitializeEffects) = initialize(disposedState)
        t->expect(disposedState)->Expect.toEqual(Reducer.initialState)
        t->expect(Reducer.Selectors.getRelay(disposedState))->Expect.toBe(None)
        t->expect(effectKinds(disposeEffects))->Expect.toEqual([#cleanup])
        t->expect(runtime(reinitializedState).acp)->Expect.toEqual(Reducer.Connecting(Opening))
        t->expect(effectKinds(reinitializeEffects))->Expect.toEqual([#connectACP, #connectRelay])
      },
    )
  })

  describe("Authentication Retry", () => {
    test(
      "auth required exposes login URL without starting automatic retry",
      t => {
        let state = withACP(Connecting(Opening))
        let (nextState, effects) = Reducer.reduce(
          state,
          ACPAuthRequiredReceived({loginUrl: loginUrl}),
        )
        t->expect(Reducer.Selectors.getAuthRedirectUrl(nextState))->Expect.toBe(Some(loginUrl))
        t->expect(effectKinds(effects))->Expect.toEqual([])
      },
    )
    test(
      "opening sign-in reconnects ACP without reconnecting relay",
      t => {
        let state = Reducer.Initialized({
          ...initialized(),
          acp: WaitingForSignIn({loginUrl: loginUrl}),
          relay: RelayConnected(mockRelay),
        })
        let (nextState, effects) = Reducer.reduce(state, BeginAuthenticationRetry)
        t
        ->expect(runtime(nextState).acp)
        ->Expect.toEqual(Authenticating({loginUrl, attempt: Opening}))
        t->expect(Reducer.Selectors.getAuthRedirectUrl(nextState))->Expect.toBe(Some(loginUrl))
        t->expect(runtime(nextState).relay)->Expect.toBe(runtime(state).relay)
        t->expect(effectKinds(effects))->Expect.toEqual([#connectACP])
      },
    )
    test(
      "failed automatic authentication schedules another retry",
      t => {
        let state = withACP(Authenticating({loginUrl, attempt: Opening}))
        let (nextState, effects) = Reducer.reduce(
          state,
          ACPAuthRequiredReceived({loginUrl: loginUrl}),
        )
        t->expect(runtime(nextState).acp)->Expect.toEqual(WaitingForAuthRetry({loginUrl: loginUrl}))
        t->expect(effectKinds(effects))->Expect.toEqual([#scheduleAuthRetry])
      },
    )
    test(
      "duplicate retry is ignored while authentication is in flight",
      t => {
        let state = withACP(Authenticating({loginUrl, attempt: Opening}))
        let (nextState, effects) = Reducer.reduce(state, RetryAuthentication)
        t->expect(nextState)->Expect.toBe(state)
        t->expect(effectKinds(effects))->Expect.toEqual([])
      },
    )
    test(
      "transient connection failure keeps automatic authentication active",
      t => {
        let state = withACP(Authenticating({loginUrl, attempt: Opening}))
        let (nextState, effects) = Reducer.reduce(state, ACPConnectError("Network unavailable"))
        t->expect(runtime(nextState).acp)->Expect.toEqual(WaitingForAuthRetry({loginUrl: loginUrl}))
        t->expect(effectKinds(effects))->Expect.toEqual([#logInfo, #scheduleAuthRetry])
      },
    )
    test(
      "stale automatic retry is ignored after authentication succeeds",
      t => {
        let state = withSession(NoSession)
        let (nextState, effects) = Reducer.reduce(state, RetryAuthentication)
        t->expect(nextState)->Expect.toBe(state)
        t->expect(effectKinds(effects))->Expect.toEqual([])
      },
    )
  })

  test("logout disconnects ACP and starts confirmation", t => {
    let state = withSession(NoSession)
    let (nextState, effects) = Reducer.reduce(state, BeginLogout)
    t
    ->expect(runtime(nextState).acp)
    ->Expect.toEqual(Closing({connection: mockConnection, session: None}))
    t->expect(Reducer.Selectors.getSession(nextState))->Expect.toBe(None)
    t->expect(Reducer.Selectors.getConnectionStatus(nextState))->Expect.toBe(LoggingOut)
    t->expect(effectKinds(effects))->Expect.toEqual([#logout])
  })

  describe("Relay Lifecycle", () => {
    test(
      "RelayConnectSuccess transitions to RelayConnected",
      t => {
        let state = Reducer.Initialized({...initialized(), relay: RelayConnecting(mockRelay)})
        let (nextState, effects) = Reducer.reduce(state, RelayConnectSuccess)
        t->expect(runtime(nextState).relay)->Expect.toEqual(Reducer.RelayConnected(mockRelay))
        t->expect(Reducer.Selectors.getRelay(nextState)->Option.getOrThrow)->Expect.toBe(mockRelay)
        t->expect(trackedRelayOutcomes(effects))->Expect.toEqual([Client__Analytics.Success])
      },
    )
    test(
      "RelayConnectError transitions to RelayError and classifies analytics",
      t => {
        [
          ("HTTP 500: Error", Client__Analytics.HttpError),
          ("Invalid tools response: bad data", Client__Analytics.InvalidResponse),
          ("Connection refused", Client__Analytics.NetworkError),
        ]->Array.forEach(
          ((message, reason)) => {
            let state = Reducer.Initialized({...initialized(), relay: RelayConnecting(mockRelay)})
            let (nextState, effects) = Reducer.reduce(state, RelayConnectError(message))
            t
            ->expect(runtime(nextState).relay)
            ->Expect.toEqual(Reducer.RelayError(mockRelay, message))
            t
            ->expect(Reducer.Selectors.getRelay(nextState)->Option.getOrThrow)
            ->Expect.toBe(mockRelay)
            t
            ->expect(Reducer.Selectors.getConnectionStatus(nextState))
            ->Expect.toEqual(Error(message))
            t->expect(effectKinds(effects))->Expect.toContain(#logError)
            t
            ->expect(trackedRelayOutcomes(effects))
            ->Expect.toEqual([Client__Analytics.Failure(reason)])
          },
        )
      },
    )
    test(
      "stale relay completions do not emit analytics",
      t => {
        let state = Reducer.Initialized({...initialized(), relay: RelayConnected(mockRelay)})
        let actions: array<Reducer.action> = [
          Reducer.RelayConnectSuccess,
          Reducer.RelayConnectError("late failure"),
        ]
        actions->Array.forEach(
          action => {
            let (_, effects) = Reducer.reduce(state, action)
            t->expect(trackedRelayOutcomes(effects))->Expect.toEqual([])
          },
        )
      },
    )
  })

  describe("Session Creation", () => {
    test(
      "SessionCreateSuccess transitions to SessionActive",
      t => {
        let mockSession = mock({"sessionId": "sess-1", "channel": null})
        let state = withSession(SessionCreating("sess-1"))
        let (nextState, effects) = Reducer.reduce(state, SessionCreateSuccess(mockSession))
        switch sessionState(nextState) {
        | Reducer.SessionActive(session) => t->expect(session)->Expect.toBe(mockSession)
        | _ => t->expect("active session")->Expect.toBe("missing")
        }
        t
        ->expect(Reducer.Selectors.getConnectionStatus(nextState))
        ->Expect.toEqual(Reducer.Selectors.SessionActive("sess-1"))
        t->expect(effectKinds(effects))->Expect.toEqual([#logInfo])
      },
    )
    test(
      "matching parse failures preserve failed session resources",
      t => {
        let mockSession = mock({"sessionId": "sess-1", "channel": null})
        [Reducer.SessionActive(mockSession), Reducer.SessionCreating("sess-1")]->Array.forEach(
          session => {
            let (failed, effects) = Reducer.reduce(
              withSession(session),
              SessionFailed({sessionId: "sess-1", error: "invalid attribution"}),
            )
            let expected: Reducer.sessionState = switch session {
            | SessionActive(session) => SessionFailed({session, error: "invalid attribution"})
            | NoSession | SessionCreating(_) | SessionCreationFailed(_) | SessionFailed(_) =>
              SessionCreationFailed("invalid attribution")
            }
            t->expect(sessionState(failed))->Expect.toEqual(expected)
            t->expect(effectKinds(effects))->Expect.toEqual([#logError])
          },
        )
      },
    )
    test(
      "stale parse and late activation failures do not fail current session",
      t => {
        let mockSession = mock({"sessionId": "sess-2", "channel": null})
        let state = withSession(SessionActive(mockSession))
        [
          Reducer.SessionFailed({sessionId: "sess-1", error: "stale update"}),
          Reducer.SessionCreateError({
            sessionId: "sess-2",
            error: Reducer.ACP.requestErrorFromMessage("late activation"),
          }),
        ]->Array.forEach(
          action => {
            let (nextState, effects) = Reducer.reduce(state, action)
            t->expect(sessionState(nextState))->Expect.toEqual(SessionActive(mockSession))
            t->expect(effectKinds(effects))->Expect.toEqual([#logInfo])
          },
        )
      },
    )
    test(
      "stale load completion cannot replace the latest requested task",
      t => {
        let initial = withSession(NoSession)
        let (loadingFirst, _) = Reducer.reduce(initial, loadTask("sess-1"))
        let (loadingSecond, _) = Reducer.reduce(loadingFirst, loadTask("sess-2"))
        let staleSession = mock({"sessionId": "sess-1", "channel": null})
        let (afterStaleSuccess, effects) = Reducer.reduce(
          loadingSecond,
          Reducer.SessionCreateSuccess(staleSession),
        )
        switch sessionState(afterStaleSuccess) {
        | Reducer.SessionCreating("sess-2") => ()
        | _ => t->expect("latest load pending")->Expect.toBe("wrong state")
        }
        switch effects {
        | [Reducer.CleanupSessionEffect({session: {sessionId: "sess-1"}}), Reducer.LogInfo(_)] => ()
        | _ => t->expect(effectKinds(effects))->Expect.toEqual([#cleanupSession, #logInfo])
        }
      },
    )
    test(
      "switching tasks enters SessionCreating before cleanup and load",
      t => {
        let oldSession = mock({"sessionId": "sess-1", "channel": null})
        let state = withSession(SessionActive(oldSession))
        let (nextState, effects) = Reducer.reduce(state, loadTask("sess-2"))
        t->expect(sessionState(nextState))->Expect.toEqual(SessionCreating("sess-2"))
        switch effects {
        | [Reducer.CleanupSessionEffect({session: cleaned}), Reducer.LoadTaskEffect({request})] =>
          t->expect(cleaned)->Expect.toBe(oldSession)
          t->expect(request.taskId)->Expect.toBe("sess-2")
        | _ => t->expect(effectKinds(effects))->Expect.toEqual([#cleanupSession, #loadTask])
        }
      },
    )
    test(
      "billing SessionCreateError returns to NoSession",
      t => {
        let err = FrontmanAiFrontmanClient.FrontmanClient__ACP.requestErrorWithCode(
          ~code=FrontmanAiFrontmanProtocol.FrontmanProtocol__JsonRpc.ErrorCode.billingInactive,
          ~message="Alternate billing copy",
        )
        let state = withSession(SessionCreating("billing-session"))
        let (nextState, effects) = Reducer.reduce(
          state,
          SessionCreateError({sessionId: "billing-session", error: err}),
        )
        t->expect(sessionState(nextState))->Expect.toBe(Reducer.NoSession)
        t->expect(effectKinds(effects))->Expect.toEqual([#logError])
      },
    )
  })

  describe("Prompt Sending", () => {
    test(
      "allows another prompt while previous prompt is still in flight",
      t => {
        let mockSession = mock({"sessionId": "task-1"})
        let activeState = withSession(SessionActive(mockSession))
        let emptyBlocks: array<ContentBlock.t> = []
        let (nextPromptState, firstEffects) = Reducer.reduce(
          activeState,
          SendPrompt({
            text: "first",
            additionalBlocks: emptyBlocks,
            onComplete: _ => (),
            _meta: None,
          }),
        )
        let (_, secondEffects) = Reducer.reduce(
          nextPromptState,
          SendPrompt({
            text: "second",
            additionalBlocks: emptyBlocks,
            onComplete: _ => (),
            _meta: None,
          }),
        )
        switch (firstEffects, secondEffects) {
        | (
            [Reducer.SendPromptEffect({text: "first"})],
            [Reducer.SendPromptEffect({text: "second"})],
          ) => ()
        | _ =>
          t
          ->expect((effectKinds(firstEffects), effectKinds(secondEffects)))
          ->Expect.toEqual(([#sendPrompt], [#sendPrompt]))
        }
      },
    )
  })

  describe("Connection Lifecycle - Session Creation Trigger", () => {
    test(
      "CreateSession starts when transports and MCP server are ready with no session",
      t => {
        let mockServer = mock({"tools": []})
        let state = Reducer.Initialized({
          ...initialized(),
          acp: Ready({connection: mockConnection, session: NoSession}),
          relay: RelayConnected(mockRelay),
          mcpServer: mockServer,
        })
        t->expect(Reducer.Selectors.getConnectionStatus(state))->Expect.toBe(Connected)
        let (nextState, effects) = Reducer.reduce(
          state,
          CreateSession({
            sessionId: "sess-1",
            onUpdate: (_, _) => (),
            onTitleUpdated: (_, _) => (),
            onComplete: _ => (),
          }),
        )
        t->expect(sessionState(nextState))->Expect.toEqual(Reducer.SessionCreating("sess-1"))
        switch effects {
        | [Reducer.CreateSessionEffect({connection, mcpServer, request})] =>
          t->expect(connection)->Expect.toBe(mockConnection)
          t->expect(mcpServer)->Expect.toBe(mockServer)
          t->expect(request.sessionId)->Expect.toBe("sess-1")
        | _ => t->expect(effectKinds(effects))->Expect.toEqual([#createSession])
        }
      },
    )
  })
})
