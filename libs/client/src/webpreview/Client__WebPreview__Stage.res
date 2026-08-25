module Log = FrontmanLogs.Logs.Make({
  let component = #WebPreviewStage
})

external asKeyboardEvent: WebAPI.EventTypes.event => WebAPI.UiEventsTypes.keyboardEvent =
  "%identity"
external asMouseEvent: WebAPI.EventTypes.event => WebAPI.UiEventsTypes.mouseEvent = "%identity"
external elementFromPoint: (
  WebAPI.DomTypes.document,
  ~x: int,
  ~y: int,
) => Nullable.t<WebAPI.DomTypes.element> = "elementFromPoint"

let _findElementsInRect: (
  WebAPI.DomTypes.document,
  float,
  float,
  float,
  float,
) => array<WebAPI.DomTypes.element> = %raw(`
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
      var style = doc.defaultView.getComputedStyle(el);
      if (style.display === "none" || style.visibility === "hidden" || style.opacity === "0") continue;
      var rect = el.getBoundingClientRect();
      if (rect.width === 0 || rect.height === 0) continue;
      if (rect.left < selRight && rect.right > rx && rect.top < selBottom && rect.bottom > ry) {
        results.push(el);
      }
    }
    var filtered = results.filter(function(el) {
      return !results.some(function(other) {
        return other !== el && el.contains(other);
      });
    });
    return filtered;
  }
`)

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
  let wasDragging = React.useRef(false)
  let pendingDragDispatch: React.ref<
    option<array<Client__Task__Reducer.annotationElement>>,
  > = React.useRef(None)

  let activePopupAnnotationId = Client__State.useSelector(
    Client__State.Selectors.activePopupAnnotationId,
  )

  let highlightedAnnotation = Client__State.useSelector(
    Client__State.Selectors.highlightedAnnotation,
  )
  let (highlightedElement, setHighlightedElement) = React.useState((): option<
    WebAPI.DomTypes.element,
  > => None)

  let scrollTimestamp = Client__Hooks.Scroll.useIFrameDocument(~document, ~withCapture=true, ())
  let domMutationTimestamp = Client__Hooks.DOMmutations.useIFrameDocument(~document, ())
  let mutationTimestamp = React.useMemo2(() => Date.now(), (domMutationTimestamp, viewportStyle))
  let clickedElement = Client__Hooks.MouseClick.useIFrameDocument(
    ~document,
    ~withCapture=webPreviewIsSelecting,
    ~preventDefault=webPreviewIsSelecting,
    ~stopPropagation=webPreviewIsSelecting,
    ~stopImmediatePropagation=webPreviewIsSelecting,
    (),
  )
  let hoveredElement = Client__Hooks.MouseMove.useIFrameDocument(~document, ~withCapture=true, ())

  let lastScrolledHighlight = React.useRef(None)

  React.useEffect(() => {
    switch (document, highlightedAnnotation) {
    | (Some(doc), Some({annotationId, selector})) =>
      let (element, _count) = Client__Tool__SelectorResolver.resolveBySelector(~doc, ~selector)
      setHighlightedElement(_ => element)
      switch (element, lastScrolledHighlight.current) {
      | (Some(element), Some((previousId, previousElement)))
        if annotationId == previousId && element === previousElement => ()
      | (Some(element), _) =>
        lastScrolledHighlight.current = Some((annotationId, element))
        element->WebAPI.Element.scrollIntoViewWithOptions({behavior: Smooth, block: Center})
      | (None, _) => lastScrolledHighlight.current = None
      }
    | (None, _) | (_, None) =>
      lastScrolledHighlight.current = None
      setHighlightedElement(_ => None)
    }
    None
  }, (document, highlightedAnnotation, mutationTimestamp))

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
        let windowTarget = WebAPI.Window.current->WebAPI.Window.asEventTarget
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

  React.useEffect(() => {
    switch (document, webPreviewIsSelecting) {
    | (Some(doc), true) => {
        let onMouseDown = ev => {
          let mouseEv = ev->asMouseEvent
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

                switch w > 10.0 && h > 10.0 {
                | true =>
                  wasDragging.current = true
                  let foundElements = _findElementsInRect(doc, x, y, w, h)

                  switch Array.length(foundElements) > 0 {
                  | true =>
                    let elements: array<
                      Client__Task__Reducer.annotationElement,
                    > = foundElements->Array.map(
                      el => {
                        {
                          Client__Task__Reducer.element: el,
                          tagName: el.tagName,
                        }
                      },
                    )

                    pendingDragDispatch.current = Some(elements)
                  | false => ()
                  }
                | false =>
                  wasDragging.current = true
                  let elementAtPoint =
                    doc->elementFromPoint(~x=startX->Float.toInt, ~y=startY->Float.toInt)
                  elementAtPoint
                  ->Nullable.toOption
                  ->Option.forEach(
                    el => {
                      let entry: Client__Task__Reducer.annotationElement = {
                        element: el,
                        tagName: el.tagName,
                      }

                      pendingDragDispatch.current = Some([entry])
                    },
                  )
                }
                Idle
              }
            | Idle => Idle
            }
          })

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

  React.useEffect(() => {
    switch (webPreviewIsSelecting, wasSelecting.current) {
    | (true, false) =>
      let currentId = clickedElement->Option.mapOr(-1, click => click.clickId)
      lastProcessedClickId.current = currentId
      wasSelecting.current = true
    | (false, true) => wasSelecting.current = false
    | _ => ()
    }
    None
  }, [webPreviewIsSelecting])

  React.useEffect(() => {
    switch webPreviewIsSelecting {
    | true =>
      clickedElement->Option.forEach(({target, clickId}) => {
        switch clickId > lastProcessedClickId.current {
        | true =>
          lastProcessedClickId.current = clickId

          switch wasDragging.current {
          | true => wasDragging.current = false
          | false =>
            switch target {
            | Some(element) =>
              Client__State.Actions.toggleAnnotation(~element, ~tagName=element.tagName)
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

  let hoverOverlay = switch (webPreviewIsSelecting, dragState) {
  | (true, Idle) =>
    <Client__WebPreview__HoveredElement
      key="hover"
      element={hoveredElement}
      scrollTimestamp={scrollTimestamp}
      mutationTimestamp={mutationTimestamp}
    />
  | _ => React.null
  }

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

  let highlightOverlay = switch highlightedElement {
  | Some(_) =>
    <Client__WebPreview__HoveredElement
      key="highlight"
      element={highlightedElement}
      scrollTimestamp={scrollTimestamp}
      mutationTimestamp={mutationTimestamp}
    />
  | None => React.null
  }

  let annotationMarkersOverlay =
    <Client__WebPreview__AnnotationMarkers
      annotations={annotations}
      scrollTimestamp={scrollTimestamp}
      mutationTimestamp={mutationTimestamp}
      onRemove={id => Client__State.Actions.removeAnnotation(~id)}
      onNavigate={(id, element) => {
        Client__State.Actions.removeAnnotation(~id)
        Client__State.Actions.addAnnotation(~element, ~tagName=element.tagName)
      }}
    />

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
      highlightOverlay
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
    <div
      className="pointer-events-none absolute top-0 left-0 w-full h-full isolate flex items-start justify-center"
    >
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
        highlightOverlay
        annotationMarkersOverlay
        annotationPopupOverlay
      </div>
    </div>
  }
}
