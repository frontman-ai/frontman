module EventHelpers = {
  //note(itay): This function will recursively iterate all the iframes in a provided iframeDoc,
  //and invoke the given event listener with the provided handler. Its safe to execute even
  //for cross-origin iframes, as those would be safely ignored.
  let rec iframeExecuteEventListener = (
    eventListener: (WebAPI.DOMAPI.document, 'a => unit) => unit,
    handler: 'a => unit,
    iframeDoc: option<WebAPI.DOMAPI.document>,
  ) =>
    iframeDoc
    ->Option.map(doc => WebAPI.Document.querySelectorAll(doc, "iframe"))
    ->Option.map(frames =>
      frames
      ->Obj.magic
      ->Array.forEach(element => {
        //note(itay): This will return null (None) in case the IFrame is cross-origin to the
        //running script, and not an error like `contentWindow.document`
        let iframeDoc = element->WebAPI.HTMLIFrameElement.contentDocument->Null.toOption
        let _: option<unit> = iframeExecuteEventListener(eventListener, handler, iframeDoc)
        let _: option<WebAPI.DOMAPI.document> = iframeDoc->Option.map(
          doc => {
            eventListener(doc, handler)
            doc
          },
        )
      })
    )
  let getIframeDoc = (iframeRef: Nullable.t<WebAPI.DOMAPI.element>) =>
    iframeRef
    ->Nullable.toOption
    ->Option.flatMap(iframe =>
      WebAPI.Element.unsafeAsHTMLIFrameElement(iframe)
      ->WebAPI.HTMLIFrameElement.contentDocument
      ->Null.toOption
    )
}

module MouseMove = {
  let useIFrameDocument = (~document: option<WebAPI.DOMAPI.document>, ~withCapture=false, ()) => {
    let (state, setState) = React.useState(() => None)
    let stateRef = React.useRef(state)
    let rafIdRef = React.useRef(None)
    let pendingTargetRef = React.useRef(None)

    React.useEffect(() => {
      stateRef.current = state
      None
    }, [state])

    React.useEffect(() => {
      // Throttle mousemove events using requestAnimationFrame for better performance
      let onMouseMove = ev => {
        let target = WebAPI.MouseEvent.asMouseEvent(ev).target

        if (
          WebAPI.Element.nodeType(target->Obj.magic) == 1 &&
            switch stateRef.current {
            | None => true
            | Some(el) => el != target
            }
        ) {
          // Store the pending target
          pendingTargetRef.current = Some(target)

          // Cancel any existing pending update
          rafIdRef.current->Option.forEach(id => WebAPI.Global.cancelAnimationFrame(id))

          // Schedule update using RAF
          let rafId = WebAPI.Global.requestAnimationFrame(_timestamp => {
            pendingTargetRef.current->Option.forEach(pendingTarget => {
              setState(_ => Some(pendingTarget))
              pendingTargetRef.current = None
            })
          })
          rafIdRef.current = Some(rafId)
        }
      }

      document->Option.map(document => {
        WebAPI.Document.addEventListener(
          document,
          Custom("mousemove"),
          onMouseMove,
          ~options={capture: withCapture},
        )

        EventHelpers.iframeExecuteEventListener(
          (doc, handler) =>
            WebAPI.Document.addEventListener(
              doc,
              Custom("mousemove"),
              handler,
              ~options={capture: withCapture},
            ),
          onMouseMove,
          Some(document),
        )->Option.ignore
        () => {
          // Cancel any pending animation frame
          rafIdRef.current->Option.forEach(id => WebAPI.Global.cancelAnimationFrame(id))

          WebAPI.Document.removeEventListener(
            document,
            Custom("mousemove"),
            onMouseMove,
            ~options={capture: withCapture},
          )

          EventHelpers.iframeExecuteEventListener(
            (doc, handler) =>
              WebAPI.Document.removeEventListener(
                doc,
                Custom("mousemove"),
                handler,
                ~options={capture: withCapture},
              ),
            onMouseMove,
            Some(document),
          )->Option.ignore
        }
      })
    }, (document, withCapture, setState))

    state
  }
}

module MouseClick = {
  // Each click returns a target and a unique clickId so consumers can always
  // detect a new click even when the same DOM element is clicked twice.
  type clickEvent = {target: option<WebAPI.EventAPI.eventTarget>, clickId: int}

  let useIFrameDocument = (
    ~document: option<WebAPI.DOMAPI.document>,
    ~withCapture=false,
    ~preventDefault=false,
    ~stopPropagation=false,
    ~stopImmediatePropagation=false,
    ~isRightClick=false,
    (),
  ) => {
    let (state, setState) = React.useState(() => None)
    let clickCounter = React.useRef(0)

    React.useEffect(() => {
      let onClick = (ev: WebAPI.EventAPI.event) => {
        preventDefault ? WebAPI.Event.preventDefault(ev) : ()
        stopPropagation ? WebAPI.Event.stopPropagation(ev) : ()
        stopImmediatePropagation ? WebAPI.Event.stopImmediatePropagation(ev) : ()
        let target = ev.target->Null.toOption
        clickCounter.current = clickCounter.current + 1
        let id = clickCounter.current
        setState(_ => Some({target, clickId: id}))
      }
      document->Option.map(document => {
        WebAPI.Document.addEventListener(
          document,
          Custom(isRightClick ? "contextmenu" : "click"),
          onClick,
          ~options={capture: withCapture},
        )
        let _: option<unit> = EventHelpers.iframeExecuteEventListener(
          (doc, handler) =>
            WebAPI.Document.addEventListener(
              doc,
              Custom(isRightClick ? "contextmenu" : "click"),
              handler,
              ~options={capture: withCapture},
            ),
          onClick,
          Some(document),
        )
        () => {
          WebAPI.Document.removeEventListener(
            document,
            Custom(isRightClick ? "contextmenu" : "click"),
            onClick,
            ~options={capture: withCapture},
          )
          let _: option<unit> = EventHelpers.iframeExecuteEventListener(
            (doc, handler) =>
              WebAPI.Document.removeEventListener(
                doc,
                Custom(isRightClick ? "contextmenu" : "click"),
                handler,
                ~options={capture: withCapture},
              ),
            onClick,
            Some(document),
          )
        }
      })
    }, (
      setState,
      withCapture,
      document,
      preventDefault,
      stopImmediatePropagation,
      stopPropagation,
      isRightClick,
    ))
    state
  }
}

module Scroll = {
  let useIFrameDocument = (~document: option<WebAPI.DOMAPI.document>, ~withCapture=false, ()) => {
    let (scrollTimestamp, setScrollTimestamp) = React.useState(() => Js.Date.now())
    let rafIdRef = React.useRef(None)
    let isScheduledRef = React.useRef(false)

    React.useEffect(() => {
      // Throttle scroll events using requestAnimationFrame for better performance
      let onScroll = _ev => {
        if !isScheduledRef.current {
          isScheduledRef.current = true
          let rafId = WebAPI.Global.requestAnimationFrame(_timestamp => {
            setScrollTimestamp(_ => Js.Date.now())
            isScheduledRef.current = false
          })
          rafIdRef.current = Some(rafId)
        }
      }

      document
      ->Option.map(document => {
        WebAPI.Document.addEventListener(
          document,
          Custom("scroll"),
          onScroll,
          ~options={capture: withCapture},
        )

        EventHelpers.iframeExecuteEventListener(
          (doc, handler) =>
            WebAPI.Document.addEventListener(
              doc,
              Custom("scroll"),
              handler,
              ~options={capture: withCapture},
            ),
          onScroll,
          Some(document),
        )->Option.ignore

        () => {
          // Cancel any pending animation frame
          rafIdRef.current->Option.forEach(id => WebAPI.Global.cancelAnimationFrame(id))

          WebAPI.Document.removeEventListener(
            document,
            Custom("scroll"),
            onScroll,
            ~options={capture: withCapture},
          )

          EventHelpers.iframeExecuteEventListener(
            (doc, handler) =>
              WebAPI.Document.removeEventListener(
                doc,
                Custom("scroll"),
                handler,
                ~options={capture: withCapture},
              ),
            onScroll,
            Some(document),
          )->Option.ignore
        }
      })
      ->ignore

      None
    }, (document, withCapture, setScrollTimestamp))

    scrollTimestamp
  }
}

// Helper to safely get iframe contentWindow - returns None for cross-origin iframes
// Cross-origin iframes throw SecurityError when accessing contentWindow properties
let getIframeWindowSafe: WebAPI.DOMAPI.element => option<WebAPI.DOMAPI.window> = %raw(`
  function(iframe) {
    try {
      var win = iframe.contentWindow;
      // Verify we have access by reading location (throws if cross-origin)
      if (win && win.location && win.location.href) {
        return win;
      }
      return undefined;
    } catch (e) {
      // Expected for cross-origin iframes - log for debugging
      console.debug('[useIFrameLocation] Cross-origin iframe access denied:', e.message);
      return undefined;
    }
  }
`)

let useIFrameLocation = (~iframeRef: Nullable.t<WebAPI.DOMAPI.element>) => {
  let (location, setLocation) = React.useState(() => None)

  React.useEffect(() => {
    let iframeWindow =
      iframeRef
      ->Nullable.toOption
      ->Option.flatMap(iframe => getIframeWindowSafe(iframe))

    switch iframeWindow {
    | Some(iframeWindow) =>
      // Get initial location (safe since getIframeWindowSafe verified access)
      let initialLocation = Some(iframeWindow->WebAPI.Window.location->WebAPI.Location.href)
      setLocation(_ => initialLocation)

      // Listen for navigation events
      let onPopState = _ev => {
        let currentLocation = Some(iframeWindow->WebAPI.Window.location->WebAPI.Location.href)
        setLocation(_ => currentLocation)
      }
      let onNavigation = ev => {
        let url = ev["destination"]["url"]
        let currentLocation = Some(url)
        setLocation(_ => currentLocation)
      }

      // Check if Navigation API is supported (not available in Firefox/Safari)
      let navigationSupported = %raw(`typeof iframeWindow.navigation !== 'undefined'`)

      WebAPI.Window.addEventListener(
        iframeWindow,
        Custom("popstate"),
        onPopState,
        ~options={capture: false},
      )

      // Only use Navigation API if supported
      if navigationSupported {
        WebAPI.Navigation.addEventListener(
          iframeWindow.navigation,
          Custom("navigate"),
          onNavigation,
          ~options={capture: false},
        )
      }

      Some(
        () => {
          WebAPI.Window.removeEventListener(
            iframeWindow,
            Custom("popstate"),
            onPopState,
            ~options={capture: false},
          )

          // Only remove Navigation API listener if it was added
          if navigationSupported {
            WebAPI.Navigation.removeEventListener(
              iframeWindow.navigation,
              Custom("navigate"),
              onNavigation,
              ~options={capture: false},
            )
          }
        },
      )
    | None => None
    }
  }, (iframeRef, setLocation))

  location
}

let useDisableIFrameAnchorPointerEvents = (
  ~iframeRef: Nullable.t<WebAPI.DOMAPI.element>,
  ~activate=true,
) => {
  React.useEffect(() => {
    let iframeDoc = EventHelpers.getIframeDoc(iframeRef)

    switch iframeDoc {
    | Some(doc) =>
      // Convert NodeList to array
      let getAnchors: WebAPI.DOMAPI.document => array<WebAPI.DOMAPI.element> = %raw(`
        (doc) => {
          return Array.from(doc.querySelectorAll("a"));
        }
      `)
      let anchorElements = getAnchors(doc)

      // Store original pointer-events values and set/restore based on activate
      let originalStyles = Array.map(anchorElements, element => {
        let htmlElement = element->Obj.magic
        let originalPointerEvents = htmlElement["style"]["pointerEvents"]
        if activate {
          htmlElement["style"]["pointerEvents"] = "none"
        }
        originalPointerEvents
      })

      Some(
        () => {
          // Always restore original pointer-events values on cleanup
          Array.forEachWithIndex(anchorElements, (element, index) => {
            let htmlElement = element->Obj.magic
            htmlElement["style"]["pointerEvents"] = originalStyles[index]
          })
        },
      )
    | None => None
    }
  }, (iframeRef, activate))
}

module MutationObserverBindings = {
  type mutationObserver
  type mutationRecord = {
    @as("type") type_: string,
    target: WebAPI.DOMAPI.node,
    addedNodes: array<WebAPI.DOMAPI.node>,
    removedNodes: array<WebAPI.DOMAPI.node>,
    attributeName: Null.t<string>,
    oldValue: Null.t<string>,
  }

  @new
  external make: (array<mutationRecord> => unit) => mutationObserver = "MutationObserver"

  @send
  external observe: (
    mutationObserver,
    WebAPI.DOMAPI.node,
    {
      "childList": bool,
      "attributes": bool,
      "characterData": bool,
      "subtree": bool,
      "attributeOldValue": bool,
      "characterDataOldValue": bool,
    },
  ) => unit = "observe"

  @send
  external disconnect: mutationObserver => unit = "disconnect"
}

module DOMmutations = {
  let useIFrameDocument = (~document: option<WebAPI.DOMAPI.document>, ()) => {
    let (mutationTimestamp, setMutationTimestamp) = React.useState(() => Js.Date.now())

    React.useEffect(() => {
      document
      ->Option.map(doc => {
        let onMutation = (_mutations: array<MutationObserverBindings.mutationRecord>) => {
          setMutationTimestamp(_ => Js.Date.now())
        }

        let observer = MutationObserverBindings.make(onMutation)
        MutationObserverBindings.observe(
          observer,
          doc->Obj.magic,
          {
            "childList": true,
            "attributes": true,
            "characterData": true,
            "subtree": true,
            "attributeOldValue": true,
            "characterDataOldValue": false,
          },
        )

        () => {
          MutationObserverBindings.disconnect(observer)
        }
      })
      ->Option.getOr(() => ())
      ->Some
    }, (document, setMutationTimestamp))

    mutationTimestamp
  }
}
