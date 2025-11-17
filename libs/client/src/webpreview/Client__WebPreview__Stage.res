@react.component
let make = (~document, ~window) => {
  let document = Some(document)
  let webPreviewIsSelecting = Client__State.useSelector(
    Client__State.Selectors.webPreviewIsSelecting,
  )
  let selectedElement = Client__State.useSelector(Client__State.Selectors.selectedElement)

  let lastProcessedClick = React.useRef(None)
  let wasSelecting = React.useRef(false)

  let scrollTimestamp = Client__Hooks.Scroll.useIFrameDocument(~document, ~withCapture=true, ())
  let mutationTimestamp = Client__Hooks.DOMmutations.useIFrameDocument(~document, ())
  let clickedElement = Client__Hooks.MouseClick.useIFrameDocument(~document, ~withCapture=false, ())
  let hoveredElement = Client__Hooks.MouseMove.useIFrameDocument(~document, ~withCapture=true, ())
  Client__Hooks.Errors.useErrorCollector(
    ~window,
    ~callback=error => {
      Client__State.Actions.addConsoleError(~error)
    },
    (),
  )

  React.useEffect(() => {
    // Handle mode transitions
    let justEnteredSelectionMode = webPreviewIsSelecting && !wasSelecting.current
    let justExitedSelectionMode = !webPreviewIsSelecting && wasSelecting.current

    if justEnteredSelectionMode {
      lastProcessedClick.current = clickedElement
      wasSelecting.current = true
    } else if justExitedSelectionMode {
      lastProcessedClick.current = None
      wasSelecting.current = false
    } else if webPreviewIsSelecting {
      // In selection mode, handle clicks
      clickedElement->Option.forEach(target => {
        let isNewClick = switch (lastProcessedClick.current, clickedElement) {
        | (Some(lastClick), Some(currentClick)) => lastClick !== currentClick
        | (None, Some(_)) => true
        | _ => false
        }

        if isNewClick {
          lastProcessedClick.current = clickedElement
          switch target {
          | Some(eventTarget) => {
              let element = WebAPI.EventTarget.asElement(eventTarget)
              Client__State.Actions.setSelectedElement(
                ~selectedElement=Some({
                  element,
                  selector: None,
                  screenshot: None,
                  sourceLocation: None,
                }),
              )
            }
          | None => Console.error("Element clicked: unknown")
          }
        }
      })
    }
    None
  }, (clickedElement, webPreviewIsSelecting))

  <div className="pointer-events-none flex-1 absolute top-0 left-0 w-full h-full">
    {webPreviewIsSelecting
      ? <Client__WebPreview__HoveredElement
          key="hover" element={hoveredElement} scrollTimestamp={scrollTimestamp}
        />
      : React.null}
    {selectedElement->Option.mapOr(React.null, data =>
      <Client__WebPreview__ClickedElement
        key="clicked"
        element={data.element}
        scrollTimestamp={scrollTimestamp}
        mutationTimestamp={mutationTimestamp}
      />
    )}
  </div>
}
