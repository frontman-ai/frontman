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

  // Chat panel open/closed toggle — collapse the chat to see the full preview
  let (chatOpen, setChatOpen) = React.useState(() => true)

  // Settings modal state
  let (settingsOpen, setSettingsOpen) = React.useState(() => false)
  let (settingsInitialTab, setSettingsInitialTab) = React.useState(() => None)

  // FTUE state
  let (ftueState, setFtueState) = React.useState(() => Client__FtueState.get())
  let hasProviderConfigured = Client__State.useSelector(
    Client__State.Selectors.hasAnyProviderConfigured,
  )
  let providerSettingsLoaded = Client__State.useSelector(
    Client__State.Selectors.providerSettingsLoaded,
  )
  let sessionInitialized = Client__State.useSelector(Client__State.Selectors.sessionInitialized)

  // Complete the sign-up flow once the authenticated connection is ready.
  React.useEffect(() => {
    switch (connectionState, ftueState) {
    | (Connected | SessionActive(_), Client__FtueState.WelcomeShown) =>
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

  let showNudge = switch (
    ftueState,
    sessionInitialized,
    providerSettingsLoaded,
    hasProviderConfigured,
  ) {
  | (Client__FtueState.Completed, true, true, false) => true
  | _ => false
  }
  let showProviderSetupModal = showNudge && !settingsOpen

  let handleProviderSetupCta = () => {
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
    <Client__ProviderSetupModal
      open_={showProviderSetupModal} onOpenSettings=handleProviderSetupCta
    />
    // FTUE: Welcome modal for first-time unauthenticated users
    {switch (authRedirectUrl, ftueState) {
    | (Some(loginUrl), Client__FtueState.New) => <Client__WelcomeModal loginUrl />
    | _ => React.null
    }}
    // Top bar (sits above the panel split)
    <Client__TopBar
      chatboxWidth
      chatOpen
      onToggleChat={() => setChatOpen(prev => !prev)}
      onSettingsClick={() => setSettingsOpen(_ => true)}
    />
    // Main content area — flex row of chat + preview panels
    <div className="flex flex-1 min-h-0 w-full">
      // Transparent overlay during resize to prevent iframe from stealing mouse events
      {switch isResizing {
      | true => <div className="fixed inset-0 z-50 cursor-col-resize" />
      | false => React.null
      }}
      {chatOpen
        ? <div
            id="chat-panel"
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
        : React.null}
      <div className="grow h-full min-w-0">
        <Client__WebPreview />
      </div>
    </div>
  </div>
}
