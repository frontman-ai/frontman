/**
 * Client__WebPreview__AnnotationMarkers - Numbered markers for annotations
 *
 * Renders a border highlight and numbered badge for each annotation,
 * positioned over the annotated element using getBoundingClientRect.
 * Re-queries position on scroll/mutation changes.
 * Number badge top-left: click to deselect.
 * Tree nav control top-right: ↑/↓ to walk to parent/first-child.
 */

module Annotation = Client__Annotation__Types
module RadixUI__Icons = Bindings__RadixUI__Icons

// Walk to parent element, stopping at body/html
let getParentEl = (element: WebAPI.DOMAPI.element): option<WebAPI.DOMAPI.element> =>
  element.parentElement
  ->Null.toOption
  ->Option.flatMap(pe => {
    switch (pe->Obj.magic : WebAPI.DOMAPI.element).tagName->String.toLowerCase {
    | "body" | "html" => None
    | _ => Some(pe->Obj.magic)
    }
  })

// Single annotation marker: border + badge (top-left) + tree nav (top-right)
module Marker = {
  @react.component
  let make = (
    ~annotation: Annotation.t,
    ~index: int,
    ~scrollTimestamp: float,
    ~mutationTimestamp: float,
    ~onRemove: string => unit,
    ~onNavigate: WebAPI.DOMAPI.element => unit,
  ) => {
    let (rect, setRect) = React.useState(() => None)

    React.useEffect(() => {
      let boundingRect = WebAPI.Element.getBoundingClientRect(annotation.element)
      setRect(_ => Some(boundingRect))
      None
    }, (annotation.element, scrollTimestamp, mutationTimestamp))

    let parentEl = getParentEl(annotation.element)
    let firstChildEl = annotation.element.firstElementChild->Null.toOption

    // Border and badge color vary based on enrichment status
    let (borderClass, badgeColorClass) = switch annotation.enrichmentStatus {
    | Annotation.Enriching => (
        "absolute inset-0 border-2 border-[#985DF7] rounded-sm box-border ring-1 ring-[#985DF7]/30",
        "bg-violet-600 animate-pulse",
      )
    | Annotation.Failed(_) => (
        "absolute inset-0 border-2 border-amber-500 rounded-sm box-border ring-1 ring-amber-500/30",
        "bg-amber-600",
      )
    | Annotation.Enriched => (
        "absolute inset-0 border-2 border-[#985DF7] rounded-sm box-border ring-1 ring-[#985DF7]/30",
        "bg-violet-600",
      )
    }

    switch rect {
    | Some(rect) =>
      <div
        className="absolute pointer-events-none z-[9999]"
        style={
          left: `${Float.toString(rect.left)}px`,
          top: `${Float.toString(rect.top)}px`,
          width: `${Float.toString(rect.width)}px`,
          height: `${Float.toString(rect.height)}px`,
        }
      >
        // Border highlight
        <div className={borderClass} />
        // Number badge — top-left, click to deselect
        <div
          className={`absolute -top-3 -left-3 flex items-center justify-center w-6 h-6 rounded-full ${badgeColorClass} text-white text-[10px] font-bold shadow-sm border-2 border-white pointer-events-auto cursor-pointer hover:bg-red-500 transition-colors`}
          onClick={e => {
            ReactEvent.Mouse.stopPropagation(e)
            onRemove(annotation.id)
          }}
          title="Click to deselect"
        >
          {React.int(index + 1)}
        </div>
        // Tree nav control — top-right, stacked ↑/↓ chevrons
        <div
          className="absolute -top-3 -right-3 flex flex-col items-center bg-violet-600 text-white shadow-sm border-2 border-white rounded-full pointer-events-auto overflow-hidden"
        >
          // Up — navigate to parent
          {switch parentEl {
          | Some(parent) =>
            <button
              type_="button"
              className="flex items-center justify-center w-5 h-3 hover:bg-white/25 transition-colors"
              title="Select parent element"
              onClick={e => {
                ReactEvent.Mouse.stopPropagation(e)
                ReactEvent.Mouse.preventDefault(e)
                onNavigate(parent)
              }}
            >
              <RadixUI__Icons.ChevronUpIcon className="size-2.5" />
            </button>
          | None =>
            <div className="flex items-center justify-center w-5 h-3 opacity-25 cursor-default">
              <RadixUI__Icons.ChevronUpIcon className="size-2.5" />
            </div>
          }}
          // Down — navigate to first child
          {switch firstChildEl {
          | Some(child) =>
            <button
              type_="button"
              className="flex items-center justify-center w-5 h-3 hover:bg-white/25 transition-colors"
              title="Select first child element"
              onClick={e => {
                ReactEvent.Mouse.stopPropagation(e)
                ReactEvent.Mouse.preventDefault(e)
                onNavigate(child)
              }}
            >
              <RadixUI__Icons.ChevronDownIcon className="size-2.5" />
            </button>
          | None =>
            <div className="flex items-center justify-center w-5 h-3 opacity-25 cursor-default">
              <RadixUI__Icons.ChevronDownIcon className="size-2.5" />
            </div>
          }}
        </div>
      </div>
    | None => React.null
    }
  }
}

@react.component
let make = (
  ~annotations: array<Annotation.t>,
  ~scrollTimestamp: float,
  ~mutationTimestamp: float,
  ~onRemove: string => unit,
  ~onNavigate: (string, WebAPI.DOMAPI.element) => unit,
) => {
  annotations
  ->Array.mapWithIndex((annotation, index) => {
    <Marker
      key={annotation.id}
      annotation
      index
      scrollTimestamp
      mutationTimestamp
      onRemove
      onNavigate={el => onNavigate(annotation.id, el)}
    />
  })
  ->React.array
}
