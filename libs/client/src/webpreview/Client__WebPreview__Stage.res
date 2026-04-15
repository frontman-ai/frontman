module Log = FrontmanLogs.Logs.Make({
  let component = #WebPreviewStage
})

// Typed externals for event casting and missing DOM APIs
external asKeyboardEvent: WebAPI.EventAPI.event => WebAPI.UIEventsAPI.keyboardEvent = "%identity"
external asMouseEvent: WebAPI.EventAPI.event => WebAPI.UIEventsAPI.mouseEvent = "%identity"
external elementFromPoint: (
  WebAPI.DOMAPI.document,
  ~x: int,
  ~y: int,
) => Nullable.t<WebAPI.DOMAPI.element> = "elementFromPoint"

// Find meaningful elements within a drag rectangle
// Returns elements whose bounding rect overlaps the selection rect
let _findElementsInRect: (
  WebAPI.DOMAPI.document,
  float, // x
  float, // y
  float, // width
  float,
) => // height
array<WebAPI.DOMAPI.element> = %raw(`
  function(doc, rx, ry, rw, rh) {
    var meaningfulTags = new Set([
      "A","ABBR","ADDRESS","ARTICLE","ASIDE","AUDIO","B","BLOCKQUOTE",
      "BUTTON","CANVAS","CAPTION","CITE","CODE","DATA","DD","DEL",
      "DETAILS","DFN","DIALOG","DL","DT","EM","FIELDSET","FIGCAPTION",
      "FIGURE","FOOTER","FORM","H1","H2","H3","H4","H5","H6","HEADER",
      "HR","I","IFRAME","IMG","INPUT","INS","KBD","LABEL","LEGEND","LI",
      "MAIN","MARK","MENU","METER","NAV","OL","OPTGROUP","OPTION",
      "OUTPUT","P","PICTURE","PRE","PROGRESS","Q","S","SAMP","SECTION",
      "SELECT","SMALL","SPAN","STRONG","SUB","SUMMARY","SUP","SVG",
      "TABLE","TBODY","TD","TEMPLATE","TEXTAREA","TFOOT","TH","THEAD",
      "TIME","TR","U","UL","VAR","VIDEO"
    ]);
    var all = doc.querySelectorAll("*");
    var results = [];
    var selRight = rx + rw;
    var selBottom = ry + rh;
    for (var i = 0; i < all.length; i++) {
      var el = all[i];
      if (!meaningfulTags.has(el.tagName)) continue;
      // Skip invisible elements
      var style = doc.defaultView.getComputedStyle(el);
      if (style.display === "none" || style.visibility === "hidden" || style.opacity === "0") continue;
      var rect = el.getBoundingClientRect();
      if (rect.width === 0 || rect.height === 0) continue;
      // Check overlap
      if (rect.left < selRight && rect.right > rx && rect.top < selBottom && rect.bottom > ry) {
        results.push(el);
      }
    }
    // Remove elements that are ancestors of other matched elements
    // (prefer more specific/leaf elements)
    var filtered = results.filter(function(el) {
      return !results.some(function(other) {
        return other !== el && el.contains(other);
      });
    });
    return filtered;
  }
`)

// Drag state for rectangle selection
type dragState =
  | Idle
  | Dragging({startX: float, startY: float, currentX: float, currentY: float})

