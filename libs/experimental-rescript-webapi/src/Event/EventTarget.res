@new
external make: unit => EventTypes.eventTarget = "EventTarget"

external asElement: EventTypes.eventTarget => DomTypes.element = "%identity"

module Impl = (
  T: {
    type t
  },
) => {
  external asEventTarget: T.t => EventTypes.eventTarget = "%identity"

  @send
  external addEventListener: (
    T.t,
    EventTypes.eventType,
    EventTypes.eventListener<'event>,
    ~options: EventTypes.addEventListenerOptions=?,
  ) => unit = "addEventListener"

  @send
  external addEventListenerWithCapture: (
    T.t,
    EventTypes.eventType,
    EventTypes.eventListener<'event>,
    @as(json`true`) _,
  ) => unit = "addEventListener"

  @send
  external removeEventListener: (
    T.t,
    EventTypes.eventType,
    EventTypes.eventListener<'event>,
    ~options: EventTypes.eventListenerOptions=?,
  ) => unit = "removeEventListener"

  @send
  external removeEventListenerUseCapture: (
    T.t,
    EventTypes.eventType,
    EventTypes.eventListener<'event>,
    @as(json`true`) _,
  ) => unit = "removeEventListener"

  @send
  external dispatchEvent: (T.t, EventTypes.event) => bool = "dispatchEvent"
}

include Impl({type t = EventTypes.eventTarget})
