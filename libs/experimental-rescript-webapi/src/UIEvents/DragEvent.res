@new
external make: (
  ~type_: string,
  ~eventInitDict: UiEventsTypes.dragEventInit=?,
) => UiEventsTypes.dragEvent = "DragEvent"

include MouseEvent.Impl({type t = UiEventsTypes.dragEvent})
