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
  let {connectionState, sendPrompt, cancelPrompt, loadTask, deleteSession, _} = Client__FrontmanProvider.useFrontman()

  // Set up ACP session callbacks when ACP+Relay are ready
  // Session creation is deferred until user sends first message (lazy session creation)
  React.useEffect(() => {
    switch connectionState {
    | Connected | SessionActive(_) =>
      Client__Debug.init()
      Client__State.Actions.setAcpSession(~sendPrompt, ~cancelPrompt, ~loadTask, ~deleteSession, ~apiBaseUrl)
    | Disconnected | Error(_) => Client__State.Actions.clearAcpSession()
    | _ => ()
    }
    None
  }, (connectionState, sendPrompt, cancelPrompt, loadTask, deleteSession, apiBaseUrl))

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
      <Client__Chatbox onSettingsClick={() => setSettingsOpen(_ => true)} />
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
