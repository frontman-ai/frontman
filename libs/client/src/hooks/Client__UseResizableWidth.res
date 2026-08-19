/**
 * Client__UseResizableWidth - Hook for resizable width with localStorage persistence
 *
 * Provides drag-to-resize functionality for panels with:
 * - Mouse drag handling (mousedown/mousemove/mouseup)
 * - Min/max width constraints
 * - localStorage persistence of user preference
 */
let defaultWidth = 384
let minWidth = 280
let maxWidth = 600
let storageKey = "frontman:chatbox-width"

let clamp = (~min, ~max, value) => {
  if value < min {
    min
  } else if value > max {
    max
  } else {
    value
  }
}

let loadSavedWidth = (): int => {
  let storage = WebAPI.Window.current->WebAPI.Window.localStorage
  switch storage->WebAPI.Storage.getItem(storageKey)->Null.toOption {
  | Some(value) =>
    switch Int.fromString(value) {
    | Some(width) => clamp(~min=minWidth, ~max=maxWidth, width)
    | None => defaultWidth
    }
  | None => defaultWidth
  }
}

let saveWidth = (width: int): unit => {
  WebAPI.Window.current
  ->WebAPI.Window.localStorage
  ->WebAPI.Storage.setItem(~key=storageKey, ~value=Int.toString(width))
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

  let isDraggingRef = React.useRef(false)
  let startXRef = React.useRef(0)
  let startWidthRef = React.useRef(state.width)

  let handleMouseMove = React.useCallback((e: Dom.mouseEvent) => {
    if isDraggingRef.current {
      let clientX: int = Obj.magic(e)["clientX"]
      let deltaX = clientX - startXRef.current
      let newWidth = clamp(~min=minWidth, ~max=maxWidth, startWidthRef.current + deltaX)
      setState(prev => {...prev, width: newWidth})
    }
  }, [])

  let handleMouseUp = React.useCallback((_e: Dom.mouseEvent) => {
    if isDraggingRef.current {
      isDraggingRef.current = false
      setState(prev => {
        saveWidth(prev.width)
        {...prev, isResizing: false}
      })

      let body = WebAPI.Document.body(WebAPI.Window.current->WebAPI.Window.document)->Null.toOption
      body->Option.forEach(body => {
        let style = WebAPI.HTMLElement.style(body)
        WebAPI.CSSStyleDeclaration.removeProperty(style, "cursor")->ignore
        WebAPI.CSSStyleDeclaration.removeProperty(style, "user-select")->ignore
      })
    }
  }, [])

  React.useEffect(() => {
    let doc = WebAPI.Window.current->WebAPI.Window.document

    WebAPI.Document.addEventListener(doc, Custom("mousemove"), handleMouseMove->Obj.magic)
    WebAPI.Document.addEventListener(doc, Custom("mouseup"), handleMouseUp->Obj.magic)

    Some(
      () => {
        WebAPI.Document.removeEventListener(doc, Custom("mousemove"), handleMouseMove->Obj.magic)
        WebAPI.Document.removeEventListener(doc, Custom("mouseup"), handleMouseUp->Obj.magic)
      },
    )
  }, (handleMouseMove, handleMouseUp))

  let handleMouseDown = React.useCallback((e: ReactEvent.Mouse.t) => {
    ReactEvent.Mouse.preventDefault(e)
    ReactEvent.Mouse.stopPropagation(e)

    isDraggingRef.current = true
    startXRef.current = ReactEvent.Mouse.clientX(e)
    startWidthRef.current = state.width

    setState(prev => {...prev, isResizing: true})

    let body = WebAPI.Document.body(WebAPI.Window.current->WebAPI.Window.document)->Null.toOption
    body->Option.forEach(body => {
      let style = WebAPI.HTMLElement.style(body)
      WebAPI.CSSStyleDeclaration.setProperty(style, ~property="cursor", ~value="col-resize")
      WebAPI.CSSStyleDeclaration.setProperty(style, ~property="user-select", ~value="none")
    })
  }, [state.width])

  (state.width, state.isResizing, handleMouseDown)
}
