module Agent = AskTheLlmAgent.Agent
module AgentEventBus = AskTheLlmAgent.Agent__EventBus

// based on the useEvent RFC: https://github.com/reactjs/rfcs/pull/220
// this will be added to React soon, so we can use this before release and refactor later
// same behavior, namely:
// this will always return a stable function, but the values used in the callback
// will never be stale. So you can easily use this to do some work on
// values within the render function and not worry about stale values, while still being able
// to use this function in an effect without worrying about the function changing triggering
// an the effect.
let useEvent = callback => {
  let callbackRef = React.useRef(callback)
  React.useLayoutEffectOnEveryRender(() => {
    callbackRef.current = callback
    None
  })

  React.useCallback(arg => {
    callbackRef.current(arg)
  }, [])
}

let useTimeout = (fn, #ms(time)) => {
  let (timeoutId, setTimeoutId) = React.useState(() => None)
  React.useLayoutEffect(() => {
    if timeoutId == None {
      let newTimeoutId = setTimeout(() => fn(), time)
      setTimeoutId(_ => Some(newTimeoutId))
    }
    Some(
      () => {
        switch timeoutId {
        | Some(timeoutId) => clearTimeout(timeoutId)
        | None => ()
        }
      },
    )
  }, (fn, time, timeoutId, setTimeoutId))
}

let useSSE = (newEventCallback: AgentEventBus.events => unit, ~url="/api/ask-the-llm/chat-sse") => {
  React.useEffect(() => {
    let eventSource = WebAPI.EventSource.make(~url)
    let onOpen = _ => {
      Console.log("[SSE] Connection opened")
    }
    let onMessage = event => {
      let data = event->WebAPI.MessageEvent.data
      let msg = data->JSON.parseOrThrow->S.parseOrThrow(AgentEventBus.eventsSchema)
      Console.log("[SSE] Received event:")
      Console.dir(msg, ~options={depth: Js.Null})
      newEventCallback(msg)
    }
    let onError = error => {
      Console.log2("[SSE] Connection error - browser will retry automatically:", error)
      // Don't close - let browser's automatic reconnection handle it
    }
    eventSource->WebAPI.EventSource.addEventListener(Custom("open"), onOpen)
    eventSource->WebAPI.EventSource.addEventListener(Custom("message"), onMessage)
    eventSource->WebAPI.EventSource.addEventListener(Custom("error"), onError)

    Some(
      () => {
        eventSource->WebAPI.EventSource.removeEventListener(Custom("open"), onOpen)
        eventSource->WebAPI.EventSource.removeEventListener(Custom("message"), onMessage)
        eventSource->WebAPI.EventSource.removeEventListener(Custom("error"), onError)
        eventSource->WebAPI.EventSource.close
      },
    )
  }, [newEventCallback])
}

let useContainerResize = (container: option<WebAPI.DOMAPI.element>, onResized: unit => unit) => {
  React.useEffect(() => {
    let animationFrameId = ref(None)
    switch container {
    | Some(container) =>
      let resizeObserver = WebAPI.ResizeObserver.make(_entries =>
        _observer => {
          animationFrameId.contents = Some(
            WebAPI.Global.requestAnimationFrame(
              (_timestamp: float) => {
                onResized()
              },
            ),
          )
        }
      )
      WebAPI.ResizeObserver.observe(resizeObserver, ~target=container)

      Some(
        () => {
          WebAPI.ResizeObserver.unobserve(resizeObserver, container)
          animationFrameId.contents->Option.forEach(id => WebAPI.Global.cancelAnimationFrame(id))
        },
      )
    | None => None
    }
  }, (container, onResized))
}

