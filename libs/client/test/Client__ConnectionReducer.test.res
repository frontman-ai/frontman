open Vitest

module Reducer = Client__ConnectionReducer
module ACP = FrontmanAiFrontmanClient.FrontmanClient__ACP
module Relay = FrontmanAiFrontmanClient.FrontmanClient__Relay
module MCPServer = FrontmanAiFrontmanClient.FrontmanClient__MCP__Server

// Helper to check if effect list contains a specific effect type
let hasEffect = (effects, predicate) => effects->Array.some(predicate)
let hasLogError = effects =>
  hasEffect(effects, e =>
    switch e {
    | Reducer.LogError(_) => true
    | _ => false
    }
  )
let hasLogInfo = effects =>
  hasEffect(effects, e =>
    switch e {
    | Reducer.LogInfo(_) => true
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

describe("Connection Reducer", () => {
  describe("Initial State", () => {
    test("starts with all components disconnected", t => {
      let state = Reducer.initialState

      t->expect(state.acp)->Expect.toBe(Reducer.ACPDisconnected)
      t->expect(state.relay)->Expect.toBe(Reducer.RelayDisconnected)
      t->expect(state.session)->Expect.toBe(Reducer.NoSession)
      t->expect(state.relayInstance)->Expect.toBe(None)
      t->expect(state.mcpServer)->Expect.toBe(None)
    })
  })

  describe("ACP Connection Flow", () => {
    test("transitions from Disconnected to Connecting on ACPConnectStart", t => {
      let (nextState, effects) = Reducer.reduce(Reducer.initialState, ACPConnectStart)

      t->expect(nextState.acp)->Expect.toBe(Reducer.ACPConnecting)
      t->expect(effects->Array.length)->Expect.toBe(0)
    })

    test("rejects ACPConnectStart when already connecting", t => {
      let state = {...Reducer.initialState, acp: ACPConnecting}
      let (nextState, effects) = Reducer.reduce(state, ACPConnectStart)

      t->expect(nextState.acp)->Expect.toBe(Reducer.ACPConnecting)
      t->expect(hasLogError(effects))->Expect.toBe(true)
    })
  })

  describe("Initialize", () => {
    test("Initialize sets up relay, mcpServer and emits connection effects", t => {
      let mockRelay = Obj.magic({"id": "relay-1"})
      let mockServer = Obj.magic({"tools": []})
      let mockConfig: Reducer.initConfig = {
        endpoint: "ws://test",
        tokenUrl: "http://test/api/socket-token",
        loginUrl: "http://test/users/log-in",
        clientName: "test",
        clientVersion: "1.0.0",
        baseUrl: "http://test",
        onACPMessage: (_, _) => (),
        onTitleUpdated: None,
        _meta: JSON.Encode.object(Dict.fromArray([("framework", JSON.Encode.string("test"))])),
      }
      let (nextState, effects) = Reducer.reduce(
        Reducer.initialState,
        Initialize({config: mockConfig, relay: mockRelay, mcpServer: mockServer}),
      )

      t->expect(nextState.acp)->Expect.toBe(Reducer.ACPConnecting)
      t->expect(nextState.relay)->Expect.toBe(Reducer.RelayConnecting)
      t->expect(Option.isSome(nextState.relayInstance))->Expect.toBe(true)
      t->expect(Option.isSome(nextState.mcpServer))->Expect.toBe(true)
      t->expect(hasConnectACP(effects))->Expect.toBe(true)
      t->expect(hasConnectRelay(effects))->Expect.toBe(true)
    })

    test("Initialize rejects when already initialized", t => {
      let mockRelay = Obj.magic({"id": "relay-1"})
      let mockServer = Obj.magic({"tools": []})
      let mockConfig: Reducer.initConfig = {
        endpoint: "ws://test",
        tokenUrl: "http://test/api/socket-token",
        loginUrl: "http://test/users/log-in",
        clientName: "test",
        clientVersion: "1.0.0",
        baseUrl: "http://test",
        onACPMessage: (_, _) => (),
        onTitleUpdated: None,
        _meta: JSON.Encode.object(Dict.fromArray([("framework", JSON.Encode.string("test"))])),
      }
      let state = {...Reducer.initialState, acp: ACPConnecting}
      let (_, effects) = Reducer.reduce(
        state,
        Initialize({config: mockConfig, relay: mockRelay, mcpServer: mockServer}),
      )

      t->expect(hasLogError(effects))->Expect.toBe(true)
    })
  })

  describe("Relay Lifecycle", () => {
    test("RelayInstanceCreated stores relay (legacy action)", t => {
      let mockRelay = Obj.magic({"id": "relay-1"})
      let (nextState, effects) = Reducer.reduce(Reducer.initialState, RelayInstanceCreated(mockRelay))

      t->expect(Option.isSome(nextState.relayInstance))->Expect.toBe(true)
      t->expect(effects->Array.length)->Expect.toBe(0)
    })

    test("RelayConnectStart requires relay instance", t => {
      let (nextState, effects) = Reducer.reduce(Reducer.initialState, RelayConnectStart)

      // Should be ignored - no relay instance
      t->expect(nextState.relay)->Expect.toBe(Reducer.RelayDisconnected)
      t->expect(effects->Array.length)->Expect.toBe(0)
    })

    test("RelayConnectSuccess transitions to RelayConnected", t => {
      let state = {...Reducer.initialState, relay: RelayConnecting}
      let (nextState, effects) = Reducer.reduce(state, RelayConnectSuccess)

      t->expect(nextState.relay)->Expect.toBe(Reducer.RelayConnected)
      t->expect(hasLogInfo(effects))->Expect.toBe(true)
    })

    test("RelayConnectError is non-fatal", t => {
      let state = {...Reducer.initialState, relay: RelayConnecting}
      let (nextState, effects) = Reducer.reduce(state, RelayConnectError("Connection refused"))

      switch nextState.relay {
      | Reducer.RelayError(_) => t->expect(true)->Expect.toBe(true)
      | _ => t->expect(false)->Expect.toBe(true)
      }
      // Non-fatal, so LogInfo not LogError
      t->expect(hasLogInfo(effects))->Expect.toBe(true)
    })
  })

  describe("Session Creation", () => {
    test("requires ACP connected to create session", t => {
      let (_, effects) = Reducer.reduce(Reducer.initialState, SessionCreateStart)

      t->expect(hasLogError(effects))->Expect.toBe(true)
    })

    test("requires MCPServer to create session", t => {
      let mockConn = Obj.magic({"socket": null, "channel": null})
      let state = {...Reducer.initialState, acp: ACPConnected(mockConn), relay: RelayConnected}
      let (_, effects) = Reducer.reduce(state, SessionCreateStart)

      t->expect(hasLogError(effects))->Expect.toBe(true)
    })

    test("requires relay ready to create session", t => {
      let mockConn = Obj.magic({"socket": null, "channel": null})
      let mockServer = Obj.magic({"tools": []})
      let state = {
        ...Reducer.initialState,
        acp: ACPConnected(mockConn),
        relay: RelayConnecting, // Still connecting!
        mcpServer: Some(mockServer),
      }
      let (nextState, effects) = Reducer.reduce(state, SessionCreateStart)

      // Should be rejected - relay not ready
      t->expect(nextState.session)->Expect.toBe(Reducer.NoSession)
      t->expect(hasLogError(effects))->Expect.toBe(true)
    })

    test("succeeds when ACP connected, relay connected, and MCPServer ready", t => {
      let mockConn = Obj.magic({"socket": null, "channel": null})
      let mockServer = Obj.magic({"tools": []})
      let state = {
        ...Reducer.initialState,
        acp: ACPConnected(mockConn),
        relay: RelayConnected,
        mcpServer: Some(mockServer),
      }
      let (nextState, _) = Reducer.reduce(state, SessionCreateStart)

      t->expect(nextState.session)->Expect.toBe(Reducer.SessionCreating)
    })

    test("rejects session creation when relay failed", t => {
      let mockConn = Obj.magic({"socket": null, "channel": null})
      let mockServer = Obj.magic({"tools": []})
      let state = {
        ...Reducer.initialState,
        acp: ACPConnected(mockConn),
        relay: RelayError("Connection refused"),
        mcpServer: Some(mockServer),
      }
      let (nextState, effects) = Reducer.reduce(state, SessionCreateStart)

      t->expect(nextState.session)->Expect.toBe(Reducer.NoSession)
      t->expect(hasLogError(effects))->Expect.toBe(true)
    })

    test("SessionCreateSuccess transitions to SessionActive", t => {
      let mockSession = Obj.magic({"sessionId": "sess-1", "channel": null})
      let state = {...Reducer.initialState, session: SessionCreating}
      let (nextState, effects) = Reducer.reduce(state, SessionCreateSuccess(mockSession))

      switch nextState.session {
      | Reducer.SessionActive(_) => t->expect(true)->Expect.toBe(true)
      | _ => t->expect(false)->Expect.toBe(true)
      }
      t->expect(hasLogInfo(effects))->Expect.toBe(true)
    })
  })

  describe("Selectors", () => {
    test("canCreateSession is true when ACP connected, relay connected, and MCPServer ready", t => {
      let mockConn = Obj.magic({"socket": null})
      let mockServer = Obj.magic({"tools": []})
      let state = {
        ...Reducer.initialState,
        acp: ACPConnected(mockConn),
        relay: RelayConnected,
        mcpServer: Some(mockServer),
      }
      t->expect(Reducer.Selectors.canCreateSession(state))->Expect.toBe(true)
    })

    test("canCreateSession is false when relay not connected", t => {
      let mockConn = Obj.magic({"socket": null})
      let mockServer = Obj.magic({"tools": []})
      let state = {
        ...Reducer.initialState,
        acp: ACPConnected(mockConn),
        relay: RelayConnecting,
        mcpServer: Some(mockServer),
      }
      t->expect(Reducer.Selectors.canCreateSession(state))->Expect.toBe(false)
    })

    test("canCreateSession is false when MCPServer not ready", t => {
      let mockConn = Obj.magic({"socket": null})
      let state = {...Reducer.initialState, acp: ACPConnected(mockConn), relay: RelayConnected}
      t->expect(Reducer.Selectors.canCreateSession(state))->Expect.toBe(false)
    })

    test("getConnectionStatus reflects session state", t => {
      let mockSession = Obj.magic({"sessionId": "sess-1"})
      let state = {...Reducer.initialState, session: SessionActive(mockSession)}

      switch Reducer.Selectors.getConnectionStatus(state) {
      | Reducer.Selectors.SessionActive(id) => t->expect(id)->Expect.toBe("sess-1")
      | _ => t->expect("SessionActive")->Expect.toBe("wrong state")
      }
    })

    test("getMCPStatus reflects relay state", t => {
      let state = {...Reducer.initialState, relay: RelayConnected}
      t->expect(Reducer.Selectors.getMCPStatus(state))->Expect.toBe(Reducer.Selectors.MCPReady)
    })
  })

  describe("Connection Lifecycle - Session Creation Trigger", () => {
    // This test documents the critical flow: App.res should create session when
    // connectionStatus becomes Connected (not SessionActive)
    test("getConnectionStatus is Connected when ACP+Relay ready but no session", t => {
      let mockConn = Obj.magic({"socket": null})
      let state = {
        ...Reducer.initialState,
        acp: ACPConnected(mockConn),
        relay: RelayConnected,
        session: NoSession,
      }

      // This is the state where session creation should be triggered
      switch Reducer.Selectors.getConnectionStatus(state) {
      | Reducer.Selectors.Connected => t->expect(true)->Expect.toBe(true)
      | _ => t->expect("Connected")->Expect.toBe("wrong state - should be Connected")
      }
    })

    test("getConnectionStatus is SessionActive only AFTER session exists", t => {
      let mockConn = Obj.magic({"socket": null})
      let mockSession = Obj.magic({"sessionId": "sess-1"})
      let state = {
        ...Reducer.initialState,
        acp: ACPConnected(mockConn),
        relay: RelayConnected,
        session: SessionActive(mockSession),
      }

      switch Reducer.Selectors.getConnectionStatus(state) {
      | Reducer.Selectors.SessionActive(id) => t->expect(id)->Expect.toBe("sess-1")
      | _ => t->expect("SessionActive")->Expect.toBe("wrong state")
      }
    })

    test("CreateSession action works when connectionStatus is Connected", t => {
      let mockConn = Obj.magic({"socket": null})
      let mockServer = Obj.magic({"tools": []})
      let state = {
        ...Reducer.initialState,
        acp: ACPConnected(mockConn),
        relay: RelayConnected,
        mcpServer: Some(mockServer),
        session: NoSession,
      }

      // Verify we're in Connected state (the trigger for session creation)
      switch Reducer.Selectors.getConnectionStatus(state) {
      | Reducer.Selectors.Connected => ()
      | _ => t->expect("setup")->Expect.toBe("should be Connected state")
      }

      // CreateSession should work from this state
      let (nextState, effects) = Reducer.reduce(
        state,
        CreateSession({
          onUpdate: (_, _) => (),
          onTitleUpdated: (_, _) => (),
          onMcpMessage: (_, _) => (),
          onComplete: _ => (),
        }),
      )

      t->expect(nextState.session)->Expect.toBe(Reducer.SessionCreating)
      t
      ->expect(
        hasEffect(effects, e =>
          switch e {
          | Reducer.CreateSessionEffect(_) => true
          | _ => false
          }
        ),
      )
      ->Expect.toBe(true)
    })

    test("full lifecycle: Connecting -> Connected -> SessionActive", t => {
      let mockConn = Obj.magic({"socket": null})
      let mockServer = Obj.magic({"tools": []})
      let mockSession = Obj.magic({"sessionId": "sess-1"})

      // Step 1: Initial state - Disconnected
      let state0 = Reducer.initialState
      switch Reducer.Selectors.getConnectionStatus(state0) {
      | Reducer.Selectors.Disconnected => ()
      | _ => t->expect("step1")->Expect.toBe("should be Disconnected")
      }

      // Step 2: ACP connecting - Connecting
      let state1 = {...state0, acp: ACPConnecting}
      switch Reducer.Selectors.getConnectionStatus(state1) {
      | Reducer.Selectors.Connecting => ()
      | _ => t->expect("step2")->Expect.toBe("should be Connecting")
      }

      // Step 3: ACP connected, relay connected - Connected (trigger for session creation!)
      let state2 = {
        ...state1,
        acp: ACPConnected(mockConn),
        relay: RelayConnected,
        mcpServer: Some(mockServer),
      }
      switch Reducer.Selectors.getConnectionStatus(state2) {
      | Reducer.Selectors.Connected => ()
      | _ => t->expect("step3")->Expect.toBe("should be Connected - THIS IS SESSION CREATE TRIGGER")
      }

      // Step 4: Session active - SessionActive
      let state3 = {...state2, session: SessionActive(mockSession)}
      switch Reducer.Selectors.getConnectionStatus(state3) {
      | Reducer.Selectors.SessionActive(_) => t->expect(true)->Expect.toBe(true)
      | _ => t->expect("step4")->Expect.toBe("should be SessionActive")
      }
    })
  })

  describe("Cleanup", () => {
    test("fully resets state to initial", t => {
      let mockRelay = Obj.magic({"id": "relay-1"})
      let mockServer = Obj.magic({"tools": []})
      let mockSession = Obj.magic({"sessionId": "sess-1"})
      let mockConn = Obj.magic({"socket": null})
      let mockAbortController = WebAPI.AbortController.make()
      let state: Reducer.state = {
        acp: ACPConnected(mockConn),
        relay: RelayConnected,
        session: SessionActive(mockSession),
        isSendingPrompt: false,
        relayInstance: Some(mockRelay),
        mcpServer: Some(mockServer),
        abortController: Some(mockAbortController),
      }

      let (nextState, effects) = Reducer.reduce(state, Cleanup)

      // State fully reset
      t->expect(nextState.acp)->Expect.toBe(Reducer.ACPDisconnected)
      t->expect(nextState.relay)->Expect.toBe(Reducer.RelayDisconnected)
      t->expect(nextState.session)->Expect.toBe(Reducer.NoSession)
      t->expect(nextState.relayInstance)->Expect.toBe(None)
      t->expect(nextState.mcpServer)->Expect.toBe(None)
      t->expect(nextState.abortController)->Expect.toBe(None)

      // Emits abort effect first
      t
      ->expect(
        hasEffect(effects, e =>
          switch e {
          | Reducer.AbortConnections(_) => true
          | _ => false
          }
        ),
      )
      ->Expect.toBe(true)

      // Emits disconnect effects
      t
      ->expect(
        hasEffect(effects, e =>
          switch e {
          | Reducer.DisconnectRelay(_) => true
          | _ => false
          }
        ),
      )
      ->Expect.toBe(true)
      t
      ->expect(
        hasEffect(effects, e =>
          switch e {
          | Reducer.DisconnectACP(_) => true
          | _ => false
          }
        ),
      )
      ->Expect.toBe(true)
    })
  })
})
