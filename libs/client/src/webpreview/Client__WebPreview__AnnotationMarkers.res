/**
 * Client__WebPreview__AnnotationMarkers - Numbered markers for annotations
 *
 * Renders a border highlight and numbered badge for each annotation,
 * positioned over the annotated element using getBoundingClientRect.
 * Re-queries position on scroll/mutation changes.
 * Click the badge to deselect (remove) that annotation.
 */

module Annotation = Client__Annotation__Types

// Single annotation marker: border + numbered badge
module Marker = {
  @react.component
  let make = (
    ~annotation: Annotation.t,
    ~index: int,
    ~scrollTimestamp: float,
    ~mutationTimestamp: float,
    ~onRemove: string => unit,
  ) => {
    let (rect, setRect) = React.useState(() => None)

    React.useEffect(() => {
      let boundingRect = WebAPI.Element.getBoundingClientRect(annotation.element)
      setRect(_ => Some(boundingRect))
      None
    }, (annotation.element, scrollTimestamp, mutationTimestamp))

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
        <div
          className="absolute inset-0 border-2 border-[#985DF7] rounded-sm box-border ring-1 ring-[#985DF7]/30"
        />
        // Numbered badge at top-left — click to deselect
        <div
          className="absolute -top-3 -left-3 flex items-center justify-center w-6 h-6 rounded-full bg-violet-600 text-white text-[10px] font-bold shadow-sm border-2 border-white pointer-events-auto cursor-pointer hover:bg-red-500 transition-colors"
          onClick={e => {
            ReactEvent.Mouse.stopPropagation(e)
            onRemove(annotation.id)
          }}
          title="Click to deselect"
        >
          {React.int(index + 1)}
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
    />
  })
  ->React.array
}
