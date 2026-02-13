/**
 * Client__WebPreview__AnnotationControls - Annotation mode toolbar
 *
 * Rendered inline in the Nav.Navigation bar. Provides:
 * - Mode toggle: Off / Quick / Batch
 * - Annotation count badge (when > 0)
 * - Clear all button (when > 0)
 * - Animation freeze toggle (when in selection mode)
 */

module Annotation = Client__Annotation__Types
module RadixUI__Icons = Bindings__RadixUI__Icons

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

// Mode button within the segmented control
module ModeButton = {
  @react.component
  let make = (
    ~label: string,
    ~isActive: bool,
    ~onClick: unit => unit,
    ~tooltip: string,
  ) => {
    <button
      type_="button"
      onClick={_ => onClick()}
      className={`px-2 py-1 text-[10px] font-medium rounded transition-colors
                 ${isActive
          ? "bg-violet-600 text-white"
          : "text-gray-500 hover:text-gray-700 hover:bg-gray-200"}`}
      title={tooltip}
    >
      {React.string(label)}
    </button>
  }
}

@react.component
let make = (
  ~mode: Annotation.annotationMode,
  ~annotationCount: int,
  ~onSetMode: Annotation.annotationMode => unit,
  ~onClear: unit => unit,
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
    // Segmented mode toggle
    <div className="flex items-center bg-gray-100 rounded-lg p-0.5">
      <ModeButton
        label="Off"
        isActive={mode == Off}
        onClick={() => onSetMode(Off)}
        tooltip="Disable element selection"
      />
      <ModeButton
        label="Quick"
        isActive={mode == Quick}
        onClick={() => onSetMode(Quick)}
        tooltip="Quick mode: click to select one element"
      />
      <ModeButton
        label="Batch"
        isActive={mode == Batch}
        onClick={() => onSetMode(Batch)}
        tooltip="Batch mode: click to annotate multiple elements with comments"
      />
    </div>
    // Freeze toggle (only when in selection mode)
    {switch isSelecting {
    | true =>
      <button
        type_="button"
        onClick={_ => setIsFrozen(prev => !prev)}
        className={`flex items-center justify-center w-6 h-6 rounded transition-colors
                   ${isFrozen
            ? "bg-blue-500 text-white"
            : "text-gray-400 hover:text-gray-600 hover:bg-gray-200"}`}
        title={isFrozen ? "Resume animations" : "Freeze animations"}
      >
        <RadixUI__Icons.CountdownTimerIcon className="size-3" />
      </button>
    | false => React.null
    }}
    // Count badge + clear button
    {switch annotationCount > 0 {
    | true =>
      <div className="flex items-center gap-0.5">
        <span
          className="inline-flex items-center justify-center min-w-[18px] h-[18px] px-1 text-[10px] font-semibold rounded-full bg-violet-100 text-violet-700"
        >
          {React.int(annotationCount)}
        </span>
        <button
          type_="button"
          onClick={_ => onClear()}
          className="flex items-center justify-center w-5 h-5 rounded text-gray-400 hover:text-red-500 hover:bg-red-50 transition-colors"
          title="Clear all annotations"
        >
          <RadixUI__Icons.Cross2Icon className="size-3" />
        </button>
      </div>
    | false => React.null
    }}
  </div>
}
