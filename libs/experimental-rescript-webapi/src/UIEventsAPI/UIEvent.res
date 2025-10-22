open UIEventsAPI

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/UIEvent)
*/
@new
external make: (~type_: string, ~eventInitDict: uiEventInit=?) => uiEvent = "UIEvent"

module Impl = (
  T: {
    type t
  },
) => {
  external asUIEvent: T.t => uiEvent = "%identity"

  include Event.Impl({type t = T.t})
}

include Impl({type t = uiEvent})
