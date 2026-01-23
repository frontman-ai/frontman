module RadixUI__Icons = Bindings__RadixUI__Icons
module Chrome = FrontmanBindings.Chrome
module ACPTypes = FrontmanFrontmanClient.FrontmanClient__ACP__Types
module SettingsModal = Client__SettingsModal

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
              Console.log2("[App] Received GetFigmaNodeResponse, requestId:", message.requestId)
              message.requestId
              ->Js.Nullable.toOption
              ->Option.forEach(requestId => {
                Console.log2("[App] Routing response to handler for:", requestId)
                let result = switch message.error->Js.Nullable.toOption {
                | Some(error) =>
                  Console.log2("[App] Response has error:", error)
                  Error(error)
                | None =>
                  switch message.node->Js.Nullable.toOption {
                  | Some(node) =>
                    Console.log("[App] Response has node data")
                    let image = message.image->Js.Nullable.toOption
                    Ok({
                      Client__Tool__GetFigmaNode.node,
                      Client__Tool__GetFigmaNode.image,
                    })
                  | None =>
                    Console.warn("[App] Response has no node data")
                    Error("No node data in response")
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
let make = (~apiBaseUrl: string) => {
  useExtensionState()

  // Use Frontman context for ACP connection
  let {connectionState, createSession, sendPrompt} = Client__FrontmanProvider.useFrontman()

  // Derive session active state from connectionState
  let isSessionActive = switch connectionState {
  | SessionActive(_) => true
  | _ => false
  }

  // Handle ACP session updates (streaming messages from the agent)
  let handleSessionUpdate = React.useCallback((update: ACPTypes.sessionUpdate) => {
    // Get current task ID directly from the store
    let state = FrontmanReactStatestore.StateStore.getState(Client__State__Store.store)
    let taskId = state.currentTaskId->Option.getOr("unknown")

    switch update {
    | AgentMessageChunk({content}) =>
      content
      ->Option.flatMap(c => c.text)
      ->Option.forEach(text => {
        Client__State.Actions.textDeltaReceived(~taskId, ~text)
      })

    | AgentMessageStart => Client__State.Actions.streamingStarted(~taskId)

    | AgentMessageEnd => Client__State.Actions.messageCompleted(~taskId)

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
      // ACP plan update - replace plan entries completely
      entries->Option.forEach(planEntries => {
        Client__State.Actions.planReceived(~taskId, ~entries=planEntries)
      })

    | Unknown({sessionUpdate}) => Console.log2("[ACP] Unhandled session update:", sessionUpdate)
    }
  }, [])

  // Track if session was created to avoid duplicate creation
  let sessionCreatedRef = React.useRef(false)

  // Auto-create session when ready (both ACP and relay initialized)
  React.useEffect(() => {
    switch connectionState {
    | Connected =>
      if !sessionCreatedRef.current {
        sessionCreatedRef.current = true
        createSession(handleSessionUpdate)
      }
    | Error(_) | Disconnected => sessionCreatedRef.current = false
    | _ => ()
    }
    None
  }, (connectionState, handleSessionUpdate, createSession))

  // Separate effect to update sendPrompt in state when session becomes active
  React.useEffect(() => {
    if isSessionActive {
      Client__Debug.init()
      Client__State.Actions.connect(~sendPrompt, ~apiBaseUrl)
    } else {
      switch connectionState {
      | Disconnected | Error(_) => Client__State.Actions.disconnect()
      | _ => ()
      }
    }
    None
  }, (connectionState, isSessionActive, sendPrompt, apiBaseUrl))

  // Get resizable width for chatbox panel
  let (chatboxWidth, isResizing, handleResizeMouseDown) = Client__UseResizableWidth.use()

  let (settingsOpen, setSettingsOpen) = React.useState(() => false)

  <div className="flex h-screen w-screen bg-background text-foreground">
    <SettingsModal open_={settingsOpen} onOpenChange={value => setSettingsOpen(_ => value)} />
    // Transparent overlay during resize to prevent iframe from stealing mouse events
    {isResizing
      ? <div className="fixed inset-0 z-50 cursor-col-resize" />
      : React.null}
    <div
      style={{width: `${Int.toString(chatboxWidth)}px`}}
      className="h-full border-r flex flex-col p-2 overflow-hidden relative shrink-0"
    >
      <button
        type_="button"
        className="absolute top-3 right-3 z-50 h-9 w-9 rounded-lg border border-zinc-800/70 bg-zinc-900/70 text-zinc-200 shadow-sm backdrop-blur transition-all duration-200 flex items-center justify-center hover:border-zinc-700 hover:bg-zinc-800/90 hover:shadow-md"
        onClick={_ => setSettingsOpen(_ => true)}
        title="Settings"
      >
        <RadixUI__Icons.GearIcon className="size-4" />
      </button>
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
