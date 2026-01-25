@react.component
let make = (~document) => {
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

  // Split effect: Handle mode transitions separately from click handling
  // This prevents unnecessary effect runs when only clickedElement changes
  React.useEffect1(() => {
    if webPreviewIsSelecting && !wasSelecting.current {
      // Entering selection mode
      lastProcessedClick.current = clickedElement
      wasSelecting.current = true
    } else if !webPreviewIsSelecting && wasSelecting.current {
      // Exiting selection mode
      lastProcessedClick.current = None
      wasSelecting.current = false
    }
    None
  }, [webPreviewIsSelecting])

  // Separate effect for handling clicks in selection mode
  React.useEffect2(() => {
    if webPreviewIsSelecting {
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

  // Selection overlay container
  <div className="pointer-events-none flex-1 absolute top-0 left-0 w-full h-full">
    // Selection mode indicator - subtle border around the preview
    {webPreviewIsSelecting
      ? <div
          className="absolute inset-0 pointer-events-none"
          style={
            boxShadow: "inset 0 0 0 2px rgba(59, 130, 246, 0.5)",
            borderRadius: "0",
          }
        />
      : React.null}
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