let useMouseOutsideElement = (
  handler,
  elementRef: React.ref<Nullable.t<WebAPI.DOMAPI.element>>,
) => {
  let handler = React.useCallback(e => {
    let _: option<unit> =
      elementRef.current
      ->Nullable.toOption
      ->Option.map(element => {
        let x = ReactEvent.Mouse.clientX(e)->Int.toFloat
        let y = ReactEvent.Mouse.clientY(e)->Int.toFloat
        let boundedRec = WebAPI.Element.getBoundingClientRect(element->Obj.magic)
        let top = boundedRec.top
        let left = boundedRec.left
        let right = boundedRec.right
        let bottom = boundedRec.bottom
        let isInside = x >= left && (x <= right && (y >= top && y <= bottom))
        if !isInside {
          handler()
        }
      })
  }, (elementRef, handler))
  React.useEffect(() => {
    WebAPI.Document.addEventListenerWithCapture(
      WebAPI.Global.document,
      Custom("mouseover"),
      handler,
    )
    Some(
      () =>
        WebAPI.Document.removeEventListener_useCapture(
          WebAPI.Global.document,
          Custom("mouseover"),
          handler,
        ),
    )
  }, [handler])
}

let useMouseInsideElement = (handler, elementRef: React.ref<Nullable.t<WebAPI.DOMAPI.element>>) => {
  let handler = React.useCallback(e => {
    let _: option<unit> =
      elementRef.current
      ->Nullable.toOption
      ->Option.map(element => {
        let x = ReactEvent.Mouse.clientX(e)->Int.toFloat
        let y = ReactEvent.Mouse.clientY(e)->Int.toFloat
        let boundedRec = WebAPI.Element.getBoundingClientRect(element->Obj.magic)
        let top = boundedRec.top
        let left = boundedRec.left
        let right = boundedRec.right
        let bottom = boundedRec.bottom
        let isInside = x >= left && (x <= right && (y >= top && y <= bottom))
        if isInside {
          handler(e)
        }
      })
  }, (elementRef, handler))
  React.useEffect(() => {
    WebAPI.Document.addEventListenerWithCapture(
      WebAPI.Global.document,
      Custom("mouseover"),
      handler,
    )
    Some(
      () =>
        WebAPI.Document.removeEventListener_useCapture(
          WebAPI.Global.document,
          Custom("mouseover"),
          handler,
        ),
    )
  }, [handler])
}

let useMouseOverElement = (handler, elementRef: Nullable.t<WebAPI.DOMAPI.element>) => {
  React.useEffect(() => {
    switch elementRef->Nullable.toOption {
    | Some(elementRef) =>
      WebAPI.Element.addEventListenerWithCapture(
        elementRef->Obj.magic,
        Custom("mouseover"),
        handler,
      )
    | None => ()
    }
    Some(
      () => {
        switch elementRef->Nullable.toOption {
        | Some(elementRef) =>
          WebAPI.Element.removeEventListener_useCapture(
            elementRef->Obj.magic,
            Custom("mouseover"),
            handler,
          )
        | None => ()
        }
      },
    )
  }, (handler, elementRef))
}

let useMouseMoveElement = (handler, elementRef: Nullable.t<WebAPI.DOMAPI.element>) => {
  React.useEffect(() => {
    switch elementRef->Nullable.toOption {
    | Some(elementRef) =>
      WebAPI.Element.addEventListenerWithCapture(
        elementRef->Obj.magic,
        Custom("mousemove"),
        handler,
      )
    | None => ()
    }
    Some(
      () => {
        switch elementRef->Nullable.toOption {
        | Some(elementRef) =>
          WebAPI.Element.removeEventListener_useCapture(
            elementRef->Obj.magic,
            Custom("mousemove"),
            handler,
          )
        | None => ()
        }
      },
    )
  }, (handler, elementRef))
}

let useDebounce = (value, delay) => {
  let (debouncedValue, setDebouncedValue) = React.useState(() => value)
  React.useEffect(() => {
    let timeout = setTimeout(() => setDebouncedValue(_ => value), delay)
    Some(() => clearTimeout(timeout))
  }, (value, delay, setDebouncedValue))
  debouncedValue
}

let useDebounceCallback = (~timeout=1000, fn: 'a => unit): ('a => unit) => {
  let id = React.useRef(Nullable.null)
  let fn = React.useRef(fn)

  let clearTimeout = () => {
    id.current->Nullable.toOption->Option.mapOr((), clearTimeout)
  }

  React.useEffect(() => {
    Some(clearTimeout)
  }, [])

  React.useCallback((a: 'a) => {
    clearTimeout()

    id.current = Nullable.make(setTimeout(() => fn.current(a), timeout))
    ()
  }, [timeout])
}

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

