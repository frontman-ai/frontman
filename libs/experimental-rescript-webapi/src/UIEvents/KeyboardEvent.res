/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/KeyboardEvent)
*/
@new
external make: (
  ~type_: string,
  ~eventInitDict: UiEventsTypes.keyboardEventInit=?,
) => UiEventsTypes.keyboardEvent = "KeyboardEvent"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/KeyboardEvent/getModifierState)
*/
@send
external getModifierState: (UiEventsTypes.keyboardEvent, string) => bool = "getModifierState"

include UIEvent.Impl({type t = UiEventsTypes.keyboardEvent})
