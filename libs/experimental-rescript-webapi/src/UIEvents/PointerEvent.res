@new
external make: (
  ~type_: string,
  ~eventInitDict: UiEventsTypes.pointerEventInit=?,
) => UiEventsTypes.pointerEvent = "PointerEvent"

@send
external getCoalescedEvents: UiEventsTypes.pointerEvent => array<UiEventsTypes.pointerEvent> =
  "getCoalescedEvents"

@send
external getPredictedEvents: UiEventsTypes.pointerEvent => array<UiEventsTypes.pointerEvent> =
  "getPredictedEvents"

include MouseEvent.Impl({type t = UiEventsTypes.pointerEvent})
