@new
external make: (
  ~type_: string,
  ~eventInitDict: UiEventsTypes.uiEventInit=?,
) => UiEventsTypes.uiEvent = "UIEvent"

module Impl = (
  T: {
    type t
  },
) => {
  external asUIEvent: T.t => UiEventsTypes.uiEvent = "%identity"

  include Event.Impl({type t = T.t})
}

include Impl({type t = UiEventsTypes.uiEvent})
