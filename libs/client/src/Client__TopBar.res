module Icons = Client__UI__Icons
module ToolIcons = Client__ToolIcons
module Button = Client__UI__Button
module Tooltip = Client__UI__Tooltip
module FrontmanLogo = Client__FrontmanLogo

let renderToolbarButton = (~label, ~onClick, ~children, ~className="") =>
  <Tooltip>
    <Tooltip.Trigger
      render={<Button variant=Button.Variant.Ghost size=Button.Size.IconSm className onClick />}
    >
      {children}
    </Tooltip.Trigger>
    <Tooltip.Content sideOffset=4.> {React.string(label)} </Tooltip.Content>
  </Tooltip>

@react.component
let make = (
  ~chatboxWidth: int,
  ~chatOpen: bool=true,
  ~workspaceView: Client__WorkspacePanel.view,
  ~onWorkspaceViewChange: Client__WorkspacePanel.view => unit,
  ~onToggleChat: unit => unit=() => (),
  ~onSettingsClick: unit => unit,
) => {
  let isAgentRunning = Client__State.useSelector(Client__State.Selectors.isAgentRunning)
  let isNewTask = Client__State.useSelector(Client__State.Selectors.isNewTask)
  let previewUrl = Client__State.useSelector(Client__State.Selectors.previewUrl)
  let previewFrame = Client__State.useSelector(Client__State.Selectors.previewFrame)
  let deviceMode = Client__State.useSelector(Client__State.Selectors.deviceMode)
  let webPreviewIsTextEditing = Client__State.useSelector(
    Client__State.Selectors.webPreviewIsTextEditing,
  )
  let completedFileChanges = Client__State.useSelector(Client__State.Selectors.completedFileChanges)
  let supportsChanges =
    Client__RuntimeConfig.read().framework->Client__RuntimeConfig.supportsFileChanges
  let fileChangeCount = Array.length(completedFileChanges.files)

  let {clearSession} = Client__FrontmanProvider.useFrontman()

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
            contentWindow->WebAPI.Window.location->WebAPI.Location.assign(resolvedUrl)
          })
          Client__State.Actions.setCurrentPreviewUrl(~url=resolvedUrl)
        }
      }
      ReactEvent.Keyboard.currentTarget(e)["blur"]()
    | "Escape" => ReactEvent.Keyboard.currentTarget(e)["blur"]()
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
      contentWindow->WebAPI.Window.location->WebAPI.Location.reload
    })
    Client__State.Actions.clearAnnotations()
  }

  let handleNewTask = () => {
    onWorkspaceViewChange(Client__WorkspacePanel.Preview)
    switch isNewTask {
    | false =>
      clearSession()
      Client__State.Actions.clearCurrentTask()
    | true => ()
    }
    Client__PromptEditor.focus()
  }

  let deviceModeActive = Client__DeviceMode.isActive(deviceMode)

  <Tooltip.Provider>
    <div className="h-8 flex items-center shrink-0 bg-[#130d20] border-b border-[#1e1538]">
      <div
        style={{
          width: chatOpen ? `${Int.toString(chatboxWidth >= 240 ? chatboxWidth : 240)}px` : "auto",
        }}
        className="flex items-center h-full shrink-0 px-1 gap-1 overflow-hidden"
      >
        {switch chatOpen {
        | true =>
          <>
            <div className="flex items-center justify-center w-7 h-7 shrink-0">
              <FrontmanLogo size=18 className={isAgentRunning ? "frontman-logo-pulse" : ""} />
            </div>
            <div className="flex flex-1 min-w-0 items-center gap-0.5 overflow-hidden">
              <Client__TopBar__TaskDropdown onNewTask={handleNewTask} />
            </div>
          </>
        | false => React.null
        }}
        <Client__ChatToggle chatOpen onToggle=onToggleChat isAgentRunning />
      </div>
      <div className="w-px h-full bg-[#1e1538] shrink-0" />
      <div className="flex items-center h-full flex-1 min-w-0 px-1 gap-1">
        {renderToolbarButton(
          ~label=switch webPreviewIsTextEditing {
          | true => "Stop editing text"
          | false => "Edit text directly in the preview"
          },
          ~onClick=_ => Client__State.Actions.toggleTextEditMode(),
          ~className=switch webPreviewIsTextEditing {
          | true => "bg-violet-500/15 text-violet-300"
          | false => ""
          },
          ~children=<ToolIcons.PencilIcon size=13 />,
        )}
        <Client__WorkspaceTabs
          view=workspaceView fileChangeCount supportsChanges onViewChange=onWorkspaceViewChange
        />
        <Client__TopBar__WorkspaceControls
          view=workspaceView
          fileChangeCount
          isAgentRunning
          previewControls={<>
            {renderToolbarButton(
              ~label="Reload",
              ~onClick=_ => handleReload(),
              ~children=<Icons.ReloadIcon />,
            )}
            {renderToolbarButton(
              ~label="Open in new window",
              ~onClick=_ =>
                WebAPI.Window.open_(
                  WebAPI.Window.current,
                  ~url=previewUrl,
                  ~target="_blank",
                  ~features="noopener,noreferrer",
                )->ignore,
              ~children=<Icons.OpenInNewWindowIcon />,
            )}
            <input
              type_="text"
              value={displayedUrl}
              onChange={handleUrlChange}
              onKeyDown={handleUrlKeyDown}
              onFocus={handleUrlFocus}
              onBlur={handleUrlBlur}
              className="flex-1 min-w-0 h-6 px-2 text-xs bg-white/5 border border-white/10 rounded text-zinc-300 placeholder-zinc-600 focus:outline-none focus:ring-1 focus:ring-violet-500/50 focus:border-violet-500/50"
            />
            {renderToolbarButton(
              ~label=deviceModeActive ? "Exit device mode" : "Toggle device mode",
              ~onClick=_ => Client__State.Actions.toggleDeviceMode(),
              ~className=deviceModeActive ? "bg-blue-500/15 text-blue-400" : "",
              ~children=<Icons.MobileIcon />,
            )}
          </>}
        />
        {renderToolbarButton(
          ~label="Help",
          ~onClick=_ =>
            WebAPI.Window.open_(
              WebAPI.Window.current,
              ~url="https://frontman.sh/docs",
              ~target="_blank",
              ~features="noopener,noreferrer",
            )->ignore,
          ~children=<Icons.QuestionMarkCircledIcon />,
        )}
        <div className="relative">
          {renderToolbarButton(
            ~label="Settings",
            ~onClick=_ => onSettingsClick(),
            ~children=<Icons.GearIcon />,
          )}
        </div>
      </div>
    </div>
  </Tooltip.Provider>
}
