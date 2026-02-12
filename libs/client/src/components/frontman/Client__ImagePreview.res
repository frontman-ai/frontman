/**
 * Client__ImagePreview - Full-size image lightbox preview
 * 
 * Shows an image in a modal overlay. Click outside or press Escape to close.
 */

@react.component
let make = (~src: string, ~onClose: unit => unit) => {
  // Close on Escape key — re-register when onClose changes to avoid stale closure
  let onCloseRef = React.useRef(onClose)
  onCloseRef.current = onClose

  React.useEffect0(() => {
    let handleKeyDown = (e: Dom.event) => {
      let key: string = (e->Obj.magic)["key"]
      if key == "Escape" {
        onCloseRef.current()
      }
    }
    let doc = WebAPI.Global.document
    let addEventListener: (WebAPI.DOMAPI.document, string, Dom.event => unit) => unit = %raw(`
      function(doc, event, handler) { doc.addEventListener(event, handler); }
    `)
    let removeEventListener: (WebAPI.DOMAPI.document, string, Dom.event => unit) => unit = %raw(`
      function(doc, event, handler) { doc.removeEventListener(event, handler); }
    `)
    addEventListener(doc, "keydown", handleKeyDown)
    Some(() => removeEventListener(doc, "keydown", handleKeyDown))
  })

  // Overlay
  <div
    role="dialog"
    ariaModal=true
    ariaLabel="Image preview"
    className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-sm
               animate-in fade-in duration-150"
    onClick={_ => onClose()}
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
    // Image
    <img
      src
      alt="Preview"
      className="max-w-[90vw] max-h-[90vh] object-contain rounded-lg shadow-2xl
                 animate-in zoom-in-95 duration-200"
      onClick={e => ReactEvent.Mouse.stopPropagation(e)}
    />
  </div>
}
