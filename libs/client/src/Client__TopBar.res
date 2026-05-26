module Icons = FrontmanBindings.Bindings__RadixUI__Icons
module Button = FrontmanBindings.Bindings__UI__Button
module Tooltip = FrontmanBindings.Bindings__UI__Tooltip
module FrontmanLogo = Client__FrontmanLogo

@send external locationAssign: ('a, string) => unit = "assign"
@send external blur: Dom.element => unit = "blur"

@react.component
let make = (
  ~chatboxWidth: int,
  ~onSettingsClick: unit => unit,
  ~showProviderNudgeBubble: bool=false,
  ~showProviderNudgeBadge: bool=false,
  ~onProviderNudgeDismiss: unit => unit=() => (),
  ~onProviderNudgeCta: unit => unit=() => (),
) => {
  let isAgentRunning = Client__State.useSelector(Client__State.Selectors.isAgentRunning)
  let isNewTask = Client__State.useSelector(Client__State.Selectors.isNewTask)
  let previewUrl = Client__State.useSelector(Client__State.Selectors.previewUrl)
  let previewFrame = Client__State.useSelector(Client__State.Selectors.previewFrame)
  let deviceMode = Client__State.useSelector(Client__State.Selectors.deviceMode)

  let {clearSession} = Client__FrontmanProvider.useFrontman()

  // URL editing local state (moved here from Client__WebPreview)
  let (editableUrl, setEditableUrl) = React.useState(() => previewUrl)
  let (isEditingUrl, setIsEditingUrl) = React.useState(() => false)

  let displayedUrl = switch isEditingUrl {
  | true => editableUrl
  | false => previewUrl
  }

  let handleUrlChange = (e: ReactEvent.Form.t) => {
    let value = (e->ReactEvent.Form.target)["value"]
    setEditableUrl(_ => value)
  }

  let handleUrlKeyDown = (e: ReactEvent.Keyboard.t) => {
    switch ReactEvent.Keyboard.key(e) {
    | "Enter" =>
      switch Client__BrowserUrl.resolveUrlWithBase(~url=editableUrl, ~base=previewUrl) {
      | None => ()
      | Some(resolvedUrl) =>
        switch Client__BrowserUrl.isSameOriginWithBase(
          ~baseUrl=previewUrl,
          ~targetUrl=resolvedUrl,
        ) {
        | false => ()
        | true =>
          previewFrame.contentWindow->Option.forEach(contentWindow => {
            contentWindow.location->locationAssign(resolvedUrl)
          })
          Client__State.Actions.setPreviewUrl(~url=resolvedUrl)
          Client__State.Actions.clearAnnotations()
          Client__BrowserUrl.syncBrowserUrl(~previewUrl=resolvedUrl)
        }
      }
      let target: Dom.element = ReactEvent.Keyboard.target(e)->Obj.magic
      target->blur
    | "Escape" =>
      let target: Dom.element = ReactEvent.Keyboard.target(e)->Obj.magic
      target->blur
    | _ => ()
    }
  }

  let handleUrlFocus = (_e: ReactEvent.Focus.t) => {
    setIsEditingUrl(_ => true)
    setEditableUrl(_ => previewUrl)
  }

  let handleUrlBlur = (_e: ReactEvent.Focus.t) => {
    setIsEditingUrl(_ => false)
  }

  let handleReload = () => {
    previewFrame.contentWindow->Option.forEach(contentWindow => {
      WebAPI.Location.reload(contentWindow.location)
    })
    Client__State.Actions.clearAnnotations()
  }

  let handleNewTask = () => {
    if !isNewTask {
      clearSession()
      Client__State.Actions.clearCurrentTask()
    }
  }

  let deviceModeActive = Client__DeviceMode.isActive(deviceMode)
  let iconSize = {"width": "14px", "height": "14px"}
  let iconBtnCls = "cursor-pointer h-7 w-7 p-0 text-zinc-400"

  <div className="h-8 flex items-center shrink-0 bg-[#130d20] border-b border-[#1e1538]">
    // LEFT ZONE — width tracks the resizable chat panel
    <div
      style={{width: `${Int.toString(chatboxWidth >= 240 ? chatboxWidth : 240)}px`}}
      className="flex items-center h-full shrink-0 px-1 gap-1 overflow-hidden"
    >
      <div className="flex items-center justify-center w-7 h-7 shrink-0">
        <FrontmanLogo size=18 className={isAgentRunning ? "frontman-logo-pulse" : ""} />
      </div>
      <Client__TopBar__TaskDropdown onNewTask={handleNewTask} />
    </div>
    // Vertical divider — visually continues the panel border below
    <div className="w-px h-full bg-[#1e1538] shrink-0" />
    // RIGHT ZONE — takes remaining space
    <div className="flex items-center h-full flex-1 min-w-0 px-1 gap-1">
      // Reload
      <Tooltip.Tooltip>
        <Tooltip.TooltipTrigger asChild=true>
          <Button.Button variant=#ghost size=#sm onClick={_ => handleReload()} className=iconBtnCls>
            <Icons.ReloadIcon style={iconSize} />
          </Button.Button>
        </Tooltip.TooltipTrigger>
        <Tooltip.TooltipContent sideOffset=4> {React.string("Reload")} </Tooltip.TooltipContent>
      </Tooltip.Tooltip>
      // Open in new window
      <Tooltip.Tooltip>
        <Tooltip.TooltipTrigger asChild=true>
          <Button.Button
            variant=#ghost
            size=#sm
            onClick={_ =>
              WebAPI.Window.open_(
                WebAPI.Global.window,
                ~url=previewUrl,
                ~target="_blank",
                ~features="noopener,noreferrer",
              )->ignore}
            className=iconBtnCls
          >
            <Icons.OpenInNewWindowIcon style={iconSize} />
          </Button.Button>
        </Tooltip.TooltipTrigger>
        <Tooltip.TooltipContent sideOffset=4>
          {React.string("Open in new window")}
        </Tooltip.TooltipContent>
      </Tooltip.Tooltip>
      // URL bar
      <input
        type_="text"
        value={displayedUrl}
        onChange={handleUrlChange}
        onKeyDown={handleUrlKeyDown}
        onFocus={handleUrlFocus}
        onBlur={handleUrlBlur}
        className="flex-1 min-w-0 h-6 px-2 text-xs bg-white/5 border border-white/10 rounded text-zinc-300 placeholder-zinc-600 focus:outline-none focus:ring-1 focus:ring-violet-500/50 focus:border-violet-500/50"
      />
      // Device mode toggle
      <Tooltip.Tooltip>
        <Tooltip.TooltipTrigger asChild=true>
          <Button.Button
            variant=#ghost
            size=#sm
            onClick={_ => Client__State.Actions.toggleDeviceMode()}
            className={`cursor-pointer h-7 w-7 p-0 ${deviceModeActive
                ? "bg-blue-500/15 text-blue-400 rounded"
                : "text-zinc-400"}`}
          >
            <Icons.MobileIcon style={iconSize} />
          </Button.Button>
        </Tooltip.TooltipTrigger>
        <Tooltip.TooltipContent sideOffset=4>
          {React.string(deviceModeActive ? "Exit device mode" : "Toggle device mode")}
        </Tooltip.TooltipContent>
      </Tooltip.Tooltip>
      // Help
      <Tooltip.Tooltip>
        <Tooltip.TooltipTrigger asChild=true>
          <Button.Button
            variant=#ghost
            size=#sm
            onClick={_ =>
              WebAPI.Window.open_(
                WebAPI.Global.window,
                ~url="https://frontman.sh/docs",
                ~target="_blank",
                ~features="noopener,noreferrer",
              )->ignore}
            className=iconBtnCls
          >
            <Icons.QuestionMarkCircledIcon style={iconSize} />
          </Button.Button>
        </Tooltip.TooltipTrigger>
        <Tooltip.TooltipContent sideOffset=4> {React.string("Help")} </Tooltip.TooltipContent>
      </Tooltip.Tooltip>
      // Settings gear with optional provider nudge
      <div className="relative">
        <Tooltip.Tooltip>
          <Tooltip.TooltipTrigger asChild=true>
            <Button.Button
              variant=#ghost size=#sm onClick={_ => onSettingsClick()} className=iconBtnCls
            >
              <Icons.GearIcon style={iconSize} />
              {switch showProviderNudgeBadge {
              | true =>
                <span
                  className="absolute -top-0.5 -right-0.5 size-2 rounded-full bg-violet-500 ring-2 ring-zinc-900"
                />
              | false => React.null
              }}
            </Button.Button>
          </Tooltip.TooltipTrigger>
          <Tooltip.TooltipContent sideOffset=4> {React.string("Settings")} </Tooltip.TooltipContent>
        </Tooltip.Tooltip>
        {switch showProviderNudgeBubble {
        | true =>
          <Client__ProviderNudgeBubble
            onOpenSettings=onProviderNudgeCta onDismiss=onProviderNudgeDismiss
          />
        | false => React.null
        }}
      </div>
    </div>
  </div>
}
