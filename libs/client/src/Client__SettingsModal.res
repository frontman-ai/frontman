module Dialog = Bindings__UI__Dialog
module Input = Bindings__UI__Input
module Button = Bindings__UI__Button
module Icons = Bindings__RadixUI__Icons
module State = Client__State
module Types = Client__State__Types
module RuntimeConfig = Client__RuntimeConfig

@react.component
let make = (~open_: bool, ~onOpenChange: bool => unit) => {
  let runtimeConfig = RuntimeConfig.read()
  let framework = runtimeConfig.framework->Option.getOr("Unknown")
  let (activeTab, setActiveTab) = React.useState(() => "general")
  let (openrouterKey, setOpenrouterKey) = React.useState(() => "")

  // Get API key settings from state
  let keySettings = State.useSelector(State.Selectors.openrouterKeySettings)

  // Fetch API key settings when modal opens
  React.useEffect(() => {
    if open_ {
      State.Actions.fetchApiKeySettings()
      State.Actions.resetOpenRouterKeySaveStatus()
      setOpenrouterKey(_ => "")
    }
    None
  }, [open_])

  // Determine status label and style based on save status
  let (statusLabel, statusClass) = switch keySettings.saveStatus {
  | Types.Idle => ("", "mt-2 text-xs text-zinc-400")
  | Types.Saving => ("Saving...", "mt-2 text-xs text-zinc-400")
  | Types.Saved => ("Saved", "mt-2 text-xs text-emerald-300")
  | Types.SaveError(msg) => (msg, "mt-2 text-xs text-red-400")
  }

  // Determine placeholder text based on key source
  let placeholder = switch keySettings.source {
  | Types.UserOverride => "Key saved - enter new key to replace"
  | Types.FromEnv => "Using environment key - enter key to override"
  | Types.None => "Enter OpenRouter API key"
  }

  let handleSave = () => {
    let trimmedKey = String.trim(openrouterKey)
    if trimmedKey == "" {
      // Don't save empty keys - this is handled locally since we don't want to dispatch
      ()
    } else {
      State.Actions.saveOpenRouterKey(~key=trimmedKey)
      setOpenrouterKey(_ => "")
    }
  }

  // Render the source badge
  let sourceBadge = switch keySettings.source {
  | Types.UserOverride =>
    <span
      className="rounded-full bg-blue-500/20 px-2 py-0.5 text-[11px] font-semibold text-blue-200">
      {React.string("User key")}
    </span>
  | Types.FromEnv =>
    <span
      className="rounded-full bg-emerald-500/20 px-2 py-0.5 text-[11px] font-semibold text-emerald-200">
      {React.string("From environment")}
    </span>
  | Types.None =>
    <span
      className="rounded-full bg-zinc-700/50 px-2 py-0.5 text-[11px] font-semibold text-zinc-400">
      {React.string("Not configured")}
    </span>
  }

  <Dialog.Dialog open_={open_} onOpenChange={onOpenChange}>
    <Dialog.DialogContent
      className="sm:max-w-none max-w-none h-[560px] w-[960px] p-0" showCloseButton={true}>
      <div className="flex h-full">
        <div className="w-56 border-r border-zinc-800 bg-zinc-950/60 px-4 py-5">
          <div className="text-lg font-semibold text-zinc-100"> {React.string("Settings")} </div>
          <div className="mt-1 text-xs text-zinc-500">
            {React.string(
              "Settings are stored in your browser. API keys are saved to your account.",
            )}
          </div>
          <div className="mt-6 flex flex-col gap-1">
            <button
              type_="button"
              className={activeTab == "general"
                ? "flex items-center gap-2 rounded-md bg-zinc-800 px-3 py-2 text-sm text-zinc-100"
                : "flex items-center gap-2 rounded-md px-3 py-2 text-sm text-zinc-400 hover:bg-zinc-900"}
              onClick={_ => setActiveTab(_ => "general")}>
              <Icons.CubeIcon className="size-4" />
              {React.string("General")}
            </button>
            <button
              type_="button"
              className={activeTab == "providers"
                ? "flex items-center gap-2 rounded-md bg-zinc-800 px-3 py-2 text-sm text-zinc-100"
                : "flex items-center gap-2 rounded-md px-3 py-2 text-sm text-zinc-400 hover:bg-zinc-900"}
              onClick={_ => setActiveTab(_ => "providers")}>
              <Icons.GlobeIcon className="size-4" />
              {React.string("Providers")}
            </button>
          </div>
        </div>

        <div className="flex-1 px-6 py-6 pr-12 overflow-y-auto">
          {activeTab == "general"
            ? <div className="space-y-4">
                <div
                  className="rounded-lg border border-emerald-900/60 bg-emerald-900/20 px-4 py-3 text-sm text-emerald-200">
                  {React.string(`Framework detected: ${framework}`)}
                </div>
              </div>
            : <div className="space-y-6">
                <div className="text-sm text-zinc-400"> {React.string("Bring your own key")} </div>
                <div className="rounded-lg border border-zinc-800 bg-zinc-900/40 px-4 py-4">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      <span className="text-sm font-semibold text-zinc-100">
                        {React.string("OpenRouter")}
                      </span>
                      {sourceBadge}
                    </div>

                    <a
                      href="https://openrouter.ai/keys"
                      target="_blank"
                      rel="noreferrer"
                      className="text-xs text-zinc-400 hover:text-zinc-200">
                      {React.string("Manage keys")}
                    </a>
                  </div>
                  <div className="mt-3 flex items-center gap-3">
                    <Input.Input
                      type_=#password
                      placeholder={placeholder}
                      value={openrouterKey}
                      onChange={e => {
                        let target = ReactEvent.Form.target(e)
                        setOpenrouterKey(_ => target["value"])
                        State.Actions.resetOpenRouterKeySaveStatus()
                      }}
                      className="flex-1 min-w-0"
                    />
                    <Button.Button
                      variant=#secondary
                      onClick={_ => handleSave()}
                      disabled={keySettings.saveStatus == Types.Saving}>
                      {React.string(keySettings.saveStatus == Types.Saving ? "Saving..." : "Save")}
                    </Button.Button>
                  </div>
                  {statusLabel != ""
                    ? <div className={statusClass}> {React.string(statusLabel)} </div>
                    : React.null}
                </div>
              </div>}
        </div>
      </div>
    </Dialog.DialogContent>
  </Dialog.Dialog>
}
