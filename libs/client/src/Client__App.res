module RadixUI__Icons = Bindings__RadixUI__Icons
module Chrome = FrontmanBindings.Chrome
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
  let {connectionState, sendPrompt, loadTask, deleteSession, _} = Client__FrontmanProvider.useFrontman()

  // Set up connection functions when ACP+Relay are ready
  // Session creation is deferred until user sends first message (lazy session creation)
  React.useEffect(() => {
    switch connectionState {
    | Connected | SessionActive(_) =>
      Client__Debug.init()
      Client__State.Actions.connect(~sendPrompt, ~loadTask, ~deleteSession, ~apiBaseUrl)
    | Disconnected | Error(_) => Client__State.Actions.disconnect()
    | _ => ()
    }
    None
  }, (connectionState, sendPrompt, loadTask, deleteSession, apiBaseUrl))

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
