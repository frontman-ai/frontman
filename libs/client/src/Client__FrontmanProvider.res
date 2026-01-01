// FrontmanProvider - React context provider for FrontmanClient ACP connection
// Uses explicit state machine for initialization handshake

module ACP = FrontmanFrontmanClient.FrontmanClient__ACP
module Types = FrontmanFrontmanClient.FrontmanClient__ACP__Types
module Relay = FrontmanFrontmanClient.FrontmanClient__Relay
module MCP = FrontmanFrontmanClient.FrontmanClient__MCP
module MCPServer = FrontmanFrontmanClient.FrontmanClient__MCP__Server
module ConsoleLogTool = FrontmanFrontmanClient.FrontmanClient__MCP__Tool__ConsoleLog
module Channel = FrontmanFrontmanClient.FrontmanClient__Phoenix__Channel

// Explicit state machine for the initialization handshake
// Each state represents a clear step in the connection process
type providerState =
  | Disconnected // Initial state
  | ConnectingACP // Step 1: Connecting socket and initializing ACP protocol
  | ConnectingRelay // Step 2: ACP ready, now connecting to relay for MCP tools
  | Ready(ACP.connection, Relay.t) // Step 3: Both ready, can create sessions
  | CreatingSession // Step 4: Session creation in progress
  | SessionActive({sessionId: string, session: ACP.session}) // Step 5: Session active
  | Error(string) // Error state

// Helper to get a display name for logging
let stateToString = state =>
  switch state {
  | Disconnected => "Disconnected"
  | ConnectingACP => "ConnectingACP"
  | ConnectingRelay => "ConnectingRelay"
  | Ready(_, _) => "Ready"
  | CreatingSession => "CreatingSession"
  | SessionActive({sessionId}) => `SessionActive(${sessionId})`
  | Error(msg) => `Error(${msg})`
  }

// Context value type - simplified, derived from state
type contextValue = {
  state: providerState,
  isReady: bool,
  isSessionActive: bool,
  sessionId: option<string>,
  createSession: (Types.sessionUpdate => unit) => promise<result<ACP.session, string>>,
  sendPrompt: (
    string,
    ~additionalBlocks: array<Types.contentBlock>,
  ) => promise<result<Types.promptResult, string>>,
}

// Default context value
let defaultContextValue: contextValue = {
  state: Disconnected,
  isReady: false,
  isSessionActive: false,
  sessionId: None,
  createSession: async (_): result<ACP.session, string> => Error("Not initialized"),
  sendPrompt: async (_, ~additionalBlocks as _): result<Types.promptResult, string> => Error(
    "No active session",
  ),
}

// Create the React context
let context = React.createContext(defaultContextValue)

// Make the context provider component
module ContextProvider = {
  let make = React.Context.provider(context)
}

// Custom hook to use the Frontman context
let useFrontman = () => React.useContext(context)

