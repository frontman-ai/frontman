open Bindings__Storybook

module StateTypes = Client__State__Types
module Store = Client__State__Store

let _forceState = (state: StateTypes.state) => {
  StateStore.forceSetStateOnlyUseForTestingDoNotUseOtherwiseAtAll(Store.store, state)
}

module Fixtures = {
  let emptyState: StateTypes.state = {
    tasks: Dict.make(),
    currentTask: StateTypes.Task.New(StateTypes.Task.makeNew(~previewUrl="http://localhost:3000")),
    acpSession: NoAcpSession,
    sessionInitialized: false,
    usageInfo: None,
    userProfile: None,
    openrouterKeySettings: {source: StateTypes.None, saveStatus: StateTypes.Idle},
    anthropicKeySettings: {source: StateTypes.None, saveStatus: StateTypes.Idle},
    anthropicOAuthStatus: StateTypes.NotConnected,
    chatgptOAuthStatus: StateTypes.ChatGPTNotConnected,
    configOptions: None,
    selectedModelValue: None,
    pendingProviderAutoSelect: None,
    sessionsLoadState: StateTypes.SessionsNotLoaded,
    updateInfo: None,
    updateCheckStatus: StateTypes.UpdateNotChecked,
    updateBannerDismissed: false,
  }
}

module ContextWrapper = {
  @react.component
  let make = (~children) => {
    <Client__FrontmanProvider.ContextProvider value={Client__FrontmanProvider.defaultContextValue}>
      {children}
    </Client__FrontmanProvider.ContextProvider>
  }
}

type args = unit

let default: Meta.t<args> = {
  title: "Components/TopBar",
  component: Obj.magic(Client__TopBar.make),
  tags: ["autodocs"],
  decorators: [Decorators.darkBackground],
}

let defaultBar: Story.t<args> = {
  name: "Default (no workspaces)",
  render: _ => {
    React.useEffect0(() => {
      _forceState(Fixtures.emptyState)
      Some(() => Client__StateSnapshot__Storybook.resetState())
    })
    <ContextWrapper>
      <div style={{width: "900px"}}>
        <Client__TopBar
          chatboxWidth=400
          onSettingsClick={() => ()}
          showProviderNudgeBubble=false
          showProviderNudgeBadge=false
          onProviderNudgeDismiss={() => ()}
          onProviderNudgeCta={() => ()}
        />
      </div>
    </ContextWrapper>
  },
}

let withNudge: Story.t<args> = {
  name: "With Provider Nudge",
  render: _ => {
    React.useEffect0(() => {
      _forceState(Fixtures.emptyState)
      Some(() => Client__StateSnapshot__Storybook.resetState())
    })
    <ContextWrapper>
      <div style={{width: "900px"}}>
        <Client__TopBar
          chatboxWidth=400
          onSettingsClick={() => ()}
          showProviderNudgeBubble=true
          showProviderNudgeBadge=false
          onProviderNudgeDismiss={() => ()}
          onProviderNudgeCta={() => ()}
        />
      </div>
    </ContextWrapper>
  },
}

let narrowChatPanel: Story.t<args> = {
  name: "Narrow chat panel (280px)",
  render: _ => {
    React.useEffect0(() => {
      _forceState(Fixtures.emptyState)
      Some(() => Client__StateSnapshot__Storybook.resetState())
    })
    <ContextWrapper>
      <div style={{width: "900px"}}>
        <Client__TopBar
          chatboxWidth=280
          onSettingsClick={() => ()}
          showProviderNudgeBubble=false
          showProviderNudgeBadge=false
          onProviderNudgeDismiss={() => ()}
          onProviderNudgeCta={() => ()}
        />
      </div>
    </ContextWrapper>
  },
}

let withNudgeBadge: Story.t<args> = {
  name: "With Provider Nudge Badge (bubble dismissed)",
  render: _ => {
    React.useEffect0(() => {
      _forceState(Fixtures.emptyState)
      Some(() => Client__StateSnapshot__Storybook.resetState())
    })
    <ContextWrapper>
      <div style={{width: "900px"}}>
        <Client__TopBar
          chatboxWidth=400
          onSettingsClick={() => ()}
          showProviderNudgeBubble=false
          showProviderNudgeBadge=true
          onProviderNudgeDismiss={() => ()}
          onProviderNudgeCta={() => ()}
        />
      </div>
    </ContextWrapper>
  },
}
