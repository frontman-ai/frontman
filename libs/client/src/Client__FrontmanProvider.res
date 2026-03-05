// FrontmanProvider - React context provider for FrontmanClient ACP connection
// Uses ConnectionReducer for centralized state management

module Log = FrontmanLogs.Logs.Make({
  let component = #FrontmanProvider
})

module ACP = FrontmanAiFrontmanClient.FrontmanClient__ACP
module Types = FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP
module Relay = FrontmanAiFrontmanClient.FrontmanClient__Relay
module MCPServer = FrontmanAiFrontmanClient.FrontmanClient__MCP__Server
module Reducer = Client__ConnectionReducer
module RuntimeConfig = Client__RuntimeConfig

// Create the text delta buffer instance and register it as active.
// The onFlush callback breaks the circular dep: TextDeltaBuffer doesn't import Client__State.
let textDeltaBuffer = Client__TextDeltaBuffer.make(~onFlush=(~taskId, ~text) => {
  Client__State.Actions.textDeltaReceived(~taskId, ~text)
})
let () = Client__TextDeltaBuffer.active := Some(textDeltaBuffer)

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
  authRedirectUrl: option<string>,
  createSession: (~onComplete: result<string, string> => unit) => unit,
  clearSession: unit => unit,
  sendPrompt: (
    string,
    ~additionalBlocks: array<Types.contentBlock>,
    ~onComplete: result<Types.promptResult, string> => unit,
    ~metadata: option<JSON.t>,
  ) => unit,
  cancelPrompt: unit => unit,
  loadTask: (string, ~needsHistory: bool, ~onComplete: result<unit, string> => unit) => unit,
  deleteSession: (string, ~onComplete: result<unit, string> => unit) => unit,
}

