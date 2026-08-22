open Vitest

module Reducer = Client__ConnectionReducer
module ContentBlock = FrontmanAiFrontmanProtocol.FrontmanProtocol__ContentBlock

let effectKinds = effects =>
  effects->Array.map(effect =>
    switch effect {
    | Reducer.LogError(_) => #logError
    | Reducer.LogInfo(_) => #logInfo
    | Reducer.TrackRelay(_) => #trackRelay
    | Reducer.ConnectACP(_) => #connectACP
    | Reducer.ScheduleAuthRetry(_) => #scheduleAuthRetry
    | Reducer.LogoutEffect(_) => #logout
    | Reducer.ConnectRelay(_) => #connectRelay
    | Reducer.CreateSessionEffect(_) => #createSession
    | Reducer.SendPromptEffect(_) => #sendPrompt
    | Reducer.CancelPromptEffect(_) => #cancelPrompt
    | Reducer.RetryTurnEffect(_) => #retryTurn
    | Reducer.FetchSessionsEffect(_) => #fetchSessions
    | Reducer.LoadTaskEffect(_) => #loadTask
    | Reducer.DeleteSessionEffect(_) => #deleteSession
    | Reducer.NotifyDeleteSessionRejected(_) => #deleteRejected
    | Reducer.NotifySessionWaiters(_) => #notifySessionWaiters
    | Reducer.NotifyPromptRejected(_) => #notifyPromptRejected
    | Reducer.CleanupSessionEffect(_) => #cleanupSession
    }
  )
let trackedOutcomes = effects =>
  effects->Array.filterMap(e =>
    switch e {
    | Reducer.TrackRelay(outcome) => Some(outcome)
    | _ => None
    }
  )