module EffectHelpers = {
  let elementEventUseEffectHandler = (
    ~eventName,
    ~element: WebAPI.DOMAPI.htmlElement,
    ~setState,
    ~withCapture=false,
    (),
  ) => {
    let handler = _e => setState()
    WebAPI.HTMLElement.addEventListener(
      element,
      eventName,
      handler,
      ~options={capture: withCapture},
    )
    Some(
      () =>
        WebAPI.HTMLElement.removeEventListener(
          element,
          eventName,
          handler,
          ~options={capture: withCapture},
        ),
    )
  }

  let documentEventUseEffectHandler = (
    ~eventName,
    ~document: WebAPI.DOMAPI.document,
    ~setState,
    ~withCapture=false,
    (),
  ) => {
    let handler = _e => setState()
    let _: option<unit> = EventHelpers.iframeExecuteEventListener(
      (doc, handler) =>
        WebAPI.Document.addEventListener(doc, eventName, handler, ~options={capture: withCapture}),
      handler,
      Some(document),
    )
    document->WebAPI.Document.addEventListener(eventName, handler, ~options={capture: withCapture})
    Some(
      () => {
        let _: option<unit> = EventHelpers.iframeExecuteEventListener(
          (doc, event) =>
            WebAPI.Document.removeEventListener(
              doc,
              eventName,
              event,
              ~options={capture: withCapture},
            ),
          handler,
          Some(document),
        )
        document->WebAPI.Document.removeEventListener(
          eventName,
          handler,
          ~options={capture: withCapture},
        )
      },
    )
  }

  let windowEventUseEffectHandlerWithEvent = (
    ~eventName,
    ~window: WebAPI.DOMAPI.window,
    ~setState,
    ~withCapture=false,
    (),
  ) => {
    let handler = e => setState(e)
    window->WebAPI.Window.addEventListener(eventName, handler, ~options={capture: withCapture})
    Some(
      () =>
        WebAPI.Window.removeEventListener(
          window,
          eventName,
          handler,
          ~options={capture: withCapture},
        ),
    )
  }

  let windowEventUseEffectHandler = (
    ~eventName,
    ~window: WebAPI.DOMAPI.window,
    ~setState,
    ~withCapture=false,
    (),
  ) => {
    let handler = _e => setState()
    window->WebAPI.Window.addEventListener(eventName, handler, ~options={capture: withCapture})
    Some(
      () => {
        WebAPI.Window.removeEventListener(
          window,
          eventName,
          handler,
          ~options={capture: withCapture},
        )
      },
    )
  }
}

module FontsLoaded = {
  let useFontsLoaded = (~document, ()) => {
    let (state, setState) = React.useState(_ => None)

    React.useEffect(() => {
      switch document {
      | Some(document) =>
        switch WebAPI.Document.fonts(document) {
        | Some(fontApi) =>
          fontApi.ready
          ->Nullable.toOption
          ->Option.forEach(fontsReady => {
            fontsReady
            ->Promise.thenResolve(
              _fonts => {
                setState(_ => Some(Js.Date.now()->Js.Date.fromFloat))
              },
            )
            ->Promise.ignore
          })
        | None => ()
        }
      | None => ()
      }
      None
    }, (document, setState))

    state
  }
}

