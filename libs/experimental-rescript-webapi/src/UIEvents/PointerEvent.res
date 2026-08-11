/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/PointerEvent)
*/
@new
external make: (
  ~type_: string,
  ~eventInitDict: UiEventsTypes.pointerEventInit=?,
) => UiEventsTypes.pointerEvent = "PointerEvent"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/PointerEvent/getCoalescedEvents)
*/
@send
external getCoalescedEvents: UiEventsTypes.pointerEvent => array<UiEventsTypes.pointerEvent> =
  "getCoalescedEvents"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/PointerEvent/getPredictedEvents)
*/
@send
external getPredictedEvents: UiEventsTypes.pointerEvent => array<UiEventsTypes.pointerEvent> =
  "getPredictedEvents"

include MouseEvent.Impl({type t = UiEventsTypes.pointerEvent})
