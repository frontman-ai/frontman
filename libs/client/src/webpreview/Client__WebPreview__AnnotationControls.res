/**
 * Client__WebPreview__AnnotationControls - Annotation mode toolbar
 *
 * Rendered inline in the Nav.Navigation bar. Provides:
 * - Single toggle: Off / Selecting
 * - Animation freeze toggle (when in selection mode)
 */

module Annotation = Client__Annotation__Types
module RadixUI__Icons = Bindings__RadixUI__Icons
module Icons = Client__ToolIcons

// Inject/remove animation freeze CSS into an iframe document
let _freezeStyleId = "frontman-animation-freeze"

let _injectFreezeCSS: WebAPI.DOMAPI.document => unit = %raw(`
  function(doc) {
    if (doc.getElementById("frontman-animation-freeze")) return;
    var style = doc.createElement("style");
    style.id = "frontman-animation-freeze";
    style.textContent = "*, *::before, *::after { animation-play-state: paused !important; transition: none !important; }";
    doc.head.appendChild(style);
    // Pause videos
    doc.querySelectorAll("video").forEach(function(v) { try { v.pause(); } catch(e) {} });
  }
`)

let _removeFreezeCSS: WebAPI.DOMAPI.document => unit = %raw(`
  function(doc) {
    var el = doc.getElementById("frontman-animation-freeze");
    if (el) el.remove();
    // Resume videos
    doc.querySelectorAll("video").forEach(function(v) { try { v.play(); } catch(e) {} });
  }
`)

@react.component
let make = (
  ~mode: Annotation.annotationMode,
  ~onToggle: unit => unit,
  ~previewDocument: option<WebAPI.DOMAPI.document>=?,
) => {
  let (isFrozen, setIsFrozen) = React.useState(() => false)
  let isSelecting = mode != Off

  // Apply/remove freeze CSS when toggle changes
  React.useEffect2(() => {
    switch previewDocument {
    | Some(doc) =>
      if isFrozen {
        _injectFreezeCSS(doc)
      } else {
        _removeFreezeCSS(doc)
      }
    | None => ()
    }
    // Cleanup: always remove freeze CSS when unmounting
    Some(() => {
      previewDocument->Option.forEach(doc => _removeFreezeCSS(doc))
    })
  }, (isFrozen, previewDocument))

  // Auto-unfreeze when leaving selection mode
  React.useEffect1(() => {
    if !isSelecting && isFrozen {
      setIsFrozen(_ => false)
    }
    None
  }, [isSelecting])

  <div className="flex items-center gap-1">
    // Select toggle button — uses CursorClickIcon, matches other nav icon buttons
    <button
      type_="button"
      onClick={_ => onToggle()}
      className={`flex items-center justify-center w-8 h-8 rounded-lg transition-colors
                 ${isSelecting
          ? "bg-violet-600 text-white hover:bg-violet-500"
          : "bg-gray-200 text-gray-600 hover:bg-gray-300 hover:text-gray-700"}`}
      title={isSelecting ? "Stop selecting elements" : "Click elements to annotate them"}
    >
      <Icons.CursorClickIcon size=16 />
    </button>
    // Freeze toggle (only when in selection mode)
    {switch isSelecting {
    | true =>
      <button
        type_="button"
        onClick={_ => setIsFrozen(prev => !prev)}
        className={`flex items-center justify-center w-8 h-8 rounded-lg transition-colors
                   ${isFrozen
            ? "bg-blue-600 text-white hover:bg-blue-500"
            : "bg-gray-200 text-gray-600 hover:bg-gray-300 hover:text-gray-700"}`}
        title={isFrozen ? "Resume animations" : "Freeze animations"}
      >
        <RadixUI__Icons.CountdownTimerIcon className="size-4" />
      </button>
    | false => React.null
    }}

  </div>
}
