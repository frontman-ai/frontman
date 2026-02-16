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
  let {connectionState, sendPrompt, cancelPrompt, loadTask, deleteSession, authRedirectUrl, _} = Client__FrontmanProvider.useFrontman()

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

  // Settings modal state
  let (settingsOpen, setSettingsOpen) = React.useState(() => false)
  let (settingsInitialTab, setSettingsInitialTab) = React.useState(() => None)

  // FTUE state
  let (ftueState, setFtueState) = React.useState(() => Client__FtueState.get())
  let (showCelebration, setShowCelebration) = React.useState(() => false)
  let (providerNudgeDismissed, setProviderNudgeDismissed) = React.useState(() => false)
  let hasProviderConfigured = Client__State.useSelector(Client__State.Selectors.hasAnyProviderConfigured)

  // Trigger post-signup celebration when session becomes active for first time after signup
  React.useEffect2(() => {
    switch (connectionState, ftueState) {
    | (Connected | SessionActive(_), Client__FtueState.WelcomeShown) =>
      setShowCelebration(_ => true)
      Client__FtueState.setCompleted()
      setFtueState(_ => Client__FtueState.Completed)
    | _ => ()
    }
    None
  }, (connectionState, ftueState))

  // Open settings on providers tab (used by FTUE CTAs)
  let openSettingsProviders = () => {
    setSettingsInitialTab(_ => Some("providers"))
    setSettingsOpen(_ => true)
  }

  let handleCelebrationDismiss = () => {
    setShowCelebration(_ => false)
  }

  let handleCelebrationConnectProvider = () => {
    setShowCelebration(_ => false)
    openSettingsProviders()
  }

  // Provider nudge: show when FTUE is completed, no provider configured, and not dismissed this session
  let showProviderNudge = switch (ftueState, hasProviderConfigured, providerNudgeDismissed) {
  | (Client__FtueState.Completed, false, false) => true
  | _ => false
  }

  let handleProviderNudgeDismiss = () => {
    setProviderNudgeDismissed(_ => true)
  }

  let handleProviderNudgeCta = () => {
    setProviderNudgeDismissed(_ => true)
    openSettingsProviders()
  }

  // Reset initialTab after settings modal closes so it doesn't stick
  let handleSettingsOpenChange = (value: bool) => {
    setSettingsOpen(_ => value)
    switch value {
    | false => setSettingsInitialTab(_ => None)
    | true => ()
    }
  }

  <div className="flex h-screen w-screen bg-background text-foreground">
    <SettingsModal
      open_={settingsOpen}
      onOpenChange={handleSettingsOpenChange}
      initialTab=?{settingsInitialTab}
    />
    // FTUE: Welcome modal for first-time unauthenticated users
    {switch (authRedirectUrl, ftueState) {
    | (Some(loginUrl), Client__FtueState.New) => <Client__WelcomeModal loginUrl />
    | _ => React.null
    }}
    // FTUE: Post-signup celebration overlay
    {switch showCelebration {
    | true =>
      <Client__PostSignupCelebration
        onDismiss=handleCelebrationDismiss onConnectProvider=handleCelebrationConnectProvider
      />
    | false => React.null
    }}
    // Transparent overlay during resize to prevent iframe from stealing mouse events
    {switch isResizing {
    | true => <div className="fixed inset-0 z-50 cursor-col-resize" />
    | false => React.null
    }}
    <div
      style={{width: `${Int.toString(chatboxWidth)}px`}}
      className="h-full border-r flex flex-col p-2 overflow-hidden relative shrink-0"
    >
      <Client__Chatbox
        onSettingsClick={() => setSettingsOpen(_ => true)}
        showProviderNudge
        onProviderNudgeDismiss=handleProviderNudgeDismiss
        onProviderNudgeCta=handleProviderNudgeCta
      />
      // Resize handle on right edge
      <div
        className={[
          "absolute top-0 right-0 w-1 h-full cursor-col-resize transition-colors",
          switch isResizing {
          | true => "bg-zinc-500"
          | false => "hover:bg-zinc-600"
          },
        ]->Array.join(" ")}
        onMouseDown={handleResizeMouseDown}
      />
    </div>
    <div className="grow h-full p-1 min-w-0">
      <Client__WebPreview />
    </div>
  </div>
}
