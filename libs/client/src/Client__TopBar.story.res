open Bindings__Storybook

open Client__State__Types

let _forceState = (state: state) => {
  StateStore.forceSetStateOnlyUseForTestingDoNotUseOtherwiseAtAll(Client__State__Store.store, state)
}

module Fixtures = {
  let emptyState: state = {
    ...Client__State__StateReducer.defaultState,
    currentTask: Task.New(Task.makeNew(~previewUrl="http://localhost:3000")),
    selectedModelValue: None,
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

module StateWrapper = {
  @react.component
  let make = (~state: state, ~children) => {
    let (_initialized, _setInitialized) = React.useState(() => {
      _forceState(state)
      true
    })

    React.useEffect0(() => Some(() => Client__StateSnapshot__Storybook.resetState()))

    children
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
    <StateWrapper state={Fixtures.emptyState}>
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
    </StateWrapper>
  },
}

let withNudge: Story.t<args> = {
  name: "With Provider Nudge",
  render: _ => {
    <StateWrapper state={Fixtures.emptyState}>
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
    </StateWrapper>
  },
}

let narrowChatPanel: Story.t<args> = {
  name: "Narrow chat panel (280px)",
  render: _ => {
    <StateWrapper state={Fixtures.emptyState}>
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
    </StateWrapper>
  },
}

let withNudgeBadge: Story.t<args> = {
  name: "With Provider Nudge Badge (bubble dismissed)",
  render: _ => {
    <StateWrapper state={Fixtures.emptyState}>
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
    </StateWrapper>
  },
}
