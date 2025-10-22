open UIEventsAPI

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/TouchEvent)
*/
@new
external make: (~type_: string, ~eventInitDict: touchEventInit=?) => touchEvent = "TouchEvent"

include UIEvent.Impl({type t = touchEvent})
