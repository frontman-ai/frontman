@new
external make: (
  ~type_: string,
  ~eventInitDict: UiEventsTypes.touchEventInit=?,
) => UiEventsTypes.touchEvent = "TouchEvent"

include UIEvent.Impl({type t = UiEventsTypes.touchEvent})
