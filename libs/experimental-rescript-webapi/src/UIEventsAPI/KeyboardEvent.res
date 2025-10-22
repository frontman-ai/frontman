open UIEventsAPI

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/KeyboardEvent)
*/
@new
external make: (~type_: string, ~eventInitDict: keyboardEventInit=?) => keyboardEvent =
  "KeyboardEvent"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/KeyboardEvent/getModifierState)
*/
@send
external getModifierState: (keyboardEvent, string) => bool = "getModifierState"

include UIEvent.Impl({type t = keyboardEvent})
