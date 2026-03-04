module Sentry = FrontmanAiFrontmanClient.FrontmanClient__Sentry

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
        iframeExecuteEventListener(eventListener, handler, iframeDoc)->Option.ignore
        iframeDoc
        ->Option.map(
          doc => {
            eventListener(doc, handler)
            doc
          },
        )
        ->Option.ignore
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

  // Shared hook: subscribes a handler to a DOM event on a document and all its
  // same-origin iframes, and tears everything down on cleanup.
  //
  // Uses ref-based handler pattern to avoid re-subscribing listeners on every
  // render. The actual DOM listener delegates to the ref, which is always
  // up-to-date. Effect only re-runs when document/event/withCapture change.
  let useDocumentEvent = (
    ~document: option<WebAPI.DOMAPI.document>,
    ~event: string,
    ~withCapture: bool,
    ~handler: WebAPI.EventAPI.event => unit,
    ~onCleanup: option<unit => unit>=?,
    (),
  ) => {
    let handlerRef = React.useRef(handler)
    let onCleanupRef = React.useRef(onCleanup)

    // Keep refs current on every render (no effect needed, refs are synchronous)
    handlerRef.current = handler
    onCleanupRef.current = onCleanup

    React.useEffect(() => {
      document->Option.map(doc => {
        let eventType = WebAPI.EventAPI.Custom(event)

        // Stable wrapper: delegates to the ref so the DOM listener never changes
        let stableHandler = (ev: WebAPI.EventAPI.event) => handlerRef.current(ev)

        WebAPI.Document.addEventListener(doc, eventType, stableHandler, ~options={capture: withCapture})
        iframeExecuteEventListener(
          (d, h) =>
            WebAPI.Document.addEventListener(d, eventType, h, ~options={capture: withCapture}),
          stableHandler,
          Some(doc),
        )->Option.ignore

        () => {
          onCleanupRef.current->Option.forEach(fn => fn())
          WebAPI.Document.removeEventListener(
            doc,
            eventType,
            stableHandler,
            ~options={capture: withCapture},
          )
          iframeExecuteEventListener(
            (d, h) =>
              WebAPI.Document.removeEventListener(d, eventType, h, ~options={capture: withCapture}),
            stableHandler,
            Some(doc),
          )->Option.ignore
        }
      })
    }, (document, event, withCapture))
  }
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

    // Throttle mousemove events using requestAnimationFrame for better performance
    let onMouseMove = (ev: WebAPI.EventAPI.event) => {
      let target = WebAPI.MouseEvent.asMouseEvent(ev->Obj.magic).target

      if (
        WebAPI.Element.nodeType(target->Obj.magic) == 1 &&
          switch stateRef.current {
          | None => true
          | Some(el) => el != target
          }
      ) {
        pendingTargetRef.current = Some(target)
        rafIdRef.current->Option.forEach(id => WebAPI.Global.cancelAnimationFrame(id))

        let rafId = WebAPI.Global.requestAnimationFrame(_timestamp => {
          pendingTargetRef.current->Option.forEach(pendingTarget => {
            setState(_ => Some(pendingTarget))
            pendingTargetRef.current = None
          })
        })
        rafIdRef.current = Some(rafId)
      }
    }

    EventHelpers.useDocumentEvent(
      ~document,
      ~event="mousemove",
      ~withCapture,
      ~handler=onMouseMove,
      ~onCleanup=() =>
        rafIdRef.current->Option.forEach(id => WebAPI.Global.cancelAnimationFrame(id)),
      (),
    )

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

    let onClick = (ev: WebAPI.EventAPI.event) => {
      switch preventDefault {
      | true => WebAPI.Event.preventDefault(ev)
      | false => ()
      }
      switch stopPropagation {
      | true => WebAPI.Event.stopPropagation(ev)
      | false => ()
      }
      switch stopImmediatePropagation {
      | true => WebAPI.Event.stopImmediatePropagation(ev)
      | false => ()
      }
      let target = ev.target->Null.toOption
      clickCounter.current = clickCounter.current + 1
      let id = clickCounter.current
      setState(_ => Some({target, clickId: id}))
    }

    let event = switch isRightClick {
    | true => "contextmenu"
    | false => "click"
    }

    EventHelpers.useDocumentEvent(~document, ~event, ~withCapture, ~handler=onClick, ())

    state
  }
}

