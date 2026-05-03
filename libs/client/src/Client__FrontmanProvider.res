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
let textDeltaBuffer = Client__TextDeltaBuffer.make(~onFlush=(~taskId, ~text, ~timestamp) => {
  Client__State.Actions.textDeltaReceived(~taskId, ~text, ~timestamp)
})
let () = Client__TextDeltaBuffer.active := Some(textDeltaBuffer)

// Extract text from a contentBlock (returns Some for TextContent, None for other variants)
let getContentBlockText = (block: Types.contentBlock): option<string> =>
  switch block {
  | TextContent({text}) => Some(text)
  | ImageContent(_) | AudioContent(_) | ResourceLink(_) | EmbeddedResource(_) => None
  }

// Parse accumulated user_message_chunk content blocks into (content, annotations).
// Inverse of messageAnnotationsToContentBlocks + buildAttachmentContentBlocks on the send path.
let _parseUserMessageBlocks = (blocks: array<Types.contentBlock>): (
  array<Client__Message.UserContentPart.t>,
  array<Client__Message.MessageAnnotation.t>,
) => {
  // First pass: collect screenshot data URLs keyed by annotation_id
  let screenshotMap = Dict.make()
  blocks->Array.forEach(block =>
    switch block {
    | EmbeddedResource({
        resource: {_meta: Some(meta), resource: BlobResourceContents({blob, mimeType})},
      })
      if meta->JSON.Decode.object->Option.flatMap(d => d->Dict.get("annotation_screenshot")) !=
        None =>
      let parsed = S.parseOrThrow(meta, Client__Task__Types.screenshotMetaSchema)
      if parsed.annotationScreenshot {
        screenshotMap->Dict.set(
          parsed.annotationId,
          `data:${mimeType->Option.getOrThrow};base64,${blob}`,
        )
      }
    | _ => ()
    }
  )

  // Second pass: build content parts and annotations
  let content = []
  let annotations = []
  blocks->Array.forEach(block =>
    switch block {
    | TextContent({text}) =>
      content->Array.push(Client__Message.UserContentPart.Text({text: text}))->ignore
    | EmbeddedResource({resource: {_meta: Some(meta), resource: TextResourceContents(_)}})
      if meta->JSON.Decode.object->Option.flatMap(d => d->Dict.get("annotation")) != None =>
      let parsed = S.parseOrThrow(meta, Client__Task__Types.annotationMetaSchema)
      if parsed.annotation {
        let screenshot = screenshotMap->Dict.get(parsed.annotationId)
        annotations
        ->Array.push(Client__Task__Types.annotationMetaToMessageAnnotation(parsed, ~screenshot))
        ->ignore
      }
    | EmbeddedResource({
        resource: {_meta: Some(meta), resource: BlobResourceContents({blob, mimeType})},
      }) =>
      // User images (screenshots already handled in first pass)
      switch meta->JSON.Decode.object {
      | Some(d) if d->Dict.get("user_image") == Some(JSON.Encode.bool(true)) =>
        let filename =
          d->Dict.get("filename")->Option.flatMap(JSON.Decode.string)->Option.getOrThrow
        let mime = mimeType->Option.getOrThrow
        content
        ->Array.push(
          Client__Message.UserContentPart.Image({
            id: None,
            image: `data:${mime};base64,${blob}`,
            mediaType: Some(mime),
            name: Some(filename),
          }),
        )
        ->ignore
      | _ => ()
      }
    | _ => ()
    }
  )
  (content, annotations)
}

// Buffer for accumulating user_message_chunk content blocks during history replay.
// A single user message may span multiple notifications (text, annotations, images).
// The buffer is flushed at turn boundaries (agent message, tool call, turn complete, load complete).
type _userMsgBufferState = {
  mutable taskId: string,
  mutable id: string,
  mutable timestamp: string,
  mutable blocks: array<Types.contentBlock>,
  mutable pending: bool,
}

let _userMsgBuffer: _userMsgBufferState = {
  taskId: "",
  id: "",
  timestamp: "",
  blocks: [],
  pending: false,
}

let _flushUserMessageBuffer = () => {
  if _userMsgBuffer.pending {
    let {taskId, id, timestamp, blocks} = _userMsgBuffer
    _userMsgBuffer.pending = false
    _userMsgBuffer.blocks = []
    let (content, annotations) = _parseUserMessageBlocks(blocks)
    Client__State.Actions.userMessageReceived(~taskId, ~id, ~content, ~annotations, ~timestamp)
  }
}

// Register the user message buffer flush callback (used by StateReducer before LoadComplete)
let () = Client__TextDeltaBuffer.flushUserMessageBuffer := _flushUserMessageBuffer

// Re-export status types for consumers
type connectionState = Reducer.Selectors.connectionStatus

// Context value type
type contextValue = {
  connectionState: connectionState,
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
    ~_meta: option<JSON.t>,
  ) => unit,
  cancelPrompt: unit => unit,
  retryTurn: string => unit,
  loadTask: (string, ~needsHistory: bool, ~onComplete: result<unit, string> => unit) => unit,
  deleteSession: (string, ~onComplete: result<unit, string> => unit) => unit,
}

