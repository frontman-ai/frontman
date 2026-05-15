module Dialog = Client__UI__Dialog
module Icons = Client__UI__Icons
module Tabs = Client__UI__Tabs
module State = Client__State
module Types = Client__State__Types
module GeneralTab = Client__SettingsModal__Tab__General
module ProvidersTab = Client__SettingsModal__Tab__Providers

exception UnknownSettingsTab(string)

type tabDefinition = {
  tab: Types.settingsTab,
  value: string,
  label: string,
  renderIcon: unit => React.element,
}

let tabDefinitions = [
  {
    tab: Types.General,
    value: "general",
    label: "General",
    renderIcon: () => <Icons.CubeIcon className="size-4" />,
  },
  {
    tab: Types.Providers,
    value: "providers",
    label: "Providers",
    renderIcon: () => <Icons.GlobeIcon className="size-4" />,
  },
]

let settingsTabValue = tab =>
  switch tab {
  | Types.General => "general"
  | Types.Providers => "providers"
  }

let openSettingsTab = tab =>
  switch tab {
  | Types.General => State.Actions.openSettingsModal()
  | Types.Providers => State.Actions.openSettingsModalOnProviders()
  }

let openSettingsTabValue = value =>
  switch tabDefinitions->Array.find(definition => definition.value == value) {
  | Some(definition) => openSettingsTab(definition.tab)
  | None => throw(UnknownSettingsTab(value))
  }

let renderTabContent = (~open_, tab) =>
  switch tab {
  | Types.General => <GeneralTab />
  | Types.Providers => <ProvidersTab open_ />
  }

let renderTabTrigger = definition =>
  <Tabs.Trigger key={definition.value} value={definition.value}>
    {definition.renderIcon()}
    {React.string(definition.label)}
  </Tabs.Trigger>

let renderTabPanel = (~open_, definition) =>
  <Tabs.Content
    key={definition.value}
    value={definition.value}
    className="flex-1 overflow-y-auto px-6 pb-6 pt-12"
  >
    {renderTabContent(~open_, definition.tab)}
  </Tabs.Content>

@react.component
let make = () => {
  let settingsModalTab = State.useSelector(State.Selectors.settingsModalTab)
  let open_ = settingsModalTab->Option.isSome
  let activeTab = settingsModalTab->Option.getOr(Types.General)
  let handleOpenChange = (open_, _) =>
    switch open_ {
    | true => State.Actions.openSettingsModal()
    | false => State.Actions.closeSettingsModal()
    }

  <Dialog open_ onOpenChange={handleOpenChange}>
    <Dialog.Content className="sm:max-w-none max-w-none h-[560px] w-[960px] p-0">
      <Dialog.Title className="sr-only"> {React.string("Settings")} </Dialog.Title>
      <Tabs
        value={settingsTabValue(activeTab)}
        onValueChange={(value, _) => openSettingsTabValue(value)}
        orientation=BaseUi.Types.Orientation.Vertical
        className="h-full overflow-hidden"
      >
        <div className="w-56 border-r px-4 py-5">
          <div className="text-lg font-semibold"> {React.string("Settings")} </div>
          <div className="mt-1 text-xs text-muted-foreground">
            {React.string(
              "Settings are stored in your browser. API keys are saved to your account.",
            )}
          </div>
          <Tabs.List variant=Tabs.Variant.Line className="mt-6 w-full">
            {tabDefinitions->Array.map(renderTabTrigger)->React.array}
          </Tabs.List>
        </div>

        {tabDefinitions->Array.map(definition => renderTabPanel(~open_, definition))->React.array}
      </Tabs>
    </Dialog.Content>
  </Dialog>
}
