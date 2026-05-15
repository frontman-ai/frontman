module Dialog = Client__UI__Dialog
module Icons = Client__UI__Icons
module Tabs = Client__UI__Tabs
module State = Client__State
module Types = Client__State__Types
module GeneralTab = Client__SettingsModal__Tab__General
module ProvidersTab = Client__SettingsModal__Tab__Providers

exception UnknownSettingsTab(string)

let settingsTabValue = tab =>
  switch tab {
  | Types.General => "general"
  | Types.Providers => "providers"
  }

let openSettingsTabValue = value =>
  switch value {
  | "general" => State.Actions.openSettingsModal()
  | "providers" => State.Actions.openSettingsModalOnProviders()
  | value => throw(UnknownSettingsTab(value))
  }

let renderPanel = (~value, ~title, ~description, children) =>
  <Tabs.Content value className="flex min-w-0 flex-1 flex-col overflow-hidden">
    <div className="shrink-0 border-b px-6 py-5">
      <h2 className="text-lg font-semibold"> {React.string(title)} </h2>
      <p className="mt-1 text-sm text-muted-foreground"> {React.string(description)} </p>
    </div>
    <div className="min-h-0 flex-1 overflow-y-auto px-6 py-6"> {children} </div>
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
    <Dialog.Content className="sm:max-w-none max-w-none h-[560px] w-[960px] overflow-hidden p-0">
      <Tabs
        value={settingsTabValue(activeTab)}
        onValueChange={(value, _) => openSettingsTabValue(value)}
        orientation=BaseUi.Types.Orientation.Vertical
        className="h-full min-h-0 overflow-hidden"
      >
        <div className="w-56 border-r px-4 py-5">
          <Dialog.Header className="gap-1">
            <Dialog.Title className="text-lg font-semibold">
              {React.string("Settings")}
            </Dialog.Title>
            <Dialog.Description className="text-xs">
              {React.string(
                "Settings are stored in your browser. API keys are saved to your account.",
              )}
            </Dialog.Description>
          </Dialog.Header>
          <Tabs.List variant=Tabs.Variant.Line className="mt-6 w-full">
            <Tabs.Trigger value={settingsTabValue(Types.General)}>
              <Icons.CubeIcon className="size-4" />
              {React.string("General")}
            </Tabs.Trigger>
            <Tabs.Trigger value={settingsTabValue(Types.Providers)}>
              <Icons.GlobeIcon className="size-4" />
              {React.string("Providers")}
            </Tabs.Trigger>
          </Tabs.List>
        </div>

        {renderPanel(
          ~value=settingsTabValue(Types.General),
          ~title="General",
          ~description="Manage account and environment settings.",
          <GeneralTab />,
        )}
        {renderPanel(
          ~value=settingsTabValue(Types.Providers),
          ~title="Providers",
          ~description="Connect subscriptions or bring your own API keys.",
          <ProvidersTab open_ />,
        )}
      </Tabs>
    </Dialog.Content>
  </Dialog>
}
