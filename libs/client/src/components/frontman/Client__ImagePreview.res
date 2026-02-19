/**
 * Client__ImagePreview - Full-size image lightbox with zoom & pan
 * 
 * Shows an image in a modal overlay.
 * - Scroll wheel to zoom in/out
 * - Drag to pan when zoomed in
 * - +/- buttons for zoom control
 * - Double-click to reset zoom
 * - Click overlay or press Escape to close
 */

let minScale = 0.5
let maxScale = 8.0
let zoomStep = 1.3

@react.component
let make = (~src: string, ~onClose: unit => unit) => {
  let onCloseRef = React.useRef(onClose)
  onCloseRef.current = onClose

  let (scale, setScale) = React.useState(() => 1.0)
  let (translateX, setTranslateX) = React.useState(() => 0.0)
  let (translateY, setTranslateY) = React.useState(() => 0.0)
  let (isDragging, setIsDragging) = React.useState(() => false)
  let dragStart = React.useRef({"x": 0.0, "y": 0.0})
  let translateStart = React.useRef({"x": 0.0, "y": 0.0})

  let isZoomed = Math.abs(scale -. 1.0) > 0.001

  let resetTransform = () => {
    setScale(_ => 1.0)
    setTranslateX(_ => 0.0)
    setTranslateY(_ => 0.0)
  }

  let applyZoom = next => {
    let clamped = Math.min(maxScale, Math.max(minScale, next))
    let snapped = Math.abs(clamped -. 1.0) < 0.001 ? 1.0 : clamped
    if snapped == 1.0 {
      setTranslateX(_ => 0.0)
      setTranslateY(_ => 0.0)
    }
    snapped
  }

  // Close on Escape key
  React.useEffect0(() => {
    let handleKeyDown = (e: Dom.event) => {
      let key: string = (e->Obj.magic)["key"]
      if key == "Escape" {
        onCloseRef.current()
      }
    }
    let doc = WebAPI.Global.document
    WebAPI.Document.addEventListener(doc, Custom("keydown"), handleKeyDown->Obj.magic)
    Some(() => WebAPI.Document.removeEventListener(doc, Custom("keydown"), handleKeyDown->Obj.magic))
  })

  // Mouse wheel zoom
  let handleWheel = (e: ReactEvent.Wheel.t) => {
    ReactEvent.Wheel.preventDefault(e)
    ReactEvent.Wheel.stopPropagation(e)
    let delta = ReactEvent.Wheel.deltaY(e)
    setScale(prev => {
      let next = delta > 0.0 ? prev /. zoomStep : prev *. zoomStep
      applyZoom(next)
    })
  }

  // Drag-to-pan handlers
  let handlePointerDown = (e: ReactEvent.Pointer.t) => {
    if isZoomed {
      ReactEvent.Pointer.stopPropagation(e)
      ReactEvent.Pointer.preventDefault(e)
      setIsDragging(_ => true)
      dragStart.current = {
        "x": ReactEvent.Pointer.clientX(e)->Int.toFloat,
        "y": ReactEvent.Pointer.clientY(e)->Int.toFloat,
      }
      translateStart.current = {"x": translateX, "y": translateY}
      // Capture pointer for smooth dragging outside the element
      let target: {..} = ReactEvent.Pointer.currentTarget(e)->Obj.magic
      let pointerId = ReactEvent.Pointer.pointerId(e)
      target["setPointerCapture"](pointerId)
    }
  }

  let handlePointerMove = (e: ReactEvent.Pointer.t) => {
    if isDragging {
      ReactEvent.Pointer.preventDefault(e)
      let dx = ReactEvent.Pointer.clientX(e)->Int.toFloat -. dragStart.current["x"]
      let dy = ReactEvent.Pointer.clientY(e)->Int.toFloat -. dragStart.current["y"]
      setTranslateX(_ => translateStart.current["x"] +. dx)
      setTranslateY(_ => translateStart.current["y"] +. dy)
    }
  }

  let handlePointerUp = (e: ReactEvent.Pointer.t) => {
    if isDragging {
      ReactEvent.Pointer.stopPropagation(e)
      setIsDragging(_ => false)
    }
  }

  // Double-click to reset
  let handleDoubleClick = (e: ReactEvent.Mouse.t) => {
    ReactEvent.Mouse.stopPropagation(e)
    resetTransform()
  }

  let transform = `scale(${Float.toString(scale)}) translate(${Float.toString(translateX /. scale)}px, ${Float.toString(translateY /. scale)}px)`

  let zoomPercent = Math.round(scale *. 100.0)->Float.toInt

  // Overlay — only close when clicking the backdrop itself (not when zoomed and panning)
  <div
    role="dialog"
    ariaModal=true
    ariaLabel="Image preview"
    className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-sm
               animate-in fade-in duration-150 select-none"
    onClick={e => {
      // Only close if clicking the backdrop directly (not the image or controls)
      let target: {..} = ReactEvent.Mouse.target(e)->Obj.magic
      let currentTarget: {..} = ReactEvent.Mouse.currentTarget(e)->Obj.magic
      if target === currentTarget {
        onClose()
      }
    }}
  >
    // Close button
    <button
      type_="button"
      ariaLabel="Close preview"
      onClick={e => {
        ReactEvent.Mouse.stopPropagation(e)
        onClose()
      }}
      className="absolute top-4 right-4 z-10 w-10 h-10 rounded-full
                 bg-zinc-800/80 border border-zinc-600 
                 flex items-center justify-center
                 text-zinc-300 hover:text-white hover:bg-zinc-700
                 transition-colors"
    >
      <Client__ToolIcons.XIcon size=20 />
    </button>
    // Zoom controls (bottom center)
    <div
      className="absolute bottom-6 left-1/2 -translate-x-1/2 z-10
                 flex items-center gap-1 px-2 py-1.5 rounded-full
                 bg-zinc-800/80 border border-zinc-600 backdrop-blur-sm"
      onClick={e => ReactEvent.Mouse.stopPropagation(e)}
    >
      <button
        type_="button"
        ariaLabel="Zoom out"
        onClick={_ =>
          setScale(prev => applyZoom(prev /. zoomStep))}
        className="w-8 h-8 rounded-full flex items-center justify-center
                   text-zinc-300 hover:text-white hover:bg-zinc-700 transition-colors"
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 16 16"
          fill="currentColor"
          width="14"
          height="14"
        >
          <path d="M4 8a.5.5 0 0 1 .5-.5h7a.5.5 0 0 1 0 1h-7A.5.5 0 0 1 4 8z" />
        </svg>
      </button>
      <button
        type_="button"
        ariaLabel="Reset zoom"
        onClick={_ => resetTransform()}
        className="min-w-[3.5rem] h-8 px-2 rounded-full flex items-center justify-center
                   text-xs font-mono text-zinc-300 hover:text-white hover:bg-zinc-700 transition-colors"
      >
        {React.string(`${Int.toString(zoomPercent)}%`)}
      </button>
      <button
        type_="button"
        ariaLabel="Zoom in"
        onClick={_ =>
          setScale(prev => applyZoom(prev *. zoomStep))}
        className="w-8 h-8 rounded-full flex items-center justify-center
                   text-zinc-300 hover:text-white hover:bg-zinc-700 transition-colors"
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 16 16"
          fill="currentColor"
          width="14"
          height="14"
        >
          <path
            d="M8 4a.5.5 0 0 1 .5.5v3h3a.5.5 0 0 1 0 1h-3v3a.5.5 0 0 1-1 0v-3h-3a.5.5 0 0 1 0-1h3v-3A.5.5 0 0 1 8 4z"
          />
        </svg>
      </button>
    </div>
    // Image with zoom/pan transform
    <img
      src
      alt="Preview"
      style={
        transform,
        transformOrigin: "center center",
        transition: isDragging ? "none" : "transform 0.15s ease-out",
        cursor: switch (isZoomed, isDragging) {
        | (_, true) => "grabbing"
        | (true, false) => "grab"
        | (false, false) => "default"
        },
      }
      className="max-w-[90vw] max-h-[90vh] object-contain rounded-lg shadow-2xl
                 animate-in zoom-in-95 duration-200"
      onWheel={handleWheel}
      onPointerDown={handlePointerDown}
      onPointerMove={handlePointerMove}
      onPointerUp={handlePointerUp}
      onPointerCancel={handlePointerUp}
      onDoubleClick={handleDoubleClick}
      onClick={e => ReactEvent.Mouse.stopPropagation(e)}
    />
  </div>
}