// Provider component
module Provider = {
  @react.component
  let make = (
    ~endpoint: string,
    ~clientName: string="frontman-client",
    ~clientVersion: string="1.0.0",
    ~children: React.element,
  ) => {
    let (state, setState) = React.useState(() => Disconnected)
    let mcpHandlerRef = React.useRef((None: option<MCP.mcpHandler<MCPServer.t>>))

    // Get base URL from current location for relay
    let getBaseUrl = React.useCallback(() => {
      let location = WebAPI.Global.location
      `${location.protocol}//${location.host}`
    }, [])

    // Log message handler for debugging
    let logMessage = React.useCallback((direction: ACP.messageDirection, payload: JSON.t) => {
      let arrow = direction == Send ? `→` : `←`
      Console.log2(`[ACP] ${arrow}`, payload)
    }, [])

    // Log MCP messages
    let logMCPMessage = React.useCallback((direction: MCP.messageDirection, payload: JSON.t) => {
      let arrow = direction == Send ? `→` : `←`
      Console.log2(`[MCP] ${arrow}`, payload)
    }, [])

    // Log state transitions
    let transitionTo = React.useCallback((newState: providerState) => {
      Console.log(`[FrontmanProvider] State: ${stateToString(newState)}`)
      setState(_ => newState)
    }, [])

    // Sequential initialization effect
    React.useEffect(() => {
      let cancelled = ref(false)

      let initialize = async () => {
        // Step 1: Connect ACP
        transitionTo(ConnectingACP)
        Console.log("[FrontmanProvider] Step 1/3: Connecting to ACP...")

        let config = ACP.makeConfig(
          ~endpoint,
          ~name=clientName,
          ~version=clientVersion,
          ~onMessage=logMessage,
        )

        let acpResult = await ACP.connect(config)

        if !cancelled.contents {
          switch acpResult {
          | Error(err) =>
            Console.error2("[FrontmanProvider] ACP connection failed:", err)
            transitionTo(Error(`ACP connection failed: ${err}`))

          | Ok(conn) =>
            Console.log("[FrontmanProvider] Step 1/3: ACP connected ✓")

            // Step 2: Connect Relay
            transitionTo(ConnectingRelay)
            Console.log("[FrontmanProvider] Step 2/3: Connecting to relay...")

            let relayInstance = Relay.make(~baseUrl=getBaseUrl())
            let relayResult = await Relay.connect(relayInstance)

            if !cancelled.contents {
              switch relayResult {
              | Error(err) =>
                // Relay failure is non-fatal - proceed with limited functionality
                Console.warn2("[FrontmanProvider] Relay connection failed (continuing anyway):", err)
                Console.log("[FrontmanProvider] Step 2/3: Relay skipped (tools may be limited)")
                transitionTo(Ready(conn, relayInstance))

              | Ok() =>
                Console.log("[FrontmanProvider] Step 2/3: Relay connected ✓")

                // Log available tools
                switch Relay.getState(relayInstance) {
                | Connected({tools, serverInfo}) =>
                  Console.log3(
                    `[FrontmanProvider] ${serverInfo.name} v${serverInfo.version} - ${tools
                      ->Array.length
                      ->Int.toString} relay tools available`,
                    tools->Array.map(t => t.name),
                    (),
                  )
                | _ => ()
                }

                // Step 3: Ready!
                Console.log("[FrontmanProvider] Step 3/3: Initialization complete ✓")
                transitionTo(Ready(conn, relayInstance))
              }
            }
          }
        }
      }

      initialize()->ignore

      // Cleanup on unmount
      Some(
        () => {
          cancelled := true
          Console.log("[FrontmanProvider] Cleaning up...")

          // Detach MCP handler
          mcpHandlerRef.current->Option.forEach(handler => {
            MCP.detach(handler)
          })
          mcpHandlerRef.current = None
        },
      )
    }, (endpoint, clientName, clientVersion, logMessage, getBaseUrl, transitionTo))

    // Create session function
    let createSession = React.useCallback(
      async (onUpdate: Types.sessionUpdate => unit): result<ACP.session, string> => {
        switch state {
        | Ready(conn, relayInstance) =>
          Console.log("[FrontmanProvider] Creating session...")
          setState(_ => CreatingSession)

          // Build MCP setup callback - runs BEFORE channel join
          let onBeforeJoin = (channel: Channel.t) => {
            Console.log("[FrontmanProvider] Attaching MCP handler before channel join...")
            let mcpServer =
              MCPServer.make(
                ~relay=relayInstance,
                ~serverName=clientName,
                ~serverVersion=clientVersion,
              )
              ->MCPServer.registerToolModule(module(ConsoleLogTool))
              ->MCPServer.registerToolModule(module(Client__Tool__GetFigmaNode))
              ->MCPServer.registerToolModule(module(Client__Tool__TakeScreenshot))
              ->MCPServer.registerToolModule(module(Client__Tool__Navigate))
              ->MCPServer.registerToolModule(module(Client__Tool__NavigateBack))
            let handler = MCP.attach(
              ~channel,
              ~serverInterface=MCPServer.toInterface(mcpServer),
              ~onMessage=logMCPMessage,
            )
            mcpHandlerRef.current = Some(handler)
            Console.log("[FrontmanProvider] MCP handler attached ✓")
          }

          let result = await ACP.createSession(conn, ~onUpdate, ~onBeforeJoin)

          switch result {
          | Ok(sess) =>
            Console.log2("[FrontmanProvider] Session created:", sess.sessionId)
            setState(_ => SessionActive({sessionId: sess.sessionId, session: sess}))
            Ok(sess)
          | Error(err) =>
            Console.error2("[FrontmanProvider] Session creation failed:", err)
            // Revert to Ready state on failure
            setState(_ => Ready(conn, relayInstance))
            Error(err)
          }

        | Disconnected => Error("Not initialized - still disconnected")
        | ConnectingACP => Error("Not ready - ACP connection in progress")
        | ConnectingRelay => Error("Not ready - relay connection in progress")
        | CreatingSession => Error("Session creation already in progress")
        | SessionActive(_) => Error("Session already active")
        | Error(msg) => Error(`Initialization failed: ${msg}`)
        }
      },
      (state, clientName, clientVersion, logMCPMessage),
    )

    // Send prompt function
    let sendPrompt = React.useCallback(
      async (text: string, ~additionalBlocks: array<Types.contentBlock>): result<
        Types.promptResult,
        string,
      > => {
        switch state {
        | SessionActive({session}) => await ACP.sendPrompt(session, text, ~additionalBlocks)
        | _ => Error("No active session")
        }
      },
      [state],
    )

    // Derive helper values from state
    let isReady = switch state {
    | Ready(_, _) => true
    | _ => false
    }

    let isSessionActive = switch state {
    | SessionActive(_) => true
    | _ => false
    }

    let sessionId = switch state {
    | SessionActive({sessionId}) => Some(sessionId)
    | _ => None
    }

    let contextValue: contextValue = {
      state,
      isReady,
      isSessionActive,
      sessionId,
      createSession,
      sendPrompt,
    }

    <ContextProvider value={contextValue}> {children} </ContextProvider>
  }
}
