@new
external make: (
  ~type_: string,
  ~eventInitDict: UiEventsTypes.wheelEventInit=?,
) => UiEventsTypes.wheelEvent = "WheelEvent"

include MouseEvent.Impl({type t = UiEventsTypes.wheelEvent})
