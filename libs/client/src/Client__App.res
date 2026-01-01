module RadixUI__Icons = Bindings__RadixUI__Icons
module Chrome = FrontmanBindings.Chrome
module ACPTypes = FrontmanFrontmanClient.FrontmanClient__ACP__Types

let useExtensionState = () => {
  React.useEffect(() => {
    let checkAttempts = ref(0)
    let maxAttempts = 3
    let checkInterval = 1666.0 // ~5 seconds total / 3 attempts
    let timeoutId = ref(None)

    let chromeRuntimeExists: unit => bool = %raw(`
      function() {
        return typeof chrome !== 'undefined' && chrome.runtime;
      }
    `)

    let hasExtensionClass = () => {
      WebAPI.Global.document
      ->WebAPI.Document.body
      ->Null.toOption
      ->Option.mapOr(false, body => {
        body
        ->WebAPI.Element.classList
        ->WebAPI.DOMTokenList.contains("frontman-extension-active")
      })
    }

    let rec checkExtension = () => {
      checkAttempts.contents = checkAttempts.contents + 1

      if !chromeRuntimeExists() || !hasExtensionClass() {
        if checkAttempts.contents < maxAttempts {
          let id = WebAPI.Global.setTimeout(~handler=() => {
            checkExtension()
          }, ~timeout=checkInterval->Float.toInt)
          timeoutId.contents = Some(id)
        } else {
          Client__ExtensionState.Actions.setExtensionNotInstalled()
        }
      } else {
        // Extension is installed, connect to it
        try {
          let port = Chrome.Runtime.Connect.connectExternal(
            "kfdpjbmabcelpgoipaccjijhehdmeghp",
            Some({name: "FrontmanClient"}),
          )

          // Set up message listener
          let messageListener = (
            message: Client__ExtensionState__StateReducer.extensionMessage,
          ) => {
            switch message.type_ {
            | "DevServerImportFigmaNodeResponse" =>
              message.selectedFigmaNode->Option.forEach(data => {
                // Transform from extension format to internal format
                // Extension always sends DSL data, so isDsl is always true
                let parsedData: Client__State__Types.FigmaNode.selectedNodeData = {
                  nodeId: data.nodeId,
                  nodeData: data.nodeData,
                  image: data.image,
                  isDsl: true, // Extension always sends DSL representation
                }
                Client__State.Actions.setFigmaNode(~figmaNode=parsedData)
              })
            | "GetFigmaNodeResponse" =>
              // Route response to the pending tool request
              // Note: fields are Js.Nullable.t since they come from JS as null, not undefined
              message.requestId
              ->Js.Nullable.toOption
              ->Option.forEach(requestId => {
                let result = switch message.error->Js.Nullable.toOption {
                | Some(error) => Error(error)
                | None =>
                  switch message.node->Js.Nullable.toOption {
                  | Some(node) =>
                    let image = message.image->Js.Nullable.toOption
                    Ok({
                      Client__Tool__GetFigmaNode.node,
                      Client__Tool__GetFigmaNode.image,
                    })
                  | None => Error("No node data in response")
                  }
                }
                Client__Tool__GetFigmaNode.handleResponse(requestId, result)
              })
            | _ => ()
            }
          }

          Chrome.Port.addMessageListener(port, messageListener)

          Client__ExtensionState.Actions.setExtensionInstalled(~port)
        } catch {
        | exn => {
            Console.error2("[Extension] Failed to connect:", exn)
            Client__ExtensionState.Actions.setExtensionNotInstalled()
          }
        }
      }
    }

    checkExtension()

    Some(
      () => {
        timeoutId.contents->Option.forEach(id => {
          WebAPI.Global.clearTimeout(id)
        })
      },
    )
  }, [])
}

