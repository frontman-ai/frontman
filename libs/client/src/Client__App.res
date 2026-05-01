module SettingsModal = Client__SettingsModal

@react.component
let make = (~apiBaseUrl: string) => {
  let {
    connectionState,
    sendPrompt,
    cancelPrompt,
    retryTurn,
    loadTask,
    deleteSession,
    authRedirectUrl,
    _,
  } = Client__FrontmanProvider.useFrontman()

  React.useEffect(() => {
    switch connectionState {
    | Connected | SessionActive(_) =>
      Client__State.Actions.setAcpSession(
        ~sendPrompt,
        ~cancelPrompt,
        ~retryTurn,
        ~loadTask,
        ~deleteSession,
        ~apiBaseUrl,
      )
    | Disconnected | Error(_) => Client__State.Actions.clearAcpSession()
    | _ => ()
    }
    None
  }, (connectionState, sendPrompt, cancelPrompt, retryTurn, loadTask, deleteSession, apiBaseUrl))

  // Get resizable width for chatbox panel
  let (chatboxWidth, isResizing, handleResizeMouseDown) = Client__UseResizableWidth.use()

  // Settings modal state
  let (settingsOpen, setSettingsOpen) = React.useState(() => false)
  let (settingsInitialTab, setSettingsInitialTab) = React.useState(() => None)

  // FTUE state
  let (ftueState, setFtueState) = React.useState(() => Client__FtueState.get())
  let (showCelebration, setShowCelebration) = React.useState(() => false)
  let (providerNudgeDismissed, setProviderNudgeDismissed) = React.useState(() => false)
  let (nudgeBubbleDismissed, setNudgeBubbleDismissed) = React.useState(() => false)
  let hasProviderConfigured = Client__State.useSelector(
    Client__State.Selectors.hasAnyProviderConfigured,
  )
  let usageInfo = Client__State.useSelector(Client__State.Selectors.usageInfo)

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

  // Provider nudge: show when FTUE is completed, no provider configured, and not dismissed this session.
  // Gate on usageInfo being loaded (Some) to avoid flashing the nudge before provider status is fetched.
  let showNudge = switch (ftueState, hasProviderConfigured, providerNudgeDismissed, usageInfo) {
  | (Client__FtueState.Completed, false, false, Some(_)) => true
  | _ => false
  }
  let showProviderNudgeBubble = showNudge && !nudgeBubbleDismissed
  let showProviderNudgeBadge = showNudge && nudgeBubbleDismissed

  let handleProviderNudgeDismiss = () => {
    setNudgeBubbleDismissed(_ => true)
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

  <div className="flex flex-col h-screen w-screen bg-background text-foreground">
    <SettingsModal
      open_={settingsOpen} onOpenChange={handleSettingsOpenChange} initialTab=?{settingsInitialTab}
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
    // Top bar (sits above the panel split)
    <Client__TopBar
      chatboxWidth
      onSettingsClick={() => setSettingsOpen(_ => true)}
      showProviderNudgeBubble
      showProviderNudgeBadge
      onProviderNudgeDismiss=handleProviderNudgeDismiss
      onProviderNudgeCta=handleProviderNudgeCta
    />
    // Main content area — flex row of chat + preview panels
    <div className="flex flex-1 min-h-0 w-full">
      // Transparent overlay during resize to prevent iframe from stealing mouse events
      {switch isResizing {
      | true => <div className="fixed inset-0 z-50 cursor-col-resize" />
      | false => React.null
      }}
      <div
        style={{width: `${Int.toString(chatboxWidth)}px`}}
        className="h-full border-r flex flex-col overflow-hidden relative shrink-0"
      >
        <Client__Chatbox />
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
      <div className="grow h-full min-w-0">
        <Client__WebPreview />
      </div>
    </div>
  </div>
}
