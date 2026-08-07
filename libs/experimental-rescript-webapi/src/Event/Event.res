@new
external make: (~type_: string, ~eventInitDict: EventTypes.eventInit=?) => EventTypes.event =
  "Event"

module Impl = (
  T: {
    type t
  },
) => {
  external asEvent: T.t => EventTypes.event = "%identity"

  @send
  external composedPath: T.t => array<EventTypes.eventTarget> = "composedPath"

  @send
  external preventDefault: T.t => unit = "preventDefault"

  @send
  external stopImmediatePropagation: T.t => unit = "stopImmediatePropagation"

  @send
  external stopPropagation: T.t => unit = "stopPropagation"
}

include Impl({type t = EventTypes.event})
