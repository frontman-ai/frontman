/**
 * Client__WebPreview__AnnotationPopup - Non-blocking comment input for annotations
 *
 * Appears near a newly-annotated element. The annotation already exists in state;
 * this popup is purely an optional comment-entry convenience.
 * - Typing updates the annotation's comment via UpdateAnnotationComment
 * - Enter closes the popup (comment is already saved)
 * - Escape closes the popup (annotation remains, no comment)
 * - Clicking another element auto-closes this popup (handled by parent)
 */

module Annotation = Client__Annotation__Types
module RadixUI__Icons = Bindings__RadixUI__Icons

@react.component
let make = (
  ~annotation: Annotation.t,
  ~index: int,
  ~scrollTimestamp: float,
  ~mutationTimestamp: float,
  ~onCommentChange: string => unit,
  ~onClose: unit => unit,
) => {
  let (comment, setComment) = React.useState(() =>
    annotation.comment->Option.getOr("")
  )
  let inputRef = React.useRef(Nullable.null)
  let (rect, setRect) = React.useState(() => None)

  // Position popup relative to the annotated element
  React.useEffect(() => {
    let boundingRect = WebAPI.Element.getBoundingClientRect(annotation.element)
    setRect(_ => Some(boundingRect))
    None
  }, (annotation.element, scrollTimestamp, mutationTimestamp))

  // Auto-focus the input once it renders (rect must be Some for the input to exist)
  React.useEffect(() => {
    switch (rect, inputRef.current->Nullable.toOption) {
    | (Some(_), Some(input)) => (input->Obj.magic)["focus"](.)
    | _ => ()
    }
    None
  }, [rect->Option.isSome])

  let handleKeyDown = (e: ReactEvent.Keyboard.t) => {
    switch ReactEvent.Keyboard.key(e) {
    | "Enter" =>
      ReactEvent.Keyboard.preventDefault(e)
      onClose()
    | "Escape" =>
      ReactEvent.Keyboard.preventDefault(e)
      onClose()
    | _ => ()
    }
  }

  let handleChange = (e: ReactEvent.Form.t) => {
    let value: string = ReactEvent.Form.target(e)["value"]
    setComment(_ => value)
    onCommentChange(value)
  }

  switch rect {
  | Some(rect) => {
      let top = rect.top +. rect.height +. 8.0
      let left = rect.left

      <div
        className="absolute z-[10000] pointer-events-auto"
        style={
          top: `min(${Float.toString(top)}px, calc(100vh - 80px))`,
          left: `clamp(8px, ${Float.toString(left)}px, calc(100vw - 328px))`,
        }
      >
        // Popup card
        <div
          className="bg-white rounded-lg shadow-lg border border-gray-200 p-2 min-w-[240px] max-w-[320px]"
        >
          <div className="flex items-center gap-1.5 mb-1">
            // Number badge
            <div
              className="flex items-center justify-center w-4 h-4 rounded-full bg-violet-600 text-white text-[9px] font-bold"
            >
              {React.int(index + 1)}
            </div>
            <span className="text-[11px] text-gray-500 font-medium">
              {React.string(`<${annotation.tagName}>`)}
            </span>
          </div>
          <div className="flex items-center gap-1">
            <input
              ref={ReactDOM.Ref.domRef(inputRef)}
              type_="text"
              value={comment}
              onChange={handleChange}
              onKeyDown={handleKeyDown}
              placeholder="Add a comment (optional)..."
              className="flex-1 h-7 px-2 text-xs bg-gray-50 border border-gray-200 rounded
                         text-gray-700 placeholder-gray-400
                         focus:outline-none focus:ring-1 focus:ring-violet-500/50 focus:border-violet-500/50"
            />
            <button
              type_="button"
              onClick={_ => onClose()}
              className="flex items-center justify-center w-7 h-7 rounded
                         text-gray-400 hover:text-gray-600 hover:bg-gray-100 transition-colors"
              title="Close (Enter or Escape)"
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
