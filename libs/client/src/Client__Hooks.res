module Sentry = FrontmanAiFrontmanClient.FrontmanClient__Sentry

module EventHelpers = {
  let rec iframeExecuteEventListener = (
    eventListener: (WebAPI.DOMAPI.document, 'a => unit) => unit,
    handler: 'a => unit,
    iframeDoc: option<WebAPI.DOMAPI.document>,
  ) =>
    iframeDoc
    ->Option.map(doc => WebAPI.Document.querySelectorAll(doc, "iframe"))
    ->Option.map(frames =>
      frames->WebAPI.NodeList.forEach(element => {
        let iframeDoc =
          element->WebAPI.Element.asRescriptElement->WebAPI.HTMLIFrameElement.contentDocument
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
    ~document: option<WebAPI.DOMAPI.document>,
    ~event: string,
    ~withCapture: bool,
    ~handler: WebAPI.EventAPI.event => unit,
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

        let stableHandler = (ev: WebAPI.EventAPI.event) => handlerRef.current(ev)

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
  let useIFrameDocument = (~document: option<WebAPI.DOMAPI.document>, ~withCapture: bool, ()) => {
    let (state, setState) = React.useState(() => None)
    let stateRef = React.useRef(state)
    let rafIdRef = React.useRef(None)
    let pendingTargetRef = React.useRef(None)

    React.useEffect(() => {
      stateRef.current = state
      None
    }, [state])

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
  type clickEvent = {target: option<WebAPI.EventAPI.eventTarget>, clickId: int}

  let useIFrameDocument = (
    ~document: option<WebAPI.DOMAPI.document>,
    ~withCapture: bool,
    ~preventDefault: bool,
    ~stopPropagation: bool,
    ~stopImmediatePropagation: bool,
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

    EventHelpers.useDocumentEvent(~document, ~event="click", ~withCapture, ~handler=onClick, ())

    state
  }
}

module Scroll = {
  let useIFrameDocument = (~document: option<WebAPI.DOMAPI.document>, ~withCapture: bool, ()) => {
    let (scrollTimestamp, setScrollTimestamp) = React.useState(() => Date.now())
    let rafIdRef = React.useRef(None)
    let isScheduledRef = React.useRef(false)

    let onScroll = _ev => {
      switch isScheduledRef.current {
      | true => ()
      | false =>
        isScheduledRef.current = true
        let rafId = WebAPI.Global.requestAnimationFrame(_timestamp => {
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
        rafIdRef.current->Option.forEach(id => WebAPI.Global.cancelAnimationFrame(id)),
      (),
    )

    scrollTimestamp
  }
}

let getIframeWindowSafe = (iframe: WebAPI.DOMAPI.element): option<WebAPI.DOMAPI.window> => {
  let iframeElement = iframe->Obj.magic
  try {
    switch WebAPI.HTMLIFrameElement.contentWindow(iframeElement) {
    | None => None
    | Some(iframeWindow) =>
      ignore(iframeWindow->WebAPI.Window.location->WebAPI.Location.href)
      Some(iframeWindow)
    }
  } catch {
  | _ => None
  }
}

@module("./iframe-location-observer.mjs")
external observeWindowLocation: (WebAPI.DOMAPI.window, string => unit) => unit => unit =
  "observeWindowLocation"

type navigation

@send
external navigationAddEventListener: (
  navigation,
  string,
  WebAPI.EventAPI.event => unit,
  bool,
) => unit = "addEventListener"

@send
external navigationRemoveEventListener: (
  navigation,
  string,
  WebAPI.EventAPI.event => unit,
  bool,
) => unit = "removeEventListener"

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

          let navigation: option<navigation> =
            (
              iframeWindow->WebAPI.Window.navigation->Obj.magic: Nullable.t<navigation>
            )->Nullable.toOption
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
  let useIFrameDocument = (~document: option<WebAPI.DOMAPI.document>, ()) => {
    let (mutationTimestamp, setMutationTimestamp) = React.useState(() => Date.now())

    React.useEffect(() => {
      document
      ->Option.map(doc => {
        let onMutation = (_mutations: array<FrontmanBindings.MutationObserver.mutationRecord>) => {
          setMutationTimestamp(_ => Date.now())
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
