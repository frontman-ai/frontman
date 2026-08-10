open Vitest

module Reducer = Client__ConnectionReducer
module FtueState = Client__FtueState
module ContentBlock = FrontmanAiFrontmanProtocol.FrontmanProtocol__ContentBlock

let hasEffect = (effects, predicate) => effects->Array.some(predicate)
let hasLogInfo = effects =>
  hasEffect(effects, e =>
    switch e {
    | Reducer.LogInfo(_) => true
    | _ => false
    }
  )
let hasLogError = effects =>
  hasEffect(effects, e =>
    switch e {
    | Reducer.LogError(_) => true
    | _ => false
    }
  )
let hasConnectACP = effects =>
  hasEffect(effects, e =>
    switch e {
    | Reducer.ConnectACP(_) => true
    | _ => false
    }
  )
let hasConnectRelay = effects =>
  hasEffect(effects, e =>
    switch e {
    | Reducer.ConnectRelay(_) => true
    | _ => false
    }
  )
let hasTrackedEvent = (effects, predicate) =>
  hasEffect(effects, e =>
    switch e {
    | Reducer.TrackAnalytics(event) => predicate(event)
    | _ => false
    }
  )
let getConnectACPInitialAuthBehavior = effects =>
  effects->Array.findMap(e =>
    switch e {
    | Reducer.ConnectACP({initialAuthBehavior}) => Some(initialAuthBehavior)
    | _ => None
    }
  )

