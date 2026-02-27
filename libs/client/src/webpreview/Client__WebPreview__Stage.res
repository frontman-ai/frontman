@react.component
let make = (~document, ~viewportStyle: option<(int, int, float)>=?) => {
  let document = Some(document)
  let webPreviewIsSelecting = Client__State.useSelector(
    Client__State.Selectors.webPreviewIsSelecting,
  )
  let selectedElement = Client__State.useSelector(Client__State.Selectors.selectedElement)
  let isAgentRunning = Client__State.useSelector(Client__State.Selectors.isAgentRunning)

  let lastProcessedClickId = React.useRef(-1)
  let wasSelecting = React.useRef(false)

  let scrollTimestamp = Client__Hooks.Scroll.useIFrameDocument(~document, ~withCapture=true, ())
  let mutationTimestamp = Client__Hooks.DOMmutations.useIFrameDocument(~document, ())
  let clickedElement = Client__Hooks.MouseClick.useIFrameDocument(
    ~document,
    ~withCapture=webPreviewIsSelecting,
    ~preventDefault=webPreviewIsSelecting,
    ~stopPropagation=webPreviewIsSelecting,
    ~stopImmediatePropagation=webPreviewIsSelecting,
    (),
  )
  let hoveredElement = Client__Hooks.MouseMove.useIFrameDocument(~document, ~withCapture=true, ())

  // Split effect: Handle mode transitions separately from click handling
  // This prevents unnecessary effect runs when only clickedElement changes
  React.useEffect1(() => {
    if webPreviewIsSelecting && !wasSelecting.current {
      // Entering selection mode — mark current click as already processed
      // so we don't re-handle a stale click from before selection mode
      let currentId = clickedElement->Option.mapOr(-1, click => click.clickId)
      lastProcessedClickId.current = currentId
      wasSelecting.current = true
    } else if !webPreviewIsSelecting && wasSelecting.current {
      // Exiting selection mode
      wasSelecting.current = false
    }
    None
  }, [webPreviewIsSelecting])

  // Separate effect for handling clicks in selection mode
  React.useEffect2(() => {
    if webPreviewIsSelecting {
      clickedElement->Option.forEach(({target, clickId}) => {
        let isNewClick = clickId > lastProcessedClickId.current

        if isNewClick {
          lastProcessedClickId.current = clickId
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

  // Set crosshair cursor on all iframe elements during selection mode.
  // Uses an injected <style> tag with `* { cursor: crosshair !important; }` so that
  // interactive elements (buttons, links, inputs) can't override the crosshair cursor.
  React.useEffect1(() => {
    if webPreviewIsSelecting {
      document->Option.forEach(doc => {
        let styleEl = WebAPI.Document.createElement(doc, "style")
        WebAPI.Element.setAttribute(styleEl, ~qualifiedName="data-frontman-cursor", ~value="true")
        styleEl.textContent = Value("* { cursor: crosshair !important; }")
        doc.head->WebAPI.HTMLHeadElement.appendChild(styleEl)->ignore
      })
    } else {
      document->Option.forEach(doc => {
        doc
        ->WebAPI.Document.querySelector("[data-frontman-cursor]")
        ->Null.toOption
        ->Option.forEach(el => {
          el->WebAPI.Element.remove
        })
      })
    }

    Some(
      () => {
        document->Option.forEach(doc => {
          doc
          ->WebAPI.Document.querySelector("[data-frontman-cursor]")
          ->Null.toOption
          ->Option.forEach(el => {
            el->WebAPI.Element.remove
          })
        })
      },
    )
  }, [webPreviewIsSelecting])

  // Selection overlay container
  // In device mode, the overlay must match the iframe's position and transform
  // so that getBoundingClientRect coordinates from inside the iframe align visually
  let selectionModeIndicator = webPreviewIsSelecting
    ? <div
        className="absolute inset-0 pointer-events-none"
        style={
          boxShadow: "inset 0 0 0 2px rgba(152, 93, 247, 0.5)",
          borderRadius: "0",
        }
      />
    : React.null

  let hoverOverlay = webPreviewIsSelecting
    ? <Client__WebPreview__HoveredElement
        key="hover" element={hoveredElement} scrollTimestamp={scrollTimestamp}
      />
    : React.null

  let clickOverlay = selectedElement->Option.mapOr(React.null, data => {
    // Re-query element from current document to handle stale DOM references
    // (e.g., after iframe remount during New → Loaded task transition)
    let element = switch (data.selector, document) {
    | (Some(sel), Some(doc)) =>
      WebAPI.Document.querySelector(doc, sel)->Null.toOption->Option.getOr(data.element)
    | _ => data.element
    }
    <Client__WebPreview__ClickedElement
      key="clicked"
      element={element}
      scrollTimestamp={scrollTimestamp}
      mutationTimestamp={mutationTimestamp}
      isScanning={isAgentRunning}
    />
  })

  switch viewportStyle {
  | None =>
    <div className="pointer-events-none flex-1 absolute top-0 left-0 w-full h-full isolate">
      selectionModeIndicator
      hoverOverlay
      clickOverlay
    </div>
  | Some((deviceWidth, deviceHeight, scale)) =>
    let widthPx = Int.toString(deviceWidth) ++ "px"
    let heightPx = Int.toString(deviceHeight) ++ "px"
    let transformStr = if scale < 1.0 {
      `scale(${Float.toFixed(scale, ~digits=4)})`
    } else {
      "none"
    }
    // Outer: fills the container, uses flex centering to match the iframe's position
    <div
      className="pointer-events-none absolute top-0 left-0 w-full h-full isolate flex items-start justify-center"
    >
      // Inner: matches the iframe wrapper's exact dimensions, transform, and offset
      <div
        className="shrink-0 mt-2 relative overflow-hidden"
        style={
          width: widthPx,
          height: heightPx,
          transform: transformStr,
          transformOrigin: "top center",
        }
      >
        selectionModeIndicator
        hoverOverlay
        clickOverlay
      </div>
    </div>
  }
}
