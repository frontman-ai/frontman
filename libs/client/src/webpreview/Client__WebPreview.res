/**
 * Client__WebPreview - Web preview panel with navigation
 * 
 * Uses pure ReScript navigation components instead of AIElements.
 */

module Nav = Client__WebPreview__Nav
module RadixUI__Icons = Bindings__RadixUI__Icons

module BackButton = {
  @react.component
  let make = (~onClick: unit => unit) => {
    <Nav.NavButton onClick={onClick} tooltip="Go back">
      <RadixUI__Icons.ArrowLeftIcon className="size-4" />
    </Nav.NavButton>
  }
}

module ForwardButton = {
  @react.component
  let make = (~onClick: unit => unit) => {
    <Nav.NavButton onClick={onClick} tooltip="Go forward">
      <RadixUI__Icons.ArrowRightIcon className="size-4" />
    </Nav.NavButton>
  }
}

module ReloadButton = {
  @react.component
  let make = (~onClick: unit => unit) => {
    <Nav.NavButton onClick={onClick} tooltip="Reload">
      <RadixUI__Icons.ReloadIcon className="size-4" />
    </Nav.NavButton>
  }
}

module SelectElement = {
  @react.component
  let make = (~onClick: unit => unit, ~isSelecting: bool) => {
    <button
      type_="button"
      onClick={_ => onClick()}
      className={`flex items-center justify-center w-8 h-8 rounded-lg transition-colors
                 ${isSelecting
          ? "bg-violet-600 text-white hover:bg-violet-500"
          : "bg-gray-200 text-gray-600 hover:bg-gray-300 hover:text-gray-700"}`}
      title={isSelecting ? "Exit selection mode" : "Select element"}
    >
      <Client__ToolIcons.CursorClickIcon size=16 />
    </button>
  }
}

module OpenInNewWindow = {
  @react.component
  let make = (~onClick: unit => unit) => {
    <button
      type_="button"
      onClick={_ => onClick()}
      className="flex items-center justify-center w-8 h-8 rounded-lg
                 bg-gray-200 text-gray-600 hover:bg-gray-300 hover:text-gray-700
                 transition-colors"
      title="Open in new tab"
    >
      <RadixUI__Icons.OpenInNewWindowIcon className="size-4" />
    </button>
  }
}

@react.component
let make = () => {
  // Use primitive selectors for efficient comparison (strings compare by value)
  let currentTaskClientId = Client__State.useSelector(Client__State.Selectors.currentTaskClientId)
  let isNewTask = Client__State.useSelector(Client__State.Selectors.isNewTask)
  let persistedTasks = Client__State.useSelector(Client__State.Selectors.tasks)
  let previewUrl = Client__State.useSelector(Client__State.Selectors.previewUrl)
  let previewFrame = Client__State.useSelector(Client__State.Selectors.previewFrame)
  let webPreviewIsSelecting = Client__State.useSelector(
    Client__State.Selectors.webPreviewIsSelecting,
  )

  let handleBack = () => {
    previewFrame.contentWindow->Option.forEach(contentWindow => {
      WebAPI.History.back(contentWindow.history)
    })
    Client__State.Actions.setSelectedElement(~selectedElement=None)
  }

  let handleForward = () => {
    previewFrame.contentWindow->Option.forEach(contentWindow => {
      WebAPI.History.forward(contentWindow.history)
    })
    Client__State.Actions.setSelectedElement(~selectedElement=None)
  }

  let handleReload = () => {
    previewFrame.contentWindow->Option.forEach(contentWindow => {
      WebAPI.Location.reload(contentWindow.location)
    })
    Client__State.Actions.setSelectedElement(~selectedElement=None)
  }
  let handleSelect = () => Client__State.Actions.toggleWebPreviewSelection()
  let handleOpenInNewTab = () => {
    WebAPI.Window.open_(
      WebAPI.Global.window,
      ~url=previewUrl,
      ~target="_blank",
      ~features="noopener,noreferrer",
    )->ignore
  }
  
    <Nav.Container>
      <Nav.Navigation>
        <Nav.TrafficLights />
        <BackButton onClick={handleBack} />
        <ForwardButton onClick={handleForward} />
        <ReloadButton onClick={handleReload} />
        <Nav.UrlInput value={previewUrl} />
        <SelectElement onClick={handleSelect} isSelecting={webPreviewIsSelecting} />
        <OpenInNewWindow onClick={handleOpenInNewTab} />
      </Nav.Navigation>

      <div className="relative size-full overflow-y-hidden">
        {switch previewFrame.contentDocument {
        | Some(document) => <Client__WebPreview__Stage document={document} />
        | _ => React.null
        }}

        // Unified array of all iframes - keeps React keys in the same sibling position
        // so switching tasks just toggles isActive prop without unmounting/remounting
        {
          let defaultUrl = Client__State__StateReducer.getInitialUrl()
          
          // Build array of all tasks including New task if present
          let allTasks = if isNewTask {
            // Prepend New task iframe (uses previewFrame from selector)
            Array.concat(
              [(currentTaskClientId, previewFrame.url)],
              persistedTasks->Array.map(task => {
                let clientId = Client__Task__Types.Task.getClientId(task)
                let taskPreviewFrame = Client__Task__Types.Task.getPreviewFrame(task, ~defaultUrl)
                (clientId, taskPreviewFrame.url)
              })
            )
          } else {
            // All tasks are in persistedTasks array
            persistedTasks->Array.map(task => {
              let clientId = Client__Task__Types.Task.getClientId(task)
              let taskPreviewFrame = Client__Task__Types.Task.getPreviewFrame(task, ~defaultUrl)
              (clientId, taskPreviewFrame.url)
            })
          }
          
          allTasks
          ->Array.map(((clientId, url)) => {
            <Client__WebPreview__Body
              key={clientId}
              taskId={clientId}
              url={url}
              isActive={clientId == currentTaskClientId}
            />
          })
          ->React.array
        }
      </div>
    </Nav.Container>
}
