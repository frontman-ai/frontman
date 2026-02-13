/**
 * Client__WebPreview__AnnotationPopup - Comment input popup for batch annotation mode
 *
 * Appears near the pending element when the user clicks in Batch mode.
 * Provides a text input for the annotation comment, confirm, and cancel.
 * Supports Enter to confirm and Escape to cancel.
 */

module Annotation = Client__Annotation__Types
module RadixUI__Icons = Bindings__RadixUI__Icons

@react.component
let make = (
  ~pending: Annotation.pending,
  ~scrollTimestamp: float,
  ~mutationTimestamp: float,
  ~onConfirm: option<string> => unit,
  ~onCancel: unit => unit,
) => {
  let (comment, setComment) = React.useState(() => "")
  let inputRef = React.useRef(Nullable.null)
  let (rect, setRect) = React.useState(() => None)

  // Position popup relative to the pending element
  React.useEffect(() => {
    let boundingRect = WebAPI.Element.getBoundingClientRect(pending.element)
    setRect(_ => Some(boundingRect))
    None
  }, (pending.element, scrollTimestamp, mutationTimestamp))

  // Auto-focus the input when mounted
  React.useEffect0(() => {
    switch inputRef.current->Nullable.toOption {
    | Some(input) => (input->Obj.magic)["focus"](.)
    | None => ()
    }
    None
  })

  let handleConfirm = () => {
    let trimmed = comment->String.trim
    let commentOpt = trimmed->String.length > 0 ? Some(trimmed) : None
    onConfirm(commentOpt)
  }

  let handleKeyDown = (e: ReactEvent.Keyboard.t) => {
    switch ReactEvent.Keyboard.key(e) {
    | "Enter" =>
      ReactEvent.Keyboard.preventDefault(e)
      handleConfirm()
    | "Escape" =>
      ReactEvent.Keyboard.preventDefault(e)
      onCancel()
    | _ => ()
    }
  }

  switch rect {
  | Some(rect) => {
      // Position popup below the element, clamped to viewport
      let top = rect.top +. rect.height +. 8.0
      let left = rect.left

      <div
        className="absolute z-[10000] pointer-events-auto"
        style={
          top: `${Float.toString(top)}px`,
          left: `${Float.toString(left)}px`,
        }
      >
        // Highlight the pending element with a dashed border
        <div
          className="absolute border-2 border-dashed border-violet-400 rounded-sm pointer-events-none z-[9999] box-border"
          style={
            top: `${Float.toString(rect.top -. top)}px`,
            left: "0px",
            width: `${Float.toString(rect.width)}px`,
            height: `${Float.toString(rect.height)}px`,
          }
        />
        // Popup card
        <div
          className="bg-white rounded-lg shadow-lg border border-gray-200 p-2 min-w-[240px] max-w-[320px]"
        >
          <div className="text-[11px] text-gray-500 mb-1 font-medium">
            {React.string(`Annotate <${pending.tagName}>`)}
          </div>
          <div className="flex items-center gap-1">
            <input
              ref={ReactDOM.Ref.domRef(inputRef)}
              type_="text"
              value={comment}
              onChange={e => setComment(_ => ReactEvent.Form.target(e)["value"])}
              onKeyDown={handleKeyDown}
              placeholder="Add a comment (optional)..."
              className="flex-1 h-7 px-2 text-xs bg-gray-50 border border-gray-200 rounded
                         text-gray-700 placeholder-gray-400
                         focus:outline-none focus:ring-1 focus:ring-violet-500/50 focus:border-violet-500/50"
            />
            <button
              type_="button"
              onClick={_ => handleConfirm()}
              className="flex items-center justify-center h-7 px-2 text-xs font-medium rounded
                         bg-violet-600 text-white hover:bg-violet-500 transition-colors"
              title="Confirm annotation (Enter)"
            >
              {React.string("Add")}
            </button>
            <button
              type_="button"
              onClick={_ => onCancel()}
              className="flex items-center justify-center w-7 h-7 rounded
                         text-gray-400 hover:text-gray-600 hover:bg-gray-100 transition-colors"
              title="Cancel (Escape)"
            >
              <RadixUI__Icons.Cross2Icon className="size-3" />
            </button>
          </div>
        </div>
      </div>
    }
  | None => React.null
  }
}