// Default context value
let defaultContextValue: contextValue = {
  connectionState: Disconnected,
  mcpState: MCPDisconnected,
  isSendingPrompt: false,
  session: None,
  relay: None,
  authRedirectUrl: None,
  createSession: (~onComplete as _) => (),
  clearSession: () => (),
  sendPrompt: (_, ~additionalBlocks as _, ~onComplete as _, ~metadata as _) => (),
  cancelPrompt: () => (),
  loadTask: (_, ~needsHistory as _, ~onComplete as _) => (),
  deleteSession: (_, ~onComplete as _) => (),
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
    ~tokenUrl: string,
    ~loginUrl: string,
    ~clientName: string="frontman-client",
    ~clientVersion: string="1.0.0",
    ~children: React.element,
  ) => {
    // Log message handlers
    let logACPMessage = React.useCallback0((direction: ACP.messageDirection, payload: JSON.t) => {
      let arrow = direction == Send ? `→` : `←`
      Log.debug(~ctx={"payload": payload}, `ACP ${arrow}`)
    })

    let logMCPMessage = React.useCallback0((direction, payload) => {
      let arrow = direction == FrontmanAiFrontmanClient.FrontmanClient__MCP.Send ? `→` : `←`
      Log.debug(~ctx={"payload": payload}, `MCP ${arrow}`)
    })

    // Use StateReducer - effects are executed in useEffect, not during dispatch
    let (state, dispatch) = StateReducer.useReducer(module(Reducer), Reducer.initialState)

    // Single initialization effect
    React.useEffect0(() => {
      let location = WebAPI.Global.location
      let baseUrl = `${location.protocol}//${location.host}`

      // Read runtime config from window.__frontmanRuntime (injected by framework middleware)
      let runtimeConfig = RuntimeConfig.read()
      let metadata = RuntimeConfig.toMetadata(runtimeConfig)

      let relay = Relay.make(~baseUrl)
      let toolRegistry = Client__ToolRegistry.coreBrowserTools()
      let mcpServer = MCPServer.make(~relay, ~serverName=clientName, ~serverVersion=clientVersion)
      let mcpServer = Client__ToolRegistry.registerAll(toolRegistry, mcpServer)

      // Wire up image ref resolver so write_file can save user-attached images.
      MCPServer.setImageRefResolver(mcpServer, (uri, ~taskId) => {
        let state = StateStore.getState(Client__State__Store.store)
        Client__State.Selectors.resolveImageRef(state, ~taskId, ~uri)
        ->Option.map(({base64, mediaType}) => {MCPServer.base64, mediaType})
      })

      let config: Reducer.initConfig = {
        endpoint,
        tokenUrl,
        loginUrl,
        clientName,
        clientVersion,
        baseUrl,
        onACPMessage: logACPMessage,
        metadata,
        onTitleUpdated: Some((taskId, title) => {
          Client__State.Actions.updateTaskTitle(~taskId, ~title)
        }),
      }

      dispatch(Initialize({config, relay, mcpServer}))

      Some(() => {
        textDeltaBuffer.reset()
        dispatch(Cleanup)
      })
    })

    let handleSessionUpdate = React.useCallback0((sessionId: string, update: Types.sessionUpdate) => {
      let taskId = sessionId
      switch update {
      | AgentMessageChunk({content}) =>
        // Per ACP spec: first agent_message_chunk implicitly signals message start.
        // Message end is signaled by session/prompt response with stopReason.
        // Buffer text deltas and flush once per animation frame to avoid
        // dozens of full state rebuilds per second during fast streaming.
        content->Option.flatMap(c => c.text)->Option.forEach(text => {
          textDeltaBuffer.add(~taskId, ~text)
        })
      | UserMessageChunk({content, timestamp}) =>
        content.text->Option.forEach(text => {
          let id = `user-hydrated-${WebAPI.Global.crypto->WebAPI.Crypto.randomUUID}`
          Client__State.Actions.userMessageReceived(~taskId, ~id, ~text, ~timestamp)
        })
      | ToolCall({toolCallId, title, parentAgentId, spawningToolName}) =>
        Client__State.Actions.toolCallReceived(~taskId, ~toolCall={
          id: toolCallId,
          toolName: title->Option.getOr("unknown_tool"),
          inputBuffer: "",
          input: None,
          result: None,
          errorText: None,
          state: Client__State__Types.Message.InputStreaming,
          createdAt: Date.now(),
          parentAgentId,
          spawningToolName,
        })
      | ToolCallUpdate({toolCallId, status, content}) =>
        let text = content->Option.flatMap(c => c->Array.get(0))->Option.flatMap(i => i.content)->Option.flatMap(c => c.text)
        switch status {
        | Some("pending") =>
          text->Option.flatMap(t => try { Some(JSON.parseOrThrow(t)) } catch { | _ => None })->Option.forEach(input => {
            Client__State.Actions.toolInputReceived(~taskId, ~id=toolCallId, ~input)
          })
        | Some("completed") =>
          let result = text->Option.mapOr(JSON.Encode.null, t =>
            try { JSON.parseOrThrow(t) } catch { | _ => JSON.Encode.string(t) }
          )
          Client__State.Actions.toolResultReceived(~taskId, ~id=toolCallId, ~result)
        | Some("failed") =>
          Client__State.Actions.toolErrorReceived(~taskId, ~id=toolCallId, ~error=text->Option.getOr("Unknown error"))
        | Some("in_progress") => () // Normal transitional status for MCP tools
        | Some(status) =>
          Log.warning(~ctx={"status": status, "toolCallId": toolCallId}, "Unhandled tool call status received")
        | None => ()
        }
      | Plan({entries}) =>
        Client__State.Actions.planReceived(~taskId, ~entries)
      | Error({message}) =>
        Client__State.Actions.agentErrorReceived(~taskId, ~error=message)
      | Unknown(_) => ()
      }
    })

    let createSession = React.useCallback1(
      (~onComplete: result<string, string> => unit) => {
        dispatch(CreateSession({onUpdate: handleSessionUpdate, onMcpMessage: logMCPMessage, onComplete}))
      },
      [dispatch],
    )

    let clearSession = React.useCallback1(() => dispatch(ClearSession), [dispatch])

    let sendPrompt = React.useCallback1(
      (text: string, ~additionalBlocks, ~onComplete, ~metadata) => {
        dispatch(SendPrompt({text, additionalBlocks, onComplete, metadata}))
      },
      [dispatch],
    )

    let cancelPrompt = React.useCallback1(() => {
      dispatch(CancelPrompt)
    }, [dispatch])

    let loadTask = React.useCallback1(
      (taskId: string, ~needsHistory, ~onComplete) => {
        dispatch(LoadTask({taskId, needsHistory, onUpdate: handleSessionUpdate, onMcpMessage: logMCPMessage, onComplete}))
      },
      [dispatch],
    )

    let deleteSession = React.useCallback1(
      (taskId: string, ~onComplete) => {
        dispatch(DeleteSession({taskId, onComplete}))
      },
      [dispatch],
    )

    // Extract auth redirect URL from ACP error state (encoded as "auth_required:<url>")
    let authRedirectUrl = switch state.acp {
    | Reducer.ACPError(msg) =>
      switch String.startsWith(msg, "auth_required:") {
      | true => Some(String.slice(msg, ~start=14, ~end=String.length(msg)))
      | false => None
      }
    | _ => None
    }

    let contextValue: contextValue = {
      connectionState: Reducer.Selectors.getConnectionStatus(state),
      mcpState: Reducer.Selectors.getMCPStatus(state),
      isSendingPrompt: state.isSendingPrompt,
      session: Reducer.Selectors.getSession(state),
      relay: state.relayInstance,
      authRedirectUrl,
      createSession,
      clearSession,
      sendPrompt,
      cancelPrompt,
      loadTask,
      deleteSession,
    }

    <ContextProvider value={contextValue}> {children} </ContextProvider>
  }
}