@react.component
let make = () => {
  useExtensionState()

  // Use Frontman context for ACP connection
  let {state, isReady, isSessionActive, createSession, sendPrompt} = Client__FrontmanProvider.useFrontman()

  // Handle ACP session updates (streaming messages from the agent)
  let handleSessionUpdate = React.useCallback((update: ACPTypes.sessionUpdate) => {
    // Get current task ID directly from the store
    let state = FrontmanReactStatestore.StateStore.getState(Client__State__Store.store)
    let taskId = state.currentTaskId->Option.getOr("unknown")

    switch update {
    | AgentMessageChunk({content}) =>
      // Text delta from assistant
      content
      ->Option.flatMap(c => c.text)
      ->Option.forEach(text => {
        // Use a consistent ID for the current message stream
        let id = `msg_${taskId}`
        // The reducer will handle creating a new streaming message if needed
        // (e.g., if last message is not an assistant message)
        Client__State.Actions.textDeltaReceived(~taskId, ~id, ~text)
      })

    | AgentMessageStart =>
      let id = `msg_${taskId}`
      Client__State.Actions.streamingStarted(~taskId, ~id)

    | AgentMessageEnd =>
      let id = `msg_${taskId}`
      Client__State.Actions.messageCompleted(~taskId, ~id)

    | ToolCall({toolCallId, title, parentAgentId, spawningToolName}) =>
      // Tool call started - create tool call entry
      let toolName = title->Option.getOr("unknown_tool")
      Client__State.Actions.toolCallReceived(
        ~taskId,
        ~toolCall={
          id: toolCallId,
          toolName,
          inputBuffer: "",
          input: None, // Input will be provided in tool_call_update
          result: None,
          errorText: None,
          state: InputStreaming,
          createdAt: Date.now(),
          parentAgentId, // If present, this is a sub-agent tool call
          spawningToolName, // Tool name that spawned the sub-agent
        },
      )

    | ToolCallUpdate({toolCallId, status, content}) =>
      // Tool call status update
      switch status {
      | Some("pending") =>
        // Pending update with content contains the tool input arguments
        let inputJson =
          content
          ->Option.flatMap(contents => contents->Array.get(0))
          ->Option.flatMap(item => item.content)
          ->Option.flatMap(c => c.text)
          ->Option.flatMap(text => {
            try {
              Some(JSON.parseOrThrow(text))
            } catch {
            | _ => None
            }
          })
        
        inputJson->Option.forEach(input => {
          Client__State.Actions.toolInputReceived(~taskId, ~id=toolCallId, ~input)
        })
        
      | Some("completed") =>
        // Extract result from content if available
        let result =
          content
          ->Option.flatMap(contents => contents->Array.get(0))
          ->Option.flatMap(item => item.content)
          ->Option.flatMap(c => c.text)
          ->Option.mapOr(JSON.Encode.null, text => {
            // Try to parse as JSON, fallback to string
            try {
              JSON.parseOrThrow(text)
            } catch {
            | _ => JSON.Encode.string(text)
            }
          })
        Client__State.Actions.toolResultReceived(~taskId, ~id=toolCallId, ~result)

      | Some("failed") =>
        // ACP spec uses "failed" status
        let error =
          content
          ->Option.flatMap(contents => contents->Array.get(0))
          ->Option.flatMap(item => item.content)
          ->Option.flatMap(c => c.text)
          ->Option.getOr("Unknown error")
        Client__State.Actions.toolErrorReceived(~taskId, ~id=toolCallId, ~error)

      | Some("in_progress") => // Tool is running - could update UI state if needed
        ()

      | Some(_status) => ()

      | None => ()
      }

    | Plan({entries}) =>
      entries->Option.forEach(planEntries => {
        Client__State.Actions.planReceived(~taskId, ~entries=planEntries)
      })

    // Todo UX events
    | TodoBatchCreated({entries, count}) =>
      Client__State.Actions.todoBatchCreated(~taskId, ~entries, ~count)

    | TodoStarted({todoId, content}) =>
      Client__State.Actions.todoStarted(~taskId, ~todoId, ~content)

    | TodoCompleted({todoId, content}) =>
      Client__State.Actions.todoCompleted(~taskId, ~todoId, ~content)

    | Unknown({sessionUpdate}) => Console.log2("[ACP] Unhandled session update:", sessionUpdate)
    }
  }, [])

  // Track if session was created to avoid duplicate creation
  let sessionCreatedRef = React.useRef(false)

  // Auto-create session when ready (both ACP and relay initialized)
  React.useEffect(() => {
    if isReady && !sessionCreatedRef.current {
      sessionCreatedRef.current = true
      Console.log("[App] Provider ready, creating session...")
      createSession(handleSessionUpdate)
      ->Promise.thenResolve(result => {
        switch result {
        | Ok(_sess) => ()
        | Error(err) =>
          sessionCreatedRef.current = false
          Console.error2("[App] Failed to create session:", err)
        }
      })
      ->ignore
    }
    None
  }, (isReady, handleSessionUpdate, createSession))

  // Separate effect to update sendPrompt in state when session becomes active
  React.useEffect(() => {
    if isSessionActive {
      Client__Debug.init()
      Client__State.Actions.connect(~sendPrompt)
    } else {
      switch state {
      | Disconnected | Error(_) => Client__State.Actions.disconnect()
      | _ => ()
      }
    }
    None
  }, (state, isSessionActive, sendPrompt))

  // Get resizable width for chatbox panel
  let (chatboxWidth, isResizing, handleResizeMouseDown) = Client__UseResizableWidth.use()

  <div className="flex h-screen w-screen bg-background text-foreground">
    // Transparent overlay during resize to prevent iframe from stealing mouse events
    {isResizing
      ? <div className="fixed inset-0 z-50 cursor-col-resize" />
      : React.null}
    <div
      style={{width: `${Int.toString(chatboxWidth)}px`}}
      className="h-full border-r flex flex-col p-2 overflow-hidden relative shrink-0"
    >
      <Client__Chatbox />
      // Resize handle on right edge
      <div
        className={[
          "absolute top-0 right-0 w-1 h-full cursor-col-resize transition-colors",
          isResizing ? "bg-zinc-500" : "hover:bg-zinc-600",
        ]->Array.join(" ")}
        onMouseDown={handleResizeMouseDown}
      />
    </div>
    <div className="grow h-full p-1 min-w-0">
      <Client__WebPreview />
    </div>
  </div>
}