module MouseEnter = {
  let useIFrameDocument = (~document: option<WebAPI.DOMAPI.document>, ~withCapture=false, ()) => {
    let (state, setState) = React.useState(() => None)
    React.useEffect(() => {
      let onMouseEnter = ev => {
        let target = WebAPI.MouseEvent.asMouseEvent(ev).target

        if WebAPI.Element.nodeType(target->Obj.magic) == 1 {
          setState(_ => Some(target))
        }
      }

      document->Option.map(document => {
        WebAPI.Document.addEventListener(
          document,
          Custom("mouseenter"),
          onMouseEnter,
          ~options={capture: withCapture},
        )

        EventHelpers.iframeExecuteEventListener(
          (doc, handler) =>
            WebAPI.Document.addEventListener(
              doc,
              Custom("mouseenter"),
              handler,
              ~options={capture: withCapture},
            ),
          onMouseEnter,
          Some(document),
        )->Option.ignore
        () => {
          WebAPI.Document.removeEventListener(
            document,
            Custom("mouseenter"),
            onMouseEnter,
            ~options={capture: withCapture},
          )

          EventHelpers.iframeExecuteEventListener(
            (doc, handler) =>
              WebAPI.Document.removeEventListener(
                doc,
                Custom("mouseenter"),
                handler,
                ~options={capture: withCapture},
              ),
            onMouseEnter,
            Some(document),
          )->Option.ignore
        }
      })
    }, (document, withCapture, setState))
    state
  }
}

