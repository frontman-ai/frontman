type t = EventTypes.eventTarget

external addEventListener: (
  t,
  EventTypes.eventType,
  EventTypes.eventListener<'event>,
  ~options: EventTypes.addEventListenerOptions=?,
) => unit = "addEventListener"

external removeEventListener: (
  t,
  EventTypes.eventType,
  EventTypes.eventListener<'event>,
  ~options: EventTypes.eventListenerOptions=?,
) => unit = "removeEventListener"
