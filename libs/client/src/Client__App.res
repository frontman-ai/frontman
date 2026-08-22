module SettingsModal = Client__SettingsModal

@react.component
let make = (~apiBaseUrl: string) => {
  let {
    connectionState,
    sendPrompt,
    cancelPrompt,
    retryTurn,
    ensureTaskSession,
    deleteSession,
    authRedirectUrl,
    beginAuthenticationRetry,
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
        ~ensureTaskSession,
        ~deleteSession,
        ~apiBaseUrl,
      )
    | LoggingOut | Disconnected | Error(_) => Client__State.Actions.clearAcpSession()
    }
    None
  }, (
    connectionState,
    sendPrompt,
    cancelPrompt,
    retryTurn,
    ensureTaskSession,
    deleteSession,
    apiBaseUrl,
  ))

  let (chatboxWidth, isResizing, handleResizeMouseDown) = Client__UseResizableWidth.use()

  let (chatOpen, setChatOpen) = React.useState(() => true)
  let (selectedWorkspaceView, setSelectedWorkspaceView) = React.useState(() =>
    Client__WorkspacePanel.Preview
  )
  let completedFileChanges = Client__State.useSelector(Client__State.Selectors.completedFileChanges)
  let fileChangeCount = Array.length(completedFileChanges.files)
  let workspaceView = Client__WorkspacePanel.availableView(
    ~view=selectedWorkspaceView,
    ~fileChangeCount,
  )

  React.useEffect(() => {
    switch fileChangeCount {
    | 0 => setSelectedWorkspaceView(_ => Client__WorkspacePanel.Preview)
    | _ => ()
    }
    None
  }, [fileChangeCount])

  let (settingsOpen, setSettingsOpen) = React.useState(() => false)
  let (settingsInitialTab, setSettingsInitialTab) = React.useState(() => None)

  let providerSetupRequired = Client__State.useSelector(
    Client__State.Selectors.providerSetupRequired,
  )

  let openSettingsProviders = () => {
    setSettingsInitialTab(_ => Some("providers"))
    setSettingsOpen(_ => true)
  }

  let showProviderSetupModal = providerSetupRequired && !settingsOpen

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
      open_={showProviderSetupModal} onOpenSettings=openSettingsProviders
    />
    {switch authRedirectUrl {
    | Some(loginUrl) => <Client__WelcomeModal loginUrl onSignIn=beginAuthenticationRetry />
    | None => React.null
    }}
    <Client__TopBar
      chatboxWidth
      chatOpen
      workspaceView
      onWorkspaceViewChange={view => setSelectedWorkspaceView(_ => view)}
      onToggleChat={() => setChatOpen(prev => !prev)}
      onSettingsClick={() => setSettingsOpen(_ => true)}
    />
    <div className="flex flex-1 min-h-0 w-full">
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
            <Client__ConversationPanel onConfigureProvider=openSettingsProviders />
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
        <Client__WorkspacePanel
          view=workspaceView preview={<Client__WebPreview />} changes={<Client__ChangesView />}
        />
      </div>
    </div>
  </div>
}
