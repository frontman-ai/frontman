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
  isSendingPrompt: bool,
  session: option<ACP.session>,
  relay: option<Relay.t>,
  createSession: (Types.sessionUpdate => unit) => unit,
  sendPrompt: (
    string,
    ~additionalBlocks: array<Types.contentBlock>,
    ~onComplete: result<Types.promptResult, string> => unit,
  ) => unit,
}

// Default context value
let defaultContextValue: contextValue = {
  connectionState: Disconnected,
  mcpState: MCPDisconnected,
  isSendingPrompt: false,
  session: None,
  relay: None,
  createSession: _ => (),
  sendPrompt: (_, ~additionalBlocks as _, ~onComplete as _) => (),
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

    let createSession = React.useCallback1(
      (onUpdate: Types.sessionUpdate => unit) => {
        dispatch(CreateSession({onUpdate, onMcpMessage: logMCPMessage}))
      },
      [dispatch],
    )

    let sendPrompt = React.useCallback1(
      (text: string, ~additionalBlocks, ~onComplete) => {
        dispatch(SendPrompt({text, additionalBlocks, onComplete}))
      },
      [dispatch],
    )

    let contextValue: contextValue = {
      connectionState: Reducer.Selectors.getConnectionStatus(state),
      mcpState: Reducer.Selectors.getMCPStatus(state),
      isSendingPrompt: state.isSendingPrompt,
      session: Reducer.Selectors.getSession(state),
      relay: state.relayInstance,
      createSession,
      sendPrompt,
    }

    <ContextProvider value={contextValue}> {children} </ContextProvider>
  }
}
