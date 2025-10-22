open UIEventsAPI

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CompositionEvent)
*/
@new
external make: (~type_: string, ~eventInitDict: compositionEventInit=?) => compositionEvent =
  "CompositionEvent"

include UIEvent.Impl({type t = compositionEvent})
