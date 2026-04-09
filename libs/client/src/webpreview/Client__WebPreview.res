/**
 * Client__WebPreview - Web preview panel
 *
 * Renders the iframe viewport. Nav controls have moved to Client__TopBar.
 */
let // Hook to measure the available space in the viewport container
useContainerSize = (ref: React.ref<Nullable.t<Dom.element>>): (int, int) => {
  let (size, setSize) = React.useState(() => (0, 0))

  React.useEffect(() => {
    switch ref.current->Nullable.toOption {
    | None => None
    | Some(element) =>
      let rect = WebAPI.Element.getBoundingClientRect(element->Obj.magic)
      setSize(_ => (rect.width->Float.toInt, rect.height->Float.toInt))

      let observer = FrontmanBindings.ResizeObserver.make(entries => {
        entries
        ->Array.get(0)
        ->Option.forEach(
          entry => {
            let cr = entry.contentRect
            setSize(_ => (cr.width->Float.toInt, cr.height->Float.toInt))
          },
        )
      })
      observer->FrontmanBindings.ResizeObserver.observe(element)
      Some(() => observer->FrontmanBindings.ResizeObserver.disconnect)
    }
  }, [])

  size
}

@react.component
let make = () => {
  let currentTaskClientId = Client__State.useSelector(Client__State.Selectors.currentTaskClientId)
  let isNewTask = Client__State.useSelector(Client__State.Selectors.isNewTask)
  let persistedTasks = Client__State.useSelector(Client__State.Selectors.tasks)
  let previewFrame = Client__State.useSelector(Client__State.Selectors.previewFrame)
  let deviceMode = Client__State.useSelector(Client__State.Selectors.deviceMode)
  let deviceOrientation = Client__State.useSelector(Client__State.Selectors.deviceOrientation)

  let containerRef: React.ref<Nullable.t<Dom.element>> = React.useRef(Nullable.null)
  let (availableWidth, availableHeight) = useContainerSize(containerRef)

  React.useEffect(() => {
    Client__DeviceMode.persist(deviceMode, deviceOrientation)
    None
  }, (deviceMode, deviceOrientation))

  let effectiveDims = Client__DeviceMode.getEffectiveDimensions(deviceMode, deviceOrientation)

  let viewportStyle = switch effectiveDims {
  | None => None
  | Some((deviceWidth, deviceHeight)) =>
    let scale = if availableWidth > 16 && availableHeight > 16 {
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

  <div className="flex flex-col h-full bg-white">
    <Client__WebPreview__DeviceBar deviceMode orientation=deviceOrientation />

    <div
      ref={ReactDOM.Ref.callbackDomRef(el => {
        containerRef.current = el
        None
      })}
      className={switch effectiveDims {
      | None => "relative size-full overflow-y-hidden"
      | Some(
          _,
        ) => "relative size-full overflow-hidden flex items-start justify-center bg-[repeating-conic-gradient(#f3f4f6_0%_25%,#ffffff_0%_50%)] bg-[length:16px_16px]"
      }}
    >
      {switch previewFrame.contentDocument {
      | Some(document) =>
        <Client__WebPreview__Stage document={document} viewportStyle=?viewportStyle />
      | _ => React.null
      }}

      {
        let defaultUrl = Client__BrowserUrl.getInitialUrl()

        let allTasks = if isNewTask {
          Array.concat(
            [(currentTaskClientId, previewFrame.url)],
            persistedTasks->Array.map(task => {
              let clientId = Client__Task__Types.Task.getClientId(task)
              let taskPreviewFrame = Client__Task__Types.Task.getPreviewFrame(task, ~defaultUrl)
              (clientId, taskPreviewFrame.url)
            }),
          )
        } else {
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
            viewportStyle=?viewportStyle
          />
        })
        ->React.array
      }
    </div>
  </div>
}
