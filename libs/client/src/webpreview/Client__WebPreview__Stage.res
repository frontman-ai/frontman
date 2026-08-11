module Log = FrontmanLogs.Logs.Make({
  let component = #WebPreviewStage
})

module Annotation = Client__Annotation__Types

external asKeyboardEvent: WebAPI.EventAPI.event => WebAPI.UIEventsAPI.keyboardEvent = "%identity"
external asMouseEvent: WebAPI.EventAPI.event => WebAPI.UIEventsAPI.mouseEvent = "%identity"
@send
external elementFromPoint: (WebAPI.DOMAPI.document, int, int) => Nullable.t<WebAPI.DOMAPI.element> =
  "elementFromPoint"

let documentScroll = (doc: WebAPI.DOMAPI.document): (float, float) =>
  doc.defaultView
  ->Null.toOption
  ->Option.mapOr((0.0, 0.0), win => (win->WebAPI.Window.scrollX, win->WebAPI.Window.scrollY))

let elementContainsBox = (
  element: WebAPI.DOMAPI.element,
  bb: Annotation.viewportBoundingBox,
): bool => {
  let Annotation.ViewportBoundingBox(bb) = bb
  let rect = WebAPI.Element.getBoundingClientRect(element)
  rect.left <= bb.x &&
  rect.top <= bb.y &&
  rect.left +. rect.width >= bb.x +. bb.width &&
  rect.top +. rect.height >= bb.y +. bb.height
}

let rec closestContainingElement = (
  element: WebAPI.DOMAPI.element,
  bb: Annotation.viewportBoundingBox,
): WebAPI.DOMAPI.element => {
  switch elementContainsBox(element, bb) {
  | true => element
  | false =>
    element.parentElement
    ->Null.toOption
    ->Option.mapOr(element, parent => closestContainingElement(parent->Obj.magic, bb))
  }
}

let viewportBoundingBoxFromPoints = (points: array<Annotation.viewportPoint>): option<
  Annotation.viewportBoundingBox,
> => {
  switch points->Array.get(0) {
  | None => None
  | Some(first) => {
      let Annotation.ViewportPoint(first) = first
      let minX = ref(first.x)
      let minY = ref(first.y)
      let maxX = ref(first.x)
      let maxY = ref(first.y)

      points->Array.forEach(point => {
        let Annotation.ViewportPoint(point) = point
        minX.contents = Math.min(minX.contents, point.x)
        minY.contents = Math.min(minY.contents, point.y)
        maxX.contents = Math.max(maxX.contents, point.x)
        maxY.contents = Math.max(maxY.contents, point.y)
      })

      Some(
        Annotation.viewportBoundingBox(
          ~x=minX.contents,
          ~y=minY.contents,
          ~width=maxX.contents -. minX.contents,
          ~height=maxY.contents -. minY.contents,
        ),
      )
    }
  }
}

let shouldAppendPoint = (
  points: array<Annotation.viewportPoint>,
  point: Annotation.viewportPoint,
): bool => {
  switch points->Array.get(Array.length(points) - 1) {
  | Some(last) => {
      let Annotation.ViewportPoint(last) = last
      let Annotation.ViewportPoint(point) = point
      let dx = point.x -. last.x
      let dy = point.y -. last.y
      dx *. dx +. dy *. dy >= 4.0
    }
  | None => true
  }
}

let pointFromMouse = (mouseEv: WebAPI.UIEventsAPI.mouseEvent): Annotation.viewportPoint =>
  Annotation.viewportPoint(~x=mouseEv.clientX->Int.toFloat, ~y=mouseEv.clientY->Int.toFloat)

let addMouseListeners = (doc: WebAPI.DOMAPI.document, ~onMouseDown, ~onMouseMove, ~onMouseUp) => {
  WebAPI.Document.addEventListener(doc, Custom("mousedown"), onMouseDown, ~options={capture: true})
  WebAPI.Document.addEventListener(doc, Custom("mousemove"), onMouseMove, ~options={capture: true})
  WebAPI.Document.addEventListener(doc, Custom("mouseup"), onMouseUp, ~options={capture: true})

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
    WebAPI.Document.removeEventListener(doc, Custom("mouseup"), onMouseUp, ~options={capture: true})
  }
}

let removeCursorStyle = (doc: WebAPI.DOMAPI.document) => {
  doc
  ->WebAPI.Document.querySelector("[data-frontman-cursor]")
  ->Null.toOption
  ->Option.forEach(el => el->WebAPI.Element.remove)
}

