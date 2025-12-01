module AIElements = Bindings__AIElements
module RadixUI__Icons = Bindings__RadixUI__Icons

// Import required types
module AgentEventBus = AskTheLlmAgent.Agent__EventBus
module Vercel = AskTheLlmAgent.Agent__Bindings__Vercel
module Agent = AskTheLlmAgent.Agent
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
          let id = WebAPI.Global.setTimeout(
            ~handler=() => {
              checkExtension()
            },
            ~timeout=checkInterval->Float.toInt,
          )
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
          let messageListener = (message: Client__ExtensionState__StateReducer.extensionMessage) => {
            switch message.type_ {
            | "DevServerImportFigmaNodeResponse" =>
              message.selectedFigmaNode->Option.forEach(data => {
                Client__State.Actions.setFigmaNode(~figmaNode=data)
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
    
    Some(() => {
      timeoutId.contents->Option.forEach(id => {
        WebAPI.Global.clearTimeout(id)
      })
    })
  }, [])
}

@react.component
let make = () => {

  useExtensionState()

  // Use Frontman context for ACP connection
  let {connectionState, createSession, sendPrompt} = Client__FrontmanProvider.useFrontman()

  // Handle ACP session updates (streaming messages from the agent)
  let handleSessionUpdate = React.useCallback((update: ACPTypes.sessionUpdate) => {
    switch update.sessionUpdate {
    | "agent_message_chunk" =>
      // ACP compliant: First agent_message_chunk implicitly signals message start
      // Text delta from assistant - append to the most recent assistant message if it exists,
      // otherwise create a new one
      // IMPORTANT: Get fresh state each time to avoid stale closures
      update.content->Option.flatMap(c => c.text)->Option.forEach(text => {
        let currentState = AskTheLlmReactStatestore.StateStore.getState(Client__State__Store.store)
        let taskId = currentState.currentTaskId->Option.getOr("unknown")
        let messages = Client__State.Selectors.messages(currentState)
        let lastMessage = messages->Array.get(Array.length(messages) - 1)
        
        let id = switch lastMessage {
        | Some(Client__State__StateReducer.Message.Assistant(Streaming({id, _}))) =>
          // Last message is a streaming assistant message - stream to it
          id
        | Some(Client__State__StateReducer.Message.Assistant(Completed(_))) =>
          // Last message is a completed assistant message - create new one
          let newId = `assistant-${Date.now()->Float.toString}`
          Client__State.Actions.streamingStarted(~taskId, ~id=newId)
          newId
        | Some(Client__State__StateReducer.Message.User(_)) | Some(Client__State__StateReducer.Message.ToolCall(_)) | None =>
          // Last message is not an assistant message (or no messages) - create new one
          let newId = `assistant-${Date.now()->Float.toString}`
          Client__State.Actions.streamingStarted(~taskId, ~id=newId)
          newId
        }
        Client__State.Actions.textDeltaReceived(~taskId, ~id, ~text)
      })

    | "tool_call" =>
      // Tool call started - create tool call entry
      // Get fresh state to ensure we have the current taskId
      let currentState = AskTheLlmReactStatestore.StateStore.getState(Client__State__Store.store)
      let taskId = currentState.currentTaskId->Option.getOr("unknown")
      update.toolCallId->Option.forEach(toolCallId => {
        // Extract tool name from title (e.g., "Calling list_files" -> "list_files")
        let toolName = update.title->Option.map(title => {
          if String.startsWith("Calling ", title) {
            title->String.slice(~start=9, ~end=String.length(title))
          } else {
            title
          }
        })->Option.getOr("unknown_tool")
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
      })

    | "tool_call_update" =>
      // Tool call status update
      // Get fresh state to ensure we have the current taskId
      let currentState = AskTheLlmReactStatestore.StateStore.getState(Client__State__Store.store)
      let taskId = currentState.currentTaskId->Option.getOr("unknown")
      update.toolCallId->Option.forEach(toolCallId => {
        switch update.status {
        | Some("completed") =>
          // Extract result from contents if available
          let result =
            update.contents
            ->Option.flatMap(contents => contents->Array.get(0))
            ->Option.flatMap(item => item.content)
            ->Option.flatMap(content => content.text)
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
          let error =
            update.contents
            ->Option.flatMap(contents => contents->Array.get(0))
            ->Option.flatMap(item => item.content)
            ->Option.flatMap(content => content.text)
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
      })

    | _ =>
      ()
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
          | Ok(_sess) =>
            ()
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
    | SessionActive(_sessionId) =>
      Client__State.Actions.connect(~sendPrompt)
    | Disconnected | Error(_) =>
      Client__State.Actions.disconnect()
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
