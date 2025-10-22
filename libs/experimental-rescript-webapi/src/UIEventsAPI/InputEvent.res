open UIEventsAPI
open DOMAPI

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/InputEvent)
*/
@new
external make: (~type_: string, ~eventInitDict: inputEventInit=?) => inputEvent = "InputEvent"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/InputEvent/getTargetRanges)
*/
@send
external getTargetRanges: inputEvent => array<staticRange> = "getTargetRanges"

include UIEvent.Impl({type t = inputEvent})
