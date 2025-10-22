open UIEventsAPI

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/PointerEvent)
*/
@new
external make: (~type_: string, ~eventInitDict: pointerEventInit=?) => pointerEvent = "PointerEvent"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/PointerEvent/getCoalescedEvents)
*/
@send
external getCoalescedEvents: pointerEvent => array<pointerEvent> = "getCoalescedEvents"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/PointerEvent/getPredictedEvents)
*/
@send
external getPredictedEvents: pointerEvent => array<pointerEvent> = "getPredictedEvents"

include MouseEvent.Impl({type t = pointerEvent})
