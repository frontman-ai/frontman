// FrontmanProvider - React context provider for FrontmanClient ACP connection
// Now with MCP support for browser-as-server tool execution

module ACP = AskTheLlmFrontmanClient.FrontmanClient__ACP
module Types = AskTheLlmFrontmanClient.FrontmanClient__ACP__Types
module Relay = AskTheLlmFrontmanClient.FrontmanClient__Relay
module MCP = AskTheLlmFrontmanClient.FrontmanClient__MCP
module MCPServer = AskTheLlmFrontmanClient.FrontmanClient__MCP__Server
module ConsoleLogTool = AskTheLlmFrontmanClient.FrontmanClient__MCP__Tool__ConsoleLog

// Connection state type for the context
type connectionState =
  | Disconnected
  | Connecting
  | Connected
  | SessionActive(string) // sessionId
  | Error(string)

// MCP state
type mcpState =
  | MCPDisconnected
  | MCPConnecting
  | MCPReady
  | MCPError(string)

// Context value type
type contextValue = {
  connectionState: connectionState,
  mcpState: mcpState,
  session: option<ACP.session>,
  relay: option<Relay.t>,
  createSession: (Types.sessionUpdate => unit) => promise<result<ACP.session, string>>,
  sendPrompt: (
    string,
    ~additionalBlocks: array<Types.contentBlock>,
  ) => promise<result<Types.promptResult, string>>,
}

// Default context value
let defaultContextValue: contextValue = {
  connectionState: Disconnected,
  mcpState: MCPDisconnected,
  session: None,
  relay: None,
  createSession: async (_): result<ACP.session, string> => Error("Not connected"),
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
    let (connectionState, setConnectionState) = React.useState(() => Disconnected)
    let (mcpState, setMCPState) = React.useState(() => MCPDisconnected)
    let (connection, setConnection) = React.useState((): option<ACP.connection> => None)
    let (session, setSession) = React.useState((): option<ACP.session> => None)
    let (relay, setRelay) = React.useState((): option<Relay.t> => None)
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

    // Connect to relay on mount
    React.useEffect(() => {
      setMCPState(_ => MCPConnecting)
      Console.log("[FrontmanProvider] Connecting to relay...")

      let relayInstance = Relay.make(~baseUrl=getBaseUrl())

      let connectRelay = async () => {
        let result = await Relay.connect(relayInstance)

        switch result {
        | Ok() =>
          Console.log("[FrontmanProvider] Relay connected")
          setRelay(_ => Some(relayInstance))
          setMCPState(_ => MCPReady)

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
        | Error(err) =>
          // Relay connection is optional - log warning but don't fail
          Console.warn2("[FrontmanProvider] Relay connection failed (tools may be limited):", err)
          setRelay(_ => Some(relayInstance)) // Still set relay so MCP server can use client tools
          setMCPState(_ => MCPReady) // Mark as ready even without relay - client tools still work
        }
      }

      connectRelay()->ignore

      Some(
        () => {
          Relay.disconnect(relayInstance)
        },
      )
    }, (getBaseUrl, setMCPState, setRelay))

    // Create session function - accepts the update handler from consumer
    let createSession = React.useCallback(
      async (onUpdate: Types.sessionUpdate => unit): result<ACP.session, string> => {
        switch connection {
        | None => Error("Not connected to server")
        | Some(conn) =>
          let result = await ACP.createSession(conn, ~onUpdate)

          switch result {
          | Ok(sess) =>
            setSession(_ => Some(sess))
            setConnectionState(_ => SessionActive(sess.sessionId))
            Console.log2("[FrontmanProvider] Session created:", sess.sessionId)

            // Attach MCP handler to session channel if relay is ready
            switch relay {
            | Some(relayInstance) =>
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
                ~channel=sess.channel,
                ~serverInterface=MCPServer.toInterface(mcpServer),
                ~onMessage=logMCPMessage,
              )
              mcpHandlerRef.current = Some(handler)
              Console.log("[FrontmanProvider] MCP handler attached to session")
            | None => Console.warn("[FrontmanProvider] Relay not ready, MCP handler not attached")
            }

            Ok(sess)
          | Error(err) =>
            Console.error2("[FrontmanProvider] Failed to create session:", err)
            Error(err)
          }
        }
      },
      (connection, relay, clientName, clientVersion, logMCPMessage, setSession, setConnectionState),
    )

    // Send prompt function with additional content blocks
    let sendPrompt = React.useCallback(
      async (text: string, ~additionalBlocks: array<Types.contentBlock>): result<
        Types.promptResult,
        string,
      > => {
        switch session {
        | None => Error("No active session")
        | Some(sess) => await ACP.sendPrompt(sess, text, ~additionalBlocks)
        }
      },
      [session],
    )

    // Connect to ACP on mount
    React.useEffect(() => {
      setConnectionState(_ => Connecting)
      Console.log("[FrontmanProvider] Connecting to ACP...")

      let config = ACP.makeConfig(
        ~endpoint,
        ~name=clientName,
        ~version=clientVersion,
        ~onMessage=logMessage,
      )

      let connectAsync = async () => {
        let result = await ACP.connect(config)

        switch result {
        | Ok(conn) =>
          Console.log("[FrontmanProvider] ACP connected and initialized")
          setConnection(_ => Some(conn))
          setConnectionState(_ => Connected)
        | Error(err) =>
          Console.error2("[FrontmanProvider] ACP connection failed:", err)
          setConnectionState(_ => Error(err))
        }
      }

      connectAsync()->ignore

      // Cleanup on unmount
      Some(
        () => {
          Console.log("[FrontmanProvider] Cleaning up...")

          // Detach MCP handler
          mcpHandlerRef.current->Option.forEach(handler => {
            MCP.detach(handler)
          })
          mcpHandlerRef.current = None

          setConnection(_ => None)
          setSession(_ => None)
        },
      )
    }, (
      endpoint,
      clientName,
      clientVersion,
      logMessage,
      setConnection,
      setConnectionState,
      setSession,
    ))

    let contextValue: contextValue = {
      connectionState,
      mcpState,
      session,
      relay,
      createSession,
      sendPrompt,
    }

    <ContextProvider value={contextValue}> {children} </ContextProvider>
  }
}
