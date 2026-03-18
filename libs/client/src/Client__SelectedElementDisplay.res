module Icons = Client__ToolIcons
module Annotation = Client__Annotation__Types
module RadixUI__Icons = Bindings__RadixUI__Icons

// Single annotation row with inline comment editing
module AnnotationRow = {
  @react.component
  let make = (~annotation: Annotation.t, ~index: int) => {
    let tagName = annotation.tagName->String.toLowerCase
    let (isEditingComment, setIsEditingComment) = React.useState(() => false)
    let (commentDraft, setCommentDraft) = React.useState(() =>
      annotation.comment->Option.getOr("")
    )
    let inputRef = React.useRef(Nullable.null)

    let textContent =
      annotation.nearbyText
      ->Option.getOr(
        annotation.element
        ->WebAPI.Element.asNode
        ->WebAPI.Node.textContent
        ->Null.toOption
        ->Option.getOr("")
        ->String.trim,
      )

    // Truncate text display
    let displayText = switch textContent->String.length > 60 {
    | true => textContent->String.slice(~start=0, ~end=60) ++ "..."
    | false => textContent
    }

    // Re-sync draft and auto-focus when entering edit mode
    React.useEffect(() => {
      switch isEditingComment {
      | true =>
        // Re-init from current reducer state to avoid stale draft
        setCommentDraft(_ => annotation.comment->Option.getOr(""))
        switch inputRef.current->Nullable.toOption {
        | Some(input) => (input->Obj.magic)["focus"](.)
        | None => ()
        }
      | false => ()
      }
      None
    }, [isEditingComment])

    let handleSaveComment = () => {
      Client__State.Actions.updateAnnotationComment(~id=annotation.id, ~comment=commentDraft)
      setIsEditingComment(_ => false)
    }

    let handleKeyDown = (e: ReactEvent.Keyboard.t) => {
      switch ReactEvent.Keyboard.key(e) {
      | "Enter" =>
        ReactEvent.Keyboard.preventDefault(e)
        handleSaveComment()
      | "Escape" =>
        ReactEvent.Keyboard.preventDefault(e)
        setCommentDraft(_ => annotation.comment->Option.getOr(""))
        setIsEditingComment(_ => false)
      | _ => ()
      }
    }

    <div className="flex items-start gap-2 group">
      // Number badge
      <div
        className="flex-shrink-0 flex items-center justify-center w-5 h-5 rounded-full bg-violet-600/80 text-white text-[10px] font-bold mt-0.5"
      >
        {React.int(index + 1)}
      </div>
      // Content
      <div className="flex-1 min-w-0">
        // Component name (if available) — unwrap result for display
        {annotation.sourceLocation->Result.getOr(None)->Option.mapOr(React.null, loc =>
          loc.componentName->Option.mapOr(React.null, compName =>
            <div className="font-mono text-xs text-zinc-200 truncate">
              {React.string(`<${compName} />`)}
            </div>
          )
        )}
        // Element tag + text with enrichment status indicator
        <div className="font-mono text-xs text-zinc-400 truncate flex items-center gap-1">
          {React.string(
            if displayText->String.length > 0 {
              `<${tagName}>: ${displayText}`
            } else {
              `<${tagName}>`
            },
          )}
          {switch annotation.enrichmentStatus {
          | Client__Annotation__Types.Enriching =>
            <span className="text-violet-400 text-[10px] animate-pulse" title="Enriching annotation details...">
              {React.string("⏳")}
            </span>
          | Client__Annotation__Types.Failed({error}) =>
            <span className="text-amber-400 text-[10px]" title={`Enrichment failed: ${error}`}>
              {React.string("⚠")}
            </span>
          | Client__Annotation__Types.Enriched => React.null
          }}
        </div>
        // Comment display / edit
        {switch isEditingComment {
        | true =>
          <input
            ref={ReactDOM.Ref.domRef(inputRef)}
            type_="text"
            value={commentDraft}
            onChange={e => setCommentDraft(_ => ReactEvent.Form.target(e)["value"])}
            onKeyDown={handleKeyDown}
            onBlur={_ => handleSaveComment()}
            placeholder="Add a comment..."
            className="w-full mt-1 h-6 px-1.5 text-xs bg-zinc-800 border border-violet-500/50 rounded
                       text-zinc-200 placeholder-zinc-500
                       focus:outline-none focus:ring-1 focus:ring-violet-500/50"
          />
        | false =>
          switch annotation.comment {
          | Some(comment) =>
            <div
              className="text-xs text-violet-300/80 mt-0.5 italic truncate cursor-pointer hover:text-violet-200 transition-colors"
              onClick={_ => setIsEditingComment(_ => true)}
              title="Click to edit comment"
            >
              {React.string(`"${comment}"`)}
            </div>
          | None =>
            <div
              className="text-xs text-zinc-600 mt-0.5 cursor-pointer hover:text-zinc-400 transition-colors opacity-0 group-hover:opacity-100"
              onClick={_ => setIsEditingComment(_ => true)}
              title="Add a comment"
            >
              {React.string("+ comment")}
            </div>
          }
        }}
      </div>
      // Remove button (visible on hover)
      <button
        type_="button"
        onClick={_ => Client__State.Actions.removeAnnotation(~id=annotation.id)}
        className="flex-shrink-0 opacity-0 group-hover:opacity-100 flex items-center justify-center w-5 h-5 rounded text-zinc-500 hover:text-red-400 hover:bg-red-400/10 transition-all"
        title="Remove annotation"
      >
        <RadixUI__Icons.Cross2Icon className="size-3" />
      </button>
    </div>
  }
}

