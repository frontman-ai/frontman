/**
 * Client__UseResizableWidth - Hook for resizable width with localStorage persistence
 * 
 * Provides drag-to-resize functionality for panels with:
 * - Mouse drag handling (mousedown/mousemove/mouseup)
 * - Min/max width constraints
 * - localStorage persistence of user preference
 */
let // Constants
defaultWidth = 384 // w-96 equivalent
let minWidth = 280
let maxWidth = 600
let storageKey = "frontman:chatbox-width"

// Clamp value between min and max
let clamp = (~min, ~max, value) => {
  if value < min {
    min
  } else if value > max {
    max
  } else {
    value
  }
}

// Load saved width from localStorage
let loadSavedWidth = (): int => {
  switch FrontmanBindings.LocalStorage.getItem(storageKey)->Nullable.toOption {
  | Some(value) =>
    switch Int.fromString(value) {
    | Some(width) => clamp(~min=minWidth, ~max=maxWidth, width)
    | None => defaultWidth
    }
  | None => defaultWidth
  }
}

// Save width to localStorage
let saveWidth = (width: int): unit => {
  FrontmanBindings.LocalStorage.setItem(storageKey, Int.toString(width))
}

type state = {
  width: int,
  isResizing: bool,
}

let use = () => {
  let (state, setState) = React.useState(() => {
    width: loadSavedWidth(),
    isResizing: false,
  })

  // Ref to track if we're currently dragging (for event handlers)
  let isDraggingRef = React.useRef(false)
  let startXRef = React.useRef(0)
  let startWidthRef = React.useRef(state.width)

  // Handle mouse move during drag
  let handleMouseMove = React.useCallback((e: Dom.mouseEvent) => {
    if isDraggingRef.current {
      let clientX: int = Obj.magic(e)["clientX"]
      let deltaX = clientX - startXRef.current
      let newWidth = clamp(~min=minWidth, ~max=maxWidth, startWidthRef.current + deltaX)
      setState(prev => {...prev, width: newWidth})
    }
  }, [])

  // Handle mouse up to end drag
  let handleMouseUp = React.useCallback((_e: Dom.mouseEvent) => {
    if isDraggingRef.current {
      isDraggingRef.current = false
      setState(prev => {
        saveWidth(prev.width)
        {...prev, isResizing: false}
      })

      // Remove cursor override from body
      let body = WebAPI.Document.body(WebAPI.Global.document)->Null.toOption
      body->Option.forEach(body => {
        let htmlBody: WebAPI.DOMAPI.htmlElement = Obj.magic(body)
        let style = WebAPI.HTMLElement.style(htmlBody)
        WebAPI.CSSStyleDeclaration.removeProperty(style, "cursor")->ignore
        WebAPI.CSSStyleDeclaration.removeProperty(style, "user-select")->ignore
      })
    }
  }, [])

  // Set up global mouse event listeners
  React.useEffect(() => {
    let doc = WebAPI.Global.document

    WebAPI.Document.addEventListener(doc, Custom("mousemove"), handleMouseMove->Obj.magic)
    WebAPI.Document.addEventListener(doc, Custom("mouseup"), handleMouseUp->Obj.magic)

    Some(
      () => {
        WebAPI.Document.removeEventListener(doc, Custom("mousemove"), handleMouseMove->Obj.magic)
        WebAPI.Document.removeEventListener(doc, Custom("mouseup"), handleMouseUp->Obj.magic)
      },
    )
  }, (handleMouseMove, handleMouseUp))

  // Handle mouse down on resize handle to start drag
  let handleMouseDown = React.useCallback((e: ReactEvent.Mouse.t) => {
    ReactEvent.Mouse.preventDefault(e)
    ReactEvent.Mouse.stopPropagation(e)

    isDraggingRef.current = true
    startXRef.current = ReactEvent.Mouse.clientX(e)
    startWidthRef.current = state.width

    setState(prev => {...prev, isResizing: true})

    // Apply cursor override to body to prevent cursor flicker
    let body = WebAPI.Document.body(WebAPI.Global.document)->Null.toOption
    body->Option.forEach(body => {
      let htmlBody: WebAPI.DOMAPI.htmlElement = Obj.magic(body)
      let style = WebAPI.HTMLElement.style(htmlBody)
      WebAPI.CSSStyleDeclaration.setProperty(style, ~property="cursor", ~value="col-resize")
      WebAPI.CSSStyleDeclaration.setProperty(style, ~property="user-select", ~value="none")
    })
  }, [state.width])

  (state.width, state.isResizing, handleMouseDown)
}
