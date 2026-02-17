// Nudge bubble shown near the settings icon urging first-time users to connect an AI provider
// Dismissible per session, re-appears on page reload until a provider is configured

module Button = Bindings__UI__Button
module Icons = Bindings__RadixUI__Icons

@react.component
let make = (~onOpenSettings: unit => unit, ~onDismiss: unit => unit) => {
  <div
    className="absolute top-full right-0 mt-2 z-50 animate-in fade-in slide-in-from-top-2 duration-300">
    // Arrow pointing up toward the settings icon
    <div className="absolute -top-1.5 right-3 size-3 rotate-45 border-l border-t border-violet-500/40 bg-zinc-900" />
    <div
      className="w-64 rounded-lg border border-violet-500/30 bg-zinc-900 p-4 shadow-xl shadow-violet-500/5">
      // Close button
      <button
        type_="button"
        className="absolute top-2 right-2 p-1 text-zinc-500 hover:text-zinc-300 transition-colors cursor-pointer"
        onClick={_ => onDismiss()}>
        <Icons.Cross2Icon style={{"width": "12px", "height": "12px"}} />
      </button>
      // Content
      <div className="flex items-start gap-3">
        <div
          className="mt-0.5 flex size-8 shrink-0 items-center justify-center rounded-full bg-violet-500/10 ring-1 ring-violet-500/20">
          <Icons.GlobeIcon style={{"width": "14px", "height": "14px"}} className="text-violet-400" />
        </div>
        <div>
          <p className="text-sm font-medium text-zinc-200">
            {React.string("Connect your AI provider")}
          </p>
          <p className="mt-1 text-xs text-zinc-500 leading-relaxed">
            {React.string("Link Anthropic, OpenAI, or OpenRouter to get started.")}
          </p>
        </div>
      </div>
      <Button.Button
        variant=#secondary
        size=#sm
        className="mt-3 w-full text-xs"
        onClick={_ => onOpenSettings()}>
        {React.string("Open Settings")}
      </Button.Button>
    </div>
  </div>
}
