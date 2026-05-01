// --- Scroll context ---

/**
 * Client__ScrollContainer - Scrollable container with stick-to-bottom behavior
 *
 * Uses CSS overflow-anchor for zero-JS stick-to-bottom during streaming,
 * and IntersectionObserver for passive isAtBottom tracking.
 * Replaces use-stick-to-bottom to eliminate layout thrashing (see #177).
 */
type scrollContext = {
  isAtBottom: bool,
  scrollToBottom: unit => unit,
}

let context = React.createContext({isAtBottom: true, scrollToBottom: () => ()})

module Provider = {
  let make = React.Context.provider(context)
}

let useScrollContext = () => React.useContext(context)

// --- Cached classNames ---

let scrollButtonBaseClassName = "sticky bottom-4 left-[50%] translate-x-[-50%] z-10 rounded-full w-8 h-8 flex items-center justify-center bg-zinc-800 border border-zinc-600 text-zinc-200 hover:bg-zinc-700 transition-colors"

let containerBaseClassName = "relative flex-1 overflow-y-auto frontman-contain-strict"

let contentBaseClassName = "p-4"

// --- ScrollButton ---

module ScrollButton = {
  @react.component
  let make = (~className: option<string>=?) => {
    let {isAtBottom, scrollToBottom} = useScrollContext()

    let buttonClassName = React.useMemo1(() => {
      switch className {
      | None => scrollButtonBaseClassName
      | Some(extra) => `${scrollButtonBaseClassName} ${extra}`
      }
    }, [className])

    if isAtBottom {
      React.null
    } else {
      <button type_="button" onClick={_ => scrollToBottom()} className={buttonClassName}>
        <svg
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="2"
          strokeLinecap="round"
          strokeLinejoin="round"
          className="w-4 h-4"
        >
          <path d="M12 5v14" />
          <path d="m19 12-7 7-7-7" />
        </svg>
      </button>
    }
  }
}

// --- Main ScrollContainer ---

@react.component
let make = (~className: option<string>=?, ~children: React.element) => {
  let containerClassName = React.useMemo1(() => {
    switch className {
    | None => containerBaseClassName
    | Some(extra) => `${containerBaseClassName} ${extra}`
    }
  }, [className])

  let sentinelRef = React.useRef(Nullable.null)
  let containerRef = React.useRef(Nullable.null)
  let contentRef = React.useRef(Nullable.null)
  let (isAtBottom, setIsAtBottom) = React.useState(() => true)

  // IntersectionObserver: passively track whether the sentinel is visible.
  // When visible the user is "at the bottom"; overflow-anchor on the sentinel
  // keeps them pinned there as content grows — zero layout reads.
  React.useEffect0(() => {
    switch (sentinelRef.current->Nullable.toOption, containerRef.current->Nullable.toOption) {
    | (Some(sentinel), Some(container)) =>
      let observer = Bindings__IntersectionObserver.make(entries => {
        entries->Array.forEach(
          entry => {
            setIsAtBottom(_ => entry.isIntersecting)
          },
        )
      }, {root: container, rootMargin: "10px", threshold: [0.0]})
      observer->Bindings__IntersectionObserver.observe(sentinel)
      Some(() => Bindings__IntersectionObserver.disconnect(observer))
    | _ => None
    }
  })

  let scrollToBottom = React.useCallback0(() => {
    switch sentinelRef.current->Nullable.toOption {
    | None => ()
    | Some(sentinel) => sentinel->Bindings__DomScrollIntoView.scrollIntoView({behavior: "smooth"})
    }
  })

  // Auto-scroll fallback (#718): two cases to handle —
  // 1. Content grows (new messages/streaming): check if near bottom, snap down.
  // 2. Container shrinks (todo list opens): check if was at bottom using
  //    previous clientHeight, snap down.
  // Both use a single ResizeObserver, fires once per frame.
  React.useEffect0(() => {
    switch (contentRef.current->Nullable.toOption, containerRef.current->Nullable.toOption) {
    | (Some(content), Some(container)) =>
      let el: WebAPI.DOMAPI.element = container->Obj.magic
      let prevClientHeight = ref(el.clientHeight)

      let contentObserver = FrontmanBindings.ResizeObserver.make(_ => {
        let nearBottom =
          el.scrollTop +. el.clientHeight->Int.toFloat >= el.scrollHeight->Int.toFloat -. 150.0
        if nearBottom {
          el.scrollTop = el.scrollHeight->Int.toFloat
        }
      })
      contentObserver->FrontmanBindings.ResizeObserver.observe(content)

      let containerObserver = FrontmanBindings.ResizeObserver.make(_ => {
        let newClientHeight = el.clientHeight
        if newClientHeight < prevClientHeight.contents {
          let wasAtBottom =
            el.scrollTop +. prevClientHeight.contents->Int.toFloat >=
              el.scrollHeight->Int.toFloat -. 150.0
          if wasAtBottom {
            el.scrollTop = el.scrollHeight->Int.toFloat
          }
        }
        prevClientHeight := newClientHeight
      })
      containerObserver->FrontmanBindings.ResizeObserver.observe(container)

      Some(
        () => {
          FrontmanBindings.ResizeObserver.disconnect(contentObserver)
          FrontmanBindings.ResizeObserver.disconnect(containerObserver)
        },
      )
    | _ => None
    }
  })

  let contextValue = React.useMemo2(
    () => {isAtBottom, scrollToBottom},
    (isAtBottom, scrollToBottom),
  )

  <Provider value={contextValue}>
    <div ref={ReactDOM.Ref.domRef(containerRef)} className={containerClassName} role="log">
      <div ref={ReactDOM.Ref.domRef(contentRef)}> {children} </div>
      // ScrollButton lives here — outside contentRef — so its show/hide does not
      // affect the ResizeObserver-watched div and cannot trigger the snap feedback loop.
      <ScrollButton />
      // Sentinel: overflow-anchor keeps it in view while the user is at the bottom.
      // All message wrappers have overflow-anchor: none (via .frontman-content-auto).
      <div
        ref={ReactDOM.Ref.domRef(sentinelRef)} className="frontman-scroll-anchor" ariaHidden=true
      />
    </div>
  </Provider>
}

// --- ContentWrapper ---

module ContentWrapper = {
  @react.component
  let make = (~className: option<string>=?, ~children: React.element) => {
    let contentClassName = React.useMemo1(() => {
      switch className {
      | None => contentBaseClassName
      | Some(extra) => `${contentBaseClassName} ${extra}`
      }
    }, [className])

    <div className={contentClassName}> {children} </div>
  }
}
