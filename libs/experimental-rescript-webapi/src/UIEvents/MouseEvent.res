@new
external make: (
  ~type_: string,
  ~eventInitDict: UiEventsTypes.mouseEventInit=?,
) => UiEventsTypes.mouseEvent = "MouseEvent"

module Impl = (
  T: {
    type t
  },
) => {
  external asMouseEvent: T.t => UiEventsTypes.mouseEvent = "%identity"

  include UIEvent.Impl({type t = T.t})

  @send
  external getModifierState: (T.t, string) => bool = "getModifierState"
}

include Impl({type t = UiEventsTypes.mouseEvent})
