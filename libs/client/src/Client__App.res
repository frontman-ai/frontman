module AIElements = Bindings__AIElements
module RadixUI__Icons = Bindings__RadixUI__Icons
module Chrome = AskTheLlmBindings.Chrome
module ACPTypes = AskTheLlmFrontmanClient.FrontmanClient__ACP__Types

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
            Some({name: "AskTheLlmClient"}),
          )

          // Set up message listener
          let messageListener = (
            message: Client__ExtensionState__StateReducer.extensionMessage,
          ) => {
            switch message.type_ {
            | "DevServerImportFigmaNodeResponse" =>
              message.selectedFigmaNode->Option.forEach(data => {
                // Parse the data structure: { nodeId: string, nodeDSL: string, image: option<string> }
                let parsedData: Client__State__Types.FigmaNode.selectedNodeData = {
                  nodeId: %raw(`data.nodeId`),
                  nodeDSL: %raw(`data.nodeDSL`),
                  image: %raw(`data.image ? (data.image === null ? null : data.image) : null`)->Js.Nullable.toOption,
                }
                Client__State.Actions.setFigmaNode(~figmaNode=parsedData)
              })
            | "GetFigmaNodeResponse" =>
              // Route response to the pending tool request
              // Note: fields are Js.Nullable.t since they come from JS as null, not undefined
              message.requestId->Js.Nullable.toOption->Option.forEach(requestId => {
                let result = switch message.error->Js.Nullable.toOption {
                | Some(error) => Error(error)
                | None =>
                  switch message.node->Js.Nullable.toOption {
                  | Some(node) =>
                    let image = message.image->Js.Nullable.toOption
                    Ok({
                      Client__Tool__GetFigmaNode.node: node,
                      Client__Tool__GetFigmaNode.image: image,
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
  let {connectionState, createSession, sendPrompt} = Client__FrontmanProvider.useFrontman()

  // Handle ACP session updates (streaming messages from the agent)
  let handleSessionUpdate = React.useCallback((update: ACPTypes.sessionUpdate) => {
    // Get current task ID directly from the store
    let state = AskTheLlmReactStatestore.StateStore.getState(Client__State__Store.store)
    let taskId = state.currentTaskId->Option.getOr("unknown")

    switch update {
    | AgentMessageChunk({content}) =>
      // Text delta from assistant
      content->Option.flatMap(c => c.text)->Option.forEach(text => {
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

    | ToolCall({toolCallId, title}) =>
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
        },
      )

    | ToolCallUpdate({toolCallId, status, content}) =>
      // Tool call status update
      switch status {
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

      | Some("in_progress") =>
        // Tool is running - could update UI state if needed
        ()

      | Some(_status) =>
        ()

      | None =>
        ()
      }

    | Plan({entries}) =>
      entries->Option.forEach(planEntries => {
        Client__State.Actions.planReceived(~taskId, ~entries=planEntries)
      })

    | Unknown({sessionUpdate}) =>
      Console.log2("[ACP] Unhandled session update:", sessionUpdate)
    }
  }, [])

  // Track if session was created to avoid duplicate creation
  let sessionCreatedRef = React.useRef(false)

  // Auto-create session when connected
  React.useEffect(() => {
    switch connectionState {
    | Connected =>
      if !sessionCreatedRef.current {
        sessionCreatedRef.current = true
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
    | _ => ()
    }
    None
  }, (connectionState, handleSessionUpdate, createSession))

  // Separate effect to update sendPrompt in state when session becomes active
  React.useEffect(() => {
    switch connectionState {
    | SessionActive(_sessionId) => Client__State.Actions.connect(~sendPrompt)
    | Disconnected | Error(_) => Client__State.Actions.disconnect()
    | _ => ()
    }
    None
  }, (connectionState, sendPrompt))

  <div className="flex h-screen w-screen bg-background text-foreground">
    <div className="h-full w-96 border-r flex flex-col p-2 overflow-hidden">
      <Client__Chatbox />
    </div>
    <div className="grow h-full p-1">
      <Client__WebPreview />
    </div>
  </div>
}
