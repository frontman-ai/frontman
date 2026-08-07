@new
external make: (
  ~type_: string,
  ~eventInitDict: UiEventsTypes.inputEventInit=?,
) => UiEventsTypes.inputEvent = "InputEvent"

@send
external getTargetRanges: UiEventsTypes.inputEvent => array<DOM.staticRange> = "getTargetRanges"

include UIEvent.Impl({type t = UiEventsTypes.inputEvent})
