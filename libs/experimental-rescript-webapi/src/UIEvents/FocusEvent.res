/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FocusEvent)
*/
@new
external make: (
  ~type_: string,
  ~eventInitDict: UiEventsTypes.focusEventInit=?,
) => UiEventsTypes.focusEvent = "FocusEvent"

include UIEvent.Impl({type t = UiEventsTypes.focusEvent})