// Default context value
let defaultContextValue: contextValue = {
  connectionState: Disconnected,
  isSendingPrompt: false,
  session: None,
  relay: None,
  authRedirectUrl: None,
  createSession: (~onComplete as _) => (),
  clearSession: () => (),
  sendPrompt: (_, ~additionalBlocks as _, ~onComplete as _, ~_meta as _) => (),
  cancelPrompt: () => (),
  retryTurn: _ => (),
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
    let initialConnectionState = {
      ...Reducer.initialState,
      initialAuthBehavior: Client__FtueState.getAuthBehavior(),
    }
    let (state, dispatch) = StateReducer.useReducer(module(Reducer), initialConnectionState)

    // Single initialization effect
    React.useEffect0(() => {
      let baseUrl = Client__RelayBaseUrl.current()

      // Read runtime config from window.__frontmanRuntime (injected by framework middleware)
      let runtimeConfig = RuntimeConfig.read()
      let _meta = RuntimeConfig.toMeta(runtimeConfig)
      let relayHeaders = Dict.make()
      runtimeConfig.wpNonce->Option.forEach(nonce => relayHeaders->Dict.set("X-WP-Nonce", nonce))

      let relay = Relay.make(~baseUrl, ~requestHeaders=relayHeaders)
      let toolRegistry = Client__ToolRegistry.forFramework(runtimeConfig.framework)
      let mcpServer = MCPServer.make(~relay, ~serverName=clientName, ~serverVersion=clientVersion)
      let mcpServer = Client__ToolRegistry.registerAll(toolRegistry, mcpServer)

      // Wire up tool result metadata so the server can resume agent execution
      // with the correct provider context (env API keys + model) after a restart.
      MCPServer.setToolResultMetaProvider(mcpServer, () => {
        let config = Client__RuntimeConfig.read()
        let envApiKey = Client__RuntimeConfig.toEnvApiKeyDict(config)
        let state = StateStore.getState(Client__State__Store.store)
        let model =
          Client__State.Selectors.selectedModelValue(state)->Option.flatMap(
            FrontmanAiFrontmanProtocol.FrontmanProtocol__Types.modelSelectionFromValueId,
          )
        {model, envApiKey}
      })

      // Wire up image ref resolver so write_file can save user-attached images.
      MCPServer.setImageRefResolver(mcpServer, (uri, ~taskId) => {
        let state = StateStore.getState(Client__State__Store.store)
        Client__State.Selectors.resolveImageRef(state, ~taskId, ~uri)->Option.map(
          ({base64, mediaType}) => {MCPServer.base64, mediaType},
        )
      })

      let config: Reducer.initConfig = {
        endpoint,
        tokenUrl,
        loginUrl,
        clientName,
        clientVersion,
        baseUrl,
        onACPMessage: logACPMessage,
        _meta,
        onTitleUpdated: Some(
          (taskId, title) => {
            Client__State.Actions.updateTaskTitle(~taskId, ~title)
          },
        ),
      }

      dispatch(Initialize({config, relay, mcpServer}))

      Some(
        () => {
          textDeltaBuffer.reset()
          _userMsgBuffer.pending = false
          _userMsgBuffer.blocks = []
          dispatch(Cleanup)
        },
      )
    })

    let handleTitleUpdated = React.useCallback0((taskId: string, title: string) => {
      Client__State.Actions.updateTaskTitle(~taskId, ~title)
    })

    let handleSessionUpdate = React.useCallback0((
      sessionId: string,
      update: Types.sessionUpdate,
    ) => {
      let taskId = sessionId
      switch update {
      | AgentMessageChunk({content, timestamp}) =>
        // Per ACP spec: first agent_message_chunk implicitly signals message start.
        // Message end is signaled by session/prompt response with stopReason.
        _flushUserMessageBuffer()
        // Buffer text deltas and flush once per animation frame to avoid
        // dozens of full state rebuilds per second during fast streaming.
        getContentBlockText(content)->Option.forEach(text => {
          textDeltaBuffer.add(~taskId, ~text, ~timestamp)
        })
      | UserMessageChunk({content, timestamp}) =>
        // During history replay, a single user message is replayed as multiple
        // user_message_chunk notifications (text, annotations, images, current_page).
        // We accumulate them in a buffer and flush at the next turn boundary.
        // If this is the first chunk for a new user message, flush any previous
        // buffered agent text and any previous user message buffer first.
        if !_userMsgBuffer.pending {
          Client__TextDeltaBuffer.flush()
          _userMsgBuffer.pending = true
          _userMsgBuffer.taskId = taskId
          _userMsgBuffer.id = `user-hydrated-${WebAPI.Global.crypto->WebAPI.Crypto.randomUUID}`
          _userMsgBuffer.timestamp = timestamp
          _userMsgBuffer.blocks = []
        }
        _userMsgBuffer.blocks = Array.concat(_userMsgBuffer.blocks, [content])
      | ToolCall({toolCallId, title, timestamp, parentAgentId, spawningToolName}) =>
        Client__TextDeltaBuffer.flush()
        let createdAt = Date.fromString(timestamp)->Date.getTime
        Client__State.Actions.toolCallReceived(
          ~taskId,
          ~toolCall={
            id: toolCallId,
            toolName: title,
            inputBuffer: "",
            input: None,
            result: None,
            errorText: None,
            state: Client__State__Types.Message.InputStreaming,
            createdAt,
            parentAgentId,
            spawningToolName,
          },
        )
      | ToolCallUpdate({toolCallId, status, content}) =>
        let text =
          content
          ->Option.flatMap(c => c->Array.get(0))
          ->Option.flatMap(i => i.content)
          ->Option.flatMap(getContentBlockText)
        switch status {
        | Some(Pending) =>
          text
          ->Option.flatMap(t =>
            try {Some(JSON.parseOrThrow(t))} catch {
            | _ => None
            }
          )
          ->Option.forEach(input => {
            Client__State.Actions.toolInputReceived(~taskId, ~id=toolCallId, ~input)
          })
        | Some(Completed) =>
          let result = text->Option.mapOr(JSON.Encode.null, t =>
            try {JSON.parseOrThrow(t)} catch {
            | _ => JSON.Encode.string(t)
            }
          )
          Client__State.Actions.toolResultReceived(~taskId, ~id=toolCallId, ~result)
        | Some(Failed) =>
          Client__State.Actions.toolErrorReceived(
            ~taskId,
            ~id=toolCallId,
            ~error=text->Option.getOr("Unknown error"),
          )
        | Some(InProgress) => () // Normal transitional status for MCP tools
        | None => ()
        }
      | Plan({entries}) => Client__State.Actions.planReceived(~taskId, ~entries)
      | AgentTurnComplete({stopReason: _}) =>
        Client__TextDeltaBuffer.flush()
        Client__State.Actions.turnCompleted(~taskId)
      | ConfigOptionUpdate({configOptions}) =>
        Client__State.Actions.configOptionsReceived(~configOptions)
      | CurrentModeUpdate(_) => () // TODO: dispatch mode change when modes are supported in UI
      | Error({message, timestamp, retryAt, attempt, maxAttempts, category}) =>
        Client__TextDeltaBuffer.flush()
        switch retryAt {
        | Some(retryAtStr) =>
          let retryAtMs = Date.fromString(retryAtStr)->Date.getTime
          let retryStatus: Client__Task__Types.Task.retryStatus = {
            attempt: attempt->Option.getOr(1),
            maxAttempts: maxAttempts->Option.getOr(5),
            retryAt: retryAtMs,
            error: message,
          }
          Client__State.Actions.retryingStatusReceived(~taskId, ~retryStatus)
        | None =>
          Client__State.Actions.agentErrorReceived(
            ~taskId,
            ~error=message,
            ~timestamp,
            ~retryable=false,
            ~category=category->Option.getOr("unknown"),
          )
        }
      | Unknown(_) => ()
      }
    })

    let createSession = React.useCallback1((~onComplete: result<string, string> => unit) => {
      dispatch(
        CreateSession({
          onUpdate: handleSessionUpdate,
          onTitleUpdated: handleTitleUpdated,
          onMcpMessage: logMCPMessage,
          onComplete,
        }),
      )
    }, [dispatch])

    let clearSession = React.useCallback1(() => dispatch(ClearSession), [dispatch])

    let sendPrompt = React.useCallback1((text: string, ~additionalBlocks, ~onComplete, ~_meta) => {
      dispatch(SendPrompt({text, additionalBlocks, onComplete, _meta}))
    }, [dispatch])

    let cancelPrompt = React.useCallback1(() => {
      dispatch(CancelPrompt)
    }, [dispatch])

    let retryTurn = React.useCallback1((retriedErrorId: string) => {
      dispatch(RetryTurn({retriedErrorId: retriedErrorId}))
    }, [dispatch])

    let loadTask = React.useCallback1((taskId: string, ~needsHistory, ~onComplete) => {
      dispatch(
        LoadTask({
          taskId,
          needsHistory,
          onUpdate: handleSessionUpdate,
          onTitleUpdated: handleTitleUpdated,
          onMcpMessage: logMCPMessage,
          onComplete,
        }),
      )
    }, [dispatch])

    let deleteSession = React.useCallback1((taskId: string, ~onComplete) => {
      dispatch(DeleteSession({taskId, onComplete}))
    }, [dispatch])

    let authRedirectUrl = Reducer.Selectors.getAuthRedirectUrl(state)

    let contextValue: contextValue = {
      connectionState: Reducer.Selectors.getConnectionStatus(state),
      isSendingPrompt: state.isSendingPrompt,
      session: Reducer.Selectors.getSession(state),
      relay: state.relayInstance,
      authRedirectUrl,
      createSession,
      clearSession,
      sendPrompt,
      cancelPrompt,
      retryTurn,
      loadTask,
      deleteSession,
    }

    <ContextProvider value={contextValue}> {children} </ContextProvider>
  }
}