module Scroll = {
  let useIFrameDocument = (~document: option<WebAPI.DOMAPI.document>, ~withCapture=false, ()) => {
    let (scrollTimestamp, setScrollTimestamp) = React.useState(() => Js.Date.now())
    let rafIdRef = React.useRef(None)
    let isScheduledRef = React.useRef(false)

    // Throttle scroll events using requestAnimationFrame for better performance
    let onScroll = _ev => {
      switch isScheduledRef.current {
      | true => ()
      | false =>
        isScheduledRef.current = true
        let rafId = WebAPI.Global.requestAnimationFrame(_timestamp => {
          setScrollTimestamp(_ => Js.Date.now())
          isScheduledRef.current = false
        })
        rafIdRef.current = Some(rafId)
      }
    }

    EventHelpers.useDocumentEvent(
      ~document,
      ~event="scroll",
      ~withCapture,
      ~handler=onScroll,
      ~onCleanup=() =>
        rafIdRef.current->Option.forEach(id => WebAPI.Global.cancelAnimationFrame(id)),
      (),
    )

    scrollTimestamp
  }
}

let getIframeWindowSafe = (iframe: WebAPI.DOMAPI.element): option<WebAPI.DOMAPI.window> => {
  let iframeElement = iframe->Obj.magic
  try {
    switch WebAPI.HTMLIFrameElement.contentWindow(iframeElement)->Null.toOption {
    | None => None
    | Some(iframeWindow) =>
      ignore(iframeWindow->WebAPI.Window.location->WebAPI.Location.href)
      Some(iframeWindow)
    }
  } catch {
  | _ => None
  }
}

let useIFrameLocation = (~iframeElement: option<WebAPI.DOMAPI.element>, ~attachmentKey: int) => {
  let (location, setLocation) = React.useState(() => None)

  React.useEffect(() => {
    switch iframeElement {
    | None =>
      setLocation(_ => None)
      None
    | Some(iframe) =>
      switch getIframeWindowSafe(iframe) {
      | None =>
        setLocation(_ => None)
        None
      | Some(iframeWindow) =>
        try {
          let initialLocation = Some(iframeWindow->WebAPI.Window.location->WebAPI.Location.href)
          setLocation(_ => initialLocation)

          let onNavigation = (ev: WebAPI.EventAPI.event) => {
            let navigateEvent: FrontmanBindings.NavigateEvent.t = ev->Obj.magic
            let destinationUrl =
              navigateEvent
              ->FrontmanBindings.NavigateEvent.destination
              ->FrontmanBindings.NavigateEvent.url
            let currentUrl = iframeWindow->WebAPI.Window.location->WebAPI.Location.href
            switch Client__BrowserUrl.resolveUrlWithBase(~url=destinationUrl, ~base=currentUrl) {
            | None => ()
            | Some(resolvedDestinationUrl) =>
              switch Client__BrowserUrl.isSameOriginWithBase(
                ~baseUrl=currentUrl,
                ~targetUrl=resolvedDestinationUrl,
              ) {
              | false => WebAPI.Event.preventDefault(ev)
              | true =>
                // If the iframe is trying to navigate to a /frontman URL, intercept
                // and redirect to the stripped version so we never load frontman-in-frontman.
                let parsed = WebAPI.URL.make(~url=resolvedDestinationUrl)
                let cleanPath = Client__BrowserUrl.stripSuffix(parsed.pathname)
                switch cleanPath != parsed.pathname {
                | false => setLocation(_ => Some(resolvedDestinationUrl))
                | true =>
                  WebAPI.Event.preventDefault(ev)
                  let cleanUrl = `${parsed.origin}${cleanPath}`
                  iframeWindow->WebAPI.Window.location->WebAPI.Location.assign(cleanUrl)
                }
              }
            }
          }

          WebAPI.Navigation.addEventListener(
            iframeWindow.navigation,
            Custom("navigate"),
            onNavigation,
            ~options={capture: false},
          )

          Some(
            () => {
              try {
                WebAPI.Navigation.removeEventListener(
                  iframeWindow.navigation,
                  Custom("navigate"),
                  onNavigation,
                  ~options={capture: false},
                )
              } catch {
              | exn =>
                // Cross-origin frame — listener already inaccessible
                Sentry.captureException(exn, ~operation="useIFrameLocation.cleanup")
              }
            },
          )
        } catch {
        | exn =>
          // Cross-origin iframe — treat like getIframeWindowSafe returning None
          Sentry.captureException(exn, ~operation="useIFrameLocation.setup")
          setLocation(_ => None)
          None
        }
      }
    }
  }, (iframeElement, attachmentKey))

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

module DOMmutations = {
  let useIFrameDocument = (~document: option<WebAPI.DOMAPI.document>, ()) => {
    let (mutationTimestamp, setMutationTimestamp) = React.useState(() => Js.Date.now())

    React.useEffect(() => {
      document
      ->Option.map(doc => {
        let onMutation = (_mutations: array<FrontmanBindings.MutationObserver.mutationRecord>) => {
          setMutationTimestamp(_ => Js.Date.now())
        }

        let observer = FrontmanBindings.MutationObserver.make(onMutation)
        FrontmanBindings.MutationObserver.observe(
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
          FrontmanBindings.MutationObserver.disconnect(observer)
        }
      })
      ->Option.getOr(() => ())
      ->Some
    }, (document, setMutationTimestamp))

    mutationTimestamp
  }
}
