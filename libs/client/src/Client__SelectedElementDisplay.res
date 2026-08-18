module Icons = Client__ToolIcons
module Annotation = Client__Annotation__Types
module UIIcons = Client__UI__Icons

module AnnotationRow = {
  @react.component
  let make = (~annotation: Annotation.t, ~index: int) => {
    let tagName = annotation.tagName->String.toLowerCase
    let (isEditingComment, setIsEditingComment) = React.useState(() => false)
    let (commentDraft, setCommentDraft) = React.useState(() => annotation.comment->Option.getOr(""))
    let inputRef = React.useRef(Nullable.null)

    let textContent = switch annotation.penShape {
    | Some({documentBoundingBox: Annotation.DocumentBoundingBox(box)}) =>
      `Pen mark: x=${box.x->Float.toString}, y=${box.y->Float.toString}, width=${box.width->Float.toString}, height=${box.height->Float.toString}`
    | None =>
      annotation.nearbyText->Option.getOr(
        annotation.element
        ->WebAPI.Element.asNode
        ->WebAPI.Node.textContent
        ->Null.toOption
        ->Option.getOr("")
        ->String.trim,
      )
    }

    let displayText = switch textContent->String.length > 60 {
    | true => textContent->String.slice(~start=0, ~end=60) ++ "..."
    | false => textContent
    }

    React.useEffect(() => {
      switch isEditingComment {
      | true =>
        setCommentDraft(_ => annotation.comment->Option.getOr(""))
        switch inputRef.current->Nullable.toOption {
        | Some(input) => (input->Obj.magic)["focus"]()
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
      <div
        className="flex-shrink-0 flex items-center justify-center w-5 h-5 rounded-full bg-white/10 text-zinc-300 text-[10px] font-bold mt-0.5"
      >
        {React.int(index + 1)}
      </div>
      <div className="flex-1 min-w-0">
        {annotation.sourceLocation
        ->Result.getOr(None)
        ->Option.mapOr(React.null, loc =>
          loc.componentName->Option.mapOr(React.null, compName =>
            <div className="font-mono text-xs text-zinc-200 truncate">
              {React.string(`<${compName} />`)}
            </div>
          )
        )}
        <div className="font-mono text-xs text-zinc-400 truncate flex items-center gap-1">
          {React.string(
            switch annotation.penShape {
            | Some(_) => `${displayText} in <${tagName}>`
            | None =>
              switch displayText->String.length > 0 {
              | true => `<${tagName}>: ${displayText}`
              | false => `<${tagName}>`
              }
            },
          )}
          {switch annotation.enrichmentStatus {
          | Client__Annotation__Types.Enriching =>
            <span
              className="text-violet-400 text-[10px] animate-pulse"
              title="Enriching annotation details..."
            >
              {React.string("⏳")}
            </span>
          | Client__Annotation__Types.Failed({error}) =>
            <span className="text-amber-400 text-[10px]" title={`Enrichment failed: ${error}`}>
              {React.string("⚠")}
            </span>
          | Client__Annotation__Types.Enriched => React.null
          }}
        </div>
        {annotation.elementorContext->Option.mapOr(React.null, context => {
          let target = switch context.postId {
          | Some(postId) => `post ${postId->Int.toString}, element ${context.elementId}`
          | None => `element ${context.elementId}`
          }
          let kind = switch (context.elementType, context.widgetType) {
          | (Some("widget"), Some(widgetType)) => `Elementor ${widgetType} widget`
          | (Some(elementType), _) => `Elementor ${elementType}`
          | _ => "Elementor element"
          }
          <div className="text-[11px] text-violet-300/80 mt-0.5 truncate">
            {React.string(`${kind} (${target})`)}
          </div>
        })}
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
      <button
        type_="button"
        onClick={_ => Client__State.Actions.removeAnnotation(~id=annotation.id)}
        className="flex-shrink-0 opacity-0 group-hover:opacity-100 flex items-center justify-center w-5 h-5 rounded text-zinc-500 hover:text-red-400 hover:bg-red-400/10 transition-all"
        title="Remove annotation"
      >
        <UIIcons.Cross2Icon className="size-3" />
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
  let reversed = annotations->Array.toReversed
  let visibleAnnotations = switch (hasOverflow, isExpanded) {
  | (true, false) => reversed->Array.slice(~start=0, ~end=_collapsedLimit)
  | _ => reversed
  }

  switch count > 0 {
  | false => React.null
  | true =>
    <div className="mx-3 mb-1 overflow-hidden">
      <div className="flex items-center gap-2 px-0.5 py-1.5">
        <Icons.CursorClickIcon size=14 className="text-zinc-400 flex-shrink-0" />
        <span className="text-xs font-medium text-zinc-400 flex-grow">
          {React.string(count == 1 ? "Annotated Item" : `Annotated Items (${Int.toString(count)})`)}
        </span>
        <button
          onClick={_ => Client__State.Actions.clearAnnotations()}
          className="px-2 py-0.5 rounded text-xs text-zinc-500 hover:text-zinc-300 hover:bg-white/6 transition-colors flex-shrink-0"
          title="Clear all annotations"
        >
          {React.string("Clear")}
        </button>
      </div>
      <div
        className={`px-3.5 pb-3 flex flex-col gap-2 min-w-0
                   ${isExpanded && hasOverflow ? "max-h-48 overflow-y-auto" : ""}`}
      >
        {visibleAnnotations
        ->Array.map(annotation => {
          let originalIndex = annotations->Array.findIndex(a => a.id == annotation.id)
          <AnnotationRow key={annotation.id} annotation index={originalIndex} />
        })
        ->React.array}
      </div>
      {switch hasOverflow {
      | true =>
        <button
          type_="button"
          onClick={_ => setIsExpanded(prev => !prev)}
          className="w-full px-0.5 py-1.5 text-xs text-zinc-400 hover:text-zinc-200 transition-colors border-t border-white/8"
        >
          {React.string(
            isExpanded ? "Show less" : `+${Int.toString(count - _collapsedLimit)} more`,
          )}
        </button>
      | false => React.null
      }}
    </div>
  }
}
