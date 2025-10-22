open UIEventsAPI

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MouseEvent)
*/
@new
external make: (~type_: string, ~eventInitDict: mouseEventInit=?) => mouseEvent = "MouseEvent"

module Impl = (
  T: {
    type t
  },
) => {
  external asMouseEvent: T.t => mouseEvent = "%identity"

  include UIEvent.Impl({type t = T.t})

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MouseEvent/getModifierState)
*/
  @send
  external getModifierState: (T.t, string) => bool = "getModifierState"
}

include Impl({type t = mouseEvent})