describe("Connection Reducer", () => {
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
        t->expect(Reducer.Selectors.getConnectionStatus(state))->Expect.toBe(Disconnected)
      },
    )
  })

  describe("Initialize", () => {
    test(
      "Initialize sets up relay, mcpServer and emits connection effects",
      t => {
        let mockRelay = Obj.magic({"id": "relay-1"})
        let mockServer = Obj.magic({"tools": []})
        let mockConfig: Reducer.initConfig = {
          endpoint: "ws://test",
          tokenUrl: "http://test/api/socket-token",
          loginUrl: "http://test/users/log-in",
          clientName: "test",
          clientVersion: "1.0.0",
          onACPMessage: (_, _) => (),
          onTitleUpdated: None,
          _meta: JSON.Encode.object(Dict.fromArray([("framework", JSON.Encode.string("test"))])),
        }
        let (nextState, effects) = Reducer.reduce(
          {...Reducer.initialState, initialAuthBehavior: FtueState.ShowWelcomeModal},
          Initialize({config: mockConfig, relay: mockRelay, mcpServer: mockServer}),
        )

        t->expect(nextState.acp)->Expect.toBe(Reducer.ACPConnecting)
        t->expect(nextState.relay)->Expect.toBe(Reducer.RelayConnecting)
        t->expect(Reducer.Selectors.getConnectionStatus(nextState))->Expect.toBe(Connecting)
        t->expect(Option.isSome(nextState.relayInstance))->Expect.toBe(true)
        t->expect(Option.isSome(nextState.mcpServer))->Expect.toBe(true)
        t->expect(hasConnectACP(effects))->Expect.toBe(true)
        t
        ->expect(getConnectACPInitialAuthBehavior(effects))
        ->Expect.toBe(Some(FtueState.ShowWelcomeModal))
        t->expect(hasConnectRelay(effects))->Expect.toBe(true)
      },
    )

    test(
      "Initialize ignores when already initialized",
      t => {
        let mockRelay = Obj.magic({"id": "relay-1"})
        let mockServer = Obj.magic({"tools": []})
        let mockConfig: Reducer.initConfig = {
          endpoint: "ws://test",
          tokenUrl: "http://test/api/socket-token",
          loginUrl: "http://test/users/log-in",
          clientName: "test",
          clientVersion: "1.0.0",
          onACPMessage: (_, _) => (),
          onTitleUpdated: None,
          _meta: JSON.Encode.object(Dict.fromArray([("framework", JSON.Encode.string("test"))])),
        }
        let state = {...Reducer.initialState, acp: ACPConnecting}
        let (_, effects) = Reducer.reduce(
          state,
          Initialize({config: mockConfig, relay: mockRelay, mcpServer: mockServer}),
        )

        t->expect(hasLogInfo(effects))->Expect.toBe(true)
      },
    )
  })

  describe("Relay Lifecycle", () => {
    test(
      "RelayConnectSuccess transitions to RelayConnected",
      t => {
        let state = {...Reducer.initialState, relay: RelayConnecting}
        let (nextState, effects) = Reducer.reduce(state, RelayConnectSuccess)

        t->expect(nextState.relay)->Expect.toBe(Reducer.RelayConnected)
        t->expect(hasLogInfo(effects))->Expect.toBe(true)
        t
        ->expect(
          hasTrackedEvent(
            effects,
            event =>
              switch event {
              | Client__Heap.LocalRelayDiscoveryCompleted({outcome: Success}) => true
              | _ => false
              },
          ),
        )
        ->Expect.toBe(true)
      },
    )

    test(
      "RelayConnectError is non-fatal",
      t => {
        let state = {...Reducer.initialState, relay: RelayConnecting}
        let (nextState, effects) = Reducer.reduce(
          state,
          RelayConnectError({message: "Connection refused", reason: Client__Heap.NetworkError}),
        )

        switch nextState.relay {
        | Reducer.RelayError(_) => t->expect(true)->Expect.toBe(true)
        | _ => t->expect(false)->Expect.toBe(true)
        }
        t->expect(hasLogInfo(effects))->Expect.toBe(true)
        t
        ->expect(
          hasTrackedEvent(
            effects,
            event =>
              switch event {
              | Client__Heap.LocalRelayDiscoveryCompleted({outcome: Failure(NetworkError)}) => true
              | _ => false
              },
          ),
        )
        ->Expect.toBe(true)
      },
    )

    test(
      "stale relay completions do not emit analytics",
      t => {
        let state = {...Reducer.initialState, relay: RelayConnected}
        let (_, effects) = Reducer.reduce(state, RelayConnectSuccess)

        t->expect(hasTrackedEvent(effects, _ => true))->Expect.toBe(false)
      },
    )
  })

  describe("Session Creation", () => {
    test(
      "SessionCreateSuccess transitions to SessionActive",
      t => {
        let mockSession = Obj.magic({"sessionId": "sess-1", "channel": null})
        let state = {...Reducer.initialState, session: SessionCreating("sess-1")}
        let (nextState, effects) = Reducer.reduce(state, SessionCreateSuccess(mockSession))

        switch nextState.session {
        | Reducer.SessionActive(_) => t->expect(true)->Expect.toBe(true)
        | _ => t->expect(false)->Expect.toBe(true)
        }
        t
        ->expect(Reducer.Selectors.getConnectionStatus(nextState))
        ->Expect.toEqual(Reducer.Selectors.SessionActive("sess-1"))
        t->expect(hasLogInfo(effects))->Expect.toBe(true)
      },
    )

    test(
      "matching parse failures transition active and creating sessions to SessionError",
      t => {
        let mockSession = Obj.magic({"sessionId": "sess-1", "channel": null})
        [Reducer.SessionActive(mockSession), Reducer.SessionCreating("sess-1")]->Array.forEach(
          session => {
            let (failed, effects) = Reducer.reduce(
              {...Reducer.initialState, session},
              SessionFailed({sessionId: "sess-1", error: "invalid attribution"}),
            )

            t->expect(failed.session)->Expect.toEqual(SessionError("invalid attribution"))
            t->expect(hasLogError(effects))->Expect.toBe(true)
          },
        )
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
            t->expect(hasLogInfo(effects))->Expect.toBe(true)
          },
        )
      },
    )

    test(
      "stale load completion cannot replace the latest requested task",
      t => {
        let loadTask = taskId => Reducer.LoadTask({
          taskId,
          needsHistory: true,
          onUpdate: (_, _) => (),
          onTitleUpdated: (_, _) => (),
          onMcpMessage: (_, _) => (),
          onComplete: _ => (),
        })
        let initial = {
          ...Reducer.initialState,
          acp: ACPConnected(Obj.magic(null)),
          mcpServer: Some(Obj.magic(null)),
        }
        let (loadingFirst, _) = Reducer.reduce(initial, loadTask("sess-1"))
        let (loadingSecond, _) = Reducer.reduce(loadingFirst, loadTask("sess-2"))
        let staleSession = Obj.magic({"sessionId": "sess-1", "channel": null})
        let (afterStaleSuccess, effects) = Reducer.reduce(
          loadingSecond,
          Reducer.SessionCreateSuccess(staleSession),
        )

        switch afterStaleSuccess.session {
        | Reducer.SessionCreating("sess-2") => ()
        | _ => t->expect("latest load pending")->Expect.toBe("wrong state")
        }
        t
        ->expect(
          effects->Array.some(
            effect =>
              switch effect {
              | Reducer.CleanupSessionEffect({session: {sessionId: "sess-1"}}) => true
              | _ => false
              },
          ),
        )
        ->Expect.toBe(true)
      },
    )

    test(
      "switching tasks enters SessionCreating before cleanup and load",
      t => {
        let oldSession = Obj.magic({"sessionId": "sess-1", "channel": null})
        let state = {
          ...Reducer.initialState,
          acp: ACPConnected(Obj.magic(null)),
          mcpServer: Some(Obj.magic(null)),
          session: SessionActive(oldSession),
        }
        let (nextState, effects) = Reducer.reduce(
          state,
          LoadTask({
            taskId: "sess-2",
            needsHistory: true,
            onUpdate: (_, _) => (),
            onTitleUpdated: (_, _) => (),
            onMcpMessage: (_, _) => (),
            onComplete: _ => (),
          }),
        )

        t->expect(nextState.session)->Expect.toEqual(SessionCreating("sess-2"))
        t
        ->expect(
          effects->Array.map(
            effect =>
              switch effect {
              | Reducer.CleanupSessionEffect(_) => #cleanup
              | Reducer.LoadTaskEffect(_) => #load
              | _ => #other
              },
          ),
        )
        ->Expect.toEqual([#cleanup, #load])
      },
    )
  })

  describe("Prompt Sending", () => {
    test(
      "allows another prompt while previous prompt is still in flight",
      t => {
        let mockSession = Obj.magic({"sessionId": "task-1"})
        let activeState = {...Reducer.initialState, session: SessionActive(mockSession)}

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

        t
        ->expect(
          hasEffect(
            firstEffects,
            e =>
              switch e {
              | Reducer.SendPromptEffect(_) => true
              | _ => false
              },
          ),
        )
        ->Expect.toBe(true)
        t
        ->expect(
          hasTrackedEvent(
            firstEffects,
            event =>
              switch event {
              | Client__Heap.PromptRequestSent => true
              | _ => false
              },
          ),
        )
        ->Expect.toBe(true)
        t
        ->expect(
          hasEffect(
            secondEffects,
            e =>
              switch e {
              | Reducer.SendPromptEffect(_) => true
              | _ => false
              },
          ),
        )
        ->Expect.toBe(true)
      },
    )
  })

  describe("Connection Lifecycle - Session Creation Trigger", () => {
    test(
      "CreateSession action works when connectionStatus is Connected",
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
          CreateSession({
            sessionId: "sess-1",
            onUpdate: (_, _) => (),
            onTitleUpdated: (_, _) => (),
            onMcpMessage: (_, _) => (),
            onComplete: _ => (),
          }),
        )

        t->expect(nextState.session)->Expect.toEqual(Reducer.SessionCreating("sess-1"))
        t
        ->expect(
          hasEffect(
            effects,
            e =>
              switch e {
              | Reducer.CreateSessionEffect(_) => true
              | _ => false
              },
          ),
        )
        ->Expect.toBe(true)
        t
        ->expect(
          hasTrackedEvent(
            effects,
            event =>
              switch event {
              | Client__Heap.TaskCreationRequested => true
              | _ => false
              },
          ),
        )
        ->Expect.toBe(true)
      },
    )
  })
})
