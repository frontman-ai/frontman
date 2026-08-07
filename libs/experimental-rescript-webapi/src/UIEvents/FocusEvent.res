@new
external make: (
  ~type_: string,
  ~eventInitDict: UiEventsTypes.focusEventInit=?,
) => UiEventsTypes.focusEvent = "FocusEvent"

include UIEvent.Impl({type t = UiEventsTypes.focusEvent})
