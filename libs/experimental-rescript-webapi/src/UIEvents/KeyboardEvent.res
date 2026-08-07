@new
external make: (
  ~type_: string,
  ~eventInitDict: UiEventsTypes.keyboardEventInit=?,
) => UiEventsTypes.keyboardEvent = "KeyboardEvent"

@send
external getModifierState: (UiEventsTypes.keyboardEvent, string) => bool = "getModifierState"

include UIEvent.Impl({type t = UiEventsTypes.keyboardEvent})
