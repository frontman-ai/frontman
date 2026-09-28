/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/InputEvent)
*/
@new
external make: (
  ~type_: string,
  ~eventInitDict: UiEventsTypes.inputEventInit=?,
) => UiEventsTypes.inputEvent = "InputEvent"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/InputEvent/getTargetRanges)
*/
@send
external getTargetRanges: UiEventsTypes.inputEvent => array<DOM.staticRange> = "getTargetRanges"

include UIEvent.Impl({type t = UiEventsTypes.inputEvent})
