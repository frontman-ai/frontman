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
let hasConnectFrameworkMCP = effects =>
  hasEffect(effects, e =>
    switch e {
    | Reducer.ConnectFrameworkMCP(_) => true
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
        t->expect(state.frameworkMCP)->Expect.toBe(Reducer.FrameworkMCPDisconnected)
        t->expect(state.session)->Expect.toBe(Reducer.NoSession)
        t->expect(state.frameworkMCPClient)->Expect.toBe(None)
        t->expect(state.mcpServer)->Expect.toBe(None)
        t->expect(Reducer.Selectors.getConnectionStatus(state))->Expect.toBe(Disconnected)
      },
    )
  })

  describe("Initialize", () => {
    test(
      "Initialize sets up framework MCP client and server and emits connection effects",
      t => {
        let mockFrameworkClient = Obj.magic({"id": "framework-mcp-1"})
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
          Initialize({
            config: mockConfig,
            frameworkMCPClient: mockFrameworkClient,
            mcpServer: mockServer,
          }),
        )

        t->expect(nextState.acp)->Expect.toBe(Reducer.ACPConnecting)
        t->expect(nextState.frameworkMCP)->Expect.toBe(Reducer.FrameworkMCPConnecting)
        t->expect(Reducer.Selectors.getConnectionStatus(nextState))->Expect.toBe(Connecting)
        t->expect(Option.isSome(nextState.frameworkMCPClient))->Expect.toBe(true)
        t->expect(Option.isSome(nextState.mcpServer))->Expect.toBe(true)
        t->expect(hasConnectACP(effects))->Expect.toBe(true)
        t
        ->expect(getConnectACPInitialAuthBehavior(effects))
        ->Expect.toBe(Some(FtueState.ShowWelcomeModal))
        t->expect(hasConnectFrameworkMCP(effects))->Expect.toBe(true)
      },
    )

    test(
      "Initialize ignores when already initialized",
      t => {
        let mockFrameworkClient = Obj.magic({"id": "framework-mcp-1"})
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
          Initialize({
            config: mockConfig,
            frameworkMCPClient: mockFrameworkClient,
            mcpServer: mockServer,
          }),
        )

        t->expect(hasLogInfo(effects))->Expect.toBe(true)
      },
    )
  })

  describe("Framework MCP Lifecycle", () => {
    test(
      "FrameworkMCPConnectSuccess transitions to FrameworkMCPConnected",
      t => {
        let state = {...Reducer.initialState, frameworkMCP: FrameworkMCPConnecting}
        let (nextState, effects) = Reducer.reduce(state, FrameworkMCPConnectSuccess)

        t->expect(nextState.frameworkMCP)->Expect.toBe(Reducer.FrameworkMCPConnected)
        t->expect(hasLogInfo(effects))->Expect.toBe(true)
      },
    )

    test(
      "FrameworkMCPConnectError is non-fatal",
      t => {
        let state = {...Reducer.initialState, frameworkMCP: FrameworkMCPConnecting}
        let (nextState, effects) = Reducer.reduce(
          state,
          FrameworkMCPConnectError("Connection refused"),
        )

        switch nextState.frameworkMCP {
        | Reducer.FrameworkMCPError(_) => t->expect(true)->Expect.toBe(true)
        | _ => t->expect(false)->Expect.toBe(true)
        }
        t->expect(hasLogInfo(effects))->Expect.toBe(true)
      },
    )

    test(
      "ACP remains ready when framework MCP is unavailable",
      t => {
        let state = {
          ...Reducer.initialState,
          acp: ACPConnected(Obj.magic(null)),
          frameworkMCP: FrameworkMCPError("Connection refused"),
        }

        t->expect(Reducer.Selectors.getConnectionStatus(state))->Expect.toBe(Connected)
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
          frameworkMCP: FrameworkMCPConnected,
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
          frameworkMCP: FrameworkMCPConnected,
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

    test(
      "rejected prompts complete with an error",
      t => {
        let result = ref(None)
        let (_, effects) = Reducer.reduce(
          Reducer.initialState,
          SendPrompt({
            text: "hello",
            additionalBlocks: [],
            onComplete: value => result := Some(value),
            _meta: None,
          }),
        )

        effects->Array.forEach(
          effect => Reducer.handleEffect(effect, Reducer.initialState, _ => ()),
        )
        t->expect(result.contents)->Expect.toEqual(Some(Error("No active session")))
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
          frameworkMCP: FrameworkMCPConnected,
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
      },
    )

    test(
      "CreateSession waits for framework MCP discovery to complete",
      t => {
        let state = {
          ...Reducer.initialState,
          acp: ACPConnected(Obj.magic(null)),
          frameworkMCP: FrameworkMCPConnecting,
          mcpServer: Some(Obj.magic(null)),
        }
        let (nextState, effects) = Reducer.reduce(
          state,
          CreateSession({
            sessionId: "sess-browser-only",
            onUpdate: (_, _) => (),
            onTitleUpdated: (_, _) => (),
            onMcpMessage: (_, _) => (),
            onComplete: _ => (),
          }),
        )

        t->expect(nextState.session)->Expect.toEqual(NoSession)
        t
        ->expect(
          effects->Array.some(
            effect =>
              switch effect {
              | Reducer.NotifyCreateSessionRejected(_) => true
              | _ => false
              },
          ),
        )
        ->Expect.toBe(true)
      },
    )

    test(
      "rejected session requests complete with an error",
      t => {
        let createResult = ref(None)
        let loadResult = ref(None)
        let request: Reducer.createSessionRequest = {
          sessionId: "sess-1",
          onUpdate: (_, _) => (),
          onTitleUpdated: (_, _) => (),
          onMcpMessage: (_, _) => (),
          onComplete: result => createResult := Some(result),
        }
        let (_, createEffects) = Reducer.reduce(Reducer.initialState, CreateSession(request))
        let (_, loadEffects) = Reducer.reduce(
          Reducer.initialState,
          LoadTask({
            taskId: "task-1",
            needsHistory: true,
            onUpdate: (_, _) => (),
            onTitleUpdated: (_, _) => (),
            onMcpMessage: (_, _) => (),
            onComplete: result => loadResult := Some(result),
          }),
        )

        createEffects->Array.forEach(
          effect => Reducer.handleEffect(effect, Reducer.initialState, _ => ()),
        )
        loadEffects->Array.forEach(
          effect => Reducer.handleEffect(effect, Reducer.initialState, _ => ()),
        )

        t->expect(createResult.contents)->Expect.toEqual(Some(Error("Not ready")))
        t->expect(loadResult.contents)->Expect.toEqual(Some(Error("Not connected")))
      },
    )
  })
})
