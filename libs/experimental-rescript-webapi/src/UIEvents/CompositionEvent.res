@new
external make: (
  ~type_: string,
  ~eventInitDict: UiEventsTypes.compositionEventInit=?,
) => UiEventsTypes.compositionEvent = "CompositionEvent"

include UIEvent.Impl({type t = UiEventsTypes.compositionEvent})
