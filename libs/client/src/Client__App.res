module SettingsModal = Client__SettingsModal

@react.component
let make = () => {
  let authRedirectUrl = Client__State.useSelector(Client__State.Selectors.getAuthRedirectUrl)

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

  let settingsTab = Client__State.useSelector(Client__State.Selectors.settingsModalTab)
  let settingsOpen = settingsTab->Option.isSome
  let settingsInitialTab = settingsTab->Option.map(tab =>
    switch tab {
    | General => "general"
    | Providers => "providers"
    | Billing => "billing"
    }
  )
  let billingStatus = Client__State.useSelector(Client__State.Selectors.billingStatus)
  let billingAccessAllowed = Client__State.useSelector(Client__State.Selectors.billingAccessAllowed)

  React.useEffect(() => {
    switch billingStatus {
    | Client__Billing.Loaded(status)
      if !Client__Billing.isAccessAllowed(status) &&
      Client__Billing.pretrialRunsRemaining(status)->Option.isNone =>
      Client__State.Actions.openSettingsModalOnBilling()
    | _ => ()
    }
    None
  }, [billingStatus])

  let providerSetupRequired = Client__State.useSelector(
    Client__State.Selectors.providerSetupRequired,
  )

  let openSettingsProviders = () => Client__State.Actions.openSettingsModalOnProviders()

  let showProviderSetupModal = providerSetupRequired && !settingsOpen && billingAccessAllowed

  let handleSettingsOpenChange = (value: bool) => {
    switch value {
    | false => Client__State.Actions.closeSettingsModal()
    | true => Client__State.Actions.openSettingsModal()
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
    | Some(loginUrl) =>
      <Client__WelcomeModal
        loginUrl onSignIn={() => Client__State.Actions.connection(RetryAuthentication)}
      />
    | None => React.null
    }}
    <Client__TopBar
      chatboxWidth
      chatOpen
      workspaceView
      onWorkspaceViewChange={view => setSelectedWorkspaceView(_ => view)}
      onToggleChat={() => setChatOpen(prev => !prev)}
      onSettingsClick={() => Client__State.Actions.openSettingsModal()}
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
