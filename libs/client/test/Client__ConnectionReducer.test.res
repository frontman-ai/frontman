open Vitest

module Reducer = Client__ConnectionReducer
module FtueState = Client__FtueState
module ACPClient = FrontmanAiFrontmanClient.FrontmanClient__ACP__Client
module ACPProtocol = FrontmanAiFrontmanClient.FrontmanClient__ACP__Protocol
module ACPTypes = FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP

let mockChannel: FrontmanAiFrontmanClient.FrontmanClient__Phoenix__Channel.t = %raw(`{
  push: function(_event, _payload) {
    return { receive: function() { return this; } };
  },
  on: function() {},
  off: function() {}
}`)

let textPromptJson = text =>
  JSON.Encode.object(
    Dict.fromArray([("type", JSON.Encode.string("text")), ("text", JSON.Encode.string(text))]),
  )

let agentTurnCompleteNotification = (~sessionId) =>
  JSON.Encode.object(
    Dict.fromArray([
      ("jsonrpc", JSON.Encode.string("2.0")),
      ("method", JSON.Encode.string("session/update")),
      (
        "params",
        JSON.Encode.object(
          Dict.fromArray([
            ("sessionId", JSON.Encode.string(sessionId)),
            (
              "update",
              JSON.Encode.object(
                Dict.fromArray([
                  ("sessionUpdate", JSON.Encode.string("agent_turn_complete")),
                  ("stopReason", JSON.Encode.string("end_turn")),
                ]),
              ),
            ),
          ]),
        ),
      ),
    ]),
  )

// Helper to check if effect list contains a specific effect type
let hasEffect = (effects, predicate) => effects->Array.some(predicate)
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
      },
    )

    test(
      "RelayConnectError is non-fatal",
      t => {
        let state = {...Reducer.initialState, relay: RelayConnecting}
        let (nextState, effects) = Reducer.reduce(state, RelayConnectError("Connection refused"))

        switch nextState.relay {
        | Reducer.RelayError(_) => t->expect(true)->Expect.toBe(true)
        | _ => t->expect(false)->Expect.toBe(true)
        }
        // Non-fatal, so LogInfo not LogError
        t->expect(hasLogInfo(effects))->Expect.toBe(true)
      },
    )
  })

  describe("Session Creation", () => {
    test(
      "SessionCreateSuccess transitions to SessionActive",
      t => {
        let mockSession = Obj.magic({"sessionId": "sess-1", "channel": null})
        let state = {...Reducer.initialState, session: SessionCreating}
        let (nextState, effects) = Reducer.reduce(state, SessionCreateSuccess(mockSession))

        switch nextState.session {
        | Reducer.SessionActive(_) => t->expect(true)->Expect.toBe(true)
        | _ => t->expect(false)->Expect.toBe(true)
        }
        t->expect(hasLogInfo(effects))->Expect.toBe(true)
      },
    )
  })

  describe("Prompt Completion", () => {
    testAsync(
      "restart-resumed turn completion releases next prompt",
      async t => {
        let sessionId = "task-1"
        let acpState = ref(ACPClient.initialState)

        let promptResultPromise = ACPProtocol.sendPrompt(
          ~channel=mockChannel,
          ~state=acpState,
          ~sessionId,
          ~prompt=[textPromptJson("first")],
          ~_meta=None,
          ~onMessage=None,
        )

        t->expect(acpState.contents.pendingRequests->Dict.keysToArray->Array.length)->Expect.toBe(1)

        ACPProtocol.handleIncomingMessage(
          ~state=acpState,
          ~onUpdate=Some((_sessionId, _update) => ()),
          ~onMessage=None,
          ~onParseError=None,
          agentTurnCompleteNotification(~sessionId),
        )

        let promptResult = await promptResultPromise
        switch promptResult {
        | Ok({stopReason: EndTurn}) => ()
        | _ => t->expect("prompt result")->Expect.toBe("end_turn")
        }

        let mockSession = Obj.magic({"sessionId": sessionId})
        let inFlightState = {
          ...Reducer.initialState,
          session: SessionActive(mockSession),
          isSendingPrompt: true,
        }

        let (completedState, _) = Reducer.reduce(inFlightState, PromptSent)
        t->expect(completedState.isSendingPrompt)->Expect.toBe(false)

        let emptyBlocks: array<ACPTypes.contentBlock> = []
        let (nextPromptState, effects) = Reducer.reduce(
          completedState,
          SendPrompt({
            text: "second",
            additionalBlocks: emptyBlocks,
            onComplete: _ => (),
            _meta: None,
          }),
        )

        t->expect(nextPromptState.isSendingPrompt)->Expect.toBe(true)
        t
        ->expect(
          hasEffect(
            effects,
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

  describe("Selectors", () => {
    test(
      "getConnectionStatus reflects session state",
      t => {
        let mockSession = Obj.magic({"sessionId": "sess-1"})
        let state = {...Reducer.initialState, session: SessionActive(mockSession)}

        switch Reducer.Selectors.getConnectionStatus(state) {
        | Reducer.Selectors.SessionActive(id) => t->expect(id)->Expect.toBe("sess-1")
        | _ => t->expect("SessionActive")->Expect.toBe("wrong state")
        }
      },
    )
  })

  describe("Connection Lifecycle - Session Creation Trigger", () => {
    // This test documents the critical flow: App.res should create session when
    // connectionStatus becomes Connected (not SessionActive)
    test(
      "getConnectionStatus is Connected when ACP+Relay ready but no session",
      t => {
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
      },
    )

    test(
      "getConnectionStatus is SessionActive only AFTER session exists",
      t => {
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
      },
    )

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
      "full lifecycle: Connecting -> Connected -> SessionActive",
      t => {
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
        | _ =>
          t->expect("step3")->Expect.toBe("should be Connected - THIS IS SESSION CREATE TRIGGER")
        }

        // Step 4: Session active - SessionActive
        let state3 = {...state2, session: SessionActive(mockSession)}
        switch Reducer.Selectors.getConnectionStatus(state3) {
        | Reducer.Selectors.SessionActive(_) => t->expect(true)->Expect.toBe(true)
        | _ => t->expect("step4")->Expect.toBe("should be SessionActive")
        }
      },
    )
  })

  describe("Cleanup", () => {
    test(
      "fully resets state to initial",
      t => {
        let mockRelay = Obj.magic({"id": "relay-1"})
        let mockServer = Obj.magic({"tools": []})
        let mockSession = Obj.magic({"sessionId": "sess-1"})
        let mockConn = Obj.magic({"socket": null})
        let mockAbortController = WebAPI.AbortController.make()
        let state: Reducer.state = {
          acp: ACPConnected(mockConn),
          relay: RelayConnected,
          session: SessionActive(mockSession),
          initialAuthBehavior: FtueState.ShowWelcomeModal,
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
          hasEffect(
            effects,
            e =>
              switch e {
              | Reducer.AbortConnections(_) => true
              | _ => false
              },
          ),
        )
        ->Expect.toBe(true)

        // Emits disconnect effects
        t
        ->expect(
          hasEffect(
            effects,
            e =>
              switch e {
              | Reducer.DisconnectRelay(_) => true
              | _ => false
              },
          ),
        )
        ->Expect.toBe(true)
        t
        ->expect(
          hasEffect(
            effects,
            e =>
              switch e {
              | Reducer.DisconnectACP(_) => true
              | _ => false
              },
          ),
        )
        ->Expect.toBe(true)
      },
    )
  })
})
