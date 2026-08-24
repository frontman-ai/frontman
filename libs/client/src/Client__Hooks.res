module Sentry = FrontmanAiFrontmanClient.FrontmanClient__Sentry

module EventHelpers = {
  let rec iframeExecuteEventListener = (
    eventListener: (WebAPI.DomTypes.document, 'a => unit) => unit,
    handler: 'a => unit,
    iframeDoc: option<WebAPI.DomTypes.document>,
  ) =>
    iframeDoc
    ->Option.map(doc => WebAPI.Document.querySelectorAll(doc, "iframe"))
    ->Option.map(frames =>
      frames->WebAPI.NodeList.forEach(element => {
        let iframeDoc =
          element
          ->FrontmanBindings.Bindings__WebAPI.iframeElementFromElement
          ->Option.flatMap(WebAPI.HTMLIFrameElement.contentDocument)
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
  let useDocumentEvent = (
    ~document: option<WebAPI.DomTypes.document>,
    ~event: string,
    ~withCapture: bool,
    ~handler: WebAPI.EventTypes.event => unit,
    ~onCleanup: option<unit => unit>=?,
    (),
  ) => {
    let handlerRef = React.useRef(handler)
    let onCleanupRef = React.useRef(onCleanup)

    handlerRef.current = handler
    onCleanupRef.current = onCleanup

    React.useEffect(() => {
      document->Option.map(doc => {
        let eventType = WebAPI.EventTypes.Custom(event)

        let stableHandler = (ev: WebAPI.EventTypes.event) => handlerRef.current(ev)

        WebAPI.Document.addEventListener(
          doc,
          eventType,
          stableHandler,
          ~options={capture: withCapture},
        )
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
  let useIFrameDocument = (~document: option<WebAPI.DomTypes.document>, ~withCapture: bool, ()) => {
    let (state, setState) = React.useState(() => None)
    let stateRef = React.useRef(state)
    let rafIdRef = React.useRef(None)
    let pendingTargetRef = React.useRef(None)

    React.useEffect(() => {
      stateRef.current = state
      None
    }, [state])

    let onMouseMove = (ev: WebAPI.EventTypes.event) => {
      switch ev.target
      ->Null.toOption
      ->Option.flatMap(FrontmanBindings.Bindings__WebAPI.elementFromEventTarget) {
      | Some(element)
        if switch stateRef.current {
        | None => true
        | Some(currentElement) => currentElement != element
        } =>
        pendingTargetRef.current = Some(element)
        rafIdRef.current->Option.forEach(id =>
          WebAPI.Window.cancelAnimationFrame(WebAPI.Window.current, id)
        )

        let rafId = WebAPI.Window.requestAnimationFrame(WebAPI.Window.current, _timestamp => {
          pendingTargetRef.current->Option.forEach(pendingTarget => {
            setState(_ => Some(pendingTarget))
            pendingTargetRef.current = None
          })
        })
        rafIdRef.current = Some(rafId)
      | _ => ()
      }
    }

    EventHelpers.useDocumentEvent(
      ~document,
      ~event="mousemove",
      ~withCapture,
      ~handler=onMouseMove,
      ~onCleanup=() =>
        rafIdRef.current->Option.forEach(id =>
          WebAPI.Window.cancelAnimationFrame(WebAPI.Window.current, id)
        ),
      (),
    )

    state
  }
}

module MouseClick = {
  type clickEvent = {target: option<WebAPI.DomTypes.element>, clickId: int}

  let useIFrameDocument = (
    ~document: option<WebAPI.DomTypes.document>,
    ~withCapture: bool,
    ~preventDefault: bool,
    ~stopPropagation: bool,
    ~stopImmediatePropagation: bool,
    (),
  ) => {
    let (state, setState) = React.useState(() => None)
    let clickCounter = React.useRef(0)

    let onClick = (ev: WebAPI.EventTypes.event) => {
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
      let target =
        ev.target
        ->Null.toOption
        ->Option.flatMap(FrontmanBindings.Bindings__WebAPI.elementFromEventTarget)
      clickCounter.current = clickCounter.current + 1
      let id = clickCounter.current
      setState(_ => Some({target, clickId: id}))
    }

    EventHelpers.useDocumentEvent(~document, ~event="click", ~withCapture, ~handler=onClick, ())

    state
  }
}

module Scroll = {
  let useIFrameDocument = (~document: option<WebAPI.DomTypes.document>, ~withCapture: bool, ()) => {
    let (scrollTimestamp, setScrollTimestamp) = React.useState(() => Date.now())
    let rafIdRef = React.useRef(None)
    let isScheduledRef = React.useRef(false)

    let onScroll = _ev => {
      switch isScheduledRef.current {
      | true => ()
      | false =>
        isScheduledRef.current = true
        let rafId = WebAPI.Window.requestAnimationFrame(WebAPI.Window.current, _timestamp => {
          setScrollTimestamp(_ => Date.now())
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
        rafIdRef.current->Option.forEach(id =>
          WebAPI.Window.cancelAnimationFrame(WebAPI.Window.current, id)
        ),
      (),
    )

    scrollTimestamp
  }
}

let getIframeWindowSafe = (iframe: WebAPI.DomTypes.element): option<WebAPI.DomTypes.window> => {
  switch iframe->FrontmanBindings.Bindings__WebAPI.iframeElementFromElement {
  | None => None
  | Some(iframeElement) =>
    try {
      switch WebAPI.HTMLIFrameElement.contentWindow(iframeElement) {
      | None => None
      | Some(iframeWindow) =>
        let location = iframeWindow->WebAPI.Window.location
        ignore(location.href)
        Some(iframeWindow)
      }
    } catch {
    | _ => None
    }
  }
}

@module("./iframe-location-observer.mjs")
external observeWindowLocation: (WebAPI.DomTypes.window, string => unit) => unit => unit =
  "observeWindowLocation"

type navigation

@get
external windowNavigation: WebAPI.DomTypes.window => Nullable.t<navigation> = "navigation"

@send
external navigationAddEventListener: (
  navigation,
  string,
  WebAPI.EventTypes.event => unit,
  bool,
) => unit = "addEventListener"

@send
external navigationRemoveEventListener: (
  navigation,
  string,
  WebAPI.EventTypes.event => unit,
  bool,
) => unit = "removeEventListener"

let useIFrameLocation = (~iframeElement: option<WebAPI.DomTypes.element>, ~attachmentKey: int) => {
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
          let initialLocation = Some((iframeWindow->WebAPI.Window.location).href)
          setLocation(_ => initialLocation)

          let onNavigation = (ev: WebAPI.EventTypes.event) => {
            let navigateEvent: FrontmanBindings.NavigateEvent.t = ev->Obj.magic
            let destinationUrl =
              navigateEvent
              ->FrontmanBindings.NavigateEvent.destination
              ->FrontmanBindings.NavigateEvent.url
            let currentUrl = (iframeWindow->WebAPI.Window.location).href
            switch Client__BrowserUrl.resolveUrlWithBase(~url=destinationUrl, ~base=currentUrl) {
            | None => ()
            | Some(resolvedDestinationUrl) =>
              switch Client__BrowserUrl.isSameOriginWithBase(
                ~baseUrl=currentUrl,
                ~targetUrl=resolvedDestinationUrl,
              ) {
              | false => WebAPI.Event.preventDefault(ev)
              | true =>
                let parsed = WebAPI.URL.make(~url=resolvedDestinationUrl)
                switch Client__BrowserUrl.hasSuffix(parsed.pathname) {
                | false => setLocation(_ => Some(resolvedDestinationUrl))
                | true =>
                  WebAPI.Event.preventDefault(ev)
                  let cleanPath = Client__BrowserUrl.stripSuffix(parsed.pathname)
                  let cleanUrl = `${parsed.origin}${cleanPath}`
                  iframeWindow->WebAPI.Window.location->WebAPI.Location.assign(cleanUrl)
                }
              }
            }
          }

          let navigation = iframeWindow->windowNavigation->Nullable.toOption
          navigation->Option.forEach(navigation =>
            navigation->navigationAddEventListener("navigate", onNavigation, false)
          )
          let cleanupLocationObserver = observeWindowLocation(iframeWindow, currentLocation =>
            setLocation(_ => Some(currentLocation))
          )

          Some(
            () => {
              try {
                cleanupLocationObserver()
                navigation->Option.forEach(navigation =>
                  navigation->navigationRemoveEventListener("navigate", onNavigation, false)
                )
              } catch {
              | exn => Sentry.captureException(exn, ~operation="useIFrameLocation.cleanup")
              }
            },
          )
        } catch {
        | exn =>
          Sentry.captureException(exn, ~operation="useIFrameLocation.setup")
          setLocation(_ => None)
          None
        }
      }
    }
  }, (iframeElement, attachmentKey))

  location
}

module DOMmutations = {
  let useIFrameDocument = (~document: option<WebAPI.DomTypes.document>, ()) => {
    let (mutationTimestamp, setMutationTimestamp) = React.useState(() => Date.now())

    React.useEffect(() => {
      document
      ->Option.map(doc => {
        let onMutation = (_mutations, _observer) => {
          setMutationTimestamp(_ => Date.now())
        }

        let observer = WebAPI.MutationObserver.make(onMutation)
        observer->WebAPI.MutationObserver.observe(
          ~target=(doc :> WebAPI.DomTypes.node),
          ~options={
            childList: true,
            attributes: true,
            characterData: true,
            subtree: true,
            attributeOldValue: true,
            characterDataOldValue: false,
          },
        )

        () => {
          observer->WebAPI.MutationObserver.disconnect
        }
      })
      ->Option.getOr(() => ())
      ->Some
    }, (document, setMutationTimestamp))

    mutationTimestamp
  }
}