let mock = value => Obj.magic(value)
let loginUrl = "https://app.frontman.sh/users/log-in"
let initConfig: Reducer.initConfig = {
  endpoint: "ws://test",
  tokenUrl: "http://test/api/socket-token",
  loginUrl: "http://test/users/log-in",
  clientName: "test",
  clientVersion: "1.0.0",
  onACPMessage: (_, _) => (),
  onTitleUpdated: None,
  _meta: JSON.Encode.object(Dict.fromArray([("framework", JSON.Encode.string("test"))])),
}
let initPayload = (): Reducer.initPayload => {
  config: initConfig,
  relay: mock({"id": "relay"}),
  mcpServer: mock({"tools": []}),
}
let initialize = state => Reducer.reduce(state, Initialize(initPayload()))
let loadTask = taskId => Reducer.EnsureTaskSession({
  taskId,
  mode: LoadExisting({needsHistory: true}),
  onUpdate: (_, _) => (),
  onTitleUpdated: (_, _) => (),
  onMcpMessage: (_, _) => (),
  onComplete: _ => (),
})
let ensureTask = (taskId, onComplete) => Reducer.EnsureTaskSession({
  taskId,
  mode: Create,
  onUpdate: (_, _) => (),
  onTitleUpdated: (_, _) => (),
  onMcpMessage: (_, _) => (),
  onComplete,
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

        t->expect(state.acp)->Expect.toBe(Reducer.ACPDisconnected)
        t->expect(state.relay)->Expect.toBe(Reducer.RelayDisconnected)
        t->expect(state.session)->Expect.toBe(Reducer.NoSession)
        t->expect(state.relayInstance)->Expect.toBe(None)
        t->expect(state.mcpServer)->Expect.toBe(None)
        t->expect(state.acpConfig)->Expect.toBe(None)
        t->expect(state.authRetryActive)->Expect.toBe(false)
        t->expect(state.authRetryInFlight)->Expect.toBe(false)
        t->expect(state.abortController)->Expect.toBe(None)
        t->expect(Reducer.Selectors.getConnectionStatus(state))->Expect.toBe(Disconnected)
      },
    )
  })

  describe("Initialize", () => {
    test(
      "Initialize sets up relay, mcpServer and emits connection effects",
      t => {
        let (nextState, effects) = initialize(Reducer.initialState)

        t->expect(nextState.acp)->Expect.toBe(Reducer.ACPConnecting)
        t->expect(nextState.relay)->Expect.toBe(Reducer.RelayConnecting)
        t->expect(Reducer.Selectors.getConnectionStatus(nextState))->Expect.toBe(Connecting)
        t->expect(Option.isSome(nextState.relayInstance))->Expect.toBe(true)
        t->expect(Option.isSome(nextState.mcpServer))->Expect.toBe(true)
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
        t->expect(disposeEffects)->Expect.toEqual([])
        t->expect(reinitializedState.acp)->Expect.toBe(Reducer.ACPConnecting)
        t
        ->expect(effectKinds(reinitializeEffects))
        ->Expect.toEqual([#connectACP, #connectRelay])
      },
    )
  })

  describe("Authentication Retry", () => {
    test(
      "auth required exposes login URL without starting automatic retry",
      t => {
        let state = {...Reducer.initialState, acp: ACPConnecting}
        let (nextState, effects) = Reducer.reduce(
          state,
          ACPAuthRequiredReceived({loginUrl: loginUrl}),
        )

        t
        ->expect(Reducer.Selectors.getAuthRedirectUrl(nextState))
        ->Expect.toBe(Some(loginUrl))
        t->expect(effectKinds(effects))->Expect.toEqual([])
      },
    )

    test(
      "opening sign-in reconnects ACP without reconnecting relay",
      t => {
        let acpConfig = Obj.magic({"endpoint": "ws://test"})
        let state = {
          ...Reducer.initialState,
          acp: ACPAuthRequired({loginUrl: loginUrl}),
          acpConfig: Some(acpConfig),
          abortController: Some(WebAPI.AbortController.make()),
          relay: RelayConnected,
        }
        let (nextState, effects) = Reducer.reduce(state, BeginAuthenticationRetry)

        t->expect(nextState.acp)->Expect.toEqual(state.acp)
        t->expect(nextState.authRetryActive)->Expect.toBe(true)
        t->expect(nextState.authRetryInFlight)->Expect.toBe(true)
        t->expect(nextState.relay)->Expect.toBe(RelayConnected)
        t->expect(effectKinds(effects))->Expect.toEqual([#connectACP])
      },
    )

    test(
      "failed automatic authentication schedules another retry",
      t => {
        let state = {
          ...Reducer.initialState,
          acp: ACPAuthRequired({loginUrl: loginUrl}),
          authRetryActive: true,
          authRetryInFlight: true,
          abortController: Some(WebAPI.AbortController.make()),
        }
        let (nextState, effects) = Reducer.reduce(
          state,
          ACPAuthRequiredReceived({loginUrl: loginUrl}),
        )

        t->expect(nextState.authRetryActive)->Expect.toBe(true)
        t->expect(nextState.authRetryInFlight)->Expect.toBe(false)
        t->expect(nextState.acp)->Expect.toEqual(ACPAuthRequired({loginUrl: loginUrl}))
        t->expect(effectKinds(effects))->Expect.toEqual([#scheduleAuthRetry])
      },
    )

    test(
      "duplicate retry is ignored while authentication is in flight",
      t => {
        let state = {
          ...Reducer.initialState,
          acp: ACPAuthRequired({loginUrl: loginUrl}),
          acpConfig: Some(Obj.magic({"endpoint": "ws://test"})),
          abortController: Some(WebAPI.AbortController.make()),
          authRetryActive: true,
          authRetryInFlight: true,
        }
        let (nextState, effects) = Reducer.reduce(state, RetryAuthentication)

        t->expect(nextState)->Expect.toBe(state)
        t->expect(effectKinds(effects))->Expect.toEqual([])
      },
    )

    test(
      "transient connection failure keeps automatic authentication active",
      t => {
        let state = {
          ...Reducer.initialState,
          acp: ACPAuthRequired({loginUrl: loginUrl}),
          authRetryActive: true,
          authRetryInFlight: true,
          abortController: Some(WebAPI.AbortController.make()),
        }
        let (nextState, effects) = Reducer.reduce(state, ACPConnectError("Network unavailable"))

        t->expect(nextState.acp)->Expect.toEqual(state.acp)
        t->expect(nextState.authRetryActive)->Expect.toBe(true)
        t->expect(nextState.authRetryInFlight)->Expect.toBe(false)
        t->expect(effectKinds(effects))->Expect.toEqual([#logInfo, #scheduleAuthRetry])
      },
    )

    test(
      "stale automatic retry is ignored after authentication succeeds",
      t => {
        let state = {...Reducer.initialState, acp: ACPConnected(Obj.magic({"id": "connection"}))}
        let (nextState, effects) = Reducer.reduce(state, RetryAuthentication)

        t->expect(nextState)->Expect.toBe(state)
        t->expect(effectKinds(effects))->Expect.toEqual([])
      },
    )
  })

  test("logout disconnects ACP and starts confirmation", t => {
    let (initialized, _) = initialize(Reducer.initialState)
    let state = {...initialized, acp: ACPConnected(mock({"id": "connection"}))}
    let (nextState, effects) = Reducer.reduce(state, BeginLogout)

    t->expect(nextState.acp)->Expect.toBe(ACPLoggingOut)
    t->expect(nextState.session)->Expect.toBe(NoSession)
    t->expect(Reducer.Selectors.getConnectionStatus(nextState))->Expect.toBe(LoggingOut)
    t->expect(effectKinds(effects))->Expect.toEqual([#logout])
  })

  describe("Relay Lifecycle", () => {
    test(
      "RelayConnectSuccess transitions to RelayConnected",
      t => {
        let state = {...Reducer.initialState, relay: RelayConnecting}
        let (nextState, effects) = Reducer.reduce(state, RelayConnectSuccess)

        t->expect(nextState.relay)->Expect.toBe(Reducer.RelayConnected)
        t
        ->expect(trackedOutcomes(effects))
        ->Expect.toEqual([Client__Heap.Success])
      },
    )

    test(
      "RelayConnectError transitions to RelayError and classifies analytics",
      t => {
        [
          ("HTTP 500: Error", Client__Heap.HttpError),
          ("Invalid tools response: bad data", Client__Heap.InvalidResponse),
          ("Connection refused", Client__Heap.NetworkError),
        ]->Array.forEach(
          ((message, reason)) => {
            let state = {...Reducer.initialState, relay: RelayConnecting}
            let (nextState, effects) = Reducer.reduce(state, RelayConnectError(message))

            t->expect(nextState.relay)->Expect.toEqual(Reducer.RelayError(message))
            t->expect(trackedOutcomes(effects))->Expect.toEqual([Client__Heap.Failure(reason)])
          },
        )
      },
    )

    test(
      "stale relay completions do not emit analytics",
      t => {
        let state = {...Reducer.initialState, relay: RelayConnected}
        let actions: array<Reducer.action> = [
          Reducer.RelayConnectSuccess,
          Reducer.RelayConnectError("late failure"),
        ]
        actions->Array.forEach(
          action => {
            let (_, effects) = Reducer.reduce(state, action)
            t->expect(trackedOutcomes(effects))->Expect.toEqual([])
          },
        )
      },
    )
  })

  describe("Session Creation", () => {
    test(
      "same-task session requests coalesce and settle every waiter once",
      t => {
        let results = ref([])
        let record = result => results.contents->Array.push(result)
        let state = {
          ...Reducer.initialState,
          acp: ACPConnected(mock({"id": "connection"})),
          relay: RelayConnected,
          mcpServer: Some(mock({"id": "mcp-server"})),
        }
        let (creating, firstEffects) = Reducer.reduce(state, ensureTask("sess-1", record))
        let (coalesced, secondEffects) = Reducer.reduce(creating, ensureTask("sess-1", record))

        t->expect(effectKinds(firstEffects))->Expect.toEqual([#createSession])
        t->expect(secondEffects)->Expect.toEqual([])
        switch coalesced.session {
        | SessionCreating({waiters}) => t->expect(waiters->Array.length)->Expect.toBe(2)
        | _ => t->expect("creating session")->Expect.toBe("missing")
        }

        let session = Obj.magic({"sessionId": "sess-1", "channel": null})
        let (active, effects) = Reducer.reduce(coalesced, SessionCreateSuccess(session))
        effects->Array.forEach(effect => Reducer.handleEffect(effect, coalesced, _ => ()))
        t
        ->expect(Reducer.Selectors.getConnectionStatus(active))
        ->Expect.toEqual(Reducer.Selectors.SessionActive("sess-1"))
        let (_, activeEffects) = Reducer.reduce(active, ensureTask("sess-1", record))
        activeEffects->Array.forEach(effect => Reducer.handleEffect(effect, active, _ => ()))
        t
        ->expect(results.contents)
        ->Expect.toEqual([Ok("sess-1"), Ok("sess-1"), Ok("sess-1")])
      },
    )

    test(
      "matching parse failures transition active and creating sessions to SessionError",
      t => {
        let results = ref([])
        let record = result => results.contents->Array.push(result)
        let mockSession = Obj.magic({"sessionId": "sess-1", "channel": null})
        [
          Reducer.SessionActive(mockSession),
          Reducer.SessionCreating({
            taskId: "sess-1",
            waiters: [record, record],
          }),
        ]->Array.forEach(
          session => {
            let (failed, effects) = Reducer.reduce(
              {...Reducer.initialState, session},
              SessionFailed({sessionId: "sess-1", error: "invalid attribution"}),
            )

            t->expect(failed.session)->Expect.toEqual(SessionError("invalid attribution"))
            effects->Array.forEach(effect => Reducer.handleEffect(effect, failed, _ => ()))
          },
        )
        t
        ->expect(results.contents)
        ->Expect.toEqual([Error("invalid attribution"), Error("invalid attribution")])
      },
    )

    test(
      "clearing session rejects creation waiters exactly once",
      t => {
        let results = ref([])
        let session = Reducer.SessionCreating({
          taskId: "sess-1",
          waiters: [result => results.contents->Array.push(result)],
        })
        let state = {...Reducer.initialState, session}
        let (cleared, effects) = Reducer.reduce(state, ClearSession)
        let (_, staleEffects) = Reducer.reduce(
          cleared,
          SessionCreateError({sessionId: "sess-1", error: "late"}),
        )
        Array.concat(effects, staleEffects)->Array.forEach(
          effect => Reducer.handleEffect(effect, cleared, _ => ()),
        )
        t->expect(results.contents)->Expect.toEqual([Error("Task session activation cancelled")])
      },
    )

    test(
      "stale parse and late activation failures do not fail current session",
      t => {
        let mockSession = Obj.magic({"sessionId": "sess-2", "channel": null})
        let state = {...Reducer.initialState, session: SessionActive(mockSession)}
        [
          Reducer.SessionFailed({sessionId: "sess-1", error: "stale update"}),
          Reducer.SessionCreateError({sessionId: "sess-2", error: "late activation"}),
        ]->Array.forEach(
          action => {
            let (nextState, effects) = Reducer.reduce(state, action)
            t->expect(nextState.session)->Expect.toEqual(SessionActive(mockSession))
            t->expect(effectKinds(effects))->Expect.toEqual([#logInfo])
          },
        )
      },
    )

    test(
      "stale load completion cannot replace the latest requested task",
      t => {
        let initial = {
          ...Reducer.initialState,
          acp: ACPConnected(mock({"id": "connection"})),
          relay: RelayConnected,
          mcpServer: Some(mock({"id": "mcp-server"})),
        }
        let (loadingFirst, _) = Reducer.reduce(initial, loadTask("sess-1"))
        let (loadingSecond, _) = Reducer.reduce(loadingFirst, loadTask("sess-2"))
        let staleSession = Obj.magic({"sessionId": "sess-1", "channel": null})
        let (afterStaleSuccess, effects) = Reducer.reduce(
          loadingSecond,
          Reducer.SessionCreateSuccess(staleSession),
        )

        switch afterStaleSuccess.session {
        | Reducer.SessionCreating({taskId: "sess-2", waiters}) =>
          t->expect(waiters->Array.length)->Expect.toBe(1)
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
        let oldSession = Obj.magic({"sessionId": "sess-1", "channel": null})
        let state = {
          ...Reducer.initialState,
          acp: ACPConnected(mock({"id": "connection"})),
          relay: RelayConnected,
          mcpServer: Some(mock({"id": "mcp-server"})),
          session: SessionActive(oldSession),
        }
        let (nextState, effects) = Reducer.reduce(state, loadTask("sess-2"))

        switch nextState.session {
        | SessionCreating({taskId: "sess-2"}) => ()
        | _ => t->expect("sess-2 creating")->Expect.toBe("missing")
        }
        switch effects {
        | [Reducer.CleanupSessionEffect({session: cleaned}), Reducer.LoadTaskEffect({request})] =>
          t->expect(cleaned)->Expect.toBe(oldSession)
          t->expect(request.taskId)->Expect.toBe("sess-2")
        | _ => t->expect(effectKinds(effects))->Expect.toEqual([#cleanupSession, #loadTask])
        }
      },
    )
  })

  describe("Prompt Sending", () => {
    test(
      "rejects a prompt targeted at another task session",
      t => {
        let result = ref(None)
        let session = Obj.magic({"sessionId": "task-1"})
        let state = {...Reducer.initialState, session: SessionActive(session)}
        let (_, effects) = Reducer.reduce(
          state,
          SendPrompt({
            taskId: "task-2",
            text: "wrong task",
            additionalBlocks: [],
            onComplete: value => result := Some(value),
            _meta: None,
          }),
        )

        t->expect(effectKinds(effects))->Expect.toEqual([#notifyPromptRejected])
        effects->Array.forEach(effect => Reducer.handleEffect(effect, state, _ => ()))
        switch result.contents {
        | Some(Error(_)) => ()
        | _ => t->expect("task-targeted rejection")->Expect.toBe("missing")
        }
      },
    )

    test(
      "allows another prompt while previous prompt is still in flight",
      t => {
        let mockSession = Obj.magic({"sessionId": "task-1"})
        let activeState = {...Reducer.initialState, session: SessionActive(mockSession)}

        let emptyBlocks: array<ContentBlock.t> = []
        let (nextPromptState, firstEffects) = Reducer.reduce(
          activeState,
          SendPrompt({
            taskId: "task-1",
            text: "first",
            additionalBlocks: emptyBlocks,
            onComplete: _ => (),
            _meta: None,
          }),
        )

        let (_, secondEffects) = Reducer.reduce(
          nextPromptState,
          SendPrompt({
            taskId: "task-1",
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
      "EnsureTaskSession creates when transports and MCP server are ready",
      t => {
        let mockConn = Obj.magic({"socket": null})
        let mockServer = Obj.magic({"tools": []})
        let state = {
          ...Reducer.initialState,
          acp: ACPConnected(mockConn),
          relay: RelayConnected,
          mcpServer: Some(mockServer),
          session: NoSession,
        }

        t->expect(Reducer.Selectors.getConnectionStatus(state))->Expect.toBe(Connected)

        let (nextState, effects) = Reducer.reduce(
          state,
          EnsureTaskSession({
            taskId: "sess-1",
            mode: Create,
            onUpdate: (_, _) => (),
            onTitleUpdated: (_, _) => (),
            onMcpMessage: (_, _) => (),
            onComplete: _ => (),
          }),
        )

        switch nextState.session {
        | Reducer.SessionCreating({taskId: "sess-1"}) => ()
        | _ => t->expect("sess-1 creating")->Expect.toBe("missing")
        }
        switch effects {
        | [Reducer.CreateSessionEffect({connection, mcpServer, request})] =>
          t->expect(connection)->Expect.toBe(mockConn)
          t->expect(mcpServer)->Expect.toBe(mockServer)
          t->expect(request.sessionId)->Expect.toBe("sess-1")
        | _ => t->expect(effectKinds(effects))->Expect.toEqual([#createSession])
        }
      },
    )

    test(
      "rejected session ensure emits completion notification",
      t => {
        let completion = ref(None)
        let request: Reducer.ensureTaskSessionRequest = {
          taskId: "sess-2",
          mode: Create,
          onUpdate: (_, _) => (),
          onTitleUpdated: (_, _) => (),
          onMcpMessage: (_, _) => (),
          onComplete: result => completion := Some(result),
        }
        let state = Reducer.initialState
        let (_, effects) = Reducer.reduce(state, EnsureTaskSession(request))

        t->expect(effectKinds(effects))->Expect.toEqual([#notifySessionWaiters])
        switch effects {
        | [notification] => Reducer.handleEffect(notification, state, _ => ())
        | _ => ()
        }
        t->expect(completion.contents)->Expect.toEqual(Some(Error("Not connected")))
      },
    )
  })
})
