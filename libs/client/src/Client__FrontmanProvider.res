// FrontmanProvider - React context provider for FrontmanClient ACP connection
// Uses ConnectionReducer for centralized state management

module ACP = FrontmanFrontmanClient.FrontmanClient__ACP
module Types = FrontmanFrontmanClient.FrontmanClient__ACP__Types
module Relay = FrontmanFrontmanClient.FrontmanClient__Relay
module MCPServer = FrontmanFrontmanClient.FrontmanClient__MCP__Server
module ConsoleLogTool = FrontmanFrontmanClient.FrontmanClient__MCP__Tool__ConsoleLog
module Reducer = Client__ConnectionReducer
module StateReducer = FrontmanReactStatestore.StateReducer

// Re-export status types for consumers
type connectionState = Reducer.Selectors.connectionStatus
type mcpState = Reducer.Selectors.mcpStatus

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
    // Log message handlers
    let logACPMessage = React.useCallback0((direction: ACP.messageDirection, payload: JSON.t) => {
      let arrow = direction == Send ? `→` : `←`
      Console.log2(`[ACP] ${arrow}`, payload)
    })

    let logMCPMessage = React.useCallback0((direction, payload) => {
      let arrow = direction == FrontmanFrontmanClient.FrontmanClient__MCP.Send ? `→` : `←`
      Console.log2(`[MCP] ${arrow}`, payload)
    })

    // Use StateReducer - effects are executed in useEffect, not during dispatch
    let (state, dispatch) = StateReducer.useReducer(module(Reducer), Reducer.initialState)

    // Single initialization effect
    React.useEffect0(() => {
      let location = WebAPI.Global.location
      let baseUrl = `${location.protocol}//${location.host}`

      let relay = Relay.make(~baseUrl)
      let mcpServer =
        MCPServer.make(~relay, ~serverName=clientName, ~serverVersion=clientVersion)
        ->MCPServer.registerToolModule(module(ConsoleLogTool))
        ->MCPServer.registerToolModule(module(Client__Tool__GetFigmaNode))
        ->MCPServer.registerToolModule(module(Client__Tool__TakeScreenshot))
        ->MCPServer.registerToolModule(module(Client__Tool__Navigate))
        ->MCPServer.registerToolModule(module(Client__Tool__NavigateBack))

      let config: Reducer.initConfig = {
        endpoint,
        clientName,
        clientVersion,
        baseUrl,
        onACPMessage: logACPMessage,
      }

      dispatch(Initialize({config, relay, mcpServer}))

      Some(() => dispatch(Cleanup))
    })

    // Create session function
    let createSession = React.useCallback2(
      async (onUpdate: Types.sessionUpdate => unit): result<ACP.session, string> => {
        if !Reducer.Selectors.canCreateSession(state) {
          Error("Not ready to create session")
        } else {
          switch (Reducer.Selectors.getACPConnection(state), Reducer.Selectors.getMCPServer(state)) {
          | (Some(conn), Some(mcpServer)) =>
            dispatch(SessionCreateStart)
            // Pass MCPServer interface so handler is attached BEFORE channel join
            let mcpServerInterface = MCPServer.toInterface(mcpServer)
            let result = await ACP.createSession(
              conn,
              ~onUpdate,
              ~mcpServerInterface,
              ~onMcpMessage=logMCPMessage,
            )
            switch result {
            | Ok(sess) =>
              dispatch(SessionCreateSuccess(sess))
              Console.log2("[FrontmanProvider] Session created:", sess.sessionId)
              Ok(sess)
            | Error(err) =>
              dispatch(SessionCreateError(err))
              Console.error2("[FrontmanProvider] Failed to create session:", err)
              Error(err)
            }
          | _ => Error("Connection or MCPServer not available")
          }
        }
      },
      (state, logMCPMessage),
    )

    // Send prompt function
    let sendPrompt = React.useCallback1(
      async (text: string, ~additionalBlocks: array<Types.contentBlock>): result<
        Types.promptResult,
        string,
      > => {
        switch Reducer.Selectors.getSession(state) {
        | None => Error("No active session")
        | Some(sess) => await ACP.sendPrompt(sess, text, ~additionalBlocks)
        }
      },
      [state],
    )

    let contextValue: contextValue = {
      connectionState: Reducer.Selectors.getConnectionStatus(state),
      mcpState: Reducer.Selectors.getMCPStatus(state),
      session: Reducer.Selectors.getSession(state),
      relay: state.relayInstance,
      createSession,
      sendPrompt,
    }

    <ContextProvider value={contextValue}> {children} </ContextProvider>
  }
}
