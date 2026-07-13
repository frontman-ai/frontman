module Impl = (
  T: {
    type t
  },
) => {
  external asExtendableEvent: T.t => EventTypes.extendableEvent = "%identity"

  include Event.Impl({type t = T.t})

  @send
  external waitUntil: (T.t, promise<'a>) => unit = "waitUntil"
}

include Impl({type t = EventTypes.extendableEvent})