@react.component
let make = (~document, ~viewportStyle: option<(int, int, float)>=?) => {
  let document = Some(document)
  let webPreviewIsSelecting = Client__State.useSelector(
    Client__State.Selectors.webPreviewIsSelecting,
  )
  let annotations = Client__State.useSelector(Client__State.Selectors.annotations)

  let lastProcessedClickId = React.useRef(-1)
  let wasSelecting = React.useRef(false)
  let (dragState, setDragState) = React.useState(() => Idle)
  // Track whether a drag gesture occurred so the click handler can skip it
  let wasDragging = React.useRef(false)
  // Stash elements to dispatch after setDragState updater completes (React purity)
  let pendingDragDispatch: React.ref<
    option<array<Client__Task__Reducer.annotationElement>>,
  > = React.useRef(None)

  let activePopupAnnotationId = Client__State.useSelector(
    Client__State.Selectors.activePopupAnnotationId,
  )

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

  // Escape key exits selection mode (listen on both iframe doc and parent window)
  React.useEffect(() => {
    switch (document, webPreviewIsSelecting) {
    | (Some(doc), true) => {
        let handleKeyDown = ev => {
          let kbEv = ev->asKeyboardEvent
          switch kbEv.key {
          | "Escape" => Client__State.Actions.toggleWebPreviewSelection()
          | _ => ()
          }
        }
        let iframeTarget = doc->WebAPI.Document.asEventTarget
        let windowTarget = WebAPI.Global.window->WebAPI.Window.asEventTarget
        iframeTarget->WebAPI.EventTarget.addEventListener(Keydown, handleKeyDown)
        windowTarget->WebAPI.EventTarget.addEventListener(Keydown, handleKeyDown)
        Some(
          () => {
            iframeTarget->WebAPI.EventTarget.removeEventListener(Keydown, handleKeyDown)
            windowTarget->WebAPI.EventTarget.removeEventListener(Keydown, handleKeyDown)
          },
        )
      }
    | _ => None
    }
  }, (document, webPreviewIsSelecting))

  // Drag selection event listeners (available in Selecting mode with modifier key)
  React.useEffect(() => {
    switch (document, webPreviewIsSelecting) {
    | (Some(doc), true) => {
        let onMouseDown = ev => {
          let mouseEv = ev->asMouseEvent
          // Start drag only with meta+shift (cmd+shift on Mac)
          switch (mouseEv.metaKey, mouseEv.shiftKey) {
          | (true, true) =>
            WebAPI.Event.preventDefault(ev)
            WebAPI.Event.stopPropagation(ev)
            setDragState(_ => Dragging({
              startX: mouseEv.clientX->Int.toFloat,
              startY: mouseEv.clientY->Int.toFloat,
              currentX: mouseEv.clientX->Int.toFloat,
              currentY: mouseEv.clientY->Int.toFloat,
            }))
          | _ => ()
          }
        }

        let onMouseMove = ev => {
          let mouseEv = ev->asMouseEvent
          setDragState(prev =>
            switch prev {
            | Dragging(d) =>
              Dragging({
                ...d,
                currentX: mouseEv.clientX->Int.toFloat,
                currentY: mouseEv.clientY->Int.toFloat,
              })
            | Idle => Idle
            }
          )
        }

        let onMouseUp = _ev => {
          setDragState(prev => {
            switch prev {
            | Dragging({startX, startY, currentX, currentY}) => {
                let x = Math.min(startX, currentX)
                let y = Math.min(startY, currentY)
                let w = Math.abs(currentX -. startX)
                let h = Math.abs(currentY -. startY)

                let viewportWidth = doc.documentElement.clientWidth->Int.toFloat

                switch w > 10.0 && h > 10.0 {
                | true =>
                  // Drag selection: find all meaningful elements in rectangle
                  wasDragging.current = true
                  let foundElements = _findElementsInRect(doc, x, y, w, h)

                  switch Array.length(foundElements) > 0 {
                  | true =>
                    let elements: array<
                      Client__Task__Reducer.annotationElement,
                    > = foundElements->Array.map(
                      el => {
                        let rect = WebAPI.Element.getBoundingClientRect(el)
                        let centerX = rect.left +. rect.width /. 2.0
                        let position: Client__Annotation__Types.position = {
                          xPercent: centerX /. viewportWidth *. 100.0,
                          yAbsolute: rect.top +. rect.height /. 2.0,
                        }
                        {
                          Client__Task__Reducer.element: el,
                          position,
                          tagName: el.tagName,
                        }
                      },
                    )

                    // Stash for dispatch after updater returns (React purity)
                    pendingDragDispatch.current = Some(elements)
                  | false => ()
                  }
                | false =>
                  // Cmd+Shift+Click (no drag): add single element directly
                  wasDragging.current = true
                  let elementAtPoint =
                    doc->elementFromPoint(~x=startX->Float.toInt, ~y=startY->Float.toInt)
                  elementAtPoint
                  ->Nullable.toOption
                  ->Option.forEach(
                    el => {
                      let rect = WebAPI.Element.getBoundingClientRect(el)
                      let centerX = rect.left +. rect.width /. 2.0
                      let position: Client__Annotation__Types.position = {
                        xPercent: centerX /. viewportWidth *. 100.0,
                        yAbsolute: rect.top +. rect.height /. 2.0,
                      }
                      let entry: Client__Task__Reducer.annotationElement = {
                        element: el,
                        position,
                        tagName: el.tagName,
                      }

                      // Stash for dispatch after updater returns (React purity)
                      pendingDragDispatch.current = Some([entry])
                    },
                  )
                }
                Idle
              }
            | Idle => Idle
            }
          })

          // Dispatch outside the setState updater to respect React purity
          switch pendingDragDispatch.current {
          | Some(elements) =>
            pendingDragDispatch.current = None
            Client__State.Actions.addAnnotations(~elements)
          | None => ()
          }
        }

        WebAPI.Document.addEventListener(
          doc,
          Custom("mousedown"),
          onMouseDown,
          ~options={capture: true},
        )
        WebAPI.Document.addEventListener(
          doc,
          Custom("mousemove"),
          onMouseMove,
          ~options={capture: true},
        )
        WebAPI.Document.addEventListener(
          doc,
          Custom("mouseup"),
          onMouseUp,
          ~options={capture: true},
        )

        Some(
          () => {
            WebAPI.Document.removeEventListener(
              doc,
              Custom("mousedown"),
              onMouseDown,
              ~options={capture: true},
            )
            WebAPI.Document.removeEventListener(
              doc,
              Custom("mousemove"),
              onMouseMove,
              ~options={capture: true},
            )
            WebAPI.Document.removeEventListener(
              doc,
              Custom("mouseup"),
              onMouseUp,
              ~options={capture: true},
            )
          },
        )
      }
    | _ => None
    }
  }, (document, webPreviewIsSelecting))

  // Split effect: Handle mode transitions separately from click handling
  // This prevents unnecessary effect runs when only clickedElement changes
  React.useEffect(() => {
    switch (webPreviewIsSelecting, wasSelecting.current) {
    | (true, false) =>
      // Entering selection mode — mark current click as already processed
      // so we don't re-handle a stale click from before selection mode
      let currentId = clickedElement->Option.mapOr(-1, click => click.clickId)
      lastProcessedClickId.current = currentId
      wasSelecting.current = true
    | (false, true) =>
      // Exiting selection mode
      wasSelecting.current = false
    | _ => ()
    }
    None
  }, [webPreviewIsSelecting])

  // Separate effect for handling clicks in selection mode
  React.useEffect(() => {
    switch webPreviewIsSelecting {
    | true =>
      clickedElement->Option.forEach(({target, clickId}) => {
        switch clickId > lastProcessedClickId.current {
        | true =>
          lastProcessedClickId.current = clickId

          // Skip click if it was part of a drag gesture
          switch wasDragging.current {
          | true => wasDragging.current = false
          | false =>
            switch target {
            | Some(eventTarget) => {
                let element = WebAPI.EventTarget.asElement(eventTarget)
                // Compute position from element bounding rect
                let rect = WebAPI.Element.getBoundingClientRect(element)
                let viewportWidth = switch document {
                | Some(doc) => doc.documentElement.clientWidth->Int.toFloat
                | None => 1.0
                }
                let centerX = rect.left +. rect.width /. 2.0
                let position: Client__Annotation__Types.position = {
                  xPercent: centerX /. viewportWidth *. 100.0,
                  yAbsolute: rect.top +. rect.height /. 2.0,
                }
                // Dispatch toggle — reducer handles add/remove and popup state atomically
                Client__State.Actions.toggleAnnotation(
                  ~element,
                  ~position,
                  ~tagName=element.tagName,
                )
              }
            | None => Log.error("Element clicked: unknown")
            }
          }
        | false => ()
        }
      })
    | false => ()
    }
    None
  }, (clickedElement, webPreviewIsSelecting))

  // Set crosshair cursor on all iframe elements during selection mode.
  // Uses an injected <style> tag with `* { cursor: crosshair !important; }` so that
  // interactive elements (buttons, links, inputs) can't override the crosshair cursor.
  React.useEffect(() => {
    switch webPreviewIsSelecting {
    | true =>
      document->Option.forEach(doc => {
        let styleEl = WebAPI.Document.createElement(doc, "style")
        WebAPI.Element.setAttribute(styleEl, ~qualifiedName="data-frontman-cursor", ~value="true")
        styleEl.textContent = Value("* { cursor: crosshair !important; }")
        doc.head->WebAPI.HTMLHeadElement.appendChild(styleEl)->ignore
      })
    | false =>
      document->Option.forEach(doc => {
        doc
        ->WebAPI.Document.querySelector("[data-frontman-cursor]")
        ->Null.toOption
        ->Option.forEach(
          el => {
            el->WebAPI.Element.remove
          },
        )
      })
    }

    Some(
      () => {
        document->Option.forEach(doc => {
          doc
          ->WebAPI.Document.querySelector("[data-frontman-cursor]")
          ->Null.toOption
          ->Option.forEach(
            el => {
              el->WebAPI.Element.remove
            },
          )
        })
      },
    )
  }, [webPreviewIsSelecting])

  // Selection overlay container
  let selectionModeIndicator = switch webPreviewIsSelecting {
  | true =>
    <div
      className="absolute inset-0 pointer-events-none"
      style={
        boxShadow: "inset 0 0 0 2px rgba(152, 93, 247, 0.5)",
        borderRadius: "0",
      }
    />
  | false => React.null
  }

  // Hover highlight (only when in selection mode, but not during drag)
  let hoverOverlay = switch (webPreviewIsSelecting, dragState) {
  | (true, Idle) =>
    <Client__WebPreview__HoveredElement
      key="hover" element={hoveredElement} scrollTimestamp={scrollTimestamp}
    />
  | _ => React.null
  }

  // Drag selection rectangle
  let dragOverlay = switch dragState {
  | Dragging({startX, startY, currentX, currentY}) => {
      let x = Math.min(startX, currentX)
      let y = Math.min(startY, currentY)
      let w = Math.abs(currentX -. startX)
      let h = Math.abs(currentY -. startY)
      <div
        className="absolute border-2 border-violet-400 bg-violet-400/15 rounded-sm pointer-events-none z-[9998]"
        style={
          left: `${Float.toString(x)}px`,
          top: `${Float.toString(y)}px`,
          width: `${Float.toString(w)}px`,
          height: `${Float.toString(h)}px`,
        }
      />
    }
  | Idle => React.null
  }

  // Annotation markers for all confirmed annotations
  let annotationMarkersOverlay =
    <Client__WebPreview__AnnotationMarkers
      annotations={annotations}
      scrollTimestamp={scrollTimestamp}
      mutationTimestamp={mutationTimestamp}
      onRemove={id => Client__State.Actions.removeAnnotation(~id)}
      onNavigate={(id, element) => {
        // Replace the annotation with one for the navigated element
        let rect = WebAPI.Element.getBoundingClientRect(element)
        let viewportWidth = switch document {
        | Some(doc) => doc.documentElement.clientWidth->Int.toFloat
        | None => 1.0
        }
        let centerX = rect.left +. rect.width /. 2.0
        let position: Client__Annotation__Types.position = {
          xPercent: centerX /. viewportWidth *. 100.0,
          yAbsolute: rect.top +. rect.height /. 2.0,
        }
        Client__State.Actions.removeAnnotation(~id)
        Client__State.Actions.addAnnotation(~element, ~position, ~tagName=element.tagName)
      }}
    />

  // Non-blocking comment popup for the active annotation
  let annotationPopupOverlay = {
    let activeAnnotation = switch activePopupAnnotationId {
    | Some(id) => annotations->Array.find(a => a.id == id)
    | None => None
    }

    switch activeAnnotation {
    | Some(annotation) =>
      let index = annotations->Array.findIndex(a => a.id == annotation.id)
      <Client__WebPreview__AnnotationPopup
        annotation={annotation}
        index={index}
        scrollTimestamp={scrollTimestamp}
        mutationTimestamp={mutationTimestamp}
        onCommentChange={comment =>
          Client__State.Actions.updateAnnotationComment(~id=annotation.id, ~comment)}
        onClose={() => Client__State.Actions.closeAnnotationPopup()}
      />
    | None => React.null
    }
  }

  switch viewportStyle {
  | None =>
    <div className="pointer-events-none flex-1 absolute top-0 left-0 w-full h-full isolate">
      selectionModeIndicator
      hoverOverlay
      dragOverlay
      annotationMarkersOverlay
      annotationPopupOverlay
    </div>
  | Some((deviceWidth, deviceHeight, scale)) =>
    let widthPx = Int.toString(deviceWidth) ++ "px"
    let heightPx = Int.toString(deviceHeight) ++ "px"
    let transformStr = switch scale < 1.0 {
    | true => `scale(${Float.toFixed(scale, ~digits=4)})`
    | false => "none"
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
        dragOverlay
        annotationMarkersOverlay
        annotationPopupOverlay
      </div>
    </div>
  }
}