let _collapsedLimit = 3

@react.component
let make = () => {
  let annotations = Client__State.useSelector(Client__State.Selectors.annotations)
  let (isExpanded, setIsExpanded) = React.useState(() => false)

  let count = Array.length(annotations)
  let hasOverflow = count > _collapsedLimit
  // Reverse so the most recently added annotation is on top
  let reversed = annotations->Array.toReversed
  let visibleAnnotations = switch (hasOverflow, isExpanded) {
  | (true, false) => reversed->Array.slice(~start=0, ~end=_collapsedLimit)
  | _ => reversed
  }

  switch count > 0 {
  | false => React.null
  | true =>
    <div
      className="mx-3 mb-2 rounded-xl border border-[#8051CD]/40 bg-[#180C2D]/80 overflow-hidden"
    >
      // Header row
      <div className="flex items-center gap-2.5 px-3.5 py-2.5">
        <Icons.CursorClickIcon size=18 className="text-[#985DF7] flex-shrink-0" />
        <span className="font-mono text-sm font-semibold text-[#985DF7] flex-grow">
          {React.string(
            count == 1
              ? "Annotated Element"
              : `Annotated Elements (${Int.toString(count)})`,
          )}
        </span>
        // Clear all button
        <button
          onClick={_ => Client__State.Actions.clearAnnotations()}
          className="px-2.5 py-1 rounded-md text-xs font-medium text-zinc-300 bg-[#8051CD]/25 hover:bg-[#8051CD]/40 transition-colors flex-shrink-0"
          title="Clear all annotations"
        >
          {React.string("Clear")}
        </button>
      </div>
      // Annotation rows — scrollable when expanded with many items
      <div
        className={`px-3.5 pb-3 flex flex-col gap-2 min-w-0
                   ${isExpanded && hasOverflow ? "max-h-48 overflow-y-auto" : ""}`}
      >
        {visibleAnnotations
        ->Array.map(annotation => {
          // Find original index so badge numbers match the preview markers
          let originalIndex = annotations->Array.findIndex(a => a.id == annotation.id)
          <AnnotationRow key={annotation.id} annotation index={originalIndex} />
        })
        ->React.array}
      </div>
      // Show more / less toggle
      {switch hasOverflow {
      | true =>
        <button
          type_="button"
          onClick={_ => setIsExpanded(prev => !prev)}
          className="w-full px-3.5 py-1.5 text-xs text-zinc-400 hover:text-zinc-200 transition-colors border-t border-[#8051CD]/20"
        >
          {React.string(
            isExpanded
              ? "Show less"
              : `+${Int.toString(count - _collapsedLimit)} more`,
          )}
        </button>
      | false => React.null
      }}
    </div>
  }
}