module MouseMove = {
  let useIFrameDocument = (~document: option<WebAPI.DOMAPI.document>, ~withCapture=false, ()) => {
    let (state, setState) = React.useState(() => None)
    let stateRef = React.useRef(state)
    React.useEffect(() => {
      stateRef.current = state
      None
    }, [state])

    React.useEffect(() => {
      let onMouseMove = ev => {
        let target = WebAPI.MouseEvent.asMouseEvent(ev).target

        if (
          WebAPI.Element.nodeType(target->Obj.magic) == 1 &&
            switch stateRef.current {
            | None => true
            | Some(el) => el != target
            }
        ) {
          setState(_ => Some(target))
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

module MouseMovePosition = {
  type t = (int, int)
  let useIFrameDocument = (
    ~document: option<WebAPI.DOMAPI.document>,
    ~withCapture=false,
    ~callback,
    (),
  ) => {
    let callbackRef = React.useRef(callback)
    React.useEffectOnEveryRender(() => {
      callbackRef.current = callback
      None
    })
    React.useEffect(() => {
      let onMouseMove = ev => {
        let x = ReactEvent.Mouse.clientX(ev)->Int.toFloat
        let y = ReactEvent.Mouse.clientY(ev)->Int.toFloat
        callbackRef.current((x, y))
      }

      document
      ->Option.map(document => {
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
      })
      ->ignore

      Some(
        () => {
          document
          ->Option.map(document => {
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
          })
          ->ignore
        },
      )
    }, (document, withCapture))
  }
}

module MouseClick = {
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

    React.useEffect(() => {
      let onClick = (ev: WebAPI.EventAPI.event) => {
        preventDefault ? WebAPI.Event.preventDefault(ev) : ()
        stopPropagation ? WebAPI.Event.stopPropagation(ev) : ()
        stopImmediatePropagation ? WebAPI.Event.stopImmediatePropagation(ev) : ()
        let target = ev.target->Null.toOption
        setState(_ => Some(target))
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

let useKeypress = (~handler, ~isActive=true, ()) => {
  let pressedKeyHandler = React.useCallback(key => handler(Some(key)), [handler])
  React.useEffect(() => {
    if isActive {
      WebAPI.Document.addEventListener(
        WebAPI.Global.document,
        Custom("keydown"),
        pressedKeyHandler,
        ~options={capture: true},
      )
      Some(
        () => {
          WebAPI.Document.removeEventListener(
            WebAPI.Global.document,
            Custom("keydown"),
            pressedKeyHandler,
            ~options={capture: true},
          )
        },
      )
    } else {
      None
    }
  }, (pressedKeyHandler, isActive))
}

let useKeypressIFrameDocument = (handler, doc) => {
  let releasedKeyHandler = useEvent(_key => handler(None))
  let pressedKeyHandler = useEvent(key => handler(Some(key)))

  React.useEffect(() => {
    doc->Option.map(doc => {
      WebAPI.Document.addEventListener(
        doc,
        Custom("keydown"),
        pressedKeyHandler,
        ~options={capture: true},
      )
      WebAPI.Document.addEventListener(
        doc,
        Custom("keyup"),
        releasedKeyHandler,
        ~options={capture: true},
      )
      let _: option<unit> = EventHelpers.iframeExecuteEventListener(
        (doc, handler) =>
          WebAPI.Document.addEventListener(
            doc,
            Custom("keydown"),
            handler,
            ~options={capture: true},
          ),
        pressedKeyHandler,
        Some(doc),
      )
      let _: option<unit> = EventHelpers.iframeExecuteEventListener(
        (doc, handler) =>
          WebAPI.Document.addEventListener(doc, Custom("keyup"), handler, ~options={capture: true}),
        releasedKeyHandler,
        Some(doc),
      )

      () => {
        WebAPI.Document.removeEventListener(
          doc,
          Custom("keydown"),
          pressedKeyHandler,
          ~options={capture: true},
        )
        WebAPI.Document.removeEventListener(
          doc,
          Custom("keyup"),
          releasedKeyHandler,
          ~options={capture: true},
        )
        let _: option<unit> = EventHelpers.iframeExecuteEventListener(
          (doc, handler) =>
            WebAPI.Document.removeEventListener(
              doc,
              Custom("keydown"),
              handler,
              ~options={capture: true},
            ),
          pressedKeyHandler,
          Some(doc),
        )
        let _: option<unit> = EventHelpers.iframeExecuteEventListener(
          (doc, handler) =>
            WebAPI.Document.removeEventListener(
              doc,
              Custom("keyup"),
              handler,
              ~options={capture: true},
            ),
          releasedKeyHandler,
          Some(doc),
        )
      }
    })
  }, (pressedKeyHandler, releasedKeyHandler, doc))
}

let useLoadedIFrameDocument = (handler, doc) => {
  React.useEffect(() => {
    doc->Option.map(doc => {
      WebAPI.Document.addEventListener(doc, Custom("load"), handler, ~options={capture: true})
      EventHelpers.iframeExecuteEventListener(
        (doc, handler) =>
          WebAPI.Document.addEventListener(doc, Custom("load"), handler, ~options={capture: true}),
        handler,
        Some(doc),
      )->ignore

      () =>
        WebAPI.Document.removeEventListener(doc, Custom("load"), handler, ~options={capture: true})
    })
  }, (handler, doc))
}

let useIsOnline = () => {
  let (isOnline, setIsOnline) = React.useState(() => true)
  React.useEffect(() => {
    let setOnline = _ => setIsOnline(_ => true)
    let setOffline = _ => setIsOnline(_ => false)
    WebAPI.Window.addEventListener(
      WebAPI.Global.window,
      Custom("online"),
      setOnline,
      ~options={capture: true},
    )
    WebAPI.Window.addEventListener(
      WebAPI.Global.window,
      Custom("offline"),
      setOffline,
      ~options={capture: true},
    )
    Some(
      () => {
        WebAPI.Window.removeEventListener(
          WebAPI.Global.window,
          Custom("online"),
          setOnline,
          ~options={capture: true},
        )
        WebAPI.Window.removeEventListener(
          WebAPI.Global.window,
          Custom("offline"),
          setOffline,
          ~options={capture: true},
        )
      },
    )
  }, [setIsOnline])
  isOnline
}

module Scroll = {
  let useIFrameDocument = (~document: option<WebAPI.DOMAPI.document>, ~withCapture=false, ()) => {
    let (scrollTimestamp, setScrollTimestamp) = React.useState(() => Js.Date.now())

    React.useEffect(() => {
      let onScroll = _ev => {
        setScrollTimestamp(_ => Js.Date.now())
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

let useIFrameLocation = (~iframeRef: Nullable.t<WebAPI.DOMAPI.element>) => {
  let (location, setLocation) = React.useState(() => None)

  React.useEffect(() => {
    let iframeWindow =
      iframeRef
      ->Nullable.toOption
      ->Option.flatMap(iframe =>
        WebAPI.Element.unsafeAsHTMLIFrameElement(iframe)
        ->WebAPI.HTMLIFrameElement.contentWindow
        ->Null.toOption
      )

    switch iframeWindow {
    | Some(iframeWindow) =>
      // Get initial location
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
  }, [iframeRef])

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
        function(doc) {
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
