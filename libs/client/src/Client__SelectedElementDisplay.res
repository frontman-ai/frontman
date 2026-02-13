module Icons = Client__ToolIcons
module Annotation = Client__Annotation__Types
module RadixUI__Icons = Bindings__RadixUI__Icons

// Single annotation row
module AnnotationRow = {
  @react.component
  let make = (~annotation: Annotation.t, ~index: int) => {
    let tagName = annotation.tagName->String.toLowerCase
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
    let displayText = if textContent->String.length > 60 {
      textContent->String.slice(~start=0, ~end=60) ++ "..."
    } else {
      textContent
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
        // Component name (if available)
        {annotation.sourceLocation->Option.mapOr(React.null, loc =>
          loc.componentName->Option.mapOr(React.null, compName =>
            <div className="font-mono text-xs text-zinc-200 truncate">
              {React.string(`<${compName} />`)}
            </div>
          )
        )}
        // Element tag + text
        <div className="font-mono text-xs text-zinc-400 truncate">
          {React.string(
            if displayText->String.length > 0 {
              `<${tagName}>: ${displayText}`
            } else {
              `<${tagName}>`
            },
          )}
        </div>
        // Comment (if present)
        {switch annotation.comment {
        | Some(comment) =>
          <div className="text-xs text-violet-300/80 mt-0.5 italic truncate">
            {React.string(`"${comment}"`)}
          </div>
        | None => React.null
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

@react.component
let make = () => {
  let annotations = Client__State.useSelector(Client__State.Selectors.annotations)

  switch Array.length(annotations) > 0 {
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
            Array.length(annotations) == 1
              ? "Annotated Element"
              : `Annotated Elements (${Int.toString(Array.length(annotations))})`,
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
      // Annotation rows
      <div className="px-3.5 pb-3 flex flex-col gap-2 min-w-0">
        {annotations
        ->Array.mapWithIndex((annotation, index) => {
          <AnnotationRow key={annotation.id} annotation index />
        })
        ->React.array}
      </div>
    </div>
  }
}