let _findElementsInRect: (
  WebAPI.DOMAPI.document,
  float,
  float,
  float,
  float,
) => array<WebAPI.DOMAPI.element> = %raw(`
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
  let annotationMode = Client__State.useSelector(Client__State.Selectors.annotationMode)
  let webPreviewIsSelecting = annotationMode != Annotation.Off
  let isSelectingElements = annotationMode == Annotation.Selecting
  let isDrawingShape = annotationMode == Annotation.Drawing
  let annotations = Client__State.useSelector(Client__State.Selectors.annotations)

  let lastProcessedClickId = React.useRef(-1)
  let wasSelecting = React.useRef(false)
  let (dragState, setDragState) = React.useState(() => Idle)
  let (drawPoints, setDrawPoints) = React.useState((): option<array<Annotation.viewportPoint>> =>
    None
  )
  let drawPointsRef: React.ref<array<Annotation.viewportPoint>> = React.useRef([])
  let wasDragging = React.useRef(false)
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
    ~withCapture=isSelectingElements,
    ~preventDefault=isSelectingElements,
    ~stopPropagation=isSelectingElements,
    ~stopImmediatePropagation=isSelectingElements,
    (),
  )
  let hoveredElement = Client__Hooks.MouseMove.useIFrameDocument(~document, ~withCapture=true, ())

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

  React.useEffect(() => {
    switch (document, isSelectingElements) {
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
                    doc->elementFromPoint(startX->Float.toInt, startY->Float.toInt)
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

        Some(addMouseListeners(doc, ~onMouseDown, ~onMouseMove, ~onMouseUp))
      }
    | _ => None
    }
  }, (document, isSelectingElements))

  React.useEffect(() => {
    switch (document, isDrawingShape) {
    | (Some(doc), true) => {
        let penAnnotationFromPoints = (points: array<Annotation.viewportPoint>): option<
          Client__Task__Reducer.penAnnotation,
        > => {
          switch viewportBoundingBoxFromPoints(points) {
          | Some(bb) =>
            let Annotation.ViewportBoundingBox(bbData) = bb
            switch bbData.width >= 3.0 || bbData.height >= 3.0 {
            | true =>
              let centerX = (bbData.x +. bbData.width /. 2.0)->Float.toInt
              let centerY = (bbData.y +. bbData.height /. 2.0)->Float.toInt
              let element =
                doc
                ->elementFromPoint(centerX, centerY)
                ->Nullable.toOption
                ->Option.mapOr(doc.body->WebAPI.HTMLElement.asElement, el =>
                  closestContainingElement(el, bb)
                )
              let (scrollX, scrollY) = documentScroll(doc)
              Some({
                Client__Task__Reducer.element,
                tagName: element.tagName,
                documentPoints: points->Array.map(point =>
                  point->Annotation.viewportPointToDocument(~scrollX, ~scrollY)
                ),
                documentBoundingBox: Annotation.documentBoundingBox(
                  ~x=bbData.x +. scrollX,
                  ~y=bbData.y +. scrollY,
                  ~width=bbData.width,
                  ~height=bbData.height,
                ),
              })
            | false => None
            }
          | None => None
          }
        }

        let onMouseDown = ev => {
          WebAPI.Event.preventDefault(ev)
          WebAPI.Event.stopPropagation(ev)
          let mouseEv = ev->asMouseEvent
          let point = pointFromMouse(mouseEv)
          drawPointsRef.current = [point]
          setDrawPoints(_ => Some([point]))
        }

        let onMouseMove = ev => {
          let mouseEv = ev->asMouseEvent
          let point = pointFromMouse(mouseEv)
          let points = drawPointsRef.current
          switch Array.length(points) > 0 && shouldAppendPoint(points, point) {
          | true =>
            let nextPoints = Array.concat(points, [point])
            drawPointsRef.current = nextPoints
            setDrawPoints(_ => Some(nextPoints))
          | false => ()
          }
        }

        let onMouseUp = ev => {
          WebAPI.Event.preventDefault(ev)
          WebAPI.Event.stopPropagation(ev)
          let mouseEv = ev->asMouseEvent
          let point = pointFromMouse(mouseEv)
          let points = drawPointsRef.current
          let finalPoints = switch shouldAppendPoint(points, point) {
          | true => Array.concat(points, [point])
          | false => points
          }

          drawPointsRef.current = []
          setDrawPoints(_ => None)

          switch penAnnotationFromPoints(finalPoints) {
          | Some(annotation) => Client__State.Actions.addPenAnnotation(~annotation)
          | None => ()
          }
        }

        Some(addMouseListeners(doc, ~onMouseDown, ~onMouseMove, ~onMouseUp))
      }
    | _ => None
    }
  }, (document, isDrawingShape))

  React.useEffect(() => {
    switch (isSelectingElements, wasSelecting.current) {
    | (true, false) =>
      let currentId = clickedElement->Option.mapOr(-1, click => click.clickId)
      lastProcessedClickId.current = currentId
      wasSelecting.current = true
    | (false, true) => wasSelecting.current = false
    | _ => ()
    }
    None
  }, [isSelectingElements])

  React.useEffect(() => {
    switch isSelectingElements {
    | true =>
      clickedElement->Option.forEach(({target, clickId}) => {
        switch clickId > lastProcessedClickId.current {
        | true =>
          lastProcessedClickId.current = clickId

          switch wasDragging.current {
          | true => wasDragging.current = false
          | false =>
            switch target {
            | Some(eventTarget) => {
                let element = WebAPI.EventTarget.asElement(eventTarget)
                Client__State.Actions.toggleAnnotation(~element, ~tagName=element.tagName)
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
  }, (clickedElement, isSelectingElements))

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
        removeCursorStyle(doc)
      })
    }

    Some(
      () => {
        document->Option.forEach(doc => {
          removeCursorStyle(doc)
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

  let hoverOverlay = switch (isSelectingElements, dragState) {
  | (true, Idle) =>
    <Client__WebPreview__HoveredElement
      key="hover" element={hoveredElement} scrollTimestamp={scrollTimestamp}
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

  let drawOverlay = switch drawPoints {
  | Some(points) =>
    <svg className="absolute inset-0 pointer-events-none z-[9998] overflow-visible">
      <Client__WebPreview__PenPolyline
        points={points->Array.map(Annotation.viewportPointToLocal)}
      />
    </svg>
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

  let overlays =
    <>
      selectionModeIndicator
      hoverOverlay
      dragOverlay
      drawOverlay
      annotationMarkersOverlay
      annotationPopupOverlay
    </>

  switch viewportStyle {
  | None =>
    <div className="pointer-events-none flex-1 absolute top-0 left-0 w-full h-full isolate">
      overlays
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
        overlays
      </div>
    </div>
  }
}
