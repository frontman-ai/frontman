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
    | Connecting => ()
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
    }
    None
  }, (connectionState, sendPrompt, cancelPrompt, retryTurn, loadTask, deleteSession, apiBaseUrl))

  // Get resizable width for chatbox panel
  let (chatboxWidth, isResizing, handleResizeMouseDown) = Client__UseResizableWidth.use()

  // FTUE state
  let (ftueState, setFtueState) = React.useState(() => Client__FtueState.get())
  let (showCelebration, setShowCelebration) = React.useState(() => false)
  let (providerNudgeDismissed, setProviderNudgeDismissed) = React.useState(() => false)
  let (nudgeBubbleDismissed, setNudgeBubbleDismissed) = React.useState(() => false)
  let hasProviderConfigured = Client__State.useSelector(
    Client__State.Selectors.hasAnyProviderConfigured,
  )

  // Trigger post-signup celebration when session becomes active for first time after signup
  React.useEffect(() => {
    switch (connectionState, ftueState) {
    | (Connected | SessionActive(_), Client__FtueState.WelcomeShown) =>
      setShowCelebration(_ => true)
      Client__FtueState.setCompleted()
      setFtueState(_ => Client__FtueState.Completed)
    | _ => ()
    }
    None
  }, (connectionState, ftueState))

  let handleCelebrationDismiss = () => {
    setShowCelebration(_ => false)
  }

  let handleCelebrationConnectProvider = () => {
    setShowCelebration(_ => false)
    Client__State.Actions.openSettingsModalOnProviders()
  }

  let showNudge = switch (ftueState, hasProviderConfigured, providerNudgeDismissed) {
  | (Client__FtueState.Completed, false, false) => true
  | _ => false
  }
  let showProviderNudgeBubble = showNudge && !nudgeBubbleDismissed
  let showProviderNudgeBadge = showNudge && nudgeBubbleDismissed

  let handleProviderNudgeDismiss = () => {
    setNudgeBubbleDismissed(_ => true)
  }

  let handleProviderNudgeCta = () => {
    setProviderNudgeDismissed(_ => true)
    Client__State.Actions.openSettingsModalOnProviders()
  }

  <div className="flex flex-col h-screen w-screen bg-background text-foreground">
    <SettingsModal />
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
      onSettingsClick={() => Client__State.Actions.openSettingsModal()}
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
        <Client__Chatbox onConfigureProvider=openSettingsProviders />
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
