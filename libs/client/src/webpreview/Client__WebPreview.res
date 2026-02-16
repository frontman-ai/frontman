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

module DeviceModeToggle = {
  @react.component
  let make = (~isActive: bool, ~onClick: unit => unit) => {
    <button
      type_="button"
      onClick={_ => onClick()}
      className={`flex items-center justify-center w-8 h-8 rounded-lg transition-colors
                 ${isActive
          ? "bg-blue-600 text-white hover:bg-blue-500"
          : "bg-gray-200 text-gray-600 hover:bg-gray-300 hover:text-gray-700"}`}
      title={isActive ? "Exit device mode" : "Toggle device mode"}
    >
      <RadixUI__Icons.MobileIcon className="size-4" />
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

// Raw JS binding for ResizeObserver (avoids curried callback complexity in WebAPI binding)
type resizeObserverEntry = {contentRect: WebAPI.DOMAPI.domRectReadOnly}

@new external makeResizeObserver: (array<resizeObserverEntry> => unit) => {..} = "ResizeObserver"

@send external observeElement: ({..}, Dom.element) => unit = "observe"

@send external disconnectObserver: ({..}) => unit = "disconnect"

// Hook to measure the available space in the viewport container
let useContainerSize = (ref: React.ref<Nullable.t<Dom.element>>): (int, int) => {
  let (size, setSize) = React.useState(() => (0, 0))

  React.useEffect(() => {
    switch ref.current->Nullable.toOption {
    | None => None
    | Some(element) =>
      // Initial measurement
      let rect = WebAPI.Element.getBoundingClientRect(element->Obj.magic)
      setSize(_ => (
        rect.width->Float.toInt,
        rect.height->Float.toInt,
      ))

      // Observe resize
      let observer = makeResizeObserver(entries => {
        entries->Array.get(0)->Option.forEach(entry => {
          let cr: WebAPI.DOMAPI.domRectReadOnly = entry.contentRect
          setSize(_ => (
            cr.width->Float.toInt,
            cr.height->Float.toInt,
          ))
        })
      })
      observer->observeElement(element)
      Some(() => observer->disconnectObserver)
    }
  }, [])

  size
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
  let deviceMode = Client__State.useSelector(Client__State.Selectors.deviceMode)
  let deviceOrientation = Client__State.useSelector(Client__State.Selectors.deviceOrientation)

  let containerRef: React.ref<Nullable.t<Dom.element>> = React.useRef(Nullable.null)
  let (availableWidth, availableHeight) = useContainerSize(containerRef)

  // Persist device mode changes to localStorage
  React.useEffect(() => {
    Client__DeviceMode.persist(deviceMode, deviceOrientation)
    None
  }, (deviceMode, deviceOrientation))

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
  let handleToggleDeviceMode = () => Client__State.Actions.toggleDeviceMode()

  let deviceModeActive = Client__DeviceMode.isActive(deviceMode)
  let effectiveDims = Client__DeviceMode.getEffectiveDimensions(deviceMode, deviceOrientation)
  
    <Nav.Container>
      <Nav.Navigation>
        <Nav.TrafficLights />
        <BackButton onClick={handleBack} />
        <ForwardButton onClick={handleForward} />
        <ReloadButton onClick={handleReload} />
        <Nav.UrlInput value={previewUrl} />
        <DeviceModeToggle isActive={deviceModeActive} onClick={handleToggleDeviceMode} />
        <SelectElement onClick={handleSelect} isSelecting={webPreviewIsSelecting} />
        <OpenInNewWindow onClick={handleOpenInNewTab} />
      </Nav.Navigation>

      // Device bar (only when device mode is active)
      <Client__WebPreview__DeviceBar deviceMode orientation=deviceOrientation />

      <div
        ref={ReactDOM.Ref.callbackDomRef(el => {
          containerRef.current = el
          None
        })}
        className={switch effectiveDims {
        | None => "relative size-full overflow-y-hidden"
        | Some(_) =>
          "relative size-full overflow-hidden flex items-start justify-center bg-[repeating-conic-gradient(#f3f4f6_0%_25%,#ffffff_0%_50%)] bg-[length:16px_16px]"
        }}
      >
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

          // Compute scale and dimensions for device mode
          let viewportStyle = switch effectiveDims {
          | None => None
          | Some((deviceWidth, deviceHeight)) =>
            let scale = if availableWidth > 16 && availableHeight > 16 {
              // Leave some padding around the viewport (8px on each side)
              Client__DeviceMode.computeScaleFactor(
                ~deviceWidth,
                ~deviceHeight,
                ~availableWidth=availableWidth - 16,
                ~availableHeight=availableHeight - 16,
              )
            } else {
              1.0
            }
            Some((deviceWidth, deviceHeight, scale))
          }
          
          allTasks
          ->Array.map(((clientId, url)) => {
            <Client__WebPreview__Body
              key={clientId}
              taskId={clientId}
              url={url}
              isActive={clientId == currentTaskClientId}
              viewportStyle=?viewportStyle
            />
          })
          ->React.array
        }
      </div>
    </Nav.Container>
}
